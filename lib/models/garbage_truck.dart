import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'garbage_route_point.dart';

class GarbageTruck {
  final String carNumber; // 車牌號碼
  final String lineId;    // 路線 ID
  final String location;  // 當前位置描述
  final LatLng position;  // 經緯度座標
  final DateTime updateTime; // 更新時間

  GarbageTruck({
    required this.carNumber,
    required this.lineId,
    required this.location,
    required this.position,
    required this.updateTime,
  });

  factory GarbageTruck.fromJson(Map<String, dynamic> json) {
    // 自動尋找可能的車牌 Key
    String car = (json['car'] ?? json['PlateNumb'] ?? json['car_number'] ?? json['PlateNumber'] ?? '未知').toString();
    
    // 自動尋找可能的路線 Key
    String line = (json['lineid'] ?? json['RouteID'] ?? json['route_id'] ?? '無').toString();
    
    // 自動尋找可能的經緯度 Key
    double lat = double.tryParse((json['latitude'] ?? json['Latitude'] ?? json['lat'] ?? '0').toString()) ?? 0;
    double lng = double.tryParse((json['longitude'] ?? json['Longitude'] ?? json['lng'] ?? '0').toString()) ?? 0;
    
    // 位置描述
    String loc = (json['location'] ?? json['address'] ?? json['Address'] ?? '').toString();
    
    // 更新時間
    DateTime time = DateTime.tryParse((json['time'] ?? json['GPSTime'] ?? json['update_time'] ?? '').toString()) ?? DateTime.now();

    return GarbageTruck(
      carNumber: car,
      lineId: line,
      location: loc,
      position: LatLng(lat, lng),
      updateTime: time,
    );
  }

  // 預測位置邏輯 (相對時間)
  LatLng predictPosition(Duration duration) {
    if (duration == Duration.zero) return position;
    final double minutes = duration.inMinutes.toDouble();
    final Random random = Random(carNumber.hashCode);
    final double angle = random.nextDouble() * 2 * pi;
    final double speed = (0.0002 + random.nextDouble() * 0.0003);
    return LatLng(position.latitude + sin(angle) * speed * minutes, position.longitude + cos(angle) * speed * minutes);
  }

  // 循跡預測邏輯 (班表時間)
  LatLng predictOnRoute(Duration duration, List<GarbageRoutePoint> allRoutePoints) {
    if (duration == Duration.zero) return position;
    final routePoints = allRoutePoints.where((p) => p.lineId == lineId).toList()..sort((a, b) => a.rank.compareTo(b.rank));
    if (routePoints.isEmpty) return predictPosition(duration);
    final distanceCalc = const Distance();
    int currentIdx = 0;
    double minD = double.infinity;
    for (int i = 0; i < routePoints.length; i++) {
      final d = distanceCalc.as(LengthUnit.Meter, position, routePoints[i].position);
      if (d < minD) { minD = d; currentIdx = i; }
    }
    final int move = (duration.inMinutes / 3).floor();
    int targetIdx = currentIdx + move;
    if (targetIdx >= routePoints.length) targetIdx = routePoints.length - 1;
    return routePoints[targetIdx].position;
  }
}
