/// [整體程式說明]: 高雄市垃圾車即時 API 診斷測試，用於確認高雄市政府開放資料平台 API 的連通性、狀態碼及回傳資料格式。
/// [執行順序說明]:
/// 1. 向高雄市 API 發送 HTTP GET 請求並設定超時限制。
/// 2. 接收回應並驗證狀態碼是否為 200。
/// 3. 解析 JSON 資料並統計取得的記錄筆數。
/// 4. 輸出範例記錄內容以供開發者調試。

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
