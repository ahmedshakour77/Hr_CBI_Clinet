import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import 'tabs/profile_tab.dart';
import 'tabs/services_tab.dart';
import 'tabs/settings_tab.dart';

/// Main Application Shell hosting the NavigationBar with 3 primary modules:
/// 1. الملف الوظيفي (Profile)
/// 2. الخدمات الذاتية (Self-Services)
/// 3. الإعدادات والأمان (Settings & Passkeys)
class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // After first frame, check if this is the first login and prompt automatic Passkey enrollment
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstTimePasskeyPrompt());
  }

  void _checkFirstTimePasskeyPrompt() {
    if (widget.auth.justSignedIn) {
      widget.auth.clearJustSignedIn();
      final hasPasskey = widget.auth.profile?.hasPasskey ?? false;
      final passkeys = widget.auth.myPasskeys;

      if (!hasPasskey && passkeys.isEmpty) {
        _showPasskeyEnrollmentSheet();
      }
    }
  }

  void _showPasskeyEnrollmentSheet() {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isDismissible: true,
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                size: 40,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'تفعيل الدخول السريع بالبصمة',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'هل تود ربط بصمة هذا الهاتف (Face ID / Fingerprint) لتسجيل الدخول الفوري بلمسة واحدة دون الحاجة لإدخال حساب مايكروسوفت كل مرة؟',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await widget.auth.addPasskey();
                if (!mounted) return;
                if (widget.auth.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.auth.errorMessage!),
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تفعيل وربط بصمة الجهاز بنجاح!'),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: const Text(
                'تفعيل البصمة الآن (تلقائي)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('لاحقاً (من الإعدادات)'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final auth = widget.auth;

    final titles = ['الملف الوظيفي', 'الخدمات الذاتية', 'الإعدادات والأمان'];

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: auth.busy ? null : auth.refreshProfile,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ProfileTab(auth: auth),
          ServicesTab(auth: auth),
          SettingsTab(auth: auth),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          indicatorColor: colors.primary.withValues(alpha: 0.14),
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge_rounded, color: Color(0xFF0F62FE)),
              label: 'الملف',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_mosaic_outlined),
              selectedIcon: Icon(Icons.auto_awesome_mosaic_rounded, color: Color(0xFF0F62FE)),
              label: 'الخدمات',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF0F62FE)),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}
