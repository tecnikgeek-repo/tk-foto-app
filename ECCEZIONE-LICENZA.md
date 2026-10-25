# Permesso aggiuntivo (GNU AGPL-3.0, sezione 7)

Come titolare dei diritti su tk-foto, Pietro De Filippis (TecnikGeek) concede il permesso di combinare, collegare
e distribuire questo programma con le seguenti librerie, alle loro licenze, anche se non sono compatibili con la
GNU AGPL:

| Libreria | Licenza | Link |
|---|---|---|
| Google ML Kit Subject Segmentation: `com.google.android.gms:play-services-mlkit-subject-segmentation` (Google Play services, Android; il modello lo scarica Google Play sul telefono) | Termini di servizio di Google ML Kit e di Google Play services | [termini](https://developers.google.com/ml-kit/terms) |
| Google Play services Base: `com.google.android.gms:play-services-base` (Android, serve a far scaricare il modello di ML Kit) | Termini di servizio di Google Play services / Google APIs | [termini](https://developers.google.com/terms) |

Il permesso riguarda solo il collegamento a queste librerie; il resto del programma resta sotto GNU AGPL-3.0.
Chi ridistribuisce il programma deve rispettare anche le licenze di queste librerie.

Non servono permessi per gli altri componenti, che hanno licenze libere: ONNX Runtime
(`com.microsoft.onnxruntime:onnxruntime-android`, MIT), AndroidX ExifInterface (Apache 2.0), i pacchetti Dart
del `pubspec.lock` (BSD, MIT, Apache 2.0), il carattere Plus Jakarta Sans (SIL OFL 1.1, `assets/font/OFL.txt`).
Apple Vision su iPhone è una libreria del sistema operativo. Il modello di scontorno IS-Net (DIS, Apache 2.0) non
è dentro l'app: lo scarica l'app al primo avvio.

---

# Additional permission (GNU AGPL-3.0, section 7)

As the copyright holder of tk-foto, Pietro De Filippis (TecnikGeek) grants permission to combine, link and
distribute this program with the following libraries, under their own licenses, even if they are not compatible
with the GNU AGPL:

| Library | License | Link |
|---|---|---|
| Google ML Kit Subject Segmentation: `com.google.android.gms:play-services-mlkit-subject-segmentation` (Google Play services, Android; the model is downloaded to the phone by Google Play) | Google ML Kit and Google Play services Terms of Service | [terms](https://developers.google.com/ml-kit/terms) |
| Google Play services Base: `com.google.android.gms:play-services-base` (Android, needed to download the ML Kit model) | Google Play services / Google APIs Terms of Service | [terms](https://developers.google.com/terms) |

This permission covers only linking to these libraries; the rest of the program remains under the GNU AGPL-3.0.
Anyone redistributing the program must also comply with the licenses of these libraries.

No permission is needed for the other components, which are under free licenses: ONNX Runtime (MIT), AndroidX
ExifInterface (Apache 2.0), the Dart packages in `pubspec.lock` (BSD, MIT, Apache 2.0), the Plus Jakarta Sans font
(SIL OFL 1.1). Apple Vision on iOS is an operating system library. The IS-Net background removal model (DIS,
Apache 2.0) is not bundled: the app downloads it on first launch.
