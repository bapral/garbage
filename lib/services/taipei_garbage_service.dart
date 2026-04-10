/// [整體程式說明]
/// 本文件定義了 [TaipeiGarbageService] 類別，專門處理台北市的垃圾清運資料。
/// 支援台北市 Open Data 平台提供的 JSON API，並整合了 CSV 本地備援方案。
/// 該服務負責解析台北市複雜的清運點位資訊，包含路線、車號、以及格式多樣的時間字串。
///
/// [執行順序說明]
/// 1. 呼叫 `syncDataIfNeeded`：首先嘗試連線至台北市 Open Data API。
/// 2. 若 API 回傳正常，解析 JSON 數組，並使用 `_formatTime` 工具將時間標準化。
/// 3. 將資料組合為 `GarbageRoutePoint` 並透過 `DatabaseService` 批量存入。
/// 4. 若雲端 API 同步失敗，自動轉向讀取 `localSourceDir` 下的 CSV 資源檔案。
/// 5. 呼叫 `fetchTrucks` 時，優先嘗試即時 API，若失敗則回退至資料庫班表推估。

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

/// [TaipeiGarbageService] 負責台北市垃圾清運資料的介接。
/// 
/// 支援台北市 Open Data JSON API 以及本地 CSV 備援方案。
class TaipeiGarbageService extends BaseGarbageService {
  /// 台北市即時位置與路線 API (JSON)
  static const String apiUrl = 'https://data.taipei/api/v1/dataset/a6e90031-7ec4-4089-afb5-361a4efe7202?scope=resourceAquire';

  final DatabaseService _dbService = DatabaseService();
  final http.Client _client;

  /// 建構子：初始化台北市服務。
  /// [localSourceDir] 資源路徑，[client] 可選傳入 http.Client。
  TaipeiGarbageService({required super.localSourceDir, http.Client? client}) 
      : _client = client ?? http.Client() {
    DatabaseService.log('TaipeiGarbageService 已建立');
  }

  @override
  void dispose() {
    _client.close();
    DatabaseService.log('TaipeiGarbageService 已釋放資源 (Client closed)');
  }

  /// 台北市路線資料同步。
  /// 
  /// 優先級：雲端 API > 本地 CSV。
  /// [onProgress] 同步進度回調。
  @override
  Future<void> syncDataIfNeeded({void Function(String)? onProgress}) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentAppVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final String? storedVersion = await _dbService.getStoredVersion('taipei');

    bool needsUpdate = storedVersion != currentAppVersion || !(await _dbService.hasData('taipei'));

    if (!needsUpdate) {
      onProgress?.call('台北市快取資料已就緒...');
      return;
    }

    onProgress?.call('正在從雲端同步台北市清運點位...');
    bool apiSuccess = await _syncFromApi(onProgress);

    if (apiSuccess) {
      await _dbService.updateVersion(currentAppVersion, 'taipei');
      onProgress?.call('台北市路線同步成功 (雲端)。');
    } else {
      onProgress?.call('雲端同步失敗，改從本地 CSV 資源匯入...');
      if (await _importFromLocalCSV(onProgress)) {
        await _dbService.updateVersion(currentAppVersion, 'taipei');
        onProgress?.call('台北市路線同步成功 (本地 CSV)。');
      } else {
        onProgress?.call('台北市同步失敗，將維持舊有資料。');
      }
    }
  }

  /// 內部工具：標準化時間字串為 HH:mm。
  /// [timeRaw] 原始時間字串。
  /// 回傳格式化後的 HH:mm 字串。
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

  /// 從台北市 Open Data API 獲取資料。
  /// [onProgress] 進度回調。
  /// 回傳是否同步成功。
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

        // 檢查獲取筆數是否在預期範圍內
        if (results.length > 1100) {
          onProgress?.call('獲取 ${results.length} 筆資料，正在寫入快取...');
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
      DatabaseService.log('台北市 API 同步異常', error: e, stackTrace: stack);
    }
    return false;
  }

  /// 備援：讀取本地 CSV 檔案。
  /// [onProgress] 進度回調。
  /// 回傳是否匯入成功。
  Future<bool> _importFromLocalCSV(void Function(String)? onProgress) async {
    try {
      final dir = Directory(localSourceDir);
      if (!await dir.exists()) return false;
      
      final files = await dir.list().toList();
      final csvFile = files.firstWhere((f) => f.path.toLowerCase().endsWith('.csv')) as File;

      final String csvContent = await csvFile.readAsString();
      final List<List<dynamic>> fields = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert(csvContent);

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
          position: LatLng(double.tryParse(row[11].toString()) ?? 0, double.tryParse(row[10].toString()) ?? 0),
          arrivalTime: formattedTime,
        ));

        if (batch.length >= 1000) {
          await _dbService.saveRoutePoints(batch, 'taipei');
          batch.clear();
          onProgress?.call('台北市 CSV 匯入進度: $i / $totalRows...');
        }
      }
      if (batch.isNotEmpty) await _dbService.saveRoutePoints(batch, 'taipei');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 抓取台北市即時位置資料。
  /// 
  /// 回傳即時 [GarbageTruck] 清單，若 API 失敗則切換至班表查詢。
  @override
  Future<List<GarbageTruck>> fetchTrucks() async {
    try {
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
          
          DateTime updateTime = now;
          final String? timeField = item['點位日期時間']?.toString() ?? item['time']?.toString();
          if (timeField != null) updateTime = DateTime.tryParse(timeField) ?? now;

          return GarbageTruck(
            carNumber: carNo,
            lineId: item['路線']?.toString() ?? item['lineid']?.toString() ?? '',
            location: location,
            position: LatLng(double.tryParse(latStr) ?? 0, double.tryParse(lonStr) ?? 0),
            updateTime: updateTime,
          );
        }).toList();
      }
    } catch (e) {
      DatabaseService.log('台北市即時 API 連線失敗，切換為班表查詢模式', error: e);
    }
    
    // 退回班表
    final now = DateTime.now();
    return await findTrucksByTime(now.hour, now.minute);
  }

  /// 班表查詢。
  /// [hour] 小時，[minute] 分鐘。
  @override
  Future<List<GarbageTruck>> findTrucksByTime(int hour, int minute) async {
    final points = await _dbService.findPointsByTime(hour, minute, 'taipei');
    final now = DateTime.now();
    return points.map((p) {
      DateTime scheduledTime = now;
      try {
        final parts = p.arrivalTime.split(':');
        if (parts.length == 2) scheduledTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      } catch (_) {}
      return GarbageTruck(carNumber: '預定車', lineId: p.lineId, location: '${p.lineName} - ${p.name}', position: p.position, updateTime: scheduledTime);
    }).toList();
  }

  /// 獲取特定車次的所有點位序列。
  /// [lineId] 路線編號（含車號）。
  @override
  Future<List<GarbageRoutePoint>> getRouteForLine(String lineId) async {
    return await _dbService.getRoutePoints(lineId, 'taipei');
  }
}
