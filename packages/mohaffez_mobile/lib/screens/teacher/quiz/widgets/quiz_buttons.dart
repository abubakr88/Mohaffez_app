import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'quiz_design_tokens.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

/// Primary CTA — gradient teal pill with subtle press scale.
class TealButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const TealButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  State<TealButton> createState() => _TealButtonState();
}

class _TealButtonState extends State<TealButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp:   disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTap: disabled
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [QuizDS.teal600, QuizDS.teal500],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: QuizDS.r16,
            boxShadow: [
              BoxShadow(
                color: QuizDS.teal500.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: AppThemeConstants.white, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: AppThemeConstants.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Secondary outlined button colored by [color] (used for صحيح / خطأ pairs).
class OutlineActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const OutlineActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: QuizDS.r16,
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Back to menu" link, low-emphasis.
class BackToMenuButton extends StatelessWidget {
  final VoidCallback onTap;
  const BackToMenuButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view_rounded, size: 14, color: QuizDS.text3),
              SizedBox(width: 6),
              Text(
                'العودة إلى القائمة',
                style: TextStyle(
                  fontSize: 13,
                  color: QuizDS.text3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small colored pill used for surah/juz/ayah metadata badges.
class InfoBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const InfoBadge({
    super.key,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: QuizDS.r12,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
