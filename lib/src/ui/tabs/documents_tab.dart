import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../id_reader/id_reader.dart';
import '../../models/document_models.dart';
import '../documents/document_preview_sheet.dart';
import '../documents/regular_passport_editor_page.dart';
import '../documents/residence_card_editor_page.dart';

/// The Official Documents Hub tab displaying the 3 mandatory Iraqi documents:
/// 1. Unified National Card (البطاقة الوطنية الموحدة - Always Electronic)
/// 2. Residence Card (بطاقة السكن - Always Paper)
/// 3. Passport (جواز السفر - Electronic with chip or Regular paper)
class DocumentsTab extends StatefulWidget {
  const DocumentsTab({super.key, required this.auth});

  final AuthController auth;

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
  @override
  void initState() {
    super.initState();
    widget.auth.loadMyDocuments();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final auth = widget.auth;
    final bundle = auth.myDocuments ?? const EmployeeDocumentsBundle();

    return RefreshIndicator(
      onRefresh: () async {
        await auth.loadMyDocuments();
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
                // Top Completion Status Hero Card
                _buildCompletionHeroCard(context, bundle),
                const SizedBox(height: 24),

                // Section 1: National Card
                _buildNationalCardSection(context, bundle.nationalCard, bundle),
                const SizedBox(height: 20),

                // Section 2: Residence Card
                _buildResidenceCardSection(context, bundle.residence, bundle),
                const SizedBox(height: 20),

                // Section 3: Passport
                _buildPassportSection(context, bundle.passport, bundle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionHeroCard(BuildContext context, EmployeeDocumentsBundle bundle) {
    final total = 3;
    final completed = bundle.completedCount;
    final ratio = bundle.completionRatio;
    final isAllComplete = completed == total;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isAllComplete
              ? [const Color(0xFF047857), const Color(0xFF059669)]
              : [const Color(0xFF0F62FE), const Color(0xFF0284C7)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isAllComplete ? const Color(0xFF059669) : const Color(0xFF0F62FE))
                .withValues(alpha: 0.28),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isAllComplete ? Icons.verified_user_rounded : Icons.folder_shared_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المستمسكات الرسمية الثلاثة',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isAllComplete
                          ? 'جميع المستمسكات مكتملة وموثقة في السيرفر'
                          : 'مكتمل $completed من أصل $total مستمسكات معتمدة',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completed / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 1. NATIONAL CARD SECTION
  // --------------------------------------------------------------------------
  Widget _buildNationalCardSection(
    BuildContext context,
    NationalCardDocModel? doc,
    EmployeeDocumentsBundle bundle,
  ) {
    final colors = Theme.of(context).colorScheme;
    final isAvailable = bundle.hasNationalCard || (doc != null && doc.isAvailable);

    return _DocumentCardShell(
      icon: Icons.credit_card_rounded,
      accentColor: const Color(0xFF0F62FE),
      title: 'البطاقة الوطنية الموحدة',
      categoryBadge: 'إلكتروني (شريحة ذكية)',
      isElectronic: true,
      isAvailable: isAvailable,
      lastUpdated: doc?.issueDate != null ? 'تاريخ الإصدار: ${doc!.issueDate}' : null,
      content: isAvailable
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoRow('رقم البطاقة (Document No):', doc?.documentNumber ?? '-'),
                _buildInfoRow('الرقم الوطني الموحد:', doc?.nationalIdNumber ?? '-'),
                _buildInfoRow('الاسم الكامل (عربي):', doc?.fullNameAr ?? '-'),
                _buildInfoRow('الاسم اللاتيني (MRZ):', doc?.fullNameEn ?? '-'),
                _buildInfoRow('تاريخ التولد والجنس:', '${doc?.dateOfBirth ?? "-"} (${doc?.gender ?? "-"})'),
                _buildInfoRow('تاريخ النفاذ والانتهاء:', doc?.expiryDate ?? '-'),
                if (doc != null)
                  _DocumentThumbnailStrip(
                    auth: widget.auth,
                    images: [
                      if (doc.hasFrontImage && doc.frontImageUrl != null)
                        _DocImageItem(
                          label: 'الوجه الأمامي',
                          url: doc.frontImageUrl,
                          onTap: () => DocumentPreviewSheet.showNationalCard(context, widget.auth, doc),
                        ),
                      if (doc.hasBackImage && doc.backImageUrl != null)
                        _DocImageItem(
                          label: 'الوجه الخلفي',
                          url: doc.backImageUrl,
                          onTap: () => DocumentPreviewSheet.showNationalCard(context, widget.auth, doc),
                        ),
                      if (doc.hasBiometricFace && doc.biometricFaceUrl != null)
                        _DocImageItem(
                          label: 'صورة الشريحة',
                          url: doc.biometricFaceUrl,
                          icon: Icons.face_rounded,
                          onTap: () => DocumentPreviewSheet.showNationalCard(context, widget.auth, doc),
                        ),
                    ],
                  ),
              ],
            )
          : Text(
              'لم يتم تسجيل البطاقة الوطنية في حسابك حتى الآن. يمكنك سحب بياناتها وصورتها الحيوية فوراً من شريحة البطاقة عبر الهاتف.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13, height: 1.4),
            ),
      primaryActionLabel: isAvailable ? 'سحب أو تحديث نسخة جديدة (NFC)' : 'قراءة وتسجيل البطاقة الآن (NFC)',
      primaryActionIcon: Icons.nfc_rounded,
      onPrimaryAction: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IdReaderPage(
              auth: widget.auth,
              initialMode: DocumentTypeMode.nationalId,
            ),
          ),
        ).then((_) => widget.auth.loadMyDocuments());
      },
      secondaryActionLabel: (isAvailable && doc != null) ? 'معاينة الوثيقة' : null,
      onSecondaryAction: (isAvailable && doc != null)
          ? () => DocumentPreviewSheet.showNationalCard(context, widget.auth, doc)
          : null,
    );
  }

  // --------------------------------------------------------------------------
  // 2. RESIDENCE CARD SECTION
  // --------------------------------------------------------------------------
  Widget _buildResidenceCardSection(
    BuildContext context,
    ResidenceDocModel? doc,
    EmployeeDocumentsBundle bundle,
  ) {
    final colors = Theme.of(context).colorScheme;
    final isAvailable = bundle.hasResidence || (doc != null && doc.isAvailable);

    return _DocumentCardShell(
      icon: Icons.home_work_rounded,
      accentColor: const Color(0xFFD97706),
      title: 'بطاقة السكن',
      categoryBadge: 'عادي (ورقي)',
      isElectronic: false,
      isAvailable: isAvailable,
      lastUpdated: doc?.formDate != null ? 'تاريخ التنظيم: ${doc!.formDate}' : null,
      content: isAvailable
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoRow('رقم الاستمارة:', doc?.formNumber ?? '-'),
                _buildInfoRow('مكتب المعلومات:', doc?.informationOffice ?? '-'),
                _buildInfoRow('اسم رب الأسرة:', doc?.familyHeadName ?? '-'),
                _buildInfoRow('المحافظة والقضاء:', '${doc?.governorate ?? ''} - ${doc?.district ?? ''}'),
                _buildInfoRow('العنوان الكامل:', 'محلة ${doc?.mahalla ?? '-'} / زقاق ${doc?.zuqaq ?? '-'} / دار ${doc?.dar ?? '-'}'),
                _buildInfoRow('نوع السكن:', doc?.housingType ?? '-'),
                if (doc != null)
                  _DocumentThumbnailStrip(
                    auth: widget.auth,
                    images: [
                      if (doc.hasCardFront && doc.cardFrontUrl != null)
                        _DocImageItem(
                          label: 'الوجه الأمامي',
                          url: doc.cardFrontUrl,
                          onTap: () => DocumentPreviewSheet.showResidenceCard(context, widget.auth, doc),
                        ),
                      if (doc.hasCardBack && doc.cardBackUrl != null)
                        _DocImageItem(
                          label: 'الوجه الخلفي',
                          url: doc.cardBackUrl,
                          onTap: () => DocumentPreviewSheet.showResidenceCard(context, widget.auth, doc),
                        ),
                    ],
                  ),
              ],
            )
          : Text(
              'بطاقة السكن غير مسجلة بعد. يمكنك تصوير الوجهين وإدخال بيانات الاستمارة من هاتفك مباشرة لتثبيتها في ملفك.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13, height: 1.4),
            ),
      primaryActionLabel: isAvailable ? 'تعديل أو إدخال تفاصيل جديدة' : 'إدخال وتصوير بطاقة السكن',
      primaryActionIcon: Icons.edit_document,
      onPrimaryAction: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResidenceCardEditorPage(
              auth: widget.auth,
              existingDoc: doc,
            ),
          ),
        ).then((_) => widget.auth.loadMyDocuments());
      },
      secondaryActionLabel: (isAvailable && doc != null) ? 'معاينة بطاقة السكن' : null,
      onSecondaryAction: (isAvailable && doc != null)
          ? () => DocumentPreviewSheet.showResidenceCard(context, widget.auth, doc)
          : null,
    );
  }

  // --------------------------------------------------------------------------
  // 3. PASSPORT SECTION
  // --------------------------------------------------------------------------
  Widget _buildPassportSection(
    BuildContext context,
    PassportDocModel? doc,
    EmployeeDocumentsBundle bundle,
  ) {
    final colors = Theme.of(context).colorScheme;
    final isAvailable = bundle.hasPassport || (doc != null && doc.isAvailable);
    final isElectronic = doc?.isElectronic ?? true;

    return _DocumentCardShell(
      icon: Icons.flight_takeoff_rounded,
      accentColor: const Color(0xFF0284C7),
      title: 'جواز السفر العراقي',
      categoryBadge: isElectronic ? 'إلكتروني (شريحة ذكية)' : 'عادي (مقروء آلياً)',
      isElectronic: isElectronic,
      isAvailable: isAvailable,
      lastUpdated: doc?.expiryDate != null ? 'تاريخ النفاذ: ${doc!.expiryDate}' : null,
      content: isAvailable
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoRow('رقم الجواز:', doc?.passportNumber ?? '-'),
                _buildInfoRow('التصنيف والنوع:', '${doc?.passportCategory ?? (isElectronic ? 'إلكتروني' : 'عادي')} - ${doc?.passportType ?? 'عادي (P)'}'),
                _buildInfoRow('الاسم بالجواز:', doc?.fullNameAr ?? doc?.fullNameEn ?? '-'),
                if ((doc?.motherName ?? '').isNotEmpty)
                  _buildInfoRow('اسم الأم:', doc!.motherName!),
                if (doc?.dateOfBirth != null || doc?.placeOfBirth != null)
                  _buildInfoRow('مكان وتاريخ الولادة:', '${doc?.placeOfBirth ?? ""} ${doc?.dateOfBirth ?? ""}'.trim()),
                _buildInfoRow('تاريخ الإصدار والنفاذ:', '${doc?.issueDate ?? '-'} إلى ${doc?.expiryDate ?? '-'}'),
                if (doc != null)
                  _DocumentThumbnailStrip(
                    auth: widget.auth,
                    images: [
                      if (doc.hasImage && doc.imageUrl != null)
                        _DocImageItem(
                          label: 'صفحة البيانات',
                          url: doc.imageUrl,
                          onTap: () => DocumentPreviewSheet.showPassport(context, widget.auth, doc),
                        ),
                      if (doc.hasBioPhoto && doc.biometricPhotoUrl != null)
                        _DocImageItem(
                          label: 'الصورة البيومترية',
                          url: doc.biometricPhotoUrl,
                          icon: Icons.face_rounded,
                          onTap: () => DocumentPreviewSheet.showPassport(context, widget.auth, doc),
                        ),
                    ],
                  ),
              ],
            )
          : Text(
              'جواز السفر غير مسجل حالياً. يدعم النظام قراءة الجواز الإلكتروني الجديد عبر NFC، أو مسح وتصوير الجواز العادي بالكاميرا وإدخال بياناته.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13, height: 1.4),
            ),
      customActions: isAvailable
          ? [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RegularPassportEditorPage(
                              auth: widget.auth,
                              existingDoc: doc,
                            ),
                          ),
                        ).then((_) => widget.auth.loadMyDocuments());
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text(
                        'تعديل تفاصيل الجواز',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                  if (doc != null) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => DocumentPreviewSheet.showPassport(context, widget.auth, doc),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size(90, 46),
                      ),
                      child: const Text(
                        'معاينة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => IdReaderPage(
                        auth: widget.auth,
                        initialMode: DocumentTypeMode.electronicPassport,
                      ),
                    ),
                  ).then((_) => widget.auth.loadMyDocuments());
                },
                icon: const Icon(Icons.nfc_rounded, size: 18, color: Color(0xFF0284C7)),
                label: const Text(
                  'سحب وقراءة جواز إلكتروني جديد (NFC)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ]
          : [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => IdReaderPage(
                              auth: widget.auth,
                              initialMode: DocumentTypeMode.electronicPassport,
                            ),
                          ),
                        ).then((_) => widget.auth.loadMyDocuments());
                      },
                      icon: const Icon(Icons.nfc_rounded, size: 18),
                      label: const Text('جواز إلكتروني (NFC)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RegularPassportEditorPage(
                              auth: widget.auth,
                              existingDoc: doc,
                            ),
                          ),
                        ).then((_) => widget.auth.loadMyDocuments());
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('جواز عادي (ورقي)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                ],
              ),
            ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Strip displaying fetched document photos with preview on tap
class _DocumentThumbnailStrip extends StatelessWidget {
  const _DocumentThumbnailStrip({
    required this.auth,
    required this.images,
  });

  final AuthController auth;
  final List<_DocImageItem> images;

  @override
  Widget build(BuildContext context) {
    final validImages = images.where((i) => i.url != null && i.url!.isNotEmpty).toList();
    if (validImages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'النسخ والصور المسجلة بالسيرفر (اضغط للمعاينة):',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: validImages.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final item = validImages[i];
              return _DocThumbnailBox(
                auth: auth,
                item: item,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DocImageItem {
  const _DocImageItem({
    required this.label,
    required this.url,
    this.icon = Icons.image_rounded,
    this.onTap,
  });

  final String label;
  final String? url;
  final IconData icon;
  final VoidCallback? onTap;
}

class _DocThumbnailBox extends StatelessWidget {
  const _DocThumbnailBox({required this.auth, required this.item});

  final AuthController auth;
  final _DocImageItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        item.onTap?.call();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 100,
        height: 74,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.url != null && item.url!.isNotEmpty)
              FutureBuilder<Uint8List?>(
                future: auth.fetchDocumentImage(item.url!),
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.memory(snapshot.data!, fit: BoxFit.cover);
                  }
                  return const Center(
                    child: Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey),
                  );
                },
              )
            else
              const Center(
                child: Icon(Icons.image_not_supported_rounded, size: 20, color: Colors.grey),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                color: Colors.black.withValues(alpha: 0.65),
                child: Text(
                  item.label,
                  style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic stylish card container for document items
class _DocumentCardShell extends StatelessWidget {
  const _DocumentCardShell({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.categoryBadge,
    required this.isElectronic,
    required this.isAvailable,
    this.lastUpdated,
    required this.content,
    this.primaryActionLabel,
    this.primaryActionIcon,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.customActions,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String categoryBadge;
  final bool isElectronic;
  final bool isAvailable;
  final String? lastUpdated;
  final Widget content;
  final String? primaryActionLabel;
  final IconData? primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final List<Widget>? customActions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isAvailable
              ? colors.outlineVariant.withValues(alpha: 0.45)
              : Colors.amber.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          categoryBadge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isElectronic ? const Color(0xFF0F62FE) : const Color(0xFFD97706),
                          ),
                        ),
                        if (lastUpdated != null) ...[
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          const SizedBox(width: 6),
                          Text(
                            lastUpdated!,
                            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isAvailable ? const Color(0xFF059669) : Colors.amber.shade800)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isAvailable ? const Color(0xFF059669) : Colors.amber.shade800)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAvailable ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 13,
                      color: isAvailable ? const Color(0xFF059669) : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isAvailable ? 'مسجلة بالسيرفر' : 'غير متوفرة',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? const Color(0xFF059669) : Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Body Content
          content,

          // Actions Row / Buttons
          if (customActions != null && customActions!.isNotEmpty) ...[
            const SizedBox(height: 18),
            ...customActions!,
          ] else if (primaryActionLabel != null && onPrimaryAction != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onPrimaryAction,
                    icon: Icon(primaryActionIcon ?? Icons.check, size: 18),
                    label: Text(
                      primaryActionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: isAvailable ? colors.primary : accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                ),
                if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: onSecondaryAction,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(90, 46),
                    ),
                    child: Text(
                      secondaryActionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
