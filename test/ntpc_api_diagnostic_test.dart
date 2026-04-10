/// [整體程式說明]: 新北市垃圾車 API 整合診斷測試，驗證新北市政府開放資料 CSV API 的連線性、標頭格式以及資料內容的正確性。
/// [執行順序說明]:
/// 1. 向新北市表定路線 CSV API 發送請求（限制 10 筆資料）。
/// 2. 驗證 HTTP 狀態碼並解析 CSV 內容。
/// 3. 檢查 CSV 標頭是否包含關鍵欄位（如 lineid, latitude, longitude, time）。
/// 4. 斷言首筆資料的欄位內容（如 LineID、座標、時間）是否符合預期格式。
/// 5. 執行即時位置 CSV API 的診斷測試，輸出標頭與範例資料以供調試。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'dart:convert';

void main() {
  group('新北市垃圾車 API 整合診斷測試', () {
    final String routeUrl = 'https://data.ntpc.gov.tw/api/datasets/edc3ad26-8ae7-4916-a00b-bc6048d19bf8/csv';
    final Map<String, String> headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    test('驗證表定路線 CSV API 連線與解析', () async {
      /// 測試表定路線 API：驗證 CSV 資料結構，確保包含必要的 LineID 與座標時間欄位
      print('正在請求 URL: $routeUrl?size=10');
      
      // 測試請求小量資料 (10筆) 以驗證格式
      final response = await http.get(Uri.parse('$routeUrl?size=10'), headers: headers);
      
      print('HTTP 狀態碼: ${response.statusCode}');
      expect(response.statusCode, 200, reason: 'API 應回傳 200 OK');

      final String body = response.body.trim();
      print('取得內容前 200 字元: ${body.substring(0, body.length > 200 ? 200 : body.length)}');

      // 使用 CsvToListConverter 解析
      final List<List<dynamic>> fields = const CsvToListConverter(
        shouldParseNumbers: false, 
        eol: '\n'
      ).convert(body);

      expect(fields.isNotEmpty, true, reason: 'CSV 解析後不應為空');
      print('解析後總列數 (含標頭): ${fields.length}');

      if (fields.isNotEmpty) {
        final header = fields[0].map((e) => e.toString().toLowerCase().trim()).toList();
        print('偵測到的標頭: $header');

        // 檢查關鍵欄位是否存在
        final requiredFields = ['lineid', 'latitude', 'longitude', 'time'];
        for (var field in requiredFields) {
          expect(header.contains(field), true, reason: '標頭應包含 $field');
        }

        // 檢查第一筆資料內容
        if (fields.length > 1) {
          final firstRow = fields[1];
          print('第一筆資料範例: $firstRow');
          
          int idxLineId = header.indexOf('lineid');
          int idxLat = header.indexOf('latitude');
          int idxLng = header.indexOf('longitude');
          int idxTime = header.indexOf('time');

          expect(firstRow[idxLineId].toString().isNotEmpty, true, reason: 'LineID 不應為空');
          expect(double.tryParse(firstRow[idxLat].toString()), isNotNull, reason: '緯度應為數字');
          expect(double.tryParse(firstRow[idxLng].toString()), isNotNull, reason: '經度應為數字');
          expect(firstRow[idxTime].toString().isNotEmpty, true, reason: '抵達時間不應為空');
        }
      }
    });

    test('驗證即時位置 CSV API 連線', () async {
      /// 測試即時位置 API：驗證連線狀態並輸出即時位置 CSV 的標頭範例
      final String apiUrl = 'https://data.ntpc.gov.tw/api/datasets/28ab4122-60e1-4065-98e5-abccb69aaca6/csv';
      print('正在請求即時位置 URL: $apiUrl?size=5');
      
      final response = await http.get(Uri.parse('$apiUrl?size=5'), headers: headers);
      expect(response.statusCode, 200);

      final List<List<dynamic>> rows = const CsvToListConverter(
        shouldParseNumbers: false, 
        eol: '\n'
      ).convert(response.body.trim());

      print('即時位置標頭: ${rows.isNotEmpty ? rows[0] : "空"}');
      if (rows.length > 1) {
        print('即時位置資料範例: ${rows[1]}');
      }
    });
  });
}
