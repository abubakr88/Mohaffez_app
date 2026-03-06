import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/admin_app_bar.dart';
import '../utils/arabic_labels.dart';

class AdminSlotLocksScreen extends ConsumerWidget {
  const AdminSlotLocksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          data: (list) => ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final l = list[i];
              return Card(
                margin: const EdgeInsets.all(AppThemeConstants.spaceSm),
                child: ListTile(
                  title:
                      Text('${ArabicLabels.slotOf}: ${l['mohaffezId'] ?? '-'}'),
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


