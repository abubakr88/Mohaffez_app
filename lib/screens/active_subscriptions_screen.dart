import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/subscription_model.dart';
import '../providers/payment_provider.dart';
import '../shared/theme/app_theme_constants.dart';

class ActiveSubscriptionsScreen extends ConsumerWidget {
  const ActiveSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentId = FirebaseAuth.instance.currentUser?.uid;
    if (studentId == null) {
      return const Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول')),
      );
    }

    final subscriptionsAsync = ref.watch(activeSubscriptionsProvider(studentId));

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: const Text('اشتراكاتي النشطة'),
          backgroundColor: AppThemeConstants.primaryAmber,
          foregroundColor: Colors.white,
        ),
        body: subscriptionsAsync.when(
          data: (subscriptions) {
            if (subscriptions.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.card_membership,
                        size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد اشتراكات نشطة',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'قم بشراء حزمة أو اشتراك لعرضها هنا',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: subscriptions.length,
              itemBuilder: (context, index) {
                final sub = subscriptions[index];
                return _SubscriptionCard(subscription: sub);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('خطأ في التحميل: $error'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionModel subscription;

  const _SubscriptionCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final remaining = subscription.remainingSessions;
    final total = subscription.totalSessions;
    final progress = total > 0 ? (total - remaining) / total : 0.0;
    final canBook = subscription.canBookSession;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Plan title and status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    subscription.planTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusBadge(status: subscription.status),
              ],
            ),
            const SizedBox(height: 8),
            
            // Teacher info
            Text(
              'المعلم: ${subscription.mohaffezName}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),

            // Progress bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? Colors.red : AppThemeConstants.primaryAmber,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$remaining / $total',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Remaining sessions text
            Text(
              '$remaining جلسة${remaining == 1 ? '' : 'ات'} متبقية',
              style: TextStyle(
                color: remaining > 0 ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            
            // Expiry date if present
            if (subscription.expiryDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'تاريخ الانتهاء: ${_formatDate(subscription.expiryDate!)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            
            const SizedBox(height: 12),

            // Book session button
            if (canBook)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to booking flow with mohaffez pre-selected
                    context.push(
                      '/nearby-mohaffez?mohaffezId=${subscription.mohaffezId}&subscriptionId=${subscription.id}',
                    );
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('احجز جلسة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primaryAmber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            else if (subscription.isDepleted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'تم استنفاد الجلسات',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else if (subscription.isExpired)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'انتهت صلاحية الاشتراك',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final SubscriptionStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      SubscriptionStatus.active => (Colors.green, 'نشط'),
      SubscriptionStatus.depleted => (Colors.orange, 'مستنفد'),
      SubscriptionStatus.expired => (Colors.red, 'منتهي'),
      SubscriptionStatus.cancelled => (Colors.grey, 'ملغي'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
