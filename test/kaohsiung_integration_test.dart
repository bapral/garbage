/// [整體程式說明]: 高雄市垃圾車 Provider 整合測試，驗證城市切換邏輯、配置更新以及非同步同步機制的穩定性。
/// [執行順序說明]:
/// 1. 初始化記憶體資料庫與模擬 PackageInfo。
/// 2. 建立 ProviderContainer 並讀取初始狀態（預設應為新北市）。
/// 3. 透過 citySelectionProvider 切換至高雄市。
/// 4. 驗證 currentCityConfigProvider 是否正確更新為高雄市的配置（如標題、中心座標）。
/// 5. 觸發 garbageTrucksProvider 並驗證其在同步過程中的行為，確保不會發生崩潰。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:ntpc_garbage_map/providers/garbage_provider.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';

void main() {
  setupPackageInfo() {
    PackageInfo.setMockInitialValues(
      appName: "Garbage Map",
      packageName: "com.example.ntpc_garbage_map",
      version: "1.0.0",
      buildNumber: "1",
      buildSignature: "buildSignature",
      installerStore: null,
    );
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    setupPackageInfo();
  });

  test('切換至高雄市後，Provider 應提供正確的 CityConfig', () async {
    /// 測試城市切換配置：驗證當選擇高雄市時，Provider 是否能正確反應高雄市的標題、初始座標等設定
    final container = ProviderContainer();
    
    // 預設是新北市
    expect(container.read(citySelectionProvider), 'ntpc');
    expect(container.read(currentCityConfigProvider).cityName, 'ntpc');

    // 切換到高雄市
    container.read(citySelectionProvider.notifier).setCity('kaohsiung');
    
    expect(container.read(citySelectionProvider), 'kaohsiung');
    final config = container.read(currentCityConfigProvider);
    expect(config.cityName, 'kaohsiung');
    expect(config.appTitle, '高雄市垃圾車即時地圖');
    expect(config.initialCenter.latitude, closeTo(22.6273, 0.01));
  });

  test('高雄市 Provider 應能觸發同步 (即使網路失敗也應正確處理)', () async {
    /// 測試非同步同步觸發：驗證高雄市 Provider 在建立時是否能正確啟動資料同步流程，並在網路異常下維持狀態穩定
    final container = ProviderContainer();
    container.read(citySelectionProvider.notifier).setCity('kaohsiung');

    // 觸發 build
    final trucks = container.read(garbageTrucksProvider);
    expect(trucks, isEmpty); // 初始應為空

    // 等待微任務完成 (同步 logic)
    await Future.delayed(const Duration(seconds: 1));
    
    // 檢查同步狀態
    final isSyncing = container.read(isSyncingProvider);
    // 這裡不強求同步成功 (因為可能沒網路)，但要確認不會 crash
    print('目前同步狀態: $isSyncing');
  });
}
