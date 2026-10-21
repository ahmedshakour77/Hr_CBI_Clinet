import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/hr_api_client.dart';
import '../id_reader/domain/entities/id_card_model.dart';
import '../models/document_models.dart';
import '../models/employee_profile.dart';
import '../services/device_info_service.dart';
import 'auth_exception.dart';
import 'microsoft_sign_in.dart';
import 'passkey_sign_in.dart';
import 'session_store.dart';

enum AuthStatus {
  restoring,
  signedOut,
  signedIn,
}

class AuthController extends ChangeNotifier {
  AuthController({
    HrApiClient? api,
    SessionStore? sessionStore,
    MicrosoftSignIn? microsoft,
    PasskeySignIn? passkey,
  }) : _api = api ?? HrApiClient(),
       _sessions = sessionStore ?? SessionStore(),
       _microsoft = microsoft ?? const MicrosoftSignIn() {
    _passkey = passkey ?? PasskeySignIn(api: _api);
  }

  final HrApiClient _api;
  final SessionStore _sessions;
  final MicrosoftSignIn _microsoft;
  late final PasskeySignIn _passkey;

  AuthStatus _status = AuthStatus.restoring;
  EmployeeProfile? _profile;
  Uint8List? _profilePhotoBytes;
  List<Map<String, dynamic>> _myPasskeys = [];
  bool _loadingPasskeys = false;
  String? _errorMessage;
  bool _busy = false;
  bool _justSignedIn = false;

  List<Map<String, dynamic>> _dynamicServices = [];
  bool _loadingServices = false;

  EmployeeDocumentsBundle? _myDocuments;
  bool _loadingDocuments = false;

  AuthStatus get status => _status;
  EmployeeProfile? get profile => _profile;
  Uint8List? get profilePhotoBytes => _profilePhotoBytes;
  List<Map<String, dynamic>> get myPasskeys => _myPasskeys;
  bool get loadingPasskeys => _loadingPasskeys;
  List<Map<String, dynamic>> get dynamicServices => _dynamicServices;
  bool get loadingServices => _loadingServices;
  EmployeeDocumentsBundle? get myDocuments => _myDocuments;
  bool get loadingDocuments => _loadingDocuments;

  HrApiClient get api => _api;
  SessionStore get sessions => _sessions;
  Future<String?> getAccessToken() => _sessions.readAccessToken();

  bool get isAdmin => _profile?.isAdmin ?? false;

  bool get justSignedIn => _justSignedIn;
  void clearJustSignedIn() => _justSignedIn = false;

  String? get errorMessage => _errorMessage;
  bool get busy => _busy;
  bool get microsoftAvailable => MicrosoftSignIn.isSupported;
  Future<String?> getLastEmployeeId() => _sessions.readLastEmployeeId();

  Future<void> restore() async {
    debugPrint('[AUTH_CONTROLLER] Restoring session from local storage...');
    final token = await _sessions.readAccessToken();

    if (token != null) {
      try {
        final profile = await _api.fetchProfile(token);
        final idToken = await _sessions.readIdToken();
        final payload = idToken != null ? _decodeJwt(idToken) : <String, dynamic>{};
        _profile = profile.copyWith(
          microsoftId: profile.microsoftId ?? payload['sub']?.toString(),
          email: profile.email ?? (payload['preferred_username'] ?? payload['email'])?.toString(),
          signedInWith: idToken != null ? 'microsoft' : 'passkey',
        );
        debugPrint('[AUTH_CONTROLLER] Stored session restored for: ${_profile?.fullName}');
        if (_profile?.employeeID != null) {
          await _sessions.saveLastEmployeeId(_profile!.employeeID!);
        }
        _loadPhotoIfAvailable(token, _profile!);
        await loadMyPasskeys();
        loadMyDocuments();
        _set(status: AuthStatus.signedIn);
        return;
      } catch (e) {
        debugPrint('[AUTH_CONTROLLER] Session token validation failed: $e');
      }
    }

    final microsoftRefreshToken = await _sessions.readMicrosoftRefreshToken();
    if (microsoftRefreshToken != null && MicrosoftSignIn.isSupported) {
      debugPrint('[AUTH_CONTROLLER] Attempting silent Microsoft refresh...');
      final idToken = await _microsoft.refresh(microsoftRefreshToken);
      if (idToken != null) {
        try {
          final payload = _decodeJwt(idToken);
          final email = (payload['preferred_username'] ?? payload['email'] ?? payload['upn'])?.toString();
          final serverAuth = await _api.exchangeMicrosoftIdToken(
            idToken: idToken,
            email: email,
          );
          final profile = await _api.fetchProfile(serverAuth.accessToken);
          _profile = profile.copyWith(
            microsoftId: profile.microsoftId ?? payload['sub']?.toString(),
            email: profile.email ?? email,
            signedInWith: 'microsoft',
          );
          await _sessions.saveSession(
            accessToken: serverAuth.accessToken,
            microsoftRefreshToken: microsoftRefreshToken,
            backendRefreshToken: serverAuth.refreshToken,
            idToken: idToken,
            employeeId: _profile?.employeeID,
          );
          _loadPhotoIfAvailable(serverAuth.accessToken, _profile!);
          await loadMyPasskeys();
          loadMyDocuments();
          _set(status: AuthStatus.signedIn);
          return;
        } catch (e) {
          debugPrint('[AUTH_CONTROLLER] Silent refresh token exchange failed: $e');
        }
      }
    }

    debugPrint('[AUTH_CONTROLLER] No valid session found. Presenting login screen.');
    await _sessions.clear();
    _set(status: AuthStatus.signedOut);
  }

  Future<void> refreshProfile() async {
    final token = await _sessions.readAccessToken();
    if (token == null) return;
    try {
      final refreshed = await _api.fetchProfile(token);
      _profile = refreshed.copyWith(
        microsoftId: _profile?.microsoftId,
        email: refreshed.email ?? _profile?.email,
        signedInWith: _profile?.signedInWith,
      );
      if (_profile?.employeeID != null) {
        await _sessions.saveLastEmployeeId(_profile!.employeeID!);
      }
      await _loadPhotoIfAvailable(token, _profile!);
      await loadMyPasskeys();
      await loadMyDocuments();
      notifyListeners();
    } catch (e) {
      debugPrint('[AUTH_CONTROLLER] Refresh error: $e');
    }
  }

  Future<void> signInWithMicrosoft() => _guard(() async {
    final tokens = await _microsoft.signIn();

    final payload = _decodeJwt(tokens.idToken);
    final email = (payload['preferred_username'] ?? payload['email'] ?? payload['upn'])?.toString();
    debugPrint('==================================================');
    debugPrint('=== MICROSOFT SIGN-IN SUCCESSFUL ===');
    debugPrint('Email extracted: $email');
    debugPrint('==================================================');

    final deviceInfo = await DeviceInfoService.getDeviceInfo();
    debugPrint('[AUTH_CONTROLLER] Device Info: $deviceInfo');

    debugPrint('[AUTH_CONTROLLER] Calling POST /api/auth/microsoft-login ...');
    final serverAuth = await _api.exchangeMicrosoftIdToken(
      idToken: tokens.idToken,
      email: email,
      deviceInfo: deviceInfo,
    );
    debugPrint('[AUTH_CONTROLLER] API Token Exchange successful!');

    debugPrint('[AUTH_CONTROLLER] Calling GET /api/employees/me ...');
    try {
      final remoteProfile = await _api.fetchProfile(serverAuth.accessToken);
      _profile = remoteProfile.copyWith(
        microsoftId: remoteProfile.microsoftId ?? payload['sub']?.toString(),
        email: remoteProfile.email ?? email,
        signedInWith: 'microsoft',
      );
      debugPrint('[AUTH_CONTROLLER] Employee Profile Loaded: ${_profile?.fullName} (${_profile?.jobTitle})');
    } catch (e) {
      debugPrint('[AUTH_CONTROLLER] Failed to load employee profile: $e');
      await _sessions.clear();
      if (e is AuthException) rethrow;
      throw AuthException(
        'عذراً، هذا الحساب غير مربوط بملف موظف في النظام. يرجى مراجعة إدارة الموارد البشرية.',
        cause: e,
      );
    }

    _loadPhotoIfAvailable(serverAuth.accessToken, _profile!);

    await _sessions.saveSession(
      accessToken: serverAuth.accessToken,
      microsoftRefreshToken: tokens.refreshToken,
      backendRefreshToken: serverAuth.refreshToken,
      idToken: tokens.idToken,
      employeeId: _profile?.employeeID,
    );

    await loadMyPasskeys();
    _justSignedIn = true;
    _set(status: AuthStatus.signedIn);
  });

  Future<void> _loadPhotoIfAvailable(String token, EmployeeProfile profile) async {
    if (profile.hasProfilePhoto && profile.employeeID != null) {
      try {
        final bytes = await _api.fetchProfilePhoto(
          token,
          profile.employeeID!,
          version: profile.profilePhotoVersion,
        );
        if (bytes != null && bytes.isNotEmpty) {
          _profilePhotoBytes = bytes;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[AUTH_CONTROLLER] Notice loading photo: $e');
      }
    }
  }

  Future<void> signInWithPasskey({String? employeeID}) => _guard(() async {
    var empId = employeeID?.trim();
    if (empId == null || empId.isEmpty) {
      empId = await _sessions.readLastEmployeeId();
    }
    if (empId == null || empId.isEmpty) {
      throw const AuthException(
        'يرجى تسجيل الدخول عبر مايكروسوفت أولاً لتفعيل البصمة على هذا الجهاز.',
      );
    }

    final deviceInfo = await DeviceInfoService.getDeviceInfo();

    try {
      final serverAuth = await _passkey.signIn(
        employeeID: empId,
        deviceInfo: deviceInfo,
      );

      final profile = await _api.fetchProfile(serverAuth.accessToken);
      _profile = profile.copyWith(signedInWith: 'passkey');

      await _sessions.saveSession(
        accessToken: serverAuth.accessToken,
        backendRefreshToken: serverAuth.refreshToken,
        employeeId: profile.employeeID ?? empId,
        clearMicrosoftTokens: true,
      );

      _loadPhotoIfAvailable(serverAuth.accessToken, _profile!);
      await loadMyPasskeys();
      _set(status: AuthStatus.signedIn);
    } on AuthException catch (e) {
      debugPrint('[AUTH_CONTROLLER] Passkey sign-in failed: ${e.message}');
      rethrow;
    }
  });

  Future<void> addPasskey() => _guard(() async {
    final token = await _sessions.readAccessToken();
    if (token == null) {
      throw const AuthException('يجب تسجيل الدخول أولاً لإضافة مفتاح مرور.');
    }

    final deviceInfo = await DeviceInfoService.getDeviceInfo();
    final model = deviceInfo['model'] ?? deviceInfo['deviceName'] ?? 'الهاتف الذكي';
    final deviceName = '$model (Biometric)';

    await _passkey.register(
      sessionToken: token,
      deviceName: deviceName,
    );

    if (_profile?.employeeID != null) {
      await _sessions.saveLastEmployeeId(_profile!.employeeID!);
    }

    final updatedProfile = await _api.fetchProfile(token);
    _profile = updatedProfile.copyWith(
      signedInWith: _profile?.signedInWith,
    );

    await loadMyPasskeys();
    notifyListeners();
  });

  bool _isPasskeyActive(Map<String, dynamic> passkey) {
    final status = passkey['status']?.toString().trim().toLowerCase();
    return passkey['isActive'] != false &&
        passkey['isBlocked'] != true &&
        passkey['isFrozen'] != true &&
        status != 'inactive' &&
        status != 'frozen' &&
        status != 'blocked' &&
        status != 'disabled' &&
        status != 'revoked';
  }

  Future<void> loadMyPasskeys() async {
    final token = await _sessions.readAccessToken();
    if (token == null) return;
    _loadingPasskeys = true;
    notifyListeners();
    try {
      _myPasskeys = await _api.getMyPasskeys(token);
      final hasActivePasskey = _myPasskeys.any(_isPasskeyActive);
      if (_profile != null && _profile!.hasPasskey != hasActivePasskey) {
        _profile = _profile!.copyWith(hasPasskey: hasActivePasskey);
      }
    } catch (e) {
      debugPrint('[AUTH_CONTROLLER] Error loading passkeys list: $e');
    } finally {
      _loadingPasskeys = false;
      notifyListeners();
    }
  }

  Future<void> deletePasskey(dynamic passkeyId, {bool permanent = false}) => _guard(() async {
    final token = await _sessions.readAccessToken();
    if (token == null) return;
    await _api.deletePasskey(
      sessionToken: token,
      passkeyId: passkeyId,
      permanent: permanent,
    );
    await loadMyPasskeys();
    notifyListeners();
  });

  Future<void> loadDynamicServices() async {
    final token = await _sessions.readAccessToken();
    if (token == null) return;
    _loadingServices = true;
    notifyListeners();
    try {
      _dynamicServices = await _api.fetchServices(token);
    } catch (e) {
      debugPrint('[AUTH_CONTROLLER] Error loading dynamic services: $e');
    } finally {
      _loadingServices = false;
      notifyListeners();
    }
  }

  Future<List<EmployeeProfile>> fetchAllEmployees({
    void Function(int loadedCount, int? totalCount)? onProgress,
  }) async {
    final token = await _sessions.readAccessToken();
    if (token == null) {
      throw const AuthException('جلسة العمل غير صالحة. يرجى تسجيل الدخول مجدداً.');
    }
    return await _api.fetchAllEmployees(token, onProgress: onProgress);
  }

  Future<EmployeeProfile> fetchEmployeeDetails(String idOrNumber) async {
    final token = await _sessions.readAccessToken();
    if (token == null) {
      throw const AuthException('جلسة العمل غير صالحة. يرجى تسجيل الدخول مجدداً.');
    }
    return await _api.fetchEmployeeDetails(token, idOrNumber);
  }

  Future<Map<String, dynamic>> updateNationalCard({
    required IdCardModel idCard,
    String? targetEmployeeId,
  }) async {
    final token = await _sessions.readAccessToken();
    if (token == null) {
      throw const AuthException('جلسة العمل غير صالحة. يرجى تسجيل الدخول مجدداً.');
    }
    final clean = targetEmployeeId?.trim();
    final effectiveEmpId = (clean != null && clean.isNotEmpty && clean.toLowerCase() != 'me')
        ? clean
        : null;

    if (idCard.isPassport) {
      try {
        final payload = idCard.toPassportApiPayload(employeeId: effectiveEmpId);
        final res = await _api.savePassport(sessionToken: token, payload: payload);
        await loadMyDocuments();
        return res;
      } catch (e) {
        debugPrint('[AUTH_CONTROLLER] Notice: /api/documents/passport fallback: $e');
        if (effectiveEmpId == null) {
          final res = await _api.updateMyNationalCard(sessionToken: token, idCard: idCard);
          await loadMyDocuments();
          return res;
        }
        return await _api.updateEmployeeNationalCard(
          sessionToken: token,
          employeeIdOrNumber: effectiveEmpId,
          idCard: idCard,
        );
      }
    } else {
      try {
        final payload = idCard.toNationalCardApiPayload(employeeId: effectiveEmpId);
        final res = await _api.saveNationalCard(sessionToken: token, payload: payload);
        await loadMyDocuments();
        return res;
      } catch (e) {
        debugPrint('[AUTH_CONTROLLER] Notice: /api/documents/national-card fallback: $e');
        if (effectiveEmpId == null) {
          final res = await _api.updateMyNationalCard(sessionToken: token, idCard: idCard);
          await loadMyDocuments();
          return res;
        }
        return await _api.updateEmployeeNationalCard(
          sessionToken: token,
          employeeIdOrNumber: effectiveEmpId,
          idCard: idCard,
        );
      }
    }
  }

  Future<void> loadMyDocuments() async {
    final token = await _sessions.readAccessToken();
    if (token == null) return;
    _loadingDocuments = true;
    notifyListeners();
    try {
      _myDocuments = await _api.getMyDocuments(token);
    } catch (e) {
      debugPrint('[AUTH_CONTROLLER] Notice: Could not load documents from server: $e');
    } finally {
      _loadingDocuments = false;
      notifyListeners();
    }
  }

  Future<EmployeeDocumentsBundle?> fetchEmployeeDocuments(String employeeId) async {
    final token = await _sessions.readAccessToken();
    if (token == null) return null;
    try {
      return await _api.getEmployeeDocuments(token, employeeId);
    } catch (e) {
      debugPrint('[AUTH_CONTROLLER] Error fetching employee documents: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> savePassport({
    required Map<String, dynamic> payload,
    String? targetEmployeeId,
  }) async {
    final token = await _sessions.readAccessToken();
    if (token == null) throw const AuthException('جلسة العمل غير صالحة. يرجى تسجيل الدخول مجدداً.');
    final finalPayload = Map<String, dynamic>.from(payload);
    final clean = targetEmployeeId?.trim();
    if (clean != null && clean.isNotEmpty && clean.toLowerCase() != 'me') {
      finalPayload['employeeID'] = clean;
    }
    final res = await _api.savePassport(sessionToken: token, payload: finalPayload);
    await loadMyDocuments();
    return res;
  }

  Future<Map<String, dynamic>> saveResidence({
    required Map<String, dynamic> payload,
    String? targetEmployeeId,
  }) async {
    final token = await _sessions.readAccessToken();
    if (token == null) throw const AuthException('جلسة العمل غير صالحة. يرجى تسجيل الدخول مجدداً.');
    final finalPayload = Map<String, dynamic>.from(payload);
    final clean = targetEmployeeId?.trim();
    if (clean != null && clean.isNotEmpty && clean.toLowerCase() != 'me') {
      finalPayload['employeeID'] = clean;
    }
    final res = await _api.saveResidence(sessionToken: token, payload: finalPayload);
    await loadMyDocuments();
    return res;
  }

  Future<Map<String, dynamic>> saveNationalCard({
    required Map<String, dynamic> payload,
    String? targetEmployeeId,
  }) async {
    final token = await _sessions.readAccessToken();
    if (token == null) throw const AuthException('جلسة العمل غير صالحة. يرجى تسجيل الدخول مجدداً.');
    final finalPayload = Map<String, dynamic>.from(payload);
    final clean = targetEmployeeId?.trim();
    if (clean != null && clean.isNotEmpty && clean.toLowerCase() != 'me') {
      finalPayload['employeeID'] = clean;
    }
    final res = await _api.saveNationalCard(sessionToken: token, payload: finalPayload);
    await loadMyDocuments();
    return res;
  }

  Future<Uint8List?> fetchDocumentImage(String relativeOrAbsoluteUrl) async {
    final token = await _sessions.readAccessToken();
    if (token == null) return null;
    return await _api.getAuthenticatedImageBytes(token, relativeOrAbsoluteUrl);
  }

  Future<void> signOut() async {
    final idToken = await _sessions.readIdToken();
    await _sessions.clear();
    _profile = null;
    _profilePhotoBytes = null;
    _myPasskeys = [];
    _justSignedIn = false;
    _set(status: AuthStatus.signedOut);
    await _microsoft.signOut(idToken);
  }

  void clearError() => _set(error: null);

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(payloadString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to decode JWT: $e');
      return {};
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    _set(busy: true, error: null);
    try {
      await action();
    } on AuthException catch (error) {
      debugPrint('AuthException in _guard: ${error.message}, cause: ${error.cause}');
      _set(error: error.isCancellation ? null : error.message);
    } catch (error) {
      debugPrint('Unexpected failure in _guard: $error');
      _set(error: 'فشل التوثيق: $error');
    } finally {
      _set(busy: false);
    }
  }

  void _set({AuthStatus? status, bool? busy, Object? error = _unset}) {
    if (status != null && status != _status) {
      debugPrint('[AUTH_CONTROLLER] Status: ${_status.name} -> ${status.name}');
      _status = status;
    }
    if (busy != null) _busy = busy;
    if (!identical(error, _unset)) {
      _errorMessage = error as String?;
      if (_errorMessage != null) {
        debugPrint('[AUTH_CONTROLLER] Error Set: "$_errorMessage"');
      }
    }
    notifyListeners();
  }

  static const _unset = Object();

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
