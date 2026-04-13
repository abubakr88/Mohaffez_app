import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/admin_app_bar.dart';
import '../shared/widgets/admin_empty_state.dart';
import '../utils/arabic_labels.dart';

/// Cache for user names to avoid repeated fetches
final _userNameCache = <String, String>{};

class AdminSlotLocksScreen extends ConsumerStatefulWidget {
  const AdminSlotLocksScreen({super.key});

  @override
  ConsumerState<AdminSlotLocksScreen> createState() => _AdminSlotLocksScreenState();
}

class _AdminSlotLocksScreenState extends ConsumerState<AdminSlotLocksScreen> {
  final Map<String, String> _userNames = {};

  Future<String> _getUserName(String userId) async {
    // Check cache first
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    // Check local state
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }
    // Fetch from Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final name = doc.data()?['displayName'] ??
          doc.data()?['name'] ??
          doc.data()?['email'] ??
          userId.substring(0, 8);
      _userNameCache[userId] = name;
      if (mounted) {
        setState(() => _userNames[userId] = name);
      }
      return name;
    } catch (e) {
      return userId.substring(0, 8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locks = ref.watch(activeSlotLocksProvider);
    final actions = ref.read(adminActionsProvider.notifier);

    Future<void> run(Future<void> Function() op) async {
      await op();
      final st = ref.read(adminActionsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              st.hasError ? AppThemeConstants.error : AppThemeConstants.success,
          content: Text(st.hasError
              ? st.error.toString()
              : ArabicLabels.operationSuccess),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: ArabicLabels.slotLocksManagement),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppThemeConstants.primaryAmber,
          onPressed: () => run(actions.releaseAllExpiredLocks),
          label: const Text(ArabicLabels.releaseExpiredLocks),
          icon: const Icon(Icons.lock_open),
        ),
        body: locks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (list) => list.isEmpty
              ? const AdminEmptyState(
                  icon: Icons.lock_open_outlined,
                  message: 'لا توجد أقفال نشطة',
                )
              : ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final l = list[i];
              final mohaffezId = l['mohaffezId']?.toString() ?? '';
              final cachedName = _userNames[mohaffezId];

              // Fetch name if not cached
              if (cachedName == null && mohaffezId.isNotEmpty) {
                _getUserName(mohaffezId).then((name) {
                  if (mounted) setState(() => _userNames[mohaffezId] = name);
                });
              }

              return Card(
                margin: const EdgeInsets.all(AppThemeConstants.spaceSm),
                child: ListTile(
                  title: Row(
                    children: [
                      Text('${ArabicLabels.slotOf}: '),
                      Expanded(
                        child: Text(
                          cachedName ?? mohaffezId.substring(0, 8),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (cachedName == null)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  subtitle: Text(
                      '${ArabicLabels.time}: ${l['timeSlot'] ?? '-'}\n${ArabicLabels.type}: ${l['sessionType'] ?? '-'}'),
                  trailing: _Countdown(expiresAt: l['expiresAt']),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Countdown extends StatefulWidget {
  final dynamic expiresAt;
  const _Countdown({required this.expiresAt});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late Timer _timer;
  Duration remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final ts = widget.expiresAt;
    final end = ts is Timestamp ? ts.toDate() : DateTime.now();
    setState(() => remaining = end.difference(DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = remaining.inSeconds;
    if (s <= 0) return const Text(ArabicLabels.expired);
    return Text(
        '${remaining.inMinutes}:${(s % 60).toString().padLeft(2, '0')}');
  }
}


