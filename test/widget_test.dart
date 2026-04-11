/// - **測試目的**: 基本啟動冒煙測試：驗證 App 啟動後地圖畫面是否正常載入並顯示預設的新北市文字。
/// - **測試覆蓋**: 
///   - App 啟動後的 Widget 樹建構。
///   - 地圖螢幕（MapScreen）載入驗證。
///   - 預設城市（新北市）名稱顯示。
/// - **測試執行順序**: 使用 Mock 覆蓋 Provider 模擬空清單 -> 啟動 MapScreen -> 等待初始化與動畫完成 -> 驗證畫面文字內容。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ntpc_garbage_map/main.dart';

import 'package:ntpc_garbage_map/screens/map_screen.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:latlong2/latlong.dart';

class MockTrucksNotifier extends GarbageTrucksNotifier {
  @override
  List<GarbageTruck> build() {
    Future.microtask(() => ref.read(isSyncingProvider.notifier).setSyncing(false));
    return [];
  }
}

void main() {
  testWidgets('Counter increment smoke test', (WidgetTester tester) async {
    /// 基本啟動冒煙測試：驗證 App 啟動後地圖畫面是否正常載入並顯示預設的新北市文字
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garbageTrucksProvider.overrideWith(MockTrucksNotifier.new),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );

    // 等待初始化結束
    await tester.pumpAndSettle();

    // 預設城市是新北市
    expect(find.textContaining('新北市'), findsWidgets);
  });
}
