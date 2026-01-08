import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/follow_service.dart';
import '../providers/booking_provider.dart';
import '../shared/widgets/verification_badge.dart';
import '../shared/widgets/availability_calendar_widget.dart';

class MohaffezProfileScreen extends ConsumerStatefulWidget {
  final String mohaffezId;
  final String mohaffezName;

  const MohaffezProfileScreen({
    super.key,
    required this.mohaffezId,
    required this.mohaffezName,
  });

  @override
  ConsumerState<MohaffezProfileScreen> createState() =>
      _MohaffezProfileScreenState();
}

class _MohaffezProfileScreenState
    extends ConsumerState<MohaffezProfileScreen> {
  bool _isFollowing = false;
  bool _loadingFollow = true;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final isFollowing = await FollowService.isFollowing(widget.mohaffezId);
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _loadingFollow = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _loadingFollow = true);
    final success = _isFollowing
        ? await FollowService.unfollowMohaffez(widget.mohaffezId)
        : await FollowService.followMohaffez(widget.mohaffezId);

    if (success) {
      setState(() {
        _isFollowing = !_isFollowing;
        _loadingFollow = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFollowing ? 'تمت المتابعة بنجاح' : 'تم إلغاء المتابعة'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() => _loadingFollow = false);
    }
  }

  // FIXED: Using Firestore transaction to prevent race condition
  Future<void> requestSession(
    BuildContext context,
    String sessionType,
    String timeSlot,
    DateTime slotDate,
    DateTime slotStart,
    DateTime slotEnd,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
      );
      return;
    }

    if (slotStart.isBefore(DateTime.now())) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الوقت المختار انتهى، اختر وقتًا آخر'),
        ),
      );
      return;
    }

    // Show loading indicator
    ref.read(bookingLoadingProvider.notifier).state = true;

    try {
      // Use Firestore transaction to prevent race condition
      final result = await FirebaseFirestore.instance.runTransaction<bool>(
        (transaction) async {
          // Check for conflicts within the transaction
          final conflictQuery = await FirebaseFirestore.instance
              .collection('sessionRequests')
              .where('mohaffezId', isEqualTo: widget.mohaffezId)
              .where('slotStart', isEqualTo: Timestamp.fromDate(slotStart))
              .where('status', whereIn: ['pending', 'accepted'])
              .get();

          if (conflictQuery.docs.isNotEmpty) {
            return false; // Slot is already booked
          }

          // Fetch user data within transaction
          final studentDocRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid);
          final imamDocRef = FirebaseFirestore.instance
              .collection('users')
              .doc(widget.mohaffezId);

          final studentSnapshot = await transaction.get(studentDocRef);
          final imamSnapshot = await transaction.get(imamDocRef);

          final studentData = studentSnapshot.data() ?? {};
          final imamData = imamSnapshot.data() ?? {};

          final studentName = (studentData['name'] as String?) ?? '';
          final imamName = (imamData['name'] as String?) ?? widget.mohaffezName;
          final imamAddressText = (imamData['addressText'] as String?) ?? '';
          final imamAddressLat = (imamData['addressLat'] as num?)?.toDouble();
          final imamAddressLng = (imamData['addressLng'] as num?)?.toDouble();
          final mohaffezPhone =
              (imamData['phone'] as String?) ?? (imamData['mobile'] as String?) ?? '';

          // Create the session request atomically
          final newRequestRef = FirebaseFirestore.instance
              .collection('sessionRequests')
              .doc();

          transaction.set(newRequestRef, {
            'studentId': user.uid,
            'studentName': studentName,
            'mohaffezId': widget.mohaffezId,
            'mohaffezName': imamName,
            'imamAddressText': imamAddressText,
            'imamAddressLat': imamAddressLat,
            'imamAddressLng': imamAddressLng,
            'mohaffezPhone': mohaffezPhone,
            'sessionType': sessionType,
            'preferredTimeSlot': timeSlot,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'slotDate': Timestamp.fromDate(
              DateTime(slotDate.year, slotDate.month, slotDate.day),
            ),
            'slotStart': Timestamp.fromDate(slotStart),
            'slotEnd': Timestamp.fromDate(slotEnd),
          });

          return true; // Booking successful
        },
      );

      ref.read(bookingLoadingProvider.notifier).state = false;

      if (!context.mounted) return;

      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب الحجز بنجاح')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذا الموعد محجوز بالفعل، اختر وقتًا آخر'),
          ),
        );
      }
    } catch (e) {
      ref.read(bookingLoadingProvider.notifier).state = false;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    }
  }

  void showBookingSheet(BuildContext context) {
    String? selectedType;
    String? selectedSlot;
    DateTime? selectedDayDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isBookingLoading = ref.watch(bookingLoadingProvider);

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  top: 20,
                  left: 16,
                  right: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'حجز جلسة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(
                              Icons.home,
                              color: selectedType == 'home'
                                  ? Colors.white
                                  : null,
                            ),
                            label: Text(
                              'في المنزل',
                              style: TextStyle(
                                color: selectedType == 'home'
                                    ? Colors.white
                                    : null,
                              ),
                            ),
                            onPressed: () {
                              setModalState(() {
                                selectedType = 'home';
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: selectedType == 'home'
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(
                              Icons.mosque,
                              color: selectedType == 'mosque'
                                  ? Colors.white
                                  : null,
                            ),
                            label: Text(
                              'في المسجد',
                              style: TextStyle(
                                color: selectedType == 'mosque'
                                    ? Colors.white
                                    : null,
                              ),
                            ),
                            onPressed: () {
                              setModalState(() {
                                selectedType = 'mosque';
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: selectedType == 'mosque'
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'اختيار اليوم والوقت',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    buildTimeSlots(
                      selectedSlot,
                      (slotValue, dayDate) {
                        setModalState(() {
                          selectedSlot = slotValue;
                          selectedDayDate = dayDate;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedType != null &&
                                selectedSlot != null &&
                                selectedDayDate != null &&
                                !isBookingLoading
                            ? () async {
                                final parsed = _parseSlotLabel(selectedSlot!);
                                final slotStart = DateTime(
                                  selectedDayDate!.year,
                                  selectedDayDate!.month,
                                  selectedDayDate!.day,
                                  parsed.$1,
                                  parsed.$2,
                                );
                                final slotEnd =
                                    slotStart.add(const Duration(minutes: 45));

                                Navigator.pop(ctx);
                                await requestSession(
                                  context,
                                  selectedType!,
                                  selectedSlot!,
                                  selectedDayDate!,
                                  slotStart,
                                  slotEnd,
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isBookingLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('تأكيد الحجز'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  (int, int) _parseSlotLabel(String label) {
    String normal = label.trim();
    if (!normal.contains(':')) {
      if (normal.length == 3) {
        normal = '${normal[0]}:${normal.substring(1)}';
      } else if (normal.length == 4) {
        normal = '${normal.substring(0, 2)}:${normal.substring(2)}';
      }
    }

    final parts = normal.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (h, m);
  }

  Widget buildTimeSlots(
    String? selectedSlot,
    void Function(String slotValue, DateTime dayDate) onSelect,
  ) {
    final now = DateTime.now();
    final days = [
      {'label': 'اليوم', 'date': now},
      {'label': 'غدًا', 'date': now.add(const Duration(days: 1))},
      {'label': 'بعد غد', 'date': now.add(const Duration(days: 2))},
    ];

    final slotLabels = ['08:00', '10:00', '16:00'];

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final date = day['date'] as DateTime;
          final label = day['label'] as String;
          final dateStr = '${date.day}/${date.month}';
          final isToday = label == 'اليوم';

          return Container(
            width: 120,
            margin: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                for (final slotLabel in slotLabels) ...{
                  // Filter past times for today
                  if (isToday) ...{
                    Builder(builder: (context) {
                      final parsed = _parseSlotLabel(slotLabel);
                      final slotTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        parsed.$1,
                        parsed.$2,
                      );

                      if (slotTime.isBefore(DateTime.now())) {
                        return const SizedBox(height: 32);
                      }

                      return Column(
                        children: [
                          buildTimeButton(
                            slotLabel,
                            slotLabel,
                            selectedSlot,
                            (slotValue) => onSelect(slotValue, date),
                          ),
                          const SizedBox(height: 6),
                        ],
                      );
                    }),
                  } else ...{
                    buildTimeButton(
                      slotLabel,
                      slotLabel,
                      selectedSlot,
                      (slotValue) => onSelect(slotValue, date),
                    ),
                    const SizedBox(height: 6),
                  }
                },
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildTimeButton(
    String time,
    String slotValue,
    String? selectedSlot,
    void Function(String) onSelect,
  ) {
    final isSelected = selectedSlot == slotValue;
    return OutlinedButton(
      onPressed: () => onSelect(slotValue),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        backgroundColor: isSelected ? Colors.red : Colors.white,
        side: BorderSide(
          color: isSelected ? Colors.red : Colors.grey.shade300,
        ),
      ),
      child: Text(
        time,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isStudent = currentUser != null && currentUser.uid != widget.mohaffezId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('ملف المحفظ'),
          actions: [
            if (isStudent && !_loadingFollow)
              IconButton(
                icon: Icon(_isFollowing ? Icons.favorite : Icons.favorite_border),
                onPressed: _toggleFollow,
                color: _isFollowing ? Colors.red : null,
                tooltip: _isFollowing ? 'إلغاء المتابعة' : 'متابعة',
              ),
            if (_loadingFollow)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {},
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.mohaffezId)
                      .get(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() ?? {};
                    final photoUrl = data['photoUrl'] as String?;
                    final specialization =
                        (data['specialization'] as String?) ?? 'تحفيظ القرآن الكريم';
                    final rating =
                        (data['rating'] as num?)?.toDouble() ?? 4.5;
                    final reviewCount = (data['reviewCount'] as int?) ?? 0;
                    final bio = data['bio'] as String?;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundImage:
                              photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // NEW: Name with badges
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.mohaffezName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // NEW: Display badges
                                  if (data['badges'] != null)
                                    VerificationBadgesRow(
                                      badges: Map<String, bool>.from(
                                          data['badges'] as Map),
                                      size: 20,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                specialization,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              // NEW: Show bio if available
                              if (bio != null && bio.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  bio,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ...List.generate(
                                    5,
                                    (i) => Icon(
                                      i < rating.round()
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 18,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$reviewCount تقييم',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Session Details
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.mosque, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'مكان التحفيظ - يحدد لاحقًا',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'مدة الجلسة 45 دقيقة',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.attach_money, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'السعر يحدد لاحقًا',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // NEW: Available Slots with Calendar Widget
              Container(
                color: Colors.white,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'أقرب مواعيد متاحة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    buildAvailableSlots(context),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Upcoming Sessions
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'أقرب جلسات قادمة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('hafizSessions')
                          .where('mohaffezId', isEqualTo: widget.mohaffezId)
                          .where(
                            'sessionDate',
                            isGreaterThanOrEqualTo:
                                Timestamp.fromDate(today),
                          )
                          .orderBy('sessionDate')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Text('لا توجد جلسات قادمة');
                        }

                        return Column(
                          children: docs.take(3).map((doc) {
                            final data = doc.data();
                            final location =
                                (data['location'] as String?) ?? '';
                            final juzCount =
                                (data['juzCount'] as int?) ?? 1;
                            final ts =
                                data['sessionDate'] as Timestamp?;
                            final date = ts?.toDate();
                            final dateStr = date != null
                                ? '${date.day}/${date.month}/${date.year}'
                                : '';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.school),
                              title: Text('$location - جزء $juzCount'),
                              subtitle: Text(dateStr),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: ElevatedButton(
              onPressed: () => showBookingSheet(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'حجز جلسة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildAvailableSlots(BuildContext context) {
    // NEW: Use the calendar widget
    return Column(
      children: [
        AvailabilityCalendarWidget(
          mohaffezId: widget.mohaffezId,
          daysToShow: 7,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            // TODO: Navigate to full calendar view
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('عرض التقويم الكامل - قريباً'),
              ),
            );
          },
          icon: const Icon(Icons.calendar_month),
          label: const Text('عرض التقويم الكامل'),
        ),
      ],
    );
  }
}
