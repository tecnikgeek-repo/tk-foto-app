// Anteprime delle schermate (caratteri veri) in build/anteprime/, per controllarle senza telefono.
// Lo scontorno qui è finto: un «prodotto» disegnato su fondo trasparente.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkfoto/dati/composizione.dart';
import 'package:tkfoto/dati/scontorno.dart';
import 'package:tkfoto/dati/scritte.dart';
import 'package:tkfoto/dati/stile.dart';
import 'package:tkfoto/schermate/editor.dart';
import 'package:tkfoto/schermate/home.dart';
import 'package:tkfoto/schermate/ritocco.dart';
import 'package:tkfoto/schermate/rivelazione.dart';
import 'package:tkfoto/tema.dart';

import 'caratteri.dart';

Future<void> _caratteri() async {
  // Roboto e icone dalla cache di Flutter (nomi in minuscolo o con le maiuscole, vedi caratteri.dart)
  await caricaCaratteri();
  // il carattere delle scritte sulla foto
  final jakarta = FontLoader(carattereScritte);
  for (final w in [400, 500, 700, 800]) {
    jakarta.addFont(Future.value(ByteData.view(File('assets/font/PlusJakartaSans-$w.ttf').readAsBytesSync().buffer)));
  }
  await jakarta.load();
}

/// Un flacone disegnato su fondo trasparente, con margini vuoti attorno come un vero ritaglio;
/// con [conSfondo] è la «foto originale»: lo stesso flacone sul tavolo, con un vaso accanto.
Future<String> _prodottoFinto({bool conSfondo = false}) async {
  final r = ui.PictureRecorder();
  final c = Canvas(r);
  const w = 900.0, h = 1200.0;
  if (conSfondo) {
    c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFE7E1D8));
    c.drawRect(const Rect.fromLTWH(0, 900, w, 300), Paint()..color = const Color(0xFFB08968));
    c.drawOval(const Rect.fromLTWH(640, 640, 180, 300), Paint()..color = const Color(0xFF65A30D));
  }
  final corpo = RRect.fromRectAndRadius(const Rect.fromLTWH(300, 380, 300, 640), const Radius.circular(70));
  c.drawRRect(
      corpo,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFF0E7490), Color(0xFF22D3EE), Color(0xFF0E7490)])
            .createShader(corpo.outerRect));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(370, 250, 160, 150), const Radius.circular(24)),
      Paint()..color = const Color(0xFF1F2937));
  c.drawRect(const Rect.fromLTWH(300, 600, 300, 220), Paint()..color = const Color(0xFFF8FAFC));
  c.drawRect(const Rect.fromLTWH(330, 650, 240, 26), Paint()..color = const Color(0xFF0F172A));
  c.drawRect(const Rect.fromLTWH(330, 700, 170, 16), Paint()..color = const Color(0xFF94A3B8));
  c.drawRect(const Rect.fromLTWH(330, 730, 200, 16), Paint()..color = const Color(0xFF94A3B8));
  final im = await r.endRecording().toImage(w.toInt(), h.toInt());
  final png = await im.toByteData(format: ui.ImageByteFormat.png);
  final f = File('${Directory.systemTemp.path}/tkfoto-prova${conSfondo ? '-originale' : ''}.png')
    ..writeAsBytesSync(png!.buffer.asUint8List());
  return f.path;
}

late String _originaleFinto;

Future<void> _scontornoFinto(Foto f) async {
  f.diritta = _originaleFinto;
  final im = await caricaImmagine(f.originale);
  final rgba = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  f
    ..ritaglio = f.originale
    ..area = areaPiena(rgba, im.width, im.height)
    ..inCorso = false;
  im.dispose();
}

Future<void> _scatta(WidgetTester t, Widget w, String nome, {double alto = 1688}) async {
  t.view.physicalSize = Size(390 * 2, alto);
  t.view.devicePixelRatio = 2;
  final k = GlobalKey();
  await t.pumpWidget(RepaintBoundary(
    key: k,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaFoto(),
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: w,
    ),
  ));
  for (var i = 0; i < 12; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump(const Duration(milliseconds: 100));
  }
  // le dissolvenze (scanner → foto finita) devono essere finite prima della fotografia
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
  await t.runAsync(() async {
    final img = await (k.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/anteprime').createSync(recursive: true);
    File('build/anteprime/$nome.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

/// Dopo un tratto: aspetta che il riconoscimento degli oggetti (canale, isolate, immagine, nel tempo vero)
/// finisca e torni il pulsante «Applica».
Future<void> _aspettaApplica(WidgetTester t) async {
  await t.pump();
  for (var i = 0; i < 40 && find.text('Applica').evaluate().isEmpty; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump(const Duration(milliseconds: 50));
  }
  expect(find.text('Applica'), findsOneWidget, reason: 'il riconoscimento degli oggetti non finisce');
}

/// I testi degli avvisi a schermo, per capire perché il ritocco non si è chiuso.
String _avvisi(WidgetTester t) =>
    [for (final w in t.widgetList<Text>(find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)))) w.data]
        .join(' | ');

// sfondi a tema e vetrina (Canva) non sono nel repo pubblico: senza, queste prove si saltano (la CI li scarica)
final _senzaContenuti = !File('assets/sfondi/autunno/04.jpg').existsSync();

void main() {
  testWidgets('anteprime', skip: _senzaContenuti, (t) async {
    configTk = configFoto;
    late String prova;
    await t.runAsync(() async {
      await _caratteri();
      prova = await _prodottoFinto();
      _originaleFinto = await _prodottoFinto(conSfondo: true);
    });

    await _scatta(t, const SchermataHome(), 'home', alto: 1688);
    await _scatta(t, const SchermataHome(), 'home-intera', alto: 4400);
    await _scatta(
        t,
        SchermataEditor(percorsi: [prova], stileIniziale: const Stile(), scontornaDa: _scontornoFinto),
        'editor-bianco');
    await _scatta(
        t,
        SchermataEditor(
            percorsi: [prova, prova, prova],
            stileIniziale: const Stile(sfondo: 'studio', ombra: Ombra.riflesso, formato: Formato.verticale),
            scontornaDa: _scontornoFinto),
        'editor-lotto');
    await _scatta(
        t,
        SchermataEditor(
            percorsi: [prova],
            stileIniziale: const Stile(sfondo: 'trasparente', ombra: Ombra.aTerra, formato: Formato.storia),
            scontornaDa: _scontornoFinto),
        'editor-trasparente');
    await _scatta(
        t,
        SchermataEditor(
            percorsi: [prova],
            stileIniziale: const Stile(sfondo: 'natale-1', ombra: Ombra.aTerra, formato: Formato.verticale),
            scontornaDa: _scontornoFinto),
        'editor-natale');
    await _scatta(t, SchermataRitocco(ritaglio: prova, diritta: _originaleFinto), 'ritocco');
    // scritte sopra la foto: titolo, prezzo e sconto
    await _scatta(
        t,
        SchermataEditor(
            percorsi: [prova],
            stileIniziale: const Stile(sfondo: 'natale-1', ombra: Ombra.aTerra, formato: Formato.verticale),
            scontornaDa: (f) async {
              await _scontornoFinto(f);
              f.scritte.addAll([
                Scritta(TipoScritta.titolo, 'Crema viso'),
                Scritta(TipoScritta.prezzo, '€ 24,90'),
                Scritta(TipoScritta.sconto, '-30%'),
              ]);
            }),
        'editor-scritte');
    // il momento del risultato, fermo a metà discesa della linea e col prodotto sollevato
    late ui.Image ritaglio;
    await t.runAsync(() async => ritaglio = await caricaImmagine(prova));
    for (final (punto, nome) in [(.3, 'rivelazione-linea'), (.72, 'rivelazione-sollevato')]) {
      await _scatta(
          t,
          Scaffold(
            backgroundColor: notte,
            body: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: SizedBox(
                    width: 366,
                    height: 480,
                    child: Rivelazione(foto: _originaleFinto, ritaglio: ritaglio, onFine: () {}, fermaA: punto)),
              ),
            ),
          ),
          nome);
    }
    // mentre si toglie lo sfondo: effetto scanner (lo scontorno finto qui non finisce mai)
    await _scatta(
        t,
        SchermataEditor(
            percorsi: [_originaleFinto], stileIniziale: const Stile(), scontornaDa: (_) => Completer<void>().future),
        'editor-scanner');
  });

  testWidgets('ritocco: ripristinare a pennello allarga il ritaglio', (t) async {
    configTk = configFoto;
    // nei test non c'è il telefono: la cartella temporanea è quella del computer
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (_) async => Directory.systemTemp.path);
    late String prova, originale;
    await t.runAsync(() async {
      prova = await _prodottoFinto();
      originale = await _prodottoFinto(conSfondo: true);
    });
    t.view.physicalSize = const Size(390 * 2, 1688);
    t.view.devicePixelRatio = 2;
    RitaglioRitoccato? esito;
    await t.pumpWidget(MaterialApp(
      theme: temaKit(),
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => esito = await Navigator.of(c)
              .push<RitaglioRitoccato>(MaterialPageRoute(builder: (_) => SchermataRitocco(ritaglio: prova, diritta: originale))),
          child: const Text('apri'),
        ),
      ),
    ));
    await t.tap(find.text('apri'));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pumpAndSettle();
    // «Ripristina» e una pennellata sul vaso verde a destra del flacone
    await t.tap(find.text('Ripristina'));
    await t.pump();
    // la foto (900×1200) sta al centro della tela: il vaso è tra x 640 e 820, y 640 e 940
    final tela = t.getRect(find.byKey(const Key('tela-ritocco')));
    final s = min(tela.width / 900, tela.height / 1200) * .94;
    final angolo = tela.center - Offset(450 * s, 600 * s);
    final dito = await t.startGesture(angolo + Offset(730 * s, 700 * s));
    for (var i = 0; i < 12; i++) {
      await dito.moveBy(Offset(0, 15 * s));
      await t.pump(const Duration(milliseconds: 16));
    }
    await dito.up();
    await _aspettaApplica(t);
    // dopo il tratto l'icona «Annulla l'ultimo tratto» è attiva
    expect(t.widget<AzioneTk>(find.byType(AzioneTk).at(1)).onTap, isNotNull, reason: 'il tratto non è stato registrato');
    // il salvataggio (toImage, PNG, file) deve girare nel tempo vero, non in quello finto dei test
    await t.runAsync(() async {
      await t.tap(find.text('Applica'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    for (var i = 0; i < 20 && esito == null; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(esito, isNotNull, reason: _avvisi(t));
    // prima il soggetto finiva a x = 600, ora comprende anche un pezzo del vaso
    expect(esito!.$2.right, greaterThan(650));
    expect(esito!.$2.left, 300);
  });

  testWidgets('ritocco: riconoscendo gli oggetti si toglie il tappo senza toccare il flacone', (t) async {
    configTk = configFoto;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (_) async => Directory.systemTemp.path);
    // il telefono finto riconosce tre oggetti: tappo, corpo del flacone e vaso
    const oggetti = [Rect.fromLTRB(370, 250, 530, 400), Rect.fromLTRB(300, 380, 600, 1020), Rect.fromLTRB(640, 640, 820, 940)];
    var chiamate = 0;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('tkfoto/scontorno'), (c) async {
      if (c.method != 'oggetti') return null;
      chiamate++;
      final a = c.arguments as Map<Object?, Object?>;
      final x = a['x']! as int, y = a['y']! as int, w = a['larghezza']! as int, h = a['altezza']! as int;
      return {
        'larghezza': w,
        'altezza': h,
        'maschere': [
          for (final o in oggetti)
            Uint8List.fromList([
              for (var j = 0; j < h; j++)
                for (var i = 0; i < w; i++) o.contains(Offset(x + i + .5, y + j + .5)) ? 255 : 0
            ]),
        ],
      };
    });
    late String prova, originale;
    await t.runAsync(() async {
      prova = await _prodottoFinto();
      originale = await _prodottoFinto(conSfondo: true);
    });
    t.view.physicalSize = const Size(390 * 2, 1688);
    t.view.devicePixelRatio = 2;
    RitaglioRitoccato? esito;
    await t.pumpWidget(MaterialApp(
      theme: temaKit(),
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => esito = await Navigator.of(c)
              .push<RitaglioRitoccato>(MaterialPageRoute(builder: (_) => SchermataRitocco(ritaglio: prova, diritta: originale))),
          child: const Text('apri'),
        ),
      ),
    ));
    await t.tap(find.text('apri'));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pumpAndSettle();
    // pennello al massimo: un tratto che parte dal tappo scuro (370–530, 250–400) e scende sul corpo azzurro
    final cursore = t.getRect(find.byType(Slider));
    await t.tapAt(cursore.centerRight - const Offset(4, 0));
    await t.pump();
    final tela = t.getRect(find.byKey(const Key('tela-ritocco')));
    final s = min(tela.width / 900, tela.height / 1200) * .94;
    final angolo = tela.center - Offset(450 * s, 600 * s);
    // passa sugli angoli in alto del tappo (il bordo del pennello è sfumato), poi scende fin sul corpo
    final tappa = [const Offset(450, 320), const Offset(400, 260), const Offset(500, 260), const Offset(450, 320), const Offset(450, 480)];
    final dito = await t.startGesture(angolo + tappa.first * s);
    for (var i = 1; i < tappa.length; i++) {
      for (var j = 0; j < 6; j++) {
        await dito.moveBy((tappa[i] - tappa[i - 1]) * s / 6);
        await t.pump(const Duration(milliseconds: 16));
      }
    }
    // schermata col dito ancora giù: si vedono il cerchio del pennello e la lente
    await t.runAsync(() async {
      RenderObject? o = t.renderObject(find.byKey(const Key('tela-ritocco')));
      while (o != null && o is! RenderRepaintBoundary) {
        o = o.parent;
      }
      final im = await (o! as RenderRepaintBoundary).toImage(pixelRatio: 1);
      final png = await im.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/anteprime').createSync(recursive: true);
      File('build/anteprime/ritocco-lente.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    await dito.up();
    await _aspettaApplica(t);
    expect(chiamate, 1, reason: 'il tratto non ha chiesto gli oggetti al telefono');
    await t.runAsync(() async {
      await t.tap(find.text('Applica'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    for (var i = 0; i < 20 && esito == null; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(esito, isNotNull, reason: _avvisi(t));
    File(esito!.$1).copySync('build/anteprime/ritocco-esito.png');
    // il tappo non c'è più (prima la parte piena iniziava a y 250), il corpo (da y 380) è rimasto intero
    expect(esito!.$2.top, inInclusiveRange(378, 400));
    expect(esito!.$2.bottom, 1020);
    expect(esito!.$2.left, 300);
    expect(esito!.$2.right, 600);
  });

  testWidgets('ritocco: «Ripara» ricostruisce l\'archetto sotto il gancio', (t) async {
    configTk = configFoto;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (_) async => Directory.systemTemp.path);
    // archetto nero orizzontale (y 500–600) con un gancio grigio sopra (x 400–500, y 470–630)
    Future<String> archetto({required bool conSfondo}) async {
      final r = ui.PictureRecorder();
      final c = Canvas(r);
      if (conSfondo) c.drawRect(const Rect.fromLTWH(0, 0, 900, 1200), Paint()..color = const Color(0xFFE7E1D8));
      c.drawRect(const Rect.fromLTRB(100, 500, 800, 600), Paint()..color = const Color(0xFF111111));
      c.drawRect(const Rect.fromLTRB(400, 470, 500, 630), Paint()..color = const Color(0xFFB8C0C8));
      final im = await r.endRecording().toImage(900, 1200);
      final png = await im.toByteData(format: ui.ImageByteFormat.png);
      return (File('${Directory.systemTemp.path}/tkfoto-archetto${conSfondo ? '-originale' : ''}.png')
            ..writeAsBytesSync(png!.buffer.asUint8List()))
          .path;
    }

    late String prova, originale;
    await t.runAsync(() async {
      prova = await archetto(conSfondo: false);
      originale = await archetto(conSfondo: true);
    });
    t.view.physicalSize = const Size(390 * 2, 1688);
    t.view.devicePixelRatio = 2;
    RitaglioRitoccato? esito;
    await t.pumpWidget(MaterialApp(
      theme: temaKit(),
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => esito = await Navigator.of(c)
              .push<RitaglioRitoccato>(MaterialPageRoute(builder: (_) => SchermataRitocco(ritaglio: prova, diritta: originale))),
          child: const Text('apri'),
        ),
      ),
    ));
    await t.tap(find.text('apri'));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pumpAndSettle();
    await t.tap(find.text('Ripara'));
    await t.pump();
    final cursore = t.getRect(find.byType(Slider));
    await t.tapAt(cursore.centerRight - const Offset(4, 0));
    await t.pump();
    final tela = t.getRect(find.byKey(const Key('tela-ritocco')));
    final s = min(tela.width / 900, tela.height / 1200) * .94;
    final angolo = tela.center - Offset(450 * s, 600 * s);
    // pennello al massimo, un tratto verticale che copre tutto il gancio
    final dito = await t.startGesture(angolo + const Offset(450, 455) * s);
    for (var i = 0; i < 12; i++) {
      await dito.moveBy(const Offset(0, 16) * s);
      await t.pump(const Duration(milliseconds: 16));
    }
    await dito.up();
    await _aspettaApplica(t);
    expect(find.byType(SnackBar), findsNothing, reason: _avvisi(t));
    await t.runAsync(() async {
      await t.tap(find.text('Applica'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    for (var i = 0; i < 20 && esito == null; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(esito, isNotNull, reason: _avvisi(t));
    late Uint8List px;
    late int w;
    await t.runAsync(() async {
      File(esito!.$1).copySync('build/anteprime/ritocco-ripara.png');
      final im = await caricaImmagine(esito!.$1);
      w = im.width;
      px = (await im.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
      im.dispose();
    });
    List<int> pixel(int x, int y) => px.sublist((y * w + x) * 4, (y * w + x) * 4 + 4);
    // al centro dell'archetto, dove c'era il gancio: nero e pieno
    expect(pixel(450, 550)[3], greaterThan(200), reason: 'pixel ${pixel(450, 550)}');
    expect(pixel(450, 550)[0], lessThan(70), reason: 'pixel ${pixel(450, 550)}');
    // sopra e sotto l'archetto, dove c'era solo il gancio: vuoto
    expect(pixel(450, 482)[3], lessThan(60), reason: 'pixel ${pixel(450, 482)}');
    expect(pixel(450, 620)[3], lessThan(60), reason: 'pixel ${pixel(450, 620)}');
  });

  test('foto finita: misure e file', skip: _senzaContenuti, () async {
    configTk = configFoto;
    final im = await caricaImmagine(await _prodottoFinto());
    final rgba = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    final area = areaPiena(rgba, im.width, im.height)!;
    expect(area, const Rect.fromLTRB(300, 250, 600, 1020));
    expect(misuraTela(area, const Stile()), const Size(2000, 2000));
    expect(misuraTela(area, const Stile(formato: Formato.storia)), const Size(1125, 2000));
    for (final (stile, nome) in [
      (const Stile(sfondo: 'bianco', ombra: Ombra.morbida), 'foto-morbida'),
      (const Stile(sfondo: 'alba', ombra: Ombra.riflesso, formato: Formato.verticale), 'foto-riflesso'),
      (const Stile(sfondo: 'trasparente', ombra: Ombra.aTerra), 'foto-trasparente'),
    ]) {
      final (byte, est) = await creaFoto(im, area, stile);
      expect(est, stile.sfondoScelto.trasparente ? 'png' : 'jpg');
      Directory('build/anteprime').createSync(recursive: true);
      File('build/anteprime/$nome.$est').writeAsBytesSync(byte);
    }
    // sfondo a tema + prodotto rimpicciolito e spostato con le dita
    final fondo = await caricaAsset('assets/sfondi/autunno/04.jpg');
    final (byte, est) = await creaFoto(im, area, const Stile(sfondo: 'autunno-4', ombra: Ombra.aTerra),
        regolazione: const Regolazione(zoom: .7, spostamento: Offset(0, .08)), fondo: fondo);
    expect(est, 'jpg');
    File('build/anteprime/foto-autunno.jpg').writeAsBytesSync(byte);
    // prodotto girato di 30°: ombra a terra e riflesso seguono l'ingombro
    for (final ombra in [Ombra.aTerra, Ombra.riflesso]) {
      final (girata, _) = await creaFoto(im, area, Stile(sfondo: 'autunno-4', ombra: ombra),
          regolazione: const Regolazione(rotazione: pi / 6), fondo: fondo);
      File('build/anteprime/foto-girata-${ombra.name}.jpg').writeAsBytesSync(girata);
    }
    expect(Regolazione.aggancia(88 * pi / 180), pi / 2);
    expect(Regolazione.aggancia(80 * pi / 180), 80 * pi / 180);
    expect(const Regolazione(rotazione: -pi / 6).gradi, -30);
    fondo.dispose();
    im.dispose();
  });
}
