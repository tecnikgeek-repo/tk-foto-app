// Scritte sopra la foto finita: titolo, prezzo (etichetta), sconto (bollino), scritta libera.
// Posizione e grandezza sono in frazioni della tela, quindi l'anteprima e il file salvato vengono uguali.
import 'dart:math';

import 'package:flutter/material.dart';

import '../tema.dart' show carattereScritte;

enum TipoScritta {
  titolo('Titolo', 'Nome del prodotto', Icons.title_rounded),
  prezzo('Prezzo', '€ 19,90', Icons.sell_rounded),
  sconto('Sconto', '-30%', Icons.percent_rounded),
  scritta('Scritta', 'Novità', Icons.text_fields_rounded);

  const TipoScritta(this.nome, this.esempio, this.icona);

  final String nome, esempio;
  final IconData icona;
}

/// Colori proposti per le scritte (per prezzo e sconto è il colore dell'etichetta).
const coloriScritte = [
  Color(0xFF0F172A),
  Colors.white,
  Color(0xFFDC2626),
  Color(0xFF0D9488),
  Color(0xFFD4A017),
  Color(0xFFDB2777),
  Color(0xFF2563EB),
];

class Scritta {
  Scritta(this.tipo, this.testo)
      : centro = switch (tipo) {
          TipoScritta.titolo => const Offset(.5, .065),
          TipoScritta.prezzo => const Offset(.76, .88),
          TipoScritta.sconto => const Offset(.83, .26),
          TipoScritta.scritta => const Offset(.5, .9),
        },
        grandezza = switch (tipo) {
          TipoScritta.titolo => .06,
          TipoScritta.prezzo => .06,
          TipoScritta.sconto => .065,
          TipoScritta.scritta => .05,
        },
        colore = switch (tipo) {
          TipoScritta.sconto => const Color(0xFFDC2626),
          _ => const Color(0xFF0F172A),
        };

  final TipoScritta tipo;
  String testo;

  /// Centro della scritta, in frazioni della tela.
  Offset centro;

  /// Altezza delle lettere, in frazioni del lato corto della tela.
  double grandezza;

  /// Colore del testo (titolo, scritta) o dell'etichetta (prezzo, sconto).
  Color colore;

  static const grandezzaMin = .025, grandezzaMax = .2;
}

/// Il colore del testo su un'etichetta di colore [fondo]: bianco sulle scure, scuro sulle chiare.
Color _sopra(Color fondo) => fondo.computeLuminance() > .6 ? const Color(0xFF0F172A) : Colors.white;

TextPainter _impagina(Scritta s, Size tela) {
  final fs = s.grandezza * tela.shortestSide;
  final etichetta = s.tipo == TipoScritta.prezzo || s.tipo == TipoScritta.sconto;
  final colore = etichetta ? _sopra(s.colore) : s.colore;
  return TextPainter(
    text: TextSpan(
      text: s.tipo == TipoScritta.titolo ? s.testo.toUpperCase() : s.testo,
      style: TextStyle(
        fontFamily: carattereScritte,
        fontSize: fs,
        height: 1.1,
        color: colore,
        fontWeight: s.tipo == TipoScritta.scritta ? FontWeight.w700 : FontWeight.w800,
        letterSpacing: s.tipo == TipoScritta.titolo ? fs * .06 : 0,
        // le scritte bianche senza etichetta hanno un'ombra leggera, per leggersi anche sui fondi chiari
        shadows: !etichetta && colore.computeLuminance() > .6
            ? [Shadow(color: const Color(0x66000000), blurRadius: fs * .25, offset: Offset(0, fs * .05))]
            : null,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: s.tipo == TipoScritta.sconto ? 2 : 3,
  )..layout(maxWidth: tela.width * .9);
}

/// Il riquadro della scritta sulla tela (senza la rotazione del bollino): serve anche per toccarla.
Rect ingombroScritta(Scritta s, Size tela) {
  final tp = _impagina(s, tela);
  final fs = s.grandezza * tela.shortestSide;
  final c = Offset(s.centro.dx * tela.width, s.centro.dy * tela.height);
  return switch (s.tipo) {
    TipoScritta.prezzo =>
      Rect.fromCenter(center: c, width: tp.width + fs * 1.1, height: tp.height + fs * .6),
    TipoScritta.sconto => Rect.fromCircle(center: c, radius: max(tp.width, tp.height) / 2 + fs * .55),
    _ => Rect.fromCenter(center: c, width: tp.width, height: tp.height),
  };
}

/// Disegna le [scritte] sulla tela; [scelta] ha attorno il riquadro tratteggiato (solo a schermo).
void disegnaScritte(Canvas c, Size tela, List<Scritta> scritte, {Scritta? scelta}) {
  for (final s in scritte) {
    final tp = _impagina(s, tela);
    final r = ingombroScritta(s, tela);
    final fs = s.grandezza * tela.shortestSide;
    c.save();
    if (s.tipo == TipoScritta.sconto) {
      // il bollino è un po' inclinato, come un adesivo
      c.translate(r.center.dx, r.center.dy);
      c.rotate(-12 * pi / 180);
      c.translate(-r.center.dx, -r.center.dy);
    }
    switch (s.tipo) {
      case TipoScritta.prezzo:
        c.drawRRect(RRect.fromRectAndRadius(r.shift(Offset(0, fs * .08)), Radius.circular(r.height / 2)),
            Paint()
              ..color = const Color(0x40000000)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, fs * .2));
        c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)), Paint()..color = s.colore);
      case TipoScritta.sconto:
        c.drawCircle(r.center.translate(0, fs * .08), r.width / 2,
            Paint()
              ..color = const Color(0x40000000)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, fs * .2));
        c.drawCircle(r.center, r.width / 2, Paint()..color = s.colore);
      case _:
        break;
    }
    tp.paint(c, r.center - Offset(tp.width / 2, tp.height / 2));
    c.restore();
    if (identical(s, scelta)) {
      final bordo = r.inflate(max(6, fs * .25));
      final tratto = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF22D3EE);
      c.drawRRect(RRect.fromRectAndRadius(bordo, const Radius.circular(8)), tratto);
    }
  }
}
