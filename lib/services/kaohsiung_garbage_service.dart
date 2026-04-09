import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/garbage_truck.dart';
import '../models/garbage_route_point.dart';
import 'database_service.dart';
import 'ntpc_garbage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 高雄市垃圾清運服務類別，負責高雄市清運路線的同步與查詢。
class KaohsiungGarbageService extends BaseGarbageService {
  /// 高雄市政府開放資料 - 垃圾清運路線及時間 API 連結清單
  static const List<String> routeApiUrls = [
    // 2025/2026 最新穩定連結 (高雄市政府 API 平台)
    'https://api.kcg.gov.tw/api/service/get/7c80a17b-ba6c-4a07-811e-feae30ff9210',
    // 2024/2025 備援連結
    'https://api.kcg.gov.tw/ServiceList/GetFullList/074c805a-00e1-4fc5-b5f8-b2f4d6b64aa4',
    // 備援：政府資料開放平臺的導向連結
    'https://data.gov.tw/api/v2/GP_P_01?format=json&filters=county,EQ,高雄市&offset=0&limit=1000'
  ];

  final DatabaseService _dbService = DatabaseService();
  final http.Client _client;

  KaohsiungGarbageService({required super.localSourceDir, http.Client? client}) 
      : _client = client ?? http.Client();

  /// 檢查並在需要時同步高雄市資料。
  /// [onProgress] 用於回報目前進度的回標函數。
  /// [debugVersion] 提供測試時模擬版本號使用。
  /// 
  /// 同步步驟：
  /// 1. 檢查目前儲存的版本是否與 App 版本一致。
  /// 2. 若不一致或無資料，則逐一嘗試 API 連結。
  /// 3. 解析 JSON 內容，轉換為 [GarbageRoutePoint] 列表。
  /// 4. 利用原子操作存入資料庫，並更新版本紀錄。
  @override
  Future<void> syncDataIfNeeded({void Function(String)? onProgress, String? debugVersion}) async {
    String currentAppVersion;
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      currentAppVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      // 在測試環境中，如果無法獲取 PackageInfo，則使用傳入的 debugVersion 或預設值
      currentAppVersion = debugVersion ?? 'test_version';
    }
    
    final String? storedVersion = await _dbService.getStoredVersion('kaohsiung');

    bool needsUpdate = storedVersion != currentAppVersion || !(await _dbService.hasData('kaohsiung'));

    if (!needsUpdate) {
      onProgress?.call('高雄市資料已就緒...');
      return;
    }

    onProgress?.call('正在同步高雄市路線資料...');
    
    for (String url in routeApiUrls) {
      try {
        onProgress?.call('嘗試從連結同步: $url');
        final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          final dynamic decoded = json.decode(utf8.decode(response.bodyBytes));
          List<dynamic> records = [];
          
          // 處理不同的 JSON 結構 (可能是直接陣列或包在 records/data 鍵中)
          if (decoded is List) {
            records = decoded;
          } else if (decoded is Map) {
            if (decoded.containsKey('data')) {
              records = decoded['data'];
            } else if (decoded.containsKey('records')) {
              records = decoded['records'];
            }
          }
          
          if (records.isEmpty) continue;

          onProgress?.call('正在解析站點: ${records.length} 筆...');
          
          List<GarbageRoutePoint> allPoints = [];
          for (int i = 0; i < records.length; i++) {
            final item = records[i];
            
            double? lat;
            double? lng;

            // 處理新的合併座標格式 "22.6408334,120.3151333"
            final String coordStr = item['經緯度']?.toString() ?? '';
            if (coordStr.contains(',')) {
              final parts = coordStr.split(',');
              if (parts.length >= 2) {
                lat = double.tryParse(parts[0].trim());
                lng = double.tryParse(parts[1].trim());
              }
            } else {
              // 舊版或備援連結的獨立經緯度格式
              lat = double.tryParse(item['緯度']?.toString() ?? item['latitude']?.toString() ?? '');
              lng = double.tryParse(item['經度']?.toString() ?? item['longitude']?.toString() ?? '');
            }

            final String area = item['行政區']?.toString() ?? item['town']?.toString() ?? '';
            final String village = item['村里']?.toString() ?? item['village']?.toString() ?? '';
            final String location = item['停留地點']?.toString() ?? item['停留點']?.toString() ?? item['caption']?.toString() ?? '未知地點';
            
            // 處理時間格式，如 "0830" 轉換為 "08:30" 或處理 "16:00-16:10"
            String timeRaw = item['停留時間']?.toString() ?? item['停留時段']?.toString() ?? item['time']?.toString() ?? '';
            String timeStr = '';
            if (timeRaw.isNotEmpty) {
              // 如果是時段 "16:00-16:10"，取前半部
              if (timeRaw.contains('-')) {
                timeStr = timeRaw.split('-')[0].trim();
              } else {
                timeStr = timeRaw;
              }

              if (timeStr.length == 4 && !timeStr.contains(':')) {
                timeStr = '${timeStr.substring(0, 2)}:${timeStr.substring(2, 4)}';
              }
            }

            final String routeName = item['清運路線名稱']?.toString() ?? item['車次']?.toString() ?? item['linid']?.toString() ?? '未知路線';

            if (lat != null && lng != null && timeStr.isNotEmpty) {
              allPoints.add(GarbageRoutePoint(
                lineId: routeName,
                lineName: '$area $routeName',
                rank: i,
                name: '${village.isNotEmpty ? "$village " : ""}$location',
                position: LatLng(lat, lng),
                arrivalTime: timeStr,
              ));
            }
          }
          
          if (allPoints.isNotEmpty) {
            onProgress?.call('正在原子寫入資料庫 ${allPoints.length} 筆...');
            await _dbService.clearAndSaveRoutePoints(allPoints, 'kaohsiung');
            await _dbService.updateVersion(currentAppVersion, 'kaohsiung');
            onProgress?.call('高雄市資料同步完成！');
            return; // 成功後退出循環
          }
        }
      } catch (e) {
        DatabaseService.log('高雄市連結嘗試失敗: $url', error: e);
      }
    }
    
    onProgress?.call('所有高雄市同步連結皆失效。');
  }

  /// 獲取高雄市目前的垃圾車清單。
  /// 目前採取「班表模式」，即根據當前時間查詢預計到達的點位。
  @override
  Future<List<GarbageTruck>> fetchTrucks() async {
    final now = DateTime.now();
    return await findTrucksByTime(now.hour, now.minute);
  }

  /// 根據指定時間查詢預定到達的車輛資訊。
  @override
  Future<List<GarbageTruck>> findTrucksByTime(int hour, int minute) async {
    final points = await _dbService.findPointsByTime(hour, minute, 'kaohsiung');
    final now = DateTime.now();
    
    return points.map((p) {
      DateTime scheduledTime = now;
      try {
        final parts = p.arrivalTime.split(':');
        if (parts.length >= 2) {
          scheduledTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
        }
      } catch (_) {}

      return GarbageTruck(
        carNumber: '預定車',
        lineId: p.lineId,
        location: p.name,
        position: p.position,
        updateTime: scheduledTime,
      );
    }).toList();
  }

  /// 取得特定路線編號的所有點位。
  @override
  Future<List<GarbageRoutePoint>> getRouteForLine(String lineId) async {
    return await _dbService.getRoutePoints(lineId, 'kaohsiung');
  }
}
