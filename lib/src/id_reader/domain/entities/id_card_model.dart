import 'dart:convert';
import 'dart:typed_data';
import 'mrz_data.dart';

/// Represents a fully verified identity card or electronic passport
/// extracted from both the visual MRZ and the secure NFC microchip.
class IdCardModel {
  const IdCardModel({
    required this.documentNumber,
    required this.documentType,
    required this.issuingCountry,
    required this.nationality,
    required this.surname,
    required this.givenNames,
    required this.gender,
    this.fullNameArabic,
    this.motherName,
    this.placeOfBirth,
    this.bloodType,
    this.dateOfBirth,
    this.dateOfExpiry,
    this.dateOfIssue,
    this.issuingAuthority,
    this.personalNumber,
    this.address,
    this.civilRecord,
    this.facePhotoBytes,
    this.signaturePhotoBytes,
    this.frontCardPhotoBytes,
    this.backCardPhotoBytes,
    this.isBacAuthenticated = false,
    this.isSodHashVerified = false,
    this.isDocumentValid = false,
    this.rawMrz = '',
  });

  /// 9-character document identifier (or padded with check digit)
  final String documentNumber;

  /// Document code (e.g., 'I', 'ID' for National ID, 'P' for Passport)
  final String documentType;

  /// ISO 3166-1 alpha-3 code of issuing state (e.g. 'IRQ', 'USA', 'DEU')
  final String issuingCountry;

  /// ISO 3166-1 alpha-3 code of cardholder nationality
  final String nationality;

  /// Primary identifier / Family Name (Latin transliteration)
  final String surname;

  /// Secondary identifiers / Given Names (Latin transliteration)
  final String givenNames;

  /// Full Name in national script (Arabic / Kurdish) from DG11 or front OCR
  final String? fullNameArabic;

  /// Mother's name (اسم الأم) from DG11 or front OCR
  final String? motherName;

  /// Place of Birth (محل الولادة / المحافظة)
  final String? placeOfBirth;

  /// Blood type (فصيلة الدم - e.g. 'O+', 'A+')
  final String? bloodType;

  /// Cardholder sex ('M', 'F', or 'X')
  final String gender;

  /// Cardholder date of birth
  final DateTime? dateOfBirth;

  /// Document expiration date
  final DateTime? dateOfExpiry;

  /// Document issuance date (تاريخ الإصدار)
  final DateTime? dateOfIssue;

  /// Issuing Authority or Civil Status Directorate (جهة الإصدار / دائرة الأحوال)
  final String? issuingAuthority;

  /// Optional personal / 12-digit national identification number (الرقم الوطني الموحد)
  final String? personalNumber;

  /// Permanent address / residence
  final String? address;

  /// Family / Civil registry record details (السجل والصحيفة)
  final String? civilRecord;

  /// Biometric facial portrait extracted from Data Group 2 (DG2)
  final Uint8List? facePhotoBytes;

  /// Digitized signature or mark extracted from Data Group 7 (DG7)
  final Uint8List? signaturePhotoBytes;

  /// High-resolution camera photograph of the card front face
  final Uint8List? frontCardPhotoBytes;

  /// High-resolution camera photograph of the card back face
  final Uint8List? backCardPhotoBytes;

  /// True if Basic Access Control (BAC) mutual authentication succeeded
  final bool isBacAuthenticated;

  /// True if Data Group hashes matched the hashes signed in EF.SOD
  final bool isSodHashVerified;

  /// Overall document integrity & expiration validity
  final bool isDocumentValid;

  /// Raw MRZ string scanned from the card
  final String rawMrz;

  /// Full concatenated cardholder name (Latin)
  String get fullName {
    final s = surname.trim();
    final g = givenNames.trim();
    if (s.isEmpty) return g;
    if (g.isEmpty) return s;
    return '$g $s';
  }

  /// Primary display name: Arabic full name if available, otherwise Latin full name
  String get displayName {
    if (fullNameArabic != null && fullNameArabic!.trim().isNotEmpty) {
      return fullNameArabic!.trim();
    }
    return fullName;
  }

  /// Creates an [IdCardModel] from optical MRZ data alone (used for regular passports
  /// or when NFC chip is bypassed/unavailable).
  factory IdCardModel.fromMrzOnly({
    required MrzData mrzData,
    Uint8List? frontCardPhotoBytes,
    Uint8List? backCardPhotoBytes,
    Uint8List? facePhotoBytes,
  }) {
    final isExpired = mrzData.dateOfExpiry != null && DateTime.now().isAfter(mrzData.dateOfExpiry!);
    String? personalNum = mrzData.optionalData.replaceAll('<', '').trim();
    if (personalNum.isEmpty && mrzData.optionalData2.isNotEmpty) {
      personalNum = mrzData.optionalData2.replaceAll('<', '').trim();
    }

    return IdCardModel(
      documentNumber: mrzData.documentNumber,
      documentType: mrzData.documentType.isNotEmpty
          ? mrzData.documentType
          : (mrzData.format == MrzFormat.td3 ? 'P' : 'I'),
      issuingCountry: mrzData.countryCode,
      nationality: mrzData.nationality,
      surname: mrzData.surname,
      givenNames: mrzData.givenNames,
      gender: mrzData.sex,
      dateOfBirth: mrzData.dateOfBirth,
      dateOfExpiry: mrzData.dateOfExpiry,
      personalNumber: personalNum.isNotEmpty ? personalNum : null,
      frontCardPhotoBytes: frontCardPhotoBytes,
      backCardPhotoBytes: backCardPhotoBytes,
      facePhotoBytes: facePhotoBytes,
      isBacAuthenticated: false,
      isSodHashVerified: false,
      isDocumentValid: !isExpired,
      rawMrz: mrzData.rawLines.join('\n'),
    );
  }

  /// Whether this document is a passport (regular or electronic)
  bool get isPassport =>
      documentType.toUpperCase().startsWith('P') ||
      documentType.toUpperCase().contains('PASS');

  /// Whether the document has expired according to device clock
  bool get isExpired {
    if (dateOfExpiry == null) return false;
    return DateTime.now().isAfter(dateOfExpiry!);
  }

  /// Converts the verified ID card record and all biometric photos into
  /// standard JSON payload matching the backend API request specification.
  Map<String, dynamic> toApiPayload() {
    String? formatDate(DateTime? d) {
      if (d == null) return null;
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    }

    String mapGender(String g) {
      final clean = g.trim().toUpperCase();
      if (clean == 'M' || clean == 'MALE' || clean.contains('ذكر')) return 'ذكر';
      if (clean == 'F' || clean == 'FEMALE' || clean.contains('أنثى') || clean.contains('انثى')) return 'أنثى';
      return g;
    }

    String mapNationality(String n) {
      final clean = n.trim().toUpperCase();
      if (clean == 'IRQ' || clean == 'IRAQ' || clean.contains('عراق')) return 'عراقي';
      return n;
    }

    return {
      'documentNumber': documentNumber,
      'nationalIdNumber': personalNumber ?? '',
      'fullNameAr': fullNameArabic ?? '',
      'fullNameEn': fullName,
      'dateOfBirth': formatDate(dateOfBirth),
      'gender': mapGender(gender),
      'nationality': mapNationality(nationality),
      'issuingState': issuingCountry.isNotEmpty ? issuingCountry : 'IRQ',
      'issueDate': formatDate(dateOfIssue),
      'expiryDate': formatDate(dateOfExpiry),
      'rawMrz': rawMrz,
      'isPassiveAuthenticationValid': isSodHashVerified,
      if (frontCardPhotoBytes != null)
        'frontImageBase64': 'data:image/jpeg;base64,${base64Encode(frontCardPhotoBytes!)}',
      if (backCardPhotoBytes != null)
        'backImageBase64': 'data:image/jpeg;base64,${base64Encode(backCardPhotoBytes!)}',
      if (facePhotoBytes != null)
        'biometricFaceBase64': 'data:image/jpeg;base64,${base64Encode(facePhotoBytes!)}',
    };
  }

  /// Exports National Card payload conforming directly to POST /api/documents/national-card
  Map<String, dynamic> toNationalCardApiPayload({String? employeeId}) {
    String formatDate(DateTime? d) {
      if (d == null) return '';
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    String mapGender(String g) {
      final clean = g.trim().toUpperCase();
      if (clean == 'M' || clean == 'MALE' || clean.contains('ذكر')) return 'ذكر';
      if (clean == 'F' || clean == 'FEMALE' || clean.contains('أنثى') || clean.contains('انثى')) return 'أنثى';
      return g;
    }

    String mapNationality(String n) {
      final clean = n.trim().toUpperCase();
      if (clean == 'IRQ' || clean == 'IRAQ' || clean.contains('عراق')) return 'عراقي';
      return n;
    }

    return {
      if (employeeId != null && employeeId.isNotEmpty) 'employeeID': employeeId,
      'documentNumber': documentNumber,
      'nationalIdNumber': personalNumber ?? '',
      'fullNameAr': fullNameArabic ?? '',
      'firstNameEn': givenNames,
      'lastNameEn': surname,
      'fullNameEn': fullName,
      'dateOfBirth': formatDate(dateOfBirth),
      'gender': mapGender(gender),
      'nationality': mapNationality(nationality),
      'issuingState': issuingCountry.isNotEmpty ? issuingCountry : 'IRQ',
      'issueDate': formatDate(dateOfIssue),
      'expiryDate': formatDate(dateOfExpiry),
      'rawMrz': rawMrz,
      'isPassiveAuthenticationValid': isSodHashVerified,
      if (facePhotoBytes != null)
        'biometricFaceBase64': base64Encode(facePhotoBytes!),
      if (frontCardPhotoBytes != null)
        'frontImageBase64': base64Encode(frontCardPhotoBytes!),
      if (backCardPhotoBytes != null)
        'backImageBase64': base64Encode(backCardPhotoBytes!),
    };
  }

  /// Exports Passport payload conforming directly to POST /api/documents/passport
  Map<String, dynamic> toPassportApiPayload({
    String? employeeId,
    bool? isElectronic,
  }) {
    String formatDate(DateTime? d) {
      if (d == null) return '';
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    String mapGender(String g) {
      final clean = g.trim().toUpperCase();
      if (clean == 'M' || clean == 'MALE' || clean.contains('ذكر')) return 'ذكر';
      if (clean == 'F' || clean == 'FEMALE' || clean.contains('أنثى') || clean.contains('انثى')) return 'أنثى';
      return g;
    }

    final electronic = isElectronic ?? (isBacAuthenticated || facePhotoBytes != null);

    return {
      if (employeeId != null && employeeId.isNotEmpty) 'employeeID': employeeId,
      'passportNumber': documentNumber,
      'isElectronic': electronic,
      'passportType': 'عادي (P)',
      'countryCode': issuingCountry.isNotEmpty ? issuingCountry : 'IRQ',
      'issuingCountry': 'العراق',
      'issuingAuthority': issuingAuthority ?? 'مديرية شؤون الجوازات',
      'nationalIdNumber': personalNumber ?? '',
      'fullNameAr': fullNameArabic ?? '',
      'fullNameEn': fullName,
      if (motherName != null && motherName!.isNotEmpty) 'motherName': motherName,
      if (placeOfBirth != null && placeOfBirth!.isNotEmpty) 'placeOfBirth': placeOfBirth,
      'dateOfBirth': formatDate(dateOfBirth),
      'gender': mapGender(gender),
      'issueDate': formatDate(dateOfIssue),
      'expiryDate': formatDate(dateOfExpiry),
      'rawMrz': rawMrz,
      if (backCardPhotoBytes != null || frontCardPhotoBytes != null)
        'passportImageBase64': base64Encode(backCardPhotoBytes ?? frontCardPhotoBytes!),
      if (facePhotoBytes != null)
        'biometricPhotoBase64': base64Encode(facePhotoBytes!),
      'notes': electronic
          ? 'تم المسح وقراءة الشريحة الذكية عبر NFC'
          : 'تم المسح والقراءة الضوئية لصفحة الجواز',
    };
  }

  @override
  String toString() {
    return 'IdCardModel(doc: $documentNumber, name: $displayName, nat: $nationality, valid: $isDocumentValid, hasFrontPhoto: ${frontCardPhotoBytes != null}, hasBackPhoto: ${backCardPhotoBytes != null})';
  }
}
