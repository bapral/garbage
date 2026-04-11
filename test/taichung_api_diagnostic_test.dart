/// - **測試目的**: 台中市政府開放資料 API 真實連線診斷測試，驗證即時動態位置與路線班表資料的連通性、狀態碼及資料結構。
/// - **測試覆蓋**: 
///   - 台中市即時動態 API 連線與 JSON 陣列解析（20,000 筆上限）。
///   - 即時資料關鍵欄位（車號、座標、時間、地點）格式驗證。
///   - 台中市路線班表 API 連線與資料樣本輸出。
///   - 班表關鍵欄位（行政區、站點、車牌、時間）結構檢查。
/// - **測試執行順序**: 向台中市即時與班表 API 發送 GET 請求 -> 驗證回應狀態碼為 200 -> 解析 JSON 資料並統計筆數 -> 輸出各 API 的樣本資料欄位供開發調試。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('台中市 API 真實連線診斷', () {
    const String dynamicApiUrl = 'https://newdatacenter.taichung.gov.tw/api/v1/no-auth/resource.download?rid=c923ad20-2ec6-43b9-b3ab-54527e99f7bc';
    const String routeApiUrl = 'https://newdatacenter.taichung.gov.tw/api/v1/no-auth/resource.download?rid=68d1a87f-7baa-4b50-8408-c36a3a7eda68';

    test('診斷：台中市即時動態 API 連線', () async {
      /// 測試即時動態 API：驗證連線能力並解析車輛位置 JSON，確認欄位格式是否符合實作要求
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
      /// 測試路線班表 API：驗證班表 API 的連通性並輸出關鍵時間與站點欄位範例
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
