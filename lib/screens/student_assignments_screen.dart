import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAssignmentsScreen extends StatelessWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('يجب تسجيل الدخول أولاً')),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تكليفات الحفظ والمراجعة')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('hafizSessions')
              .where('studentId', isEqualTo: user.uid)
              .orderBy('sessionDate', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            
            // Filter docs with assignments
            final assignmentDocs = docs.where((doc) {
              final data = doc.data();
              final hifz = (data['hifzAssignment'] as String?) ?? '';
              final muraja = (data['murajaAssignment'] as String?) ?? '';
              final rating = (data['sessionRating'] as num?)?.toInt() ?? 0;
              final notes = (data['sessionNotes'] as String?) ?? '';
              return hifz.isNotEmpty || muraja.isNotEmpty || rating > 0 || notes.isNotEmpty;
            }).toList();

            if (assignmentDocs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد تكليفات حالياً',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'سيظهر هنا ورد الحفظ والمراجعة بعد جلستك الأولى',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: assignmentDocs.length,
              itemBuilder: (context, index) {
                final data = assignmentDocs[index].data();
                final mohaffezName =
                    (data['mohaffezName'] as String?) ?? '';
                final location =
                    (data['location'] as String?) ?? '';
                final sessionType =
                    (data['sessionType'] as String?) ?? '';
                final slotLabel =
                    (data['preferredTimeSlot'] as String?) ?? '';
                final ts = data['sessionDate'] as Timestamp?;
                final date = ts?.toDate();
                final dateStr = date != null
                    ? '${date.day}/${date.month}/${date.year}'
                    : '';
                final hifz =
                    (data['hifzAssignment'] as String?) ?? '';
                final muraja =
                    (data['murajaAssignment'] as String?) ?? '';
                final rating =
                    (data['sessionRating'] as num?)?.toInt() ?? 0;
                final notes =
                    (data['sessionNotes'] as String?) ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
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
                        if (sessionType.isNotEmpty ||
                            slotLabel.isNotEmpty) ...[
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
                        if (hifz.isNotEmpty) ...[
                          const Text(
                            'ورد الحفظ:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hifz,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (muraja.isNotEmpty) ...[
                          const Text(
                            'ورد المراجعة:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            muraja,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (rating > 0) ...[
                          Row(
                            children: [
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
                                  color: rating >= 7
                                      ? Colors.green
                                      : rating >= 5
                                          ? Colors.orange
                                          : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (notes.isNotEmpty) ...[
                          const Text(
                            'ملاحظات الشيخ:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notes,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
