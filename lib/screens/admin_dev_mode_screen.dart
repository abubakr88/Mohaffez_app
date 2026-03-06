import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dev_mode_model.dart';
import '../providers/system_config_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/admin_app_bar.dart';
import '../utils/arabic_labels.dart';

class AdminDevModeScreen extends ConsumerStatefulWidget {
  const AdminDevModeScreen({super.key});

  @override
  ConsumerState<AdminDevModeScreen> createState() => _AdminDevModeScreenState();
}

class _AdminDevModeScreenState extends ConsumerState<AdminDevModeScreen> {
  final uidCtrl = TextEditingController();
  final latCtrl = TextEditingController();
  final lngCtrl = TextEditingController();
  final updates = <String, dynamic>{};

  @override
  void dispose() {
    uidCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(systemConfigNotifierProvider.notifier)
        .updateDevMode(updates);
    final st = ref.read(systemConfigNotifierProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            st.hasError ? AppThemeConstants.error : AppThemeConstants.success,
        content: Text(
            st.hasError ? st.error.toString() : ArabicLabels.settingsSaved),
      ),
    );
    if (!st.hasError) updates.clear();
  }

  @override
  Widget build(BuildContext context) {
    final devAsync = ref.watch(devModeProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: ArabicLabels.devMode, actions: [
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppThemeConstants.spaceSm),
            child: Icon(Icons.warning_amber),
          )
        ]),
        body: devAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (dev) => _buildBody(dev),
        ),
      ),
    );
  }

  Widget _buildBody(DevModeModel dev) {
    final enabled = (updates['devModeEnabled'] as bool?) ?? dev.devModeEnabled;
    final users = List<String>.from(
        (updates['devModeUsers'] as List<String>?) ?? dev.devModeUsers);
    latCtrl.text =
        latCtrl.text.isEmpty ? dev.fakeGpsLat.toString() : latCtrl.text;
    lngCtrl.text =
        lngCtrl.text.isEmpty ? dev.fakeGpsLng.toString() : lngCtrl.text;

    return ListView(
      padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
      children: [
        Container(
          padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
          decoration: BoxDecoration(
            color: AppThemeConstants.error.withValues(alpha: 0.2),
            borderRadius: AppThemeConstants.borderRadiusMd,
          ),
          child: const Text(ArabicLabels.devModeWarning),
        ),
        const SizedBox(height: AppThemeConstants.spaceSm),
        _switch(
            'devModeEnabled', ArabicLabels.enableDevMode, dev.devModeEnabled,
            forceEnabled: true),
        _switch('bypassPayment', ArabicLabels.bypassPayment, dev.bypassPayment,
            enabled: enabled),
        _switch('bypassPromoValidation', ArabicLabels.bypassPromoValidation,
            dev.bypassPromoValidation,
            enabled: enabled),
        _switch(
            'bypassSlotLock', ArabicLabels.bypassSlotLock, dev.bypassSlotLock,
            enabled: enabled),
        _switch('mockNotifications', ArabicLabels.mockNotifications,
            dev.mockNotifications,
            enabled: enabled),
        _switch('skipAppVersionCheck', ArabicLabels.skipVersionCheck,
            dev.skipAppVersionCheck,
            enabled: enabled),
        _switch(
            'fakeGpsEnabled', ArabicLabels.enableFakeGps, dev.fakeGpsEnabled,
            enabled: enabled),
        if (((updates['fakeGpsEnabled'] as bool?) ?? dev.fakeGpsEnabled) &&
            enabled) ...[
          TextField(
            controller: latCtrl,
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: ArabicLabels.latitude),
            onChanged: (v) =>
                updates['fakeGpsLat'] = double.tryParse(v) ?? dev.fakeGpsLat,
          ),
          TextField(
            controller: lngCtrl,
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: ArabicLabels.longitude),
            onChanged: (v) =>
                updates['fakeGpsLng'] = double.tryParse(v) ?? dev.fakeGpsLng,
          ),
        ],
        _switch('showDebugOverlay', ArabicLabels.showDebugOverlay,
            dev.showDebugOverlay,
            enabled: enabled),
        _switch('logAllFirestoreWrites', ArabicLabels.logFirestoreWrites,
            dev.logAllFirestoreWrites,
            enabled: enabled),
        _switch('slowNetworkSimulation', ArabicLabels.simulateSlowNetwork,
            dev.slowNetworkSimulation,
            enabled: enabled),
        const SizedBox(height: AppThemeConstants.spaceMd),
        const Text(ArabicLabels.devModeUsers,
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppThemeConstants.spaceSm),
        ...users.map((uid) => ListTile(
              title: Text(uid),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppThemeConstants.error),
                onPressed: enabled
                    ? () {
                        users.remove(uid);
                        updates['devModeUsers'] = users;
                        setState(() {});
                      }
                    : null,
              ),
            )),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: uidCtrl,
                enabled: enabled,
                decoration:
                    const InputDecoration(labelText: ArabicLabels.addUid),
              ),
            ),
            IconButton(
              onPressed: enabled
                  ? () {
                      final uid = uidCtrl.text.trim();
                      if (uid.isNotEmpty && !users.contains(uid)) {
                        users.add(uid);
                        updates['devModeUsers'] = users;
                        uidCtrl.clear();
                        setState(() {});
                      }
                    }
                  : null,
              icon: const Icon(Icons.add_circle,
                  color: AppThemeConstants.primaryAmber),
            ),
          ],
        ),
        const SizedBox(height: AppThemeConstants.spaceMd),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeConstants.primaryAmber),
          onPressed: _save,
          child: const Text(ArabicLabels.saveSettings),
        ),
      ],
    );
  }

  Widget _switch(
    String key,
    String title,
    bool initial, {
    bool enabled = true,
    bool forceEnabled = false,
  }) {
    final current = (updates[key] as bool?) ?? initial;
    return SwitchListTile(
      title: Text(title),
      value: current,
      onChanged: (!enabled && !forceEnabled)
          ? null
          : (v) {
              updates[key] = v;
              setState(() {});
            },
    );
  }
}


