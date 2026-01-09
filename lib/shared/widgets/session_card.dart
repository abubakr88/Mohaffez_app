import 'package:flutter/material.dart';

class SessionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String location;
  final DateTime? dateTime;
  final String hifz;
  final String muraja;
  final int rating;
  final String notes;
  final Widget? trailing;

  const SessionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.location,
    this.dateTime,
    required this.hifz,
    required this.muraja,
    required this.rating,
    required this.notes,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = dateTime != null
        ? '${dateTime!.day}/${dateTime!.month}/${dateTime!.year} - ${dateTime!.hour.toString().padLeft(2, '0')}:${dateTime!.minute.toString().padLeft(2, '0')}'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.person, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            // Details
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
            // Assignments
            if (hifz.isNotEmpty || muraja.isNotEmpty) ...[
              const Divider(height: 16),
              if (hifz.isNotEmpty) ...[
                const Text(
                  'تكليف الحفظ:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(hifz, style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 8),
              ],
              if (muraja.isNotEmpty) ...[
                const Text(
                  'تكليف المراجعة:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(muraja, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ],
            // Rating
            if (rating > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'التقييم:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(
                    10,
                    (index) => Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      size: 14,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$rating/10',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
            // Notes
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'ملاحظات:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(notes, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
