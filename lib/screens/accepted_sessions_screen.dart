import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';

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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد جلسات مقبولة حاليًا',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ابحث عن محفظ قريب واحجز جلسة',
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
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final location = (data['location'] as String?) ?? '';
                final sessionType =
                    (data['sessionType'] as String?) ?? '';
                final slotLabel =
                    (data['preferredTimeSlot'] as String?) ?? '';
                final mohaffezName =
                    (data['mohaffezName'] as String?) ?? '';
                final slotStartTs = data['slotStart'] as Timestamp?;
                final sessionDateTs =
                    data['sessionDate'] as Timestamp?;
                final slotStart = slotStartTs?.toDate();
                final baseDate = slotStart ?? sessionDateTs?.toDate();
                final dateStr = baseDate != null
                    ? '${baseDate.day}/${baseDate.month}/${baseDate.year} ${baseDate.hour.toString().padLeft(2, '0')}:${baseDate.minute.toString().padLeft(2, '0')}'
                    : '';
                final lat =
                    (data['imamAddressLat'] as num?)?.toDouble();
                final lng =
                    (data['imamAddressLng'] as num?)?.toDouble();
                final phone = (data['mohaffezPhone'] as String?) ?? '';
                final hifz =
                    data['hifzAssignment'] as String? ?? '';
                final muraja =
                    data['murajaAssignment'] as String? ?? '';
                final rating =
                    (data['sessionRating'] as num?)?.toInt() ?? 0;
                final notes =
                    data['sessionNotes'] as String? ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
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
                        const SizedBox(height: 4),
                        Text(
                          '$sessionType - $slotLabel',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey,
                              ),
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
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey,
                              ),
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
                        const SizedBox(height: 8),
                        if (hifz.isNotEmpty)
                          Text('ورد الحفظ: $hifz'),
                        if (muraja.isNotEmpty)
                          Text('ورد المراجعة: $muraja'),
                        Text('تقييم الحفظ: $rating / 10'),
                        if (notes.isNotEmpty)
                          Text('ملاحظات الشيخ: $notes'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (lat != null && lng != null)
                              TextButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse(
                                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                                  );
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode
                                        .externalApplication,
                                  );
                                },
                                icon: const Icon(Icons.map),
                                label: const Text('الموقع'),
                              ),
                            const SizedBox(width: 8),
                            if (phone.isNotEmpty)
                              TextButton.icon(
                                onPressed: () async {
                                  final uri =
                                      Uri.parse('https://wa.me/$phone');
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode
                                        .externalApplication,
                                  );
                                },
                                icon: Icon(
                                  Icons.phone,
                                  color: Colors.green.shade600,
                                ),
                                label: const Text('الاتصال'),
                              ),
                          ],
                        ),
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
