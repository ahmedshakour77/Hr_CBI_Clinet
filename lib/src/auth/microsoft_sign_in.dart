import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import '../config/app_config.dart';
import 'auth_exception.dart';

/// Microsoft Entra ID sign-in over OAuth 2.0 authorization code + PKCE.
///
/// AppAuth opens the system browser (Custom Tabs on Android, an
/// `ASWebAuthenticationSession` on iOS) rather than a WebView. That is not a
/// stylistic choice: Microsoft blocks embedded WebViews for sign-in, and only
/// the system browser can reuse an existing session or a device-bound
/// credential for single sign-on.
class MicrosoftSignIn {
  const MicrosoftSignIn({FlutterAppAuth? appAuth})
    : _appAuth = appAuth ?? const FlutterAppAuth();

  final FlutterAppAuth _appAuth;

  /// `flutter_appauth` ships Android, iOS and macOS implementations only.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Runs the interactive flow and returns the tokens.
  ///
  /// The `id_token` is what identifies the user; it is sent to our server for
  /// verification rather than being trusted here.
  Future<({String idToken, String? refreshToken})> signIn() async {
    _assertUsable();
    debugPrint('[MICROSOFT_SIGN_IN] Initiating OAuth 2.0 PKCE flow...');
    debugPrint('  Client ID: ${AppConfig.entraClientId}');
    debugPrint('  Redirect URL: ${AppConfig.entraRedirectUrl}');
    debugPrint('  Discovery URL: ${AppConfig.entraDiscoveryUrl}');

    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AppConfig.entraClientId,
          AppConfig.entraRedirectUrl,
          serviceConfiguration: AuthorizationServiceConfiguration(
            authorizationEndpoint: AppConfig.entraAuthorizationEndpoint,
            tokenEndpoint: AppConfig.entraTokenEndpoint,
          ),
          scopes: AppConfig.entraScopes,
          promptValues: const ['select_account'],
        ),
      );

      final idToken = result.idToken;
      if (idToken == null) {
        debugPrint('[MICROSOFT_SIGN_IN] !!! Error: Microsoft returned null idToken');
        throw const AuthException(
          'Microsoft did not return an identity token. Check that the app '
          'registration requests the "openid" scope.',
        );
      }

      debugPrint('================= [ MICROSOFT SIGN-IN RESULT ] =================');
      debugPrint('Access Token Expiration: ${result.accessTokenExpirationDateTime}');
      debugPrint('Refresh Token: ${result.refreshToken != null ? "Present" : "None"}');
      debugPrint('Additional Parameters: ${result.tokenAdditionalParameters}');

      // Decode and print claims directly
      try {
        final parts = idToken.split('.');
        if (parts.length >= 2) {
          final normalized = base64Url.normalize(parts[1]);
          final payloadJson = utf8.decode(base64Url.decode(normalized));
          final decoded = jsonDecode(payloadJson);
          final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
          debugPrint('--- [ DECODED ID_TOKEN CLAIMS (JSON) ] ---');
          for (final line in pretty.split('\n')) {
            debugPrint(line);
          }
          debugPrint('-------------------------------------------');
        }
      } catch (e) {
        debugPrint('Could not parse id_token payload: $e');
      }

      debugPrint('--- [ FULL RAW ID TOKEN (Chunked to avoid logcat truncation) ] ---');
      for (var i = 0; i < idToken.length; i += 400) {
        debugPrint(idToken.substring(i, i + 400 > idToken.length ? idToken.length : i + 400));
      }
      debugPrint('================================================================');

      return (idToken: idToken, refreshToken: result.refreshToken);
    } on FlutterAppAuthUserCancelledException {
      debugPrint('[MICROSOFT_SIGN_IN] User cancelled the sign-in prompt.');
      throw const AuthException.cancelled();
    } on FlutterAppAuthPlatformException catch (error) {
      throw AuthException(
        error.platformErrorDetails.errorDescription ??
            'Microsoft sign-in failed.',
        cause: error,
      );
    } catch (error) {
      throw AuthException(
        'Microsoft sign-in failed: $error',
        cause: error,
      );
    }
  }

  /// Renews the session without user interaction. Returns null when the refresh
  /// token has been revoked or expired and a full sign-in is required.
  Future<String?> refresh(String refreshToken) async {
    _assertUsable();

    try {
      final result = await _appAuth.token(
        TokenRequest(
          AppConfig.entraClientId,
          AppConfig.entraRedirectUrl,
          discoveryUrl: AppConfig.entraDiscoveryUrl,
          scopes: AppConfig.entraScopes,
          refreshToken: refreshToken,
        ),
      );
      return result.idToken;
    } on FlutterAppAuthPlatformException {
      return null;
    }
  }

  /// Ends the session at Microsoft as well as locally. Without this, the next
  /// sign-in silently reuses the browser session and appears to skip logout.
  Future<void> signOut(String? idToken) async {
    if (!isSupported || idToken == null) return;
    try {
      await _appAuth.endSession(
        EndSessionRequest(
          idTokenHint: idToken,
          postLogoutRedirectUrl: AppConfig.entraRedirectUrl,
          discoveryUrl: AppConfig.entraDiscoveryUrl,
        ),
      );
    } catch (_) {
      // Local sign-out has already happened by this point; a failure to reach
      // the end-session endpoint must not strand the user in a signed-in UI.
    }
  }

  void _assertUsable() {
    if (!isSupported) {
      throw const AuthException(
        'Microsoft sign-in is only available on Android, iOS and macOS. '
        'Run the app on a mobile device or emulator.',
      );
    }
    if (!AppConfig.isConfigured) {
      throw AuthException(
        'Microsoft sign-in is not configured. Missing: '
        '${AppConfig.missingSettings.join(', ')}.',
      );
    }
  }
}
