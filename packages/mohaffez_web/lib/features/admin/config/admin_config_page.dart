import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminConfigPage extends ConsumerWidget {
  const AdminConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(systemConfigProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'إعدادات النظام',
            subtitle: 'ضبط إعدادات المنصة',
          ),
          const SizedBox(height: DSSpacing.xxl),
          configAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (config) => _ConfigForm(config: config),
          ),
        ],
      ),
    );
  }
}

class _ConfigForm extends ConsumerWidget {
  const _ConfigForm({required this.config});
  final SystemConfigModel config;

  Future<void> _save(
      BuildContext context, WidgetRef ref, Map<String, dynamic> updates) async {
    await ref
        .read(systemConfigNotifierProvider.notifier)
        .updateGlobalConfig(updates);
    if (!context.mounted) return;
    final state = ref.read(systemConfigNotifierProvider);
    state.when(
      data: (_) =>
          DSToast.show(context, 'تم حفظ الإعداد', type: DSToastType.success),
      loading: () {},
      error: (e, _) =>
          DSToast.show(context, 'فشل الحفظ: $e', type: DSToastType.error),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DSGrid(
      tabletColumns: 1,
      desktopColumns: 2,
      children: [
        _ConfigCard(
          title: 'تحديات الجلسة V2',
          children: [
            _SwitchRow(
              label: 'تفعيل التحديات منخفضة التكلفة',
              value: config.challengeV2Enabled,
              onChanged: (v) => _save(context, ref, {'challengeV2Enabled': v}),
            ),
            const SizedBox(height: DSSpacing.sm),
            Text(
              'يتحكم في البطاقة الدائمة للطالب ومعالج بنك الأسئلة الموحد.',
              style: DSText.caption(context, color: DSColors.text3),
            ),
          ],
        ),

        // ── Maintenance ─────────────────────────────────────────────────
        _ConfigCard(
          title: 'وضع الصيانة',
          children: [
            _SwitchRow(
              label: 'تفعيل وضع الصيانة',
              value: config.maintenanceMode,
              onChanged: (v) => _save(context, ref, {'maintenanceMode': v}),
            ),
            const SizedBox(height: DSSpacing.md),
            _EditableRow(
              label: 'رسالة الصيانة',
              value: config.maintenanceMessage.isEmpty
                  ? '— (افتراضية)'
                  : config.maintenanceMessage,
              onEdit: () => _editText(
                context,
                title: 'رسالة الصيانة',
                initial: config.maintenanceMessage,
                multiline: true,
                onSave: (v) => _save(context, ref, {'maintenanceMessage': v}),
              ),
            ),
            const SizedBox(height: DSSpacing.sm),
            Text(
              'عند التفعيل سيرى المستخدمون شاشة صيانة عند فتح التطبيق.',
              style: DSText.caption(context, color: DSColors.text3),
            ),
          ],
        ),

        // ── App version ─────────────────────────────────────────────────
        _ConfigCard(
          title: 'إصدار التطبيق',
          children: [
            _EditableRow(
              label: 'الإصدار الإلزامي',
              value: config.forceUpdateVersion,
              onEdit: () => _editText(
                context,
                title: 'الإصدار الإلزامي',
                initial: config.forceUpdateVersion,
                onSave: (v) => _save(context, ref, {'forceUpdateVersion': v}),
              ),
            ),
            _EditableRow(
              label: 'الإصدار الموصى به',
              value: config.recommendedUpdateVersion,
              onEdit: () => _editText(
                context,
                title: 'الإصدار الموصى به',
                initial: config.recommendedUpdateVersion,
                onSave: (v) =>
                    _save(context, ref, {'recommendedUpdateVersion': v}),
              ),
            ),
          ],
        ),

        // ── Commission ──────────────────────────────────────────────────
        _ConfigCard(
          title: 'إعدادات العمولة',
          children: [
            _EditableRow(
              label: 'نسبة العمولة',
              value: '${(config.commissionRate * 100).toStringAsFixed(0)}%',
              onEdit: () => _editNumber(
                context,
                title: 'نسبة العمولة (%)',
                initial: (config.commissionRate * 100).toStringAsFixed(0),
                onSave: (n) => _save(context, ref, {'commissionRate': n / 100}),
              ),
            ),
            _EditableRow(
              label: 'عمولة الدفع المباشر',
              value:
                  '${(config.directPaymentCommission * 100).toStringAsFixed(0)}%',
              onEdit: () => _editNumber(
                context,
                title: 'عمولة الدفع المباشر (%)',
                initial:
                    (config.directPaymentCommission * 100).toStringAsFixed(0),
                onSave: (n) =>
                    _save(context, ref, {'directPaymentCommission': n / 100}),
              ),
            ),
            _EditableRow(
              label: 'الحد الأدنى للسحب',
              value: '${config.minimumWithdrawAmount.toStringAsFixed(0)} ج.م',
              onEdit: () => _editNumber(
                context,
                title: 'الحد الأدنى للسحب (ج.م)',
                initial: config.minimumWithdrawAmount.toStringAsFixed(0),
                onSave: (n) =>
                    _save(context, ref, {'minimumWithdrawAmount': n}),
              ),
            ),
            _EditableRow(
              label: 'حد دين الدفع المباشر',
              value:
                  '${config.directPaymentDebtThresholdEgp.toStringAsFixed(0)} ج.م',
              onEdit: () => _editNumber(
                context,
                title: 'حد دين الدفع المباشر (ج.م)',
                initial:
                    config.directPaymentDebtThresholdEgp.toStringAsFixed(0),
                onSave: (n) =>
                    _save(context, ref, {'directPaymentDebtThresholdEgp': n}),
              ),
            ),
          ],
        ),

        _ConfigCard(
          title: 'إعدادات التسعير',
          children: [
            _EditableRow(
              label: 'الحد الأدنى لسعر الساعة',
              value:
                  '${config.minimumTeacherHourlyRateEgp.toStringAsFixed(0)} ج.م',
              onEdit: () => _editNumber(
                context,
                title: 'الحد الأدنى لسعر الساعة (ج.م)',
                initial: config.minimumTeacherHourlyRateEgp.toStringAsFixed(0),
                minValue: 0,
                onSave: (n) => _save(
                  context,
                  ref,
                  {'minimumTeacherHourlyRateEgp': n},
                ),
              ),
            ),
            const SizedBox(height: DSSpacing.sm),
            Text(
              'يُحسب الحد من سعر الخطة وعدد الجلسات ومدة كل جلسة. القيمة صفر تعني عدم فرض حد أدنى.',
              style: DSText.caption(context, color: DSColors.text3),
            ),
          ],
        ),

        _ConfigCard(
          title: 'إعدادات الحسابات',
          children: [
            _EditableRow(
              label: 'الحد الأدنى لعمر حساب الطالب المستقل',
              value: '${config.minimumIndependentStudentAge} سنة',
              onEdit: () => _editNumber(
                context,
                title: 'الحد الأدنى لعمر الطالب',
                initial: '${config.minimumIndependentStudentAge}',
                isInt: true,
                minValue: 5,
                maxValue: 30,
                onSave: (n) => _save(
                  context,
                  ref,
                  {'minimumIndependentStudentAge': n.toInt()},
                ),
              ),
            ),
            const SizedBox(height: DSSpacing.sm),
            Text(
              'الطالب الأصغر من هذا العمر سيُوجّه لاستخدام حساب ولي أمر.',
              style: DSText.caption(context, color: DSColors.text3),
            ),
          ],
        ),

        // ── Sessions ────────────────────────────────────────────────────
        _ConfigCard(
          title: 'إعدادات الجلسات',
          children: [
            _SwitchRow(
                label: 'جلسات أونلاين',
                value: config.enableOnlineSessions,
                onChanged: (v) =>
                    _save(context, ref, {'enableOnlineSessions': v})),
            const SizedBox(height: DSSpacing.sm),
            _SwitchRow(
                label: 'جلسات في المساجد',
                value: config.enableMosqueSessions,
                onChanged: (v) =>
                    _save(context, ref, {'enableMosqueSessions': v})),
            const SizedBox(height: DSSpacing.sm),
            _SwitchRow(
                label: 'جلسات في المنازل',
                value: config.enableHomeSessions,
                onChanged: (v) =>
                    _save(context, ref, {'enableHomeSessions': v})),
            const SizedBox(height: DSSpacing.sm),
            _SwitchRow(
              label: 'مدة مستقلة لكل خطة سعرية',
              value: config.variablePlanSessionDurationEnabled,
              onChanged: (v) => _save(
                context,
                ref,
                {'variablePlanSessionDurationEnabled': v},
              ),
            ),
            const SizedBox(height: DSSpacing.xs),
            Text(
              'فعّلها بعد نشر Functions والتطبيقات واختبار المواعيد ذات المدد المختلفة.',
              style: DSText.caption(context, color: DSColors.text3),
            ),
            const SizedBox(height: DSSpacing.md),
            _EditableRow(
              label: 'مهلة الدفع (ساعة)',
              value: '${config.paymentDeadlineHours}',
              onEdit: () => _editNumber(
                context,
                title: 'مهلة الدفع (ساعة)',
                initial: '${config.paymentDeadlineHours}',
                isInt: true,
                onSave: (n) =>
                    _save(context, ref, {'paymentDeadlineHours': n.toInt()}),
              ),
            ),
            _EditableRow(
              label: 'حد الحجز المسبق (يوم)',
              value: '${config.maxAdvanceBookingDays}',
              onEdit: () => _editNumber(
                context,
                title: 'حد الحجز المسبق (يوم)',
                initial: '${config.maxAdvanceBookingDays}',
                isInt: true,
                onSave: (n) =>
                    _save(context, ref, {'maxAdvanceBookingDays': n.toInt()}),
              ),
            ),
            _EditableRow(
              label: 'أقصى مدة للجلسة (دقيقة)',
              value: '${config.sessionMaxDurationMinutes}',
              onEdit: () => _editNumber(
                context,
                title: 'أقصى مدة للجلسة (دقيقة)',
                initial: '${config.sessionMaxDurationMinutes}',
                isInt: true,
                onSave: (n) => _save(
                    context, ref, {'sessionMaxDurationMinutes': n.toInt()}),
              ),
            ),
            _EditableRow(
              label: 'مهلة التأخير المسموحة (دقيقة)',
              value: '${config.lateSessionGraceMinutes}',
              onEdit: () => _editNumber(
                context,
                title: 'مهلة التأخير المسموحة (دقيقة)',
                initial: '${config.lateSessionGraceMinutes}',
                isInt: true,
                onSave: (n) =>
                    _save(context, ref, {'lateSessionGraceMinutes': n.toInt()}),
              ),
            ),
          ],
        ),

        // ── Verification ────────────────────────────────────────────────
        _ConfigCard(
          title: 'التحقق من الهوية',
          children: [
            _SwitchRow(
                label: 'مراجعة الوثائق مطلوبة',
                value: config.credentialReviewRequired,
                onChanged: (v) =>
                    _save(context, ref, {'credentialReviewRequired': v})),
            const SizedBox(height: DSSpacing.sm),
            _SwitchRow(
                label: 'استقبال محفظين جدد',
                value: config.teacherRegistrationEnabled,
                onChanged: (v) =>
                    _save(context, ref, {'teacherRegistrationEnabled': v})),
            const SizedBox(height: DSSpacing.xs),
            Text(
              config.teacherRegistrationEnabled
                  ? 'يمكن للزوار إنشاء حساب محفظ جديد وإكمال طلب المراجعة.'
                  : 'تم إيقاف إنشاء حسابات المحفظين الجدد مؤقتاً. حسابات الطلاب تعمل بشكل طبيعي.',
              style: DSText.caption(context, color: DSColors.text3),
            ),
            const SizedBox(height: DSSpacing.sm),
            _SwitchRow(
                label: 'قبول المحفظين تلقائياً',
                value: config.autoApproveMohaffez,
                onChanged: (v) =>
                    _save(context, ref, {'autoApproveMohaffez': v})),
            const SizedBox(height: DSSpacing.sm),
            _SwitchRow(
                label: 'الحجز بدون تحقق',
                value: config.allowUnverifiedBooking,
                onChanged: (v) =>
                    _save(context, ref, {'allowUnverifiedBooking': v})),
            const SizedBox(height: DSSpacing.md),
            _EditableRow(
              label: 'حد ملفات الوثائق',
              value: '${config.maxCredentialFiles}',
              onEdit: () => _editNumber(
                context,
                title: 'حد ملفات الوثائق',
                initial: '${config.maxCredentialFiles}',
                isInt: true,
                onSave: (n) =>
                    _save(context, ref, {'maxCredentialFiles': n.toInt()}),
              ),
            ),
          ],
        ),

        // ── Exams ───────────────────────────────────────────────────────
        _ConfigCard(
          title: 'الاختبارات',
          children: [
            _EditableRow(
              label: 'درجة النجاح',
              value: '${config.examPassingScore.toStringAsFixed(0)}%',
              onEdit: () => _editNumber(
                context,
                title: 'درجة النجاح (%)',
                initial: config.examPassingScore.toStringAsFixed(0),
                onSave: (n) => _save(context, ref, {'examPassingScore': n}),
              ),
            ),
            _EditableRow(
              label: 'أقصى محاولات',
              value: '${config.examMaxRetries}',
              onEdit: () => _editNumber(
                context,
                title: 'أقصى محاولات',
                initial: '${config.examMaxRetries}',
                isInt: true,
                onSave: (n) =>
                    _save(context, ref, {'examMaxRetries': n.toInt()}),
              ),
            ),
            _EditableRow(
              label: 'فترة الانتظار (يوم)',
              value: '${config.examRetryCooldownDays}',
              onEdit: () => _editNumber(
                context,
                title: 'فترة الانتظار (يوم)',
                initial: '${config.examRetryCooldownDays}',
                isInt: true,
                onSave: (n) =>
                    _save(context, ref, {'examRetryCooldownDays': n.toInt()}),
              ),
            ),
          ],
        ),

        // ── Notifications ───────────────────────────────────────────────
        _ConfigCard(
          title: 'الإشعارات',
          children: [
            _SwitchRow(
                label: 'تفعيل الإشعارات (FCM)',
                value: config.fcmEnabled,
                onChanged: (v) => _save(context, ref, {'fcmEnabled': v})),
            const SizedBox(height: DSSpacing.sm),
            _SwitchRow(
                label: 'تذكير الدفع',
                value: config.paymentReminderEnabled,
                onChanged: (v) =>
                    _save(context, ref, {'paymentReminderEnabled': v})),
            const SizedBox(height: DSSpacing.sm),
            _SwitchRow(
                label: 'تذكير الجلسات',
                value: config.sessionReminderEnabled,
                onChanged: (v) =>
                    _save(context, ref, {'sessionReminderEnabled': v})),
          ],
        ),

        // ── Paymob ──────────────────────────────────────────────────────
        _ConfigCard(
          title: 'بوابة الدفع Paymob',
          children: [
            _SwitchRow(
              label: 'تفعيل الدفع الإلكتروني (Paymob)',
              value: config.paymobEnabled,
              onChanged: (v) => _save(context, ref, {'paymobEnabled': v}),
            ),
            const SizedBox(height: DSSpacing.md),
            Text(
              config.paymobEnabled
                  ? 'الدفع الإلكتروني مفعّل. تأكد من ضبط PAYMOB_HMAC_SECRET في إعدادات الـ Functions.'
                  : 'الدفع الإلكتروني معطّل. سيظهر للطلاب كـ "قريبا". لا تفعّل إلا بعد توقيع عقد Paymob واستلام بيانات الـ HMAC.',
              style: DSText.caption(context, color: DSColors.text3),
            ),
          ],
        ),
      ],
    );
  }

  // ── Edit dialogs ──────────────────────────────────────────────────────
  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initial,
    required ValueChanged<String> onSave,
    bool multiline = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final ok = await DSDialog.show<bool>(
      context,
      title: title,
      child: DSTextField(
        controller: controller,
        autofocus: true,
        maxLines: multiline ? 4 : 1,
      ),
      actions: [
        DSButton(
            label: 'إلغاء',
            variant: DSButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false)),
        DSButton(
            label: 'حفظ', onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
    if (ok == true) onSave(controller.text.trim());
  }

  Future<void> _editNumber(
    BuildContext context, {
    required String title,
    required String initial,
    required ValueChanged<double> onSave,
    bool isInt = false,
    double? minValue,
    double? maxValue,
  }) async {
    final controller = TextEditingController(text: initial);
    String? error;
    final ok = await DSDialog.show<bool>(
      context,
      title: title,
      child: StatefulBuilder(
        builder: (ctx, setState) => DSTextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          error: error,
          onChanged: (_) {
            if (error != null) setState(() => error = null);
          },
        ),
      ),
      actions: [
        DSButton(
            label: 'إلغاء',
            variant: DSButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false)),
        DSButton(
            label: 'حفظ', onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
    if (ok != true) return;
    final parsed = double.tryParse(controller.text.trim());
    if (parsed == null) {
      if (context.mounted) {
        DSToast.show(context, 'قيمة غير صالحة', type: DSToastType.error);
      }
      return;
    }
    if (minValue != null && parsed < minValue) {
      if (context.mounted) {
        DSToast.show(
          context,
          'يجب ألا تقل القيمة عن ${minValue.toStringAsFixed(0)}',
          type: DSToastType.error,
        );
      }
      return;
    }
    if (maxValue != null && parsed > maxValue) {
      if (context.mounted) {
        DSToast.show(
          context,
          'يجب ألا تزيد القيمة عن ${maxValue.toStringAsFixed(0)}',
          type: DSToastType.error,
        );
      }
      return;
    }
    onSave(isInt ? parsed.roundToDouble() : parsed);
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────
class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: DSSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: DSText.body(context))),
        Switch(
            value: value, onChanged: onChanged, activeColor: DSColors.primary),
      ],
    );
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow(
      {required this.label, required this.value, required this.onEdit});
  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DSSpacing.md),
      child: Row(
        children: [
          Expanded(
            child:
                Text(label, style: DSText.body(context, color: DSColors.text2)),
          ),
          Text(value, style: DSText.bodyMedium(context)),
          const SizedBox(width: DSSpacing.xs),
          DSIconButton(
            icon: Icons.edit_outlined,
            onPressed: onEdit,
            tooltip: 'تعديل',
          ),
        ],
      ),
    );
  }
}
