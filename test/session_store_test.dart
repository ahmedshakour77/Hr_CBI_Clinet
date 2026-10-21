import 'package:cbi_app/src/auth/session_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.clear();
  }
}

void main() {
  late FakeFlutterSecureStorage fakeStorage;
  late SessionStore sessionStore;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    sessionStore = SessionStore(storage: fakeStorage);
  });

  group('SessionStore', () {
    test('returns null when storage is initially empty', () async {
      expect(await sessionStore.readAccessToken(), isNull);
      expect(await sessionStore.readRefreshToken(), isNull);
      expect(await sessionStore.readMicrosoftRefreshToken(), isNull);
      expect(await sessionStore.readBackendRefreshToken(), isNull);
      expect(await sessionStore.readIdToken(), isNull);
      expect(await sessionStore.readLastEmployeeId(), isNull);
    });

    test('saveSession keeps Microsoft and backend refresh tokens separate', () async {
      await sessionStore.saveSession(
        accessToken: 'test_access_token_123',
        microsoftRefreshToken: 'microsoft_refresh_456',
        backendRefreshToken: 'backend_refresh_999',
        idToken: 'test_id_token_789',
        employeeId: 'EMP-001',
      );

      expect(await sessionStore.readAccessToken(), 'test_access_token_123');
      expect(await sessionStore.readMicrosoftRefreshToken(), 'microsoft_refresh_456');
      expect(await sessionStore.readRefreshToken(), 'microsoft_refresh_456');
      expect(await sessionStore.readBackendRefreshToken(), 'backend_refresh_999');
      expect(await sessionStore.readIdToken(), 'test_id_token_789');
      expect(await sessionStore.readLastEmployeeId(), 'EMP-001');
    });

    test('legacy refreshToken parameter remains Microsoft-token compatible', () async {
      await sessionStore.saveSession(
        accessToken: 'access',
        refreshToken: 'legacy_ms_refresh',
        idToken: 'id_token',
      );
      expect(await sessionStore.readMicrosoftRefreshToken(), 'legacy_ms_refresh');
    });

    test('passkey session clears stale Microsoft tokens but keeps backend refresh', () async {
      await sessionStore.saveSession(
        accessToken: 'ms_access',
        microsoftRefreshToken: 'ms_refresh',
        idToken: 'ms_id',
        employeeId: 'EMP-1',
      );

      await sessionStore.saveSession(
        accessToken: 'passkey_access',
        backendRefreshToken: 'backend_refresh',
        employeeId: 'EMP-1',
        clearMicrosoftTokens: true,
      );

      expect(await sessionStore.readAccessToken(), 'passkey_access');
      expect(await sessionStore.readMicrosoftRefreshToken(), isNull);
      expect(await sessionStore.readIdToken(), isNull);
      expect(await sessionStore.readBackendRefreshToken(), 'backend_refresh');
    });

    test('saveLastEmployeeId persists employee ID independently', () async {
      await sessionStore.saveLastEmployeeId('EMP-999');
      expect(await sessionStore.readLastEmployeeId(), 'EMP-999');
    });

    test('clear wipes all tokens and retains last employee ID', () async {
      await sessionStore.saveSession(
        accessToken: 'access_to_delete',
        microsoftRefreshToken: 'ms_refresh_to_delete',
        backendRefreshToken: 'backend_refresh_to_delete',
        idToken: 'id_to_delete',
        employeeId: 'EMP-KEEP',
      );

      await sessionStore.clear();

      expect(await sessionStore.readAccessToken(), isNull);
      expect(await sessionStore.readMicrosoftRefreshToken(), isNull);
      expect(await sessionStore.readBackendRefreshToken(), isNull);
      expect(await sessionStore.readIdToken(), isNull);
      expect(await sessionStore.readLastEmployeeId(), 'EMP-KEEP');
    });
  });
}
