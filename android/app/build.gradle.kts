plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sirko.sirko"
    // compileSdk 36 & NDK 27 diperlukan oleh plugin (mobile_scanner/CameraX,
    // sqlite3_flutter_libs, shared_preferences). AGP dinaikkan ke 8.9.1 di
    // settings.gradle.kts agar mendukung compileSdk 36.
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.sirko.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23 // mobile_scanner butuh minimal API 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // --- Patrol (E2E native Android) ---
        // Runner instrumentasi Patrol menggantikan AndroidJUnitRunner default.
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    // Patrol butuh AndroidX Test Orchestrator agar tiap skenario dart dijalankan
    // dalam proses bersih (mencegah state bocor antar-skenario).
    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Orchestrator runtime untuk instrumentasi Patrol.
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
