import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gowhymo/db/lib.dart';
import 'package:gowhymo/db/user.dart';
import 'package:gowhymo/rust/api/user_identity.dart';
import 'package:gowhymo/rust/frb_generated.dart';
import 'package:gowhymo/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppInitializer {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await _initRust();
    await _initDatabase();
    await _initPrefs();
  }

  static Future<void> _initRust() async {
    await RustLib.init();
  }

  static Future<void> _initDatabase() async {
    await initDatabase();
  }

  static Future<void> _initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    await _initUserIdentity();
  }

  static Future<void> _initUserIdentity() async {
    const addressKey = 'userIdentityAddress';
    const publicKeyKey = 'userIdentityPublicKey';
    const privateKeyKey = 'userIdentityPrivateKey';

    final address = prefs.getString(addressKey);
    final publicKey = prefs.getString(publicKeyKey);
    final privateKey = await _secureStorage.read(key: privateKeyKey);

    if (address == null || publicKey == null || privateKey == null) {
      final identity = generateUserIdentity();
      final newAddress = identity.address;
      final newPublicKey = identity.publicKey;
      final newPrivateKey = identity.privateKey;

      await prefs.setString(addressKey, newAddress);
      await prefs.setString(publicKeyKey, newPublicKey);
      await _secureStorage.write(key: privateKeyKey, value: newPrivateKey);

      final isExist = await isUserIdentityExist(newAddress);
      if (!isExist) {
        await saveUserIdentityData({
          'address': newAddress,
          'privateKey': newPrivateKey,
          'publicKey': newPublicKey,
        });
      }
    }
  }
}
