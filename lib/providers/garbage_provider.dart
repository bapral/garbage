import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/garbage_truck.dart';
import '../services/garbage_service.dart';

// 全域服務 Provider
final garbageServiceProvider = Provider((ref) => GarbageService());

// 垃圾車清單狀態 Provider (使用新一代 Notifier)
final garbageTrucksProvider = NotifierProvider<GarbageTrucksNotifier, List<GarbageTruck>>(GarbageTrucksNotifier.new);

class GarbageTrucksNotifier extends Notifier<List<GarbageTruck>> {
  Timer? _timer;

  @override
  List<GarbageTruck> build() {
    // 初始狀態
    Future.microtask(() => refresh());
    _startTimer();
    
    // 當 Provider 被註銷時自動停止計時器
    ref.onDispose(() => _timer?.cancel());
    
    return [];
  }

  // 手動重新整理
  Future<void> refresh() async {
    final service = ref.read(garbageServiceProvider);
    final trucks = await service.fetchTrucks();
    state = trucks;
  }

  // 每 30 秒自動更新一次
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      refresh();
    });
  }
}
