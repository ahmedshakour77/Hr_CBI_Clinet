import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_exception.dart';
import '../config/app_config.dart';
import '../id_reader/domain/entities/id_card_model.dart';
import '../models/document_models.dart';
import '../models/employee_profile.dart';
import '../services/device_info_service.dart';

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
      final summary = <String, dynamic>{};
      for (final entry in body.entries) {
        final val = entry.value;
        if (val is String && val.startsWith('data:image')) {
          summary[entry.key] = '[BASE64_IMAGE: ${(val.length / 1024).toStringAsFixed(1)} KB]';
        } else if (val is String && val.length > 300) {
          summary[entry.key] = '[LONG_STRING: ${val.length} chars]';
        } else {
          summary[entry.key] = val;
        }
      }
      debugPrint('[HTTP_API] Body Payload Summary: ${jsonEncode(summary)}');
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
    if (status == 403) {
      return 'عذراً، لا تملك الصلاحية لتنفيذ هذا الإجراء (403 Forbidden). هذه العملية تتطلب صلاحيات إدارة الموارد البشرية (Admin/HR).';
    }
    if (status == 401) {
      return 'عذراً، هذا الحساب غير مصرح له بالدخول إلى النظام.';
    }
    if (code != null && code.isNotEmpty && !code.contains('_')) {
      return code;
    }
    return status >= 500
        ? 'حدث خطأ في خادم النظام ($status). يرجى المحاولة لاحقاً.'
        : 'فشل الطلب من الخادم (رمز الاستجابة $status).';
  }

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

  Future<EmployeeProfile> fetchProfile(String sessionToken) async {
    final uri = _uri('/api/employees/me');
    late final http.Response response;
    try {
      response = await _http.get(
        uri,
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $sessionToken',
        },
      );
    } catch (error) {
      throw AuthException(
        'تعذر الاتصال بالخادم لجلب بيانات الموظف. يرجى التحقق من اتصال الإنترنت.',
        cause: error,
      );
    }
    final json = await _decode(response);
    return EmployeeProfile.fromJson(json);
  }

  Future<Uint8List?> fetchProfilePhoto(
    String sessionToken,
    String employeeId, {
    int? version,
  }) async {
    final uri = _baseUrl.replace(
      path: '/api/employees/$employeeId/profile-photo/thumbnail',
      queryParameters: version != null ? {'v': '$version'} : null,
    );
    try {
      final response = await _http.get(
        uri,
        headers: {'authorization': 'Bearer $sessionToken'},
      );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchServices(String sessionToken) async {
    final uri = _uri('/api/services');
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
        if (decoded is List) return decoded.cast<Map<String, dynamic>>();
        if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          return (decoded['data'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> passkeyRegistrationOptions({
    required String sessionToken,
    String? deviceName,
  }) async {
    return _post(
      '/api/auth/passkey/register/options',
      bearer: sessionToken,
      body: {if (deviceName != null && deviceName.isNotEmpty) 'deviceName': deviceName},
    );
  }

  Future<Map<String, dynamic>> verifyPasskeyRegistration({
    required String sessionToken,
    required String optionsJson,
    required String attestationResponseJson,
    String? deviceName,
  }) async {
    return _post(
      '/api/auth/passkey/register/complete',
      bearer: sessionToken,
      body: {
        'optionsJson': optionsJson,
        'attestationResponseJson': attestationResponseJson,
        if (deviceName != null && deviceName.isNotEmpty) 'deviceName': deviceName,
      },
    );
  }

  Future<Map<String, dynamic>> passkeyLoginOptions({required String employeeID}) {
    return _post('/api/auth/passkey/login/options', body: {'employeeID': employeeID});
  }

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

  Future<List<Map<String, dynamic>>> getMyPasskeys(String sessionToken) async {
    final uri = _uri('/api/auth/passkey/my-passkeys');
    final response = await _http.get(
      uri,
      headers: {
        'authorization': 'Bearer $sessionToken',
        'content-type': 'application/json',
      },
    );
    if (response.statusCode >= 400) return [];
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    if (decoded is Map<String, dynamic> && decoded['passkeys'] is List) {
      return (decoded['passkeys'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  Future<void> deletePasskey({
    required String sessionToken,
    required dynamic passkeyId,
    bool permanent = false,
  }) async {
    final uri = _uri(
      '/api/auth/passkey/$passkeyId',
      permanent ? {'permanent': 'true'} : null,
    );
    final response = await _http.delete(
      uri,
      headers: {
        'authorization': 'Bearer $sessionToken',
        'content-type': 'application/json',
      },
    );
    if (response.statusCode >= 400) {
      throw AuthException(
        permanent
            ? 'فشل حذف ومحو مفتاح المرور نهائياً (${response.statusCode})'
            : 'فشل تجميد/تعطيل مفتاح المرور (${response.statusCode})',
        cause: response.body,
      );
    }
  }

  Future<Map<String, dynamic>> updateMyNationalCard({
    required String sessionToken,
    required IdCardModel idCard,
  }) {
    return _post(
      '/api/employees/me/national-card',
      bearer: sessionToken,
      body: idCard.toApiPayload(),
    );
  }

  Future<Map<String, dynamic>> updateEmployeeNationalCard({
    required String sessionToken,
    required String employeeIdOrNumber,
    required IdCardModel idCard,
  }) {
    final cleanId = employeeIdOrNumber.trim();
    if (cleanId.isEmpty || cleanId.toLowerCase() == 'me') {
      return updateMyNationalCard(sessionToken: sessionToken, idCard: idCard);
    }
    return _post(
      '/api/employees/$cleanId/national-card',
      bearer: sessionToken,
      body: idCard.toApiPayload(),
    );
  }

  Future<EmployeeDocumentsBundle> getMyDocuments(String sessionToken) async {
    final response = await _http.get(
      _uri('/api/documents/me'),
      headers: {
        'authorization': 'Bearer $sessionToken',
        'content-type': 'application/json',
      },
    );
    return EmployeeDocumentsBundle.fromJson(await _decode(response));
  }

  Future<EmployeeDocumentsBundle> getEmployeeDocuments(
    String sessionToken,
    String employeeId,
  ) async {
    final cleanId = employeeId.trim();
    if (cleanId.isEmpty || cleanId.toLowerCase() == 'me') {
      return getMyDocuments(sessionToken);
    }
    final response = await _http.get(
      _uri('/api/documents/$cleanId'),
      headers: {
        'authorization': 'Bearer $sessionToken',
        'content-type': 'application/json',
      },
    );
    return EmployeeDocumentsBundle.fromJson(await _decode(response));
  }

  Future<Map<String, dynamic>> savePassport({
    required String sessionToken,
    required Map<String, dynamic> payload,
  }) {
    return _post('/api/documents/passport', bearer: sessionToken, body: payload);
  }

  Future<Map<String, dynamic>> saveResidence({
    required String sessionToken,
    required Map<String, dynamic> payload,
  }) {
    return _post('/api/documents/residence', bearer: sessionToken, body: payload);
  }

  Future<Map<String, dynamic>> saveNationalCard({
    required String sessionToken,
    required Map<String, dynamic> payload,
  }) {
    return _post('/api/documents/national-card', bearer: sessionToken, body: payload);
  }

  Uri? _trustedAuthenticatedResourceUri(String relativeOrAbsoluteUrl) {
    final raw = relativeOrAbsoluteUrl.trim();
    if (raw.isEmpty) return null;

    final candidate = Uri.tryParse(raw);
    if (candidate == null) return null;

    final resolved = candidate.hasScheme ? candidate : _baseUrl.resolveUri(candidate);
    final sameOrigin = resolved.scheme.toLowerCase() == _baseUrl.scheme.toLowerCase() &&
        resolved.host.toLowerCase() == _baseUrl.host.toLowerCase() &&
        resolved.port == _baseUrl.port;

    if (!sameOrigin || resolved.scheme.toLowerCase() != 'https') {
      return null;
    }
    return resolved;
  }

  Future<Uint8List?> getAuthenticatedImageBytes(
    String sessionToken,
    String relativeOrAbsoluteUrl,
  ) async {
    final uri = _trustedAuthenticatedResourceUri(relativeOrAbsoluteUrl);
    if (uri == null) {
      debugPrint('[HTTP_API] Refused authenticated resource outside configured API origin.');
      return null;
    }

    try {
      final response = await _http.get(
        uri,
        headers: {'authorization': 'Bearer $sessionToken'},
      );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  Future<List<EmployeeProfile>> fetchAllEmployees(
    String sessionToken, {
    void Function(int loadedCount, int? totalCount)? onProgress,
  }) async {
    try {
      final allAtOnce = await _tryFetchAllInOneCall(sessionToken);
      if (allAtOnce != null && allAtOnce.length > 50) {
        onProgress?.call(allAtOnce.length, allAtOnce.length);
        return allAtOnce;
      }
    } catch (_) {}

    return _fetchPaginatedEmployees(sessionToken, onProgress: onProgress);
  }

  Future<List<EmployeeProfile>?> _tryFetchAllInOneCall(String sessionToken) async {
    for (final paramName in ['pageSize', 'limit']) {
      final uri = _uri('/api/employees', {paramName: '5000'});
      try {
        final response = await _http.get(
          uri,
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $sessionToken',
          },
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final list = _extractListFromDecoded(decoded);
          if (list.length > 50) {
            return list.map(EmployeeProfile.fromJson).toList();
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<List<EmployeeProfile>> _fetchPaginatedEmployees(
    String sessionToken, {
    void Function(int loadedCount, int? totalCount)? onProgress,
  }) async {
    final allProfiles = <EmployeeProfile>[];
    final seenIds = <String>{};
    int page = 1;
    int? reportedTotal;
    const pageSize = 50;
    const maxPages = 1000;

    String pageParam = 'page';
    String sizeParam = 'pageSize';

    while (page <= maxPages) {
      final pageValue = pageParam == 'offset'
          ? ((page - 1) * pageSize).toString()
          : page.toString();
      final query = <String, String>{
        pageParam: pageValue,
        sizeParam: pageSize.toString(),
      };
      final uri = _uri('/api/employees', query);

      late final http.Response response;
      try {
        response = await _http.get(
          uri,
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $sessionToken',
          },
        );
      } catch (error) {
        if (page == 1) {
          throw AuthException(
            'تعذر الاتصال بالخادم لجلب قائمة الموظفين. يرجى التحقق من اتصال الإنترنت.',
            cause: error,
          );
        }
        break;
      }

      if (response.statusCode == 403) {
        throw const AuthException(
          'عذراً، هذا الحساب غير مصرح له بالوصول إلى قائمة الموظفين (403 Forbidden). هذه الميزة متاحة لمدراء النظام ومسؤولي الموارد البشرية فقط.',
        );
      }

      if (response.statusCode != 200) {
        if (page == 1 || page == 2) {
          if (pageParam == 'page') {
            pageParam = 'pageNumber';
            page = 1;
            allProfiles.clear();
            seenIds.clear();
            reportedTotal = null;
            continue;
          }
          if (pageParam == 'pageNumber') {
            pageParam = 'offset';
            sizeParam = 'limit';
            page = 1;
            allProfiles.clear();
            seenIds.clear();
            reportedTotal = null;
            continue;
          }
        }
        if (page == 1) {
          throw AuthException(
            'فشل استرجاع قائمة الموظفين من الخادم (رمز ${response.statusCode}).',
            cause: response.body,
          );
        }
        break;
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        if (page == 1) {
          throw AuthException(
            'فشل تحليل استجابة الخادم لقائمة الموظفين.',
            cause: response.body,
          );
        }
        break;
      }

      if (decoded is Map<String, dynamic>) {
        final rawTotal = decoded['total'] ??
            decoded['totalCount'] ??
            decoded['totalEmployees'] ??
            decoded['count'] ??
            decoded['totalRecords'];
        if (rawTotal is num) reportedTotal = rawTotal.toInt();
      }

      final list = _extractListFromDecoded(decoded);
      if (list.isEmpty) break;

      int newOnThisPage = 0;
      for (final raw in list) {
        final profile = EmployeeProfile.fromJson(raw);
        final stableId = profile.employeeID?.trim();
        final id = (stableId != null && stableId.isNotEmpty)
            ? stableId
            : '${profile.name}_${profile.jobTitle}_${allProfiles.length}';
        if (seenIds.add(id)) {
          allProfiles.add(profile);
          newOnThisPage++;
        }
      }

      onProgress?.call(allProfiles.length, reportedTotal);

      if (newOnThisPage == 0) {
        if (page <= 2 && pageParam == 'page') {
          pageParam = 'pageNumber';
          page = 1;
          allProfiles.clear();
          seenIds.clear();
          reportedTotal = null;
          continue;
        }
        if (page <= 2 && pageParam == 'pageNumber') {
          pageParam = 'offset';
          sizeParam = 'limit';
          page = 1;
          allProfiles.clear();
          seenIds.clear();
          reportedTotal = null;
          continue;
        }
        break;
      }

      if (reportedTotal != null && allProfiles.length >= reportedTotal) break;
      if (list.length < pageSize && reportedTotal == null) break;

      page++;
    }

    return allProfiles;
  }

  List<Map<String, dynamic>> _extractListFromDecoded(dynamic decoded) {
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    if (decoded is Map<String, dynamic>) {
      for (final key in ['data', 'employees', 'items', 'result', 'list', 'records']) {
        final val = decoded[key];
        if (val is List) {
          return val.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    return [];
  }

  Future<EmployeeProfile> fetchEmployeeDetails(String sessionToken, String idOrNumber) async {
    final cleanId = idOrNumber.trim();
    if (cleanId.isEmpty || cleanId.toLowerCase() == 'me') {
      return fetchProfile(sessionToken);
    }
    final uri = _uri('/api/employees/$cleanId');
    late final http.Response response;
    try {
      response = await _http.get(
        uri,
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $sessionToken',
        },
      );
    } catch (error) {
      throw AuthException(
        'تعذر الاتصال بالخادم لجلب بيانات الموظف $cleanId.',
        cause: error,
      );
    }

    if (response.statusCode == 403) {
      throw const AuthException(
        'عذراً، هذا الحساب غير مصرح له بالوصول إلى بيانات هذا الموظف (403 Forbidden).',
      );
    }

    return EmployeeProfile.fromJson(await _decode(response));
  }

  void dispose() => _http.close();
}
