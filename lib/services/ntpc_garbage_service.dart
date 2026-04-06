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

abstract class BaseGarbageService {
  final String localSourceDir;
  BaseGarbageService({required this.localSourceDir});
  Future<void> syncDataIfNeeded({void Function(String)? onProgress});
  Future<List<GarbageTruck>> fetchTrucks();
  Future<List<GarbageTruck>> findTrucksByTime(int hour, int minute);
  Future<List<GarbageRoutePoint>> getRouteForLine(String lineId);
}

class NtpcGarbageService extends BaseGarbageService {
  // 依照使用者提供的正確即時位置 CSV 端點
  static const String apiUrl = 'https://data.ntpc.gov.tw/api/datasets/28ab4122-60e1-4065-98e5-abccb69aaca6/csv';
  static const String routeUrl = 'https://data.ntpc.gov.tw/api/datasets/edc3ad26-8ae7-4916-a00b-bc6048d19bf8/csv';

  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/csv, application/json',
    'Referer': 'https://data.ntpc.gov.tw/',
  };

  final DatabaseService _dbService = DatabaseService();
  final http.Client _client;

  NtpcGarbageService({required super.localSourceDir, http.Client? client}) 
      : _client = client ?? http.Client();

  @override
  Future<void> syncDataIfNeeded({void Function(String)? onProgress}) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentAppVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final String? storedVersion = await _dbService.getStoredVersion();

    bool needsUpdate = storedVersion != currentAppVersion || !(await _dbService.hasData('ntpc'));

    if (!needsUpdate) {
      onProgress?.call('新北市資料已就緒...');
      return;
    }

    onProgress?.call('正在嘗試從雲端更新新北市路線...');
    bool apiSuccess = await _syncFromApi(onProgress);

    if (apiSuccess) {
      await _dbService.updateVersion(currentAppVersion);
      onProgress?.call('新北市路線已透過 API 更新完成！');
    } else {
      onProgress?.call('API 更新失敗或筆數不足，嘗試從本地 CSV 恢復...');
      if (await _importFromLocalCSV(onProgress)) {
        await _dbService.updateVersion(currentAppVersion);
        onProgress?.call('新北市路線已從本地 CSV 更新完成。');
      } else {
        onProgress?.call('新北市本地 CSV 也無法讀取，嘗試使用模擬資料。');
        await _insertMockRouteData();
      }
    }
  }

  Future<bool> _syncFromApi(void Function(String)? onProgress) async {
    try {
      // 請求較大筆數 (size=100000) 以獲取完整路線
      final response = await _client.get(Uri.parse('$routeUrl?size=100000'), headers: _headers);
      
      if (response.statusCode == 200) {
        final String body = response.body.trim();
        final List<List<dynamic>> fields = const CsvToListConverter(
          shouldParseNumbers: false, 
          eol: '\n'
        ).convert(body);

        if (fields.length > 5000) {
          onProgress?.call('從新北市路線 API 獲取 ${fields.length - 1} 筆點位，準備更新...');
          await _dbService.clearAllRoutePoints('ntpc');
          
          final header = fields[0].map((e) => e.toString().toLowerCase().trim()).toList();
          int idxLineId = header.indexOf('lineid');
          int idxLat = header.indexOf('latitude');
          int idxLng = header.indexOf('longitude');
          int idxTime = header.indexOf('time');
          int idxLineName = header.indexOf('linename');
          int idxName = header.indexOf('name');
          int idxRank = header.indexOf('rank');

          List<GarbageRoutePoint> batch = [];
          for (int i = 1; i < fields.length; i++) {
            final row = fields[i];
            if (row.length < 4) continue;

            batch.add(GarbageRoutePoint(
              lineId: row[idxLineId].toString(),
              lineName: idxLineName != -1 ? row[idxLineName].toString() : '',
              rank: idxRank != -1 ? (int.tryParse(row[idxRank].toString()) ?? 0) : i,
              name: idxName != -1 ? row[idxName].toString() : '',
              position: LatLng(
                double.tryParse(row[idxLat].toString()) ?? 0, 
                double.tryParse(row[idxLng].toString()) ?? 0
              ),
              arrivalTime: row[idxTime].toString(),
            ));

            if (batch.length >= 1000) {
              await _dbService.saveRoutePoints(batch, 'ntpc');
              batch.clear();
            }
          }
          if (batch.isNotEmpty) await _dbService.saveRoutePoints(batch, 'ntpc');
          return true;
        }
      }
    } catch (e) {
      print('新北市 API 同步發生異常: $e');
    }
    return false;
  }

  Future<bool> _importFromLocalCSV(void Function(String)? onProgress) async {
    try {
      final dir = Directory(localSourceDir);
      if (!await dir.exists()) return false;
      final files = await dir.list().toList();
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
      int totalRows = fields.length - 1;
      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        if (row.length < 4) continue;
        batch.add(GarbageRoutePoint(
          lineId: row[idxLineId].toString(),
          lineName: idxLineName != -1 ? row[idxLineName].toString() : '',
          rank: idxRank != -1 ? (int.tryParse(row[idxRank].toString()) ?? 0) : i,
          name: idxName != -1 ? row[idxName].toString() : '',
          position: LatLng(double.tryParse(row[idxLat].toString()) ?? 0, double.tryParse(row[idxLng].toString()) ?? 0),
          arrivalTime: row[idxTime].toString(),
        ));
        if (batch.length >= 1000) { 
          await _dbService.saveRoutePoints(batch, 'ntpc'); 
          batch.clear(); 
          onProgress?.call('已匯入 $i / $totalRows 筆...');
        }
      }
      if (batch.isNotEmpty) await _dbService.saveRoutePoints(batch, 'ntpc');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<GarbageTruck>> fetchTrucks() async {
    try {
      // 增加 size 並加入時間戳記以避開快取
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String requestUrl = '$apiUrl?size=20000&_t=$timestamp';
      
      final response = await _client.get(Uri.parse(requestUrl), headers: _headers);
      if (response.statusCode == 200) {
        final String body = response.body.trim();
        // 解析 CSV
        final List<List<dynamic>> rows = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert(body);
        
        if (rows.length > 1) {
          final header = rows[0].map((e) => e.toString().toLowerCase().trim()).toList();
          final int idxLineId = header.indexOf('lineid');
          final int idxCar = header.indexOf('car');
          final int idxLat = header.indexOf('latitude');
          final int idxLng = header.indexOf('longitude');
          final int idxTime = header.indexOf('time');
          final int idxLoc = header.indexOf('location');

          List<GarbageTruck> trucks = [];
          for (int i = 1; i < rows.length; i++) {
            final row = rows[i];
            if (row.length < 5) continue;

            trucks.add(GarbageTruck(
              carNumber: row[idxCar].toString(),
              lineId: row[idxLineId].toString(),
              location: row[idxLoc].toString(),
              position: LatLng(
                double.tryParse(row[idxLat].toString()) ?? 0,
                double.tryParse(row[idxLng].toString()) ?? 0,
              ),
              updateTime: DateTime.tryParse(row[idxTime].toString()) ?? DateTime.now(),
            ));
          }
          await DatabaseService.log('成功從 CSV 獲取即時車輛: ${trucks.length} 台');
          return trucks;
        }
      }
    } catch (e) {
      await DatabaseService.log('即時 CSV 獲取失敗: $e');
    }

    // Fallback: 搜尋當前班表
    final now = DateTime.now();
    return await findTrucksByTime(now.hour, now.minute);
  }

  @override
  Future<List<GarbageTruck>> findTrucksByTime(int hour, int minute) async {
    final points = await _dbService.findPointsByTime(hour, minute, 'ntpc');
    final now = DateTime.now();
    return points.map((p) {
      DateTime scheduledTime = now;
      try {
        final parts = p.arrivalTime.split(':');
        if (parts.length == 2) scheduledTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      } catch (_) {}
      return GarbageTruck(
        carNumber: scheduledTime.isBefore(now) ? '已過站' : '預定車', 
        lineId: p.lineId, 
        location: '${p.lineName} - ${p.name}', 
        position: p.position, 
        updateTime: scheduledTime
      );
    }).toList();
  }

  @override
  Future<List<GarbageRoutePoint>> getRouteForLine(String lineId) async {
    return await _dbService.getRoutePoints(lineId, 'ntpc');
  }

  Future<void> _insertMockRouteData() async {
    await _dbService.saveRoutePoints([
      GarbageRoutePoint(lineId: '新店-01', lineName: '新店線', rank: 1, name: '中央八街口', position: LatLng(24.9742, 121.5284), arrivalTime: '20:30'),
    ], 'ntpc');
  }
}
