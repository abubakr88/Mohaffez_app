import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  static const _maxChildPhotoBytes = 3 * 1024 * 1024;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final isParentView = userAsync.maybeWhen(
      data: (user) => user == null || normalizeRole(user.role) == roleParent,
      orElse: () => true,
    );
    final showParentBackArrow =
        normalizeRole(userAsync.valueOrNull?.role) == roleParent;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text(isParentView ? 'إدارة الأبناء/الطلاب' : 'بيانات الطالب'),
          backgroundColor: _tealDark,
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: showParentBackArrow
              ? IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => context.pop(),
                )
              : null,
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
                final isParent = normalizeRole(user.role) == roleParent;
                final visibleProfiles = isParent
                    ? activeProfiles
                        .where((profile) => profile.relationship != 'self')
                        .toList()
                    : <StudentProfileModel>[StudentProfileModel.fromUser(user)];
                final activeProfile = StudentProfileModel.resolveActiveOrNull(
                  user,
                  activeProfiles,
                  allowSelfFallback: !isParent,
                );
                var selectedProfileId = activeProfile?.id;

                return StatefulBuilder(
                  builder: (context, setLocalState) {
                    StudentProfileModel? selectedProfile;
                    for (final profile in visibleProfiles) {
                      if (profile.id == selectedProfileId) {
                        selectedProfile = profile;
                        break;
                      }
                    }
                    final hasPendingChange = selectedProfile != null &&
                        selectedProfile.id != activeProfile?.id;

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
                          _IntroCard(isParent: isParent),
                          const SizedBox(height: 14),
                          if (visibleProfiles.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: _EmptyChildrenCard(),
                            ),
                          ...visibleProfiles.map(
                            (profile) {
                              final isActive =
                                  activeProfile?.id == profile.id ||
                                      (activeProfile?.id == 'self' &&
                                          profile.id == 'self');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ProfileCard(
                                  profile: profile,
                                  isActive: isActive,
                                  isSelected: selectedProfileId == profile.id,
                                  onSetActive: isParent
                                      ? () {
                                          HapticFeedback.selectionClick();
                                          setLocalState(() {
                                            selectedProfileId = profile.id;
                                          });
                                        }
                                      : null,
                                  onEdit: profile.id == 'self'
                                      ? () => _showSelfProfileDialog(
                                            context,
                                            ref,
                                            owner: user,
                                          )
                                      : () => _showProfileDialog(
                                            context,
                                            ref,
                                            owner: user,
                                            profile: profile,
                                          ),
                                  onDelete: profile.id == 'self'
                                      ? null
                                      : () =>
                                          _confirmDelete(context, ref, profile),
                                ),
                              );
                            },
                          ),
                          if (isParent) ...[
                            const SizedBox(height: 4),
                            FilledButton.icon(
                              onPressed: hasPendingChange
                                  ? () => _setActive(
                                        context,
                                        ref,
                                        selectedProfile!,
                                      )
                                  : null,
                              icon: const Icon(Icons.check_circle_rounded),
                              label: Text(
                                selectedProfile == null
                                    ? 'اختر ابنًا لتفعيله'
                                    : hasPendingChange
                                        ? 'تأكيد التبديل إلى ${selectedProfile.name}'
                                        : '${selectedProfile.name} مفعل حاليًا',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _teal,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _border,
                                disabledForegroundColor: _text3,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () =>
                                  _showProfileDialog(context, ref, owner: user),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('إضافة ابن/طالب'),
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
                        ],
                      ),
                    );
                  },
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
    XFile? selectedImage;
    Uint8List? selectedImageBytes;
    bool isSaving = false;

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
                    _ChildPhotoPicker(
                      name: nameController.text.trim(),
                      photoUrl: profile?.photoUrl,
                      selectedBytes: selectedImageBytes,
                      onPick: () async {
                        try {
                          final image = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1200,
                            maxHeight: 1200,
                            imageQuality: 85,
                          );
                          if (image == null) return;
                          final bytes = await image.readAsBytes();
                          if (bytes.length > _maxChildPhotoBytes) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'حجم الصورة كبير. اختر صورة أقل من 3 ميجابايت.',
                                  ),
                                  backgroundColor: AppThemeConstants.error,
                                ),
                              );
                            }
                            return;
                          }
                          setState(() {
                            selectedImage = image;
                            selectedImageBytes = bytes;
                          });
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تعذر اختيار الصورة. يرجى المحاولة مرة أخرى',
                                ),
                                backgroundColor: AppThemeConstants.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
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
                              ? 'مطلوب للمطابقة مع المحفّظ المناسب'
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
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty ||
                              (gender != 'male' && gender != 'female') ||
                              birthDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'أدخل الاسم وحدد النوع وتاريخ الميلاد',
                                ),
                              ),
                            );
                            return;
                          }
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
                            setState(() => isSaving = true);
                            var savedProfile = updated;
                            if (profile == null) {
                              final createdId =
                                  await repository.createProfile(updated);
                              savedProfile = updated.copyWith(id: createdId);
                            } else {
                              await repository.updateProfile(updated);
                            }
                            if (selectedImage != null) {
                              final photoUrl = await _uploadStudentProfilePhoto(
                                ownerId: owner.uid,
                                profileId: savedProfile.id,
                                image: selectedImage!,
                              );
                              await repository.updateProfile(
                                savedProfile.copyWith(photoUrl: photoUrl),
                              );
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
                            if (dialogContext.mounted) {
                              setState(() => isSaving = false);
                            }
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('حفظ'),
                ),
              ],
            ),
          );
        },
      ),
    );

    nameController.dispose();
  }

  static Future<void> _showSelfProfileDialog(
    BuildContext context,
    WidgetRef ref, {
    required UserModel owner,
  }) async {
    String? gender = owner.gender;
    DateTime? birthDate = owner.dateOfBirth;
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إكمال بيانات الطالب'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      initialDate: birthDate ?? DateTime(2010),
                      firstDate: DateTime(1940),
                      lastDate: DateTime.now(),
                      helpText: 'تاريخ الميلاد',
                    );
                    if (picked != null) setState(() => birthDate = picked);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'تاريخ الميلاد',
                      prefixIcon: Icon(Icons.cake_rounded),
                    ),
                    child: Text(
                      birthDate == null
                          ? 'اختر تاريخ الميلاد'
                          : DateFormat('yyyy/MM/dd').format(birthDate!),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if ((gender != 'male' && gender != 'female') ||
                            birthDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('حدد النوع وتاريخ الميلاد'),
                            ),
                          );
                          return;
                        }
                        setState(() => isSaving = true);
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(owner.uid)
                              .update({
                            'gender': gender,
                            'dateOfBirth': Timestamp.fromDate(birthDate!),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          ref.invalidate(currentUserProvider);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تعذر حفظ البيانات. حاول مرة أخرى',
                                ),
                              ),
                            );
                          }
                          setState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<String> _uploadStudentProfilePhoto({
    required String ownerId,
    required String profileId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    if (bytes.length > _maxChildPhotoBytes) {
      throw Exception('child profile photo too large');
    }

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('student_profile_photos')
        .child(ownerId)
        .child(profileId);

    await storageRef.putData(
      bytes,
      SettableMetadata(contentType: _imageContentTypeFor(image)),
    );
    return storageRef.getDownloadURL();
  }

  static String _imageContentTypeFor(XFile image) {
    final mimeType = image.mimeType;
    if (mimeType == 'image/png' ||
        mimeType == 'image/jpeg' ||
        mimeType == 'image/webp') {
      return mimeType!;
    }

    final name = image.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class _ChildPhotoPicker extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final Uint8List? selectedBytes;
  final VoidCallback onPick;

  const _ChildPhotoPicker({
    required this.name,
    required this.photoUrl,
    required this.selectedBytes,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final initial = trimmedName.isNotEmpty ? trimmedName[0] : 'ط';
    final trimmedPhotoUrl = photoUrl?.trim();
    final hasPhoto = selectedBytes != null ||
        (trimmedPhotoUrl != null && trimmedPhotoUrl.isNotEmpty);
    ImageProvider? imageProvider;
    if (selectedBytes != null) {
      imageProvider = MemoryImage(selectedBytes!);
    } else if (hasPhoto) {
      imageProvider = NetworkImage(trimmedPhotoUrl!);
    }

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor:
                  StudentProfilesScreen._teal.withValues(alpha: 0.12),
              backgroundImage: imageProvider,
              child: hasPhoto
                  ? null
                  : Text(
                      initial,
                      style: const TextStyle(
                        color: StudentProfilesScreen._teal,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            Positioned(
              bottom: -2,
              left: -2,
              child: Material(
                color: StudentProfilesScreen._teal,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPick,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.photo_library_rounded, size: 18),
          label: const Text('اختيار صورة الابن'),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  final bool isParent;

  const _IntroCard({required this.isParent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB9E2DA)),
      ),
      child: Row(
        children: [
          Icon(isParent ? Icons.family_restroom_rounded : Icons.person_rounded,
              color: StudentProfilesScreen._teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isParent
                  ? 'اختر الطالب النشط قبل الحجز. سيظهر اسمه للمعلم في الطلب والجلسة، مع بقاء الحساب والدفع تحت حسابك الحالي.'
                  : 'هذا هو ملفك كطالب. حساب الطالب مخصص لطالب واحد فقط، ولإدارة أكثر من طالب يرجى استخدام حساب ولي أمر.',
              style: const TextStyle(
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
  final bool isSelected;
  final VoidCallback? onSetActive;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.isSelected,
    this.onSetActive,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final genderIcon =
        profile.gender == 'female' ? Icons.female_rounded : Icons.male_rounded;
    final photoUrl = profile.photoUrl?.trim();
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
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
              color: isSelected
                  ? StudentProfilesScreen._teal
                  : StudentProfilesScreen._border,
              width: isSelected ? 1.5 : 1,
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
                clipBehavior: Clip.antiAlias,
                child: hasPhoto
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          genderIcon,
                          color: isActive
                              ? StudentProfilesScreen._teal
                              : StudentProfilesScreen._text3,
                        ),
                      )
                    : Icon(
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
                        if (onSetActive != null && isSelected && !isActive)
                          Container(
                            margin: const EdgeInsetsDirectional.only(end: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'مختار',
                              style: TextStyle(
                                fontSize: 11,
                                color: StudentProfilesScreen._teal,
                                fontWeight: FontWeight.w800,
                              ),
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

class _EmptyChildrenCard extends StatelessWidget {
  const _EmptyChildrenCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StudentProfilesScreen._border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.family_restroom_rounded,
            size: 42,
            color: StudentProfilesScreen._teal,
          ),
          SizedBox(height: 10),
          Text(
            'أضف بيانات ابنك الأول',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: StudentProfilesScreen._text2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'سيتم استخدام الطفل النشط في البحث والحجز والدفع والمتابعة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: StudentProfilesScreen._text3,
              height: 1.4,
            ),
          ),
        ],
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
