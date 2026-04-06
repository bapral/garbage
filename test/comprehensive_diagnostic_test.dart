import 'package:flutter_test/flutter_test.dart';
import 'package:ntpc_garbage_map/services/garbage_service.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Comprehensive Diagnostic: Initialize DB and Search Central 8th St', () async {
    final dbService = DatabaseService();
    final garbageService = GarbageService();

    // 1. 強制清空舊資料，重新模擬初始化
    print('--- 診斷開始：重新初始化資料庫 ---');
    await dbService.clearAllRoutePoints();
    
    // 2. 執行分頁抓取 (這會花一點時間，測試環境可能只跑前幾頁)
    await garbageService.initializeRouteData();

    // 3. 檢查總筆數
    final count = await dbService.getTotalCount();
    print('資料庫總筆數: $count');
    expect(count, isPositive, reason: '資料庫不應為空');

    // 4. 關鍵字搜尋：中央八街
    print('正在搜尋「中央八街」相關點位...');
    final keywordResults = await dbService.searchPointsByName('中央八街');
    if (keywordResults.isEmpty) {
      print('警告：資料庫中找不到任何名稱包含「中央八街」的清運點。');
    } else {
      print('成功！找到 ${keywordResults.length} 筆中央八街相關點位。');
      for (var p in keywordResults) {
        print('  - 路線: ${p.lineId}, 時間: ${p.arrivalTime}, 名稱: ${p.name}');
      }
    }

    // 5. 時間搜尋：20:30 (前後 15 分鐘)
    print('正在搜尋 20:30 預計經過的所有車輛...');
    final timeResults = await dbService.findPointsByTime(20, 30);
    print('在 20:30 (±15分) 區間內找到 ${timeResults.length} 筆車輛位置。');
    
    expect(timeResults, isNotEmpty, reason: '20:30 應該要有排班車輛');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
