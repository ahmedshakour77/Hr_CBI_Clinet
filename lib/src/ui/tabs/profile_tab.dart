import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_controller.dart';
import '../../id_reader/id_reader.dart';
import '../../models/employee_profile.dart';
import '../widgets/profile_field.dart';
import '../widgets/shadow_avatar.dart';

/// The Profile tab displaying the full employee record from `/api/employees/me`.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final profile = auth.profile ?? const EmployeeProfile();

    return RefreshIndicator(
      onRefresh: auth.refreshProfile,
      color: Theme.of(context).colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroProfileHeader(
                  profile: profile,
                  imageBytes: auth.profilePhotoBytes,
                ),
                const SizedBox(height: 20),

                _QuickStatsRibbon(profile: profile),
                const SizedBox(height: 26),

                const _SectionHeader(
                  icon: Icons.badge_outlined,
                  title: 'البيانات الإدارية والوظيفية',
                ),
                const SizedBox(height: 12),
                _JobDetailsCard(profile: profile),
                const SizedBox(height: 26),

                const _SectionHeader(
                  icon: Icons.school_outlined,
                  title: 'المؤهل والتحصيل العلمي',
                ),
                const SizedBox(height: 12),
                _EducationCard(profile: profile),
                const SizedBox(height: 26),

                const _SectionHeader(
                  icon: Icons.person_outline_rounded,
                  title: 'البيانات الشخصية',
                ),
                const SizedBox(height: 12),
                _PersonalDetailsCard(profile: profile),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const IdReaderPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.nfc_rounded, color: Color(0xFF0F62FE)),
                  label: const Text(
                    'قراءة وتدقيق البطاقة الوطنية / الجواز (NFC)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                const _SectionHeader(
                  icon: Icons.security_rounded,
                  title: 'الأمان وحساب مايكروسوفت',
                ),
                const SizedBox(height: 12),
                _MicrosoftAccountCard(
                  email: profile.email,
                  microsoftId: profile.microsoftId,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroProfileHeader extends StatelessWidget {
  const _HeroProfileHeader({
    required this.profile,
    this.imageBytes,
  });

  final EmployeeProfile profile;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final name = profile.name ?? 'موظف في البنك المركزي';
    final job = profile.jobTitle ?? 'موظف';
    final position = profile.positionTitle;
    final formation = profile.formation ?? 'البنك المركزي العراقي';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: 0.90),
            colors.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              ShadowAvatar(
                imageBytes: imageBytes,
                initials: _initials(profile.name),
                size: 116,
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF10B981),
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            job,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (position != null && position.isNotEmpty && position != job) ...[
            const SizedBox(height: 4),
            Text(
              position,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_rounded, size: 17, color: colors.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    formation,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (profile.roles.isNotEmpty || profile.isAdmin) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (profile.isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.admin_panel_settings_rounded, size: 14, color: Color(0xFF8B5CF6)),
                        SizedBox(width: 4),
                        Text(
                          'مسؤول إداري (HR Admin)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ...profile.roles.where((r) => r != 'HR_Admin').map((role) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        role == 'Employee' ? 'موظف معتمد' : role,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String? _initials(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return null;
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final letters = parts
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    return letters.isEmpty ? null : letters;
  }
}

class _QuickStatsRibbon extends StatelessWidget {
  const _QuickStatsRibbon({required this.profile});

  final EmployeeProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final years = profile.yearsOfService;
    final yearsLabel = years == null
        ? 'غير محدد'
        : (years == 0 ? 'أقل من سنة' : '$years ${years == 1 ? "سنة" : "سنوات"}');

    final gradeStageLabel = (profile.grade != null || profile.stage != null)
        ? '${profile.grade ?? ""} ${profile.stage != null ? "• ${profile.stage!}" : ""}'.trim()
        : '---';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.badge_outlined,
                title: 'الرقم الوظيفي',
                value: profile.employeeID ?? '---',
                color: colors.primary,
                copyableValue: profile.employeeID,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.workspace_premium_outlined,
                title: 'الدرجة والمرحلة',
                value: gradeStageLabel,
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.history_toggle_off_rounded,
                title: 'سنوات الخدمة',
                value: yearsLabel,
                color: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline_rounded,
                title: 'الحالة',
                value: profile.employeeStatus ?? 'مستمر بالخدمة',
                color: const Color(0xFF059669),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.copyableValue,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final String? copyableValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: copyableValue != null && copyableValue!.isNotEmpty
          ? () async {
              await Clipboard.setData(ClipboardData(text: copyableValue!));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم نسخ $title: $copyableValue'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 21, color: colors.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _JobDetailsCard extends StatelessWidget {
  const _JobDetailsCard({required this.profile});

  final EmployeeProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          ProfileField(
            icon: Icons.account_balance_outlined,
            label: 'التشكيل / الإدارة العامة',
            value: profile.formation,
          ),
          const _Divider(),
          ProfileField(
            icon: Icons.account_tree_outlined,
            label: 'القسم / الشعبة',
            value: profile.firstDepartment,
          ),
          const _Divider(),
          ProfileField(
            icon: Icons.engineering_outlined,
            label: 'العنوان الوظيفي الحالي',
            value: profile.jobTitle,
          ),
          if (profile.positionTitle != null && profile.positionTitle != profile.jobTitle) ...[
            const _Divider(),
            ProfileField(
              icon: Icons.assignment_ind_outlined,
              label: 'المنصب الإداري',
              value: profile.positionTitle,
            ),
          ],
          const _Divider(),
          ProfileField(
            icon: Icons.grade_outlined,
            label: 'الدرجة والمرحلة الوظيفية',
            value: (profile.grade != null || profile.stage != null)
                ? '${profile.grade ?? ""} - ${profile.stage ?? ""}'.trim()
                : null,
          ),
          const _Divider(),
          ProfileField(
            icon: Icons.event_available_outlined,
            label: 'تاريخ التعيين / المباشرة',
            value: _formatDate(profile.hireDate),
          ),
          if (profile.administrativeUnit != null && profile.administrativeUnit!.isNotEmpty) ...[
            const _Divider(),
            ProfileField(
              icon: Icons.domain_rounded,
              label: 'الشعبة / الوحدة الإدارية',
              value: profile.administrativeUnit,
            ),
          ],
          if (profile.lastJobTitleDate != null) ...[
            const _Divider(),
            ProfileField(
              icon: Icons.update_outlined,
              label: 'تاريخ نيل العنوان الحالي',
              value: _formatDate(profile.lastJobTitleDate),
            ),
          ],
          if (profile.serviceStatus != null && profile.serviceStatus!.isNotEmpty) ...[
            const _Divider(),
            ProfileField(
              icon: Icons.verified_user_outlined,
              label: 'حالة الخدمة',
              value: profile.serviceStatus,
            ),
          ],
        ],
      ),
    );
  }

  static String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

class _EducationCard extends StatelessWidget {
  const _EducationCard({required this.profile});

  final EmployeeProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          ProfileField(
            icon: Icons.school_outlined,
            label: 'التحصيل الدراسي (المؤهل العلمي)',
            value: profile.educationLevel,
          ),
          const _Divider(),
          ProfileField(
            icon: Icons.psychology_outlined,
            label: 'التخصص الدقيق',
            value: profile.specialization,
          ),
        ],
      ),
    );
  }
}

class _PersonalDetailsCard extends StatelessWidget {
  const _PersonalDetailsCard({required this.profile});

  final EmployeeProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          ProfileField(
            icon: Icons.cake_outlined,
            label: 'تاريخ التولد / العمر',
            value: profile.birthDate != null
                ? '${_formatDate(profile.birthDate)} (${profile.age ?? ""} سنة)'
                : (profile.age != null ? '${profile.age} سنة' : null),
          ),
          const _Divider(),
          ProfileField(
            icon: Icons.male_rounded,
            label: 'الجنس',
            value: profile.gender,
          ),
          const _Divider(),
          ProfileField(
            icon: Icons.flag_outlined,
            label: 'القومية / الجنسية',
            value: profile.nationality,
          ),
          const _Divider(),
          ProfileField(
            icon: Icons.auto_stories_outlined,
            label: 'الديانة',
            value: profile.religion,
          ),
          if (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty) ...[
            const _Divider(),
            ProfileField(
              icon: Icons.phone_android_rounded,
              label: 'رقم الهاتف المعتمد',
              value: profile.phoneNumber,
            ),
          ],
        ],
      ),
    );
  }

  static String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
  );
}

class _MicrosoftAccountCard extends StatelessWidget {
  const _MicrosoftAccountCard({required this.email, required this.microsoftId});

  final String? email;
  final String? microsoftId;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.verified_user_rounded, size: 18, color: colors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'تم التوثيق عبر Microsoft Entra ID',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (email != null) ...[
            _CopyableRow(label: 'حساب مايكروسوفت الرسمي', value: email!),
            const SizedBox(height: 12),
          ],
          if (microsoftId != null)
            _CopyableRow(label: 'معرّف الحساب (Microsoft ID)', value: microsoftId!),
        ],
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  const _CopyableRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم النسخ إلى الحافظة بنجاح'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          tooltip: 'نسخ',
        ),
      ],
    );
  }
}
