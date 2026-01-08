import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/widgets/session_card.dart';
import '../shared/widgets/empty_state.dart';
import '../main.dart';
import '../shared/constants/app_theme.dart';

class MohaffezHome extends StatefulWidget {
  const MohaffezHome({super.key});

  @override
  State<MohaffezHome> createState() => _MohaffezHomeState();
}

class _MohaffezHomeState extends State<MohaffezHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('صفحة المحفظ'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'طلبات الجلسات'),
              Tab(text: 'الجلسات المقبولة'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSessionRequestsTab(user.uid),
            _buildAcceptedSessionsTab(user.uid),
          ],
        ),
      ),
    );
  }

  // Tab 1: Session Requests
  Widget _buildSessionRequestsTab(String mohaffezId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('sessionRequests')
          .where('mohaffezId', isEqualTo: mohaffezId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'لا توجد طلبات جديدة',
            message: 'ستظهر هنا طلبات الحجز من الطلاب',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final studentName = data['studentName'] as String? ?? '';
            final sessionType = data['sessionType'] as String? ?? '';
            final timeSlot = data['preferredTimeSlot'] as String? ?? '';
            final slotStartTs = data['slotStart'] as Timestamp?;
            final slotStart = slotStartTs?.toDate();
            final location = data['imamAddressText'] as String? ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
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
                            studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (sessionType.isNotEmpty || timeSlot.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$sessionType - $timeSlot',
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
                          const Icon(Icons.location_on,
                              size: 14, color: Colors.grey),
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
                    if (slotStart != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${slotStart.day}/${slotStart.month}/${slotStart.year} ${slotStart.hour.toString().padLeft(2, '0')}:${slotStart.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _rejectRequest(doc.id),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('رفض'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _acceptRequest(context, doc.id, data),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('قبول'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentGreen,
                            ),
                          ),
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
    );
  }

  // Tab 2: Accepted Sessions
  Widget _buildAcceptedSessionsTab(String mohaffezId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('mohaffezId', isEqualTo: mohaffezId)
          .orderBy('sessionDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.school_outlined,
            title: 'لا توجد جلسات مقبولة',
            message: 'ستظهر هنا الجلسات بعد قبول طلبات الطلاب',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final studentName = data['studentName'] as String? ?? '';
            final location = data['location'] as String? ?? '';
            final sessionType = data['sessionType'] as String? ?? '';
            final slotLabel = data['preferredTimeSlot'] as String? ?? '';
            final sessionDateTs = data['sessionDate'] as Timestamp?;
            final sessionDate = sessionDateTs?.toDate();
            final lat = (data['imamAddressLat'] as num?)?.toDouble();
            final lng = (data['imamAddressLng'] as num?)?.toDouble();
            final hifz = data['hifzAssignment'] as String? ?? '';
            final muraja = data['murajaAssignment'] as String? ?? '';
            final rating = (data['sessionRating'] as num?)?.toInt() ?? 0;
            final notes = data['sessionNotes'] as String? ?? '';

            return SessionCard(
              title: studentName,
              subtitle: (sessionType.isNotEmpty && slotLabel.isNotEmpty)
                  ? '$sessionType - $slotLabel'
                  : null,
              location: location,
              dateTime: sessionDate,
              hifz: hifz,
              muraja: muraja,
              rating: rating,
              notes: notes,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showAssignmentDialog(context, doc.id, data),
                    tooltip: 'تعديل التكليف',
                  ),
                  if (lat != null && lng != null)
                    IconButton(
                      icon: const Icon(Icons.map, size: 20),
                      onPressed: () async {
                        final uri = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                        );
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      },
                      tooltip: 'عرض الموقع',
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('sessionRequests')
          .doc(requestId)
          .update({'status': 'rejected'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الطلب')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  Future<void> _acceptRequest(
    BuildContext context,
    String requestId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Create accepted session
      final sessionRef =
          FirebaseFirestore.instance.collection('hafizSessions').doc();

      await sessionRef.set({
        'mohaffezId': data['mohaffezId'],
        'studentId': data['studentId'],
        'mohaffezName': data['mohaffezName'],
        'studentName': data['studentName'],
        'sessionType': data['sessionType'],
        'location': data['imamAddressText'] ?? '',
        'mohaffezPhone': data['mohaffezPhone'],
        'imamAddressLat': data['imamAddressLat'],
        'imamAddressLng': data['imamAddressLng'],
        'preferredTimeSlot': data['preferredTimeSlot'],
        'sessionDate': data['slotStart'],
        'slotStart': data['slotStart'],
        'slotEnd': data['slotEnd'],
        'createdAt': FieldValue.serverTimestamp(),
        'juzCount': 1,
        'hifzAssignment': '',
        'murajaAssignment': '',
        'sessionRating': 0,
        'sessionNotes': '',
      });

      // Update request status
      await FirebaseFirestore.instance
          .collection('sessionRequests')
          .doc(requestId)
          .update({'status': 'accepted'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول الطلب بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  void _showAssignmentDialog(
    BuildContext context,
    String sessionId,
    Map<String, dynamic> currentData,
  ) {
    final hifzController = TextEditingController(
      text: currentData['hifzAssignment'] as String? ?? '',
    );
    final murajaController = TextEditingController(
      text: currentData['murajaAssignment'] as String? ?? '',
    );
    final notesController = TextEditingController(
      text: currentData['sessionNotes'] as String? ?? '',
    );
    int rating = (currentData['sessionRating'] as num?)?.toInt() ?? 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('تكليف الطالب'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: hifzController,
                        decoration: const InputDecoration(
                          labelText: 'ورد الحفظ',
                          hintText: 'مثال: من آية 1 إلى آية 10 من سورة البقرة',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: murajaController,
                        decoration: const InputDecoration(
                          labelText: 'ورد المراجعة',
                          hintText: 'مثال: سورة الفاتحة كاملة',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      const Text('تقييم الحفظ:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(10, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                rating = index + 1;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: rating >= index + 1
                                    ? AppTheme.accentGreen
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: rating >= index + 1
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('hafizSessions')
                          .doc(sessionId)
                          .update({
                        'hifzAssignment': hifzController.text.trim(),
                        'murajaAssignment': murajaController.text.trim(),
                        'sessionRating': rating,
                        'sessionNotes': notesController.text.trim(),
                      });

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم حفظ التكليف بنجاح')),
                        );
                      }
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
