import Flutter
import UIKit

// @main 標記為應用程序的入口點
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // 當應用程序啟動完成後調用
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 調用父類的 didFinishLaunchingWithOptions 以完成 Flutter 的初始化
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 當隱式 Flutter 引擎初始化完成後調用，用於註冊插件
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
