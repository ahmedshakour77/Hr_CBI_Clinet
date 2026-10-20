import 'package:flutter_test/flutter_test.dart';
import 'package:cbi_app/src/id_reader/data/datasources/mrz_scanner_service.dart';
import 'package:cbi_app/src/id_reader/domain/entities/mrz_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MrzScannerService TD3 Iraqi Passport Tests', () {
    late MrzScannerService service;

    setUp(() {
      service = MrzScannerService();
    });

    test('Parses pristine Iraqi TD3 Passport MRZ', () {
      // Line 1: 44 chars
      // Line 2: 44 chars
      // Doc: A12345678, Check: 4 (calculated)
      // DOB: 900101, Check: 5
      // DOE: 300101, Check: 8
      const docNum = 'A12345678';
      final docCheck = MrzScannerService.calculateCheckDigit(docNum).toString();
      const dob = '900101';
      final dobCheck = MrzScannerService.calculateCheckDigit(dob).toString();
      const doe = '300101';
      final doeCheck = MrzScannerService.calculateCheckDigit(doe).toString();

      final l1 = 'P<IRQAL<<SAADI<<AHMED<HASSAN<<<<<<<<<<<<<<<<';
      final l2 = '$docNum${docCheck}IRQ$dob${dobCheck}M$doe$doeCheck<<<<<<<<<<<<<<04';

      final rawText = '''
REPUBLIC OF IRAQ
PASSPORT
$l1
$l2
''';

      final result = service.parseRecognizedText(rawText);
      expect(result, isNotNull);
      expect(result!.format, MrzFormat.td3);
      expect(result.documentNumber, docNum);
      expect(result.countryCode, 'IRQ');
      expect(result.nationality, 'IRQ');
      expect(result.birthDateRaw, dob);
      expect(result.expiryDateRaw, doe);
      expect(result.surname, 'AL');
      expect(result.givenNames, 'SAADI AHMED HASSAN');
      expect(result.bacKeySeed, '$docNum$docCheck$dob$dobCheck$doe$doeCheck');
    });

    test('Parses Iraqi TD3 Passport with OCR noise, chevron artifacts and intermediate lines', () {
      const docNum = 'A12345678';
      final docCheck = MrzScannerService.calculateCheckDigit(docNum).toString();
      const dob = '900101';
      final dobCheck = MrzScannerService.calculateCheckDigit(dob).toString();
      const doe = '300101';
      final doeCheck = MrzScannerService.calculateCheckDigit(doe).toString();

      // Notice « instead of <, spaces, noise line between L1 and L2
      final l1WithArtifacts = '  P«IRQAL««SAADI««AHMED«HASSAN««««««««««««««««  ';
      final noiseLine = 'تاريخ الانتهاء REPUBLIC OF IRAQ';
      // Notice O instead of 0 in DOB and DOE (common OCR misread)
      final l2WithOcrConfusions = ' $docNum${docCheck}IRQ9O01O1${dobCheck}M3O01O1$doeCheck««««««««««««««04 ';

      final rawText = '''
Header Text
$l1WithArtifacts
$noiseLine
$l2WithOcrConfusions
Footer Text
''';

      final result = service.parseRecognizedText(rawText);
      expect(result, isNotNull);
      expect(result!.documentNumber, docNum);
      expect(result.birthDateRaw, dob);
      expect(result.expiryDateRaw, doe);
      expect(result.countryCode, 'IRQ');
    });

    test('Parses Iraqi TD3 Passport with leading noise and doc number digit confusions', () {
      // Passport number: A02345678 -> OCR misread second char as 'O' -> AO2345678
      const realDocNum = 'A02345678';
      final docCheck = MrzScannerService.calculateCheckDigit(realDocNum).toString();
      const dob = '950512';
      final dobCheck = MrzScannerService.calculateCheckDigit(dob).toString();
      const doe = '350511';
      final doeCheck = MrzScannerService.calculateCheckDigit(doe).toString();

      // Leading '<' before P<, and OCR read 'AO' instead of 'A0'
      final l1 = '<P<IRQKHALIL<<ALI<<<<<<<<<<<<<<<<<<<<<<<<<<<';
      final l2 = '<AO2345678${docCheck}IRQ$dob${dobCheck}M$doe$doeCheck<<<<<<<<<<<<<<05';

      final rawText = '$l1\n$l2';

      final result = service.parseRecognizedText(rawText);
      expect(result, isNotNull);
      expect(result!.documentNumber, realDocNum);
      expect(result.documentNumberCheckDigit, docCheck);
      expect(result.birthDateRaw, dob);
      expect(result.expiryDateRaw, doe);
    });

    test('Parses Iraqi TD1 National ID MRZ without regression', () {
      const docNum = '123456789';
      final docCheck = MrzScannerService.calculateCheckDigit(docNum).toString();
      const dob = '920315';
      final dobCheck = MrzScannerService.calculateCheckDigit(dob).toString();
      const doe = '320314';
      final doeCheck = MrzScannerService.calculateCheckDigit(doe).toString();
      const opt1 = '<<<<<<<<<<<<<<<';
      const opt2 = '<<<<<<<<<<<';

      final l1 = 'I<IRQ$docNum$docCheck$opt1';
      final compositeStr = '${l1.substring(5, 30)}$dob$dobCheck$doe$doeCheck$opt2';
      final compositeCheck = MrzScannerService.calculateCheckDigit(compositeStr).toString();
      final l2 = '$dob${dobCheck}M$doe${doeCheck}IRQ$opt2$compositeCheck';
      const l3 = 'AL<<MOHAMMED<<<<<<<<<<<<<<<<<<';

      final rawText = '$l1\n$l2\n$l3';

      final result = service.parseRecognizedText(rawText);
      expect(result, isNotNull);
      expect(result!.format, MrzFormat.td1);
      expect(result.documentNumber, docNum);
      expect(result.birthDateRaw, dob);
      expect(result.expiryDateRaw, doe);
      expect(result.surname, 'AL');
      expect(result.givenNames, 'MOHAMMED');
    });
  });
}
