// Sfondi fotografici a tema (Natale, Pasqua, Ferragosto…), dentro l'app in assets/sfondi/<categoria>/.
// L'elenco delle foto è in temi_elenco.dart, scritto da tools/importa_sfondi.py.
// Le foto (fatte con Canva) non stanno nel repo pubblico: la CI le scarica prima di compilare. Chi compila dal
// sorgente senza di loro ha l'app intera, solo senza le categorie i cui file mancano.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'stile.dart';
import 'temi_elenco.dart';

/// Asset presenti nell'app (null = non ancora letti: si mostrano tutti, come nei test).
Set<String>? _presenti;

/// Legge una volta l'elenco degli asset dell'app: la chiama main prima di runApp.
Future<void> caricaSfondiPresenti() async {
  try {
    _presenti = (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets().toSet();
  } catch (_) {}
}

class Categoria {
  const Categoria(this.id, this.nome, this.icona);

  final String id, nome;
  final IconData icona;

  List<Sfondo> get sfondi => [
        for (final (n, nome) in elencoTemi[id] ?? const <(int, String)>[])
          if (_presenti?.contains(_file(n)) ?? true) Sfondo('$id-$n', nome, asset: _file(n)),
      ];

  String _file(int n) => 'assets/sfondi/$id/${n.toString().padLeft(2, '0')}.jpg';
}

/// Le categorie che hanno almeno una foto nell'app.
List<Categoria> get categorie => [for (final c in _categorie) if (c.sfondi.isNotEmpty) c];

const _categorie = [
  Categoria('natale', 'Natale', Icons.park_rounded),
  Categoria('sanvalentino', 'San Valentino', Icons.favorite_rounded),
  Categoria('pasqua', 'Pasqua', Icons.egg_rounded),
  Categoria('festamamma', 'Festa della mamma', Icons.volunteer_activism_rounded),
  Categoria('primavera', 'Primavera', Icons.local_florist_rounded),
  Categoria('matrimonio', 'Matrimonio', Icons.diamond_rounded),
  Categoria('ferragosto', 'Ferragosto', Icons.beach_access_rounded),
  Categoria('saldiestivi', 'Saldi estivi', Icons.wb_sunny_rounded),
  Categoria('autunno', 'Autunno', Icons.eco_rounded),
  Categoria('halloween', 'Halloween', Icons.nightlight_round),
  Categoria('blackfriday', 'Black Friday', Icons.local_offer_rounded),
];

/// Tutti gli sfondi a tema, per cercarli per id.
List<Sfondo> get sfondiATema => [for (final c in categorie) ...c.sfondi];
