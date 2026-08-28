import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cbi.CBIHr"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.cbi.cbihr"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Custom URL scheme for the Microsoft Entra ID OAuth redirect (flutter_appauth).
        // Must match ENTRA_REDIRECT_URL in lib/src/config/app_config.dart
        // (com.example.cbiapp://oauthredirect) and the redirect URI registered in Azure.
        manifestPlaceholders["appAuthRedirectScheme"] = "com.cbi.cbiapp"
    }

    signingConfigs {
        create("release") {
            val envKeystorePath = providers.environmentVariable("ANDROID_KEYSTORE_PATH").orNull
                ?: providers.gradleProperty("ANDROID_KEYSTORE_PATH").orNull
            val envStorePassword = providers.environmentVariable("ANDROID_KEYSTORE_PASSWORD").orNull
                ?: providers.gradleProperty("ANDROID_KEYSTORE_PASSWORD").orNull
            val envKeyAlias = providers.environmentVariable("ANDROID_KEY_ALIAS").orNull
                ?: providers.gradleProperty("ANDROID_KEY_ALIAS").orNull
            val envKeyPassword = providers.environmentVariable("ANDROID_KEY_PASSWORD").orNull
                ?: providers.gradleProperty("ANDROID_KEY_PASSWORD").orNull

            if (!envKeystorePath.isNullOrBlank() && !envStorePassword.isNullOrBlank() && !envKeyAlias.isNullOrBlank() && !envKeyPassword.isNullOrBlank()) {
                storeFile = file(envKeystorePath)
                storePassword = envStorePassword
                keyAlias = envKeyAlias
                keyPassword = envKeyPassword
            } else {
                val keyPropertiesPath = providers.environmentVariable("KEY_PROPERTIES_PATH").orNull
                    ?: rootProject.file("key.properties").absolutePath
                val keystorePropertiesFile = file(keyPropertiesPath)
                if (keystorePropertiesFile.exists()) {
                    val keystoreProperties = Properties()
                    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                    val rawStoreFile = keystoreProperties.getProperty("storeFile")
                    if (!rawStoreFile.isNullOrBlank()) {
                        val resolvedFile = file(rawStoreFile)
                        storeFile = if (resolvedFile.exists()) resolvedFile else rootProject.file(rawStoreFile)
                    }
                    storePassword = keystoreProperties.getProperty("storePassword")
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
