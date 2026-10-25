// Ritocco del ritaglio a pennello: «Cancella» toglie i pezzi di sfondo rimasti, «Ripristina» ridà le parti
// del prodotto tagliate per sbaglio (le riprende dalla foto raddrizzata). Un dito disegna, due dita
// ingrandiscono e spostano. Le parti tolte si vedono in rosso tenue, per sapere cosa ripristinare.
// Con «Riconosci gli oggetti» ogni tratto viene rifinito dallo stesso modello dello scontorno (dati/oggetti.dart).
// «Ripara» ricostruisce il pezzo di prodotto che stava sotto un oggetto tolto, prolungando quello che c'è attorno.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../dati/composizione.dart';
import '../dati/oggetti.dart';
import '../dati/scontorno.dart';
import '../tema.dart';

/// Esito del ritocco: il nuovo PNG del ritaglio e la sua parte piena.
typedef RitaglioRitoccato = (String ritaglio, Rect area);

enum _Strumento { cancella, ripristina, ripara }

const _viola = Color(0xFF7C3AED);

class _Tratto {
  _Tratto(this.strumento, this.larghezza, Offset inizio, {this.daRifinire = false})
      : path = (Path()..moveTo(inizio.dx, inizio.dy)),
        punti = 1;

  final _Strumento strumento;
  final double larghezza;
  final Path path;
  int punti;

  bool get cancella => strumento == _Strumento.cancella;
  bool get ripara => strumento == _Strumento.ripara;

  /// Riconosci gli oggetti / Ripara: finché il calcolo non è finito il tratto si vede solo evidenziato.
  bool daRifinire;

  /// Il tratto rifinito sugli oggetti (bianco con l'alfa), da mettere in [zona]; null = il tratto com'è.
  /// Per «Ripara» è la forma del pezzo ricostruito.
  ui.Image? maschera;

  /// «Ripara»: i colori ricostruiti (opachi), da stendere sulla foto in [zona] dove dice [peso].
  ui.Image? colore, peso;
  Rect? zona;

  void libera() {
    maschera?.dispose();
    colore?.dispose();
    peso?.dispose();
  }
}

/// Colore del tratto evidenziato e del cerchio del pennello.
Color _coloreStrumento(_Strumento s) => switch (s) {
      _Strumento.cancella => rosso,
      _Strumento.ripristina => accento,
      _Strumento.ripara => _viola,
    };

class SchermataRitocco extends StatefulWidget {
  const SchermataRitocco({super.key, required this.ritaglio, required this.diritta});

  final String ritaglio, diritta;

  @override
  State<SchermataRitocco> createState() => _SchermataRitoccoState();
}

class _SchermataRitoccoState extends State<SchermataRitocco> {
  ui.Image? _ritaglio, _foto;

  /// Copie leggere per lo schermo: ridisegnare le foto vere (3072 px) a ogni tratto faceva andare a scatti.
  ui.Image? _ritaglioVista, _fotoVista;
  final _tratti = <_Tratto>[];
  _Tratto? _corrente;
  _Strumento _strumento = _Strumento.cancella;
  bool _automatico = true;

  /// Tratti che aspettano il riconoscimento degli oggetti.
  int _inLavoro = 0;

  /// Diametro del pennello a schermo.
  double _pennello = 34;

  /// Vista: punto immagine p → schermo t + p * s.
  double _s = 0;
  Offset _t = Offset.zero;
  double _sIniziale = 1;
  Offset _tIniziale = Offset.zero, _fuocoIniziale = Offset.zero;
  bool _zoomInCorso = false;
  Offset? _dito;
  bool _salva = false;

  @override
  void initState() {
    super.initState();
    Future.wait([
      caricaImmagine(widget.ritaglio),
      caricaImmagine(widget.diritta),
      caricaRidotta(widget.ritaglio).then((r) => r.$1),
      caricaRidotta(widget.diritta).then((r) => r.$1),
    ]).then((im) {
      if (!mounted) {
        for (final i in im) {
          i.dispose();
        }
        return;
      }
      setState(() {
        _ritaglio = im[0];
        _foto = im[1];
        _ritaglioVista = im[2];
        _fotoVista = im[3];
      });
    });
  }

  @override
  void dispose() {
    _ritaglio?.dispose();
    _foto?.dispose();
    _ritaglioVista?.dispose();
    _fotoVista?.dispose();
    for (final t in _tratti) {
      t.libera();
    }
    super.dispose();
  }

  void _togli(Iterable<_Tratto> via) {
    for (final t in via.toList()) {
      _tratti.remove(t);
      t.libera();
    }
  }

  /// «Ripara»: ricostruisce quello che sta sotto il tratto prolungando il ritaglio attorno.
  Future<void> _ripara(_Tratto tr) async {
    final rit = _ritaglio!, foto = _foto!;
    final tutta = Rect.fromLTWH(0, 0, rit.width.toDouble(), rit.height.toDouble());
    final b = tr.path.getBounds().inflate(tr.larghezza / 2);
    final z = b.inflate(max(b.longestSide * .4, 40.0)).intersect(tutta);
    final zona = Rect.fromLTRB(
        z.left.floorToDouble(), z.top.floorToDouble(), z.right.ceilToDouble(), z.bottom.ceilToDouble());
    setState(() => _inLavoro++);
    var riuscito = false;
    try {
      if (zona.isEmpty) return;
      final w = zona.width.toInt(), h = zona.height.toInt();
      // il ritaglio com'è adesso (con i tratti già fatti) e il tratto, nella zona
      final prima = _tratti.takeWhile((t) => t != tr).where((t) => !t.daRifinire).toList();
      final immagine = await _pixelZona(zona, (c) => _disegnaRitaglio(c, foto, rit, prima));
      final traccia = await _pixelZona(zona, (c) => c.drawPath(tr.path, _vernice(tr)));
      final esito = await riparaZona(immagine, traccia, w, h);
      final colore = await _immagine(esito.colore, w, h),
          peso = await _immagine(esito.peso, w, h),
          forma = await _immagine(esito.forma, w, h);
      if (!mounted || !_tratti.contains(tr)) {
        colore.dispose();
        peso.dispose();
        forma.dispose();
        return;
      }
      setState(() {
        tr
          ..colore = colore
          ..peso = peso
          ..maschera = forma
          ..zona = zona;
      });
      riuscito = true;
    } catch (_) {
      // sotto: il tratto si toglie e si avvisa
    } finally {
      if (mounted) {
        setState(() {
          tr.daRifinire = false;
          _inLavoro--;
          if (!riuscito) _togli([tr]);
        });
        if (!riuscito && _tratti.isNotEmpty) avviso(context, 'Non riesco a riparare questo pezzo: prova con un tratto più piccolo');
      }
    }
  }

  /// Rifinisce il tratto con gli oggetti che il modello dello scontorno riconosce attorno a lui.
  Future<void> _rifinisci(_Tratto tr) async {
    final rit = _ritaglio!, foto = _foto!;
    final tutta = Rect.fromLTWH(0, 0, rit.width.toDouble(), rit.height.toDouble());
    final b = tr.path.getBounds().inflate(tr.larghezza / 2);
    // un po' di foto attorno al tratto, perché il modello capisca dove continuano gli oggetti
    final zona = b.inflate(max(b.longestSide * .6, 120.0)).intersect(tutta);
    setState(() => _inLavoro++);
    try {
      if (zona.isEmpty) return;
      final kx = foto.width / rit.width, ky = foto.height / rit.height;
      final o = await oggettiInZona(
          widget.diritta, Rect.fromLTRB(zona.left * kx, zona.top * ky, zona.right * kx, zona.bottom * ky));
      if (o == null || o.maschere.isEmpty || !mounted || !_tratti.contains(tr)) return;
      final registra = ui.PictureRecorder();
      Canvas(registra)
        ..scale(o.larghezza / zona.width, o.altezza / zona.height)
        ..translate(-zona.left, -zona.top)
        ..drawPath(tr.path, _vernice(tr));
      final im = await registra.endRecording().toImage(o.larghezza, o.altezza);
      final traccia = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      im.dispose();
      final esito = await rifinisciTratto(traccia, o.maschere, o.larghezza, o.altezza, tr.cancella);
      final maschera = await _immagine(esito.rgba, o.larghezza, o.altezza);
      if (!mounted || !_tratti.contains(tr)) return maschera.dispose();
      setState(() {
        tr
          ..maschera = maschera
          ..zona = zona;
      });
      if (esito.fermato) {
        avviso(context,
            'Ho lasciato quello che continua fuori dal tratto. Per togliere un oggetto passaci sopra tutto; '
            'se è attaccato al prodotto spegni «Riconosci gli oggetti» e usa un pennello piccolo');
      }
    } catch (_) {
      // se il riconoscimento non riesce resta il tratto com'è
    } finally {
      if (mounted) {
        setState(() {
          tr.daRifinire = false;
          _inLavoro--;
        });
      }
    }
  }

  void _adatta(Size area) {
    final im = _ritaglio!;
    _s = min(area.width / im.width, area.height / im.height) * .94;
    _t = Offset((area.width - im.width * _s) / 2, (area.height - im.height * _s) / 2);
  }

  Offset _inImmagine(Offset schermo) => (schermo - _t) / _s;

  void _inizio(ScaleStartDetails d) {
    _sIniziale = _s;
    _tIniziale = _t;
    _fuocoIniziale = d.localFocalPoint;
    _zoomInCorso = d.pointerCount > 1;
    if (!_zoomInCorso) {
      setState(() {
        _dito = d.localFocalPoint;
        final p = _inImmagine(d.localFocalPoint);
        _corrente = _Tratto(_strumento, _pennello / _s, p,
            daRifinire: _strumento == _Strumento.ripara || _automatico);
        _tratti.add(_corrente!);
      });
    }
  }

  void _muovi(ScaleUpdateDetails d) {
    if (d.pointerCount > 1 && !_zoomInCorso) {
      // è arrivato il secondo dito: il tratto appena iniziato non era voluto
      _zoomInCorso = true;
      if (_corrente != null) _togli([_corrente!]);
      _corrente = null;
      _sIniziale = _s;
      _tIniziale = _t;
      _fuocoIniziale = d.localFocalPoint;
    }
    setState(() {
      if (_zoomInCorso) {
        _dito = null;
        final nuova = (_sIniziale * d.scale).clamp(_sIniziale * .2, 20.0);
        final punto = (_fuocoIniziale - _tIniziale) / _sIniziale;
        _t = d.localFocalPoint - punto * nuova;
        _s = nuova;
      } else if (_corrente != null) {
        _dito = d.localFocalPoint;
        final p = _inImmagine(d.localFocalPoint);
        _corrente!.path.lineTo(p.dx, p.dy);
        _corrente!.punti++;
      }
    });
  }

  void _fine(ScaleEndDetails _) {
    final c = _corrente;
    setState(() {
      // un tocco senza movimento lascia un punto: lo si allunga di poco perché si veda
      if (c != null && c.punti == 1) {
        final b = c.path.getBounds();
        c.path.lineTo(b.left + .01, b.top);
      }
      _corrente = null;
      _dito = null;
    });
    if (c != null && c.daRifinire) c.ripara ? _ripara(c) : _rifinisci(c);
  }

  Future<void> _applica() async {
    final rit = _ritaglio, foto = _foto;
    if (rit == null || foto == null) return;
    if (_tratti.isEmpty) return Navigator.of(context).pop();
    if (_inLavoro > 0) return;
    setState(() => _salva = true);
    try {
      final registra = ui.PictureRecorder();
      _disegnaRitaglio(Canvas(registra), foto, rit, _tratti);
      final im = await registra.endRecording().toImage(rit.width, rit.height);
      final png = (await im.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final rgba = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      final w = im.width, h = im.height;
      im.dispose();
      final area = await calcolaAreaPiena(rgba, w, h);
      if (area == null) {
        if (mounted) avviso(context, 'Hai cancellato tutto il prodotto: ripristinane una parte');
        return;
      }
      final cartella = await getTemporaryDirectory();
      final percorso = '${cartella.path}/ritocco-${DateTime.now().microsecondsSinceEpoch}.png';
      await File(percorso).writeAsBytes(png);
      if (mounted) Navigator.of(context).pop<RitaglioRitoccato>((percorso, area));
    } catch (e) {
      if (mounted) avviso(context, 'Non riesco a salvare il ritocco: $e');
    } finally {
      if (mounted) setState(() => _salva = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: notte,
        body: Column(children: [
          TestataSemplice(
            titolo: 'Ritocca il ritaglio',
            indietro: () => Navigator.of(context).pop(),
            azioni: [
              AzioneTk(Icons.undo_rounded, 'Annulla l\'ultimo tratto',
                  _tratti.isEmpty ? null : () => setState(() => _togli([_tratti.last]))),
              AzioneTk(Icons.restart_alt_rounded, 'Ricomincia',
                  _tratti.isEmpty ? null : () => setState(() => _togli(_tratti))),
            ],
          ),
          Expanded(
            child: _ritaglio == null || _foto == null || _ritaglioVista == null || _fotoVista == null
                ? const Center(child: CircularProgressIndicator(color: bianco))
                : LayoutBuilder(builder: (_, misure) {
                    if (_s == 0) _adatta(misure.biggest);
                    return GestureDetector(
                      key: const Key('tela-ritocco'),
                      onScaleStart: _inizio,
                      onScaleUpdate: _muovi,
                      onScaleEnd: _fine,
                      onDoubleTap: () => setState(() => _adatta(misure.biggest)),
                      child: ClipRect(
                        child: CustomPaint(
                          size: misure.biggest,
                          painter: _PittoreRitocco(
                            foto: _fotoVista!,
                            ritaglio: _ritaglioVista!,
                            misura: Size(_ritaglio!.width.toDouble(), _ritaglio!.height.toDouble()),
                            tratti: List.of(_tratti),
                            versione: _tratti.fold(0, (a, t) => a + t.punti + (t.daRifinire ? 0 : 1 << 20)),
                            s: _s,
                            t: _t,
                            dito: _dito,
                            pennello: _pennello,
                            strumento: _strumento,
                          ),
                        ),
                      ),
                    );
                  }),
          ),
          _Comandi(
            strumento: _strumento,
            automatico: _automatico,
            pennello: _pennello,
            salva: _salva,
            inLavoro: _inLavoro > 0,
            onStrumento: (s) => setState(() => _strumento = s),
            onAutomatico: (v) => setState(() => _automatico = v),
            onPennello: (v) => setState(() => _pennello = v),
            onApplica: _applica,
          ),
        ]),
      );
}

/// Disegna il ritaglio ritoccato: la foto, tenuta solo dove la maschera (ritaglio + tratti) è piena.
/// [misura] = la misura vera del ritaglio (i tratti sono in quelle coordinate); a schermo [foto] e [ritaglio]
/// possono essere copie leggere più piccole, si stendono su tutta la misura.
void _disegnaRitaglio(Canvas c, ui.Image foto, ui.Image ritaglio, List<_Tratto> tratti, {Size? misura}) {
  final r = Offset.zero & (misura ?? Size(ritaglio.width.toDouble(), ritaglio.height.toDouble()));
  c.saveLayer(r, Paint());
  c.drawImageRect(foto, Rect.fromLTWH(0, 0, foto.width.toDouble(), foto.height.toDouble()), r, Paint());
  // «Ripara»: i colori ricostruiti stesi sulla foto, sfumati come il tratto
  for (final t in tratti) {
    final col = t.colore, peso = t.peso, zona = t.zona;
    if (t.daRifinire || col == null || peso == null || zona == null) continue;
    c.saveLayer(zona, Paint());
    c.drawImageRect(col, Rect.fromLTWH(0, 0, col.width.toDouble(), col.height.toDouble()), zona, Paint());
    c.drawImageRect(peso, Rect.fromLTWH(0, 0, peso.width.toDouble(), peso.height.toDouble()), zona,
        Paint()..blendMode = BlendMode.dstIn);
    c.restore();
  }
  c.saveLayer(r, Paint()..blendMode = BlendMode.dstIn);
  c.drawImageRect(ritaglio, Rect.fromLTWH(0, 0, ritaglio.width.toDouble(), ritaglio.height.toDouble()), r, Paint());
  for (final t in tratti) {
    // il tratto che aspetta il riconoscimento degli oggetti non vale ancora (si vede solo evidenziato)
    if (t.daRifinire) continue;
    final modo = t.cancella ? BlendMode.dstOut : BlendMode.srcOver;
    final m = t.maschera, zona = t.zona, peso = t.peso;
    if (t.ripara) {
      // sotto il tratto la forma ricostruita prende il posto di quella che c'era
      if (m == null || zona == null || peso == null) continue;
      c.drawImageRect(peso, Rect.fromLTWH(0, 0, peso.width.toDouble(), peso.height.toDouble()), zona,
          Paint()..blendMode = BlendMode.dstOut);
      c.drawImageRect(m, Rect.fromLTWH(0, 0, m.width.toDouble(), m.height.toDouble()), zona,
          Paint()..blendMode = BlendMode.plus);
    } else if (m != null && zona != null) {
      c.drawImageRect(m, Rect.fromLTWH(0, 0, m.width.toDouble(), m.height.toDouble()), zona,
          Paint()
            ..blendMode = modo
            ..filterQuality = FilterQuality.medium);
    } else {
      c.drawPath(t.path, _vernice(t)..blendMode = modo);
    }
  }
  c.restore();
  c.restore();
}

/// I pixel (RGBA premoltiplicati) di quello che [disegna] fa nella [zona] dell'immagine.
Future<Uint8List> _pixelZona(Rect zona, void Function(Canvas) disegna) async {
  final registra = ui.PictureRecorder();
  disegna(Canvas(registra)..translate(-zona.left, -zona.top));
  final im = await registra.endRecording().toImage(zona.width.toInt(), zona.height.toInt());
  try {
    return (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  } finally {
    im.dispose();
  }
}

Future<ui.Image> _immagine(Uint8List rgba, int w, int h) {
  final fatto = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, fatto.complete);
  return fatto.future;
}

/// Il pennello del tratto [t], bianco.
Paint _vernice(_Tratto t) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = t.larghezza
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = bianco
  // bordo appena sfumato, come lo scontorno automatico
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(.5, t.larghezza * .08));

/// Raggio della lente d'ingrandimento a schermo e quanto ingrandisce rispetto alla vista.
const _raggioLente = 62.0, _zoomLente = 2.2;

class _PittoreRitocco extends CustomPainter {
  _PittoreRitocco({
    required this.foto,
    required this.ritaglio,
    required this.misura,
    required this.tratti,
    required this.versione,
    required this.s,
    required this.t,
    required this.dito,
    required this.pennello,
    required this.strumento,
  });

  /// Copie leggere di foto e ritaglio, stese sulla [misura] vera del ritaglio.
  final ui.Image foto, ritaglio;
  final Size misura;
  final List<_Tratto> tratti;
  final int versione;
  final double s;
  final Offset t;
  final Offset? dito;
  final double pennello;
  final _Strumento strumento;

  @override
  void paint(Canvas canvas, Size size) {
    _scena(canvas);
    final d = dito;
    if (d == null) return;
    final cerchio = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _coloreStrumento(strumento);
    canvas.drawCircle(d, pennello / 2, cerchio);
    // lente d'ingrandimento in alto: il dito copre il punto che si ritocca. Va dall'altra parte se il dito è lì sotto
    const margine = 14.0 + _raggioLente;
    final aSinistra = !(d.dx < margine * 2 + 20 && d.dy < margine * 2 + 20);
    final lente = Offset(aSinistra ? margine : size.width - margine, margine);
    final giro = Rect.fromCircle(center: lente, radius: _raggioLente);
    canvas.drawCircle(lente, _raggioLente + 2,
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.save();
    canvas.clipPath(Path()..addOval(giro));
    canvas.drawRect(giro, Paint()..color = navy);
    canvas.translate(lente.dx, lente.dy);
    canvas.scale(_zoomLente);
    canvas.translate(-d.dx, -d.dy);
    _scena(canvas);
    canvas.drawCircle(d, pennello / 2, cerchio..strokeWidth = 2 / _zoomLente);
    canvas.restore();
    canvas.drawCircle(
        lente,
        _raggioLente,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = bianco);
  }

  /// Foto, parti tolte in rosso e ritaglio, con la vista attuale (spostamento [t], scala [s]).
  void _scena(Canvas canvas) {
    canvas.save();
    canvas.translate(t.dx, t.dy);
    canvas.scale(s);
    final r = Offset.zero & misura;
    canvas.save();
    canvas.clipRect(r);
    // scacchiera grande quanto la foto (il lato di un quadretto resta di 14 punti a schermo)
    final quadretto = 14 / s;
    canvas.drawRect(r, Paint()..color = bianco);
    final grigio = Paint()..color = grigio200;
    for (var y = 0; y * quadretto < r.height; y++) {
      for (var x = y % 2; x * quadretto < r.width; x += 2) {
        canvas.drawRect(Rect.fromLTWH(x * quadretto, y * quadretto, quadretto, quadretto), grigio);
      }
    }
    // la foto intera, tenue e rossa: quello che è stato tolto
    canvas.saveLayer(r, Paint()..color = const Color(0x59000000));
    canvas.drawImageRect(foto, Rect.fromLTWH(0, 0, foto.width.toDouble(), foto.height.toDouble()), r, Paint());
    canvas.drawRect(r, Paint()..color = const Color(0x80DC2626)..blendMode = BlendMode.srcATop);
    canvas.restore();
    _disegnaRitaglio(canvas, foto, ritaglio, tratti, misura: misura);
    // i tratti che aspettano il riconoscimento degli oggetti: evidenziati, non ancora applicati
    for (final tr in tratti.where((tr) => tr.daRifinire)) {
      canvas.drawPath(
          tr.path, _vernice(tr)..color = _coloreStrumento(tr.strumento).withValues(alpha: .45));
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PittoreRitocco old) =>
      old.versione != versione ||
      old.tratti.length != tratti.length ||
      old.s != s ||
      old.t != t ||
      old.dito != dito ||
      old.strumento != strumento;
}

class _Comandi extends StatelessWidget {
  const _Comandi({
    required this.strumento,
    required this.automatico,
    required this.pennello,
    required this.salva,
    required this.inLavoro,
    required this.onStrumento,
    required this.onAutomatico,
    required this.onPennello,
    required this.onApplica,
  });

  final _Strumento strumento;
  final bool automatico, salva, inLavoro;
  final double pennello;
  final ValueChanged<_Strumento> onStrumento;
  final ValueChanged<bool> onAutomatico;
  final ValueChanged<double> onPennello;
  final VoidCallback onApplica;

  Widget _bottone(_Strumento s, String testo, IconData icona) => Expanded(
      child: _Modo(testo, icona, _coloreStrumento(s), scelto: strumento == s, onTap: () => onStrumento(s)));

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: navy,
          border: Border(top: BorderSide(color: filoVetro)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            _bottone(_Strumento.cancella, 'Cancella', Icons.cleaning_services_rounded),
            const SizedBox(width: 8),
            _bottone(_Strumento.ripristina, 'Ripristina', Icons.brush_rounded),
            const SizedBox(width: 8),
            _bottone(_Strumento.ripara, 'Ripara', Icons.healing_rounded),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.circle, size: 10, color: grigio400),
            Expanded(child: Slider(value: pennello, min: 8, max: 90, onChanged: onPennello)),
            const Icon(Icons.circle, size: 24, color: grigio400),
          ]),
          if (strumento == _Strumento.ripara)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(children: [
                Icon(Icons.healing_rounded, size: 22, color: _viola),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Passa sopra il pezzo da rifare (dove c\'era il gancio): lo ricostruisco '
                      'prolungando il prodotto attorno',
                      style: TextStyle(color: grigio500, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ]),
            )
          else
          InkWell(
            key: const Key('riconosci-oggetti'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => onAutomatico(!automatico),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                Icon(Icons.auto_fix_high_rounded, size: 22, color: automatico ? accento : grigio400),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Riconosci gli oggetti',
                        style: TextStyle(color: bianco, fontSize: 14.5, fontWeight: FontWeight.w800)),
                    Text(
                        automatico
                            ? 'Passa sopra un oggetto: lo stacco io dal prodotto'
                            : 'Il pennello prende tutto quello che tocca',
                        style: const TextStyle(color: grigio500, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
                Switch(value: automatico, onChanged: onAutomatico),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Un dito per ritoccare, due per ingrandire e spostare',
              style: TextStyle(color: grigio500, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          BottoneTk(
              testo: salva
                  ? 'Salvo…'
                  : inLavoro
                      ? 'Un momento…'
                      : 'Applica',
              icona: Icons.check_rounded,
              onTap: salva || inLavoro ? null : onApplica),
        ]),
      );
}

class _Modo extends StatelessWidget {
  const _Modo(this.testo, this.icona, this.colore, {required this.scelto, required this.onTap});

  final String testo;
  final IconData icona;
  final Color colore;
  final bool scelto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: scelto ? colore.withValues(alpha: .18) : vetro,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scelto ? colore : grigio200, width: scelto ? 2 : 1),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icona, color: scelto ? colore : grigio400, size: 21),
              const SizedBox(height: 3),
              Text(testo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scelto ? bianco : grigio200, fontSize: 13.5, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}
