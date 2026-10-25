# tk-foto per Android e iPhone

Foto prodotto pronte in un tocco: scontorno sul telefono, rifinitura a pennello, «Ripara», sfondi in tinta e
110 sfondi a tema, ombre, formati per negozio online e social, scritte (titolo, prezzo, sconto).
Tutte le funzioni sono gratis, per tutti.

- **Piattaforme:** Android (APK) e iPhone.
- **Licenza:** software libero sotto [GNU AGPL-3.0](COPYING), fornito così com'è, senza alcuna garanzia.
- **Permesso aggiuntivo per le librerie:** Google ML Kit Subject Segmentation e Google Play services, vedi
  [ECCEZIONE-LICENZA.md](ECCEZIONE-LICENZA.md) (AGPL sez. 7).
- **Scontorno:** sul telefono. Su Android con il modello IS-Net (DIS, Apache 2.0), che l'app scarica una volta
  sola al primo avvio (46 MB); finché non c'è, con Google ML Kit. Su iPhone con Apple Vision.
- **Privacy:** foto e ritagli restano sul telefono, non vengono caricati da nessuna parte. Le statistiche anonime
  (una volta al giorno: nome, versione, sistema e un codice casuale) partono solo se dici sì nel benvenuto o in
  Informazioni.

## Compilare dal sorgente

Serve [Flutter](https://flutter.dev) (versione indicata in `.github/workflows/android.yml`):

```
flutter pub get
flutter test
flutter build apk --release --target-platform android-arm,android-arm64
```

Senza la variabile `ANDROID_KEYSTORE` l'APK si firma con la chiave di debug di Flutter.

Gli sfondi a tema (`assets/sfondi/`) e le foto della vetrina (`assets/demo/`) non sono nel repo: sono contenuti
grafici con una licenza propria, non coperti dall'AGPL, e stanno solo nell'app pubblicata. Compilando dal sorgente
l'app funziona per intero (scontorno, sfondi a colori e sfumati, scritte, formati), senza quelle foto; le prove
che le usano si saltano. Puoi mettere le tue foto in `assets/sfondi/<categoria>/01.jpg`, `02.jpg`…

Il nome «tk-foto» e il logo non sono coperti dalla licenza (AGPL sez. 7): una versione modificata deve avere un
nome diverso.

© 2026 Pietro De Filippis (TecnikGeek) — [pietrodefilippis.it](https://pietrodefilippis.it)
