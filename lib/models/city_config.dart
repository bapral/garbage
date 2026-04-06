import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class CityConfig {
  final String cityName;
  final String appTitle;
  final LatLng initialCenter;
  final MaterialColor themeColor;
  final String localSourceDir;

  CityConfig({
    required this.cityName,
    required this.appTitle,
    required this.initialCenter,
    required this.themeColor,
    required this.localSourceDir,
  });
}
