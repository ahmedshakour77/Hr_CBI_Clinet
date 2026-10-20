import 'package:flutter/material.dart';

/// Modal bottom sheet presenting high-tech animated NFC radar rings,
/// physical card positioning advice, and real-time APDU read progress.
class NfcTappingSheet extends StatefulWidget {
  const NfcTappingSheet({
    super.key,
    required this.stepDescription,
    required this.progress,
    required this.onCancel,
    this.onSkipNfc,
    this.isPassport = false,
  });

  final String stepDescription;
  final double progress;
  final VoidCallback onCancel;
  final VoidCallback? onSkipNfc;
  final bool isPassport;

  @override
  State<NfcTappingSheet> createState() => _NfcTappingSheetState();
}

class _NfcTappingSheetState extends State<NfcTappingSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF14171E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'جاهز لقراءة الشريحة الذكية (NFC)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            widget.isPassport
                ? 'للجواز الإلكتروني: ضع ظهر الهاتف مباشرة فوق صفحة البيانات البلاستيكية أو الغلاف الخلفي للجواز وثبّته'
                : 'ضع ظهر البطاقة على ظهر الهاتف وثبّته حتى اكتمال القراءة',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9EA7B8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 26),

          // Pulsing Radar / Phone Animation
          SizedBox(
            height: 130,
            width: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Concentric Expanding Rings
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(130, 130),
                      painter: _RadarPulsePainter(
                        animationValue: _pulseController.value,
                        color: primary,
                      ),
                    );
                  },
                ),

                // Center Icon Circle
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primary.withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    widget.isPassport ? Icons.menu_book_rounded : Icons.nfc_rounded,
                    color: primary,
                    size: 34,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: widget.progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
          const SizedBox(height: 12),

          // Status Step Description
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.stepDescription,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${(widget.progress * 100).toInt()}%',
                style: TextStyle(
                  color: primary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Option: Skip NFC for regular passports without chip
          if (widget.onSkipNfc != null) ...[
            FilledButton.tonalIcon(
              onPressed: widget.onSkipNfc,
              icon: const Icon(Icons.flash_on_rounded, size: 18),
              label: const Text(
                'جواز عادي (بدون شريحة) - إنهاء بالقراءة الضوئية',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: Colors.amber.withValues(alpha: 0.18),
                foregroundColor: Colors.amberAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amberAccent.withValues(alpha: 0.4)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Cancel button
          OutlinedButton(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'إلغاء المسح',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPulsePainter extends CustomPainter {
  const _RadarPulsePainter({
    required this.animationValue,
    required this.color,
  });

  final double animationValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final waveProgress = (animationValue + (i / 3.0)) % 1.0;
      final radius = 36 + (maxRadius - 36) * waveProgress;
      final alpha = (1.0 - waveProgress).clamp(0.0, 0.8);

      final paint = Paint()
        ..color = color.withValues(alpha: alpha * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
