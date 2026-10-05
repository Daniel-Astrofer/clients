import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:kerosene/core/security/kerosene_secure_prefix.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  String _p(String key) => '${keroseneSecurePrefix()}$key';

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              lOptions: LinuxOptions(),
              wOptions: WindowsOptions(),
            );

  IOSOptions _iosOptions() => const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  IOSOptions _legacyIOSOptions() => const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      );

  AndroidOptions _androidOptions() => const AndroidOptions(
        storageNamespace: 'kerosene_secure_storage',
      );

  AndroidOptions _legacyAndroidOptions() => const AndroidOptions();

  LinuxOptions _linuxOptions() => const LinuxOptions();

  WindowsOptions _windowsOptions() => const WindowsOptions();

  /// Save a value securely
  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(
        key: _p(key),
        value: value,
        iOptions: _iosOptions(),
        aOptions: _androidOptions(),
        lOptions: _linuxOptions(),
        wOptions: _windowsOptions(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureStorageService: write failed: $e');
      }
      rethrow;
    }
  }

  /// Read a value securely
  Future<String?> read({required String key}) async {
    try {
      final value = await _storage.read(
        key: _p(key),
        iOptions: _iosOptions(),
        aOptions: _androidOptions(),
        lOptions: _linuxOptions(),
        wOptions: _windowsOptions(),
      );
      if (value != null) {
        return value;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureStorageService: read failed: $e');
      }
    }

    return _readLegacy(key);
  }

  /// Delete a value securely
  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(
        key: _p(key),
        iOptions: _iosOptions(),
        aOptions: _androidOptions(),
        lOptions: _linuxOptions(),
        wOptions: _windowsOptions(),
      );
      await _storage.delete(
        key: _p(key),
        iOptions: _legacyIOSOptions(),
        aOptions: _legacyAndroidOptions(),
        lOptions: _linuxOptions(),
        wOptions: _windowsOptions(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureStorageService: delete failed: $e');
      }
      rethrow;
    }
  }

  /// Delete all values
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll(
        iOptions: _iosOptions(),
        aOptions: _androidOptions(),
        lOptions: _linuxOptions(),
        wOptions: _windowsOptions(),
      );
      await _storage.deleteAll(
        iOptions: _legacyIOSOptions(),
        aOptions: _legacyAndroidOptions(),
        lOptions: _linuxOptions(),
        wOptions: _windowsOptions(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureStorageService: deleteAll failed: $e');
      }
      rethrow;
    }
  }

  Future<String?> _readLegacy(String key) async {
    try {
      final value = await _storage.read(
        key: _p(key),
        iOptions: _legacyIOSOptions(),
        aOptions: _legacyAndroidOptions(),
        lOptions: _linuxOptions(),
        wOptions: _windowsOptions(),
      );
      if (value == null) {
        return null;
      }

      await write(key: key, value: value);
      await _storage.delete(
        key: _p(key),
        iOptions: _legacyIOSOptions(),
        aOptions: _legacyAndroidOptions(),
        lOptions: _linuxOptions(),
        wOptions: _windowsOptions(),
      );
      return value;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureStorageService: legacy read failed: $e');
      }
      return null;
    }
  }
}
