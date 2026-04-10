/// [整體程式說明]: 驗證各城市垃圾車預測模式的時間範圍邏輯（前5分鐘至後20分鐘），確保點位在正確的時間視窗內可見。
/// [執行順序說明]:
/// 1. 初始化記憶體資料庫。
/// 2. 插入特定時間的測試垃圾車路線點位。
/// 3. 模擬不同「現在時間」並查詢資料庫。
/// 4. 斷言查詢結果是否符合「前5後20」的邊界條件。

import 'package:flutter_test/flutter_test.dart';
import 'package:ntpc_garbage_map/models/city_config.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:ntpc_garbage_map/services/ntpc_garbage_service.dart';
import 'package:ntpc_garbage_map/services/taipei_garbage_service.dart';
import 'package:ntpc_garbage_map/services/kaohsiung_garbage_service.dart';
import 'package:ntpc_garbage_map/models/garbage_route_point.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('各城市預測模式時間範圍驗證 (前5後20)', () {
    /// 各城市預測模式時間範圍驗證：確保點位在給定的 25 分鐘視窗（前5後20）內可被正確檢索
    late DatabaseService dbService;

    setUp(() async {
      DatabaseService.resetInstance();
      DatabaseService.customPath = inMemoryDatabasePath;
      dbService = DatabaseService();
      await dbService.db;
    });

    /// 插入測試資料到指定城市的資料庫
    Future<void> insertTestData(String city, String time) async {
      await dbService.saveRoutePoints([
        GarbageRoutePoint(
          lineId: 'TEST-01',
          lineName: '測試路線',
          rank: 1,
          name: '測試點',
          position: LatLng(25.0, 121.0),
          arrivalTime: time,
        )
      ], city);
    }

    test('驗證 25 分鐘可見窗口 (前5後20邏輯)', () async {
      /// 測試點位可見性：驗證 12:00 的點位在 11:40 至 12:05 之間是否可見，並確認邊界外的不可見性
      final service = NtpcGarbageService(localSourceDir: 'tmp');
      
      // 測試點：12:00
      await insertTestData('ntpc', '12:00');

      // 邏輯解釋：
      // 點位 12:00 會在「現在時間」滿足以下條件時被抓到：
      // 現在時間 - 5 <= 12:00 <= 現在時間 + 20
      // 移項後：
      // 12:00 - 20 <= 現在時間 <= 12:00 + 5
      // 11:40 <= 現在時間 <= 12:05
      
      // 測試 1: 11:39 (太早) -> 應抓不到
      expect(await service.findTrucksByTime(11, 39), isEmpty);

      // 測試 2: 11:40 (邊界開始) -> 應抓到
      expect(await service.findTrucksByTime(11, 40), isNotEmpty);

      // 測試 3: 12:00 (當下) -> 應抓到
      expect(await service.findTrucksByTime(12, 0), isNotEmpty);

      // 測試 4: 12:05 (邊界結束) -> 應抓到
      expect(await service.findTrucksByTime(12, 5), isNotEmpty);

      // 測試 5: 12:06 (太晚) -> 應抓不到
      expect(await service.findTrucksByTime(12, 6), isEmpty);
      
      print('[測試] 驗證成功：12:00 的點位在 11:40~12:05 (25分鐘) 之間可見');
    });

    test('驗證所有城市皆套用相同 前5後20 邏輯', () async {
      /// 測試多城市通用邏輯：驗證新北市、台北市及高雄市是否均採用相同的前5後20時間預測邏輯
      final cities = ['ntpc', 'taipei', 'kaohsiung'];
      for (var city in cities) {
        await dbService.clearAllRoutePoints(city);
        await insertTestData(city, '10:00');
        
        // 應在 09:40 ~ 10:05 可見
        expect(await dbService.findPointsByTime(9, 39, city), isEmpty, reason: '$city: 09:39 應不可見');
        expect(await dbService.findPointsByTime(9, 40, city), isNotEmpty, reason: '$city: 09:40 應可見');
        expect(await dbService.findPointsByTime(10, 5, city), isNotEmpty, reason: '$city: 10:05 應可見');
        expect(await dbService.findPointsByTime(10, 6, city), isEmpty, reason: '$city: 10:06 應不可見');
        
        print('[測試] $city 驗證成功');
      }
    });
  });
}
