import 'dart:convert';
import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import 'lib.dart' as db_lib;

enum AvatarType { none, imageFile, randomAvatar }

Future<void> createKidsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS kids (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      birth_date TEXT,
      gender TEXT,
      avatar_type TEXT NOT NULL,
      avatar_image_data TEXT,
      description TEXT,
      created_by TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      metadata TEXT
    )
  ''');
}

class Kid {
  final int id;
  final String name;
  final DateTime? birthDate;
  final String? gender;
  final AvatarType? avatarType;
  final String? avatarImageData;
  final String? description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  const Kid({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.avatarType,
    required this.avatarImageData,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
  });

  /// 从JSON创建Kid实例
  factory Kid.fromJson(Map<String, dynamic> json) {
    return Kid(
      id: json['id'] as int,
      name: json['name'] as String,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      gender: json['gender'] as String?,
      avatarType: AvatarType.values.firstWhere(
        (e) => e.name == json['avatar_type'] as String?,
        orElse: () => AvatarType.imageFile,
      ),
      avatarImageData: json['avatar_image_data'] as String?,
      description: json['description'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      metadata: json['metadata'] != null
          ? _parseMetadata(json['metadata'])
          : null,
    );
  }

  /// 将Kid实例转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
      'avatar_type': avatarType?.name,
      'avatar_image_data': avatarImageData,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    };
  }

  static Map<String, dynamic> _parseMetadata(dynamic metadata) {
    if (metadata is Map<String, dynamic>) {
      return metadata;
    }
    if (metadata is String) {
      try {
        final decoded = jsonDecode(metadata);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        final Map<String, dynamic> result = {};
        final cleaned = metadata.substring(1, metadata.length - 1);
        if (cleaned.isNotEmpty) {
          for (final pair in cleaned.split(',')) {
            final parts = pair.split('=');
            if (parts.length == 2) {
              final key = parts[0].trim();
              final value = parts[1].trim();
              if (value.startsWith('"') && value.endsWith('"')) {
                result[key] = value.substring(1, value.length - 1);
              } else {
                final intVal = int.tryParse(value);
                if (intVal != null) {
                  result[key] = intVal;
                } else {
                  result[key] = value;
                }
              }
            }
          }
        }
        return result;
      }
    }
    return {};
  }

  /// 获取Kid的所有者
  String get ownerId => createdBy;

  /// 创建Kid的拷贝，可选择性地更新某些字段
  Kid copyWith({
    int? id,
    String? name,
    DateTime? birthDate,
    String? gender,
    String? avatarUrl,
    String? description,
    int? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Kid(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      avatarType: avatarType,
      avatarImageData: avatarImageData,
      description: description ?? this.description,
      createdBy: createdBy?.toString() ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Kid表操作类
class KidDao {
  static const String _tableName = 'kids';
  static Database? _db;

  /// 获取数据库实例 - 使用共享的数据库实例
  static Future<Database> get _database async {
    return await db_lib.getDatabase();
  }

  /// 新增或替换孩子记录
  static Future<int> insertOrReplace(Kid kid) async {
    final db = await _database;
    return await db.insert(
      _tableName,
      kid.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> insert(Kid kid) async {
    final db = await _database;
    // 创建新的Map，移除id字段让数据库自动生成
    final kidData = Map<String, dynamic>.from(kid.toJson());
    kidData.remove('id');
    
    return await db.insert(
      _tableName,
      kidData,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 根据id查询孩子
  static Future<Kid?> getById(int id) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Kid.fromJson(maps.first);
  }

  /// 根据创建者查询所有孩子
  static Future<List<Kid>> getByCreatedBy(int createdBy) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'created_by = ?',
      whereArgs: [createdBy],
      orderBy: 'created_at DESC',
    );
    return maps.map((json) => Kid.fromJson(json)).toList();
  }

  /// 查询全部孩子
  static Future<List<Kid>> getAll() async {
    final db = await _database;
    final maps = await db.query(_tableName, orderBy: 'created_at DESC');
    return maps.map((json) => Kid.fromJson(json)).toList();
  }

  /// 更新孩子信息
  static Future<void> update(Kid kid) async {
    final db = await _database;
    await db.update(
      _tableName,
      kid.toJson(),
      where: 'id = ?',
      whereArgs: [kid.id],
    );
  }

  /// 删除孩子
  static Future<void> delete(int id) async {
    final db = await _database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// 关闭数据库
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}

/// 创建新的孩子记录
Future<Kid> createKid({
  required String name,
  required int createdBy,
  DateTime? birthDate,
  String? gender,
  String? avatarImageData,
  String? description,
  Map<String, dynamic>? metadata,
}) async {
  try {
    final now = DateTime.now();
    final kid = Kid(
      id: 0, // 插入时ID为0，数据库会自动生成
      name: name,
      birthDate: birthDate,
      gender: gender,
      avatarType: AvatarType.imageFile,
      avatarImageData: avatarImageData,
      description: description,
      createdBy: createdBy.toString(),
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );

    // 保存到本地数据库
    await KidDao.insertOrReplace(kid);

    return kid;
  } catch (e) {
    log('创建孩子失败: $e', name: 'db/kid.dart');
    rethrow;
  }
}