import 'package:flutter_test/flutter_test.dart';
import 'package:ntpc_garbage_map/services/taipei_garbage_service.dart';
import 'package:ntpc_garbage_map/services/ntpc_garbage_service.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Mock PackageInfo
    PackageInfo.setMockInitialValues(
      appName: 'ntpc_garbage_map',
      packageName: 'com.example.ntpc_garbage_map',
      version: '1.0.0',
      buildNumber: '6',
      buildSignature: '',
    );
  });

  group('同步門檻邏輯測試', () {
    final dbService = DatabaseService();
    final tempDir = Directory.systemTemp.createTempSync('garbage_test');

    test('測試台北市同步門檻 (應 > 1100 筆)', () async {
      final service = TaipeiGarbageService(localSourceDir: tempDir.path);
      
      print('開始台北市同步測試...');
      String lastStatus = '';
      await service.syncDataIfNeeded(onProgress: (p) {
        lastStatus = p;
        print('  [台北] $p');
      });

      final count = await dbService.getTotalCount();
      print('台北市同步後資料庫總筆數: $count');
      
      if (lastStatus.contains('更新完成')) {
        expect(count, greaterThan(1100), reason: '若顯示更新完成，筆數應大於 1100');
      }
    });

    test('測試新北市同步門檻 (應 > 5000 筆)', () async {
      final service = NtpcGarbageService(localSourceDir: tempDir.path);
      
      print('開始新北市同步測試...');
      String lastStatus = '';
      await service.syncDataIfNeeded(onProgress: (p) {
        lastStatus = p;
        print('  [新北] $p');
      });

      final count = await dbService.getTotalCount();
      print('新北市同步後資料庫總筆數: $count');

      if (lastStatus.contains('更新完成')) {
        expect(count, greaterThan(5000), reason: '若顯示更新完成，筆數應大於 5000');
      }
    });
  });
}
