import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

class CancellationPolicyScreen extends StatelessWidget {
  const CancellationPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سياسة الإلغاء والغياب'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _intro(),
            const SizedBox(height: 16),
            _studentSection(),
            const SizedBox(height: 16),
            _teacherSection(),
            const SizedBox(height: 16),
            _generalRules(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeConstants.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeConstants.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppThemeConstants.primary, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'تهدف هذه السياسة إلى حماية حقوق الطرفين وضمان الالتزام بالمواعيد. يُرجى الاطلاع عليها قبل حجز أي جلسة.',
              style: TextStyle(fontSize: 13, color: AppThemeConstants.textPrimary, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentSection() {
    return _PolicyCard(
      title: 'سياسة الطالب',
      icon: Icons.person_rounded,
      color: AppThemeConstants.primary,
      children: [
        const _SectionHeader('إلغاء الجلسة'),
        const _PolicyRow(
          icon: Icons.check_circle_outline,
          iconColor: AppThemeConstants.success,
          label: 'إلغاء قبل الجلسة بأكثر من 3 ساعات',
          value: 'استرداد 100% إلى المحفظة',
          valueColor: AppThemeConstants.success,
        ),
        const _PolicyRow(
          icon: Icons.schedule_rounded,
          iconColor: AppThemeConstants.warning,
          label: 'إلغاء قبل الجلسة من 1 إلى 3 ساعات',
          value: 'استرداد 50% إلى المحفظة',
          valueColor: AppThemeConstants.warning,
        ),
        const _PolicyRow(
          icon: Icons.cancel_outlined,
          iconColor: AppThemeConstants.error,
          label: 'إلغاء قبل الجلسة بأقل من ساعة',
          value: 'لا يوجد استرداد',
          valueColor: AppThemeConstants.error,
        ),
        const Divider(height: 24),
        const _SectionHeader('غياب الطالب'),
        const _PolicyRow(
          icon: Icons.person_off_outlined,
          iconColor: AppThemeConstants.error,
          label: 'غياب الطالب دون إلغاء مسبق',
          value: 'لا يوجد استرداد — يُحتسب للمحفظ',
          valueColor: AppThemeConstants.error,
        ),
        const Divider(height: 24),
        _note('يتم إصدار إنذار تنبيهي على الحساب عند كل إلغاء أو غياب.'),
      ],
    );
  }

  Widget _teacherSection() {
    return _PolicyCard(
      title: 'سياسة المحفظ',
      icon: Icons.school_rounded,
      color: AppThemeConstants.secondary,
      children: [
        const _SectionHeader('إلغاء الجلسة'),
        const _PolicyRow(
          icon: Icons.check_circle_outline,
          iconColor: AppThemeConstants.success,
          label: 'إلغاء قبل الجلسة بأكثر من 3 ساعات',
          value: 'استرداد 100% للطالب — بدون غرامة عمولة',
          valueColor: AppThemeConstants.success,
        ),
        const _PolicyRow(
          icon: Icons.schedule_rounded,
          iconColor: AppThemeConstants.warning,
          label: 'إلغاء قبل الجلسة من 1 إلى 3 ساعات',
          value: 'استرداد 100% للطالب + زيادة 0.5% على العمولة',
          valueColor: AppThemeConstants.warning,
        ),
        const _PolicyRow(
          icon: Icons.cancel_outlined,
          iconColor: AppThemeConstants.error,
          label: 'إلغاء قبل الجلسة بأقل من ساعة',
          value: 'استرداد 100% للطالب + زيادة 1% على العمولة',
          valueColor: AppThemeConstants.error,
        ),
        const Divider(height: 24),
        const _SectionHeader('غياب المحفظ'),
        const _PolicyRow(
          icon: Icons.person_off_outlined,
          iconColor: AppThemeConstants.error,
          label: 'غياب المحفظ (يُبلّغ عنه الطالب أو يُكتشف تلقائياً)',
          value: 'استرداد 100% للطالب + زيادة 1.5% على العمولة',
          valueColor: AppThemeConstants.error,
        ),
        const Divider(height: 24),
        const _SectionHeader('نظام العمولة الإضافية'),
        _note(
          'تُضاف الغرامة على نسبة العمولة الأساسية لهذه الدورة فقط، وتُعاد الضبط في كل دورة محاسبة. '
          'عند تعدد المخالفات، تتراكم الغرامات — كل مخالفة تُضاف على ما قبلها.',
        ),
        const SizedBox(height: 8),
        _note('يتم إصدار إنذار تنبيهي وتنبيه للإدارة عند كل إلغاء أو غياب.'),
      ],
    );
  }

  Widget _generalRules() {
    return const _PolicyCard(
      title: 'قواعد عامة',
      icon: Icons.gavel_rounded,
      color: AppThemeConstants.textSecondary,
      children: [
        _BulletPoint('يحق لكل طرف مراجعة سجل الإلغاءات والغيابات من خلال سجل الجلسات.'),
        _BulletPoint('تُبلَّغ الإدارة تلقائياً عن المحفظين غير الملتزمين لاتخاذ الإجراء المناسب.'),
        _BulletPoint('الجلسات الأونلاين: إذا لم ينضم المحفظ خلال 60 دقيقة من الموعد، يُسجَّل غياباً تلقائياً.'),
        _BulletPoint('مبالغ الاسترداد تُضاف مباشرة إلى المحفظة الإلكترونية داخل التطبيق.'),
      ],
    );
  }

  Widget _note(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppThemeConstants.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppThemeConstants.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppThemeConstants.textSecondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _PolicyCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppThemeConstants.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppThemeConstants.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  const _PolicyRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: AppThemeConstants.textPrimary, height: 1.4),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: CircleAvatar(
              radius: 3,
              backgroundColor: AppThemeConstants.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppThemeConstants.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
