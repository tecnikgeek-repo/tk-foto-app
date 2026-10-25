// Lo stile della foto finita: sfondo, ombra, formato e spazio attorno al soggetto.
// Si applica uguale a tutte le foto del lotto e si ricorda per la volta dopo.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'temi.dart';

class Sfondo {
  const Sfondo(this.id, this.nome, {this.colore, this.sfumatura, this.asset});

  final String id, nome;
  final Color? colore;
  final Gradient? sfumatura;

  /// Foto a tema dentro l'app: si disegna a parte (serve caricarla), vedi `fondo` in disegnaFoto.
  final String? asset;

  bool get trasparente => colore == null && sfumatura == null && asset == null;

  void disegna(Canvas c, Rect area) {
    if (colore != null) c.drawRect(area, Paint()..color = colore!);
    if (sfumatura != null) c.drawRect(area, Paint()..shader = sfumatura!.createShader(area));
  }
}

const sfondi = [
  Sfondo('bianco', 'Bianco', colore: Color(0xFFFFFFFF)),
  Sfondo('trasparente', 'Trasparente'),
  Sfondo('studio', 'Studio',
      sfumatura: RadialGradient(colors: [Color(0xFFFFFFFF), Color(0xFFE2E8F0)], radius: .9, center: Alignment(0, -.2))),
  Sfondo('grigio', 'Grigio', colore: Color(0xFFF1F5F9)),
  Sfondo('crema', 'Crema', colore: Color(0xFFFFF7ED)),
  Sfondo('rosa', 'Rosa', colore: Color(0xFFFCE7F3)),
  Sfondo('cielo', 'Cielo', colore: Color(0xFFE0F2FE)),
  Sfondo('salvia', 'Salvia', colore: Color(0xFFDCFCE7)),
  Sfondo('limone', 'Limone', colore: Color(0xFFFEF9C3)),
  Sfondo('lavanda', 'Lavanda', colore: Color(0xFFEDE9FE)),
  Sfondo('nero', 'Nero', colore: Color(0xFF0F172A)),
  Sfondo('alba', 'Alba',
      sfumatura: LinearGradient(
          colors: [Color(0xFFFDE68A), Color(0xFFFCA5A5)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
  Sfondo('mare', 'Mare',
      sfumatura: LinearGradient(
          colors: [Color(0xFFBAE6FD), Color(0xFFC7D2FE)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
  Sfondo('menta', 'Menta',
      sfumatura: LinearGradient(
          colors: [Color(0xFFCCFBF1), Color(0xFFD9F99D)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
  Sfondo('notte', 'Notte',
      sfumatura: LinearGradient(
          colors: [Color(0xFF334155), Color(0xFF0F172A)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
];

enum Ombra {
  nessuna('Nessuna', Icons.block_rounded),
  morbida('Morbida', Icons.blur_on_rounded),
  aTerra('A terra', Icons.horizontal_rule_rounded),
  riflesso('Riflesso', Icons.flip_rounded);

  const Ombra(this.nome, this.icona);

  final String nome;
  final IconData icona;

  /// Spazio sotto il soggetto (in proporzione alla sua altezza) per l'ombra o il riflesso.
  double get spazioSotto => switch (this) { Ombra.riflesso => .35, Ombra.aTerra => .05, _ => 0 };
}

enum Formato {
  quadrato('Quadrato', '1:1 · negozio online', 1),
  verticale('Post', '4:5 · social', 4 / 5),
  storia('Storia', '9:16 · storie e reel', 9 / 16),
  classico('Classico', '3:4 · annunci', 3 / 4),
  largo('Largo', '16:9 · banner', 16 / 9),
  originale('Originale', 'aderente al soggetto', 0);

  const Formato(this.nome, this.descrizione, this.rapporto);

  final String nome, descrizione;

  /// Larghezza / altezza; 0 = segue la forma del soggetto.
  final double rapporto;
}

/// Lato lungo della foto finita, in pixel.
const latoUscita = 2000;

class Stile {
  const Stile({this.sfondo = 'bianco', this.ombra = Ombra.morbida, this.formato = Formato.quadrato, this.margine = .1});

  final String sfondo;
  final Ombra ombra;
  final Formato formato;

  /// Spazio attorno al soggetto, in proporzione al lato corto (0–0,3).
  final double margine;

  Sfondo get sfondoScelto =>
      sfondi.where((s) => s.id == sfondo).firstOrNull ??
      sfondiATema.where((s) => s.id == sfondo).firstOrNull ??
      sfondi.first;

  /// Sfondo scuro: l'ombra va più marcata per vedersi.
  bool get sfondoScuro => const {'nero', 'notte'}.contains(sfondo) || sfondo.startsWith('halloween') || sfondo.startsWith('blackfriday');

  Stile copia({String? sfondo, Ombra? ombra, Formato? formato, double? margine}) => Stile(
      sfondo: sfondo ?? this.sfondo,
      ombra: ombra ?? this.ombra,
      formato: formato ?? this.formato,
      margine: margine ?? this.margine);

  Map<String, Object> toJson() =>
      {'sfondo': sfondo, 'ombra': ombra.name, 'formato': formato.name, 'margine': margine};

  static Stile daJson(Map<String, dynamic> j) => Stile(
        sfondo: j['sfondo'] as String? ?? 'bianco',
        ombra: Ombra.values.firstWhere((o) => o.name == j['ombra'], orElse: () => Ombra.morbida),
        formato: Formato.values.firstWhere((f) => f.name == j['formato'], orElse: () => Formato.quadrato),
        margine: ((j['margine'] as num?) ?? .1).toDouble().clamp(0, .3),
      );

  static Future<Stile> carica() async {
    try {
      final t = (await SharedPreferences.getInstance()).getString('stile');
      if (t != null) return daJson(jsonDecode(t) as Map<String, dynamic>);
    } catch (_) {}
    return const Stile();
  }

  Future<void> salva() async {
    try {
      await (await SharedPreferences.getInstance()).setString('stile', jsonEncode(toJson()));
    } catch (_) {}
  }
}
