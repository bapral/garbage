/// [整體程式說明]: 台南市真實同步測試，驗證從真實 API 抓取台南市清運點資料（應超過 10000 筆）並存入資料庫，以及獲取即時 GPS 車輛的穩定性。
/// [執行順序說明]:
/// 1. 初始化測試環境與臨時目錄。
/// 2. 測試真實同步：執行 syncDataIfNeeded，驗證資料庫中的台南市點位總數是否符合預期門檻。
/// 3. 測試特定路線：獲取路線 18 的點位並斷言其內容。
/// 4. 測試真實 GPS：呼叫 fetchTrucks 並驗證是否能成功抓取到即時車輛（含座標與車號）。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ntpc_garbage_map/services/tainan_garbage_service.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  late TainanGarbageService service;
  late String tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    PackageInfo.setMockInitialValues(
      appName: 'ntpc_garbage_map',
      packageName: 'com.example.ntpc_garbage_map',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'buildSignature',
    );
  });

  setUp(() async {
    tempDir = p.join(Directory.systemTemp.path, 'tainan_real_sync_test_${DateTime.now().millisecondsSinceEpoch}');
    await Directory(tempDir).create(recursive: true);
    
    DatabaseService.customPath = p.join(tempDir, 'test_tainan_real.db');
    DatabaseService.resetInstance();
    
    service = TainanGarbageService(localSourceDir: tempDir);
  });

  tearDown(() async {
    DatabaseService.resetInstance();
    try {
      if (await Directory(tempDir).exists()) {
        await Directory(tempDir).delete(recursive: true);
      }
    } catch (_) {}
  });

  test('台南市真實同步測試：從 API 抓取並存入資料庫', () async {
    /// 測試真實同步：驗證台南市資料同步後，資料庫中的總點位數是否符合大於 10000 筆的預期門檻
    print('開始同步台南市資料...');
    await service.syncDataIfNeeded(onProgress: (msg) {
      print('進度: $msg');
    });

    final dbCount = await DatabaseService().getTotalCount('tainan');
    print('資料庫內台南市點位總數: $dbCount');
    
    expect(dbCount, greaterThan(10000), reason: '台南市資料應超過 10000 筆');

    // 測試隨機抓取一條路線
    final points = await service.getRouteForLine('18');
    print('路線 18 的點位數: ${points.length}');
    expect(points.isNotEmpty, true);
    if (points.isNotEmpty) {
      print('第一站: ${points.first.name} (${points.first.arrivalTime})');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('台南市真實 GPS 測試：從 API 抓取即時車輛', () async {
    /// 測試真實 GPS：驗證是否能成功抓取即時車輛資料，確保座標與車號欄位有效
    print('開始抓取台南市即時 GPS...');
    final trucks = await service.fetchTrucks();
    print('獲取到 ${trucks.length} 台車輛');
    
    // 如果現在不是收運時間，可能很少車，但 API 應該要回傳資料（即使只有幾台）
    // 根據之前測試有 13 台
    expect(trucks.isNotEmpty, true);
    
    if (trucks.isNotEmpty) {
      final truck = trucks.first;
      print('車號: ${truck.carNumber}, 位置: ${truck.location}, 座標: ${truck.position}');
      expect(truck.carNumber, isNot('未知車號'));
      expect(truck.position.latitude, isNot(0));
    }
  }, timeout: const Timeout(Duration(minutes: 1)));
}
