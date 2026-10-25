// Il modello di scontorno buono (IS-Net, open source, licenza Apache 2.0), quantizzato a 8 bit: 46 MB.
// Non sta nell'APK (gli aggiornamenti resterebbero pesanti): l'app lo scarica una volta sola dalla Dropbox delle
// app TK e lo tiene nella sua cartella. Finché non c'è, lo scontorno lo fa ML Kit come prima.
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const _url =
    'https://dl.dropboxusercontent.com/scl/fi/ngjmk5gf9000owscm5puk/foto-isnet-int8.onnx?rlkey=jsz3msa8gnua5w0oq6w9i9pje';
const _byte = 46360717;

Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/isnet-int8.onnx');

/// Il percorso del modello se è già scaricato e intero, altrimenti null.
Future<String?> modelloPronto() async {
  if (!Platform.isAndroid) return null;
  try {
    final f = await _file();
    return await f.exists() && await f.length() == _byte ? f.path : null;
  } catch (_) {
    return null;
  }
}

Future<void>? _scaricamento;

/// Scarica il modello se manca, in silenzio e una volta sola; se non riesce si riprova al prossimo avvio.
Future<void> preparaModello() => _scaricamento ??= _scarica();

Future<void> _scarica() async {
  if (!Platform.isAndroid || await modelloPronto() != null) return;
  try {
    final f = await _file();
    final parziale = File('${f.path}.parziale');
    final risposta = await http.Client().send(http.Request('GET', Uri.parse(_url)));
    if (risposta.statusCode != 200) return;
    final scrivi = parziale.openWrite();
    await risposta.stream.pipe(scrivi);
    if (await parziale.length() == _byte) {
      await parziale.rename(f.path);
    } else {
      await parziale.delete();
    }
  } catch (_) {
    // senza rete o con poco spazio: resta ML Kit
  } finally {
    _scaricamento = null;
  }
}
