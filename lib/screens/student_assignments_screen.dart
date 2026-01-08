import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/widgets/assignment_card.dart';
import '../shared/widgets/empty_state.dart';

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
              return hifz.isNotEmpty ||
                  muraja.isNotEmpty ||
                  rating > 0 ||
                  notes.isNotEmpty;
            }).toList();

            if (assignmentDocs.isEmpty) {
              return const EmptyState(
                icon: Icons.assignment_outlined,
                title: 'لا توجد تكليفات حالياً',
                message: 'سيظهر هنا ورد الحفظ والمراجعة بعد جلستك الأولى',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: assignmentDocs.length,
              itemBuilder: (context, index) {
                final data = assignmentDocs[index].data();
                final mohaffezName = (data['mohaffezName'] as String?) ?? '';
                final location = (data['location'] as String?) ?? '';
                final sessionType = (data['sessionType'] as String?) ?? '';
                final slotLabel =
                    (data['preferredTimeSlot'] as String?) ?? '';
                final ts = data['sessionDate'] as Timestamp?;
                final date = ts?.toDate();
                final hifz = (data['hifzAssignment'] as String?) ?? '';
                final muraja = (data['murajaAssignment'] as String?) ?? '';
                final rating = (data['sessionRating'] as num?)?.toInt() ?? 0;
                final notes = (data['sessionNotes'] as String?) ?? '';

                return AssignmentCard(
                  mohaffezName: mohaffezName,
                  location: location,
                  sessionType: sessionType,
                  slotLabel: slotLabel,
                  sessionDate: date,
                  hifz: hifz,
                  muraja: muraja,
                  rating: rating,
                  notes: notes,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
