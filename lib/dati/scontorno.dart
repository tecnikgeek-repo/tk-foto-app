// Scontorno sul telefono: ML Kit su Android, Apple Vision su iPhone (codice nativo in MainActivity.kt
// e AppDelegate.swift, canale «tkfoto/scontorno»). Niente internet e niente costi, tranne il primo
// scaricamento del modello su Android, che fa Google Play.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'composizione.dart';
import 'modello.dart';
import 'scritte.dart';

const _canale = MethodChannel('tkfoto/scontorno');

/// Lato lungo massimo della foto da scontornare.
const latoScontorno = 3072;

/// Una foto del lotto: l'originale e, quando è pronto, il ritaglio trasparente.
class Foto {
  Foto(this.originale);

  final String originale;

  /// PNG del soggetto con lo sfondo trasparente.
  String? ritaglio;

  /// Parte piena del ritaglio (il soggetto), in pixel del PNG.
  Rect? area;

  /// La foto raddrizzata, della stessa misura del ritaglio: il ritocco ne riprende i pezzi da ripristinare.
  String? diritta;

  /// Ingrandimento e spostamento fatti con le dita su questa foto.
  Regolazione regolazione = Regolazione.nessuna;

  /// La parte della foto finita da tenere, in frazioni (tuttaLaFoto = niente taglio).
  Rect taglio = tuttaLaFoto;

  /// Le scritte sopra la foto (titolo, prezzo, sconto…).
  final scritte = <Scritta>[];

  String? errore;
  bool inCorso = false;

  bool get pronta => ritaglio != null && area != null;
}

/// Scontorna [foto]; [stato] riceve i messaggi da mostrare mentre si aspetta il modello.
Future<void> scontorna(Foto foto, {void Function(String)? stato}) async {
  foto
    ..inCorso = true
    ..errore = null;
  try {
    final cartella = await getTemporaryDirectory();
    final uscita = '${cartella.path}/ritaglio-${DateTime.now().microsecondsSinceEpoch}.png';
    final inizio = DateTime.now();
    String? diritta;
    while (true) {
      try {
        final esito = await _canale.invokeMethod<Map<Object?, Object?>>('scontorna', {
          'percorso': foto.originale,
          'latoMax': latoScontorno,
          'uscita': uscita,
          // il modello buono, se è già scaricato (dati/modello.dart); senza, ML Kit
          'modello': await modelloPronto(),
        });
        diritta = esito?['originale'] as String?;
        break;
      } on PlatformException catch (e) {
        // Android, prima volta: Google Play sta scaricando il modello, si riprova finché arriva
        if (e.code == 'MODELLO' && DateTime.now().difference(inizio) < const Duration(minutes: 3)) {
          stato?.call('Preparo lo scontorno: succede solo la prima volta e serve internet…');
          await Future<void>.delayed(const Duration(seconds: 4));
          continue;
        }
        foto.errore = e.code == 'MODELLO'
            ? 'Lo scontorno non è ancora pronto: controlla la connessione e riprova'
            : (e.message ?? e.code);
        return;
      }
    }
    // niente rifinitura dei bordi dopo il modello (provata nella 1.7: su fondi scuri o a trama bucava il prodotto
    // e sfrangiava i bordi); il ritaglio del modello da solo è più pulito
    final ritaglio = uscita;
    final immagine = await caricaImmagine(ritaglio);
    final rgba = (await immagine.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    final w = immagine.width, h = immagine.height;
    immagine.dispose();
    final area = await calcolaAreaPiena(rgba, w, h);
    if (area == null) {
      foto.errore = 'Nella foto non trovo un soggetto da ritagliare';
      return;
    }
    foto
      ..ritaglio = ritaglio
      ..area = area
      ..diritta = diritta;
  } catch (e) {
    foto.errore = 'Scontorno non riuscito: $e';
  } finally {
    foto.inCorso = false;
  }
}


/// Gli oggetti che il telefono riconosce in un pezzo della foto: una maschera per oggetto,
/// [larghezza] × [altezza] byte (0 = fuori, 255 = dentro), riga dopo riga.
typedef OggettiInZona = ({int larghezza, int altezza, List<Uint8List> maschere});

/// Riconosce gli oggetti dentro [zona] (pixel della foto raddrizzata [percorso]) con lo stesso modello
/// dello scontorno. Null se non si può (modello non pronto, telefono che non lo sa fare).
Future<OggettiInZona?> oggettiInZona(String percorso, Rect zona) async {
  try {
    final e = await _canale.invokeMethod<Map<Object?, Object?>>('oggetti', {
      'percorso': percorso,
      'x': zona.left.floor(),
      'y': zona.top.floor(),
      'larghezza': zona.width.ceil(),
      'altezza': zona.height.ceil(),
    });
    if (e == null) return null;
    return (
      larghezza: e['larghezza']! as int,
      altezza: e['altezza']! as int,
      maschere: [for (final m in e['maschere']! as List<Object?>) m! as Uint8List],
    );
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

Future<ui.Image> caricaImmagine(String percorso) async => _decodifica(await File(percorso).readAsBytes());

/// Lato lungo delle copie leggere usate a schermo (anteprime e ritocco): le foto vere sono a 3072 px e
/// ridisegnarle a ogni movimento del dito fa andare l'app a scatti.
const latoVista = 1400;

/// L'immagine in [percorso] ridotta a lato lungo ≤ [lato], e quanto è stata ridotta (1 = intera).
Future<(ui.Image, double)> caricaRidotta(String percorso, {int lato = latoVista}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(await File(percorso).readAsBytes());
  var scala = 1.0;
  final codec = await ui.instantiateImageCodecWithSize(buffer, getTargetSize: (w, h) {
    final lungo = w > h ? w : h;
    if (lungo <= lato) return ui.TargetImageSize(width: w, height: h);
    scala = lato / lungo;
    return ui.TargetImageSize(width: (w * scala).round(), height: (h * scala).round());
  });
  final fotogramma = await codec.getNextFrame();
  codec.dispose();
  return (fotogramma.image, scala);
}

/// Foto dentro l'app (gli sfondi a tema).
Future<ui.Image> caricaAsset(String asset) async => _decodifica((await rootBundle.load(asset)).buffer.asUint8List());

Future<ui.Image> _decodifica(Uint8List byte) async {
  final codec = await ui.instantiateImageCodec(byte);
  final fotogramma = await codec.getNextFrame();
  codec.dispose();
  return fotogramma.image;
}
