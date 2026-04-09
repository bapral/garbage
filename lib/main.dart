import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/map_screen.dart';
import 'services/database_service.dart';

/// 應用程式進入點。
/// 使用 [runZonedGuarded] 捕捉全域未處理的異常，並將其記錄至本地日誌系統。
void main() {
  runZonedGuarded(() async {
    // 確保 Flutter 引擎初始化完成
    WidgetsFlutterBinding.ensureInitialized();
    
    DatabaseService.log('Application starting...');
    
    // 捕捉 Flutter 框架層級的錯誤
    FlutterError.onError = (FlutterErrorDetails details) {
      DatabaseService.log('Flutter Error', error: details.exception, stackTrace: details.stack);
      FlutterError.presentError(details);
    };

    // 捕捉非同步任務中發出的錯誤
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
    // 捕捉任何溢出的例外狀況
    DatabaseService.log('Uncaught Global Error', error: error, stackTrace: stack);
  });
}

/// 應用程式主要 Widget。
class GarbageMapApp extends StatefulWidget {
  const GarbageMapApp({super.key});

  @override
  State<GarbageMapApp> createState() => _GarbageMapAppState();
}

class _GarbageMapAppState extends State<GarbageMapApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 在 Windows 平台，當視窗被關閉時，Lifecycle 會進入 detached
    // 我們主動執行 exit(0) 以確保程式徹底退出，不會留在背景。
    if (state == AppLifecycleState.detached && !kIsWeb) {
      DatabaseService.log('Window closed, exiting application.');
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '台灣垃圾車即時地圖',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.yellow,
          primary: Colors.yellow[800]!,
          secondary: Colors.orange,
        ),
        useMaterial3: true,
      ),
      // 首頁顯示地圖螢幕
      home: const MapScreen(),
    );
  }
}
