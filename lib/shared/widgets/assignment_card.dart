import 'package:flutter/material.dart';

class AssignmentCard extends StatelessWidget {
  final String mohaffezName;
  final String location;
  final String sessionType;
  final String slotLabel;
  final DateTime? sessionDate;
  final String hifz;
  final String muraja;
  final int rating;
  final String notes;

  const AssignmentCard({
    super.key,
    required this.mohaffezName,
    required this.location,
    required this.sessionType,
    required this.slotLabel,
    this.sessionDate,
    required this.hifz,
    required this.muraja,
    required this.rating,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = sessionDate != null
        ? '${sessionDate!.day}/${sessionDate!.month}/${sessionDate!.year}'
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Mohaffez name
            Row(
              children: [
                const Icon(Icons.person, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    mohaffezName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),

            // Session details
            if (sessionType.isNotEmpty || slotLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '$sessionType - $slotLabel',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            if (location.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                location,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'تاريخ الجلسة: $dateStr',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],

            const Divider(height: 16),

            // Hifz assignment
            if (hifz.isNotEmpty) ...[
              const Text(
                'ورد الحفظ:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  hifz,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Muraja assignment
            if (muraja.isNotEmpty) ...[
              const Text(
                'ورد المراجعة:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  muraja,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Rating
            if (rating > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getRatingColor(rating).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getRatingColor(rating).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getRatingIcon(rating),
                      color: _getRatingColor(rating),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'تقييم الحفظ: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$rating / 10',
                      style: TextStyle(
                        fontSize: 14,
                        color: _getRatingColor(rating),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Notes
            if (notes.isNotEmpty) ...[
              const Text(
                'ملاحظات الشيخ:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  notes,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRatingColor(int rating) {
    if (rating >= 7) return Colors.green;
    if (rating >= 5) return Colors.orange;
    return Colors.red;
  }

  IconData _getRatingIcon(int rating) {
    if (rating >= 7) return Icons.sentiment_very_satisfied;
    if (rating >= 5) return Icons.sentiment_neutral;
    return Icons.sentiment_dissatisfied;
  }
}
