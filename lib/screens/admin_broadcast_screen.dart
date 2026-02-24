import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/system_config_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../utils/arabic_labels.dart';

class AdminBroadcastScreen extends ConsumerStatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  ConsumerState<AdminBroadcastScreen> createState() =>
      _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends ConsumerState<AdminBroadcastScreen> {
  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  String targetRole = 'all';

  @override
  void dispose() {
    titleCtrl.dispose();
    bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    await ref
        .read(systemConfigNotifierProvider.notifier)
        .sendBroadcastNotification(
            titleCtrl.text.trim(), bodyCtrl.text.trim(), targetRole);

    final st = ref.read(systemConfigNotifierProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            st.hasError ? AppThemeConstants.error : AppThemeConstants.success,
        content: Text(
            st.hasError ? st.error.toString() : ArabicLabels.operationSuccess),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(systemConfigNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text(ArabicLabels.broadcastNotifications)),
        body: Padding(
          padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                      labelText: ArabicLabels.notificationTitle)),
              const SizedBox(height: AppThemeConstants.spaceSm),
              TextField(
                controller: bodyCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: ArabicLabels.notificationBody),
              ),
              const SizedBox(height: AppThemeConstants.spaceSm),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text(ArabicLabels.all)),
                  ButtonSegment(
                      value: 'student', label: Text(ArabicLabels.students)),
                  ButtonSegment(
                      value: 'mohaffez', label: Text(ArabicLabels.mohaffezin)),
                ],
                selected: {targetRole},
                onSelectionChanged: (v) => setState(() => targetRole = v.first),
              ),
              const SizedBox(height: AppThemeConstants.spaceSm),
              ElevatedButton.icon(
                onPressed: actionState.isLoading ? null : _send,
                icon: actionState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text(ArabicLabels.send),
              ),
              const SizedBox(height: AppThemeConstants.spaceMd),
              const Text(ArabicLabels.sendHistory,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppThemeConstants.spaceSm),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('broadcastHistory')
                      .orderBy('sentAt', descending: true)
                      .snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d = docs[i].data();
                        final sentAt = d['sentAt'];
                        return Card(
                          child: ListTile(
                            title: Text(d['title']?.toString() ?? '-'),
                            subtitle: Text(
                              '${ArabicLabels.filterByRole}: ${d['targetRole'] ?? 'all'}\n'
                              '${ArabicLabels.sentToCount} ${d['recipientCount'] ?? 0} ${ArabicLabels.recipients}\n'
                              '${ArabicLabels.operationAt}: ${sentAt is Timestamp ? sentAt.toDate().toString().split('.').first : '-'}',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
