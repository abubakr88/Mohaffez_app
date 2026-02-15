import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: fontSize + 2, color: config.textColor),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status) {
      case 'pending':
        return _StatusConfig(
          label: 'قيد الانتظار',
          icon: Icons.hourglass_empty,
          bgColor: Colors.blue.shade50,
          textColor: Colors.blue.shade700,
          borderColor: Colors.blue.shade300,
        );
      case 'awaiting_payment':
        return _StatusConfig(
          label: 'في انتظار الدفع',
          icon: Icons.payment,
          bgColor: Colors.amber.shade50,
          textColor: Colors.amber.shade800,
          borderColor: Colors.amber.shade300,
        );
      case 'accepted':
        return _StatusConfig(
          label: 'مؤكدة',
          icon: Icons.check_circle,
          bgColor: Colors.green.shade50,
          textColor: Colors.green.shade700,
          borderColor: Colors.green.shade300,
        );
      case 'completed':
        return _StatusConfig(
          label: 'مكتملة',
          icon: Icons.done_all,
          bgColor: Colors.teal.shade50,
          textColor: Colors.teal.shade700,
          borderColor: Colors.teal.shade300,
        );
      case 'cancelled':
        return _StatusConfig(
          label: 'ملغية',
          icon: Icons.cancel,
          bgColor: Colors.grey.shade100,
          textColor: Colors.grey.shade700,
          borderColor: Colors.grey.shade400,
        );
      case 'expired':
        return _StatusConfig(
          label: 'منتهية',
          icon: Icons.timer_off,
          bgColor: Colors.red.shade50,
          textColor: Colors.red.shade700,
          borderColor: Colors.red.shade300,
        );
      default:
        return _StatusConfig(
          label: status,
          icon: Icons.info_outline,
          bgColor: Colors.grey.shade50,
          textColor: Colors.grey.shade700,
          borderColor: Colors.grey.shade300,
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;

  _StatusConfig({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
  });
}
