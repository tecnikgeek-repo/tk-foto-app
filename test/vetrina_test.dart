// Provino degli esempi della vetrina in home, in build/anteprime/vetrina.png: sopra il «dopo» (prodotto nel suo
// contesto, nello stesso punto della foto), sotto il «prima». Stessi calcoli di _PittoreVetrina in home.dart.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkfoto/dati/composizione.dart';
import 'package:tkfoto/dati/stile.dart';

const _esempi = ['flacone', 'peluche', 'borsa', 'auto', 'scarpa', 'orologio', 'cuffie'];

Future<ui.Image> _apri(String percorso) async {
  final codec = await ui.instantiateImageCodec(File(percorso).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

void main() {
  // le foto della vetrina (Canva) non sono nel repo pubblico: senza, la prova si salta (la CI le scarica)
  test('vetrina: tutti gli esempi', skip: !File('assets/demo/flacone-dopo.png').existsSync(), () async {
    const lato = Size(400, 430);
    final registra = ui.PictureRecorder();
    final c = Canvas(registra);
    for (var i = 0; i < _esempi.length; i++) {
      final nome = _esempi[i];
      final s = await _apri('assets/demo/$nome-dopo.png');
      final rgba = (await s.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      final a = areaPiena(rgba, s.width, s.height)!;
      final fondo = await _apri('assets/demo/$nome-contesto.jpg');
      final p = await _apri('assets/demo/$nome-prima.jpg');
      final scala = max(lato.width / p.width, lato.height / p.height);
      final angolo = Offset((lato.width - p.width * scala) / 2, (lato.height - p.height * scala) / 2);
      final kx = p.width / s.width * scala, ky = p.height / s.height * scala;
      final voluto = Rect.fromLTRB(
          angolo.dx + a.left * kx, angolo.dy + a.top * ky, angolo.dx + a.right * kx, angolo.dy + a.bottom * ky);
      const stile = Stile(ombra: Ombra.aTerra, formato: Formato.quadrato, margine: .17);
      final reg = regolazioneVerso(lato, a, stile, voluto);
      // il prodotto nel «dopo» deve stare dove sta nel «prima»
      final dove = posizioneSoggetto(lato, a, stile, reg);
      expect((dove.center - voluto.center).distance, lessThan(1), reason: nome);
      expect((dove.width - voluto.width).abs(), lessThan(1), reason: nome);
      c.save();
      c.translate(i * lato.width, 0);
      c.clipRect(Offset.zero & lato);
      disegnaFoto(c, lato, s, a, stile, fondo: fondo, regolazione: reg);
      c.restore();
      c.save();
      c.translate(i * lato.width, lato.height);
      disegnaACoprire(c, p, Offset.zero & lato);
      c.restore();
    }
    final im = await registra.endRecording().toImage((lato.width * _esempi.length).toInt(), (lato.height * 2).toInt());
    final png = await im.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/anteprime').createSync(recursive: true);
    File('build/anteprime/vetrina.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
