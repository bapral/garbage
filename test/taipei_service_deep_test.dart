import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ntpc_garbage_map/models/garbage_route_point.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:ntpc_garbage_map/services/taipei_garbage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  // 初始化 sqflite_ffi 供測試使用
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('TaipeiGarbageService Deep Tests', () {
    late DatabaseService dbService;
    late TaipeiGarbageService taipeiService;
    late Directory tempDir;

    setUp(() async {
      dbService = DatabaseService();
      DatabaseService.customPath = inMemoryDatabasePath;
      // 清空資料庫
      final db = await dbService.db;
      await db.delete(DatabaseService.tableName);
      await db.delete(DatabaseService.metaTable);

      // 建立臨時目錄存放測試 CSV
      tempDir = await Directory.systemTemp.createTemp('taipei_test');
      taipeiService = TaipeiGarbageService(localSourceDir: tempDir.path);
      
      // Mock PackageInfo (通常在測試環境中需要這個)
      PackageInfo.setMockInitialValues(
        appName: "garbage_map",
        packageName: "com.example.ntpc_garbage_map",
        version: "1.0.0",
        buildNumber: "1",
        buildSignature: "",
        installerStore: null,
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('CSV parsing should correctly handle Taipei City format (1630 -> 16:30)', () async {
      // 建立模擬台北市 CSV 資料
      // 行政區,里別,分隊,局編,車號,路線,車次,抵達時間,離開時間,地點,經度,緯度
      final csvContent = '''行政區,里別,分隊,局編,車號,路線,車次,抵達時間,離開時間,地點,經度,緯度
士林區,天壽里,天母分隊,103-074,821-BT,天母-1,第1車,1630,1640,臺北市士林區天母西路48號,121.525,25.11836
士林區,天壽里,天母分隊,103-074,821-BT,天母-1,第1車,1705,1715,臺北市士林區天母西路20號,121.52724,25.1184
''';
      
      final csvFile = File('${tempDir.path}/taipei.csv');
      await csvFile.writeAsString(csvContent);

      // 執行同步
      await taipeiService.syncDataIfNeeded();

      // 驗證資料庫中的資料
      final count = await dbService.getTotalCount();
      expect(count, equals(2));

      // 搜尋 16:30 的點
      final pointsAt1630 = await dbService.findPointsByTime(16, 30, 'taipei');
      expect(pointsAt1630.length, equals(1));
      expect(pointsAt1630.first.name, contains('天母西路48號'));
      expect(pointsAt1630.first.arrivalTime, equals('16:30'));
      expect(pointsAt1630.first.position.latitude, equals(25.11836));
      expect(pointsAt1630.first.position.longitude, equals(121.525));

      // 搜尋 17:00 的點 (應該搜尋到 17:05 的)
      final pointsAt1700 = await dbService.findPointsByTime(17, 0, 'taipei');
      expect(pointsAt1700.length, equals(1));
      expect(pointsAt1700.first.arrivalTime, equals('17:05'));
    });

    test('findTrucksByTime should return Taipei predicted trucks correctly', () async {
      final csvContent = '''行政區,里別,分隊,局編,車號,路線,車次,抵達時間,離開時間,地點,經度,緯度
士林區,天壽里,天母分隊,103-074,821-BT,天母-1,第1車,1900,1905,地點A,121.5,25.1
''';
      await File('${tempDir.path}/taipei.csv').writeAsString(csvContent);
      await taipeiService.syncDataIfNeeded();

      final predictedTrucks = await taipeiService.findTrucksByTime(19, 0);
      
      expect(predictedTrucks.length, equals(1));
      expect(predictedTrucks.first.carNumber, equals('預定車'));
      expect(predictedTrucks.first.lineId, equals('天母-1-821-BT'));
      expect(predictedTrucks.first.location, contains('天母-1 (821-BT) - 地點A'));
    });
  });
}
