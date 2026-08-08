// lib/screens/confirm_bundle_session_screen.dart
//
// PURPOSE: Used ONLY when the student already has an active bundle and wants
// to consume one session from it (subscriptionCredit path).
// requiresPaymentOnAcceptance is intentionally FALSE here — no new payment
// is needed. The PendingRequestsScreen.handleAccept() routes this request
// type to confirmBundleSession() (PATH 1), not to the regular accept flow.
//
// For NEW bundle purchases (student buying a bundle for the first time),
// see select_bundle_plan_screen.dart where requiresPaymentOnAcceptance = true.

import 'dart:ui' as ui;
import 'package:mohaffez_core/mohaffez_core.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/utils/booking_learner_guard.dart';
import '../../shared/utils/time_formatter.dart';
import '../../shared/widgets/meeting_provider_picker.dart';

class ConfirmBundleSessionScreen extends ConsumerStatefulWidget {
  final String? requestId;
  final String? subscriptionId;

  const ConfirmBundleSessionScreen({
    super.key,
    this.requestId,
    this.subscriptionId,
  });

  @override
  ConsumerState<ConfirmBundleSessionScreen> createState() =>
      _ConfirmBundleSessionScreenState();
}

class _ConfirmBundleSessionScreenState
    extends ConsumerState<ConfirmBundleSessionScreen> {
  bool _isLoading = false;
  String? _selectedProvider;
  bool _showProviderValidation = false;
  SubscriptionModel? _activeSubscription;
  bool _loadingSubscription = true;
  String? _subscriptionError;
  SessionRequestModel? _loadedRequest;
  bool _hydrating = true;
  // Local cache so bookingFlowProvider.reset() on success doesn't null out
  // slotContext during the GoRouter transition frame (causing a brief flash).
  SlotContext? _cachedSlotContext;

  @override
  void initState() {
    super.initState();
    _hydrateContext();
  }

  Future<void> _hydrateContext() async {
    // 1. Read current slotContext from provider
    final slotCtx = ref.read(bookingFlowProvider).slotContext;

    // 2. If slotContext is already set, cache it locally and move on.
    if (slotCtx != null) {
      if (mounted) {
        setState(() {
          _cachedSlotContext = slotCtx;
          _hydrating = false;
        });
      }
      if (mounted) await _loadSubscription();
      return;
    }

    // 3. widget.requestId must be non-null (passed as constructor param).
    //    If missing, bail out gracefully.
    final requestId = widget.requestId;
    if (requestId == null || requestId.isEmpty) {
      if (mounted) setState(() => _hydrating = false);
      if (mounted) await _loadSubscription();
      return;
    }

    try {
      // 4. Load the sessionRequest doc from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('sessionRequests')
          .doc(requestId)
          .get();

      if (!doc.exists || !mounted) {
        if (mounted) {
          setState(() => _hydrating = false);
          await _loadSubscription();
        }
        return;
      }

      // 5. Parse into model
      _loadedRequest = SessionRequestModel.fromMap(doc.data()!, doc.id);
      final requestSubscriptionId = _loadedRequest!.subscriptionId?.trim();
      if (requestSubscriptionId != null && requestSubscriptionId.isNotEmpty) {
        ref
            .read(bookingFlowProvider.notifier)
            .setSelectedSubscription(requestSubscriptionId);
      }

      // 6. Rebuild a SlotContext from the persisted fields
      final r = _loadedRequest!;

      DateTime parseTs(dynamic ts) =>
          ts is Timestamp ? ts.toDate() : DateTime.parse(ts.toString());

      final rebuilt = SlotContext(
        mohaffezId: r.mohaffezId,
        mohaffezName: r.mohaffezName,
        // FIX: preserve mohaffezPhone from loaded request so it is available
        // for WhatsApp / call actions on the upcoming sessions screen.
        mohaffezPhone: r.mohaffezPhone,
        sessionType: r.sessionType,
        preferredTimeSlot: r.preferredTimeSlot,
        slotDate: parseTs(r.slotDate).toUtc().toIso8601String(),
        slotStart: parseTs(r.slotStart).toUtc().toIso8601String(),
        slotEnd: parseTs(r.slotEnd).toUtc().toIso8601String(),
        imamAddressText: r.imamAddressText,
        imamAddressLat: r.imamAddressLat,
        imamAddressLng: r.imamAddressLng,
        slotLockId: r.slotLockId,
      );

      // 7. Inject into provider and cache locally.
      ref.read(bookingFlowProvider.notifier).setSlotContext(rebuilt);
      _cachedSlotContext = rebuilt;
    } catch (e) {
      // Error silently handled - slotContext will remain null
    } finally {
      if (mounted) setState(() => _hydrating = false);
    }

    if (mounted) await _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final flow = ref.read(bookingFlowProvider);
    final slotContext = flow.slotContext;
    final currentUser = ref.read(currentUserProvider).value;

    if (slotContext == null || currentUser == null) {
      setState(() {
        _subscriptionError = 'بيانات الجلسة غير مكتملة';
        _loadingSubscription = false;
      });
      return;
    }

    try {
      final repo = ref.read(sessionRepositoryProvider);
      final exactSubscriptionId =
          widget.subscriptionId?.trim().isNotEmpty == true
              ? widget.subscriptionId!.trim()
              : (_loadedRequest?.subscriptionId?.trim().isNotEmpty == true
                  ? _loadedRequest!.subscriptionId!.trim()
                  : flow.selectedSubscriptionId?.trim());
      SubscriptionModel? sub;
      if (exactSubscriptionId != null && exactSubscriptionId.isNotEmpty) {
        sub = await repo.getBundleById(exactSubscriptionId);
      } else {
        // Compatibility for old internal links created before exact bundle IDs
        // were carried through the booking flow.
        final legacy = await repo.getActiveBundle(
          studentId: currentUser.uid,
          mohaffezId: slotContext.mohaffezId,
          sessionType: slotContext.sessionType,
        );
        if (legacy != null) sub = await repo.getBundleById(legacy.id);
      }

      if (!mounted) return;

      if (sub == null) {
        setState(() {
          _subscriptionError = 'لا توجد باقة نشطة لهذا النوع من الجلسات';
          _loadingSubscription = false;
        });
        return;
      }

      if (sub.studentId != currentUser.uid ||
          sub.mohaffezId != slotContext.mohaffezId ||
          (sub.sessionType.trim().isNotEmpty &&
              sub.sessionType != slotContext.sessionType)) {
        setState(() {
          _subscriptionError = 'الباقة المختارة لا تخص هذا الحجز.';
          _loadingSubscription = false;
        });
        return;
      }

      if (!sub.canBookSession) {
        setState(() {
          _subscriptionError =
              'هذه الباقة غير نشطة أو منتهية أو لا تحتوي على جلسات متبقية.';
          _loadingSubscription = false;
        });
        return;
      }

      if (normalizeRole(currentUser.role) == roleParent &&
          ((sub.studentProfileId?.trim().isEmpty ?? true) ||
              (sub.studentProfileName?.trim().isEmpty ?? true))) {
        setState(() {
          _subscriptionError =
              'لا تحتوي هذه الباقة على بيانات الابن المرتبط بها. تواصل مع الدعم قبل الحجز.';
          _loadingSubscription = false;
        });
        return;
      }

      // FIX Bug 2: guard against zero remaining sessions.
      // A stale or inconsistent subscription doc could have remainingSessions == 0,
      // which would display "-1 من X" in the UI and allow a doomed booking attempt.
      if (sub.remainingSessions <= 0) {
        if (!mounted) return;
        setState(() {
          _subscriptionError = 'لا توجد جلسات متبقية في هذه الباقة.';
          _loadingSubscription = false;
        });
        return;
      }

      setState(() {
        _activeSubscription = sub;
        _loadingSubscription = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _subscriptionError =
            'حدث خطأ أثناء تحميل الباقة. يرجى المحاولة مرة أخرى';
        _loadingSubscription = false;
      });
    }
  }

  Future<void> _confirmSession() async {
    final flow = ref.read(bookingFlowProvider);
    final slotContext = flow.slotContext;
    final currentUser = ref.read(currentUserProvider).value;
    final sub = _activeSubscription;

    if (_activeSubscription == null ||
        _activeSubscription!.remainingSessions <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد جلسات متبقية. يرجى تجديد الباقة.'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
      return;
    }

    if (slotContext == null || currentUser == null || sub == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ. يرجى المحاولة مرة أخرى.'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
      return;
    }

    if (slotContext.sessionType == 'online' && _selectedProvider == null) {
      setState(() => _showProviderValidation = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر وسيلة التواصل المناسبة للجلسة أولاً'),
          backgroundColor: AppThemeConstants.warning,
        ),
      );
      return;
    }

    final storedProfileId = sub.studentProfileId?.trim();
    final storedProfileName = sub.studentProfileName?.trim();
    final activeProfile = storedProfileId != null &&
            storedProfileId.isNotEmpty &&
            storedProfileName != null &&
            storedProfileName.isNotEmpty
        ? StudentProfileModel(
            id: storedProfileId,
            ownerId: currentUser.uid,
            name: storedProfileName,
            gender: sub.studentProfileGender,
            dateOfBirth: sub.studentProfileBirthDate,
            photoUrl: sub.studentProfilePhotoUrl,
            relationship: 'child',
          )
        : resolveBookingLearner(context, ref, currentUser);
    if (activeProfile == null) return;

    setState(() => _isLoading = true);

    String? slotLockId;
    try {
      final bookingService = ref.read(bookingServiceProvider);

      final slotDate = DateTime.parse(slotContext.slotDate);
      final slotStart = DateTime.parse(slotContext.slotStart);
      final slotEnd = DateTime.parse(slotContext.slotEnd);

      // ── CREATE SLOT LOCK ───────────────────────────────────────────────────
      // Path A (use existing bundle) needs a slot lock to prevent conflicts,
      // just like Path B (buy new bundle) creates one in directPayment.ts.
      //
      // Must include `availabilityDocId` — without it, the createSessionRequest
      // CF reads the lock, can't locate the matching availability doc, and
      // skips disabling the time slot. Result: the slot stays bookable for
      // other students even though this booking is in flight.
      final firestore = FirebaseFirestore.instance;

      // Look up the availability doc for the slot's weekday so the CF can
      // disable the time slot atomically when it accepts the request.
      final availabilitySnap = await firestore
          .collection('users')
          .doc(slotContext.mohaffezId)
          .collection('availability')
          .where('dayOfWeek', isEqualTo: slotDate.weekday)
          .limit(1)
          .get();
      final availabilityDocId =
          availabilitySnap.docs.isEmpty ? null : availabilitySnap.docs.first.id;

      final lockRef = firestore.collection('slotLocks').doc();
      slotLockId = lockRef.id;

      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      await lockRef.set({
        'id': slotLockId,
        'mohaffezId': slotContext.mohaffezId,
        'slotDate': Timestamp.fromDate(slotDate),
        'timeSlot': slotContext.preferredTimeSlot,
        'sessionType': slotContext.sessionType,
        if (availabilityDocId != null) 'availabilityDocId': availabilityDocId,
        'lockedBy': currentUser.uid,
        'lockedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'released': false,
        'sessionRequestId': null, // Will be updated by createSessionRequest CF
      });

      final result = await bookingService.createSessionRequest(
        mohaffezId: slotContext.mohaffezId,
        studentId: currentUser.uid,
        studentName: activeProfile.name,
        mohaffezName: slotContext.mohaffezName,
        sessionType: slotContext.sessionType,
        preferredTimeSlot: slotContext.preferredTimeSlot,
        slotDate: slotDate,
        slotStart: slotStart,
        slotEnd: slotEnd,
        imamAddressText: slotContext.imamAddressText,
        imamAddressLat: slotContext.imamAddressLat,
        imamAddressLng: slotContext.imamAddressLng,
        mohaffezPhone: slotContext.mohaffezPhone,
        studentPhone: currentUser.phoneNumber,
        subscriptionId: sub.id!,
        slotLockId: slotLockId, // Use the newly created slot lock
        // INTENTIONALLY false: no new payment needed — student already owns
        // this bundle. PendingRequestsScreen.handleAccept() detects
        // selectedPaymentMethod == 'subscriptionCredit' and routes to
        // confirmBundleSession() directly, bypassing the payment gate.
        requiresPaymentOnAcceptance: false,
        paymentMethod: BookingPaymentMethod.bundleCredit,
        planTitle: sub.planTitle,
        planType: 'bundle',
        sessionsCount: sub.totalSessions,
        paymentAmount: 0,
        preferredProvider:
            slotContext.sessionType == 'online' ? _selectedProvider : null,
        guardianId: sub.guardianId?.trim().isNotEmpty == true
            ? sub.guardianId
            : currentUser.uid,
        guardianName: sub.guardianName?.trim().isNotEmpty == true
            ? sub.guardianName
            : currentUser.name,
        studentProfileId: activeProfile.id,
        studentProfileName: activeProfile.name,
        studentProfileGender: activeProfile.gender,
        studentProfileBirthDate: activeProfile.dateOfBirth,
        studentAge: activeProfile.age,
        sessionDurationMinutes: sub.sessionDurationMinutes,
      );

      if (!mounted) return;

      if (result.success) {
        ref.read(bookingFlowProvider.notifier).reset();

        // Show different message for duplicate vs new request
        final message = result.isDuplicate
            ? 'لديك طلب موجود بالفعل لهذا الموعد — تم استخدامه'
            : 'تم إرسال طلب الجلسة بنجاح ✓';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: result.isDuplicate
                ? AppThemeConstants.warning
                : AppThemeConstants.success,
            duration: Duration(seconds: result.isDuplicate ? 4 : 3),
          ),
        );
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(result.errorMessage ?? 'فشل إرسال الطلب، حاول مرة أخرى'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ. يرجى المحاولة مرة أخرى.'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } catch (e) {
      // Safety net: catches Dart Errors (TypeError, etc.) that are not Exceptions.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ غير متوقع — يرجى المحاولة مجدداً'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hydrating) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري تحميل البيانات...'),
            ],
          ),
        ),
      );
    }

    // Use the locally cached slotContext so bookingFlowProvider.reset() on
    // success doesn't null it out during the GoRouter transition frame.
    final slotContext = _cachedSlotContext;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        appBar: AppBar(
          title: const Text('تأكيد الحجز'),
          backgroundColor: AppThemeConstants.primary,
          foregroundColor: AppThemeConstants.onPrimary,
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: context.pop,
                )
              : null,
        ),
        body: _loadingSubscription
            ? const Center(child: CircularProgressIndicator())
            : _subscriptionError != null
                ? _buildErrorState()
                : slotContext == null
                    ? _buildNoContextState()
                    : _buildContent(slotContext),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: AppThemeConstants.error),
            const SizedBox(height: 16),
            Text(
              _subscriptionError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hydrating = true;
                  _loadingSubscription = true;
                  _subscriptionError = null;
                });
                _hydrateContext();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoContextState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber,
                size: 64, color: AppThemeConstants.warning),
            const SizedBox(height: 16),
            const Text('لم يتم تحديد موعد الجلسة'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (context.canPop())
                  OutlinedButton(
                    onPressed: context.pop,
                    child: const Text('رجوع'),
                  ),
                if (context.canPop()) const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('العودة للرئيسية'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(SlotContext slotContext) {
    final sub = _activeSubscription!;

    DateTime? displayDate;
    try {
      displayDate = DateTime.parse(slotContext.slotDate);
    } catch (e) {
      // Date parsing failed - displayDate will remain null and date row will be hidden
      // Consider logging this error for debugging in development
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bundle header card ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeConstants.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeConstants.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.collections_bookmark_outlined,
                        color: AppThemeConstants.primary),
                    SizedBox(width: 8),
                    Text(
                      'استخدام باقة حالية',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppThemeConstants.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow(Icons.bookmark_outline, 'اسم الباقة', sub.planTitle),
                const SizedBox(height: 6),
                _infoRow(
                  Icons.confirmation_number_outlined,
                  'الجلسات المتبقية',
                  '${sub.remainingSessions} من ${sub.totalSessions}',
                ),
                const SizedBox(height: 4),
                const Text(
                  'ستُخصم جلسة واحدة عند التأكيد',
                  style: TextStyle(
                      fontSize: 12, color: AppThemeConstants.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Session details card ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeConstants.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeConstants.divider),
              boxShadow: [
                BoxShadow(
                  color: AppThemeConstants.onPrimary.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تفاصيل الجلسة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Divider(height: 20),
                _infoRow(
                    Icons.person_outline, 'المحفظ', slotContext.mohaffezName),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.category_outlined,
                  'نوع الجلسة',
                  ArabicLabels.getSessionTypeLabel(slotContext.sessionType),
                ),
                const SizedBox(height: 8),
                _infoRow(Icons.access_time, 'الوقت',
                    formatTimeToArabicAmPm(slotContext.preferredTimeSlot)),
                if (displayDate != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.calendar_today,
                    'التاريخ',
                    DateFormat('EEEE، d MMMM yyyy', 'ar').format(displayDate),
                  ),
                ],
                if (slotContext.imamAddressText != null &&
                    slotContext.imamAddressText!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.location_on_outlined, 'العنوان',
                      slotContext.imamAddressText!),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // FIX Bug 2: warning shown when this IS the last session
          if (sub.remainingSessions <= 1) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppThemeConstants.warningBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppThemeConstants.warning),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: AppThemeConstants.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذه آخر جلسة في باقتك الحالية',
                      style: TextStyle(
                          color: AppThemeConstants.warning,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (slotContext.sessionType == 'online') ...[
            const SizedBox(height: 16),
            MeetingProviderPicker(
              teacherId: slotContext.mohaffezId,
              selected: _selectedProvider,
              showValidationError: _showProviderValidation,
              onChanged: (id) => setState(() {
                _selectedProvider = id;
                _showProviderValidation = false;
              }),
            ),
          ],

          const SizedBox(height: 24),

          // ── Confirm button ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _confirmSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeConstants.secondary,
                foregroundColor: AppThemeConstants.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: AppThemeConstants.onPrimary, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isLoading
                    ? 'جارٍ الإرسال...'
                    : slotContext.sessionType == 'online' &&
                            _selectedProvider == null
                        ? 'اختر وسيلة التواصل ثم أكد الحجز'
                        : 'تأكيد الحجز',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Cancel button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : context.pop,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('رجوع'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppThemeConstants.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
              fontSize: 13,
              color: AppThemeConstants.textPrimary,
              fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
