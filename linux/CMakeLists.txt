# 目的：Linux 平台的專案建置配置 (CMake Build Configuration)
# 作用：管理 Linux 桌面端應用的編譯流程，包括定義執行檔名稱、設定 GTK 應用程式識別碼、處理 PkgConfig 依賴（如 GTK+ 3.0）、配置安裝路徑以及封裝 Flutter 資產。
# 格式與用法：使用 CMake 腳本語言。開發者可在此調整應用程式識別碼 (APPLICATION_ID) 或新增 Linux 特定的系統依賴庫。

cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# 應用的執行檔名稱。
set(BINARY_NAME "ntpc_garbage_map")
# 應用的唯一 GTK 識別碼。
set(APPLICATION_ID "com.example.ntpc_garbage_map")

# 顯式啟用現代 CMake 行為。
cmake_policy(SET CMP0063 NEW)

# 設定從執行檔相對路徑 lib/ 載入依賴庫。
set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# 用於跨平台編譯的根檔案系統設定。
if(FLUTTER_TARGET_PLATFORM_SYSROOT)
  set(CMAKE_SYSROOT ${FLUTTER_TARGET_PLATFORM_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
endif()

# 定義建置組態選項。
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE
    STRING "Flutter build mode" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Profile" "Release")
endif()

# 套用於大多數目標的編譯設定。
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_14)
  target_compile_options(${TARGET} PRIVATE -Wall -Werror)
  target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
  target_compile_definitions(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:NDEBUG>")
endfunction()

# Flutter 庫與工具的建置規則。
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# 系統層級的依賴項。
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

# 應用程式的主要編譯內容；詳見 runner/CMakeLists.txt。
add_subdirectory("runner")

# 執行 Flutter 工具部分的建置。此項不可移除。
add_dependencies(${BINARY_NAME} flutter_assemble)

# 為了確保資產路徑正確，僅安裝後的執行檔能正常開啟。
# 將未打包的執行檔放在子目錄中，以防止誤用。
set_target_properties(${BINARY_NAME}
  PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/intermediates_do_not_run"
)

# 自動生成的插件建置規則。
include(flutter/generated_plugins.cmake)

# === 安裝與打包 (Installation) ===
# 預設情況下，「安裝」會在建置目錄中建立一個可移動的封裝 (Bundle)。
set(BUILD_BUNDLE_DIR "${PROJECT_BINARY_DIR}/bundle")
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

# 每次建置前清理舊的封裝目錄。
install(CODE "
  file(REMOVE_RECURSE \"${BUILD_BUNDLE_DIR}/\")
  " COMPONENT Runtime)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

foreach(bundled_library ${PLUGIN_BUNDLED_LIBRARIES})
  install(FILES "${bundled_library}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endforeach(bundled_library)

# 複製原生資產 (Native Assets)。
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/linux/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# 每次建置時完整重新複製資產目錄。
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# 僅在非 Debug 組態下安裝 AOT 庫。
if(NOT CMAKE_BUILD_TYPE MATCHES "Debug")
  install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()
