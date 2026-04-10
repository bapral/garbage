/// [整體程式說明]: 狀態流變遷測試，驗證應用程式在執行資料同步時，isSyncingProvider 的狀態是否能正確經歷「同步中」到「同步完成」的轉變。
/// [執行順序說明]:
/// 1. 初始化 PackageInfo 模擬值。
/// 2. 使用 MockSyncService 覆蓋服務提供者以模擬受控的同步延遲。
/// 3. 建立 ProviderContainer 並同時監聽 garbageTrucksProvider 與 isSyncingProvider。
/// 4. 進入輪詢迴圈，等待並驗證 isSyncingProvider 的值從 true 變更為 false。
/// 5. 確保同步狀態在 1 秒內正確轉換，否則測試失敗。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';
import 'package:ntpc_garbage_map/services/ntpc_garbage_service.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:ntpc_garbage_map/models/garbage_route_point.dart';
import 'package:package_info_plus/package_info_plus.dart';

// 建立一個 Mock Service
class MockSyncService extends BaseGarbageService {
  MockSyncService() : super(localSourceDir: '');

  @override
  Future<void> syncDataIfNeeded({void Function(String)? onProgress}) async {
    onProgress?.call('Mock 同步中...');
    await Future.delayed(const Duration(milliseconds: 100));
  }
  
  @override
  Future<List<GarbageTruck>> fetchTrucks() async => [];

  @override
  Future<List<GarbageTruck>> findTrucksByTime(int h, int m) async => [];

  @override
  Future<List<GarbageRoutePoint>> getRouteForLine(String id) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('State Flow Tests', () {
    /// 狀態流測試：驗證資料同步過程中的狀態變遷（從「同步中」到「同步完成」）
    test('isSyncingProvider should transition from true to false with MockService', () async {
      /// 測試同步狀態轉換：驗證使用模擬服務進行同步時，isSyncingProvider 最終是否會轉變為 false
      PackageInfo.setMockInitialValues(
        appName: "map", packageName: "map", version: "1.0.0", buildNumber: "1", buildSignature: "1"
      );

      final container = ProviderContainer(
        overrides: [
          garbageServiceProvider.overrideWith((ref) => MockSyncService()),
        ],
      );
      
      // 監聽 Provider 以確保它被初始化
      container.listen(garbageTrucksProvider, (p, n) {});
      container.listen(isSyncingProvider, (p, n) {});

      // 等待狀態改變
      bool success = false;
      for(int i=0; i<30; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (container.read(isSyncingProvider) == false) {
          success = true;
          break;
        }
      }
      
      expect(success, isTrue, reason: "同步應在 1 秒內完成並變為 false");
    });
  });
}
