import 'dart:convert';
import 'package:cbi_app/src/api/hr_api_client.dart';
import 'package:cbi_app/src/auth/auth_controller.dart';
import 'package:cbi_app/src/auth/session_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFlutterSecureStorage fakeStorage;
  late SessionStore sessionStore;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    sessionStore = SessionStore(storage: fakeStorage);
  });

  group('AuthController', () {
    test('initial status is restoring', () {
      final auth = AuthController(sessionStore: sessionStore);
      expect(auth.status, AuthStatus.restoring);
      expect(auth.profile, isNull);
      expect(auth.busy, isFalse);
    });

    test('restore with no stored token transitions to signedOut', () async {
      final auth = AuthController(sessionStore: sessionStore);
      await auth.restore();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.profile, isNull);
    });

    test('restore with valid stored token restores profile and signedIn state', () async {
      await sessionStore.saveSession(
        accessToken: 'valid_session_token',
        employeeId: 'CBI-007',
      );

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/employees/me') {
          return http.Response(
            jsonEncode({
              'employeeID': 'CBI-007',
              'name': 'سارة أحمد',
              'jobTitle': 'مدقق حسابات رئيسي',
              'formation': 'دائرة التدقيق والرقابة',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/auth/passkey/my-passkeys') {
          return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/services') {
          return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = HrApiClient(httpClient: mockClient);
      final auth = AuthController(
        api: apiClient,
        sessionStore: sessionStore,
      );

      await auth.restore();

      expect(auth.status, AuthStatus.signedIn);
      expect(auth.profile?.employeeID, 'CBI-007');
      expect(auth.profile?.name, 'سارة أحمد');
    });

    test('restore with invalid stored token falls back to signedOut', () async {
      await sessionStore.saveSession(
        accessToken: 'expired_or_revoked_token',
      );

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'invalid_session'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = HrApiClient(httpClient: mockClient);
      final auth = AuthController(
        api: apiClient,
        sessionStore: sessionStore,
      );

      await auth.restore();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.profile, isNull);
    });

    test('signOut clears stored session and resets status to signedOut', () async {
      await sessionStore.saveSession(
        accessToken: 'token_to_clear',
        employeeId: 'EMP-1',
      );

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'employeeID': 'EMP-1',
            'name': 'موظف تجريبي',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = HrApiClient(httpClient: mockClient);
      final auth = AuthController(
        api: apiClient,
        sessionStore: sessionStore,
      );

      await auth.restore();
      expect(auth.status, AuthStatus.signedIn);

      await auth.signOut();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.profile, isNull);
      expect(await sessionStore.readAccessToken(), isNull);
    });

    test('deletePasskey calls api and reloads passkeys list', () async {
      await sessionStore.saveSession(
        accessToken: 'active_token',
        employeeId: 'EMP-PASS',
      );

      var deleteEndpointCalled = false;
      var getPasskeysCallCount = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/employees/me') {
          return http.Response(
            jsonEncode({'employeeID': 'EMP-PASS', 'name': 'علي حسن'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/auth/passkey/my-passkeys') {
          getPasskeysCallCount++;
          if (deleteEndpointCalled) {
            return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
          }
          return http.Response(
            jsonEncode([{'id': 'key_123', 'deviceName': 'Galaxy S24'}]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'DELETE' && request.url.path == '/api/auth/passkey/key_123') {
          deleteEndpointCalled = true;
          return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('OK', 200, headers: {'content-type': 'application/json'});
      });

      final apiClient = HrApiClient(httpClient: mockClient);
      final auth = AuthController(
        api: apiClient,
        sessionStore: sessionStore,
      );

      await auth.restore();
      expect(auth.myPasskeys.length, 1);

      await auth.deletePasskey('key_123');

      expect(deleteEndpointCalled, isTrue);
      expect(auth.myPasskeys, isEmpty);
      expect(getPasskeysCallCount, 2);
    });
  });
}
