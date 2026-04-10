/// [整體程式說明]: 高雄市 API 連結連通性探針，用於批次測試多個高雄市政府開放資料連結的有效性、回應格式及資料欄位。
/// [執行順序說明]:
/// 1. 遍歷 KaohsiungGarbageService.routeApiUrls 中定義的所有 API 連結。
/// 2. 對每個連結發送 HTTP GET 請求並設定 15 秒超時。
/// 3. 驗證狀態碼、解析 JSON 回傳內容並確認其是否為 List 格式。
/// 4. 輸出成功的記錄筆數與首筆資料的欄位名稱以供開發者檢核。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ntpc_garbage_map/services/kaohsiung_garbage_service.dart';

void main() {
  test('高雄市 API 連結連通性探針', () async {
    /// 連結探針測試：巡檢多個 API 網址，驗證其連線狀態及 JSON 資料結構的相容性
    const urls = KaohsiungGarbageService.routeApiUrls;
    
    for (String url in urls) {
      print('\n[探針] 測試連結: $url');
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        print('  狀態碼: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final body = utf8.decode(response.bodyBytes);
          final dynamic data = json.decode(body);
          if (data is List) {
            print('  成功！回傳筆數: ${data.length}');
            if (data.isNotEmpty) {
              print('  範例欄位: ${data.first.keys.toList()}');
            }
          } else {
            print('  錯誤: 回傳非 List 格式');
          }
        } else {
          print('  失敗: 狀態碼非 200');
        }
      } catch (e) {
        print('  崩潰: $e');
      }
    }
  });
}
