/// Model representing the full employee record from `/api/employees/me`.
class EmployeeProfile {
  const EmployeeProfile({
    this.employeeID,
    this.name,
    this.formation,
    this.firstDepartment,
    this.jobTitle,
    this.positionTitle,
    this.stage,
    this.grade,
    this.educationLevel,
    this.specialization,
    this.lastJobTitleDate,
    this.hireDate,
    this.gender,
    this.religion,
    this.nationality,
    this.birthDate,
    this.employeeStatus,
    this.serviceStatus,
    this.hasProfilePhoto = false,
    this.profilePhotoVersion,
    this.email,
    this.phoneNumber,
    this.administrativeUnit,
    this.microsoftId,
    this.hasPasskey = false,
    this.signedInWith,
    this.roles = const [],
    this.permissions = const [],
    this.rawJson,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> rawJson) {
    final json = (rawJson['data'] is Map<String, dynamic>)
        ? rawJson['data'] as Map<String, dynamic>
        : (rawJson['employee'] is Map<String, dynamic>)
            ? rawJson['employee'] as Map<String, dynamic>
            : (rawJson['result'] is Map<String, dynamic>)
                ? rawJson['result'] as Map<String, dynamic>
                : rawJson;

    String? getString(List<String> keys) {
      for (final key in keys) {
        if (!json.containsKey(key)) continue;
        final val = json[key];
        if (val == null) continue;
        if (val is String && val.trim().isNotEmpty) return val.trim();
        if (val is num || val is bool) return val.toString();
        if (val is Map) {
          for (final sub in ['name', 'title', 'nameAr', 'arName', 'value', 'id']) {
            final subVal = val[sub];
            if (subVal != null && subVal.toString().trim().isNotEmpty) {
              return subVal.toString().trim();
            }
          }
        }
      }
      return null;
    }

    DateTime? getDate(List<String> keys) {
      for (final key in keys) {
        if (!json.containsKey(key)) continue;
        final val = json[key];
        if (val == null) continue;
        if (val is String && val.trim().isNotEmpty) {
          final parsed = DateTime.tryParse(val.trim());
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    int? getInt(List<String> keys) {
      for (final key in keys) {
        if (!json.containsKey(key)) continue;
        final val = json[key];
        if (val == null) continue;
        if (val is int) return val;
        if (val is num) return val.toInt();
        if (val is String) return int.tryParse(val.trim());
      }
      return null;
    }

    bool getBool(List<String> keys) {
      for (final key in keys) {
        if (!json.containsKey(key)) continue;
        final val = json[key];
        if (val == null) continue;
        if (val is bool) return val;
        if (val is String) return val.trim().toLowerCase() == 'true' || val.trim() == '1';
        if (val is num) return val == 1;
      }
      return false;
    }

    return EmployeeProfile(
      employeeID: getString([
        'employeeID',
        'employeeId',
        'employeeNumber',
        'empId',
        'empNumber',
        'badgeNumber',
        'id',
        'code',
      ]),
      name: getString([
        'name',
        'fullName',
        'displayName',
        'employeeName',
        'arabicName',
      ]),
      formation: getString([
        'formation',
        'department',
        'departmentName',
        'directorate',
        'generalDepartment',
      ]),
      firstDepartment: getString([
        'firstDepartment',
        'section',
        'division',
        'unit',
        'departmentSection',
      ]),
      jobTitle: getString(['jobTitle', 'job_title', 'title']),
      positionTitle: getString([
        'positionTitle',
        'position',
        'role',
        'positionName',
      ]),
      stage: getString(['stage', 'stageName', 'step']),
      grade: getString(['grade', 'gradeName', 'rank']),
      educationLevel: getString([
        'educationLevel',
        'qualification',
        'degree',
        'education',
      ]),
      specialization: getString([
        'specialization',
        'major',
        'specialty',
        'fieldOfStudy',
      ]),
      lastJobTitleDate: getDate(['lastJobTitleDate', 'lastPromotionDate']),
      hireDate: getDate([
        'hireDate',
        'hire_date',
        'appointmentDate',
        'joiningDate',
        'startDate',
      ]),
      gender: getString(['gender', 'sex']),
      religion: getString(['religion']),
      nationality: getString(['nationality', 'citizenship']),
      birthDate: getDate(['birthDate', 'birth_date', 'dateOfBirth', 'dob']),
      employeeStatus: getString([
        'employeeStatus',
        'status',
        'employmentStatus',
        'state',
      ]),
      serviceStatus: getString(['serviceStatus', 'service_status', 'employmentStatus', 'status']),
      hasProfilePhoto: getBool(['hasProfilePhoto', 'hasPhoto']),
      profilePhotoVersion: getInt(['profilePhotoVersion', 'photoVersion', 'v']),
      email: getString([
        'email',
        'workEmail',
        'userEmail',
        'upn',
        'preferred_username',
      ]),
      phoneNumber: getString(['phoneNumber', 'phone', 'mobile']),
      administrativeUnit: getString(['administrativeUnit', 'unit', 'section', 'division']),
      microsoftId: getString(['microsoftId', 'sub', 'oid']),
      hasPasskey: json['hasPasskey'] as bool? ?? false,
      signedInWith: json['signedInWith'] as String?,
      roles: (json['roles'] is List)
          ? (json['roles'] as List).map((e) => e.toString()).toList()
          : (json['role'] != null ? [json['role'].toString()] : const []),
      permissions: (json['permissions'] is List)
          ? (json['permissions'] as List).map((e) => e.toString()).toList()
          : const [],
      rawJson: json,
    );
  }

  final String? employeeID;
  final String? name;
  final String? formation;
  final String? firstDepartment;
  final String? jobTitle;
  final String? positionTitle;
  final String? stage;
  final String? grade;
  final String? educationLevel;
  final String? specialization;
  final DateTime? lastJobTitleDate;
  final DateTime? hireDate;
  final String? gender;
  final String? religion;
  final String? nationality;
  final DateTime? birthDate;
  final String? employeeStatus;
  final String? serviceStatus;
  final bool hasProfilePhoto;
  final int? profilePhotoVersion;
  final String? email;
  final String? phoneNumber;
  final String? administrativeUnit;
  final String? microsoftId;
  final bool hasPasskey;
  final String? signedInWith;
  final List<String> roles;
  final List<String> permissions;
  final Map<String, dynamic>? rawJson;

  /// Compatibility aliases
  String? get fullName => name;
  String? get employeeId => employeeID;
  String? get department => formation;
  String? get section => administrativeUnit ?? firstDepartment;
  String? get position => positionTitle ?? jobTitle;
  String? get status => serviceStatus ?? employeeStatus;

  /// True if the employee holds HR administrator privileges
  bool get isAdmin {
    if (rawJson != null) {
      if (rawJson!['isAdmin'] == true ||
          rawJson!['is_admin'] == true ||
          rawJson!['isHR'] == true ||
          rawJson!['is_hr'] == true) {
        return true;
      }
    }

    if (roles.any((r) =>
        r.toLowerCase().contains('admin') ||
        r.toLowerCase().contains('hr') ||
        r.toLowerCase().contains('manager') ||
        r.toLowerCase().contains('staff'))) {
      return true;
    }

    if (permissions.contains('VIEW_ALL_EMPLOYEES') ||
        permissions.contains('MANAGE_DOCUMENTS') ||
        permissions.contains('VERIFY_DOCUMENTS')) {
      return true;
    }

    final title = (positionTitle ?? jobTitle ?? '').toLowerCase();
    if (title.contains('admin') ||
        title.contains('hr') ||
        title.contains('مدير') ||
        title.contains('مسؤول') ||
        title.contains('موارد بشرية') ||
        title.contains('تقنية المعلومات') ||
        title.contains('it')) {
      return true;
    }

    return false;
  }

  EmployeeProfile copyWith({
    String? employeeID,
    String? name,
    String? formation,
    String? firstDepartment,
    String? jobTitle,
    String? positionTitle,
    String? stage,
    String? grade,
    String? educationLevel,
    String? specialization,
    DateTime? lastJobTitleDate,
    DateTime? hireDate,
    String? gender,
    String? religion,
    String? nationality,
    DateTime? birthDate,
    String? employeeStatus,
    bool? hasProfilePhoto,
    int? profilePhotoVersion,
    String? email,
    String? microsoftId,
    bool? hasPasskey,
    String? signedInWith,
    Map<String, dynamic>? rawJson,
  }) {
    return EmployeeProfile(
      employeeID: employeeID ?? this.employeeID,
      name: name ?? this.name,
      formation: formation ?? this.formation,
      firstDepartment: firstDepartment ?? this.firstDepartment,
      jobTitle: jobTitle ?? this.jobTitle,
      positionTitle: positionTitle ?? this.positionTitle,
      stage: stage ?? this.stage,
      grade: grade ?? this.grade,
      educationLevel: educationLevel ?? this.educationLevel,
      specialization: specialization ?? this.specialization,
      lastJobTitleDate: lastJobTitleDate ?? this.lastJobTitleDate,
      hireDate: hireDate ?? this.hireDate,
      gender: gender ?? this.gender,
      religion: religion ?? this.religion,
      nationality: nationality ?? this.nationality,
      birthDate: birthDate ?? this.birthDate,
      employeeStatus: employeeStatus ?? this.employeeStatus,
      hasProfilePhoto: hasProfilePhoto ?? this.hasProfilePhoto,
      profilePhotoVersion: profilePhotoVersion ?? this.profilePhotoVersion,
      email: email ?? this.email,
      microsoftId: microsoftId ?? this.microsoftId,
      hasPasskey: hasPasskey ?? this.hasPasskey,
      signedInWith: signedInWith ?? this.signedInWith,
      rawJson: rawJson ?? this.rawJson,
    );
  }

  /// Age in whole years, or null when no birth date is on file.
  int? get age => _wholeYearsSince(birthDate);

  /// Completed years of service, or null when no hire date is on file.
  int? get yearsOfService => _wholeYearsSince(hireDate);

  static int? _wholeYearsSince(DateTime? start, {DateTime? now}) {
    if (start == null) return null;
    final today = now ?? DateTime.now();
    if (start.isAfter(today)) return null;

    var years = today.year - start.year;
    final hasHadAnniversary =
        today.month > start.month ||
        (today.month == start.month && today.day >= start.day);
    if (!hasHadAnniversary) years -= 1;
    return years < 0 ? null : years;
  }

  static int? wholeYearsSince(DateTime? start, DateTime now) =>
      _wholeYearsSince(start, now: now);
}
