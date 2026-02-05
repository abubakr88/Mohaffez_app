import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // ✅ REQUIRED IMPORT
import '../shared/constants/app_theme.dart';
import '../providers/mohaffez_profile_providers.dart';
import '../providers/user_provider.dart';
import '../providers/booking_provider.dart';

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
  DateTime? selectedDate; // ✅ ADDED
  int? selectedDayOfWeek; // ✅ ADDED to track which day was selected
  bool isBooking = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(mohaffezProfileProvider(widget.mohaffezId));

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
                    if (profile['bio'] != null &&
                        (profile['bio'] as String).isNotEmpty)
                      _buildBioSection(profile['bio'] as String),
                    const SizedBox(height: 16),
                    _buildCredentialsSection(ref),
                    const SizedBox(height: 16),
                    _buildSessionTypeSelector(),
                    const SizedBox(height: 16),
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
                      // ✅ UPDATED: Show both date and time
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
                                Icon(Icons.calendar_today,
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
                                Icon(Icons.access_time,
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
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home, size: 18),
                      SizedBox(width: 6),
                      Text('بيت الطالب'),
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
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mosque, size: 18),
                      SizedBox(width: 6),
                      Text('المسجد'),
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
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, size: 18),
                      SizedBox(width: 6),
                      Text('أونلاين'),
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

    // ✅ COMPLETELY FIXED: Proper date calculation
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

                  // Filter by enabled AND sessionType
                  final enabledSlots = timeSlots
                      .where((ts) =>
                          ts['enabled'] == true &&
                          ts['sessionType'] == selectedSessionType)
                      .toList();

                  if (enabledSlots.isEmpty) return const SizedBox.shrink();

                  // ✅ BULLETPROOF DATE CALCULATION
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day); // Strip time
                  final currentDayOfWeek = today.weekday; // 1=Monday, 7=Sunday

                  // Calculate days until this dayOfWeek
                  int daysUntil = dayOfWeek - currentDayOfWeek;
                  if (daysUntil <= 0) {
                    daysUntil += 7; // Next week if day has passed
                  }

                  // ✅ EXPLICIT DATE CONSTRUCTION
                  final targetDate = DateTime(
                    today.year,
                    today.month,
                    today.day + daysUntil,
                  );

                  // ✅ DEBUG OUTPUT
                  print('🔍 Availability Debug:');
                  print('   dayOfWeek from Firestore: $dayOfWeek');
                  print('   today: $today');
                  print('   currentDayOfWeek: $currentDayOfWeek');
                  print('   daysUntil: $daysUntil');
                  print('   targetDate: $targetDate');

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
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
                                      selectedDate = targetDate; // ✅ SET THE CORRECT DATE
                                      selectedDayOfWeek = dayOfWeek;
                                    });
                                    
                                    // ✅ DEBUG: Print when slot is selected
                                    print('🎯 Slot Selected:');
                                    print('   selectedDate: $selectedDate');
                                    print('   selectedDayOfWeek: $selectedDayOfWeek');
                                    print('   timeSlot: ${ts['startTime']} - ${ts['endTime']}');
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

  /// COMPLETELY FIXED: Proper date handling with DEBUG
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

    // VALIDATION: Prevent booking in the past
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
      final startParts = (selectedTimeSlot!['startTime'] as String).split(':');
      final endParts = (selectedTimeSlot!['endTime'] as String).split(':');

      // FIX: Build dates explicitly - ensure they use selectedDate
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

      // Create a date-only version for slotDate
      final slotDate = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      );

      // DEBUG PRINTS
      print('🚀 SENDING BOOKING REQUEST:');
      print('   selectedDate: $selectedDate');
      print('   slotStart: $slotStart');
      print('   slotEnd: $slotEnd');
      print('   slotDate: $slotDate');

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
        slotDate: slotDate, // CRITICAL: Pass the date-only version
        imamAddressText: profile['addressText'],
        imamAddressLat: profile['addressLat'],
        imamAddressLng: profile['addressLng'],
        mohaffezPhone: profile['phoneNumber'],
      );

      print('📋 Booking Result: ${result.isSuccess ? '✅ SUCCESS' : '❌ FAILED'}');

      if (mounted) {
        if (result.isSuccess) {
          setState(() {
            selectedTimeSlot = null;
            selectedDate = null;
            selectedDayOfWeek = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم إرسال طلب الحجز بنجاح'),
              backgroundColor: AppTheme.accentGreen,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? '❌ فشل إرسال الطلب'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('💥 Booking Error: $e');
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
 }