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
