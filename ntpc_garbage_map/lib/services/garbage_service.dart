import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/garbage_truck.dart';

class GarbageService {
  // 新北市垃圾車即時位置 API
  static const String apiUrl = 'https://data.ntpc.gov.tw/api/datasets/EDC3AD26-8BD2-49A7-805D-0576461F297B/json?page=0&size=50';

  Future<List<GarbageTruck>> fetchTrucks() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isEmpty) return _getMockTrucks(); // 如果 API 回傳空 (非收運時間)，使用模擬資料
        return data.map((json) => GarbageTruck.fromJson(json)).toList();
      }
    } catch (e) {
      print('API 錯誤: $e');
    }
    return _getMockTrucks(); // 發生錯誤時回傳模擬資料，確保畫面不空白
  }

  // 模擬資料：在新北市政府附近生成幾台垃圾車
  List<GarbageTruck> _getMockTrucks() {
    return [
      GarbageTruck(
        carNumber: 'MOCK-001',
        lineId: '板橋區-1',
        location: '新北市政府周邊',
        position: LatLng(25.0125, 121.4650),
        updateTime: DateTime.now(),
      ),
      GarbageTruck(
        carNumber: 'MOCK-002',
        lineId: '板橋區-2',
        location: '板橋車站附近',
        position: LatLng(25.0142, 121.4632),
        updateTime: DateTime.now(),
      ),
      GarbageTruck(
        carNumber: 'MOCK-003',
        lineId: '板橋區-3',
        location: '府中商圈',
        position: LatLng(25.0085, 121.4590),
        updateTime: DateTime.now(),
      ),
    ];
  }
}
