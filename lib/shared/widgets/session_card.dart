import 'package:flutter/material.dart';
import '../utils/date_utils.dart';

class SessionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? location;
  final DateTime? dateTime;
  final String? hifz;
  final String? muraja;
  final int? rating;
  final String? notes;
  final Widget? trailing;

  const SessionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.location,
    this.dateTime,
    this.hifz,
    this.muraja,
    this.rating,
    this.notes,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        dateTime != null ? AppDateUtils.formatDateTime(dateTime!) : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            if (location != null && location!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (dateStr != null && dateStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 14, color: Colors.grey),
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
            if ((hifz?.isNotEmpty ?? false) ||
                (muraja?.isNotEmpty ?? false) ||
                (rating != null && rating! > 0) ||
                (notes?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              const Divider(height: 16),
            ],
            if (hifz != null && hifz!.isNotEmpty) ...[
              const Text(
                'الحفظ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hifz!,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            if (muraja != null && muraja!.isNotEmpty) ...[
              const Text(
                'المراجعة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                muraja!,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            if (rating != null && rating! > 0) ...[
              Row(
                children: [
                  const Text(
                    'التقييم: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$rating/10',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: rating! >= 7
                          ? Colors.green
                          : rating! >= 5
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (notes != null && notes!.isNotEmpty) ...[
              const Text(
                'ملاحظات',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notes!,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
