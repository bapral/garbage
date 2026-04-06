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
    test('NTPC: Real Connection Test (CSV Route API)', () async {
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
