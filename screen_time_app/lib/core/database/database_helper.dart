import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:math';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_usage.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE daily_usage (
        date TEXT PRIMARY KEY,
        total_minutes INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE app_schedules (
        package_name TEXT PRIMARY KEY,
        allowed_days TEXT,
        start_time TEXT,
        end_time TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE app_categories (
        package_name TEXT PRIMARY KEY,
        category TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE app_schedules (
          package_name TEXT PRIMARY KEY,
          allowed_days TEXT,
          start_time TEXT,
          end_time TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_categories (
          package_name TEXT PRIMARY KEY,
          category TEXT
        )
      ''');
    }
  }

  Future<void> upsertCategory(String packageName, String category) async {
    final db = await instance.database;
    await db.insert(
      'app_categories',
      {'package_name': packageName, 'category': category},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getCategories() async {
    final db = await instance.database;
    final result = await db.query('app_categories');
    Map<String, String> categories = {};
    for (var row in result) {
      categories[row['package_name'] as String] = row['category'] as String;
    }
    return categories;
  }

  Future<void> upsertSchedule(String packageName, String allowedDays, String? startTime, String? endTime) async {
    final db = await instance.database;
    await db.insert(
      'app_schedules',
      {
        'package_name': packageName,
        'allowed_days': allowedDays,
        'start_time': startTime,
        'end_time': endTime,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Map<String, dynamic>>> getSchedules() async {
    final db = await instance.database;
    final result = await db.query('app_schedules');
    Map<String, Map<String, dynamic>> schedules = {};
    for (var row in result) {
      schedules[row['package_name'] as String] = row;
    }
    return schedules;
  }

  Future<void> upsertUsage(String date, int minutes) async {
    final db = await instance.database;
    await db.insert(
      'daily_usage',
      {'date': date, 'total_minutes': minutes},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getUsageForDateRange(String startDate, String endDate) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(total_minutes) as sum FROM daily_usage WHERE date >= ? AND date <= ?',
      [startDate, endDate],
    );

    if (result.isNotEmpty && result.first['sum'] != null) {
      return (result.first['sum'] as num).toInt();
    }
    return 0;
  }

  Future<void> seedDummyData() async {
    // Purged for production
    return;
  }
}
