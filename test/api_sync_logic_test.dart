/// [整體程式說明]: 驗證雙北市垃圾車 API 同步邏輯，確保資料更新門檻、同步機制以及異常處理符合預期。
/// [執行順序說明]:
/// 1. 初始化模擬資料庫與環境。
/// 2. 設定測試用的 API 回傳內容（包含正常與低於門檻的資料筆數）。
/// 3. 執行同步方法並觸發 API 請求。
/// 4. 斷言資料庫中的紀錄筆數，確認是否正確更新。

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ntpc_garbage_map/models/garbage_route_point.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:ntpc_garbage_map/services/taipei_garbage_service.dart';
import 'package:ntpc_garbage_map/services/ntpc_garbage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Dual-City API Sync Logic Tests', () {
    /// 雙北 API 同步邏輯測試：驗證資料更新門檻與同步機制
    late DatabaseService dbService;
    late Directory tempDir;

    setUp(() async {
      dbService = DatabaseService();
      final db = await dbService.db;
      await db.delete(DatabaseService.tableName);
      await db.delete('metadata');

      tempDir = await Directory.systemTemp.createTemp('api_sync_test');
      
      PackageInfo.setMockInitialValues(
        appName: "garbage_map", packageName: "com.example", version: "1.0.0", buildNumber: "1",
        buildSignature: "", installerStore: null,
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('Taipei: Should update database when API returns 1101 records', () async {
      /// 測試台北市：當 API 回傳 1101 筆紀錄（超過 1100 筆門檻）時，應成功更新資料庫
      final mockData = List.generate(1101, (i) => {
        '車號': 'C-$i', '地點': 'L-$i', '經度': '121', '緯度': '25', '路線': 'R', '抵達時間': '1800'
      });
      
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'result': {'results': mockData}}),
          200,
          headers: {HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8'},
        );
      });

      // 建立一個空的本地 CSV 避免報錯
      final csvFile = File('${tempDir.path}/taipei.csv');
      await csvFile.writeAsString('行政區,里別,分隊,局編,車號,路線,車次,抵達時間,離開時間,地點,經度,緯度\n');

      final service = TaipeiGarbageService(localSourceDir: tempDir.path, client: mockClient);
      await service.syncDataIfNeeded();
      
      final count = await dbService.getTotalCount();
      expect(count, equals(1101));
    });

    test('Taipei: Should NOT update database when API returns only 1000 records (Threshold Fail)', () async {
      /// 測試台北市：當 API 僅回傳 1000 筆紀錄（低於 1100 筆門檻）時，視為異常不應更新資料庫
      await dbService.saveRoutePoints([
        GarbageRoutePoint(lineId: 'OLD', lineName: 'OLD', rank: 1, name: 'OLD', position: LatLng(0,0), arrivalTime: '00:00')
      ], 'taipei');

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'result': {'results': List.generate(1000, (i) => {'車號': 'C'})}}),
          200,
          headers: {HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8'},
        );
      });

      // 建立一個空的本地 CSV 避免報錯
      final csvFile = File('${tempDir.path}/taipei.csv');
      await csvFile.writeAsString('行政區,里別,分隊,局編,車號,路線,車次,抵達時間,離開時間,地點,經度,緯度\n');

      final service = TaipeiGarbageService(localSourceDir: tempDir.path, client: mockClient);
      await service.syncDataIfNeeded();
      
      final count = await dbService.getTotalCount();
      // 雖然 API 失敗，但因為本地 CSV 是空的，資料庫應維持 1 (原本的 OLD 資料)
      expect(count, equals(1));
    });

    test('NTPC: Should update database when API returns 5001 CSV lines', () async {
      /// 測試新北市：當 API 回傳 5001 筆 CSV 資料（超過 5000 筆門檻）時，應成功更新資料庫
      final mockClient = MockClient((request) async {
        String csv = 'lineid,latitude,longitude,time\n';
        for (int i = 0; i < 5001; i++) {
          csv += 'L,25,121,1700\n';
        }
        return http.Response(csv, 200);
      });

      final service = NtpcGarbageService(localSourceDir: tempDir.path, client: mockClient);
      
      await service.syncDataIfNeeded();
      
      final count = await dbService.getTotalCount();
      expect(count, equals(5001));
    });
  });
}
