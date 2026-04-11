/// - **測試目的**: 新北市政府開放資料 API 診斷測試，用於掃描並驗證多個可能的 Dataset ID (OID)，以確認哪一個包含即時垃圾車 JSON 資料。
/// - **測試覆蓋**: 
///   - 批次掃描多個新北市 OID 連結。
///   - API HTTP GET 請求連通性與 Header 驗證。
///   - JSON 陣列格式檢查與資料筆數統計。
///   - 成功獲取的資料首筆範例輸出，協助定位正確資料源。
/// - **測試執行順序**: 定義包含多個 OID 的掃描列表 -> 遍歷列表並發送 HTTP 請求 -> 驗證狀態碼並解析 JSON 內容 -> 輸出診斷報告與資料範例。

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://data.ntpc.gov.tw/',
  };

  test('Diagnostic: Scan multiple OIDs for Real-time Garbage Truck Data', () async {
    /// 診斷測試：批次掃描多個 OID 以識別含有即時位置 JSON 資料的正確 API 連結
    // 掃描幾個可能的新北市垃圾車 OID
    final oids = [
      'EDC3AD26-8BD2-49A7-805D-0576461F297B', // 官方標示為車輛位置
      '39e17852-9ac9-45b7-bc60-d8d0ed7e3161', // 焚化廠 (之前誤用)
      '2ED449AA-96BB-4A34-A705-F91D3D9EF281', // 路線班表
    ];

    print('--- 開始 API 掃描 ---');
    
    for (var oid in oids) {
      final url = 'https://data.ntpc.gov.tw/api/datasets/$oid/json?size=5';
      print('正在測試 OID: $oid');
      
      try {
        final response = await http.get(Uri.parse(url), headers: headers);
        print('  狀態碼: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final body = response.body.trim();
          if (body.startsWith('[')) {
            final List data = json.decode(body);
            print('  成功獲取 JSON 陣列！筆數: ${data.length}');
            if (data.isNotEmpty) {
              print('  範例資料第一筆: ${data.first}');
            }
          } else {
            print('  回傳非 JSON 陣列 (可能是 HTML 錯誤頁面)');
          }
        }
      } catch (e) {
        print('  請求出錯: $e');
      }
      print('------------------');
    }
  }, timeout: const Timeout(Duration(minutes: 1)));
}
