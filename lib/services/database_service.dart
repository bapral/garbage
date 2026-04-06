import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/garbage_route_point.dart';
import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // 提供測試時重置單例的方法
  @visibleForTesting
  static void resetInstance() {
    _db?.close();
    _db = null;
    _instance = DatabaseService._internal();
  }

  static Database? _db;
  static const String tableName = 'route_points';
  static const String metaTable = 'metadata';
  
  // 允許自定義資料庫路徑 (預設為檔案路徑)
  static String? _customPath;
  @visibleForTesting
  static set customPath(String? path) => _customPath = path;

  // 日誌記錄
  static Future<void> log(String message, {Object? error, StackTrace? stackTrace}) async {
    final now = DateTime.now();
    final logStr = '[$now] $message${error != null ? '\nError: $error' : ''}${stackTrace != null ? '\nStackTrace: $stackTrace' : ''}\n---\n';
    debugPrint(logStr);
    
    // 非同步寫入檔案，不阻塞執行流程
    _writeLogToFile(logStr);
  }

  static Future<void> _writeLogToFile(String logStr) async {
    try {
      String? logPath;
      if (Platform.isWindows) {
        final localAppData = Platform.environment['LOCALAPPDATA'];
        if (localAppData != null) {
          logPath = join(localAppData, 'garbage_map_debug.log');
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        logPath = join(Platform.environment['HOME'] ?? '.', 'garbage_map_debug.log');
      }
      
      if (logPath != null) {
        final file = File(logPath);
        await file.writeAsString(logStr, mode: FileMode.append, flush: true);
      }
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    try {
      await log('Initializing database...');
      if (Platform.isWindows || Platform.isLinux) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        await log('sqfliteFfi initialized');
      }
      
      // 如果有設定自定義路徑（如記憶體資料庫），優先使用
      final String path = _customPath ?? join(await getDatabasesPath(), 'garbage_map_v3.db');
      await log('Database path: $path');
      
      final db = await openDatabase(
        path,
        version: 2, // 升級版本以套用 city 欄位
        onCreate: (db, version) async {
          await log('Creating database tables...');
          await db.execute('CREATE TABLE $tableName (lineId TEXT, lineName TEXT, rank INTEGER, name TEXT, latitude REAL, longitude REAL, arrivalTime TEXT, city TEXT)');
          await db.execute('CREATE TABLE $metaTable (key TEXT PRIMARY KEY, value TEXT)');
          await db.execute('CREATE INDEX idx_lineId ON $tableName (lineId)');
          await db.execute('CREATE INDEX idx_time ON $tableName (arrivalTime)');
          await db.execute('CREATE INDEX idx_city ON $tableName (city)');
          await log('Tables created successfully');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await log('Upgrading database from $oldVersion to $newVersion...');
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE $tableName ADD COLUMN city TEXT');
            await db.execute('CREATE INDEX idx_city ON $tableName (city)');
          }
          await log('Upgrade complete');
        },
      );
      await log('Database opened successfully');
      return db;
    } catch (e, stack) {
      await log('Database initialization failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<String?> getStoredVersion() async {
    final database = await db;
    final List<Map<String, dynamic>> maps = await database.query(metaTable, where: 'key = ?', whereArgs: ['app_version']);
    return maps.isNotEmpty ? maps.first['value'] : null;
  }

  Future<void> updateVersion(String version) async {
    final database = await db;
    await database.insert(metaTable, {'key': 'app_version', 'value': version}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearAllRoutePoints(String city) async {
    final database = await db;
    await database.delete(tableName, where: 'city = ?', whereArgs: [city]);
  }

  Future<void> saveRoutePoints(List<GarbageRoutePoint> points, String city) async {
    final database = await db;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (var p in points) {
        batch.insert(tableName, {
          'lineId': p.lineId, 'lineName': p.lineName, 'rank': p.rank, 'name': p.name,
          'latitude': p.position.latitude, 'longitude': p.position.longitude, 'arrivalTime': p.arrivalTime,
          'city': city,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> getTotalCount([String? city]) async {
    final database = await db;
    if (city != null) {
      return Sqflite.firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM $tableName WHERE city = ?', [city])) ?? 0;
    }
    return Sqflite.firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM $tableName')) ?? 0;
  }

  Future<bool> hasData(String city) async => (await getTotalCount(city)) > 0;

  Future<List<GarbageRoutePoint>> findPointsByTime(int hour, int minute, String city) async {
    final database = await db;
    // 只抓取指定時間起 +20 分鐘內的資料
    final String start = _offsetTime(hour, minute, 0);
    final String end = _offsetTime(hour, minute, 20);
    final List<Map<String, dynamic>> maps = await database.query(
      tableName, 
      where: "arrivalTime >= ? AND arrivalTime <= ? AND city = ?", 
      whereArgs: [start, end, city]
    );
    return maps.map((m) => GarbageRoutePoint(
      lineId: m['lineId'] ?? '', lineName: m['lineName'] ?? '', rank: m['rank'] ?? 0, name: m['name'] ?? '',
      position: LatLng(m['latitude'] ?? 0, m['longitude'] ?? 0), arrivalTime: m['arrivalTime'] ?? '',
    )).toList();
  }

  String _offsetTime(int h, int m, int offset) {
    int total = h * 60 + m + offset;
    if (total < 0) total = 0; if (total > 1439) total = 1439;
    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  Future<List<GarbageRoutePoint>> getRoutePoints(String lineId, String city) async {
    final database = await db;
    final List<Map<String, dynamic>> maps = await database.query(
      tableName, 
      where: 'lineId = ? AND city = ?', 
      whereArgs: [lineId, city], 
      orderBy: 'rank ASC'
    );
    return maps.map((m) => GarbageRoutePoint(
      lineId: m['lineId'], lineName: m['lineName'], rank: m['rank'], name: m['name'],
      position: LatLng(m['latitude'], m['longitude']), arrivalTime: m['arrivalTime'],
    )).toList();
  }
}
