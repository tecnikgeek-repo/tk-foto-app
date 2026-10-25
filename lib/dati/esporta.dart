// Foto finite: file nella cartella temporanea, poi in galleria (album «tk-foto») o condivise.
import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'composizione.dart';
import 'scontorno.dart';
import 'stile.dart';

String _due(int n) => n.toString().padLeft(2, '0');

/// Crea i file delle foto pronte con lo [stile]; [avanzamento] riceve quante ne ha fatte.
Future<List<String>> preparaFile(List<Foto> foto, Stile stile, {void Function(int fatte)? avanzamento}) async {
  final cartella = Directory('${(await getTemporaryDirectory()).path}/pronte')..createSync(recursive: true);
  // i file della volta prima non servono più
  for (final vecchio in cartella.listSync()) {
    try {
      vecchio.deleteSync();
    } catch (_) {}
  }
  final o = DateTime.now();
  final base = 'tk-foto-${o.year}${_due(o.month)}${_due(o.day)}-${_due(o.hour)}${_due(o.minute)}${_due(o.second)}';
  final pronte = foto.where((f) => f.pronta).toList();
  final asset = stile.sfondoScelto.asset;
  final fondo = asset == null ? null : await caricaAsset(asset);
  final percorsi = <String>[];
  try {
    for (var i = 0; i < pronte.length; i++) {
      final immagine = await caricaImmagine(pronte[i].ritaglio!);
      try {
        final (byte, estensione) =
            await creaFoto(immagine, pronte[i].area!, stile,
                regolazione: pronte[i].regolazione,
                fondo: fondo,
                taglio: pronte[i].taglio,
                scritte: pronte[i].scritte);
        final percorso = '${cartella.path}/$base${pronte.length > 1 ? '-${i + 1}' : ''}.$estensione';
        await File(percorso).writeAsBytes(byte);
        percorsi.add(percorso);
      } finally {
        immagine.dispose();
      }
      avanzamento?.call(i + 1);
    }
  } finally {
    fondo?.dispose();
  }
  return percorsi;
}

Future<void> salvaInGalleria(List<String> percorsi) async {
  if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) {
    throw 'serve il permesso di salvare nella galleria';
  }
  for (final p in percorsi) {
    await Gal.putImage(p, album: 'tk-foto');
  }
}

Future<void> condividi(List<String> percorsi) =>
    SharePlus.instance.share(ShareParams(files: [for (final p in percorsi) XFile(p)]));
