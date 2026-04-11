/// - **測試目的**: 核心邏輯與資料庫綜合單元測試，驗證垃圾車位置預測演算法、資料庫版本控制以及基於時間的點位查詢功能。
/// - **測試覆蓋**: 
///   - GarbageTruck.predictOnRoute 預測演算法準確性驗證。
///   - DatabaseService 資料庫版本資訊儲存與讀取邏輯。
///   - findPointsByTime 15 分鐘時間偏移視窗查詢。
/// - **測試執行順序**: 初始化記憶體資料庫環境 -> 執行各項核心邏輯測試（預測、版本、查詢） -> 驗證計算結果或資料庫狀態是否符合預期。

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
