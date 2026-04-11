/**
 * 目的：Gradle 專案結構與插件管理配置 (Project Structure & Plugin Management Configuration)
 * 作用：定義專案中包含哪些模組（如 `:app`），設定 Flutter SDK 的載入路徑，並管理 Gradle 插件的版本及儲存庫來源。
 * 格式與用法：使用 Kotlin DSL (Gradle) 編寫。包含 `pluginManagement` 和 `plugins` 區塊，負責在建置初期載入必要的工具。
 */

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
