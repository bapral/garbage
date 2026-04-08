import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ntpc_garbage_map/services/kaohsiung_garbage_service.dart';

void main() {
  test('高雄市 API 連結連通性探針', () async {
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
