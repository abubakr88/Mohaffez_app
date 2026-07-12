// lib/screens/select_bundle_plan_screen.dart
//
// NET-NEW screen (replaces BundlePlanSelectionWrapper which navigated directly
// to payment). Now follows the teacher-first rule:
//   1. Student picks a plan
//   2. createSessionRequest CF called → status "pending"
//   3. Waiting state shown — DirectPaymentScreen is NOT opened from here
//
// FIX: Added `requiresPaymentOnAcceptance: true` to the CF payload.
//   Without this flag the Firestore doc stored false (the default), so
//   SessionRepository.acceptRequest() took PATH A (immediate session creation)
//   instead of PATH B (status → awaitingPayment). The result was that the
//   teacher's accept action created a hafizSession without any payment ever
//   being collected.
//
// FIX: Safe result.data parsing — guard `is Map` before casting to avoid
//   TypeError (a Dart Error, not Exception) that would silently swallow the
//   success response and leave _submitting = true forever.

import 'dart:ui' as ui;
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/utils/booking_learner_guard.dart';
import '../../shared/widgets/admin_app_bar.dart';

// ── Plan badge colours ──────────────────────────────────────────────────────
// (planType parameter retained for signature stability; only bundles exist now.)

Color _badgeBg(String planType) =>
    AppThemeConstants.secondary.withValues(alpha: 0.1);

Color _badgeBorder(String planType) => AppThemeConstants.secondary;

Color _badgeFg(String planType) => AppThemeConstants.secondary;

// ── Screen ──────────────────────────────────────────────────────────────────

class SelectBundlePlanScreen extends ConsumerStatefulWidget {
  const SelectBundlePlanScreen({super.key});

  @override
  ConsumerState<SelectBundlePlanScreen> createState() =>
      _SelectBundlePlanScreenState();
}

class _SelectBundlePlanScreenState
    extends ConsumerState<SelectBundlePlanScreen> {
  List<PricingPlanModel> _plans = [];
  PricingPlanModel? _selectedPlan;
  bool _loadingPlans = true;
  bool _submitting = false;
  bool _requestSent = false; // true after CF returns success
  String? _createdRequestId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadPlans() async {
    final flow = ref.read(bookingFlowProvider);
    final slotContext = flow.slotContext;
    final mohaffezId = slotContext?.mohaffezId ?? '';

    debugPrint('🔵 [BUNDLE_FLOW] Step2_SelectBundlePlan_BUILD: '
        'mohaffezId=$mohaffezId, '
        'sessionType=${slotContext?.sessionType}, '
        'slotDate=${slotContext?.slotDate}, '
        'preferredTimeSlot=${slotContext?.preferredTimeSlot}');

    if (mohaffezId.isEmpty) {
      setState(() {
        _error = 'لم يتم تحديد المحفظ';
        _loadingPlans = false;
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(mohaffezId)
          .collection('pricingPlans')
          .where('isActive', isEqualTo: true)
          .where('type', isEqualTo: 'bundle')
          .orderBy('sessionsCount')
          .get();

      final loadedPlans = snap.docs
          .map((d) => PricingPlanModel.fromJson({...d.data(), 'id': d.id}))
          .toList();
      final studentCountry = PricingCountryUtils.inferUserCountry(
          ref.read(currentUserProvider).valueOrNull);
      final modePlans = loadedPlans
          .where((plan) =>
              PricingCountryUtils.matchesMode(plan, slotContext?.sessionType))
          .toList();
      final plans = PricingCountryUtils.preferCountryPlans(
          modePlans, studentCountry.code);
      final selectedPlanId = flow.selectedPlanId?.trim();
      PricingPlanModel? preselectedPlan;
      if (selectedPlanId != null && selectedPlanId.isNotEmpty) {
        for (final plan in plans) {
          if (plan.id == selectedPlanId) {
            preselectedPlan = plan;
            break;
          }
        }
      }
      final visiblePlans =
          preselectedPlan == null ? plans : <PricingPlanModel>[preselectedPlan];

      debugPrint('✅ [BUNDLE_FLOW] Step2_PlansLoaded: count=${plans.length}, '
          'plans=${plans.map((p) => 'id=${p.id}, title=${p.title}, type=${p.type.name}, sessions=${p.sessionsCount}, price=${p.priceEGP}').toList()}');

      if (mounted) {
        setState(() {
          _plans = visiblePlans;
          _selectedPlan = preselectedPlan;
          _loadingPlans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ أثناء تحميل الباقات. يرجى المحاولة مرة أخرى';
          _loadingPlans = false;
        });
      }
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _sendRequest() async {
    final plan = _selectedPlan;
    if (plan == null) return;

    final flow = ref.read(bookingFlowProvider);
    final user = ref.read(currentUserProvider).value;

    final slotCtx = flow.slotContext;

    // Guard: ensure all booking context fields are present before calling CF.
    if (slotCtx == null ||
        slotCtx.mohaffezId.isEmpty ||
        slotCtx.mohaffezName.isEmpty ||
        slotCtx.slotDate.isEmpty ||
        slotCtx.slotStart.isEmpty ||
        slotCtx.slotEnd.isEmpty ||
        slotCtx.preferredTimeSlot.isEmpty ||
        slotCtx.sessionType.isEmpty ||
        user == null) {
      setState(() =>
          _error = 'بيانات الحجز غير مكتملة، يرجى العودة والمحاولة مجدداً');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final activeProfile = resolveBookingLearner(context, ref, user);
      if (activeProfile == null) return;
      final callable =
          FirebaseFunctions.instance.httpsCallable('createSessionRequest');

      debugPrint('🔵 [BUNDLE_FLOW] Step3_SendRequest: '
          'mohaffezId=${slotCtx.mohaffezId}, '
          'planType=${plan.type.name}, '
          'planId=${plan.id}, '
          'sessionsCount=${plan.sessionsCount}, '
          'requiresPaymentOnAcceptance=true');

      final result = await callable.call({
        'mohaffezId': slotCtx.mohaffezId,
        'mohaffezName': slotCtx.mohaffezName,
        'studentName': activeProfile.name,
        ...activeProfile.toCallableBookingSnapshot(user),
        'sessionType': slotCtx.sessionType,
        'preferredTimeSlot': slotCtx.preferredTimeSlot,
        'slotDate': slotCtx.slotDate,
        'slotStart': slotCtx.slotStart,
        'slotEnd': slotCtx.slotEnd,
        if (slotCtx.imamAddressText != null)
          'imamAddressText': slotCtx.imamAddressText,
        if (slotCtx.imamAddressLat != null)
          'imamAddressLat': slotCtx.imamAddressLat,
        if (slotCtx.imamAddressLng != null)
          'imamAddressLng': slotCtx.imamAddressLng,
        if (slotCtx.mohaffezPhone != null)
          'mohaffezPhone': slotCtx.mohaffezPhone,
        'selectedPaymentMethod': 'pay_after_acceptance',
        // ── plan fields ───────────────────────────────────────────────
        'planType': plan.type.name,
        'planId': plan.id,
        'planTitle': plan.title,
        'sessionsCount': plan.sessionsCount,
        'validityDays': plan.validityDays,
        'paymentAmount': plan.priceEGP,
        ...PricingCountryUtils.paymentSnapshot(plan),
        // FIX: This flag tells SessionRepository.acceptRequest() to take
        // PATH B (status → awaitingPayment) instead of PATH A (immediate
        // session creation). Without it the teacher's accept creates a
        // hafizSession with no payment collected.
        'requiresPaymentOnAcceptance': true,
      });

      // FIX: Safe result.data parsing.
      // A hard `as Map<String, dynamic>` cast throws TypeError (a Dart Error,
      // not Exception) if the CF returns null or a non-Map value, which
      // bypasses both on-Exception catch blocks and leaves _submitting = true
      // forever. Guard with `is Map` first.
      String? requestId;
      if (result.data is Map) {
        requestId =
            (result.data as Map<String, dynamic>)['requestId'] as String?;
      }

      debugPrint('✅ [BUNDLE_FLOW] Step3_RequestCreated: requestId=$requestId');

      if (mounted) {
        if (requestId != null && requestId.isNotEmpty) {
          ref.read(bookingFlowProvider.notifier).reset();
          context.go('/booking/status/$requestId');
          return;
        }
        setState(() {
          _submitting = false;
          _requestSent = true;
          _createdRequestId = requestId;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          '❌ [BUNDLE_FLOW] Step3_CF_ERROR: code=${e.code}, message=${e.message}');
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'حدث خطأ أثناء إرسال الطلب. يرجى المحاولة مرة أخرى';
        });
      }
    } on Exception catch (e) {
      debugPrint('❌ [BUNDLE_FLOW] Step3_ERROR: $e');
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى';
        });
      }
    } catch (e, stack) {
      // Catches Dart Errors (TypeError, etc.) — not caught by on Exception.
      debugPrint('❌ [BUNDLE_FLOW] Step3_UNHANDLED_ERROR: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'حدث خطأ غير متوقع — يرجى المحاولة مجدداً';
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_requestSent) return _buildWaitingState();
    final hasPreselectedPlan =
        ref.watch(bookingFlowProvider).selectedPlanId?.trim().isNotEmpty ==
            true;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AdminAppBar(
          title: hasPreselectedPlan ? 'مراجعة الباقة' : 'اختر الباقة',
        ),
        body: _loadingPlans
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _plans.isEmpty
                ? _buildErrorState()
                : _buildPlanList(),
        bottomNavigationBar: _plans.isNotEmpty ? _buildBottomBar() : null,
      ),
    );
  }

  // ── Plan list ──────────────────────────────────────────────────────────────

  Widget _buildPlanList() {
    if (_plans.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد باقات متاحة لهذا المحفظ حالياً',
            style: TextStyle(color: AppThemeConstants.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _plans.length,
      itemBuilder: (_, i) => _buildPlanCard(_plans[i]),
    );
  }

  Widget _buildPlanCard(PricingPlanModel plan) {
    final isSelected = _selectedPlan?.id == plan.id;
    final color = _badgeFg(plan.type.name);
    final localAmount = PricingCountryUtils.displayAmount(plan);
    final priceStr = NumberFormat('#,##0.##', 'ar').format(localAmount);
    final hasValidity = plan.validityDays != null && plan.validityDays! > 0;
    final pricePerSession =
        plan.sessionsCount > 0 ? localAmount / plan.sessionsCount : 0.0;
    final pricePerSessionStr =
        NumberFormat('#,##0', 'ar').format(pricePerSession);

    return InkWell(
      onTap: () {
        debugPrint('🔵 [BUNDLE_FLOW] Step2_PlanSelected: '
            'planId=${plan.id}, '
            'planTitle=${plan.title}, '
            'planType=${plan.type.name}, '
            'sessionsCount=${plan.sessionsCount}, '
            'priceEGP=${plan.priceEGP}, '
            'validityDays=${plan.validityDays}');
        setState(() => _selectedPlan = plan);
      },
      borderRadius: AppThemeConstants.borderRadiusLg,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.06)
              : AppThemeConstants.surface,
          borderRadius: AppThemeConstants.borderRadiusLg,
          border: Border.all(
            color: isSelected ? color : AppThemeConstants.outline,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  const BoxShadow(
                    color: AppThemeConstants.shadow,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  )
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection indicator
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(left: 12, top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? color : AppThemeConstants.textDisabled,
                    width: 2,
                  ),
                  color: isSelected ? color : AppThemeConstants.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check,
                        size: 13, color: AppThemeConstants.onPrimary)
                    : null,
              ),

              // Plan info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _PlanTypeBadge(planType: plan.type.name),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            plan.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isSelected
                                  ? color
                                  : AppThemeConstants.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Plan description
                    if (plan.description != null &&
                        plan.description!.isNotEmpty) ...[
                      Text(
                        plan.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppThemeConstants.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],

                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.menu_book_outlined,
                          label: '${plan.sessionsCount} جلسة',
                          color: color,
                        ),
                        if (hasValidity) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.calendar_today_outlined,
                            label: '${plan.validityDays} يوم',
                            color: AppThemeConstants.textSecondary,
                          ),
                        ],
                        if (plan.sessionDurationMinutes != null) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.timer_outlined,
                            label: '${plan.sessionDurationMinutes} دقيقة',
                            color: AppThemeConstants.textSecondary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Text(
                          '$priceStr ${plan.currencyLabel}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (plan.currencyCode != 'EGP') ...[
                          Text(
                            'يعادل ${PricingCountryUtils.egpPriceText(plan)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppThemeConstants.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (plan.sessionsCount > 0) ...[
                          Text(
                            '($pricePerSessionStr ${plan.currencyLabel}/جلسة)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppThemeConstants.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                      color: AppThemeConstants.error, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_selectedPlan == null || _submitting)
                    ? null
                    : _sendRequest,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppThemeConstants.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: AppThemeConstants.onPrimary),
                label: Text(
                  _submitting ? 'جارٍ الإرسال...' : 'إرسال الطلب للمعلم',
                  style: const TextStyle(
                    color: AppThemeConstants.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.primary,
                  disabledBackgroundColor: AppThemeConstants.divider,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppThemeConstants.borderRadiusMd,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Waiting state ──────────────────────────────────────────────────────────

  Widget _buildWaitingState() {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: 'في انتظار الموافقة'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppThemeConstants.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppThemeConstants.secondary, width: 2),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 44,
                    color: AppThemeConstants.secondary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'تم إرسال طلبك بنجاح!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'في انتظار موافقة المعلم على الباقة.\n'
                  'ستتلقى إشعاراً فور الموافقة ويمكنك إتمام الدفع.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppThemeConstants.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_selectedPlan != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: _badgeBg(_selectedPlan!.type.name),
                      borderRadius: AppThemeConstants.borderRadiusMd,
                      border: Border.all(
                          color: _badgeBorder(_selectedPlan!.type.name)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.card_membership,
                          size: 20,
                          color: _badgeFg(_selectedPlan!.type.name),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_selectedPlan!.title} · '
                          '${_selectedPlan!.sessionsCount} جلسة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _badgeFg(_selectedPlan!.type.name),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                if (_createdRequestId != null &&
                    _createdRequestId!.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.go('/booking/status/${_createdRequestId!}'),
                    icon: const Icon(Icons.track_changes_rounded),
                    label: const Text('متابعة حالة الطلب'),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('العودة إلى الرئيسية'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppThemeConstants.borderRadiusMd,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Error state ────────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 56, color: AppThemeConstants.error),
            const SizedBox(height: 16),
            Text(
              _error ?? 'خطأ غير معروف',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppThemeConstants.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _loadingPlans = true;
                });
                _loadPlans();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small reusable widgets ───────────────────────────────────────────────────

class _PlanTypeBadge extends StatelessWidget {
  final String planType;
  const _PlanTypeBadge({required this.planType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _badgeBg(planType),
        borderRadius: AppThemeConstants.borderRadiusRound,
        border: Border.all(color: _badgeBorder(planType)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.card_membership, size: 12, color: _badgeFg(planType)),
          const SizedBox(width: 4),
          Text(
            'حزمة',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _badgeFg(planType),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppThemeConstants.borderRadiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
