import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/arabic_labels.dart';

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
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    // CHANGED: Centralized Arabic label to avoid mojibake.
                    ArabicLabels.paymentExpired,
                    style: TextStyle(
                      color: Colors.red.shade900,
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
          bgColor = Colors.red.shade100;
          textColor = Colors.red.shade900;
          icon = Icons.warning;
        } else if (hours < 3) {
          bgColor = Colors.orange.shade100;
          textColor = Colors.orange.shade900;
          icon = Icons.timer;
        } else {
          bgColor = Colors.blue.shade50;
          textColor = Colors.blue.shade900;
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
                          '${ArabicLabels.timeRemaining}: $hours ساعة و $minutes دقيقة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 16,
                          ),
                        ),
                        if (hours < 3)
                          Text(
                            'سيتم إلغاء الطلب تلقائياً بعد انتهاء المدة',
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
                    backgroundColor: hours < 1 ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
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
