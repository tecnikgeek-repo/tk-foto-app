package it.pietrodefilippis.tkfoto

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.mlkit.common.MlKitException
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.FloatBuffer
import java.util.concurrent.Executors

/**
 * Scontorno sul telefono con ML Kit Subject Segmentation (niente internet, niente costi).
 * Canale «tkfoto/scontorno», metodo «scontorna» {percorso, latoMax, uscita} → {larghezza, altezza, originale}:
 * scrive in «uscita» il PNG del soggetto con lo sfondo trasparente e in «originale» la foto raddrizzata
 * della stessa misura (per il ritocco a pennello).
 */
class MainActivity : FlutterActivity() {
    private val lavoro = Executors.newSingleThreadExecutor()
    private val principale = Handler(Looper.getMainLooper())

    private val segmentatore by lazy {
        SubjectSegmentation.getClient(SubjectSegmenterOptions.Builder().enableForegroundBitmap().build())
    }

    /** Lo stesso modello, ma con un risultato per ogni oggetto trovato (per il ritocco). */
    private val segmentatoreOggetti by lazy {
        SubjectSegmentation.getClient(
            SubjectSegmenterOptions.Builder()
                .enableMultipleSubjects(
                    SubjectSegmenterOptions.SubjectResultOptions.Builder().enableConfidenceMask().build()
                )
                .build()
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TkAggiornamento.registra(flutterEngine, this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tkfoto/scontorno").setMethodCallHandler { call, result ->
            when (call.method) {
                "scontorna" -> {
                    val modello = call.argument<String>("modello")
                    if (modello != null && File(modello).exists()) {
                        scontornaIsNet(
                            call.argument<String>("percorso")!!,
                            call.argument<Int>("latoMax") ?: 2048,
                            call.argument<String>("uscita")!!,
                            modello,
                            result,
                        )
                    } else {
                        scontorna(
                            call.argument<String>("percorso")!!,
                            call.argument<Int>("latoMax") ?: 2048,
                            call.argument<String>("uscita")!!,
                            result,
                        )
                    }
                }
                "oggetti" -> oggetti(
                    call.argument<String>("percorso")!!,
                    call.argument<Int>("x")!!,
                    call.argument<Int>("y")!!,
                    call.argument<Int>("larghezza")!!,
                    call.argument<Int>("altezza")!!,
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Metodo «oggetti» {percorso, x, y, larghezza, altezza} → {larghezza, altezza, maschere}: gli oggetti
     * riconosciuti nel pezzo indicato della foto, una maschera di byte (0–255) per oggetto. Il pezzo può
     * tornare rimpicciolito (lato lungo ≤ 1024): le misure sono quelle delle maschere.
     */
    private fun oggetti(percorso: String, x: Int, y: Int, larghezza: Int, altezza: Int, result: MethodChannel.Result) {
        lavoro.execute {
            val pezzo = try {
                val foto = BitmapFactory.decodeFile(percorso, BitmapFactory.Options().apply {
                    inPreferredConfig = Bitmap.Config.ARGB_8888
                }) ?: throw IllegalArgumentException("formato non letto")
                val x0 = x.coerceIn(0, foto.width - 1)
                val y0 = y.coerceIn(0, foto.height - 1)
                val w = larghezza.coerceIn(1, foto.width - x0)
                val h = altezza.coerceIn(1, foto.height - y0)
                val ritagliato = Bitmap.createBitmap(foto, x0, y0, w, h)
                val lungo = maxOf(w, h)
                if (lungo > 1024) {
                    Bitmap.createScaledBitmap(ritagliato, maxOf(1, w * 1024 / lungo), maxOf(1, h * 1024 / lungo), true)
                } else {
                    ritagliato
                }
            } catch (e: Exception) {
                principale.post { result.error("FOTO", "Non riesco ad aprire la foto: ${e.message}", null) }
                return@execute
            }
            segmentatoreOggetti.process(InputImage.fromBitmap(pezzo, 0))
                .addOnSuccessListener(lavoro) { r ->
                    val w = pezzo.width
                    val h = pezzo.height
                    val maschere = r.subjects.mapNotNull { s ->
                        val fiducia = s.confidenceMask ?: return@mapNotNull null
                        fiducia.rewind()
                        val m = ByteArray(w * h)
                        for (yy in 0 until s.height) {
                            for (xx in 0 until s.width) {
                                val v = fiducia.get()
                                val px = s.startX + xx
                                val py = s.startY + yy
                                if (px in 0 until w && py in 0 until h) {
                                    m[py * w + px] = (v.coerceIn(0f, 1f) * 255f).toInt().toByte()
                                }
                            }
                        }
                        m
                    }
                    val esito = mapOf("larghezza" to w, "altezza" to h, "maschere" to maschere)
                    principale.post { result.success(esito) }
                }
                .addOnFailureListener(lavoro) { e ->
                    if (e is MlKitException && e.errorCode == MlKitException.UNAVAILABLE) {
                        ModuleInstall.getClient(this)
                            .installModules(ModuleInstallRequest.newBuilder().addApi(segmentatoreOggetti).build())
                        principale.post { result.error("MODELLO", "Il modello non è ancora pronto", null) }
                    } else {
                        principale.post { result.error("OGGETTI", e.message ?: e.toString(), null) }
                    }
                }
        }
    }

    private fun scontorna(percorso: String, latoMax: Int, uscita: String, result: MethodChannel.Result) {
        lavoro.execute {
            val foto = try {
                caricaDiritta(percorso, latoMax)
            } catch (e: Exception) {
                principale.post { result.error("FOTO", "Non riesco ad aprire la foto: ${e.message}", null) }
                return@execute
            }
            // la foto raddrizzata, della stessa misura del ritaglio: serve al ritocco per ripristinare
            val diritta = uscita.removeSuffix(".png") + "-originale.jpg"
            FileOutputStream(File(diritta)).use { foto.compress(Bitmap.CompressFormat.JPEG, 94, it) }
            segmentatore.process(InputImage.fromBitmap(foto, 0))
                .addOnSuccessListener(lavoro) { r ->
                    val soggetto = r.foregroundBitmap
                    if (soggetto == null) {
                        principale.post { result.error("VUOTO", "Nella foto non trovo un soggetto da ritagliare", null) }
                        return@addOnSuccessListener
                    }
                    FileOutputStream(File(uscita)).use { soggetto.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    val esito = mapOf("larghezza" to soggetto.width, "altezza" to soggetto.height, "originale" to diritta)
                    principale.post { result.success(esito) }
                }
                .addOnFailureListener(lavoro) { e ->
                    // la prima volta Google Play scarica il modello: lo chiediamo e l'app riprova da sola
                    if (e is MlKitException && e.errorCode == MlKitException.UNAVAILABLE) {
                        ModuleInstall.getClient(this)
                            .installModules(ModuleInstallRequest.newBuilder().addApi(segmentatore).build())
                        principale.post { result.error("MODELLO", "Preparo lo scontorno, solo la prima volta", null) }
                    } else {
                        principale.post { result.error("SCONTORNO", e.message ?: e.toString(), null) }
                    }
                }
        }
    }

    private var ambiente: OrtEnvironment? = null
    private var sessione: OrtSession? = null
    private var sessioneDi: String? = null

    /** La sessione ONNX del modello in [percorso], aperta una volta sola (caricarla costa un paio di secondi). */
    private fun sessione(percorso: String): OrtSession {
        val s = sessione
        if (s != null && sessioneDi == percorso) return s
        s?.close()
        val env = ambiente ?: OrtEnvironment.getEnvironment().also { ambiente = it }
        val opzioni = OrtSession.SessionOptions().apply {
            setIntraOpNumThreads(maxOf(1, minOf(4, Runtime.getRuntime().availableProcessors())))
        }
        return env.createSession(percorso, opzioni).also {
            sessione = it
            sessioneDi = percorso
        }
    }

    /**
     * Scontorno con IS-Net (DIS, licenza Apache 2.0): molto più preciso di ML Kit su vetro, bordi e oggetti
     * qualsiasi. Il modello guarda la foto a 1024×1024; la maschera torna alla misura della foto e la
     * pulizia toglie solo pezzetti staccati e velature. Stesse uscite di [scontorna].
     */
    private fun scontornaIsNet(percorso: String, latoMax: Int, uscita: String, modello: String, result: MethodChannel.Result) {
        lavoro.execute {
            try {
                val foto = caricaDiritta(percorso, latoMax)
                val diritta = uscita.removeSuffix(".png") + "-originale.jpg"
                FileOutputStream(File(diritta)).use { foto.compress(Bitmap.CompressFormat.JPEG, 94, it) }
                val lato = 1024
                val piccola = Bitmap.createScaledBitmap(foto, lato, lato, true)
                val px = IntArray(lato * lato)
                piccola.getPixels(px, 0, lato, 0, 0, lato, lato)
                if (piccola !== foto) piccola.recycle()
                // ingresso: RGB in [−0,5, 0,5], canali separati (1×3×1024×1024)
                val ingresso = FloatBuffer.allocate(3 * lato * lato)
                val piano = lato * lato
                for (i in 0 until piano) {
                    val c = px[i]
                    ingresso.put(i, ((c shr 16) and 0xFF) / 255f - .5f)
                    ingresso.put(piano + i, ((c shr 8) and 0xFF) / 255f - .5f)
                    ingresso.put(2 * piano + i, (c and 0xFF) / 255f - .5f)
                }
                val s = sessione(modello)
                val env = ambiente!!
                val maschera = FloatArray(piano)
                OnnxTensor.createTensor(env, ingresso, longArrayOf(1, 3, lato.toLong(), lato.toLong())).use { t ->
                    s.run(mapOf(s.inputNames.first() to t)).use { r ->
                        val fb = (r[0] as OnnxTensor).floatBuffer
                        fb.rewind()
                        fb.get(maschera)
                    }
                }
                var mi = Float.MAX_VALUE
                var ma = -Float.MAX_VALUE
                for (v in maschera) {
                    if (v < mi) mi = v
                    if (v > ma) ma = v
                }
                if (ma - mi < 1e-3f) {
                    principale.post { result.error("VUOTO", "Nella foto non trovo un soggetto da ritagliare", null) }
                    return@execute
                }
                for (i in 0 until piano) maschera[i] = (maschera[i] - mi) / (ma - mi)
                pulisci(maschera, lato)
                // la maschera come immagine (alfa), poi ingrandita alla misura della foto con filtro
                val mpx = IntArray(piano)
                for (i in 0 until piano) {
                    val a = (maschera[i] * 255f).toInt().coerceIn(0, 255)
                    mpx[i] = (a shl 24) or 0xFFFFFF
                }
                val mPiccola = Bitmap.createBitmap(mpx, lato, lato, Bitmap.Config.ARGB_8888)
                val w = foto.width
                val h = foto.height
                val mGrande = Bitmap.createScaledBitmap(mPiccola, w, h, true)
                mPiccola.recycle()
                val fpx = IntArray(w * h)
                foto.getPixels(fpx, 0, w, 0, 0, w, h)
                // a 3072 px ogni copia della foto pesa quasi 30 MB: si libera appena possibile
                foto.recycle()
                val apx = IntArray(w * h)
                mGrande.getPixels(apx, 0, w, 0, 0, w, h)
                mGrande.recycle()
                var pieni = 0
                for (i in 0 until w * h) {
                    val a = (apx[i] ushr 24) and 0xFF
                    if (a > 128) pieni++
                    fpx[i] = (a shl 24) or (fpx[i] and 0xFFFFFF)
                }
                if (pieni < w * h / 1000) {
                    principale.post { result.error("VUOTO", "Nella foto non trovo un soggetto da ritagliare", null) }
                    return@execute
                }
                val ritaglio = Bitmap.createBitmap(fpx, w, h, Bitmap.Config.ARGB_8888)
                FileOutputStream(File(uscita)).use { ritaglio.compress(Bitmap.CompressFormat.PNG, 100, it) }
                ritaglio.recycle()
                val esito = mapOf("larghezza" to w, "altezza" to h, "originale" to diritta)
                principale.post { result.success(esito) }
            } catch (e: Throwable) {
                // modello rovinato, memoria che non basta…: la foto si scontorna lo stesso, con ML Kit
                scontorna(percorso, latoMax, uscita, result)
            }
        }
    }

    /**
     * Pulisce la maschera del modello (valori 0–1, [lato]×[lato]): via le velature (ombre e riflessi presi a metà)
     * e i pezzetti staccati molto più piccoli del soggetto. Gli oggetti grandi a parte restano (un set di prodotti).
     */
    private fun pulisci(m: FloatArray, lato: Int) {
        val n = lato * lato
        // pezzi pieni (> 0,5) collegati fra loro
        val pezzo = IntArray(n)
        val aree = ArrayList<Int>()
        aree.add(0)
        val coda = IntArray(n)
        for (s in 0 until n) {
            if (m[s] <= .5f || pezzo[s] != 0) continue
            val id = aree.size
            var testa = 0
            var fine = 0
            coda[fine++] = s
            pezzo[s] = id
            while (testa < fine) {
                val p = coda[testa++]
                val x = p % lato
                val y = p / lato
                if (x > 0 && m[p - 1] > .5f && pezzo[p - 1] == 0) { pezzo[p - 1] = id; coda[fine++] = p - 1 }
                if (x < lato - 1 && m[p + 1] > .5f && pezzo[p + 1] == 0) { pezzo[p + 1] = id; coda[fine++] = p + 1 }
                if (y > 0 && m[p - lato] > .5f && pezzo[p - lato] == 0) { pezzo[p - lato] = id; coda[fine++] = p - lato }
                if (y < lato - 1 && m[p + lato] > .5f && pezzo[p + lato] == 0) { pezzo[p + lato] = id; coda[fine++] = p + lato }
            }
            aree.add(fine)
        }
        val grande = aree.maxOrNull() ?: 0
        if (grande == 0) return
        // i pezzi da tenere, allargati di qualche pixel per non tagliare il bordo morbido
        val tieni = BooleanArray(n)
        for (p in 0 until n) if (pezzo[p] != 0 && aree[pezzo[p]] * 100 >= grande) tieni[p] = true
        val vicino = BooleanArray(n)
        val r = 6
        for (y in 0 until lato) {
            var ultimo = -1000
            for (x in 0 until lato) { if (tieni[y * lato + x]) ultimo = x; if (x - ultimo <= r) vicino[y * lato + x] = true }
            ultimo = 1000 + lato
            for (x in lato - 1 downTo 0) { if (tieni[y * lato + x]) ultimo = x; if (ultimo - x <= r) vicino[y * lato + x] = true }
        }
        val vicino2 = BooleanArray(n)
        for (x in 0 until lato) {
            var ultimo = -1000
            for (y in 0 until lato) { if (vicino[y * lato + x]) ultimo = y; if (y - ultimo <= r) vicino2[y * lato + x] = true }
            ultimo = 1000 + lato
            for (y in lato - 1 downTo 0) { if (vicino[y * lato + x]) ultimo = y; if (ultimo - y <= r) vicino2[y * lato + x] = true }
        }
        for (p in 0 until n) {
            // lontano dal soggetto via tutto; vicino si tiene la maschera del modello com'è (solo le velature
            // quasi invisibili si tolgono): stringerla bucava i riflessi dei prodotti lucidi
            m[p] = if (vicino2[p] && m[p] >= .06f) m[p] else 0f
        }
    }

    /** Apre la foto rimpicciolita (lato lungo ≤ latoMax) e girata come la si vede (EXIF). */
    private fun caricaDiritta(percorso: String, latoMax: Int): Bitmap {
        val misure = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(percorso, misure)
        var campione = 1
        while (maxOf(misure.outWidth, misure.outHeight) / (campione * 2) >= latoMax) campione *= 2
        val opzioni = BitmapFactory.Options().apply {
            inSampleSize = campione
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        var foto = BitmapFactory.decodeFile(percorso, opzioni) ?: throw IllegalArgumentException("formato non letto")
        val lungo = maxOf(foto.width, foto.height)
        val matrice = Matrix()
        if (lungo > latoMax) matrice.postScale(latoMax.toFloat() / lungo, latoMax.toFloat() / lungo)
        when (ExifInterface(percorso).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrice.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrice.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrice.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrice.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrice.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { matrice.postRotate(90f); matrice.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_TRANSVERSE -> { matrice.postRotate(270f); matrice.postScale(-1f, 1f) }
        }
        if (!matrice.isIdentity) {
            val girata = Bitmap.createBitmap(foto, 0, 0, foto.width, foto.height, matrice, true)
            if (girata !== foto) foto.recycle()
            foto = girata
        }
        return foto
    }
}
