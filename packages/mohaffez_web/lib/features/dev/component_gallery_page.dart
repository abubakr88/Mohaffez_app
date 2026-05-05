import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';

class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  final _searchCtrl = TextEditingController();
  String? _selectVal;
  bool _loading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DSColors.surfaceMuted,
      body: PageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              title: 'Component Gallery',
              subtitle: 'Design system components — debug only',
              breadcrumbs: ['Dev', 'Components'],
            ),
            const SizedBox(height: DSSpacing.xxl),
            _section(context, 'Buttons', _buttons(context)),
            _section(context, 'Badges', _badges(context)),
            _section(context, 'Inputs', _inputs(context)),
            _section(context, 'Cards', _cards(context)),
            _section(context, 'Feedback', _feedback(context)),
            _section(context, 'Data Table', _table(context)),
            _section(context, 'Avatar', _avatars(context)),
            _section(context, 'Progress', _progress(context)),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: DSText.h2(context)),
        const SizedBox(height: DSSpacing.lg),
        child,
        const SizedBox(height: DSSpacing.xxl),
        const Divider(color: DSColors.border),
        const SizedBox(height: DSSpacing.xxl),
      ],
    );
  }

  Widget _buttons(BuildContext context) {
    return Wrap(
      spacing: DSSpacing.sm,
      runSpacing: DSSpacing.sm,
      children: [
        DSButton(label: 'Primary', onPressed: () {}),
        DSButton(label: 'Secondary', variant: DSButtonVariant.secondary, onPressed: () {}),
        DSButton(label: 'Ghost', variant: DSButtonVariant.ghost, onPressed: () {}),
        DSButton(label: 'Destructive', variant: DSButtonVariant.destructive, onPressed: () {}),
        DSButton(label: 'Small', size: DSButtonSize.sm, onPressed: () {}),
        DSButton(label: 'Large', size: DSButtonSize.lg, onPressed: () {}),
        DSButton(
          label: 'Loading',
          loading: _loading,
          onPressed: () async {
            setState(() => _loading = true);
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) setState(() => _loading = false);
          },
        ),
        const DSButton(label: 'Disabled'),
        DSButton(
          label: 'With Icon',
          leading: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
          onPressed: () {},
        ),
        DSIconButton(icon: Icons.edit_rounded, onPressed: () {}),
        DSIconButton(icon: Icons.delete_rounded, variant: DSIconButtonVariant.outlined, onPressed: () {}),
        DSIconButton(icon: Icons.settings_rounded, variant: DSIconButtonVariant.filled, onPressed: () {}),
      ],
    );
  }

  Widget _badges(BuildContext context) {
    return const Wrap(
      spacing: DSSpacing.sm,
      runSpacing: DSSpacing.sm,
      children: [
        DSBadge(label: 'Primary', variant: DSBadgeVariant.primary),
        DSBadge(label: 'Success', variant: DSBadgeVariant.success, dot: true),
        DSBadge(label: 'Warning', variant: DSBadgeVariant.warning, dot: true),
        DSBadge(label: 'Error', variant: DSBadgeVariant.error, dot: true),
        DSBadge(label: 'Info', variant: DSBadgeVariant.info),
        DSBadge(label: 'Neutral'),
      ],
    );
  }

  Widget _inputs(BuildContext context) {
    return DSGrid(
      desktopColumns: 2,
      children: [
        const DSTextField(label: 'اسم الطالب', hint: 'أدخل الاسم'),
        const DSTextField(label: 'البريد الإلكتروني', hint: 'example@email.com', keyboardType: TextInputType.emailAddress),
        const DSTextField(label: 'مع خطأ', hint: 'اكتب هنا', error: 'هذا الحقل مطلوب'),
        DSSearchField(hint: 'ابحث عن معلم...', controller: _searchCtrl),
        DSSelect<String>(
          label: 'الدور',
          hint: 'اختر دوراً',
          value: _selectVal,
          onChanged: (v) => setState(() => _selectVal = v),
          items: const [
            DSSelectItem(value: 'student', label: 'طالب'),
            DSSelectItem(value: 'teacher', label: 'محفظ'),
            DSSelectItem(value: 'admin', label: 'مدير'),
          ],
        ),
        const DSTextField(label: 'ملاحظات', hint: 'اكتب ملاحظاتك...', maxLines: 3),
      ],
    );
  }

  Widget _cards(BuildContext context) {
    return DSGrid(
      desktopColumns: 3,
      children: [
        const DSStatCard(
          label: 'إجمالي الطلاب',
          value: '١٢٤',
          icon: Icons.people_outline_rounded,
          trend: '+٥ هذا الشهر',
          trendPositive: true,
        ),
        const DSStatCard(
          label: 'الجلسات المكتملة',
          value: '٨٩',
          icon: Icons.check_circle_outline_rounded,
          iconColor: DSColors.success,
        ),
        const DSStatCard(
          label: 'الإيرادات',
          value: '٢٤٥٠ ج',
          icon: Icons.account_balance_wallet_outlined,
          iconColor: DSColors.secondary,
          trend: '-٣ هذا الأسبوع',
          trendPositive: false,
        ),
        DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('بطاقة مخصصة', style: DSText.h3(context)),
              const SizedBox(height: DSSpacing.sm),
              Text('يمكنك وضع أي محتوى داخل DSCard', style: DSText.body(context, color: DSColors.text2)),
            ],
          ),
        ),
        DSCard(
          onTap: () {},
          child: Text('بطاقة قابلة للنقر', style: DSText.body(context)),
        ),
        DSEmptyState(
          title: 'لا توجد بيانات',
          subtitle: 'أضف بياناتك الأولى',
          actionLabel: 'إضافة',
          onAction: () {},
        ),
      ],
    );
  }

  Widget _feedback(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: DSSpacing.sm,
          runSpacing: DSSpacing.sm,
          children: [
            DSButton(
              label: 'Toast نجاح',
              variant: DSButtonVariant.secondary,
              onPressed: () => DSToast.show(context, 'تمت العملية بنجاح', type: DSToastType.success),
            ),
            DSButton(
              label: 'Toast خطأ',
              variant: DSButtonVariant.secondary,
              onPressed: () => DSToast.show(context, 'حدث خطأ ما', type: DSToastType.error),
            ),
            DSButton(
              label: 'Toast تحذير',
              variant: DSButtonVariant.secondary,
              onPressed: () => DSToast.show(context, 'يرجى الانتباه', type: DSToastType.warning),
            ),
            DSButton(
              label: 'Dialog',
              variant: DSButtonVariant.secondary,
              onPressed: () => DSDialog.show(
                context,
                title: 'عنوان النافذة',
                child: Text('محتوى النافذة هنا', style: DSText.body(context, color: DSColors.text2)),
                actions: [
                  DSButton(label: 'إغلاق', variant: DSButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
                  DSButton(label: 'تأكيد', onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: DSSpacing.lg),
        const DSBanner(
          title: 'معلومة مهمة',
          message: 'هذا شريط إعلامي لإظهار رسائل مهمة للمستخدم.',
        ),
        const SizedBox(height: DSSpacing.sm),
        const DSBanner(
          message: 'تحذير: تأكد من صحة البيانات قبل المتابعة.',
          variant: DSBannerVariant.warning,
        ),
        const SizedBox(height: DSSpacing.sm),
        const DSBanner(
          message: 'حدث خطأ أثناء الاتصال بالخادم.',
          variant: DSBannerVariant.error,
        ),
        const SizedBox(height: DSSpacing.lg),
        Text('Skeleton', style: DSText.h3(context)),
        const SizedBox(height: DSSpacing.sm),
        const DSGrid(
          desktopColumns: 3,
          children: [DSSkeletonCard(), DSSkeletonCard(), DSSkeletonCard()],
        ),
      ],
    );
  }

  Widget _table(BuildContext context) {
    final rows = List.generate(
      5,
      (i) => {'name': 'محمد أحمد ${i + 1}', 'sessions': '${(i + 1) * 3}', 'status': i % 2 == 0 ? 'نشط' : 'معلق'},
    );

    return DSDataTable<Map<String, String>>(
      columns: [
        DSColumnDef(
          key: 'name',
          label: 'الاسم',
          sortable: true,
          cellBuilder: (ctx, row) => Text(row['name']!, style: DSText.bodyMedium(ctx)),
        ),
        DSColumnDef(
          key: 'sessions',
          label: 'الجلسات',
          width: 120,
          cellBuilder: (ctx, row) => Text(row['sessions']!, style: DSText.body(ctx, color: DSColors.text2)),
        ),
        DSColumnDef(
          key: 'status',
          label: 'الحالة',
          width: 120,
          cellBuilder: (ctx, row) => DSBadge(
            label: row['status']!,
            variant: row['status'] == 'نشط' ? DSBadgeVariant.success : DSBadgeVariant.warning,
            dot: true,
          ),
        ),
      ],
      rows: rows,
      onRowTap: (row) => DSToast.show(context, 'نقرت على: ${row['name']}'),
    );
  }

  Widget _avatars(BuildContext context) {
    return const Wrap(
      spacing: DSSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DSAvatar(name: 'محمد أحمد', size: 32),
        DSAvatar(name: 'فاطمة علي', size: 40),
        DSAvatar(name: 'عمر خالد', size: 48, color: DSColors.secondary),
        DSAvatar(size: 40),
      ],
    );
  }

  Widget _progress(BuildContext context) {
    return const Column(
      children: [
        DSProgressBar(value: 0.3, label: 'التقدم في الحفظ', showPercent: true),
        SizedBox(height: DSSpacing.md),
        DSProgressBar(value: 0.65, label: 'الجلسات المكتملة', color: DSColors.success, showPercent: true),
        SizedBox(height: DSSpacing.md),
        DSProgressBar(value: 0.85, color: DSColors.secondary, height: 12),
      ],
    );
  }
}
