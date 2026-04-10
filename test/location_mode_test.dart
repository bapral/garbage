/// [整體程式說明]: 地圖位置模式切換穩定性測試，驗證使用者切換「自動定位」與「手動模式」時的系統反應與 UI 狀態。
/// [執行順序說明]:
/// 1. 使用 Mock 覆蓋 Provider 以模擬初始測試環境。
/// 2. 啟動 MapScreen 並驗證初始狀態為「位置: 自動」。
/// 3. 模擬點擊 AppBar 標題區塊，觸發模式切換。
/// 4. 驗證 UI 更新為「位置: 手動」。
/// 5. 透過 Provider 手動注入座標，並驗證地圖上是否正確顯示人像標記點（Icons.person_pin_circle）。
/// 6. 再次觸發切換以返回自動模式，確保狀態機正確。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ntpc_garbage_map/screens/map_screen.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';

// 模擬 Notifier
class MockLocationTrucks extends GarbageTrucksNotifier {
  @override
  List<GarbageTruck> build() {
    // 結束同步狀態
    Future.microtask(() => ref.read(isSyncingProvider.notifier).setSyncing(false));
    return [
      GarbageTruck(
        carNumber: 'TEST-GPS',
        lineId: 'L1',
        location: 'Somewhere',
        position: LatLng(25.0, 121.0),
        updateTime: DateTime.now(),
      )
    ];
  }
}

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: "map", packageName: "map", version: "1.0.0", buildNumber: "4", buildSignature: "1"
    );
  });

  testWidgets('Location Mode Toggle Stability Test', (WidgetTester tester) async {
    /// 測試位置模式切換：驗證自動與手動模式之間的切換邏輯，以及手動設定座標時 Marker 的正確顯示
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garbageTrucksProvider.overrideWith(MockLocationTrucks.new),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );

    // 等待載入完成
    await tester.pumpAndSettle();

    // 1. 驗證初始為自動模式
    expect(find.textContaining('位置: 自動'), findsOneWidget);

    // 2. 點擊標題區域切換模式 (AppBar 的 InkWell)
    await tester.tap(find.textContaining('新北市垃圾車即時地圖'));
    await tester.pumpAndSettle();

    // 3. 驗證模式變更為手動
    expect(find.textContaining('位置: 手動'), findsOneWidget);

    // 4. 直接透過 Provider 設定手動座標
    final container = ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
    container.read(manualPositionProvider.notifier).setPosition(LatLng(25.01, 121.46));
    await tester.pumpAndSettle();

    // 5. 驗證藍色 Marker (人像圖示) 是否出現
    expect(find.byIcon(Icons.person_pin_circle), findsOneWidget);

    // 6. 再次點擊標題切換回自動模式
    await tester.tap(find.textContaining('新北市垃圾車即時地圖'));
    await tester.pumpAndSettle();
    expect(find.textContaining('位置: 自動'), findsOneWidget);
  });
}
