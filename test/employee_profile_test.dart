import 'package:cbi_app/src/models/employee_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wholeYearsSince', () {
    test('counts a completed year', () {
      expect(
        EmployeeProfile.wholeYearsSince(
          DateTime(2020, 3, 10),
          DateTime(2026, 3, 10),
        ),
        6,
      );
    });

    test('does not count a year until the anniversary has passed', () {
      expect(
        EmployeeProfile.wholeYearsSince(
          DateTime(2020, 3, 10),
          DateTime(2026, 3, 9),
        ),
        5,
      );
    });

    test('handles an anniversary later in the same month', () {
      expect(
        EmployeeProfile.wholeYearsSince(
          DateTime(2020, 12, 31),
          DateTime(2026, 1, 1),
        ),
        5,
      );
    });

    test('returns null for a future date', () {
      expect(
        EmployeeProfile.wholeYearsSince(
          DateTime(2030, 1, 1),
          DateTime(2026, 1, 1),
        ),
        isNull,
      );
    });

    test('returns null when no date is on file', () {
      expect(EmployeeProfile.wholeYearsSince(null, DateTime(2026, 1, 1)), isNull);
    });
  });

  group('fromJson', () {
    test('parses a fully populated record', () {
      final profile = EmployeeProfile.fromJson({
        'fullName': 'Amal Haddad',
        'email': 'amal@example.com',
        'birthDate': '1990-05-04',
        'position': 'Field Engineer',
        'jobTitle': 'Senior Engineer II',
        'hireDate': '2019-09-01',
        'hasPasskey': true,
        'signedInWith': 'passkey',
      });

      expect(profile.fullName, 'Amal Haddad');
      expect(profile.position, 'Field Engineer');
      expect(profile.jobTitle, 'Senior Engineer II');
      expect(profile.hasPasskey, isTrue);
      expect(profile.birthDate, DateTime(1990, 5, 4));
    });

    test('leaves unset fields null so the UI can show placeholders', () {
      final profile = EmployeeProfile.fromJson({'fullName': 'Amal Haddad'});

      expect(profile.age, isNull);
      expect(profile.yearsOfService, isNull);
      expect(profile.position, isNull);
      expect(profile.jobTitle, isNull);
      expect(profile.hasPasskey, isFalse);
    });

    test('treats an unparseable date as absent rather than throwing', () {
      final profile = EmployeeProfile.fromJson({'hireDate': 'not-a-date'});
      expect(profile.hireDate, isNull);
      expect(profile.yearsOfService, isNull);
    });
  });

  group('copyWith', () {
    test('preserves security and contact fields when only auth metadata changes', () {
      const profile = EmployeeProfile(
        employeeID: '1001',
        name: 'أحمد علي',
        serviceStatus: 'على الملاك',
        phoneNumber: '7700000000',
        administrativeUnit: 'قسم الأنظمة',
        roles: ['hr_admin'],
        permissions: ['VIEW_ALL_EMPLOYEES', 'VERIFY_DOCUMENTS'],
      );

      final updated = profile.copyWith(signedInWith: 'passkey');

      expect(updated.serviceStatus, 'على الملاك');
      expect(updated.phoneNumber, '7700000000');
      expect(updated.administrativeUnit, 'قسم الأنظمة');
      expect(updated.roles, ['hr_admin']);
      expect(updated.permissions, ['VIEW_ALL_EMPLOYEES', 'VERIFY_DOCUMENTS']);
    });
  });

  group('isAdmin', () {
    test('does not grant admin rights based on job title alone', () {
      const profile = EmployeeProfile(
        jobTitle: 'مدير قسم تقنية المعلومات',
        roles: [],
        permissions: [],
      );
      expect(profile.isAdmin, isFalse);
    });

    test('grants admin rights for explicit privileged role', () {
      const profile = EmployeeProfile(roles: ['hr_admin']);
      expect(profile.isAdmin, isTrue);
    });

    test('grants admin rights for explicit privileged permission', () {
      const profile = EmployeeProfile(permissions: ['VIEW_ALL_EMPLOYEES']);
      expect(profile.isAdmin, isTrue);
    });
  });
}
