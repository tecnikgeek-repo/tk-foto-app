// Il momento del risultato, appena finito lo scontorno: la linea di luce scende sulla foto e dove passa lo sfondo
// sparisce, resta solo il prodotto sul fondo scuro; poi il prodotto si solleva con un alone di luce e si
// riappoggia. Dura meno di due secondi, poi si passa all'editor.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tema.dart';

class Rivelazione extends StatefulWidget {
  const Rivelazione({super.key, required this.foto, required this.ritaglio, required this.onFine, this.fermaA});

  /// La foto raddrizzata, della stessa misura del ritaglio (così prodotto e foto combaciano).
  final String foto;
  final ui.Image ritaglio;
  final VoidCallback onFine;

  /// Solo per le anteprime: l'animazione resta ferma a questo punto (0–1).
  final double? fermaA;

  @override
  State<Rivelazione> createState() => _RivelazioneState();
}

class _RivelazioneState extends State<Rivelazione> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));

  @override
  void initState() {
    super.initState();
    if (widget.fermaA != null) {
      _t.value = widget.fermaA!;
      return;
    }
    _t.forward().whenComplete(() {
      if (mounted) widget.onFine();
    });
    // un colpetto quando il prodotto si stacca
    Future<void>.delayed(const Duration(milliseconds: 950), () {
      if (mounted) HapticFeedback.lightImpact();
    });
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        builder: (_, _) {
          final t = _t.value;
          // 0–0,5: la linea scende; 0,5–0,75: il prodotto si solleva; 0,75–1: si riappoggia
          final scesa = Curves.easeInOutCubic.transform((t / .5).clamp(0.0, 1.0));
          final su = Curves.easeOut.transform(((t - .5) / .25).clamp(0.0, 1.0));
          final giu = Curves.easeInOut.transform(((t - .75) / .25).clamp(0.0, 1.0));
          final scala = 1 + .05 * su - .05 * giu;
          final alone = (.75 * su - .45 * giu).clamp(0.0, 1.0);
          return LayoutBuilder(builder: (_, m) {
            final y = scesa * m.maxHeight;
            final prodotto = RawImage(image: widget.ritaglio, fit: BoxFit.cover);
            return Stack(fit: StackFit.expand, children: [
              const ColoredBox(color: notte),
              // la foto com'era, ancora sotto la linea
              ClipRect(
                clipper: _Fascia(y, sotto: true),
                child: Image.file(File(widget.foto), cacheWidth: 1000, fit: BoxFit.cover),
              ),
              // alone di luce attorno al prodotto
              if (alone > 0)
                Opacity(
                  opacity: alone,
                  child: Transform.scale(
                    scale: scala,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(luce1, BlendMode.srcIn), child: prodotto),
                    ),
                  ),
                ),
              // il prodotto staccato, sopra la linea
              ClipRect(
                clipper: _Fascia(y, sotto: false),
                child: Transform.scale(scale: scala, child: prodotto),
              ),
              // la linea di luce
              if (scesa < 1) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  top: y - 7,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(boxShadow: [
                      BoxShadow(color: luce1.withValues(alpha: .8), blurRadius: 16, spreadRadius: 1),
                    ]),
                  ),
                ),
                Positioned(left: 0, right: 0, top: y - 1.5, height: 3, child: const ColoredBox(color: accentoChiaro)),
              ],
            ]);
          });
        },
      );
}

/// La parte sopra o sotto la linea.
class _Fascia extends CustomClipper<Rect> {
  _Fascia(this.y, {required this.sotto});

  final double y;
  final bool sotto;

  @override
  Rect getClip(Size size) => sotto ? Rect.fromLTRB(0, y, size.width, size.height) : Rect.fromLTRB(0, 0, size.width, y);

  @override
  bool shouldReclip(_Fascia old) => old.y != y || old.sotto != sotto;
}
