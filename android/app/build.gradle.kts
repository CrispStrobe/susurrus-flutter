plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin applies after Android + Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.crispstrobe.crisperweaver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.crispstrobe.crisperweaver"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    // Pre-built libwhisper.so (+ sibling CrispASR backend libs) are dropped
    // into src/main/jniLibs/<abi>/ by CrispASR/build-android.sh.
    sourceSets {
        named("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    packaging {
        jniLibs {
            // Other plugins may ship libc++_shared; keep the first.
            pickFirsts += "**/libc++_shared.so"
        }
    }

    buildTypes {
        release {
            // Signed debug for now so `flutter run --release` works without a
            // keystore. Swap in a release signingConfig before publishing.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
