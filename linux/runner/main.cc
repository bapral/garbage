#include "my_application.h"

// Linux 應用程序的進入點
int main(int argc, char** argv) {
  // 創建一個新的應用程序實例
  g_autoptr(MyApplication) app = my_application_new();
  // 運行 Gtk 應用程序
  return g_application_run(G_APPLICATION(app), argc, argv);
}
