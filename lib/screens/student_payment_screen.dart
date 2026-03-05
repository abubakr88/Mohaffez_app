// lib/screens/student_payment_screen.dart
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
import '../services/direct_payment_service.dart';
import 'direct_payment_screen.dart';

enum _DPMethod { online, direct }

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
    this.lockedRequest,
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
  final Map<String, dynamic>? lockedRequest;

  @override
  ConsumerState<StudentPaymentScreen> createState() =>
      _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends ConsumerState<StudentPaymentScreen> {
  PricingPlanModel? selectedPlan;
  bool planSelectionFallback = false;
  final promoCodeController = TextEditingController();
  PromoCodeModel? appliedPromoCode;
  PricingResult? pricingResult;
  bool isProcessingPayment = false;

  bool _loadingWallets = true;
  bool _hasDirectPayment = false;
  // ignore: unused_field
  Map<String, String?> _walletNumbers = {};
  _DPMethod _selectedDPMethod = _DPMethod.online;

  // ── Existing getters ──────────────────────────────────────────────────────
  String get lockedSessionType =>
      widget.sessionType ??
      widget.preselectedSessionType ??
      lockedRequestSessionType ??
      'online';

  DateTime? get lockedDate =>
      widget.sessionDate ?? widget.preselectedDate ?? lockedRequestSlotDate;

  String get lockedTimeSlot {
    if (widget.timeSlot != null && widget.timeSlot!.trim().isNotEmpty) {
      return widget.timeSlot!;
    }
    if (widget.preselectedTimeSlot != null) {
      final start = widget.preselectedTimeSlot!['startTime']?.toString() ?? '';
      final end = widget.preselectedTimeSlot!['endTime']?.toString();
      if (end != null && end.isNotEmpty) return '$start-$end';
      return start;
    }
    if (lockedRequestTimeSlot != null && lockedRequestTimeSlot!.isNotEmpty) {
      return lockedRequestTimeSlot!;
    }
    return '';
  }

  bool get hasSelectedSlot => lockedTimeSlot.isNotEmpty && lockedDate != null;

  bool get isLockedRequest => widget.lockedRequest != null;

  String? get lockedRequestSessionType =>
      isLockedRequest ? widget.lockedRequest!['sessionType'] as String? : null;

  DateTime? get lockedRequestSlotDate {
    if (!isLockedRequest) return null;
    final timestamp = widget.lockedRequest!['slotDate'];
    if (timestamp is DateTime) return timestamp;
    if (timestamp is Timestamp) return timestamp.toDate();
    return null;
  }

  String? get lockedRequestTimeSlot => isLockedRequest
      ? widget.lockedRequest!['preferredTimeSlot'] as String?
      : null;

  String? get lockedRequestLocation => isLockedRequest
      ? widget.lockedRequest!['imamAddressText'] as String?
      : null;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '🔍 [PaymentScreen] isLockedRequest=$isLockedRequest planId=${widget.lockedRequest?['planId']} paymentAmount=${widget.lockedRequest?['paymentAmount']}',
    );
    _loadWalletAvailability();
  }

  Future<void> _loadWalletAvailability() async {
    if (widget.requestId == null || widget.requestId!.isEmpty) {
      if (mounted) setState(() => _loadingWallets = false);
      return;
    }
    try {
      final wallets = await DirectPaymentService.getMohaffezWalletNumbers(
          widget.mohaffezId);
      final hasAny =
          wallets.values.any((v) => v != null && v.trim().isNotEmpty);
      if (mounted) {
        setState(() {
          _walletNumbers = wallets;
          _hasDirectPayment = hasAny;
          _loadingWallets = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingWallets = false);
    }
  }

  @override
  void dispose() {
    promoCodeController.dispose();
    super.dispose();
  }

  void calculatePrice() {
    if (selectedPlan == null) {
      setState(() => pricingResult = null);
      return;
    }
    final pricing = ref
        .read(pricingServiceProvider)
        .applyPromoCode(selectedPlan!, appliedPromoCode);
    setState(() => pricingResult = pricing);
  }

  PricingResult resolvePricing() {
    if (selectedPlan == null) {
      return const PricingResult(
          originalPrice: 0, discount: 0, finalPrice: 0, isFree: false);
    }
    return pricingResult ??
        ref
            .read(pricingServiceProvider)
            .applyPromoCode(selectedPlan!, appliedPromoCode);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(activePricingPlansProvider(widget.mohaffezId));
    final pricing = resolvePricing();

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
          title: const Text(ArabicLabels.payment),
          backgroundColor: AppTheme.accentGreen,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () =>
                  ref.invalidate(activePricingPlansProvider(widget.mohaffezId)),
            ),
          ],
        ),
        body: plansAsync.when(
          data: (plans) {
            var filteredPlans = plans.where((p) {
              if (lockedSessionType == 'home') {
                return p.mode == SessionMode.home;
              }
              if (lockedSessionType == 'mosque') {
                return p.mode == SessionMode.mosque;
              }
              return p.mode == SessionMode.online;
            }).toList();

            if (widget.showSubscriptionsOnly) {
              filteredPlans = filteredPlans
                  .where((p) => p.type != PlanType.single)
                  .toList();
            }

            if (isLockedRequest &&
                selectedPlan == null &&
                !planSelectionFallback &&
                filteredPlans.isNotEmpty) {
              final lockedPlanId = widget.lockedRequest!['planId'] as String?;
              final lockedAmount =
                  (widget.lockedRequest!['paymentAmount'] as num? ??
                          widget.lockedRequest!['sessionPrice'] as num?)
                      ?.toDouble();

              PricingPlanModel? match;

              if (lockedPlanId != null && lockedPlanId.isNotEmpty) {
                try {
                  match = filteredPlans.firstWhere((p) => p.id == lockedPlanId);
                } catch (_) {}
              }

              if (match == null && lockedAmount != null && lockedAmount > 0) {
                for (final plan in filteredPlans) {
                  if ((plan.priceEGP - lockedAmount).abs() < 0.01) {
                    match = plan;
                    break;
                  }
                }
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (match != null) {
                  setState(() => selectedPlan = match);
                } else {
                  setState(() => planSelectionFallback = true);
                }
              });
            }

            if (filteredPlans.isEmpty) {
              return const EmptyState(
                icon: Icons.payments_outlined,
                title: 'لا توجد خطط دفع',
                message: 'لم يضف المحفظ خطط دفع بعد',
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(activePricingPlansProvider(widget.mohaffezId));
                await ref
                    .read(activePricingPlansProvider(widget.mohaffezId).future)
                    .catchError((_) => <PricingPlanModel>[]);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  buildLockedSessionDetailsCard,
                  if (widget.sessionDetails != null || hasSelectedSlot)
                    const SizedBox(height: 14),
                  if (isLockedRequest && !planSelectionFallback)
                    if (selectedPlan != null)
                      _buildLockedPlanCard(selectedPlan!)
                    else
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'جارٍ تحديد خطة الدفع...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                  else
                    ...filteredPlans.map(buildPlanCard),
                  if (selectedPlan != null) ...[
                    const SizedBox(height: 14),
                    buildPromoCodeSection,
                    const SizedBox(height: 12),
                    buildPriceSummary,
                    _buildPaymentMethodToggle(resolvePricing()),
                    const SizedBox(height: 100),
                  ],
                ],
              ),
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
                  child: buildPaymentButton(pricing),
                ),
              ),
      ),
    );
  }

  Widget _buildPaymentMethodToggle(PricingResult pricing) {
    // Don't show for free sessions
    if (pricing.finalPrice <= 0.01) return const SizedBox.shrink();

    // Only show when arrived from a real booking request
    if (widget.requestId == null || widget.requestId!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Still loading
    if (_loadingWallets) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Teacher hasn't saved any wallet numbers → hide silently
    if (!_hasDirectPayment) return const SizedBox.shrink();

    // ── Render toggle ─────────────────────────────────────────────────────────
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'طريقة الدفع',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      setState(() => _selectedDPMethod = _DPMethod.online),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDPMethod == _DPMethod.online
                            ? AppTheme.accentGreen
                            : Colors.grey.shade300,
                        width: _selectedDPMethod == _DPMethod.online ? 2 : 1,
                      ),
                      color: _selectedDPMethod == _DPMethod.online
                          ? AppTheme.accentGreen.withValues(alpha: 0.08)
                          : Colors.white,
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.credit_card, color: AppTheme.accentGreen),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'دفع إلكتروني',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () =>
                      setState(() => _selectedDPMethod = _DPMethod.direct),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDPMethod == _DPMethod.direct
                            ? Colors.green
                            : Colors.grey.shade300,
                        width: _selectedDPMethod == _DPMethod.direct ? 2 : 1,
                      ),
                      color: _selectedDPMethod == _DPMethod.direct
                          ? Colors.green.withValues(alpha: 0.08)
                          : Colors.white,
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'دفع مباشر',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── MODIFIED: Payment button — now handles card AND direct modes ──────────
  Widget buildPaymentButton(PricingResult pricing) {
    final isFreeSession = pricing.finalPrice < 0.01;

    // ── FREE SESSION (existing) ────────────────────────────────────────────
    if (isFreeSession && appliedPromoCode != null) {
      final requiresSlot = isFreeSession && widget.requestId == null;
      final canPay = !isProcessingPayment && (!requiresSlot || hasSelectedSlot);

      if (requiresSlot && !hasSelectedSlot) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                    child: Text('يرجى العودة لاختيار الموعد أولاً',
                        style:
                            TextStyle(fontSize: 13, color: Colors.deepOrange))),
              ]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('العودة لاختيار الموعد'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.orange.shade300)),
              ),
            ),
          ],
        );
      }

      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: canPay ? () => proceedToPayment(context, ref) : null,
          icon: isProcessingPayment
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle, color: Colors.white),
          label: Text(
            isProcessingPayment
                ? 'جاري التأكيد...'
                : 'تأكيد الجلسة المجانية 🎁',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
          ),
        ),
      );
    }

    // ── EXISTING: Card / Paymob payment ──────────────────────────────────
    final requiresSlot = isFreeSession && widget.requestId == null;
    final canPay = !isProcessingPayment && (!requiresSlot || hasSelectedSlot);

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: canPay ? () => proceedToPayment(context, ref) : null,
        icon: isProcessingPayment
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(isFreeSession ? Icons.check_circle : Icons.payment,
                color: Colors.white),
        label: Text(
          isProcessingPayment
              ? 'جاري المعالجة...'
              : isFreeSession
                  ? 'تأكيد الجلسة المجانية 🎁'
                  : '${pricing.finalPrice.toStringAsFixed(0)} ${ArabicLabels.egp} - ${ArabicLabels.payNow}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isFreeSession ? Colors.green : AppTheme.accentGreen,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: isFreeSession ? 4 : 2,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
        ),
      ),
    );
  }

  // ── MODIFIED: proceedToPayment — 3 branches now ───────────────────────────
  Future<void> proceedToPayment(BuildContext context, WidgetRef ref) async {
    if (selectedPlan == null) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول')));
      return;
    }

    final pricing = resolvePricing();
    final isFreeSession = pricing.finalPrice < 0.01;

    if (isFreeSession && appliedPromoCode != null) {
      await handleFreeSession(context, ref, user);
    } else if (_selectedDPMethod == _DPMethod.direct &&
        widget.requestId != null) {
      _openDirectPaymentScreen(context, user, pricing);
      return;
    } else {
      await handleRegularPayment(context, ref, user, pricing);
    }
  }

  void _openDirectPaymentScreen(
    BuildContext context,
    dynamic user,
    PricingResult pricing,
  ) {
    final requestId = widget.requestId;
    if (requestId == null || requestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات الطلب غير مكتملة')),
      );
      return;
    }

    final slotDate = lockedDate;
    if (slotDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات الموعد غير مكتملة')),
      );
      return;
    }
    DateTime slotStart;
    DateTime slotEnd;

    final lockedStart = widget.lockedRequest?['slotStart'];
    final lockedEnd = widget.lockedRequest?['slotEnd'];

    if (lockedStart is Timestamp && lockedEnd is Timestamp) {
      slotStart = lockedStart.toDate();
      slotEnd = lockedEnd.toDate();
    } else if (lockedStart is DateTime && lockedEnd is DateTime) {
      slotStart = lockedStart;
      slotEnd = lockedEnd;
    } else {
      slotStart = slotDate;
      slotEnd = slotDate.add(const Duration(hours: 1));
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectPaymentScreen(
          requestId: requestId,
          mohaffezId: widget.mohaffezId,
          mohaffezName: widget.mohaffezName,
          studentName: user.name,
          amount: pricing.finalPrice,
          sessionType: lockedSessionType,
          preferredTimeSlot: lockedTimeSlot,
          slotDate: slotDate,
          slotStart: slotStart,
          slotEnd: slotEnd,
          imamAddressText: widget.location ??
              widget.mohaffezAddress ??
              lockedRequestLocation,
          imamAddressLat: widget.mohaffezLat,
          imamAddressLng: widget.mohaffezLng,
          mohaffezPhone:
              widget.mohaffezPhone ?? widget.lockedRequest?['mohaffezPhone'],
        ),
      ),
    );
  }

  // ── Existing: buildLockedSessionDetailsCard ───────────────────────────────
  Widget get buildLockedSessionDetailsCard {
    Map<String, dynamic>? details;
    if (isLockedRequest) {
      details = widget.lockedRequest;
    } else if (widget.sessionDetails != null) {
      details = widget.sessionDetails;
    } else if (hasSelectedSlot) {
      details = {
        'sessionType': lockedSessionType,
        'slotDate': lockedDate != null ? Timestamp.fromDate(lockedDate!) : null,
        'preferredTimeSlot': lockedTimeSlot,
        'location': widget.location ?? widget.mohaffezAddress,
      };
    }
    if (details == null) return const SizedBox.shrink();

    final sessionType = details['sessionType'] as String?;
    final slotDate = details['slotDate'] as Timestamp?;
    final timeSlot = details['timeSlot'] as String? ??
        details['preferredTimeSlot'] as String?;
    final location =
        details['location'] as String? ?? details['imamAddressText'] as String?;

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
          Row(children: [
            const Icon(Icons.lock, size: 32, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isLockedRequest ? 'طلب محجوز — أكمل الدفع' : 'تفاصيل الجلسة',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900),
              ),
            ),
          ]),
          if (isLockedRequest) ...[
            const SizedBox(height: 4),
            const Text(
              'راجع تفاصيل جلستك أدناه ثم تابع إلى الدفع',
              style: TextStyle(fontSize: 13, color: Colors.blue),
            ),
          ],
          Divider(height: 24, color: Colors.blue.shade300),
          lockedDetailRow('المحفظ:', widget.mohaffezName),
          lockedDetailRow(ArabicLabels.type, getSessionTypeArabic(sessionType)),
          if (slotDate != null)
            lockedDetailRow(
                ArabicLabels.date,
                DateFormat('EEEE، dd MMMM yyyy', 'ar')
                    .format(slotDate.toDate())),
          if (timeSlot != null && timeSlot.isNotEmpty)
            lockedDetailRow(ArabicLabels.time, timeSlot),
          if (location != null && location.isNotEmpty)
            lockedDetailRow(ArabicLabels.location, location),
          const SizedBox(height: 12),
          if (planSelectionFallback || !isLockedRequest)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.info_outline,
                    size: 20, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLockedRequest
                        ? 'اختر خطة الدفع واستكمل العملية.'
                        : 'اختر الخطة المناسبة لإتمام الحجز.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.amber.shade900),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget lockedDetailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ]),
      );

  // ── Existing: buildPlanCard ───────────────────────────────────────────────
  Widget buildPlanCard(PricingPlanModel plan) {
    final selected = selectedPlan?.id == plan.id;
    return GestureDetector(
      onTap: () {
        setState(() => selectedPlan = plan);
        calculatePrice();
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
          color: selected ? AppTheme.accentGreen.withValues(alpha: 0.05) : null,
        ),
        child: Row(children: [
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
                Text(plan.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  plan.sessionsCount > 1
                      ? '${plan.sessionsCount} جلسات'
                      : 'جلسة واحدة',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            '${plan.priceEGP.toStringAsFixed(0)} ${ArabicLabels.egp}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ]),
      ),
    );
  }

  Widget _buildLockedPlanCard(PricingPlanModel plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGreen, width: 2),
        color: AppTheme.accentGreen.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: AppTheme.accentGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${plan.priceEGP.toStringAsFixed(0)} جنيه',
                  style: const TextStyle(color: AppTheme.accentGreen),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('محدد',
                style: TextStyle(fontSize: 12, color: AppTheme.accentGreen)),
          ),
        ],
      ),
    );
  }

  // ── Existing: buildPromoCodeSection ──────────────────────────────────────
  Widget get buildPromoCodeSection {
    final promoState = ref.watch(promoCodeProvider);
    final isValidatingPromo = promoState.isLoading;
    final promoError = promoState.hasError ? promoState.error.toString() : null;
    final promoCodeValid = appliedPromoCode != null && promoState.hasValue;
    final discount = appliedPromoCode?.discount ?? 0;
    final pricing = resolvePricing();
    final isFreeSession = pricing.finalPrice < 0.01;

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isFreeSession && promoCodeValid)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Colors.green, Color(0xFF66BB6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Row(children: [
              Icon(Icons.celebration, color: Colors.white, size: 36),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('جلسة مجانية! 🎁',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('100% خصم مطبق',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ]),
          ),
        TextField(
          controller: promoCodeController,
          onChanged: (_) {
            if (appliedPromoCode != null) {
              setState(() {
                appliedPromoCode = null;
                calculatePrice();
              });
              ref.read(promoCodeProvider.notifier).clearPromoCode();
            }
          },
          decoration: InputDecoration(
            labelText: ArabicLabels.enterPromoCode,
            hintText: 'PROMO2025',
            suffixIcon: isValidatingPromo
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2)))
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
                  if (promoCodeController.text.trim().isEmpty) return;
                  await ref
                      .read(promoCodeProvider.notifier)
                      .validateCode(promoCodeController.text.trim());
                  final latest = ref.read(promoCodeProvider).valueOrNull;
                  if (latest != null && mounted) {
                    setState(() {
                      appliedPromoCode = latest;
                      calculatePrice();
                    });
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: promoCodeValid ? Colors.green : null,
          ),
          child: Text(isValidatingPromo
              ? '...'
              : promoCodeValid
                  ? ArabicLabels.apply
                  : 'تحقق'),
        ),
        if (promoError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.error, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(promoError,
                      style: const TextStyle(color: Colors.red, fontSize: 12))),
            ]),
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
              child: Row(children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('كود الخصم مطبّق',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                      Text(
                        appliedPromoCode?.type == 'percentage'
                            ? '${ArabicLabels.discount} ${discount.toStringAsFixed(0)}%'
                            : '${ArabicLabels.discount} ${discount.toStringAsFixed(0)} ${ArabicLabels.currency}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  // ── Existing: buildPriceSummary ───────────────────────────────────────────
  Widget get buildPriceSummary {
    final pricing = resolvePricing();
    final isFreeSession = pricing.finalPrice < 0.01;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isFreeSession
            ? Colors.green.withValues(alpha: 0.1)
            : AppTheme.primaryAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFreeSession
              ? Colors.green
              : AppTheme.primaryAmber.withValues(alpha: 0.25),
        ),
      ),
      child: Column(children: [
        if (pricing.originalPrice > 0)
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('سعر الخطة'),
            Text(
              '${pricing.originalPrice.toStringAsFixed(2)} ${ArabicLabels.currency}',
              style: TextStyle(
                decoration:
                    pricing.discount > 0 ? TextDecoration.lineThrough : null,
                color: Colors.grey,
              ),
            ),
          ]),
        if (pricing.discount > 0) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text(ArabicLabels.discount),
            Text(
              '- ${pricing.discount.toStringAsFixed(2)} ${ArabicLabels.currency}',
              style: const TextStyle(
                  color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ]),
        ],
        const Divider(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text(ArabicLabels.total,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(
            isFreeSession
                ? 'مجاني 🎁'
                : '${pricing.finalPrice.toStringAsFixed(2)} ${ArabicLabels.currency}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isFreeSession ? Colors.green : AppTheme.primaryAmber),
          ),
        ]),
      ]),
    );
  }

  // ── Existing: handleFreeSession (unchanged) ───────────────────────────────
  Future<void> handleFreeSession(
      BuildContext context, WidgetRef ref, dynamic user) async {
    // Guard against using context after async gaps
    if (!mounted) return;
    setState(() => isProcessingPayment = true);
    try {
      DateTime? slotDate;
      String? timeSlot;
      String? sessionType;
      DateTime? slotStart;
      DateTime? slotEnd;
      String? location;
      double? lat;
      double? lng;
      String? phone;

      if (widget.requestId != null) {
        final requestSnap = await FirebaseFirestore.instance
            .collection('sessionRequests')
            .doc(widget.requestId)
            .get();
        if (!requestSnap.exists) throw Exception('الطلب غير موجود');
        final data = requestSnap.data() as Map<String, dynamic>;
        final slotDateRaw = data['slotDate'];
        slotDate = slotDateRaw is Timestamp
            ? slotDateRaw.toDate()
            : slotDateRaw is DateTime
                ? slotDateRaw
                : null;
        timeSlot = data['preferredTimeSlot'] as String?;
        sessionType = data['sessionType'] as String?;
        location = data['imamAddressText'] as String?;
        lat = (data['imamAddressLat'] as num?)?.toDouble();
        lng = (data['imamAddressLng'] as num?)?.toDouble();
        phone = data['mohaffezPhone'] as String?;
      } else {
        if (!hasSelectedSlot) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('يرجى اختيار الموعد أولاً'),
              backgroundColor: Colors.red));
          return;
        }
        slotDate = lockedDate;
        timeSlot = lockedTimeSlot;
        sessionType = lockedSessionType;
        location =
            widget.mohaffezAddress ?? widget.location ?? lockedRequestLocation;
        lat = widget.mohaffezLat;
        lng = widget.mohaffezLng;
        phone = widget.mohaffezPhone;
      }

      if (slotDate == null || timeSlot == null || sessionType == null) {
        throw Exception('بيانات الموعد غير مكتملة');
      }

      final timeSlotParts = timeSlot.split('-');
      final startParts = timeSlotParts.first.trim().split(':');
      final endParts = timeSlotParts.length > 1
          ? timeSlotParts.last.trim().split(':')
          : startParts;

      slotStart = DateTime(
        slotDate.year,
        slotDate.month,
        slotDate.day,
        int.tryParse(startParts[0]) ?? 0,
        int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0,
      );
      slotEnd = DateTime(
        slotDate.year,
        slotDate.month,
        slotDate.day,
        int.tryParse(endParts[0]) ?? 0,
        int.tryParse(endParts.length > 1 ? endParts[1] : '0') ?? 0,
      );

      debugPrint(
          'FREE SESSION: date=$slotDate, slot=$timeSlot, type=$sessionType');

      final basePayment = PaymentModel(
        studentId: user.uid,
        studentName: user.name,
        studentEmail: user.email,
        studentPhone: user.phoneNumber ?? '',
        mohaffezId: widget.mohaffezId,
        mohaffezName: widget.mohaffezName,
        planId: selectedPlan!.id!,
        planTitle: selectedPlan!.title,
        amount: 0.0,
        method: PaymentMethod.cash,
        status: PaymentStatus.pending,
        gateway: PaymentGateway.manual,
        createdAt: DateTime.now(),
        metadata: {
          'promoCode': appliedPromoCode!.code,
          'sessionType': sessionType,
          'confirmBooking': widget.requestId != null,
          if (widget.requestId != null) 'requestId': widget.requestId,
          'sessionDetails': {
            'slotDate': Timestamp.fromDate(slotDate),
            'preferredTimeSlot': timeSlot,
            'sessionType': sessionType,
            'location': location,
          },
        },
      );

      final paymentResult = await ref
          .read(paymentActionsProvider.notifier)
          .startPaymentAndHandleResult(
            basePayment: basePayment,
            plan: selectedPlan!,
            extraMetadata: basePayment.metadata,
          );
      if (paymentResult == null) throw Exception('فشل إنشاء سجل الدفع');

      final result =
          await ref.read(bookingFlowProvider.notifier).createFreeSession(
                mohaffezId: widget.mohaffezId,
                mohaffezName: widget.mohaffezName,
                studentId: user.uid,
                studentName: user.name,
                sessionType: sessionType,
                preferredTimeSlot: timeSlot,
                slotDate: slotDate,
                slotStart: slotStart,
                slotEnd: slotEnd,
                imamAddressText: location,
                imamAddressLat: lat,
                imamAddressLng: lng,
                mohaffezPhone: phone,
                promoCode: appliedPromoCode!.code,
                requestId: widget.requestId,
                paymentId: paymentResult.paymentId,
              );

      if (!mounted) return;
      if (result.isSuccess) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 تم تأكيد جلستك المجانية!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        context.go('/home');
      } else {
        throw Exception(result.errorMessage ?? 'فشل تأكيد الجلسة');
      }
    } catch (e, stack) {
      debugPrint('Free session error: $e');
      debugPrintStack(stackTrace: stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5)));
    } finally {
      if (mounted) setState(() => isProcessingPayment = false);
    }
  }

  // ── Existing: handleRegularPayment (unchanged) ────────────────────────────
  Future<void> handleRegularPayment(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    PricingResult pricing,
  ) async {
    setState(() => isProcessingPayment = true);
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
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
            'sessionType': lockedSessionType,
            'slotDate':
                lockedDate != null ? Timestamp.fromDate(lockedDate!) : null,
            'preferredTimeSlot': lockedTimeSlot,
            'location': widget.location,
          },
        if (appliedPromoCode != null) 'promoCode': appliedPromoCode!.code,
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
            const SnackBar(content: Text('فشل الدفع، حاول مرة أخرى')));
        return;
      }

      if (result.paymentUrl.isEmpty) {
        _openDirectPaymentScreen(context, user, pricing);
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

      if (success == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم الدفع بنجاح!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${ArabicLabels.error}: $e')));
    } finally {
      if (mounted) setState(() => isProcessingPayment = false);
    }
  }

  String getSessionTypeArabic(String? type) {
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
