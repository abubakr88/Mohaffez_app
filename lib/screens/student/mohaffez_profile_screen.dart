// lib/screens/mohaffez_profile_screen.dart

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/widgets/skeleton_card.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../providers/mohaffez_profile_providers.dart';
import '../../providers/pricing_provider.dart';
import '../../providers/student_count_provider.dart';
import '../../models/pricing_plan_model.dart';
import '../../models/slot_context.dart';
import '../../providers/booking_flow_provider.dart';

class MohaffezProfileScreen extends ConsumerStatefulWidget {
  final String mohaffezId;
  final double? userLat;
  final double? userLng;

  const MohaffezProfileScreen({
    super.key,
    required this.mohaffezId,
    this.userLat,
    this.userLng,
  });

  @override
  ConsumerState<MohaffezProfileScreen> createState() =>
      _MohaffezProfileScreenState();
}

class _MohaffezProfileScreenState
    extends ConsumerState<MohaffezProfileScreen> {
  String selectedSessionType = 'home';
  Map<String, dynamic>? selectedTimeSlot;
  DateTime? selectedDate;
  int? selectedDayOfWeek;

  /// Helper to filter pricing plans by selected session type
  List<PricingPlanModel> _relevantPlans(List<PricingPlanModel> plans) {
    return plans.where((plan) {
      if (selectedSessionType == 'home') {
        return plan.mode == SessionMode.home;
      }
      if (selectedSessionType == 'mosque') {
        return plan.mode == SessionMode.mosque;
      }
      if (selectedSessionType == 'online') {
        return plan.mode == SessionMode.online;
      }
      return false;
    }).toList();
  }

  Future<void> _openYoutubeVideo(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح الرابط'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    }
  }

  // ─── Navigation helper ────────────────────────────────────────────────────

  void _navigateToBookingMethod() {
    if (selectedTimeSlot == null || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر موعداً من التقويم أولاً'),
          backgroundColor: AppThemeConstants.warning,
        ),
      );
      return;
    }
    final profileValue =
        ref.read(mohaffezProfileProvider(widget.mohaffezId)).value ?? {};
    final slotContext = _buildSlotContext(profileValue);
    ref.read(bookingFlowProvider.notifier).setSlotContext(slotContext);
    context.push('/booking/method');
  }

  // ─── SlotContext builder ──────────────────────────────────────────────────

  SlotContext _buildSlotContext(Map<String, dynamic>? profileValue) {
    final startRaw =
        selectedTimeSlot!['startTime'] as String? ?? '0:0';
    final endRaw =
        selectedTimeSlot!['endTime'] as String? ?? '0:0';

    final startParts = startRaw.split(':');
    final endParts = endRaw.split(':');

    final startHour =
        int.tryParse(startParts.elementAtOrNull(0) ?? '') ?? 0;
    final startMin =
        int.tryParse(startParts.elementAtOrNull(1) ?? '') ?? 0;
    final endHour =
        int.tryParse(endParts.elementAtOrNull(0) ?? '') ?? 0;
    final endMin =
        int.tryParse(endParts.elementAtOrNull(1) ?? '') ?? 0;

    final slotStart = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      startHour,
      startMin,
    );
    final slotEnd = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      endHour,
      endMin,
    );

    return SlotContext(
      mohaffezId: widget.mohaffezId,
      mohaffezName: profileValue?['name'] as String? ?? '',
      mohaffezPhone: profileValue?['phoneNumber'] as String?,
      sessionType: selectedSessionType,
      preferredTimeSlot: '$startRaw - $endRaw',
      slotDate: DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      ).toIso8601String(),
      slotStart: slotStart.toIso8601String(),
      slotEnd: slotEnd.toIso8601String(),
      imamAddressText: profileValue?['addressText'] as String?,
      // FIX Bug 2: Firestore stores coordinates as num, not double.
      // Direct cast 'as double?' throws TypeError at runtime.
      // Use (as num?)?.toDouble() which safely handles both int and double.
      imamAddressLat:
          (profileValue?['addressLat'] as num?)?.toDouble(),
      imamAddressLng:
          (profileValue?['addressLng'] as num?)?.toDouble(),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileAsync =
        ref.watch(mohaffezProfileProvider(widget.mohaffezId));
    final plansAsync =
        ref.watch(activePricingPlansProvider(widget.mohaffezId));

    // Auto-switch to the first session type that has a plan
    ref.listen(activePricingPlansProvider(widget.mohaffezId), (_, next) {
      next.whenData((plans) {
        if (!_hasPlanForType(plans, selectedSessionType)) {
          const order = ['home', 'mosque', 'online'];
          final first = order.firstWhere(
            (t) => _hasPlanForType(plans, t),
            orElse: () => selectedSessionType,
          );
          if (first != selectedSessionType && mounted) {
            setState(() {
              selectedSessionType = first;
              selectedTimeSlot = null;
              selectedDate = null;
              selectedDayOfWeek = null;
            });
          }
        }
      });
    });

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        body: profileAsync.when(
          data: (profile) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(mohaffezProfileProvider(widget.mohaffezId));
              ref.invalidate(activePricingPlansProvider(widget.mohaffezId));
              ref.invalidate(credentialsProvider(widget.mohaffezId));
              ref.invalidate(availabilityProvider(widget.mohaffezId));
              await ref
                  .read(mohaffezProfileProvider(widget.mohaffezId).future)
                  .catchError((_) => <String, dynamic>{});
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildAppBar(context, profile),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBasicInfo(ref, profile),
                      const SizedBox(height: 16),
                      _buildPricingPreviewBanner(plansAsync),
                      const SizedBox(height: 16),
                      if (profile['bio'] != null &&
                          (profile['bio'] as String).isNotEmpty)
                        _buildBioSection(profile['bio'] as String),
                      if (profile['youtubeVideoUrl'] != null &&
                          (profile['youtubeVideoUrl'] as String).isNotEmpty)
                        _buildYoutubeSection(
                          profile['youtubeVideoUrl'] as String,
                        ),
                      const SizedBox(height: 16),
                      _buildCredentialsSection(ref),
                      const SizedBox(height: 16),
                      _buildTrustBadgesSection(),
                      const SizedBox(height: 16),
                      _buildSessionTypeSelector(plansAsync),
                      const SizedBox(height: 16),
                      _buildPricingSection(plansAsync),
                      const SizedBox(height: 16),
                      _buildAvailabilitySection(ref, profile, plansAsync),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 64, color: AppThemeConstants.error),
                const SizedBox(height: 16),
                const Text(
                  'تعذر تحميل البيانات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يرجى التحقق من الاتصال بالإنترنت والمحاولة مرة أخرى',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppThemeConstants.grey500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    ref.invalidate(mohaffezProfileProvider(widget.mohaffezId));
                    ref.invalidate(activePricingPlansProvider(widget.mohaffezId));
                    ref.invalidate(credentialsProvider(widget.mohaffezId));
                    ref.invalidate(availabilityProvider(widget.mohaffezId));
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: selectedTimeSlot != null && selectedDate != null
              ? SafeArea(
                  key: const ValueKey('booking_bar'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppThemeConstants.white,
                        boxShadow: [
                          BoxShadow(
                            color: AppThemeConstants.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.secondary
                                  .withValues(alpha: 0.1),
                              borderRadius: AppThemeConstants.borderRadiusSm,
                              border: Border.all(
                                color: AppThemeConstants.secondary
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded,
                                        color: AppThemeConstants.secondary,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'التاريخ: ${DateFormat('EEEE، dd MMMM yyyy', 'ar').format(selectedDate!)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded,
                                        color: AppThemeConstants.secondary,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'الوقت: ${selectedTimeSlot!['startTime']} - ${selectedTimeSlot!['endTime']}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () {
                                        setState(() {
                                          selectedTimeSlot = null;
                                          selectedDate = null;
                                          selectedDayOfWeek = null;
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _navigateToBookingMethod,
                              icon: const Icon(Icons.send_rounded),
                              label: const Text(
                                'إرسال طلب الحجز',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppThemeConstants.primary,
                                foregroundColor: AppThemeConstants.white,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: AppThemeConstants.borderRadiusMd,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
              : const SizedBox.shrink(key: ValueKey('empty_bar')),
        ),
      ),
    );
  }

  // ─── Pricing preview banner ───────────────────────────────────────────────

  Widget _buildPricingPreviewBanner(
      AsyncValue<List<PricingPlanModel>> plansAsync) {
    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) return const SizedBox.shrink();

        final relevantPlans = _relevantPlans(plans);

        if (relevantPlans.isEmpty) return const SizedBox.shrink();

        final sortedPlans = List<PricingPlanModel>.from(relevantPlans)
          ..sort((a, b) => (a.priceEGP / a.sessionsCount)
              .compareTo(b.priceEGP / b.sessionsCount));

        final bestPlan = sortedPlans.first;
        final pricePerSession = bestPlan.priceEGP / bestPlan.sessionsCount;

        // Find the single session plan for this session type to calculate savings
        final singlePlan = relevantPlans
            .where((p) => p.type == PlanType.single)
            .fold<PricingPlanModel?>(null, (prev, curr) {
          if (prev == null) return curr;
          return curr.priceEGP < prev.priceEGP ? curr : prev;
        });

        final savings = (bestPlan.sessionsCount > 1 && singlePlan != null)
            ? ((singlePlan.priceEGP * bestPlan.sessionsCount) - bestPlan.priceEGP).toInt()
            : 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppThemeConstants.primary, AppThemeConstants.primaryVariant],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppThemeConstants.borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: AppThemeConstants.primary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الأسعار تبدأ من',
                        style: TextStyle(
                            color: AppThemeConstants.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pricePerSession.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(
                          color: AppThemeConstants.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const Text(
                        'لكل جلسة',
                        style: TextStyle(
                            color: AppThemeConstants.white70, fontSize: 14),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_offer,
                        color: AppThemeConstants.white, size: 40),
                  ),
                ],
              ),
              if (savings > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.savings,
                          color: AppThemeConstants.white, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'وفر حتى $savings ج.م مع الباقات',
                          style: const TextStyle(
                            color: AppThemeConstants.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 140,
        child: SkeletonCard(),
      ),
      error: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppThemeConstants.errorLight,
          borderRadius: AppThemeConstants.borderRadiusMd,
          border: Border.all(color: AppThemeConstants.accentRed),
        ),
        child: const Row(
          children: [
            Icon(Icons.error_outline, color: AppThemeConstants.error, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'تعذر تحميل الأسعار',
                style: TextStyle(fontSize: 14, color: AppThemeConstants.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Trust badges ─────────────────────────────────────────────────────────

  Widget _buildTrustBadgesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppThemeConstants.surfaceCream,
          borderRadius: AppThemeConstants.borderRadiusLg,
          border: Border.all(
            color: AppThemeConstants.secondary.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: AppThemeConstants.shadow.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppThemeConstants.secondary,
                        Color(0xFFE8C47A),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: AppThemeConstants.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ثقة وأمان في كل خطوة',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppThemeConstants.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'تفاصيل الدفع والاعتماد موضحة بوضوح قبل إرسال الطلب.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppThemeConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildTrustItem(
                    Icons.lock_rounded,
                    'دفع آمن',
                    'تشفير 256-bit',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTrustItem(
                    Icons.verified_user_rounded,
                    'مُعتمد',
                    'موثق ومضمون',
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1, color: AppThemeConstants.outline),
            ),
            const Text(
              'طرق الدفع المتاحة',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppThemeConstants.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildPaymentMethodBadge(Icons.credit_card_rounded, 'بطاقة'),
                _buildPaymentMethodBadge(
                  Icons.account_balance_wallet_rounded,
                  'محفظة',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppThemeConstants.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppThemeConstants.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppThemeConstants.secondary, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppThemeConstants.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppThemeConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppThemeConstants.secondary.withValues(alpha: 0.26),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppThemeConstants.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: AppThemeConstants.secondary, size: 16),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppThemeConstants.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pricing section ──────────────────────────────────────────────────────

  Widget _buildReadOnlyPlanCard(PricingPlanModel plan) {
    final isBundle =
        plan.type == PlanType.bundle || plan.type == PlanType.subscription;
    final badgeColor =
        isBundle ? AppThemeConstants.accentPurpleDark : AppThemeConstants.accentAmberDark;
    final badgeBg = isBundle ? AppThemeConstants.accentPurpleLight : AppThemeConstants.accentAmberLight;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeConstants.grey200),
        boxShadow: [
          BoxShadow(
              color: AppThemeConstants.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(isBundle ? 'باقة' : 'جلسة واحدة',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor)),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(plan.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold))),
            Text('${plan.priceEGP.toStringAsFixed(0)} جنيه',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppThemeConstants.success)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _profileChip(
                '${plan.sessionsCount} جلسة', Icons.event_available),
            if (plan.validityDays != null && plan.validityDays! > 0)
              _profileChip('${plan.validityDays} يوم', Icons.schedule),
            if (isBundle)
              _profileChip(
                '${(plan.priceEGP / plan.sessionsCount).toStringAsFixed(0)} جنيه/جلسة',
                Icons.payments_outlined,
              ),
          ]),
          if (plan.description != null && plan.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(plan.description!,
                style:
                    const TextStyle(fontSize: 12, color: AppThemeConstants.grey600)),
          ],
        ],
      ),
    );
  }

  Widget _profileChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppThemeConstants.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppThemeConstants.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppThemeConstants.secondary),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    AppThemeConstants.secondary.withValues(alpha: 0.9))),
      ]),
    );
  }

  Widget _buildPricingSection(
      AsyncValue<List<PricingPlanModel>> plansAsync) {
    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) return const SizedBox.shrink();

        final relevantPlans = _relevantPlans(plans);

        if (relevantPlans.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppThemeConstants.primary.withValues(alpha: 0.08),
                borderRadius: AppThemeConstants.borderRadiusMd,
                border: Border.all(
                    color: AppThemeConstants.primary
                        .withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppThemeConstants.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا توجد خطط تسعير متاحة لهذا النوع من الجلسات',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppThemeConstants.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'خطط التسعير المتاحة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              decoration: BoxDecoration(
                color: AppThemeConstants.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppThemeConstants.primary.withValues(alpha: 0.35)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppThemeConstants.primary),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                  'يمكنك التواصل مع المحفظ مباشرة للتفاوض على سعر مناسب',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppThemeConstants.primary),
                )),
              ]),
            ),
            const SizedBox(height: 14),
            ...relevantPlans.map((plan) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildReadOnlyPlanCard(plan),
                )),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'خطط التسعير المتاحة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: SkeletonList(itemCount: 3, itemHeight: 70),
            ),
          ],
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppThemeConstants.errorLight,
            borderRadius: AppThemeConstants.borderRadiusMd,
            border: Border.all(color: AppThemeConstants.accentRed),
          ),
          child: const Row(
            children: [
              Icon(Icons.error_outline, color: AppThemeConstants.error, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تعذر تحميل خطط التسعير',
                  style: TextStyle(fontSize: 14, color: AppThemeConstants.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(
      BuildContext context, Map<String, dynamic> profile) {
    final name = (profile['name'] as String?)?.trim().isNotEmpty == true
        ? profile['name'] as String
        : 'المحفّظ';
    final specialization = (profile['specialization'] as String?)
        ?.trim();
    final rating = (profile['rating'] as num?)?.toDouble() ?? 0;
    final reviewCount = profile['reviewCount'] as int? ?? 0;

    return SliverAppBar(
      expandedHeight: 248,
      pinned: true,
      backgroundColor: AppThemeConstants.deepTeal,
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppThemeConstants.primary, AppThemeConstants.primaryVariant],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -40,
              left: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppThemeConstants.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              right: -20,
              child: Transform.rotate(
                angle: -0.35,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    color: AppThemeConstants.secondary.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              left: 16,
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: [
                      AppThemeConstants.white.withValues(alpha: 0.16),
                      AppThemeConstants.white.withValues(alpha: 0.09),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  border: Border.all(
                    color: AppThemeConstants.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.secondary
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'ملف محفّظ معتمد',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppThemeConstants.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppThemeConstants.white,
                              height: 1.15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (specialization != null &&
                              specialization.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              specialization,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppThemeConstants.white70,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildHeroBadge(
                                Icons.star_rounded,
                                reviewCount > 0
                                    ? rating.toStringAsFixed(1)
                                    : 'جديد',
                              ),
                              _buildHeroBadge(
                                Icons.rate_review_rounded,
                                reviewCount > 0 ? '$reviewCount تقييم' : 'جديد',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemeConstants.white.withValues(alpha: 0.42),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppThemeConstants.black.withValues(alpha: 0.20),
                            blurRadius: 16,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: AppThemeConstants.white,
                        child: profile['photoUrl'] != null &&
                                (profile['photoUrl'] as String).isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: profile['photoUrl'],
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.person, size: 42),
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                size: 42,
                                color: AppThemeConstants.primary,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Basic info with statistics ───────────────────────────────────────────

  Widget _buildBasicInfo(WidgetRef ref, Map<String, dynamic> profile) {
    final rating = profile['rating'] as num? ?? 0.0;
    final reviewCount = profile['reviewCount'] as int? ?? 0;
    final ratingText = reviewCount > 0 ? rating.toStringAsFixed(1) : 'جديد';
    final statsAsync = ref.watch(mohaffezStatsProvider(widget.mohaffezId));
    final studentCountAsync = ref.watch(mohaffezStudentCountProvider(widget.mohaffezId));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: statsAsync.when(
        data: (stats) {
          final completedSessions = stats['completedSessions'] as int? ?? 0;
          final studentCount = studentCountAsync.when(
            data: (count) => count,
            loading: () => 0,
            error: (_, __) => 0,
          );

          debugPrint('👨‍🏫 Student count from Cloud Function: $studentCount');

          return _buildStatsCard(
            stats: [
              _buildStatItem(
                icon: Icons.star_rounded,
                value: ratingText,
                label: 'التقييم',
                color: AppThemeConstants.accentAmber,
              ),
              _buildStatItem(
                icon: Icons.check_circle_rounded,
                value: '$completedSessions',
                label: 'جلسة منجزة',
                color: AppThemeConstants.success,
              ),
              _buildStatItem(
                icon: Icons.school_rounded,
                value: '$studentCount',
                label: 'طالب',
                color: AppThemeConstants.secondary,
              ),
            ],
          );
        },
        loading: () => _buildStatsCard(
          stats: [
            _buildStatItem(
              icon: Icons.star_rounded,
              value: ratingText,
              label: 'التقييم',
              color: AppThemeConstants.accentAmber,
            ),
            _buildStatItem(
              icon: Icons.check_circle_rounded,
              value: '...',
              label: 'جلسة منجزة',
              color: AppThemeConstants.success,
            ),
            _buildStatItem(
              icon: Icons.school_rounded,
              value: '...',
              label: 'طالب',
              color: AppThemeConstants.secondary,
            ),
          ],
        ),
        error: (_, __) => _buildStatsCard(
          stats: [
            _buildStatItem(
              icon: Icons.star_rounded,
              value: ratingText,
              label: 'التقييم',
              color: AppThemeConstants.accentAmber,
            ),
            _buildStatItem(
              icon: Icons.check_circle_rounded,
              value: '-',
              label: 'جلسة منجزة',
              color: AppThemeConstants.success,
            ),
            _buildStatItem(
              icon: Icons.school_rounded,
              value: '-',
              label: 'طالب',
              color: AppThemeConstants.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard({required List<Widget> stats}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppThemeConstants.white),
        boxShadow: [
          BoxShadow(
            color: AppThemeConstants.shadow.withValues(alpha: 0.09),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'لمحة سريعة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppThemeConstants.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'مؤشرات تساعدك على تقييم الملف بسرعة قبل الحجز.',
            style: TextStyle(
              fontSize: 13,
              color: AppThemeConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(stats.length, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i < stats.length - 1 ? 8 : 0),
                child: stats[i],
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppThemeConstants.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppThemeConstants.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppThemeConstants.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bio ──────────────────────────────────────────────────────────────────

  Widget _buildBioSection(String bio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نبذة تعريفية',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeConstants.grey50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeConstants.grey200),
            ),
            child: Text(
              bio,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Credentials ──────────────────────────────────────────────────────────

  Widget _buildYoutubeSection(String youtubeUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'فيديو تلاوة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _openYoutubeVideo(youtubeUrl),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF7F1D1D),
                    AppThemeConstants.error,
                    Color(0xFFB91C1C),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeConstants.error.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x1FFFFFFF),
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: AppThemeConstants.white,
                        size: 34,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'استمع إلى تلاوة تعريفية',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppThemeConstants.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'استعراض سريع للصوت وأسلوب التلاوة قبل اتخاذ القرار.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppThemeConstants.white70,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_new_rounded,
                    color: AppThemeConstants.white70,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsSection(WidgetRef ref) {
    final credentials = ref.watch(credentialsProvider(widget.mohaffezId));
    return credentials.when(
      data: (creds) {
        if (creds.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'الشهادات والمؤهلات',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 176,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: creds.length,
                itemBuilder: (context, index) {
                  final cred = creds[index];
                  return Container(
                    width: 250,
                    margin: const EdgeInsetsDirectional.only(end: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFCFBFF),
                          AppThemeConstants.accentPurpleLight,
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppThemeConstants.accentPurple.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppThemeConstants.accentPurple.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppThemeConstants.accentPurple.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                color: AppThemeConstants.accentPurple,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cred['title'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppThemeConstants.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeConstants.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.business_rounded,
                                size: 16,
                                color: AppThemeConstants.grey600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cred['organization'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: AppThemeConstants.grey700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeConstants.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AppThemeConstants.success,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'معتمدة',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppThemeConstants.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 280,
        child: SkeletonList(itemCount: 3, itemHeight: 84),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppThemeConstants.errorLight,
            borderRadius: AppThemeConstants.borderRadiusMd,
            border: Border.all(color: AppThemeConstants.accentRed),
          ),
          child: const Row(
            children: [
              Icon(Icons.error_outline, color: AppThemeConstants.error, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تعذر تحميل الشهادات والمؤهلات',
                  style: TextStyle(fontSize: 14, color: AppThemeConstants.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppThemeConstants.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppThemeConstants.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppThemeConstants.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppThemeConstants.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Session type selector ────────────────────────────────────────────────

  bool _hasPlanForType(List<PricingPlanModel> plans, String type) {
    return plans.any((p) {
      if (type == 'home') return p.mode == SessionMode.home;
      if (type == 'mosque') return p.mode == SessionMode.mosque;
      if (type == 'online') return p.mode == SessionMode.online;
      return false;
    });
  }

  Widget _buildSessionTypeSelector(
      AsyncValue<List<PricingPlanModel>> plansAsync) {
    final plans = plansAsync.valueOrNull ?? [];

    final homeHasPlan = _hasPlanForType(plans, 'home');
    final mosqueHasPlan = _hasPlanForType(plans, 'mosque');
    final onlineHasPlan = _hasPlanForType(plans, 'online');
    final anyMissing = !homeHasPlan || !mosqueHasPlan || !onlineHasPlan;

    Widget chip({
      required String type,
      required String label,
      required IconData icon,
      required Color activeColor,
      required bool hasPlan,
    }) {
      final isSelected = selectedSessionType == type && hasPlan;
      return GestureDetector(
        onTap: hasPlan
            ? null
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('لم يحدد المحفظ خطة سعر لهذا النوع من الجلسات'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: hasPlan
                ? (isSelected ? activeColor : AppThemeConstants.white)
                : AppThemeConstants.grey100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasPlan
                  ? (isSelected
                      ? activeColor
                      : AppThemeConstants.outline)
                  : AppThemeConstants.grey300,
              width: isSelected ? 2 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: hasPlan
                ? () {
                    final hadSelectedSlot = selectedTimeSlot != null;
                    setState(() {
                      selectedSessionType = type;
                      selectedTimeSlot = null;
                      selectedDate = null;
                      selectedDayOfWeek = null;
                    });
                    if (hadSelectedSlot && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم مسح الموعد المختار'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasPlan ? icon : Icons.lock_outline_rounded,
                  size: 18,
                  color: hasPlan
                      ? (isSelected
                          ? AppThemeConstants.textPrimary
                          : AppThemeConstants.textSecondary)
                      : AppThemeConstants.grey400,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: hasPlan
                        ? (isSelected
                            ? AppThemeConstants.textPrimary
                            : AppThemeConstants.textSecondary)
                        : AppThemeConstants.grey400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نوع الجلسة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(
                type: 'home',
                label: 'بيت الطالب',
                icon: Icons.home_rounded,
                activeColor:
                    AppThemeConstants.primary.withValues(alpha: 0.18),
                hasPlan: homeHasPlan,
              ),
              chip(
                type: 'mosque',
                label: 'المسجد',
                icon: Icons.mosque_rounded,
                activeColor:
                    AppThemeConstants.secondary.withValues(alpha: 0.18),
                hasPlan: mosqueHasPlan,
              ),
              chip(
                type: 'online',
                label: 'أونلاين',
                icon: Icons.videocam_rounded,
                activeColor: AppThemeConstants.accentBlue.withValues(alpha: 0.18),
                hasPlan: onlineHasPlan,
              ),
            ],
          ),
          if (anyMissing && plansAsync.hasValue) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 13, color: AppThemeConstants.grey500),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'الأنواع المقفلة: لم يحدد المحفظ خطة سعر لها بعد',
                    style: TextStyle(
                        fontSize: 11, color: AppThemeConstants.grey500),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Availability section ─────────────────────────────────────────────────

  Widget _buildAvailabilitySection(WidgetRef ref,
      Map<String, dynamic> profile,
      AsyncValue<List<PricingPlanModel>> plansAsync) {
    final plans = plansAsync.valueOrNull ?? [];
    final currentTypeHasPlan = plansAsync.hasValue
        ? _hasPlanForType(plans, selectedSessionType)
        : true;

    if (!currentTypeHasPlan) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppThemeConstants.grey50,
            borderRadius: AppThemeConstants.borderRadiusMd,
            border: Border.all(color: AppThemeConstants.grey300),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  color: AppThemeConstants.grey400, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'اختر نوع جلسة متاح أولاً لعرض المواعيد',
                  style: TextStyle(fontSize: 14, color: AppThemeConstants.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final availability = ref.watch(availabilityProvider(widget.mohaffezId));
    return availability.when(
      data: (slots) {
            if (slots.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.grey50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppThemeConstants.grey200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: AppThemeConstants.grey400, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'لا توجد أوقات متاحة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15, color: AppThemeConstants.grey600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            const arabicDays = [
              'الإثنين',
              'الثلاثاء',
              'الأربعاء',
              'الخميس',
              'الجمعة',
              'السبت',
              'الأحد',
            ];

            // Pre-filter all slots to check if any exist for selected session type
            final hasAnyFilteredSlots = slots.any((slot) {
              final timeSlots = List<Map<String, dynamic>>.from(slot['timeSlots'] ?? []);
              return timeSlots.any((ts) =>
                  ts['enabled'] == true && ts['sessionType'] == selectedSessionType);
            });

            if (!hasAnyFilteredSlots) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.warningLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppThemeConstants.accentOrange),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppThemeConstants.accentOrange, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'لا توجد أوقات متاحة لهذا النوع من الجلسات',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15, color: AppThemeConstants.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'الأوقات المتاحة - اختر الوقت المناسب',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                ...(() {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final currentDayOfWeek = today.weekday;
                  final sorted = [...slots]..sort((a, b) {
                      int dA = ((a['dayOfWeek'] as int) - currentDayOfWeek + 7) % 7;
                      int dB = ((b['dayOfWeek'] as int) - currentDayOfWeek + 7) % 7;
                      return dA.compareTo(dB);
                    });
                  return sorted;
                }()).expand((slot) {
                  final dayOfWeek = slot['dayOfWeek'] as int;
                  final timeSlots =
                      List<Map<String, dynamic>>.from(
                          slot['timeSlots'] ?? []);

                  final now = DateTime.now();
                  final today =
                      DateTime(now.year, now.month, now.day);
                  final currentDayOfWeek = today.weekday;

                  int baseDaysUntil = dayOfWeek - currentDayOfWeek;
                  if (baseDaysUntil < 0) baseDaysUntil += 7;

                  // Show only the next occurrence of this weekday (within 7 days)
                  return List.generate(1, (weekIndex) {
                    final daysUntil = baseDaysUntil + (weekIndex * 7);
                    final targetDate = DateTime(
                      today.year,
                      today.month,
                      today.day + daysUntil,
                    );
                    final isToday = daysUntil == 0;

                    final enabledSlots = timeSlots.where((ts) {
                      if (ts['enabled'] != true) return false;
                      if (ts['sessionType'] != selectedSessionType) {
                        return false;
                      }
                      if (isToday) {
                        final parts =
                            (ts['startTime'] as String? ?? '0:0').split(':');
                        final hour =
                            int.tryParse(parts.elementAtOrNull(0) ?? '') ?? 0;
                        final minute =
                            int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0;
                        final slotTime = DateTime(
                          today.year,
                          today.month,
                          today.day,
                          hour,
                          minute,
                        );
                        return slotTime.isAfter(now);
                      }
                      return true;
                    }).toList();

                    if (enabledSlots.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 18,
                                  color: AppThemeConstants.secondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${arabicDays[dayOfWeek - 1]} - ${DateFormat('dd/MM', 'ar').format(targetDate)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isToday)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppThemeConstants.secondary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'اليوم',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppThemeConstants.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: enabledSlots.map((ts) {
                              final isSelected =
                                  selectedTimeSlot == ts &&
                                      selectedDayOfWeek == dayOfWeek &&
                                      selectedDate == targetDate;
                              return Semantics(
                                button: true,
                                selected: isSelected,
                                label: 'وقت ${ts['startTime']} إلى ${ts['endTime']}',
                                hint: isSelected ? 'تم اختيار هذا الوقت' : 'اختر هذا الوقت',
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedTimeSlot = ts;
                                      selectedDate = targetDate;
                                      selectedDayOfWeek = dayOfWeek;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 48,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppThemeConstants.secondary
                                          : AppThemeConstants.successLight,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppThemeConstants.secondary
                                            : AppThemeConstants.accentGreenAlt,
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: isSelected
                                              ? AppThemeConstants.white
                                              : AppThemeConstants.success,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${ts['startTime']} - ${ts['endTime']}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? AppThemeConstants.white
                                                : AppThemeConstants.success,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.check_circle,
                                              size: 16, color: AppThemeConstants.white),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    );
                  });
                }),
              ],
            );
          },
      loading: () => const SizedBox(
            height: 320,
            child: SkeletonList(itemCount: 4, itemHeight: 70),
          ),
      error: (_, __) => const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'خطأ في تحميل الأوقات المتاحة',
              style: TextStyle(color: AppThemeConstants.error),
            ),
          ),
        );
  }
}
