import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../id_reader/id_reader.dart';
import '../admin/admin_employees_directory_page.dart';

/// The Self-Services tab offering dynamic API-driven and standard HR requests for CBI employees.
class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  @override
  void initState() {
    super.initState();
    widget.auth.loadDynamicServices();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final auth = widget.auth;
    final profile = auth.profile;
    final dynamicServices = auth.dynamicServices;

    return RefreshIndicator(
      onRefresh: () async {
        await auth.loadDynamicServices();
      },
      color: colors.primary,
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
                // Welcome Banner
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary,
                        const Color(0xFF0284C7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.grid_view_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'بوابة الخدمات الذاتية',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          if (auth.loadingServices)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'مرحباً ${profile?.name ?? "زميلنا العزيز"}، يمكنك تقديم ومتابعة جميع طلباتك الإدارية والمالية المتاحة لحسابك مباشرة.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // If Dynamic Services are returned from API, render them first
                if (dynamicServices.isNotEmpty) ...[
                  const _CategoryHeader(
                    title: 'الخدمات المخصصة لحسابك',
                    icon: Icons.stars_rounded,
                    badge: 'خاص بحسابك',
                  ),
                  const SizedBox(height: 12),
                  _ServiceGrid(
                    items: dynamicServices.map((svc) {
                      final title = svc['title'] ?? svc['name'] ?? svc['serviceName'] ?? 'خدمة موظف';
                      final subtitle = svc['subtitle'] ?? svc['description'] ?? svc['category'] ?? '';
                      final description = svc['details'] ?? svc['description'] ?? 'تقديم طلب للخدمة مباشرة';

                      return _ServiceItem(
                        title: title.toString(),
                        subtitle: subtitle.toString(),
                        icon: _iconForName(svc['icon']?.toString()),
                        color: colors.primary,
                        onTap: () => _showServiceModal(
                          context,
                          title: title.toString(),
                          description: description.toString(),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 26),
                ],

                // Category 1: الإجازات والغيابات
                const _CategoryHeader(
                  title: 'الإجازات والدوام',
                  icon: Icons.calendar_month_outlined,
                  badge: '3 خدمات',
                ),
                const SizedBox(height: 12),
                _ServiceGrid(
                  items: [
                    _ServiceItem(
                      title: 'طلب إجازة جديدة',
                      subtitle: 'اعتيادية، مرضية، دراسية',
                      icon: Icons.add_circle_outline_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () => _showServiceModal(
                        context,
                        title: 'طلب إجازة اعتيادية',
                        description: 'تقديم طلب إجازة رسمي إلى مدير الشعبة للمصادقة.',
                      ),
                    ),
                    _ServiceItem(
                      title: 'رصيد الإجازات',
                      subtitle: 'استعراض الرصيد المتبقي',
                      icon: Icons.pie_chart_outline_rounded,
                      color: const Color(0xFF0284C7),
                      onTap: () => _showServiceModal(
                        context,
                        title: 'رصيد الإجازات المتبقي',
                        description: 'الرصيد الاعتيادي المتبقي: 36 يوماً\nالرصيد الزمني: 12 ساعة',
                      ),
                    ),
                    _ServiceItem(
                      title: 'سجل الحضور والبصمة',
                      subtitle: 'سجل البصمات اليومي',
                      icon: Icons.fingerprint_rounded,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => _showServiceModal(
                        context,
                        title: 'سجل الحضور اليومي',
                        description: 'استعراض حركة البصمة لأيام الدوام الرسمي خلال الشهر الحالي.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Category 2: الرواتب والمستحقات
                const _CategoryHeader(
                  title: 'الرواتب والمستحقات المالية',
                  icon: Icons.account_balance_wallet_outlined,
                  badge: '2 خدمات',
                ),
                const SizedBox(height: 12),
                _ServiceGrid(
                  items: [
                    _ServiceItem(
                      title: 'كشف الراتب الشهري',
                      subtitle: 'الراتب الاسمي والمخصصات',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFFF59E0B),
                      onTap: () => _showServiceModal(
                        context,
                        title: 'كشف الراتب الشهري',
                        description: 'تحميل كشف الراتب للشهر الحالي وتفاصيل الاستقطاعات والمخصصات المصرفية.',
                      ),
                    ),
                    _ServiceItem(
                      title: 'السلف والقروض المصرفية',
                      subtitle: 'تقديم ومتابعة الأقساط',
                      icon: Icons.monetization_on_outlined,
                      color: const Color(0xFFEC4899),
                      onTap: () => _showServiceModal(
                        context,
                        title: 'السلف والقروض',
                        description: 'طلب سلفة جديدة أو استعراض جدول استقطاع الأقساط الشهرية.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Category 3: الكتب والشهادات الرسمية
                const _CategoryHeader(
                  title: 'الكتب والشهادات الرسمية',
                  icon: Icons.description_outlined,
                  badge: '3 خدمات',
                ),
                const SizedBox(height: 12),
                _ServiceGrid(
                  items: [
                    _ServiceItem(
                      title: 'كتاب تأييد استمرار',
                      subtitle: 'لمن يهمه الأمر',
                      icon: Icons.verified_outlined,
                      color: const Color(0xFF0F62FE),
                      onTap: () => _showServiceModal(
                        context,
                        title: 'طلب كتاب تأييد استمرار بالخدمة',
                        description: 'إصدار كتاب تأييد رسمي مع كود QR للتحقق الإلكتروني.',
                      ),
                    ),
                    _ServiceItem(
                      title: 'شهادة راتب',
                      subtitle: 'موجهة للدوائر الرسمية',
                      icon: Icons.request_quote_outlined,
                      color: const Color(0xFF059669),
                      onTap: () => _showServiceModal(
                        context,
                        title: 'طلب شهادة راتب',
                        description: 'إصدار شهادة راتب معتمدة موجهة إلى الجهات الحكومية أو المصرفية.',
                      ),
                    ),
                    _ServiceItem(
                      title: 'كتب الشكر والتقدير',
                      subtitle: 'سجل التشكرات والقدم',
                      icon: Icons.military_tech_outlined,
                      color: const Color(0xFFD97706),
                      onTap: () => _showServiceModal(
                        context,
                        title: 'سجل كتب الشكر والتقدير',
                        description: 'عرض كتب الشكر والتقدير الوزارية والإدارية واحتساب القدم الوظيفي.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Category 4: الهوية والتحقق الرقمي
                _CategoryHeader(
                  title: 'الهوية والتحقق الرقمي',
                  icon: Icons.fingerprint_rounded,
                  badge: auth.isAdmin ? 'صلاحيات HR' : 'NFC الذكي',
                ),
                const SizedBox(height: 12),
                _ServiceGrid(
                  items: [
                    if (auth.isAdmin)
                      _ServiceItem(
                        title: 'إدارة وتحديث بطاقات الموظفين (HR Admin)',
                        subtitle: 'استعراض جميع الموظفين، التدقيق، وتحديث الشريحة عبر NFC',
                        icon: Icons.admin_panel_settings_rounded,
                        color: const Color(0xFF0F62FE),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AdminEmployeesDirectoryPage(auth: auth),
                            ),
                          );
                        },
                      ),
                    _ServiceItem(
                      title: auth.isAdmin ? 'قارئ بطاقتي أنا (كأدمن)' : 'قارئ البطاقة الموحدة والجواز',
                      subtitle: auth.isAdmin
                          ? 'تحديث بطاقتك الشخصية كمسؤول عبر المسار المباشر me'
                          : 'قراءة وتدقيق الشريحة عبر NFC وتحديث بطاقتك الشخصية',
                      icon: Icons.nfc_rounded,
                      color: auth.isAdmin ? const Color(0xFF10B981) : const Color(0xFF0F62FE),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => IdReaderPage(
                              auth: auth,
                              targetEmployeeId: 'me',
                              targetEmployeeName: profile?.name,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconForName(String? name) {
    if (name == null) return Icons.stars_rounded;
    return switch (name.toLowerCase()) {
      'calendar' || 'leave' => Icons.calendar_month_outlined,
      'salary' || 'money' || 'wallet' => Icons.receipt_long_rounded,
      'loan' || 'bank' => Icons.monetization_on_outlined,
      'document' || 'letter' => Icons.description_outlined,
      'award' || 'honor' => Icons.military_tech_outlined,
      _ => Icons.stars_rounded,
    };
  }

  static void _showServiceModal(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F62FE).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.layers_outlined,
                    color: Color(0xFF0F62FE),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                description,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم فتح نافذة: $title'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'تقديم الطلب الآن',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.title,
    required this.icon,
    required this.badge,
  });

  final String title;
  final IconData icon;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.items});

  final List<_ServiceItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: item,
      )).toList(),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  const _ServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
