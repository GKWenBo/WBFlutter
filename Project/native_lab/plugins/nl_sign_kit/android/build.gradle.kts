group = "com.wenbo.nl_sign_kit"
version = "1.0-SNAPSHOT"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // 与 app 侧 AGP 版本保持一致（见 app/android/settings.gradle.kts）。
        classpath("com.android.tools.build:gradle:9.0.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.wenbo.nl_sign_kit"

    compileSdk = 36

    // ★ FFI 插件的关键：让 AGP 用 NDK 编译 src/CMakeLists.txt，
    // 产物 libnl_sign_kit.so 会随 AAR 合进 APK。
    // 版本与 Flutter 3.44 的 flutter.ndkVersion 一致（见 FlutterExtension.kt）。
    ndkVersion = "28.2.13676358"

    externalNativeBuild {
        cmake {
            // 和官方 plugin_ffi 模板一致：CMake 放在 src/，Android/iOS 共用一份 C。
            path = file("../src/CMakeLists.txt")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
    }
}
