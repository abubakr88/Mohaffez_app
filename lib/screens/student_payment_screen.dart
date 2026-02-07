// lib/screens/student_payment_screen.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pricing_plan_model.dart';
import '../models/payment_model.dart';
import '../providers/pricing_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/user_provider.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import 'payment_webview_screen.dart';
import 'package:intl/intl.dart';

class StudentPaymentScreen extends ConsumerStatefulWidget {
  final String mohaffezId;
  final String mohaffezName;
  final String? preselectedSessionType;
  final Map<String, dynamic>? preselectedTimeSlot;
  final DateTime? preselectedDate;
  final bool autoBookAfterPayment;
  final bool showSubscriptionsOnly;

  const StudentPaymentScreen({
    super.key,
    required this.mohaffezId,
    required this.mohaffezName,
    this.preselectedSessionType,
    this.preselectedTimeSlot,
    this.preselectedDate,
    this.autoBookAfterPayment = false,
    this.showSubscriptionsOnly = false,
  });

  @override
  ConsumerState<StudentPaymentScreen> createState() =>
      _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends ConsumerState<StudentPaymentScreen> {
  PricingPlanModel? selectedPlan;
  late String selectedSessionType;

  @override
  void initState() {
    super.initState();
    selectedSessionType = widget.preselectedSessionType ?? 'online';
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(activePricingPlansProvider(widget.mohaffezId));

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.autoBookAfterPayment ? 'إتمام الحجز' : 'اختر خطة الدفع',
          ),
          backgroundColor: AppTheme.accentGreen,
        ),
        body: plansAsync.when(
          data: (plans) {
            // Filter by selected session type
            var filteredPlans = plans.where((p) {
              if (selectedSessionType == 'home') return p.mode == SessionMode.home;
              if (selectedSessionType == 'mosque') {
                return p.mode == SessionMode.mosque;
              }
              if (selectedSessionType == 'online') {
                return p.mode == SessionMode.online;
              }
              return false;
            }).toList();

            // Filter to show only subscriptions/bundles if requested
            if (widget.showSubscriptionsOnly) {
              filteredPlans = filteredPlans
                  .where((p) => p.type != PlanType.single)
                  .toList();
            }

            if (filteredPlans.isEmpty) {
              return EmptyState(
                icon: Icons.payments_outlined,
                title: 'لا توجد خطط متاحة',
                message: widget.showSubscriptionsOnly
                    ? 'لا توجد باقات أو اشتراكات متاحة حالياً'
                    : 'لا توجد خطط تسعير متاحة',
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.autoBookAfterPayment && widget.preselectedDate != null)
                  _buildSessionInfoCard(),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSessionTypeSelector(),
                const SizedBox(height: 24),
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
                          '${selectedPlan!.priceEGP.toStringAsFixed(0)} ج.م - ادفع الآن',
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

  Widget _buildSessionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع الجلسة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSessionTypeChip(
                'home',
                'بيت الطالب',
                Icons.home,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSessionTypeChip(
                'mosque',
                'المسجد',
                Icons.mosque,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSessionTypeChip(
                'online',
                'أونلاين',
                Icons.videocam,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSessionTypeChip(
    String type,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = selectedSessionType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedSessionType = type;
          selectedPlan = null; // Reset plan when type changes
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
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
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'معلومات الجلسة المحجوزة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 8),
              Text(
                DateFormat('EEEE، dd MMMM yyyy', 'ar')
                    .format(widget.preselectedDate!),
              ),
            ],
          ),
          if (widget.preselectedTimeSlot != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${widget.preselectedTimeSlot!['startTime']} - ${widget.preselectedTimeSlot!['endTime']}',
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'اختر خطة الدفع المناسبة لإتمام الحجز',
              style: TextStyle(
                fontSize: 13,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.school,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            widget.mohaffezName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.showSubscriptionsOnly
                ? 'اختر الباقة المناسبة'
                : widget.autoBookAfterPayment
                    ? 'اختر خطة الدفع'
                    : 'الدفع لـ ${widget.mohaffezName}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accentGreen : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentGreen.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.accentGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        )
                      else
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? AppTheme.accentGreen
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getPlanTypeLabel(plan),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${plan.priceEGP.toStringAsFixed(0)} ج.م',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppTheme.accentGreen
                                  : AppTheme.primaryAmber,
                            ),
                          ),
                          if (plan.sessionsCount > 1)
                            Text(
                              '${pricePerSession.toStringAsFixed(0)} ج.م/جلسة',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFeatureChip(
                        '${plan.sessionsCount} جلسة',
                        Icons.event_available,
                      ),
                      if (plan.sessionsPerWeek != null)
                        _buildFeatureChip(
                          '${plan.sessionsPerWeek}x أسبوعياً',
                          Icons.calendar_today,
                        ),
                      if (plan.validityDays != null)
                        _buildFeatureChip(
                          'صالح ${plan.validityDays} يوم',
                          Icons.schedule,
                        ),
                      if (plan.isFreeTrialAvailable)
                        _buildFeatureChip(
                          'تجربة مجانية',
                          Icons.stars,
                          color: Colors.orange,
                        ),
                    ],
                  ),
                  if (plan.description != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_offer,
                            size: 16,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plan.description!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (plan.isBundle || plan.isSubscription)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple, Colors.deepPurple],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        plan.isSubscription ? 'الأكثر طلباً' : 'عرض مميز',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.primaryAmber).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (color ?? AppTheme.primaryAmber).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color ?? AppTheme.primaryAmber,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? AppTheme.primaryAmber,
            ),
          ),
        ],
      ),
    );
  }

  String _getPlanTypeLabel(PricingPlanModel plan) {
    if (plan.isSingle) return 'جلسة واحدة';
    if (plan.isBundle) return 'باقة ${plan.sessionsCount} جلسات';
    if (plan.isSubscription) {
      return 'اشتراك شهري - ${plan.sessionsPerWeek}x أسبوعياً';
    }
    return '';
  }

  /// REFACTORED: Now uses centralized orchestration
  Future<void> _proceedToPayment(BuildContext context, WidgetRef ref) async {
    if (selectedPlan == null) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
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

      // Build metadata for backend webhook
      final metadata = <String, dynamic>{
        if (widget.autoBookAfterPayment) ...{
          'confirmBooking': false, // Just creating subscription first
          'sessionType': widget.preselectedSessionType,
          if (widget.preselectedTimeSlot != null)
            'timeSlot': widget.preselectedTimeSlot,
          if (widget.preselectedDate != null)
            'sessionDate': widget.preselectedDate!.toIso8601String(),
        },
      };

      // Call centralized orchestration
      final result = await ref
          .read(paymentActionsProvider.notifier)
          .startPaymentAndHandleResult(
            basePayment: basePayment,
            plan: selectedPlan!,
            extraMetadata: metadata,
          );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إنشاء رابط الدفع')),
        );
        return;
      }

      // Navigate to payment webview with paymentId for status polling
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

      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الدفع بنجاح! 🎉'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }
}
