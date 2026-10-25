// Taglio della foto del prodotto (solo il ritaglio: lo sfondo resta intero e il prodotto non cambia misura):
// un riquadro che si sposta trascinandolo e si allarga dagli angoli, con le proporzioni pronte
// (libero, 1:1, 4:5, 9:16, 16:9). Ritorna il taglio in frazioni della parte piena del ritaglio.
import 'dart:math';

import 'package:flutter/material.dart';

import '../dati/composizione.dart';
import '../tema.dart';

/// Proporzioni pronte del taglio (larghezza / altezza in pixel); null = libero.
const _proporzioni = <(String, double?)>[
  ('Libero', null),
  ('1:1', 1),
  ('4:5', 4 / 5),
  ('3:4', 3 / 4),
  ('9:16', 9 / 16),
  ('16:9', 16 / 9),
];

/// Lato minimo del riquadro, in frazioni della foto.
const _minimo = .12;

class SchermataTaglio extends StatefulWidget {
  const SchermataTaglio({super.key, required this.tela, required this.iniziale, required this.foto});

  /// Misura in pixel della foto intera (serve per le proporzioni).
  final Size tela;
  final Rect iniziale;

  /// La foto intera, senza taglio, disegnata a tutta la superficie che le si dà.
  final Widget foto;

  @override
  State<SchermataTaglio> createState() => _SchermataTaglioState();
}

enum _Presa { sposta, altoSinistra, altoDestra, bassoSinistra, bassoDestra }

class _SchermataTaglioState extends State<SchermataTaglio> {
  late Rect _r = widget.iniziale;
  double? _rapporto;
  _Presa? _presa;

  /// Rapporto larghezza/altezza in frazioni che corrisponde a [rapporto] in pixel.
  double _inFrazioni(double rapporto) => rapporto * widget.tela.height / widget.tela.width;

  /// Il riquadro più grande con [rapporto] (in pixel), centrato dov'era il taglio di prima.
  void _proporzione(double? rapporto) {
    setState(() {
      _rapporto = rapporto;
      if (rapporto == null) return;
      final k = _inFrazioni(rapporto);
      var w = 1.0, h = 1 / k;
      if (h > 1) {
        h = 1;
        w = k;
      }
      final c = _r.center;
      final l = (c.dx - w / 2).clamp(0.0, 1 - w), t = (c.dy - h / 2).clamp(0.0, 1 - h);
      _r = Rect.fromLTWH(l, t, w, h);
    });
  }

  void _inizio(DragStartDetails d, Size misura) {
    final p = Offset(d.localPosition.dx / misura.width, d.localPosition.dy / misura.height);
    // gli angoli si prendono anche un po' fuori: le dita sono grosse
    final presaX = 30 / misura.width, presaY = 30 / misura.height;
    bool vicino(Offset a) => (p.dx - a.dx).abs() < presaX && (p.dy - a.dy).abs() < presaY;
    _presa = vicino(_r.topLeft)
        ? _Presa.altoSinistra
        : vicino(_r.topRight)
            ? _Presa.altoDestra
            : vicino(_r.bottomLeft)
                ? _Presa.bassoSinistra
                : vicino(_r.bottomRight)
                    ? _Presa.bassoDestra
                    : _r.contains(p)
                        ? _Presa.sposta
                        : null;
  }

  void _muovi(DragUpdateDetails d, Size misura) {
    final presa = _presa;
    if (presa == null) return;
    final dx = d.delta.dx / misura.width, dy = d.delta.dy / misura.height;
    setState(() {
      if (presa == _Presa.sposta) {
        _r = _r.shift(Offset(dx, dy));
        _r = _r.shift(Offset(
          _r.left < 0 ? -_r.left : (_r.right > 1 ? 1 - _r.right : 0),
          _r.top < 0 ? -_r.top : (_r.bottom > 1 ? 1 - _r.bottom : 0),
        ));
        return;
      }
      // l'angolo opposto resta fermo
      final fermo = switch (presa) {
        _Presa.altoSinistra => _r.bottomRight,
        _Presa.altoDestra => _r.bottomLeft,
        _Presa.bassoSinistra => _r.topRight,
        _ => _r.topLeft,
      };
      final mobile = switch (presa) {
        _Presa.altoSinistra => _r.topLeft,
        _Presa.altoDestra => _r.topRight,
        _Presa.bassoSinistra => _r.bottomLeft,
        _ => _r.bottomRight,
      };
      var nuovo = Offset((mobile.dx + dx).clamp(0.0, 1.0), (mobile.dy + dy).clamp(0.0, 1.0));
      var w = max(_minimo, (nuovo.dx - fermo.dx).abs()), h = max(_minimo, (nuovo.dy - fermo.dy).abs());
      final rapporto = _rapporto;
      if (rapporto != null) {
        // proporzione bloccata: comanda la larghezza, l'altezza segue, e tutto resta dentro la foto
        final k = _inFrazioni(rapporto);
        h = w / k;
        final maxW = nuovo.dx < fermo.dx ? fermo.dx : 1 - fermo.dx;
        final maxH = nuovo.dy < fermo.dy ? fermo.dy : 1 - fermo.dy;
        if (h > maxH) {
          h = maxH;
          w = h * k;
        }
        if (w > maxW) {
          w = maxW;
          h = w / k;
        }
      }
      final sx = mobile.dx < fermo.dx ? -1 : 1, sy = mobile.dy < fermo.dy ? -1 : 1;
      nuovo = Offset(fermo.dx + sx * w, fermo.dy + sy * h);
      _r = Rect.fromPoints(fermo, nuovo).intersect(tuttaLaFoto);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: notte,
        body: Column(children: [
          TestataSemplice(
            titolo: 'Taglia la foto',
            indietro: () => Navigator.of(context).pop(),
            azioni: [
              AzioneTk(Icons.crop_free_rounded, 'Tutta la foto', () => setState(() {
                    _r = tuttaLaFoto;
                    _rapporto = null;
                  })),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.tela.width / widget.tela.height,
                  child: LayoutBuilder(builder: (_, m) {
                    final misura = m.biggest;
                    return GestureDetector(
                      key: const Key('tela-taglio'),
                      onPanStart: (d) => _inizio(d, misura),
                      onPanUpdate: (d) => _muovi(d, misura),
                      onPanEnd: (_) => _presa = null,
                      child: Stack(fit: StackFit.expand, children: [
                        ClipRect(child: widget.foto),
                        CustomPaint(painter: _Riquadro(_r)),
                      ]),
                    );
                  }),
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: navy,
              border: Border(top: BorderSide(color: filoVetro)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _proporzioni.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (nome, rapporto) = _proporzioni[i];
                    final scelta = rapporto == _rapporto;
                    return ChoiceChip(
                      label: Text(nome),
                      selected: scelta,
                      onSelected: (_) => _proporzione(rapporto),
                      showCheckmark: false,
                      labelStyle: TextStyle(color: scelta ? notte : grigio200, fontWeight: FontWeight.w800),
                      selectedColor: luce1,
                      backgroundColor: navy2,
                      side: BorderSide(color: scelta ? luce1 : filoVetro),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                  'Si taglia solo il prodotto, lo sfondo resta intero. Trascina il riquadro per spostarlo, '
                  'gli angoli per cambiarne la misura',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: grigio400, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              BottoneTk(
                  testo: 'Applica', icona: Icons.check_rounded, onTap: () => Navigator.of(context).pop<Rect>(_r)),
            ]),
          ),
        ]),
      );
}

/// Il riquadro del taglio: fuori la foto è velata, sul bordo le linee dei terzi e gli angoli da prendere.
class _Riquadro extends CustomPainter {
  const _Riquadro(this.r);

  final Rect r;

  @override
  void paint(Canvas canvas, Size size) {
    final q = Rect.fromLTRB(r.left * size.width, r.top * size.height, r.right * size.width, r.bottom * size.height);
    canvas.drawPath(
        Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRect(q)),
        Paint()..color = const Color(0x99000000));
    final linea = Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(q.left + q.width * i / 3, q.top), Offset(q.left + q.width * i / 3, q.bottom), linea);
      canvas.drawLine(Offset(q.left, q.top + q.height * i / 3), Offset(q.right, q.top + q.height * i / 3), linea);
    }
    canvas.drawRect(
        q,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = bianco);
    final angolo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = bianco;
    const l = 22.0;
    for (final (p, sx, sy) in [
      (q.topLeft, 1.0, 1.0),
      (q.topRight, -1.0, 1.0),
      (q.bottomLeft, 1.0, -1.0),
      (q.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(p, p + Offset(l * sx, 0), angolo);
      canvas.drawLine(p, p + Offset(0, l * sy), angolo);
    }
  }

  @override
  bool shouldRepaint(_Riquadro old) => old.r != r;
}
