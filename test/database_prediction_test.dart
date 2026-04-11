/// - **測試目的**: 資料庫預測相關查詢測試，專注於驗證 findPointsByTime 方法在不同時間區段下的查詢準確性。
/// - **測試覆蓋**: 
///   - 特定小時與分鐘的正確點位回傳。
///   - 15 分鐘偏移區間（前後）內的點位檢索。
///   - 同一 10 分鐘區塊內的點位查詢。
/// - **測試執行順序**: 初始化記憶體資料庫並重置實例 -> 插入多組模擬的垃圾車路線點位資料 -> 針對特定時分執行查詢 -> 驗證查詢結果是否包含預期的時間區間點位。

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ntpc_garbage_map/models/garbage_route_point.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // 初始化 sqflite_ffi 供測試使用
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Database Time Search Tests', () {
    /// 資料庫時間搜尋測試：驗證根據給定時間搜尋點位的準確性
    late DatabaseService dbService;

    setUp(() async {
      // 設定使用記憶體資料庫
      DatabaseService.customPath = inMemoryDatabasePath;
      DatabaseService.resetInstance();
      
      dbService = DatabaseService();
      // 在記憶體中，onCreate 會自動執行，所以不需要手動 delete
    });

    test('findPointsByTime should return correct points for a specific hour/minute', () async {
      /// 測試特定時間查詢：驗證在搜尋 20:30 時，是否能正確抓取 20:15 至 20:45 區間內的所有點位
      final mockPoints = [
        GarbageRoutePoint(lineId: 'L1', lineName: 'Route 1', rank: 1, name: 'Central 8th St', position: LatLng(25.0, 121.0), arrivalTime: '20:30'),
        GarbageRoutePoint(lineId: 'L1', lineName: 'Route 1', rank: 2, name: 'Other St', position: LatLng(25.1, 121.1), arrivalTime: '20:45'),
        GarbageRoutePoint(lineId: 'L2', lineName: 'Route 2', rank: 1, name: 'Morning St', position: LatLng(25.2, 121.2), arrivalTime: '08:30'),
      ];

      await dbService.saveRoutePoints(mockPoints, 'ntpc');

      // 搜尋 20:30 左右的點 (區間為 20:15 - 20:45)
      final results = await dbService.findPointsByTime(20, 30, 'ntpc');
      
      expect(results.length, equals(2));
      expect(results.any((p) => p.name == 'Central 8th St'), isTrue);
      expect(results.any((p) => p.name == 'Other St'), isTrue);
    });

    test('findPointsByTime should return points within the same 10-minute block', () async {
      /// 測試 10 分鐘區段查詢：驗證當點位時間與搜尋時間處於同一個 10 分鐘區塊內時，是否能被正確檢索
      final mockPoints = [
        GarbageRoutePoint(lineId: 'L1', lineName: 'Route 1', rank: 1, name: 'Point A', position: LatLng(25.0, 121.0), arrivalTime: '20:32'),
        GarbageRoutePoint(lineId: 'L1', lineName: 'Route 1', rank: 2, name: 'Point B', position: LatLng(25.1, 121.1), arrivalTime: '20:38'),
      ];

      await dbService.saveRoutePoints(mockPoints, 'ntpc');

      // 搜尋 20:30 (預期會搜到 20:3X)
      final results = await dbService.findPointsByTime(20, 30, 'ntpc');
      
      expect(results.length, equals(2));
    });
  });
}
