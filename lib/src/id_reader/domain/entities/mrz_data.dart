enum MrzFormat {
  /// Standard ID-1 National Identity Card (3 lines of 30 characters)
  td1,

  /// Standard ID-2 format (2 lines of 36 characters)
  td2,

  /// Standard Passport ID-3 format (2 lines of 44 characters)
  td3,
}

/// Structured representation of parsed Machine Readable Zone (MRZ)
/// conformant to ICAO Doc 9303 (Parts 3, 4, and 7).
class MrzData {
  const MrzData({
    required this.format,
    required this.documentType,
    required this.countryCode,
    required this.documentNumber,
    required this.documentNumberCheckDigit,
    required this.nationality,
    required this.birthDateRaw,
    required this.birthDateCheckDigit,
    required this.sex,
    required this.expiryDateRaw,
    required this.expiryDateCheckDigit,
    required this.compositeCheckDigit,
    required this.surname,
    required this.givenNames,
    this.optionalData = '',
    this.optionalData2 = '',
    this.rawLines = const [],
  });

  final MrzFormat format;
  final String documentType;
  final String countryCode;
  final String documentNumber;
  final String documentNumberCheckDigit;
  final String nationality;

  /// YYMMDD
  final String birthDateRaw;
  final String birthDateCheckDigit;

  /// 'M', 'F', or '<'
  final String sex;

  /// YYMMDD
  final String expiryDateRaw;
  final String expiryDateCheckDigit;

  final String compositeCheckDigit;
  final String surname;
  final String givenNames;
  final String optionalData;
  final String optionalData2;
  final List<String> rawLines;

  /// Computes the exact 24-character BAC seed string according to ICAO 9303 Part 11:
  /// Concatenation of:
  /// 1. Document number (padded with '<' to 9 chars) + check digit (1 char) -> 10 chars
  /// 2. Date of birth (YYMMDD) + check digit (1 char) -> 7 chars
  /// 3. Date of expiry (YYMMDD) + check digit (1 char) -> 7 chars
  /// Total: 24 characters.
  String get bacKeySeed {
    final cleanDoc = documentNumber.replaceAll('<', '').padRight(9, '<');
    final docPart = '$cleanDoc$documentNumberCheckDigit';
    final dobPart = '$birthDateRaw$birthDateCheckDigit';
    final doePart = '$expiryDateRaw$expiryDateCheckDigit';
    return '$docPart$dobPart$doePart';
  }

  /// Parses YYMMDD into a [DateTime] object.
  /// Handles century rollover: assumes 1900s if year > currentYear % 100 + 10 for DOB,
  /// otherwise 2000s.
  DateTime? parseDate(String yymmdd, {bool isExpiry = false}) {
    if (yymmdd.length != 6) return null;
    final yy = int.tryParse(yymmdd.substring(0, 2));
    final mm = int.tryParse(yymmdd.substring(2, 4));
    final dd = int.tryParse(yymmdd.substring(4, 6));

    if (yy == null || mm == null || dd == null) return null;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;

    final currentYearTwoDigits = DateTime.now().year % 100;
    int year;
    if (isExpiry) {
      // Expiry dates are typically current century
      year = 2000 + yy;
    } else {
      // Birth date century deduction
      year = (yy > currentYearTwoDigits) ? 1900 + yy : 2000 + yy;
    }

    return DateTime(year, mm, dd);
  }

  DateTime? get dateOfBirth => parseDate(birthDateRaw, isExpiry: false);
  DateTime? get dateOfExpiry => parseDate(expiryDateRaw, isExpiry: true);

  /// Whether this MRZ belongs to a passport (TD3 format or document code starting with 'P').
  bool get isPassport => format == MrzFormat.td3 || documentType.toUpperCase().startsWith('P');

  @override
  String toString() {
    return 'MrzData(format: $format, doc: $documentNumber, dob: $birthDateRaw, exp: $expiryDateRaw)';
  }
}
