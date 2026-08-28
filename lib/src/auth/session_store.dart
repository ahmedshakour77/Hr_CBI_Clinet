import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists tokens in the platform keystore.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'cbi.accessToken';
  static const _refreshTokenKey = 'cbi.msRefreshToken';
  static const _idTokenKey = 'cbi.msIdToken';
  static const _lastEmployeeIdKey = 'cbi.lastEmployeeId';

  /// Our own API session token.
  Future<String?> readAccessToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    debugPrint('[SESSION_STORE] Read access token: ${token != null ? "FOUND (${token.length} chars)" : "NONE"}');
    return token;
  }

  /// Microsoft refresh token, used to renew without a fresh interactive login.
  Future<String?> readRefreshToken() async {
    final token = await _storage.read(key: _refreshTokenKey);
    debugPrint('[SESSION_STORE] Read refresh token: ${token != null ? "FOUND (${token.length} chars)" : "NONE"}');
    return token;
  }

  /// Kept only so sign-out can pass `id_token_hint` to the Entra end-session
  /// endpoint, which is what actually clears the browser session.
  Future<String?> readIdToken() async {
    final token = await _storage.read(key: _idTokenKey);
    debugPrint('[SESSION_STORE] Read ID token: ${token != null ? "FOUND (${token.length} chars)" : "NONE"}');
    return token;
  }

  /// The employee ID saved from the most recent session for quick passkey login.
  Future<String?> readLastEmployeeId() async {
    final empId = await _storage.read(key: _lastEmployeeIdKey);
    debugPrint('[SESSION_STORE] Read last employee ID: $empId');
    return empId;
  }

  Future<void> saveLastEmployeeId(String employeeId) async {
    await _storage.write(key: _lastEmployeeIdKey, value: employeeId);
  }

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    String? idToken,
    String? employeeId,
  }) async {
    debugPrint('[SESSION_STORE] Persisting session tokens to secure storage...');
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    if (idToken != null) {
      await _storage.write(key: _idTokenKey, value: idToken);
    }
    if (employeeId != null) {
      await _storage.write(key: _lastEmployeeIdKey, value: employeeId);
    }
    debugPrint('[SESSION_STORE] Session tokens saved cleanly!');
  }

  Future<void> clear() async {
    debugPrint('[SESSION_STORE] Clearing all persisted session tokens...');
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _idTokenKey);
  }
}
