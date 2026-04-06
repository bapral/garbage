import 'package:latlong2/latlong.dart';

class GarbageRoutePoint {
  final String lineId;      // 路線 ID
  final String lineName;    // 路線名稱
  final int rank;           // 順序
  final String name;        // 清運點名稱
  final LatLng position;    // 座標
  final String arrivalTime; // 預計抵達時間 (例如 "17:30")

  GarbageRoutePoint({
    required this.lineId,
    required this.lineName,
    required this.rank,
    required this.name,
    required this.position,
    required this.arrivalTime,
  });

  factory GarbageRoutePoint.fromJson(Map<String, dynamic> json) {
    return GarbageRoutePoint(
      lineId: json['lineid'] ?? '',
      lineName: json['linename'] ?? '',
      rank: int.tryParse(json['rank']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? '',
      position: LatLng(
        double.tryParse(json['latitude']?.toString() ?? '0') ?? 0,
        double.tryParse(json['longitude']?.toString() ?? '0') ?? 0,
      ),
      arrivalTime: json['time'] ?? '',
    );
  }
}
