import 'package:cbi_app/src/id_reader/data/datasources/mrz_scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MrzScannerService strict ICAO validation', () {
    late MrzScannerService service;

    setUp(() {
      service = MrzScannerService();
    });

    tearDown(() {
      service.dispose();
    });

    test('accepts a valid ICAO TD3 sample', () {
      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const line2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';

      final result = service.parseRecognizedText('$line1\n$line2');

      expect(result, isNotNull);
      expect(result!.documentNumber, 'L898902C3');
      expect(result.birthDateRaw, '740812');
      expect(result.expiryDateRaw, '120415');
    });

    test('rejects a truncated TD3 line instead of padding missing characters', () {
      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const truncatedLine2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<';

      final result = service.parseRecognizedText('$line1\n$truncatedLine2');

      expect(result, isNull);
    });

    test('rejects TD3 when the composite check digit is invalid', () {
      const line1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
      const invalidComposite = 'L898902C36UTO7408122F1204159ZE184226B<<<<<11';

      final result = service.parseRecognizedText('$line1\n$invalidComposite');

      expect(result, isNull);
    });
  });
}
