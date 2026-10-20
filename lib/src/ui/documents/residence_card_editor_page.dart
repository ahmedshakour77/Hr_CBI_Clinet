import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/auth_controller.dart';
import '../../models/document_models.dart';

/// Form page to capture and submit official Residence Card details and photos.
/// Matches endpoint: POST /api/documents/residence
class ResidenceCardEditorPage extends StatefulWidget {
  const ResidenceCardEditorPage({
    super.key,
    required this.auth,
    this.existingDoc,
    this.targetEmployeeId,
    this.targetEmployeeName,
  });

  final AuthController auth;
  final ResidenceDocModel? existingDoc;
  final String? targetEmployeeId;
  final String? targetEmployeeName;

  @override
  State<ResidenceCardEditorPage> createState() => _ResidenceCardEditorPageState();
}

class _ResidenceCardEditorPageState extends State<ResidenceCardEditorPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _formNumberCtrl;
  late final TextEditingController _formDateCtrl;
  late final TextEditingController _officeCtrl;
  late final TextEditingController _familyHeadCtrl;
  late final TextEditingController _governorateCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _mahallaCtrl;
  late final TextEditingController _zuqaqCtrl;
  late final TextEditingController _darCtrl;
  late String _housingType;

  Uint8List? _frontImageBytes;
  Uint8List? _backImageBytes;
  bool _isSaving = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final d = widget.existingDoc;
    _formNumberCtrl = TextEditingController(text: d?.formNumber ?? '');
    _formDateCtrl = TextEditingController(text: d?.formDate ?? '');
    _officeCtrl = TextEditingController(text: d?.informationOffice ?? '');
    _familyHeadCtrl = TextEditingController(text: d?.familyHeadName ?? '');
    _governorateCtrl = TextEditingController(text: d?.governorate ?? 'بغداد');
    _districtCtrl = TextEditingController(text: d?.district ?? '');
    _mahallaCtrl = TextEditingController(text: d?.mahalla ?? '');
    _zuqaqCtrl = TextEditingController(text: d?.zuqaq ?? '');
    _darCtrl = TextEditingController(text: d?.dar ?? '');
    final rawHousing = (d?.housingType ?? '').trim();
    _housingType = rawHousing.isNotEmpty ? rawHousing : 'دار';

    _loadExistingImages();
  }

  Future<void> _loadExistingImages() async {
    final d = widget.existingDoc;
    if (d?.cardFrontUrl != null && d!.cardFrontUrl!.isNotEmpty) {
      final bytes = await widget.auth.fetchDocumentImage(d.cardFrontUrl!);
      if (mounted && bytes != null) setState(() => _frontImageBytes = bytes);
    }
    if (d?.cardBackUrl != null && d!.cardBackUrl!.isNotEmpty) {
      final bytes = await widget.auth.fetchDocumentImage(d.cardBackUrl!);
      if (mounted && bytes != null) setState(() => _backImageBytes = bytes);
    }
  }

  @override
  void dispose() {
    _formNumberCtrl.dispose();
    _formDateCtrl.dispose();
    _officeCtrl.dispose();
    _familyHeadCtrl.dispose();
    _governorateCtrl.dispose();
    _districtCtrl.dispose();
    _mahallaCtrl.dispose();
    _zuqaqCtrl.dispose();
    _darCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isFront, ImageSource source) async {
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
          if (isFront) {
            _frontImageBytes = bytes;
          } else {
            _backImageBytes = bytes;
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

  void _showImagePickerOptions(bool isFront) {
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
                isFront ? 'تصوير الوجه الأمامي لبطاقة السكن' : 'تصوير الوجه الخلفي لبطاقة السكن',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0F62FE)),
                title: const Text('التقاط بالكاميرا الآن'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(isFront, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0F62FE)),
                title: const Text('اختيار من ألبوم الصور'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(isFront, ImageSource.gallery);
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
        'formNumber': _formNumberCtrl.text.trim(),
        'formDate': _formDateCtrl.text.trim(),
        'informationOffice': _officeCtrl.text.trim(),
        'familyHeadName': _familyHeadCtrl.text.trim(),
        'governorateName': _governorateCtrl.text.trim(),
        'district': _districtCtrl.text.trim(),
        'mahalla': _mahallaCtrl.text.trim(),
        'zuqaq': _zuqaqCtrl.text.trim(),
        'dar': _darCtrl.text.trim(),
        'housingType': _housingType,
        if (_frontImageBytes != null)
          'cardFrontBase64': base64Encode(_frontImageBytes!),
        if (_backImageBytes != null)
          'cardBackBase64': base64Encode(_backImageBytes!),
      };

      await widget.auth.saveResidence(
        payload: payload,
        targetEmployeeId: widget.targetEmployeeId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ وتحديث بيانات بطاقة السكن بنجاح!'),
          backgroundColor: Color(0xFF059669),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حفظ بطاقة السكن: $e'),
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
              ? 'تحديث بطاقة السكن: ${widget.targetEmployeeName ?? widget.targetEmployeeId}'
              : 'بطاقة السكن (ورقي عادي)',
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
                      color: colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.home_work_rounded, color: colors.primary, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'بطاقة السكن تصنف كمستمسك عادي ورقي بدون شريحة ذكية، يرجى ملء بيانات الاستمارة وتصوير الوجهين بوضوح.',
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

                  // Image Upload Cards (Front and Back)
                  Text(
                    'صور بطاقة السكن (الوجه والظهر)',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPhotoCaptureBox(
                          title: 'الوجه الأمامي',
                          bytes: _frontImageBytes,
                          onTap: () => _showImagePickerOptions(true),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildPhotoCaptureBox(
                          title: 'الوجه الخلفي',
                          bytes: _backImageBytes,
                          onTap: () => _showImagePickerOptions(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Card Data Fields
                  Text(
                    'بيانات بطاقة السكن',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _formNumberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رقم الاستمارة / البطاقة *',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال رقم الاستمارة' : null,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _formDateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'تاريخ التنظيم (YYYY-MM-DD)',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _officeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'مكتب المعلومات *',
                            prefixIcon: Icon(Icons.business_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _familyHeadCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم رب الأسرة',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Address Details
                  Text(
                    'تفاصيل العنوان الجغرافي',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _governorateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'المحافظة *',
                            prefixIcon: Icon(Icons.location_city_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _districtCtrl,
                          decoration: const InputDecoration(
                            labelText: 'القضاء / الناحية',
                            prefixIcon: Icon(Icons.map_outlined),
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
                          controller: _mahallaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'المحلة',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _zuqaqCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الزقاق',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _darCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الدار',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Builder(
                    builder: (context) {
                      final availableHousingTypes = <String>[
                        'دار',
                        'شقة',
                        'ملك',
                        'إيجار',
                        'مجمع سكني',
                        'سكن عائلي',
                      ];
                      if (_housingType.isNotEmpty && !availableHousingTypes.contains(_housingType)) {
                        availableHousingTypes.insert(0, _housingType);
                      }

                      return DropdownButtonFormField<String>(
                        initialValue: _housingType,
                        decoration: const InputDecoration(
                          labelText: 'نوع السكن',
                          prefixIcon: Icon(Icons.house_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                        ),
                        items: availableHousingTypes
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _housingType = val);
                        },
                      );
                    },
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
                      _isSaving ? 'جاري الحفظ...' : 'حفظ وتحديث بطاقة السكن',
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
