/// [整體程式說明]: 雙北市政府真實 API 連線能力測試，驗證生產環境下與新北市（CSV）及台北市（JSON）表定路線 API 的通訊狀況及資料量級。
/// [執行順序說明]:
/// 1. 設定較長的測試超時（5 分鐘）以應對網路延遲。
/// 2. 測試新北市：請求真實 CSV 連結，解析內容並驗證資料量是否超過 1000 筆門檻。
/// 3. 測試台北市：請求真實 JSON 連結，解析 result.results 並驗證資料量是否達到 1000 筆上限。
/// 4. 輸出成功的狀態碼與筆數，若連線失敗或資料異常則觸發 Fail。

@Timeout(Duration(minutes: 5))
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

void main() {
  const Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  group('Real Government API Connection Tests', () {
    /// 真實政府 API 連線測試：驗證與雙北政府開放資料 API 的連線能力、狀態碼以及資料筆數
    test('NTPC: Real Connection Test (CSV Route API)', () async {
      /// 測試新北市連線：驗證是否能與新北市 CSV 路由 API 建立連線並抓取足量的班表資料
      const url = 'https://data.ntpc.gov.tw/api/datasets/edc3ad26-8ae7-4916-a00b-bc6048d19bf8/csv?size=5000';
      print('--- 連線測試: 新北市表定路線 API ---');
      
      try {
        final response = await http.get(Uri.parse(url), headers: headers);
        print('HTTP 狀態碼: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final List<List<dynamic>> fields = const CsvToListConverter(eol: '\n').convert(response.body);
          print('成功抓取新北市路線點位！總筆數: ${fields.length - 1}');
          expect(fields.length - 1, greaterThan(1000), reason: '新北市路線資料量應超過 1000 筆');
        } else {
          fail('新北市 API 連線失敗');
        }
      } catch (e) {
        fail('連線過程中發生異常: $e');
      }
    });

    test('Taipei: Real Connection Test (JSON Route API)', () async {
      /// 測試台北市連線：驗證是否能與台北市 JSON 路由 API 建立連線並獲取超過 1000 筆的結果
      const url = 'https://data.taipei/api/v1/dataset/a6e90031-7ec4-4089-afb5-361a4efe7202?scope=resourceAquire&limit=5000';
      print('--- 連線測試: 台北市表定路線 API ---');
      
      try {
        final response = await http.get(Uri.parse(url), headers: headers);
        print('HTTP 狀態碼: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final dynamic decoded = json.decode(response.body);
          List results = [];
          if (decoded is Map && decoded.containsKey('result')) {
            results = decoded['result']['results'] ?? [];
          } else if (decoded is List) {
            results = decoded;
          }
          
          print('成功抓取台北市路線點位！總筆數: ${results.length}');
          if (results.isNotEmpty) {
            print('範例點位 (第一筆): ${results.first}');
          }
          
          expect(results.length, greaterThanOrEqualTo(1000), reason: '台北市資料量應至少達到 1000 筆上限');
        } else {
          fail('台北市 API 連線失敗');
        }
      } catch (e) {
        fail('連線過程中發生異常: $e');
      }
    });
  });
}
