import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:ntpc_garbage_map/models/garbage_route_point.dart';

void main() {
  group('GarbageTruck Route Prediction Tests', () {
    final mockRoutePoints = [
      GarbageRoutePoint(lineId: 'ROUTE-1', lineName: 'Test Route', rank: 0, name: 'Point 0', position: LatLng(25.0, 121.0), arrivalTime: '17:00'),
      GarbageRoutePoint(lineId: 'ROUTE-1', lineName: 'Test Route', rank: 1, name: 'Point 1', position: LatLng(25.1, 121.1), arrivalTime: '17:05'),
      GarbageRoutePoint(lineId: 'ROUTE-1', lineName: 'Test Route', rank: 2, name: 'Point 2', position: LatLng(25.2, 121.2), arrivalTime: '17:10'),
    ];

    test('predictOnRoute should stay at current position for Duration.zero', () {
      final truck = GarbageTruck(
        carNumber: 'TRUCK-1',
        lineId: 'ROUTE-1',
        location: 'Start',
        position: LatLng(25.0, 121.0),
        updateTime: DateTime.now(),
      );

      final predicted = truck.predictOnRoute(Duration.zero, mockRoutePoints);
      expect(predicted, equals(LatLng(25.0, 121.0)));
    });

    test('predictOnRoute should move to the next point after some time', () {
      final truck = GarbageTruck(
        carNumber: 'TRUCK-1',
        lineId: 'ROUTE-1',
        location: 'Start',
        position: LatLng(25.0, 121.0),
        updateTime: DateTime.now(),
      );

      // 假設 3 分鐘移動一個點，6 分鐘應該移動到索引 2 (Point 2)
      // current is Point 0 (index 0), move 2 points -> index 2
      final predicted = truck.predictOnRoute(const Duration(minutes: 6), mockRoutePoints);
      expect(predicted, equals(LatLng(25.2, 121.2)));
    });

    test('predictOnRoute should fallback to linear prediction if route is missing', () {
      final truck = GarbageTruck(
        carNumber: 'TRUCK-1',
        lineId: 'MISSING-ROUTE',
        location: 'Start',
        position: LatLng(25.0, 121.0),
        updateTime: DateTime.now(),
      );

      final predicted = truck.predictOnRoute(const Duration(minutes: 10), mockRoutePoints);
      // 因為找不到路線，會執行 predictPosition (隨機線性移動)，座標一定會變動
      expect(predicted, isNot(equals(LatLng(25.0, 121.0))));
    });
  });
}
