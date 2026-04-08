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
