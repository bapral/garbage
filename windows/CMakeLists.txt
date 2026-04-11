# 目的：Windows 平台的專案建置配置 (CMake Build Configuration)
# 作用：定義 Windows 桌面端應用的編譯規範，包括 C++ 標準、預定義宏（如 UNICODE）、編譯器選項、Flutter 資產目錄路徑，以及安裝打包執行檔時的檔案分配邏輯。
# 格式與用法：使用 CMake 腳本語言。開發者可以在此處設定應用的二進位檔名稱 (BINARY_NAME) 或新增額外的 C++ 依賴庫。

cmake_minimum_required(VERSION 3.14)
project(ntpc_garbage_map LANGUAGES CXX)

# 應用的執行檔名稱。修改此變數可更改生成的執行檔檔名。
set(BINARY_NAME "ntpc_garbage_map")

# 顯式啟用現代 CMake 行為，以避免在新版本 CMake 中出現警告。
cmake_policy(VERSION 3.14...3.25)

# 定義建置組態選項。
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()

# 定義 Profile 建置模式的設定，通常比照 Release 模式。
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# 為所有專案使用 Unicode 編碼。
add_definitions(-DUNICODE -D_UNICODE)

# 套用於大多數目標的編譯設定。
#
# 注意：插件預設會使用此函式，因此新增全域選項時需謹慎。
# 通常建議將新選項套用於特定的目標，而非直接修改此全域函式。
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100" /utf-8)
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter 庫與工具的建置規則。
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# 應用程式的主要編譯內容；詳見 runner/CMakeLists.txt。
add_subdirectory("runner")

# 自動生成的插件建置規則，負責編譯插件並將其加入應用程式。
include(flutter/generated_plugins.cmake)

# === 安裝與打包 (Installation) ===
# 支援檔案會被複製到執行檔旁的目錄，以便直接執行。
# 這樣做而非製作獨立包（如 Linux），是為了確保在 Visual Studio 中能正常建置與偵錯。
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# 將「安裝」步驟設為預設，因為它是執行應用的必要前提。
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# 複製由 build.dart 從各個套件提供的原生資產 (Native Assets)。
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# 每次建置時完整重新複製資產目錄，以避免舊檔案殘留。
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# 僅在非 Debug 組態下安裝 AOT 編譯庫。
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
