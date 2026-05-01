// lib/screens/direct_payment_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/src/models/direct_payment_model.dart';
import 'package:mohaffez_core/src/models/pricing_plan_model.dart';
import 'package:mohaffez_core/src/providers/booking_flow_provider.dart';
import 'package:mohaffez_core/src/providers/user_provider.dart';
import 'package:mohaffez_core/src/repositories/pricing_repository.dart';
import 'package:mohaffez_core/src/services/direct_payment_service.dart';
import 'package:mohaffez_core/src/theme/app_theme_constants.dart';

class DirectPaymentScreen extends ConsumerStatefulWidget {
  final String? requestId;
  final String? mohaffezId;
  final String? mohaffezName;
  final String? studentName;
  final String studentEmail;
  final String studentPhone;
  final double? amount;
  final String? sessionType;
  final String? preferredTimeSlot;
  final DateTime? slotDate;
  final DateTime? slotStart;
  final DateTime? slotEnd;
  final String? imamAddressText;
  final double? imamAddressLat;
  final double? imamAddressLng;
  final String? mohaffezPhone;
  final String? planType;
  final String? planId;
  final String? planTitle;
  final int? sessionsCount;
  final int? validityDays;
  final bool autoBookFirstSession;

  const DirectPaymentScreen({
    super.key,
    this.requestId,
    this.mohaffezId,
    this.mohaffezName,
    this.studentName,
    this.studentEmail = '',
    this.studentPhone = '',
    this.amount,
    this.sessionType,
    this.preferredTimeSlot,
    this.slotDate,
    this.slotStart,
    this.slotEnd,
    this.imamAddressText,
    this.imamAddressLat,
    this.imamAddressLng,
    this.mohaffezPhone,
    this.planType,
    this.planId,
    this.planTitle,
    this.sessionsCount,
    this.validityDays,
    this.autoBookFirstSession = false,
  });

  @override
  ConsumerState<DirectPaymentScreen> createState() =>
      _DirectPaymentScreenState();
}

class _DirectPaymentScreenState extends ConsumerState<DirectPaymentScreen> {
  Map<String, String?> wallets = {};
  DirectPaymentMethod? selectedMethod;
  bool loading = true;
  bool submitting = false;
  final noteController = TextEditingController();

  // Resolved values — prefer widget params, fall back to bookingFlowProvider
  String? resolvedMohaffezId;
  String? resolvedMohaffezName;
  String? resolvedStudentName;
  String? resolvedStudentEmail;
  String? resolvedStudentPhone;
  double? resolvedAmount;
  String? resolvedSessionType;
  String? resolvedTimeSlot;
  DateTime? resolvedSlotDate;
  DateTime? resolvedSlotStart;
  DateTime? resolvedSlotEnd;
  String? resolvedImamAddressText;
  double? resolvedImamAddressLat;
  double? resolvedImamAddressLng;
  String? resolvedMohaffezPhone;

  // App-kill recovery — populated from sessionRequests doc when provider is empty
  String? _hydratedPlanId;
  String? _hydratedPlanTitle;
  String? _hydratedPlanType;
  int?    _hydratedSessions;
  int?    _hydratedValidity;

  @override
  void initState() {
    super.initState();
    _initializeFromProvider();
  }

  Future<void> _initializeFromProvider() async {
    final flow = ref.read(bookingFlowProvider);
    final slotContext = flow.slotContext;
    final currentUser = ref.read(currentUserProvider).value;

    // 🔍 DIAG Step 3: DirectPaymentScreen building, print all incoming params
    debugPrint('🔵 [BUNDLE_FLOW] Step3_DirectPaymentScreen_BUILD: '
        'requestId=${widget.requestId}, '
        'mohaffezId=${widget.mohaffezId}, '
        'mohaffezName=${widget.mohaffezName}, '
        'planType=${widget.planType}, '
        'planId=${widget.planId}, '
        'planTitle=${widget.planTitle}, '
        'sessionsCount=${widget.sessionsCount}, '
        'validityDays=${widget.validityDays}, '
        'amount=${widget.amount}, '
        'sessionType=${widget.sessionType}, '
        'slotDate=${widget.slotDate}, '
        'slotStart=${widget.slotStart}, '
        'slotEnd=${widget.slotEnd}, '
        'preferredTimeSlot=${widget.preferredTimeSlot}, '
        'slotContext_mohaffezId=${slotContext?.mohaffezId}, '
        'slotContext_sessionType=${slotContext?.sessionType}');

    // ── FIX: Only guard when BOTH provider context AND widget params are absent.
    // When navigating from StudentRequestsScreen (Pay Now), mohaffezId is passed
    // directly as a widget param — slotContext is intentionally null.
    // Crashing here was the root cause of the wrong screen being shown.
    if (slotContext == null && widget.mohaffezId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('بيانات الجلسة غير مكتملة، يرجى المحاولة مرة أخرى'),
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    // Resolve values: widget params win over provider context
    resolvedMohaffezId = widget.mohaffezId ?? slotContext?.mohaffezId;
    resolvedMohaffezName = widget.mohaffezName ?? slotContext?.mohaffezName;
    resolvedStudentName = widget.studentName ?? currentUser?.name ?? '';
    resolvedStudentEmail = widget.studentEmail.isNotEmpty
        ? widget.studentEmail
        : currentUser?.email ?? '';
    resolvedStudentPhone = widget.studentPhone.isNotEmpty
        ? widget.studentPhone
        : currentUser?.phoneNumber ?? '';
    resolvedSessionType = widget.sessionType ?? slotContext?.sessionType;
    resolvedTimeSlot =
        widget.preferredTimeSlot ?? slotContext?.preferredTimeSlot;
    resolvedImamAddressText =
        widget.imamAddressText ?? slotContext?.imamAddressText;
    resolvedImamAddressLat =
        widget.imamAddressLat ?? slotContext?.imamAddressLat;
    resolvedImamAddressLng =
        widget.imamAddressLng ?? slotContext?.imamAddressLng;
    resolvedMohaffezPhone =
        widget.mohaffezPhone ?? slotContext?.mohaffezPhone;

    // Slot dates: prefer widget DateTime params first, then parse from provider
    if (widget.slotDate != null) {
      resolvedSlotDate = widget.slotDate;
      resolvedSlotStart = widget.slotStart;
      resolvedSlotEnd = widget.slotEnd;
    } else if (slotContext != null) {
      if (slotContext.slotDate.isNotEmpty) {
        resolvedSlotDate = DateTime.tryParse(slotContext.slotDate);
      }
      if (slotContext.slotStart.isNotEmpty) {
        resolvedSlotStart = DateTime.tryParse(slotContext.slotStart);
      }
      if (slotContext.slotEnd.isNotEmpty) {
        resolvedSlotEnd = DateTime.tryParse(slotContext.slotEnd);
      }
    }

    // Fetch price based on plan type
    if (widget.amount == null) {
      final isBundlePlan = widget.planType == 'bundle' ||
                           widget.planType == 'subscription';

      if (isBundlePlan && widget.planId != null) {
        await _fetchBundlePlanPrice(
          resolvedMohaffezId ?? slotContext?.mohaffezId ?? '',
          widget.planId!,
        );
      } else {
        await _fetchSingleSessionPrice(
          resolvedMohaffezId ?? slotContext?.mohaffezId ?? '',
          resolvedSessionType ?? '',
        );
      }
    } else {
      resolvedAmount = widget.amount;
    }

    await _hydrateSlotFromRequestIfNeeded();
    if (resolvedMohaffezId != null) {
      await _loadWallets(resolvedMohaffezId!);
    }
  }

  Future<void> _hydrateSlotFromRequestIfNeeded() async {
    final rid = widget.requestId;
    if (rid == null || rid.isEmpty) return;
    // Skip when slot timestamps are already resolved
    if (resolvedSlotDate != null &&
        resolvedSlotStart != null &&
        resolvedSlotEnd != null) {
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('sessionRequests')
          .doc(rid)
          .get();
      if (!doc.exists || !mounted) return;
      final d = doc.data()!;

      DateTime? parse(dynamic v) {
        if (v is Timestamp) return v.toDate();
        if (v is String) return DateTime.tryParse(v);
        return null;
      }

      setState(() {
        resolvedSlotDate    ??= parse(d['slotDate']);
        resolvedSlotStart   ??= parse(d['slotStart']);
        resolvedSlotEnd     ??= parse(d['slotEnd']);
        resolvedTimeSlot    ??= d['preferredTimeSlot'] as String?;
        resolvedSessionType ??= d['sessionType'] as String?;
        _hydratedPlanId     ??= d['planId']         as String?;
        _hydratedPlanTitle  ??= d['planTitle']      as String?;
        _hydratedPlanType   ??= d['planType']       as String?;
        _hydratedSessions   ??= d['sessionsCount']  as int?;
        _hydratedValidity   ??= d['validityDays']   as int?;
      });

      if (resolvedAmount == null && resolvedMohaffezId != null) {
        final effectivePlanType = widget.planType ?? _hydratedPlanType;
        final effectivePlanId   = widget.planId   ?? _hydratedPlanId;
        final isBundle = effectivePlanType == 'bundle' ||
            effectivePlanType == 'subscription';
        if (isBundle && effectivePlanId != null) {
          await _fetchBundlePlanPrice(resolvedMohaffezId!, effectivePlanId);
        } else if (!isBundle) {
          await _fetchSingleSessionPrice(
              resolvedMohaffezId!, resolvedSessionType ?? '');
        }
      }
    } catch (e) {
      debugPrint('DirectPaymentScreen._hydrateSlotFromRequestIfNeeded: $e');
    }
  }

  Future<void> _fetchSingleSessionPrice(
      String mohaffezId, String sessionType) async {
    try {
      final repository = ref.read(pricingRepositoryProvider);
      final plans = await repository.getPlansForTeacher(mohaffezId);
      final sessionMode = SessionMode.values.firstWhere(
        (m) => m.name == sessionType,
        orElse: () => SessionMode.online,
      );
      final singlePlan = plans.firstWhere(
        (plan) =>
            plan.type == PlanType.single && plan.mode == sessionMode,
        orElse: () => throw Exception('No single session plan found'),
      );
      if (!mounted) return;
      setState(() => resolvedAmount = singlePlan.priceEGP);
    } catch (e) {
      debugPrint('Error fetching single session price: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('تعذّر جلب سعر الجلسة، تواصل مع المعلم مباشرة')),
        );
      }
    }
  }

  Future<void> _fetchBundlePlanPrice(String mohaffezId, String planId) async {
    try {
      final repository = ref.read(pricingRepositoryProvider);
      final plans = await repository.getPlansForTeacher(mohaffezId);
      final bundlePlan = plans.firstWhere(
        (plan) => plan.id == planId,
        orElse: () => throw Exception('Bundle plan not found'),
      );
      if (!mounted) return;
      setState(() => resolvedAmount = bundlePlan.priceEGP);
    } catch (e) {
      debugPrint('Error fetching bundle plan price: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('تعذّر جلب سعر الباقة، تواصل مع المعلم مباشرة')),
      );
    }
  }

  Future<void> _loadWallets(String mohaffezId) async {
    final loaded =
        await DirectPaymentService.getMohaffezWalletNumbers(mohaffezId);
    if (!mounted) return;
    setState(() {
      wallets = loaded;
      loading = false;
    });
  }

  List<DirectPaymentMethod> get availableMethods =>
      DirectPaymentMethod.values
          .where((m) => (wallets[m.value] ?? '').isNotEmpty)
          .toList();

  Future<void> _confirmPayment() async {
    if (selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر طريقة الدفع أولاً')),
      );
      return;
    }
    if (resolvedMohaffezId == null ||
        resolvedAmount == null ||
        resolvedSessionType == null ||
        resolvedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات الجلسة غير مكتملة')),
      );
      return;
    }

    final requestId = widget.requestId;
    if (requestId == null || requestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد رقم الطلب')),
      );
      return;
    }

    setState(() => submitting = true);

    // 🔍 DIAG Step 3: Confirm payment button tapped, print payload
    debugPrint('🔵 [BUNDLE_FLOW] Step3_ConfirmPayment_TAPPED: '
        'requestId=${widget.requestId}, '
        'mohaffezId=$resolvedMohaffezId, '
        'mohaffezName=$resolvedMohaffezName, '
        'studentName=$resolvedStudentName, '
        'amount=$resolvedAmount, '
        'sessionType=$resolvedSessionType, '
        'preferredTimeSlot=$resolvedTimeSlot, '
        'slotDate=$resolvedSlotDate, '
        'slotStart=$resolvedSlotStart, '
        'slotEnd=$resolvedSlotEnd, '
        'paymentMethod=${selectedMethod!.value}, '
        'planType=${widget.planType}, '
        'planId=${widget.planId}, '
        'planTitle=${widget.planTitle}, '
        'sessionsCount=${widget.sessionsCount}, '
        'validityDays=${widget.validityDays}');

    try {
      final result = await DirectPaymentService.studentMarkPaid(
        requestId: requestId,
        mohaffezId: resolvedMohaffezId!,
        mohaffezName: resolvedMohaffezName ?? '',
        studentName: resolvedStudentName ?? '',
        studentEmail: resolvedStudentEmail ?? '',
        studentPhone: resolvedStudentPhone ?? '',
        amount: resolvedAmount!,
        sessionType: resolvedSessionType!,
        preferredTimeSlot: resolvedTimeSlot!,
        slotDate: resolvedSlotDate,
        slotStart: resolvedSlotStart,
        slotEnd: resolvedSlotEnd,
        paymentMethod: selectedMethod!.value,
        studentNote: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        imamAddressText: resolvedImamAddressText,
        imamAddressLat: resolvedImamAddressLat,
        imamAddressLng: resolvedImamAddressLng,
        mohaffezPhone: resolvedMohaffezPhone,
        planType:      widget.planType      ?? _hydratedPlanType,
        planId:        widget.planId        ?? _hydratedPlanId,
        planTitle:     widget.planTitle     ?? _hydratedPlanTitle,
        sessionsCount: widget.sessionsCount ?? _hydratedSessions,
        validityDays:  widget.validityDays  ?? _hydratedValidity,
      );

      // 🔍 DIAG Step 3: CF response
      debugPrint('✅ [BUNDLE_FLOW] Step3_CF_RESPONSE: result=$result');

      if (!mounted) return;

      final success = result['success'] == true;
      if (success) {
        // Only reset the booking flow when we came through it (Path B/C from
        // BookingMethodScreen).  When coming from StudentRequestsScreen (Pay
        // Now), slotContext is null so reset is a no-op — safe either way.
        ref.read(bookingFlowProvider.notifier).reset();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم إرسال إشعار الدفع — بانتظار تأكيد المعلم'),
            backgroundColor: AppThemeConstants.success,
          ),
        );
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  result['message']?.toString() ?? 'فشل إرسال الإشعار')),
        );
      }
    } on Exception catch (e) {
      // 🔍 DIAG Step 3: CF error
      debugPrint('❌ [BUNDLE_FLOW] Step3_CF_ERROR: error=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: _buildAppBar('الدفع المباشر'),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (availableMethods.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: _buildAppBar('الدفع المباشر'),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      size: 64, color: AppThemeConstants.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'لم يُضف المعلم أرقام محافظه بعد',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'يرجى التواصل مع المعلم مباشرة أو انتظار إضافة أرقام الدفع',
                    style: TextStyle(color: AppThemeConstants.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.primary,
                      foregroundColor: AppThemeConstants.onPrimary,
                    ),
                    child: const Text('رجوع'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _buildAppBar('الدفع'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSessionSummaryCard(),
              const SizedBox(height: AppThemeConstants.spaceLg),

              _buildAmountCard(),
              const SizedBox(height: AppThemeConstants.spaceLg),

              const Text(
                'اختر طريقة الدفع',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: AppThemeConstants.spaceSm),
              ...availableMethods.map((m) => _buildMethodTile(m)),
              const SizedBox(height: AppThemeConstants.spaceLg),

              if (selectedMethod != null) ...[
                _buildWalletNumberCard(),
                const SizedBox(height: AppThemeConstants.spaceLg),
              ],

              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  hintText: 'أضف رقم المعاملة أو أي ملاحظة للمعلم...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.note_outlined),
                ),
              ),
              const SizedBox(height: AppThemeConstants.spaceLg),

              _buildInstructionsCard(),
              const SizedBox(height: AppThemeConstants.spaceLg),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: submitting ? null : _confirmPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.secondary,
                    foregroundColor: AppThemeConstants.onPrimary,
                    disabledBackgroundColor: AppThemeConstants.secondary
                        .withValues(alpha: 0.5),
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: AppThemeConstants.onPrimary, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    submitting ? 'جاري الإرسال...' : 'دفعت — أرسل الإشعار',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: AppThemeConstants.spaceMd),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar helper ──────────────────────────────────────────────────────────

  AppBar _buildAppBar(String title) {
    return AppBar(
      title: Text(title),
      backgroundColor: AppThemeConstants.primary,
      foregroundColor: AppThemeConstants.onPrimary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        tooltip: 'رجوع',
        onPressed: () {
          // Use Navigator.pop when navigated via MaterialPageRoute
          // (StudentRequestsScreen → Pay Now), or context.pop for GoRouter routes.
          if (context.canPop()) {
            context.pop();
          } else {
            context.pop();
          }
        },
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────────────────────

  Widget _buildSessionSummaryCard() {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.info_outline,
                  color: AppThemeConstants.primary),
              SizedBox(width: 8),
              Text(
                'تفاصيل الجلسة',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ]),
            const Divider(height: 20),

            if (resolvedMohaffezName != null)
              _infoRow(Icons.person_outline, 'المحفظ',
                  resolvedMohaffezName!),

            if (resolvedSessionType != null) ...[
              const SizedBox(height: 6),
              _infoRow(Icons.category_outlined, 'النوع',
                  _translateSessionType(resolvedSessionType!)),
            ],

            // LTR wrapper prevents RTL from flipping "07:00 - 07:45"
            if (resolvedTimeSlot != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.access_time,
                      size: 16, color: AppThemeConstants.textSecondary),
                  const SizedBox(width: 8),
                  const Text('الوقت: ',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppThemeConstants.textSecondary,
                          fontWeight: FontWeight.w600)),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(resolvedTimeSlot!,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],

            if (resolvedSlotDate != null) ...[
              const SizedBox(height: 6),
              _infoRow(Icons.calendar_today, 'التاريخ',
                  '${resolvedSlotDate!.day}/${resolvedSlotDate!.month}/${resolvedSlotDate!.year}'),
            ],

            if (resolvedImamAddressText != null &&
                resolvedImamAddressText!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _infoRow(Icons.location_on_outlined, 'الموقع',
                  resolvedImamAddressText!),
            ],

            // Bundle plan badge
            if (widget.planType == 'bundle' ||
                widget.planType == 'subscription') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppThemeConstants.primary
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppThemeConstants.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                        Icons.collections_bookmark_outlined,
                        size: 14,
                        color: AppThemeConstants.primary),
                    const SizedBox(width: 4),
                    Text(
                      widget.planType == 'bundle'
                          ? '${widget.planTitle ?? ''} · ${widget.sessionsCount ?? ''} جلسة'
                          : widget.planTitle ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppThemeConstants.primaryVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            AppThemeConstants.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppThemeConstants.secondary
                .withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('المبلغ المطلوب',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          Text(
            resolvedAmount != null
                ? '${resolvedAmount!.toStringAsFixed(0)} ج.م'
                : '...',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppThemeConstants.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTile(DirectPaymentMethod method) {
    final isSelected = selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => selectedMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppThemeConstants.primary.withValues(alpha: 0.08)
              : AppThemeConstants.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppThemeConstants.primary
                : AppThemeConstants.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(
            isSelected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: isSelected
                ? AppThemeConstants.primary
                : AppThemeConstants.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(method.label,
              style: TextStyle(
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 15,
              )),
        ]),
      ),
    );
  }

  Widget _buildWalletNumberCard() {
    final walletNumber = wallets[selectedMethod!.value] ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeConstants.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeConstants.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_balance_wallet,
                color: AppThemeConstants.info, size: 18),
            const SizedBox(width: 6),
            Text(
              'رقم ${selectedMethod!.label}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppThemeConstants.info,
                  fontSize: 14),
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  walletNumber,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined,
                    color: AppThemeConstants.info),
                tooltip: 'نسخ الرقم',
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: walletNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ تم نسخ الرقم'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeConstants.accentAmberLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeConstants.accentAmber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outlined, color: AppThemeConstants.accentAmber, size: 18),
            SizedBox(width: 6),
            Text('تعليمات الدفع',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.accentAmber,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppThemeConstants.accentAmber),
          const SizedBox(height: 10),
          _instructionStep(
            number: '1',
            text: 'حوّل المبلغ على الرقم الظاهر أعلاه',
            icon: Icons.send_to_mobile_outlined,
          ),
          const SizedBox(height: 8),
          _instructionStep(
            number: '2',
            text: 'اضغط "دفعت — أرسل الإشعار" بعد إتمام التحويل',
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 8),
          _instructionStep(
            number: '3',
            text: 'سيتم تفعيل الجلسة بعد مراجعة المعلم وتأكيده للاستلام',
            icon: Icons.schedule_outlined,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppThemeConstants.warningLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppThemeConstants.accentOrange),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppThemeConstants.warning, size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'لا تضغط تأكيد قبل إتمام التحويل الفعلي',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppThemeConstants.accentOrange,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionStep({
    required String number,
    required String text,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: AppThemeConstants.accentAmberDark, shape: BoxShape.circle),
          child: Text(number,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppThemeConstants.white,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: AppThemeConstants.accentAmberDark),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppThemeConstants.grey600),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13,
                color: AppThemeConstants.grey700,
                fontWeight: FontWeight.w600)),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  String _translateSessionType(String type) {
    switch (type) {
      case 'home':
        return 'في المنزل';
      case 'mosque':
        return 'في المسجد';
      case 'online':
        return 'أونلاين';
      default:
        return type;
    }
  }
}
