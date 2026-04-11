/// - **測試目的**: 台北市新版 API 診斷：分析中文欄位結構與資料正確性，確保服務能正確提取車號、地點、座標及匯入日期。
/// - **測試覆蓋**: 
///   - 台北市 API JSON 結構（Map/List）辨識。
///   - 關鍵中文欄位（車號、地點、經度、緯度、路線、抵達時間）存在性分析。
///   - _importdate 內部結構（date 字串）解析相容性診斷。
///   - 座標欄位（緯度、經度）轉換為 double 的準確性測試。
/// - **測試執行順序**: 向台北市 API 發送帶有標頭的請求 -> 驗證狀態碼並解析 JSON 結構 -> 分析首筆資料的中文欄位與日期結構 -> 執行座標解析測試並輸出詳細診斷報告。

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ntpc_garbage_map/services/taipei_garbage_service.dart';

void main() {
  const Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  group('Taipei City New API Diagnostic (Chinese Fields)', () {
    /// 台北市新版 API 診斷：分析中文欄位結構與資料正確性
    test('Fetch and analyze Taipei Garbage Truck API with Chinese Fields', () async {
      /// 測試獲取並分析：驗證台北市垃圾車 API 是否包含預期的中文欄位（如「車號」、「地點」等）以及 _importdate 結構
      final url = TaipeiGarbageService.apiUrl;
      print('--- 台北市新 API 深度診斷開始 ---');
      print('目標 URL: $url');
      
      try {
        final response = await http.get(Uri.parse(url), headers: headers);
        print('HTTP 狀態碼: ${response.statusCode}');
        
        if (response.statusCode != 200) {
          print('錯誤: API 請求失敗，狀態碼非 200。回傳內容: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
          return;
        }

        final dynamic decoded = json.decode(response.body);
        List<dynamic> results = [];

        if (decoded is Map && decoded.containsKey('result')) {
          results = decoded['result']['results'] ?? [];
          print('成功！獲取到 Map (result/results) 結構，共 ${results.length} 筆資料。');
        } else if (decoded is List) {
          results = decoded;
          print('成功！獲取到 List 結構，共 ${results.length} 筆資料。');
        } else {
          print('錯誤: 未知 JSON 結構: ${decoded.runtimeType}');
          return;
        }

        if (results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          print('--- 資料結構與中文欄位分析 ---');
          
          // 檢查我們在 Service 中使用的關鍵中文欄位
          final chineseFields = ['車號', '地點', '經度', '緯度', '路線', '抵達時間'];
          for (var field in chineseFields) {
            if (first.containsKey(field)) {
              print('  [OK] 欄位 "$field" 存在，值: ${first[field]} (${first[field].runtimeType})');
            } else {
              print('  [!!] 警告: 找不到預期的中文欄位 "$field"');
            }
          }

          // 特別診斷 _importdate 結構
          if (first.containsKey('_importdate')) {
            print('--- _importdate 內部結構 ---');
            final importDate = first['_importdate'];
            if (importDate is Map) {
              importDate.forEach((k, v) => print('  $k: $v ($v.runtimeType)'));
              if (importDate.containsKey('date')) {
                final dateStr = importDate['date'].toString();
                final parsed = DateTime.tryParse(dateStr);
                print('  解析測試: "$dateStr" -> ${parsed != null ? "成功: $parsed" : "失敗"}');
              }
            } else {
              print('  _importdate 並非 Map 類型: ${importDate.runtimeType}');
            }
          }

          // 座標轉換測試
          final lat = double.tryParse(first['緯度']?.toString() ?? '0');
          final lon = double.tryParse(first['經度']?.toString() ?? '0');
          print('--- 座標解析測試 ---');
          print('  緯度(緯度): $lat');
          print('  經度(經度): $lon');

        } else {
          print('警告: 目前 API 回傳結果為空，可能是非清運時段。');
        }

      } catch (e) {
        print('診斷過程中發生例外: $e');
      }
      print('--- 台北市新 API 診斷結束 ---');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
