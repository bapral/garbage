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
import '../services/tainan_garbage_service.dart';
import '../services/kaohsiung_garbage_service.dart';
import '../services/database_service.dart';

/// 城市選擇狀態 Provider。
/// 預設為 'ntpc' (新北市)。
final citySelectionProvider = NotifierProvider<CitySelectionNotifier, String>(CitySelectionNotifier.new);

class CitySelectionNotifier extends Notifier<String> {
  @override
  String build() => 'ntpc';
  void setCity(String city) => state = city;
}

/// 垃圾清運服務實體 Provider。
/// 根據 [currentCityConfigProvider] 的城市設定，回傳對應的服務類別實體。
final garbageServiceProvider = Provider<BaseGarbageService>((ref) {
  final config = ref.watch(currentCityConfigProvider);
  if (config.cityName == 'taipei') {
    return TaipeiGarbageService(localSourceDir: config.localSourceDir);
  } else if (config.cityName == 'taichung') {
    return TaichungGarbageService(localSourceDir: config.localSourceDir);
  } else if (config.cityName == 'tainan') {
    return TainanGarbageService(localSourceDir: config.localSourceDir);
  } else if (config.cityName == 'kaohsiung') {
    return KaohsiungGarbageService(localSourceDir: config.localSourceDir);
  }
  return NtpcGarbageService(localSourceDir: config.localSourceDir);
});

/// 目前顯示來源與狀態文字 Provider，用於 UI 上顯示資料來源資訊。
final sourceInfoProvider = NotifierProvider<SourceInfoNotifier, String>(SourceInfoNotifier.new);

class SourceInfoNotifier extends Notifier<String> {
  @override
  String build() => '載入中...';
  void setInfo(String msg) => state = msg;
}

/// 目前城市配置 Provider。
/// 定義各地圖初始中心點、主題顏色及本地資源路徑。
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
  } else if (city == 'tainan') {
    return CityConfig(
      cityName: 'tainan',
      appTitle: '台南市垃圾車即時地圖',
      initialCenter: const LatLng(22.9975, 120.2025),
      themeColor: Colors.orange,
      localSourceDir: r'D:\CLI\garbage\台南市垃圾車路線',
    );
  } else if (city == 'kaohsiung') {
    return CityConfig(
      cityName: 'kaohsiung',
      appTitle: '高雄市垃圾車即時地圖',
      initialCenter: const LatLng(22.6273, 120.3014),
      themeColor: Colors.purple,
      localSourceDir: r'D:\CLI\garbage\高雄市垃圾車路線',
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

/// 位置模式 Provider (自動 GPS 定位 或 手動地圖指定)。
enum LocationMode { auto, manual }
final locationModeProvider = NotifierProvider<LocationModeNotifier, LocationMode>(LocationModeNotifier.new);

class LocationModeNotifier extends Notifier<LocationMode> {
  @override
  LocationMode build() => LocationMode.auto;
  void toggle() => state = (state == LocationMode.auto ? LocationMode.manual : LocationMode.auto);
}

/// 手動指定位置 Provider。當模式為 manual 時，儲存使用者在地圖上點擊的座標。
final manualPositionProvider = NotifierProvider<ManualPositionNotifier, LatLng?>(ManualPositionNotifier.new);

class ManualPositionNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;
  void setPosition(LatLng? pos) => state = pos;
}

/// 本地資料庫中當前城市的快取總筆數 Provider。
final routeDataCountProvider = NotifierProvider<RouteDataCountNotifier, int>(RouteDataCountNotifier.new);

class RouteDataCountNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setCount(int value) => state = value;
}

/// 資料同步狀態 Provider。
final isSyncingProvider = NotifierProvider<SyncStatusNotifier, bool>(SyncStatusNotifier.new);

class SyncStatusNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void setSyncing(bool value) => state = value;
}

/// 同步進度描述 Provider。
final syncProgressProvider = NotifierProvider<SyncProgressNotifier, String>(SyncProgressNotifier.new);

class SyncProgressNotifier extends Notifier<String> {
  @override
  String build() => '正在檢查資料庫版本...';
  void setProgress(String msg) => state = msg;
}

/// 指定目標時間 Provider (絕對時間預測模式)。
final targetTimeProvider = NotifierProvider<TargetTimeNotifier, DateTime?>(TargetTimeNotifier.new);

class TargetTimeNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void setTime(DateTime time) => state = time;
  void reset() => state = null;
}

/// 預測時間偏移 Provider (相對時間預測模式，例如 30 分鐘後)。
final predictionDurationProvider = NotifierProvider<PredictionDurationNotifier, Duration>(PredictionDurationNotifier.new);

class PredictionDurationNotifier extends Notifier<Duration> {
  @override
  Duration build() => Duration.zero;
  void setDuration(Duration duration) => state = duration;
  void reset() => state = Duration.zero;
}

/// 垃圾車原始資料狀態 Provider，負責定期從服務端抓取最新車輛資訊。
final garbageTrucksProvider = NotifierProvider<GarbageTrucksNotifier, List<GarbageTruck>>(GarbageTrucksNotifier.new);

/// 最終地圖上顯示的垃圾車清單 Provider。
/// 邏輯：
/// 1. 若設定了 [targetTime]，則從資料庫查詢該時間點的班表。
/// 2. 若設定了 [predictionDuration]，則計算未來時間點並從資料庫查詢。
/// 3. 若皆無設定，則顯示 [garbageTrucksProvider] 抓取到的即時動態。
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

  // 非同步更新標籤，避免與 build 過程衝突
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
    // 監控城市切換，一旦改變則執行同步與重新整理
    final city = ref.watch(citySelectionProvider);
    state = [];
    
    Future.microtask(() async {
      final service = ref.read(garbageServiceProvider);
      ref.read(isSyncingProvider.notifier).setSyncing(true);
      try {
        // 同步城市路線資料
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

  /// 更新本地資料庫筆數統計。
  Future<void> _updateCount(String city) async {
    final count = await DatabaseService().getTotalCount(city);
    ref.read(routeDataCountProvider.notifier).setCount(count);
  }

  /// 重新整理即時車輛動態。
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

  /// 強制從雲端或本地來源重新同步所有路線點位，並更新資料庫。
  Future<void> forceUpdateRouteData() async {
    final city = ref.read(citySelectionProvider);
    final service = ref.read(garbageServiceProvider);
    
    final targetTime = ref.read(targetTimeProvider);
    final duration = ref.read(predictionDurationProvider);
    final isPrediction = targetTime != null || duration != Duration.zero;

    if (isPrediction) {
      // 預測模式下，強制觸發資料庫重新同步
      ref.read(isSyncingProvider.notifier).setSyncing(true);
      try {
        await DatabaseService().updateVersion('force_refresh_$city', city);
        await service.syncDataIfNeeded(onProgress: (msg) {
          ref.read(syncProgressProvider.notifier).setProgress(msg);
        });
        await _updateCount(city);
        ref.invalidate(predictedTrucksProvider);
      } finally {
        ref.read(isSyncingProvider.notifier).setSyncing(false);
      }
    } else {
      // 即時模式下，僅重新抓取車輛位置
      await refresh();
    }
  }

  /// 啟動 30 秒一次的定期輪詢計時器。
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) => refresh());
  }
}
