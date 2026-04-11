/// - **測試目的**: 版本化本地匯入與 UI 測試：驗證資料同步的跳過機制、版本檢查以及地圖 AppBar 與詳細資訊卡的顯示。
/// - **測試覆蓋**: 
///   - 資料同步跳過機制（版本一致時不重複匯入）。
///   - AppBar 顯示快取紀錄數量驗證。
///   - BottomSheet 中 SelectableText 組件使用驗證。
/// - **測試執行順序**: 初始化 sqflite_ffi 並設定臨時目錄與 CSV -> 執行首次與重複同步測試筆數 -> 啟動 MapScreen 並驗證快取文字 -> 點擊標記驗證資訊卡文字類型。

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ntpc_garbage_map/screens/map_screen.dart';
import 'package:ntpc_garbage_map/services/ntpc_garbage_service.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockTrucksNotifier extends GarbageTrucksNotifier {
  @override
  List<GarbageTruck> build() {
    Future.microtask(() => ref.read(isSyncingProvider.notifier).setSyncing(false));
    return [
      GarbageTruck(
        carNumber: 'ABC-1234', 
        lineId: 'L1', 
        location: 'Test Location', 
        position: LatLng(25.0125, 121.4650), 
        updateTime: DateTime.now()
      )
    ];
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: "map", packageName: "map", version: "1.0.0", buildNumber: "4", buildSignature: "1"
    );
  });

  group('Versioned Local Import & UI Tests', () {
    /// 版本化本地匯入與 UI 測試：驗證資料同步的跳過機制以及 AppBar 與 BottomSheet 的顯示資訊
    late Directory tempDir;
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService();
      DatabaseService.customPath = inMemoryDatabasePath;
      final db = await dbService.db;
      await db.delete(DatabaseService.tableName);
      await db.delete(DatabaseService.metaTable);

      tempDir = Directory.systemTemp.createTempSync('garbage_test');
      final tempCsv = File('${tempDir.path}/test_routes.csv');
      tempCsv.writeAsStringSync(
        'lineId,latitude,longitude,time\n'
        'TEST-01,24.9742,121.5284,20:30\n'
        'TEST-01,24.9750,121.5290,20:45\n'
      );
    });

    tearDown(() {
      DatabaseService.customPath = null;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('syncDataIfNeeded should import and skip correctly', () async {
      /// 測試同步跳過機制：驗證當本地資料已存在且版本一致時，第二次同步應正確跳過以節省效能
      final service = NtpcGarbageService(localSourceDir: tempDir.path);
      await service.syncDataIfNeeded();
      final count = await dbService.getTotalCount();
      expect(count, greaterThanOrEqualTo(2));

      await service.syncDataIfNeeded();
      final countAgain = await dbService.getTotalCount();
      expect(countAgain, equals(count));
    });

    testWidgets('AppBar display record count', (WidgetTester tester) async {
      /// 測試 AppBar 顯示：驗證地圖標題列是否正確顯示當前緩存的紀錄數量
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            garbageTrucksProvider.overrideWith(MockTrucksNotifier.new),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('快取'), findsWidgets);
    });

    testWidgets('SelectableText in BottomSheet', (WidgetTester tester) async {
      /// 測試 BottomSheet 內容：驗證點擊垃圾車後出現的詳細資訊卡中，是否使用了可選取的文字元件（SelectableText）
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            garbageTrucksProvider.overrideWith(MockTrucksNotifier.new),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.local_shipping_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsAtLeast(1));
      expect(find.text('ABC-1234'), findsOneWidget);
    });
  });
}
