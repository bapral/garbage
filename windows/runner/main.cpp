#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

/**
 * 目的：Windows 桌面應用程式的進入點程式碼 (Main Entry Point)
 * 作用：初始化 Win32 視窗環境，啟動 Flutter 引擎並載入應用資產，並處理標準的 Windows 訊息循環 (Message Loop) 以維持應用程式執行。
 * 格式與用法：C++ 檔案，包含 `wWinMain` 進入點。開發者可以在此處自定義視窗的初始位置、大小、標題，或加入特定的 Win32 API 呼叫。
 */

// Windows 應用程式的進入點
int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // 如果存在控制台（例如透過 'flutter run' 啟動），則附加到控制台；
  // 或者在偵錯器執行時建立一個新控制台。
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // 初始化 COM 元件，以便在程式庫或插件中使用。
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // 指向包含 Flutter 資產的數據目錄
  flutter::DartProject project(L"data");

  // 獲取命令列參數並傳遞給 Flutter 引擎
  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // 建立 Flutter 視窗
  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"ntpc_garbage_map", origin, size)) {
    return EXIT_FAILURE;
  }
  // 設定視窗關閉時退出應用程式
  window.SetQuitOnClose(true);

  // 標準 Windows 訊息循環
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // 反初始化 COM
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
