// lib/screens/student_payment_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pricing_plan_model.dart';
import '../models/payment_model.dart';
import '../providers/pricing_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/user_provider.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import 'payment_webview_screen.dart';

class StudentPaymentConfirmationScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String mohaffezId;
  final String mohaffezName;
  final Map<String, dynamic> sessionDetails;

  const StudentPaymentConfirmationScreen({
    super.key,
    required this.requestId,
    required this.mohaffezId,
    required this.mohaffezName,
    required this.sessionDetails,
  });

  @override
  ConsumerState<StudentPaymentConfirmationScreen> createState() =>
      _StudentPaymentConfirmationScreenState();
}

class _StudentPaymentConfirmationScreenState
    extends ConsumerState<StudentPaymentConfirmationScreen> {
  PricingPlanModel? selectedPlan;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(activePricingPlansProvider(widget.mohaffezId));
    final sessionType = widget.sessionDetails['sessionType'] as String;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تأكيد الحجز بالدفع'),
          backgroundColor: AppTheme.accentGreen,
        ),
        body: plansAsync.when(
          data: (plans) {
            // Filter plans by session type
            final filteredPlans = plans.where((p) {
              if (sessionType == 'home') return p.mode == SessionMode.home;
              if (sessionType == 'mosque') return p.mode == SessionMode.mosque;
              if (sessionType == 'online') return p.mode == SessionMode.online;
              return false;
            }).toList();

            if (filteredPlans.isEmpty) {
              return const EmptyState(
                icon: Icons.payments_outlined,
                title: 'لا توجد خطط متاحة',
                message: 'المحفظ لم يضف خطط تسعير',
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentGreen, Colors.green],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 48,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'تم قبول طلبك! 🎉',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.mohaffezName} وافق على جلستك',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSessionDetailsCard(),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'اختر خطة الدفع لتأكيد الحجز النهائي',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...filteredPlans.map((plan) => _buildPlanCard(plan)),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ: $e')),
        ),
        bottomNavigationBar: selectedPlan != null
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => _proceedToPayment(context, ref),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'ادفع ${selectedPlan!.displayPrice} وأكّد الحجز',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSessionDetailsCard() {
    final sessionDate = (widget.sessionDetails['slotDate'] as Timestamp).toDate();
    final timeSlot = widget.sessionDetails['preferredTimeSlot'] as String;
    final sessionType = widget.sessionDetails['sessionType'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'تفاصيل الجلسة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            Icons.person,
            'المحفظ',
            widget.mohaffezName,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            Icons.calendar_today,
            'التاريخ',
            DateFormat('EEEE، dd MMMM yyyy', 'ar').format(sessionDate),
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            Icons.access_time,
            'الوقت',
            timeSlot,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            _getSessionTypeIcon(sessionType),
            'النوع',
            _getSessionTypeLabel(sessionType),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(PricingPlanModel plan) {
    final isSelected = selectedPlan?.id == plan.id;
    final pricePerSession = plan.priceEGP / plan.sessionsCount;

    return GestureDetector(
      onTap: () => setState(() => selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accentGreen : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accentGreen : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.accentGreen : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.sessionsCount} جلسة${plan.sessionsCount > 1 ? " - ${pricePerSession.toStringAsFixed(0)} ج/جلسة" : ""}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              plan.displayPrice,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.accentGreen : AppTheme.primaryAmber,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSessionTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'mosque':
        return Icons.mosque;
      case 'online':
        return Icons.videocam;
      default:
        return Icons.event;
    }
  }

  String _getSessionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return 'بيت الطالب';
      case 'mosque':
        return 'المسجد';
      case 'online':
        return 'أونلاين';
      default:
        return type;
    }
  }

  /// REFACTORED: Now uses centralized orchestration
  /// and removes direct Firestore writes (backend does it)
  Future<void> _proceedToPayment(BuildContext context, WidgetRef ref) async {
    if (selectedPlan == null) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تسجيل الدخول أولاً')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Build base payment model
      final basePayment = PaymentModel(
        studentId: user.uid,
        studentName: user.name,
        studentEmail: user.email,
        studentPhone: user.phoneNumber ?? '',
        mohaffezId: widget.mohaffezId,
        mohaffezName: widget.mohaffezName,
        planId: selectedPlan!.id!,
        planTitle: selectedPlan!.title,
        amount: selectedPlan!.priceEGP,
        method: PaymentMethod.card,
        status: PaymentStatus.pending,
        gateway: PaymentGateway.paymob,
        createdAt: DateTime.now(),
      );

      // Metadata tells backend to confirm this specific request
      final metadata = <String, dynamic>{
        'requestId': widget.requestId,
        'confirmBooking': true,
        'sessionDetails': widget.sessionDetails,
      };

      // Call centralized orchestration
      final result = await ref
          .read(paymentActionsProvider.notifier)
          .startPaymentAndHandleResult(
            basePayment: basePayment,
            plan: selectedPlan!,
            extraMetadata: metadata,
          );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل بدء عملية الدفع')),
        );
        return;
      }

      // Navigate to payment webview
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (ctx) => PaymentWebViewScreen(
            paymentUrl: result.paymentUrl,
            paymentId: result.paymentId,
            plan: selectedPlan!,
          ),
        ),
      );

      if (success == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الدفع وتأكيد الحجز بنجاح! ✅'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        // Navigate back to home
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }
}
