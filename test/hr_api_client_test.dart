import 'dart:convert';
import 'package:cbi_app/src/api/hr_api_client.dart';
import 'package:cbi_app/src/auth/auth_exception.dart';
import 'package:cbi_app/src/id_reader/domain/entities/id_card_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('HrApiClient', () {
    test('exchangeMicrosoftIdToken parses accessToken on success', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/auth/microsoft-login');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['idToken'], 'valid_id_token');
        return http.Response(
          jsonEncode({
            'accessToken': 'jwt_access_token_abc',
            'tokenType': 'Bearer',
            'expiresIn': 3600,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = HrApiClient(httpClient: mockClient);
      final response = await client.exchangeMicrosoftIdToken(
        idToken: 'valid_id_token',
        email: 'user@cbi.gov.iq',
      );

      expect(response.accessToken, 'jwt_access_token_abc');
      expect(response.tokenType, 'Bearer');
      expect(response.expiresIn, 3600);
    });

    test('fetchProfile returns EmployeeProfile on 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/employees/me');
        expect(request.headers['authorization'], 'Bearer test_token');
        return http.Response(
          jsonEncode({
            'employeeID': 'CBI-101',
            'name': 'أحمد محمد',
            'jobTitle': 'مدير قسم تقنية المعلومات',
            'formation': 'دائرة العمليات المالية',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = HrApiClient(httpClient: mockClient);
      final profile = await client.fetchProfile('test_token');

      expect(profile.employeeID, 'CBI-101');
      expect(profile.name, 'أحمد محمد');
      expect(profile.jobTitle, 'مدير قسم تقنية المعلومات');
      expect(profile.formation, 'دائرة العمليات المالية');
    });

    test('fetchProfile throws AuthException with friendly message on 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'user_not_found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = HrApiClient(httpClient: mockClient);

      expect(
        () => client.fetchProfile('unknown_token'),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('عذراً، هذا الحساب غير مربوط بملف موظف في النظام'),
        )),
      );
    });

    test('fetchProfile throws AuthException on 401 Unauthorized', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'unauthorized'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = HrApiClient(httpClient: mockClient);

      expect(
        () => client.fetchProfile('bad_token'),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('غير مصرح'),
        )),
      );
    });

    test('passkeyRegistrationOptions sends deviceName and returns payload', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/auth/passkey/register/options');
        expect(request.headers['authorization'], 'Bearer session_token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['deviceName'], 'Pixel 8');
        return http.Response(
          jsonEncode({'challenge': 'test_reg_challenge', 'rp': {'id': 'cbi.iq'}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = HrApiClient(httpClient: mockClient);
      final options = await client.passkeyRegistrationOptions(
        sessionToken: 'session_token',
        deviceName: 'Pixel 8',
      );

      expect(options['challenge'], 'test_reg_challenge');
    });

    test('getMyPasskeys (Endpoint 3.1) returns list of registered passkeys', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/auth/passkey/my-passkeys');
        expect(request.method, 'GET');
        return http.Response(
          jsonEncode([
            {'id': 'cred_1', 'deviceName': 'iPhone 15', 'createdAt': '2026-01-01'},
            {'id': 'cred_2', 'deviceName': 'MacBook Pro', 'createdAt': '2026-02-01'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = HrApiClient(httpClient: mockClient);
      final passkeys = await client.getMyPasskeys('valid_token');

      expect(passkeys.length, 2);
      expect(passkeys.first['id'], 'cred_1');
      expect(passkeys.first['deviceName'], 'iPhone 15');
    });

    test('deletePasskey (Endpoint 3.2) sends HTTP DELETE with credentials for freeze', () async {
      var deleteCalled = false;
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/auth/passkey/cred_to_delete_99');
        expect(request.url.queryParameters.isEmpty, isTrue);
        expect(request.method, 'DELETE');
        expect(request.headers['authorization'], 'Bearer valid_token');
        deleteCalled = true;
        return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
      });

      final client = HrApiClient(httpClient: mockClient);
      await client.deletePasskey(sessionToken: 'valid_token', passkeyId: 'cred_to_delete_99');

      expect(deleteCalled, isTrue);
    });

    test('deletePasskey sends HTTP DELETE with ?permanent=true when permanent is true', () async {
      var deleteCalled = false;
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/auth/passkey/cred_to_delete_99');
        expect(request.url.queryParameters['permanent'], 'true');
        expect(request.method, 'DELETE');
        expect(request.headers['authorization'], 'Bearer valid_token');
        deleteCalled = true;
        return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
      });

      final client = HrApiClient(httpClient: mockClient);
      await client.deletePasskey(sessionToken: 'valid_token', passkeyId: 'cred_to_delete_99', permanent: true);

      expect(deleteCalled, isTrue);
    });

    test('deletePasskey throws AuthException on HTTP 400+', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'not_found'}), 404, headers: {'content-type': 'application/json'});
      });

      final client = HrApiClient(httpClient: mockClient);
      expect(
        () => client.deletePasskey(sessionToken: 'valid_token', passkeyId: 'non_existent_key'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('فشل تجميد/تعطيل مفتاح المرور'))),
      );
      expect(
        () => client.deletePasskey(sessionToken: 'valid_token', passkeyId: 'non_existent_key', permanent: true),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('فشل حذف ومحو مفتاح المرور'))),
      );
    });

    test('updateMyNationalCard sends POST /api/employees/me/national-card', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/employees/me/national-card');
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer test_token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['documentNumber'], 'A12345678');
        expect(body['fullNameAr'], 'علي حسن');
        expect(body['gender'], 'ذكر');
        expect(body['nationality'], 'عراقي');
        return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
      });

      final client = HrApiClient(httpClient: mockClient);
      const card = IdCardModel(
        documentNumber: 'A12345678',
        documentType: 'I',
        issuingCountry: 'IRQ',
        nationality: 'IRQ',
        surname: 'Hassan',
        givenNames: 'Ali',
        gender: 'M',
        fullNameArabic: 'علي حسن',
      );

      final res = await client.updateMyNationalCard(sessionToken: 'test_token', idCard: card);
      expect(res['success'], isTrue);
    });

    test('updateEmployeeNationalCard sends POST /api/employees/{id}/national-card for admin', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/employees/1041001/national-card');
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer admin_token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['documentNumber'], 'A99887766');
        return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
      });

      final client = HrApiClient(httpClient: mockClient);
      const card = IdCardModel(
        documentNumber: 'A99887766',
        documentType: 'I',
        issuingCountry: 'IRQ',
        nationality: 'IRQ',
        surname: 'Salim',
        givenNames: 'Falah',
        gender: 'M',
      );

      final res = await client.updateEmployeeNationalCard(
        sessionToken: 'admin_token',
        employeeIdOrNumber: '1041001',
        idCard: card,
      );
      expect(res['success'], isTrue);
    });

    test('updateEmployeeNationalCard throws AuthException on 403 Forbidden for non-admin', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'forbidden', 'message': 'Forbidden'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = HrApiClient(httpClient: mockClient);
      const card = IdCardModel(
        documentNumber: 'B11223344',
        documentType: 'I',
        issuingCountry: 'IRQ',
        nationality: 'IRQ',
        surname: 'Other',
        givenNames: 'User',
        gender: 'M',
      );

      expect(
        () => client.updateEmployeeNationalCard(
          sessionToken: 'regular_employee_token',
          employeeIdOrNumber: '999999',
          idCard: card,
        ),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('403 Forbidden'))),
      );
    });

    test('fetchAllEmployees sends GET /api/employees and returns parsed list', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/employees');
        expect(request.headers['authorization'], 'Bearer admin_token');
        return http.Response(
          jsonEncode([
            {'employeeID': '101', 'name': 'أحمد فالح', 'jobTitle': 'مهندس برمجيات'},
            {'employeeID': '102', 'name': 'سارة كريم', 'jobTitle': 'محاسب رئيسي'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = HrApiClient(httpClient: mockClient);
      final employees = await client.fetchAllEmployees('admin_token');
      expect(employees.length, 2);
      expect(employees.first.employeeID, '101');
      expect(employees.first.name, 'أحمد فالح');
      expect(employees.last.employeeID, '102');
    });

    test('fetchAllEmployees automatically paginates and fetches all employees across multiple pages', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        final page = request.url.queryParameters['page'] ?? '1';
        if (page == '1' || requestCount == 1) {
          // Page 1: returns 50 employees
          final list50 = List.generate(
            50,
            (i) => {'employeeID': 'EMP-$i', 'name': 'موظف $i', 'formation': 'دائرة العمليات'},
          );
          return http.Response(
            jsonEncode({'total': 75, 'data': list50}),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else {
          // Page 2: returns remaining 25 employees
          final list25 = List.generate(
            25,
            (i) => {'employeeID': 'EMP-${i + 50}', 'name': 'موظف ${i + 50}', 'formation': 'دائرة الإصدار'},
          );
          return http.Response(
            jsonEncode({'total': 75, 'data': list25}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
      });

      final client = HrApiClient(httpClient: mockClient);
      final progressUpdates = <int>[];
      final employees = await client.fetchAllEmployees(
        'admin_token',
        onProgress: (loaded, total) => progressUpdates.add(loaded),
      );

      expect(employees.length, 75);
      expect(employees.first.employeeID, 'EMP-0');
      expect(employees.last.employeeID, 'EMP-74');
      expect(progressUpdates, contains(50));
      expect(progressUpdates.last, 75);
    });
  });
}
