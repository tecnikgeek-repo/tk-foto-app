// Il taglio della foto finita: misura del file e riquadro che si trascina.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkfoto/dati/composizione.dart';
import 'package:tkfoto/dati/scritte.dart';
import 'package:tkfoto/dati/stile.dart';
import 'package:tkfoto/schermate/taglio.dart';
import 'package:tkfoto/tema.dart';

void main() {
  test('taglio: si taglia il prodotto, lo sfondo resta intero e il prodotto non cambia misura', () async {
    // un «prodotto» quadrato pieno al centro di un'immagine trasparente
    final r = ui.PictureRecorder();
    Canvas(r).drawRect(const Rect.fromLTWH(100, 100, 200, 200), Paint()..color = const Color(0xFF0E7490));
    final soggetto = await r.endRecording().toImage(400, 400);
    const area = Rect.fromLTWH(100, 100, 200, 200);
    const stile = Stile(formato: Formato.quadrato);
    final intero = posizioneSoggetto(misuraTela(area, stile), area, stile);
    // si tiene solo la metà sinistra del prodotto
    final (byte, est) = await creaFoto(soggetto, area, stile, taglio: const Rect.fromLTWH(0, 0, .5, 1));
    expect(est, 'jpg');
    final codec = await ui.instantiateImageCodec(byte);
    final im = (await codec.getNextFrame()).image;
    expect((im.width, im.height), (2000, 2000), reason: 'la foto finita resta intera');
    final px = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    int rosso(Offset p) => px[(p.dy.round() * 2000 + p.dx.round()) * 4];
    // metà sinistra del prodotto: c'è ed è dove stava (colore del prodotto, rosso basso)
    expect(rosso(intero.center - Offset(intero.width / 4, 0)), lessThan(60));
    // metà destra: tagliata, si vede lo sfondo bianco
    expect(rosso(intero.center + Offset(intero.width / 4, 0)), greaterThan(200));
  });

  testWidgets('barra di avanzamento: sul fondo scuro la parte vuota si vede vuota', (t) async {
    configTk = configFoto;
    final chiave = GlobalKey();
    await t.pumpWidget(MaterialApp(
      theme: temaFoto(),
      home: Center(
        child: RepaintBoundary(
          key: chiave,
          child: const SizedBox(
              width: 300, height: 8, child: LinearProgressIndicator(value: .57, minHeight: 8)),
        ),
      ),
    ));
    late Uint8List px;
    await t.runAsync(() async {
      final im = await (chiave.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
      px = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    });
    List<int> a(int x) => px.sublist((4 * 300 + x) * 4, (4 * 300 + x) * 4 + 3);
    // a sinistra l'accento, a destra (oltre il 57%) il binario grigio scuro: devono essere diversi
    expect(a(30), [accento.r, accento.g, accento.b].map((c) => (c * 255).round()).toList());
    expect(a(270), isNot(a(30)));
  });

  test('scritte: il bollino dello sconto finisce nel file salvato', () async {
    final r = ui.PictureRecorder();
    Canvas(r).drawRect(const Rect.fromLTWH(100, 100, 200, 200), Paint()..color = const Color(0xFF0E7490));
    final soggetto = await r.endRecording().toImage(400, 400);
    final sconto = Scritta(TipoScritta.sconto, '-30%')..centro = const Offset(.15, .15);
    final (byte, _) = await creaFoto(soggetto, const Rect.fromLTWH(100, 100, 200, 200),
        const Stile(formato: Formato.quadrato), scritte: [sconto]);
    final im = (await (await ui.instantiateImageCodec(byte)).getNextFrame()).image;
    final px = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    // un po' sotto il centro del bollino (sopra c'è la scritta bianca): rosso pieno
    final i = ((300 + 170) * 2000 + 300) * 4;
    expect(px[i], greaterThan(180), reason: 'rosso ${px.sublist(i, i + 4)}');
    expect(px[i + 1], lessThan(80));
  });

  testWidgets('taglio: dall\'angolo il riquadro si stringe, con 1:1 resta quadrato', (t) async {
    configTk = configFoto;
    t.view.physicalSize = const Size(390 * 2, 1688);
    t.view.devicePixelRatio = 2;
    Rect? esito;
    final chiave = GlobalKey();
    await t.pumpWidget(RepaintBoundary(
      key: chiave,
      child: MaterialApp(
        theme: temaKit(),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => esito = await Navigator.of(c).push<Rect>(MaterialPageRoute(
                builder: (_) => SchermataTaglio(
                      tela: const Size(2000, 2000),
                      iniziale: tuttaLaFoto,
                      foto: Container(
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFFFDE68A), Color(0xFF0D9488)])),
                      ),
                    ))),
            child: const Text('apri'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('apri'));
    await t.pumpAndSettle();
    await t.tap(find.text('1:1'));
    await t.pump();
    final tela = t.getRect(find.byKey(const Key('tela-taglio')));
    // l'angolo in basso a destra trascinato verso il centro
    final g = await t.startGesture(tela.bottomRight - const Offset(4, 4));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(Offset(-tela.width * .03, -tela.height * .01));
      await t.pump();
    }
    await g.up();
    await t.pump();
    await t.runAsync(() async {
      final im = await (chiave.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 1);
      final png = await im.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/anteprime').createSync(recursive: true);
      File('build/anteprime/taglio.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    await t.tap(find.text('Applica'));
    await t.pumpAndSettle();
    expect(esito, isNotNull);
    expect(esito!.right, lessThan(.8));
    expect(esito!.topLeft, Offset.zero);
    expect((esito!.width - esito!.height).abs(), lessThan(.001), reason: 'con 1:1 deve restare quadrato: $esito');
  });
}
