import 'package:latlong2/latlong.dart';

/// [GarbageRoutePoint] 類別代表垃圾車清運點的資訊。
/// 記錄了清運點的名稱、順序、位置及預計抵達時間等。
class GarbageRoutePoint {
  /// 路線 ID，用於關聯特定清運路線
  final String lineId;
  
  /// 路線名稱
  final String lineName;
  
  /// 在該清運路線中的順序 (排名)
  final int rank;
  
  /// 清運點的名稱 (例如: "中山路 10 號")
  final String name;
  
  /// 清運點的經緯度座標
  final LatLng position;
  
  /// 預計抵達時間 (格式通常為 "HH:mm"，例如 "17:30")
  final String arrivalTime;

  GarbageRoutePoint({
    required this.lineId,
    required this.lineName,
    required this.rank,
    required this.name,
    required this.position,
    required this.arrivalTime,
  });

  /// 從 JSON 格式轉換為 [GarbageRoutePoint] 物件的工廠方法。
  /// 
  /// [json] 為 API 回傳的 Map 資料。
  /// 此方法會自動處理各種可能的欄位名稱 (如 `lineid`, `rank`, `latitude` 等)，並進行基礎的類型轉換與預設值設定。
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
