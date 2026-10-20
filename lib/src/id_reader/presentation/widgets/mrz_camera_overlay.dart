import 'package:flutter/material.dart';
import '../controllers/id_reader_controller.dart';

/// Guided camera viewfinder overlay tailored to ICAO 9303 ID card / Passport MRZ zones.
/// Features a semi-transparent dark mask, animated laser scanning bar, and HUD corner brackets.
class MrzCameraOverlay extends StatefulWidget {
  const MrzCameraOverlay({
    super.key,
    required this.onBack,
    this.onToggleFlash,
    this.isFlashOn = false,
    this.isFrontMode = false,
    this.onCaptureFront,
    this.onSkipFront,
    this.targetEmployeeName,
    this.documentMode = DocumentTypeMode.nationalId,
    this.onModeChanged,
  });

  final VoidCallback onBack;
  final VoidCallback? onToggleFlash;
  final bool isFlashOn;
  final bool isFrontMode;
  final VoidCallback? onCaptureFront;
  final VoidCallback? onSkipFront;
  final String? targetEmployeeName;
  final DocumentTypeMode documentMode;
  final ValueChanged<DocumentTypeMode>? onModeChanged;

  @override
  State<MrzCameraOverlay> createState() => _MrzCameraOverlayState();
}

class _MrzCameraOverlayState extends State<MrzCameraOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _laserAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final isPassport = widget.documentMode != DocumentTypeMode.nationalId;

    // Viewfinder dimensions: TD1 card (~0.64) vs TD3 passport page (~0.72)
    final boxWidth = size.width * 0.88;
    final boxHeight = boxWidth * (isPassport ? 0.72 : 0.64);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cutout mask
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.68),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: boxWidth,
                  height: boxHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Corner Brackets & Border
        Center(
          child: SizedBox(
            width: boxWidth,
            height: boxHeight,
            child: Stack(
              children: [
                // Inner dashed or subtle border
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

                // 4 Neon Corner Brackets
                const Positioned(
                  top: 0,
                  left: 0,
                  child: _CornerBracket(isTop: true, isLeft: true),
                ),
                const Positioned(
                  top: 0,
                  right: 0,
                  child: _CornerBracket(isTop: true, isLeft: false),
                ),
                const Positioned(
                  bottom: 0,
                  left: 0,
                  child: _CornerBracket(isTop: false, isLeft: true),
                ),
                const Positioned(
                  bottom: 0,
                  right: 0,
                  child: _CornerBracket(isTop: false, isLeft: false),
                ),

                // Lower MRZ Target Highlight Band (shown in Back Mode only)
                if (!widget.isFrontMode)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    height: boxHeight * (isPassport ? 0.36 : 0.42),
                    child: Container(
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isPassport
                            ? 'MRZ P<<<<<<<< (سطران للجواز)'
                            : 'MRZ ID<<<<<<< (3 أسطر للبطاقة)',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),

                // Animated Scanning Laser Bar (shown in Back Mode only)
                if (!widget.isFrontMode)
                  AnimatedBuilder(
                    animation: _laserAnim,
                    builder: (context, _) {
                      return Positioned(
                        top: 14 + (boxHeight - 32) * _laserAnim.value,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                primaryColor.withValues(alpha: 0.8),
                                Colors.tealAccent,
                                primaryColor.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.tealAccent.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),

        // Top Navigation & Document Mode Header
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _resolveScreenTitle(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                      if (widget.targetEmployeeName != null &&
                          widget.targetEmployeeName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            widget.targetEmployeeName!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  IconButton(
                    onPressed: widget.onToggleFlash,
                    icon: Icon(
                      widget.isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: widget.isFlashOn ? Colors.amber : Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Mode Selector Pills
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModePill(
                      title: 'بطاقة موحدة',
                      icon: Icons.badge_outlined,
                      isSelected: widget.documentMode == DocumentTypeMode.nationalId,
                      onTap: () => widget.onModeChanged?.call(DocumentTypeMode.nationalId),
                    ),
                    _ModePill(
                      title: 'جواز إلكتروني',
                      icon: Icons.menu_book_rounded,
                      isSelected: widget.documentMode == DocumentTypeMode.electronicPassport,
                      onTap: () => widget.onModeChanged?.call(DocumentTypeMode.electronicPassport),
                    ),
                    _ModePill(
                      title: 'جواز عادي',
                      icon: Icons.auto_stories_outlined,
                      isSelected: widget.documentMode == DocumentTypeMode.regularPassport,
                      onTap: () => widget.onModeChanged?.call(DocumentTypeMode.regularPassport),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom Controls
        if (widget.isFrontMode) ...[
          // Front Mode: Shutter capture button + Skip
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'وجّه الكاميرا نحو الوجه الأمامي واضغط زر الالتقاط',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 48),
                    // Shutter Button
                    GestureDetector(
                      onTap: widget.onCaptureFront,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: primaryColor, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.6),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(Icons.camera_alt_rounded, color: primaryColor, size: 36),
                      ),
                    ),
                    // Skip button
                    if (widget.onSkipFront != null)
                      TextButton(
                        onPressed: widget.onSkipFront,
                        child: const Text(
                          'تخطي ←',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          // Back / MRZ Mode: Dynamic instruction card
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222B).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPassport ? Icons.menu_book_rounded : Icons.qr_code_scanner,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _resolveInstructionTitle(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _resolveInstructionDesc(),
                          style: const TextStyle(
                            color: Color(0xFFB0B7C3),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _resolveScreenTitle() {
    if (widget.documentMode == DocumentTypeMode.nationalId) {
      return widget.isFrontMode ? 'الوجه الأمامي للبطاقة' : 'الوجه الخلفي (MRZ)';
    } else if (widget.documentMode == DocumentTypeMode.electronicPassport) {
      return 'جواز إلكتروني (صفحة البيانات)';
    } else {
      return 'جواز عادي (صفحة البيانات)';
    }
  }

  String _resolveInstructionTitle() {
    if (widget.documentMode == DocumentTypeMode.nationalId) {
      return 'مسح شريط الـ MRZ في الخلف';
    } else if (widget.documentMode == DocumentTypeMode.electronicPassport) {
      return 'مسح شريط الجواز الإلكتروني (MRZ)';
    } else {
      return 'قراءة الجواز العادي ضوئياً';
    }
  }

  String _resolveInstructionDesc() {
    if (widget.documentMode == DocumentTypeMode.nationalId) {
      return 'وجّه الكاميرا نحو الأسطر النصية أسفل ظهر البطاقة لمسحها تلقائياً.';
    } else if (widget.documentMode == DocumentTypeMode.electronicPassport) {
      return 'وجّه الكاميرا نحو شريط الـ MRZ في صفحة الجواز للبدء بقراءة الشريحة الذكية (NFC).';
    } else {
      return 'وجّه الكاميرا نحو شريط الـ MRZ في صفحة الجواز لقراءة البيانات فوراً بدون شريحة.';
    }
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.isTop, required this.isLeft});

  final bool isTop;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    const double length = 24;
    const double thickness = 4;
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      width: length,
      height: length,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: color, width: thickness) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: color, width: thickness) : BorderSide.none,
          left: isLeft ? BorderSide(color: color, width: thickness) : BorderSide.none,
          right: !isLeft ? BorderSide(color: color, width: thickness) : BorderSide.none,
        ),
      ),
    );
  }
}
