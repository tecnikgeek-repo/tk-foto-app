// Home: vetrina prima/dopo animata, sfondi a tema da sfogliare, cosa sa fare l'app, formati e consigli.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../dati/composizione.dart';
import '../dati/modello.dart';
import '../dati/scontorno.dart';
import '../dati/stile.dart';
import '../dati/temi.dart';
import '../tema.dart';
import '../tk_pro.dart';
import 'editor.dart';

/// Quante foto si possono preparare insieme.
const fotoPerLotto = 30;

/// Frasi in più del benvenuto: cosa va in rete per lo scontorno.
const righeBenvenutoFoto = [
  'Lo scontorno si fa **sul telefono**: le tue foto non vengono caricate da nessuna parte.',
  'Su Android, dopo questa schermata, l\'app scarica una volta sola il **modello di scontorno IS-Net** (46 MB, '
      'licenza Apache 2.0); finché non c\'è, lavora ML Kit di Google, che Google Play scarica alla prima foto.',
];

/// Schede dati di Informazioni: scontorno, sfondi, stile ricordato.
Future<List<(String, String)>> righeInformazioniFoto() async {
  final modello = await modelloPronto();
  final stile = await Stile.carica();
  return [
    (
      'Scontorno',
      !Platform.isAndroid
          ? 'Apple Vision sul telefono'
          : modello != null
              ? 'IS-Net sul telefono'
              : 'ML Kit (IS-Net non ancora scaricato)'
    ),
    ('Sfondi a tema', '${sfondiATema.length} in ${categorie.length} categorie'),
    ('Ultimo stile', '${stile.sfondoScelto.nome} · ${stile.formato.nome}'),
    ('Foto per volta', 'fino a $fotoPerLotto'),
    ('Album in galleria', 'tk-foto'),
  ];
}

/// Gli esempi della vetrina della home, in `assets/demo/`: foto «com'è scattata» (`NOME-prima.jpg`), ritaglio
/// fatto con lo stesso modello dell'app (`NOME-dopo.png`) e il contesto adatto all'oggetto (`NOME-contesto.jpg`:
/// showroom per l'auto, cameretta per il peluche…). Generate con Canva, design «tk-foto sfondi a tema 2».
const _esempiVetrina = ['flacone', 'peluche', 'borsa', 'auto', 'scarpa', 'orologio', 'cuffie'];

/// Cosa mostra ogni esempio: il prodotto e la scena in cui finisce.
const _etichetteVetrina = {
  'flacone': 'Profumo · Bagno di marmo',
  'peluche': 'Peluche · Cameretta',
  'borsa': 'Borsa · Boutique',
  'auto': 'Auto · Showroom',
  'scarpa': 'Scarpa · Pista',
  'orologio': 'Orologio · Studio',
  'cuffie': 'Cuffie · Scrivania',
};

class SchermataHome extends StatefulWidget {
  const SchermataHome({super.key});

  @override
  State<SchermataHome> createState() => _SchermataHomeState();
}

class _SchermataHomeState extends State<SchermataHome> {
  final _scegli = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // primo avvio: benvenuto (software libero, privacy, statistiche) PRIMA di qualunque chiamata in rete
      if (mounted) await benvenutoTk(context, righeExtra: righeBenvenutoFoto);
      // il modello di scontorno buono si scarica in silenzio la prima volta (dati/modello.dart)
      preparaModello();
      // controllo discreto: parla solo se c'è una versione nuova
      if (mounted) proponiAggiornamento(context, avvisaSeAggiornata: false);
      // invito al caffè: al primo avvio e poi al massimo una volta al mese, mai sopra un'altra finestra
      if (mounted) invitoCaffe(context);
    });
  }

  /// [sfondo]: se si parte da una categoria, le foto si aprono già con quello sfondo.
  Future<void> _apri(List<String> percorsi, {String? sfondo}) async {
    final stile = sfondo == null ? null : (await Stile.carica()).copia(sfondo: sfondo);
    if (mounted) await vai<void>(context, SchermataEditor(percorsi: percorsi, stileIniziale: stile));
  }

  Future<void> _scatta({String? sfondo}) async {
    try {
      final f = await _scegli.pickImage(source: ImageSource.camera);
      if (f != null && mounted) await _apri([f.path], sfondo: sfondo);
    } catch (e) {
      if (mounted) avviso(context, 'Fotocamera non disponibile: $e');
    }
  }

  Future<void> _galleria({String? sfondo}) async {
    try {
      final scelte = await _scegli.pickMultiImage(limit: fotoPerLotto);
      if (scelte.isEmpty || !mounted) return;
      if (scelte.length > fotoPerLotto) avviso(context, 'Ne preparo $fotoPerLotto alla volta: le altre al prossimo giro');
      await _apri([for (final f in scelte.take(fotoPerLotto)) f.path], sfondo: sfondo);
    } catch (e) {
      if (mounted) avviso(context, 'Galleria non disponibile: $e');
    }
  }

  /// Toccata una categoria: si sceglie da dove prendere le foto e si parte già col suo sfondo.
  Future<void> _daCategoria(Categoria c) async {
    final da = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: navy,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (f) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Foto per ${c.nome}', style: const TextStyle(color: bianco, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Le apro già con lo sfondo a tema, poi lo cambi come vuoi',
                textAlign: TextAlign.center, style: TextStyle(color: grigio400, fontSize: 13.5)),
            const SizedBox(height: 20),
            BottoneLuce(
                testo: 'Scatta una foto',
                icona: Icons.photo_camera_rounded,
                onTap: () => Navigator.pop(f, ImageSource.camera)),
            const SizedBox(height: 12),
            BottoneVetro(
                testo: 'Scegli dalla galleria',
                icona: Icons.photo_library_rounded,
                onTap: () => Navigator.pop(f, ImageSource.gallery)),
          ]),
        ),
      ),
    );
    final sfondo = c.sfondi.firstOrNull?.id;
    if (da == ImageSource.camera) await _scatta(sfondo: sfondo);
    if (da == ImageSource.gallery) await _galleria(sfondo: sfondo);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: notte,
        body: SfondoStudio(
          child: Column(children: [
            Testata(
              sottotitolo: 'Foto prodotto pronte in un tocco',
              azioni: [AzioneTk(Icons.info, 'Informazioni', () => apriInformazioni(context,
                      righe: righeInformazioniFoto,
                      notaDati: 'Foto, ritagli e modello restano su questo telefono: niente viene caricato in rete.'))],
            ),
            Expanded(
              // la prima schermata è alta quanto il telefono: la vetrina prende lo spazio che resta, titolo e
              // pulsanti si vedono sempre interi; il resto si raggiunge scorrendo
              child: LayoutBuilder(
                builder: (_, spazio) => ListView(
                padding: EdgeInsets.only(bottom: 30 + MediaQuery.of(context).padding.bottom),
                children: [
                  SizedBox(
                    height: spazio.maxHeight,
                    child: Padding(
                      // sotto c'è la barra di sistema di Android (l'app ci disegna sotto): i pulsanti stanno sopra
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 18 + MediaQuery.of(context).padding.bottom),
                      child: Column(children: [
                        const Expanded(child: Center(child: _Vetrina())),
                        const SizedBox(height: 20),
                        // il titolo, con l'ultima parte che si accende
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Foto da vetrina',
                                style: TextStyle(
                                    color: bianco, fontSize: 30, height: 1.08, fontWeight: FontWeight.w800)),
                            TestoLuce('in un tocco.',
                                stile: TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w800)),
                            SizedBox(height: 8),
                            Text('Lo sfondo sparisce da solo, il prodotto finisce nella scena giusta.',
                                style: TextStyle(
                                    color: grigio400, fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                        const SizedBox(height: 18),
                        BottoneLuce(testo: 'Scatta una foto', icona: Icons.photo_camera_rounded, onTap: _scatta),
                        const SizedBox(height: 12),
                        BottoneVetro(
                            testo: 'Scegli dalla galleria', icona: Icons.photo_library_rounded, onTap: _galleria),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _Pregi(),
                  const SizedBox(height: 34),
                  const _Titolo('Sfondi a tema', 'Tocca una festa e parti già col suo sfondo'),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 224,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: categorie.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _CartaCategoria(categorie[i], onTap: () => _daCategoria(categorie[i])),
                    ),
                  ),
                  const SizedBox(height: 34),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _Consigli()),
                ],
                ),
              ),
            ),
          ]),
        ),
      );
}

/// Tre pillole di vetro con quello che conta: niente internet, tanti sfondi, tante foto insieme.
class _Pregi extends StatelessWidget {
  const _Pregi();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          _Pregio(Icons.wifi_off_rounded, 'Senza internet'),
          _Pregio(Icons.auto_awesome_rounded, '110 sfondi'),
          _Pregio(Icons.burst_mode_rounded, '30 foto insieme'),
        ]),
      );
}

class _Pregio extends StatelessWidget {
  const _Pregio(this.icona, this.testo);

  final IconData icona;
  final String testo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: vetro,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: filoVetro),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icona, color: luce1, size: 16),
          const SizedBox(width: 6),
          Text(testo, style: const TextStyle(color: grigio200, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

// ───────────────────────── vetrina prima/dopo ─────────────────────────

/// Un esempio della vetrina pronto da disegnare.
class _Esempio {
  _Esempio(this.prima, this.soggetto, this.area, this.fondo);

  final ui.Image prima, soggetto, fondo;
  final Rect area;

  void libera() {
    prima.dispose();
    soggetto.dispose();
    fondo.dispose();
  }
}

Future<_Esempio?> _caricaEsempio(int i) async {
  try {
    final nome = _esempiVetrina[i % _esempiVetrina.length];
    final prima = await caricaAsset('assets/demo/$nome-prima.jpg');
    final soggetto = await caricaAsset('assets/demo/$nome-dopo.png');
    final rgba = (await soggetto.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    final area = await calcolaAreaPiena(rgba, soggetto.width, soggetto.height);
    final fondo = await caricaAsset('assets/demo/$nome-contesto.jpg');
    if (area == null) return null;
    return _Esempio(prima, soggetto, area, fondo);
  } catch (_) {
    return null;
  }
}

/// Foto di prova «com'è scattata» che una tendina trasforma in foto da vetrina; a ogni passaggio cambia
/// esempio (flacone, peluche, borsa, auto…). Il prodotto resta fermo: cambia solo quello che ha attorno.
/// Sotto, i due pulsanti per cominciare.
class _Vetrina extends StatefulWidget {
  const _Vetrina();

  @override
  State<_Vetrina> createState() => _VetrinaState();
}

class _VetrinaState extends State<_Vetrina> with SingleTickerProviderStateMixin {
  late final _tendina = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
    ..addStatusListener(_giro)
    ..forward();
  /// In memoria solo l'esempio che si vede e il prossimo, già caricato per il cambio.
  _Esempio? _ora, _prossimo;
  var _quale = 0;

  @override
  void initState() {
    super.initState();
    _caricaEsempio(0).then((e) {
      if (!mounted) return e?.libera();
      setState(() => _ora = e);
      _preparaProssimo();
    });
  }

  void _preparaProssimo() {
    _caricaEsempio(_quale + 1).then((e) {
      if (!mounted) return e?.libera();
      _prossimo?.libera();
      _prossimo = e;
    });
  }

  /// A ogni andata e ritorno della tendina passa all'esempio dopo (se è già pronto).
  void _giro(AnimationStatus s) {
    if (!mounted) return;
    if (s == AnimationStatus.completed) {
      _tendina.reverse();
    } else if (s == AnimationStatus.dismissed) {
      final p = _prossimo;
      if (p != null) {
        final vecchio = _ora;
        setState(() {
          _ora = p;
          _prossimo = null;
          _quale = (_quale + 1) % _esempiVetrina.length;
        });
        // l'immagine vecchia si libera dopo il prossimo disegno, quando nessuno la usa più
        WidgetsBinding.instance.addPostFrameCallback((_) => vecchio?.libera());
        _preparaProssimo();
      }
      _tendina.forward();
    }
  }

  @override
  void dispose() {
    _tendina.dispose();
    _ora?.libera();
    _prossimo?.libera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        // bordo di luce attorno alla scena e alone sotto
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [luce1, Color(0x3322D3EE), luceViola], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: luce1.withValues(alpha: .22), blurRadius: 40, offset: const Offset(0, 14))],
        ),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(30.5),
            child: AspectRatio(
              aspectRatio: 4 / 4.6,
              child: _ora == null
                  ? Container(
                      decoration: const BoxDecoration(gradient: LinearGradient(colors: [accento, accentoScuro])),
                      alignment: Alignment.center,
                      child: const Icon(Icons.content_cut_rounded, color: bianco, size: 64),
                    )
                  : AnimatedBuilder(
                      animation: _tendina,
                      builder: (_, _) {
                        final x = Curves.easeInOutCubic.transform(_tendina.value);
                        return Stack(fit: StackFit.expand, children: [
                          CustomPaint(painter: _PittoreVetrina(_ora!, x)),
                          // velo scuro in basso, perché la didascalia si legga su ogni foto
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00070B14), Color(0x00070B14), Color(0xB3070B14)],
                                stops: [0, .62, 1],
                              ),
                            ),
                          ),
                          // la foto originale sta a sinistra della tendina, quella pronta a destra
                          Positioned(left: 14, top: 14, child: _Etichetta('PRIMA', visibile: x > .2)),
                          Positioned(right: 14, top: 14, child: _Etichetta('DOPO', visibile: x < .8, accesa: true)),
                          Positioned(
                            left: 16,
                            bottom: 16,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: Text(_etichetteVetrina[_esempiVetrina[_quale]] ?? '',
                                  key: ValueKey(_quale),
                                  style: const TextStyle(
                                      color: bianco, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: .2)),
                            ),
                          ),
                          // maniglia della tendina
                          LayoutBuilder(
                            builder: (_, m) => Stack(children: [
                              Positioned(
                                left: m.maxWidth * x - 1.5,
                                top: 0,
                                bottom: 0,
                                child: Container(width: 3, color: bianco),
                              ),
                              Positioned(
                                left: m.maxWidth * x - 20,
                                top: m.maxHeight / 2 - 20,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: bianco,
                                    shape: BoxShape.circle,
                                    boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 10)],
                                  ),
                                  child: const Icon(Icons.auto_awesome_rounded, color: accento, size: 22),
                                ),
                              ),
                            ]),
                          ),
                        ]);
                      },
                    ),
            ),
        ),
      );
}

class _PittoreVetrina extends CustomPainter {
  _PittoreVetrina(this.esempio, this.x);

  final _Esempio esempio;
  final double x;

  @override
  void paint(Canvas canvas, Size size) {
    final tutto = Offset.zero & size;
    // dove sta il prodotto nella foto «prima» (disegnata a coprire la vetrina): lì resta anche nel «dopo»
    final p = esempio.prima, s = esempio.soggetto;
    final scala = max(size.width / p.width, size.height / p.height);
    final angolo = Offset((size.width - p.width * scala) / 2, (size.height - p.height * scala) / 2);
    final a = esempio.area;
    final kx = p.width / s.width * scala, ky = p.height / s.height * scala;
    final voluto = Rect.fromLTRB(
        angolo.dx + a.left * kx, angolo.dy + a.top * ky, angolo.dx + a.right * kx, angolo.dy + a.bottom * ky);
    const stile = Stile(ombra: Ombra.aTerra, formato: Formato.quadrato, margine: .17);
    // dopo: il prodotto nel suo contesto, con l'ombra a terra
    disegnaFoto(canvas, size, s, a, stile,
        fondo: esempio.fondo, regolazione: regolazioneVerso(size, a, stile, voluto));
    // prima: la foto com'è stata scattata, a sinistra della tendina
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width * x, size.height));
    disegnaACoprire(canvas, esempio.prima, tutto);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PittoreVetrina old) => old.x != x || old.esempio != esempio;
}

class _Etichetta extends StatelessWidget {
  const _Etichetta(this.testo, {required this.visibile, this.accesa = false});

  final String testo;
  final bool visibile, accesa;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: visibile ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: accesa ? accento : navy.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(testo,
              style: const TextStyle(color: bianco, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ),
      );
}

// ───────────────────────── sezioni ─────────────────────────

class _Titolo extends StatelessWidget {
  const _Titolo(this.titolo, this.sotto);

  final String titolo, sotto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titolo, style: const TextStyle(color: bianco, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(sotto, style: const TextStyle(color: grigio400, fontSize: 13.5, fontWeight: FontWeight.w500)),
        ]),
      );
}

/// Carta di una categoria: la foto del primo sfondo, il nome e quanti sfondi ha.
class _CartaCategoria extends StatelessWidget {
  const _CartaCategoria(this.categoria, {required this.onTap});

  final Categoria categoria;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sfondi = categoria.sfondi;
    return Premibile(
      onTap: onTap,
      child: Container(
        width: 156,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: filoVetro),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Stack(fit: StackFit.expand, children: [
            if (sfondi.isNotEmpty) Image.asset(sfondi.first.asset!, cacheWidth: 320, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x10000000), Color(0xCC0F172A)],
                  stops: [0, .45, 1],
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: bianco.withValues(alpha: .92), shape: BoxShape.circle),
                child: Icon(categoria.icona, color: accentoScuro, size: 19),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(categoria.nome,
                    maxLines: 2,
                    style: const TextStyle(color: bianco, fontSize: 16, height: 1.1, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('${sfondi.length} sfondi',
                    style: const TextStyle(color: grigio200, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Consigli extends StatelessWidget {
  const _Consigli();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: vetro,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: filoVetro),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.tips_and_updates_rounded, color: luce1, size: 22),
            SizedBox(width: 8),
            Text('Per un ritaglio perfetto', style: TextStyle(color: bianco, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          SizedBox(height: 10),
          _Consiglio('Appoggia il prodotto su un fondo uniforme, diverso dal suo colore.'),
          _Consiglio('Luce morbida e di fronte: niente controluce.'),
          _Consiglio('Inquadralo intero, senza tagliarlo ai bordi della foto.'),
        ]),
      );
}

class _Consiglio extends StatelessWidget {
  const _Consiglio(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_rounded, color: luce1, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(testo, style: const TextStyle(color: grigio300, fontSize: 13.5, height: 1.35))),
        ]),
      );
}

/// Rettangolino con le proporzioni del formato («Originale» = sagoma tratteggiata).
class SagomaFormato extends StatelessWidget {
  const SagomaFormato(this.formato, {super.key, this.lato = 20, this.colore = navy});

  final Formato formato;
  final double lato;
  final Color colore;

  @override
  Widget build(BuildContext context) {
    final r = formato.rapporto == 0 ? .8 : formato.rapporto;
    final w = r >= 1 ? lato : lato * r, h = r >= 1 ? lato / r : lato;
    return SizedBox(
      width: lato,
      height: lato,
      child: Center(
        child: formato.rapporto == 0
            ? Icon(Icons.crop_free_rounded, size: lato, color: colore)
            : Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                    border: Border.all(color: colore, width: 2), borderRadius: BorderRadius.circular(3)),
              ),
      ),
    );
  }
}
