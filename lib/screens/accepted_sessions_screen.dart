import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/widgets/session_card.dart';
import '../shared/widgets/empty_state.dart';

class AcceptedSessionsScreen extends StatelessWidget {
  const AcceptedSessionsScreen({super.key});

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
        appBar: AppBar(title: const Text('جلساتي المقبولة')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('hafizSessions')
              .where('studentId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'لا توجد جلسات مقبولة حاليًا',
                message: 'ابحث عن محفظ قريب واحجز جلسة',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final location = (data['location'] as String?) ?? '';
                final sessionType = (data['sessionType'] as String?) ?? '';
                final slotLabel =
                    (data['preferredTimeSlot'] as String?) ?? '';
                final mohaffezName = (data['mohaffezName'] as String?) ?? '';
                final slotStartTs = data['slotStart'] as Timestamp?;
                final sessionDateTs = data['sessionDate'] as Timestamp?;
                final slotStart = slotStartTs?.toDate();
                final baseDate = slotStart ?? sessionDateTs?.toDate();
                final lat = (data['imamAddressLat'] as num?)?.toDouble();
                final lng = (data['imamAddressLng'] as num?)?.toDouble();
                final phone = (data['mohaffezPhone'] as String?) ?? '';
                final hifz = data['hifzAssignment'] as String? ?? '';
                final muraja = data['murajaAssignment'] as String? ?? '';
                final rating = (data['sessionRating'] as num?)?.toInt() ?? 0;
                final notes = data['sessionNotes'] as String? ?? '';

                return SessionCard(
                  title: mohaffezName,
                  subtitle: (sessionType.isNotEmpty && slotLabel.isNotEmpty)
                      ? '$sessionType - $slotLabel'
                      : null,
                  location: location,
                  dateTime: baseDate,
                  hifz: hifz,
                  muraja: muraja,
                  rating: rating,
                  notes: notes,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (lat != null && lng != null)
                        TextButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                            );
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text('الموقع'),
                        ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('https://wa.me/$phone');
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: Icon(
                            Icons.phone,
                            color: Colors.green.shade600,
                            size: 16,
                          ),
                          label: const Text('اتصال'),
                        ),
                      ],
                    ],
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
