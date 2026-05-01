import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mohaffez_core/src/providers/system_config_provider.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/widgets/admin_app_bar.dart';
import 'package:mohaffez_core/src/utils/arabic_labels.dart';

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
  int? _audienceCount;
  bool _isLoadingCount = false;

  @override
  void dispose() {
    titleCtrl.dispose();
    bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAudienceCount() async {
    setState(() => _isLoadingCount = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getBroadcastAudienceCount');
      final result = await callable.call({'targetRole': targetRole});
      if (mounted) {
        setState(() {
          _audienceCount = result.data['count'] as int;
          _isLoadingCount = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _audienceCount = null;
          _isLoadingCount = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppThemeConstants.error,
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  Future<void> _send(int recipientCount) async {
    await ref
        .read(systemConfigNotifierProvider.notifier)
        .sendBroadcastNotification(
            titleCtrl.text.trim(), bodyCtrl.text.trim(), targetRole);

    final st = ref.read(systemConfigNotifierProvider);
    if (!mounted) return;

    if (st.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text(st.error.toString()),
        ),
      );
    } else {
      // Show success modal bottom sheet
      await showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: AppThemeConstants.success,
                size: 64,
              ),
              const SizedBox(height: AppThemeConstants.spaceMd),
              Text(
                'تم الإرسال بنجاح إلى $recipientCount مستخدم 🎉',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppThemeConstants.spaceMd),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(ArabicLabels.close),
              ),
            ],
          ),
        ),
      );
      // Clear form after success
      titleCtrl.clear();
      bodyCtrl.clear();
    }
  }

  Future<void> _showConfirmDialog() async {
    if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('يرجى إدخال عنوان ونص الإشعار'),
        ),
      );
      return;
    }

    final recipientCount = _audienceCount ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد إرسال الإشعار'),
        content: Text(
          'سيتم إرسال "${titleCtrl.text.trim()}" إلى $recipientCount مستخدم. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(ArabicLabels.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إرسال الآن'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _send(recipientCount);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAudienceCount();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(systemConfigNotifierProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: ArabicLabels.broadcastNotifications),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
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
                    onSelectionChanged: (v) {
                      setState(() => targetRole = v.first);
                      _fetchAudienceCount();
                    },
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  // Audience count preview
                  if (_isLoadingCount)
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_audienceCount != null)
                    Text(
                      'سيصل الإشعار إلى $_audienceCount مستخدم',
                      style: const TextStyle(
                        color: AppThemeConstants.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: AppThemeConstants.spaceSm),
                  ElevatedButton.icon(
                    onPressed: actionState.isLoading ? null : _showConfirmDialog,
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
                ]),
              ),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('broadcastHistory')
                      .orderBy('sentAt', descending: true)
                      .snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData) {
                      return const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs = snap.data!.docs;
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final d = docs[i].data();
                          final sentAt = d['sentAt'];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppThemeConstants.spaceMd,
                              vertical: AppThemeConstants.spaceXs,
                            ),
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
                        childCount: docs.length,
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}


