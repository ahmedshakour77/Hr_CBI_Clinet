import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_exception.dart';
import '../config/app_config.dart';
import '../models/employee_profile.dart';
import '../services/device_info_service.dart';

/// Response payload from `POST /api/auth/microsoft-login` and `POST /api/auth/passkey/login/complete`.
class ServerAuthResponse {
  const ServerAuthResponse({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
    this.rawJson,
  });

  factory ServerAuthResponse.fromJson(Map<String, dynamic> json) {
    final token = (json['accessToken'] ?? json['access_token'] ?? json['token']) as String?;
    if (token == null || token.isEmpty) {
      throw AuthException(
        json['message']?.toString() ?? 'لم يُرجع الخادم رمز تفويض (accessToken) صالح.',
        cause: json,
      );
    }

    return ServerAuthResponse(
      accessToken: token,
      refreshToken: (json['refreshToken'] ?? json['refresh_token']) as String?,
      tokenType: (json['tokenType'] ?? json['token_type'] ?? 'Bearer') as String,
      expiresIn: json['expiresIn'] as int? ?? json['expires_in'] as int?,
      rawJson: json,
    );
  }

  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int? expiresIn;
  final Map<String, dynamic>? rawJson;
}

/// HTTP client talking to the CBI HR backend (`https://apihr.iraqservice.uk`).
class HrApiClient {
  HrApiClient({http.Client? httpClient, Uri? baseUrl})
    : _http = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? Uri.parse(AppConfig.rpBaseUrl);

  final http.Client _http;
  final Uri _baseUrl;

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) =>
      _baseUrl.replace(path: path, queryParameters: queryParameters);

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? body,
    String? bearer,
  }) async {
    final uri = _uri(path);
    debugPrint('[HTTP_API] >>> POST $uri');
    if (body != null) {
      debugPrint('[HTTP_API] Body: ${jsonEncode(body)}');
    }

    final headers = <String, String>{
      'content-type': 'application/json',
      if (bearer != null) 'authorization': 'Bearer $bearer',
    };

    late final http.Response response;
    try {
      response = await _http.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      debugPrint('[HTTP_API] <<< ${response.statusCode} POST $path (${response.body.length} bytes)');
    } catch (error) {
      debugPrint('[HTTP_API] !!! Network error reaching $uri: $error');
      throw AuthException(
        'تعذر الاتصال بالخادم ($path). يرجى التحقق من اتصال الإنترنت.',
        cause: error,
      );
    }

    return _decode(response);
  }

  Future<Map<String, dynamic>> _decode(http.Response response) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('[HTTP_API] !!! Failed to parse JSON response (${response.statusCode}): ${response.body}');
      if (response.statusCode >= 400) {
        throw AuthException(
          'فشل الطلب من الخادم (رمز الاستجابة ${response.statusCode}).',
          cause: response.body,
        );
      }
      return Future.value(<String, dynamic>{});
    }

    if (response.statusCode >= 400) {
      final rawError = json['message'] ?? json['error'] ?? json['detail'] ?? json['title'];
      debugPrint('[HTTP_API] !!! Server Error ${response.statusCode}: $rawError');

      final errorCode = rawError is String ? rawError.trim() : null;
      throw AuthException(
        _messageForError(errorCode, response.statusCode),
        cause: json,
      );
    }
    return Future.value(json);
  }

  String _messageForError(String? code, int status) {
    if (code != null) {
      final mapped = switch (code) {
        'invalid_id_token' => 'رمز الدخول غير صالح أو تم رفضه من قبل الخادم.',
        'unauthorized' => 'عذراً، هذا الحساب غير مصرح له بالدخول إلى النظام.',
        'not_found' || 'user_not_found' || 'employee_not_found' =>
          'عذراً، هذا الحساب غير مربوط بملف موظف في النظام. يرجى مراجعة إدارة الموارد البشرية.',
        'challenge_expired' => 'انتهت صلاحية الجلسة، يرجى إعادة تسجيل الدخول.',
        'unknown_credential' => 'مفتاح المرور غير مسجل.',
        'verification_failed' => 'فشلت عملية التحقق.',
        'missing_bearer_token' || 'invalid_session' || 'unknown_user' =>
          'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مجدداً.',
        _ => null,
      };
      if (mapped != null) return mapped;
    }

    if (status == 404) {
      return 'عذراً، هذا الحساب غير مربوط بملف موظف في النظام. يرجى مراجعة إدارة الموارد البشرية.';
    }
    if (status == 401 || status == 403) {
      return 'عذراً، هذا الحساب غير مصرح له بالدخول إلى النظام.';
    }
    if (code != null && code.isNotEmpty && !code.contains('_')) {
      return code;
    }
    return status >= 500
        ? 'حدث خطأ في خادم النظام ($status). يرجى المحاولة لاحقاً.'
        : 'فشل الطلب من الخادم (رمز الاستجابة $status).';
  }

  /// Trades a verified Entra `id_token`, `email`, and `deviceInfo` for an app session token from the HR backend.
  /// POST https://apihr.iraqservice.uk/api/auth/microsoft-login
  Future<ServerAuthResponse> exchangeMicrosoftIdToken({
    required String idToken,
    String? email,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final info = deviceInfo ?? await DeviceInfoService.getDeviceInfo();
    final body = <String, dynamic>{
      'idToken': idToken,
      if (email != null && email.isNotEmpty) 'email': email,
      'deviceInfo': info,
    };
    final json = await _post('/api/auth/microsoft-login', body: body);
    return ServerAuthResponse.fromJson(json);
  }

  /// Fetches the authenticated employee record.
  /// GET https://apihr.iraqservice.uk/api/employees/me
  Future<EmployeeProfile> fetchProfile(String sessionToken) async {
    final uri = _uri('/api/employees/me');
    debugPrint('[HTTP_API] >>> GET $uri');
    late final http.Response response;
    try {
      response = await _http.get(
        uri,
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $sessionToken',
        },
      );
      debugPrint('[HTTP_API] <<< ${response.statusCode} GET /api/employees/me (${response.body.length} bytes)');
    } catch (error) {
      debugPrint('[HTTP_API] !!! Network error reaching $uri: $error');
      throw AuthException(
        'تعذر الاتصال بالخادم لجلب بيانات الموظف. يرجى التحقق من اتصال الإنترنت.',
        cause: error,
      );
    }
    final json = await _decode(response);
    debugPrint('================= [/api/employees/me RESPONSE JSON] =================');
    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(json);
      for (final line in pretty.split('\n')) {
        debugPrint(line);
      }
    } catch (_) {
      debugPrint('$json');
    }
    debugPrint('====================================================================');
    return EmployeeProfile.fromJson(json);
  }

  /// Fetches the employee profile photo thumbnail bytes.
  /// GET /api/employees/{employeeID}/profile-photo/thumbnail
  Future<Uint8List?> fetchProfilePhoto(
    String sessionToken,
    String employeeId, {
    int? version,
  }) async {
    final uri = _baseUrl.replace(
      path: '/api/employees/$employeeId/profile-photo/thumbnail',
      queryParameters: version != null ? {'v': '$version'} : null,
    );
    debugPrint('[HTTP_API] >>> GET Profile Photo: $uri');
    try {
      final response = await _http.get(
        uri,
        headers: {
          'authorization': 'Bearer $sessionToken',
        },
      );
      debugPrint('[HTTP_API] <<< ${response.statusCode} GET Profile Photo (${response.bodyBytes.length} bytes)');
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('[HTTP_API] Notice: Could not load profile photo: $e');
    }
    return null;
  }

  /// Fetches available employee self-services for the current user.
  /// GET /api/services or GET /api/employees/me/services
  Future<List<Map<String, dynamic>>> fetchServices(String sessionToken) async {
    final uri = _uri('/api/services');
    debugPrint('[HTTP_API] >>> GET $uri');
    try {
      final response = await _http.get(
        uri,
        headers: {
          'authorization': 'Bearer $sessionToken',
          'content-type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
        if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          return (decoded['data'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      debugPrint('[HTTP_API] Notice: /api/services not returned ($e), will use service catalog.');
    }
    return [];
  }

  /// 1.1 Request Passkey Registration Options
  /// POST /api/auth/passkey/register/options
  Future<Map<String, dynamic>> passkeyRegistrationOptions({
    required String sessionToken,
    String? deviceName,
  }) async {
    return await _post(
      '/api/auth/passkey/register/options',
      bearer: sessionToken,
      body: {
        if (deviceName != null && deviceName.isNotEmpty) 'deviceName': deviceName,
      },
    );
  }

  /// 1.2 Complete Passkey Registration
  /// POST /api/auth/passkey/register/complete
  Future<Map<String, dynamic>> verifyPasskeyRegistration({
    required String sessionToken,
    required String optionsJson,
    required String attestationResponseJson,
    String? deviceName,
  }) async {
    return await _post(
      '/api/auth/passkey/register/complete',
      bearer: sessionToken,
      body: {
        'optionsJson': optionsJson,
        'attestationResponseJson': attestationResponseJson,
        if (deviceName != null && deviceName.isNotEmpty) 'deviceName': deviceName,
      },
    );
  }

  /// 2.1 Request Passkey Login Challenge
  /// POST /api/auth/passkey/login/options
  Future<Map<String, dynamic>> passkeyLoginOptions({
    required String employeeID,
  }) async {
    return await _post(
      '/api/auth/passkey/login/options',
      body: {'employeeID': employeeID},
    );
  }

  /// 2.2 Complete Passkey Login
  /// POST /api/auth/passkey/login/complete
  Future<ServerAuthResponse> verifyPasskeyLogin({
    required String optionsJson,
    required String assertionResponseJson,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final info = deviceInfo ?? await DeviceInfoService.getDeviceInfo();
    final json = await _post(
      '/api/auth/passkey/login/complete',
      body: {
        'optionsJson': optionsJson,
        'assertionResponseJson': assertionResponseJson,
        'deviceInfo': info,
      },
    );
    return ServerAuthResponse.fromJson(json);
  }

  /// 3.1 Get Registered Passkeys for Current User
  /// GET /api/auth/passkey/my-passkeys
  Future<List<Map<String, dynamic>>> getMyPasskeys(String sessionToken) async {
    final uri = _uri('/api/auth/passkey/my-passkeys');
    debugPrint('[HTTP_API] >>> GET $uri');
    final response = await _http.get(
      uri,
      headers: {
        'authorization': 'Bearer $sessionToken',
        'content-type': 'application/json',
      },
    );
    debugPrint('[HTTP_API] <<< ${response.statusCode} GET ${uri.path} (${response.body.length} bytes)');
    if (response.statusCode >= 400) {
      debugPrint('[HTTP_API] Failed to fetch passkeys (${response.statusCode}): ${response.body}');
      return [];
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    } else if (decoded is Map<String, dynamic> && decoded['passkeys'] is List) {
      return (decoded['passkeys'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// 3.2 Freeze / Block or Permanently Delete a Passkey by ID
  /// DELETE /api/auth/passkey/{id} (Freeze / Deactivate)
  /// DELETE /api/auth/passkey/{id}?permanent=true (Permanently Delete from DB)
  Future<void> deletePasskey({
    required String sessionToken,
    required dynamic passkeyId,
    bool permanent = false,
  }) async {
    final uri = _uri(
      '/api/auth/passkey/$passkeyId',
      permanent ? {'permanent': 'true'} : null,
    );
    debugPrint('[HTTP_API] >>> DELETE $uri');
    final response = await _http.delete(
      uri,
      headers: {
        'authorization': 'Bearer $sessionToken',
        'content-type': 'application/json',
      },
    );
    debugPrint('[HTTP_API] <<< ${response.statusCode} DELETE ${uri.path}');
    if (response.statusCode >= 400) {
      throw AuthException(
        permanent
            ? 'فشل حذف ومحو مفتاح المرور نهائياً (${response.statusCode})'
            : 'فشل تجميد/تعطيل مفتاح المرور (${response.statusCode})',
        cause: response.body,
      );
    }
  }

  void dispose() => _http.close();
}
