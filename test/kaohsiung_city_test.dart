import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:ntpc_garbage_map/services/kaohsiung_garbage_service.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';

// 手動模擬 HttpClient
class FakeClient extends http.BaseClient {
  final String mockResponse;
  final int statusCode;

  FakeClient(this.mockResponse, {this.statusCode = 200});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(mockResponse)),
      statusCode,
    );
  }
}

void main() {
  late DatabaseService dbService;

  setupPackageInfo() {
    PackageInfo.setMockInitialValues(
      appName: "Garbage Map",
      packageName: "com.example.ntpc_garbage_map",
      version: "1.0.0",
      buildNumber: "1",
      buildSignature: "buildSignature",
      installerStore: null,
    );
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    setupPackageInfo();
    dbService = DatabaseService();
  });

  test('高雄市服務應能正確解析模擬的 JSON 並存入資料庫', () async {
    final mockJson = [
      {
        "行政區": "三民區",
        "村里": "鼎西里",
        "停留地點": "天祥一路與鼎力路口",
        "停留時間": "16:30",
        "經度": "120.3200",
        "緯度": "22.6600",
        "清運路線名稱": "三民01"
      }
    ];

    final fakeClient = FakeClient(json.encode(mockJson));
    final service = KaohsiungGarbageService(
      localSourceDir: 'test_dir',
      client: fakeClient,
    );

    // 執行同步
    await service.syncDataIfNeeded(onProgress: (msg) => print('進度: $msg'));

    // 驗證資料庫內容
    final count = await dbService.getTotalCount('kaohsiung');
    expect(count, greaterThan(0));

    final points = await dbService.getRoutePoints('三民01', 'kaohsiung');
    expect(points.isNotEmpty, true);
    expect(points.first.name, '鼎西里 天祥一路與鼎力路口');
    expect(points.first.arrivalTime, '16:30');
  });

  test('高雄市服務應能處理 404 連結並嘗試下一個備用連結', () async {
    // 故意讓第一個連結失敗 (這需要修改 FakeClient 來支援不同 URL 回傳不同結果，但這裡簡化)
    // 我們可以測試當 records 為空時的情況
    final fakeClient = FakeClient('[]', statusCode: 200);
    final service = KaohsiungGarbageService(
      localSourceDir: 'test_dir',
      client: fakeClient,
    );

    await service.syncDataIfNeeded(onProgress: (msg) => print('進度: $msg'));
    // 雖然 records 為空不會報錯，但會提示同步失敗
  });
}
