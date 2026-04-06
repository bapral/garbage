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
  
  Polyline? _nearestPolyline;
  Polyline? _selectedPolyline;
  String? _routeInfo;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _userPosition = pos;
      });
      if (ref.read(locationModeProvider) == LocationMode.auto) {
        try {
          _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
        } catch (e) {
          print('MapController 尚未就緒');
        }
      }
    }
  }

  LatLng? _getEffectiveUserLatLng() {
    final mode = ref.read(locationModeProvider);
    if (mode == LocationMode.manual) {
      return ref.read(manualPositionProvider);
    }
    return _userPosition != null ? LatLng(_userPosition!.latitude, _userPosition!.longitude) : null;
  }

  void _clearAllPolylines() {
    setState(() {
      _nearestPolyline = null;
      _selectedPolyline = null;
      _routeInfo = null;
    });
  }

  void _findNearestTruck(List<GarbageTruck> trucks) {
    final userLatLng = _getEffectiveUserLatLng();
    if (userLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先獲取位置或在地圖上手動指定地點')));
      return;
    }

    if (trucks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('此時段下沒有可用的垃圾車資訊')));
      return;
    }

    final distanceCalc = const Distance();
    GarbageTruck? nearestTruck;
    double minDistance = double.infinity;

    for (var truck in trucks) {
      final d = distanceCalc.as(LengthUnit.Meter, userLatLng, truck.position);
      if (d < minDistance) {
        minDistance = d;
        nearestTruck = truck;
      }
    }

    if (nearestTruck != null) {
      setState(() {
        _selectedPolyline = null;
        _nearestPolyline = Polyline(
          points: [userLatLng, nearestTruck!.position],
          color: Colors.green.withValues(alpha: 0.8),
          strokeWidth: 2.0,
        );
        final minutes = (minDistance / 83).ceil();
        _routeInfo = '最近目標: ${nearestTruck!.carNumber}\n距離: ${minDistance.toInt()} 公尺 (步行約 $minutes 分鐘)';
      });

      final bounds = LatLngBounds.fromPoints([userLatLng, nearestTruck.position]);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(100)));
      _showTruckInfo(nearestTruck);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(currentCityConfigProvider);
    final isSyncing = ref.watch(isSyncingProvider);
    final trucksAsync = ref.watch(predictedTrucksProvider);
    final duration = ref.watch(predictionDurationProvider);
    final targetTime = ref.watch(targetTimeProvider);
    final locationMode = ref.watch(locationModeProvider);
    final manualPos = ref.watch(manualPositionProvider);
    
    bool isAbsolute = targetTime != null;
    bool isRelative = duration != Duration.zero;
    bool isNow = !isAbsolute && !isRelative;

    if (isSyncing) {
      final progressMsg = ref.watch(syncProgressProvider);
      return Scaffold(
        appBar: AppBar(
          title: const Text('系統初始化...', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: config.themeColor[700],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 6, color: config.themeColor[900]),
              const SizedBox(height: 30),
              Text(progressMsg, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 15),
              const Text('請檢查日誌檔案以獲取詳細資訊：', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SelectionArea(child: Text('C:\\Users\\bapral\\AppData\\Local\\garbage_map_debug.log', style: TextStyle(color: Colors.blueGrey, fontSize: 10))),
            ],
          ),
        ),
      );
    }

    String predictionText = '';
    if (isAbsolute) {
      predictionText = '檢索目標時間: ${targetTime!.hour}:${targetTime.minute.toString().padLeft(2, '0')}';
    } else if (isRelative) {
      predictionText = '預測位置: ${duration.inHours > 0 ? '${duration.inHours}小時' : ''}${duration.inMinutes % 60}分鐘後';
    } else {
      predictionText = '目前即時線上車輛';
    }

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            ref.read(locationModeProvider.notifier).toggle();
            final newMode = ref.read(locationModeProvider);
            _clearAllPolylines();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(newMode == LocationMode.auto ? '已切換為：自動 GPS 定位' : '已切換為：手動指定地點 (點擊地圖設定)'),
              duration: const Duration(seconds: 2),
            ));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(config.appTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(width: 5),
                  Icon(locationMode == LocationMode.auto ? Icons.gps_fixed : Icons.edit_location_alt, size: 16, color: Colors.black54),
                ],
              ),
              Consumer(
                builder: (context, ref, child) {
                  final count = ref.watch(routeDataCountProvider);
                  final sourceInfo = ref.watch(sourceInfoProvider);
                  return SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('快取: $count | 位置: ${locationMode == LocationMode.auto ? "自動" : "手動"}', 
                          style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        Text(sourceInfo, style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        backgroundColor: config.themeColor[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.location_city),
            onPressed: () => _showCitySelectionDialog(),
            tooltip: '切換城市',
          ),
          IconButton(
            icon: Icon(isNow ? Icons.refresh : Icons.auto_graph),
            onPressed: isNow 
              ? () {
                  _clearAllPolylines();
                  ref.read(garbageTrucksProvider.notifier).refresh();
                }
              : () {
                  ref.read(predictionDurationProvider.notifier).reset();
                  ref.read(targetTimeProvider.notifier).reset();
                  _clearAllPolylines();
                },
            tooltip: isNow ? '重新整理' : '重置為即時',
          ),
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: () => _showPredictionDialog(),
            tooltip: '選擇預測模式',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'update') {
                ref.read(garbageTrucksProvider.notifier).forceUpdateRouteData();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'update', child: Text('強制更新資料庫')),
            ],
          ),
        ],
      ),
      body: trucksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: SelectionArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text('載入失敗', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SelectableText(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.read(garbageTrucksProvider.notifier).refresh(),
                    child: const Text('重試'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (trucks) => Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: config.initialCenter,
                initialZoom: 14.0,
                onTap: (_, point) {
                  if (ref.read(locationModeProvider) == LocationMode.manual) {
                    ref.read(manualPositionProvider.notifier).setPosition(point);
                    _clearAllPolylines();
                  } else {
                    _clearAllPolylines();
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.ntpc_garbage_map',
                ),
                PolylineLayer(
                  polylines: [
                    if (_nearestPolyline != null) _nearestPolyline!,
                    if (_selectedPolyline != null) _selectedPolyline!,
                  ],
                ),
                MarkerLayer(
                  markers: trucks.map((truck) {
                    // 更準確的城市判斷：檢查 lineId 是否包含台北，或者目前的城市配置是否為台北且該車輛不是來自新北
                    final bool isTaipei = truck.lineId.contains('台北') || (config.cityName == 'taipei' && !truck.lineId.contains('新北'));
                    final Color cityColor = isTaipei ? Colors.blue[700]! : Colors.orange[800]!;
                    final String cityShort = isTaipei ? '北' : '新';
                    
                    return Marker(
                      point: truck.position,
                      width: 65,
                      height: 65,
                      child: GestureDetector(
                        onTap: () => _showTruckInfo(truck),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 底部發光背景
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: cityColor, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: cityColor.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                  const BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            // 車輛圖標
                            Opacity(
                              opacity: isNow ? 1.0 : 0.7,
                              child: Icon(
                                Icons.local_shipping_rounded,
                                color: cityColor,
                                size: 28,
                              ),
                            ),
                            // 城市標籤
                            Positioned(
                              top: 5,
                              right: 5,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: cityColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: Text(
                                  cityShort,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (locationMode == LocationMode.manual && manualPos != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: manualPos,
                        width: 45,
                        height: 45,
                        child: const Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 45),
                      ),
                    ],
                  )
                else if (locationMode == LocationMode.auto && _userPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.person_pin_circle, color: Colors.redAccent, size: 40),
                      ),
                    ],
                  ),
              ],
            ),
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Card(
                color: isNow ? Colors.orange[50]?.withValues(alpha: 0.9) : Colors.blue[50]?.withValues(alpha: 0.9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  child: Row(
                    children: [
                      Icon(isNow ? Icons.sensors : Icons.event_note, color: isNow ? Colors.orange : Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectionArea(
                          child: Text(predictionText, style: TextStyle(fontWeight: FontWeight.bold, color: isNow ? Colors.orange[900] : Colors.blue[900])),
                        ),
                      ),
                      if (!isNow)
                        TextButton(
                          onPressed: () {
                            ref.read(predictionDurationProvider.notifier).reset();
                            ref.read(targetTimeProvider.notifier).reset();
                            _clearAllPolylines();
                          },
                          child: const Text('回到現在'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_routeInfo != null)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Card(
                  color: Colors.yellow[50],
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_walk, color: Colors.orange),
                        const SizedBox(width: 15),
                        Expanded(
                          child: SelectionArea(
                            child: Text(_routeInfo!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _nearestPolyline = null;
                            _routeInfo = null;
                          }),
                        )
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'nearest',
            onPressed: () => trucksAsync.whenData((trucks) => _findNearestTruck(trucks)),
            backgroundColor: Colors.green,
            child: const Icon(Icons.near_me, color: Colors.white),
          ),
          const SizedBox(height: 15),
          FloatingActionButton(
            heroTag: 'location',
            onPressed: () {
              if (ref.read(locationModeProvider) == LocationMode.auto) {
                _determinePosition();
              } else {
                final mPos = ref.read(manualPositionProvider);
                if (mPos != null) _mapController.move(mPos, 15);
              }
            },
            backgroundColor: config.themeColor[700],
            child: Icon(locationMode == LocationMode.auto ? Icons.my_location : Icons.location_searching, color: Colors.black),
          ),
        ],
      ),
    );
  }

  void _showCitySelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('選擇城市'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.map, color: Colors.blue),
                title: const Text('台北市'),
                onTap: () {
                  ref.read(citySelectionProvider.notifier).setCity('taipei');
                  Navigator.pop(context);
                  _onCityChanged();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.map, color: Colors.yellow),
                title: const Text('新北市'),
                onTap: () {
                  ref.read(citySelectionProvider.notifier).setCity('ntpc');
                  Navigator.pop(context);
                  _onCityChanged();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onCityChanged() {
    _clearAllPolylines();
    final config = ref.read(currentCityConfigProvider);
    _mapController.move(config.initialCenter, 14.0);
  }

  void _showPredictionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('預測功能選擇'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.history, color: Colors.orange),
                title: const Text('預測 X 小時 Y 分後'),
                onTap: () {
                  Navigator.pop(context);
                  _showDurationPicker();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.blue),
                title: const Text('預測指定時間點'),
                onTap: () async {
                  Navigator.pop(context);
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (time != null) {
                    final now = DateTime.now();
                    final selected = DateTime(now.year, now.month, now.day, time.hour, time.minute);
                    ref.read(targetTimeProvider.notifier).setTime(selected);
                    ref.read(predictionDurationProvider.notifier).reset();
                    _clearAllPolylines();
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.sensors, color: Colors.green),
                title: const Text('回到現在'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(predictionDurationProvider.notifier).reset();
                  ref.read(targetTimeProvider.notifier).reset();
                  _clearAllPolylines();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDurationPicker() {
    int hours = 0;
    int minutes = 30;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('預測幾小時幾分鐘後？'),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  DropdownButton<int>(
                    value: hours,
                    items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('$i 小時'))),
                    onChanged: (val) => setState(() => hours = val!),
                  ),
                  DropdownButton<int>(
                    value: minutes,
                    items: List.generate(60, (i) => DropdownMenuItem(value: i, child: Text('$i 分鐘'))),
                    onChanged: (val) => setState(() => minutes = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                ElevatedButton(
                  onPressed: () {
                    ref.read(predictionDurationProvider.notifier).setDuration(Duration(hours: hours, minutes: minutes));
                    ref.read(targetTimeProvider.notifier).reset();
                    _clearAllPolylines();
                    Navigator.pop(context);
                  },
                  child: const Text('確定預測'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTruckInfo(GarbageTruck truck) {
    String distanceStr = '正在獲取位置...';
    String walkTimeStr = '';

    final userLatLng = _getEffectiveUserLatLng();
    if (userLatLng != null) {
      final distance = const Distance().as(LengthUnit.Meter, userLatLng, truck.position);
      final minutes = (distance / 83).ceil();
      distanceStr = '${distance.toInt()} 公尺';
      walkTimeStr = ' (步行約 $minutes 分鐘)';

      setState(() {
        _selectedPolyline = Polyline(
          points: [userLatLng, truck.position],
          color: Colors.orange.withValues(alpha: 0.8),
          strokeWidth: 2.0,
        );
      });
    }

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
                  Expanded(child: SelectableText(truck.carNumber, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              SelectableText('路線: ${truck.lineId}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 5),
              SelectableText('距離: $distanceStr$walkTimeStr', style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              SelectableText('位置說明: ${truck.location}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 5),
              SelectableText('時間標記: ${truck.updateTime.hour}:${truck.updateTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
