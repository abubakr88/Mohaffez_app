import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

class QuranMistakePainter extends CustomPainter {
  final List<QuranMistake> mistakes;

  QuranMistakePainter({required this.mistakes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final mistake in mistakes) {
      final dx = mistake.xPosition.clamp(0.0, 1.0) * size.width;
      final dy = mistake.yPosition.clamp(0.0, 1.0) * size.height;

      final fillPaint = Paint()
        ..color = getMistakeColor(mistake.type).withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = AppThemeConstants.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(dx, dy), 16, fillPaint);
      canvas.drawCircle(Offset(dx, dy), 16, strokePaint);

      if (mistake.hasComment) {
        final commentPaint = Paint()
          ..color = AppThemeConstants.accentBlueDark
          ..style = PaintingStyle.fill;
        final commentStroke = Paint()
          ..color = AppThemeConstants.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        final commentOffset = Offset(dx + 12, dy - 12);
        canvas.drawCircle(commentOffset, 7.5, commentPaint);
        canvas.drawCircle(commentOffset, 7.5, commentStroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant QuranMistakePainter oldDelegate) {
    return oldDelegate.mistakes != mistakes;
  }
}
