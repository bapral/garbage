/// - **測試目的**: 高雄市垃圾車服務深層整合測試，使用 Mock API 驗證完整的資料同步流程、時間查詢以及垃圾車點位抓取邏輯。
/// - **測試覆蓋**: 
///   - Mock API 資料同步與資料庫存入驗證。
///   - 資料庫總筆數斷言。
///   - 19:30 點位名稱與屬性查詢準確性。
///   - findTrucksByTime 服務層級 GarbageTruck 物件回傳驗證。
/// - **測試執行順序**: 初始化記憶體資料庫並重置實例 -> 使用 MockClient 注入模擬的高雄市多筆 API 回傳資料 -> 執行 syncDataIfNeeded 同步方法 -> 驗證資料庫筆數與特定時間查詢結果。

import 'package:flutter_test/flutter_test.dart';
import 'package:ntpc_garbage_map/models/city_config.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:ntpc_garbage_map/services/kaohsiung_garbage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  // 注意：不要在這裡調用 TestWidgetsFlutterBinding.ensureInitialized()
  // 除非我們真的需要測試 Widget
  
  // 初始化 sqflite_ffi 用於測試
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('高雄市垃圾車服務整合測試 (Mock 版)', () {
    /// 高雄市垃圾車服務整合測試：驗證模擬環境下的資料同步、庫存狀態及時間搜尋功能
    late DatabaseService dbService;
    late KaohsiungGarbageService khService;

    // 模擬的高雄市 API 回傳資料
    final mockJsonResponse = json.encode([
      {
        "行政區": "左營區",
        "村里": "埤東里",
        "清運路線名稱": "M01",
        "停留地點": "勝利路與左營大路口",
        "緯度": "22.678",
        "經度": "120.298",
        "停留時間": "1930"
      },
      {
        "行政區": "苓雅區",
        "村里": "五權里",
        "清運路線名稱": "M02",
        "停留地點": "和平路與三多路口",
        "緯度": "22.623",
        "經度": "120.318",
        "停留時間": "2000"
      }
    ]);

    setUp(() async {
      DatabaseService.resetInstance();
      DatabaseService.customPath = inMemoryDatabasePath;
      dbService = DatabaseService();
      
      // 使用 MockClient 模擬網路請求
      final mockClient = MockClient((request) async {
        return http.Response(mockJsonResponse, 200, headers: {
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8'
        });
      });

      khService = KaohsiungGarbageService(
        localSourceDir: 'test_assets',
        client: mockClient
      );
    });

    tearDown(() async {
      final db = await dbService.db;
      await db.close();
    });

    test('測試高雄市資料同步流程 (Mock API)', () async {
      /// 測試同步流程：驗證高雄市資料是否能正確存入資料庫，並測試 19:30 的點位查詢準確性
      print('[測試] 開始執行高雄市資料同步 (Mock)...');
      
      await khService.syncDataIfNeeded(debugVersion: '1.0.0+test');

      final hasData = await dbService.hasData('kaohsiung');
      expect(hasData, isTrue);

      final totalCount = await dbService.getTotalCount('kaohsiung');
      print('[測試] 資料庫總筆數: $totalCount');
      expect(totalCount, equals(2));

      // 測試時間查詢功能 (19:30)
      print('[測試] 查詢 19:30 的點位...');
      final points = await dbService.findPointsByTime(19, 30, 'kaohsiung');
      expect(points, isNotEmpty);
      expect(points.first.name, contains('勝利路'));
      print('[測試] 驗證成功：抓取到 Mock 點位 ${points.first.name}');
    });

    test('測試 KaohsiungGarbageService.findTrucksByTime (Mock)', () async {
      /// 測試垃圾車查詢：驗證服務層級的 findTrucksByTime 函式是否能正確回傳特定時間的垃圾車物件
      await khService.syncDataIfNeeded(debugVersion: '1.0.0+test');
      
      // 測試 19:30 的垃圾車
      final trucks = await khService.findTrucksByTime(19, 30);
      print('[測試] 19:30 查詢到 ${trucks.length} 台垃圾車');
      expect(trucks, isNotEmpty);
      expect(trucks.first.location, contains('勝利路'));
    });
  });
}
