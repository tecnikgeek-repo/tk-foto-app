// Schermate per la scheda del Play Store (1080×1920, 9:16) con le foto vere della vetrina: il ritaglio è quello
// già pronto in assets/demo/<nome>-dopo.png, la foto originale <nome>-prima.jpg. Finiscono in build/store/.
// Gira solo con `flutter test --dart-define=STORE=true test/store_test.dart` e con gli sfondi a tema presenti.
import 'dart:io';
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
import 'package:tkfoto/tema.dart';

import 'caratteri.dart';

const _store = bool.fromEnvironment('STORE');
final _senzaContenuti = !File('assets/sfondi/natale/02.jpg').existsSync();

/// Copia un asset in un file temporaneo: l'editor apre percorsi di file, come quelli della galleria.
String _file(String nome) {
  final f = File('${Directory.systemTemp.path}/tkfoto-store-$nome')..writeAsBytesSync(File('assets/demo/$nome').readAsBytesSync());
  return f.path;
}

/// Scontorno «già fatto»: il ritaglio vero della vetrina al posto del modello.
Future<void> Function(Foto) _ritaglioDi(String esempio, {List<Scritta> scritte = const []}) => (f) async {
      final ritaglio = _file('$esempio-dopo.png');
      final im = await caricaImmagine(ritaglio);
      final rgba = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      f
        ..diritta = _file('$esempio-prima.jpg')
        ..ritaglio = ritaglio
        ..area = areaPiena(rgba, im.width, im.height)
        ..inCorso = false;
      f.scritte.addAll(scritte);
      im.dispose();
    };

Future<void> _scatta(WidgetTester t, Widget w, String nome) async {
  t.view.physicalSize = const Size(1080, 1920);
  t.view.devicePixelRatio = 3;
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
  for (var i = 0; i < 16; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump(const Duration(milliseconds: 100));
  }
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
  await t.runAsync(() async {
    final img = await (k.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 3);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/store').createSync(recursive: true);
    File('build/store/$nome.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('schermate per il Play Store', skip: !_store || _senzaContenuti, (t) async {
    configTk = configFoto;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (_) async => Directory.systemTemp.path);
    await t.runAsync(() async {
      await caricaCaratteri();
      final jakarta = FontLoader(carattereScritte);
      for (final w in [400, 500, 700, 800]) {
        jakarta.addFont(Future.value(ByteData.view(File('assets/font/PlusJakartaSans-$w.ttf').readAsBytesSync().buffer)));
      }
      await jakarta.load();
    });

    await _scatta(t, const SchermataHome(), '1-home');
    await _scatta(
        t,
        SchermataEditor(
            percorsi: [_file('borsa-prima.jpg')],
            stileIniziale: const Stile(sfondo: 'natale-2', ombra: Ombra.aTerra, formato: Formato.verticale),
            scontornaDa: _ritaglioDi('borsa')),
        '2-sfondo-a-tema');
    await _scatta(
        t,
        SchermataEditor(
            percorsi: [_file('scarpa-prima.jpg')],
            stileIniziale: const Stile(sfondo: 'blackfriday-1', ombra: Ombra.aTerra, formato: Formato.verticale),
            scontornaDa: _ritaglioDi('scarpa', scritte: [
              Scritta(TipoScritta.titolo, 'Sneaker'),
              Scritta(TipoScritta.prezzo, '€ 89,90'),
              Scritta(TipoScritta.sconto, '-20%'),
            ])),
        '3-scritte');
    await _scatta(
        t,
        SchermataEditor(
            percorsi: [_file('orologio-prima.jpg')],
            stileIniziale: const Stile(sfondo: 'studio', ombra: Ombra.riflesso, formato: Formato.quadrato),
            scontornaDa: _ritaglioDi('orologio')),
        '4-studio');
    await _scatta(t, SchermataRitocco(ritaglio: _file('cuffie-dopo.png'), diritta: _file('cuffie-prima.jpg')), '5-ritocco');
    await _scatta(
        t,
        SchermataEditor(
            percorsi: [_file('peluche-prima.jpg')],
            stileIniziale: const Stile(sfondo: 'festamamma-4', ombra: Ombra.morbida, formato: Formato.verticale),
            scontornaDa: _ritaglioDi('peluche')),
        '6-festa');
  });
}
