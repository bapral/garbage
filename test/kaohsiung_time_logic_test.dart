import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:ntpc_garbage_map/models/garbage_route_point.dart';

void main() {
  late DatabaseService dbService;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dbService = DatabaseService();
  });

  test('深度測試：時間過濾邏輯應正確處理跨小時邊界', () async {
    // 1. 插入測試站點
    final testPoints = [
      GarbageRoutePoint(lineId: 'L1', lineName: 'N1', rank: 1, name: '10:00站', position: const LatLng(22.6, 120.3), arrivalTime: '10:00'),
      GarbageRoutePoint(lineId: 'L2', lineName: 'N2', rank: 2, name: '10:15站', position: const LatLng(22.6, 120.3), arrivalTime: '10:15'),
      GarbageRoutePoint(lineId: 'L3', lineName: 'N3', rank: 3, name: '10:30站', position: const LatLng(22.6, 120.3), arrivalTime: '10:30'),
      GarbageRoutePoint(lineId: 'L4', lineName: 'N4', rank: 4, name: '11:05站', position: const LatLng(22.6, 120.3), arrivalTime: '11:05'),
    ];

    await dbService.clearAndSaveRoutePoints(testPoints, 'kaohsiung_test');

    // 2. 測試 10:10 (預計抓取 10:10 ~ 10:30 的車)
    // 注意：DatabaseService 預設範圍通常是前後 10-20 分鐘
    final pointsAt1010 = await dbService.findPointsByTime(10, 10, 'kaohsiung_test');
    expect(pointsAt1010.any((p) => p.name == '10:15站'), true);
    expect(pointsAt1010.any((p) => p.name == '10:00站'), true); // 應該包含剛過站的

    // 3. 測試 10:55 (應能抓到 11:05 的車 - 跨小時測試)
    final pointsAt1055 = await dbService.findPointsByTime(10, 55, 'kaohsiung_test');
    expect(pointsAt1055.any((p) => p.name == '11:05站'), true, reason: '應能抓到 10 分鐘後的跨小時站點');
  });
}
