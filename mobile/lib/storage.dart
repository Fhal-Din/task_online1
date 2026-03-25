import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStorage {
  static const _tokenKey = 'access_token';
  final FlutterSecureStorage _storage;

  AppStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) => _storage.write(
        key: _tokenKey,
        value: token,
      );

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}

