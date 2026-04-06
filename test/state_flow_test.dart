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
    test('isSyncingProvider should transition from true to false with MockService', () async {
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
