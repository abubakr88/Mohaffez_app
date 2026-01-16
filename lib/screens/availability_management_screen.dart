import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../shared/constants/app_theme.dart';
import '../shared/constants/schedule_constants.dart';

class AvailabilityManagementScreen extends StatefulWidget {
  const AvailabilityManagementScreen({super.key});

  @override
  State<AvailabilityManagementScreen> createState() =>
      _AvailabilityManagementScreenState();
}

class _AvailabilityManagementScreenState
    extends State<AvailabilityManagementScreen>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  Map<int, Map<String, dynamic>> weeklySchedule = {};
  bool loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadAvailability();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadAvailability() async {
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('availability')
          .get();

      final schedule = <int, Map<String, dynamic>>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dayOfWeek = data['dayOfWeek'] as int;
        schedule[dayOfWeek] = data;
      }

      setState(() {
        weeklySchedule = schedule;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> toggleTimeSlot(
    int dayOfWeek,
    String startTime,
    String endTime,
    String sessionType,
  ) async {
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('availability')
          .doc('day$dayOfWeek');

      final doc = await docRef.get();
      List<Map<String, dynamic>> timeSlots = [];

      if (doc.exists) {
        final data = doc.data()!;
        timeSlots = List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);
      }

      final slotIndex = timeSlots.indexWhere((slot) =>
          slot['startTime'] == startTime &&
          slot['endTime'] == endTime &&
          slot['sessionType'] == sessionType);

      if (slotIndex >= 0) {
        // Toggle enabled status
        timeSlots[slotIndex]['enabled'] = !timeSlots[slotIndex]['enabled'];
      } else {
        // Add new slot
        timeSlots.add({
          'startTime': startTime,
          'endTime': endTime,
          'sessionType': sessionType,
          'enabled': true,
        });
      }

      await docRef.set({
        'dayOfWeek': dayOfWeek,
        'timeSlots': timeSlots,
        'recurringWeekly': true,
      });

      await loadAvailability();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  bool isSlotEnabled(int dayOfWeek, String startTime, String sessionType) {
    if (!weeklySchedule.containsKey(dayOfWeek)) return false;

    final daySchedule = weeklySchedule[dayOfWeek]!;
    final timeSlots =
        List<Map<String, dynamic>>.from(daySchedule['timeSlots'] ?? []);

    final slot = timeSlots.firstWhere(
      (s) =>
          s['startTime'] == startTime &&
          (s['sessionType'] == sessionType || s['sessionType'] == 'both'),
      orElse: () => {},
    );

    return slot['enabled'] == true;
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('الرجاء تسجيل الدخول')),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Modern App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.calendar_today,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'إدارة الأوقات',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'حدد الأوقات المتاحة لديك',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.event_busy,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  // Show block date dialog
                                },
                                tooltip: 'حظر تاريخ',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: Colors.blue,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.home, size: 20),
                        text: 'في المنزل/المسجد',
                      ),
                      Tab(
                        icon: Icon(Icons.videocam, size: 20),
                        text: 'عن بُعد',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Info Card
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'اضغط على اليوم لتفعيل أو إلغاء الوقت المتاح. التغييرات تُحفظ تلقائياً.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            SliverFillRemaining(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildScheduleGrid('home'),
                        _buildScheduleGrid('online'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleGrid(String sessionType) {
    return RefreshIndicator(
      onRefresh: loadAvailability,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: ScheduleConstants.timeSlots.map((slot) {
          return _TimeSlotCard(
            startTime: slot['start']!,
            endTime: slot['end']!,
            sessionType: sessionType,
            weeklySchedule: weeklySchedule,
            onDayTap: (dayOfWeek) {
              toggleTimeSlot(
                dayOfWeek,
                slot['start']!,
                slot['end']!,
                sessionType,
              );
            },
            isSlotEnabled: isSlotEnabled,
          );
        }).toList(),
      ),
    );
  }
}

class _TimeSlotCard extends StatelessWidget {
  final String startTime;
  final String endTime;
  final String sessionType;
  final Map<int, Map<String, dynamic>> weeklySchedule;
  final Function(int) onDayTap;
  final bool Function(int, String, String) isSlotEnabled;

  const _TimeSlotCard({
    required this.startTime,
    required this.endTime,
    required this.sessionType,
    required this.weeklySchedule,
    required this.onDayTap,
    required this.isSlotEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$startTime - $endTime',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Days Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                final dayOfWeek = (index + 1) % 7 + 1; // Monday = 1
                final isEnabled = isSlotEnabled(dayOfWeek, startTime, sessionType);

                return _DayChip(
                  day: ScheduleConstants.arabicDays[index],
                  isEnabled: isEnabled,
                  onTap: () => onDayTap(dayOfWeek),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String day;
  final bool isEnabled;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isEnabled ? AppTheme.accentGreen : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled ? AppTheme.accentGreen : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppTheme.accentGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isEnabled ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: isEnabled ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              day.substring(0, 3),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isEnabled ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
