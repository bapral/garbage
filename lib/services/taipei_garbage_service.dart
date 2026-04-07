import 'dart:io';
import 'package:latlong2/latlong.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/garbage_truck.dart';
import '../models/garbage_route_point.dart';
import 'database_service.dart';
import 'ntpc_garbage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class TaipeiGarbageService extends BaseGarbageService {
  // 台北市即時位置 API (JSON 格式)
  static const String apiUrl = 'https://data.taipei/api/v1/dataset/a6e90031-7ec4-4089-afb5-361a4efe7202?scope=resourceAquire';

  final DatabaseService _dbService = DatabaseService();
  final http.Client _client;

  TaipeiGarbageService({required super.localSourceDir, http.Client? client}) 
      : _client = client ?? http.Client();

  @override
  Future<void> syncDataIfNeeded({void Function(String)? onProgress}) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentAppVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final String? storedVersion = await _dbService.getStoredVersion('taipei');

    bool needsUpdate = storedVersion != currentAppVersion || !(await _dbService.hasData('taipei'));

    if (!needsUpdate) {
      onProgress?.call('台北市資料已就緒...');
      return;
    }

    onProgress?.call('正在嘗試從雲端更新台北市路線...');
    bool apiSuccess = await _syncFromApi(onProgress);

    if (apiSuccess) {
      await _dbService.updateVersion(currentAppVersion, 'taipei');
      onProgress?.call('台北市路線已透過 API 更新完成！');
    } else {
      onProgress?.call('API 更新失敗或筆數不足，嘗試從本地 CSV 恢復...');
      if (await _importFromLocalCSV(onProgress)) {
        await _dbService.updateVersion(currentAppVersion, 'taipei');
        onProgress?.call('台北市路線已從本地 CSV 更新完成。');
      } else {
        onProgress?.call('台北市本地 CSV 也無法讀取，維持現狀。');
      }
    }
  }

  String _formatTime(String timeRaw) {
    String raw = timeRaw.replaceAll(':', '').trim();
    if (raw.length == 4) {
      return '${raw.substring(0, 2)}:${raw.substring(2, 4)}';
    } else if (raw.length == 3) {
      return '0${raw.substring(0, 1)}:${raw.substring(1, 3)}';
    } else if (raw.length == 2) {
      return '00:${raw.padLeft(2, '0')}';
    }
    return timeRaw.contains(':') ? timeRaw : '00:00';
  }

  Future<bool> _syncFromApi(void Function(String)? onProgress) async {
    try {
      final String syncUrl = '$apiUrl&limit=100000';
      final response = await _client.get(Uri.parse(syncUrl));
      
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        List<dynamic> results = [];
        if (decoded is Map && decoded.containsKey('result')) {
          results = decoded['result']['results'] ?? [];
        } else if (decoded is List) {
          results = decoded;
        }

        if (results.length > 1100) {
          onProgress?.call('從 API 獲取 ${results.length} 筆資料，準備寫入資料庫...');
          await _dbService.clearAllRoutePoints('taipei');
          
          List<GarbageRoutePoint> batch = [];
          for (int i = 0; i < results.length; i++) {
            final item = results[i];
            final String lineId = item['路線']?.toString() ?? item['lineid']?.toString() ?? '未知路線';
            final String carNo = item['車號']?.toString() ?? item['car']?.toString() ?? '未知車號';
            String timeRaw = (item['抵達時間']?.toString() ?? item['time']?.toString() ?? '').trim();
            String formattedTime = _formatTime(timeRaw);

            batch.add(GarbageRoutePoint(
              lineId: '$lineId-$carNo',
              lineName: '$lineId ($carNo)',
              rank: i,
              name: item['地點']?.toString() ?? item['location']?.toString() ?? '未知點',
              position: LatLng(
                double.tryParse(item['緯度']?.toString() ?? '0') ?? 0,
                double.tryParse(item['經度']?.toString() ?? '0') ?? 0,
              ),
              arrivalTime: formattedTime,
            ));

            if (batch.length >= 1000) {
              await _dbService.saveRoutePoints(batch, 'taipei');
              batch.clear();
              onProgress?.call('寫入進度: $i / ${results.length}...');
            }
          }
          if (batch.isNotEmpty) await _dbService.saveRoutePoints(batch, 'taipei');
          return true;
        }
      }
    } catch (e, stack) {
      DatabaseService.log('台北市 API 同步發生異常', error: e, stackTrace: stack);
    }
    return false;
  }

  Future<bool> _importFromLocalCSV(void Function(String)? onProgress) async {
    try {
      final dir = Directory(localSourceDir);
      if (!await dir.exists()) return false;
      
      final files = await dir.list().toList();
      final csvFile = files.firstWhere(
        (f) => f.path.toLowerCase().endsWith('.csv'),
        orElse: () => throw Exception('找不到 CSV 檔案'),
      ) as File;

      final String csvContent = await csvFile.readAsString();
      final List<List<dynamic>> fields = const CsvToListConverter(
        shouldParseNumbers: false, 
        eol: '\n'
      ).convert(csvContent);

      if (fields.isEmpty) return false;
      
      List<GarbageRoutePoint> batch = [];
      int totalRows = fields.length - 1;
      
      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        if (row.length < 12) continue;

        String lineId = row[5].toString(); 
        String carNo = row[4].toString(); 
        String arrivalTimeRaw = row[7].toString(); 
        String formattedTime = _formatTime(arrivalTimeRaw);

        batch.add(GarbageRoutePoint(
          lineId: '$lineId-$carNo', 
          lineName: '$lineId ($carNo)',
          rank: i, 
          name: row[9].toString(),
          position: LatLng(
            double.tryParse(row[11].toString()) ?? 0, 
            double.tryParse(row[10].toString()) ?? 0
          ),
          arrivalTime: formattedTime,
        ));

        if (batch.length >= 1000) {
          await _dbService.saveRoutePoints(batch, 'taipei');
          batch.clear();
          onProgress?.call('台北市資料匯入中: $i / $totalRows...');
        }
      }

      if (batch.isNotEmpty) {
        await _dbService.saveRoutePoints(batch, 'taipei');
      }
      return true;
    } catch (e, stack) {
      DatabaseService.log('台北市 CSV 匯入錯誤', error: e, stackTrace: stack);
      return false;
    }
  }

  @override
  Future<List<GarbageTruck>> fetchTrucks() async {
    try {
      // 增加 limit 並加入時間戳記以避開快取
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String requestUrl = '$apiUrl&limit=20000&_t=$timestamp';
      
      final response = await _client.get(Uri.parse(requestUrl));
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        List<dynamic> results = [];

        if (decoded is List) {
          results = decoded;
        } else if (decoded is Map && decoded.containsKey('result')) {
          results = decoded['result']['results'] ?? [];
        }
        
        final now = DateTime.now();
        return results.map((item) {
          final String carNo = item['車號']?.toString() ?? item['car']?.toString() ?? '未知車號';
          final String location = item['地點']?.toString() ?? item['location']?.toString() ?? '行駛中';
          final String latStr = item['緯度']?.toString() ?? item['latitude']?.toString() ?? '0';
          final String lonStr = item['經度']?.toString() ?? item['longitude']?.toString() ?? '0';
          
          // 台北市 API 的 _importdate 通常是靜態的。
          // 對於即時位置，我們應該優先使用 API 內的點位時間，若無則使用當前時間。
          DateTime updateTime = now;
          final String? timeField = item['點位日期時間']?.toString() ?? item['time']?.toString();
          if (timeField != null) {
            updateTime = DateTime.tryParse(timeField) ?? now;
          }

          return GarbageTruck(
            carNumber: carNo,
            lineId: item['路線']?.toString() ?? item['lineid']?.toString() ?? '',
            location: location,
            position: LatLng(
              double.tryParse(latStr) ?? 0,
              double.tryParse(lonStr) ?? 0,
            ),
            updateTime: updateTime,
          );
        }).toList();
      }
    } catch (e) {
      DatabaseService.log('台北市即時位置獲取失敗', error: e);
    }
    
    final now = DateTime.now();
    return await findTrucksByTime(now.hour, now.minute);
  }

  @override
  Future<List<GarbageTruck>> findTrucksByTime(int hour, int minute) async {
    final points = await _dbService.findPointsByTime(hour, minute, 'taipei');
    final now = DateTime.now();
    return points.map((p) {
      // 嘗試將 "HH:mm" 解析為當天的 DateTime
      DateTime scheduledTime = now;
      try {
        final parts = p.arrivalTime.split(':');
        if (parts.length == 2) {
          scheduledTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
        }
      } catch (_) {}

      return GarbageTruck(
        carNumber: '預定車',
        lineId: p.lineId, 
        location: '${p.lineName} - ${p.name}',
        position: p.position,
        updateTime: scheduledTime,
      );
    }).toList();
  }

  @override
  Future<List<GarbageRoutePoint>> getRouteForLine(String lineId) async {
    return await _dbService.getRoutePoints(lineId, 'taipei');
  }
}
