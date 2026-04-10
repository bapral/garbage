/// [整體程式說明]: 台南市真實 API 同步指令稿，用於模擬真實 App 的資料同步流程，執行台南市清運點班表的同步匯入以及即時 GPS 車輛抓取測試。
/// [執行順序說明]:
/// 1. 初始化 FFI 與模擬 PackageInfo。
/// 2. 建立臨時目錄並指定測試資料庫路徑。
/// 3. 執行同步清運點流程，並驗證資料庫總筆數是否符合預期（>10000 筆）。
/// 4. 執行即時 GPS 獲取測試，若有回傳資料則輸出範例車輛資訊。
/// 5. 清理環境並刪除臨時目錄。

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ntpc_garbage_map/services/tainan_garbage_service.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

/// 台南市真實 API 同步指令稿
/// 本指令稿用於模擬真實 App 的資料同步流程，執行台南市清運點班表的同步匯入以及即時 GPS 車輛抓取測試。
void main() async {
  print('--- 台南市真實 API 同步指令稿 ---');
  
  // 初始化 FFI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  PackageInfo.setMockInitialValues(
    appName: 'ntpc_garbage_map',
    packageName: 'com.example.ntpc_garbage_map',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: 'buildSignature',
  );

  final tempDir = p.join(Directory.systemTemp.path, 'tainan_real_sync_script_${DateTime.now().millisecondsSinceEpoch}');
  await Directory(tempDir).create(recursive: true);
  
  DatabaseService.customPath = p.join(tempDir, 'test_tainan_real_script.db');
  DatabaseService.resetInstance();
  
  final service = TainanGarbageService(localSourceDir: tempDir);

  try {
    print('\n[1/2] 正在同步清運點...');
    await service.syncDataIfNeeded(onProgress: (msg) => print('  > $msg'));

    final dbCount = await DatabaseService().getTotalCount('tainan');
    print('  > 資料庫總筆數: $dbCount');
    
    if (dbCount > 10000) {
      print('  > [成功] 同步筆數符合預期');
    } else {
      print('  > [失敗] 同步筆數不足: $dbCount');
    }

    print('\n[2/2] 正在獲取即時 GPS...');
    final trucks = await service.fetchTrucks();
    print('  > 獲取到 ${trucks.length} 台車輛');
    
    if (trucks.isNotEmpty) {
      final truck = trucks.first;
      print('  > [成功] 範例車輛: ${truck.carNumber} (${truck.location}) at ${truck.position}');
    } else {
      print('  > [警告] 目前沒有在線車輛，但這在非收運時間是正常的。');
    }

  } catch (e, stack) {
    print('發生異常: $e');
    print(stack);
  } finally {
    DatabaseService.resetInstance();
    await Directory(tempDir).delete(recursive: true);
    print('\n--- 指令稿結束 ---');
    exit(0);
  }
}
