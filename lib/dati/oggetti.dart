// Ritocco che riconosce gli oggetti: il tratto a pennello viene rifinito con le maschere degli oggetti
// trovate dallo stesso modello dello scontorno (oggettiInZona in scontorno.dart). E «Ripara»: ricostruisce
// il pezzo di prodotto che stava sotto un oggetto tolto (un gancio sopra l'archetto delle cuffie).
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

/// Esito della rifinitura: la maschera del tratto rifinito (RGBA, bianco con l'alfa) e se il tratto è stato
/// quasi tutto fermato perché passava su oggetti che continuano fuori di lui.
typedef TrattoRifinito = ({Uint8List rgba, bool fermato});

/// Quanto di un oggetto deve coprire il tratto perché «Cancella» lo tolga: sotto, l'oggetto continua fuori
/// dal tratto (è il prodotto) e resta.
const _copertoPerTogliere = .5;

/// [rifinisci] in un isolate. Funzione a sé, non async: la chiusura non deve portarsi dietro delle ui.Image.
Future<TrattoRifinito> rifinisciTratto(Uint8List tratto, List<Uint8List> maschere, int w, int h, bool cancella) =>
    Isolate.run(() => rifinisci(tratto, maschere, w, h, cancella));

/// [tratto] = il tratto disegnato (RGBA, conta l'alfa) alla misura delle [maschere] degli oggetti.
/// «Cancella» toglie lo sfondo e gli oggetti coperti per buona parte, e lascia quelli che continuano fuori dal
/// tratto. «Ripristina» ridà solo i pixel che sono di un oggetto, non lo sfondo attorno.
TrattoRifinito rifinisci(Uint8List tratto, List<Uint8List> maschere, int w, int h, bool cancella) {
  final n = w * h;
  final a = Uint8List(n);
  var sommaA = 0;
  for (var i = 0; i < n; i++) {
    a[i] = tratto[i * 4 + 3];
    sommaA += a[i];
  }
  // cancella: gli oggetti da tenere; ripristina: tutti gli oggetti toccati
  final scelta = Uint8List(n);
  var qualcuno = false;
  for (final m in maschere) {
    var tot = 0, coperto = 0;
    for (var i = 0; i < n; i++) {
      tot += m[i];
      coperto += min(m[i], a[i]);
    }
    if (tot == 0 || coperto == 0) continue;
    if (cancella && coperto / tot >= _copertoPerTogliere) continue;
    qualcuno = true;
    for (var i = 0; i < n; i++) {
      if (m[i] > scelta[i]) scelta[i] = m[i];
    }
  }
  final out = Uint8List(n * 4);
  var restato = 0;
  for (var i = 0; i < n; i++) {
    final int alfa;
    if (cancella) {
      alfa = a[i] * (255 - scelta[i]) ~/ 255;
    } else {
      // nessun oggetto sotto il tratto: si ripristina quello che si è toccato, come col pennello semplice
      alfa = qualcuno ? a[i] * scelta[i] ~/ 255 : a[i];
    }
    restato += alfa;
    // bianco premoltiplicato: i canali colore valgono quanto l'alfa
    out[i * 4] = alfa;
    out[i * 4 + 1] = alfa;
    out[i * 4 + 2] = alfa;
    out[i * 4 + 3] = alfa;
  }
  return (rgba: out, fermato: cancella && sommaA > 0 && restato < sommaA * .4);
}

/// Esito di «Ripara» (RGBA, grandi quanto la zona): [colore] è opaco e va steso sulla foto dove dice [peso]
/// (il tratto, con il suo bordo sfumato); [forma] dice quanto del pezzo ricostruito fa parte del soggetto.
/// Nelle maschere conta solo l'alfa: così non importa se i pixel sono letti premoltiplicati o no.
typedef Riparazione = ({Uint8List colore, Uint8List peso, Uint8List forma});

/// [ripara] in un isolate (funzione a sé, non async, per non portarsi dietro delle ui.Image).
Future<Riparazione> riparaZona(Uint8List immagine, Uint8List tratto, int w, int h) =>
    Isolate.run(() => ripara(immagine, tratto, w, h));

/// Ricostruisce i pixel sotto il [tratto] prolungando quello che c'è attorno: per ogni pixel si guarda in 4
/// direzioni (orizzontale, verticale, due diagonali) dove finisce il buco da una parte e dall'altra, e si
/// passa dolcemente da un capo all'altro. Vale la direzione più breve tra quelle dove i due capi si
/// somigliano: così un archetto nero interrotto da un gancio si ricongiunge, e il vuoto sopra resta vuoto.
/// [immagine] = il ritaglio com'è adesso nella zona (RGBA premoltiplicati), [tratto] = il tratto (conta l'alfa).
Riparazione ripara(Uint8List immagine, Uint8List tratto, int w, int h) {
  final n = w * h;
  final ignoto = Uint8List(n);
  for (var i = 0; i < n; i++) {
    if (tratto[i * 4 + 3] > 8) ignoto[i] = 1;
  }
  // per ogni pixel: il valore dato dalla direzione migliore finora e il suo punteggio
  final somma = Float64List(n * 4), pesi = Float64List(n);
  double val(int i, int c) => immagine[i * 4 + c] / 255;

  void linea(List<int> pixel, double passo) {
    var prima = -1;
    for (var k = 0; k < pixel.length; k++) {
      if (ignoto[pixel[k]] == 1) continue;
      if (prima >= 0 && k - prima > 1) {
        // un buco tra due pixel noti: i capi sono la media dei due pixel noti più vicini da ogni parte
        final a = pixel[prima], a2 = prima > 0 && ignoto[pixel[prima - 1]] == 0 ? pixel[prima - 1] : a;
        final b = pixel[k], b2 = k + 1 < pixel.length && ignoto[pixel[k + 1]] == 0 ? pixel[k + 1] : b;
        final v1 = [for (var c = 0; c < 4; c++) (val(a, c) + val(a2, c)) / 2];
        final v2 = [for (var c = 0; c < 4; c++) (val(b, c) + val(b2, c)) / 2];
        var diff = 0.0;
        for (var c = 0; c < 4; c++) {
          diff += (v1[c] - v2[c]) * (v1[c] - v2[c]);
        }
        final lungo = (k - prima) * passo;
        // vince la direzione migliore (breve e coi capi uguali): mescolarle farebbe sparire in una nebbia una
        // striscia sottile che attraversa il buco, vista da una direzione sola mentre le altre vedono sfondo
        // prodotto pieno da tutti e due i capi: sotto quello che si ripara il prodotto continua, quindi conta
        // di più (vicino al bordo del tratto le linee che vedono solo sfondo sono corte e vincerebbero)
        final pieno = v1[3] > .5 && v2[3] > .5 ? 4 : 1;
        final punteggio = pieno * exp(-diff / .08) / (lungo * lungo);
        for (var j = prima + 1; j < k; j++) {
          final p = pixel[j];
          if (punteggio <= pesi[p]) continue;
          final t = (j - prima) / (k - prima);
          for (var c = 0; c < 4; c++) {
            somma[p * 4 + c] = v1[c] * (1 - t) + v2[c] * t;
          }
          pesi[p] = punteggio;
        }
      }
      prima = k;
    }
  }

  // tutte le righe, colonne e diagonali della zona
  for (var y = 0; y < h; y++) {
    linea([for (var x = 0; x < w; x++) y * w + x], 1);
  }
  for (var x = 0; x < w; x++) {
    linea([for (var y = 0; y < h; y++) y * w + x], 1);
  }
  List<int> diagonale(int x, int y, int dy) => [
        for (; x < w && y >= 0 && y < h; x++, y += dy) y * w + x,
      ];
  for (var y = 0; y < h; y++) {
    linea(diagonale(0, y, 1), sqrt2);
    linea(diagonale(0, y, -1), sqrt2);
  }
  for (var x = 1; x < w; x++) {
    linea(diagonale(x, 0, 1), sqrt2);
    linea(diagonale(x, h - 1, -1), sqrt2);
  }

  // valori ricostruiti, poi una passata di sfocatura leggera dentro il buco per togliere le righe
  final v = Float64List(n * 4);
  for (var i = 0; i < n; i++) {
    for (var c = 0; c < 4; c++) {
      v[i * 4 + c] = ignoto[i] == 0 ? val(i, c) : somma[i * 4 + c];
    }
  }
  final liscio = Float64List.fromList(v);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (ignoto[i] == 0) continue;
      for (var c = 0; c < 4; c++) {
        var s = 0.0, q = 0;
        for (var yy = max(0, y - 1); yy <= min(h - 1, y + 1); yy++) {
          for (var xx = max(0, x - 1); xx <= min(w - 1, x + 1); xx++) {
            s += v[(yy * w + xx) * 4 + c];
            q++;
          }
        }
        liscio[i * 4 + c] = s / q;
      }
    }
  }

  final colore = Uint8List(n * 4), pesi8 = Uint8List(n * 4), forma = Uint8List(n * 4);
  for (var i = 0; i < n; i++) {
    final peso = tratto[i * 4 + 3];
    final a = liscio[i * 4 + 3];
    // bordo netto come quello del soggetto, non una nebbia
    final alfa = ignoto[i] == 1 ? ((a - .5) * 2.5 + .5).clamp(0.0, 1.0) : a;
    for (var c = 0; c < 3; c++) {
      colore[i * 4 + c] = a > .001 ? (liscio[i * 4 + c] / a * 255).round().clamp(0, 255) : 0;
      pesi8[i * 4 + c] = peso;
    }
    colore[i * 4 + 3] = 255;
    pesi8[i * 4 + 3] = peso;
    final f = (alfa * peso).round();
    forma[i * 4] = f;
    forma[i * 4 + 1] = f;
    forma[i * 4 + 2] = f;
    forma[i * 4 + 3] = f;
  }
  return (colore: colore, peso: pesi8, forma: forma);
}
