import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/garbage_route_point.dart';
import 'package:latlong2/latlong.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;
  static const String tableName = 'route_points';
  static const String metaTable = 'metadata';

  // 日誌記錄
  static Future<void> log(String message) async {
    final now = DateTime.now();
    final logStr = '[$now] $message\n';
    print(logStr);
    try {
      final file = File(r'C:\Users\bapral\AppData\Local\garbage_map_debug.log');
      await file.writeAsString(logStr, mode: FileMode.append);
    } catch (_) {}
  }

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final String path = join(await getDatabasesPath(), 'garbage_map_v3.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE $tableName (lineId TEXT, lineName TEXT, rank INTEGER, name TEXT, latitude REAL, longitude REAL, arrivalTime TEXT)');
        await db.execute('CREATE TABLE $metaTable (key TEXT PRIMARY KEY, value TEXT)');
        await db.execute('CREATE INDEX idx_lineId ON $tableName (lineId)');
        await db.execute('CREATE INDEX idx_time ON $tableName (arrivalTime)');
      },
    );
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

  Future<void> clearAllRoutePoints() async {
    final database = await db;
    await database.delete(tableName);
  }

  Future<void> saveRoutePoints(List<GarbageRoutePoint> points) async {
    final database = await db;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (var p in points) {
        batch.insert(tableName, {
          'lineId': p.lineId, 'lineName': p.lineName, 'rank': p.rank, 'name': p.name,
          'latitude': p.position.latitude, 'longitude': p.position.longitude, 'arrivalTime': p.arrivalTime,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> getTotalCount() async {
    final database = await db;
    return Sqflite.firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM $tableName')) ?? 0;
  }

  Future<bool> hasData() async => (await getTotalCount()) > 0;

  Future<List<GarbageRoutePoint>> findPointsByTime(int hour, int minute) async {
    final database = await db;
    final String start = _offsetTime(hour, minute, -15);
    final String end = _offsetTime(hour, minute, 15);
    final List<Map<String, dynamic>> maps = await database.query(tableName, where: "arrivalTime >= ? AND arrivalTime <= ?", whereArgs: [start, end]);
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

  Future<List<GarbageRoutePoint>> getRoutePoints(String lineId) async {
    final database = await db;
    final List<Map<String, dynamic>> maps = await database.query(tableName, where: 'lineId = ?', whereArgs: [lineId], orderBy: 'rank ASC');
    return maps.map((m) => GarbageRoutePoint(
      lineId: m['lineId'], lineName: m['lineName'], rank: m['rank'], name: m['name'],
      position: LatLng(m['latitude'], m['longitude']), arrivalTime: m['arrivalTime'],
    )).toList();
  }
}
