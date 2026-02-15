import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/payment_model.dart';
import '../models/pricing_plan_model.dart';
import '../models/promo_code_model.dart';
import '../providers/payment_provider.dart';
import '../providers/pricing_provider.dart';
import '../providers/promo_code_provider.dart';
import '../providers/user_provider.dart';
import '../providers/booking_provider.dart';
import '../services/pricing_service.dart';
import '../shared/constants/app_theme.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/empty_state.dart';
import '../utils/arabic_labels.dart';
import 'payment_webview_screen.dart';

class StudentPaymentScreen extends ConsumerStatefulWidget {
  const StudentPaymentScreen({
    super.key,
    required this.mohaffezId,
    required this.mohaffezName,
    this.requestId,
    this.sessionType,
    this.sessionDate,
    this.timeSlot,
    this.location,
    this.sessionDetails,
    this.preselectedSessionType,
    this.preselectedTimeSlot,
    this.preselectedDate,
    this.autoBookAfterPayment = false,
    this.showSubscriptionsOnly = false,
    this.mohaffezAddress,
    this.mohaffezLat,
    this.mohaffezLng,
    this.mohaffezPhone,
  });

  final String mohaffezId;
  final String mohaffezName;
  final String? requestId;
  final String? sessionType;
  final DateTime? sessionDate;
  final String? timeSlot;
  final String? location;
  final Map<String, dynamic>? sessionDetails;
  final String? preselectedSessionType;
  final Map<String, dynamic>? preselectedTimeSlot;
  final DateTime? preselectedDate;
  final bool autoBookAfterPayment;
  final bool showSubscriptionsOnly;
  final String? mohaffezAddress;
  final double? mohaffezLat;
  final double? mohaffezLng;
  final String? mohaffezPhone;

  @override
  ConsumerState<StudentPaymentScreen> createState() =>
      _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends ConsumerState<StudentPaymentScreen> {
  PricingPlanModel? selectedPlan;
  final _promoCodeController = TextEditingController();
  PromoCodeModel? _appliedPromoCode;
  PricingResult? _pricingResult;
  bool _isProcessingPayment = false;

  String get _lockedSessionType =>
      widget.sessionType ?? widget.preselectedSessionType ?? 'online';
  
  DateTime? get _lockedDate => widget.sessionDate ?? widget.preselectedDate;

  String get _lockedTimeSlot {
    if (widget.timeSlot != null && widget.timeSlot!.trim().isNotEmpty) {
      return widget.timeSlot!;
    }
    if (widget.preselectedTimeSlot != null) {
      final start = widget.preselectedTimeSlot!['startTime']?.toString() ?? '';
      final end = widget.preselectedTimeSlot!['endTime']?.toString();
      if (end != null && end.isNotEmpty) {
        return '$start-$end';
      }
      return start;
    }
    return '';
  }

  bool get _hasSelectedSlot => _lockedTimeSlot.isNotEmpty && _lockedDate != null;

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  void _calculatePrice() {
    if (selectedPlan == null) {
      setState(() => _pricingResult = null);
      return;
    }
    final pricing = ref
        .read(pricingServiceProvider)
        .applyPromoCode(selectedPlan!, _appliedPromoCode);
    setState(() => _pricingResult = pricing);
  }

  PricingResult _resolvePricing() {
    if (selectedPlan == null) {
      return const PricingResult(
        originalPrice: 0,
        discount: 0,
        finalPrice: 0,
        isFree: false,
      );
    }
    return _pricingResult ??
        ref
            .read(pricingServiceProvider)
            .applyPromoCode(selectedPlan!, _appliedPromoCode);
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(activePricingPlansProvider(widget.mohaffezId));
    final pricing = _resolvePricing();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(ArabicLabels.payment),
          backgroundColor: AppTheme.accentGreen,
        ),
        body: plansAsync.when(
          data: (plans) {
            var filteredPlans = plans.where((p) {
              if (_lockedSessionType == 'home') {
                return p.mode == SessionMode.home;
              }
              if (_lockedSessionType == 'mosque') {
                return p.mode == SessionMode.mosque;
              }
              return p.mode == SessionMode.online;
            }).toList();
            
            if (widget.showSubscriptionsOnly) {
              filteredPlans = filteredPlans
                  .where((p) => p.type != PlanType.single)
                  .toList();
            }
            
            if (filteredPlans.isEmpty) {
              return const EmptyState(
                icon: Icons.payments_outlined,
                title: 'لا توجد خطط متاحة',
                message: 'لا توجد خطط مناسبة لهذا النوع من الجلسات',
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildLockedSessionDetailsCard(),
                if (widget.sessionDetails != null) const SizedBox(height: 14),
                ...filteredPlans.map(_buildPlanCard),
                if (selectedPlan != null) ...[
                  const SizedBox(height: 14),
                  _buildPromoCodeSection(),
                  const SizedBox(height: 12),
                  _buildPriceSummary(),
                  const SizedBox(height: 100),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('${ArabicLabels.error}: $e')),
        ),
        bottomNavigationBar: selectedPlan == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildPaymentButton(pricing),
                ),
              ),
      ),
    );
  }

  Widget _buildPaymentButton(PricingResult pricing) {
    final isFreeSession = pricing.finalPrice <= 0.01;
    final canPay = !_isProcessingPayment && (!isFreeSession || _hasSelectedSlot);

    return ElevatedButton.icon(
      onPressed: canPay ? () => _proceedToPayment(context, ref) : null,
      icon: _isProcessingPayment
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              isFreeSession ? Icons.check_circle : Icons.payment,
              color: Colors.white,
            ),
      label: Text(
        isFreeSession
            ? '🎉 تأكيد الجلسة المجانية'
            : '${pricing.finalPrice.toStringAsFixed(0)} ${ArabicLabels.egp} - ${ArabicLabels.payNow}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isFreeSession ? Colors.green : AppTheme.accentGreen,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: isFreeSession ? 4 : 2,
      ),
    );
  }

  Widget _buildLockedSessionDetailsCard() {
    if (widget.sessionDetails == null) {
      return const SizedBox.shrink();
    }

    final details = widget.sessionDetails!;
    final sessionType = details['sessionType'] as String?;
    final slotDate = details['slotDate'] as Timestamp?;
    final timeSlot = details['timeSlot'] as String?;
    final location = details['location'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock, size: 32, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تفاصيل الجلسة مؤكدة من المحفظ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 24, color: Colors.blue.shade300),
          _lockedDetailRow('المحفظ', widget.mohaffezName),
          _lockedDetailRow(ArabicLabels.type, _getSessionTypeArabic(sessionType)),
          if (slotDate != null)
            _lockedDetailRow(
              ArabicLabels.date,
              DateFormat('EEEE dd MMMM yyyy', 'ar').format(slotDate.toDate()),
            ),
          if (timeSlot != null) _lockedDetailRow(ArabicLabels.time, timeSlot),
          if (location != null && location.isNotEmpty)
            _lockedDetailRow(ArabicLabels.location, location),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 20, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'لا يمكن تغيير هذه التفاصيل. الباقات المعروضة تطابق نوع الجلسة المختار.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockedDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildPromoCodeSection() {
    final promoState = ref.watch(promoCodeProvider);
    final isValidatingPromo = promoState.isLoading;
    final promoError = promoState.hasError ? promoState.error.toString() : null;
    final promoCodeValid = _appliedPromoCode != null;
    final discount = _appliedPromoCode?.discount ?? 0;
    
    final pricing = _resolvePricing();
    final isFreeSession = pricing.finalPrice <= 0.01;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: AppThemeConstants.borderRadiusMd,
        border: Border.all(
          color: isFreeSession ? Colors.green : Colors.grey.shade300,
          width: isFreeSession ? 2 : 1,
        ),
        color: isFreeSession ? Colors.green.shade50 : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isFreeSession && promoCodeValid) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.green, Color(0xFF66BB6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: const [
                  Icon(Icons.celebration, color: Colors.white, size: 36),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎉 جلسة مجانية!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'تم تطبيق خصم 100% - لا حاجة للدفع',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          TextField(
            controller: _promoCodeController,
            onChanged: (_) {
              if (_appliedPromoCode != null) {
                setState(() {
                  _appliedPromoCode = null;
                  _calculatePrice();
                });
                ref.read(promoCodeProvider.notifier).clearPromoCode();
              }
            },
            decoration: InputDecoration(
              labelText: ArabicLabels.enterPromoCode,
              hintText: 'أدخل كود الخصم هنا',
              suffixIcon: isValidatingPromo
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : promoCodeValid
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: isValidatingPromo
                ? null
                : () async {
                    if (_promoCodeController.text.trim().isEmpty) return;
                    await ref
                        .read(promoCodeProvider.notifier)
                        .validateCode(_promoCodeController.text.trim());
                    final latest = ref.read(promoCodeProvider).valueOrNull;
                    if (latest != null && mounted) {
                      setState(() {
                        _appliedPromoCode = latest;
                        _calculatePrice();
                      });
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: promoCodeValid ? Colors.green : null,
            ),
            child: Text(
              isValidatingPromo 
                  ? 'جاري التحقق...' 
                  : promoCodeValid 
                      ? 'تم التطبيق ✓' 
                      : ArabicLabels.apply,
            ),
          ),
          
          if (promoError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      promoError,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          
          if (promoCodeValid && discount > 0 && !isFreeSession)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'كود صحيح',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          Text(
                            _appliedPromoCode?.type == 'percentage'
                                ? '${ArabicLabels.discount} ${discount.toStringAsFixed(0)}%'
                                : '${ArabicLabels.discount} ${discount.toStringAsFixed(0)} ${ArabicLabels.currency}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary() {
    final pricing = _resolvePricing();
    final isFreeSession = pricing.finalPrice <= 0.01;
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isFreeSession 
            ? Colors.green.withOpacity(0.1)
            : AppTheme.primaryAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFreeSession
              ? Colors.green
              : AppTheme.primaryAmber.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          if (pricing.originalPrice > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('السعر الأصلي:'),
                Text(
                  '${pricing.originalPrice.toStringAsFixed(2)} ${ArabicLabels.currency}',
                  style: TextStyle(
                    decoration: pricing.discount > 0 
                        ? TextDecoration.lineThrough 
                        : null,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          if (pricing.discount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('${ArabicLabels.discount}:'),
                Text(
                  '- ${pricing.discount.toStringAsFixed(2)} ${ArabicLabels.currency}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '${ArabicLabels.total}:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                isFreeSession
                    ? 'مجاني 🎉'
                    : '${pricing.finalPrice.toStringAsFixed(2)} ${ArabicLabels.currency}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isFreeSession ? Colors.green : AppTheme.primaryAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(PricingPlanModel plan) {
    final selected = selectedPlan?.id == plan.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPlan = plan;
          _calculatePrice();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.accentGreen : Colors.grey.shade300,
            width: selected ? 2.5 : 1,
          ),
          color: selected ? AppTheme.accentGreen.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: AppTheme.accentGreen,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.sessionsCount} ${plan.sessionsCount == 1 ? "جلسة" : "جلسات"}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${plan.priceEGP.toStringAsFixed(0)} ${ArabicLabels.egp}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _proceedToPayment(BuildContext context, WidgetRef ref) async {
    if (selectedPlan == null) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تسجيل الدخول')),
      );
      return;
    }

    final pricing = _resolvePricing();
    final isFreeSession = pricing.finalPrice <= 0.01;

    if (isFreeSession && _appliedPromoCode != null) {
      await _handleFreeSession(context, ref, user);
      return;
    }

    await _handleRegularPayment(context, ref, user, pricing);
  }

  // ============================================
  // ✅ FIXED: Use Cloud Function via bookingFlowProvider
  // ============================================
  Future<void> _handleFreeSession(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
  ) async {
    // Guard: a time slot must be selected for a free session
    if (!_hasSelectedSlot) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ يجب اختيار موعد الجلسة أولاً من صفحة المحفظ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      // Parse slot details
      final slotDate = _lockedDate!;
      final timeSlotParts = _lockedTimeSlot.split('-');
      
      final startParts = timeSlotParts.first.split(':');
      final endParts = timeSlotParts.length > 1 
          ? timeSlotParts.last.split(':') 
          : startParts;
      
      final slotStart = DateTime(
        slotDate.year,
        slotDate.month,
        slotDate.day,
        int.tryParse(startParts[0]) ?? 0,
        int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0,
      );
      
      final slotEnd = DateTime(
        slotDate.year,
        slotDate.month,
        slotDate.day,
        int.tryParse(endParts[0]) ?? 0,
        int.tryParse(endParts.length > 1 ? endParts[1] : '0') ?? 0,
      );

      // ✅ Use the existing booking flow provider which calls the Cloud Function
      final result = await ref.read(bookingFlowProvider.notifier).createFreeSession(
        mohaffezId: widget.mohaffezId,
        mohaffezName: widget.mohaffezName,
        studentId: user.uid,
        studentName: user.name,
        sessionType: _lockedSessionType,
        preferredTimeSlot: _lockedTimeSlot,
        slotDate: slotDate,
        slotStart: slotStart,
        slotEnd: slotEnd,
        imamAddressText: widget.mohaffezAddress ?? widget.location,
        imamAddressLat: widget.mohaffezLat,
        imamAddressLng: widget.mohaffezLng,
        mohaffezPhone: widget.mohaffezPhone,
        promoCode: _appliedPromoCode!.code,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        // Cloud Function already increments promo usage
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 تم حجز الجلسة المجانية بنجاح!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate to home after a short delay
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          context.go('/home');
        }
      } else {
        throw Exception(result.errorMessage ?? 'فشل إنشاء الجلسة المجانية');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  Future<void> _handleRegularPayment(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    PricingResult pricing,
  ) async {
    setState(() => _isProcessingPayment = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final basePayment = PaymentModel(
        studentId: user.uid,
        studentName: user.name,
        studentEmail: user.email,
        studentPhone: user.phoneNumber ?? '',
        mohaffezId: widget.mohaffezId,
        mohaffezName: widget.mohaffezName,
        planId: selectedPlan!.id!,
        planTitle: selectedPlan!.title,
        amount: pricing.finalPrice,
        method: PaymentMethod.card,
        status: PaymentStatus.pending,
        gateway: PaymentGateway.paymob,
        createdAt: DateTime.now(),
      );

      final metadata = <String, dynamic>{
        if (widget.requestId != null) 'requestId': widget.requestId,
        if (widget.requestId != null) 'confirmBooking': true,
        if (widget.requestId != null)
          'sessionDetails': {
            'sessionType': _lockedSessionType,
            'slotDate':
                _lockedDate != null ? Timestamp.fromDate(_lockedDate!) : null,
            'preferredTimeSlot': _lockedTimeSlot,
            'location': widget.location,
          },
        if (_appliedPromoCode != null) 'promoCode': _appliedPromoCode!.code,
      };

      final result = await ref
          .read(paymentActionsProvider.notifier)
          .startPaymentAndHandleResult(
            basePayment: basePayment,
            plan: selectedPlan!,
            extraMetadata: metadata,
          );

      if (!context.mounted) return;
      Navigator.pop(context);

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إنشاء عملية الدفع')),
        );
        return;
      }

      if (result.paymentUrl.isEmpty) {
        // This case should not happen for paid sessions, but handle gracefully
        if (_appliedPromoCode != null) {
          await ref
              .read(promoCodeProvider.notifier)
              .applyPromoCode(_appliedPromoCode!.code);
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد الجلسة المجانية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
        return;
      }

      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            paymentUrl: result.paymentUrl,
            paymentId: result.paymentId,
            plan: selectedPlan!,
          ),
        ),
      );

      if (success == true) {
        if (_appliedPromoCode != null) {
          await ref
              .read(promoCodeProvider.notifier)
              .applyPromoCode(_appliedPromoCode!.code);
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الدفع بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ArabicLabels.error}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  String _getSessionTypeArabic(String? type) {
    switch (type) {
      case 'home':
        return ArabicLabels.homeSession;
      case 'mosque':
        return ArabicLabels.mosqueSession;
      case 'online':
        return ArabicLabels.onlineSession;
      default:
        return type ?? '';
    }
  }
}