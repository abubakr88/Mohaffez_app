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
  final maintenanceMessageCtrl = TextEditingController();
  final forceVersionCtrl = TextEditingController();
  final recVersionCtrl = TextEditingController();

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
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(systemConfigNotifierProvider.notifier)
        .updateGlobalConfig(updates);
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
            this.setState(() {});
          },
        );
      },
    );
  }

  Widget _numberField(String key, String label, Object initial) {
    final ctrl = TextEditingController(
        text: updates[key]?.toString() ?? initial.toString());
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) {
        final parsed = v.contains('.') ? double.tryParse(v) : int.tryParse(v);
        updates[key] = parsed;
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
                this.setState(() {});
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
      onPressed: _save,
      child: const Text(ArabicLabels.saveSettings),
    );
  }
}
