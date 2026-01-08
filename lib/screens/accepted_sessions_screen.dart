import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/widgets/session_card.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/error_widgets.dart';

class AcceptedSessionsScreen extends StatefulWidget {
  const AcceptedSessionsScreen({super.key});

  @override
  State<AcceptedSessionsScreen> createState() => _AcceptedSessionsScreenState();
}

class _AcceptedSessionsScreenState extends State<AcceptedSessionsScreen> {
  // Add a key to force rebuild on retry
  int _rebuildKey = 0;

  void _retry() {
    setState(() {
      _rebuildKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول')),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الجلسات المقبولة'),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          key: ValueKey(_rebuildKey), // Force rebuild on retry
          stream: FirebaseFirestore.instance
              .collection('hafizSessions')
              .where('studentId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            // Show error if any
            if (snapshot.hasError) {
              return ErrorDisplay.dataLoad(
                onRetry: _retry,
              );
            }

            // Show shimmer while loading
            if (!snapshot.hasData) {
              return ShimmerWidgets.list(
                itemCount: 4,
                itemBuilder: () => ShimmerWidgets.listItem(
                  showAvatar: true,
                  lines: 3,
                ),
              );
            }

            final docs = snapshot.data!.docs;

            // Show empty state
            if (docs.isEmpty) {
              return const EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'لا توجد جلسات',
                message: 'لم تقبل أي جلسات بعد',
              );
            }

            // Show list of sessions
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final location = data['location'] as String? ?? '';
                final sessionType = data['sessionType'] as String? ?? '';
                final slotLabel = data['preferredTimeSlot'] as String? ?? '';
                final mohaffezName = data['mohaffezName'] as String? ?? '';
                final slotStartTs = data['slotStart'] as Timestamp?;
                final sessionDateTs = data['sessionDate'] as Timestamp?;
                final slotStart = slotStartTs?.toDate();
                final baseDate = slotStart ?? sessionDateTs?.toDate();
                final lat = (data['imamAddressLat'] as num?)?.toDouble();
                final lng = (data['imamAddressLng'] as num?)?.toDouble();
                final phone = data['mohaffezPhone'] as String? ?? '';
                final hifz = data['hifzAssignment'] as String? ?? '';
                final muraja = data['murajaAssignment'] as String? ?? '';
                final rating = (data['sessionRating'] as num?)?.toInt() ?? 0;
                final notes = data['sessionNotes'] as String? ?? '';

                return SessionCard(
                  title: mohaffezName,
                  subtitle: sessionType.isNotEmpty && slotLabel.isNotEmpty
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
                      // Map button
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
                          label: const Text('خريطة'),
                        ),

                      // WhatsApp button
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
                          label: const Text('واتساب'),
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
