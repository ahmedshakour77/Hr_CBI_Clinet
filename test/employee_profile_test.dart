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
      // One day short of six years.
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
}
