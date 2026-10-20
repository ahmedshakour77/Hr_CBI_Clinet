import 'package:flutter/material.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_exception.dart';
import '../../id_reader/presentation/controllers/id_reader_controller.dart';
import '../../id_reader/presentation/views/id_reader_page.dart';
import '../../models/document_models.dart';
import '../../models/employee_profile.dart';
import '../documents/document_preview_sheet.dart';
import '../documents/regular_passport_editor_page.dart';
import '../documents/residence_card_editor_page.dart';

/// Enterprise-grade, ultra-responsive Employee Directory for HR Administrators.
/// Features instant in-memory search, department filtering, employee profiling,
/// and complete multi-document verification & management (National Card, Residence Card, Passport).
class AdminEmployeesDirectoryPage extends StatefulWidget {
  const AdminEmployeesDirectoryPage({
    super.key,
    required this.auth,
    this.isEmbedded = false,
  });

  final AuthController auth;
  final bool isEmbedded;

  @override
  State<AdminEmployeesDirectoryPage> createState() => _AdminEmployeesDirectoryPageState();
}

class _AdminEmployeesDirectoryPageState extends State<AdminEmployeesDirectoryPage> {
  final TextEditingController _searchController = TextEditingController();
  List<EmployeeProfile> _allEmployees = [];
  List<EmployeeProfile> _filteredEmployees = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedFormation;
  final Set<String> _formations = {};

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await widget.auth.fetchAllEmployees();
      if (!mounted) return;

      final formations = <String>{};
      for (final e in list) {
        if (e.formation != null && e.formation!.trim().isNotEmpty) {
          formations.add(e.formation!.trim());
        }
      }

      setState(() {
        _allEmployees = list;
        _formations.clear();
        _formations.addAll(formations);
        _isLoading = false;
      });
      _applyFilter();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ أثناء تحميل دليل الموظفين: $e';
      });
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredEmployees = _allEmployees.where((emp) {
        final matchesFormation = _selectedFormation == null ||
            (emp.formation != null && emp.formation!.trim() == _selectedFormation);

        if (!matchesFormation) return false;

        if (query.isEmpty) return true;

        final name = (emp.name ?? '').toLowerCase();
        final id = (emp.employeeID ?? '').toLowerCase();
        final title = (emp.jobTitle ?? '').toLowerCase();
        final formation = (emp.formation ?? '').toLowerCase();
        final section = (emp.firstDepartment ?? '').toLowerCase();

        return name.contains(query) ||
            id.contains(query) ||
            title.contains(query) ||
            formation.contains(query) ||
            section.contains(query);
      }).toList();
    });
  }

  void _scanCardForEmployee(EmployeeProfile emp) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IdReaderPage(
          auth: widget.auth,
          targetEmployeeId: emp.employeeID,
          targetEmployeeName: emp.name,
        ),
      ),
    );
  }

  void _scanMyCardAsAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IdReaderPage(
          auth: widget.auth,
          targetEmployeeId: 'me',
          targetEmployeeName: widget.auth.profile?.name ?? 'بطاقتي أنا (كأدمن)',
        ),
      ),
    );
  }

  void _showEmployeeDetailsModal(EmployeeProfile emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmployeeDetailsSheet(
        employee: emp,
        auth: widget.auth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF161B24),
              elevation: 0,
              title: const Text(
                'دليل الموظفين وإدارة المستمسكات (HR)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: _loadEmployees,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'تحديث القائمة',
                ),
              ],
            ),
      body: Column(
        children: [
          if (widget.isEmbedded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: const Color(0xFF161B24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F62FE).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF38BDF8), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'دليل الموظفين والمستمسكات',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'صلاحية الإدارة: فحص وتحديث وثائق الموظفين',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadEmployees,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    tooltip: 'تحديث القائمة',
                  ),
                ],
              ),
            ),
          // Top Search & Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF161B24),
              border: Border(
                bottom: BorderSide(color: Colors.white10),
              ),
            ),
            child: Column(
              children: [
                // Search Input Field
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'البحث بالاسم، الرقم الوظيفي، أو التشكيل...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF38BDF8), size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilter();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: primary, width: 1.5),
                    ),
                  ),
                ),

                // Formations Filter Chips (if multiple formations exist)
                if (_formations.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _FilterChip(
                          label: 'جميع التشكيلات (${_allEmployees.length})',
                          isSelected: _selectedFormation == null,
                          onTap: () {
                            setState(() => _selectedFormation = null);
                            _applyFilter();
                          },
                        ),
                        const SizedBox(width: 8),
                        ..._formations.map((f) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _FilterChip(
                                label: f,
                                isSelected: _selectedFormation == f,
                                onTap: () {
                                  setState(() {
                                    _selectedFormation = _selectedFormation == f ? null : f;
                                  });
                                  _applyFilter();
                                },
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Main Directory Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadEmployees,
              color: primary,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0F62FE)),
            SizedBox(height: 16),
            Text(
              'جاري استقدام بيانات الموظفين بأحدث التقنيات...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadEmployees,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F62FE),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: _filteredEmployees.length + 1, // +1 for the Admin Self-Update VIP Card
      itemBuilder: (context, index) {
        if (index == 0) {
          // Admin VIP Self-Update Card
          return _AdminSelfCard(
            adminProfile: widget.auth.profile,
            onScanMyCard: _scanMyCardAsAdmin,
          );
        }

        final emp = _filteredEmployees[index - 1];
        return _EmployeeCard(
          employee: emp,
          auth: widget.auth,
          onTap: () => _showEmployeeDetailsModal(emp),
          onScanCard: () => _scanCardForEmployee(emp),
        );
      },
    );
  }
}

/// Top VIP Card allowing the Admin to update their own National Card directly
class _AdminSelfCard extends StatelessWidget {
  const _AdminSelfCard({
    required this.adminProfile,
    required this.onScanMyCard,
  });

  final EmployeeProfile? adminProfile;
  final VoidCallback onScanMyCard;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2638), Color(0xFF161F33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF0F62FE).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F62FE).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F62FE).withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF38BDF8), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'تحديث بطاقتي أنا (كأدمن)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '/me مسموح',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      adminProfile?.name ?? 'المسؤول الحالي',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                    ),
                    Text(
                      'POST /api/employees/me/national-card',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onScanMyCard,
                icon: const Icon(Icons.nfc_rounded, size: 16),
                label: const Text('مسح بطاقتي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F62FE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Standard, high-performance employee item card
class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.auth,
    required this.onTap,
    required this.onScanCard,
  });

  final EmployeeProfile employee;
  final AuthController auth;
  final VoidCallback onTap;
  final VoidCallback onScanCard;

  @override
  Widget build(BuildContext context) {
    final name = employee.name ?? 'موظف';
    final empId = employee.employeeID ?? '';
    final job = employee.jobTitle ?? employee.positionTitle ?? 'موظف';
    final formation = employee.formation ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Employee Avatar / Initial
              _EmployeeAvatar(employee: employee, auth: auth),
              const SizedBox(width: 14),

              // Employee Details Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (empId.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              empId,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (formation.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        formation,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // NFC Scan Button
              IconButton.filled(
                onPressed: onScanCard,
                icon: const Icon(Icons.nfc_rounded, size: 20),
                tooltip: 'مسح وتحديث البطاقة للموظف',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F62FE),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeAvatar extends StatelessWidget {
  const _EmployeeAvatar({required this.employee, required this.auth});

  final EmployeeProfile employee;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final empId = employee.employeeID;
    final name = employee.name ?? '';
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0F62FE).withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0F62FE).withValues(alpha: 0.4), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: (employee.hasProfilePhoto && empId != null)
          ? FutureBuilder(
              future: auth.getAccessToken().then((token) => token != null
                  ? auth.api.fetchProfilePhoto(
                      token,
                      empId,
                      version: employee.profilePhotoVersion,
                    )
                  : null),
              builder: (ctx, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                }
                return Center(
                  child: Text(
                    initial,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                );
              },
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F62FE) : const Color(0xFF1E2638),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F62FE) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Detailed Employee Inspection, Document Management and Verification BottomSheet
class _EmployeeDetailsSheet extends StatefulWidget {
  const _EmployeeDetailsSheet({
    required this.employee,
    required this.auth,
  });

  final EmployeeProfile employee;
  final AuthController auth;

  @override
  State<_EmployeeDetailsSheet> createState() => _EmployeeDetailsSheetState();
}

class _EmployeeDetailsSheetState extends State<_EmployeeDetailsSheet> {
  EmployeeDocumentsBundle? _bundle;
  bool _isLoadingDocs = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final empId = widget.employee.employeeID;
    if (empId == null || empId.isEmpty) {
      if (mounted) setState(() => _isLoadingDocs = false);
      return;
    }
    setState(() => _isLoadingDocs = true);
    final bundle = await widget.auth.fetchEmployeeDocuments(empId);
    if (!mounted) return;
    setState(() {
      _bundle = bundle;
      _isLoadingDocs = false;
    });
  }

  Future<void> _scanNationalCard() async {
    final emp = widget.employee;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IdReaderPage(
          auth: widget.auth,
          targetEmployeeId: emp.employeeID,
          targetEmployeeName: emp.name,
          initialMode: DocumentTypeMode.nationalId,
        ),
      ),
    );
    _loadDocuments();
  }

  Future<void> _scanElectronicPassport() async {
    final emp = widget.employee;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IdReaderPage(
          auth: widget.auth,
          targetEmployeeId: emp.employeeID,
          targetEmployeeName: emp.name,
          initialMode: DocumentTypeMode.electronicPassport,
        ),
      ),
    );
    _loadDocuments();
  }

  Future<void> _editResidenceCard() async {
    final emp = widget.employee;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResidenceCardEditorPage(
          auth: widget.auth,
          targetEmployeeId: emp.employeeID,
          targetEmployeeName: emp.name,
          existingDoc: _bundle?.residence,
        ),
      ),
    );
    _loadDocuments();
  }

  Future<void> _editRegularPassport() async {
    final emp = widget.employee;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegularPassportEditorPage(
          auth: widget.auth,
          targetEmployeeId: emp.employeeID,
          targetEmployeeName: emp.name,
          existingDoc: _bundle?.passport,
        ),
      ),
    );
    _loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    final bundle = _bundle;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF121622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              _EmployeeAvatar(employee: emp, auth: widget.auth),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name ?? 'تفاصيل الموظف',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'الرقم الوظيفي: ${emp.employeeID ?? "غير محدد"}',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 26),

          // Details Body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section: Official Documents Hub (3 Documents)
                  _buildDocumentsManagerCard(context, bundle),
                  const SizedBox(height: 16),

                  _SheetSection(
                    title: 'البيانات الوظيفية',
                    children: [
                      _SheetRow(label: 'التشكيل / الدائرة', value: emp.formation),
                      _SheetRow(label: 'القسم / الشعبة', value: emp.firstDepartment),
                      if (emp.administrativeUnit != null && emp.administrativeUnit!.isNotEmpty)
                        _SheetRow(label: 'الوحدة الإدارية', value: emp.administrativeUnit),
                      _SheetRow(label: 'العنوان الوظيفي', value: emp.jobTitle),
                      _SheetRow(label: 'المنصب', value: emp.positionTitle),
                      _SheetRow(label: 'الدرجة والمرحلة', value: '${emp.grade ?? "—"} / ${emp.stage ?? "—"}'),
                      _SheetRow(label: 'حالة الموظف', value: emp.employeeStatus ?? 'نشط (على ملاك البنك)'),
                      if (emp.serviceStatus != null && emp.serviceStatus!.isNotEmpty)
                        _SheetRow(label: 'حالة الخدمة', value: emp.serviceStatus),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SheetSection(
                    title: 'الخدمة والتعيين',
                    children: [
                      _SheetRow(label: 'تاريخ المباشرة', value: _formatDate(emp.hireDate)),
                      _SheetRow(label: 'سنوات الخدمة', value: emp.yearsOfService != null ? '${emp.yearsOfService} سنة' : null),
                      _SheetRow(label: 'تاريخ آخر ترفيع', value: _formatDate(emp.lastJobTitleDate)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SheetSection(
                    title: 'المؤهل والبيانات الشخصية',
                    children: [
                      _SheetRow(label: 'التحصيل الدراسي', value: emp.educationLevel),
                      _SheetRow(label: 'التخصص', value: emp.specialization),
                      _SheetRow(label: 'المواليد', value: _formatDate(emp.birthDate)),
                      _SheetRow(label: 'الجنس', value: emp.gender == 'M' ? 'ذكر' : (emp.gender == 'F' ? 'أنثى' : emp.gender)),
                      _SheetRow(label: 'الجنسية', value: emp.nationality),
                      if (emp.phoneNumber != null && emp.phoneNumber!.isNotEmpty)
                        _SheetRow(label: 'رقم الهاتف', value: emp.phoneNumber),
                      _SheetRow(label: 'البريد المؤسسي', value: emp.email),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsManagerCard(BuildContext context, EmployeeDocumentsBundle? bundle) {
    if (_isLoadingDocs) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF161B24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
            ),
            SizedBox(width: 14),
            Text(
              'جاري فحص المستمسكات المسجلة في السيرفر...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final b = bundle ?? const EmployeeDocumentsBundle();
    final completed = b.completedCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed == 3
              ? const Color(0xFF059669).withValues(alpha: 0.5)
              : const Color(0xFF0F62FE).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_shared_rounded,
                color: completed == 3 ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                size: 22,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'المستمسكات الرسمية الثلاثة (إدارة وتحديث)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: completed == 3
                      ? const Color(0xFF059669).withValues(alpha: 0.2)
                      : const Color(0xFF0F62FE).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: completed == 3
                        ? const Color(0xFF059669).withValues(alpha: 0.6)
                        : const Color(0xFF0F62FE).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '$completed من 3 مكتملة',
                  style: TextStyle(
                    color: completed == 3 ? const Color(0xFF34D399) : const Color(0xFF38BDF8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. National Card
          _buildDocItem(
            context: context,
            title: '1. البطاقة الوطنية الموحدة',
            subtitle: 'إلكترونية بشريحة ذكية (NFC / Barcode)',
            isRegistered: b.hasNationalCard,
            registeredDetail: b.nationalCard?.documentNumber != null
                ? 'رقم الوثيقة: ${b.nationalCard!.documentNumber}'
                : null,
            detailsWidget: b.hasNationalCard && b.nationalCard != null
                ? _buildAdminDocSummaryTable([
                    if (b.nationalCard!.nationalIdNumber != null)
                      MapEntry('الرقم الوطني الموحد', b.nationalCard!.nationalIdNumber!),
                    if (b.nationalCard!.fullNameAr != null)
                      MapEntry('الاسم بالكامل (عربي)', b.nationalCard!.fullNameAr!),
                    if (b.nationalCard!.fullNameEn != null)
                      MapEntry('الاسم باللاتينية', b.nationalCard!.fullNameEn!),
                    if (b.nationalCard!.expiryDate != null)
                      MapEntry('تاريخ النفاذ والانتهاء', b.nationalCard!.expiryDate!),
                  ])
                : null,
            actions: [
              _DocActionButton(
                label: 'مسح NFC',
                icon: Icons.nfc_rounded,
                isPrimary: true,
                onPressed: _scanNationalCard,
              ),
              if (b.hasNationalCard && b.nationalCard != null) ...[
                const SizedBox(width: 8),
                _DocActionButton(
                  label: 'معاينة وصور',
                  icon: Icons.visibility_rounded,
                  isPrimary: false,
                  onPressed: () {
                    DocumentPreviewSheet.showNationalCard(context, widget.auth, b.nationalCard!);
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // 2. Residence Card
          _buildDocItem(
            context: context,
            title: '2. بطاقة السكن',
            subtitle: 'ورقية عادية بدون شريحة (تصوير الاستمارة)',
            isRegistered: b.hasResidence,
            registeredDetail: b.residence?.formNumber != null
                ? 'استمارة: ${b.residence!.formNumber}'
                : null,
            detailsWidget: b.hasResidence && b.residence != null
                ? _buildAdminDocSummaryTable([
                    if (b.residence!.governorate != null || b.residence!.district != null)
                      MapEntry('المحافظة والقضاء', '${b.residence!.governorate ?? ""} - ${b.residence!.district ?? ""}'),
                    if (b.residence!.mahalla != null || b.residence!.zuqaq != null || b.residence!.dar != null)
                      MapEntry('العنوان', 'محلة ${b.residence!.mahalla ?? "-"} / زقاق ${b.residence!.zuqaq ?? "-"} / دار ${b.residence!.dar ?? "-"}'),
                    if (b.residence!.familyHeadName != null)
                      MapEntry('اسم رب الأسرة', b.residence!.familyHeadName!),
                    if (b.residence!.informationOffice != null)
                      MapEntry('مكتب المعلومات', b.residence!.informationOffice!),
                  ])
                : null,
            actions: [
              _DocActionButton(
                label: b.hasResidence ? 'تعديل / تصوير' : 'إدخال وتصوير',
                icon: Icons.edit_document,
                isPrimary: true,
                onPressed: _editResidenceCard,
              ),
              if (b.hasResidence && b.residence != null) ...[
                const SizedBox(width: 8),
                _DocActionButton(
                  label: 'معاينة وصور',
                  icon: Icons.visibility_rounded,
                  isPrimary: false,
                  onPressed: () {
                    DocumentPreviewSheet.showResidenceCard(context, widget.auth, b.residence!);
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // 3. Passport
          _buildDocItem(
            context: context,
            title: '3. جواز السفر العراقي',
            subtitle: b.passport?.isElectronic == true
                ? 'جواز إلكتروني (بشريحة ذكية)'
                : 'إلكتروني أو عادي (مقروء آلياً ورقي)',
            isRegistered: b.hasPassport,
            registeredDetail: b.passport?.passportNumber != null
                ? 'رقم الجواز: ${b.passport!.passportNumber} (${b.passport!.passportCategory ?? ""})'
                : null,
            detailsWidget: b.hasPassport && b.passport != null
                ? _buildAdminDocSummaryTable([
                    MapEntry('التصنيف والنوع', '${b.passport!.passportCategory ?? (b.passport!.isElectronic ? "إلكتروني" : "عادي")} - ${b.passport!.passportType ?? "عادي (P)"}'),
                    if (b.passport!.fullNameAr != null || b.passport!.fullNameEn != null)
                      MapEntry('الاسم بالجواز', b.passport!.fullNameAr ?? b.passport!.fullNameEn ?? "-"),
                    if (b.passport!.issueDate != null || b.passport!.expiryDate != null)
                      MapEntry('تاريخ النفاذ', '${b.passport!.issueDate ?? "-"} إلى ${b.passport!.expiryDate ?? "-"}'),
                  ])
                : null,
            actions: [
              _DocActionButton(
                label: 'مسح إلكتروني (NFC)',
                icon: Icons.nfc_rounded,
                isPrimary: true,
                onPressed: _scanElectronicPassport,
              ),
              const SizedBox(width: 8),
              _DocActionButton(
                label: b.hasPassport ? 'تعديل التفاصيل' : 'إدخال عادي ورقي',
                icon: Icons.edit_note_rounded,
                isPrimary: false,
                onPressed: _editRegularPassport,
              ),
              if (b.hasPassport && b.passport != null) ...[
                const SizedBox(width: 8),
                _DocActionButton(
                  label: 'معاينة وصور',
                  icon: Icons.visibility_rounded,
                  isPrimary: false,
                  onPressed: () {
                    DocumentPreviewSheet.showPassport(context, widget.auth, b.passport!);
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isRegistered,
    required String? registeredDetail,
    Widget? detailsWidget,
    required List<Widget> actions,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRegistered
              ? const Color(0xFF059669).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRegistered ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRegistered
                      ? const Color(0xFF059669).withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isRegistered ? 'مسجلة بالسيرفر' : 'غير مسجلة',
                  style: TextStyle(
                    color: isRegistered ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          if (registeredDetail != null) ...[
            const SizedBox(height: 4),
            Text(
              registeredDetail,
              style: const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (detailsWidget != null) ...[
            detailsWidget,
          ],
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: actions),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDocSummaryTable(List<MapEntry<String, String>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 115,
                  child: Text(
                    e.key,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static String? _formatDate(DateTime? d) {
    if (d == null) return null;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }
}

class _DocActionButton extends StatelessWidget {
  const _DocActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F62FE),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: const Color(0xFF38BDF8)),
        label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white24),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
          Flexible(
            child: Text(
              value!,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
