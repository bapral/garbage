import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ntpc_garbage_map/main.dart';
import 'package:ntpc_garbage_map/screens/map_screen.dart';
import 'package:ntpc_garbage_map/providers/garbage_provider.dart';
import 'package:ntpc_garbage_map/models/garbage_truck.dart';

/// 模擬資料通知器以避免在測試中觸發真實 API
class MockTrucksNotifier extends GarbageTrucksNotifier {
  @override
  List<GarbageTruck> build() {
    // 延遲更新狀態以模擬非同步載入
    Future.microtask(() => ref.read(isSyncingProvider.notifier).setSyncing(false));
    return [];
  }
}

void main() {
  group('應用程式啟動測試 (App Startup Tests)', () {
    
    testWidgets('應成功啟動 GarbageMapApp 並顯示 MapScreen', (WidgetTester tester) async {
      // 1. 啟動 App
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // 覆蓋 Provider 以避免真實網路請求
            garbageTrucksProvider.overrideWith(MockTrucksNotifier.new),
          ],
          child: const GarbageMapApp(),
        ),
      );

      // 2. 驗證標題與 MaterialApp 屬性
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.title, equals('新北市垃圾車即時地圖'));
      expect(app.debugShowCheckedModeBanner, isFalse);

      // 3. 驗證首頁是否為 MapScreen
      expect(find.byType(MapScreen), findsOneWidget);

      // 4. 等待動畫與非同步操作完成 (例如 Geolocator 權限請求或初始化)
      await tester.pumpAndSettle();

      // 5. 驗證地圖標題列 (預設應顯示新北市)
      expect(find.textContaining('新北市'), findsWidgets);
    });

    testWidgets('啟動時應具有正確的主題色 (Theme Data)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: GarbageMapApp(),
        ),
      );

      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.theme?.useMaterial3, isTrue);
      expect(app.theme?.colorScheme.primary, isNotNull);
    });
  });
}
