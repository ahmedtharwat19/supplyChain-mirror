// buildscript يجب أن يكون أولاً
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20") // ✅ التحديث هنا
        classpath("com.google.gms:google-services:4.4.3")
    }
}

// ثم plugins
plugins {
    id("com.android.application") apply false
    id("org.jetbrains.kotlin.android")  apply false
    id("com.google.gms.google-services") version "4.4.3" apply false
    id("dev.flutter.flutter-gradle-plugin") apply false
    id("com.google.firebase.firebase-perf") version "1.4.2" apply false     
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// تغيير مجلد البناء
val newBuildDir: File = file("${rootDir}/../build")
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = File(newBuildDir, project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

