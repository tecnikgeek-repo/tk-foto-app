// Foto di Benvenuto, Informazioni e Licenze su un telefono 412×915 con i caratteri veri, per guardarle senza
// telefono. Gira solo con `flutter test --update-goldens test/schermate_golden_test.dart` (in CI sul ramo):
// le PNG finiscono in test/goldens/ e la CI le carica come artefatto. Con `flutter test` normale si salta.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tkfoto/schermate/home.dart';
import 'package:tkfoto/tema.dart';
import 'package:tkfoto/tk_licenza.dart';
import 'package:tkfoto/tk_pro.dart';

import 'caratteri.dart';

const _telefono = Size(412, 915);

Future<void> _mostra(WidgetTester t, Widget schermata, {Size lato = _telefono}) async {
  t.view.physicalSize = lato * 2;
  t.view.devicePixelRatio = 2;
  await t.pumpWidget(MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: temaFoto(),
      home: schermata));
  await t.pump(const Duration(milliseconds: 300));
  // l'icona vera (asset) si decodifica solo fuori dal tempo finto del test
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(caricaCaratteri);

  testWidgets('foto delle schermate', skip: !autoUpdateGoldenFiles, (t) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'tk-foto',
        packageName: 'it.pietrodefilippis.tkfoto',
        version: '2.3.0',
        buildNumber: '30',
        buildSignature: '');
    configTk = configFoto;
    final lic = Licenza(slug: 'tk-foto', versione: '2.3.0');
    await t.runAsync(lic.carica);
    proTk = ProTk(lic);
    addTearDown(t.view.reset);

    await _mostra(t, SchermataBenvenuto(lic: lic, righeExtra: righeBenvenutoFoto));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/benvenuto.png'));

    // con l'interruttore acceso
    await t.tap(find.byType(Switch));
    await t.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/benvenuto-statistiche.png'));

    Future<List<(String, String)>> righe() async => [
          ('Scontorno', 'IS-Net sul telefono'),
          ('Sfondi a tema', '110 in 11 categorie'),
          ('Ultimo stile', 'Bianco · Quadrato'),
          ('Foto per volta', 'fino a 30'),
          ('Album in galleria', 'tk-foto'),
        ];
    const nota = 'Foto, ritagli e modello restano su questo telefono: niente viene caricato in rete.';
    await _mostra(t, SchermataInformazioni(righe: righe, notaDati: nota));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/informazioni.png'));

    await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await t.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/informazioni-fondo.png'));

    // tutta la pagina in una foto sola (telefono «lungo»)
    await _mostra(t, SchermataInformazioni(righe: righe, notaDati: nota), lato: const Size(412, 1700));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/informazioni-intera.png'));

    await _mostra(t, const SchermataLicenze(versione: '2.3.0'));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/licenze.png'));

    await t.pumpWidget(const SizedBox());
  });
}
