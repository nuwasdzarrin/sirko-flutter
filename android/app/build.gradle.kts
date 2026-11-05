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
        manifestPlaceholders["appLabel"] = "Sirko"
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
        debug {
            // Debug terpasang BERDAMPINGAN dengan rilis (ID paket & signature beda)
            // agar uji di HP tak perlu uninstall app rilis beserta datanya.
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "Sirko Dev"
        }
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

// --- Hasil build release → KasirWarung/apk-release ---
// Build dir dialihkan ke C:/fbuild (lihat android/build.gradle.kts, masalah
// spasi di path). Agar APK mudah ditemukan, tiap `assembleRelease` (termasuk
// `flutter build apk --release [--split-per-abi]`) menyalin APK ke folder
// apk-release dengan nama Sirko-<versi>-b<build>[-<abi>].apk.
val apkReleaseDir = rootProject.file("../../apk-release")
android.applicationVariants.configureEach {
    val variant = this
    // Tool `flutter build apk` mencari APK di <proyek>/build/app/outputs/
    // flutter-apk; tanpa salinan ini ia melapor "failed to produce an .apk"
    // (palsu) karena build dir dialihkan ke C:/fbuild. Berlaku semua varian.
    // Dilewati bila build dir sudah di lokasi standar (tak dialihkan).
    val flutterToolApkDir = rootProject.file("../build/app/outputs/flutter-apk")
    val apkDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
    if (apkDir.canonicalPath != flutterToolApkDir.canonicalPath) {
        val copyForFlutterTool = tasks.register<Copy>(
            "copy${variant.name.replaceFirstChar { it.uppercase() }}ApkForFlutterTool"
        ) {
            from(apkDir)
            into(flutterToolApkDir)
        }
        variant.assembleProvider.configure { finalizedBy(copyForFlutterTool) }
    }

    if (variant.buildType.name != "release") return@configureEach
    val copyApk = tasks.register<Copy>(
        "copy${variant.name.replaceFirstChar { it.uppercase() }}ApkToApkRelease"
    ) {
        from(variant.outputs.map { it.outputFile })
        into(apkReleaseDir)
        rename { fileName ->
            // app-release.apk → "" ; app-arm64-v8a-release.apk → "-arm64-v8a"
            val abi = fileName.removePrefix("app-").removeSuffix(".apk")
                .removeSuffix("-release").removeSuffix("release")
            val suffix = if (abi.isEmpty()) "" else "-$abi"
            "Sirko-${variant.versionName}-b${variant.versionCode}$suffix.apk"
        }
    }
    variant.assembleProvider.configure { finalizedBy(copyApk) }
}

// Kompilasi Dart (app.so) SELALU diulang: dengan build dir di luar proyek,
// Gradle pernah menganggapnya up-to-date sehingga APK baru berisi kode lama.
tasks.matching { it.name.startsWith("compileFlutterBuild") }.configureEach {
    outputs.upToDateWhen { false }
}

dependencies {
    // Orchestrator runtime untuk instrumentasi Patrol.
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
