import java.io.FileInputStream
import java.util.Properties
import com.android.build.api.dsl.ApplicationExtension

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keyFileCandidates = listOf(
    rootProject.file("key.properties"),
    project.file("key.properties"),
    rootProject.file("app/key.properties"),
    file("../key.properties")
)
val keystorePropertiesFile = keyFileCandidates.firstOrNull { it.exists() }
if (keystorePropertiesFile != null) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

configure<ApplicationExtension> {
    namespace = "com.tphimx.tphimx_setup"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Application ID registered on Google Play Console
        applicationId = "com.tphimx.tphimx_setup"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val alias = keystoreProperties.getProperty("keyAlias")
            val keyPass = keystoreProperties.getProperty("keyPassword")
            val storePass = keystoreProperties.getProperty("storePassword")
            val storeFilePath = keystoreProperties.getProperty("storeFile")

            if (!storeFilePath.isNullOrEmpty()) {
                val candidateFiles = listOf(
                    file(storeFilePath),
                    rootProject.file(storeFilePath),
                    rootProject.file("app/$storeFilePath")
                )
                val targetKeystore = candidateFiles.firstOrNull { it.exists() }
                if (targetKeystore != null) {
                    storeFile = targetKeystore
                }
            }
            keyAlias = alias
            keyPassword = keyPass
            storePassword = storePass
        }
    }

    buildTypes {
        release {
            val relConfig = signingConfigs.getByName("release")
            val isValidReleaseConfig = relConfig.storeFile?.exists() == true &&
                    !relConfig.keyAlias.isNullOrEmpty() &&
                    !relConfig.keyPassword.isNullOrEmpty() &&
                    !relConfig.storePassword.isNullOrEmpty()

            if (isValidReleaseConfig) {
                println("===> [SIGNING_CONFIG] Release signing configuration successfully applied using storeFile: ${relConfig.storeFile?.absolutePath}")
                signingConfig = relConfig
            } else {
                throw GradleException(
                    "BUILD FAILED: Release signing configuration is invalid or missing.\n" +
                    "key.properties exists: ${keystorePropertiesFile != null}\n" +
                    "storeFile exists: ${relConfig.storeFile?.exists()}\n" +
                    "Make sure key.properties contains keyAlias, keyPassword, storePassword, storeFile and points to a valid keystore."
                )
            }
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
