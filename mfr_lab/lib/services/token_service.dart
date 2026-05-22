// Secure JWT storage + validity checks (flutter_secure_storage + jwt_decoder).
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../constants.dart';

class TokenService {
  TokenService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  String? _accessCache;
  String? _refreshCache;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessCache = accessToken;
    _refreshCache = refreshToken;
    await _storage.write(key: StorageKeys.accessToken, value: accessToken);
    await _storage.write(key: StorageKeys.refreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    _accessCache ??= await _storage.read(key: StorageKeys.accessToken);
    return _accessCache;
  }

  Future<String?> getRefreshToken() async {
    _refreshCache ??= await _storage.read(key: StorageKeys.refreshToken);
    return _refreshCache;
  }

  Future<void> clear() async {
    _accessCache = null;
    _refreshCache = null;
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
  }

  /// True if a refresh token exists and is not itself expired.
  Future<bool> hasUsableSession() async {
    final refresh = await getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      return !JwtDecoder.isExpired(refresh);
    } catch (_) {
      return false;
    }
  }

  /// True if the current access token is missing or expired (needs refresh).
  Future<bool> isAccessExpired() async {
    final access = await getAccessToken();
    if (access == null || access.isEmpty) return true;
    try {
      return JwtDecoder.isExpired(access);
    } catch (_) {
      return true;
    }
  }
}
