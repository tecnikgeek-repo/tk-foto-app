// Editor: scontorna le foto una dopo l'altra, mostra l'anteprima dal vivo e applica lo stesso stile
// (sfondo, ombra, formato, spazio) a tutto il lotto; salva in galleria o condivide.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../dati/composizione.dart';
import '../dati/esporta.dart';
import '../dati/scritte.dart';
import '../dati/scontorno.dart';
import '../dati/stile.dart';
import '../dati/temi.dart';
import '../tema.dart';
import 'home.dart';
import 'ritocco.dart';
import 'rivelazione.dart';
import 'taglio.dart';

enum _Scheda {
  sfondo('Sfondo', Icons.format_color_fill_rounded),
  ombra('Ombra', Icons.layers_rounded),
  formato('Formato', Icons.aspect_ratio_rounded),
  spazio('Spazio', Icons.open_in_full_rounded),
  testo('Testo', Icons.text_fields_rounded);

  const _Scheda(this.nome, this.icona);

  final String nome;
  final IconData icona;
}

class SchermataEditor extends StatefulWidget {
  const SchermataEditor({super.key, required this.percorsi, this.stileIniziale, this.scontornaDa});

  final List<String> percorsi;

  /// Per le anteprime di prova: stile da usare subito invece di quello salvato.
  final Stile? stileIniziale;

  /// Per le anteprime di prova: scontorno finto al posto di quello del telefono.
  final Future<void> Function(Foto)? scontornaDa;

  @override
  State<SchermataEditor> createState() => _SchermataEditorState();
}

class _SchermataEditorState extends State<SchermataEditor> {
  late final List<Foto> _foto = [for (final p in widget.percorsi) Foto(p)];
  late Stile _stile = widget.stileIniziale ?? const Stile();
  var _scelta = 0;
  var _scheda = _Scheda.sfondo;
  ui.Image? _immagine;
  String? _immaginePer;
  ui.Image? _fondo;
  String? _fondoPer;
  String? _stato;
  bool _lavora = false;

  /// Categoria aperta nella scheda Sfondo (null = tinte unite e sfumature).
  String? _categoria;

  /// Zoom e rotazione all'inizio del gesto con due dita.
  double _zoomIniziale = 1, _rotazioneIniziale = 0;

  /// La scritta scelta (riquadro tratteggiato, si cambia dalla scheda Testo) e quella che si sta trascinando.
  Scritta? _scritta, _trascinata;

  /// La scritta sotto il dito in [p] (coordinate della foto a schermo, grande [misura]), la più in alto.
  Scritta? _scrittaIn(Foto f, Offset p, Size misura) {
    for (final s in f.scritte.reversed) {
      if (ingombroScritta(s, misura).inflate(14).contains(p)) return s;
    }
    return null;
  }

  Future<void> _aggiungiScritta(TipoScritta tipo) async {
    final f = _attuale;
    final testo = await chiediTesto(context, tipo.nome, iniziale: tipo.esempio, ok: 'Aggiungi');
    if (testo == null || testo.trim().isEmpty || !mounted) return;
    final s = Scritta(tipo, testo.trim());
    setState(() {
      f.scritte.add(s);
      _scritta = s;
    });
  }

  Future<void> _modificaScritta(Scritta s) async {
    final testo = await chiediTesto(context, s.tipo.nome, iniziale: s.testo);
    if (testo == null || testo.trim().isEmpty || !mounted) return;
    setState(() => s.testo = testo.trim());
  }

  /// Cambia quando cambia una scritta qualsiasi (le scritte si modificano sul posto: serve per ridisegnare).
  int _versioneScritte(Foto f) =>
      Object.hashAll([for (final s in f.scritte) Object.hash(s.testo, s.centro, s.grandezza, s.colore)]);

  void _cambiaScritta(void Function(Scritta s) cambia) {
    final s = _scritta;
    if (s == null) return;
    tocco();
    setState(() => cambia(s));
  }

  Foto get _attuale => _foto[_scelta];

  @override
  void initState() {
    super.initState();
    if (widget.stileIniziale == null) {
      // ombra, formato e spazio come l'ultima volta, ma si parte dal prodotto senza sfondo: il tema lo sceglie
      // l'utente dopo aver visto il ritaglio
      Stile.carica().then((s) {
        if (mounted) _cambiaStile(s.copia(sfondo: 'trasparente'), salva: false);
      });
    } else {
      _cambiaStile(_stile, salva: false);
    }
    _scontornaTutte();
  }

  @override
  void dispose() {
    _immagine?.dispose();
    _fondo?.dispose();
    super.dispose();
  }

  /// Carica la foto dello sfondo a tema scelto (una sola in memoria).
  Future<void> _caricaFondo() async {
    final asset = _stile.sfondoScelto.asset;
    if (asset == _fondoPer) return;
    _fondoPer = asset;
    final im = asset == null ? null : await caricaAsset(asset);
    if (!mounted || _fondoPer != asset) {
      im?.dispose();
      return;
    }
    setState(() {
      _fondo?.dispose();
      _fondo = im;
    });
  }

  Future<void> _scontornaTutte() async {
    if (_lavora) return;
    _lavora = true;
    while (mounted) {
      final prossima = _foto.where((f) => !f.pronta && f.errore == null && !f.inCorso).firstOrNull;
      if (prossima == null) break;
      setState(() => prossima.inCorso = true);
      if (widget.scontornaDa != null) {
        await widget.scontornaDa!(prossima);
      } else {
        await scontorna(prossima, stato: (s) {
          if (mounted) setState(() => _stato = s);
        });
      }
      if (!mounted) return;
      setState(() => _stato = null);
      await _caricaScelta();
    }
    _lavora = false;
  }

  /// Quanto è ridotta la copia leggera del ritaglio a schermo rispetto al file vero.
  double _scalaVista = 1;

  /// La parte piena del ritaglio nella copia leggera a schermo.
  Rect _areaVista(Foto f) {
    final a = f.area!, s = _scalaVista;
    return Rect.fromLTRB(a.left * s, a.top * s, a.right * s, a.bottom * s);
  }

  /// Carica in memoria solo il ritaglio della foto scelta (con 30 foto tutte insieme sarebbero troppe), in una
  /// copia leggera: a schermo basta, e ridisegnarla mentre si muove il prodotto non fa scatti. Il file salvato
  /// si fa dal ritaglio vero.
  Future<void> _caricaScelta() async {
    final f = _attuale;
    if (!f.pronta || _immaginePer == f.ritaglio) return;
    final (im, scala) = await caricaRidotta(f.ritaglio!);
    if (!mounted || _attuale != f) {
      im.dispose();
      return;
    }
    setState(() {
      _immagine?.dispose();
      _immagine = im;
      _scalaVista = scala;
      _immaginePer = f.ritaglio;
    });
  }

  void _cambiaStile(Stile s, {bool salva = true}) {
    setState(() {
      _stile = s;
      // la scheda Sfondo si apre sulla categoria dello sfondo scelto
      if (!salva) _categoria = categorie.where((c) => s.sfondo.startsWith('${c.id}-')).firstOrNull?.id;
    });
    if (salva) s.salva();
    _caricaFondo();
  }

  void _regola(Regolazione r) => setState(() => _attuale.regolazione = r);

  void _scegli(int i) {
    setState(() => _scelta = i);
    _caricaScelta();
  }

  Future<void> _aggiungi() async {
    final libere = fotoPerLotto - _foto.length;
    if (libere <= 0) return avviso(context, 'Ne preparo $fotoPerLotto alla volta');
    final scelte = await ImagePicker().pickMultiImage(limit: libere);
    if (scelte.isEmpty || !mounted) return;
    setState(() => _foto.addAll([for (final f in scelte.take(libere)) Foto(f.path)]));
    _scontornaTutte();
  }

  Future<void> _togli(int i) async {
    if (_foto.length == 1) return;
    if (!await conferma(context, 'Togliere questa foto?', 'Non verrà salvata con le altre.', si: 'Togli')) return;
    setState(() {
      _foto.removeAt(i);
      if (_scelta >= _foto.length) _scelta = _foto.length - 1;
    });
    _caricaScelta();
  }

  void _riprova(Foto f) {
    setState(() => f.errore = null);
    _scontornaTutte();
  }

  /// Crea i file con lo stile scelto mostrando l'avanzamento; null se qualcosa va storto.
  Future<List<String>?> _prepara() async {
    final pronte = _foto.where((f) => f.pronta).length;
    if (pronte == 0) {
      avviso(context, 'Aspetta che lo scontorno sia finito');
      return null;
    }
    final fatte = ValueNotifier<int>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(pronte == 1 ? 'Preparo la foto' : 'Preparo $pronte foto'),
        content: ValueListenableBuilder<int>(
          valueListenable: fatte,
          builder: (_, n, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: pronte == 1 ? null : n / pronte),
            const SizedBox(height: 10),
            Text(pronte == 1 ? 'Un attimo…' : '$n di $pronte'),
          ]),
        ),
      ),
    );
    try {
      return await preparaFile(_foto, _stile, avanzamento: (n) => fatte.value = n);
    } catch (e) {
      if (mounted) avviso(context, 'Non riesco a preparare le foto: $e');
      return null;
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _salva() async {
    final file = await _prepara();
    if (file == null || !mounted) return;
    try {
      await salvaInGalleria(file);
      if (mounted) {
        festeggia(context, file.length == 1 ? 'Salvata in galleria' : '${file.length} foto salvate in galleria');
      }
    } catch (e) {
      if (mounted) avviso(context, 'Salvataggio non riuscito: $e');
    }
  }

  Future<void> _condividi() async {
    final file = await _prepara();
    if (file == null || !mounted) return;
    try {
      await condividi(file);
    } catch (e) {
      if (mounted) avviso(context, 'Condivisione non riuscita: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pronte = _foto.where((f) => f.pronta).length;
    return Scaffold(
      backgroundColor: notte,
      body: SfondoStudio(
        child: Column(children: [
          TestataSemplice(
            titolo: _foto.length == 1 ? 'La tua foto' : '${_foto.length} foto',
            indietro: () => Navigator.of(context).pop(),
            azioni: [
              AzioneTk(Icons.add_photo_alternate_rounded, 'Aggiungi foto', _aggiungi),
              AzioneTk(Icons.ios_share_rounded, 'Condividi', pronte == 0 ? null : _condividi),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Center(
                child: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: _anteprima()),
              ),
            ),
          ),
          if (_foto.length > 1) _striscia(),
          _Pannello(
            scheda: _scheda,
            stile: _stile,
            onScheda: (s) {
              tocco();
              setState(() => _scheda = s);
            },
            onStile: (s) {
              tocco();
              _cambiaStile(s);
            },
            categoria: _categoria,
            onCategoria: (c) {
              tocco();
              setState(() => _categoria = c);
            },
            pronte: pronte,
            totale: _foto.length,
            onSalva: _salva,
            scritta: _attuale.scritte.contains(_scritta) ? _scritta : null,
            onAggiungiScritta: (t) {
              tocco();
              _aggiungiScritta(t);
            },
            onCambiaScritta: _cambiaScritta,
            onModificaScritta: () {
              if (_scritta != null) _modificaScritta(_scritta!);
            },
            onTogliScritta: () {
              tocco();
              setState(() {
                _attuale.scritte.remove(_scritta);
                _scritta = null;
              });
            },
          ),
        ]),
      ),
    );
  }

  /// Le foto che hanno già fatto vedere il loro momento del risultato (si fa una volta sola per foto).
  final _rivelate = <Foto>{};

  /// Il riquadro grande della foto mentre si lavora (scanner) e nel momento del risultato.
  Widget _riquadroGrande(Widget dentro, String didascalia, {Key? key}) => LayoutBuilder(
        key: key,
        builder: (_, m) => Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: filoVetro),
              boxShadow: [BoxShadow(color: luce1.withValues(alpha: .18), blurRadius: 34, offset: const Offset(0, 10))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: SizedBox(width: m.maxWidth, height: max(120.0, m.maxHeight - 46), child: dentro),
            ),
          ),
          const SizedBox(height: 14),
          Text(didascalia,
              textAlign: TextAlign.center,
              style: const TextStyle(color: grigio300, fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: .2)),
        ]),
      );

  Widget _anteprima() {
    final f = _attuale;
    if (f.errore != null) {
      return CardTk(
        key: const ValueKey('errore'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: rosso, size: 40),
          const SizedBox(height: 10),
          Text(f.errore!, textAlign: TextAlign.center, style: const TextStyle(color: bianco, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          SizedBox(width: 180, child: BottoneLuce(testo: 'Riprova', icona: Icons.refresh_rounded, alto: 48, onTap: () => _riprova(f))),
        ]),
      );
    }
    final im = _immagine;
    if (!f.pronta || im == null || _immaginePer != f.ritaglio) {
      // mentre si scontorna: la foto grande quanto lo spazio, con l'effetto scanner
      return _riquadroGrande(
        key: ValueKey('lavoro-${f.originale}'),
        Stack(fit: StackFit.expand, children: [
          Image.file(File(f.originale), cacheWidth: 1000, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: navy2)),
          const _Scanner(),
        ]),
        _stato ?? 'Tolgo lo sfondo…',
      );
    }
    // appena finito: il momento del risultato (con lo scontorno vero; nei test lo scontorno è finto)
    if (!_rivelate.contains(f) && f.diritta != null && widget.scontornaDa == null) {
      return _riquadroGrande(
        key: ValueKey('rivela-${f.originale}'),
        Rivelazione(foto: f.diritta!, ritaglio: im, onFine: () => setState(() => _rivelate.add(f))),
        'Ecco il tuo prodotto',
      );
    }
    final tela = misuraTela(f.area!, _stile);
    final aTema = _stile.sfondoScelto.asset != null;
    final r = f.regolazione;
    final t = f.taglio;
    return Column(key: ValueKey('pronta-${f.originale}'), mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: AspectRatio(
          aspectRatio: tela.width / tela.height,
          child: LayoutBuilder(
            builder: (_, misure) => GestureDetector(
              // pinch-to-zoom: due dita ingrandiscono e girano, un dito sposta, doppio tocco rimette tutto a posto;
              // un dito su una scritta sposta la scritta
              onTapUp: (d) {
                final s = _scrittaIn(f, d.localPosition, misure.biggest);
                if (s != null && identical(s, _scritta)) {
                  _modificaScritta(s);
                } else {
                  setState(() {
                    _scritta = s;
                    if (s != null) _scheda = _Scheda.testo;
                  });
                }
              },
              onScaleStart: (d) {
                _zoomIniziale = f.regolazione.zoom;
                _rotazioneIniziale = f.regolazione.rotazione;
                _trascinata = d.pointerCount == 1 ? _scrittaIn(f, d.localFocalPoint, misure.biggest) : null;
                if (_trascinata != null) setState(() => _scritta = _trascinata);
              },
              onScaleEnd: (_) => _trascinata = null,
              onScaleUpdate: (d) {
                final trascinata = _trascinata;
                if (trascinata != null) {
                  final c = trascinata.centro +
                      Offset(d.focalPointDelta.dx / misure.maxWidth, d.focalPointDelta.dy / misure.maxHeight);
                  setState(() => trascinata.centro = Offset(c.dx.clamp(0, 1), c.dy.clamp(0, 1)));
                  return;
                }
                final z = (_zoomIniziale * d.scale).clamp(Regolazione.zoomMin, Regolazione.zoomMax);
                final s = f.regolazione.spostamento +
                    Offset(d.focalPointDelta.dx / misure.maxWidth, d.focalPointDelta.dy / misure.maxHeight);
                final giro = d.pointerCount > 1
                    ? Regolazione.aggancia(_rotazioneIniziale + d.rotation)
                    : f.regolazione.rotazione;
                _regola(Regolazione(
                    zoom: z, spostamento: Offset(s.dx.clamp(-.6, .6), s.dy.clamp(-.6, .6)), rotazione: giro));
              },
              onDoubleTap: () => _regola(Regolazione.nessuna),
              child: Container(
                // la foto finita sospesa nello studio: ombra profonda e un filo di luce
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    const BoxShadow(color: Color(0x99000000), blurRadius: 36, offset: Offset(0, 16)),
                    BoxShadow(color: luce1.withValues(alpha: .12), blurRadius: 30),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: aTema && _fondo == null
                      ? Container(
                          color: navy2,
                          alignment: Alignment.center,
                          child: const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)))
                      : CustomPaint(
                          painter: _stile.sfondoScelto.trasparente ? const Scacchiera() : null,
                          foregroundPainter: _Pittore(im, _areaVista(f), _stile, r, aTema ? _fondo : null, t,
                              scritte: List.of(f.scritte), scelta: _scritta, versione: _versioneScritte(f)),
                          child: const SizedBox.expand(),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      // gli strumenti in una barra di vetro sotto la foto (si rimpicciolisce solo se non ci sta)
      Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(color: vetro, borderRadius: BorderRadius.circular(23), border: Border.all(color: filoVetro)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (f.diritta != null) _Strumento(Icons.brush_rounded, 'Ritocca', () => _ritocca(f)),
            _Strumento(Icons.crop_rounded, t == tuttaLaFoto ? 'Taglia' : 'Tagliata', () => _taglia(f),
                chiave: const Key('taglia'), acceso: t != tuttaLaFoto),
            _Strumento(
                Icons.rotate_90_degrees_cw_rounded,
                'Gira',
                () => _regola(Regolazione(
                    zoom: r.zoom,
                    spostamento: r.spostamento,
                    rotazione: Regolazione.aggancia(r.rotazione + pi / 2, tolleranza: 45)))),
            if (r.modificata)
              _Strumento(Icons.center_focus_strong_rounded,
                  'Centra · ${(r.zoom * 100).round()}%${r.gradi != 0 ? ' · ${r.gradi}°' : ''}',
                  () => _regola(Regolazione.nessuna),
                  acceso: true),
          ]),
        ),
      ),
    ]);
  }

  /// Apre il taglio sulla sola foto del prodotto (il ritaglio, senza sfondo): lo sfondo resta intero.
  Future<void> _taglia(Foto f) async {
    final im = _immagine;
    if (im == null || f.area == null) return;
    final taglio = await vai<Rect>(
      context,
      SchermataTaglio(
        tela: f.area!.size,
        iniziale: f.taglio,
        foto: CustomPaint(
          painter: const Scacchiera(),
          foregroundPainter: _SoloProdotto(im, _areaVista(f)),
          child: const SizedBox.expand(),
        ),
      ),
    );
    if (taglio != null && mounted) setState(() => f.taglio = taglio);
  }

  Future<void> _ritocca(Foto f) async {
    final esito = await vai<RitaglioRitoccato>(context, SchermataRitocco(ritaglio: f.ritaglio!, diritta: f.diritta!));
    if (esito == null || !mounted) return;
    setState(() {
      f
        ..ritaglio = esito.$1
        ..area = esito.$2;
    });
    _caricaScelta();
  }

  Widget _striscia() => SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          itemCount: _foto.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f = _foto[i];
            final scelta = i == _scelta;
            return GestureDetector(
              onTap: () => _scegli(i),
              onLongPress: () => _togli(i),
              child: Container(
                width: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scelta ? luce1 : Colors.transparent, width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.file(File(f.ritaglio ?? f.originale),
                        cacheWidth: 160, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: grigio200)),
                    if (!f.pronta)
                      Container(
                        color: navy.withValues(alpha: .5),
                        alignment: Alignment.center,
                        child: f.errore != null
                            ? const Icon(Icons.error_rounded, color: bianco, size: 22)
                            : const SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(color: bianco, strokeWidth: 2.5)),
                      ),
                  ]),
                ),
              ),
            );
          },
        ),
      );
}

class _Pittore extends CustomPainter {
  _Pittore(this.immagine, this.area, this.stile, this.regolazione, this.fondo, this.taglio,
      {this.scritte = const [], this.scelta, this.versione = 0});

  final ui.Image immagine;
  final Rect area;
  final Stile stile;
  final Regolazione regolazione;
  final ui.Image? fondo;
  final Rect taglio;
  final List<Scritta> scritte;
  final Scritta? scelta;
  final int versione;

  @override
  void paint(Canvas canvas, Size size) {
    // regolazione, taglio e scritte sono in frazioni, quindi valgono uguali a schermo e nel file
    canvas.clipRect(Offset.zero & size);
    disegnaFoto(canvas, size, immagine, area, stile, regolazione: regolazione, fondo: fondo, taglio: taglio);
    disegnaScritte(canvas, size, scritte, scelta: scelta);
  }

  @override
  bool shouldRepaint(_Pittore old) =>
      old.immagine != immagine ||
      old.area != area ||
      old.stile != stile ||
      old.regolazione != regolazione ||
      old.fondo != fondo ||
      old.taglio != taglio ||
      old.scritte.length != scritte.length ||
      old.scelta != scelta ||
      old.versione != versione;
}

/// Effetto scanner mentre si toglie lo sfondo: una linea luminosa che scorre su e giù con la sua scia,
/// la foto appena velata e le squadrette di un mirino agli angoli.
class _Scanner extends StatefulWidget {
  const _Scanner();

  @override
  State<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<_Scanner> with SingleTickerProviderStateMixin {
  late final _giro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _giro,
        builder: (_, _) => CustomPaint(
          painter: _PittoreScanner(Curves.easeInOut.transform(_giro.value), _giro.status == AnimationStatus.forward),
        ),
      );
}

class _PittoreScanner extends CustomPainter {
  _PittoreScanner(this.t, this.scende);

  /// Dove sta la linea, da 0 (in alto) a 1 (in basso).
  final double t;

  /// La scia sta dietro la linea: sopra quando scende, sotto quando sale.
  final bool scende;

  @override
  void paint(Canvas canvas, Size size) {
    final tutto = Offset.zero & size;
    canvas.drawRect(tutto, Paint()..color = navy.withValues(alpha: .28));
    final y = t * size.height;
    final lungaScia = size.height * .22;
    final scia = scende ? Rect.fromLTRB(0, y - lungaScia, size.width, y) : Rect.fromLTRB(0, y, size.width, y + lungaScia);
    canvas.drawRect(
        scia,
        Paint()
          ..shader = LinearGradient(
            begin: scende ? Alignment.topCenter : Alignment.bottomCenter,
            end: scende ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [accento.withValues(alpha: 0), accento.withValues(alpha: .38)],
          ).createShader(scia));
    // la linea: un alone largo e sfocato, poi il filo chiaro
    canvas.drawRect(
        Rect.fromLTWH(0, y - 6, size.width, 12),
        Paint()
          ..color = accento.withValues(alpha: .7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRect(Rect.fromLTWH(0, y - 1.5, size.width, 3), Paint()..color = const Color(0xFFCCFBF1));
    // squadrette agli angoli
    final squadra = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = bianco.withValues(alpha: .9);
    const m = 16.0, l = 30.0;
    for (final (p, sx, sy) in [
      (const Offset(m, m), 1.0, 1.0),
      (Offset(size.width - m, m), -1.0, 1.0),
      (Offset(m, size.height - m), 1.0, -1.0),
      (Offset(size.width - m, size.height - m), -1.0, -1.0),
    ]) {
      canvas.drawLine(p, p + Offset(l * sx, 0), squadra);
      canvas.drawLine(p, p + Offset(0, l * sy), squadra);
    }
  }

  @override
  bool shouldRepaint(_PittoreScanner old) => old.t != t || old.scende != scende;
}

/// Solo la parte piena del ritaglio, a tutta la superficie: è quella che si taglia.
class _SoloProdotto extends CustomPainter {
  _SoloProdotto(this.immagine, this.area);

  final ui.Image immagine;
  final Rect area;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawImageRect(immagine, area, Offset.zero & size, Paint()..filterQuality = FilterQuality.high);

  @override
  bool shouldRepaint(_SoloProdotto old) => old.immagine != immagine || old.area != area;
}

/// Pulsantino tondo di vetro della scheda Testo.
class _BottoncinoTesto extends StatelessWidget {
  const _BottoncinoTesto(this.icona, this.descrizione, this.onTap, {this.rosso = false});

  final IconData icona;
  final String descrizione;
  final VoidCallback onTap;
  final bool rosso;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: descrizione,
        child: Premibile(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(color: vetro, shape: BoxShape.circle, border: Border.all(color: filoVetro)),
            child: Icon(icona, size: 19, color: rosso ? const Color(0xFFF87171) : bianco),
          ),
        ),
      );
}

/// Un pulsante della barra di vetro sotto la foto: icona e nome, d'accento quando è attivo.
class _Strumento extends StatelessWidget {
  const _Strumento(this.icona, this.nome, this.onTap, {this.chiave, this.acceso = false});

  final IconData icona;
  final String nome;
  final VoidCallback onTap;
  final Key? chiave;
  final bool acceso;

  @override
  Widget build(BuildContext context) => Premibile(
        key: chiave,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icona, size: 19, color: acceso ? luce2 : bianco),
            const SizedBox(width: 7),
            Text(nome,
                style: TextStyle(color: acceso ? luce2 : bianco, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _Pannello extends StatelessWidget {
  const _Pannello({
    required this.scheda,
    required this.stile,
    required this.onScheda,
    required this.onStile,
    required this.categoria,
    required this.onCategoria,
    required this.pronte,
    required this.totale,
    required this.onSalva,
    required this.scritta,
    required this.onAggiungiScritta,
    required this.onCambiaScritta,
    required this.onModificaScritta,
    required this.onTogliScritta,
  });

  final _Scheda scheda;
  final Stile stile;
  final ValueChanged<_Scheda> onScheda;
  final ValueChanged<Stile> onStile;
  final String? categoria;
  final ValueChanged<String?> onCategoria;
  final int pronte, totale;
  final VoidCallback onSalva;

  /// La scritta scelta sulla foto (null = nessuna).
  final Scritta? scritta;
  final ValueChanged<TipoScritta> onAggiungiScritta;
  final void Function(void Function(Scritta s)) onCambiaScritta;
  final VoidCallback onModificaScritta, onTogliScritta;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: filoVetro)),
          boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, -6))],
        ),
        padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Schede(scelta: scheda, onScheda: onScheda),
          const SizedBox(height: 14),
          SizedBox(height: scheda == _Scheda.sfondo || scheda == _Scheda.testo ? 140 : 92, child: _opzioni()),
          const SizedBox(height: 14),
          BottoneLuce(
            testo: totale == 1
                ? 'Salva in galleria'
                : (pronte < totale ? 'Salva $pronte di $totale' : 'Salva tutte ($totale)'),
            icona: Icons.download_rounded,
            onTap: pronte == 0 ? null : onSalva,
          ),
        ]),
      );

  Widget _elencoSfondi() {
    final elenco = categoria == null ? sfondi : categorie.firstWhere((c) => c.id == categoria).sfondi;
    if (elenco.isEmpty) {
      return const Center(
          child: Text('Sfondi in arrivo con il prossimo aggiornamento',
              style: TextStyle(color: grigio500, fontSize: 13, fontWeight: FontWeight.w600)));
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: elenco.length,
      separatorBuilder: (_, _) => const SizedBox(width: 2),
      itemBuilder: (_, i) => _Campione(elenco[i],
          scelto: elenco[i].id == stile.sfondo, onTap: () => onStile(stile.copia(sfondo: elenco[i].id))),
    );
  }

  /// Scheda Testo: sopra i quattro tipi da aggiungere; sotto, per la scritta scelta, colori e grandezza.
  Widget _opzioniTesto() {
    final s = scritta;
    return Column(children: [
      SizedBox(
        height: 64,
        child: Row(children: [
          for (final t in TipoScritta.values) ...[
            if (t != TipoScritta.values.first) const SizedBox(width: 8),
            Expanded(
              child: _Casella(
                scelta: false,
                onTap: () => onAggiungiScritta(t),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(t.icona, color: luce2, size: 22),
                  const SizedBox(height: 4),
                  Text(t.nome, style: const TextStyle(color: grigio200, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: s == null
            ? const Center(
                child: Text('Aggiungi una scritta, poi trascinala sulla foto. Toccala per cambiarla',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: grigio400, fontSize: 12.5, fontWeight: FontWeight.w600)))
            : Row(children: [
                Expanded(
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final c in coloriScritte)
                      Premibile(
                        onTap: () => onCambiaScritta((x) => x.colore = c),
                        child: Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.only(right: 7),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: c == s.colore ? luce1 : filoVetro, width: c == s.colore ? 3 : 1),
                          ),
                        ),
                      ),
                  ]),
                ),
                _BottoncinoTesto(Icons.text_decrease_rounded, 'Più piccola',
                    () => onCambiaScritta((x) => x.grandezza = (x.grandezza / 1.15).clamp(Scritta.grandezzaMin, Scritta.grandezzaMax))),
                _BottoncinoTesto(Icons.text_increase_rounded, 'Più grande',
                    () => onCambiaScritta((x) => x.grandezza = (x.grandezza * 1.15).clamp(Scritta.grandezzaMin, Scritta.grandezzaMax))),
                _BottoncinoTesto(Icons.edit_rounded, 'Cambia il testo', onModificaScritta),
                _BottoncinoTesto(Icons.delete_outline_rounded, 'Togli la scritta', onTogliScritta, rosso: true),
              ]),
      ),
    ]);
  }

  Widget _opzioni() => switch (scheda) {
        _Scheda.sfondo => Column(children: [
            SizedBox(
              height: 34,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _ChipCategoria('Tinte', Icons.palette_rounded, scelta: categoria == null, onTap: () => onCategoria(null)),
                for (final c in categorie)
                  _ChipCategoria(c.nome, c.icona, scelta: categoria == c.id, onTap: () => onCategoria(c.id)),
              ]),
            ),
            const SizedBox(height: 10),
            Expanded(child: _elencoSfondi()),
          ]),
        _Scheda.ombra => Row(children: [
            for (final o in Ombra.values) ...[
              if (o != Ombra.values.first) const SizedBox(width: 8),
              Expanded(
                child: _Casella(
                  scelta: o == stile.ombra,
                  onTap: () => onStile(stile.copia(ombra: o)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(o.icona, color: o == stile.ombra ? luce2 : grigio400, size: 26),
                    const SizedBox(height: 6),
                    Text(o.nome,
                        style: TextStyle(
                            color: o == stile.ombra ? bianco : grigio300, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
          ]),
        _Scheda.formato => ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: Formato.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = Formato.values[i];
              final si = f == stile.formato;
              return SizedBox(
                width: 104,
                child: _Casella(
                  scelta: si,
                  onTap: () => onStile(stile.copia(formato: f)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SagomaFormato(f, lato: 24, colore: si ? luce2 : grigio400),
                    const SizedBox(height: 6),
                    Text(f.nome,
                        style: TextStyle(color: si ? bianco : grigio300, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    Text(f.descrizione.split(' · ').first,
                        style: const TextStyle(color: grigio500, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              );
            },
          ),
        _Scheda.testo => _opzioniTesto(),
        _Scheda.spazio => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(children: [
              const Text('Spazio attorno al prodotto',
                  style: TextStyle(color: bianco, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Pilla('${(stile.margine * 100).round()}%', luce1),
            ]),
            Slider(
              value: stile.margine,
              max: .3,
              divisions: 30,
              onChanged: (v) => onStile(stile.copia(margine: v)),
            ),
          ]),
      };
}

class _Schede extends StatelessWidget {
  const _Schede({required this.scelta, required this.onScheda});

  final _Scheda scelta;
  final ValueChanged<_Scheda> onScheda;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: vetro, borderRadius: BorderRadius.circular(18), border: Border.all(color: filoVetro)),
        child: Row(children: [
          for (final s in _Scheda.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onScheda(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: s == scelta ? gradienteLuce : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: s == scelta
                        ? [BoxShadow(color: luce1.withValues(alpha: .35), blurRadius: 14, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Column(children: [
                    Icon(s.icona, size: 19, color: s == scelta ? notte : grigio400),
                    const SizedBox(height: 2),
                    Text(s.nome,
                        style: TextStyle(
                            color: s == scelta ? notte : grigio400, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
        ]),
      );
}

/// Casella di scelta (ombra, formato): bordo e fondo d'accento quando è scelta.
class _Casella extends StatelessWidget {
  const _Casella({required this.scelta, required this.onTap, required this.child});

  final bool scelta;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Premibile(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: scelta ? luce1.withValues(alpha: .14) : vetro,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scelta ? luce1 : filoVetro, width: scelta ? 1.6 : 1),
            boxShadow: scelta ? [BoxShadow(color: luce1.withValues(alpha: .25), blurRadius: 14)] : null,
          ),
          child: child,
        ),
      );
}

/// Pillola di una categoria di sfondi (Tinte, Natale, Pasqua…).
class _ChipCategoria extends StatelessWidget {
  const _ChipCategoria(this.nome, this.icona, {required this.scelta, required this.onTap});

  final String nome;
  final IconData icona;
  final bool scelta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Premibile(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: scelta ? bianco : vetro,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scelta ? bianco : filoVetro),
            ),
            child: Row(children: [
              Icon(icona, size: 16, color: scelta ? notte : grigio400),
              const SizedBox(width: 6),
              Text(nome,
                  style: TextStyle(color: scelta ? notte : grigio200, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

/// Campione di uno sfondo col suo nome sotto: pallino per le tinte, riquadro con la foto per i temi.
class _Campione extends StatelessWidget {
  const _Campione(this.sfondo, {required this.scelto, required this.onTap});

  final Sfondo sfondo;
  final bool scelto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Premibile(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: sfondo.asset != null ? 56 : 58,
              height: sfondo.asset != null ? 70 : 58,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: sfondo.asset != null ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: sfondo.asset != null ? BorderRadius.circular(14) : null,
                border: Border.all(color: scelto ? luce1 : Colors.transparent, width: 2.5),
                boxShadow: scelto ? [BoxShadow(color: luce1.withValues(alpha: .45), blurRadius: 14)] : null,
              ),
              child: sfondo.asset != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(sfondo.asset!, cacheWidth: 140, fit: BoxFit.cover),
                    )
                  : Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: filoVetro)),
                      child: ClipOval(
                        child: CustomPaint(
                          painter: sfondo.trasparente ? const Scacchiera(lato: 8) : _Tinta(sfondo),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(sfondo.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scelto ? bianco : grigio400, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _Tinta extends CustomPainter {
  const _Tinta(this.sfondo);

  final Sfondo sfondo;

  @override
  void paint(Canvas canvas, Size size) => sfondo.disegna(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(_Tinta old) => old.sfondo != sfondo;
}
