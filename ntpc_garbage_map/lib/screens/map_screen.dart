import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/garbage_provider.dart';
import '../models/garbage_truck.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _determinePosition(); // 初始獲取使用者位置
  }

  // 獲取 GPS 位置權限與當前位置
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _userPosition = pos;
    });
    // 移動地圖中心到使用者位置
    _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
  }

  @override
  Widget build(BuildContext context) {
    final trucks = ref.watch(garbageTrucksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('新北市垃圾車即時地圖', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.yellow[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(garbageTrucksProvider.notifier).refresh(),
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(25.0125, 121.4650), // 初始中心：新北市政府
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.ntpc_garbage_map',
          ),
          // 顯示垃圾車 Marker
          MarkerLayer(
            markers: trucks.map((truck) {
              return Marker(
                point: truck.position,
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () => _showTruckInfo(truck),
                  child: const Icon(
                    Icons.local_shipping,
                    color: Colors.orange,
                    size: 35,
                  ),
                ),
              );
            }).toList(),
          ),
          // 顯示使用者位置 Marker
          if (_userPosition != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _determinePosition,
        backgroundColor: Colors.yellow[700],
        child: const Icon(Icons.my_location, color: Colors.black),
      ),
    );
  }

  // 點擊垃圾車顯示資訊
  void _showTruckInfo(GarbageTruck truck) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping, color: Colors.orange, size: 40),
                  const SizedBox(width: 15),
                  Text(truck.carNumber, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Text('路線: ${truck.lineId}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 5),
              Text('當前位置: ${truck.location}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 5),
              Text('最後更新: ${truck.updateTime.hour}:${truck.updateTime.minute.toString().padLeft(2, '0')}', 
                   style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
