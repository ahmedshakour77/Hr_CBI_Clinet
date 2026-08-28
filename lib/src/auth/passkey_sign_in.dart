import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

import '../api/hr_api_client.dart';
import 'auth_exception.dart';

/// Passkey (WebAuthn / FIDO2) registration and biometric authentication.
class PasskeySignIn {
  PasskeySignIn({
    HrApiClient? api,
    PasskeyAuthenticator? authenticator,
  }) : _api = api ?? HrApiClient(),
       _authenticator = authenticator ?? PasskeyAuthenticator();

  final HrApiClient _api;
  final PasskeyAuthenticator _authenticator;

  /// 1. Register a new passkey (Fingerprint / Face ID) for the logged-in employee.
  Future<void> register({
    required String sessionToken,
    String? deviceName,
  }) async {
    debugPrint('[PASSKEY] Step 1.1: Requesting passkey registration options...');
    final optionsRes = await _api.passkeyRegistrationOptions(
      sessionToken: sessionToken,
      deviceName: deviceName,
    );

    final optionsJson = optionsRes['optionsJson'] as String? ?? jsonEncode(optionsRes);
    final optionsMap = (optionsRes['options'] is Map<String, dynamic>)
        ? optionsRes['options'] as Map<String, dynamic>
        : (optionsRes['optionsJson'] != null
            ? jsonDecode(optionsRes['optionsJson'] as String) as Map<String, dynamic>
            : optionsRes);

    debugPrint('[PASSKEY] Server optionsMap: $optionsMap');
    debugPrint('[PASSKEY] Relying Party (RP) ID from server: "${optionsMap['rp']?['id'] ?? optionsMap['rpId']}"');

    final request = RegisterRequestType.fromJson(optionsMap);

    final RegisterResponseType response;
    try {
      debugPrint('[PASSKEY] Step 1.2: Prompting native biometric scan for registration...');
      response = await _authenticator.register(request);
      debugPrint('[PASSKEY] Native authenticator successfully created credential!');
    } on AuthenticatorException catch (error) {
      debugPrint('[PASSKEY] Native authenticator error during registration: $error');
      throw _translate(error, isRegistration: true);
    }

    final attestationResponseJson = jsonEncode(response.toJson());

    debugPrint('[PASSKEY] Step 1.3: Verifying attestation response with backend...');
    await _api.verifyPasskeyRegistration(
      sessionToken: sessionToken,
      optionsJson: optionsJson,
      attestationResponseJson: attestationResponseJson,
      deviceName: deviceName,
    );
    debugPrint('[PASSKEY] Registration complete and verified by server!');
  }

  /// 2. Sign in using registered passkey & employee ID. Returns the ServerAuthResponse.
  Future<ServerAuthResponse> signIn({
    required String employeeID,
    Map<String, dynamic>? deviceInfo,
  }) async {
    debugPrint('[PASSKEY] Step 2.1: Requesting login options for employee: $employeeID...');
    final optionsRes = await _api.passkeyLoginOptions(employeeID: employeeID);

    final optionsJson = optionsRes['optionsJson'] as String? ?? jsonEncode(optionsRes);
    final optionsMap = (optionsRes['options'] is Map<String, dynamic>)
        ? optionsRes['options'] as Map<String, dynamic>
        : (optionsRes['optionsJson'] != null
            ? jsonDecode(optionsRes['optionsJson'] as String) as Map<String, dynamic>
            : optionsRes);

    final request = AuthenticateRequestType.fromJson(
      optionsMap,
      mediation: MediationType.Optional,
      preferImmediatelyAvailableCredentials: false,
    );

    final AuthenticateResponseType response;
    try {
      debugPrint('[PASSKEY] Step 2.2: Prompting native biometric scan for sign-in...');
      response = await _authenticator.authenticate(request);
      debugPrint('[PASSKEY] Native authenticator signed assertion challenge!');
    } on AuthenticatorException catch (error) {
      debugPrint('[PASSKEY] Native authenticator error during sign-in: $error');
      throw _translate(error, isRegistration: false);
    }

    final assertionResponseJson = jsonEncode(response.toJson());

    debugPrint('[PASSKEY] Step 2.3: Completing biometric login with server...');
    final serverAuth = await _api.verifyPasskeyLogin(
      optionsJson: optionsJson,
      assertionResponseJson: assertionResponseJson,
      deviceInfo: deviceInfo,
    );
    debugPrint('[PASSKEY] Biometric authentication successful! Access Token received.');
    return serverAuth;
  }

  /// Check whether the device supports biometric passkeys.
  Future<bool> isAvailable() async {
    try {
      // ignore: deprecated_member_use
      return await _authenticator.canAuthenticate();
    } catch (_) {
      return false;
    }
  }

  AuthException _translate(
    AuthenticatorException error, {
    required bool isRegistration,
  }) {
    return switch (error) {
      PasskeyAuthCancelledException() => const AuthException.cancelled(),

      NoCredentialsAvailableException() => const AuthException(
        'لم يتم العثور على مفتاح مرور مسجل على هذا الجهاز. سجّل الدخول عبر مايكروسوفت أولاً ثم قم بربط البصمة من ملفك الشخصي.',
      ),

      ExcludeCredentialsCanNotBeRegisteredException() => const AuthException(
        'يوجد بالفعل مفتاح مرور مسجل لهذا الحساب على هذا الجهاز.',
      ),

      DomainNotAssociatedException() => AuthException(
        'التطبيق غير مقترن بنطاق المصادقة الخاص بالخادم (.well-known association).',
        cause: error,
      ),

      MissingGoogleSignInException() => const AuthException(
        'يرجى إضافة حساب Google على جهازك لاستخدام مفاتيح المرور (Passkeys).',
      ),

      SyncAccountNotAvailableException() => const AuthException(
        'لا يوجد موفر مفاتيح مرور مفعل على هذا الجهاز. يرجى تفعيله من إعدادات الهاتف.',
      ),

      DeviceNotSupportedException() || PasskeyUnsupportedException() =>
        const AuthException('هذا الجهاز لا يدعم تقنية مفاتيح المرور (Passkeys).'),

      NoCreateOptionException() => const AuthException(
        'تعذر إنشاء مفتاح مرور. تأكد من تفعيل قفل الشاشة والبصمة في إعدادات الهاتف.',
      ),

      TimeoutException() => const AuthException(
        'انتهت مهلة قراءة البصمة. يرجى المحاولة مرة أخرى.',
      ),

      MalformedBase64UrlChallenge() ||
      MalformedBase64UrlCredentialID() ||
      MalformedBase64UrlUserID() => AuthException(
        'أرسل الخادم بيانات غير صالحة للتحدي المشفر.',
        cause: error,
      ),

      UnhandledAuthenticatorException() => ((error.message?.contains('RP ID') ?? false) || (error.details?.toString().contains('RP ID') ?? false))
          ? AuthException(
              'يتطلب تفعيل البصمة رفع ملف الربط (.well-known/assetlinks.json) على الخادم لنطاق المصادقة.',
              cause: error,
            )
          : AuthException(
              'فشلت عملية المصادقة البيومترية: ${error.message}',
              cause: error,
            ),
    };
  }
}
