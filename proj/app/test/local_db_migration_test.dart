import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app/db/local_db.dart';

Future<void> _createVersion1Schema(Database db) async {
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

  await db.execute('''
    CREATE TABLE dictionaries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      dict_type TEXT NOT NULL,
      dict_value TEXT NOT NULL,
      UNIQUE(dict_type, dict_value)
    )
  ''');
}

void main() {
  late Database db;
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('item_intelli_db_test_');
    dbPath = '${tempDir.path}${Platform.pathSeparator}migration.db';
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('migrates v1 database to v2 without losing local data', () async {
    db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await _createVersion1Schema(db);
          await db.insert('tools', {
            'code': 'TL-OLD-001',
            'name': '旧库工具',
            'model': 'M1',
            'status': '在库',
            'use_count': 1,
            'lifespan_limit': 30,
            'location': '基地总库',
            'operator': '测试员',
            'last_update_time': '2026-06-21T00:00:00',
          });
          await db.insert('accessories', {
            'barcode': 'ACC-OLD-001',
            'name': '旧库配件',
            'spec': 'S1',
            'unit': '个',
            'safety_stock': 2,
            'current_stock': 3,
          });
          await db.insert('local_logs', {
            'timestamp': 1,
            'time_str': '2026-06-21 00:00:00',
            'type': 'checkout',
            'tool_code': 'TL-OLD-001',
            'operator': '测试员',
            'detail': '{}',
          });
          await db.insert('dictionaries', {
            'dict_type': 'operator',
            'dict_value': '测试员',
          });
        },
      ),
    );
    await db.close();

    db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: LocalDatabase.databaseVersion,
        onUpgrade: LocalDatabase.migrateSchema,
      ),
    );

    final settingsColumns = await db.rawQuery('PRAGMA table_info(settings)');
    expect(settingsColumns.map((row) => row['name']), containsAll(['key', 'value']));
    expect(await db.query('tools'), hasLength(1));
    expect(await db.query('accessories'), hasLength(1));
    expect(await db.query('local_logs'), hasLength(1));
    expect(await db.query('dictionaries'), hasLength(1));
  });
}
