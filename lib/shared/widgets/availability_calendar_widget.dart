import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

class AvailabilityCalendarWidget extends StatelessWidget {
  final String mohaffezId;
  final int daysToShow;

  const AvailabilityCalendarWidget({
    super.key,
    required this.mohaffezId,
    this.daysToShow = 7,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(
      daysToShow,
      (index) => now.add(Duration(days: index)),
    );

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final date = days[index];
          return _DayAvailabilityCard(
            mohaffezId: mohaffezId,
            date: date,
          );
        },
      ),
    );
  }
}

class _DayAvailabilityCard extends StatelessWidget {
  final String mohaffezId;
  final DateTime date;

  const _DayAvailabilityCard({
    required this.mohaffezId,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final dayOfWeek = date.weekday - 1; // 1 = Monday
    final isToday = DateUtils.isSameDay(date, DateTime.now());

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(mohaffezId)
          .collection('availability')
          .where('dayOfWeek', isEqualTo: dayOfWeek)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        int availableSlots = 0;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final timeSlots = List<Map<String, dynamic>>.from(
            data['timeSlots'] ?? [],
          );
          
          // Count enabled slots that are in the future (if today)
          availableSlots = timeSlots.where((slot) {
            if (!slot['enabled']) return false;
            
            if (isToday) {
              final startTime = slot['startTime'] as String;
              final parts = startTime.split(':');
              final slotDateTime = DateTime(
                date.year,
                date.month,
                date.day,
                int.parse(parts[0]),
                int.parse(parts[1]),
              );
              return slotDateTime.isAfter(DateTime.now());
            }
            
            return true;
          }).length;
        }

        return Container(
          width: 100,
          margin: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isToday ? Colors.blue : Colors.grey.shade300,
              width: isToday ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _getArabicDayName(dayOfWeek),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isToday ? Colors.blue : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM').format(date),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: availableSlots > 0
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      availableSlots > 0 ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: availableSlots > 0 ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      availableSlots > 0 ? '$availableSlots متاح' : 'غير متاح',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: availableSlots > 0
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getArabicDayName(int dayOfWeek) {
    const days = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return days[dayOfWeek - 1];
  }
}
