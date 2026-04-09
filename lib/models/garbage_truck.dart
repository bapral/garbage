import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'garbage_route_point.dart';

/// [GarbageTruck] 類別代表垃圾車的即時動態資訊與位置預測邏輯。
/// 包含車牌號碼、路線 ID、當前位置描述及最近一次更新時間。
class GarbageTruck {
  /// 車牌號碼
  final String carNumber;
  
  /// 當前行駛的路線 ID
  final String lineId;
  
  /// 當前位置描述 (例如: "忠孝東路一段與中山路口")
  final String location;
  
  /// 垃圾車最新的經緯度座標
  final LatLng position;
  
  /// 最後一次收到 GPS 更新的時間
  final DateTime updateTime;

  GarbageTruck({
    required this.carNumber,
    required this.lineId,
    required this.location,
    required this.position,
    required this.updateTime,
  });

  /// 從各類城市 API 的 JSON 回傳值解析為 [GarbageTruck] 物件。
  /// 
  /// 由於各縣市欄位不一，此工廠方法會根據已知模式 (如 `PlateNumb`, `RouteID`, `Latitude`) 尋找適當的 Key。
  factory GarbageTruck.fromJson(Map<String, dynamic> json) {
    // 自動尋找可能的車牌 Key，包含 PlateNumb, car_number, PlateNumber 等。
    String car = (json['car'] ?? json['PlateNumb'] ?? json['car_number'] ?? json['PlateNumber'] ?? '未知').toString();
    
    // 自動尋找可能的路線 Key，包含 RouteID, route_id 等。
    String line = (json['lineid'] ?? json['RouteID'] ?? json['route_id'] ?? '無').toString();
    
    // 自動尋找可能的座標 Key 並嘗試解析為浮點數。
    double lat = double.tryParse((json['latitude'] ?? json['Latitude'] ?? json['lat'] ?? '0').toString()) ?? 0;
    double lng = double.tryParse((json['longitude'] ?? json['Longitude'] ?? json['lng'] ?? '0').toString()) ?? 0;
    
    // 解析位置地址描述，涵蓋 address 或 location 欄位。
    String loc = (json['location'] ?? json['address'] ?? json['Address'] ?? '').toString();
    
    // 解析更新時間，支援 GPSTime 等常見格式，若解析失敗則使用目前時間。
    DateTime time = DateTime.tryParse((json['time'] ?? json['GPSTime'] ?? json['update_time'] ?? '').toString()) ?? DateTime.now();

    return GarbageTruck(
      carNumber: car,
      lineId: line,
      location: loc,
      position: LatLng(lat, lng),
      updateTime: time,
    );
  }

  /// 簡易位置預測邏輯：基於隨機方向與固定速度進行估算。
  /// 
  /// [duration] 自上次更新以來所經過的時間。
  /// 此方法主要用於缺乏路線資訊時，提供垃圾車可能的移動方向示意。
  LatLng predictPosition(Duration duration) {
    if (duration == Duration.zero) return position;
    final double minutes = duration.inMinutes.toDouble();
    
    // 使用車牌號碼作為種子來確保隨機方向的連貫性。
    final Random random = Random(carNumber.hashCode);
    final double angle = random.nextDouble() * 2 * pi;
    
    // 設定每分鐘隨機移動的小量距離 (模擬車速)。
    final double speed = (0.0002 + random.nextDouble() * 0.0003);
    return LatLng(
      position.latitude + sin(angle) * speed * minutes,
      position.longitude + cos(angle) * speed * minutes
    );
  }

  /// 循跡位置預測邏輯：基於指定路線的清運點序列進行推估。
  /// 
  /// [duration] 自上次更新以來經過的時間。
  /// [allRoutePoints] 系統中所有清運點的清單。
  /// 
  /// 執行步驟：
  /// 1. 篩選出屬於該垃圾車當前 [lineId] 的所有清運點，並依 [rank] 排序。
  /// 2. 計算垃圾車當前位置與路線中每個點的距離，尋找「最近的清運點」作為起始索引。
  /// 3. 假設垃圾車每 3 分鐘移動到下一個清運點 (基於 [duration])，計算目標清運點的索引。
  /// 4. 回傳目標清運點的座標，若超出清單長度則回傳最後一個清運點。
  LatLng predictOnRoute(Duration duration, List<GarbageRoutePoint> allRoutePoints) {
    if (duration == Duration.zero) return position;
    
    // 1. 篩選與排序路線點
    final routePoints = allRoutePoints.where((p) => p.lineId == lineId).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    
    // 如果找不到該路線的清運點資訊，則回退到簡易隨機預測模式。
    if (routePoints.isEmpty) return predictPosition(duration);
    
    final distanceCalc = const Distance();
    int currentIdx = 0;
    double minD = double.infinity;
    
    // 2. 尋找與目前即時座標最接近的路線索引。
    for (int i = 0; i < routePoints.length; i++) {
      final d = distanceCalc.as(LengthUnit.Meter, position, routePoints[i].position);
      if (d < minD) {
        minD = d;
        currentIdx = i;
      }
    }
    
    // 3. 計算預期的進度 (假設每 3 分鐘移動一個站點)。
    final int move = (duration.inMinutes / 3).floor();
    int targetIdx = currentIdx + move;
    
    // 防止索引超出清單範圍。
    if (targetIdx >= routePoints.length) targetIdx = routePoints.length - 1;
    
    // 4. 回傳預測點座標。
    return routePoints[targetIdx].position;
  }
}
