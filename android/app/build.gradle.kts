plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "it.pietrodefilippis.tkfoto"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "it.pietrodefilippis.tkfoto"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // solo i processori dei telefoni: ONNX Runtime porterebbe anche x86/x86_64 (20 MB in più);
    // ndk.abiFilters non basta, il plugin di Flutter lo sovrascrive
    packaging {
        jniLibs {
            excludes += listOf("lib/x86/**", "lib/x86_64/**")
        }
    }

    // chiave fissa di tk-foto, FUORI dal repo: in CI arriva dal segreto ANDROID_KEYSTORE_B64 (percorso nella
    // variabile ANDROID_KEYSTORE). La firma non cambia tra una versione e l'altra, così gli aggiornamenti si
    // installano sopra. Senza la variabile (rami senza segreto, chi compila dal sorgente) = chiave di debug di Flutter.
    val chiaveTk = System.getenv("ANDROID_KEYSTORE")?.takeIf { it.isNotBlank() && file(it).exists() }
    signingConfigs {
        if (chiaveTk != null) {
            create("tk") {
                storeFile = file(chiaveTk)
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
    }

    // versione per il Play Store (play.yml, TK_PLAY=1): il manifest di src/play toglie il permesso di installare APK.
    // Stesso pacchetto e stessa chiave: chi ha l'app da Dropbox si aggiorna da Play senza disinstallare.
    if (System.getenv("TK_PLAY") == "1") {
        sourceSets.getByName("release").manifest.srcFile("src/play/AndroidManifest.xml")
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("tk") ?: signingConfigs.getByName("debug")
            // R8 non regge ML Kit (come in tk-pdf)
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // scontorno sul telefono (il modello lo scarica Google Play una volta sola)
    implementation("com.google.android.gms:play-services-mlkit-subject-segmentation:16.0.0-beta1")
    implementation("com.google.android.gms:play-services-base:18.5.0")
    // scontorno buono: IS-Net (modello open source, scaricato dall'app al primo avvio) con ONNX Runtime
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.20.0")
    // foto girate come le ha scattate il telefono
    implementation("androidx.exifinterface:exifinterface:1.3.7")
}

flutter {
    source = "../.."
}
