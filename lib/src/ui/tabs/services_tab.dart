import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../id_reader/id_reader.dart';
import '../admin/admin_employees_directory_page.dart';

/// The Self-Services tab offering API-driven and planned HR requests.
/// Planned services never display fabricated employee values or fake success.
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
      onRefresh: auth.loadDynamicServices,
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
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.primary, const Color(0xFF0284C7)],
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
                        'مرحباً ${profile?.name ?? "زميلنا العزيز"}، تظهر الخدمات المرتبطة فعلياً بحسابك أولاً. الخدمات الأخرى موضحة كخدمات قيد الربط ولا تعرض بيانات غير حقيقية.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (dynamicServices.isNotEmpty) ...[
                  const _CategoryHeader(
                    title: 'الخدمات المخصصة لحسابك',
                    icon: Icons.stars_rounded,
                    badge: 'مرتبطة بالنظام',
                  ),
                  const SizedBox(height: 12),
                  _ServiceGrid(
                    items: dynamicServices.map((svc) {
                      final title = svc['title'] ?? svc['name'] ?? svc['serviceName'] ?? 'خدمة موظف';
                      final subtitle = svc['subtitle'] ?? svc['description'] ?? svc['category'] ?? '';
                      final description = svc['details'] ?? svc['description'] ?? 'الخدمة متاحة من خلال النظام.';
                      return _ServiceItem(
                        title: title.toString(),
                        subtitle: subtitle.toString(),
                        icon: _iconForName(svc['icon']?.toString()),
                        color: colors.primary,
                        onTap: () => _showServiceModal(
                          context,
                          title: title.toString(),
                          description: description.toString(),
                          isConnected: true,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 26),
                ],

                const _CategoryHeader(
                  title: 'الإجازات والدوام',
                  icon: Icons.calendar_month_outlined,
                  badge: 'قيد الربط',
                ),
                const SizedBox(height: 12),
                _ServiceGrid(
                  items: [
                    _ServiceItem(
                      title: 'طلب إجازة جديدة',
                      subtitle: 'اعتيادية، مرضية، دراسية',
                      icon: Icons.add_circle_outline_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () => _showPlannedService(
                        context,
                        title: 'طلب إجازة جديدة',
                        description: 'سيتم تفعيل تقديم طلب الإجازة بعد ربط واجهة الخدمة مع نظام الموارد البشرية وسير الموافقات.',
                      ),
                    ),
                    _ServiceItem(
                      title: 'رصيد الإجازات',
                      subtitle: 'استعراض الرصيد الفعلي من النظام',
                      icon: Icons.pie_chart_outline_rounded,
                      color: const Color(0xFF0284C7),
                      onTap: () => _showPlannedService(
                        context,
                        title: 'رصيد الإجازات',
                        description: 'لا يعرض التطبيق رصيداً افتراضياً. سيظهر الرصيد الفعلي فقط بعد ربط خدمة أرصدة الإجازات بالـ API.',
                      ),
                    ),
                    _ServiceItem(
                      title: 'سجل الحضور والبصمة',
                      subtitle: 'سجل البصمات اليومي',
                      icon: Icons.fingerprint_rounded,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => _showPlannedService(
                        context,
                        title: 'سجل الحضور والبصمة',
                        description: 'هذه الخدمة قيد الربط مع مصدر بيانات الحضور والبصمة، ولن يتم عرض سجل تجريبي بدلاً عن البيانات الفعلية.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const _CategoryHeader(
                  title: 'الرواتب والمستحقات المالية',
                  icon: Icons.account_balance_wallet_outlined,
                  badge: 'قيد الربط',
                ),
                const SizedBox(height: 12),
                _ServiceGrid(
                  items: [
                    _ServiceItem(
                      title: 'كشف الراتب الشهري',
                      subtitle: 'الراتب الاسمي والمخصصات',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFFF59E0B),
                      onTap: () => _showPlannedService(
                        context,
                        title: 'كشف الراتب الشهري',
                        description: 'سيتم إظهار كشف الراتب بعد ربط الخدمة المالية والتحقق من صلاحيات الوصول للبيانات الحساسة.',
                      ),
                    ),
                    _ServiceItem(
                      title: 'السلف والقروض المصرفية',
                      subtitle: 'تقديم ومتابعة الأقساط',
                      icon: Icons.monetization_on_outlined,
                      color: const Color(0xFFEC4899),
                      onTap: () => _showPlannedService(
                        context,
                        title: 'السلف والقروض',
                        description: 'الخدمة قيد الربط مع النظام المالي ولا توجد حالياً عملية تقديم أو متابعة منفذة من هذه الشاشة.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const _CategoryHeader(
                  title: 'الكتب والشهادات الرسمية',
                  icon: Icons.description_outlined,
                  badge: 'قيد الربط',
                ),
                const SizedBox(height: 12),
                _ServiceGrid(
                  items: [
                    _ServiceItem(
                      title: 'كتاب تأييد استمرار',
                      subtitle: 'لمن يهمه الأمر',
                      icon: Icons.verified_outlined,
                      color: const Color(0xFF0F62FE),
                      onTap: () => _showPlannedService(
                        context,
                        title: 'كتاب تأييد استمرار بالخدمة',
                        description: 'إصدار الكتاب سيُفعّل بعد ربط مسار الطلب والموافقة والتوقيع والتحقق الإلكتروني.',
                      ),
                    ),
                    _ServiceItem(
                      title: 'شهادة راتب',
                      subtitle: 'موجهة للدوائر الرسمية',
                      icon: Icons.request_quote_outlined,
                      color: const Color(0xFF059669),
                      onTap: () => _showPlannedService(
                        context,
                        title: 'شهادة راتب',
                        description: 'الخدمة قيد الربط ولن يتم إنشاء شهادة أو إظهار نجاح قبل تنفيذ الـ API ومسار الاعتماد الفعلي.',
                      ),
                    ),
                    _ServiceItem(
                      title: 'كتب الشكر والتقدير',
                      subtitle: 'سجل التشكرات والقدم',
                      icon: Icons.military_tech_outlined,
                      color: const Color(0xFFD97706),
                      onTap: () => _showPlannedService(
                        context,
                        title: 'كتب الشكر والتقدير',
                        description: 'سيظهر السجل الفعلي واحتساب القدم بعد ربط الخدمة ببيانات الموارد البشرية.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _CategoryHeader(
                  title: 'الهوية والتحقق الرقمي',
                  icon: Icons.fingerprint_rounded,
                  badge: auth.isAdmin ? 'صلاحيات HR' : 'NFC تجريبي',
                ),
                const SizedBox(height: 12),
                _ServiceGrid(
                  items: [
                    if (auth.isAdmin)
                      _ServiceItem(
                        title: 'إدارة وتحديث بطاقات الموظفين (HR Admin)',
                        subtitle: 'استعراض الموظفين وتحديث بيانات المستمسكات حسب صلاحيات الخادم',
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
                      title: auth.isAdmin ? 'قارئ مستمسكي الشخصي' : 'قارئ البطاقة الموحدة والجواز',
                      subtitle: 'قراءة MRZ والشريحة NFC — التحقق التشفيري الكامل من SOD غير مكتمل بعد',
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

  static void _showPlannedService(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    _showServiceModal(
      context,
      title: title,
      description: description,
      isConnected: false,
    );
  }

  static void _showServiceModal(
    BuildContext context, {
    required String title,
    required String description,
    required bool isConnected,
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
                  child: Icon(
                    isConnected ? Icons.layers_outlined : Icons.construction_rounded,
                    color: const Color(0xFF0F62FE),
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
              onPressed: () => Navigator.of(ctx).pop(),
              icon: Icon(isConnected ? Icons.check_rounded : Icons.close_rounded, size: 18),
              label: Text(
                isConnected ? 'حسناً' : 'إغلاق',
                style: const TextStyle(fontWeight: FontWeight.w700),
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
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: item,
              ))
          .toList(),
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
