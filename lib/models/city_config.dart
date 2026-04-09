import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// [CityConfig] 類別用於定義特定城市的配置資訊。
/// 包含城市名稱、應用程式標題、地圖初始中心點、主題顏色以及本地資源目錄。
class CityConfig {
  /// 城市名稱 (例如: "臺北市")
  final String cityName;
  
  /// 應用程式顯示的標題
  final String appTitle;
  
  /// 地圖開啟時的預設中心經緯度座標
  final LatLng initialCenter;
  
  /// 應用程式的主題顏色 (MaterialColor)
  final MaterialColor themeColor;
  
  /// 存放該城市相關本地資料的目錄路徑
  final String localSourceDir;

  CityConfig({
    required this.cityName,
    required this.appTitle,
    required this.initialCenter,
    required this.themeColor,
    required this.localSourceDir,
  });
}
