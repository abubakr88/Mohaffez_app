import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'pick_location_screen.dart';
import '../services/notification_service.dart';

class MohaffezHome extends StatelessWidget {
  const MohaffezHome({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: AppBar(
                title: const Text('لوحة المحفظ'),
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                bottom: const TabBar(
                  indicatorColor: AppTheme.accentGreen,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(icon: Icon(Icons.event_available), text: 'جلساتي القادمة'),
                    Tab(icon: Icon(Icons.pending_actions), text: 'الطلبات'),
                  ],
                ),
              ),
            ),
          ),
          body: const TabBarView(
            children: [
              MohaffezUpcomingSessions(),
              MohaffezRequestsList(),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AddSessionScreen(),
                ),
              );
            },
            child: const Icon(Icons.add),
            tooltip: 'إضافة جلسة جديدة',
          ),
        ),
      ),
    );
  }
}

// جلساتي القادمة (المقبولة فقط)
class MohaffezUpcomingSessions extends StatelessWidget {
  const MohaffezUpcomingSessions({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('mohaffezId', isEqualTo: uid)
          .where('sessionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .orderBy('sessionDate')
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
                    'لا توجد جلسات قادمة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اقبل طلبات الطلاب لتظهر هنا',
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
            final studentName = data['studentName'] as String? ?? '';
            final location = data['location'] as String? ?? '';
            final sessionType = data['sessionType'] as String? ?? '';
            final slotLabel = data['preferredTimeSlot'] as String? ?? '';
            final ts = data['sessionDate'] as Timestamp?;
            final date = ts?.toDate();
            final dateStr = date != null
                ? '${date.day}/${date.month}/${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                : '';
            final hifz = data['hifzAssignment'] as String? ?? '';
            final muraja = data['murajaAssignment'] as String? ?? '';
            final rating = (data['sessionRating'] as num?)?.toInt() ?? 0;
            final notes = data['sessionNotes'] as String? ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.accentGreen.withOpacity(0.2),
                          child: const Icon(
                            Icons.person,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                studentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (sessionType.isNotEmpty || slotLabel.isNotEmpty)
                                Text(
                                  '$sessionType - $slotLabel',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'مقبولة',
                            style: TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (location.isNotEmpty) ...[ 
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (hifz.isNotEmpty || muraja.isNotEmpty || notes.isNotEmpty) ...[
                      const Divider(height: 24),
                      if (hifz.isNotEmpty) ...[
                        const Text(
                          'ورد الحفظ:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
                            fontSize: 13,
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
                              'التقييم: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '$rating / 10',
                              style: TextStyle(
                                fontSize: 13,
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
                          'ملاحظات:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notes,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('حذف الجلسة'),
                              content: const Text('هل تريد حذف هذه الجلسة؟'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('إلغاء'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('حذف'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await docs[index].reference.delete();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم حذف الجلسة')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('حذف'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
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
}

// FIXED: Rating input using Slider widget with constraints 0-10
Future<Map<String, dynamic>?> _askAssignments(BuildContext context) async {
  final hifzCtrl = TextEditingController();
  final murajaCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  
  double ratingValue = 5.0; // Default rating

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('تكليفات الجلسة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: hifzCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ورد الحفظ (مثال: من أول البقرة إلى آية 25)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: murajaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ورد المراجعة',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  // FIXED: Use Slider instead of TextField for rating
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'تقييم الحفظ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ratingValue >= 7
                                  ? Colors.green.withOpacity(0.1)
                                  : ratingValue >= 5
                                      ? Colors.orange.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: ratingValue >= 7
                                    ? Colors.green
                                    : ratingValue >= 5
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                            ),
                            child: Text(
                              '${ratingValue.toInt()} / 10',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: ratingValue >= 7
                                    ? Colors.green
                                    : ratingValue >= 5
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: ratingValue >= 7
                              ? Colors.green
                              : ratingValue >= 5
                                  ? Colors.orange
                                  : Colors.red,
                          inactiveTrackColor: Colors.grey.shade300,
                          thumbColor: ratingValue >= 7
                              ? Colors.green
                              : ratingValue >= 5
                                  ? Colors.orange
                                  : Colors.red,
                          overlayColor: (ratingValue >= 7
                                  ? Colors.green
                                  : ratingValue >= 5
                                      ? Colors.orange
                                      : Colors.red)
                              .withOpacity(0.2),
                          valueIndicatorColor: ratingValue >= 7
                              ? Colors.green
                              : ratingValue >= 5
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                        child: Slider(
                          value: ratingValue,
                          min: 0,
                          max: 10,
                          divisions: 10,
                          label: ratingValue.toInt().toString(),
                          onChanged: (value) {
                            setDialogState(() {
                              ratingValue = value;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '0 (ضعيف)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '10 (ممتاز)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات عامة على الطالب',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop({
                    'hifzAssignment': hifzCtrl.text.trim(),
                    'murajaAssignment': murajaCtrl.text.trim(),
                    'sessionRating': ratingValue.toInt(),
                    'sessionNotes': notesCtrl.text.trim(),
                  });
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      );
    },
  );

  hifzCtrl.dispose();
  murajaCtrl.dispose();
  notesCtrl.dispose();

  return result;
}

class MohaffezRequestsList extends StatelessWidget {
  const MohaffezRequestsList({super.key});

  // FIXED: Proper null check with status rollback
  Future<void> updateStatus(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    String newStatus,
  ) async {
    try {
      final doc = await ref.get();
      final data = doc.data() ?? {};

      // Update status first
      await ref.update({'status': newStatus});

      if (newStatus == 'accepted') {
        final slotStartTs = data['slotStart'] as Timestamp?;
        final slotEndTs = data['slotEnd'] as Timestamp?;
        final createdAtTs = data['createdAt'] as Timestamp?;
        final sessionDateTs = slotStartTs ?? createdAtTs ?? Timestamp.now();

        // FIXED: Check for null and handle cancellation properly
        final assignments = await _askAssignments(context);
        
        // Early return if user cancels the dialog
        if (assignments == null) {
          // Revert status back to pending since user cancelled
          await ref.update({'status': 'pending'});
          
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إلغاء العملية')),
          );
          return;
        }

        // Proceed only if assignments are provided
        await FirebaseFirestore.instance.collection('hafizSessions').add({
          'mohaffezId': data['mohaffezId'],
          'studentId': data['studentId'],
          'studentName': data['studentName'],
          'mohaffezName': data['mohaffezName'],
          'location': data['imamAddressText'],
          'imamAddressLat': data['imamAddressLat'],
          'imamAddressLng': data['imamAddressLng'],
          'sessionDate': sessionDateTs,
          'sessionType': data['sessionType'],
          'preferredTimeSlot': data['preferredTimeSlot'],
          'createdAt': FieldValue.serverTimestamp(),
          'mohaffezPhone': data['mohaffezPhone'],
          'juzCount': 1,
          if (slotStartTs != null) 'slotStart': slotStartTs,
          if (slotEndTs != null) 'slotEnd': slotEndTs,
          'hifzAssignment': assignments['hifzAssignment'] ?? '',
          'murajaAssignment': assignments['murajaAssignment'] ?? '',
          'sessionRating': assignments['sessionRating'] ?? 0,
          'sessionNotes': assignments['sessionNotes'] ?? '',
        });

        // Send notification to student
        await NotificationService.notifyUser(
          userId: data['studentId'] as String,
          title: 'تم قبول طلب جلستك',
          body: '${data['mohaffezName'] ?? ''} - ${data['imamAddressText'] ?? ''}.',
          type: 'session',
          scheduleId: doc.id,
          mohaffezId: data['mohaffezId'] as String?,
          mohaffezName: data['mohaffezName'] as String?,
        );
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'accepted' 
                ? 'تم قبول الطلب وإضافته للجلسات القادمة' 
                : 'تم رفض الطلب',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e.toString()}')),
      );
    }
  }

  Color _statusColor(String status) {
    if (status == 'accepted') return Colors.green;
    if (status == 'rejected') return Colors.red;
    return Colors.orange;
  }

  String _statusLabel(String status) {
    if (status == 'accepted') return 'مقبول';
    if (status == 'rejected') return 'مرفوض';
    return 'قيد المراجعة';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('sessionRequests')
          .where('mohaffezId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        
        // Separate requests by status
        final pendingDocs = docs
            .where((doc) => (doc.data()['status'] as String?) == 'pending')
            .toList();
        final completedDocs = docs
            .where((doc) => (doc.data()['status'] as String?) != 'pending')
            .toList();

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد طلبات حاليًا',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (pendingDocs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  'طلبات جديدة (${pendingDocs.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              ...pendingDocs.map((doc) => _buildRequestCard(context, doc, true)),
              const SizedBox(height: 16),
            ],
            if (completedDocs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  'طلبات سابقة (${completedDocs.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              ...completedDocs.map((doc) => _buildRequestCard(context, doc, false)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool isPending,
  ) {
    final data = doc.data();
    final studentName = (data['studentName'] as String?) ?? '';
    final imamAddressText = (data['imamAddressText'] as String?) ?? '';
    final status = (data['status'] as String?) ?? 'pending';
    final sessionType = (data['sessionType'] as String?) ?? '';
    final slotLabel = (data['preferredTimeSlot'] as String?) ?? '';
    final createdTs = data['createdAt'] as Timestamp?;
    final createdDate = createdTs?.toDate();
    final createdStr = createdDate != null
        ? '${createdDate.day}/${createdDate.month}/${createdDate.year} ${createdDate.hour.toString().padLeft(2, '0')}:${createdDate.minute.toString().padLeft(2, '0')}'
        : '';

    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isPending ? 3 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isPending
                      ? Colors.orange.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  child: Icon(
                    Icons.person,
                    color: isPending ? Colors.orange : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (sessionType.isNotEmpty || slotLabel.isNotEmpty)
                        Text(
                          '$sessionType - $slotLabel',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (imamAddressText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      imamAddressText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (createdStr.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    createdStr,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => updateStatus(context, doc.reference, 'accepted'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('قبول'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => updateStatus(context, doc.reference, 'rejected'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('رفض'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Add Session Screen
class AddSessionScreen extends StatefulWidget {
  const AddSessionScreen({super.key});

  @override
  State<AddSessionScreen> createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  final locationController = TextEditingController();
  final juzCountController = TextEditingController();
  DateTime? selectedDate;
  double? lat;
  double? lng;

  Future<void> pickLocation() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const PickLocationScreen()),
    );

    if (result != null) {
      setState(() {
        locationController.text = result['locationName'] ?? '';
        lat = result['lat'] as double?;
        lng = result['lng'] as double?;
      });
    }
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  Future<void> saveSession() async {
    if (locationController.text.isEmpty ||
        juzCountController.text.isEmpty ||
        selectedDate == null ||
        lat == null ||
        lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال جميع البيانات المطلوبة')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection('hafizSessions').add({
      'mohaffezId': uid,
      'location': locationController.text,
      'juzCount': int.parse(juzCountController.text),
      'sessionDate': Timestamp.fromDate(selectedDate!),
      'lat': lat,
      'lng': lng,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إضافة الجلسة بنجاح')),
    );
  }

  @override
  void dispose() {
    locationController.dispose();
    juzCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إضافة جلسة جديدة')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: pickLocation,
                icon: const Icon(Icons.location_on),
                label: const Text('اختيار المكان'),
              ),
              if (locationController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(locationController.text),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: juzCountController,
                decoration: const InputDecoration(
                  labelText: 'عدد الأجزاء',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  selectedDate != null
                      ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                      : 'اختيار التاريخ',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: saveSession,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('حفظ الجلسة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
