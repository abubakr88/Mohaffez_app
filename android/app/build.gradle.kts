import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val dotenv = Properties().apply {
    val envFile = rootProject.file(".env")
    if (envFile.exists()) {
        envFile.inputStream().use { load(it) }
    }
}

val mapsApiKey = System.getenv("GOOGLE_MAPS_API_KEY")?.takeIf { it.isNotBlank() }
    ?: (project.findProperty("GOOGLE_MAPS_API_KEY") as String?)?.takeIf { it.isNotBlank() }
    ?: dotenv.getProperty("GOOGLE_MAPS_API_KEY")?.takeIf { it.isNotBlank() }
    ?: ""

android {
    namespace = "com.imam.mohaffez_app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.imam.mohaffez_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.24")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // Firebase App Check providers
    implementation("com.google.firebase:firebase-appcheck-playintegrity:17.0.1")
    debugImplementation("com.google.firebase:firebase-appcheck-debug:18.0.0")
}
