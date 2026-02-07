import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../shared/constants/app_theme.dart';
import '../providers/mohaffez_profile_providers.dart';
import '../providers/user_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/pricing_provider.dart';
import '../models/pricing_plan_model.dart';
import '../repositories/payment_repository.dart';
import 'student_payment_screen.dart';

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
  bool isBooking = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(mohaffezProfileProvider(widget.mohaffezId));
    final plansAsync = ref.watch(activePricingPlansProvider(widget.mohaffezId));

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        body: profileAsync.when(
          data: (profile) => CustomScrollView(
            slivers: [
              _buildAppBar(context, profile),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfo(profile),
                    const SizedBox(height: 16),

                    // ✅ NEW: Pricing Preview Banner (Prominent)
                    _buildPricingPreviewBanner(plansAsync),
                    const SizedBox(height: 16),

                    if (profile['bio'] != null &&
                        (profile['bio'] as String).isNotEmpty)
                      _buildBioSection(profile['bio'] as String),
                    const SizedBox(height: 16),

                    _buildCredentialsSection(ref),
                    const SizedBox(height: 16),

                    // ✅ NEW: Trust Badges Section
                    _buildTrustBadgesSection(),
                    const SizedBox(height: 16),

                    // Session Type Selector
                    _buildSessionTypeSelector(),
                    const SizedBox(height: 16),

                    // ✅ Detailed Pricing Plans (Horizontal Scroll)
                    _buildPricingSection(plansAsync),
                    const SizedBox(height: 16),

                    // Availability Section
                    _buildAvailabilitySection(ref, profile),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
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
                        color: Colors.black.withOpacity(0.1),
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
                          color: AppTheme.accentGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.accentGreen.withOpacity(0.3),
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

                      // Booking button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isBooking
                              ? null
                              : () => sendBookingRequest(profileAsync.value!),
                          icon: isBooking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            isBooking ? 'جاري الإرسال...' : 'إرسال طلب الحجز',
                            style: const TextStyle(
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

  // ✅ NEW: Pricing Preview Banner (Most Prominent)
  Widget _buildPricingPreviewBanner(
      AsyncValue<List<PricingPlanModel>> plansAsync) {
    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) return const SizedBox.shrink();

        // Filter by selected session type
        final relevantPlans = plans.where((plan) {
          if (selectedSessionType == 'home') return plan.mode == SessionMode.home;
          if (selectedSessionType == 'mosque')
            return plan.mode == SessionMode.mosque;
          if (selectedSessionType == 'online')
            return plan.mode == SessionMode.online;
          return false;
        }).toList();

        if (relevantPlans.isEmpty) return const SizedBox.shrink();

        // Get best value plan (lowest price per session)
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
                color: AppTheme.primaryAmber.withOpacity(0.3),
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
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
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
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_offer,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
              if (savings > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.savings, color: Colors.white, size: 18),
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

  // ✅ NEW: Trust Badges Section
  Widget _buildTrustBadgesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          children: [
            // Trust Icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTrustItem(
                  Icons.lock,
                  'دفع آمن',
                  'تشفير 256-bit',
                ),
                _buildTrustItem(
                  Icons.verified_user,
                  'معتمد',
                  'موثق ومضمون',
                ),
                _buildTrustItem(
                  Icons.replay,
                  'استرجاع',
                  'خلال ساعتين',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Payment Methods
            const Text(
              'طرق الدفع المتاحة',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
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
        Icon(icon, color: Colors.green.shade700, size: 28),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIX 2: Make "عرض جميع الخطط والدفع" button LARGER and MORE VISIBLE
  Widget _buildPricingSection(AsyncValue<List<PricingPlanModel>> plansAsync) {
    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) {
          return const SizedBox.shrink();
        }

        // Filter plans by selected session type
        final relevantPlans = plans.where((plan) {
          if (selectedSessionType == 'home') return plan.mode == SessionMode.home;
          if (selectedSessionType == 'mosque')
            return plan.mode == SessionMode.mosque;
          if (selectedSessionType == 'online')
            return plan.mode == SessionMode.online;
          return false;
        }).toList();

        if (relevantPlans.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا توجد خطط تسعير متاحة لهذا النوع من الجلسات',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
                  final plan = relevantPlans[index];
                  return _buildPricingCard(plan);
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // ✅ LARGER, MORE PROMINENT BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => StudentPaymentScreen(
                          mohaffezId: widget.mohaffezId,
                          mohaffezName: _getMohaffezName(),
                          preselectedSessionType: selectedSessionType,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payments, size: 24),
                  label: const Text(
                    'عرض جميع الخطط والدفع',
                    style: TextStyle(
                      fontSize: 18, // ✅ Increased from 14 to 18
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryAmber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }


 // ... (keep all imports and class declaration as before until _buildPricingCard)

  // ✅ FIX 1: Make pricing cards CLICKABLE
  Widget _buildPricingCard(PricingPlanModel plan) {
    final pricePerSession = plan.priceEGP / plan.sessionsCount;
    return GestureDetector(
      onTap: () {
        // ✅ Navigate to payment screen when card is tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => StudentPaymentScreen(
              mohaffezId: widget.mohaffezId,
              mohaffezName: _getMohaffezName(),
              preselectedSessionType: selectedSessionType,
            ),
          ),
        );
      },
      child: Container(
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
              color: AppTheme.primaryAmber.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
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
            // Price
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
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            // Bottom info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_available, size: 12, color: Colors.white),
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
      ),
    );
  }


  String _getMohaffezName() {
    final profileValue =
        ref.read(mohaffezProfileProvider(widget.mohaffezId)).value;
    return profileValue?['name'] ?? '';
  }

  // ✅ MAIN BOOKING FUNCTION - Handles payment flow
  Future<void> sendBookingRequest(Map<String, dynamic> profile) async {
    if (selectedTimeSlot == null || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ الرجاء اختيار موعد وساعة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (selectedDate!.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ لا يمكن حجز موعد في الماضي'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isBooking = true);

    try {
      // ✅ CHECK: Does student have active subscription?
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final activeSubscription = await paymentRepo.getActiveSubscription(
        user.uid,
        widget.mohaffezId,
      );

      if (activeSubscription != null && activeSubscription.remainingSessions > 0) {
        // ✅ HAS SUBSCRIPTION: Send request directly (credit on hold)
        await _sendRequestWithSubscription(profile, activeSubscription);
      } else {
        // ✅ NO SUBSCRIPTION: Show options
        await _showBookingOptionsDialog(profile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isBooking = false);
      }
    }
  }

  // ✅ Send request with existing subscription (credit held, consumed on acceptance)
  Future<void> _sendRequestWithSubscription(
    Map<String, dynamic> profile,
    dynamic subscription,
  ) async {
    final user = ref.read(currentUserProvider).value!;

    final startParts = (selectedTimeSlot!['startTime'] as String).split(':');
    final endParts = (selectedTimeSlot!['endTime'] as String).split(':');

    final slotStart = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      int.parse(startParts[0]),
      int.parse(startParts[1]),
    );

    final slotEnd = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      int.parse(endParts[0]),
      int.parse(endParts[1]),
    );

    final slotDate = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
    );

    // Create request with subscription reference
    final result = await ref.read(bookingServiceProvider).createSessionRequest(
          mohaffezId: widget.mohaffezId,
          studentId: user.uid,
          studentName: user.name,
          mohaffezName: profile['name'] ?? '',
          sessionType: selectedSessionType,
          preferredTimeSlot:
              '${selectedTimeSlot!['startTime']} - ${selectedTimeSlot!['endTime']}',
          slotStart: slotStart,
          slotEnd: slotEnd,
          slotDate: slotDate,
          imamAddressText: profile['addressText'],
          imamAddressLat: profile['addressLat'],
          imamAddressLng: profile['addressLng'],
          mohaffezPhone: profile['phoneNumber'],
          subscriptionId: subscription.id, // ✅ LINK subscription
          isPaid: false, // ✅ Not paid yet, credit on hold
        );

    if (result.isSuccess && mounted) {
      setState(() {
        selectedTimeSlot = null;
        selectedDate = null;
        selectedDayOfWeek = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ تم إرسال طلب الحجز!\nسيتم خصم جلسة عند قبول المحفظ\n(${subscription.remainingSessions} جلسة متاحة)',
          ),
          backgroundColor: AppTheme.accentGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ✅ Show dialog: Buy package OR send free request (pay later)
  Future<void> _showBookingOptionsDialog(Map<String, dynamic> profile) async {
    if (!mounted) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('كيف تريد الحجز؟'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اختر طريقة الحجز المناسبة لك:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Option 1: Buy package now
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_offer, color: Colors.green),
                  ),
                  title: const Text(
                    'شراء باقة الآن',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'احصل على خصم مع الباقات واحجز مباشرة',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pop(ctx, 'buy_package'),
                ),
              ),

              const SizedBox(height: 12),

              // Option 2: Request now, pay after acceptance
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.blue),
                  ),
                  title: const Text(
                    'إرسال طلب مجاني',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'ادفع فقط إذا قبل المحفظ الطلب',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pop(ctx, 'free_request'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'buy_package' && mounted) {
      // Navigate to payment screen to buy package
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => StudentPaymentScreen(
            mohaffezId: widget.mohaffezId,
            mohaffezName: profile['name'] ?? '',
            preselectedSessionType: selectedSessionType,
            showSubscriptionsOnly: true, // ✅ Show packages/subscriptions only
          ),
        ),
      );

      if (result == true && mounted) {
        // After buying package, send request automatically
        final paymentRepo = ref.read(paymentRepositoryProvider);
        final newSubscription = await paymentRepo.getActiveSubscription(
          ref.read(currentUserProvider).value!.uid,
          widget.mohaffezId,
        );

        if (newSubscription != null) {
          await _sendRequestWithSubscription(profile, newSubscription);
        }
      }
    } else if (choice == 'free_request' && mounted) {
      // Send free request (pay after acceptance)
      await _sendFreeRequest(profile);
    }
  }

  // ✅ Send free request (payment happens AFTER teacher accepts)
  Future<void> _sendFreeRequest(Map<String, dynamic> profile) async {
    final user = ref.read(currentUserProvider).value!;

    final startParts = (selectedTimeSlot!['startTime'] as String).split(':');
    final endParts = (selectedTimeSlot!['endTime'] as String).split(':');

    final slotStart = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      int.parse(startParts[0]),
      int.parse(startParts[1]),
    );

    final slotEnd = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      int.parse(endParts[0]),
      int.parse(endParts[1]),
    );

    final slotDate = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
    );

    final result = await ref.read(bookingServiceProvider).createSessionRequest(
          mohaffezId: widget.mohaffezId,
          studentId: user.uid,
          studentName: user.name,
          mohaffezName: profile['name'] ?? '',
          sessionType: selectedSessionType,
          preferredTimeSlot:
              '${selectedTimeSlot!['startTime']} - ${selectedTimeSlot!['endTime']}',
          slotStart: slotStart,
          slotEnd: slotEnd,
          slotDate: slotDate,
          imamAddressText: profile['addressText'],
          imamAddressLat: profile['addressLat'],
          imamAddressLng: profile['addressLng'],
          mohaffezPhone: profile['phoneNumber'],
          isPaid: false, // ✅ Payment pending until acceptance
          requiresPaymentOnAcceptance: true, // ✅ NEW FLAG
        );

    if (result.isSuccess && mounted) {
      setState(() {
        selectedTimeSlot = null;
        selectedDate = null;
        selectedDayOfWeek = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ تم إرسال طلب الحجز!\nسيتم إشعارك عند قبول المحفظ للدفع',
          ),
          backgroundColor: AppTheme.accentGreen,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildAppBar(BuildContext context, Map<String, dynamic> profile) {
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
                        ),
                        if (profile['specialization'] != null)
                          Text(
                            profile['specialization'],
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection(String bio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نبذة تعريفية',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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

  Widget _buildCredentialsSection(WidgetRef ref) {
    return Consumer(
      builder: (context, ref, _) {
        final credentials = ref.watch(credentialsProvider(widget.mohaffezId));
        return credentials.when(
          data: (creds) {
            if (creds.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'الشهادات والمؤهلات',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: creds.length,
                    itemBuilder: (context, index) {
                      final cred = creds[index];
                      return Container(
                        width: 220,
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.purple.withOpacity(0.3)),
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
                                    size: 16, color: Colors.grey.shade600),
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
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 14, color: Colors.green.shade700),
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
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildSessionTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نوع الجلسة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.home, size: 18),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text('بيت الطالب'),
                      ),
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
                  selectedColor: AppTheme.primaryAmber.withOpacity(0.3),
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
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.mosque, size: 18),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text('المسجد'),
                      ),
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
                  selectedColor: AppTheme.accentGreen.withOpacity(0.3),
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
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.videocam, size: 18),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text('أونلاين'),
                      ),
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
                  selectedColor: Colors.blue.withOpacity(0.3),
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

  Widget _buildAvailabilitySection(
      WidgetRef ref, Map<String, dynamic> profile) {
    return Consumer(
      builder: (context, ref, _) {
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
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: Colors.grey.shade400, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        'لا توجد أوقات متاحة',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
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
              'الأحد'
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'الأوقات المتاحة - اختر الوقت المناسب',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...slots.map((slot) {
                  final dayOfWeek = slot['dayOfWeek'] as int;
                  final timeSlots =
                      List<Map<String, dynamic>>.from(slot['timeSlots'] ?? []);

                  final enabledSlots = timeSlots
                      .where((ts) =>
                          ts['enabled'] == true &&
                          ts['sessionType'] == selectedSessionType)
                      .toList();

                  if (enabledSlots.isEmpty) return const SizedBox.shrink();

                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final currentDayOfWeek = today.weekday;

                  int daysUntil = dayOfWeek - currentDayOfWeek;
                  if (daysUntil <= 0) {
                    daysUntil += 7;
                  }

                  final targetDate = DateTime(
                    today.year,
                    today.month,
                    today.day + daysUntil,
                  );

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 18, color: AppTheme.accentGreen),
                            const SizedBox(width: 8),
                            Text(
                              '${arabicDays[dayOfWeek - 1]} - ${DateFormat('dd/MM', 'ar').format(targetDate)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: enabledSlots
                              .map(
                                (ts) => GestureDetector(
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
                                      color: selectedTimeSlot == ts &&
                                              selectedDayOfWeek == dayOfWeek
                                          ? AppTheme.accentGreen
                                          : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: selectedTimeSlot == ts &&
                                                selectedDayOfWeek == dayOfWeek
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
                                          color: selectedTimeSlot == ts &&
                                                  selectedDayOfWeek == dayOfWeek
                                              ? Colors.white
                                              : Colors.green.shade700,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${ts['startTime']} - ${ts['endTime']}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: selectedTimeSlot == ts &&
                                                    selectedDayOfWeek ==
                                                        dayOfWeek
                                                ? Colors.white
                                                : Colors.green.shade700,
                                          ),
                                        ),
                                        if (selectedTimeSlot == ts &&
                                            selectedDayOfWeek == dayOfWeek) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.check_circle,
                                              size: 16, color: Colors.white),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  );
                }).toList(),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
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
