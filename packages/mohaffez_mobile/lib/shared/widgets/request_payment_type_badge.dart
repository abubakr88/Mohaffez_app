import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/src/models/subscription_model.dart';
import 'package:mohaffez_core/src/providers/session_provider_paginated.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

/// Shows a payment-type info card on the teacher's session request detail screen.
/// - Bundle/subscription request → green card with planTitle + remainingSessions/totalSessions
/// - Direct-payment request      → blue card with "دفع مباشر"
class RequestPaymentTypeBadge extends ConsumerWidget {
  final Map<String, dynamic> requestData;
  const RequestPaymentTypeBadge({super.key, required this.requestData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawType = ((requestData['paymentType'] as String?) ??
            (requestData['planType'] as String?) ??
            '')
        .toLowerCase();
    final isBundleType = rawType == 'bundle' || rawType == 'subscription';
    final subscriptionId = requestData['subscriptionId'] as String?;

    if (isBundleType && subscriptionId != null && subscriptionId.isNotEmpty) {
      return _BundleCard(subscriptionId: subscriptionId, requestData: requestData);
    }

    return _shell(
      bg: AppThemeConstants.accentBlueLight,
      border: AppThemeConstants.accentBlue,
      child: _row(Icons.payments_outlined, AppThemeConstants.accentBlueDark, 'نوع الحجز',
          'دفع مباشر', AppThemeConstants.accentBlueDark),
    );
  }
}

class _BundleCard extends ConsumerWidget {
  final String subscriptionId;
  final Map<String, dynamic> requestData;
  const _BundleCard(
      {required this.subscriptionId, required this.requestData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(_bundleProvider(subscriptionId));
    return subAsync.when(
      loading: () => const SizedBox(
          height: 52,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => _fallback(requestData),
      data: (sub) {
        if (sub == null) return _fallback(requestData);
        final isLast = sub.remainingSessions <= 1;
        return _shell(
          bg: AppThemeConstants.successLight,
          border: AppThemeConstants.accentGreenAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row(Icons.card_membership, AppThemeConstants.success, 'نوع الحجز',
                  'باقة', AppThemeConstants.success),
              const SizedBox(height: 6),
              _row(Icons.label_outline, AppThemeConstants.black54, 'اسم الباقة',
                  sub.planTitle, AppThemeConstants.black87),
              const SizedBox(height: 6),
              _row(
                Icons.event_available,
                isLast ? AppThemeConstants.warning : AppThemeConstants.black54,
                'الجلسات المتبقية',
                '${sub.remainingSessions} / ${sub.totalSessions}',
                isLast ? AppThemeConstants.warning : AppThemeConstants.black87,
              ),
              if (isLast) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.warningLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppThemeConstants.accentOrange),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: AppThemeConstants.warning),
                    SizedBox(width: 6),
                    Text(
                      'آخر جلسة في باقة الطالب',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppThemeConstants.warning),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _fallback(Map<String, dynamic> req) {
    final title = (req['planTitle'] as String?) ?? 'باقة';
    return _shell(
      bg: AppThemeConstants.successLight,
      border: AppThemeConstants.accentGreenAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(Icons.card_membership, AppThemeConstants.success, 'نوع الحجز',
              'باقة', AppThemeConstants.success),
          const SizedBox(height: 6),
          _row(Icons.label_outline, AppThemeConstants.black54, 'اسم الباقة', title,
              AppThemeConstants.black87),
        ],
      ),
    );
  }
}

Widget _shell(
    {required Color bg, required Color border, required Widget child}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: border),
    ),
    child: child,
  );
}

Widget _row(IconData icon, Color iconColor, String label, String value,
    Color valueColor) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: iconColor),
      const SizedBox(width: 8),
      Text('$label: ',
          style:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Expanded(
        child: Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor)),
      ),
    ],
  );
}

final _bundleProvider =
    FutureProvider.family<SubscriptionModel?, String>((ref, id) async {
  return ref.read(sessionRepositoryProvider).getBundleById(id);
});
