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

  // ✅ Stats for each session type
  int homeSlots = 0;
  int mosqueSlots = 0;
  int onlineSlots = 0;

  // ✅ CONFIGURABLE SETTINGS
  String startTime = ScheduleConstants.defaultStartTime;
  String endTime = ScheduleConstants.defaultEndTime;
  int sessionDuration = ScheduleConstants.defaultSessionDurationMinutes;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAvailability();
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ Load user's schedule settings
  Future<void> _loadSettings() async {
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('settings')
          .doc('schedule')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          startTime = data['startTime'] as String? ?? ScheduleConstants.defaultStartTime;
          endTime = data['endTime'] as String? ?? ScheduleConstants.defaultEndTime;
          sessionDuration = data['sessionDuration'] as int? ?? ScheduleConstants.defaultSessionDurationMinutes;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // ✅ Save schedule settings
  Future<void> _saveSettings() async {
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('settings')
          .doc('schedule')
          .set({
        'startTime': startTime,
        'endTime': endTime,
        'sessionDuration': sessionDuration,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الإعدادات بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  Future<void> _loadAvailability() async {
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('availability')
          .get();

      final schedule = <int, Map<String, dynamic>>{};
      int home = 0;
      int mosque = 0;
      int online = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dayOfWeek = data['dayOfWeek'] as int;
        schedule[dayOfWeek] = data;

        // ✅ FIXED: Count enabled slots per type correctly
        final timeSlots = List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);
        for (var slot in timeSlots) {
          // ✅ Only count if explicitly enabled
          if (slot['enabled'] == true) {
            final sessionType = slot['sessionType'] as String? ?? 'home';
            
            // ✅ Count each type separately (NOT 'both')
            if (sessionType == 'home') {
              home++;
            } else if (sessionType == 'mosque') {
              mosque++;
            } else if (sessionType == 'online') {
              online++;
            }
          }
        }
      }

      // ✅ Debug: Print to verify counts
      debugPrint('=== Availability Stats ===');
      debugPrint('Home slots: $home');
      debugPrint('Mosque slots: $mosque');
      debugPrint('Online slots: $online');
      debugPrint('========================');

      setState(() {
        weeklySchedule = schedule;
        homeSlots = home;
        mosqueSlots = mosque;
        onlineSlots = online;
        loading = false;
      });
    } catch (e) {
      debugPrint('Error loading availability: $e');
      setState(() => loading = false);
    }
  }

  Future<void> _toggleTimeSlot(
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
          .doc('day_$dayOfWeek');

      final doc = await docRef.get();
      List<Map<String, dynamic>> timeSlots = [];

      if (doc.exists) {
        final data = doc.data()!;
        timeSlots = List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);

        final slotIndex = timeSlots.indexWhere((slot) =>
            slot['startTime'] == startTime &&
            slot['endTime'] == endTime &&
            slot['sessionType'] == sessionType);

        if (slotIndex >= 0) {
          // Toggle enabled status
          timeSlots[slotIndex]['enabled'] = !(timeSlots[slotIndex]['enabled'] ?? false);
        } else {
          // Add new slot
          timeSlots.add({
            'startTime': startTime,
            'endTime': endTime,
            'sessionType': sessionType,
            'enabled': true,
          });
        }
      } else {
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

      await _loadAvailability();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  bool _isSlotEnabled(int dayOfWeek, String startTime, String sessionType) {
    if (!weeklySchedule.containsKey(dayOfWeek)) return false;

    final daySchedule = weeklySchedule[dayOfWeek]!;
    final timeSlots = List<Map<String, dynamic>>.from(daySchedule['timeSlots'] ?? []);

    final slot = timeSlots.firstWhere(
      (s) =>
          s['startTime'] == startTime &&
          s['sessionType'] == sessionType,
      orElse: () => {},
    );

    return slot['enabled'] == true;
  }

  // ✅ NEW: Clear all availability data
  Future<void> _clearAllAvailability() async {
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد المسح'),
          content: const Text(
            'هل تريد مسح جميع الأوقات المتاحة؟\nسيتم حذف جميع الأوقات المفعلة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('مسح الكل'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('availability')
          .get();

      // Delete all availability documents
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      await _loadAvailability();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم مسح جميع الأوقات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في المسح: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ UPDATED: Settings dialog with clear button
  void _showSettingsDialog() {
    String tempStart = startTime;
    String tempEnd = endTime;
    int tempDuration = sessionDuration;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إعدادات الجدول'),
          content: StatefulBuilder(
            builder: (context, setDialogState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Start Time
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('وقت البداية'),
                    subtitle: Text(tempStart),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(tempStart.split(':')[0]),
                          minute: int.parse(tempStart.split(':')[1]),
                        ),
                      );
                      if (time != null) {
                        setDialogState(() {
                          tempStart = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                  // End Time
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('وقت النهاية'),
                    subtitle: Text(tempEnd),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.parse(tempEnd.split(':')[0]),
                          minute: int.parse(tempEnd.split(':')[1]),
                        ),
                      );
                      if (time != null) {
                        setDialogState(() {
                          tempEnd = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                  // Session Duration
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('مدة الجلسة (دقيقة)'),
                    subtitle: Slider(
                      value: tempDuration.toDouble(),
                      min: 15,
                      max: 120,
                      divisions: 21,
                      label: '$tempDuration دقيقة',
                      onChanged: (value) {
                        setDialogState(() {
                          tempDuration = value.toInt();
                        });
                      },
                    ),
                    trailing: Text('$tempDuration'),
                  ),
                  const Divider(height: 32),
                  // ✅ NEW: Clear All Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Close settings dialog first
                        _clearAllAvailability();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text(
                        'مسح جميع الأوقات',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  startTime = tempStart;
                  endTime = tempEnd;
                  sessionDuration = tempDuration;
                });
                _saveSettings();
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
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
                                      'الأوقات المتاحة',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'إدارة أوقات الجلسات',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
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
                    labelColor: AppTheme.primaryAmber,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: AppTheme.primaryAmber,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(icon: Icon(Icons.home, size: 20), text: 'في المنزل'),
                      Tab(icon: Icon(Icons.mosque, size: 20), text: 'في المسجد'),
                      Tab(icon: Icon(Icons.videocam, size: 20), text: 'أونلاين'),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _showSettingsDialog,
                  tooltip: 'إعدادات الجدول',
                ),
              ],
            ),

            // ✅ Stats Summary
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.home,
                      label: 'في المنزل',
                      count: homeSlots,
                      color: AppTheme.primaryAmber,
                    ),
                    _buildStatItem(
                      icon: Icons.mosque,
                      label: 'في المسجد',
                      count: mosqueSlots,
                      color: AppTheme.accentGreen,
                    ),
                    _buildStatItem(
                      icon: Icons.videocam,
                      label: 'أونلاين',
                      count: onlineSlots,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),

            // Info Card
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
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
                        'اضغط على الأيام لتفعيل أو إلغاء الأوقات. الجدول من $startTime إلى $endTime ($sessionDuration دقيقة لكل جلسة).',
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
                        _buildScheduleGrid('mosque'),
                        _buildScheduleGrid('online'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
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
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleGrid(String sessionType) {
    // ✅ Generate slots based on settings
    final slots = ScheduleConstants.generateTimeSlots(
      startTime: startTime,
      endTime: endTime,
      durationMinutes: sessionDuration,
    );

    return RefreshIndicator(
      onRefresh: _loadAvailability,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: slots.map((slot) {
          return TimeSlotCard(
            startTime: slot['start']!,
            endTime: slot['end']!,
            sessionType: sessionType,
            weeklySchedule: weeklySchedule,
            onDayTap: (dayOfWeek) => _toggleTimeSlot(
              dayOfWeek,
              slot['start']!,
              slot['end']!,
              sessionType,
            ),
            isSlotEnabled: _isSlotEnabled,
          );
        }).toList(),
      ),
    );
  }
}

class TimeSlotCard extends StatelessWidget {
  final String startTime;
  final String endTime;
  final String sessionType;
  final Map<int, Map<String, dynamic>> weeklySchedule;
  final Function(int) onDayTap;
  final bool Function(int, String, String) isSlotEnabled;

  const TimeSlotCard({
    super.key,
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
                // ✅ FIXED: Correct dayOfWeek calculation
                // Dart DateTime.weekday: Monday=1, Tuesday=2, ..., Sunday=7
                // We want: Monday=1, Tuesday=2, ..., Sunday=7 (same as Dart)
                final dayOfWeek = index + 1; // Monday=1, Sunday=7
                
                final isEnabled = isSlotEnabled(dayOfWeek, startTime, sessionType);
                
                return DayChip(
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

class DayChip extends StatelessWidget {
  final String day;
  final bool isEnabled;
  final VoidCallback onTap;

  const DayChip({
    super.key,
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
              : null,
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
