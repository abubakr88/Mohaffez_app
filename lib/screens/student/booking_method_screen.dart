// lib/screens/booking/booking_method_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/pricing_plan_model.dart';
import '../../models/subscription_model.dart';
import '../../providers/booking_flow_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/session_provider_paginated.dart';
import '../../providers/pricing_provider.dart';
import '../../shared/theme/app_theme_constants.dart';

// ─── Providers ────────────────────────────────────────────────────────────────
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
  BookingPath? _committedPath;
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
    context.push('/booking/confirm-bundle-session');
  }

  void _onBuyNewBundle() {
    _committedPath = BookingPath.buyNewBundle;
    ref
        .read(bookingFlowProvider.notifier)
        .setBookingPath(BookingPath.buyNewBundle);
    context.push('/booking/select-bundle-plan');
  }

  void _onNewDirectRequest() {
    _committedPath = BookingPath.newDirectRequest;
    ref
        .read(bookingFlowProvider.notifier)
        .setBookingPath(BookingPath.newDirectRequest);
    setState(() => _navigatingAway = true);
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
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('الرجاء تسجيل الدخول'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/auth'),
                child: const Text('تسجيل الدخول'),
              ),
            ],
          ),
        ),
      );
    }

    final activeBundleAsync = ref.watch(
      activeBundleProvider((
        studentId: studentId,
        mohaffezId: slotContext.mohaffezId,
        sessionType: slotContext.sessionType,
      )),
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
            loading: () => const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تحميل خطط التسعير...'),
              ],
            )),
            error: (err, stack) =>
                _buildErrorWidget('فشل في تحميل خطط التسعير', studentId, slotContext),
          ),
          loading: () => const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري تحميل الباقة النشطة...'),
            ],
          )),
          error: (err, stack) =>
              _buildErrorWidget('فشل في تحميل الباقة النشطة', studentId, slotContext),
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

    final singleSessionPrices = plans
        .where((p) => p.type == PlanType.single)
        .map((p) => p.priceEGP)
        .toList();
    final lowestPrice = singleSessionPrices.isEmpty
        ? null
        : singleSessionPrices.reduce((a, b) => a < b ? a : b);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _BookingOptionCard(
          icon: Icons.card_membership_rounded,
          backgroundColor: AppThemeConstants.successBackground,
          iconColor: AppThemeConstants.success,
          title: 'استخدام باقة حالية',
          subtitle: activeBundle != null
              ? 'متبقي ${activeBundle.remainingSessions} جلسة من ${activeBundle.totalSessions}'
              : 'لا توجد باقة نشطة لهذا النوع',
          hint: activeBundle == null ? 'اشترِ باقة أولاً' : null,
          isEnabled: activeBundle != null,
          onTap: activeBundle != null ? _onUseExistingBundle : null,
        ),
        const SizedBox(height: 16),

        _BookingOptionCard(
          icon: Icons.add_shopping_cart_rounded,
          backgroundColor: AppThemeConstants.accentBackground,
          iconColor: AppThemeConstants.primary,
          title: 'شراء باقة جديدة',
          subtitle: activeBundle != null
              ? 'لديك باقة نشطة بالفعل لهذا النوع من الجلسات'
              : 'اختر باقة وابدأ على الفور',
          hint: activeBundle != null ? 'يجب إنهاء الباقة الحالية أولاً' : null,
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
          subtitle: lowestPrice != null
              ? 'دفع مباشر لجلسة واحدة • ${lowestPrice.toInt()} جنيه'
              : 'دفع مباشر لجلسة واحدة',
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

  Widget _buildErrorWidget(String message, String? studentId, dynamic slotContext) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppThemeConstants.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('رجوع'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    if (studentId != null && slotContext != null) {
                      ref.invalidate(activeBundleProvider((
                        studentId: studentId,
                        mohaffezId: slotContext.mohaffezId,
                        sessionType: slotContext.sessionType,
                      )));
                      ref.invalidate(teacherPlansProvider(slotContext.mohaffezId));
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
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
  final String? hint;
  final bool isEnabled;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? borderColor;

  const _BookingOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.hint,
    required this.isEnabled,
    this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
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
                    color: (iconColor ?? AppThemeConstants.primary).withValues(alpha: 0.1),
                    borderRadius: AppThemeConstants.borderRadiusSm,
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: isEnabled 
                        ? (iconColor ?? AppThemeConstants.primary)
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
                      if (hint != null && !isEnabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            hint!,
                            style: AppThemeConstants.bodySmall.copyWith(
                              color: AppThemeConstants.warning,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded, 
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
