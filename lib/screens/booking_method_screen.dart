// lib/screens/booking/booking_method_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/pricing_plan_model.dart';
import '../models/subscription_model.dart';
import '../providers/booking_flow_provider.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/pricing_provider.dart';
import '../shared/theme/app_theme_constants.dart';

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
    final canBuyNewBundle = hasBundlePlans && activeBundle == null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ── Option 1: Use existing bundle ──────────────────────────────────
        _BookingOptionCard(
          icon: Icons.card_membership_rounded,
          backgroundColor: AppThemeConstants.successBackground,
          iconColor: AppThemeConstants.success,
          title: 'استخدام باقة حالية',
          subtitle: activeBundle != null
              ? 'متبقي ${activeBundle.remainingSessions} جلسة من ${activeBundle.totalSessions}'
              : 'لا توجد باقة نشطة لهذا النوع',
          isEnabled: activeBundle != null,
          onTap: activeBundle != null ? _onUseExistingBundle : null,
        ),
        const SizedBox(height: 16),

        // ── Option 2: Buy new bundle ────────────────────────────────────
        _BookingOptionCard(
          icon: Icons.add_shopping_cart_rounded,
          backgroundColor: AppThemeConstants.accentBackground,
          iconColor: AppThemeConstants.primary,
          title: 'شراء باقة جديدة',
          subtitle: activeBundle != null
              ? 'لديك باقة نشطة بالفعل لهذا النوع من الجلسات'
              : 'اختر باقة وابدأ على الفور',
          isEnabled: canBuyNewBundle,
          onTap: canBuyNewBundle ? _onBuyNewBundle : null,
        ),
        const SizedBox(height: 16),

        // ── Option 3: Direct single-session request ─────────────────────
        _BookingOptionCard(
          icon: Icons.payment_rounded,
          backgroundColor: AppThemeConstants.surface,
          iconColor: AppThemeConstants.primary,
          borderColor: AppThemeConstants.primary,
          title: 'إرسال طلب حجز جديد',
          subtitle: 'دفع مباشر لجلسة واحدة',
          isEnabled: true,
          onTap: _onNewDirectRequest,
        ),
        const SizedBox(height: 32),

        // ── Cancel ──────────────────────────────────────────────────────
        TextButton(
          onPressed: () => context.pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppThemeConstants.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'إلغاء',
            style: TextStyle(fontSize: 15),
          ),
        ),
        const SizedBox(height: 24),
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
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? borderColor;

  const _BookingOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isEnabled,
    this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Card(
        elevation: AppThemeConstants.elevationSm,
        shadowColor: AppThemeConstants.shadow,
        color: backgroundColor ?? AppThemeConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppThemeConstants.borderRadiusMd,
          side: borderColor != null 
              ? BorderSide(color: borderColor!, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: AppThemeConstants.borderRadiusMd,
          child: Padding(
            padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (iconColor ?? colorScheme.primary).withOpacity(0.1),
                    borderRadius: AppThemeConstants.borderRadiusSm,
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: isEnabled 
                        ? (iconColor ?? colorScheme.primary)
                        : AppThemeConstants.textDisabled,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppThemeConstants.titleMedium.copyWith(
                          color: isEnabled 
                              ? AppThemeConstants.textPrimary
                              : AppThemeConstants.textDisabled,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppThemeConstants.bodySmall.copyWith(
                          color: isEnabled
                              ? AppThemeConstants.textSecondary
                              : AppThemeConstants.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded, 
                  color: isEnabled 
                      ? AppThemeConstants.textSecondary
                      : AppThemeConstants.textDisabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
