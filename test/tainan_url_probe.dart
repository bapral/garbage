/// - **測試目的**: 暴力測試台南市 API 網址組合，用於巡檢並探測台南市政府多個開放資料連結的有效性及內容摘要。
/// - **測試覆蓋**: 
///   - 批次驗證多個台南市 API 潛在連結的連通性。
///   - HTTP 狀態碼與內容長度檢查。
///   - 回應內容摘要（前 100 字元）輸出與診斷。
/// - **測試執行順序**: 定義包含多個潛在網址的列表 -> 遍歷列表並發送 HTTP GET 請求（5 秒超時） -> 輸出探測結果與摘要 -> 捕獲連線異常供分析。

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
