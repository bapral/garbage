import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: GarbageMapApp(),
    ),
  );
}

class GarbageMapApp extends StatelessWidget {
  const GarbageMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '新北市垃圾車即時地圖',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.yellow,
          primary: Colors.yellow[800]!,
          secondary: Colors.orange,
        ),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
