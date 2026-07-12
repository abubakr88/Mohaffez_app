// lib/screens/direct_booking_request_screen.dart
// WHY THIS SCREEN EXISTS: Path C direct single-session booking previously jumped
// straight to the payment screen, forcing the student to pay before the teacher
// agreed to the slot. This screen inserts the missing "request first" step:
//   Student sends request → Teacher accepts (PendingRequestsScreen) →
//   Student gets notified → Student pays (StudentRequestsScreen "pay-now") →
//   Teacher confirms receipt (DirectPaymentConfirmationsScreen) → Session created

import 'dart:ui' as ui;
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/utils/time_formatter.dart';
import '../../shared/utils/booking_learner_guard.dart';
import '../../shared/widgets/meeting_provider_picker.dart';

class DirectBookingRequestScreen extends ConsumerStatefulWidget {
  const DirectBookingRequestScreen({super.key});

  @override
  ConsumerState<DirectBookingRequestScreen> createState() =>
      _DirectBookingRequestScreenState();
}

class _DirectBookingRequestScreenState
    extends ConsumerState<DirectBookingRequestScreen> {
  bool _submitting = false;
  bool _acknowledged = false;
  String? _selectedProvider;

  // True only after a successful request is sent.
  // Prevents dispose from resetting the provider too early during navigation.
  bool _navigatingAway = false;

  // FIX[BUNDLE-ORPHAN]: Cache the notifier reference early — before any disposal can occur.
  // This is the canonical Riverpod pattern for using notifiers in dispose().
  late final BookingFlowNotifier _bookingFlowNotifier;

  @override
  void initState() {
    super.initState();
    // Cache the notifier reference early
    _bookingFlowNotifier = ref.read(bookingFlowProvider.notifier);
  }

  @override
  void dispose() {
    // If the user backed out without sending, reset the flow so the slot
    // isn't left in a dirty state for the next booking attempt.
    if (!_navigatingAway) {
      // ✅ Uses cached reference — no ref access, safe after widget disposal
      _bookingFlowNotifier.reset();
    }
    super.dispose();
  }

  // Send request
  Future<void> sendRequest() async {
    final flow = ref.read(bookingFlowProvider);
    final slotContext = flow.slotContext;
    final currentUser = ref.read(currentUserProvider).value;

    if (slotContext == null || currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ. أعد المحاولة'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
      return;
    }

    final activeProfile = resolveBookingLearner(context, ref, currentUser);
    if (activeProfile == null) return;

    // Capture messenger BEFORE any await
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);

    try {
      final selectedPlan = await _singleSessionPlanForRequest(slotContext);
      if (selectedPlan == null) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'لا توجد خطة سعر متاحة لهذا النوع من الجلسات في بلدك حالياً',
            ),
            backgroundColor: AppThemeConstants.error,
          ),
        );
        return;
      }
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final payload = {
        if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
        'mohaffezId': slotContext.mohaffezId,
        'mohaffezName': slotContext.mohaffezName,
        'studentName': activeProfile.name,
        ...activeProfile.toCallableBookingSnapshot(currentUser),
        'sessionType': slotContext.sessionType,
        if (slotContext.sessionType == 'online' && _selectedProvider != null)
          'preferredProvider': _selectedProvider,
        'preferredTimeSlot': slotContext.preferredTimeSlot,
        'slotDate': slotContext.slotDate,
        'slotStart': slotContext.slotStart,
        'slotEnd': slotContext.slotEnd,
        if (slotContext.imamAddressText?.isNotEmpty == true)
          'imamAddressText': slotContext.imamAddressText,
        if (slotContext.imamAddressLat != null)
          'imamAddressLat': slotContext.imamAddressLat,
        if (slotContext.imamAddressLng != null)
          'imamAddressLng': slotContext.imamAddressLng,
        if (slotContext.mohaffezPhone?.isNotEmpty == true)
          'mohaffezPhone': slotContext.mohaffezPhone,
        if (currentUser.phoneNumber?.trim().isNotEmpty == true)
          'studentPhone': currentUser.phoneNumber!.trim(),
        'planType': selectedPlan.type.name,
        'planId': selectedPlan.id,
        'planTitle': selectedPlan.title,
        'sessionsCount': selectedPlan.sessionsCount,
        'validityDays': selectedPlan.validityDays,
        'paymentAmount': selectedPlan.priceEGP,
        ...PricingCountryUtils.paymentSnapshot(selectedPlan),
        // Payment is selected only after the teacher accepts. New requests no
        // longer expose an external transfer to the teacher.
        'selectedPaymentMethod': 'pay_after_acceptance',
        'requiresPaymentOnAcceptance': true,
      };

      if (kDebugMode) {
        final firebaseOptions = Firebase.app().options;
        debugPrint('[DirectBooking] Sending createSessionRequest');
        debugPrint('  firebaseProject=${firebaseOptions.projectId}');
        debugPrint('  firebaseAppId=${firebaseOptions.appId}');
        debugPrint('  mohaffezId=${slotContext.mohaffezId}');
        debugPrint('  sessionType=${slotContext.sessionType}');
        debugPrint('  preferredProvider=$_selectedProvider');
        debugPrint('  hasIdToken=${idToken != null && idToken.isNotEmpty}');
        debugPrint('  payloadKeys=${payload.keys.join(', ')}');
      }

      final result = await FirebaseFunctions.instance
          .httpsCallable(
            'createSessionRequest',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 30),
            ),
          )
          .call(payload);

      if (!mounted) return;

      final data = Map<String, dynamic>.from(result.data as Map);
      final success = data['success'] == true;

      if (success) {
        final requestId = data['requestId']?.toString();
        _navigatingAway = true;
        ref.read(bookingFlowProvider.notifier).reset();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم إرسال الطلب! سيتم إعلامك عندما يقبل المحفظ'),
            backgroundColor: AppThemeConstants.success,
            duration: Duration(seconds: 5),
          ),
        );
        if (requestId != null && requestId.isNotEmpty) {
          context.go('/booking/status/$requestId');
        } else {
          context.go('/requests');
        }
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(data['message']?.toString() ?? 'فشل إرسال الطلب'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('[DirectBooking] FirebaseFunctionsException');
        debugPrint('  code=${e.code}');
        debugPrint('  message=${e.message}');
        debugPrint('  details=${e.details}');
      }
      if (!mounted) return;
      // Idempotent: if the same request was already sent, treat as success.
      if (e.code == 'already-exists') {
        String? existingRequestId;
        if (e.details is Map) {
          existingRequestId = (e.details as Map)['requestId']?.toString();
        }
        _navigatingAway = true;
        ref.read(bookingFlowProvider.notifier).reset();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم إرسال الطلب بالفعل'),
            backgroundColor: AppThemeConstants.warning,
          ),
        );
        if (existingRequestId != null && existingRequestId.isNotEmpty) {
          context.go('/booking/status/$existingRequestId');
        } else {
          context.go('/requests');
        }
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(_functionsErrorMessage(e)),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getErrorMessage(e)),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<PricingPlanModel?> _singleSessionPlanForRequest(
    SlotContext slotContext,
  ) async {
    final repository = ref.read(pricingRepositoryProvider);
    final plans = await repository.getPlansForTeacher(slotContext.mohaffezId);
    final studentCountry = PricingCountryUtils.inferUserCountry(
        ref.read(currentUserProvider).valueOrNull);
    final matchingPlans = plans
        .where((plan) =>
            plan.isActive &&
            plan.type == PlanType.single &&
            PricingCountryUtils.matchesMode(plan, slotContext.sessionType))
        .toList();
    final visiblePlans = PricingCountryUtils.preferCountryPlans(
      matchingPlans,
      studentCountry.code,
    );
    if (visiblePlans.isEmpty) return null;
    final selectedPlanId = ref.read(bookingFlowProvider).selectedPlanId?.trim();
    if (selectedPlanId != null && selectedPlanId.isNotEmpty) {
      for (final plan in visiblePlans) {
        if (plan.id == selectedPlanId) return plan;
      }
    }
    visiblePlans.sort((a, b) => a.priceEGP.compareTo(b.priceEGP));
    return visiblePlans.first;
  }

  String _functionsErrorMessage(FirebaseFunctionsException e) =>
      switch (e.code) {
        'unavailable' => 'الخدمة غير متاحة حالياً. يرجى المحاولة لاحقاً',
        'permission-denied' => 'ليس لديك صلاحية لإجراء هذه العملية',
        'not-found' => 'لم يتم العثور على البيانات المطلوبة',
        'deadline-exceeded' => 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى',
        'resource-exhausted' => 'تم تجاوز الحد المسموح. يرجى المحاولة لاحقاً',
        _ => 'حدث خطأ. يرجى المحاولة مرة أخرى',
      };

  // Build
  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(bookingFlowProvider);
    final slotContext = flow.slotContext;

    // Guard: if slot context was lost (e.g. hot-restart), go home.
    if (slotContext == null) {
      if (!_navigatingAway) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/home');
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final DateTime? slotDate = DateTime.tryParse(slotContext.slotDate);
    final String dateStr = slotDate != null
        ? DateFormat('EEEE d MMMM yyyy', 'ar').format(slotDate)
        : slotContext.slotDate;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إرسال طلب حجز'),
          backgroundColor: AppThemeConstants.primary,
          foregroundColor: AppThemeConstants.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            tooltip: 'رجوع',
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session summary
              SummaryCard(
                mohaffezName: slotContext.mohaffezName,
                isFoundingTeacher: slotContext.isFoundingTeacher,
                sessionType: slotContext.sessionType,
                timeSlot: slotContext.preferredTimeSlot,
                dateStr: dateStr,
                address: slotContext.imamAddressText,
              ),
              const SizedBox(height: 16),
              // Payment method note
              const InfoCard(
                icon: Icons.account_balance_wallet_outlined,
                color: AppThemeConstants.primary,
                title: 'طريقة الدفع',
                body: 'ستدفع بعد قبول المحفظ للطلب. لا يُطلب منك الدفع الآن.',
              ),
              const SizedBox(height: 12),
              // How it works
              const InfoCard(
                icon: Icons.info_outline,
                color: AppThemeConstants.primary,
                title: 'كيف يعمل؟',
                body:
                    '١. ترسل الطلب.\n٢. يقبل المحفظ.\n٣. تستلم إشعار بالقبول.\n٤. تحوّل المبلغ مباشرة.\n٥. يؤكد المحفظ الاستلام.',
              ),
              if (slotContext.sessionType == 'online') ...[
                const SizedBox(height: 16),
                MeetingProviderPicker(
                  teacherId: slotContext.mohaffezId,
                  selected: _selectedProvider,
                  onChanged: (id) => setState(() => _selectedProvider = id),
                ),
              ],
              const SizedBox(height: 16),
              // Acknowledgment checkbox
              Container(
                decoration: BoxDecoration(
                  color: _acknowledged
                      ? AppThemeConstants.primary.withValues(alpha: 0.08)
                      : AppThemeConstants.grey50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _acknowledged
                        ? AppThemeConstants.primary.withValues(alpha: 0.4)
                        : AppThemeConstants.grey300,
                  ),
                ),
                child: CheckboxListTile(
                  value: _acknowledged,
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _acknowledged = v ?? false),
                  activeColor: AppThemeConstants.primary,
                  title: const Text(
                    'أتفهم أنني سأحوّل المبلغ مباشرةً بعد قبول المحفظ للطلب',
                    style: TextStyle(fontSize: 13),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              const SizedBox(height: 20),
              // Send button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_submitting ||
                          !_acknowledged ||
                          (slotContext.sessionType == 'online' &&
                              _selectedProvider == null))
                      ? null
                      : sendRequest,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: AppThemeConstants.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined,
                          color: AppThemeConstants.white),
                  label: Text(
                    _submitting ? 'جاري الإرسال...' : 'إرسال الطلب',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppThemeConstants.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primary,
                    disabledBackgroundColor:
                        AppThemeConstants.primary.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Cancel
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _submitting ? null : () => context.pop(),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(
                        color: AppThemeConstants.grey500, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class SummaryCard extends StatelessWidget {
  final String mohaffezName;
  final bool isFoundingTeacher;
  final String sessionType;
  final String timeSlot;
  final String dateStr;
  final String? address;

  const SummaryCard({
    required this.mohaffezName,
    this.isFoundingTeacher = false,
    required this.sessionType,
    required this.timeSlot,
    required this.dateStr,
    this.address,
    super.key,
  });

  String translateSessionType(String type) {
    switch (type) {
      case 'home':
        return 'منزل';
      case 'mosque':
        return 'مسجد';
      case 'online':
        return 'أونلاين';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.assignment_outlined, color: AppThemeConstants.primary),
              SizedBox(width: 8),
              Text('تفاصيل الجلسة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const Divider(height: 20),
            _row(Icons.person_outline, 'المحفظ: ', mohaffezName),
            if (isFoundingTeacher) ...[
              const SizedBox(height: 8),
              const FoundingTeacherBadge(
                compact: true,
                showLabel: true,
                size: 16,
              ),
            ],
            const SizedBox(height: 8),
            _row(Icons.category_outlined, 'نوع الجلسة: ',
                translateSessionType(sessionType)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.access_time,
                    size: 16, color: AppThemeConstants.grey500),
                const SizedBox(width: 8),
                const Text('الوقت: ',
                    style: TextStyle(
                        color: AppThemeConstants.grey500, fontSize: 13)),
                Expanded(
                  child: Text(
                    formatTimeToArabicAmPm(timeSlot),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row(Icons.calendar_today, 'التاريخ: ', dateStr),
            if (address != null && address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _row(Icons.location_on_outlined, 'العنوان: ', address!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: AppThemeConstants.grey500),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: AppThemeConstants.grey500, fontSize: 13)),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13))),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────

class InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 13, height: 1.7)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
