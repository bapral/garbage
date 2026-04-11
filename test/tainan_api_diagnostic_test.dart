/// - **測試目的**: 台南市政府開放資料 API 真實連線診斷測試，驗證新版即時 GPS 與清運點（班表）API 的連通性與資料格式。
/// - **測試覆蓋**: 
///   - 即時 GPS API 連通性、狀態碼與 success 旗標驗證。
///   - GPS 資料欄位結構解析與統計。
///   - 清運點（班表）API 連線性與欄位範例輸出。
/// - **測試執行順序**: 向台南市新版 API 發送 GET 請求 -> 驗證 HTTP 狀態碼與成功旗標 -> 解析資料欄位並統計記錄筆數 -> 輸出首筆記錄的所有欄位內容供檢視。

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('診斷：台南市即時 GPS API 真實連線測試 (新網址)', () async {
    /// 測試 GPS API：驗證台南市即時 GPS 資料的獲取與 JSON 欄位結構是否正確
    const String url = 'https://soa.tainan.gov.tw/Api/Service/Get/2c8a70d5-06f2-4353-9e92-c40d33bcd969';
    
    print('\n--- 台南市即時 GPS API 診斷 ---');
    print('連線至: $url');
    
    try {
      final response = await http.get(Uri.parse(url));
      print('HTTP 狀態碼: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        if (data['success'] == true) {
          final List<dynamic> records = data['data'] ?? [];
          print('成功獲取資料，共 ${records.length} 筆記錄');
          
          if (records.isNotEmpty) {
            print('第一筆資料所有欄位:');
            final first = records.first;
            first.forEach((key, value) {
              print('  $key: $value');
            });
          } else {
            print('警告：API 回傳的 records 清單是空的！');
          }
        } else {
          print('錯誤：API 回傳 success = false');
          print('錯誤訊息: ${data['message']}');
        }
      } else {
        print('錯誤：HTTP 失敗');
        print('內容: ${response.body}');
      }
    } catch (e) {
      print('連線異常: $e');
    }
  });

  test('診斷：台南市清運點 (班表) API 真實連線測試 (新網址)', () async {
    /// 測試班表 API：驗證台南市班表 API 的連通性並輸出範例欄位以供檢視
    const String url = 'https://soa.tainan.gov.tw/Api/Service/Get/84df8cd6-8741-41ed-919c-5105a28ecd6d';
    
    print('\n--- 台南市清運點 API 診斷 ---');
    print('連線至: $url');
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final records = data['data'] ?? [];
          print('成功獲取班表，共 ${records.length} 筆');
          if (records.isNotEmpty) {
            print('班表欄位範例:');
            (records.first as Map).forEach((k, v) => print('  $k: $v'));
          }
        }
      }
    } catch (e) {
      print('班表連線異常: $e');
    }
  });
}
