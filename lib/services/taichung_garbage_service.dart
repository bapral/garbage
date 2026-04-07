import 'dart:io';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/garbage_truck.dart';
import '../models/garbage_route_point.dart';
import 'database_service.dart';
import 'ntpc_garbage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';

class TaichungGarbageService extends BaseGarbageService {
  // 台中市定時定點路線 API (JSON)
  static const String routeApiUrl = 'https://newdatacenter.taichung.gov.tw/api/v1/no-auth/resource.download?rid=68d1a87f-7baa-4b50-8408-c36a3a7eda68';
  // 台中市垃圾及資源回收車動態資訊 API (JSON)
  static const String dynamicApiUrl = 'https://newdatacenter.taichung.gov.tw/api/v1/no-auth/resource.download?rid=c923ad20-2ec6-43b9-b3ab-54527e99f7bc';

  final DatabaseService _dbService = DatabaseService();
  final http.Client _client;

  TaichungGarbageService({required super.localSourceDir, http.Client? client}) 
      : _client = client ?? http.Client();

  @override
  Future<void> syncDataIfNeeded({void Function(String)? onProgress}) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentAppVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final String? storedVersion = await _dbService.getStoredVersion('taichung');

    bool needsUpdate = storedVersion != currentAppVersion || !(await _dbService.hasData('taichung'));

    if (!needsUpdate) {
      onProgress?.call('台中市資料已就緒...');
      return;
    }

    onProgress?.call('正在同步台中市路線資料 (包含比對即時位置)...');
    
    try {
      // 1. 先抓取即時動態 API，建立「車牌 -> 最新位置」的對照表
      onProgress?.call('獲取台中市即時動態位置以比對站點...');
      final dynamicResponse = await _client.get(Uri.parse('$dynamicApiUrl&limit=20000')).timeout(const Duration(seconds: 15));
      Map<String, LatLng> carPositions = {};
      if (dynamicResponse.statusCode == 200) {
        final List<dynamic> dynamicData = json.decode(dynamicResponse.body);
        for (var item in dynamicData) {
          final String carNo = item['car']?.toString() ?? '';
          final double? lng = double.tryParse(item['X']?.toString() ?? '');
          final double? lat = double.tryParse(item['Y']?.toString() ?? '');
          if (carNo.isNotEmpty && lat != null && lng != null) {
            carPositions[carNo] = LatLng(lat, lng);
          }
        }
      }

      // 2. 讀取本地 JSON 班表
      onProgress?.call('讀取台中市本地班表 JSON...');
      final String jsonPath = join(localSourceDir, '0_臺中市定時定點垃圾收運地點.JSON');
      final File jsonFile = File(jsonPath);
      if (!await jsonFile.exists()) {
        throw Exception('找不到本地 JSON 班表檔案: $jsonPath');
      }

      final String content = await jsonFile.readAsString();
      final List<dynamic> scheduleData = json.decode(content);
      
      onProgress?.call('正在解析台中市路線: ${scheduleData.length} 筆...');
      
      List<GarbageRoutePoint> allPoints = [];
      int dayOfWeek = DateTime.now().weekday; // 1-7 (Mon-Sun)
      
      for (int i = 0; i < scheduleData.length; i++) {
        final item = scheduleData[i];
        final String carNo = item['car_licence']?.toString() ?? '';
        final String locationName = item['caption']?.toString() ?? '未知地點';
        
        // 獲取當天的抵達時間 (g_d[1-7]_time_s)
        String arrivalTime = item['g_d${dayOfWeek}_time_s']?.toString() ?? '';
        if (arrivalTime.isEmpty) {
          // 如果當天沒收，找第一個有收的時間作為代表
          for (int d = 1; d <= 7; d++) {
            arrivalTime = item['g_d${d}_time_s']?.toString() ?? '';
            if (arrivalTime.isNotEmpty) break;
          }
        }

        if (arrivalTime.isEmpty) continue;

        // 嘗試從剛才建立的對照表中找出這台車的「可能位置」
        LatLng pos = carPositions[carNo] ?? const LatLng(24.147, 120.673);

        allPoints.add(GarbageRoutePoint(
          lineId: carNo,
          lineName: '${item['area'] ?? ''}${item['village'] ?? ''} ($carNo)',
          rank: i,
          name: locationName,
          position: pos,
          arrivalTime: arrivalTime,
        ));
      }
      
      onProgress?.call('正在原子寫入資料庫 ${allPoints.length} 筆...');
      await _dbService.clearAndSaveRoutePoints(allPoints, 'taichung');
      
      await _dbService.updateVersion(currentAppVersion, 'taichung');
      onProgress?.call('台中市資料同步完成！');
      
    } catch (e, stack) {
      DatabaseService.log('台中市同步失敗', error: e, stackTrace: stack);
      onProgress?.call('同步失敗: $e');
    }
  }

  @override
  Future<List<GarbageTruck>> fetchTrucks() async {
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final response = await _client.get(Uri.parse('$dynamicApiUrl&limit=20000&_t=$timestamp'));
      
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        final now = DateTime.now();
        
        return results.map((item) {
          final String carNo = item['car']?.toString() ?? '未知車號';
          final String location = item['location']?.toString() ?? '行駛中';
          final String latStr = item['Y']?.toString() ?? '0';
          final String lonStr = item['X']?.toString() ?? '0';
          
          DateTime updateTime = now;
          final String? timeStr = item['time']?.toString();
          if (timeStr != null && timeStr.contains('T')) {
            // 格式: 20260406T213649
            try {
              final String formatted = '${timeStr.substring(0, 4)}-${timeStr.substring(4, 6)}-${timeStr.substring(6, 8)} ${timeStr.substring(9, 11)}:${timeStr.substring(11, 13)}:${timeStr.substring(13, 15)}';
              updateTime = DateTime.tryParse(formatted) ?? now;
            } catch (_) {}
          }

          return GarbageTruck(
            carNumber: carNo,
            lineId: item['lineid']?.toString() ?? '',
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
      DatabaseService.log('台中市即時位置獲取失敗', error: e);
    }
    
    final now = DateTime.now();
    return await findTrucksByTime(now.hour, now.minute);
  }

  @override
  Future<List<GarbageTruck>> findTrucksByTime(int hour, int minute) async {
    final points = await _dbService.findPointsByTime(hour, minute, 'taichung');
    DatabaseService.log('台中市預測查詢: $hour:$minute, 找到 ${points.length} 筆點位');
    
    final now = DateTime.now();
    return points.map((p) {
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
    return await _dbService.getRoutePoints(lineId, 'taichung');
  }
}
