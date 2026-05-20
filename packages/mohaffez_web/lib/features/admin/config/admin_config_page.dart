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
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DSGrid(
      tabletColumns: 1,
      desktopColumns: 2,
      children: [
        DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'وضع الصيانة'),
              const SizedBox(height: DSSpacing.lg),
              _SwitchRow(
                label: 'تفعيل وضع الصيانة',
                value: config.maintenanceMode,
                onChanged: (_) {},
              ),
              const SizedBox(height: DSSpacing.md),
              Text(
                config.maintenanceMessage.isEmpty
                    ? 'عند التفعيل سيرى المستخدمون شاشة صيانة عند فتح التطبيق.'
                    : config.maintenanceMessage,
                style: DSText.caption(context, color: DSColors.text3),
              ),
            ],
          ),
        ),
        DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'إصدار التطبيق'),
              const SizedBox(height: DSSpacing.lg),
              _InfoRow(label: 'الإصدار الإلزامي',    value: config.forceUpdateVersion),
              _InfoRow(label: 'الإصدار الموصى به',   value: config.recommendedUpdateVersion),
            ],
          ),
        ),
        DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'إعدادات العمولة'),
              const SizedBox(height: DSSpacing.lg),
              _InfoRow(label: 'نسبة العمولة',              value: '${(config.commissionRate * 100).toStringAsFixed(0)}%'),
              _InfoRow(label: 'عمولة الدفع المباشر',        value: '${(config.directPaymentCommission * 100).toStringAsFixed(0)}%'),
              _InfoRow(label: 'الحد الأدنى للسحب',          value: '${config.minimumWithdrawAmount.toStringAsFixed(0)} ج.م'),
            ],
          ),
        ),
        DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'إعدادات الجلسات'),
              const SizedBox(height: DSSpacing.lg),
              _SwitchRow(label: 'جلسات أونلاين',    value: config.enableOnlineSessions,  onChanged: (_) {}),
              const SizedBox(height: DSSpacing.sm),
              _SwitchRow(label: 'جلسات في المساجد', value: config.enableMosqueSessions,  onChanged: (_) {}),
              const SizedBox(height: DSSpacing.sm),
              _SwitchRow(label: 'جلسات في المنازل', value: config.enableHomeSessions,    onChanged: (_) {}),
              const SizedBox(height: DSSpacing.md),
              _InfoRow(label: 'مهلة الدفع (ساعة)',     value: '${config.paymentDeadlineHours}'),
              _InfoRow(label: 'حد الحجز المسبق (يوم)', value: '${config.maxAdvanceBookingDays}'),
            ],
          ),
        ),
        DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'التحقق من الهوية'),
              const SizedBox(height: DSSpacing.lg),
              _SwitchRow(label: 'مراجعة الوثائق مطلوبة',    value: config.credentialReviewRequired, onChanged: (_) {}),
              const SizedBox(height: DSSpacing.sm),
              _SwitchRow(label: 'قبول المحفظين تلقائياً',  value: config.autoApproveMohaffez,      onChanged: (_) {}),
              const SizedBox(height: DSSpacing.sm),
              _SwitchRow(label: 'الحجز بدون تحقق',         value: config.allowUnverifiedBooking,   onChanged: (_) {}),
              const SizedBox(height: DSSpacing.md),
              _InfoRow(label: 'حد ملفات الوثائق', value: '${config.maxCredentialFiles}'),
            ],
          ),
        ),
        DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'الاختبارات'),
              const SizedBox(height: DSSpacing.lg),
              _InfoRow(label: 'درجة النجاح',            value: '${config.examPassingScore.toStringAsFixed(0)}%'),
              _InfoRow(label: 'أقصى محاولات',           value: '${config.examMaxRetries}'),
              _InfoRow(label: 'فترة الانتظار (يوم)',    value: '${config.examRetryCooldownDays}'),
            ],
          ),
        ),
        DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'بوابة الدفع Paymob'),
              const SizedBox(height: DSSpacing.lg),
              _SwitchRow(
                label: 'تفعيل الدفع الإلكتروني (Paymob)',
                value: config.paymobEnabled,
                onChanged: (v) async {
                  await ref
                      .read(systemConfigNotifierProvider.notifier)
                      .updateGlobalConfig({'paymobEnabled': v});
                },
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
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: DSText.body(context)),
        Switch(value: value, onChanged: onChanged, activeColor: DSColors.primary),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DSSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: DSText.body(context, color: DSColors.text2)),
          Text(value, style: DSText.bodyMedium(context)),
        ],
      ),
    );
  }
}
