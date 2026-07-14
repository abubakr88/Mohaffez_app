// lib/screens/student_payment_screen.dart
import 'dart:ui' as ui;
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/utils/booking_learner_guard.dart';
import '../../shared/utils/time_formatter.dart';
import '../../services/payment_service.dart';

enum _DpMethod { online, wallet, direct }

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
    this.showBundlePlansOnly = false,
    this.autoBookFirstSession = false,
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
  final bool showBundlePlansOnly;
  final bool autoBookFirstSession;
  final String? mohaffezAddress;
  final double? mohaffezLat;
  final double? mohaffezLng;
  final String? mohaffezPhone;
  final Map<String, dynamic>? lockedRequest;

  @override
  ConsumerState<StudentPaymentScreen> createState() =>
      _StudentPaymentScreenState();
}

class _PaymentChoiceTile extends StatelessWidget {
  const _PaymentChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = selected
        ? AppThemeConstants.primary
        : enabled
            ? AppThemeConstants.textSecondary
            : AppThemeConstants.grey500;

    return Material(
      color: AppThemeConstants.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? AppThemeConstants.primary.withValues(alpha: 0.07)
                : AppThemeConstants.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppThemeConstants.primary
                  : AppThemeConstants.grey300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: accent,
              ),
              const SizedBox(width: 10),
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? AppThemeConstants.textPrimary
                            : AppThemeConstants.grey500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled
                            ? AppThemeConstants.textSecondary
                            : AppThemeConstants.warning,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentAvailabilityMessage extends StatelessWidget {
  const _PaymentAvailabilityMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeConstants.warningLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppThemeConstants.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppThemeConstants.warning,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppThemeConstants.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
  _DpMethod _selectedDPMethod = _DpMethod.online;

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

  String get effectiveMohaffezName {
    for (final value in [
      widget.mohaffezName,
      widget.lockedRequest?['mohaffezName'],
      widget.sessionDetails?['mohaffezName'],
    ]) {
      final name = value?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return 'المحفظ';
  }

  bool get lockedRequestIsBundlePlan {
    final planType =
        widget.lockedRequest?['planType']?.toString().trim().toLowerCase();
    final selectedPaymentMethod = widget.lockedRequest?['selectedPaymentMethod']
        ?.toString()
        .trim()
        .toLowerCase();
    return planType == 'bundle' ||
        planType == 'subscription' ||
        selectedPaymentMethod == 'buy_new_package';
  }

  bool get isLegacyDirectPaymentRequest =>
      widget.lockedRequest?['selectedPaymentMethod']
          ?.toString()
          .trim()
          .toLowerCase() ==
      'directpayment';

  bool _planMatchesLockedRequest(PricingPlanModel plan) {
    if (!isLockedRequest) return true;

    final lockedPlanId = widget.lockedRequest?['planId']?.toString().trim();
    if (lockedPlanId != null && lockedPlanId.isNotEmpty) {
      return plan.id == lockedPlanId;
    }

    return lockedRequestIsBundlePlan
        ? plan.type == PlanType.bundle
        : plan.type == PlanType.single;
  }

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
    // Existing requests that already committed to an external transfer must
    // remain completable. New requests use wallet or Paymob after acceptance.
    if (isLegacyDirectPaymentRequest) {
      _selectedDPMethod = _DpMethod.direct;
    }
    debugPrint(
      '🔍 [PaymentScreen] isLockedRequest=$isLockedRequest planId=${widget.lockedRequest?['planId']} paymentAmount=${widget.lockedRequest?['paymentAmount']}',
    );
    _loadWalletAvailability();
  }

  Future<void> _loadWalletAvailability() async {
    if (!isLegacyDirectPaymentRequest) {
      if (mounted) setState(() => _loadingWallets = false);
      return;
    }
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
          backgroundColor: AppThemeConstants.secondary,
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
            final studentCountry = PricingCountryUtils.inferUserCountry(
                ref.read(currentUserProvider).valueOrNull);
            filteredPlans = PricingCountryUtils.preferCountryPlans(
              filteredPlans,
              studentCountry.code,
            );

            if (widget.showSubscriptionsOnly) {
              filteredPlans = filteredPlans
                  .where((p) => p.type != PlanType.single)
                  .toList();
            }

            // NEW: Filter for bundle plans only when showBundlePlansOnly is true
            if (widget.showBundlePlansOnly) {
              filteredPlans = filteredPlans
                  .where((p) => p.type == PlanType.bundle)
                  .toList();
            }

            if (isLockedRequest) {
              filteredPlans =
                  filteredPlans.where(_planMatchesLockedRequest).toList();
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

              if (match == null && filteredPlans.length == 1) {
                match = filteredPlans.first;
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
                            style: TextStyle(color: AppThemeConstants.grey500),
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
          error: (_, __) =>
              const Center(child: Text('حدث خطأ. يرجى المحاولة مرة أخرى')),
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
    if (!isLegacyDirectPaymentRequest) {
      return _buildModernPaymentMethodToggle(pricing);
    }
    return _buildLegacyPaymentMethodToggle(pricing);
  }

  Widget _buildModernPaymentMethodToggle(PricingResult pricing) {
    if (pricing.finalPrice <= 0.01) return const SizedBox.shrink();

    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final paymobOn =
        ref.watch(systemConfigProvider).valueOrNull?.paymobEnabled ?? false;
    final walletAsync = ref.watch(walletProvider((
      userId: user.uid,
      ownerType: WalletOwnerType.student,
    )));

    return walletAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (paymobOn) ...[
              const Text(
                'اختر طريقة الدفع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _PaymentChoiceTile(
                icon: Icons.credit_card_rounded,
                title: 'الدفع الإلكتروني',
                subtitle: 'إتمام الدفع بأمان من خلال بوابة الدفع',
                selected: true,
                enabled: true,
                onTap: () =>
                    setState(() => _selectedDPMethod = _DpMethod.online),
              ),
              const SizedBox(height: 10),
            ],
            _PaymentAvailabilityMessage(
              message: paymobOn
                  ? 'تعذر تحميل رصيد محفظي، لكن يمكنك المتابعة بالدفع الإلكتروني.'
                  : 'تعذر تحميل وسائل الدفع حاليًا. يرجى المحاولة مرة أخرى.',
            ),
          ],
        ),
      ),
      data: (wallet) {
        final balance = wallet.balanceEgp;
        final walletSufficient = balance >= pricing.finalPrice;
        final walletEligible = widget.requestId?.trim().isNotEmpty == true;

        if (!paymobOn &&
            walletEligible &&
            walletSufficient &&
            _selectedDPMethod == _DpMethod.online) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedDPMethod == _DpMethod.online) {
              setState(() => _selectedDPMethod = _DpMethod.wallet);
            }
          });
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اختر طريقة الدفع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (walletEligible)
                _PaymentChoiceTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'رصيد محفظي',
                  subtitle: walletSufficient
                      ? 'الرصيد المتاح ${balance.toStringAsFixed(2)} ج.م'
                      : 'الرصيد ${balance.toStringAsFixed(2)} ج.م — ينقصك ${(pricing.finalPrice - balance).toStringAsFixed(2)} ج.م',
                  selected: _selectedDPMethod == _DpMethod.wallet,
                  enabled: walletSufficient,
                  onTap: () =>
                      setState(() => _selectedDPMethod = _DpMethod.wallet),
                  trailing: walletSufficient
                      ? null
                      : TextButton.icon(
                          onPressed: () => context.push('/wallet-topup'),
                          icon: const Icon(Icons.add_card_rounded, size: 18),
                          label: const Text('شحن'),
                        ),
                ),
              if (paymobOn) ...[
                if (walletEligible) const SizedBox(height: 10),
                _PaymentChoiceTile(
                  icon: Icons.credit_card_rounded,
                  title: 'الدفع الإلكتروني',
                  subtitle: 'إتمام الدفع بأمان من خلال بوابة الدفع',
                  selected: _selectedDPMethod == _DpMethod.online,
                  enabled: true,
                  onTap: () =>
                      setState(() => _selectedDPMethod = _DpMethod.online),
                ),
              ],
              if (!paymobOn && (!walletEligible || !walletSufficient)) ...[
                const SizedBox(height: 10),
                _PaymentAvailabilityMessage(
                  message: walletEligible
                      ? 'اشحن رصيد محفظي لإتمام الدفع.'
                      : 'الدفع الإلكتروني غير متاح حاليًا. يرجى المحاولة لاحقًا.',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegacyPaymentMethodToggle(PricingResult pricing) {
    // Don't show for free sessions
    if (pricing.finalPrice <= 0.01) return const SizedBox.shrink();

    // Still loading wallet info — show spinner so the toggle slot is reserved.
    if (_loadingWallets) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Toggle always renders when there's a non-free payment so the
    // "قريبا" Paymob badge stays visible during the coming-soon phase.
    // Direct option is shown as disabled when teacher has no wallet AND
    // we're not in a bundle flow (where direct is always viable).
    final paymobOn =
        ref.watch(systemConfigProvider).valueOrNull?.paymobEnabled ?? false;
    final directAvailable = _hasDirectPayment || widget.showBundlePlansOnly;

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
                  onTap: paymobOn
                      ? () =>
                          setState(() => _selectedDPMethod = _DpMethod.online)
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'الدفع الإلكتروني قادم قريباً، استخدم الدفع المباشر الآن.'),
                            ),
                          ),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !paymobOn
                            ? AppThemeConstants.grey300
                            : (_selectedDPMethod == _DpMethod.online
                                ? AppThemeConstants.secondary
                                : AppThemeConstants.grey300),
                        width:
                            (paymobOn && _selectedDPMethod == _DpMethod.online)
                                ? 2
                                : 1,
                      ),
                      color: !paymobOn
                          ? AppThemeConstants.grey100
                          : (_selectedDPMethod == _DpMethod.online
                              ? AppThemeConstants.secondary
                                  .withValues(alpha: 0.08)
                              : AppThemeConstants.white),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.credit_card,
                          color: paymobOn
                              ? AppThemeConstants.secondary
                              : AppThemeConstants.grey500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'دفع إلكتروني',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: paymobOn
                                  ? AppThemeConstants.textPrimary
                                  : AppThemeConstants.grey500,
                            ),
                          ),
                        ),
                        if (!paymobOn) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.grey300,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'قريبا',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppThemeConstants.grey700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: directAvailable
                      ? () =>
                          setState(() => _selectedDPMethod = _DpMethod.direct)
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('لم يفعّل المحفظ الدفع المباشر بعد.'),
                            ),
                          ),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !directAvailable
                            ? AppThemeConstants.grey300
                            : (_selectedDPMethod == _DpMethod.direct
                                ? AppThemeConstants.success
                                : AppThemeConstants.grey300),
                        width: (directAvailable &&
                                _selectedDPMethod == _DpMethod.direct)
                            ? 2
                            : 1,
                      ),
                      color: !directAvailable
                          ? AppThemeConstants.grey100
                          : (_selectedDPMethod == _DpMethod.direct
                              ? AppThemeConstants.success
                                  .withValues(alpha: 0.08)
                              : AppThemeConstants.white),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: directAvailable
                              ? AppThemeConstants.success
                              : AppThemeConstants.grey500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'دفع مباشر',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: directAvailable
                                  ? AppThemeConstants.textPrimary
                                  : AppThemeConstants.grey500,
                            ),
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
                color: AppThemeConstants.warningLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppThemeConstants.accentOrange),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline,
                    color: AppThemeConstants.warning, size: 20),
                SizedBox(width: 8),
                Expanded(
                    child: Text('يرجى العودة لاختيار الموعد أولاً',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppThemeConstants.accentOrange))),
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
                    side: const BorderSide(
                        color: AppThemeConstants.accentOrange)),
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
                      strokeWidth: 2, color: AppThemeConstants.white))
              : const Icon(Icons.check_circle, color: AppThemeConstants.white),
          label: Text(
            isProcessingPayment
                ? 'جاري التأكيد...'
                : 'تأكيد الجلسة المجانية 🎁',
            style: const TextStyle(
                color: AppThemeConstants.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemeConstants
                .secondary, // WHY: Replace direct green with themed accent green.
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            disabledBackgroundColor: AppThemeConstants.grey300,
            disabledForegroundColor: AppThemeConstants.grey600,
          ),
        ),
      );
    }

    // ── EXISTING: Card / Paymob payment ──────────────────────────────────
    // BUG-A FIX: Allow bundle/subscription plans to proceed without slot
    final planType = selectedPlan?.type;
    final isBundlePlan = planType == PlanType.bundle;
    final requiresSlot = !isFreeSession &&
        !isBundlePlan && // bundles do not require a slot
        widget.requestId == null;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final wallet = user == null
        ? null
        : ref
            .watch(walletProvider((
              userId: user.uid,
              ownerType: WalletOwnerType.student,
            )))
            .valueOrNull;
    final walletCanCover = _selectedDPMethod != _DpMethod.wallet ||
        (wallet != null && wallet.balanceEgp >= pricing.finalPrice);
    final canPay = !isProcessingPayment &&
        (!requiresSlot || hasSelectedSlot) &&
        walletCanCover;

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
                    strokeWidth: 2, color: AppThemeConstants.white))
            : Icon(
                _selectedDPMethod == _DpMethod.wallet
                    ? Icons.account_balance_wallet_rounded
                    : isFreeSession
                        ? Icons.check_circle
                        : Icons.payment,
                color: AppThemeConstants.white),
        label: Text(
          isProcessingPayment
              ? 'جاري المعالجة...'
              : isFreeSession
                  ? 'تأكيد الجلسة المجانية 🎁'
                  : _selectedDPMethod == _DpMethod.wallet
                      ? 'ادفع ${pricing.finalPrice.toStringAsFixed(0)} ج.م من رصيد محفظي'
                      : 'ادفع ${pricing.finalPrice.toStringAsFixed(0)} ج.م إلكترونيًا',
          style: const TextStyle(
              color: AppThemeConstants.white,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isFreeSession
              ? AppThemeConstants.secondary
              : AppThemeConstants
                  .secondary, // WHY: Replace direct green with themed accent green.
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: isFreeSession ? 4 : 2,
          disabledBackgroundColor: AppThemeConstants.grey300,
          disabledForegroundColor: AppThemeConstants.grey600,
        ),
      ),
    );
  }

  // ── MODIFIED: proceedToPayment — 3 branches now ───────────────────────────
  Future<void> proceedToPayment(BuildContext context, WidgetRef ref) async {
    if (selectedPlan == null) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول')));
      return;
    }

    final pricing = resolvePricing();
    final isFreeSession = pricing.finalPrice < 0.01;

    // Legacy external transfers remain available only for requests that were
    // created with that method before the new wallet/Paymob flow.
    final planType = selectedPlan?.type;
    final isBundlePlan = planType == PlanType.bundle;
    final paymobOn = await _isPaymobEnabled();
    if (!mounted || !context.mounted) return;

    if (isFreeSession && appliedPromoCode != null) {
      await handleFreeSession(context, ref, user);
    } else if (_selectedDPMethod == _DpMethod.wallet) {
      await _payFromAppWallet(pricing);
    } else if (_selectedDPMethod == _DpMethod.direct) {
      // BUG-A FIX: Allow bundles to proceed without requestId
      if (isBundlePlan || widget.requestId != null) {
        _openDirectPaymentScreen(context, user, pricing);
        return;
      }
    } else {
      if (!paymobOn) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'الدفع الإلكتروني غير مفعل حالياً. يمكنك الدفع من رصيد محفظي أو المحاولة لاحقًا.',
            ),
          ),
        );
        return;
      }
      await handleRegularPayment(context, ref, user, pricing);
    }
  }

  Future<void> _payFromAppWallet(PricingResult pricing) async {
    final requestId = widget.requestId?.trim();
    if (requestId == null || requestId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('لا يمكن الدفع من المحفظة قبل قبول طلب الحجز.'),
        ),
      );
      return;
    }

    setState(() => isProcessingPayment = true);
    try {
      await ref.read(walletRepositoryProvider).payFromWallet(
            sessionRequestId: requestId,
            amountEgp: pricing.finalPrice,
          );
      if (!mounted) return;
      ref.read(bookingFlowProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.success,
          content: Text('تم الدفع من رصيد محفظي وتأكيد الحجز.'),
        ),
      );
      context.go('/booking/status/$requestId');
    } catch (error) {
      debugPrint('Wallet payment failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text(
              'تعذر إتمام الدفع من المحفظة. تحقق من الرصيد وحاول مرة أخرى.'),
        ),
      );
    } finally {
      if (mounted) setState(() => isProcessingPayment = false);
    }
  }

  Future<bool> _isPaymobEnabled() async {
    final cached = ref.read(systemConfigProvider).valueOrNull;
    if (cached?.paymobEnabled == true) return true;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('systemConfig')
          .doc('global')
          .get();
      return snap.data()?['paymobEnabled'] == true;
    } catch (e) {
      debugPrint('PaymentScreen: failed to read Paymob flag: $e');
      return cached?.paymobEnabled == true;
    }
  }

  void _openDirectPaymentScreen(
    BuildContext context,
    dynamic user,
    PricingResult pricing,
  ) {
    final userModel = user as UserModel;
    final activeProfile = resolveBookingLearner(context, ref, userModel);
    if (activeProfile == null) return;

    // ── BUNDLE/SUBSCRIPTION: no slot or requestId needed upfront ──────────
    // WHY: Bundles are paid first; sessions are booked separately afterward.
    // Only single-session plans require a slot and a requestId at this stage.
    final planType = selectedPlan?.type;
    final isBundlePlan = planType == PlanType.bundle;

    if (isBundlePlan) {
      // Read slot context from booking flow provider when autoBookFirstSession is true
      Map<String, String>? slotData;
      if (widget.autoBookFirstSession) {
        final flow = ref.read(bookingFlowProvider);
        final slotCtx = flow.slotContext;
        if (slotCtx != null) {
          slotData = {
            'slotDate': slotCtx.slotDate,
            'slotStart': slotCtx.slotStart,
            'slotEnd': slotCtx.slotEnd,
            'preferredTimeSlot': slotCtx.preferredTimeSlot,
            'sessionType': slotCtx.sessionType,
          };
        }
      }

      context.push(
        '/booking/direct-payment',
        extra: {
          'requestId': null,
          'mohaffezId': widget.mohaffezId,
          'mohaffezName': effectiveMohaffezName,
          'studentName': activeProfile.name,
          'studentEmail': userModel.email,
          'studentPhone': userModel.phoneNumber ?? '',
          'amount': pricing.finalPrice,
          'sessionType': slotData?['sessionType'] ?? lockedSessionType,
          'preferredTimeSlot': slotData?['preferredTimeSlot'] ?? '',
          'slotDate': slotData != null && slotData['slotDate']!.isNotEmpty
              ? DateTime.tryParse(slotData['slotDate']!)
              : null,
          'slotStart': slotData != null && slotData['slotStart']!.isNotEmpty
              ? DateTime.tryParse(slotData['slotStart']!)
              : null,
          'slotEnd': slotData != null && slotData['slotEnd']!.isNotEmpty
              ? DateTime.tryParse(slotData['slotEnd']!)
              : null,
          'imamAddressText': widget.location,
          'planId': selectedPlan!.id ?? '',
          'planTitle': selectedPlan!.title,
          'planType': planType?.name ?? PlanType.bundle.name,
          'sessionsCount': selectedPlan!.sessionsCount,
          'validityDays': selectedPlan!.validityDays,
          ...activeProfile.toBookingSnapshot(userModel),
          ...PricingCountryUtils.paymentSnapshot(selectedPlan!),
          'autoBookFirstSession': widget.autoBookFirstSession,
        },
      );
      return; // ← stop here; do NOT fall through to the slot guards
    }
    // ── end bundle bypass ─────────────────────────────────────────────────

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

    context.push(
      '/booking/direct-payment',
      extra: {
        'requestId': requestId,
        'mohaffezId': widget.mohaffezId,
        'mohaffezName': effectiveMohaffezName,
        'studentName': activeProfile.name,
        'studentEmail': userModel.email,
        'studentPhone': userModel.phoneNumber ?? '',
        'amount': pricing.finalPrice,
        'sessionType': lockedSessionType,
        'preferredTimeSlot': lockedTimeSlot,
        'slotDate': slotDate,
        'slotStart': slotStart,
        'slotEnd': slotEnd,
        'imamAddressText':
            widget.location ?? widget.mohaffezAddress ?? lockedRequestLocation,
        'imamAddressLat': widget.mohaffezLat,
        'imamAddressLng': widget.mohaffezLng,
        'mohaffezPhone':
            widget.mohaffezPhone ?? widget.lockedRequest?['mohaffezPhone'],
        ...activeProfile.toBookingSnapshot(userModel),
      },
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
        color: AppThemeConstants
            .surface, // WHY: Replace direct blue shade with themed surface color.
        border: Border.all(color: AppThemeConstants.accentBlue, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lock,
                size: 32, color: AppThemeConstants.accentBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isLockedRequest ? 'طلب محجوز — أكمل الدفع' : 'تفاصيل الجلسة',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants
                        .textPrimary), // WHY: Replace direct blue shade text with themed primary text.
              ),
            ),
          ]),
          if (isLockedRequest) ...[
            const SizedBox(height: 4),
            const Text(
              'راجع تفاصيل جلستك أدناه ثم تابع إلى الدفع',
              style:
                  TextStyle(fontSize: 13, color: AppThemeConstants.accentBlue),
            ),
          ],
          const Divider(height: 24, color: AppThemeConstants.accentBlue),
          lockedDetailRow('المحفظ:', effectiveMohaffezName),
          lockedDetailRow(ArabicLabels.type, getSessionTypeArabic(sessionType)),
          if (slotDate != null)
            lockedDetailRow(
                ArabicLabels.date,
                DateFormat('EEEE، dd MMMM yyyy', 'ar')
                    .format(slotDate.toDate())),
          if (timeSlot != null && timeSlot.isNotEmpty)
            lockedDetailRow(
                ArabicLabels.time, formatTimeToArabicAmPm(timeSlot)),
          if (lockedSessionType != 'online' &&
              location != null &&
              location.isNotEmpty)
            lockedDetailRow(ArabicLabels.location, location),
          const SizedBox(height: 12),
          if (planSelectionFallback || !isLockedRequest)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppThemeConstants.primary.withValues(
                    alpha:
                        0.1), // WHY: Replace direct amber shade with themed amber tint.
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 20,
                    color: AppThemeConstants
                        .primaryVariant), // WHY: Replace direct amber shade with themed amber dark.
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLockedRequest
                        ? 'اختر خطة الدفع واستكمل العملية.'
                        : 'اختر الخطة المناسبة لإتمام الحجز.',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppThemeConstants
                            .primaryVariant), // WHY: Replace direct amber shade with themed amber dark.
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
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppThemeConstants.accentBlueDark)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ]),
      );

  // ── Existing: buildPlanCard ───────────────────────────────────────────────
  Widget buildPlanCard(PricingPlanModel plan) {
    final selected = selectedPlan?.id == plan.id;
    return InkWell(
      onTap: () {
        setState(() => selectedPlan = plan);
        calculatePrice();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppThemeConstants.secondary
                : AppThemeConstants.grey300,
            width: selected ? 2.5 : 1,
          ),
          color: selected
              ? AppThemeConstants.secondary.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(children: [
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: AppThemeConstants.secondary,
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
                  style: const TextStyle(
                      fontSize: 13, color: AppThemeConstants.grey600),
                ),
              ],
            ),
          ),
          Text(
            PricingCountryUtils.displayPriceText(plan),
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
        border: Border.all(color: AppThemeConstants.secondary, width: 2),
        color: AppThemeConstants.secondary.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: AppThemeConstants.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  PricingCountryUtils.displayPriceText(plan),
                  style: const TextStyle(color: AppThemeConstants.secondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppThemeConstants.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('محدد',
                style: TextStyle(
                    fontSize: 12, color: AppThemeConstants.secondary)),
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
          color: isFreeSession
              ? AppThemeConstants.success
              : AppThemeConstants.grey300,
          width: isFreeSession ? 2 : 1,
        ),
        color: isFreeSession ? AppThemeConstants.successLight : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isFreeSession && promoCodeValid)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppThemeConstants.success, Color(0xFF66BB6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: AppThemeConstants.success.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Row(children: [
              Icon(Icons.celebration, color: AppThemeConstants.white, size: 36),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('جلسة مجانية! 🎁',
                        style: TextStyle(
                            color: AppThemeConstants.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('100% خصم مطبق',
                        style: TextStyle(
                            color: AppThemeConstants.white70, fontSize: 14)),
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
                    ? const Icon(Icons.check_circle,
                        color: AppThemeConstants.success)
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
            backgroundColor: promoCodeValid ? AppThemeConstants.success : null,
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
              const Icon(Icons.error, color: AppThemeConstants.error, size: 16),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(promoError,
                      style: const TextStyle(
                          color: AppThemeConstants.error, fontSize: 12))),
            ]),
          ),
        if (promoCodeValid && discount > 0 && !isFreeSession)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppThemeConstants.successLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppThemeConstants.success),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle,
                    color: AppThemeConstants.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('كود الخصم مطبّق',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppThemeConstants.success)),
                      Text(
                        appliedPromoCode?.type == 'percentage'
                            ? '${ArabicLabels.discount} ${discount.toStringAsFixed(0)}%'
                            : '${ArabicLabels.discount} ${discount.toStringAsFixed(0)} ${ArabicLabels.currency}',
                        style: const TextStyle(
                            fontSize: 12, color: AppThemeConstants.success),
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
            ? AppThemeConstants.success.withValues(alpha: 0.1)
            : AppThemeConstants.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFreeSession
              ? AppThemeConstants.success
              : AppThemeConstants.primary.withValues(alpha: 0.25),
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
                color: AppThemeConstants.grey500,
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
                  color: AppThemeConstants.success,
                  fontWeight: FontWeight.bold),
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
                color: isFreeSession
                    ? AppThemeConstants.success
                    : AppThemeConstants.primary),
          ),
        ]),
      ]),
    );
  }

  // ── Existing: handleFreeSession (unchanged) ───────────────────────────────
  Future<void> handleFreeSession(
      BuildContext context, WidgetRef ref, dynamic user) async {
    final userModel = user as UserModel;
    final activeProfile = resolveBookingLearner(context, ref, userModel);
    if (activeProfile == null) return;

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
              backgroundColor: AppThemeConstants.error));
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
        studentName: activeProfile.name,
        studentEmail: user.email,
        studentPhone: user.phoneNumber ?? '',
        mohaffezId: widget.mohaffezId,
        mohaffezName: effectiveMohaffezName,
        planId: selectedPlan!.id ?? '',
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
            'sessionDurationMinutes': selectedPlan!.sessionDurationMinutes,
            ...activeProfile.toBookingSnapshot(userModel),
          },
          ...activeProfile.toBookingSnapshot(userModel),
          ...PricingCountryUtils.paymentSnapshot(selectedPlan!),
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
          await ref.read(legacyBookingFlowProvider.notifier).createFreeSession(
                mohaffezId: widget.mohaffezId,
                mohaffezName: effectiveMohaffezName,
                studentId: user.uid,
                studentName: activeProfile.name,
                guardianId: user.uid,
                guardianName: user.name,
                studentProfileId: activeProfile.id,
                studentProfileName: activeProfile.name,
                studentProfileGender: activeProfile.gender,
                studentProfileBirthDate: activeProfile.dateOfBirth,
                studentAge: activeProfile.age,
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
            backgroundColor: AppThemeConstants.success,
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (!context.mounted) return;
        if (widget.requestId != null && widget.requestId!.isNotEmpty) {
          context.go('/booking/status/${widget.requestId}');
        } else {
          context.go('/home');
        }
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.errorMessage ?? 'تعذر تأكيد الجلسة'),
          backgroundColor: AppThemeConstants.error,
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e, stack) {
      debugPrint('Free session error: $e');
      debugPrintStack(stackTrace: stack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('حدث خطأ. يرجى المحاولة مرة أخرى'),
          backgroundColor: AppThemeConstants.error,
          duration: Duration(seconds: 5)));
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
    final userModel = user as UserModel;
    final activeProfile = resolveBookingLearner(context, ref, userModel);
    if (activeProfile == null) return;

    setState(() => isProcessingPayment = true);
    var loadingDialogOpen = true;
    BuildContext? loadingDialogContext;

    void closeLoadingDialog() {
      if (!loadingDialogOpen) return;
      final dialogContext = loadingDialogContext;
      if (dialogContext != null && dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
      loadingDialogOpen = false;
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          loadingDialogContext = dialogContext;
          return const Center(child: CircularProgressIndicator());
        });
    try {
      final basePayment = PaymentModel(
        studentId: user.uid,
        studentName: activeProfile.name,
        studentEmail: user.email,
        studentPhone: user.phoneNumber ?? '',
        mohaffezId: widget.mohaffezId,
        mohaffezName: effectiveMohaffezName,
        planId: selectedPlan!.id ?? '',
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
            'sessionDurationMinutes': selectedPlan!.sessionDurationMinutes,
            ...activeProfile.toBookingSnapshot(userModel),
          },
        ...activeProfile.toBookingSnapshot(userModel),
        ...PricingCountryUtils.paymentSnapshot(selectedPlan!),
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

      if (result == null) {
        closeLoadingDialog();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل الدفع، حاول مرة أخرى')));
        return;
      }

      var paymentUrl = result.paymentUrl;
      if (paymentUrl.isEmpty) {
        final studentPhone = user.phoneNumber?.trim();
        final studentName = activeProfile.name.trim();
        final paymobResult =
            await ref.read(paymentServiceProvider).initiatePayment(
                  paymentId: result.paymentId,
                  amount: pricing.finalPrice,
                  studentEmail: user.email,
                  studentPhone: studentPhone != null && studentPhone.isNotEmpty
                      ? studentPhone
                      : '01000000000',
                  studentName: studentName.isNotEmpty ? studentName : 'Student',
                );

        if (!context.mounted) return;
        if (paymobResult['success'] != true) {
          debugPrint('Paymob initiatePayment failed: ${paymobResult['error']}');
          closeLoadingDialog();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('فشل تجهيز الدفع الإلكتروني. يرجى المحاولة مرة أخرى'),
              backgroundColor: AppThemeConstants.error,
            ),
          );
          return;
        }

        paymentUrl = paymobResult['paymentUrl']?.toString() ?? '';
        if (paymentUrl.isEmpty) {
          throw Exception('Paymob returned an empty payment URL');
        }

        try {
          await ref.read(paymentRepositoryProvider).updatePaymentGatewayInfo(
                result.paymentId,
                orderId: paymobResult['orderId']?.toString(),
                paymentKey: paymobResult['paymentKey']?.toString(),
              );
        } catch (e) {
          debugPrint('Paymob gateway order update failed: $e');
        }
      }

      if (!context.mounted) return;
      closeLoadingDialog();

      final success = await context.push<bool>(
        '/payment-webview',
        extra: {
          'paymentUrl': paymentUrl,
          'paymentId': result.paymentId,
          'plan': selectedPlan!,
        },
      );

      if (success == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم الدفع بنجاح!'),
              backgroundColor: AppThemeConstants.success),
        );
        if (widget.requestId != null && widget.requestId!.isNotEmpty) {
          context.go('/booking/status/${widget.requestId}');
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('Paymob payment error: $e');
      if (!context.mounted) return;
      closeLoadingDialog();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('حدث خطأ في تجهيز الدفع الإلكتروني. يرجى المحاولة مرة أخرى'),
        backgroundColor: AppThemeConstants.error,
      ));
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
