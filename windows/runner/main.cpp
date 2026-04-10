#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// Windows 應用程序的進入點
int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // 如果存在控制台（例如 'flutter run'），則附加到控制台；
  // 或者在調試器運行時創建一個新控制台。
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // 初始化 COM 組件，以便在庫或插件中使用。
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // 指向包含 Flutter 資產的數據目錄
  flutter::DartProject project(L"data");

  // 獲取命令行參數並傳遞給 Flutter 引擎
  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // 創建 Flutter 窗口
  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"ntpc_garbage_map", origin, size)) {
    return EXIT_FAILURE;
  }
  // 設置窗口關閉時退出應用程序
  window.SetQuitOnClose(true);

  // 標準 Windows 消息循環
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // 反初始化 COM
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
