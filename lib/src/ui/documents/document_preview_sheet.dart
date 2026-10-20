import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../auth/auth_controller.dart';
import '../../models/document_models.dart';

/// Modal bottom sheet to preview authenticated document images (front, back, biometric photo).
class DocumentPreviewSheet extends StatefulWidget {
  const DocumentPreviewSheet({
    super.key,
    required this.title,
    required this.auth,
    this.primaryImageUrl,
    this.secondaryImageUrl,
    this.primaryImageTitle = 'الوجه الأمامي',
    this.secondaryImageTitle = 'الوجه الخلفي',
    this.localPrimaryBytes,
    this.localSecondaryBytes,
    this.details = const {},
  });

  final String title;
  final AuthController auth;
  final String? primaryImageUrl;
  final String? secondaryImageUrl;
  final String primaryImageTitle;
  final String secondaryImageTitle;
  final Uint8List? localPrimaryBytes;
  final Uint8List? localSecondaryBytes;
  final Map<String, String?> details;

  static void show(
    BuildContext context, {
    required String title,
    required AuthController auth,
    String? primaryImageUrl,
    String? secondaryImageUrl,
    String primaryImageTitle = 'الوجه الأمامي',
    String secondaryImageTitle = 'الوجه الخلفي',
    Uint8List? localPrimaryBytes,
    Uint8List? localSecondaryBytes,
    Map<String, String?> details = const {},
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DocumentPreviewSheet(
        title: title,
        auth: auth,
        primaryImageUrl: primaryImageUrl,
        secondaryImageUrl: secondaryImageUrl,
        primaryImageTitle: primaryImageTitle,
        secondaryImageTitle: secondaryImageTitle,
        localPrimaryBytes: localPrimaryBytes,
        localSecondaryBytes: localSecondaryBytes,
        details: details,
      ),
    );
  }

  static void showNationalCard(
    BuildContext context,
    AuthController auth,
    NationalCardDocModel card,
  ) {
    show(
      context,
      title: 'البطاقة الوطنية الموحدة',
      auth: auth,
      primaryImageUrl: card.frontImageUrl,
      secondaryImageUrl: card.backImageUrl,
      primaryImageTitle: 'الوجه الأمامي للبطاقة',
      secondaryImageTitle: 'الوجه الخلفي للبطاقة',
      details: {
        'رقم الوثيقة': card.documentNumber,
        'الرقم الوطني الموحد': card.nationalIdNumber,
        'الاسم الكامل بالعربية': card.fullNameAr,
        'الاسم بالإنجليزية': card.fullNameEn,
        'تاريخ التولد': card.dateOfBirth,
        'الجنس': card.gender,
        'الجنسية': card.nationality,
        'جهة الإصدار': card.issuingState,
        'تاريخ الإصدار': card.issueDate,
        'تاريخ انتهاء الصلاحية': card.expiryDate,
      },
    );
  }

  static void showResidenceCard(
    BuildContext context,
    AuthController auth,
    ResidenceDocModel doc,
  ) {
    show(
      context,
      title: 'بطاقة السكن',
      auth: auth,
      primaryImageUrl: doc.cardFrontUrl,
      secondaryImageUrl: doc.cardBackUrl,
      primaryImageTitle: 'الوجه الأمامي لبطاقة السكن',
      secondaryImageTitle: 'الوجه الخلفي لبطاقة السكن',
      details: {
        'رقم الاستمارة': doc.formNumber,
        'تاريخ التنظيم': doc.formDate,
        'مكتب المعلومات': doc.informationOffice,
        'اسم رب الأسرة': doc.familyHeadName,
        'المحافظة': doc.governorate,
        'القضاء': doc.district,
        'المحلة': doc.mahalla,
        'الزقاق': doc.zuqaq,
        'الدار': doc.dar,
        'نوع السكن': doc.housingType,
      },
    );
  }

  static void showPassport(
    BuildContext context,
    AuthController auth,
    PassportDocModel doc,
  ) {
    show(
      context,
      title: 'جواز السفر (${doc.passportCategory ?? (doc.isElectronic ? "إلكتروني" : "عادي")})',
      auth: auth,
      primaryImageUrl: doc.imageUrl,
      secondaryImageUrl: doc.biometricPhotoUrl,
      primaryImageTitle: 'صفحة البيانات المقروءة آلياً',
      secondaryImageTitle: 'صورة الوجه البيومترية',
      details: {
        'رقم الجواز': doc.passportNumber,
        'نوع الجواز': doc.passportType,
        'فئة الجواز': doc.passportCategory,
        'الاسم الكامل': doc.fullNameAr ?? doc.fullNameEn,
        'اسم الأم': doc.motherName,
        'الرقم الوطني': doc.nationalIdNumber,
        'مكان وتاريخ الولادة': '${doc.placeOfBirth ?? ""} ${doc.dateOfBirth ?? ""}'.trim(),
        'الجنس': doc.gender,
        'جهة الإصدار': doc.issuingAuthority,
        'تاريخ الإصدار': doc.issueDate,
        'تاريخ انتهاء الصلاحية': doc.expiryDate,
      },
    );
  }

  @override
  State<DocumentPreviewSheet> createState() => _DocumentPreviewSheetState();
}

class _DocumentPreviewSheetState extends State<DocumentPreviewSheet> {
  Uint8List? _primaryBytes;
  Uint8List? _secondaryBytes;
  bool _loadingPrimary = false;
  bool _loadingSecondary = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    if (widget.localPrimaryBytes != null) {
      _primaryBytes = widget.localPrimaryBytes;
    } else if (widget.primaryImageUrl != null && widget.primaryImageUrl!.isNotEmpty) {
      setState(() => _loadingPrimary = true);
      _primaryBytes = await widget.auth.fetchDocumentImage(widget.primaryImageUrl!);
      if (mounted) setState(() => _loadingPrimary = false);
    }

    if (widget.localSecondaryBytes != null) {
      _secondaryBytes = widget.localSecondaryBytes;
    } else if (widget.secondaryImageUrl != null && widget.secondaryImageUrl!.isNotEmpty) {
      setState(() => _loadingSecondary = true);
      _secondaryBytes = await widget.auth.fetchDocumentImage(widget.secondaryImageUrl!);
      if (mounted) setState(() => _loadingSecondary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.badge_rounded, color: colors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Images Grid/Cards
                  if (widget.primaryImageUrl != null || widget.localPrimaryBytes != null) ...[
                    _buildImageCard(
                      title: widget.primaryImageTitle,
                      bytes: _primaryBytes,
                      isLoading: _loadingPrimary,
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (widget.secondaryImageUrl != null || widget.localSecondaryBytes != null) ...[
                    _buildImageCard(
                      title: widget.secondaryImageTitle,
                      bytes: _secondaryBytes,
                      isLoading: _loadingSecondary,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Details Fields Table
                  if (widget.details.isNotEmpty) ...[
                    Text(
                      'البيانات المسجلة بالوثيقة',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: widget.details.entries.map((entry) {
                          final val = entry.value;
                          if (val == null || val.trim().isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    val,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard({
    required String title,
    required Uint8List? bytes,
    required bool isLoading,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.image_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            height: 200,
            color: Colors.black.withValues(alpha: 0.05),
            alignment: Alignment.center,
            child: isLoading
                ? const CircularProgressIndicator()
                : (bytes != null && bytes.isNotEmpty)
                    ? InteractiveViewer(
                        clipBehavior: Clip.none,
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: 200,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 36, color: colors.outline),
                          const SizedBox(height: 6),
                          Text(
                            'لم يتم تحميل الصورة',
                            style: TextStyle(color: colors.outline, fontSize: 12),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
