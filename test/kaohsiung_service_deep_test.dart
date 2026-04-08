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
      await khService.syncDataIfNeeded(debugVersion: '1.0.0+test');
      
      // 測試 19:30 的垃圾車
      final trucks = await khService.findTrucksByTime(19, 30);
      print('[測試] 19:30 查詢到 ${trucks.length} 台垃圾車');
      expect(trucks, isNotEmpty);
      expect(trucks.first.location, contains('勝利路'));
    });
  });
}
