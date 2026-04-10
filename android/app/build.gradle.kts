plugins {
    // Android 應用程序插件
    id("com.android.application")
    // Kotlin Android 插件
    id("kotlin-android")
    // Flutter Gradle 插件必須在 Android 和 Kotlin 插件之後應用
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // 應用的命名空間，用於生成 R 和 BuildConfig 類
    namespace = "com.example.ntpc_garbage_map"
    // 編譯時使用的 Android SDK 版本
    compileSdk = flutter.compileSdkVersion
    // NDK 版本，由 Flutter 指定
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // 指定編譯 Java 代碼時使用的源代碼兼容性版本
        sourceCompatibility = JavaVersion.VERSION_17
        // 指定生成的 Java 字節碼的目標兼容性版本
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // 指定 Kotlin 編譯後的 JVM 目標版本
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // 應用的唯一包名 (Application ID)
        applicationId = "com.example.ntpc_garbage_map"
        // 最低支持的 Android SDK 版本
        minSdk = flutter.minSdkVersion
        // 目標 Android SDK 版本
        targetSdk = flutter.targetSdkVersion
        // 應用的版本代碼 (整數)，用於商店版本更新
        versionCode = flutter.versionCode
        // 應用的版本名稱 (字符串)，顯示給用戶看
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
