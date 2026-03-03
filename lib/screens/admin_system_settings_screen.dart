import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/system_config_model.dart';
import '../providers/system_config_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../utils/arabic_labels.dart';

class AdminSystemSettingsScreen extends ConsumerStatefulWidget {
  const AdminSystemSettingsScreen({super.key});

  @override
  ConsumerState<AdminSystemSettingsScreen> createState() =>
      _AdminSystemSettingsScreenState();
}

class _AdminSystemSettingsScreenState
    extends ConsumerState<AdminSystemSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, dynamic> updates = {};
  final Map<String, TextEditingController> _numCtrlCache = {};
  final maintenanceMessageCtrl = TextEditingController();
  final forceVersionCtrl = TextEditingController();
  final recVersionCtrl = TextEditingController();
  bool _isLoadingSave = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    maintenanceMessageCtrl.dispose();
    forceVersionCtrl.dispose();
    recVersionCtrl.dispose();
    for (final ctrl in _numCtrlCache.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (updates.isEmpty) return;
    setState(() => _isLoadingSave = true);
    try {
      await ref
          .read(systemConfigNotifierProvider.notifier)
          .updateGlobalConfig(updates);
      if (!mounted) return;
      updates.clear();
      _numCtrlCache.clear(); // reset controllers so they reflect saved values
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.success,
          content: const Text(ArabicLabels.settingsSaved),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingSave = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(systemConfigProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(ArabicLabels.systemSettings),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: ArabicLabels.paymentSettings),
              Tab(text: ArabicLabels.sessionSettings),
              Tab(text: ArabicLabels.appVersionSettings),
              Tab(text: 'التحقق'),
            ],
          ),
        ),
        body: configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (config) {
            maintenanceMessageCtrl.text = maintenanceMessageCtrl.text.isEmpty
                ? config.maintenanceMessage
                : maintenanceMessageCtrl.text;
            forceVersionCtrl.text = forceVersionCtrl.text.isEmpty
                ? config.forceUpdateVersion
                : forceVersionCtrl.text;
            recVersionCtrl.text = recVersionCtrl.text.isEmpty
                ? config.recommendedUpdateVersion
                : recVersionCtrl.text;
            return TabBarView(
              controller: _tabController,
              children: [
                _financialTab(config),
                _bookingTab(config),
                _appTab(config),
                _verifyTab(config),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _financialTab(SystemConfigModel c) {
    // TODO: اربط هذه الإعدادات مع شاشة السحب عند توفرها.
    return _sectionList([
      _sliderTile('commissionRate', ArabicLabels.commissionRate,
          c.commissionRate, 0, 0.2),
      _numberField('paymentDeadlineHours', ArabicLabels.paymentDeadlineHours,
          c.paymentDeadlineHours),
      _numberField(
          'minimumWithdrawAmount', 'حد السحب الأدنى', c.minimumWithdrawAmount),
      _switchTile(
          'freeSessionEnabled', 'تفعيل الجلسات المجانية', c.freeSessionEnabled),
      _saveButton(),
    ]);
  }

  Widget _bookingTab(SystemConfigModel c) {
    return _sectionList([
      _numberField('slotLockDurationMinutes',
          ArabicLabels.slotLockDurationMinutes, c.slotLockDurationMinutes),
      _numberField('maxPendingRequestsPerStudent', 'أقصى طلبات معلقة للطالب',
          c.maxPendingRequestsPerStudent),
      _numberField('maxAdvanceBookingDays', 'أقصى حجز مسبق (أيام)',
          c.maxAdvanceBookingDays),
      _numberField('sessionReminderHours1', 'تذكير أول (ساعات)',
          c.sessionReminderHours1),
      _numberField('sessionReminderHours2', 'تذكير ثان (ساعات)',
          c.sessionReminderHours2),
      _saveButton(),
    ]);
  }

  Widget _appTab(SystemConfigModel c) {
    // TODO: استخدم forceUpdateVersion في فحص الإصدار داخل التطبيق.
    return _sectionList([
      _switchTile(
          'maintenanceMode', ArabicLabels.maintenanceMode, c.maintenanceMode),
      TextField(
        controller: maintenanceMessageCtrl,
        decoration:
            const InputDecoration(labelText: ArabicLabels.maintenanceMessage),
        onChanged: (v) => updates['maintenanceMessage'] = v,
      ),
      TextField(
        controller: forceVersionCtrl,
        decoration: const InputDecoration(labelText: ArabicLabels.forceVersion),
        onChanged: (v) => updates['forceUpdateVersion'] = v,
      ),
      TextField(
        controller: recVersionCtrl,
        decoration:
            const InputDecoration(labelText: ArabicLabels.recommendedVersion),
        onChanged: (v) => updates['recommendedUpdateVersion'] = v,
      ),
      _numberField('defaultSearchRadiusKm', 'نطاق البحث الافتراضي',
          c.defaultSearchRadiusKm),
      _switchTile('enableOnlineSessions', 'تفعيل الجلسات الأونلاين',
          c.enableOnlineSessions),
      _switchTile(
          'enableMosqueSessions', 'تفعيل جلسات المسجد', c.enableMosqueSessions),
      _switchTile(
          'enableHomeSessions', 'تفعيل الجلسات المنزلية', c.enableHomeSessions),
      _saveButton(),
    ]);
  }

  Widget _verifyTab(SystemConfigModel c) {
    return _sectionList([
      _switchTile('credentialReviewRequired', 'مراجعة الشهادات مطلوبة',
          c.credentialReviewRequired),
      _switchTile(
          'autoApproveMohaffez', 'قبول المحفظ تلقائياً', c.autoApproveMohaffez),
      _switchTile('allowUnverifiedBooking', 'السماح بالحجز دون تحقق',
          c.allowUnverifiedBooking),
      _numberField(
          'maxCredentialFiles', 'أقصى عدد ملفات الشهادة', c.maxCredentialFiles),
      _saveButton(),
    ]);
  }

  Widget _sectionList(List<Widget> children) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
      itemBuilder: (_, i) => children[i],
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppThemeConstants.spaceSm),
      itemCount: children.length,
    );
  }

  Widget _switchTile(String key, String title, bool initial) {
    return StatefulBuilder(
      builder: (_, setState) {
        final current = (updates[key] as bool?) ?? initial;
        return SwitchListTile(
          title: Text(title),
          value: current,
          onChanged: (v) {
            setState(() => updates[key] = v);
            // No outer setState needed - updates map is mutated by reference
          },
        );
      },
    );
  }

  Widget _numberField(String key, String label, Object initial) {
    final ctrl = _numCtrlCache.putIfAbsent(
      key,
      () => TextEditingController(
          text: updates[key]?.toString() ?? initial.toString()),
    );
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (v) {
        final parsed = v.contains('.') ? double.tryParse(v) : int.tryParse(v);
        if (parsed != null) updates[key] = parsed;
        // Do NOT assign null — leave updates[key] unchanged on partial input
      },
    );
  }

  Widget _sliderTile(
      String key, String title, double initial, double min, double max) {
    return StatefulBuilder(
      builder: (_, setState) {
        final current = (updates[key] as double?) ?? initial;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title: ${(current * 100).toStringAsFixed(0)}%'),
            Slider(
              value: current,
              min: min,
              max: max,
              onChanged: (v) {
                setState(() => updates[key] = v);
                // No outer setState needed - updates map is mutated by reference
              },
            ),
          ],
        );
      },
    );
  }

  Widget _saveButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeConstants.primaryAmber),
      onPressed: _isLoadingSave ? null : _save,
      child: _isLoadingSave
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text(ArabicLabels.saveSettings),
    );
  }
}
