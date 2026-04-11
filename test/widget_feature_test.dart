/// - **測試目的**: 功能 UI 元件測試：驗證預測按鈕、最近站點尋找按鈕以及預測對話框的互動邏輯與顯示。
/// - **測試覆蓋**: 
///   - 預測模式選擇按鈕（時鐘圖示）存在性。
///   - 尋找最近按鈕（導航圖示）存在性。
///   - 預測功能選擇與輸入對話框彈出流程。
///   - 對話框取消按鈕的功能驗證。
/// - **測試執行順序**: 使用 Mock 覆蓋 Provider -> 啟動 MapScreen 並等待載入 -> 檢查 AppBar 功能按鈕存在性 -> 模擬點擊預測按鈕彈出選單 -> 選擇模式並測試對話框顯示與取消。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ntpc_garbage_map/screens/map_screen.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:latlong2/latlong.dart';

// 模擬 Notifier
class MockGarbageTrucksNotifier extends GarbageTrucksNotifier {
  @override
  List<GarbageTruck> build() {
    Future.microtask(() => ref.read(isSyncingProvider.notifier).setSyncing(false));
    return [
      GarbageTruck(
        carNumber: 'TEST-001',
        lineId: '123',
        location: 'Test Location',
        position: LatLng(25.0125, 121.4650),
        updateTime: DateTime.now(),
      )
    ];
  }
}

void main() {
  testWidgets('Feature UI Elements Test', (WidgetTester tester) async {
    /// 功能 UI 元件測試：驗證預測按鈕、最近站點尋找按鈕以及預測對話框的互動邏輯與顯示
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garbageTrucksProvider.overrideWith(MockGarbageTrucksNotifier.new),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );

    // 等待初始化結束
    await tester.pump();

    // 1. 檢查是否有「預測按鈕」(時鐘圖示)
    expect(find.byTooltip('選擇預測模式'), findsOneWidget);

    // 2. 檢查是否有「尋找最近按鈕」(near_me 圖示)
    expect(find.byIcon(Icons.near_me), findsOneWidget);

    // 3. 測試點擊預測按鈕彈出選單，再點擊第一個 ListTile
    await tester.tap(find.byTooltip('選擇預測模式'));
    await tester.pumpAndSettle();
    expect(find.text('預測功能選擇'), findsOneWidget);
    
    await tester.tap(find.text('預測 X 小時 Y 分後'));
    await tester.pumpAndSettle();
    expect(find.text('預測幾小時幾分鐘後？'), findsOneWidget);
    
    // 4. 點擊「取消」關閉對話框
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('預測幾小時幾分鐘後？'), findsNothing);
  });
}
