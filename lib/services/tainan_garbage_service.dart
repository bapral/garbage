import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/garbage_truck.dart';
import '../models/garbage_route_point.dart';
import 'database_service.dart';
import 'ntpc_garbage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class TainanGarbageService extends BaseGarbageService {
  // 台南市垃圾車 GPS API
  static const String dynamicApiUrl = 'https://soa.tainan.gov.tw/Api/Service/Get/2c8a70d5-06f2-4353-9e92-c40d33bcd969';
  // 台南市清運點資料 API (班表)
  static const String routeApiUrl = 'https://soa.tainan.gov.tw/Api/Service/Get/84df8cd6-8741-41ed-919c-5105a28ecd6d';

  final DatabaseService _dbService = DatabaseService();
  final http.Client _client;

  TainanGarbageService({required super.localSourceDir, http.Client? client}) 
      : _client = client ?? http.Client();

  @override
  Future<void> syncDataIfNeeded({void Function(String)? onProgress}) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentAppVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final String? storedVersion = await _dbService.getStoredVersion('tainan');

    bool needsUpdate = storedVersion != currentAppVersion || !(await _dbService.hasData('tainan'));

    if (!needsUpdate) {
      onProgress?.call('台南市資料已就緒...');
      return;
    }

    onProgress?.call('正在同步台南市路線資料...');
    
    try {
      final response = await _client.get(Uri.parse(routeApiUrl)).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> records = data['data'] ?? [];
        
        onProgress?.call('正在解析台南市站點: ${records.length} 筆...');
        
        List<GarbageRoutePoint> allPoints = [];
        for (int i = 0; i < records.length; i++) {
          final item = records[i];
          
          final double? lat = double.tryParse(item['LATITUDE']?.toString() ?? '');
          final double? lng = double.tryParse(item['LONGITUDE']?.toString() ?? '');
          final String routeId = item['ROUTEID']?.toString() ?? '未知路線';
          final String area = item['AREA']?.toString() ?? '';
          String arrivalTime = item['TIME']?.toString() ?? '';

          if (lat != null && lng != null && arrivalTime.isNotEmpty) {
            allPoints.add(GarbageRoutePoint(
              lineId: routeId,
              lineName: '$area $routeId 路線',
              rank: int.tryParse(item['ROUTEORDER']?.toString() ?? '') ?? i,
              name: item['POINTNAME']?.toString() ?? '未知站點',
              position: LatLng(lat, lng),
              arrivalTime: arrivalTime,
            ));
          }
        }
        
        onProgress?.call('正在原子寫入資料庫 ${allPoints.length} 筆...');
        await _dbService.clearAndSaveRoutePoints(allPoints, 'tainan');
        await _dbService.updateVersion(currentAppVersion, 'tainan');
        onProgress?.call('台南市資料同步完成！');
      }
    } catch (e) {
      DatabaseService.log('台南市同步失敗', error: e);
      onProgress?.call('同步失敗: $e');
    }
  }

  @override
  Future<List<GarbageTruck>> fetchTrucks() async {
    try {
      final response = await _client.get(Uri.parse(dynamicApiUrl));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> records = data['data'] ?? [];
        final now = DateTime.now();
        
        return records.map((item) {
          final String carNo = item['car']?.toString() ?? '未知車號';
          final String linid = item['linid']?.toString() ?? carNo;
          final double lat = double.tryParse(item['y']?.toString() ?? '0') ?? 0;
          final double lng = double.tryParse(item['x']?.toString() ?? '0') ?? 0;
          
          return GarbageTruck(
            carNumber: carNo,
            lineId: linid,
            location: item['location']?.toString() ?? '行駛中',
            position: LatLng(lat, lng),
            updateTime: now,
          );
        }).toList();
      }
    } catch (e) {
      DatabaseService.log('台南市即時位置獲取失敗', error: e);
    }
    
    // 失敗則回傳預測資料
    final now = DateTime.now();
    return await findTrucksByTime(now.hour, now.minute);
  }


  @override
  Future<List<GarbageTruck>> findTrucksByTime(int hour, int minute) async {
    final points = await _dbService.findPointsByTime(hour, minute, 'tainan');
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
    return await _dbService.getRoutePoints(lineId, 'tainan');
  }
}
