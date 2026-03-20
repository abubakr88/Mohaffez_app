// lib/screens/booking/booking_method_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/pricing_plan_model.dart';
import '../models/subscription_model.dart';        // ← ADD THIS BACK
import '../providers/booking_flow_provider.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/pricing_provider.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

// BUG FIX #1: Removed duplicate local activeBundleProvider definition.
// It conflicted with the one in session_provider_paginated.dart (named-record
// params vs positional tuple). The canonical version lives there; we just
// import and use it below with the named-record syntax.

// FIX 4: ref.watch instead of ref.read — consistent with provider best practice
final teacherPlansProvider =
    FutureProvider.autoDispose.family<List<PricingPlanModel>, String>(
  (ref, mohaffezId) async {
    final repository = ref.watch(pricingRepositoryProvider);
    return repository.getPlansForTeacher(mohaffezId);
  },
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class BookingMethodScreen extends ConsumerStatefulWidget {
  const BookingMethodScreen({super.key});

  @override
  ConsumerState<BookingMethodScreen> createState() =>
      _BookingMethodScreenState();
}

class _BookingMethodScreenState extends ConsumerState<BookingMethodScreen> {
  /// Tracks whether the user committed to a booking path by tapping an option.
  /// Used in dispose() to decide whether to reset the provider.
  /// Storing it here avoids reading ref inside dispose() which is unsafe.
  BookingPath? _committedPath;

  // Prevents the null guard from firing a second navigation when we
  // intentionally call reset() after a successful booking.
  bool _navigatingAway = false;

  late final BookingFlowNotifier _bookingNotifier;

  @override
  void initState() {
    super.initState();
    _bookingNotifier = ref.read(bookingFlowProvider.notifier);
  }

  @override
  void dispose() {
    if (_committedPath == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bookingNotifier.reset();
      });
    }
    super.dispose();
  }

  // ─── Option tap handlers ──────────────────────────────────────────────────

  void _onUseExistingBundle() {
    _committedPath = BookingPath.useExistingBundle;
    ref
        .read(bookingFlowProvider.notifier)
        .setBookingPath(BookingPath.useExistingBundle);
    // BUG FIX #1: push instead of pushReplacement.
    // pushReplacement removed this screen from the stack, which disposed the
    // autoDispose bookingFlowProvider and wiped slotContext — causing the
    // null guard in build() to fire and redirect to /home.
    // push keeps this screen alive in the stack, preserving provider state.
    context.push('/booking/confirm-bundle-session');
  }

  void _onBuyNewBundle() {
    final flow = ref.read(bookingFlowProvider);
    final slotContext = flow.slotContext;
    debugPrint('🔵 [BUNDLE_FLOW] Step1_BuyNewBundle: tapped, slotContext='
        'mohaffezId=${slotContext?.mohaffezId}, '
        'sessionType=${slotContext?.sessionType}, '
        'slotDate=${slotContext?.slotDate}, '
        'slotStart=${slotContext?.slotStart}, '
        'slotEnd=${slotContext?.slotEnd}, '
        'preferredTimeSlot=${slotContext?.preferredTimeSlot}');

    _committedPath = BookingPath.buyNewBundle;
    ref
        .read(bookingFlowProvider.notifier)
        .setBookingPath(BookingPath.buyNewBundle);
    // BUG FIX #1: push instead of pushReplacement (same reason as above).
    context.push('/booking/select-bundle-plan');
  }

  void _onNewDirectRequest() {
    _committedPath = BookingPath.newDirectRequest;
    ref
        .read(bookingFlowProvider.notifier)
        .setBookingPath(BookingPath.newDirectRequest);
    setState(() => _navigatingAway = true);
    // BUG FIX #1: push instead of pushReplacement (same reason as above).
    context.push('/booking/direct-request');
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(bookingFlowProvider);
    final slotContext = flow.slotContext;

    if (slotContext == null) {
      if (!_navigatingAway) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/home');
        });
      }
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentUser = ref.watch(currentUserProvider).value;
    final studentId = currentUser?.uid;

    if (studentId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // BUG FIX #2: Use named-record params to match the canonical
    // activeBundleProvider defined in session_provider_paginated.dart.
    // The old positional tuple (studentId, mohaffezId, sessionType) caused
    // a type mismatch and a duplicate-provider naming conflict.
    final activeBundleAsync = ref.watch(
      activeBundleProvider((
        studentId: studentId,
        mohaffezId: slotContext.mohaffezId,
        sessionType: slotContext.sessionType,
      )),
    );

    activeBundleAsync.when(
      data: (activeBundle) {
        if (activeBundle != null) {
          debugPrint('✅ [BUNDLE_FLOW] Step6_ActiveBundle: found, '
              'id=${activeBundle.id}, '
              'remainingSessions=${activeBundle.remainingSessions}, '
              'totalSessions=${activeBundle.totalSessions}, '
              'sessionType=${activeBundle.sessionType}, '
              'planTitle=${activeBundle.planTitle}, '
              'status=${activeBundle.status}');
        } else {
          debugPrint('⚠️ [BUNDLE_FLOW] Step6_ActiveBundle: no active bundle');
        }
      },
      loading: () => debugPrint('🔵 [BUNDLE_FLOW] Step6_ActiveBundle: loading...'),
      error: (e, st) => debugPrint('❌ [BUNDLE_FLOW] Step6_ActiveBundle ERROR: $e'),
    );

    final teacherPlansAsync = ref.watch(
      teacherPlansProvider(slotContext.mohaffezId),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كيف تريد الحجز؟'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            tooltip: 'رجوع',
            onPressed: () => context.pop(),
          ),
        ),
        body: activeBundleAsync.when(
          data: (activeBundle) => teacherPlansAsync.when(
            data: (plans) => _buildOptionsList(context, activeBundle, plans),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) =>
                _buildErrorWidget('فشل في تحميل خطط التسعير'),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              _buildErrorWidget('فشل في تحميل الباقة النشطة'),
        ),
      ),
    );
  }

  // ─── Options list ─────────────────────────────────────────────────────────

  Widget _buildOptionsList(
    BuildContext context,
    ActiveBundleInfo? activeBundle,
    List<PricingPlanModel> plans,
  ) {
    final hasBundlePlans = plans.any(
      (plan) =>
          plan.type == PlanType.bundle || plan.type == PlanType.subscription,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ── Option 1: Use existing bundle ──────────────────────────────────
        _BookingOptionCard(
          icon: Icons.card_membership,
          title: 'استخدام باقة حالية',
          subtitle: activeBundle != null
              ? 'متبقي ${activeBundle.remainingSessions} جلسة من ${activeBundle.totalSessions}'
              : 'لا توجد باقة نشطة لهذا النوع',
          isEnabled: activeBundle != null,
          onTap: activeBundle != null ? _onUseExistingBundle : null,
        ),
        const SizedBox(height: 12),

        // ── Option 2: Buy new bundle ────────────────────────────────────
        _BookingOptionCard(
          icon: Icons.add_shopping_cart,
          title: 'شراء باقة جديدة',
          subtitle: 'اختر باقة وابدأ على الفور',
          isEnabled: hasBundlePlans,
          onTap: hasBundlePlans ? _onBuyNewBundle : null,
        ),
        const SizedBox(height: 12),

        // ── Option 3: Direct single-session request ─────────────────────
        _BookingOptionCard(
          icon: Icons.payment,
          title: 'إرسال طلب حجز جديد',
          subtitle: 'دفع مباشر لجلسة واحدة',
          isEnabled: true,
          onTap: _onNewDirectRequest,
        ),
        const SizedBox(height: 24),

        // ── Cancel ──────────────────────────────────────────────────────
        TextButton(
          onPressed: () => context.pop(),
          child: const Text(
            'إلغاء',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─── Error state ──────────────────────────────────────────────────────────

  Widget _buildErrorWidget(String message) {
    final flow = ref.read(bookingFlowProvider);
    final slotContext = flow.slotContext;
    final studentId = ref.read(currentUserProvider).value?.uid;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (studentId != null && slotContext != null) {
                  // BUG FIX #2: named-record params to match canonical provider
                  ref.invalidate(activeBundleProvider((
                    studentId: studentId,
                    mohaffezId: slotContext.mohaffezId,
                    sessionType: slotContext.sessionType,
                  )));
                  // BUG FIX #3: invalidate only this teacher's plan cache,
                  // not every cached instance of the family provider.
                  ref.invalidate(teacherPlansProvider(slotContext.mohaffezId));
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Option card widget ───────────────────────────────────────────────────────

class _BookingOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isEnabled;
  final VoidCallback? onTap;

  const _BookingOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isEnabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
