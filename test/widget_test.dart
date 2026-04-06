import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ntpc_garbage_map/main.dart';

void main() {
  testWidgets('Counter increment smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GarbageMapApp()));

    // 預設城市是新北市
    expect(find.textContaining('新北市'), findsWidgets);
  });
}
