import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('--- 台南市 API 簡易連線測試 ---');
  
  final gpsUrl = 'https://soa.tainan.gov.tw/Api/Service/Get/2c8a70d5-06f2-4353-9e92-c40d33bcd969';
  final routeUrl = 'https://soa.tainan.gov.tw/Api/Service/Get/84df8cd6-8741-41ed-919c-5105a28ecd6d';

  try {
    print('\n[1/2] 測試即時 GPS API...');
    final gpsRes = await http.get(Uri.parse(gpsUrl));
    print('  狀態碼: ${gpsRes.statusCode}');
    if (gpsRes.statusCode == 200) {
      final data = json.decode(utf8.decode(gpsRes.bodyBytes));
      final List records = data['data'] ?? [];
      print('  成功！獲取到 ${records.length} 筆資料');
      if (records.isNotEmpty) {
        print('  範例: ${records.first}');
      }
    }

    print('\n[2/2] 測試清運點 API (僅抓取前幾筆)...');
    final routeRes = await http.get(Uri.parse(routeUrl));
    print('  狀態碼: ${routeRes.statusCode}');
    if (routeRes.statusCode == 200) {
      final data = json.decode(utf8.decode(routeRes.bodyBytes));
      final List records = data['data'] ?? [];
      print('  成功！總共獲取到 ${records.length} 筆資料');
      if (records.isNotEmpty) {
        print('  範例: ${records.first}');
      }
    }

  } catch (e) {
    print('發生錯誤: $e');
  }
  
  print('\n--- 測試結束 ---');
  exit(0);
}
