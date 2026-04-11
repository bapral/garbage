/**
 * 目的：Android 應用程式層級的建置配置 (App-Level Build Configuration)
 * 作用：詳細配置 Android 應用程式的建置細節，包括應用程式 ID、SDK 版本、編譯選項、簽名設定以及與 Flutter 的整合邏輯。
 * 格式與用法：使用 Kotlin DSL (Gradle) 編寫。包含 `android` 和 `flutter` 配置區塊，用於定義原生 Android 屬性及 Flutter 專屬屬性。
 */

plugins {
    // Android 應用程式插件
    id("com.android.application")
    // Kotlin Android 插件
    id("kotlin-android")
    // Flutter Gradle 插件必須在 Android 和 Kotlin 插件之後應用
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // 應用的命名空間，用於產生 R 和 BuildConfig 類別
    namespace = "com.example.ntpc_garbage_map"
    // 編譯時使用的 Android SDK 版本
    compileSdk = flutter.compileSdkVersion
    // NDK 版本，由 Flutter 指定
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // 指定編譯 Java 程式碼時使用的原始碼相容性版本
        sourceCompatibility = JavaVersion.VERSION_17
        // 指定產生的 Java 位元組碼的目標相容性版本
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // 指定 Kotlin 編譯後的 JVM 目標版本
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // 應用的唯一包名 (Application ID)
        applicationId = "com.example.ntpc_garbage_map"
        // 最低支援的 Android SDK 版本
        minSdk = flutter.minSdkVersion
        // 目標 Android SDK 版本
        targetSdk = flutter.targetSdkVersion
        // 應用的版本代碼 (整數)，用於商店版本更新
        versionCode = flutter.versionCode
        // 應用的版本名稱 (字串)，顯示給用戶看
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 發行版配置
            // 目前使用偵錯金鑰簽名，以便 `flutter run --release` 可以正常運作
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    // 指向 Flutter 原始碼的路徑
    source = "../.."
}
