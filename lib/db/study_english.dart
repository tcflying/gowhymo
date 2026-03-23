import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import 'lib.dart' as db_lib;

Future<void> createEnglishWordsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS english_words (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kid_id INTEGER NOT NULL,
      word TEXT NOT NULL,
      phonetic TEXT,
      definition TEXT NOT NULL,
      example TEXT,
      spelling TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (kid_id) REFERENCES kids(id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_kid_id ON english_words(kid_id)
  ''');
}

Future<void> createWordStudyRecordsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS word_study_records (
      kid_id INTEGER NOT NULL,
      word_id INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'new',
      interval_days INTEGER NOT NULL DEFAULT 0,
      consecutive_correct INTEGER NOT NULL DEFAULT 0,
      ef REAL NOT NULL DEFAULT 2.5,
      last_review_time INTEGER NOT NULL,
      next_review_time INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (kid_id, word_id),
      FOREIGN KEY (kid_id) REFERENCES kids(id) ON DELETE CASCADE,
      FOREIGN KEY (word_id) REFERENCES english_words(id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_next_review_time ON word_study_records(next_review_time)
  ''');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_status ON word_study_records(status)
  ''');
}

class EnglishWord {
  final int id;
  final int kidId;
  final String word;
  final String? phonetic;
  final String definition;
  final String? example;
  final String? spelling;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EnglishWord({
    required this.id,
    required this.kidId,
    required this.word,
    required this.phonetic,
    required this.definition,
    required this.example,
    required this.spelling,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EnglishWord.fromJson(Map<String, dynamic> json) {
    return EnglishWord(
      id: json['id'] as int,
      kidId: json['kid_id'] as int,
      word: json['word'] as String,
      phonetic: json['phonetic'] as String?,
      definition: json['definition'] as String,
      example: json['example'] as String?,
      spelling: json['spelling'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kid_id': kidId,
      'word': word,
      'phonetic': phonetic,
      'definition': definition,
      'example': example,
      'spelling': spelling,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EnglishWord copyWith({
    int? id,
    int? kidId,
    String? word,
    String? phonetic,
    String? definition,
    String? example,
    String? spelling,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EnglishWord(
      id: id ?? this.id,
      kidId: kidId ?? this.kidId,
      word: word ?? this.word,
      phonetic: phonetic ?? this.phonetic,
      definition: definition ?? this.definition,
      example: example ?? this.example,
      spelling: spelling ?? this.spelling,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class EnglishWordDao {
  static const String _tableName = 'english_words';

  static Future<Database> get _database async {
    return await db_lib.getDatabase();
  }

  static Future<int> insert(EnglishWord word) async {
    final db = await _database;
    final wordData = Map<String, dynamic>.from(word.toJson());
    wordData.remove('id');
    return await db.insert(
      _tableName,
      wordData,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<int> insertOrReplace(EnglishWord word) async {
    final db = await _database;
    return await db.insert(
      _tableName,
      word.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> insertBatch(List<EnglishWord> words) async {
    final db = await _database;
    final batch = db.batch();
    for (final word in words) {
      final wordData = Map<String, dynamic>.from(word.toJson());
      wordData.remove('id');
      batch.insert(
        _tableName,
        wordData,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<EnglishWord>> getAll(int kidId) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'kid_id = ?',
      whereArgs: [kidId],
      orderBy: 'created_at DESC',
    );
    return maps.map((json) => EnglishWord.fromJson(json)).toList();
  }

  static Future<EnglishWord?> getById(int id) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return EnglishWord.fromJson(maps.first);
  }

  static Future<List<EnglishWord>> searchByKeyword(int kidId, String keyword) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'kid_id = ? AND (word LIKE ? OR definition LIKE ?)',
      whereArgs: [kidId, '%$keyword%', '%$keyword%'],
      orderBy: 'created_at DESC',
    );
    return maps.map((json) => EnglishWord.fromJson(json)).toList();
  }

  static Future<void> update(EnglishWord word) async {
    final db = await _database;
    await db.update(
      _tableName,
      word.toJson(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  static Future<void> delete(int id) async {
    final db = await _database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}

/// 单词学习记录模型类
/// 用于实现间隔重复学习算法(Spaced Repetition System, SRS)
/// 基于SuperMemo算法跟踪每个单词的学习进度和复习计划
class WordStudyRecord {
  /// 关联的孩子ID（复合主键的一部分）
  final int kidId;
  
  /// 关联的单词ID（复合主键的一部分）
  final int wordId;
  
  /// 学习状态：
  /// - 'new': 新词，尚未开始学习
  /// - 'learning': 学习中，需要频繁复习
  /// - 'reviewing': 复习中，按间隔重复算法安排复习
  final String status;
  
  /// 下次复习的间隔天数（基于间隔重复算法计算）
  final int intervalDays;
  
  /// 连续答对次数，用于计算复习间隔
  final int consecutiveCorrect;
  
  /// 易记性因子(Ease Factor)，基于SuperMemo算法
  /// - 初始值为2.5
  /// - 答对时增加，答错时减少
  /// - 影响下次复习间隔的计算
  final double ef;
  
  /// 上次复习时间（Unix时间戳，秒）
  final int lastReviewTime;
  
  /// 下次复习时间（Unix时间戳，秒）
  final int nextReviewTime;
  
  /// 记录创建时间（Unix时间戳，秒）
  final int createdAt;
  
  /// 记录最后更新时间（Unix时间戳，秒）
  final int updatedAt;

  const WordStudyRecord({
    required this.kidId,
    required this.wordId,
    required this.status,
    required this.intervalDays,
    required this.consecutiveCorrect,
    required this.ef,
    required this.lastReviewTime,
    required this.nextReviewTime,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WordStudyRecord.fromJson(Map<String, dynamic> json) {
    return WordStudyRecord(
      kidId: json['kid_id'] as int,
      wordId: json['word_id'] as int,
      status: json['status'] as String,
      intervalDays: json['interval_days'] as int,
      consecutiveCorrect: json['consecutive_correct'] as int,
      ef: (json['ef'] as num).toDouble(),
      lastReviewTime: json['last_review_time'] as int,
      nextReviewTime: json['next_review_time'] as int,
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kid_id': kidId,
      'word_id': wordId,
      'status': status,
      'interval_days': intervalDays,
      'consecutive_correct': consecutiveCorrect,
      'ef': ef,
      'last_review_time': lastReviewTime,
      'next_review_time': nextReviewTime,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  WordStudyRecord copyWith({
    int? kidId,
    int? wordId,
    String? status,
    int? intervalDays,
    int? consecutiveCorrect,
    double? ef,
    int? lastReviewTime,
    int? nextReviewTime,
    int? createdAt,
    int? updatedAt,
  }) {
    return WordStudyRecord(
      kidId: kidId ?? this.kidId,
      wordId: wordId ?? this.wordId,
      status: status ?? this.status,
      intervalDays: intervalDays ?? this.intervalDays,
      consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
      ef: ef ?? this.ef,
      lastReviewTime: lastReviewTime ?? this.lastReviewTime,
      nextReviewTime: nextReviewTime ?? this.nextReviewTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 单词学习记录数据访问对象(DAO)
/// 提供对word_study_records表的CRUD操作
/// 支持间隔重复学习算法的数据管理
class WordStudyRecordDao {
  /// 数据库表名
  static const String _tableName = 'word_study_records';

  /// 获取数据库实例
  static Future<Database> get _database async {
    return await db_lib.getDatabase();
  }

  /// 插入新的学习记录
  /// 自动移除ID字段（数据库自动生成）
  static Future<int> insert(WordStudyRecord record) async {
    final db = await _database;
    final recordData = Map<String, dynamic>.from(record.toJson());
    recordData.remove('id');
    return await db.insert(
      _tableName,
      recordData,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 插入或替换学习记录（存在冲突时替换）
  static Future<int> insertOrReplace(WordStudyRecord record) async {
    final db = await _database;
    return await db.insert(
      _tableName,
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批量插入学习记录
  static Future<void> insertBatch(List<WordStudyRecord> records) async {
    final db = await _database;
    final batch = db.batch();
    for (final record in records) {
      final recordData = Map<String, dynamic>.from(record.toJson());
      recordData.remove('id');
      batch.insert(
        _tableName,
        recordData,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 获取指定孩子的所有学习记录（按创建时间倒序）
  static Future<List<WordStudyRecord>> getAll(int kidId) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'kid_id = ?',
      whereArgs: [kidId],
      orderBy: 'created_at DESC',
    );
    return maps.map((json) => WordStudyRecord.fromJson(json)).toList();
  }

  /// 根据单词ID获取指定孩子的学习记录
  static Future<List<WordStudyRecord>> getByWordId(int kidId, int wordId) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'kid_id = ? AND word_id = ?',
      whereArgs: [kidId, wordId],
      orderBy: 'created_at DESC',
    );
    return maps.map((json) => WordStudyRecord.fromJson(json)).toList();
  }

  /// 获取需要复习的记录（下次复习时间已到）
  static Future<List<WordStudyRecord>> getDueForReview(int kidId) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final maps = await db.query(
      _tableName,
      where: 'kid_id = ? AND next_review_time <= ?',
      whereArgs: [kidId, now],
      orderBy: 'next_review_time ASC',
    );
    return maps.map((json) => WordStudyRecord.fromJson(json)).toList();
  }

  /// 更新学习记录
  static Future<void> update(WordStudyRecord record) async {
    final db = await _database;
    await db.update(
      _tableName,
      record.toJson(),
      where: 'kid_id = ? AND word_id = ?',
      whereArgs: [record.kidId, record.wordId],
    );
  }

  /// 根据复合主键删除学习记录
  static Future<void> delete(int kidId, int wordId) async {
    final db = await _database;
    await db.delete(_tableName, where: 'kid_id = ? AND word_id = ?', whereArgs: [kidId, wordId]);
  }

  /// 根据单词ID删除相关学习记录
  static Future<void> deleteByWordId(int wordId) async {
    final db = await _database;
    await db.delete(_tableName, where: 'word_id = ?', whereArgs: [wordId]);
  }

  /// 获取新词列表（状态为'new'）
  /// 按创建时间正序排列，支持限制数量
  static Future<List<WordStudyRecord>> getNewWords(int kidId, {int limit = 20}) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'kid_id = ? AND status = ?',
      whereArgs: [kidId, 'new'],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return maps.map((json) => WordStudyRecord.fromJson(json)).toList();
  }

  /// 获取复习队列（学习中或复习中且需要复习的记录）
  /// 按下次复习时间升序排列，支持限制数量
  static Future<List<WordStudyRecord>> getReviewQueue(int kidId, {int limit = 50}) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final maps = await db.query(
      _tableName,
      where: 'kid_id = ? AND status IN (?, ?) AND next_review_time <= ?',
      whereArgs: [kidId, 'learning', 'reviewing', now],
      orderBy: 'next_review_time ASC',
      limit: limit,
    );
    return maps.map((json) => WordStudyRecord.fromJson(json)).toList();
  }

  /// 更新学习记录（基于复习评分）
  /// 根据复习结果更新间隔重复算法参数
  /// 包括：状态、易记性因子、连续答对次数、间隔天数等
  static Future<void> updateStudyRecord({
    required int kidId,
    required int wordId,
    required ReviewRating rating,
  }) async {
    final db = await _database;
    final records = await db.query(
      _tableName,
      where: 'kid_id = ? AND word_id = ?',
      whereArgs: [kidId, wordId],
    );
    
    if (records.isEmpty) return;
    
    final record = WordStudyRecord.fromJson(records.first);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    final newStatus = calculateNextStatus(
      currentStatus: WordStatus.values.firstWhere(
        (s) => s.name == record.status,
        orElse: () => WordStatus.newWord,
      ),
      rating: rating,
    );
    
    final newEf = calculateEf(
      currentEf: record.ef,
      rating: rating,
    );
    
    int newConsecutiveCorrect;
    int newIntervalDays;
    
    if (rating == ReviewRating.forgot) {
      newConsecutiveCorrect = 0;
      newIntervalDays = 0;
    } else {
      newConsecutiveCorrect = record.consecutiveCorrect + 1;
      newIntervalDays = calculateNextReviewTime(
        currentIntervalDays: record.intervalDays,
        ef: newEf,
        consecutiveCorrect: newConsecutiveCorrect,
        rating: rating,
      ) - now;
      newIntervalDays = (newIntervalDays / 86400).round();
    }
    
    final nextReviewTime = calculateNextReviewTime(
      currentIntervalDays: newIntervalDays,
      ef: newEf,
      consecutiveCorrect: newConsecutiveCorrect,
      rating: rating,
    );
    
    await db.update(
      _tableName,
      {
        'status': newStatus.name,
        'interval_days': newIntervalDays,
        'consecutive_correct': newConsecutiveCorrect,
        'ef': newEf,
        'last_review_time': now,
        'next_review_time': nextReviewTime,
        'updated_at': now,
      },
      where: 'kid_id = ? AND word_id = ?',
      whereArgs: [kidId, wordId],
    );
  }

  /// 创建新的单词学习记录（初始化状态）
  /// 设置初始参数：状态为'new'，易记性因子为2.5，间隔为0
  /// 使用复合主键 (kid_id, word_id)，直接插入即可
  static Future<void> createNewWordRecord(int kidId, int wordId) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    final record = WordStudyRecord(
      kidId: kidId,
      wordId: wordId,
      status: 'new',
      intervalDays: 0,
      consecutiveCorrect: 0,
      ef: 2.5,
      lastReviewTime: now,
      nextReviewTime: now,
      createdAt: now,
      updatedAt: now,
    );
    
    await db.insert(
      _tableName,
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    log('createNewWordRecord - kidId: $kidId, wordId: $wordId', name: 'study_english.dart');
  }

  /// 批量创建新的单词学习记录
  static Future<void> createNewWordRecordsBatch(int kidId, List<int> wordIds) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final batch = db.batch();
    for (final wordId in wordIds) {
      final record = WordStudyRecord(
        kidId: kidId,
        wordId: wordId,
        status: 'new',
        intervalDays: 0,
        consecutiveCorrect: 0,
        ef: 2.5,
        lastReviewTime: now,
        nextReviewTime: now,
        createdAt: now,
        updatedAt: now,
      );
      batch.insert(
        _tableName,
        record.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    log('createNewWordRecordsBatch - kidId: $kidId, 创建了 ${wordIds.length} 个学习记录', name: 'study_english.dart');
  }

  /// 获取今日已复习的单词数量
  static Future<int> getTodayReviewCount(int kidId) async {
    final db = await _database;
    final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0).millisecondsSinceEpoch ~/ 1000;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM $_tableName
      WHERE kid_id = ? AND last_review_time >= ?
    ''', [kidId, todayStart]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取新词数量（状态为'new'）
  static Future<int> getNewWordCount(int kidId) async {
    final db = await _database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM $_tableName
      WHERE kid_id = ? AND status = 'new'
    ''', [kidId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 清理孤立的单词学习记录（没有对应单词的记录）
  static Future<void> cleanupOrphanedRecords() async {
    final db = await _database;
    
    // 查找孤立的记录（word_id 不在 english_words 表中的记录）
    final orphanedRecords = await db.rawQuery('''
      SELECT wsr.kid_id, wsr.word_id FROM word_study_records wsr
      LEFT JOIN english_words ew ON wsr.word_id = ew.id
      WHERE ew.id IS NULL
    ''');
    
    if (orphanedRecords.isNotEmpty) {
      log('发现 ${orphanedRecords.length} 个孤立的学习记录，正在清理...', name: 'study_english.dart');
      
      for (final record in orphanedRecords) {
        final kidId = record['kid_id'] as int;
        final wordId = record['word_id'] as int;
        await db.delete(_tableName, where: 'kid_id = ? AND word_id = ?', whereArgs: [kidId, wordId]);
        log('删除孤立的学习记录 - kidId: $kidId, wordId: $wordId', name: 'study_english.dart');
      }
      
      log('清理完成，共删除 ${orphanedRecords.length} 个孤立记录', name: 'study_english.dart');
    } else {
      log('没有发现孤立的学习记录', name: 'study_english.dart');
    }
  }
}

Future<EnglishWord> createEnglishWord({
  required int kidId,
  required String word,
  required String definition,
  String? phonetic,
  String? example,
  String? spelling,
}) async {
  try {
    final now = DateTime.now();
    final englishWord = EnglishWord(
      id: 0,
      kidId: kidId,
      word: word,
      phonetic: phonetic,
      definition: definition,
      example: example,
      spelling: spelling,
      createdAt: now,
      updatedAt: now,
    );

    await EnglishWordDao.insert(englishWord);
    return englishWord;
  } catch (e) {
    log('创建单词失败: $e', name: 'db/english_word.dart');
    rethrow;
  }
}

enum WordStatus {
  newWord,
  learning,
  reviewing,
}

enum ReviewRating {
  forgot,
  hard,
  good,
  easy,
}

int calculateNextReviewTime({
  required int currentIntervalDays,
  required double ef,
  required int consecutiveCorrect,
  required ReviewRating rating,
}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  
  switch (rating) {
    case ReviewRating.forgot:
      return now;
    case ReviewRating.hard:
      return now + (Duration(days: 1).inSeconds);
    case ReviewRating.good:
      if (consecutiveCorrect == 1) {
        return now + (Duration(days: 1).inSeconds);
      } else if (consecutiveCorrect == 2) {
        return now + (Duration(days: 6).inSeconds);
      } else {
        return now + (Duration(days: (currentIntervalDays * ef).round()).inSeconds);
      }
    case ReviewRating.easy:
      if (consecutiveCorrect == 1) {
        return now + (Duration(days: 4).inSeconds);
      } else {
        return now + (Duration(days: (currentIntervalDays * ef * 1.3).round()).inSeconds);
      }
  }
}

double calculateEf({
  required double currentEf,
  required ReviewRating rating,
}) {
  double newEf = currentEf;
  
  switch (rating) {
    case ReviewRating.forgot:
      newEf = currentEf - 0.2;
      break;
    case ReviewRating.hard:
      newEf = currentEf - 0.15;
      break;
    case ReviewRating.good:
      newEf = currentEf;
      break;
    case ReviewRating.easy:
      newEf = currentEf + 0.1;
      break;
  }
  
  return newEf.clamp(1.3, 2.5);
}

WordStatus calculateNextStatus({
  required WordStatus currentStatus,
  required ReviewRating rating,
}) {
  if (rating == ReviewRating.forgot) {
    return WordStatus.learning;
  }
  
  if (currentStatus == WordStatus.newWord && rating == ReviewRating.good) {
    return WordStatus.learning;
  }
  
  if (currentStatus == WordStatus.learning && rating == ReviewRating.good) {
    return WordStatus.reviewing;
  }
  
  return currentStatus;
}
