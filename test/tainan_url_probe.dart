/// [整體程式說明]: 暴力測試台南市 API 網址組合，用於巡檢並探測台南市政府多個開放資料連結的有效性及內容摘要。
/// [執行順序說明]:
/// 1. 定義多個包含台南市 GPS 資料的潛在網址列表。
/// 2. 遍歷網址列表，發送 HTTP GET 請求並設定 5 秒超時。
/// 3. 輸出回應狀態碼、內容長度以及前 100 字元的摘要。
/// 4. 捕獲並顯示探測過程中的任何錯誤。

import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('診斷：暴力測試台南市 API 網址組合', () async {
    /// 網址暴力探測：批次驗證多個台南市 API 連結的連通性，以確認最佳的資料源
    final List<String> urls = [
      'https://data.tainan.gov.tw/api/3/action/datastore_search?resource_id=de3c0118-9334-476a-bf3e-b64b107765d8&limit=5',
      'http://data.tainan.gov.tw/api/3/action/datastore_search?resource_id=de3c0118-9334-476a-bf3e-b64b107765d8&limit=5',
      'https://data.tainan.gov.tw/api/v1/dump/datastore_search?resource_id=de3c0118-9334-476a-bf3e-b64b107765d8&limit=5',
      'https://data.tainan.gov.tw/dataset/de3c0118-9334-476a-bf3e-b64b107765d8/resource/de3c0118-9334-476a-bf3e-b64b107765d8/download/gps.json',
    ];

    for (final url in urls) {
      print('測試網址: $url');
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        print('  -> 狀態碼: ${response.statusCode}');
        if (response.statusCode == 200) {
          print('  -> [成功] 內容長度: ${response.body.length}');
          print('  -> 內容摘要: ${response.body.substring(0, 100)}');
        }
      } catch (e) {
        print('  -> [錯誤]: $e');
      }
    }
  });
}
