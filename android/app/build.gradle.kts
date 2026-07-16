plugins {
    id("com.android.application")
    id("com.huawei.agconnect")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.steffen.disponere"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.steffen.disponere"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // OAuth-Rueckkanal fuer flutter_appauth: umgedrehte Client-ID.
        // Muss zeichengleich zu GoogleConfig.redirectScheme sein
        // (lib/config/google_config.dart, git-ignoriert).
        manifestPlaceholders["appAuthRedirectScheme"] =
            "com.googleusercontent.apps.505497602062-hk0ti6m40nkl2ean6ruqca6roqs6fb0j"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.huawei.agconnect:agconnect-core:1.5.2.300")
}