import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/garbage_route_point.dart';
import 'package:latlong2/latlong.dart';

class DatabaseService {
  static Database? _db;
  static const String tableName = 'route_points';
  static const String metaTable = 'metadata';

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

    final String path = join(await getDatabasesPath(), 'garbage_map_v2.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            lineId TEXT,
            lineName TEXT,
            rank INTEGER,
            name TEXT,
            latitude REAL,
            longitude REAL,
            arrivalTime TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE $metaTable (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_lineId ON $tableName (lineId)');
        await db.execute('CREATE INDEX idx_time ON $tableName (arrivalTime)');
      },
    );
  }

  Future<String?> getStoredVersion() async {
    final database = await db;
    final List<Map<String, dynamic>> maps = await database.query(
      metaTable,
      where: 'key = ?',
      whereArgs: ['app_version'],
    );
    if (maps.isNotEmpty) return maps.first['value'];
    return null;
  }

  Future<void> updateVersion(String version) async {
    final database = await db;
    await database.insert(
      metaTable,
      {'key': 'app_version', 'value': version},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAllRoutePoints() async {
    final database = await db;
    await database.delete(tableName);
  }

  Future<void> saveRoutePoints(List<GarbageRoutePoint> points) async {
    final database = await db;
    final batch = database.batch();
    for (var p in points) {
      batch.insert(tableName, {
        'lineId': p.lineId,
        'lineName': p.lineName,
        'rank': p.rank,
        'name': p.name,
        'latitude': p.position.latitude,
        'longitude': p.position.longitude,
        'arrivalTime': p.arrivalTime,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<int> getTotalCount() async {
    final database = await db;
    final count = Sqflite.firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM $tableName'));
    return count ?? 0;
  }

  Future<bool> hasData() async {
    return (await getTotalCount()) > 0;
  }

  Future<List<GarbageRoutePoint>> findPointsByTime(int hour, int minute) async {
    final database = await db;
    final String timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    
    final List<Map<String, dynamic>> maps = await database.query(
      tableName,
      where: "arrivalTime >= ? AND arrivalTime <= ?",
      whereArgs: [
        _offsetTime(hour, minute, -15),
        _offsetTime(hour, minute, 15),
      ],
    );

    return List.generate(maps.length, (i) {
      return GarbageRoutePoint(
        lineId: maps[i]['lineId'] ?? '',
        lineName: maps[i]['lineName'] ?? '',
        rank: maps[i]['rank'] ?? 0,
        name: maps[i]['name'] ?? '',
        position: LatLng(maps[i]['latitude'] ?? 0, maps[i]['longitude'] ?? 0),
        arrivalTime: maps[i]['arrivalTime'] ?? '',
      );
    });
  }

  String _offsetTime(int h, int m, int offset) {
    int total = h * 60 + m + offset;
    if (total < 0) total = 0;
    if (total > 1439) total = 1439;
    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  Future<List<GarbageRoutePoint>> getRoutePoints(String lineId) async {
    final database = await db;
    final List<Map<String, dynamic>> maps = await database.query(
      tableName,
      where: 'lineId = ?',
      whereArgs: [lineId],
      orderBy: 'rank ASC',
    );
    return maps.map((m) => GarbageRoutePoint(
      lineId: m['lineId'],
      lineName: m['lineName'],
      rank: m['rank'],
      name: m['name'],
      position: LatLng(m['latitude'], m['longitude']),
      arrivalTime: m['arrivalTime'],
    )).toList();
  }
}
