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
    late DatabaseService dbService;

    setUp(() async {
      DatabaseService.customPath = inMemoryDatabasePath;
      DatabaseService.resetInstance();
      dbService = DatabaseService();
    });

    test('GarbageTruck.predictOnRoute calculates correct future position', () {
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
      await dbService.updateVersion('2.0.0');
      final version = await dbService.getStoredVersion();
      expect(version, equals('2.0.0'));
    });

    test('DatabaseService.findPointsByTime handles 15-min offset window', () async {
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
