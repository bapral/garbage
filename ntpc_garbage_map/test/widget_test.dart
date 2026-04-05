import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ntpc_garbage_map/main.dart';

void main() {
  testWidgets('Counter increment smoke test', (WidgetTester tester) async {
    // 修正：使用新類別名稱，並包裝在 ProviderScope 中
    await tester.pumpWidget(const ProviderScope(child: GarbageMapApp()));

    // 檢查 App 是否能成功載入地圖畫面 (包含 "新北市" 字樣)
    expect(find.textContaining('新北市'), findsOneWidget);
  });
}
