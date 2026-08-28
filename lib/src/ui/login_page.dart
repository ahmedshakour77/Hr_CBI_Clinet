import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../config/app_config.dart';
import '../services/device_info_service.dart';
import 'widgets/microsoft_logo.dart';

/// Modern, executive sign-in screen for the Central Bank of Iraq HR portal.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Ambient Background Glowing Orbs & Gradients
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.18),
                    colors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0284C7).withValues(alpha: 0.15),
                    const Color(0xFF0284C7).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // CBI Executive Branding
                      const _BrandHeader(),
                      const SizedBox(height: 32),

                      // Sign-In Interactive Glass Card
                      _SignInCard(auth: auth),
                      const SizedBox(height: 24),

                      // Error Banner
                      if (auth.errorMessage != null) ...[
                        _ErrorBanner(
                          message: auth.errorMessage!,
                          onDismiss: auth.clearError,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Configuration Warning
                      if (!AppConfig.isConfigured) ...[
                        _ConfigWarning(missing: AppConfig.missingSettings),
                        const SizedBox(height: 24),
                      ],

                      // Security Footer
                      const _SecurityFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Central Bank of Iraq emblem, titles, and verified security pill.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        // Glowing Logo Frame
        Container(
          width: 92,
          height: 92,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary,
                const Color(0xFF0284C7),
                colors.primaryContainer,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              'logo2.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.account_balance_rounded,
                size: 42,
                color: colors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // Official Institution Title
        Text(
          'البنك المركزي العراقي',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'منظومة الموارد البشرية والخدمات الذاتية',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),

        // Security Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'بوابة الدخول الموحد المعتمدة',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The Main Glassmorphic Card holding the Microsoft and Passkey authentication actions.
class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تسجيل الدخول إلى حسابك',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'استخدم بريدك الوظيفي الرسمي للمتابعة',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),

          // Primary: Microsoft Entra ID Button
          _MicrosoftButton(auth: auth),
          const SizedBox(height: 20),

          // Elegant Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: colors.outlineVariant.withValues(alpha: 0.4),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'أو الدخول البيومتري',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: colors.outlineVariant.withValues(alpha: 0.4),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Secondary: Passkey (Fingerprint / Face ID) Button
          _PasskeyButton(auth: auth),
        ],
      ),
    );
  }
}

/// Official Microsoft Login Button with loading animation and platform checks.
class _MicrosoftButton extends StatelessWidget {
  const _MicrosoftButton({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final available = auth.microsoftAvailable;
    final isBusy = auth.busy;

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy || !available ? null : auth.signInWithMicrosoft,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isBusy || !available
                  ? [
                      colors.surfaceContainerHighest,
                      colors.surfaceContainerHighest,
                    ]
                  : [
                      const Color(0xFF0F172A),
                      const Color(0xFF1E293B),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isBusy || !available
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isBusy) ...[
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'جاري التوثيق والتحقق...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else ...[
                const MicrosoftLogo(size: 20),
                const SizedBox(width: 14),
                const Text(
                  'الدخول بحساب مايكروسوفت',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (available) return button;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        button,
        const SizedBox(height: 8),
        Text(
          'يتطلب تسجيل الدخول عبر مايكروسوفت نظام Android أو iOS أو macOS.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: colors.error,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Modern Biometric Passkey sign-in card button.
class _PasskeyButton extends StatelessWidget {
  const _PasskeyButton({required this.auth});

  final AuthController auth;

  Future<void> _handlePasskeyClick(BuildContext context) async {
    final lastEmpId = await auth.getLastEmployeeId();
    if (lastEmpId != null && lastEmpId.isNotEmpty) {
      await auth.signInWithPasskey(employeeID: lastEmpId);
      return;
    }

    if (!context.mounted) return;

    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                color: Color(0xFFD97706),
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'لم يتم ربط البصمة على هذا الجهاز بعد',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'لتفعيل ميزة الدخول بالبصمة (Passkey)، سجّل الدخول أولاً باستخدام حساب مايكروسوفت الرسمي المعتمد، وسيتم تفعيل البصمة لهذا الهاتف تلقائياً.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                auth.signInWithMicrosoft();
              },
              icon: const MicrosoftLogo(size: 18),
              label: const Text(
                'الدخول بحساب مايكروسوفت الآن',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isBusy = auth.busy;

    return OutlinedButton(
      onPressed: isBusy ? null : () => _handlePasskeyClick(context),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.6),
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: colors.surface.withValues(alpha: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fingerprint_rounded,
            size: 24,
            color: colors.primary,
          ),
          const SizedBox(width: 12),
          Text(
            'الدخول ببصمة الإصبع (Passkey)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating Alert Banner for unauthorized or connection error messages.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.error.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.error.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline_rounded,
              color: colors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.onErrorContainer,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: const Color(0xFF991B1B),
            tooltip: 'إغلاق',
          ),
        ],
      ),
    );
  }
}

class _ConfigWarning extends StatelessWidget {
  const _ConfigWarning({required this.missing});

  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_outlined, size: 18),
              const SizedBox(width: 8),
              Text('الإعداد غير مكتمل', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'إعدادات البناء المفقودة: ${missing.join(', ')}.\n'
            'مررها عبر --dart-define أو ملف env.json.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Security Badge & Version Footer
class _SecurityFooter extends StatelessWidget {
  const _SecurityFooter();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 15,
              color: colors.onSurfaceVariant.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 6),
            Text(
              'نظام محمي ومشفر وفق معايير الأمان المعتمدة',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FutureBuilder<String>(
          future: DeviceInfoService.getAppVersion(),
          builder: (context, snapshot) {
            final version = snapshot.data ?? '1.0.0';
            return Text(
              'Central Bank of Iraq • v$version',
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            );
          },
        ),
      ],
    );
  }
}
