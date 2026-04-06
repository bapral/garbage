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
      final service = NtpcGarbageService(localSourceDir: tempDir.path);
      await service.syncDataIfNeeded();
      final count = await dbService.getTotalCount();
      expect(count, greaterThanOrEqualTo(2));

      await service.syncDataIfNeeded();
      final countAgain = await dbService.getTotalCount();
      expect(countAgain, equals(count));
    });

    testWidgets('AppBar display record count', (WidgetTester tester) async {
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
