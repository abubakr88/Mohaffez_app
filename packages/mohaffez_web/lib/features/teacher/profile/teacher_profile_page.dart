import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class TeacherProfilePage extends ConsumerWidget {
  const TeacherProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid       = ref.watch(authProvider).user?.uid ?? '';
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
                : _TeacherProfileForm(user: user),
          ),
        ],
      ),
    );
  }
}

class _TeacherProfileForm extends ConsumerStatefulWidget {
  const _TeacherProfileForm({required this.user});
  final UserModel user;

  @override
  ConsumerState<_TeacherProfileForm> createState() => _TeacherProfileFormState();
}

class _TeacherProfileFormState extends ConsumerState<_TeacherProfileForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _bioCtrl  = TextEditingController(text: widget.user.bio ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateUser(widget.user.uid, {
        'name': _nameCtrl.text.trim(),
        'bio':  _bioCtrl.text.trim(),
      });
      if (mounted) DSToast.show(context, 'تم حفظ التغييرات', type: DSToastType.success);
    } catch (e) {
      if (mounted) DSToast.show(context, 'خطأ: $e', type: DSToastType.error);
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
                child: DSAvatar(imageUrl: widget.user.photoUrl, name: widget.user.name, size: 80),
              ),
              const SizedBox(height: DSSpacing.xl),
              DSTextField(controller: _nameCtrl, label: 'الاسم الكامل', hint: 'أدخل اسمك'),
              const SizedBox(height: DSSpacing.lg),
              DSTextField(
                controller: _bioCtrl,
                label: 'نبذة تعريفية',
                hint: 'اكتب نبذة عن خبرتك...',
                maxLines: 3,
              ),
              const SizedBox(height: DSSpacing.lg),
              DSTextField(
                label: 'رقم الهاتف',
                hint: widget.user.phoneNumber ?? '—',
                enabled: false,
              ),
              const SizedBox(height: DSSpacing.xl),
              DSButton(label: 'حفظ التغييرات', fullWidth: true, loading: _saving, onPressed: _save),
            ],
          ),
        ),
        DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'إحصائياتي'),
              const SizedBox(height: DSSpacing.xl),
              _StatRow(label: 'التقييم', value: widget.user.rating.toStringAsFixed(1)),
              _StatRow(label: 'عدد التقييمات', value: '${widget.user.reviewCount}'),
              _StatRow(label: 'المتابعون', value: '${widget.user.followerCount}'),
              if (widget.user.specialization != null)
                _StatRow(label: 'التخصص', value: widget.user.specialization!),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
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
