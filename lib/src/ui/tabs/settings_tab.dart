import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../services/device_info_service.dart';

/// The Settings & Passkey Security Management Tab.
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key, required this.auth});

  final AuthController auth;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  Map<String, dynamic>? _deviceInfo;

  @override
  void initState() {
    super.initState();
    _loadDevice();
    widget.auth.loadMyPasskeys();
  }

  Future<void> _loadDevice() async {
    final info = await DeviceInfoService.getDeviceInfo();
    if (mounted) setState(() => _deviceInfo = info);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final auth = widget.auth;
    final profile = auth.profile;
    final passkeys = auth.myPasskeys;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section 1: Passkey & Biometric Management
              _SectionTitle(
                title: 'إدارة مفاتيح المرور والبصمة (Passkey)',
                icon: Icons.fingerprint_rounded,
                color: colors.primary,
              ),
              const SizedBox(height: 12),
              _PasskeyManagementCard(
                auth: auth,
                passkeys: passkeys,
                isLoading: auth.loadingPasskeys,
              ),
              const SizedBox(height: 26),

              // Section 2: Account & Security
              _SectionTitle(
                title: 'الأمان والحساب المعتمد',
                icon: Icons.shield_outlined,
                color: const Color(0xFF059669),
              ),
              const SizedBox(height: 12),
              _AccountSecurityCard(profile: profile),
              const SizedBox(height: 26),

              // Section 3: Device Information
              _SectionTitle(
                title: 'معلومات الجهاز والنظام',
                icon: Icons.devices_rounded,
                color: const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 12),
              _DeviceInfoCard(deviceInfo: _deviceInfo),
              const SizedBox(height: 32),

              // Sign Out Button
              FilledButton.tonalIcon(
                onPressed: auth.busy ? null : () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: const Text(
                  'تسجيل الخروج من التطبيق',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 20),

              // Footer
              Center(
                child: FutureBuilder<String>(
                  future: DeviceInfoService.getAppVersion(),
                  builder: (context, snapshot) {
                    final version = snapshot.data ?? '1.0.0';
                    return Text(
                      'Central Bank of Iraq • الإصدار $version',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('تسجيل الخروج'),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد الخروج'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await widget.auth.signOut();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PasskeyManagementCard extends StatelessWidget {
  const _PasskeyManagementCard({
    required this.auth,
    required this.passkeys,
    required this.isLoading,
  });

  final AuthController auth;
  final List<Map<String, dynamic>> passkeys;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (passkeys.isEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الدخول السريع ببصمة الهاتف',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'اربط بصمة هذا الجهاز لتسجيل الدخول الفوري بضغطة زر واحدة دون الحاجة لحساب مايكروسوفت كل مرة.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: auth.busy ? null : () => _registerPasskey(context),
              icon: auth.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_moderator_rounded, size: 20),
              label: Text(
                auth.busy ? 'جاري ربط البصمة...' : 'ربط بصمة هذا الجهاز الآن (Passkey)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'بصمة الدخول السريع مفعلة',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'يمكنك الآن تسجيل الدخول مباشرة بالبصمة من شاشة البداية دون الحاجة لحساب مايكروسوفت.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),

          const Divider(),
          const SizedBox(height: 12),

          // Passkeys List
          Row(
            children: [
              Text(
                'المفاتيح والبصمات المسجلة',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: auth.loadMyPasskeys,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'تحديث قائمة البصمات',
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (passkeys.isEmpty && !isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'لا توجد بصمات مسجلة على حسابك حالياً. اضغط على الزر أعلاه للربط.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...passkeys.map((pk) {
              final id = pk['id'] ?? pk['passkeyId'] ?? pk['credentialId'] ?? pk['credId'];
              final deviceName = (pk['deviceName'] ?? pk['device'] ?? pk['name'] ?? 'هاتف مسجل').toString();
              final createdAt = (pk['createdAt'] ?? pk['created'] ?? pk['registeredAt'])?.toString() ?? '';
              final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : '';
              final isInactive = pk['isActive'] == false ||
                  pk['isBlocked'] == true ||
                  pk['isFrozen'] == true ||
                  pk['status'] == 'inactive' ||
                  pk['status'] == 'frozen' ||
                  pk['status'] == 'blocked';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isInactive
                        ? Colors.orange.withValues(alpha: 0.4)
                        : colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isInactive
                            ? Colors.orange.withValues(alpha: 0.12)
                            : const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isInactive ? Icons.lock_clock_rounded : Icons.fingerprint_rounded,
                        color: isInactive ? Colors.orange : const Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  deviceName,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isInactive
                                      ? Colors.orange.withValues(alpha: 0.15)
                                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isInactive ? 'مجمّد' : 'نشط',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isInactive ? Colors.orange.shade800 : const Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (dateStr.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'تاريخ التسجيل: $dateStr',
                              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (action) {
                        if (id == null) return;
                        if (action == 'freeze') {
                          _handlePasskeyAction(context, id, permanent: false, deviceName: deviceName);
                        } else if (action == 'delete') {
                          _handlePasskeyAction(context, id, permanent: true, deviceName: deviceName);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'freeze',
                          child: Row(
                            children: [
                              Icon(Icons.pause_circle_outline_rounded, color: Colors.orange, size: 18),
                              SizedBox(width: 8),
                              Text('تجميد / تعطيل المفتاح'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('محو وحذف نهائياً', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          if (passkeys.isNotEmpty) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: auth.busy ? null : () => _registerPasskey(context),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('ربط جهاز آخر / إعادة ربط البصمة'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _registerPasskey(BuildContext context) async {
    await auth.addPasskey();
    if (!context.mounted) return;
    if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم ربط بصمة الجهاز بنجاح! يمكنك الآن تسجيل الدخول بالبصمة مباشرة.'),
          backgroundColor: Color(0xFF059669),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handlePasskeyAction(
    BuildContext context,
    dynamic id, {
    required bool permanent,
    required String deviceName,
  }) async {
    final title = permanent ? 'محو وحذف مفتاح المرور نهائياً' : 'تجميد وتعطيل مفتاح المرور';
    final desc = permanent
        ? 'هل أنت متأكد من رغبتك في حذف مفتاح ($deviceName) نهائياً من قاعدة البيانات؟ لن يمكن استعادته.'
        : 'هل تريد تجميد وتعطيل مفتاح ($deviceName) مؤقتاً؟ سيتعذر الدخول به حتى إعادة تفعيله.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(desc),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: permanent ? Colors.redAccent : Colors.orange,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(permanent ? 'حذف نهائي' : 'تجميد المفتاح'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await auth.deletePasskey(id, permanent: permanent);
      if (!context.mounted) return;
      if (auth.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              permanent
                  ? 'تم محو وحذف مفتاح المرور بنجاح.'
                  : 'تم تجميد وتعطيل مفتاح المرور بنجاح.',
            ),
            backgroundColor: permanent ? Colors.redAccent : Colors.orange.shade800,
          ),
        );
      }
    }
  }
}

class _AccountSecurityCard extends StatelessWidget {
  const _AccountSecurityCard({required this.profile});

  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _RowItem(
            icon: Icons.alternate_email_rounded,
            label: 'البريد الرسمي المعتمد',
            value: profile?.email ?? 'غير محدد',
          ),
          const Divider(),
          _RowItem(
            icon: Icons.badge_outlined,
            label: 'الرقم الوظيفي',
            value: profile?.employeeID ?? 'غير محدد',
          ),
          const Divider(),
          _RowItem(
            icon: Icons.verified_user_outlined,
            label: 'مزود التوثيق',
            value: 'Microsoft Entra ID (Azure)',
          ),
        ],
      ),
    );
  }
}

class _DeviceInfoCard extends StatelessWidget {
  const _DeviceInfoCard({required this.deviceInfo});

  final Map<String, dynamic>? deviceInfo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final info = deviceInfo ?? {};

    final platform = info['platform']?.toString() ?? 'Android/iOS';
    final model = info['model']?.toString() ?? 'هاتف ذكي';
    final osVersion = info['osVersion']?.toString() ?? '';
    final appVersion = info['appVersion']?.toString() ?? '1.0.0';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _RowItem(
            icon: Icons.phone_android_rounded,
            label: 'طراز الجهاز',
            value: '$model ($platform $osVersion)',
          ),
          const Divider(),
          _RowItem(
            icon: Icons.apps_rounded,
            label: 'إصدار التطبيق',
            value: 'v$appVersion',
          ),
          const Divider(),
          _RowItem(
            icon: Icons.enhanced_encryption_outlined,
            label: 'حالة التشفير',
            value: 'FIDO2 / WebAuthn مشفر',
          ),
        ],
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
