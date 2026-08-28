import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/hr_api_client.dart';
import '../models/employee_profile.dart';
import '../services/device_info_service.dart';
import 'auth_exception.dart';
import 'microsoft_sign_in.dart';
import 'passkey_sign_in.dart';
import 'session_store.dart';

enum AuthStatus {
  /// Still deciding whether a stored session is usable.
  restoring,
  signedOut,
  signedIn,
}

/// Single source of truth for authentication state, user profile, and passkey management.
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

  AuthStatus get status => _status;
  EmployeeProfile? get profile => _profile;
  Uint8List? get profilePhotoBytes => _profilePhotoBytes;
  List<Map<String, dynamic>> get myPasskeys => _myPasskeys;
  bool get loadingPasskeys => _loadingPasskeys;
  List<Map<String, dynamic>> get dynamicServices => _dynamicServices;
  bool get loadingServices => _loadingServices;

  /// True immediately after an interactive Microsoft login (used to prompt automatic Passkey setup).
  bool get justSignedIn => _justSignedIn;
  void clearJustSignedIn() => _justSignedIn = false;

  /// Non-null when the last action failed for a reason worth showing.
  String? get errorMessage => _errorMessage;

  /// True while a sign-in or action is in flight.
  bool get busy => _busy;

  bool get microsoftAvailable => MicrosoftSignIn.isSupported;

  /// Get the last remembered employee ID on this device.
  Future<String?> getLastEmployeeId() => _sessions.readLastEmployeeId();

  /// Reattaches to a stored session on launch, checking `/api/employees/me`.
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
          signedInWith: 'microsoft',
        );
        debugPrint('[AUTH_CONTROLLER] Stored session restored for: ${_profile?.fullName}');
        if (_profile?.employeeID != null) {
          await _sessions.saveLastEmployeeId(_profile!.employeeID!);
        }
        _loadPhotoIfAvailable(token, _profile!);
        await loadMyPasskeys();
        _set(status: AuthStatus.signedIn);
        return;
      } catch (e) {
        debugPrint('[AUTH_CONTROLLER] Session token validation failed: $e');
      }
    }

    final refreshToken = await _sessions.readRefreshToken();
    if (refreshToken != null && MicrosoftSignIn.isSupported) {
      debugPrint('[AUTH_CONTROLLER] Attempting silent Microsoft refresh...');
      final idToken = await _microsoft.refresh(refreshToken);
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
            refreshToken: serverAuth.refreshToken ?? refreshToken,
            idToken: idToken,
            employeeId: _profile?.employeeID,
          );
          _loadPhotoIfAvailable(serverAuth.accessToken, _profile!);
          await loadMyPasskeys();
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

  /// Refreshes the current employee profile, photo, and passkeys without re-authenticating.
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
      notifyListeners();
    } catch (e) {
      debugPrint('[AUTH_CONTROLLER] Refresh error: $e');
    }
  }

  /// Interactive Microsoft login flow -> Token Exchange -> Employee Profile verification.
  Future<void> signInWithMicrosoft() => _guard(() async {
    final tokens = await _microsoft.signIn();

    // 1. Decode JWT payload to extract user email
    final payload = _decodeJwt(tokens.idToken);
    final email = (payload['preferred_username'] ?? payload['email'] ?? payload['upn'])?.toString();
    debugPrint('==================================================');
    debugPrint('=== MICROSOFT SIGN-IN SUCCESSFUL ===');
    debugPrint('Email extracted: $email');
    debugPrint('==================================================');

    // 2. Collect Device Info
    final deviceInfo = await DeviceInfoService.getDeviceInfo();
    debugPrint('[AUTH_CONTROLLER] Device Info: $deviceInfo');

    // 3. Authenticate with backend API: POST /api/auth/microsoft-login
    debugPrint('[AUTH_CONTROLLER] Calling POST /api/auth/microsoft-login ...');
    final serverAuth = await _api.exchangeMicrosoftIdToken(
      idToken: tokens.idToken,
      email: email,
      deviceInfo: deviceInfo,
    );
    debugPrint('[AUTH_CONTROLLER] API Token Exchange successful!');

    // 4. Fetch Employee Profile: GET /api/employees/me
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
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException(
        'عذراً، هذا الحساب غير مربوط بملف موظف في النظام. يرجى مراجعة إدارة الموارد البشرية.',
        cause: e,
      );
    }

    // 5. Load profile photo if available
    _loadPhotoIfAvailable(serverAuth.accessToken, _profile!);

    // 6. Persist Session upon complete success (and remember employeeID)
    await _sessions.saveSession(
      accessToken: serverAuth.accessToken,
      refreshToken: serverAuth.refreshToken ?? tokens.refreshToken,
      idToken: tokens.idToken,
      employeeId: _profile?.employeeID,
    );

    // 7. Load passkeys list & mark just signed in
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

  /// Interactive Passkey (Biometric) Login flow.
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
        refreshToken: serverAuth.refreshToken,
        employeeId: profile.employeeID ?? empId,
      );

      _loadPhotoIfAvailable(serverAuth.accessToken, _profile!);
      await loadMyPasskeys();
      _set(status: AuthStatus.signedIn);
    } on AuthException catch (e) {
      debugPrint('[AUTH_CONTROLLER] Passkey sign-in failed: ${e.message}');
      rethrow;
    }
  });

  /// Enrolls a passkey on the current device automatically with zero manual input.
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
      hasPasskey: true,
      signedInWith: _profile?.signedInWith,
    );

    await loadMyPasskeys();
    notifyListeners();
  });

  /// Fetches the registered passkeys for the current user.
  Future<void> loadMyPasskeys() async {
    final token = await _sessions.readAccessToken();
    if (token == null) return;
    _loadingPasskeys = true;
    notifyListeners();
    try {
      _myPasskeys = await _api.getMyPasskeys(token);
      if (_myPasskeys.isNotEmpty && _profile != null && !_profile!.hasPasskey) {
        _profile = _profile!.copyWith(hasPasskey: true);
      }
    } catch (e) {
      debugPrint('[AUTH_CONTROLLER] Error loading passkeys list: $e');
    } finally {
      _loadingPasskeys = false;
      notifyListeners();
    }
  }

  /// Deletes or freezes a passkey by ID.
  /// If [permanent] is true, it permanently deletes the passkey from the server DB.
  /// Otherwise, it freezes / deactivates it without wiping.
  Future<void> deletePasskey(dynamic passkeyId, {bool permanent = false}) => _guard(() async {
    final token = await _sessions.readAccessToken();
    if (token == null) return;
    await _api.deletePasskey(
      sessionToken: token,
      passkeyId: passkeyId,
      permanent: permanent,
    );
    await loadMyPasskeys();
    if (_myPasskeys.isEmpty && _profile != null) {
      _profile = _profile!.copyWith(hasPasskey: false);
    }
    notifyListeners();
  });

  /// Fetches dynamic services catalog tailored to the logged-in employee.
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

  Future<void> signOut() async {
    final idToken = await _sessions.readIdToken();
    await _sessions.clear();
    _profile = null;
    _profilePhotoBytes = null;
    _myPasskeys = [];
    _justSignedIn = false;
    _set(status: AuthStatus.signedOut);

    // Best-effort Microsoft sign-out
    await _microsoft.signOut(idToken);
  }

  void clearError() => _set(error: null);

  // ---------------------------------------------------------------------

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

  /// Runs an action with busy state and uniform error handling.
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
