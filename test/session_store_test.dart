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
      expect(await sessionStore.readIdToken(), isNull);
      expect(await sessionStore.readLastEmployeeId(), isNull);
    });

    test('saveSession correctly writes all token fields', () async {
      await sessionStore.saveSession(
        accessToken: 'test_access_token_123',
        refreshToken: 'test_refresh_token_456',
        idToken: 'test_id_token_789',
        employeeId: 'EMP-001',
      );

      expect(await sessionStore.readAccessToken(), 'test_access_token_123');
      expect(await sessionStore.readRefreshToken(), 'test_refresh_token_456');
      expect(await sessionStore.readIdToken(), 'test_id_token_789');
      expect(await sessionStore.readLastEmployeeId(), 'EMP-001');
    });

    test('saveLastEmployeeId persists employee ID independently', () async {
      await sessionStore.saveLastEmployeeId('EMP-999');
      expect(await sessionStore.readLastEmployeeId(), 'EMP-999');
    });

    test('clear wipes access, refresh, and id tokens', () async {
      await sessionStore.saveSession(
        accessToken: 'access_to_delete',
        refreshToken: 'refresh_to_delete',
        idToken: 'id_to_delete',
        employeeId: 'EMP-KEEP',
      );

      await sessionStore.clear();

      expect(await sessionStore.readAccessToken(), isNull);
      expect(await sessionStore.readRefreshToken(), isNull);
      expect(await sessionStore.readIdToken(), isNull);
      // Last employee ID is intentionally retained for quick passkey login
      expect(await sessionStore.readLastEmployeeId(), 'EMP-KEEP');
    });
  });
}
