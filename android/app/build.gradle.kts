plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.impetus.impetus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.impetus.impetus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Explicit floor required by workmanager (>= 21); pinned per spec so
        // the contract does not silently change with Flutter's default.
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing reads credentials from the environment so keystore
    // material is never committed. CI decodes KEYSTORE_BASE64 into
    // /tmp/keystore.jks and exports the four env vars; local builds without
    // secrets fall back to debug signing.
    signingConfigs {
        create("release") {
            val env = System.getenv()
            // storeFile stays null (and the config unused) when the env
            // vars are absent, so local builds fall back to debug signing.
            storeFile = env["KEYSTORE_PATH"]?.let { file(it) }
            storePassword = env["KEYSTORE_PASSWORD"]
            keyAlias = env["KEY_ALIAS"]
            keyPassword = env["KEY_PASSWORD"]
        }
    }

    buildTypes {
        release {
            val env = System.getenv()
            val hasSigningEnv = env["KEYSTORE_PATH"] != null &&
                env["KEYSTORE_PASSWORD"] != null &&
                env["KEY_ALIAS"] != null &&
                env["KEY_PASSWORD"] != null
            signingConfig = if (hasSigningEnv) {
                signingConfigs.getByName("release")
            } else {
                // Local builds without secrets still work via debug keys.
                signingConfigs.getByName("debug")
            }
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
