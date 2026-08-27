import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ─────────────────────────────────────────────────────────────────────────────
// FIRMA DE RELEASE
//
// Las contraseñas viven en android/key.properties, que está en .gitignore y
// NUNCA se sube a git. El archivo .jks tampoco: guárdalo FUERA de la carpeta
// del proyecto.
//
// Si key.properties no existe (otro computador, un clon recién bajado), el
// build no falla: cae a la firma de debug. Así `flutter run` sigue sirviendo
// para desarrollar, y solo quien tenga el keystore puede generar un AAB
// publicable.
// ─────────────────────────────────────────────────────────────────────────────
val keystorePropertiesFile = rootProject.file("key.properties")
val hayKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (hayKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.serenityapp.parental"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // ⚠️ PERMANENTE una vez subas el primer bundle a Google Play.
        // No se puede cambiar nunca más sin publicar una app nueva desde cero,
        // perdiendo descargas, reseñas y suscriptores.
        applicationId = "com.serenityapp.parental"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hayKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hayKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Sin keystore no se puede publicar, pero sí compilar y probar.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    // Dependencias nativas de Android para Auth y Firestore
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.android.gms:play-services-auth:21.2.0")
}
