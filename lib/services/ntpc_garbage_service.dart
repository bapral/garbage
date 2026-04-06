import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/garbage_truck.dart';
import '../models/garbage_route_point.dart';
import 'database_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:csv/csv.dart';
import 'dart:io';

/// 城市服務抽象介面
abstract class BaseGarbageService {
  final String localSourceDir;
  BaseGarbageService({required this.localSourceDir});

  Future<void> syncDataIfNeeded({void Function(String)? onProgress});
  Future<List<GarbageTruck>> fetchTrucks();
  Future<List<GarbageTruck>> findTrucksByTime(int hour, int minute);
  Future<List<GarbageRoutePoint>> getRouteForLine(String lineId);
}

/// 新北市專屬實作
class NtpcGarbageService extends BaseGarbageService {
  static const String apiUrl = 'https://data.ntpc.gov.tw/api/datasets/39e17852-9ac9-45b7-bc60-d8d0ed7e3161/json';
  static const String routeUrl = 'https://data.ntpc.gov.tw/api/datasets/2ED449AA-96BB-4A34-A705-F91D3D9EF281/json';

  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
    'Referer': 'https://data.ntpc.gov.tw/',
  };

  final DatabaseService _dbService = DatabaseService();

  NtpcGarbageService({required super.localSourceDir});

  @override
  Future<void> syncDataIfNeeded({void Function(String)? onProgress}) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentAppVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final String? storedVersion = await _dbService.getStoredVersion();

    if (storedVersion == currentAppVersion) {
      if (await _dbService.hasData()) {
        onProgress?.call('資料版本一致 ($currentAppVersion)，載入中...');
        return;
      }
    }

    onProgress?.call('正在匯入新北市本地資料...');
    await _dbService.clearAllRoutePoints();
    
    bool success = await _importFromLocalCSV(onProgress);
    
    if (success) {
      await _dbService.updateVersion(currentAppVersion);
      onProgress?.call('匯入完成！');
    } else {
      await _insertMockRouteData();
    }
  }

  Future<bool> _importFromLocalCSV(void Function(String)? onProgress) async {
    try {
      final dir = Directory(localSourceDir);
      if (!await dir.exists()) return false;

      final List<FileSystemEntity> files = await dir.list().toList();
      final csvFile = files.firstWhere((f) => f.path.toLowerCase().endsWith('.csv')) as File;
      
      final String csvContent = await csvFile.readAsString();
      final List<List<dynamic>> fields = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert(csvContent);

      if (fields.isEmpty) return false;

      final header = fields[0].map((e) => e.toString().toLowerCase().trim()).toList();
      
      int findIndex(List<String> keywords) {
        for (var k in keywords) {
          int idx = header.indexOf(k.toLowerCase());
          if (idx != -1) return idx;
        }
        return -1;
      }

      final int idxLineId = findIndex(['lineid', '路線編號']);
      final int idxLat = findIndex(['latitude', '緯度', 'lat']);
      final int idxLng = findIndex(['longitude', '經度', 'lng', 'lon']);
      final int idxTime = findIndex(['time', '抵達時間']);
      final int idxLineName = findIndex(['linename', '路線名稱']);
      final int idxName = findIndex(['name', '清運點名稱']);
      final int idxRank = findIndex(['rank', '順序']);

      List<GarbageRoutePoint> batch = [];
      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        if (row.length <= max(idxLineId, max(idxLat, idxTime))) continue;

        batch.add(GarbageRoutePoint(
          lineId: row[idxLineId].toString(),
          lineName: idxLineName != -1 ? row[idxLineName].toString() : '',
          rank: idxRank != -1 ? (int.tryParse(row[idxRank].toString()) ?? 0) : i,
          name: idxName != -1 ? row[idxName].toString() : '',
          position: LatLng(double.tryParse(row[idxLat].toString()) ?? 0, double.tryParse(row[idxLng].toString()) ?? 0),
          arrivalTime: row[idxTime].toString(),
        ));

        if (batch.length >= 2000) {
          await _dbService.saveRoutePoints(batch);
          batch.clear();
          onProgress?.call('已匯入 $i / ${fields.length - 1} 筆...');
        }
      }
      if (batch.isNotEmpty) await _dbService.saveRoutePoints(batch);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<GarbageTruck>> fetchTrucks() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl?size=1000'), headers: _headers);
      if (response.statusCode == 200 && response.body.contains('[{')) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => GarbageTruck.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<List<GarbageTruck>> findTrucksByTime(int hour, int minute) async {
    final points = await _dbService.findPointsByTime(hour, minute);
    final now = DateTime.now();
    return points.map((p) {
      DateTime scheduledTime = now;
      try {
        final parts = p.arrivalTime.split(':');
        if (parts.length == 2) scheduledTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      } catch (_) {}
      return GarbageTruck(carNumber: '預定車輛', lineId: p.lineId, location: '${p.lineName} - ${p.name}', position: p.position, updateTime: scheduledTime);
    }).toList();
  }

  @override
  Future<List<GarbageRoutePoint>> getRouteForLine(String lineId) async {
    return await _dbService.getRoutePoints(lineId);
  }

  Future<void> _insertMockRouteData() async {
    await _dbService.saveRoutePoints([
      GarbageRoutePoint(lineId: '新店-01', lineName: '新店線', rank: 1, name: '中央八街口', position: LatLng(24.9742, 121.5284), arrivalTime: '20:30'),
    ]);
  }
}
