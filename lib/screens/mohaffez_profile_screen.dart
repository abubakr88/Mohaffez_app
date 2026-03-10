// lib/screens/mohaffez_profile_screen.dart

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/skeleton_card.dart';
import '../shared/theme/app_theme_constants.dart';
import '../providers/mohaffez_profile_providers.dart';
import '../providers/user_provider.dart';
import '../providers/pricing_provider.dart';
import '../models/pricing_plan_model.dart';
import '../models/slot_context.dart';
import '../providers/booking_flow_provider.dart';

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

  // ─── Navigation helper ────────────────────────────────────────────────────

  /// Validates slot selection, builds SlotContext, and navigates to the
  /// booking method screen. Used by all three entry points on this page.
  void _navigateToBookingMethod() {
    if (selectedTimeSlot == null || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر موعداً من التقويم أولاً'),
          backgroundColor: Colors.orange,
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

  /// Safely parses HH:mm time strings and builds a [SlotContext].
  /// Uses [int.tryParse] with fallback to 0 to avoid RangeError on
  /// malformed or missing time data.
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
      imamAddressLat: profileValue?['addressLat'] as double?,
      imamAddressLng: profileValue?['addressLng'] as double?,
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileAsync =
        ref.watch(mohaffezProfileProvider(widget.mohaffezId));
    final plansAsync =
        ref.watch(activePricingPlansProvider(widget.mohaffezId));

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        body: profileAsync.when(
          data: (profile) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(mohaffezProfileProvider(widget.mohaffezId));
              await ref
                  .read(mohaffezProfileProvider(widget.mohaffezId).future)
                  .catchError((_) => <String, dynamic>{});
            },
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context, profile),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBasicInfo(profile),
                      const SizedBox(height: 16),
                      _buildPricingPreviewBanner(plansAsync),
                      const SizedBox(height: 16),
                      if (profile['bio'] != null &&
                          (profile['bio'] as String).isNotEmpty)
                        _buildBioSection(profile['bio'] as String),
                      const SizedBox(height: 16),
                      _buildCredentialsSection(ref),
                      const SizedBox(height: 16),
                      _buildTrustBadgesSection(),
                      const SizedBox(height: 16),
                      _buildSessionTypeSelector(),
                      const SizedBox(height: 16),
                      _buildPricingSection(plansAsync),
                      const SizedBox(height: 16),
                      _buildAvailabilitySection(ref, profile),
                      const SizedBox(height: 24),
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
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('خطأ في تحميل البيانات: $e'),
              ],
            ),
          ),
        ),
        bottomNavigationBar: selectedTimeSlot != null && selectedDate != null
            ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Selected booking summary
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                AppTheme.accentGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    color: AppTheme.accentGreen, size: 20),
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
                                const Icon(Icons.access_time,
                                    color: AppTheme.accentGreen, size: 20),
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
                                  icon: const Icon(Icons.close, size: 20),
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
                          icon: const Icon(Icons.send),
                          label: const Text(
                            'إرسال طلب الحجز',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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

  // ─── Pricing preview banner ───────────────────────────────────────────────

  Widget _buildPricingPreviewBanner(
      AsyncValue<List<PricingPlanModel>> plansAsync) {
    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) return const SizedBox.shrink();

        final relevantPlans = plans.where((plan) {
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

        if (relevantPlans.isEmpty) return const SizedBox.shrink();

        final sortedPlans = List<PricingPlanModel>.from(relevantPlans)
          ..sort((a, b) => (a.priceEGP / a.sessionsCount)
              .compareTo(b.priceEGP / b.sessionsCount));

        final bestPlan = sortedPlans.first;
        final pricePerSession = bestPlan.priceEGP / bestPlan.sessionsCount;
        final savings = bestPlan.sessionsCount > 1
            ? ((50 * bestPlan.sessionsCount) - bestPlan.priceEGP).toInt()
            : 0;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryAmber.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pricePerSession.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const Text(
                        'لكل جلسة',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_offer,
                        color: Colors.white, size: 40),
                  ),
                ],
              ),
              if (savings > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.savings,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'وفر حتى $savings ج.م مع الباقات',
                          style: const TextStyle(
                            color: Colors.white,
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
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── Trust badges ─────────────────────────────────────────────────────────

  Widget _buildTrustBadgesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppThemeConstants.accentGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppThemeConstants.accentGreen.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTrustItem(Icons.lock, 'دفع آمن', 'تشفير 256-bit'),
                _buildTrustItem(
                    Icons.verified_user, 'معتمد', 'موثق ومضمون'),
                _buildTrustItem(Icons.replay, 'استرجاع', 'خلال ساعتين'),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'طرق الدفع المتاحة',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPaymentMethodBadge(Icons.credit_card, 'بطاقة'),
                const SizedBox(width: 12),
                _buildPaymentMethodBadge(
                    Icons.account_balance_wallet, 'محفظة'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, color: AppThemeConstants.accentGreen, size: 28),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppThemeConstants.accentGreen,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppThemeConstants.primaryAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppThemeConstants.primaryAmber, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppThemeConstants.primaryAmber,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pricing section ──────────────────────────────────────────────────────

  Widget _buildPricingSection(
      AsyncValue<List<PricingPlanModel>> plansAsync) {
    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) return const SizedBox.shrink();

        final relevantPlans = plans.where((plan) {
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

        if (relevantPlans.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    AppThemeConstants.primaryAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppThemeConstants.primaryAmber
                        .withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppThemeConstants.primaryAmber),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا توجد خطط تسعير متاحة لهذا النوع من الجلسات',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppThemeConstants.primaryAmber,
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
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: relevantPlans.length,
                itemBuilder: (context, index) {
                  return _buildPricingCard(relevantPlans[index]);
                },
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: const SizedBox.shrink()
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(
                'اختر موعدًا أولاً لحجز باقة أو جلسة',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildPricingCard(PricingPlanModel plan) {
    final pricePerSession = plan.priceEGP / plan.sessionsCount;
    return Container(
        width: 180,
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryAmber.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              plan.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${plan.priceEGP.toStringAsFixed(0)} ج',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (plan.sessionsCount > 1)
                  Text(
                    '${pricePerSession.toStringAsFixed(0)} ج/جلسة',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_available,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${plan.sessionsCount} جلسة',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(
      BuildContext context, Map<String, dynamic> profile) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              left: 20,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: profile['photoUrl'] != null &&
                            (profile['photoUrl'] as String).isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: profile['photoUrl'],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.person, size: 40),
                            ),
                          )
                        : const Icon(Icons.person,
                            size: 40, color: AppTheme.primaryAmber),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          profile['name'] ?? 'غير محدد',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (profile['specialization'] != null)
                          Text(
                            profile['specialization'],
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
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

  // ─── Basic info ───────────────────────────────────────────────────────────

  Widget _buildBasicInfo(Map<String, dynamic> profile) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoCard(
            icon: Icons.star,
            label: 'التقييم',
            value: '${profile['rating'] ?? 0.0}/10',
            color: Colors.amber,
          ),
          _buildInfoCard(
            icon: Icons.people,
            label: 'المتابعون',
            value: '${profile['followerCount'] ?? 0}',
            color: AppTheme.accentGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
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

  Widget _buildCredentialsSection(WidgetRef ref) {
    return Consumer(
      builder: (context, ref, _) {
        final credentials =
            ref.watch(credentialsProvider(widget.mohaffezId));
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
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: creds.length,
                    itemBuilder: (context, index) {
                      final cred = creds[index];
                      return Container(
                        width: 220,
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  Colors.purple.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified,
                                    color: Colors.purple, size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    cred['title'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.business,
                                    size: 16,
                                    color: Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    cred['organization'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 14,
                                      color: Colors.green.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    'معتمدة',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
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
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  // ─── Session type selector ────────────────────────────────────────────────

  Widget _buildSessionTypeSelector() {
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
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home, size: 18),
                      SizedBox(width: 6),
                      Flexible(child: Text('بيت الطالب')),
                    ],
                  ),
                  selected: selectedSessionType == 'home',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedSessionType = 'home';
                        selectedTimeSlot = null;
                        selectedDate = null;
                        selectedDayOfWeek = null;
                      });
                    }
                  },
                  selectedColor:
                      AppTheme.primaryAmber.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    fontWeight: selectedSessionType == 'home'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mosque, size: 18),
                      SizedBox(width: 6),
                      Flexible(child: Text('المسجد')),
                    ],
                  ),
                  selected: selectedSessionType == 'mosque',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedSessionType = 'mosque';
                        selectedTimeSlot = null;
                        selectedDate = null;
                        selectedDayOfWeek = null;
                      });
                    }
                  },
                  selectedColor:
                      AppTheme.accentGreen.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    fontWeight: selectedSessionType == 'mosque'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, size: 18),
                      SizedBox(width: 6),
                      Flexible(child: Text('أونلاين')),
                    ],
                  ),
                  selected: selectedSessionType == 'online',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedSessionType = 'online';
                        selectedTimeSlot = null;
                        selectedDate = null;
                        selectedDayOfWeek = null;
                      });
                    }
                  },
                  selectedColor: Colors.blue.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    fontWeight: selectedSessionType == 'online'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Availability section ─────────────────────────────────────────────────

  Widget _buildAvailabilitySection(
      WidgetRef ref, Map<String, dynamic> profile) {
    return Consumer(
      builder: (context, ref, _) {
        final availability =
            ref.watch(availabilityProvider(widget.mohaffezId));
        return availability.when(
          data: (slots) {
            if (slots.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: Colors.grey.shade400, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'لا توجد أوقات متاحة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade600),
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
                ...slots.map((slot) {
                  final dayOfWeek = slot['dayOfWeek'] as int;
                  final timeSlots =
                      List<Map<String, dynamic>>.from(
                          slot['timeSlots'] ?? []);

                  final now = DateTime.now();
                  final today =
                      DateTime(now.year, now.month, now.day);
                  final currentDayOfWeek = today.weekday;

                  int daysUntil = dayOfWeek - currentDayOfWeek;
                  if (daysUntil < 0) daysUntil += 7;

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
                          (ts['startTime'] as String).split(':');
                      final slotTime = DateTime(
                        today.year,
                        today.month,
                        today.day,
                        int.parse(parts[0]),
                        int.parse(parts[1]),
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
                            const Icon(Icons.calendar_today,
                                size: 18,
                                color: AppTheme.accentGreen),
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
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: enabledSlots.map((ts) {
                            final isSelected = selectedTimeSlot == ts &&
                                selectedDayOfWeek == dayOfWeek;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedTimeSlot = ts;
                                  selectedDate = targetDate;
                                  selectedDayOfWeek = dayOfWeek;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.accentGreen
                                      : Colors.green.shade50,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.accentGreen
                                        : Colors.green.shade200,
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
                                          ? Colors.white
                                          : Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${ts['startTime']} - ${ts['endTime']}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.check_circle,
                                          size: 16,
                                          color: Colors.white),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 320,
            child: SkeletonList(itemCount: 4, itemHeight: 70),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'خطأ في تحميل الأوقات المتاحة',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        );
      },
    );
  }
}
