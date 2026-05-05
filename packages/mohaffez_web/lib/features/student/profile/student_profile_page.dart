import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class StudentProfilePage extends ConsumerWidget {
  const StudentProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authProvider).user?.uid ?? '';
    final userAsync = ref.watch(userByIdProvider(uid));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'ملفي الشخصي'),
          const SizedBox(height: DSSpacing.xxl),
          userAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (user) => user == null
                ? const DSEmptyState(title: 'لم يُعثر على المستخدم', icon: Icons.person_off_outlined)
                : _ProfileForm(user: user),
          ),
        ],
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.user});
  final UserModel user;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateUser(
        widget.user.uid,
        {'name': _nameCtrl.text.trim()},
      );
      if (mounted) DSToast.show(context, 'تم حفظ التغييرات', type: DSToastType.success);
    } catch (e) {
      if (mounted) DSToast.show(context, 'خطأ في الحفظ: $e', type: DSToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSGrid(
      tabletColumns: 1,
      desktopColumns: 2,
      children: [
        DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'البيانات الشخصية'),
              const SizedBox(height: DSSpacing.xl),
              Center(
                child: DSAvatar(
                  imageUrl: widget.user.photoUrl,
                  name: widget.user.name,
                  size: 80,
                ),
              ),
              const SizedBox(height: DSSpacing.xl),
              DSTextField(
                controller: _nameCtrl,
                label: 'الاسم الكامل',
                hint: 'أدخل اسمك',
              ),
              const SizedBox(height: DSSpacing.lg),
              DSTextField(
                label: 'رقم الهاتف',
                hint: widget.user.phoneNumber ?? '—',
                enabled: false,
              ),
              const SizedBox(height: DSSpacing.xl),
              DSButton(
                label: 'حفظ التغييرات',
                fullWidth: true,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
        const DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'إحصائياتي'),
              SizedBox(height: DSSpacing.xl),
              DSEmptyState(
                title: 'قريباً',
                subtitle: 'ستُعرض إحصائياتك هنا',
                icon: Icons.bar_chart_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
