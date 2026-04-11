/// - **測試目的**: 高雄市垃圾車資料完整性深度測試，驗證服務是否能正確過濾包含無效座標或缺失時間的異常資料。
/// - **測試覆蓋**: 
///   - 正常資料行的正確解析與存入。
///   - 無效座標格式（非數值字串）的過濾驗證。
///   - 缺失關鍵時間資訊（null）的記錄排除。
/// - **測試執行順序**: 初始化測試環境與模擬套件資訊 -> 建構包含正常、座標錯誤及時間缺失的模擬 JSON -> 執行同步流程並觸發解析 -> 查詢資料庫並斷言僅存入正常資料。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ntpc_garbage_map/services/kaohsiung_garbage_service.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';

class FakeClient extends http.BaseClient {
  final String mockResponse;
  FakeClient(this.mockResponse);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream.value(utf8.encode(mockResponse)), 200);
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PackageInfo.setMockInitialValues(appName: "G", packageName: "G", version: "1.0.0", buildNumber: "1", buildSignature: "G", installerStore: null);
  });

  test('深度測試：應能過濾掉包含無效經緯度或時間的髒資料', () async {
    /// 測試資料過濾：驗證 KaohsiungGarbageService 是否能識別並排除經緯度格式錯誤或時間缺失的非法資料列
    final corruptJson = [
      {
        "行政區": "正常區",
        "停留地點": "正常站",
        "停留時間": "16:30",
        "經度": "120.3200",
        "緯度": "22.6600",
      },
      {
        "行政區": "座標錯誤區",
        "停留地點": "錯誤站1",
        "停留時間": "17:00",
        "經度": "ABC", // 無效經度
        "緯度": "22.6800",
      },
      {
        "行政區": "時間缺失區",
        "停留地點": "錯誤站2",
        "停留時間": null, // 缺失時間
        "經度": "120.3100",
        "緯度": "22.6800",
      }
    ];

    final service = KaohsiungGarbageService(localSourceDir: 'T', client: FakeClient(json.encode(corruptJson)));
    await service.syncDataIfNeeded();

    final db = DatabaseService();
    final count = await db.getTotalCount('kaohsiung');
    
    // 應該只有 1 筆正常資料被存入
    expect(count, 1);
  });
}
