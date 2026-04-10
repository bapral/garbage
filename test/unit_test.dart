/// [整體程式說明]: 垃圾車路線預測測試：驗證垃圾車在給定路線上根據時間推移預測未來位置的準確性。
/// [執行順序說明]:
/// 1. 建立包含多個站點（座標與抵達時間）的模擬路線清單。
/// 2. 測試當時間增量為零時，預測位置應維持在原位。
/// 3. 測試經過特定時間（如 6 分鐘）後，垃圾車是否能根據路線站點時間正確移動到預期的後續站點。
/// 4. 測試降級預測：當無法找到對應路線資訊時，系統是否能自動降級為座標變動的線性預測模式。

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:ntpc_garbage_map/models/garbage_route_point.dart';

void main() {
  group('GarbageTruck Route Prediction Tests', () {
    /// 垃圾車路線預測測試：驗證垃圾車在給定路線上根據時間推移預測位置的準確性
    final mockRoutePoints = [
      GarbageRoutePoint(lineId: 'ROUTE-1', lineName: 'Test Route', rank: 0, name: 'Point 0', position: LatLng(25.0, 121.0), arrivalTime: '17:00'),
      GarbageRoutePoint(lineId: 'ROUTE-1', lineName: 'Test Route', rank: 1, name: 'Point 1', position: LatLng(25.1, 121.1), arrivalTime: '17:05'),
      GarbageRoutePoint(lineId: 'ROUTE-1', lineName: 'Test Route', rank: 2, name: 'Point 2', position: LatLng(25.2, 121.2), arrivalTime: '17:10'),
    ];

    test('predictOnRoute should stay at current position for Duration.zero', () {
      /// 測試零增量預測：驗證當預測時間增量為零時，垃圾車應保持在目前的起始點位置
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
      /// 測試站點移動預測：驗證當預測時間經過 6 分鐘後，垃圾車是否能根據路線站點時間正確移動到預期的後續站點
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
      /// 測試降級預測：驗證當無法找到對應路線資訊時，系統是否能自動降級為線性預測模式（座標應產生變動而非停滯）
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
