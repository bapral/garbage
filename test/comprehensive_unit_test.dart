/// [整體程式說明]: 核心邏輯與資料庫綜合單元測試，驗證垃圾車位置預測演算法、資料庫版本控制以及基於時間的點位查詢功能。
/// [執行順序說明]:
/// 1. 初始化記憶體資料庫環境。
/// 2. 測試 GarbageTruck.predictOnRoute 函式，驗證其在給定路線上計算未來位置的準確性。
/// 3. 驗證 DatabaseService 的版本資訊儲存與讀取邏輯。
/// 4. 測試 findPointsByTime 查詢，驗證其是否能正確處理 15 分鐘的時間偏移視窗。

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:ntpc_garbage_map/models/garbage_route_point.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Core Logic & DB Tests', () {
    /// 核心邏輯與資料庫測試：驗證預測演算法、版本控制及資料庫查詢邏輯
    late DatabaseService dbService;

    setUp(() async {
      DatabaseService.customPath = inMemoryDatabasePath;
      DatabaseService.resetInstance();
      dbService = DatabaseService();
    });

    test('GarbageTruck.predictOnRoute calculates correct future position', () {
      /// 測試預測演算法：驗證垃圾車在給定路線站點與時間下，是否能準確計算出 6 分鐘後的未來位置
      final route = [
        GarbageRoutePoint(lineId: '1', lineName: 'R1', rank: 0, name: 'P0', position: LatLng(25.0, 121.0), arrivalTime: '10:00'),
        GarbageRoutePoint(lineId: '1', lineName: 'R1', rank: 1, name: 'P1', position: LatLng(25.1, 121.1), arrivalTime: '10:05'),
        GarbageRoutePoint(lineId: '1', lineName: 'R1', rank: 2, name: 'P2', position: LatLng(25.2, 121.2), arrivalTime: '10:10'),
      ];
      final truck = GarbageTruck(carNumber: 'C1', lineId: '1', location: 'L1', position: LatLng(25.0, 121.0), updateTime: DateTime.now());

      // 預測 6 分鐘後 (應移動 2 個點位)
      final predicted = truck.predictOnRoute(const Duration(minutes: 6), route);
      expect(predicted, equals(LatLng(25.2, 121.2)));
    });

    test('DatabaseService versioning logic works', () async {
      /// 測試版本控制：驗證 DatabaseService 是否能正確儲存新北市的資料版本號，並在隨後成功讀取回傳
      await dbService.updateVersion('2.0.0', 'ntpc');
      final version = await dbService.getStoredVersion('ntpc');
      expect(version, equals('2.0.0'));
    });

    test('DatabaseService.findPointsByTime handles 15-min offset window', () async {
      /// 測試時間偏移查詢：驗證資料庫查詢是否能正確抓取指定時間（20:30）前後 15 分鐘內的站點（如 20:40）
      await dbService.saveRoutePoints([
        GarbageRoutePoint(lineId: '1', lineName: 'R1', rank: 1, name: 'Target', position: LatLng(25, 121), arrivalTime: '20:40'),
      ], 'ntpc');

      // 搜尋 20:30 (應能搜到 20:15~20:45 之間的 20:40)
      final results = await dbService.findPointsByTime(20, 30, 'ntpc');
      expect(results.length, equals(1));
      expect(results.first.name, equals('Target'));
    });
  });
}
