// lib/screens/booking/booking_method_screen.dart

import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/utils/time_formatter.dart';

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
  bool _selectedPlanRouteScheduled = false;

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

  void _continueWithSelectedPlan(PricingPlanModel plan) {
    if (_selectedPlanRouteScheduled) return;
    _selectedPlanRouteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (plan.type == PlanType.bundle) {
        _onBuyNewBundle();
      } else {
        _onNewDirectRequest();
      }
    });
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
            loading: () => const Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تحميل خطط التسعير...'),
              ],
            )),
            error: (err, stack) => _buildErrorWidget(
                'فشل في تحميل خطط التسعير', studentId, slotContext),
          ),
          loading: () => const Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري تحميل الباقة النشطة...'),
            ],
          )),
          error: (err, stack) => _buildErrorWidget(
              'فشل في تحميل الباقة النشطة', studentId, slotContext),
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
    final flow = ref.read(bookingFlowProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final activeProfile = ref.watch(activeStudentProfileProvider).valueOrNull;
    final role = currentUser == null ? '' : normalizeRole(currentUser.role);
    final learnerName = activeProfile?.name ??
        (role == roleParent ? null : currentUser?.name.trim());
    final needsChildSelection = role == roleParent && activeProfile == null;
    final studentCountry = PricingCountryUtils.inferUserCountry(
        ref.read(currentUserProvider).valueOrNull);
    final modePlans = plans
        .where((plan) =>
            plan.isActive &&
            PricingCountryUtils.matchesMode(
              plan,
              flow.slotContext?.sessionType,
            ))
        .toList();
    final visiblePlans =
        PricingCountryUtils.preferCountryPlans(modePlans, studentCountry.code);

    final hasBundlePlans =
        visiblePlans.any((plan) => plan.type == PlanType.bundle);
    final canBuyNewBundle = hasBundlePlans && activeBundle == null;

    final singleSessionPlans =
        visiblePlans.where((p) => p.type == PlanType.single).toList();
    final lowestPlan = singleSessionPlans.isEmpty
        ? null
        : singleSessionPlans.reduce(
            (a, b) => a.priceEGP < b.priceEGP ? a : b,
          );

    PricingPlanModel? selectedPlan;
    final selectedPlanId = flow.selectedPlanId;
    if (selectedPlanId != null && selectedPlanId.isNotEmpty) {
      for (final plan in visiblePlans) {
        if (plan.id == selectedPlanId) {
          selectedPlan = plan;
          break;
        }
      }
    }
    final selectedSinglePlan =
        selectedPlan?.type == PlanType.single ? selectedPlan : lowestPlan;

    if (selectedPlan != null && activeBundle == null && !needsChildSelection) {
      _continueWithSelectedPlan(selectedPlan);
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('جاري تجهيز ملخص الحجز...'),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (flow.slotContext != null) ...[
          _BookingSummaryBanner(
            slotContext: flow.slotContext!,
            learnerName: learnerName,
          ),
          const SizedBox(height: 12),
        ],
        if (needsChildSelection) ...[
          const _MissingLearnerCard(),
          const SizedBox(height: 16),
        ],
        _BookingOptionCard(
          icon: Icons.card_membership_rounded,
          backgroundColor: AppThemeConstants.successBackground,
          iconColor: AppThemeConstants.success,
          title: 'استخدام باقة حالية',
          subtitle: activeBundle != null
              ? 'متبقي ${activeBundle.remainingSessions} جلسة من ${activeBundle.totalSessions}'
              : 'لا توجد باقة نشطة لهذا النوع',
          hint: activeBundle == null ? 'اشترِ باقة أولاً' : null,
          isEnabled: activeBundle != null && !needsChildSelection,
          onTap: activeBundle != null && !needsChildSelection
              ? _onUseExistingBundle
              : null,
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
          isEnabled: canBuyNewBundle && !needsChildSelection,
          onTap:
              canBuyNewBundle && !needsChildSelection ? _onBuyNewBundle : null,
        ),
        const SizedBox(height: 16),

        // ── Option 3: Direct single-session request ─────────────────────
        _BookingOptionCard(
          icon: Icons.payment_rounded,
          backgroundColor: AppThemeConstants.surface,
          iconColor: AppThemeConstants.primary,
          borderColor: AppThemeConstants.primary,
          title: 'إرسال طلب حجز جديد',
          subtitle: selectedSinglePlan != null
              ? 'جلسة واحدة • ${PricingCountryUtils.displayPriceText(selectedSinglePlan)} • الدفع بعد القبول'
              : 'جلسة واحدة • الدفع بعد قبول المحفظ',
          isEnabled: !needsChildSelection,
          onTap: needsChildSelection ? null : _onNewDirectRequest,
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

  Widget _buildErrorWidget(
      String message, String? studentId, dynamic slotContext) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppThemeConstants.error),
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
                      ref.invalidate(
                          teacherPlansProvider(slotContext.mohaffezId));
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

class _BookingSummaryBanner extends StatelessWidget {
  const _BookingSummaryBanner({
    required this.slotContext,
    required this.learnerName,
  });

  final SlotContext slotContext;
  final String? learnerName;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(slotContext.slotDate);
    final dateLabel = date == null
        ? slotContext.slotDate
        : '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    final address = slotContext.imamAddressText?.trim();

    return Card(
      elevation: AppThemeConstants.elevationSm,
      color: AppThemeConstants.accentBackground,
      shape: RoundedRectangleBorder(
        borderRadius: AppThemeConstants.borderRadiusLg,
        side: BorderSide(
          color: AppThemeConstants.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.primary.withValues(alpha: 0.12),
                    borderRadius: AppThemeConstants.borderRadiusMd,
                  ),
                  child: const Icon(
                    Icons.fact_check_rounded,
                    color: AppThemeConstants.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'مراجعة طلب الحجز',
                    style: AppThemeConstants.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _BookingSummaryPill(
                  icon: Icons.child_care_rounded,
                  label: learnerName?.trim().isNotEmpty == true
                      ? learnerName!.trim()
                      : 'اختر الطالب',
                  isWarning: learnerName?.trim().isNotEmpty != true,
                ),
                _BookingSummaryPill(
                  icon: Icons.person_rounded,
                  label: slotContext.mohaffezName,
                ),
                _BookingSummaryPill(
                  icon: Icons.video_camera_back_rounded,
                  label: ArabicLabels.getSessionTypeLabel(
                    slotContext.sessionType,
                  ),
                ),
                _BookingSummaryPill(
                  icon: Icons.access_time_rounded,
                  label: formatTimeToArabicAmPm(slotContext.preferredTimeSlot),
                ),
                _BookingSummaryPill(
                  icon: Icons.calendar_today_rounded,
                  label: dateLabel,
                ),
                if (address != null && address.isNotEmpty)
                  _BookingSummaryPill(
                    icon: Icons.location_on_rounded,
                    label: address,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppThemeConstants.surface,
                borderRadius: AppThemeConstants.borderRadiusMd,
                border: Border.all(color: AppThemeConstants.outline),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppThemeConstants.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لن يتم طلب الدفع الآن. سيتم إرسال الطلب للمحفظ، وبعد القبول يمكنك إتمام الدفع ومتابعة حالة الحجز.',
                      style: AppThemeConstants.bodySmall.copyWith(
                        color: AppThemeConstants.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingLearnerCard extends StatelessWidget {
  const _MissingLearnerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeConstants.warningBackground,
        borderRadius: AppThemeConstants.borderRadiusLg,
        border: Border.all(color: AppThemeConstants.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.child_care_rounded,
                color: AppThemeConstants.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'اختر الابن قبل الحجز',
                  style: AppThemeConstants.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'هذا حساب ولي أمر. اختر الابن النشط حتى يظهر الطلب والجلسة والواجبات باسمه.',
            style: AppThemeConstants.bodySmall.copyWith(
              color: AppThemeConstants.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/student-profiles'),
              icon: const Icon(Icons.people_alt_rounded),
              label: const Text('اختيار أو إضافة ابن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeConstants.primary,
                foregroundColor: AppThemeConstants.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingSummaryPill extends StatelessWidget {
  const _BookingSummaryPill({
    required this.icon,
    required this.label,
    this.isWarning = false,
  });

  final IconData icon;
  final String label;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color =
        isWarning ? AppThemeConstants.warning : AppThemeConstants.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppThemeConstants.borderRadiusMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppThemeConstants.bodySmall.copyWith(
                color: AppThemeConstants.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                    color: (iconColor ?? AppThemeConstants.primary)
                        .withValues(alpha: 0.1),
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
