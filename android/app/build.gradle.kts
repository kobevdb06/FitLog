import java.util.Properties

// The release keystore is never committed. Point at it from android/key.properties,
// which git ignores; see key.properties.example for the four lines it needs.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "be.fitlog.app"
    // flutter_secure_storage 11 compiles against API 37 and AGP refuses a
    // lower compileSdk for its consumers.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time on API 23 devices.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "be.fitlog.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 23 is the floor for flutter_secure_storage / sqlcipher / biometrics.
        minSdk = flutter.minSdkVersion
        targetSdk = 37
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key so a fresh checkout still builds, but says
            // so: an APK signed with it must never be handed to anyone. That key is
            // public knowledge, and Android lets anything signed with it replace the
            // app - which here means replacing the encrypted database.
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
                println("")
                println("  !! FitLog: no android/key.properties. This release APK is signed")
                println("     with the debug key: fine to run, never to hand out.")
                println("     See android/key.properties.example.")
                println("")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        jniLibs {
            // sqlcipher_flutter_libs ships prebuilt .so files that must not be stripped.
            useLegacyPackaging = false
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
