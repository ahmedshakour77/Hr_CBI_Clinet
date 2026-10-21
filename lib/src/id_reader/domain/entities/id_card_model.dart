import 'dart:convert';
import 'dart:typed_data';
import 'mrz_data.dart';

/// Represents identity-document data extracted from optical MRZ and, when
/// available, the NFC chip. Cryptographic authenticity is reported separately
/// and must only become true after full ICAO passive authentication.
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
    bool isSodHashVerified = false,
    bool isDocumentValid = false,
    this.rawMrz = '',
  })  : isSodHashVerified = false,
        // The NFC service historically supplied `true` after only finding DG
        // hashes inside EF.SOD. That is not full ICAO passive authentication.
        // Fail closed for NFC results until CMS signature + DS/CSCA chain
        // validation is implemented. Optical-only validity can still represent
        // non-expiration when no SOD claim was made.
        isDocumentValid = isDocumentValid && !isSodHashVerified;

  final String documentNumber;
  final String documentType;
  final String issuingCountry;
  final String nationality;
  final String surname;
  final String givenNames;
  final String? fullNameArabic;
  final String? motherName;
  final String? placeOfBirth;
  final String? bloodType;
  final String gender;
  final DateTime? dateOfBirth;
  final DateTime? dateOfExpiry;
  final DateTime? dateOfIssue;
  final String? issuingAuthority;
  final String? personalNumber;
  final String? address;
  final String? civilRecord;
  final Uint8List? facePhotoBytes;
  final Uint8List? signaturePhotoBytes;
  final Uint8List? frontCardPhotoBytes;
  final Uint8List? backCardPhotoBytes;
  final bool isBacAuthenticated;

  /// Full ICAO passive authentication status. This intentionally remains false
  /// until EF.SOD CMS signature and the Document Signer -> CSCA trust chain are
  /// validated, not merely until DG hashes are found in the SOD bytes.
  final bool isSodHashVerified;

  /// Document validity used by the UI. NFC records that relied on the legacy
  /// weak SOD check fail closed; optical-only records may still be considered
  /// non-expired but are never reported as cryptographically authenticated.
  final bool isDocumentValid;

  final String rawMrz;

  String get fullName {
    final s = surname.trim();
    final g = givenNames.trim();
    if (s.isEmpty) return g;
    if (g.isEmpty) return s;
    return '$g $s';
  }

  String get displayName {
    if (fullNameArabic != null && fullNameArabic!.trim().isNotEmpty) {
      return fullNameArabic!.trim();
    }
    return fullName;
  }

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

  bool get isPassport =>
      documentType.toUpperCase().startsWith('P') ||
      documentType.toUpperCase().contains('PASS');

  bool get isExpired {
    if (dateOfExpiry == null) return false;
    return DateTime.now().isAfter(dateOfExpiry!);
  }

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
          ? 'تم المسح وقراءة الشريحة الذكية عبر NFC — التحقق التشفيري الكامل من SOD غير مكتمل بعد'
          : 'تم المسح والقراءة الضوئية لصفحة الجواز',
    };
  }

  @override
  String toString() {
    return 'IdCardModel(doc: $documentNumber, name: $displayName, nat: $nationality, valid: $isDocumentValid, passiveAuth: $isSodHashVerified, hasFrontPhoto: ${frontCardPhotoBytes != null}, hasBackPhoto: ${backCardPhotoBytes != null})';
  }
}
