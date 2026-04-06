import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/garbage_truck.dart';
import '../models/garbage_route_point.dart';
import '../models/city_config.dart';
import '../services/ntpc_garbage_service.dart';
import '../services/taipei_garbage_service.dart';
import '../services/taichung_garbage_service.dart';
import '../services/database_service.dart';

// 目前城市選擇
final citySelectionProvider = NotifierProvider<CitySelectionNotifier, String>(CitySelectionNotifier.new);

class CitySelectionNotifier extends Notifier<String> {
  @override
  String build() => 'ntpc';
  void setCity(String city) => state = city;
}

// 全域服務 Provider
final garbageServiceProvider = Provider<BaseGarbageService>((ref) {
  final config = ref.watch(currentCityConfigProvider);
  if (config.cityName == 'taipei') {
    return TaipeiGarbageService(localSourceDir: config.localSourceDir);
  } else if (config.cityName == 'taichung') {
    return TaichungGarbageService(localSourceDir: config.localSourceDir);
  }
  return NtpcGarbageService(localSourceDir: config.localSourceDir);
});

// 目前顯示來源與筆數 Provider
final sourceInfoProvider = NotifierProvider<SourceInfoNotifier, String>(SourceInfoNotifier.new);

class SourceInfoNotifier extends Notifier<String> {
  @override
  String build() => '載入中...';
  void setInfo(String msg) => state = msg;
}

// 目前城市配置
final currentCityConfigProvider = Provider<CityConfig>((ref) {
  final city = ref.watch(citySelectionProvider);
  if (city == 'taipei') {
    return CityConfig(
      cityName: 'taipei',
      appTitle: '台北市垃圾車即時地圖',
      initialCenter: const LatLng(25.0330, 121.5654),
      themeColor: Colors.blue,
      localSourceDir: r'D:\CLI\garbage\台北市垃圾車路線',
    );
  } else if (city == 'taichung') {
    return CityConfig(
      cityName: 'taichung',
      appTitle: '台中市垃圾車即時地圖',
      initialCenter: const LatLng(24.1477, 120.6736),
      themeColor: Colors.green,
      localSourceDir: r'D:\CLI\garbage\臺中市定時定點垃圾收運地點',
    );
  }
  return CityConfig(
    cityName: 'ntpc',
    appTitle: '新北市垃圾車即時地圖',
    initialCenter: const LatLng(25.0125, 121.4650),
    themeColor: Colors.yellow,
    localSourceDir: r'D:\CLI\garbage\新北市垃圾車路線',
  );
});

// 位置模式 (自動/手動)
enum LocationMode { auto, manual }
final locationModeProvider = NotifierProvider<LocationModeNotifier, LocationMode>(LocationModeNotifier.new);

class LocationModeNotifier extends Notifier<LocationMode> {
  @override
  LocationMode build() => LocationMode.auto;
  void toggle() => state = (state == LocationMode.auto ? LocationMode.manual : LocationMode.auto);
}

// 手動指定的位置
final manualPositionProvider = NotifierProvider<ManualPositionNotifier, LatLng?>(ManualPositionNotifier.new);

class ManualPositionNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;
  void setPosition(LatLng? pos) => state = pos;
}

// 資料庫快取總筆數
final routeDataCountProvider = NotifierProvider<RouteDataCountNotifier, int>(RouteDataCountNotifier.new);

class RouteDataCountNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setCount(int value) => state = value;
}

// 是否正在同步資料庫
final isSyncingProvider = NotifierProvider<SyncStatusNotifier, bool>(SyncStatusNotifier.new);

class SyncStatusNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void setSyncing(bool value) => state = value;
}

// 同步進度文字
final syncProgressProvider = NotifierProvider<SyncProgressNotifier, String>(SyncProgressNotifier.new);

class SyncProgressNotifier extends Notifier<String> {
  @override
  String build() => '正在檢查資料庫版本...';
  void setProgress(String msg) => state = msg;
}

// 目標預測時間
final targetTimeProvider = NotifierProvider<TargetTimeNotifier, DateTime?>(TargetTimeNotifier.new);

class TargetTimeNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void setTime(DateTime time) => state = time;
  void reset() => state = null;
}

// 預測時間偏移
final predictionDurationProvider = NotifierProvider<PredictionDurationNotifier, Duration>(PredictionDurationNotifier.new);

class PredictionDurationNotifier extends Notifier<Duration> {
  @override
  Duration build() => Duration.zero;
  void setDuration(Duration duration) => state = duration;
  void reset() => state = Duration.zero;
}

// 垃圾車清單狀態 Provider
final garbageTrucksProvider = NotifierProvider<GarbageTrucksNotifier, List<GarbageTruck>>(GarbageTrucksNotifier.new);

// 最終顯示清單 Provider
final predictedTrucksProvider = FutureProvider<List<GarbageTruck>>((ref) async {
  final realTimeTrucks = ref.watch(garbageTrucksProvider);
  final duration = ref.watch(predictionDurationProvider);
  final targetTime = ref.watch(targetTimeProvider);
  final service = ref.read(garbageServiceProvider);
  
  List<GarbageTruck> result;
  String sourceLabel = '';

  if (targetTime != null) {
    result = await service.findTrucksByTime(targetTime.hour, targetTime.minute);
    sourceLabel = '資料來源: 資料庫 (指定時間)';
  } else if (duration != Duration.zero) {
    final target = DateTime.now().add(duration);
    result = await service.findTrucksByTime(target.hour, target.minute);
    sourceLabel = '資料來源: 資料庫 (預測模式)';
  } else {
    result = realTimeTrucks;
    bool isApiData = realTimeTrucks.isNotEmpty && realTimeTrucks.any((t) => t.carNumber != '已過站' && t.carNumber != '預定車');
    sourceLabel = isApiData ? '資料來源: 雲端 API (即時)' : '資料來源: 資料庫 (API 攔截/沒車)';
  }

  // 修正：使用 Future.microtask 延遲更新另一個 Provider，避免初始化期間修改衝突
  final finalLabel = '$sourceLabel | 顯示筆數: ${result.length}';
  Future.microtask(() {
    ref.read(sourceInfoProvider.notifier).setInfo(finalLabel);
  });

  return result;
});

class GarbageTrucksNotifier extends Notifier<List<GarbageTruck>> {
  Timer? _timer;

  @override
  List<GarbageTruck> build() {
    // 偵聽城市選擇，當切換城市時重新觸發 build
    final city = ref.watch(citySelectionProvider);
    
    // 重設狀態，確保舊城市的資料不會留在畫面上
    state = [];
    
    Future.microtask(() async {
      final service = ref.read(garbageServiceProvider);
      ref.read(isSyncingProvider.notifier).setSyncing(true);
      try {
        await service.syncDataIfNeeded(onProgress: (msg) {
          ref.read(syncProgressProvider.notifier).setProgress(msg);
        });
        await _updateCount(city);
        await refresh();
      } catch (e) {
        DatabaseService.log('同步失敗', error: e);
      } finally {
        ref.read(isSyncingProvider.notifier).setSyncing(false);
      }
    });
    
    _startTimer();
    ref.onDispose(() => _timer?.cancel());
    return [];
  }

  Future<void> _updateCount(String city) async {
    final count = await DatabaseService().getTotalCount(city);
    ref.read(routeDataCountProvider.notifier).setCount(count);
  }

  Future<void> refresh() async {
    final city = ref.read(citySelectionProvider);
    final service = ref.read(garbageServiceProvider);
    try {
      final trucks = await service.fetchTrucks();
      state = trucks;
      await _updateCount(city);
    } catch (e) {
      DatabaseService.log('重新整理失敗', error: e);
    }
  }

  Future<void> forceUpdateRouteData() async {
    final city = ref.read(citySelectionProvider);
    final service = ref.read(garbageServiceProvider);
    ref.read(isSyncingProvider.notifier).setSyncing(true);
    try {
      await DatabaseService().updateVersion('force_refresh_$city');
      await service.syncDataIfNeeded(onProgress: (msg) {
        ref.read(syncProgressProvider.notifier).setProgress(msg);
      });
      await _updateCount(city);
      await refresh();
    } finally {
      ref.read(isSyncingProvider.notifier).setSyncing(false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) => refresh());
  }
}
