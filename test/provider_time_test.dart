/// [整體程式說明]: predictedTrucksProvider 的時間切換邏輯測試，驗證當使用者手動設定 targetTime 時，系統是否能正確從即時模式切換到資料庫預測模式。
/// [執行順序說明]:
/// 1. 初始化測試環境與 ProviderContainer。
/// 2. 使用 MockGarbageService 覆蓋 garbageServiceProvider 以提供受控的查詢結果。
/// 3. 設定 targetTimeProvider 為特定時間（2026/04/06 20:30）。
/// 4. 讀取 predictedTrucksProvider 並等待非同步結果。
/// 5. 驗證回傳的垃圾車清單是否包含模擬的測試資料（如「中央八街」站點）。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';
import 'package:ntpc_garbage_map/services/ntpc_garbage_service.dart';

// 模擬服務
class MockGarbageService extends NtpcGarbageService {
  MockGarbageService() : super(localSourceDir: '');

  @override
  Future<List<GarbageTruck>> findTrucksByTime(int hour, int minute) async {
    if (hour == 20 && minute == 30) {
      return [
        GarbageTruck(
          carNumber: '預定車輛',
          lineId: 'TEST-LINE',
          location: '中央八街',
          position: LatLng(24.9, 121.5),
          updateTime: DateTime.now(),
        )
      ];
    }
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  test('predictedTrucksProvider should switch to database search when targetTime is set', () async {
    /// 測試目標時間切換：驗證當 targetTime 被設定後，Provider 是否切換到資料庫搜尋並獲取模擬的點位資料
    final container = ProviderContainer(
      overrides: [
        garbageServiceProvider.overrideWith((ref) => MockGarbageService()),
      ],
    );

    // 1. 設定目標時間為 20:30
    final target = DateTime(2026, 4, 6, 20, 30);
    container.read(targetTimeProvider.notifier).setTime(target);

    // 2. 讀取預測結果
    final trucks = await container.read(predictedTrucksProvider.future);

    // 3. 驗證是否抓到了模擬的中央八街車輛
    expect(trucks.length, equals(1));
    expect(trucks.first.location, contains('中央八街'));
    expect(trucks.first.carNumber, equals('預定車輛'));
  });
}
