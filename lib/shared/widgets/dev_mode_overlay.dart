import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dev_mode_model.dart';
import '../../providers/system_config_provider.dart';
import '../../providers/user_provider.dart';
import '../theme/app_theme_constants.dart';

class DevModeOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const DevModeOverlay({super.key, required this.child});

  @override
  ConsumerState<DevModeOverlay> createState() => _DevModeOverlayState();
}

class _DevModeOverlayState extends ConsumerState<DevModeOverlay> {
  Offset fabOffset = const Offset(16, 560);

  @override
  Widget build(BuildContext context) {
    final devMode =
        ref.watch(devModeProvider).valueOrNull ?? DevModeModel.defaults();
    final user = ref.watch(currentUserProvider).valueOrNull;
    // ignore: unnecessary_null_comparison
    final isDevActive = devMode != null &&
        devMode.devModeEnabled &&
        user != null &&
        devMode.devModeUsers.contains(user.uid);
    final showOverlay = isDevActive && devMode.showDebugOverlay;
    final showChip = devMode.devModeEnabled;

    // ✅ FIX: Wrap Stack with Directionality because DevModeOverlay sits
    // above MaterialApp in the tree, so no Directionality ancestor exists yet.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          widget.child,
          if (showOverlay)
            Positioned(
              left: fabOffset.dx,
              top: fabOffset.dy,
              child: Draggable(
                feedback: _fab(context),
                childWhenDragging: const SizedBox.shrink(),
                onDragEnd: (details) =>
                    setState(() => fabOffset = details.offset),
                child: _fab(context),
              ),
            ),
          if (showChip)
            const Positioned(
              top: AppThemeConstants.spaceSm,
              right: AppThemeConstants.spaceSm,
              child: SafeArea(
                child: Chip(
                  backgroundColor: AppThemeConstants.warning,
                  label: Text(
                    'DEV',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fab(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppThemeConstants.primaryAmber,
      onPressed: () => _openDevSheet(context),
      child: const Icon(Icons.bug_report),
    );
  }

  Future<void> _openDevSheet(BuildContext context) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    final devMode = ref.read(devModeProvider).valueOrNull;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final activeFlags = <String>[];
        if (devMode?.bypassPayment == true) activeFlags.add('bypassPayment');
        if (devMode?.bypassPromoValidation == true) {
          activeFlags.add('bypassPromoValidation');
        }
        if (devMode?.bypassSlotLock == true) activeFlags.add('bypassSlotLock');
        if (devMode?.mockNotifications == true) {
          activeFlags.add('mockNotifications');
        }
        if (devMode?.skipAppVersionCheck == true) {
          activeFlags.add('skipAppVersionCheck');
        }
        if (devMode?.fakeGpsEnabled == true) activeFlags.add('fakeGpsEnabled');

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المستخدم: ${user?.uid ?? '-'}'),
                Text('الدور: ${user?.role ?? '-'}'),
                const SizedBox(height: AppThemeConstants.spaceSm),
                Text(
                  'الأوضاع النشطة: ${activeFlags.isEmpty ? 'لا شيء' : activeFlags.join(', ')}',
                ),
                const SizedBox(height: AppThemeConstants.spaceMd),
                if (devMode?.logAllFirestoreWrites == true)
                  SizedBox(
                    height: 200,
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('devLogs')
                          .orderBy('timestamp', descending: true)
                          .limit(5)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final docs = snapshot.data!.docs;
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (_, i) {
                            final data = docs[i].data();
                            return ListTile(
                              dense: true,
                              title: Text(
                                data['action']?.toString() ?? 'log',
                              ),
                              subtitle: Text(
                                data['timestamp']?.toString() ?? '',
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: AppThemeConstants.spaceSm),
                ElevatedButton(
                  onPressed: () async {
                    final ctx = context;
                    try {
                      final logs = await FirebaseFirestore.instance
                          .collection('devLogs')
                          .get();
                      final batch = FirebaseFirestore.instance.batch();
                      for (final d in logs.docs) {
                        batch.delete(d.reference);
                      }
                      await batch.commit();
                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                    } catch (e) {
                      debugPrint('⚠️ Failed to clear dev logs: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.error,
                  ),
                  child: const Text('مسح السجلات'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
