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

  void dispose() {
    _recognizer.close();
  }

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

  MrzData? parseRecognizedText(String rawText) {
    final rawLines = rawText
        .split('\n')
        .map((l) {
          String s = l.trim().toUpperCase().replaceAll(' ', '');
          s = s.replaceAll(RegExp(r'[«»‹›\(\)\[\]\{\}\|/\_\-]'), '<');
          return s;
        })
        .where((l) => l.contains('<') || l.length >= 25)
        .toList();

    if (rawLines.isEmpty) return null;

    final hasPassportHint = rawLines.any((l) => l.contains('P<') || (l.startsWith('P') && l.length >= 30));
    if (hasPassportHint) {
      final td3Result = _tryParseTd3(rawLines);
      if (td3Result != null) return td3Result;
    }

    final td1Result = _tryParseTd1(rawLines);
    if (td1Result != null) return td1Result;

    if (!hasPassportHint) {
      final td3Result = _tryParseTd3(rawLines);
      if (td3Result != null) return td3Result;
    }

    return null;
  }

  MrzData? _tryParseTd1(List<String> lines) {
    for (int i = 0; i <= lines.length - 3; i++) {
      final l1 = _normalizeLength(lines[i], 30);
      final l2 = _normalizeLength(lines[i + 1], 30);
      final l3 = _normalizeLength(lines[i + 2], 30);
      if (l1 == null || l2 == null || l3 == null) continue;

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

        if (!_verifyCheckDigit(docNum, docCheck)) continue;
        if (!_verifyCheckDigit(dob, dobCheck)) continue;
        if (!_verifyCheckDigit(doe, doeCheck)) continue;

        final compositeStr = '${l1.substring(5, 30)}${l2.substring(0, 7)}${l2.substring(8, 15)}${l2.substring(18, 29)}';
        if (!_verifyCheckDigit(compositeStr, compositeCheck)) continue;

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

  MrzData? _tryParseTd3(List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line1Candidate = lines[i];

      int pIdx = line1Candidate.indexOf('P<');
      if (pIdx == -1) {
        final match = RegExp(r'\bP[A-Z<]').firstMatch(line1Candidate);
        if (match != null) pIdx = match.start;
      }
      if (pIdx == -1) continue;

      final l1Raw = line1Candidate.substring(pIdx);
      final l1 = _normalizeLength(l1Raw, 44);
      if (l1 == null) continue;

      final country = l1.substring(2, 5).replaceAll('<', '');

      final candidateIndices = <int>[];
      for (int step = 1; step <= 5; step++) {
        if (i + step < lines.length) candidateIndices.add(i + step);
        if (i - step >= 0) candidateIndices.add(i - step);
      }

      for (final j in candidateIndices) {
        final line2Candidate = lines[j];
        if (line2Candidate.length < 44) continue;
        if (line2Candidate.startsWith('P<')) continue;

        String l2Raw = line2Candidate;
        if (country.isNotEmpty && country.length == 3 && line2Candidate.contains(country)) {
          final cIdx = line2Candidate.indexOf(country);
          if (cIdx >= 10) l2Raw = line2Candidate.substring(cIdx - 10);
        }

        final l2 = _normalizeLength(l2Raw, 44);
        if (l2 == null) continue;

        try {
          final rawDocNum = l2.substring(0, 9);
          final docNum = _sanitizePassportDocNumber(rawDocNum);
          final docCheck = _sanitizeNumeric(l2.substring(9, 10));
          final nat = l2.substring(10, 13).replaceAll('<', '');
          final dob = _sanitizeNumeric(l2.substring(13, 19));
          final dobCheck = _sanitizeNumeric(l2.substring(19, 20));
          final sexChar = l2.substring(20, 21);
          final sex = (sexChar == 'M' || sexChar == 'F' || sexChar == '<') ? sexChar : '<';
          final doe = _sanitizeNumeric(l2.substring(21, 27));
          final doeCheck = _sanitizeNumeric(l2.substring(27, 28));
          final opt = l2.substring(28, 42);
          final personalCheck = _sanitizeNumeric(l2.substring(42, 43));
          final compositeCheck = _sanitizeNumeric(l2.substring(43, 44));

          if (!_verifyCheckDigit(docNum, docCheck)) continue;
          if (!_verifyCheckDigit(dob, dobCheck)) continue;
          if (!_verifyCheckDigit(doe, doeCheck)) continue;
          if (!_verifyCheckDigit(opt, personalCheck)) continue;

          final compositeStr = '${l2.substring(0, 10)}${l2.substring(13, 20)}${l2.substring(21, 43)}';
          if (!_verifyCheckDigit(compositeStr, compositeCheck)) continue;

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

  static int calculateCheckDigit(String input) {
    const weights = [7, 3, 1];
    int sum = 0;
    for (int i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      int val = 0;
      if (code >= 48 && code <= 57) {
        val = code - 48;
      } else if (code >= 65 && code <= 90) {
        val = code - 65 + 10;
      } else if (code == 60) {
        val = 0;
      } else {
        return -1;
      }
      sum += val * weights[i % 3];
    }
    return sum % 10;
  }

  static bool _verifyCheckDigit(String value, String checkDigitStr) {
    final expected = int.tryParse(checkDigitStr);
    if (expected == null) return false;
    final calculated = calculateCheckDigit(value);
    return calculated >= 0 && calculated == expected;
  }

  /// OCR must provide the complete ICAO line. Missing characters are never
  /// fabricated with filler characters because that can turn partial OCR into
  /// an apparently valid identity document.
  static String? _normalizeLength(String line, int targetLength) {
    if (line.length < targetLength) return null;
    if (line.length == targetLength) return line;
    return line.substring(0, targetLength);
  }

  static String _sanitizeNumeric(String input) {
    return input
        .replaceAll('O', '0')
        .replaceAll('Q', '0')
        .replaceAll('D', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('Z', '2')
        .replaceAll('S', '5')
        .replaceAll('B', '8');
  }

  static String _sanitizePassportDocNumber(String input) {
    if (input.isEmpty) return input;
    String first = input[0];
    if (first == '4' || first == '@') first = 'A';
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

  static String _sanitizeAlphaNumeric(String input) {
    return input.replaceAll(' ', '<').replaceAll('«', '<');
  }
}
