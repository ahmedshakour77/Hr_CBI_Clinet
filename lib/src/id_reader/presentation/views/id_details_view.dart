import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../auth/auth_controller.dart';
import '../../../auth/auth_exception.dart';
import '../../domain/entities/id_card_model.dart';

/// Detailed summary screen presenting the parsed biometric ID record,
/// decoded DG2 portrait photograph, and cryptographic security badges.
class IdDetailsView extends StatefulWidget {
  const IdDetailsView({
    super.key,
    required this.idCard,
    this.targetEmployeeId,
    this.targetEmployeeName,
    this.auth,
    this.onConfirm,
  });

  final IdCardModel idCard;
  final String? targetEmployeeId;
  final String? targetEmployeeName;
  final AuthController? auth;
  final VoidCallback? onConfirm;

  @override
  State<IdDetailsView> createState() => _IdDetailsViewState();
}

class _IdDetailsViewState extends State<IdDetailsView> {
  bool _isSaving = false;

  bool get _isTargetOther =>
      widget.targetEmployeeId != null &&
      widget.targetEmployeeId!.isNotEmpty &&
      widget.targetEmployeeId!.toLowerCase() != 'me';

  Future<void> _handleConfirm() async {
    if (widget.onConfirm != null) {
      widget.onConfirm!();
      return;
    }

    if (widget.auth == null) {
      Navigator.of(context).pop(widget.idCard);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.auth!.updateNationalCard(
        idCard: widget.idCard,
        targetEmployeeId: widget.targetEmployeeId,
      );

      if (!mounted) return;

      final isOther = _isTargetOther;
      final targetName = widget.targetEmployeeName ?? widget.targetEmployeeId ?? '';

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF161B24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.greenAccent, width: 2),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                widget.idCard.isPassport
                    ? 'تم حفظ وتحديث بيانات الجواز بنجاح'
                    : 'تم حفظ وتحديث البطاقة بنجاح',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                isOther
                    ? 'تم تحديث بيانات وصور الوثيقة للموظف ($targetName) بنجاح في قاعدة البيانات عبر الصلاحية الإدارية.\nالمسار: POST /api/employees/${widget.targetEmployeeId}/national-card'
                    : 'تم تحديث بيانات وثيقتك وصورك بنجاح في قاعدة بيانات الموارد البشرية.\nالمسار: POST /api/employees/me/national-card',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(widget.idCard);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: const Color(0xFF0F62FE),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('تم المتابعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString();
      final is403 = errStr.contains('403') || (e is AuthException && e.message.contains('403'));

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF161B24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent, width: 2),
                ),
                child: Icon(
                  is403 ? Icons.lock_person_rounded : Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                is403 ? 'تم رفض الطلب (403 Forbidden)' : 'فشل حفظ وتحديث البيانات',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                is403
                    ? 'عذراً، السيرفر قفل العملية ورفضها برمز منع 403 Forbidden.\nحسابك غير مخول بتحديث بطاقة موظف آخر. هذا المسار (/api/employees/{id}/national-card) مخصص لمسؤولي الموارد البشرية (Admin / HR) فقط.'
                    : (e is AuthException ? e.message : 'حدث خطأ غير متوقع: $e'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: is403 ? Colors.redAccent : const Color(0xFF0F62FE),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final idCard = widget.idCard;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'ملف التحقق من الهوية الرقمية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Role & Target Action Banner
            if (_isTargetOther) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0F62FE).withValues(alpha: 0.18),
                      const Color(0xFF0284C7).withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF0F62FE).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F62FE).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Color(0xFF38BDF8),
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
                              const Text(
                                'تحديث بطاقة موظف (صلاحية HR Admin)',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'مسموح للأدمن',
                                  style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'الموظف المستهدف: ${widget.targetEmployeeName ?? "الموظف #${widget.targetEmployeeId}"}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'المسار: POST /api/employees/${widget.targetEmployeeId}/national-card',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_pin_rounded, color: Colors.greenAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تحديث بطاقتك الشخصية (المسار المعتمد للموظف)',
                            style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'POST /api/employees/me/national-card',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Status Verification Ribbon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: idCard.isDocumentValid
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: idCard.isDocumentValid
                      ? Colors.green.withValues(alpha: 0.4)
                      : Colors.amber.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    idCard.isDocumentValid
                        ? Icons.verified_user_rounded
                        : Icons.warning_amber_rounded,
                    color: idCard.isDocumentValid ? Colors.greenAccent : Colors.amberAccent,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          idCard.isDocumentValid
                              ? (idCard.isBacAuthenticated
                                  ? 'تمت المصادقة وقراءة الشريحة الإلكترونية بنجاح'
                                  : 'تمت القراءة الضوئية لبيانات الجواز بنجاح')
                              : 'تنبيه التحقق من الوثيقة',
                          style: TextStyle(
                            color: idCard.isDocumentValid ? Colors.greenAccent : Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          idCard.isDocumentValid
                              ? (idCard.isBacAuthenticated
                                  ? 'تمت مطابقة التوقيع الرقمي والتشفير (BAC + SOD) مع الشريحة الأصلية.'
                                  : 'تم استخراج وتدقيق بيانات الجواز آلياً عبر الكاميرا والشريط الضوئي (MRZ).')
                              : (idCard.isExpired ? 'هذه الوثيقة منتهية الصلاحية.' : 'بانتظار التحقق من التوقيع الرقمي.'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Digital Identity Holographic Card
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E2638), Color(0xFF121622)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Card Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            idCard.isPassport ? Icons.menu_book_rounded : Icons.badge_rounded,
                            color: primary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            idCard.isPassport
                                ? (idCard.isBacAuthenticated
                                    ? 'جواز سفر إلكتروني (e-Passport)'
                                    : 'جواز سفر عادي (مقروء آلياً)')
                                : 'البطاقة الوطنية الموحدة',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          idCard.issuingCountry,
                          style: TextStyle(
                            color: primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 28),

                  // Biometric Photo + Core Info Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Facial Portrait Frame (Extracted from DG2)
                      Container(
                        width: 96,
                        height: 124,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: idCard.facePhotoBytes != null
                            ? Image.memory(
                                idCard.facePhotoBytes!,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Center(
                                  child: Icon(Icons.person, color: Colors.white38, size: 48),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.person, color: Colors.white38, size: 48),
                              ),
                      ),
                      const SizedBox(width: 18),

                      // Primary Identifiers
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (idCard.fullNameArabic != null && idCard.fullNameArabic!.isNotEmpty) ...[
                              _LabelValue(
                                label: 'الاسم الكامل',
                                value: idCard.fullNameArabic!,
                                isHighlight: true,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                idCard.fullName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ] else ...[
                              _LabelValue(
                                label: 'FULL NAME',
                                value: idCard.fullName.isNotEmpty ? idCard.fullName : 'N/A',
                                isHighlight: true,
                              ),
                            ],
                            const SizedBox(height: 10),
                            _LabelValue(
                              label: 'رقم الوثيقة / DOCUMENT NO.',
                              value: idCard.documentNumber,
                            ),
                            const SizedBox(height: 10),
                            _LabelValue(
                              label: 'الجنسية / NATIONALITY',
                              value: idCard.nationality,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Secondary Data Grid
                  Row(
                    children: [
                      Expanded(
                        child: _LabelValue(
                          label: 'تاريخ الولادة',
                          value: _formatDate(idCard.dateOfBirth),
                        ),
                      ),
                      Expanded(
                        child: _LabelValue(
                          label: 'الجنس',
                          value: idCard.gender == 'M' ? 'ذكر / M' : (idCard.gender == 'F' ? 'أنثى / F' : idCard.gender),
                        ),
                      ),
                      Expanded(
                        child: _LabelValue(
                          label: 'تاريخ النفاذ',
                          value: _formatDate(idCard.dateOfExpiry),
                        ),
                      ),
                    ],
                  ),
                  if (idCard.personalNumber != null && idCard.personalNumber!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _LabelValue(
                      label: 'الرقم الوطني الموحد / NATIONAL ID',
                      value: idCard.personalNumber!,
                      isHighlight: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Card Archived Copies Section (Front & Back Photos)
            Text(
              idCard.isPassport ? 'نسخ وثائق الجواز المحفوظة' : 'نسخ وثائق البطاقة الأصلية المحفوظة',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                if (idCard.isPassport) ...[
                  // Passport Page Thumbnail
                  Expanded(
                    flex: 2,
                    child: _CardPhotoThumbnail(
                      title: 'صفحة بيانات الجواز',
                      subtitle: 'صورة الوثيقة وشريط MRZ',
                      photoBytes: idCard.backCardPhotoBytes ?? idCard.frontCardPhotoBytes,
                      onTap: (idCard.backCardPhotoBytes ?? idCard.frontCardPhotoBytes) != null
                          ? () => _openPhotoModal(
                                context,
                                'صفحة بيانات الجواز',
                                (idCard.backCardPhotoBytes ?? idCard.frontCardPhotoBytes)!,
                              )
                          : null,
                    ),
                  ),
                ] else ...[
                  // Front Card Thumbnail
                  Expanded(
                    child: _CardPhotoThumbnail(
                      title: 'الوجه الأمامي',
                      subtitle: 'صورة البطاقة',
                      photoBytes: idCard.frontCardPhotoBytes,
                      onTap: idCard.frontCardPhotoBytes != null
                          ? () => _openPhotoModal(context, 'الوجه الأمامي للبطاقة', idCard.frontCardPhotoBytes!)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Back Card Thumbnail
                  Expanded(
                    child: _CardPhotoThumbnail(
                      title: 'الوجه الخلفي',
                      subtitle: 'شريط MRZ',
                      photoBytes: idCard.backCardPhotoBytes,
                      onTap: idCard.backCardPhotoBytes != null
                          ? () => _openPhotoModal(context, 'الوجه الخلفي للبطاقة', idCard.backCardPhotoBytes!)
                          : null,
                    ),
                  ),
                ],
                // Signature Thumbnail if available
                if (idCard.signaturePhotoBytes != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CardPhotoThumbnail(
                      title: 'التوقيع الرقمي',
                      subtitle: 'DG7 Mark',
                      photoBytes: idCard.signaturePhotoBytes,
                      onTap: () => _openPhotoModal(context, 'التوقيع الرقمي', idCard.signaturePhotoBytes!),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Additional Civil Details Section
            const Text(
              'البيانات والسجلات التفصيلية',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B24),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  if (idCard.motherName != null && idCard.motherName!.isNotEmpty) ...[
                    _DetailRow(label: 'اسم الأم', value: idCard.motherName!),
                    const Divider(color: Colors.white10),
                  ],
                  if (idCard.placeOfBirth != null && idCard.placeOfBirth!.isNotEmpty) ...[
                    _DetailRow(label: 'محل الولادة', value: idCard.placeOfBirth!),
                    const Divider(color: Colors.white10),
                  ],
                  if (idCard.dateOfIssue != null) ...[
                    _DetailRow(label: 'تاريخ الإصدار', value: _formatDate(idCard.dateOfIssue)),
                    const Divider(color: Colors.white10),
                  ],
                  if (idCard.issuingAuthority != null && idCard.issuingAuthority!.isNotEmpty) ...[
                    _DetailRow(label: 'جهة الإصدار / دائرة الأحوال', value: idCard.issuingAuthority!),
                    const Divider(color: Colors.white10),
                  ],
                  if (idCard.bloodType != null && idCard.bloodType!.isNotEmpty) ...[
                    _DetailRow(label: 'فصيلة الدم', value: idCard.bloodType!),
                    const Divider(color: Colors.white10),
                  ],
                  _DetailRow(label: 'الرقم المرجعي للـ MRZ', value: idCard.documentNumber),
                  const Divider(color: Colors.white10),
                  _DetailRow(label: 'صلاحية الوثيقة', value: idCard.isExpired ? 'منتهية' : 'سارية المفعول'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Security Details Section
            const Text(
              'تفاصيل التحقق الأمني الرقمي',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            _SecurityCheckTile(
              title: 'Basic Access Control (BAC)',
              subtitle: 'المصادقة الثنائية بمفاتيح 3DES-EDE تمت بنجاح',
              isPassed: idCard.isBacAuthenticated,
            ),
            const SizedBox(height: 8),
            _SecurityCheckTile(
              title: 'Passive Authentication (SOD)',
              subtitle: 'تطابق تجزئات DG1 و DG2 مع كائن الأمان الموقع رقمياً',
              isPassed: idCard.isSodHashVerified,
            ),
            const SizedBox(height: 8),
            _SecurityCheckTile(
              title: 'صلاحية التاريخ والوثيقة',
              subtitle: idCard.isExpired ? 'الوثيقة منتهية الصلاحية' : 'الوثيقة سارية ومطابقة للأصل',
              isPassed: !idCard.isExpired,
            ),

            const SizedBox(height: 32),

            // Confirm Action
            ElevatedButton(
              onPressed: _isSaving ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isTargetOther ? Icons.cloud_upload_rounded : Icons.verified_user_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isTargetOther
                              ? 'حفظ وتحديث بيانات الموظف (${widget.targetEmployeeName ?? widget.targetEmployeeId})'
                              : 'تأكيد وحفظ بيانات بطاقتي الشخصية',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static void _openPhotoModal(BuildContext context, String title, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF121622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _CardPhotoThumbnail extends StatelessWidget {
  const _CardPhotoThumbnail({
    required this.title,
    required this.subtitle,
    this.photoBytes,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Uint8List? photoBytes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF161B24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: photoBytes != null ? Colors.white24 : Colors.white10,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photoBytes != null)
              Image.memory(photoBytes!, fit: BoxFit.cover)
            else
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 26),
                    SizedBox(height: 4),
                    Text(
                      'غير متوفرة',
                      style: TextStyle(color: Colors.white30, fontSize: 10),
                    ),
                  ],
                ),
              ),
            // Gradient Overlay with Title
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (photoBytes != null)
                      const Icon(Icons.zoom_in, color: Colors.white70, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isHighlight ? 15 : 13,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SecurityCheckTile extends StatelessWidget {
  const _SecurityCheckTile({
    required this.title,
    required this.subtitle,
    required this.isPassed,
  });

  final String title;
  final String subtitle;
  final bool isPassed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(
            isPassed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isPassed ? Colors.greenAccent : Colors.amberAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
