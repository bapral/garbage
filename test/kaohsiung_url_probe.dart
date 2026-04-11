/// - **測試目的**: 高雄市 API 連結連通性探針，用於批次測試多個高雄市政府開放資料連結的有效性、回應格式及資料欄位。
/// - **測試覆蓋**: 
///   - 批次 API 網址連通性巡檢。
///   - HTTP 200 狀態碼與 15 秒超時驗證。
///   - JSON 回傳格式（List）與資料結構相容性檢查。
///   - 成功筆數統計與首筆資料欄位名稱輸出。
/// - **測試執行順序**: 遍歷 KaohsiungGarbageService 中定義的所有 API 連結 -> 對每個連結發送 HTTP GET 請求 -> 驗證狀態碼、格式與解析內容 -> 輸出診斷結果供開發者檢核。

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
