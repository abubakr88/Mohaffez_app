import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

class StudentProfilesScreen extends ConsumerWidget {
  const StudentProfilesScreen({super.key});

  static const _teal = Color(0xFF0E8278);
  static const _tealDark = Color(0xFF095752);
  static const _bg = Color(0xFFF4F7F6);
  static const _border = Color(0xFFE5EDE9);
  static const _text2 = Color(0xFF4B5563);
  static const _text3 = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text('إدارة الطلاب'),
          backgroundColor: _tealDark,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _ErrorState(
            onRetry: () => ref.invalidate(currentUserProvider),
          ),
          data: (user) {
            if (user == null) {
              return const Center(child: Text('يرجى تسجيل الدخول أولا'));
            }
            final profilesAsync = ref.watch(studentProfilesProvider(user.uid));
            return profilesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _ErrorState(
                onRetry: () =>
                    ref.invalidate(studentProfilesProvider(user.uid)),
              ),
              data: (profiles) {
                final activeProfiles =
                    profiles.where((profile) => profile.isActive).toList();
                final visibleProfiles = [
                  StudentProfileModel.fromUser(user),
                  ...activeProfiles
                      .where((profile) => profile.relationship != 'self'),
                ];
                final activeProfile =
                    StudentProfileModel.resolveActive(user, activeProfiles);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(studentProfilesProvider(user.uid));
                    await Future<void>.delayed(
                      const Duration(milliseconds: 200),
                    );
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                    children: [
                      const _IntroCard(),
                      const SizedBox(height: 14),
                      ...visibleProfiles.map(
                        (profile) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ProfileCard(
                            profile: profile,
                            isActive: activeProfile.id == profile.id ||
                                (activeProfile.id == 'self' &&
                                    profile.id == 'self'),
                            onSetActive: () =>
                                _setActive(context, ref, profile),
                            onEdit: profile.id == 'self'
                                ? null
                                : () => _showProfileDialog(
                                      context,
                                      ref,
                                      owner: user,
                                      profile: profile,
                                    ),
                            onDelete: profile.id == 'self'
                                ? null
                                : () => _confirmDelete(context, ref, profile),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () =>
                            _showProfileDialog(context, ref, owner: user),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('إضافة طالب'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  static Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    StudentProfileModel profile,
  ) async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(studentProfileRepositoryProvider).setActiveProfile(
            ownerId: profile.ownerId,
            profileId: profile.id,
          );
      ref.invalidate(currentUserProvider);
      ref.invalidate(studentProfilesProvider(profile.ownerId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم اختيار ${profile.name} للحجوزات القادمة'),
            backgroundColor: AppThemeConstants.success,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر اختيار الطالب، يرجى المحاولة مرة أخرى'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    }
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    StudentProfileModel profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الطالب؟'),
          content: Text(
            'سيتم إخفاء ${profile.name} من الاختيارات القادمة، ولن تتأثر الطلبات أو الجلسات السابقة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppThemeConstants.error,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(studentProfileRepositoryProvider).softDeleteProfile(
            ownerId: profile.ownerId,
            profileId: profile.id,
          );
      ref.invalidate(currentUserProvider);
      ref.invalidate(studentProfilesProvider(profile.ownerId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر حذف الطالب، يرجى المحاولة مرة أخرى'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    }
  }

  static Future<void> _showProfileDialog(
    BuildContext context,
    WidgetRef ref, {
    required UserModel owner,
    StudentProfileModel? profile,
  }) async {
    final nameController = TextEditingController(text: profile?.name ?? '');
    String? gender = profile?.gender;
    DateTime? birthDate = profile?.dateOfBirth;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final isEdit = profile != null;
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              title: Text(isEdit ? 'تعديل بيانات الطالب' : 'إضافة طالب'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الطالب',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: gender,
                      decoration: const InputDecoration(
                        labelText: 'النوع',
                        prefixIcon: Icon(Icons.wc_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('طالب')),
                        DropdownMenuItem(value: 'female', child: Text('طالبة')),
                      ],
                      onChanged: (value) => setState(() => gender = value),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: birthDate ?? DateTime(2015),
                          firstDate: DateTime(1980),
                          lastDate: DateTime.now(),
                          helpText: 'تاريخ الميلاد',
                        );
                        if (picked != null) {
                          setState(() => birthDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ الميلاد',
                          prefixIcon: Icon(Icons.cake_rounded),
                        ),
                        child: Text(
                          birthDate == null
                              ? 'اختياري'
                              : DateFormat('yyyy/MM/dd').format(birthDate!),
                          style: TextStyle(
                            color: birthDate == null ? _text3 : _text2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final repository =
                        ref.read(studentProfileRepositoryProvider);
                    final updated = (profile ??
                            StudentProfileModel(
                              id: '',
                              ownerId: owner.uid,
                              name: name,
                              relationship: 'child',
                            ))
                        .copyWith(
                      name: name,
                      gender: gender,
                      dateOfBirth: birthDate,
                    );

                    try {
                      if (profile == null) {
                        await repository.createProfile(updated);
                      } else {
                        await repository.updateProfile(updated);
                      }
                      ref.invalidate(currentUserProvider);
                      ref.invalidate(studentProfilesProvider(owner.uid));
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تعذر حفظ البيانات'),
                            backgroundColor: AppThemeConstants.error,
                          ),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  child: const Text('حفظ'),
                ),
              ],
            ),
          );
        },
      ),
    );

    nameController.dispose();
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB9E2DA)),
      ),
      child: const Row(
        children: [
          Icon(Icons.family_restroom_rounded,
              color: StudentProfilesScreen._teal),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'اختر الطالب النشط قبل الحجز. سيظهر اسمه للمعلم في الطلب والجلسة، مع بقاء الحساب والدفع تحت حسابك الحالي.',
              style: TextStyle(
                color: StudentProfilesScreen._text2,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final StudentProfileModel profile;
  final bool isActive;
  final VoidCallback onSetActive;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onSetActive,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final genderIcon =
        profile.gender == 'female' ? Icons.female_rounded : Icons.male_rounded;
    final relationship =
        profile.relationship == 'self' ? 'الحساب الحالي' : 'طالب مُدار';
    final details = [
      relationship,
      if (profile.age != null) '${profile.age} سنة',
      if (profile.gender == 'female') 'طالبة',
      if (profile.gender == 'male') 'طالب',
    ].join(' • ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSetActive,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? StudentProfilesScreen._teal
                  : StudentProfilesScreen._border,
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isActive
                      ? StudentProfilesScreen._teal.withValues(alpha: 0.12)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  genderIcon,
                  color: isActive
                      ? StudentProfilesScreen._teal
                      : StudentProfilesScreen._text3,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'نشط',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2E8B57),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: const TextStyle(
                        fontSize: 12,
                        color: StudentProfilesScreen._text2,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'تعديل',
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  color: StudentProfilesScreen._teal,
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppThemeConstants.error,
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppThemeConstants.error,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text('تعذر تحميل بيانات الطلاب'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
