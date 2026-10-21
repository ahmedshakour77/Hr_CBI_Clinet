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
  static const _microsoftRefreshTokenKey = 'cbi.msRefreshToken';
  static const _backendRefreshTokenKey = 'cbi.backendRefreshToken';
  static const _idTokenKey = 'cbi.msIdToken';
  static const _lastEmployeeIdKey = 'cbi.lastEmployeeId';

  Future<String?> readAccessToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    debugPrint('[SESSION_STORE] Read access token: ${token != null ? "FOUND (${token.length} chars)" : "NONE"}');
    return token;
  }

  /// Microsoft OAuth refresh token only. Never store backend refresh tokens here.
  Future<String?> readRefreshToken() => readMicrosoftRefreshToken();

  Future<String?> readMicrosoftRefreshToken() async {
    final token = await _storage.read(key: _microsoftRefreshTokenKey);
    debugPrint('[SESSION_STORE] Read Microsoft refresh token: ${token != null ? "FOUND (${token.length} chars)" : "NONE"}');
    return token;
  }

  Future<String?> readBackendRefreshToken() async {
    final token = await _storage.read(key: _backendRefreshTokenKey);
    debugPrint('[SESSION_STORE] Read backend refresh token: ${token != null ? "FOUND (${token.length} chars)" : "NONE"}');
    return token;
  }

  Future<String?> readIdToken() async {
    final token = await _storage.read(key: _idTokenKey);
    debugPrint('[SESSION_STORE] Read ID token: ${token != null ? "FOUND (${token.length} chars)" : "NONE"}');
    return token;
  }

  Future<String?> readLastEmployeeId() async {
    final empId = await _storage.read(key: _lastEmployeeIdKey);
    debugPrint('[SESSION_STORE] Read last employee ID: $empId');
    return empId;
  }

  Future<void> saveLastEmployeeId(String employeeId) async {
    await _storage.write(key: _lastEmployeeIdKey, value: employeeId);
  }

  /// Saves an app session and explicitly controls the two refresh-token domains.
  ///
  /// [refreshToken] remains as a backwards-compatible alias for Microsoft's
  /// refresh token. New code should use [microsoftRefreshToken].
  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    String? microsoftRefreshToken,
    String? backendRefreshToken,
    String? idToken,
    String? employeeId,
    bool clearMicrosoftTokens = false,
  }) async {
    debugPrint('[SESSION_STORE] Persisting session tokens to secure storage...');
    await _storage.write(key: _accessTokenKey, value: accessToken);

    final msRefresh = microsoftRefreshToken ?? refreshToken;
    if (clearMicrosoftTokens) {
      await _storage.delete(key: _microsoftRefreshTokenKey);
      await _storage.delete(key: _idTokenKey);
    } else {
      if (msRefresh != null) {
        await _storage.write(key: _microsoftRefreshTokenKey, value: msRefresh);
      }
      if (idToken != null) {
        await _storage.write(key: _idTokenKey, value: idToken);
      }
    }

    if (backendRefreshToken != null) {
      await _storage.write(key: _backendRefreshTokenKey, value: backendRefreshToken);
    } else {
      await _storage.delete(key: _backendRefreshTokenKey);
    }

    if (employeeId != null) {
      await _storage.write(key: _lastEmployeeIdKey, value: employeeId);
    }
    debugPrint('[SESSION_STORE] Session tokens saved cleanly!');
  }

  Future<void> clear() async {
    debugPrint('[SESSION_STORE] Clearing all persisted session tokens...');
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _microsoftRefreshTokenKey);
    await _storage.delete(key: _backendRefreshTokenKey);
    await _storage.delete(key: _idTokenKey);
  }
}
