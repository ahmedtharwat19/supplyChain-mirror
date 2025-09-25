import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.puresip_purchasing"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    applicationVariants.all {
    val variant = this
        variant.outputs.all {
            val outputImpl = this as ApkVariantOutputImpl
            val appName = "puresip_purchasing"
            val versionName = variant.versionName
            val versionCode = variant.versionCode
            outputImpl.outputFileName = "${appName}_v${versionName}_${versionCode}.apk"
        }
    }
    compileOptions {
        isCoreLibraryDesugaringEnabled = true // ✅ صيغة Kotlin الصحيحة
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.puresip_purchasing"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ الصيغة الصحيحة لـ Kotlin DSL
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    implementation("androidx.core:core-ktx:1.12.0")
    // أضف باقي dependencies هنا بنفس الصيغة
}