import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing config is read from android/key.properties (git-ignored).
// When that file is absent (CI, fresh clone) the release build falls back to
// debug signing so it still compiles.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.flowa.flowa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (uses Java 8+ APIs on older devices).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Google Play application id (CLAUDE.md). Note: differs from the Kotlin
        // namespace above, which is fine.
        applicationId = "com.flowa.app"
        // Phone auth + flutter_local_notifications need a reasonably recent API.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// The app has NO native C++ code, but Flutter's Gradle plugin attaches an empty
// CMake build to every app (only to make AGP download the NDK). AGP then runs a
// `configureCMake*` task whose metadata file gets locked on Windows
// ("generate_cxx_metadata_*_timing.txt ... used by another process"), failing
// the build intermittently. We drop that empty CMake build entirely here, after
// Flutter has configured the DSL, so the CMake task is never created. The NDK is
// still resolved on demand from `ndkVersion` when a plugin actually needs it.
androidComponents {
    finalizeDsl { extension ->
        extension.externalNativeBuild.cmake.path = null
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
