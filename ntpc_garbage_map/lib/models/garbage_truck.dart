import 'package:latlong2/latlong.dart';

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
}
