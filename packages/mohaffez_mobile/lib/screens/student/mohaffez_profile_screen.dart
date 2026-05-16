// lib/screens/mohaffez_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/widgets/skeleton_card.dart';
import '../../shared/utils/time_formatter.dart';
import '../../providers/mohaffez_profile_providers.dart';
import '../../providers/student_count_provider.dart';
import '../../tour/tour_guard_helper.dart';

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

class _MohaffezProfileScreenState extends ConsumerState<MohaffezProfileScreen> {
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
    if (guardWriteInTour(ref, context)) return;
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
    final startRaw = selectedTimeSlot!['startTime'] as String? ?? '0:0';
    final endRaw = selectedTimeSlot!['endTime'] as String? ?? '0:0';

    final startParts = startRaw.split(':');
    final endParts = endRaw.split(':');

    final startHour = int.tryParse(startParts.elementAtOrNull(0) ?? '') ?? 0;
    final startMin = int.tryParse(startParts.elementAtOrNull(1) ?? '') ?? 0;
    final endHour = int.tryParse(endParts.elementAtOrNull(0) ?? '') ?? 0;
    final endMin = int.tryParse(endParts.elementAtOrNull(1) ?? '') ?? 0;

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
      slotDate: DateTime.utc(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      ).toIso8601String(),
      slotStart: slotStart.toUtc().toIso8601String(),
      slotEnd: slotEnd.toUtc().toIso8601String(),
      imamAddressText: profileValue?['addressText'] as String?,
      // FIX Bug 2: Firestore stores coordinates as num, not double.
      // Direct cast 'as double?' throws TypeError at runtime.
      // Use (as num?)?.toDouble() which safely handles both int and double.
      imamAddressLat: (profileValue?['addressLat'] as num?)?.toDouble(),
      imamAddressLng: (profileValue?['addressLng'] as num?)?.toDouble(),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(mohaffezProfileProvider(widget.mohaffezId));
    final plansAsync = ref.watch(activePricingPlansProvider(widget.mohaffezId));

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
                      const SizedBox(height: 16),
                      _buildCompactTrustStrip(ref, profile),
                      const SizedBox(height: 18),
                      _buildModernSessionSelector(plansAsync),
                      const SizedBox(height: 20),
                      _buildModernAvailabilitySection(ref, profile, plansAsync),
                      const SizedBox(height: 20),
                      _buildModernPricingSection(plansAsync),
                      const SizedBox(height: 20),
                      if (profile['bio'] != null &&
                          (profile['bio'] as String).isNotEmpty)
                        _buildModernBioSection(profile['bio'] as String),
                      const SizedBox(height: 20),
                      _buildCompactCredentialsSection(ref),
                      const SizedBox(height: 20),
                      if (profile['youtubeVideoUrl'] != null &&
                          (profile['youtubeVideoUrl'] as String).isNotEmpty)
                        _buildPremiumYoutubeSection(
                          profile['youtubeVideoUrl'] as String,
                        ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
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
                    ref.invalidate(
                        activePricingPlansProvider(widget.mohaffezId));
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
        bottomNavigationBar: selectedTimeSlot != null && selectedDate != null
            ? SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedDate != null
                                  ? DateFormat(
                                      'EEEE، d MMM',
                                      'ar',
                                    ).format(selectedDate!)
                                  : '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatTimeToArabicAmPm(
                                selectedTimeSlot!['startTime'],
                              ),
                              style: const TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _navigateToBookingMethod,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D9E75),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'تأكيد الحجز',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
  // ─── Pricing section ──────────────────────────────────────────────────────

  Widget _buildReadOnlyPlanCard(PricingPlanModel plan) {
    final isBundle =
        plan.type == PlanType.bundle || plan.type == PlanType.subscription;
    final badgeColor = isBundle
        ? AppThemeConstants.accentPurpleDark
        : AppThemeConstants.accentAmberDark;
    final badgeBg = isBundle
        ? AppThemeConstants.accentPurpleLight
        : AppThemeConstants.accentAmberLight;
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: badgeBg, borderRadius: BorderRadius.circular(20)),
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
            _profileChip('${plan.sessionsCount} جلسة', Icons.event_available),
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
                style: const TextStyle(
                    fontSize: 12, color: AppThemeConstants.grey600)),
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
                color: AppThemeConstants.secondary.withValues(alpha: 0.9))),
      ]),
    );
  }

  Widget _buildModernPricingSection(AsyncValue<List<PricingPlanModel>> plansAsync) {
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
                    color: AppThemeConstants.primary.withValues(alpha: 0.4)),
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
              Icon(Icons.error_outline,
                  color: AppThemeConstants.error, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تعذر تحميل خطط التسعير',
                  style:
                      TextStyle(fontSize: 14, color: AppThemeConstants.error),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Compact Trust Strip ───────────────────────────────────────────────────

  Widget _buildCompactTrustStrip(
    WidgetRef ref,
    Map<String, dynamic> profile,
  ) {
    final rating = profile['rating'] as num? ?? 0.0;
    final studentCountAsync =
        ref.watch(mohaffezStudentCountProvider(widget.mohaffezId));

    final studentCount = studentCountAsync.when(
      data: (count) => count,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _miniTrust(Icons.star_rounded, rating.toStringAsFixed(1), 'التقييم'),
            _miniTrust(Icons.people_alt_rounded, '$studentCount+', 'طالب'),
            _miniTrust(Icons.workspace_premium_rounded, 'إجازة', 'معتمد'),
            _miniTrust(Icons.access_time_filled_rounded, '10 د', 'الرد'),
          ],
        ),
      ),
    );
  }

  Widget _miniTrust(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF1D9E75), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, Map<String, dynamic> profile) {
    final name = (profile['name'] as String?)?.trim().isNotEmpty == true
        ? profile['name'] as String
        : 'المحفّظ';
    final specialization = (profile['specialization'] as String?)?.trim();
    final rating = (profile['rating'] as num?)?.toDouble() ?? 0;
    final reviewCount = profile['reviewCount'] as int? ?? 0;

    return SliverAppBar(
      expandedHeight: 248,
      pinned: true,
      automaticallyImplyLeading: false,
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
                  colors: [
                    AppThemeConstants.primary,
                    AppThemeConstants.primaryVariant
                  ],
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
                          color:
                              AppThemeConstants.white.withValues(alpha: 0.42),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppThemeConstants.black.withValues(alpha: 0.20),
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

  // ─── Modern Bio Section ───────────────────────────────────────────────────

  Widget _buildModernBioSection(String bio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نبذة عن المحفظ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              bio,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Compact Credentials Section ──────────────────────────────────────────

  Widget _buildCompactCredentialsSection(WidgetRef ref) {
    final credsAsync = ref.watch(credentialsProvider(widget.mohaffezId));

    return credsAsync.when(
      data: (creds) {
        if (creds.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الإجازات والشهادات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: creds.map((cred) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFFE8A020),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            cred['title'] ?? 'إجازة',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 120,
          child: SkeletonCard(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── Premium YouTube Section ──────────────────────────────────────────────

  Widget _buildPremiumYoutubeSection(String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF085041),
              Color(0xFF1D9E75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D9E75).withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'شاهد فيديو تعريفي',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'تعرف على أسلوب المحفظ في التدريس',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _openYoutubeVideo(url),
                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                label: const Text(
                  'مشاهدة الفيديو',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1D9E75),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildModernSessionSelector(
    AsyncValue<List<PricingPlanModel>> plansAsync,
  ) {
    final plans = plansAsync.valueOrNull ?? [];

    Widget item({
      required String type,
      required String title,
      required IconData icon,
    }) {
      final hasPlan = _hasPlanForType(plans, type);
      final selected = selectedSessionType == type;

      return Expanded(
        child: GestureDetector(
          onTap: hasPlan
              ? () {
                  final hadSelectedSlot = selectedTimeSlot != null;
                  setState(() {
                    selectedSessionType = type;
                    selectedTimeSlot = null;
                    selectedDate = null;
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
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: hasPlan && selected
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF1D9E75),
                        Color(0xFF085041),
                      ],
                    )
                  : null,
              color: hasPlan && selected ? null : Colors.white,
              border: Border.all(
                color: hasPlan
                    ? (selected
                        ? Colors.transparent
                        : const Color(0xFFE5E7EB))
                    : Colors.grey.withValues(alpha: 0.3),
              ),
              boxShadow: hasPlan && selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1D9E75).withValues(alpha: 0.24),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      )
                    ]
                  : [],
            ),
            child: Column(
              children: [
                Icon(
                  hasPlan ? icon : Icons.lock_outline_rounded,
                  color: hasPlan && selected
                      ? Colors.white
                      : (hasPlan ? const Color(0xFF1D9E75) : Colors.grey),
                  size: 26,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: hasPlan && selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
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
      child: Row(
        children: [
          item(
            type: 'online',
            title: 'أونلاين',
            icon: Icons.videocam_rounded,
          ),
          item(
            type: 'mosque',
            title: 'في المسجد',
            icon: Icons.mosque_rounded,
          ),
          item(
            type: 'home',
            title: 'زيارة منزلية',
            icon: Icons.home_rounded,
          ),
        ],
      ),
    );
  }

  // ─── Modern Availability/Booking Section ───────────────────────────────────

  Widget _buildModernAvailabilitySection(
    WidgetRef ref,
    Map<String, dynamic> profile,
    AsyncValue<List<PricingPlanModel>> plansAsync,
  ) {
    final availability = ref.watch(
      availabilityProvider(widget.mohaffezId),
    );

    return availability.when(
      data: (slots) {
        if (slots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: Colors.grey, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا توجد أوقات متاحة',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Pre-filter all slots to check if any exist for selected session type
        final hasAnyFilteredSlots = slots.any((slot) {
          final timeSlots =
              List<Map<String, dynamic>>.from(slot['timeSlots'] ?? []);
          return timeSlots.any((ts) =>
              ts['enabled'] == true &&
              ts['sessionType'] == selectedSessionType);
        });

        if (!hasAnyFilteredSlots) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.orange, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا توجد أوقات متاحة لهذا النوع من الجلسات',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'احجز جلستك',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اختر اليوم والوقت المناسب لك',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),

                // Compact horizontal date strip + time slots
                ...(() {
                  const arabicDays = [
                    'الإثنين',
                    'الثلاثاء',
                    'الأربعاء',
                    'الخميس',
                    'الجمعة',
                    'السبت',
                    'الأحد',
                  ];

                  final now = serverNow(ref);
                  final today = DateTime(now.year, now.month, now.day);
                  final currentDayOfWeek = today.weekday;

                  final sortedSlots = [...slots]..sort((a, b) {
                    int dA = ((a['dayOfWeek'] as int) - currentDayOfWeek + 7) % 7;
                    int dB = ((b['dayOfWeek'] as int) - currentDayOfWeek + 7) % 7;
                    return dA.compareTo(dB);
                  });

                  // Build (date, enabledSlots) for each available day
                  final availableDays =
                      <({DateTime date, List<Map<String, dynamic>> slots})>[];

                  for (final slot in sortedSlots) {
                    final dayOfWeek = slot['dayOfWeek'] as int;
                    final timeSlots = List<Map<String, dynamic>>.from(
                        slot['timeSlots'] ?? []);
                    int daysUntil = dayOfWeek - currentDayOfWeek;
                    if (daysUntil < 0) daysUntil += 7;
                    final targetDate = DateTime(
                        today.year, today.month, today.day + daysUntil);
                    final isToday = daysUntil == 0;

                    final enabled = timeSlots.where((ts) {
                      if (ts['enabled'] != true) return false;
                      if (ts['sessionType'] != selectedSessionType) return false;
                      if (isToday) {
                        final parts =
                            (ts['startTime'] as String? ?? '0:0').split(':');
                        final hour =
                            int.tryParse(parts.elementAtOrNull(0) ?? '') ?? 0;
                        final minute =
                            int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0;
                        return DateTime(today.year, today.month, today.day,
                                hour, minute)
                            .isAfter(now);
                      }
                      return true;
                    }).toList();

                    if (enabled.isNotEmpty) {
                      availableDays.add((date: targetDate, slots: enabled));
                    }
                  }

                  if (availableDays.isEmpty) return <Widget>[];

                  // Which day is currently highlighted in the strip
                  final effectiveDate = (selectedDate != null &&
                          availableDays
                              .any((d) => d.date.day == selectedDate!.day &&
                                  d.date.month == selectedDate!.month))
                      ? selectedDate!
                      : availableDays.first.date;

                  final activeSlots = availableDays
                      .firstWhere(
                        (d) =>
                            d.date.day == effectiveDate.day &&
                            d.date.month == effectiveDate.month,
                        orElse: () => availableDays.first,
                      )
                      .slots;

                  String dayChipLabel(DateTime date) {
                    final diff = date.difference(today).inDays;
                    if (diff == 0) return 'اليوم';
                    if (diff == 1) return 'غداً';
                    return arabicDays[date.weekday - 1];
                  }

                  return [
                    // ── Horizontal date strip ──
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        itemCount: availableDays.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final day = availableDays[i];
                          final isSelected =
                              day.date.day == effectiveDate.day &&
                                  day.date.month == effectiveDate.month;
                          return GestureDetector(
                            onTap: () => setState(() {
                              selectedDate = day.date;
                              selectedTimeSlot = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppThemeConstants.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : const Color(0xFFE5E7EB),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppThemeConstants.primary
                                              .withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    dayChipLabel(day.date),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    DateFormat('dd/MM', 'ar')
                                        .format(day.date),
                                    style: TextStyle(
                                      fontSize: 11,
                                       color: isSelected
                                          ? Colors.white
                                              .withValues(alpha: 0.75)
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Time slots for the selected day ──
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: activeSlots.map((ts) {
                        final startTime = ts['startTime'] as String?;
                        final endTime = ts['endTime'] as String?;
                        final timeText = formatTimeToArabicAmPm(
                            '$startTime - $endTime');
                        final isSelected = selectedTimeSlot != null &&
                            selectedTimeSlot!['startTime'] == startTime &&
                            selectedTimeSlot!['endTime'] == endTime &&
                            selectedDate?.day == effectiveDate.day &&
                            selectedDate?.month == effectiveDate.month;

                        return GestureDetector(
                          onTap: () => setState(() {
                            selectedTimeSlot = {
                              'startTime': startTime,
                              'endTime': endTime,
                            };
                            selectedDate = effectiveDate;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppThemeConstants.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : const Color(0xFFE5E7EB),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppThemeConstants.primary
                                            .withValues(alpha: 0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                timeText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ];
                }()),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

}
