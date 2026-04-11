import Flutter
import UIKit

/**
 * 目的：iOS 應用程式的進入點與生命週期管理 (Application Delegate)
 * 作用：負責處理 iOS 原生應用程式的生命週期事件，初始化 Flutter 引擎並向原生系統註冊所有 Flutter 插件，確保 Flutter 與 iOS 底層的溝通。
 * 格式與用法：使用 Swift 編寫，繼承自 `FlutterAppDelegate` 並符合 `FlutterImplicitEngineDelegate` 協議。通常用於加入第三方 SDK 的原生初始化邏輯。
 */

// @main 標記為應用程式的入口點
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // 當應用程式啟動完成後調用
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 調用父類別的 didFinishLaunchingWithOptions 以完成 Flutter 的初始化
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 當隱式 Flutter 引擎初始化完成後調用，用於註冊插件
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
