/// - **測試目的**: 台中市垃圾車服務邏輯測試，驗證即時動態 API 解析、班表資料庫同步以及時間過濾邏輯的正確性。
/// - **測試覆蓋**: 
///   - fetchTrucks 即時動態 API JSON 解析與座標時間轉換。
///   - syncDataIfNeeded 本地 JSON 班表讀取、解析與資料庫同步。
///   - findTrucksByTime 時間過濾規則（前後 20 分鐘）驗證。
/// - **測試執行順序**: 初始化模擬環境與臨時測試目錄 -> 使用 ManualMockClient 注入模擬 JSON 執行動態解析測試 -> 在臨時目錄建立班表檔執行同步測試 -> 插入測試點位執行時間過濾邏輯測試。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ntpc_garbage_map/services/taichung_garbage_service.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:ntpc_garbage_map/models/garbage_route_point.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

// 手寫 MockClient 避免依賴 build_runner
class ManualMockClient extends http.BaseClient {
  String? mockResponse;
  int mockStatus = 200;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(mockResponse ?? '[]')),
      mockStatus,
    );
  }
}

void main() {
  late TaichungGarbageService service;
  late ManualMockClient mockClient;
  late String tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // 為 package_info_plus 提供 Mock 值
    PackageInfo.setMockInitialValues(
      appName: 'ntpc_garbage_map',
      packageName: 'com.example.ntpc_garbage_map',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'buildSignature',
    );
  });

  setUp(() async {
    mockClient = ManualMockClient();
    tempDir = p.join(Directory.systemTemp.path, 'taichung_test_${DateTime.now().millisecondsSinceEpoch}');
    await Directory(tempDir).create(recursive: true);
    
    DatabaseService.customPath = p.join(tempDir, 'test.db');
    DatabaseService.resetInstance();
    
    service = TaichungGarbageService(localSourceDir: tempDir, client: mockClient);
  });

  tearDown(() async {
    DatabaseService.resetInstance(); // 確保資料庫連接關閉
    try {
      await Directory(tempDir).delete(recursive: true);
    } catch (_) {
      // 忽略因 Windows 檔案鎖定造成的刪除失敗
    }
  });

  group('TaichungGarbageService 測試', () {
    /// 台中市垃圾車服務測試：驗證動態 API 解析、班表同步及時間過濾邏輯
    test('fetchTrucks 應正確解析台中市動態 API JSON', () async {
      /// 測試動態解析：驗證是否能正確解析台中市政府動態 API 回傳的 JSON 格式並轉換為 GarbageTruck 物件
      mockClient.mockResponse = json.encode([
        {
          "lineid": "123",
          "car": "ABC-1234",
          "time": "20260406T153000",
          "location": "台中火車站",
          "X": "120.684",
          "Y": "24.137"
        }
      ]);

      final trucks = await service.fetchTrucks();

      expect(trucks.length, 1);
      expect(trucks.first.carNumber, "ABC-1234");
      expect(trucks.first.position.latitude, 24.137);
      expect(trucks.first.position.longitude, 120.684);
      expect(trucks.first.updateTime.hour, 15);
      expect(trucks.first.updateTime.minute, 30);
    });

    test('syncDataIfNeeded 應能處理本地 JSON 並寫入資料庫', () async {
      /// 測試同步邏輯：驗證是否能正確讀取本地的 JSON 班表資料、解析並存入資料庫，以及後續的預測查詢
      final mockJsonFile = File(p.join(tempDir, '0_臺中市定時定點垃圾收運地點.JSON'));
      final mockSchedule = [
        {
          "area": "中區",
          "village": "中華里",
          "car_licence": "ABC-1234",
          "caption": "測試地點",
          "g_d1_time_s": "08:30",
          "g_d2_time_s": "08:30",
          "g_d3_time_s": "08:30",
          "g_d4_time_s": "08:30",
          "g_d5_time_s": "08:30",
          "g_d6_time_s": "08:30",
          "g_d7_time_s": "08:30"
        }
      ];
      await mockJsonFile.writeAsString(json.encode(mockSchedule));

      mockClient.mockResponse = json.encode([
        {
          "car": "ABC-1234",
          "X": "120.5",
          "Y": "24.5"
        }
      ]);

      await service.syncDataIfNeeded();

      final dbCount = await DatabaseService().getTotalCount('taichung');
      expect(dbCount, 1);

      final predictedTrucks = await service.findTrucksByTime(8, 25);
      expect(predictedTrucks.length, 1);
      expect(predictedTrucks.first.updateTime.hour, 8);
      expect(predictedTrucks.first.updateTime.minute, 30);
    });

    test('findTrucksByTime 應符合 20 分鐘過濾規則', () async {
      /// 測試時間過濾：驗證台中市服務的時間過濾邏輯，確保僅回傳搜尋時間前後 20 分鐘內的站點
      final db = DatabaseService();
      await db.saveRoutePoints([
        GarbageRoutePoint(lineId: 'T1', lineName: '台中線', rank: 1, name: '點A', position: const LatLng(24, 120), arrivalTime: '09:00'),
        GarbageRoutePoint(lineId: 'T2', lineName: '台中線', rank: 2, name: '點B', position: const LatLng(24, 120), arrivalTime: '09:15'),
        GarbageRoutePoint(lineId: 'T3', lineName: '台中線', rank: 3, name: '點C', position: const LatLng(24, 120), arrivalTime: '09:30'),
      ], 'taichung');

      final result = await service.findTrucksByTime(9, 0);
      
      expect(result.length, 2);
      expect(result.any((t) => t.location.contains('點A')), true);
      expect(result.any((t) => t.location.contains('點B')), true);
      expect(result.any((t) => t.location.contains('點C')), false);
    });
  });
}
