// Composizione della foto finita: sfondo, ombra e soggetto ritagliato al centro.
// La stessa funzione disegna l'anteprima a schermo e la foto da salvare, così sono identiche.
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'scritte.dart';
import 'stile.dart';

/// Misura della foto finita (pixel) per il soggetto [area] con lo [stile].
Size misuraTela(Rect area, Stile stile) {
  final r = stile.formato.rapporto > 0
      ? stile.formato.rapporto
      : area.width / (area.height * (1 + stile.ombra.spazioSotto));
  return r >= 1
      ? Size(latoUscita.toDouble(), (latoUscita / r).roundToDouble())
      : Size((latoUscita * r).roundToDouble(), latoUscita.toDouble());
}

/// Ingrandimento e spostamento del soggetto fatti con le dita, propri di ogni foto.
class Regolazione {
  const Regolazione({this.zoom = 1, this.spostamento = Offset.zero, this.rotazione = 0});

  /// 1 = la misura che il soggetto ha da solo (centrato nello spazio libero).
  final double zoom;

  /// Spostamento in frazioni della tela (0,1 = un decimo della larghezza o dell'altezza).
  final Offset spostamento;

  /// Rotazione attorno al centro del soggetto, in radianti (positiva = senso orario).
  final double rotazione;

  static const nessuna = Regolazione();
  static const zoomMin = .3, zoomMax = 3.0;

  bool get modificata => zoom != 1 || spostamento != Offset.zero || rotazione != 0;

  /// Rotazione in gradi, tra -180 e 180.
  int get gradi {
    final g = (rotazione * 180 / pi).round() % 360;
    return g > 180 ? g - 360 : g;
  }

  /// Rotazione agganciata al quarto di giro più vicino quando ci si è entro [tolleranza] gradi.
  static double aggancia(double rotazione, {double tolleranza = 5}) {
    const quarto = pi / 2;
    final vicino = (rotazione / quarto).roundToDouble() * quarto;
    return (rotazione - vicino).abs() <= tolleranza * pi / 180 ? vicino : rotazione;
  }
}

/// Dove va il soggetto dentro la tela: centrato nello spazio libero, lasciando posto all'ombra sotto,
/// poi ingrandito e spostato secondo la [regolazione].
Rect posizioneSoggetto(Size tela, Rect area, Stile stile, [Regolazione regolazione = Regolazione.nessuna]) {
  final bordo = stile.margine * tela.shortestSide;
  final libero = Rect.fromLTRB(bordo, bordo, tela.width - bordo, tela.height - bordo);
  final sotto = 1 + stile.ombra.spazioSotto;
  // si fa stare nei margini l'ingombro del soggetto girato, non il soggetto dritto
  final ingombro = _ingombroGirato(Offset.zero & area.size, regolazione.rotazione);
  final scala = min(libero.width / ingombro.width, libero.height / (ingombro.height * sotto)) * regolazione.zoom;
  final w = area.width * scala, h = area.height * scala;
  final centro = Offset(libero.center.dx, libero.center.dy - ingombro.height * scala * (sotto - 1) / 2) +
      Offset(regolazione.spostamento.dx * tela.width, regolazione.spostamento.dy * tela.height);
  return Rect.fromCenter(center: centro, width: w, height: h);
}

/// La regolazione che mette il soggetto proprio in [voluto] (stesso posto e stessa misura), per esempio dove
/// stava nella foto originale.
Regolazione regolazioneVerso(Size tela, Rect area, Stile stile, Rect voluto) {
  final zoom = voluto.width / posizioneSoggetto(tela, area, stile).width;
  final conZoom = posizioneSoggetto(tela, area, stile, Regolazione(zoom: zoom));
  final d = voluto.center - conZoom.center;
  return Regolazione(zoom: zoom, spostamento: Offset(d.dx / tela.width, d.dy / tela.height));
}

/// Disegna la foto finita su [c], grande [tela]. [soggetto] è il ritaglio trasparente, [area] la parte piena.
/// [fondo] = immagine dello sfondo a tema, se lo sfondo scelto ne ha una.
/// [taglio] = la parte del prodotto da tenere (frazioni di [area]): il resto non si disegna, ma il prodotto
/// resta della stessa misura e nello stesso posto, e lo sfondo resta intero.
void disegnaFoto(Canvas c, Size tela, ui.Image soggetto, Rect area, Stile stile,
    {Regolazione regolazione = Regolazione.nessuna, ui.Image? fondo, Rect taglio = tuttaLaFoto}) {
  final tutto = Offset.zero & tela;
  if (fondo != null) {
    disegnaACoprire(c, fondo, tutto);
  } else {
    stile.sfondoScelto.disegna(c, tutto);
  }
  final dst = posizioneSoggetto(tela, area, stile, regolazione);
  final pennello = Paint()..filterQuality = FilterQuality.high;
  final scuroSfondo = stile.sfondoScuro;
  final giro = regolazione.rotazione;

  /// Il soggetto in [dove], girato attorno al suo centro e tagliato com'è stato scelto.
  void soggettoIn(Rect dove) {
    c.save();
    c.translate(dove.center.dx, dove.center.dy);
    if (giro != 0) c.rotate(giro);
    final r = Rect.fromCenter(center: Offset.zero, width: dove.width, height: dove.height);
    if (taglio != tuttaLaFoto) {
      c.clipRect(Rect.fromLTWH(r.left + taglio.left * r.width, r.top + taglio.top * r.height,
          taglio.width * r.width, taglio.height * r.height));
    }
    c.drawImageRect(soggetto, area, r, pennello);
    c.restore();
  }

  // ombra e riflesso stanno sotto il soggetto girato e tagliato: si usa il riquadro che lo contiene
  final tenuto = Rect.fromLTWH(dst.left + taglio.left * dst.width, dst.top + taglio.top * dst.height,
      taglio.width * dst.width, taglio.height * dst.height);
  final ingombro = _ingombroAttorno(tenuto, dst.center, giro);

  switch (stile.ombra) {
    case Ombra.nessuna:
      break;
    case Ombra.morbida:
      final sigma = max(1.0, dst.height * .03);
      c.saveLayer(
          tutto,
          Paint()
            ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma)
            ..colorFilter = ColorFilter.mode(Colors.black.withValues(alpha: scuroSfondo ? .6 : .3), BlendMode.srcIn));
      soggettoIn(dst.shift(Offset(dst.width * .015, dst.height * .03)));
      c.restore();
    case Ombra.aTerra:
      final ovale = Rect.fromCenter(
          center: Offset(ingombro.center.dx, ingombro.bottom - dst.height * .005),
          width: ingombro.width * .9,
          height: max(3.0, dst.height * .06));
      c.drawOval(
          ovale,
          Paint()
            ..color = Colors.black.withValues(alpha: scuroSfondo ? .7 : .4)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, ovale.height * .45));
    case Ombra.riflesso:
      final zona =
          Rect.fromLTWH(ingombro.left, ingombro.bottom, ingombro.width, dst.height * Ombra.riflesso.spazioSotto);
      c.saveLayer(zona, Paint());
      c.clipRect(zona);
      c.save();
      c.translate(0, ingombro.bottom * 2);
      c.scale(1, -1);
      soggettoIn(dst);
      c.restore();
      c.drawRect(
          zona,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = const LinearGradient(
                    colors: [Color(0x66FFFFFF), Color(0x1AFFFFFF), Color(0x00FFFFFF)],
                    stops: [0, .55, 1],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter)
                .createShader(zona));
      c.restore();
  }
  soggettoIn(dst);
}

/// Riquadro che contiene [r] girato di [giro] radianti attorno al suo centro.
Rect _ingombroGirato(Rect r, double giro) {
  if (giro == 0) return r;
  final w = (r.width * cos(giro)).abs() + (r.height * sin(giro)).abs();
  final h = (r.width * sin(giro)).abs() + (r.height * cos(giro)).abs();
  return Rect.fromCenter(center: r.center, width: w, height: h);
}

/// Riquadro che contiene [r] girato di [giro] radianti attorno al punto [centro].
Rect _ingombroAttorno(Rect r, Offset centro, double giro) {
  if (giro == 0) return r;
  final co = cos(giro), si = sin(giro);
  final punti = [
    for (final p in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight])
      centro + Offset((p.dx - centro.dx) * co - (p.dy - centro.dy) * si, (p.dx - centro.dx) * si + (p.dy - centro.dy) * co),
  ];
  return Rect.fromLTRB(punti.map((p) => p.dx).reduce(min), punti.map((p) => p.dy).reduce(min),
      punti.map((p) => p.dx).reduce(max), punti.map((p) => p.dy).reduce(max));
}

/// Disegna [immagine] in modo che copra tutto [dove], tagliando quello che avanza (centrata).
void disegnaACoprire(Canvas c, ui.Image immagine, Rect dove) {
  final w = immagine.width.toDouble(), h = immagine.height.toDouble();
  final scala = max(dove.width / w, dove.height / h);
  final src = Rect.fromCenter(center: Offset(w / 2, h / 2), width: dove.width / scala, height: dove.height / scala);
  c.drawImageRect(immagine, src, dove, Paint()..filterQuality = FilterQuality.high);
}

/// Tutta la foto del prodotto, senza taglio (il taglio è in frazioni della parte piena del ritaglio: 0–1).
const tuttaLaFoto = Rect.fromLTWH(0, 0, 1, 1);

/// La foto finita come file: JPG (qualità 92) con lo sfondo pieno, PNG se lo sfondo è trasparente.
Future<(Uint8List, String)> creaFoto(ui.Image soggetto, Rect area, Stile stile,
    {Regolazione regolazione = Regolazione.nessuna,
    ui.Image? fondo,
    Rect taglio = tuttaLaFoto,
    List<Scritta> scritte = const []}) async {
  final tela = misuraTela(area, stile);
  final registra = ui.PictureRecorder();
  final c = Canvas(registra);
  disegnaFoto(c, tela, soggetto, area, stile, regolazione: regolazione, fondo: fondo, taglio: taglio);
  disegnaScritte(c, tela, scritte);
  final immagine = await registra.endRecording().toImage(tela.width.toInt(), tela.height.toInt());
  try {
    if (stile.sfondoScelto.trasparente && fondo == null) {
      final png = await immagine.toByteData(format: ui.ImageByteFormat.png);
      return (png!.buffer.asUint8List(), 'png');
    }
    final grezzi = (await immagine.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    return (await _codificaJpg(grezzi, immagine.width, immagine.height), 'jpg');
  } finally {
    immagine.dispose();
  }
}

/// [areaPiena] in un isolate. Funzione a sé apposta: una chiusura scritta dentro una funzione async si porta
/// dietro tutte le sue variabili (anche le ui.Image, che non si possono spedire a un isolate).
Future<Rect?> calcolaAreaPiena(Uint8List rgba, int larghezza, int altezza) =>
    Isolate.run(() => areaPiena(rgba, larghezza, altezza));

Future<Uint8List> _codificaJpg(Uint8List rgba, int w, int h) => Isolate.run(() =>
    img.encodeJpg(img.Image.fromBytes(width: w, height: h, bytes: rgba.buffer, numChannels: 4), quality: 92));

/// Riquadro della parte piena (alfa > 24) di un'immagine RGBA; null se è tutta trasparente.
Rect? areaPiena(Uint8List rgba, int larghezza, int altezza) {
  var x0 = larghezza, y0 = altezza, x1 = -1, y1 = -1;
  for (var y = 0; y < altezza; y++) {
    final riga = y * larghezza * 4;
    for (var x = 0; x < larghezza; x++) {
      if (rgba[riga + x * 4 + 3] > 24) {
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        y1 = y;
      }
    }
  }
  if (x1 < 0) return null;
  return Rect.fromLTRB(x0.toDouble(), y0.toDouble(), x1 + 1.0, y1 + 1.0);
}
