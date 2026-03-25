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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/pricing_plan_model.dart';
import '../providers/booking_flow_provider.dart';
import '../providers/user_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/admin_app_bar.dart';

// ── Plan badge colours ──────────────────────────────────────────────────────

Color _badgeBg(String planType) => planType == 'subscription'
    ? Colors.purple.shade50
    : Colors.amber.shade50;

Color _badgeBorder(String planType) => planType == 'subscription'
    ? Colors.purple.shade300
    : Colors.amber.shade400;

Color _badgeFg(String planType) => planType == 'subscription'
    ? Colors.purple.shade700
    : Colors.amber.shade800;

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
          .where('type', whereIn: ['bundle', 'subscription'])
          .orderBy('sessionsCount')
          .get();

      final plans = snap.docs
          .map((d) => PricingPlanModel.fromJson({...d.data(), 'id': d.id}))
          .toList();

      debugPrint('✅ [BUNDLE_FLOW] Step2_PlansLoaded: count=${plans.length}, '
          'plans=${plans.map((p) => 'id=${p.id}, title=${p.title}, type=${p.type.name}, sessions=${p.sessionsCount}, price=${p.priceEGP}').toList()}');

      if (mounted) {
        setState(() {
          _plans = plans;
          _loadingPlans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'فشل تحميل الباقات: $e';
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
        'studentName': user.name,
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
        'selectedPaymentMethod': 'directpayment',
        // ── plan fields ───────────────────────────────────────────────
        'planType': plan.type.name, // 'bundle' | 'subscription'
        'planId': plan.id,
        'planTitle': plan.title,
        'sessionsCount': plan.sessionsCount,
        'validityDays': plan.validityDays,
        'paymentAmount': plan.priceEGP,
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
        setState(() {
          _submitting = false;
          _requestSent = true;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [BUNDLE_FLOW] Step3_CF_ERROR: code=${e.code}, message=${e.message}');
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message ?? 'حدث خطأ أثناء إرسال الطلب';
        });
      }
    } on Exception catch (e) {
      debugPrint('❌ [BUNDLE_FLOW] Step3_ERROR: $e');
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'حدث خطأ: $e';
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

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: 'اختر الباقة'),
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
            style: TextStyle(color: Colors.grey),
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
    final priceStr = NumberFormat('#,##0', 'ar').format(plan.priceEGP);
    final hasValidity = plan.validityDays != null && plan.validityDays! > 0;

    return GestureDetector(
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
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
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
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
                    color: isSelected ? color : Colors.grey.shade400,
                    width: 2,
                  ),
                  color: isSelected ? color : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
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
                              color: isSelected ? color : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

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
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text(
                      '$priceStr ج.م',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
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
                  style: const TextStyle(color: Colors.red, fontSize: 13),
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
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  _submitting ? 'جارٍ الإرسال...' : 'إرسال الطلب للمعلم',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.primaryAmber,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.amber.shade300, width: 2),
                  ),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 44,
                    color: Colors.amber.shade700,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'تم إرسال طلبك بنجاح!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'في انتظار موافقة المعلم على الباقة.\n'
                  'ستتلقى إشعاراً فور الموافقة ويمكنك إتمام الدفع.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
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
                      borderRadius: BorderRadius.circular(12),
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
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('العودة إلى الرئيسية'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error ?? 'خطأ غير معروف',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _badgeBorder(planType)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.card_membership, size: 12, color: _badgeFg(planType)),
          const SizedBox(width: 4),
          Text(
            planType == 'subscription' ? 'اشتراك' : 'حزمة',
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
        borderRadius: BorderRadius.circular(8),
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
