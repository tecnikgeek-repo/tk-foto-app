// Colori e pezzi propri di tk-foto; testata, card, dialoghi, Informazioni e splash sono nel kit comune.
// tk-foto usa il fondo scuro del kit (come tk-tv): uno «studio» dove la foto è l'unica cosa luminosa,
// con aloni di luce, vetro, pulsanti che si accendono e si abbassano al tocco.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kit_tk.dart';

export 'kit_tk.dart';

const accento = Color(0xFF0D9488);
const accentoScuro = Color(0xFF0F766E);
const accentoChiaro = Color(0xFFCCFBF1);

/// Luce dello studio: verde acqua che sfuma nel ciano, e un viola per il secondo alone.
const luce1 = Color(0xFF14B8A6), luce2 = Color(0xFF22D3EE), luceViola = Color(0xFF8B5CF6);
const gradienteLuce = LinearGradient(colors: [luce1, luce2], begin: Alignment.centerLeft, end: Alignment.centerRight);

/// Fondo dello studio (più scuro del navy del kit) e vetro: velo bianco sottile con un filo di bordo.
const notte = Color(0xFF070B14);
const vetro = Color(0x14FFFFFF), filoVetro = Color(0x24FFFFFF);

/// Carattere delle scritte messe sulla foto (Plus Jakarta Sans, in assets/font).
/// L'interfaccia usa quello di tutte le app TK (Roboto), come le altre.
const carattereScritte = 'Jakarta';

/// Una leggera vibrazione a ogni scelta.
void tocco() => HapticFeedback.selectionClick();

/// Il fondo dello studio: notte con due aloni di luce sfumati (verde acqua in alto, viola in basso).
class SfondoStudio extends StatelessWidget {
  const SfondoStudio({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(color: notte),
        child: Stack(children: [
          Positioned(
            left: -160,
            top: -120,
            child: _Alone(colore: luce1.withValues(alpha: .26), lato: 460),
          ),
          Positioned(
            right: -180,
            bottom: 60,
            child: _Alone(colore: luceViola.withValues(alpha: .20), lato: 480),
          ),
          Positioned.fill(child: child),
        ]),
      );
}

class _Alone extends StatelessWidget {
  const _Alone({required this.colore, required this.lato});

  final Color colore;
  final double lato;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: lato,
          height: lato,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [colore, colore.withValues(alpha: 0)]),
          ),
        ),
      );
}

/// Si abbassa un poco quando lo si preme (con una vibrazione leggera), come un pulsante vero.
class Premibile extends StatefulWidget {
  const Premibile({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Premibile> createState() => _PremibileState();
}

class _PremibileState extends State<Premibile> {
  var _giu = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _giu = true),
        onTapCancel: () => setState(() => _giu = false),
        onTapUp: (_) => setState(() => _giu = false),
        onTap: widget.onTap == null
            ? null
            : () {
                tocco();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _giu ? .96 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Il pulsante principale: gradiente di luce con l'alone sotto.
class BottoneLuce extends StatelessWidget {
  const BottoneLuce({super.key, required this.testo, required this.onTap, this.icona, this.alto = 58});

  final String testo;
  final IconData? icona;
  final VoidCallback? onTap;
  final double alto;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .45 : 1,
        child: Premibile(
          onTap: onTap,
          child: Container(
            height: alto,
            decoration: BoxDecoration(
              gradient: gradienteLuce,
              borderRadius: BorderRadius.circular(alto / 2),
              boxShadow: [BoxShadow(color: luce1.withValues(alpha: .45), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icona != null) ...[Icon(icona, color: notte, size: 22), const SizedBox(width: 10)],
              Flexible(
                child: Text(testo,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: notte, fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: .2)),
              ),
            ]),
          ),
        ),
      );
}

/// Pulsante di vetro: velo chiaro sottile, filo di bordo, testo bianco.
class BottoneVetro extends StatelessWidget {
  const BottoneVetro({super.key, required this.testo, required this.onTap, this.icona, this.alto = 54});

  final String testo;
  final IconData? icona;
  final VoidCallback? onTap;
  final double alto;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .45 : 1,
        child: Premibile(
          onTap: onTap,
          child: Container(
            height: alto,
            decoration: BoxDecoration(
              color: vetro,
              borderRadius: BorderRadius.circular(alto / 2),
              border: Border.all(color: filoVetro),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icona != null) ...[Icon(icona, color: bianco, size: 20), const SizedBox(width: 10)],
              Flexible(
                child: Text(testo,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: bianco, fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );
}

/// Pannello di vetro (sfoca quello che c'è dietro).
class Vetro extends StatelessWidget {
  const Vetro({super.key, required this.child, this.raggio = 22, this.padding = EdgeInsets.zero});

  final Widget child;
  final double raggio;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(raggio),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: const Color(0x260F172A),
              borderRadius: BorderRadius.circular(raggio),
              border: Border.all(color: filoVetro),
            ),
            child: child,
          ),
        ),
      );
}

/// Testo col gradiente di luce.
class TestoLuce extends StatelessWidget {
  const TestoLuce(this.testo, {super.key, required this.stile});

  final String testo;
  final TextStyle stile;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => gradienteLuce.createShader(r),
        child: Text(testo, style: stile),
      );
}

/// Festeggia una cosa riuscita (foto salvate): spunta luminosa che compare e sparisce da sola.
Future<void> festeggia(BuildContext context, String testo) async {
  HapticFeedback.mediumImpact();
  final voce = OverlayEntry(builder: (_) => _Festa(testo));
  Overlay.of(context).insert(voce);
  await Future<void>.delayed(const Duration(milliseconds: 1700));
  voce.remove();
}

class _Festa extends StatelessWidget {
  const _Festa(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1700),
            builder: (_, t, _) {
              // entra in fretta con un rimbalzo, resta, poi svanisce
              final dentro = Curves.easeOutBack.transform((t / .25).clamp(0.0, 1.0));
              final fuori = 1 - Curves.easeIn.transform(((t - .8) / .2).clamp(0.0, 1.0));
              return Opacity(
                opacity: fuori,
                child: Container(
                  color: notte.withValues(alpha: .45 * fuori),
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: .6 + .4 * dentro,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: gradienteLuce,
                          boxShadow: [BoxShadow(color: luce1.withValues(alpha: .6), blurRadius: 40)],
                        ),
                        child: const Icon(Icons.check_rounded, color: notte, size: 58),
                      ),
                      const SizedBox(height: 18),
                      Text(testo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: bianco, fontSize: 18, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      );
}

/// Simbolo di tk-foto: le forbici del ritaglio.
Widget simboloFoto(double lato) => Icon(Icons.content_cut_rounded, color: bianco, size: lato * .54);

const configFoto = ConfigTk(
  nome: 'tk-foto',
  motto: 'Foto prodotto in un tocco',
  descrizione: 'Scontorno e foto prodotto',
  accento: accento,
  accentoScuro: accentoScuro,
  simbolo: simboloFoto,
  manifestUrl: manifestFoto,
  scuro: true,
  eccezioneLicenza: 'Google ML Kit Subject Segmentation, Google Play Services',
);

/// Il tema dell'app: quello scuro del kit (carattere e passaggi tra le schermate come in tutte le app TK),
/// col fondo dello studio un po' più scuro.
ThemeData temaFoto() => temaKit().copyWith(scaffoldBackgroundColor: notte);

/// Manifesto degli aggiornamenti su Dropbox (`/foto-version.json`).
const manifestFoto =
    'https://dl.dropboxusercontent.com/scl/fi/elctuhzddrwsox4r6ck6r/foto-version.json?rlkey=aghgfrxmv8uwo5dlfe4kzd9d9';

Future<T?> vai<T>(BuildContext context, Widget schermata) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => schermata));

/// Titolo di una card con l'icona colorata.
class TitoloCard extends StatelessWidget {
  const TitoloCard(this.titolo, {super.key, this.icona, this.colore = accento});

  final String titolo;
  final IconData? icona;
  final Color colore;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          if (icona != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: colore.withValues(alpha: .13), borderRadius: BorderRadius.circular(10)),
              child: Icon(icona, color: colore, size: 18),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(titolo, style: const TextStyle(color: navy, fontSize: 15, fontWeight: FontWeight.w800))),
        ]),
      );
}

/// Scacchiera grigia che indica lo sfondo trasparente.
class Scacchiera extends CustomPainter {
  const Scacchiera({this.lato = 12});

  final double lato;

  @override
  void paint(Canvas canvas, Size size) {
    // l'ultima fila di quadretti non deve uscire dalla foto (si vedrebbe come una riga di trattini)
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = bianco);
    final p = Paint()..color = grigio200;
    for (var y = 0; y * lato < size.height; y++) {
      for (var x = (y % 2); x * lato < size.width; x += 2) {
        canvas.drawRect(Rect.fromLTWH(x * lato, y * lato, lato, lato), p);
      }
    }
  }

  @override
  bool shouldRepaint(Scacchiera old) => old.lato != lato;
}
