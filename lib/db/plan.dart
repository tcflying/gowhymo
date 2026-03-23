import 'dart:convert';
import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import 'lib.dart' as db_lib;

Future<void> createPlansTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS plans (
      plan_id INTEGER PRIMARY KEY AUTOINCREMENT,
      kid_id INTEGER NOT NULL,
      content TEXT NOT NULL,
      date TEXT NOT NULL,
      slot_name TEXT NOT NULL,
      location TEXT,
      created_by TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
}

class Plan {
  final int planId;
  final int kidId;
  final String content;
  final DateTime date;
  final String slotName;
  final String? location;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Plan({
    required this.planId,
    required this.kidId,
    required this.content,
    required this.date,
    required this.slotName,
    this.location,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      planId: json['plan_id'] as int,
      kidId: json['kid_id'] as int,
      content: json['content'] as String,
      date: DateTime.parse(json['date'] as String),
      slotName: json['slot_name'] as String,
      location: json['location'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan_id': planId,
      'kid_id': kidId,
      'content': content,
      'date': date.toIso8601String(),
      'slot_name': slotName,
      'location': location,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String toJsonString() {
    return json.encode(toJson());
  }

  static Plan fromJsonString(String jsonString) {
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    return Plan.fromJson(jsonMap);
  }

  Plan copyWith({
    int? planId,
    int? kidId,
    String? content,
    DateTime? date,
    String? slotName,
    String? location,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Plan(
      planId: planId ?? this.planId,
      kidId: kidId ?? this.kidId,
      content: content ?? this.content,
      date: date ?? this.date,
      slotName: slotName ?? this.slotName,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Plan表操作类
class PlanDao {
  static const String _tableName = 'plans';
  static Database? _db;

  /// 获取数据库实例 - 使用共享的数据库实例
  static Future<Database> get _database async {
    return await db_lib.getDatabase();
  }

  /// 新增或替换计划记录
  static Future<int> insertOrReplace(Plan plan) async {
    final db = await _database;
    return await db.insert(
      _tableName,
      plan.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> insert(Plan plan) async {
    final db = await _database;
    // 创建新的Map，移除plan_id字段让数据库自动生成
    final planData = Map<String, dynamic>.from(plan.toJson());
    planData.remove('plan_id');

    return await db.insert(
      _tableName,
      planData,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 根据plan_id查询计划
  static Future<Plan?> getById(int planId) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'plan_id = ?',
      whereArgs: [planId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Plan.fromJson(maps.first);
  }

  /// 根据kid_id查询所有计划
  static Future<List<Plan>> getByKidId(int kidId) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'kid_id = ?',
      whereArgs: [kidId],
      orderBy: 'date ASC, slot_name ASC',
    );
    return maps.map((json) => Plan.fromJson(json)).toList();
  }

  /// 根据kid_id和日期查询计划
  static Future<List<Plan>> getByKidIdAndDate(int kidId, DateTime date) async {
    final db = await _database;
    final dateStr = date.toIso8601String().split('T')[0]; // 获取日期部分
    final maps = await db.query(
      _tableName,
      where: 'kid_id = ? AND date = ?',
      whereArgs: [kidId, dateStr],
      orderBy: 'slot_name ASC',
    );
    return maps.map((json) => Plan.fromJson(json)).toList();
  }

  /// 查询全部计划
  static Future<List<Plan>> getAll() async {
    final db = await _database;
    final maps = await db.query(_tableName, orderBy: 'date ASC, slot_name ASC');
    return maps.map((json) => Plan.fromJson(json)).toList();
  }

  /// 更新计划信息
  static Future<void> update(Plan plan) async {
    final db = await _database;
    await db.update(
      _tableName,
      plan.toJson(),
      where: 'plan_id = ?',
      whereArgs: [plan.planId],
    );
  }

  /// 删除计划
  static Future<void> delete(int planId) async {
    final db = await _database;
    await db.delete(_tableName, where: 'plan_id = ?', whereArgs: [planId]);
  }

  /// 关闭数据库
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
