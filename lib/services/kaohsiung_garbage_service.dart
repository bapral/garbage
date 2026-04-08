import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/garbage_truck.dart';
import '../models/garbage_route_point.dart';
import 'database_service.dart';
import 'ntpc_garbage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class KaohsiungGarbageService extends BaseGarbageService {
  // 高雄市政府開放資料 - 垃圾清運路線及時間 JSON
  static const List<String> routeApiUrls = [
    'https://data.kcg.gov.tw/dataset/074c805a-00e1-4fc5-b5f8-b2f4d6b64aa4/resource/7999969a-9691-4604-9926-34c83f206607/download/1100525.json',
    'https://data.kcg.gov.tw/dataset/074c805a-00e1-4fc5-b5f8-b2f4d6b64aa4/resource/1f099632-696c-499e-89ef-39669966949c/download/113.json',
    // 終極備援：環境部全國垃圾車清運路線 (過濾高雄市)
    'https://data.moenv.gov.tw/api/v2/GP_P_01?format=json&filters=county,EQ,高雄市&offset=0&limit=1000'
  ];

  final DatabaseService _dbService = DatabaseService();
  final http.Client _client;

  KaohsiungGarbageService({required super.localSourceDir, http.Client? client}) 
      : _client = client ?? http.Client();

  @override
  Future<void> syncDataIfNeeded({void Function(String)? onProgress}) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentAppVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
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
          
          if (decoded is List) {
            records = decoded;
          } else if (decoded is Map && decoded.containsKey('records')) {
            records = decoded['records'];
          }
          
          if (records.isEmpty) continue;

          onProgress?.call('正在解析站點: ${records.length} 筆...');
          
          List<GarbageRoutePoint> allPoints = [];
          for (int i = 0; i < records.length; i++) {
            final item = records[i];
            
            final double? lat = double.tryParse(item['緯度']?.toString() ?? item['latitude']?.toString() ?? '');
            final double? lng = double.tryParse(item['經度']?.toString() ?? item['longitude']?.toString() ?? '');
            final String area = item['行政區']?.toString() ?? item['town']?.toString() ?? '';
            final String village = item['村里']?.toString() ?? item['village']?.toString() ?? '';
            final String location = item['停留地點']?.toString() ?? item['caption']?.toString() ?? '未知地點';
            
            String timeStr = item['停留時間']?.toString() ?? item['time']?.toString() ?? '';
            if (timeStr.length == 4 && !timeStr.contains(':')) {
              timeStr = '${timeStr.substring(0, 2)}:${timeStr.substring(2, 4)}';
            }

            final String routeName = item['清運路線名稱']?.toString() ?? item['linid']?.toString() ?? '未知路線';

            if (lat != null && lng != null && timeStr.isNotEmpty) {
              allPoints.add(GarbageRoutePoint(
                lineId: routeName,
                lineName: '$area $routeName',
                rank: i,
                name: '$village $location',
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

  @override
  Future<List<GarbageTruck>> fetchTrucks() async {
    final now = DateTime.now();
    return await findTrucksByTime(now.hour, now.minute);
  }

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

  @override
  Future<List<GarbageRoutePoint>> getRouteForLine(String lineId) async {
    return await _dbService.getRoutePoints(lineId, 'kaohsiung');
  }
}
