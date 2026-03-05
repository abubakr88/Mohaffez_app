import 'package:flutter/material.dart';

class VerificationBadge extends StatelessWidget {
  final String type; // 'certified', 'experienced', 'phoneVerified', 'topRated'
  final double size;
  final bool showLabel;

  const VerificationBadge({
    super.key,
    required this.type,
    this.size = 20,
    this.showLabel = false,
  });

  IconData _getIcon() {
    switch (type) {
      case 'certified':
        return Icons.verified;
      case 'experienced':
        return Icons.star;
      case 'phoneVerified':
        return Icons.phone_enabled;
      case 'topRated':
        return Icons.emoji_events;
      default:
        return Icons.check_circle;
    }
  }

  Color _getColor() {
    switch (type) {
      case 'certified':
        return Colors.blue;
      case 'experienced':
        return Colors.amber;
      case 'phoneVerified':
        return Colors.green;
      case 'topRated':
        return const Color(0xFFFFD700); // Gold
      default:
        return Colors.grey;
    }
  }

  String _getLabel() {
    switch (type) {
      case 'certified':
        return 'معتمد';
      case 'experienced':
        return 'خبير';
      case 'phoneVerified':
        return 'موثّق';
      case 'topRated':
        return 'متميز';
      default:
        return '';
    }
  }

  String _getTooltip() {
    switch (type) {
      case 'certified':
        return 'محفظ معتمد - تم التحقق من شهادة الإجازة';
      case 'experienced':
        return 'محفظ خبير - أكثر من 50 جلسة بتقييم عالي';
      case 'phoneVerified':
        return 'تم التحقق من رقم الهاتف';
      case 'topRated':
        return 'محفظ متميز - من أفضل 10% في المنطقة';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showLabel) {
      return Tooltip(
        message: _getTooltip(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _getColor().withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIcon(),
                size: size,
                color: _getColor(),
              ),
              const SizedBox(width: 4),
              Text(
                _getLabel(),
                style: TextStyle(
                  fontSize: size * 0.7,
                  fontWeight: FontWeight.bold,
                  color: _getColor(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Tooltip(
      message: _getTooltip(),
      child: Icon(
        _getIcon(),
        size: size,
        color: _getColor(),
      ),
    );
  }
}

// Widget to display all badges
class VerificationBadgesRow extends StatelessWidget {
  final Map<String, bool> badges;
  final double size;
  final bool showLabels;

  const VerificationBadgesRow({
    super.key,
    required this.badges,
    this.size = 20,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeBadges = badges.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();

    if (activeBadges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: activeBadges.map((badgeType) {
        return VerificationBadge(
          type: badgeType,
          size: size,
          showLabel: showLabels,
        );
      }).toList(),
    );
  }
}
