import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:mohaffez_core/mohaffez_core.dart';

class PaymentDeadlineTimer extends StatefulWidget {
  const PaymentDeadlineTimer({
    super.key,
    required this.paymentDeadline,
    required this.onPayNow,
  });

  final Timestamp? paymentDeadline;
  final VoidCallback onPayNow;

  @override
  State<PaymentDeadlineTimer> createState() => _PaymentDeadlineTimerState();
}

class _PaymentDeadlineTimerState extends State<PaymentDeadlineTimer> {
  @override
  Widget build(BuildContext context) {
    if (widget.paymentDeadline == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DateTime>(
      stream:
          Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      builder: (context, _) {
        final deadline = widget.paymentDeadline!.toDate();
        final remaining = deadline.difference(DateTime.now());

        if (remaining.isNegative) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppThemeConstants.errorBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.error, color: AppThemeConstants.error),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    // CHANGED: Centralized Arabic label to avoid mojibake.
                    ArabicLabels.paymentExpired,
                    style: TextStyle(
                      color: AppThemeConstants.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final hours = remaining.inHours;
        final minutes = remaining.inMinutes.remainder(60);

        Color bgColor;
        Color textColor;
        IconData icon;
        if (hours < 1) {
          bgColor = AppThemeConstants.errorBackground;
          textColor = AppThemeConstants.error;
          icon = Icons.warning;
        } else if (hours < 3) {
          bgColor = AppThemeConstants.warningBackground;
          textColor = AppThemeConstants.warning;
          icon = Icons.timer;
        } else {
          bgColor = AppThemeConstants.accentBackground;
          textColor = AppThemeConstants.primary;
          icon = Icons.schedule;
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: textColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, color: textColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // CHANGED: Proper UTF-8 Arabic interpolation.
                          '${ArabicLabels.timeRemaining}: $hours ${hours > 1 ? ArabicLabels.hours : ArabicLabels.hour} و $minutes ${minutes > 1 ? ArabicLabels.minutes : ArabicLabels.minute}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 16,
                          ),
                        ),
                        if (hours < 3)
                          Text(
                            'ادفع الآن لتجنب إلغاء الحجز',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onPayNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hours < 1 ? AppThemeConstants.error : AppThemeConstants.success,
                    foregroundColor: AppThemeConstants.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    // CHANGED: Centralized Arabic action label.
                    ArabicLabels.payNow,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
