import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('台中市 API 真實連線診斷', () {
    const String dynamicApiUrl = 'https://newdatacenter.taichung.gov.tw/api/v1/no-auth/resource.download?rid=c923ad20-2ec6-43b9-b3ab-54527e99f7bc';
    const String routeApiUrl = 'https://newdatacenter.taichung.gov.tw/api/v1/no-auth/resource.download?rid=68d1a87f-7baa-4b50-8408-c36a3a7eda68';

    test('診斷：台中市即時動態 API 連線', () async {
      print('\n--- 台中市即時動態 API 測試 ---');
      // 使用與實作一致的 20,000 筆上限測試
      final String url = '$dynamicApiUrl&limit=20000';
      print('請求網址: $url');

      final response = await http.get(Uri.parse(url));
      
      expect(response.statusCode, 200, reason: 'API 應該回傳 HTTP 200');
      
      final List<dynamic> data = json.decode(response.body);
      print('成功抓取到即時車輛位置: ${data.length} 筆');
      
      if (data.isNotEmpty) {
        final sample = data.first;
        print('樣本資料 (第一筆):');
        print(' - 車號 (car): ${sample['car']}');
        print(' - 路線 (lineid): ${sample['lineid']}');
        print(' - 時間 (time): ${sample['time']}');
        print(' - 位置 (X, Y): ${sample['X']}, ${sample['Y']}');
        print(' - 地點說明: ${sample['location']}');
      } else {
        print('警告：API 回傳資料為空 (可能目前非收運時間)');
      }
    });

    test('診斷：台中市路線班表 API 連線', () async {
      print('\n--- 台中市路線班表 API 測試 ---');
      final String url = '$routeApiUrl&limit=100'; // 診斷時僅抓取前 100 筆確認結構
      print('請求網址: $url');

      final response = await http.get(Uri.parse(url));
      
      expect(response.statusCode, 200, reason: 'API 應該回傳 HTTP 200');
      
      final List<dynamic> data = json.decode(response.body);
      print('成功抓取到班表資料樣本: ${data.length} 筆');
      
      if (data.isNotEmpty) {
        final sample = data.first;
        print('樣本資料 (第一筆):');
        print(' - 行政區: ${sample['area']}');
        print(' - 站點說明: ${sample['caption']}');
        print(' - 班表車牌: ${sample['car_licence']}');
        print(' - 週一時間 (g_d1_time_s): ${sample['g_d1_time_s']}');
      }
    });
  });
}
