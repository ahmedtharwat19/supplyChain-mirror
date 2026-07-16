import java.util.Properties
import java.io.FileInputStream
import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.firebase.firebase-perf")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
println("=========================================")
println("Flutter compileSdk: ${flutter.compileSdkVersion}")
println("Flutter targetSdk: ${flutter.targetSdkVersion}")
println("Flutter minSdk: ${flutter.minSdkVersion}")
println("=========================================")
android {
    namespace = "com.puresip.purchasing"
    compileSdk = 36  // ✅ تم التحديث إلى 36
    
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                storeFile     = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias      = keystoreProperties["keyAlias"] as String
                keyPassword   = keystoreProperties["keyPassword"] as String
            }
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val outputImpl = this as ApkVariantOutputImpl
            val appName    = "puresip_purchasing"
            val ver        = variant.versionName
            val code       = variant.versionCode
            outputImpl.outputFileName = "${appName}_v${ver}_${code}.apk"
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId   = "com.puresip.purchasing"
        minSdk = flutter.minSdkVersion
        targetSdk       = 34  // ✅ يبقى 34 (runtime behavior)
        multiDexEnabled = true
        versionCode     = flutter.versionCode.toInt()
        versionName     = flutter.versionName
    }

    buildTypes {
        release {
            if (keystoreProperties.isNotEmpty()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled   = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled   = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // ✅ Kotlin
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.9.22")
    implementation("androidx.core:core-ktx:1.13.1")
    
    // ✅ MultiDex
    implementation("androidx.multidex:multidex:2.0.1")
    
    // ✅ Firebase
    implementation(platform("com.google.firebase:firebase-bom:34.13.0"))
    implementation("com.google.firebase:firebase-perf")
    implementation("com.google.firebase:firebase-analytics")
    
    // ✅ Permission Handler
    implementation("androidx.core:core:1.13.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
