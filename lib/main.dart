import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/map_screen.dart';
import 'services/database_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    DatabaseService.log('Application starting...');
    
    FlutterError.onError = (FlutterErrorDetails details) {
      DatabaseService.log('Flutter Error', error: details.exception, stackTrace: details.stack);
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      DatabaseService.log('Platform Dispatcher Error', error: error, stackTrace: stack);
      return true;
    };

    runApp(
      const ProviderScope(
        child: GarbageMapApp(),
      ),
    );
  }, (error, stack) {
    DatabaseService.log('Uncaught Global Error', error: error, stackTrace: stack);
  });
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
