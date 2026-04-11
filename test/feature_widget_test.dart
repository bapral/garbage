/// - **測試目的**: 完整功能 UI 整合測試，驗證地圖介面、標記點資訊卡、預測選單以及導航功能等核心 UI 互動流程。
/// - **測試覆蓋**: 
///   - 地圖啟動與預設城市顯示。
///   - Marker 標記點點擊與資訊卡顯示（含 SelectableText 內容）。
///   - 預測功能選單對話框彈出與內容驗證。
///   - 導航按鈕存在與點擊模擬。
/// - **測試執行順序**: 使用 Mock 覆蓋 Provider 以模擬靜態資料 -> 啟動 MapScreen 並等待 Widget 樹建構 -> 模擬點擊地圖標記點並驗證資訊卡 -> 模擬點擊預測選單並驗證對話框 -> 驗證導航按鈕。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ntpc_garbage_map/screens/map_screen.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';

// 模擬 Notifier
class MockGarbageTrucksNotifier extends GarbageTrucksNotifier {
  @override
  List<GarbageTruck> build() {
    // 立即結束同步狀態
    Future.microtask(() => ref.read(isSyncingProvider.notifier).setSyncing(false));
    return [
      GarbageTruck(
        carNumber: 'TEST-123',
        lineId: 'LINE-1',
        location: '測試路 100 號',
        position: LatLng(25.0125, 121.4650),
        updateTime: DateTime.now(),
      )
    ];
  }
}

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: "map", packageName: "map", version: "1.0.0", buildNumber: "1", buildSignature: "1"
    );
  });

  testWidgets('Full Feature UI Test', (WidgetTester tester) async {
    /// 全功能 UI 測試：驗證地圖啟動、點位資訊卡顯示、預測功能選單及導航按鈕等核心 UI 元件
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garbageTrucksProvider.overrideWith(MockGarbageTrucksNotifier.new),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );

    // 1. 進入地圖
    await tester.pumpAndSettle();
    expect(find.textContaining('新北市'), findsOneWidget);

    // 2. 測試 Marker 資訊卡與 SelectableText
    await tester.tap(find.byIcon(Icons.local_shipping_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsAtLeast(3));
    expect(find.text('TEST-123'), findsOneWidget);

    // 點擊空白處關閉
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 3. 測試預測選單
    await tester.tap(find.byIcon(Icons.timer));
    await tester.pumpAndSettle();
    expect(find.text('預測功能選擇'), findsOneWidget);
    expect(find.text('預測指定時間點'), findsOneWidget);
    
    // 關閉對話框
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 4. 測試導航按鈕
    expect(find.byIcon(Icons.near_me), findsOneWidget);
    await tester.tap(find.byIcon(Icons.near_me));
    await tester.pump();
  });
}
