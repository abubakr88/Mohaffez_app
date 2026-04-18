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

// Load release signing config from android/key.properties (never commit this file)
val keystoreProperties = Properties().apply {
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.imam.mohaffez_app"
    compileSdk = 36

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: ""
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: ""
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword") ?: ""
        }
    }

    defaultConfig {
        applicationId = "com.imam.mohaffez_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
