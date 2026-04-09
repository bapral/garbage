import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/garbage_provider.dart';
import '../models/garbage_truck.dart';

/// 地圖主畫面類別，負責地圖渲染、圖層顯示與使用者互動。
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  Position? _userPosition; // 目前使用者的 GPS 位置
  
  Polyline? _nearestPolyline; // 指向最近目標的線條
  Polyline? _selectedPolyline; // 使用者選取車輛後的連結線
  String? _routeInfo; // 底部資訊卡片的說明文字

  @override
  void initState() {
    super.initState();
    _determinePosition(); // 初始化時嘗試獲取 GPS 權限與位置
  }

  /// 獲取使用者當前的 GPS 位置，並處理權限要求。
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
      // 若為自動模式，地圖跟隨至當前位置
      if (ref.read(locationModeProvider) == LocationMode.auto) {
        try {
          _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
        } catch (e) {
          print('MapController 尚未就緒');
        }
      }
    }
  }

  /// 根據目前的模式 (自動/手動)，回傳有效的參考座標。
  LatLng? _getEffectiveUserLatLng() {
    final mode = ref.read(locationModeProvider);
    if (mode == LocationMode.manual) {
      return ref.read(manualPositionProvider);
    }
    return _userPosition != null ? LatLng(_userPosition!.latitude, _userPosition!.longitude) : null;
  }

  /// 清除地圖上的所有線條與資訊框。
  void _clearAllPolylines() {
    setState(() {
      _nearestPolyline = null;
      _selectedPolyline = null;
      _routeInfo = null;
    });
  }

  /// 搜尋距離參考座標最近的一台垃圾車。
  /// 並在地圖上劃出一條虛擬線段，並將視野移至兩者之間。
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
        // 粗估步行時間 (時速約 5km/h = 83m/min)
        final minutes = (minDistance / 83).ceil();
        _routeInfo = '最近目標: ${nearestTruck!.carNumber}\n距離: ${minDistance.toInt()} 公尺 (步行約 $minutes 分鐘)';
      });

      // 自動調整地圖視野以同時顯示使用者與最近目標
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

    final isDarkColor = config.themeColor.computeLuminance() < 0.5;
    final appBarTitleColor = isDarkColor ? Colors.white : Colors.black87;
    final appBarSubtitleColor = isDarkColor ? Colors.white70 : Colors.black54;

    // 當系統正在同步大筆路線資料時的等待畫面
    if (isSyncing) {
      final progressMsg = ref.watch(syncProgressProvider);
      return Scaffold(
        appBar: AppBar(
          title: Text('系統初始化...', style: TextStyle(fontWeight: FontWeight.bold, color: appBarTitleColor)),
          backgroundColor: config.themeColor[800],
          elevation: 2,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 6, color: config.themeColor[800]),
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

    // 狀態列顯示目前的模式 (即時/預測)
    String predictionText = '';
    if (isNow) {
      predictionText = '目前即時線上車輛';
    } else if (isAbsolute) {
      predictionText = '檢索目標時間: ${targetTime!.hour}:${targetTime.minute.toString().padLeft(2, '0')}';
    } else if (isRelative) {
      predictionText = '預測位置: ${duration.inHours > 0 ? '${duration.inHours}小時' : ''}${duration.inMinutes % 60}分鐘後';
    }

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            // 點擊標題區塊可快速切換定位模式
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
                  Text(config.appTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: appBarTitleColor)),
                  const SizedBox(width: 5),
                  Icon(locationMode == LocationMode.auto ? Icons.gps_fixed : Icons.edit_location_alt, size: 16, color: appBarSubtitleColor),
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
                          style: TextStyle(fontSize: 11, color: appBarSubtitleColor)),
                        Text(sourceInfo, style: TextStyle(fontSize: 10, color: appBarSubtitleColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        backgroundColor: config.themeColor[800],
        iconTheme: IconThemeData(color: appBarTitleColor),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_city),
            onPressed: () => _showCitySelectionDialog(),
            tooltip: '切換城市',
            color: appBarTitleColor,
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
            color: appBarTitleColor,
          ),
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: () => _showPredictionDialog(),
            tooltip: '選擇預測模式',
            color: appBarTitleColor,
          ),
          PopupMenuButton<String>(
            iconColor: appBarTitleColor,
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
                    // 根據車輛線路來源決定標記顏色
                    Color cityColor;
                    String cityShort;
                    
                    if (truck.lineId.contains('台北') || config.cityName == 'taipei') {
                      cityColor = Colors.blue[700]!;
                      cityShort = '北';
                    } else if (truck.lineId.contains('台中') || config.cityName == 'taichung') {
                      cityColor = Colors.green[700]!;
                      cityShort = '中';
                    } else if (truck.lineId.contains('新北') || config.cityName == 'ntpc') {
                      cityColor = Colors.orange[800]!;
                      cityShort = '新';
                    } else if (truck.lineId.contains('台南') || config.cityName == 'tainan') {
                      cityColor = Colors.deepOrange[700]!;
                      cityShort = '南';
                    } else if (truck.lineId.contains('高雄') || config.cityName == 'kaohsiung') {
                      cityColor = Colors.purple[700]!;
                      cityShort = '高';
                    } else {
                      cityColor = Colors.grey[700]!;
                      cityShort = '?';
                    }
                    
                    return Marker(
                      point: truck.position,
                      width: 65,
                      height: 65,
                      child: GestureDetector(
                        onTap: () => _showTruckInfo(truck),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
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
                            Opacity(
                              opacity: isNow ? 1.0 : 0.7,
                              child: Icon(Icons.local_shipping_rounded, color: cityColor, size: 28),
                            ),
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
                                child: Text(cityShort, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // 使用者定位標記 (區分自動與手動顏色)
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
            // 頂部當前模式資訊卡片
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
            // 底部導航/距離資訊
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

  /// 顯示城市切換對話框。
  void _showCitySelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('選擇城市'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCityTile('台北市', 'taipei', Colors.blue),
              const Divider(),
              _buildCityTile('新北市', 'ntpc', Colors.yellow),
              const Divider(),
              _buildCityTile('台中市', 'taichung', Colors.green),
              const Divider(),
              _buildCityTile('台南市', 'tainan', Colors.orange),
              const Divider(),
              _buildCityTile('高雄市', 'kaohsiung', Colors.purple),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCityTile(String label, String cityKey, Color color) {
    return ListTile(
      leading: Icon(Icons.map, color: color),
      title: Text(label),
      onTap: () {
        ref.read(citySelectionProvider.notifier).setCity(cityKey);
        Navigator.pop(context);
        _onCityChanged();
      },
    );
  }

  /// 城市切換後的回調處理。
  void _onCityChanged() {
    _clearAllPolylines();
    final config = ref.read(currentCityConfigProvider);
    _mapController.move(config.initialCenter, 14.0);
  }

  /// 顯示預測模式選擇對話框。
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

  /// 顯示時間長度選取器 (相對預測模式)。
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

  /// 顯示車輛詳細資訊底板。
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
