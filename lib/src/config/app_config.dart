library;


/// Deployment configuration.
///
/// Nothing here is a secret — a public OAuth client has no client secret — but
/// tenant and client IDs still identify your organisation, so they are supplied
/// at build time rather than committed:
///
/// ```
/// flutter run \
///   --dart-define=ENTRA_TENANT_ID=a834b56b-a04e-4362-accd-64f2e6b5a6a1 \
///   --dart-define=ENTRA_CLIENT_ID=5c3522c1-728d-4387-adb2-e293c74206c2 \
///   --dart-define=RP_BASE_URL=https://hr.example.com \
///   --dart-define=RP_ID=hr.example.com
/// ```
///    --dart-define-from-file=env.json
/// Keep them in `--dart-define-from-file=env.json` if the command line gets
/// unwieldy.   flutter run --device 1B011FDF6004CN --dart-define-from-file=env.json
class AppConfig {
  const AppConfig._();

  // ---------------------------------------------------------------------
  // Microsoft Entra ID
  // ---------------------------------------------------------------------

  /// Directory (tenant) ID. `organizations` accepts any work/school account;
  /// use your tenant GUID to restrict sign-in to your own directory.
  static const entraTenantId = String.fromEnvironment(
    'ENTRA_TENANT_ID',
    defaultValue: 'organizations',
  );

  /// Application (client) ID from the Azure app registration.
  static const entraClientId = String.fromEnvironment(
    'ENTRA_CLIENT_ID',
    defaultValue: '5c3522c1-728d-4387-adb2-e293c74206c2',
  );

  /// OIDC discovery document & endpoints.
  static String get entraDiscoveryUrl =>
      'https://login.microsoftonline.com/$entraTenantId/v2.0/.well-known/openid-configuration';

  static String get entraAuthorizationEndpoint =>
      'https://login.microsoftonline.com/$entraTenantId/oauth2/v2.0/authorize';

  static String get entraTokenEndpoint =>
      'https://login.microsoftonline.com/$entraTenantId/oauth2/v2.0/token';

  /// Custom-scheme redirect. This exact string must be registered in Azure
  /// under Authentication > Mobile and desktop applications, and the scheme
  /// part must match `appAuthRedirectScheme` in android/app/build.gradle.kts
  /// and the CFBundleURLSchemes entry in ios/Runner/Info.plist.
  static const entraRedirectUrl = String.fromEnvironment(
    'ENTRA_REDIRECT_URL',
    defaultValue: 'com.cbi.cbiapp://oauthredirect',
  );

  /// `offline_access` is what gets us a refresh token; without it the session
  /// dies as soon as the access token expires.
  static const entraScopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
  ];

  // ---------------------------------------------------------------------
  // Relying party / API
  // ---------------------------------------------------------------------

  static const _definedRpBaseUrl = String.fromEnvironment('RP_BASE_URL');

  /// Base URL of the HR backend API.
  static String get rpBaseUrl {
    if (_definedRpBaseUrl.isNotEmpty) return _definedRpBaseUrl;
    return 'https://apihr.iraqservice.uk';
  }



  /// Surfaces misconfiguration at startup instead of as a confusing OAuth
  /// error three taps later.
  static List<String> get missingSettings => [
    if (entraClientId.isEmpty) 'ENTRA_CLIENT_ID',
  ];

  static bool get isConfigured => missingSettings.isEmpty;
}
