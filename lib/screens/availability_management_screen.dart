import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../shared/constants/schedule_constants.dart';

class AvailabilityManagementScreen extends StatefulWidget {
  const AvailabilityManagementScreen({super.key});

  @override
  State<AvailabilityManagementScreen> createState() =>
      _AvailabilityManagementScreenState();
}

class _AvailabilityManagementScreenState
    extends State<AvailabilityManagementScreen> {
  final user = FirebaseAuth.instance.currentUser;
  
  final List<String> arabicDays = ScheduleConstants.arabicDays;
  final List<Map<String, String>> timeSlots = ScheduleConstants.timeSlots;

  Map<int, Map<String, dynamic>> _weeklySchedule = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
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
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dayOfWeek = data['dayOfWeek'] as int;
        schedule[dayOfWeek] = data;
      }

      setState(() {
        _weeklySchedule = schedule;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
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

      // Get current schedule for this day
      final doc = await docRef.get();
      List<Map<String, dynamic>> timeSlots = [];

      if (doc.exists) {
        final data = doc.data()!;
        timeSlots = List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);
      }

      // Check if this slot exists
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

      // Save to Firestore
      await docRef.set({
        'dayOfWeek': dayOfWeek,
        'timeSlots': timeSlots,
        'recurringWeekly': true,
      });

      // Reload
      await _loadAvailability();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  bool _isSlotEnabled(int dayOfWeek, String startTime, String sessionType) {
    if (!_weeklySchedule.containsKey(dayOfWeek)) return false;

    final daySchedule = _weeklySchedule[dayOfWeek]!;
    final timeSlots = List<Map<String, dynamic>>.from(
      daySchedule['timeSlots'] ?? [],
    );

    final slot = timeSlots.firstWhere(
      (s) =>
          s['startTime'] == startTime &&
          (s['sessionType'] == sessionType || s['sessionType'] == 'both'),
      orElse: () => {},
    );

    return slot['enabled'] == true;
  }

  void _showBlockDateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const BlockDateBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('يجب تسجيل الدخول')),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('إدارة المواعيد'),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.event_busy),
              onPressed: _showBlockDateDialog,
              tooltip: 'حجب تواريخ محددة',
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info card
                    Card(
                      elevation: 0,
                      color: Colors.blue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blue.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'اضغط على الوقت لتفعيله أو إلغاء تفعيله. الأوقات المفعلة ستكون متاحة للحجز.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Session type tabs
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.grey.shade700,
                              indicator: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              tabs: const [
                                Tab(text: 'في المنزل'),
                                Tab(text: 'في المسجد'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: TabBarView(
                              children: [
                                _buildScheduleGrid('home'),
                                _buildScheduleGrid('mosque'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildScheduleGrid(String sessionType) {
    return SingleChildScrollView(
      child: Column(
        children: ScheduleConstants.timeSlots.map((slot) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${slot['start']} - ${slot['end']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (index) {
                      final dayOfWeek = index + 1; // 1 = Monday
                      final isEnabled = _isSlotEnabled(
                        dayOfWeek,
                        slot['start']!,
                        sessionType,
                      );

                      return GestureDetector(
                        onTap: () => _toggleTimeSlot(
                          dayOfWeek,
                          slot['start']!,
                          slot['end']!,
                          sessionType,
                        ),
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? Colors.green
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isEnabled
                                  ? Colors.green.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              ScheduleConstants.arabicDays[index].substring(0, 3),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isEnabled ? Colors.white : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Block Date Bottom Sheet
class BlockDateBottomSheet extends StatefulWidget {
  const BlockDateBottomSheet({super.key});

  @override
  State<BlockDateBottomSheet> createState() => _BlockDateBottomSheetState();
}

class _BlockDateBottomSheetState extends State<BlockDateBottomSheet> {
  final _reasonController = TextEditingController();
  DateTime? _selectedDate;
  bool _allDay = true;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _blockDate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedDate == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('unavailableDates')
          .add({
        'date': Timestamp.fromDate(_selectedDate!),
        'reason': _reasonController.text.trim(),
        'allDay': _allDay,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حجب التاريخ بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
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
              'حجب تاريخ محدد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('التاريخ'),
              subtitle: Text(
                _selectedDate != null
                    ? DateFormat('yyyy/MM/dd').format(_selectedDate!)
                    : 'لم يتم الاختيار',
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'السبب (اختياري)',
                hintText: 'مثال: إجازة، سفر',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('حجب اليوم بالكامل'),
              value: _allDay,
              onChanged: (value) {
                setState(() => _allDay = value);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedDate != null ? _blockDate : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('حجب التاريخ'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
