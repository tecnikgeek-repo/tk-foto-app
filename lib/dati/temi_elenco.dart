// Scritto da tools/importa_sfondi.py: non modificare a mano.
// categoria -> (numero del file, nome mostrato)
const elencoTemi = <String, List<(int, String)>>{
  'natale': [(1, 'Tavolo e albero'), (2, 'Marmo e oro'), (3, 'Legno e pigne'), (4, 'Neve nordica'), (5, 'Podio rosso'), (6, 'Notte stellata'), (7, 'Lino e candele'), (8, 'Rame'), (9, 'Pastello'), (10, 'Pietra e agrifoglio')],
  'sanvalentino': [(1, 'Petali rosa'), (2, 'Raso rosso'), (3, 'Cuori bokeh'), (4, 'Podio bordeaux'), (5, 'Palloncini cuore'), (6, 'Candele romantiche'), (7, 'Seta cipria'), (8, 'Rose bianche'), (9, 'Podio rosso'), (10, 'Fiori secchi')],
  'primavera': [(1, 'Ciliegio'), (2, 'Mimosa'), (3, 'Lavanda'), (4, 'Margherite'), (5, 'Tulipani'), (6, 'Glicine'), (7, 'Foglie fresche'), (8, 'Sottobosco'), (9, 'Farfalle'), (10, 'Giardino')],
  'blackfriday': [(1, 'Nero e oro'), (2, 'Nastri rossi'), (3, 'Neon viola'), (4, 'Nero argento'), (5, 'Nero fucsia'), (6, 'Palloncini oro'), (7, 'Regali neri'), (8, 'Palco blu'), (9, 'Fumo ambra'), (10, 'Rosso e oro')],
  'halloween': [(1, 'Zucche e candele'), (2, 'Pozioni'), (3, 'Luna e nebbia'), (4, 'Oro e nero'), (5, 'Lume di candela'), (6, 'Ragnatele'), (7, 'Pipistrelli'), (8, 'Lanterne gotiche'), (9, 'Zucche pastello'), (10, 'Velluto rosso')],
  'pasqua': [(1, 'Uova pastello'), (2, 'Prato fiorito'), (3, 'Lavanda lilla'), (4, 'Podio azzurro'), (5, 'Marmo oro'), (6, 'Rami d\'ulivo'), (7, 'Fiori di pesco'), (8, 'Tulipani'), (9, 'Coniglietto salvia'), (10, 'Cesti di vimini')],
  'autunno': [(1, 'Foglie d\'acero'), (2, 'Castagne'), (3, 'Coperta di lana'), (4, 'Zucche'), (5, 'Sottobosco'), (6, 'Velluto bordeaux'), (7, 'Pigne'), (8, 'Spighe'), (9, 'Bosco dorato'), (10, 'Spezie')],
  'ferragosto': [(1, 'Sabbia e mare'), (2, 'Ombre di palma'), (3, 'Bianco mediterraneo'), (4, 'Limoni costiera'), (5, 'Tramonto'), (6, 'Stelle marine'), (7, 'Ombrellone'), (8, 'Maioliche'), (9, 'Acqua turchese'), (10, 'Scogli e onde')],
  'festamamma': [(1, 'Peonie'), (2, 'Ranuncoli'), (3, 'Rose lilla'), (4, 'Podio rosa'), (5, 'Camomilla'), (6, 'Regali'), (7, 'Colazione'), (8, 'Petali'), (9, 'Finestra'), (10, 'Vassoio')],
  'saldiestivi': [(1, 'Monstera'), (2, 'Anguria'), (3, 'Piscina'), (4, 'Agrumi'), (5, 'Palloncini'), (6, 'Coriandoli'), (7, 'Ghiaccioli'), (8, 'Spiaggia'), (9, 'Pompelmo'), (10, 'Ibisco')],
  'matrimonio': [(1, 'Bianco e oro'), (2, 'Eucalipto'), (3, 'Cipria'), (4, 'Champagne'), (5, 'Bianco e argento'), (6, 'Nastri azzurri'), (7, 'Boho terracotta'), (8, 'Candele'), (9, 'Arco floreale'), (10, 'Gypsophila')],
};
