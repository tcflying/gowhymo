import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:gowhymo/models/focus_session.dart';
import 'lib.dart' as db_lib;

/// 创建专注学习会话表
Future<void> createFocusSessionsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS focus_sessions (
      id TEXT PRIMARY KEY,
      kid_id INTEGER NOT NULL,
      plan_id TEXT,
      content TEXT NOT NULL,
      estimated_minutes INTEGER NOT NULL,
      actual_minutes INTEGER,
      started_at TEXT,
      completed_at TEXT,
      quality TEXT,
      status TEXT NOT NULL,
      base_reward INTEGER,
      time_bonus INTEGER,
      quality_multiplier REAL,
      final_reward INTEGER,
      is_accurate_estimate INTEGER,
      prophet_bonus INTEGER,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');

  // 创建索引以优化查询
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_focus_sessions_kid_id 
    ON focus_sessions(kid_id)
  ''');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_focus_sessions_status 
    ON focus_sessions(status)
  ''');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_focus_sessions_completed_at 
    ON focus_sessions(completed_at)
  ''');
}

/// 专注学习会话表操作类
class FocusSessionDao {
  static const String _tableName = 'focus_sessions';

  /// 获取数据库实例
  static Future<Database> get _database async {
    return await db_lib.getDatabase();
  }

  /// 将会话状态转换为整数（SQLite存储）
  static int? _boolToInt(bool? value) {
    if (value == null) return null;
    return value ? 1 : 0;
  }

  /// 将整数转换为布尔值
  static bool? _intToBool(int? value) {
    if (value == null) return null;
    return value == 1;
  }

  /// 将FocusSession转换为数据库Map
  static Map<String, dynamic> _toDbMap(FocusSession session) {
    return {
      'id': session.id,
      'kid_id': session.kidId,
      'plan_id': session.planId,
      'content': session.content,
      'estimated_minutes': session.estimatedMinutes,
      'actual_minutes': session.actualMinutes,
      'started_at': session.startedAt?.toIso8601String(),
      'completed_at': session.completedAt?.toIso8601String(),
      'quality': session.quality?.name,
      'status': session.status.name,
      'base_reward': session.baseReward,
      'time_bonus': session.timeBonus,
      'quality_multiplier': session.qualityMultiplier,
      'final_reward': session.finalReward,
      'is_accurate_estimate': _boolToInt(session.isAccurateEstimate),
      'prophet_bonus': session.prophetBonus,
      'created_at': session.createdAt.toIso8601String(),
      'updated_at': session.updatedAt.toIso8601String(),
    };
  }

  /// 将数据库Map转换为FocusSession
  static FocusSession _fromDbMap(Map<String, dynamic> map) {
    return FocusSession(
      id: map['id'] as String,
      kidId: map['kid_id'] as int,
      planId: map['plan_id'] as String?,
      content: map['content'] as String,
      estimatedMinutes: map['estimated_minutes'] as int,
      actualMinutes: map['actual_minutes'] as int?,
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      quality: map['quality'] != null
          ? FocusQuality.values.byName(map['quality'] as String)
          : null,
      status: FocusSessionStatus.values.byName(map['status'] as String),
      baseReward: map['base_reward'] as int?,
      timeBonus: map['time_bonus'] as int?,
      qualityMultiplier: map['quality_multiplier'] != null
          ? (map['quality_multiplier'] as num).toDouble()
          : null,
      finalReward: map['final_reward'] as int?,
      isAccurateEstimate: _intToBool(map['is_accurate_estimate'] as int?),
      prophetBonus: map['prophet_bonus'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// 插入新的专注会话
  static Future<int> insert(FocusSession session) async {
    final db = await _database;
    return await db.insert(
      _tableName,
      _toDbMap(session),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新专注会话
  static Future<int> update(FocusSession session) async {
    final db = await _database;
    return await db.update(
      _tableName,
      _toDbMap(session),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// 根据ID查询会话
  static Future<FocusSession?> getById(String id) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _fromDbMap(maps.first);
  }

  /// 根据kidId查询所有会话
  static Future<List<FocusSession>> getByKidId(int kidId) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'kid_id = ?',
      whereArgs: [kidId],
      orderBy: 'created_at DESC',
    );
    return maps.map(_fromDbMap).toList();
  }

  /// 查询进行中的会话
  static Future<FocusSession?> getRunningSession(int kidId) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'kid_id = ? AND status = ?',
      whereArgs: [kidId, FocusSessionStatus.running.name],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _fromDbMap(maps.first);
  }

  /// 查询今日已完成的会话
  static Future<List<FocusSession>> getTodayCompletedSessions(int kidId) async {
    final db = await _database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final maps = await db.query(
      _tableName,
      where: 'kid_id = ? AND status = ? AND completed_at >= ? AND completed_at < ?',
      whereArgs: [
        kidId,
        FocusSessionStatus.completed.name,
        today.toIso8601String(),
        tomorrow.toIso8601String(),
      ],
      orderBy: 'completed_at DESC',
    );
    return maps.map(_fromDbMap).toList();
  }

  /// 查询本周已完成的会话
  static Future<List<FocusSession>> getThisWeekCompletedSessions(int kidId) async {
    final db = await _database;
    final now = DateTime.now();
    // 获取本周一
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final weekEnd = weekStart.add(const Duration(days: 7));

    final maps = await db.query(
      _tableName,
      where: 'kid_id = ? AND status = ? AND completed_at >= ? AND completed_at < ?',
      whereArgs: [
        kidId,
        FocusSessionStatus.completed.name,
        weekStart.toIso8601String(),
        weekEnd.toIso8601String(),
      ],
      orderBy: 'completed_at DESC',
    );
    return maps.map(_fromDbMap).toList();
  }

  /// 获取今日获得的总奖励
  static Future<int> getTodayTotalReward(int kidId) async {
    final sessions = await getTodayCompletedSessions(kidId);
    return sessions.fold<int>(0, (sum, s) => sum + (s.finalReward ?? 0));
  }

  /// 获取本周获得的总奖励
  static Future<int> getThisWeekTotalReward(int kidId) async {
    final sessions = await getThisWeekCompletedSessions(kidId);
    return sessions.fold<int>(0, (sum, s) => sum + (s.finalReward ?? 0));
  }

  /// 获取历史会话（用于预估建议）
  static Future<List<FocusSession>> getHistoryForSuggestion(
    int kidId,
    String content, {
    int limit = 10,
  }) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'kid_id = ? AND status = ? AND content LIKE ?',
      whereArgs: [
        kidId,
        FocusSessionStatus.completed.name,
        '%$content%',
      ],
      orderBy: 'completed_at DESC',
      limit: limit,
    );
    return maps.map(_fromDbMap).toList();
  }

  /// 删除会话
  static Future<int> delete(String id) async {
    final db = await _database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除孩子的所有会话
  static Future<int> deleteByKidId(int kidId) async {
    final db = await _database;
    return await db.delete(
      _tableName,
      where: 'kid_id = ?',
      whereArgs: [kidId],
    );
  }

  /// 获取统计信息
  static Future<Map<String, dynamic>> getStatistics(int kidId) async {
    final db = await _database;

    // 总会话数
    final totalCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $_tableName WHERE kid_id = ?',
      [kidId],
    )) ?? 0;

    // 已完成会话数
    final completedCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $_tableName WHERE kid_id = ? AND status = ?',
      [kidId, FocusSessionStatus.completed.name],
    )) ?? 0;

    // 总奖励
    final totalRewardResult = await db.rawQuery(
      'SELECT SUM(final_reward) as total FROM $_tableName WHERE kid_id = ? AND status = ?',
      [kidId, FocusSessionStatus.completed.name],
    );
    final totalReward = (totalRewardResult.first['total'] as num?)?.toInt() ?? 0;

    // 平均预估准确度
    final accuracyResult = await db.rawQuery(
      'SELECT AVG(CASE WHEN is_accurate_estimate = 1 THEN 1.0 ELSE 0.0 END) as avg_accuracy '
      'FROM $_tableName WHERE kid_id = ? AND status = ?',
      [kidId, FocusSessionStatus.completed.name],
    );
    final avgAccuracy = (accuracyResult.first['avg_accuracy'] as num?)?.toDouble() ?? 0.0;

    return {
      'totalSessions': totalCount,
      'completedSessions': completedCount,
      'totalReward': totalReward,
      'averageAccuracy': avgAccuracy,
    };
  }
}
