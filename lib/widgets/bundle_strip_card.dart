// lib/widgets/bundle_strip_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/subscription_model.dart';
import '../models/pricing_plan_model.dart';
import '../shared/theme/app_theme_constants.dart';

class BundleStripCard extends StatelessWidget {
  final SubscriptionModel sub;
  const BundleStripCard({super.key, required this.sub});

  // FIX: Helper method to get plan type label
  String _planTypeLabel(PlanType type) {
    switch (type) {
      case PlanType.bundle:
        return 'باقة حلقات';
      case PlanType.subscription:
        return 'اشتراك شهري';
      case PlanType.single:
        return 'جلسة مفردة';
    }
  }

  Color get _progressColor {
    if (sub.progressPercentage >= 0.5) return AppThemeConstants.accentGreen;
    if (sub.progressPercentage >= 0.2) return AppThemeConstants.warning;
    return AppThemeConstants.error;
  }

  String get _urgencyLabel {
    if (sub.remainingSessions <= 2) return '⚠️ متبقي ${sub.remainingSessions} فقط';
    return 'متبقي ${sub.remainingSessions} جلسة';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/active-subscriptions'),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppThemeConstants.surfaceWhite,
          borderRadius: AppThemeConstants.borderRadiusLg,
          border: Border.all(
            color: _progressColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teacher name
            Text(
              sub.mohaffezName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppThemeConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            // Session type
            Text(
              _planTypeLabel(sub.planType),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: sub.progressPercentage,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            // Sessions count + urgency
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${sub.remainingSessions}/${sub.totalSessions}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _progressColor,
                  ),
                ),
                if (sub.remainingSessions <= 2)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '⚠️',
                      style: TextStyle(
                          fontSize: 10, color: AppThemeConstants.error),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
