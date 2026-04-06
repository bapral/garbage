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
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService();
      // 使用記憶體資料庫進行測試 (sqflite_ffi 支援)
      // 但因為 DatabaseService 內部寫死了路徑，我們這裡直接使用它，並確保先清空
      final db = await dbService.db;
      await db.delete(DatabaseService.tableName);
    });

    test('findPointsByTime should return correct points for a specific hour/minute', () async {
      final mockPoints = [
        GarbageRoutePoint(lineId: 'L1', lineName: 'Route 1', rank: 1, name: 'Central 8th St', position: LatLng(25.0, 121.0), arrivalTime: '20:30'),
        GarbageRoutePoint(lineId: 'L1', lineName: 'Route 1', rank: 2, name: 'Other St', position: LatLng(25.1, 121.1), arrivalTime: '20:45'),
        GarbageRoutePoint(lineId: 'L2', lineName: 'Route 2', rank: 1, name: 'Morning St', position: LatLng(25.2, 121.2), arrivalTime: '08:30'),
      ];

      await dbService.saveRoutePoints(mockPoints);

      // 搜尋 20:30 左右的點
      final results = await dbService.findPointsByTime(20, 30);
      
      expect(results.length, equals(1));
      expect(results.first.name, equals('Central 8th St'));
      expect(results.first.arrivalTime, equals('20:30'));
    });

    test('findPointsByTime should return points within the same 10-minute block', () async {
      final mockPoints = [
        GarbageRoutePoint(lineId: 'L1', lineName: 'Route 1', rank: 1, name: 'Point A', position: LatLng(25.0, 121.0), arrivalTime: '20:32'),
        GarbageRoutePoint(lineId: 'L1', lineName: 'Route 1', rank: 2, name: 'Point B', position: LatLng(25.1, 121.1), arrivalTime: '20:38'),
      ];

      await dbService.saveRoutePoints(mockPoints);

      // 搜尋 20:30 (預期會搜到 20:3X)
      final results = await dbService.findPointsByTime(20, 30);
      
      expect(results.length, equals(2));
    });
  });
}
