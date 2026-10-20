/// Models representing official documents from:
/// `GET /api/documents/me` and `GET /api/documents/{employeeID}`.
class EmployeeDocumentsBundle {
  const EmployeeDocumentsBundle({
    this.employeeID,
    this.employeeName,
    this.hasNationalCard = false,
    this.hasResidence = false,
    this.hasPassport = false,
    this.allDocumentsComplete = false,
    this.nationalCard,
    this.residence,
    this.passport,
  });

  final String? employeeID;
  final String? employeeName;
  final bool hasNationalCard;
  final bool hasResidence;
  final bool hasPassport;
  final bool allDocumentsComplete;
  final NationalCardDocModel? nationalCard;
  final ResidenceDocModel? residence;
  final PassportDocModel? passport;

  int get completedCount =>
      (hasNationalCard ? 1 : 0) + (hasResidence ? 1 : 0) + (hasPassport ? 1 : 0);

  double get completionRatio => completedCount / 3.0;

  factory EmployeeDocumentsBundle.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    return EmployeeDocumentsBundle(
      employeeID: data['employeeID']?.toString() ?? data['employeeId']?.toString(),
      employeeName: data['employeeName']?.toString() ?? data['name']?.toString(),
      hasNationalCard: data['hasNationalCard'] as bool? ?? (data['nationalCard'] != null),
      hasResidence: data['hasResidence'] as bool? ?? (data['residence'] != null),
      hasPassport: data['hasPassport'] as bool? ?? (data['passport'] != null),
      allDocumentsComplete: data['allDocumentsComplete'] as bool? ?? false,
      nationalCard: data['nationalCard'] is Map<String, dynamic>
          ? NationalCardDocModel.fromJson(data['nationalCard'] as Map<String, dynamic>)
          : null,
      residence: data['residence'] is Map<String, dynamic>
          ? ResidenceDocModel.fromJson(data['residence'] as Map<String, dynamic>)
          : null,
      passport: data['passport'] is Map<String, dynamic>
          ? PassportDocModel.fromJson(data['passport'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeID': employeeID,
        'employeeName': employeeName,
        'hasNationalCard': hasNationalCard,
        'hasResidence': hasResidence,
        'hasPassport': hasPassport,
        'allDocumentsComplete': allDocumentsComplete,
        'nationalCard': nationalCard?.toJson(),
        'residence': residence?.toJson(),
        'passport': passport?.toJson(),
      };
}

/// Official National Card (البطاقة الوطنية الموحدة)
class NationalCardDocModel {
  const NationalCardDocModel({
    this.id,
    this.documentType = 'البطاقة الوطنية الموحدة',
    this.isElectronic = true,
    this.documentFormat = 'إلكتروني (شريحة ذكية)',
    this.documentNumber,
    this.nationalIdNumber,
    this.fullNameAr,
    this.firstNameEn,
    this.lastNameEn,
    this.fullNameEn,
    this.dateOfBirth,
    this.gender,
    this.nationality = 'عراقي',
    this.issuingState = 'IRQ',
    this.issueDate,
    this.expiryDate,
    this.rawMrz,
    this.hasFrontImage = false,
    this.frontImageUrl,
    this.hasBackImage = false,
    this.backImageUrl,
    this.hasBiometricFace = false,
    this.biometricFaceUrl,
  });

  final int? id;
  final String? documentType;
  final bool isElectronic;
  final String? documentFormat;
  final String? documentNumber;
  final String? nationalIdNumber;
  final String? fullNameAr;
  final String? firstNameEn;
  final String? lastNameEn;
  final String? fullNameEn;
  final String? dateOfBirth;
  final String? gender;
  final String? nationality;
  final String? issuingState;
  final String? issueDate;
  final String? expiryDate;
  final String? rawMrz;
  final bool hasFrontImage;
  final String? frontImageUrl;
  final bool hasBackImage;
  final String? backImageUrl;
  final bool hasBiometricFace;
  final String? biometricFaceUrl;

  factory NationalCardDocModel.fromJson(Map<String, dynamic> json) {
    return NationalCardDocModel(
      id: json['id'] as int?,
      documentType: json['documentType'] as String? ?? 'البطاقة الوطنية الموحدة',
      isElectronic: json['isElectronic'] as bool? ?? true,
      documentFormat: json['documentFormat'] as String?,
      documentNumber: json['documentNumber']?.toString(),
      nationalIdNumber: json['nationalIdNumber']?.toString(),
      fullNameAr: json['fullNameAr'] as String?,
      firstNameEn: json['firstNameEn'] as String?,
      lastNameEn: json['lastNameEn'] as String?,
      fullNameEn: json['fullNameEn'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      gender: json['gender'] as String?,
      nationality: json['nationality'] as String? ?? 'عراقي',
      issuingState: json['issuingState'] as String? ?? 'IRQ',
      issueDate: json['issueDate'] as String?,
      expiryDate: json['expiryDate'] as String?,
      rawMrz: json['rawMrz'] as String?,
      hasFrontImage: json['hasFrontImage'] as bool? ?? false,
      frontImageUrl: json['frontImageUrl'] as String?,
      hasBackImage: json['hasBackImage'] as bool? ?? false,
      backImageUrl: json['backImageUrl'] as String?,
      hasBiometricFace: json['hasBiometricFace'] as bool? ?? false,
      biometricFaceUrl: json['biometricFaceUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'documentType': documentType,
        'isElectronic': isElectronic,
        'documentFormat': documentFormat,
        'documentNumber': documentNumber,
        'nationalIdNumber': nationalIdNumber,
        'fullNameAr': fullNameAr,
        'firstNameEn': firstNameEn,
        'lastNameEn': lastNameEn,
        'fullNameEn': fullNameEn,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'nationality': nationality,
        'issuingState': issuingState,
        'issueDate': issueDate,
        'expiryDate': expiryDate,
        'rawMrz': rawMrz,
        'hasFrontImage': hasFrontImage,
        'frontImageUrl': frontImageUrl,
        'hasBackImage': hasBackImage,
        'backImageUrl': backImageUrl,
        'hasBiometricFace': hasBiometricFace,
        'biometricFaceUrl': biometricFaceUrl,
      };

  bool get isAvailable =>
      (documentNumber != null && documentNumber!.isNotEmpty) ||
      (nationalIdNumber != null && nationalIdNumber!.isNotEmpty) ||
      hasFrontImage ||
      hasBackImage ||
      hasBiometricFace;
}

/// Official Residence Card (بطاقة السكن)
class ResidenceDocModel {
  const ResidenceDocModel({
    this.id,
    this.documentType = 'بطاقة السكن',
    this.isElectronic = false,
    this.documentFormat = 'عادي (ورقي)',
    this.formNumber,
    this.formDate,
    this.informationOffice,
    this.familyHeadName,
    this.governorateId,
    this.governorate,
    this.district,
    this.mahalla,
    this.zuqaq,
    this.dar,
    this.housingType = 'ملك',
    this.complexName,
    this.buildingNumber,
    this.floorNumber,
    this.apartmentNumber,
    this.latitude,
    this.longitude,
    this.locationUrl,
    this.hasCardFront = false,
    this.cardFrontUrl,
    this.hasCardBack = false,
    this.cardBackUrl,
  });

  final int? id;
  final String? documentType;
  final bool isElectronic;
  final String? documentFormat;
  final String? formNumber;
  final String? formDate;
  final String? informationOffice;
  final String? familyHeadName;
  final int? governorateId;
  final String? governorate;
  final String? district;
  final String? mahalla;
  final String? zuqaq;
  final String? dar;
  final String? housingType;
  final String? complexName;
  final String? buildingNumber;
  final String? floorNumber;
  final String? apartmentNumber;
  final double? latitude;
  final double? longitude;
  final String? locationUrl;
  final bool hasCardFront;
  final String? cardFrontUrl;
  final bool hasCardBack;
  final String? cardBackUrl;

  factory ResidenceDocModel.fromJson(Map<String, dynamic> json) {
    double? parseCoord(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return ResidenceDocModel(
      id: json['id'] as int?,
      documentType: json['documentType'] as String? ?? 'بطاقة السكن',
      isElectronic: json['isElectronic'] as bool? ?? false,
      documentFormat: json['documentFormat'] as String? ?? 'عادي (ورقي)',
      formNumber: json['formNumber']?.toString(),
      formDate: json['formDate'] as String?,
      informationOffice: json['informationOffice'] as String?,
      familyHeadName: json['familyHeadName'] as String?,
      governorateId: json['governorateId'] as int?,
      governorate: json['governorate'] as String? ?? json['governorateName'] as String?,
      district: json['district'] as String?,
      mahalla: json['mahalla']?.toString(),
      zuqaq: json['zuqaq']?.toString(),
      dar: json['dar']?.toString(),
      housingType: json['housingType'] as String? ?? 'ملك',
      complexName: json['complexName'] as String?,
      buildingNumber: json['buildingNumber']?.toString(),
      floorNumber: json['floorNumber']?.toString(),
      apartmentNumber: json['apartmentNumber']?.toString(),
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
      locationUrl: json['locationUrl'] as String?,
      hasCardFront: json['hasCardFront'] as bool? ?? false,
      cardFrontUrl: json['cardFrontUrl'] as String?,
      hasCardBack: json['hasCardBack'] as bool? ?? false,
      cardBackUrl: json['cardBackUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'documentType': documentType,
        'isElectronic': isElectronic,
        'documentFormat': documentFormat,
        'formNumber': formNumber,
        'formDate': formDate,
        'informationOffice': informationOffice,
        'familyHeadName': familyHeadName,
        'governorateId': governorateId,
        'governorate': governorate,
        'district': district,
        'mahalla': mahalla,
        'zuqaq': zuqaq,
        'dar': dar,
        'housingType': housingType,
        'complexName': complexName,
        'buildingNumber': buildingNumber,
        'floorNumber': floorNumber,
        'apartmentNumber': apartmentNumber,
        'latitude': latitude,
        'longitude': longitude,
        'locationUrl': locationUrl,
        'hasCardFront': hasCardFront,
        'cardFrontUrl': cardFrontUrl,
        'hasCardBack': hasCardBack,
        'cardBackUrl': cardBackUrl,
      };

  bool get isAvailable =>
      (formNumber != null && formNumber!.isNotEmpty) ||
      hasCardFront ||
      hasCardBack;
}

/// Official Passport (جواز السفر - إلكتروني أو عادي)
class PassportDocModel {
  const PassportDocModel({
    this.id,
    this.documentType = 'جواز السفر',
    this.isElectronic = true,
    this.passportCategory = 'إلكتروني',
    this.passportType = 'عادي (P)',
    this.passportNumber,
    this.countryCode = 'IRQ',
    this.issuingCountry = 'العراق',
    this.issuingAuthority = 'مديرية شؤون الجوازات',
    this.nationalIdNumber,
    this.fullNameAr,
    this.fullNameEn,
    this.motherName,
    this.placeOfBirth,
    this.dateOfBirth,
    this.gender,
    this.issueDate,
    this.expiryDate,
    this.rawMrz,
    this.hasImage = false,
    this.imageUrl,
    this.hasBioPhoto = false,
    this.biometricPhotoUrl,
    this.notes,
  });

  final int? id;
  final String? documentType;
  final bool isElectronic;
  final String? passportCategory;
  final String? passportType;
  final String? passportNumber;
  final String? countryCode;
  final String? issuingCountry;
  final String? issuingAuthority;
  final String? nationalIdNumber;
  final String? fullNameAr;
  final String? fullNameEn;
  final String? motherName;
  final String? placeOfBirth;
  final String? dateOfBirth;
  final String? gender;
  final String? issueDate;
  final String? expiryDate;
  final String? rawMrz;
  final bool hasImage;
  final String? imageUrl;
  final bool hasBioPhoto;
  final String? biometricPhotoUrl;
  final String? notes;

  factory PassportDocModel.fromJson(Map<String, dynamic> json) {
    return PassportDocModel(
      id: json['id'] as int?,
      documentType: json['documentType'] as String? ?? 'جواز السفر',
      isElectronic: json['isElectronic'] as bool? ?? (json['passportCategory'] == 'إلكتروني'),
      passportCategory: json['passportCategory'] as String? ??
          (json['isElectronic'] == true ? 'إلكتروني' : 'عادي'),
      passportType: json['passportType'] as String? ?? 'عادي (P)',
      passportNumber: json['passportNumber']?.toString(),
      countryCode: json['countryCode'] as String? ?? 'IRQ',
      issuingCountry: json['issuingCountry'] as String? ?? 'العراق',
      issuingAuthority: json['issuingAuthority'] as String? ?? 'مديرية شؤون الجوازات',
      nationalIdNumber: json['nationalIdNumber']?.toString(),
      fullNameAr: json['fullNameAr'] as String?,
      fullNameEn: json['fullNameEn'] as String?,
      motherName: json['motherName'] as String?,
      placeOfBirth: json['placeOfBirth'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      gender: json['gender'] as String?,
      issueDate: json['issueDate'] as String?,
      expiryDate: json['expiryDate'] as String?,
      rawMrz: json['rawMrz'] as String?,
      hasImage: json['hasImage'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      hasBioPhoto: json['hasBioPhoto'] as bool? ?? false,
      biometricPhotoUrl: json['biometricPhotoUrl'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'documentType': documentType,
        'isElectronic': isElectronic,
        'passportCategory': passportCategory,
        'passportType': passportType,
        'passportNumber': passportNumber,
        'countryCode': countryCode,
        'issuingCountry': issuingCountry,
        'issuingAuthority': issuingAuthority,
        'nationalIdNumber': nationalIdNumber,
        'fullNameAr': fullNameAr,
        'fullNameEn': fullNameEn,
        'motherName': motherName,
        'placeOfBirth': placeOfBirth,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'issueDate': issueDate,
        'expiryDate': expiryDate,
        'rawMrz': rawMrz,
        'hasImage': hasImage,
        'imageUrl': imageUrl,
        'hasBioPhoto': hasBioPhoto,
        'biometricPhotoUrl': biometricPhotoUrl,
        'notes': notes,
      };

  bool get isAvailable =>
      (passportNumber != null && passportNumber!.isNotEmpty) ||
      hasImage ||
      hasBioPhoto;
}
