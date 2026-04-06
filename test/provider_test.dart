import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:ntpc_garbage_map/models/garbage_route_point.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';

// 模擬垃圾車資料
class MockGarbageTrucksNotifier extends GarbageTrucksNotifier {
  @override
  List<GarbageTruck> build() {
    return [
      GarbageTruck(
        carNumber: 'TEST-001',
        lineId: 'LINE-A',
        location: 'Current',
        position: LatLng(25.0, 121.0),
        updateTime: DateTime.now(),
      )
    ];
  }
}

void main() {
  test('predictedTrucksProvider should use route data if available', () async {
    final container = ProviderContainer(
      overrides: [
        garbageTrucksProvider.overrideWith(MockGarbageTrucksNotifier.new),
        // 模擬路線 Provider 回傳一個預定義的點
        routePointsProvider.overrideWith((ref) => [
          GarbageRoutePoint(lineId: 'LINE-A', lineName: 'Route A', rank: 0, name: 'P0', position: LatLng(25.0, 121.0), arrivalTime: '17:00'),
          GarbageRoutePoint(lineId: 'LINE-A', lineName: 'Route A', rank: 1, name: 'P1', position: LatLng(25.1, 121.1), arrivalTime: '17:05'),
          GarbageRoutePoint(lineId: 'LINE-A', lineName: 'Route A', rank: 2, name: 'P2', position: LatLng(25.2, 121.2), arrivalTime: '17:10'),
        ]),
      ],
    );

    // 1. 預設 0 分鐘，位置不變
    var trucks = container.read(predictedTrucksProvider);
    expect(trucks.first.position, equals(LatLng(25.0, 121.0)));

    // 2. 設定預測 6 分鐘後 (應前進 2 個點到 index 2: P2)
    container.read(predictionDurationProvider.notifier).setDuration(const Duration(minutes: 6));
    
    // 重新讀取預測後的資料
    trucks = container.read(predictedTrucksProvider);
    expect(trucks.first.position, equals(LatLng(25.2, 121.2)));
    expect(trucks.first.location, contains('(沿路線預測)'));
  });
}
