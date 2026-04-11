import Cocoa
import FlutterMacOS

/**
 * 目的：macOS 桌面應用程式的進入點與生命週期管理 (Application Delegate)
 * 作用：負責處理 macOS 原生應用程式的事件，例如視窗關閉行為、狀態保存以及 Flutter 引擎的初始化，確保應用程式與 macOS 系統環境正確互動。
 * 格式與用法：使用 Swift 編寫，繼承自 `FlutterAppDelegate`。開發者可以在此自定義視窗關閉後是否終止應用程式等 macOS 特有行為。
 */

@main
class AppDelegate: FlutterAppDelegate {
  // 設定當最後一個視窗關閉時，是否自動終止應用程式
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  // 設定應用程式是否支援安全的狀態恢復 (State Restoration)
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
