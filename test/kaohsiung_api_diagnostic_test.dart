/// - **測試目的**: 高雄市垃圾車即時 API 診斷測試，用於確認高雄市政府開放資料平台 API 的連通性、狀態碼及回傳資料格式。
/// - **測試覆蓋**: 
///   - API 連通性驗證（HTTP 200 狀態碼）。
///   - JSON 資料解析與結構檢查。
///   - 記錄筆數統計與範例內容輸出。
/// - **測試執行順序**: 向高雄市 API 發送 HTTP GET 請求並設定超時 -> 接收回應並驗證狀態碼 -> 解析 JSON 資料並統計記錄筆數 -> 輸出範例記錄內容供開發調試。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  test('高雄市 api.kcg.gov.tw 即時 API 診斷測試', () async {
    /// 診斷測試：驗證與高雄市政府 API 的連線，確保能獲取即時資料並正確解析 JSON 內容
    const String url = 'https://api.kcg.gov.tw/api/service/Get/280df90a-8042-4abc-9bc9-2ad51a4204ed';
    
    print('正在請求 URL: $url');
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
    
    print('狀態碼: ${response.statusCode}');
    expect(response.statusCode, 200);
    
    final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
    final List<dynamic> records = data['data'] ?? [];
    
    print('取得記錄數: ${records.length}');
    if (records.isNotEmpty) {
      final sample = records.first;
      print('範例記錄內容: $sample');
    }
  });
}
