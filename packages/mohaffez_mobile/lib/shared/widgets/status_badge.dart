import 'package:flutter/material.dart';
import '../theme/app_theme_constants.dart';

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
          bgColor: AppThemeConstants.info.withValues(alpha: 0.1),
          textColor: AppThemeConstants.info,
          borderColor: AppThemeConstants.info.withValues(alpha: 0.3),
        );
      case 'awaitingpayment':
        return _StatusConfig(
          label: 'في انتظار الدفع',
          icon: Icons.payment,
          bgColor: AppThemeConstants.warning.withValues(alpha: 0.1),
          textColor: AppThemeConstants.warning,
          borderColor: AppThemeConstants.warning.withValues(alpha: 0.3),
        );

      // ── NEW ──────────────────────────────────────────────────────────────
      case 'awaitingdirectpaymentconfirmation':
        return _StatusConfig(
          label: 'في انتظار تأكيد الدفع المباشر',
          icon: Icons.payments_outlined,
          bgColor: AppThemeConstants.warning.withValues(alpha: 0.1),
          textColor: AppThemeConstants.warning,
          borderColor: AppThemeConstants.warning.withValues(alpha: 0.3),
        );
      // ─────────────────────────────────────────────────────────────────────

      case 'accepted':
      // ── NEW: legacy poisoned docs — render identically to accepted ───────
      case 'confirmed':
        return _StatusConfig(
          label: 'مؤكدة',
          icon: Icons.check_circle,
          bgColor: AppThemeConstants.success.withValues(alpha: 0.1),
          textColor: AppThemeConstants.success,
          borderColor: AppThemeConstants.success.withValues(alpha: 0.3),
        );

      case 'completed':
        return _StatusConfig(
          label: 'مكتملة',
          icon: Icons.done_all,
          bgColor: AppThemeConstants.success.withValues(alpha: 0.1),
          textColor: AppThemeConstants.success,
          borderColor: AppThemeConstants.success.withValues(alpha: 0.3),
        );

      case 'cancelled':
        return _StatusConfig(
          label: 'ملغية',
          icon: Icons.cancel,
          bgColor: AppThemeConstants.textMuted.withValues(alpha: 0.1),
          textColor: AppThemeConstants.textSecondary,
          borderColor: AppThemeConstants.textMuted.withValues(alpha: 0.3),
        );

      // ── NEW ──────────────────────────────────────────────────────────────
      case 'rejected':
        return _StatusConfig(
          label: 'مرفوضة',
          icon: Icons.do_not_disturb_alt,
          bgColor: AppThemeConstants.error.withValues(alpha: 0.1),
          textColor: AppThemeConstants.error,
          borderColor: AppThemeConstants.error.withValues(alpha: 0.3),
        );
      // ─────────────────────────────────────────────────────────────────────

      case 'expired':
        return _StatusConfig(
          label: 'منتهية',
          icon: Icons.timer_off,
          bgColor: AppThemeConstants.error.withValues(alpha: 0.1),
          textColor: AppThemeConstants.error,
          borderColor: AppThemeConstants.error.withValues(alpha: 0.3),
        );
      default:
        return _StatusConfig(
          label: status,
          icon: Icons.info_outline,
          bgColor: AppThemeConstants.textMuted.withValues(alpha: 0.1),
          textColor: AppThemeConstants.textSecondary,
          borderColor: AppThemeConstants.textMuted.withValues(alpha: 0.3),
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
