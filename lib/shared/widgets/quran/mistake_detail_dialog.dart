import 'package:flutter/material.dart';

import '../../../models/quran_mistake_model.dart';
import '../../../utils/quran_mistake_utils.dart';

Future<void> showMistakeDetailDialog(
  BuildContext context,
  QuranMistake mistake, {
  required bool isEditable,
}) {
  final hasComment = mistake.correctionNote != null && mistake.correctionNote!.isNotEmpty;

  Widget detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: getMistakeColor(mistake.type).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                getMistakeIcon(mistake.type),
                color: getMistakeColor(mistake.type),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mistake.type.fullLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: getMistakeColor(mistake.type),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            detailRow(Icons.menu_book, 'الصفحة', '${mistake.pageNumber}'),
            detailRow(Icons.format_list_numbered, 'الآية', '${mistake.ayahNumber}'),
            if (mistake.wordText != null && mistake.wordText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'الكلمة / الموضع',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  mistake.wordText!,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (hasComment) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.chat_bubble, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'تعليق المعلم',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  mistake.correctionNote!,
                  style: TextStyle(fontSize: 14, color: Colors.blue.shade900, height: 1.6),
                ),
              ),
            ],
            if (!hasComment && isEditable) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text(
                    'لا يوجد تعليق لهذا الخطأ',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    ),
  );
}
