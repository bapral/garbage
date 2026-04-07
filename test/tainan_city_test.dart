import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ntpc_garbage_map/services/tainan_garbage_service.dart';
import 'package:ntpc_garbage_map/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class ManualMockClient extends http.BaseClient {
  String? mockResponse;
  int mockStatus = 200;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(mockResponse ?? '[]')),
      mockStatus,
    );
  }
}

void main() {
  late TainanGarbageService service;
  late ManualMockClient mockClient;
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
    mockClient = ManualMockClient();
    tempDir = p.join(Directory.systemTemp.path, 'tainan_test_${DateTime.now().millisecondsSinceEpoch}');
    await Directory(tempDir).create(recursive: true);
    
    DatabaseService.customPath = p.join(tempDir, 'test_tainan.db');
    DatabaseService.resetInstance();
    
    service = TainanGarbageService(localSourceDir: tempDir, client: mockClient);
  });

  tearDown(() async {
    DatabaseService.resetInstance();
    try {
      if (await Directory(tempDir).exists()) {
        await Directory(tempDir).delete(recursive: true);
      }
    } catch (_) {}
  });

  group('TainanGarbageService 測試', () {
    test('fetchTrucks 應正確解析台南市動態 GPS API JSON', () async {
      mockClient.mockResponse = json.encode({
        "data": [
          {
            "car": "TNN-1234",
            "linid": "L-123",
            "y": "23.001",
            "x": "120.201",
            "location": "台南市中心"
          }
        ]
      });

      final trucks = await service.fetchTrucks();

      expect(trucks.length, 1);
      expect(trucks.first.carNumber, "TNN-1234");
      expect(trucks.first.lineId, "L-123");
      expect(trucks.first.position.latitude, 23.001);
      expect(trucks.first.position.longitude, 120.201);
    });

    test('syncDataIfNeeded 應從 API 同步清運點至資料庫', () async {
      mockClient.mockResponse = json.encode({
        "data": [
          {
            "ROUTEID": "R-5678",
            "POINTNAME": "安平古堡",
            "TIME": "17:30",
            "LATITUDE": "23.0012",
            "LONGITUDE": "120.1583",
            "AREA": "安平區",
            "ROUTEORDER": "1"
          }
        ]
      });

      await service.syncDataIfNeeded();

      final dbCount = await DatabaseService().getTotalCount('tainan');
      expect(dbCount, 1);

      final predictedTrucks = await service.findTrucksByTime(17, 30);
      expect(predictedTrucks.length, 1);
      expect(predictedTrucks.first.location, contains("安平古堡"));
      expect(predictedTrucks.first.updateTime.hour, 17);
      expect(predictedTrucks.first.updateTime.minute, 30);
    });

    test('當 API 失敗時，fetchTrucks 應降級至資料庫查詢 (回傳預測車)', () async {
      // 先同步一筆資料進資料庫
      mockClient.mockResponse = json.encode({
        "data": [
          {
            "ROUTEID": "DB-001",
            "POINTNAME": "資料庫地點",
            "TIME": "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}",
            "LATITUDE": "22.9",
            "LONGITUDE": "120.2",
            "AREA": "測試區",
            "ROUTEORDER": "1"
          }
        ]
      });
      await service.syncDataIfNeeded();

      // 模擬 API 噴錯
      mockClient.mockStatus = 500;
      mockClient.mockResponse = "Error";

      final trucks = await service.fetchTrucks();
      
      // 應回傳預定車
      expect(trucks.any((t) => t.carNumber == '預定車'), true);
      expect(trucks.any((t) => t.location.contains('資料庫地點')), true);
    });
  });
}
