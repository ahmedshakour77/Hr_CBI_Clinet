import 'dart:convert';

import 'package:cbi_app/src/api/hr_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('authenticated document resources', () {
    test('sends bearer token only to the configured HTTPS API origin', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        expect(request.url.host, 'api.example.test');
        expect(request.headers['authorization'], 'Bearer secret-session');
        return http.Response.bytes([1, 2, 3], 200);
      });
      final client = HrApiClient(
        httpClient: mock,
        baseUrl: Uri.parse('https://api.example.test'),
      );

      final bytes = await client.getAuthenticatedImageBytes(
        'secret-session',
        'https://api.example.test/api/documents/1/front',
      );

      expect(bytes, [1, 2, 3]);
      expect(calls, 1);
    });

    test('refuses an external absolute URL without making a request', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        return http.Response('unexpected', 500);
      });
      final client = HrApiClient(
        httpClient: mock,
        baseUrl: Uri.parse('https://api.example.test'),
      );

      final bytes = await client.getAuthenticatedImageBytes(
        'secret-session',
        'https://attacker.example/steal',
      );

      expect(bytes, isNull);
      expect(calls, 0);
    });

    test('refuses HTTP even when the host matches', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        return http.Response('unexpected', 500);
      });
      final client = HrApiClient(
        httpClient: mock,
        baseUrl: Uri.parse('https://api.example.test'),
      );

      final bytes = await client.getAuthenticatedImageBytes(
        'secret-session',
        'http://api.example.test/api/documents/1/front',
      );

      expect(bytes, isNull);
      expect(calls, 0);
    });
  });

  test('offset pagination uses record offset rather than page number', () async {
    final observedOffsets = <String>[];

    List<Map<String, dynamic>> rows(int start, int count) => List.generate(
          count,
          (i) => {
            'employeeID': 'EMP-${start + i}',
            'name': 'موظف ${start + i}',
          },
        );

    final mock = MockClient((request) async {
      final q = request.url.queryParameters;

      // Disable the two optimistic all-in-one probes.
      if (q['pageSize'] == '5000' || q['limit'] == '5000') {
        return http.Response('{}', 400);
      }

      if (q.containsKey('page')) {
        // page=2 deliberately repeats page 1 so the client tries pageNumber.
        return http.Response(
          jsonEncode({'total': 75, 'data': rows(0, 50)}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (q.containsKey('pageNumber')) {
        // Same deliberate duplication to force the offset strategy.
        return http.Response(
          jsonEncode({'total': 75, 'data': rows(0, 50)}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (q.containsKey('offset')) {
        observedOffsets.add(q['offset']!);
        final offset = int.parse(q['offset']!);
        final data = offset == 0 ? rows(0, 50) : rows(50, 25);
        return http.Response(
          jsonEncode({'total': 75, 'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('not found', 404);
    });

    final client = HrApiClient(
      httpClient: mock,
      baseUrl: Uri.parse('https://api.example.test'),
    );

    final employees = await client.fetchAllEmployees('admin-token');

    expect(employees.length, 75);
    expect(observedOffsets, containsAllInOrder(['0', '50']));
    expect(observedOffsets, isNot(contains('2')));
  });
}
