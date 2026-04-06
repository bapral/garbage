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
    return GarbageTruck(
      carNumber: json['car'] ?? '未知',
      lineId: json['lineid'] ?? '無',
      location: json['location'] ?? '',
      position: LatLng(
        double.tryParse(json['latitude']?.toString() ?? '0') ?? 0,
        double.tryParse(json['longitude']?.toString() ?? '0') ?? 0,
      ),
      updateTime: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  // 基於路線資料的精確預測
  LatLng predictOnRoute(Duration duration, List<GarbageRoutePoint> allRoutePoints) {
    if (duration == Duration.zero) return position;

    // 1. 篩選出屬於此路線的所有清運點，並依 rank 排序
    final routePoints = allRoutePoints.where((p) => p.lineId == lineId).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    if (routePoints.isEmpty) return predictPosition(duration); // 找不到路線則退回線性模擬

    // 2. 找到離目前車子最近的清運點索引 (假設目前車子就在這點附近)
    final distanceCalc = const Distance();
    int currentPointIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < routePoints.length; i++) {
      final d = distanceCalc.as(LengthUnit.Meter, position, routePoints[i].position);
      if (d < minDistance) {
        minDistance = d;
        currentPointIndex = i;
      }
    }

    // 3. 根據時間推算前進的點數 (假設平均 3 分鐘移動一個點)
    final int pointsToMove = (duration.inMinutes / 3).floor();
    int predictedIndex = currentPointIndex + pointsToMove;

    // 4. 防止超出索引範圍 (如果是環狀路線可使用 %，此處先以最大值限制)
    if (predictedIndex >= routePoints.length) {
      predictedIndex = routePoints.length - 1;
    }

    return routePoints[predictedIndex].position;
  }

  // 預測位置：根據經過的時間 (X 小時 Y 分鐘) 模擬預測位置 (線性模擬備案)
  // 這裡使用車牌號碼作為隨機種子，讓同一台車的預測路徑一致
  LatLng predictPosition(Duration duration) {
    if (duration == Duration.zero) return position;

    final double minutes = duration.inMinutes.toDouble();
    final int seed = carNumber.hashCode;
    final Random random = Random(seed);

    // 模擬垃圾車平均移動速度 (每分鐘移動約 0.0002 ~ 0.0005 經緯度單位，約 20-50公尺)
    // 給予一個基於 seed 的隨機方向
    final double angle = random.nextDouble() * 2 * pi;
    final double speed = (0.0002 + random.nextDouble() * 0.0003);

    // 簡單的線性預測 (實務上應搭配路線資料，此處為展示預測功能)
    final double latOffset = sin(angle) * speed * minutes;
    final double lngOffset = cos(angle) * speed * minutes;

    return LatLng(
      position.latitude + latOffset,
      position.longitude + lngOffset,
    );
  }
}
