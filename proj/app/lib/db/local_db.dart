import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('local_item_intelli.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. 精密工具本地 SQLite 表 (对应 PostgreSQL 结构)
    await db.execute('''
      CREATE TABLE tools (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        model TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT '在库',
        use_count INTEGER NOT NULL DEFAULT 0,
        lifespan_limit INTEGER NOT NULL DEFAULT 30,
        location TEXT DEFAULT '基地总库',
        operator TEXT NOT NULL,
        last_update_time TEXT NOT NULL,
        checkout_time TEXT
      )
    ''');

    // 2. 配件表
    await db.execute('''
      CREATE TABLE accessories (
        barcode TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        spec TEXT NOT NULL,
        unit TEXT NOT NULL DEFAULT '个',
        safety_stock INTEGER NOT NULL DEFAULT 20,
        current_stock INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 3. 离线待同步日志缓存表
    await db.execute('''
      CREATE TABLE local_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        time_str TEXT NOT NULL,
        type TEXT NOT NULL,
        tool_code TEXT NOT NULL,
        operator TEXT NOT NULL,
        detail TEXT NOT NULL
      )
    ''');

    // 4. 下发字典表
    await db.execute('''
      CREATE TABLE dictionaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dict_type TEXT NOT NULL,
        dict_value TEXT NOT NULL,
        UNIQUE(dict_type, dict_value)
      )
    ''');

    // 5. 本地配置表
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 数据库操作封装 (CRUD & Logs)
  // ─────────────────────────────────────────────────────────────

  // 获取所有在库/离库工具
  Future<List<Map<String, dynamic>>> getTools() async {
    final db = await instance.database;
    return await db.query('tools');
  }

  // 获取特定工具
  Future<Map<String, dynamic>?> getTool(String code) async {
    final db = await instance.database;
    final maps = await db.query(
      'tools',
      where: 'code = ?',
      whereArgs: [code],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // 获取配件库存
  Future<List<Map<String, dynamic>>> getAccessories() async {
    final db = await instance.database;
    return await db.query('accessories');
  }

  // 写入待同步离线操作日志
  Future<int> insertLocalLog(Map<String, dynamic> log) async {
    final db = await instance.database;
    return await db.insert('local_logs', {
      'timestamp': log['timestamp'],
      'time_str': log['timeStr'],
      'type': log['type'],
      'tool_code': log['toolCode'],
      'operator': log['operator'],
      'detail': jsonEncode(log['detail']),
    });
  }

  // 获取所有待同步日志
  Future<List<Map<String, dynamic>>> getLocalLogs() async {
    final db = await instance.database;
    return await db.query('local_logs', orderBy: 'timestamp ASC');
  }

  // 获取下发的字典数据 (根据类别)
  Future<List<String>> getDictionaryValues(String type) async {
    final db = await instance.database;
    final results = await db.query(
      'dictionaries',
      columns: ['dict_value'],
      where: 'dict_type = ?',
      whereArgs: [type],
    );
    return results.map((r) => r['dict_value'] as String).toList();
  }

  // 保存本地配置
  Future<void> saveSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 获取本地配置
  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  // 回库近场同步握手成功后，由 API 返回的最新全局总账覆写本地，并清空同步成功的日志
  Future performSyncAlignment(
    List<Map<String, dynamic>> tools,
    List<Map<String, dynamic>> accessories,
    Map<String, List<String>> dicts,
  ) async {
    final db = await instance.database;
    
    await db.transaction((txn) async {
      // 1. 清除旧资产和配件
      await txn.delete('tools');
      await txn.delete('accessories');
      await txn.delete('dictionaries');
      await txn.delete('local_logs'); // 成功同步，清空日志

      // 2. 写入新工具
      for (var t in tools) {
        await txn.insert('tools', t);
      }

      // 3. 写入新配件
      for (var a in accessories) {
        await txn.insert('accessories', a);
      }

      // 4. 写入新字典参数
      for (final entry in dicts.entries) {
        for (var val in entry.value) {
          await txn.insert('dictionaries', {
            'dict_type': entry.key,
            'dict_value': val,
          });
        }
      }
    });
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
