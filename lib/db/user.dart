import 'dart:convert';
import 'dart:developer';
import 'package:gowhymo/ui/lib.dart';
import 'package:gowhymo/theme/app_theme.dart';
import 'package:gowhymo/constants/app_constants.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib.dart' as db_lib;

/// 用户身份标识相关 Key 常量 - 必须与 main.dart 保持一致
class UserIdentityKeys {
  static const String address = 'userIdentityAddress';
  static const String publicKey = 'userIdentityPublicKey';
  static const String privateKey = 'userIdentityPrivateKey';
}

/// 安全存储实例 - 用于读取加密存储的私钥
/// 必须与 main.dart 中的配置保持一致
const FlutterSecureStorage secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

class User {
  final String id; // UserIdentity address，最终裁定权在私钥
  final String? phone;
  final String? email;
  final String? password;
  final String? nickname;
  final DateTime? lastLoginAt;
  final DateTime createdAt; // 创建时间戳
  final DateTime updatedAt; // 更新时间戳

  User({
    required this.id,
    this.phone,
    this.email,
    this.password,
    this.nickname,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从 JSON 构造
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    password: json['password'] as String?,
    nickname: json['nickname'] as String?,
    lastLoginAt: json['last_login_at'] == null
        ? null
        : DateTime.parse(json['last_login_at'] as String),
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
  );

  /// 转 JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'email': email,
    'password': password,
    'nickname': nickname,
    'last_login_at': lastLoginAt?.toIso8601String(),
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };
}

/// 用户表操作类
class UserDao {
  static const String _tableName = 'users';
  static Database? _db;

  /// 获取数据库实例 - 使用共享的数据库实例
  static Future<Database> get _database async {
    return await db_lib.getDatabase();
  }

  /// 新增或替换用户
  static Future<int> insertOrReplace(User user) async {
    final db = await _database;
    final rowsAffected = await db.insert(
      _tableName,
      user.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return rowsAffected;
  }

  /// 根据 id 查询用户
  static Future<User?> getById(String id) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return User.fromJson(maps.first);
  }

  ///根据最后登录时间查询用户
  static Future<User?> getByLastLoginAt() async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      orderBy: 'last_login_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return User.fromJson(maps.first);
  }

  /// 查询全部用户
  static Future<List<User>> getAll() async {
    final db = await _database;
    final maps = await db.query(_tableName);
    return maps.map((json) => User.fromJson(json)).toList();
  }

  /// 更新用户
  static Future<void> update(User user) async {
    final db = await _database;
    await db.update(
      _tableName,
      user.toJson(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /// 删除用户
  static Future<void> delete(String id) async {
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

Future<bool> isUserIdentityExist(String address) async {
  final db = await db_lib.getDatabase();
  final count = Sqflite.firstIntValue(
    await db.rawQuery(
      'SELECT COUNT(*) FROM user_identities WHERE address = ?',
      [address],
    ),
  );
  return count != 0;
}

/// 保存用户身份标识数据
Future<void> saveUserIdentityData(Map<String, String> identityData) async {
  final db = await db_lib.getDatabase();
  final now = DateTime.now().millisecondsSinceEpoch;

  await db.insert('user_identities', {
    'address': identityData['address'],
    'private_key': identityData['privateKey'],
    'public_key': identityData['publicKey'],
    'created_at': now,
    'updated_at': now,
  }, conflictAlgorithm: ConflictAlgorithm.fail);
}

/// 获取第一个用户身份标识数据（通常一个手机只有一个）
Future<Map<String, String>?> getFirstUserIdentityData() async {
  final db = await db_lib.getDatabase();

  final List<Map<String, dynamic>> maps = await db.query(
    'user_identities',
    limit: 1,
  );

  if (maps.isEmpty) return null;

  final map = maps.first;
  return {
    'address': map['address'] as String,
    'privateKey': map['private_key'] as String,
    'publicKey': map['public_key'] as String,
  };
}

/// 获取所有用户身份标识数据
Future<List<Map<String, String>>> getAllUserIdentityData() async {
  final db = await db_lib.getDatabase();

  final List<Map<String, dynamic>> maps = await db.query('user_identities');

  if (maps.isEmpty) return [];

  return maps
      .map(
        (map) => {
          'address': map['address'] as String,
          'privateKey': map['private_key'] as String,
          'publicKey': map['public_key'] as String,
        },
      )
      .toList();
}

Future<User> createOrUpdateUser(String nickname) async {
  try {
    // 1. 获取身份标识
    // 地址和公钥从 SharedPreferences 读取（非敏感信息）
    final address = prefs.getString(UserIdentityKeys.address) ?? '';
    final publicKey = prefs.getString(UserIdentityKeys.publicKey) ?? '';
    // 私钥从安全存储读取（敏感信息，使用加密存储）
    final privateKey = await secureStorage.read(key: UserIdentityKeys.privateKey) ?? '';

    if (address.isEmpty || privateKey.isEmpty || publicKey.isEmpty) {
      throw Exception('用户身份标识地址、私钥或公钥为空');
    }
    log(
      '注册用户: $nickname, 地址: $address, 私钥: $privateKey, 公钥: $publicKey',
      name: 'db/user.dart',
    );
    // 2. 创建用户，设置创建时间和更新时间
    final now = DateTime.now();
    final user = User(
      id: address,
      nickname: nickname,
      createdAt: now,
      updatedAt: now,
    );

    //3. 先保存身份标识到本地数据库（外键必须先存在）
    final isExist = await isUserIdentityExist(address);
    if (isExist) {
      log('用户身份标识已存在: $address', name: 'db/user.dart');
    } else {
      await saveUserIdentityData({
        'address': address,
        'privateKey': privateKey,
        'publicKey': publicKey,
      });
    }
    // 4. 再保存用户到本地数据库
    final rowsAffected = await UserDao.insertOrReplace(user);
    if (rowsAffected == 0) {
      throw Exception('未影响到数据库行');
    }
    return user;
  } catch (e) {
    log('创建或更新用户失败: $e', name: 'db/user.dart');
    rethrow;
  }
}
