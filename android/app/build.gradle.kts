import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key for Google Play, per machine and out of the repo:
// android/key.properties (gitignored; see key.properties.example) names a
// keystore kept somewhere outside this folder. Without that file a release
// build is signed with the debug key, which runs on a phone but Google Play
// refuses.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.sandit.personalos"
    compileSdk = flutter.compileSdkVersion
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
        applicationId = "com.sandit.personalos"
        // Release builds keep this identity. Debug builds override both the
        // application id and label below so they can live beside production.
        manifestPlaceholders["appLabel"] = "PersonalOS"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            manifestPlaceholders["appLabel"] = "PersonalOS Dev"
        }
        release {
            // The upload key when this machine has one; otherwise the debug
            // key, so `flutter run --release` still works.
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKey) "release" else "debug",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Provides the Theme.AppCompat styles LaunchTheme now extends (local_auth
    // needs them). Declared here so the theme resolves whatever else pulls it in.
    implementation("androidx.appcompat:appcompat:1.7.0")
    // Google's Block Store: keeps sync's data key across reinstalls and onto
    // a new phone restored from this one's backup (sync_key_backup.dart).
    implementation("com.google.android.gms:play-services-auth-blockstore:16.4.0")
}
