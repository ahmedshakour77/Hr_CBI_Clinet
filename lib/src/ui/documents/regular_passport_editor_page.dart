import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/auth_controller.dart';
import '../../models/document_models.dart';

/// Form page for entering and uploading a Regular (non-electronic) Passport.
/// Matches endpoint: POST /api/documents/passport with isElectronic: false
class RegularPassportEditorPage extends StatefulWidget {
  const RegularPassportEditorPage({
    super.key,
    required this.auth,
    this.existingDoc,
    this.targetEmployeeId,
    this.targetEmployeeName,
  });

  final AuthController auth;
  final PassportDocModel? existingDoc;
  final String? targetEmployeeId;
  final String? targetEmployeeName;

  @override
  State<RegularPassportEditorPage> createState() => _RegularPassportEditorPageState();
}

class _RegularPassportEditorPageState extends State<RegularPassportEditorPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _passportNumberCtrl;
  late final TextEditingController _fullNameArCtrl;
  late final TextEditingController _fullNameEnCtrl;
  late final TextEditingController _motherNameCtrl;
  late final TextEditingController _placeOfBirthCtrl;
  late final TextEditingController _dateOfBirthCtrl;
  late final TextEditingController _issueDateCtrl;
  late final TextEditingController _expiryDateCtrl;
  late final TextEditingController _rawMrzCtrl;
  late String _gender;
  late String _passportType;

  Uint8List? _passportImageBytes;
  Uint8List? _bioPhotoBytes;
  bool _isSaving = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final d = widget.existingDoc;
    _passportNumberCtrl = TextEditingController(text: d?.passportNumber ?? '');
    _fullNameArCtrl = TextEditingController(text: d?.fullNameAr ?? '');
    _fullNameEnCtrl = TextEditingController(text: d?.fullNameEn ?? '');
    _motherNameCtrl = TextEditingController(text: d?.motherName ?? '');
    _placeOfBirthCtrl = TextEditingController(text: d?.placeOfBirth ?? 'بغداد');
    _dateOfBirthCtrl = TextEditingController(text: d?.dateOfBirth ?? '');
    _issueDateCtrl = TextEditingController(text: d?.issueDate ?? '');
    _expiryDateCtrl = TextEditingController(text: d?.expiryDate ?? '');
    _rawMrzCtrl = TextEditingController(text: d?.rawMrz ?? '');
    _gender = d?.gender ?? 'ذكر';
    _passportType = d?.passportType ?? 'عادي (P)';

    _loadExistingImages();
  }

  Future<void> _loadExistingImages() async {
    final d = widget.existingDoc;
    if (d?.imageUrl != null && d!.imageUrl!.isNotEmpty) {
      final bytes = await widget.auth.fetchDocumentImage(d.imageUrl!);
      if (mounted && bytes != null) setState(() => _passportImageBytes = bytes);
    }
    if (d?.biometricPhotoUrl != null && d!.biometricPhotoUrl!.isNotEmpty) {
      final bytes = await widget.auth.fetchDocumentImage(d.biometricPhotoUrl!);
      if (mounted && bytes != null) setState(() => _bioPhotoBytes = bytes);
    }
  }

  @override
  void dispose() {
    _passportNumberCtrl.dispose();
    _fullNameArCtrl.dispose();
    _fullNameEnCtrl.dispose();
    _motherNameCtrl.dispose();
    _placeOfBirthCtrl.dispose();
    _dateOfBirthCtrl.dispose();
    _issueDateCtrl.dispose();
    _expiryDateCtrl.dispose();
    _rawMrzCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isDataPage, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          if (isDataPage) {
            _passportImageBytes = bytes;
          } else {
            _bioPhotoBytes = bytes;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر التقاط الصورة: $e')),
      );
    }
  }

  void _showImagePickerOptions(bool isDataPage) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isDataPage ? 'تصوير صفحة بيانات الجواز كاملة' : 'التقاط الصورة الشخصية للوجه',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0F62FE)),
                title: const Text('التقاط بالكاميرا الآن'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(isDataPage, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0F62FE)),
                title: const Text('اختيار من ألبوم الصور'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(isDataPage, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'passportNumber': _passportNumberCtrl.text.trim(),
        'isElectronic': false, // Regular paper passport
        'passportType': _passportType,
        'countryCode': 'IRQ',
        'issuingCountry': 'العراق',
        'issuingAuthority': 'مديرية شؤون الجوازات',
        'fullNameAr': _fullNameArCtrl.text.trim(),
        'fullNameEn': _fullNameEnCtrl.text.trim(),
        'motherName': _motherNameCtrl.text.trim(),
        'placeOfBirth': _placeOfBirthCtrl.text.trim(),
        'dateOfBirth': _dateOfBirthCtrl.text.trim(),
        'gender': _gender,
        'issueDate': _issueDateCtrl.text.trim(),
        'expiryDate': _expiryDateCtrl.text.trim(),
        'rawMrz': _rawMrzCtrl.text.trim(),
        if (_passportImageBytes != null)
          'passportImageBase64': base64Encode(_passportImageBytes!),
        if (_bioPhotoBytes != null)
          'biometricPhotoBase64': base64Encode(_bioPhotoBytes!),
        'notes': 'إدخال يدوي لجواز عادي مقروء آلياً',
      };

      await widget.auth.savePassport(
        payload: payload,
        targetEmployeeId: widget.targetEmployeeId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ وتحديث بيانات جواز السفر العادي بنجاح!'),
          backgroundColor: Color(0xFF059669),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حفظ بيانات الجواز: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isOther = widget.targetEmployeeId != null &&
        widget.targetEmployeeId!.isNotEmpty &&
        widget.targetEmployeeId!.toLowerCase() != 'me';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isOther
              ? 'تحديث الجواز: ${widget.targetEmployeeName ?? widget.targetEmployeeId}'
              : 'جواز السفر (عادي مقروء آلياً)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Notice Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flight_rounded, color: Color(0xFF0284C7), size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'هذا النموذج مخصص لجواز السفر العادي (الورقي المقروء آلياً). إذا كان جوازك إلكترونياً يحتوي على شريحة ذكية، يرجى استخدام ميزة القراءة اللحظية عبر NFC من الصفحة السابقة.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Image Upload Cards
                  Text(
                    'صور صفحة الجواز والصورة الشخصية',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildPhotoCaptureBox(
                          title: 'صفحة البيانات كاملة',
                          bytes: _passportImageBytes,
                          onTap: () => _showImagePickerOptions(true),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: _buildPhotoCaptureBox(
                          title: 'صورة الوجه',
                          bytes: _bioPhotoBytes,
                          onTap: () => _showImagePickerOptions(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Passport Fields
                  Text(
                    'بيانات الجواز',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _passportNumberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رقم الجواز (مثال: A12345678) *',
                      prefixIcon: Icon(Icons.numbers_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال رقم الجواز' : null,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _fullNameArCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الاسم بالعربية',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _fullNameEnCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الاسم بالإنجليزية',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _motherNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم الأم',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _placeOfBirthCtrl,
                          decoration: const InputDecoration(
                            labelText: 'محل الولادة',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _dateOfBirthCtrl,
                          decoration: const InputDecoration(
                            labelText: 'المواليد (YYYY-MM-DD)',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: const InputDecoration(
                            labelText: 'الجنس',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                            DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _gender = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _issueDateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'تاريخ الإصدار',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _expiryDateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'تاريخ النفاذ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_rounded),
                    label: Text(
                      _isSaving ? 'جاري الحفظ...' : 'حفظ وتحديث جواز السفر',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCaptureBox({
    required String title,
    required Uint8List? bytes,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: bytes != null ? Colors.green : colors.outlineVariant.withValues(alpha: 0.45),
            width: bytes != null ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes, fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.65),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: colors.primary, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'انقر للتصوير',
                    style: TextStyle(fontSize: 10, color: colors.outline),
                  ),
                ],
              ),
      ),
    );
  }
}
