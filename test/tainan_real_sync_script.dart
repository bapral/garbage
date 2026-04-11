/// - **測試目的**: 台南市真實 API 同步指令稿，用於模擬真實 App 的資料同步流程，執行台南市清運點班表的同步匯入以及即時 GPS 車輛抓取測試。
/// - **測試覆蓋**: 
///   - 真實 API 班表同步流程（應 >10000 筆資料）。
///   - 即時 GPS 獲取穩定性與資料內容（車號、地點、座標）。
///   - 異常處理與環境清理（臨時目錄刪除）。
/// - **測試執行順序**: 初始化 FFI 與模擬 PackageInfo -> 建立臨時目錄並指定測試資料庫 -> 執行清運點同步流程並驗證筆數 -> 執行即時 GPS 獲取測試 -> 清理測試環境。

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
