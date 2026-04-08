import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  test('高雄市 api.kcg.gov.tw 即時 API 診斷測試', () async {
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
