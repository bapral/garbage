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
      // 設定使用記憶體資料庫
      DatabaseService.customPath = inMemoryDatabasePath;
      DatabaseService.resetInstance();
      
      dbService = DatabaseService();
      // 在記憶體中，onCreate 會自動執行，所以不需要手動 delete
    });

    test('findPointsByTime should return correct points for a specific hour/minute', () async {
      final mockPoints = [
        GarbageRoutePoint(lineId: 'L1', lineName: 'Route 1', rank: 1, name: 'Central 8th St', position: LatLng(25.0, 121.0), arrivalTime: '20:30'),
        GarbageRoutePoint(lineId: 'L1', lineName: 'Route 1', rank: 2, name: 'Other St', position: LatLng(25.1, 121.1), arrivalTime: '20:45'),
        GarbageRoutePoint(lineId: 'L2', lineName: 'Route 2', rank: 1, name: 'Morning St', position: LatLng(25.2, 121.2), arrivalTime: '08:30'),
      ];

      await dbService.saveRoutePoints(mockPoints);

      // 搜尋 20:30 左右的點 (區間為 20:15 - 20:45)
      final results = await dbService.findPointsByTime(20, 30);
      
      expect(results.length, equals(2));
      expect(results.any((p) => p.name == 'Central 8th St'), isTrue);
      expect(results.any((p) => p.name == 'Other St'), isTrue);
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
