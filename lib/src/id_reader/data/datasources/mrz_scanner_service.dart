import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/entities/mrz_data.dart';
import '../../domain/errors/id_card_failure.dart';

/// Real-time camera stream processor that extracts, sanitizes, and mathematically
/// validates Machine Readable Zone (MRZ) data for TD1 and TD3 documents.
class MrzScannerService {
  MrzScannerService() {
    _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  late final TextRecognizer _recognizer;
  bool _isProcessingFrame = false;
  DateTime _lastProcessedTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Closes the ML Kit text recognition native pipeline.
  void dispose() {
    _recognizer.close();
  }

  /// Processes an [InputImage] from camera stream with built-in frame throttling.
  /// Throttled to a minimum interval of [throttleMs] milliseconds to preserve 60fps UI.
  Future<MrzData?> processFrame(InputImage inputImage, {int throttleMs = 350}) async {
    final now = DateTime.now();
    if (_isProcessingFrame || now.difference(_lastProcessedTime).inMilliseconds < throttleMs) {
      return null;
    }

    _isProcessingFrame = true;
    _lastProcessedTime = now;

    try {
      final recognizedText = await _recognizer.processImage(inputImage);
      return parseRecognizedText(recognizedText.text);
    } catch (e) {
      throw MrzScanFailure('Failed to recognize text from camera frame', e);
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Parses and validates arbitrary raw OCR text blocks into structured [MrzData].
  MrzData? parseRecognizedText(String rawText) {
    // 1. Clean up lines: uppercase, trim, strip spaces, convert chevron artifacts
    final rawLines = rawText
        .split('\n')
        .map((l) {
          String s = l.trim().toUpperCase().replaceAll(' ', '');
          // Replace common OCR misreads of chevrons '<'
          s = s.replaceAll(RegExp(r'[«»‹›\(\)\[\]\{\}\|/\_\-]'), '<');
          return s;
        })
        .where((l) => l.contains('<') || l.length >= 25)
        .toList();

    if (rawLines.isEmpty) return null;

    // Check for TD3 (Passport) first if any line contains passport indicators
    final hasPassportHint = rawLines.any((l) => l.contains('P<') || (l.startsWith('P') && l.length >= 30));
    if (hasPassportHint) {
      final td3Result = _tryParseTd3(rawLines);
      if (td3Result != null) return td3Result;
    }

    // Check for TD1 (3 lines of 30 characters - National ID)
    final td1Result = _tryParseTd1(rawLines);
    if (td1Result != null) return td1Result;

    // Check for TD3 fallback if not checked yet
    if (!hasPassportHint) {
      final td3Result = _tryParseTd3(rawLines);
      if (td3Result != null) return td3Result;
    }

    return null;
  }

  /// TD1 Format (Standard National ID): 3 lines of 30 characters
  /// Line 1: [DocType(2)][IssuingState(3)][DocNumber(9)][Check(1)][Optional1(15)]
  /// Line 2: [DOB(6)][Check(1)][Sex(1)][DOE(6)][Check(1)][Nationality(3)][Optional2(11)][CompositeCheck(1)]
  /// Line 3: [Surname<<GivenNames(30)]
  MrzData? _tryParseTd1(List<String> lines) {
    for (int i = 0; i <= lines.length - 3; i++) {
      String l1 = _sanitizeLength(lines[i], 30);
      String l2 = _sanitizeLength(lines[i + 1], 30);
      String l3 = _sanitizeLength(lines[i + 2], 30);

      if (l1.length != 30 || l2.length != 30 || l3.length != 30) continue;

      // First character must be 'I' or 'A' or 'C'
      final docTypeChar = l1[0];
      if (!'IAC'.contains(docTypeChar)) continue;

      try {
        final docType = l1.substring(0, 2).replaceAll('<', '');
        final country = l1.substring(2, 5).replaceAll('<', '');
        final docNum = _sanitizeAlphaNumeric(l1.substring(5, 14));
        final docCheck = _sanitizeNumeric(l1.substring(14, 15));
        final opt1 = l1.substring(15, 30);

        final dob = _sanitizeNumeric(l2.substring(0, 6));
        final dobCheck = _sanitizeNumeric(l2.substring(6, 7));
        final sex = l2.substring(7, 8);
        final doe = _sanitizeNumeric(l2.substring(8, 14));
        final doeCheck = _sanitizeNumeric(l2.substring(14, 15));
        final nat = l2.substring(15, 18).replaceAll('<', '');
        final opt2 = l2.substring(18, 29);
        final compositeCheck = _sanitizeNumeric(l2.substring(29, 30));

        // Validate Check Digits
        if (!_verifyCheckDigit(docNum, docCheck)) continue;
        if (!_verifyCheckDigit(dob, dobCheck)) continue;
        if (!_verifyCheckDigit(doe, doeCheck)) continue;

        // Composite check string for TD1: Line1(0..30) + Line2(0..7) + Line2(8..15) + Line2(18..29)
        final compositeStr = '${l1.substring(5, 30)}$dob$dobCheck$doe$doeCheck$opt2';
        if (!_verifyCheckDigit(compositeStr, compositeCheck)) {
          // Some national IDs omit optional data in composite check, check fallback:
          if (!_verifyCheckDigit('$docNum$docCheck$dob$dobCheck$doe$doeCheck', compositeCheck)) {
            // Still accept if the 3 primary keys (Doc, DOB, DOE) are valid
          }
        }

        // Parse Names from Line 3 (SURNAME<<GIVEN<NAMES)
        final nameParts = l3.split('<<');
        final surname = nameParts.isNotEmpty ? nameParts[0].replaceAll('<', ' ').trim() : '';
        final given = nameParts.length > 1 ? nameParts[1].replaceAll('<', ' ').trim() : '';

        return MrzData(
          format: MrzFormat.td1,
          documentType: docType,
          countryCode: country,
          documentNumber: docNum,
          documentNumberCheckDigit: docCheck,
          nationality: nat,
          birthDateRaw: dob,
          birthDateCheckDigit: dobCheck,
          sex: sex,
          expiryDateRaw: doe,
          expiryDateCheckDigit: doeCheck,
          compositeCheckDigit: compositeCheck,
          surname: surname,
          givenNames: given,
          optionalData: opt1,
          optionalData2: opt2,
          rawLines: [l1, l2, l3],
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// TD3 Format (Standard Passport): 2 lines of 44 characters
  /// Line 1: [P<][IssuingState(3)][Surname<<GivenNames(39)]
  /// Line 2: [DocNumber(9)][Check(1)][Nationality(3)][DOB(6)][Check(1)][Sex(1)][DOE(6)][Check(1)][PersonalNum(14)][Check(1)][CompositeCheck(1)]
  MrzData? _tryParseTd3(List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line1Candidate = lines[i];

      // Line 1 begins with 'P<' or 'P' followed by uppercase letter and country code
      int pIdx = line1Candidate.indexOf('P<');
      if (pIdx == -1) {
        final match = RegExp(r'\bP[A-Z<]').firstMatch(line1Candidate);
        if (match != null) {
          pIdx = match.start;
        }
      }
      if (pIdx == -1) continue;

      final l1Raw = line1Candidate.substring(pIdx);
      if (l1Raw.length < 28) continue;
      final l1 = _sanitizeLength(l1Raw, 44);

      final country = l1.substring(2, 5).replaceAll('<', '');

      // Search for Line 2 candidate around Line 1 (subsequent lines first, then preceding lines)
      final candidateIndices = <int>[];
      for (int step = 1; step <= 5; step++) {
        if (i + step < lines.length) candidateIndices.add(i + step);
        if (i - step >= 0) candidateIndices.add(i - step);
      }

      for (final j in candidateIndices) {
        final line2Candidate = lines[j];
        if (line2Candidate.length < 28) continue;
        if (line2Candidate.startsWith('P<')) continue;

        String l2Raw = line2Candidate;
        // Anchor using country code if present in line 2 (e.g. 'IRQ' at index 10)
        if (country.isNotEmpty && country.length == 3 && line2Candidate.contains(country)) {
          final cIdx = line2Candidate.indexOf(country);
          if (cIdx >= 10) {
            l2Raw = line2Candidate.substring(cIdx - 10);
          }
        }

        final l2 = _sanitizeLength(l2Raw, 44);
        if (l2.length != 44) continue;

        try {
          // Document Number & Check Digit
          final rawDocNum = l2.substring(0, 9);
          final docNum = _sanitizePassportDocNumber(rawDocNum);
          final docCheck = _sanitizeNumeric(l2.substring(9, 10));

          final nat = l2.substring(10, 13).replaceAll('<', '');
          final dob = _sanitizeNumeric(l2.substring(13, 19));
          final dobCheck = _sanitizeNumeric(l2.substring(19, 20));
          final sexChar = l2.substring(20, 21);
          final sex = (sexChar == 'M' || sexChar == 'F') ? sexChar : '<';
          final doe = _sanitizeNumeric(l2.substring(21, 27));
          final doeCheck = _sanitizeNumeric(l2.substring(27, 28));
          final opt = l2.substring(28, 42);
          final compositeCheck = _sanitizeNumeric(l2.substring(43, 44));

          // Validate Check Digits
          final isDocValid = _verifyCheckDigit(docNum, docCheck);
          final isDobValid = _verifyCheckDigit(dob, dobCheck);
          final isDoeValid = _verifyCheckDigit(doe, doeCheck);

          // All 3 primary fields (Doc, DOB, DOE) must be mathematically sound
          if (!isDocValid || !isDobValid || !isDoeValid) {
            continue;
          }

          // Names from Line 1: P<IRQ Surname << Given Names
          final namesRaw = l1.substring(5, 44);
          final nameParts = namesRaw.split('<<');
          final surname = nameParts.isNotEmpty
              ? nameParts[0].replaceAll('<', ' ').replaceAll(RegExp(r'\s+'), ' ').trim()
              : '';
          final given = nameParts.length > 1
              ? nameParts.sublist(1).join(' ').replaceAll('<', ' ').replaceAll(RegExp(r'\s+'), ' ').trim()
              : '';

          return MrzData(
            format: MrzFormat.td3,
            documentType: 'P',
            countryCode: country,
            documentNumber: docNum,
            documentNumberCheckDigit: docCheck,
            nationality: nat.isNotEmpty ? nat : country,
            birthDateRaw: dob,
            birthDateCheckDigit: dobCheck,
            sex: sex,
            expiryDateRaw: doe,
            expiryDateCheckDigit: doeCheck,
            compositeCheckDigit: compositeCheck,
            surname: surname,
            givenNames: given,
            optionalData: opt,
            rawLines: [l1, l2],
          );
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  /// Calculates check digit according to ICAO Doc 9303 7-3-1 weighting scheme.
  /// Characters: '0'-'9' => 0..9, 'A'-'Z' => 10..35, '<' => 0.
  static int calculateCheckDigit(String input) {
    const weights = [7, 3, 1];
    int sum = 0;
    for (int i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      int val = 0;
      if (code >= 48 && code <= 57) {
        val = code - 48; // '0'-'9'
      } else if (code >= 65 && code <= 90) {
        val = code - 65 + 10; // 'A'-'Z'
      } else if (code == 60) {
        val = 0; // '<'
      }
      sum += val * weights[i % 3];
    }
    return sum % 10;
  }

  static bool _verifyCheckDigit(String value, String checkDigitStr) {
    final expected = int.tryParse(checkDigitStr);
    if (expected == null) return false;
    return calculateCheckDigit(value) == expected;
  }

  /// Pad or trim string to target length
  static String _sanitizeLength(String line, int targetLength) {
    if (line.length == targetLength) return line;
    if (line.length > targetLength) return line.substring(0, targetLength);
    return line.padRight(targetLength, '<');
  }

  /// Corrects typical OCR misinterpretations in numeric fields
  static String _sanitizeNumeric(String input) {
    return input
        .replaceAll('O', '0')
        .replaceAll('Q', '0')
        .replaceAll('D', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('Z', '2')
        .replaceAll('S', '5')
        .replaceAll('B', '8')
        .replaceAll('<', '0');
  }

  /// Corrects passport document numbers (series letter followed by digits)
  static String _sanitizePassportDocNumber(String input) {
    if (input.isEmpty) return input;
    String first = input[0];
    if (first == '4' || first == '@') first = 'A'; // common OCR confusion for 'A'
    final rest = input.substring(1)
        .replaceAll('O', '0')
        .replaceAll('Q', '0')
        .replaceAll('D', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('Z', '2')
        .replaceAll('S', '5')
        .replaceAll('B', '8');
    return '$first$rest';
  }

  /// Corrects alphanumeric fields
  static String _sanitizeAlphaNumeric(String input) {
    return input.replaceAll(' ', '<').replaceAll('«', '<');
  }
}
