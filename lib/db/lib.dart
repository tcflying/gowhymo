import 'dart:developer';
import 'package:gowhymo/db/focus_session.dart';
import 'package:gowhymo/db/kid.dart';
import 'package:gowhymo/db/study_english.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 数据库实例缓存
Database? _database;

/// 数据库文件名
const String _databaseName = 'gowhymo.db';

/// 数据库版本号
const int _databaseVersion = 5;

/// 初始化数据库 - 如果数据库已存在则返回现有实例，否则创建新数据库
Future<Database> initDatabase() async {
  if (_database != null) {
    // log('数据库已存在，返回缓存实例', name: 'db/lib.dart');
    return _database!;
  }

  // log('初始化数据库...', name: 'db/lib.dart');
  _database = await _initDB(_databaseName);
  // log('数据库初始化完成', name: 'db/lib.dart');
  return _database!;
}

/// 获取数据库实例 - 供外部调用的主要函数
Future<Database> getDatabase() async {
  return await initDatabase();
}

/// 关闭数据库连接
Future<void> closeDatabase() async {
  if (_database != null) {
    await _database!.close();
    _database = null;
    // log('数据库连接已关闭', name: 'db/lib.dart');
  }
}

/// 内部数据库初始化函数
Future<Database> _initDB(String filePath) async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, filePath);

  return await openDatabase(
    path,
    version: _databaseVersion,
    onCreate: _createDB,
    onUpgrade: _onUpgrade,
    onConfigure: _onConfigure,
  );
}

/// 数据库配置回调
Future<void> _onConfigure(Database db) async {
  await db.rawQuery('PRAGMA foreign_keys = ON');
  await db.rawQuery('PRAGMA journal_mode = WAL');
  await db.rawQuery('PRAGMA synchronous = NORMAL');
  await db.rawQuery('PRAGMA cache_size = -64000');
  await db.rawQuery('PRAGMA temp_store = MEMORY');
}

/// 数据库创建回调
Future<void> _createDB(Database db, int version) async {
  // log('创建数据库表结构，版本: $version', name: 'db/lib.dart');
  // 创建应用配置表除了UI相关的配置项（ui相关的存在prefs中）
  await db.execute('''
    CREATE TABLE IF NOT EXISTS app_config (
      key TEXT PRIMARY KEY,
      value TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS user_identities (
      address TEXT PRIMARY KEY,              -- Base58编码的地址，作为用户唯一标识
      private_key TEXT NOT NULL,           -- Base58编码的私钥
      public_key TEXT NOT NULL,            -- Base58编码的公钥
      created_at INTEGER NOT NULL,         -- 创建时间戳
      updated_at INTEGER NOT NULL          -- 更新时间戳
    )
  ''');

  // 创建用户信息表 - 对应Rust层的User结构体
  await db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,                 -- UserIdentity address，外键关联
      phone TEXT,                          -- 手机号（可选）
      email TEXT,                          -- 邮箱（可选）
      password TEXT,                       -- 密码（可选）
      nickname TEXT,                       -- 昵称（可选）
      last_login_at INTEGER,              -- 最后登录时间戳（可选）
      created_at INTEGER NOT NULL,         -- 创建时间戳
      updated_at INTEGER NOT NULL,          -- 更新时间戳
      FOREIGN KEY (id) REFERENCES user_identities(address) ON DELETE CASCADE
    )
  ''');
  await createKidsTable(db);
  await createEnglishWordsTable(db);
  await createWordStudyRecordsTable(db);
  await createFocusSessionsTable(db);
}

/// 数据库升级回调
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await createEnglishWordsTable(db);
    await createWordStudyRecordsTable(db);
  }

  if (oldVersion < 3) {
    await db.execute('DROP TABLE IF EXISTS word_study_records');
    await createWordStudyRecordsTable(db);
  }

  if (oldVersion < 4) {
    await db.execute('ALTER TABLE english_words ADD COLUMN spelling TEXT');
  }

  if (oldVersion < 5) {
    await createFocusSessionsTable(db);
  }
}

/// 检查数据库是否存在
Future<bool> isDatabaseExists() async {
  try {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    return await databaseExists(path);
  } catch (e) {
    log('检查数据库是否存在时出错: $e', name: 'db/lib.dart');
    return false;
  }
}

/// 删除数据库
Future<void> delDatabase() async {
  try {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await closeDatabase();
    await deleteDatabase(path);
    log('数据库已删除', name: 'db/lib.dart');
  } catch (e) {
    log('删除数据库时出错: $e', name: 'db/lib.dart');
    rethrow;
  }
}

/// 获取数据库文件路径
Future<String> getDatabasePath() async {
  final dbPath = await getDatabasesPath();
  return join(dbPath, _databaseName);
}

/// 获取数据库信息
Future<Map<String, dynamic>> getDatabaseInfo() async {
  final db = await getDatabase();
  final path = await getDatabasePath();

  return {
    'path': path,
    'version': _databaseVersion,
    'isOpen': db.isOpen,
    'tableCount': await db
        .rawQuery('SELECT COUNT(*) FROM sqlite_master WHERE type="table"')
        .then(
          (value) => value.first['COUNT(*)'] as int,
        ),
  };
}

/// 优化数据库
Future<void> optimizeDatabase() async {
  try {
    final db = await getDatabase();
    await db.execute('PRAGMA optimize');
    await db.execute('VACUUM');
    log('数据库优化完成', name: 'db/lib.dart');
  } catch (e) {
    log('数据库优化失败: $e', name: 'db/lib.dart');
    rethrow;
  }
}

/// 分析数据库
Future<Map<String, dynamic>> analyzeDatabase() async {
  try {
    final db = await getDatabase();
    final result = await db.rawQuery('PRAGMA database_list');
    final pageSize = await db.rawQuery('PRAGMA page_size');
    final pageCount = await db.rawQuery('PRAGMA page_count');
    
    final dbSize = (pageSize.first['page_size'] as int) * (pageCount.first['page_count'] as int);
    
    return {
      'databaseSize': dbSize,
      'pageSize': pageSize.first['page_size'],
      'pageCount': pageCount.first['page_count'],
      'databasePath': result.first['file'],
    };
  } catch (e) {
    log('分析数据库失败: $e', name: 'db/lib.dart');
    rethrow;
  }
}
