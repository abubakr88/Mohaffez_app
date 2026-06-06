import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../services/photo_upload_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets/cached_avatar.dart';
import '../../shared/widgets/meeting_links_sheet.dart';
import '../../tour/tour_guard_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS (consistent with home screens)
// ═══════════════════════════════════════════════════════════════════════════════
class _DS {
  static const teal800  = Color(0xFF095752);
  static const teal700  = Color(0xFF0C6F6A);
  static const teal600  = Color(0xFF0E8278);
  static const teal500  = Color(0xFF1A9E84);
  static const teal50   = Color(0xFFEAF6F3);

  static const amber  = Color(0xFFE67E22);
  static const purple = Color(0xFF7A5AF8);
  static const green  = Color(0xFF2E8B57);
  static const blue   = Color(0xFF2563EB);
  static const red    = Color(0xFFDC2626);
  static const redBg  = Color(0xFFFFEBEE);

  static const bg     = Color(0xFFF4F7F6);
  static const text1  = Color(0xFF111827);
  static const text2  = Color(0xFF4B5563);
  static const text3  = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5EDE9);

  static const r8  = BorderRadius.all(Radius.circular(8));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));

  static List<BoxShadow> subtleShadow = [
    const BoxShadow(
      color: AppThemeConstants.shadow,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROOT
// ═══════════════════════════════════════════════════════════════════════════════
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditingBio = false;
  bool _isUploadingPhoto = false;
  final _bioController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _bioController.dispose();
    _youtubeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  // ─── Actions ───────────────────────────────────────────────────────────────
  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        _showSnackBar('لا يمكن فتح تطبيق الهاتف');
      }
    } catch (_) {
      if (mounted) _showSnackBar('تعذّر فتح تطبيق الهاتف');
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        _showSnackBar('لا يمكن فتح تطبيق البريد');
      }
    } catch (_) {
      if (mounted) _showSnackBar('تعذّر فتح تطبيق البريد الإلكتروني');
    }
  }

  String _meetingLinksSubtitle(UserModel user) {
    final count = user.meetingLinks.values.where((v) => v.trim().isNotEmpty).length +
        ((user.meetingLink?.trim().isNotEmpty ?? false) && user.meetingLinks.isEmpty ? 1 : 0);
    if (count == 0) return 'أضف رابط Zoom أو Google Meet أو Teams';
    if (count == 1) return 'تم إضافة رابط واحد';
    return 'تم إضافة $count روابط';
  }

  Future<void> _showMeetingLinksSheet(UserModel user) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeetingLinksSheet(user: user),
    );
    if (saved == true && mounted) {
      ref.invalidate(currentUserProvider);
      _showSnackBar('تم حفظ روابط الاجتماعات', isSuccess: true);
    }
  }

  bool _isValidYoutubeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') || host.contains('youtu.be');
  }

  Future<void> _showPhotoOptionsSheet(UserModel user) async {
    if (guardWriteInTour(ref, context)) return;
    final hasPhoto = user.photoUrl != null && user.photoUrl!.isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppThemeConstants.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _DS.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: _DS.teal500),
                title: const Text('اختيار صورة جديدة'),
                onTap: () => Navigator.pop(ctx, 'pick'),
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.crop_rounded, color: _DS.amber),
                  title: const Text('تعديل الصورة الحالية'),
                  onTap: () => Navigator.pop(ctx, 'edit'),
                ),
              ListTile(
                leading: const Icon(Icons.close_rounded, color: _DS.text3),
                title: const Text(ArabicLabels.cancel),
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (choice == 'pick') {
      await _pickAndUploadPhoto(user.uid);
    } else if (choice == 'edit') {
      await _editCurrentPhoto(user.uid, user.photoUrl!);
    }
  }

  Future<String?> _runCropper(String sourcePath) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 85,
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'اقتصاص الصورة',
          toolbarColor: const Color(0xFF095752),
          toolbarWidgetColor: AppThemeConstants.onPrimary,
          activeControlsWidgetColor: const Color(0xFF1A9E84),
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'اقتصاص الصورة',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    return cropped?.path;
  }

  Future<void> _uploadCroppedPhoto(String userId, String croppedPath) async {
    if (!mounted) return;
    BuildContext? loadingCtx;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        loadingCtx = dialogCtx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    await PhotoUploadService.uploadProfilePhoto(
      userId,
      File(croppedPath),
      FirebaseFirestore.instance,
    );

    if (!mounted) return;
    final ctx = loadingCtx;
    if (ctx != null && ctx.mounted && Navigator.canPop(ctx)) {
      Navigator.of(ctx).pop();
    }
    ref.invalidate(currentUserProvider);
    _showSnackBar('تم تحديث الصورة بنجاح', isSuccess: true);
  }

  Future<void> _pickAndUploadPhoto(String userId) async {
    if (_isUploadingPhoto) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      if (!mounted) return;
      final croppedPath = await _runCropper(image.path);
      if (croppedPath == null) return;
      await _uploadCroppedPhoto(userId, croppedPath);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).maybePop();
      _showSnackBar('تعذّر رفع الصورة. يرجى المحاولة مرة أخرى');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _editCurrentPhoto(String userId, String photoUrl) async {
    if (_isUploadingPhoto) return;
    setState(() => _isUploadingPhoto = true);
    try {
      // Download the current photo to a temp file so the cropper can work on it.
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}${Platform.pathSeparator}edit_profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final client = HttpClient();
      try {
        final req = await client.getUrl(Uri.parse(photoUrl));
        final resp = await req.close();
        if (resp.statusCode != 200) {
          throw Exception('فشل تحميل الصورة الحالية (HTTP ${resp.statusCode})');
        }
        await resp.pipe(tempFile.openWrite());
      } finally {
        client.close(force: true);
      }

      if (!mounted) return;
      final croppedPath = await _runCropper(tempFile.path);
      if (croppedPath == null) return;
      await _uploadCroppedPhoto(userId, croppedPath);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).maybePop();
      _showSnackBar('تعذّر رفع الصورة. يرجى المحاولة مرة أخرى');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveBio(String userId) async {
    if (guardWriteInTour(ref, context)) return;
    try {
      final repository = ref.read(userRepositoryProvider);
      await repository.updateUser(userId, {'bio': _bioController.text.trim()});
      ref.invalidate(currentUserProvider);
      setState(() => _isEditingBio = false);
      if (mounted) _showSnackBar('تم حفظ النبذة بنجاح', isSuccess: true);
    } catch (_) {
      if (mounted) _showSnackBar('تعذّر حفظ النبذة. يرجى المحاولة مرة أخرى');
    }
  }

  Future<void> _saveYoutubeLink(String userId) async {
    if (guardWriteInTour(ref, context)) return;
    try {
      final trimmed = _youtubeController.text.trim();
      if (trimmed.isNotEmpty && !_isValidYoutubeUrl(trimmed)) {
        throw Exception('يرجى إدخال رابط YouTube صحيح');
      }
      final repository = ref.read(userRepositoryProvider);
      await repository.updateUser(userId, {
        'youtubeVideoUrl': trimmed.isEmpty ? null : trimmed,
      });
      ref.invalidate(currentUserProvider);
      if (mounted) _showSnackBar('تم حفظ رابط الفيديو بنجاح', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnackBar(e is Exception && e.toString().contains('YouTube') ? e.toString().replaceFirst('Exception: ', '') : 'تعذّر حفظ رابط الفيديو. يرجى المحاولة مرة أخرى');
    }
  }

  Future<void> _saveName(String userId) async {
    if (guardWriteInTour(ref, context)) return;
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      _showSnackBar('الاسم لا يمكن أن يكون فارغاً');
      return;
    }
    try {
      final repository = ref.read(userRepositoryProvider);
      await repository.updateUser(userId, {'name': trimmed});
      ref.invalidate(currentUserProvider);
      if (mounted) _showSnackBar('تم حفظ الاسم بنجاح', isSuccess: true);
    } catch (_) {
      if (mounted) _showSnackBar('تعذّر حفظ الاسم. يرجى المحاولة مرة أخرى');
    }
  }

  Future<void> _savePhone(String userId) async {
    if (guardWriteInTour(ref, context)) return;
    final trimmed = _phoneController.text.trim();
    // Allow clearing the number; otherwise require digits-only (with optional +).
    if (trimmed.isNotEmpty &&
        !RegExp(r'^\+?[0-9\s\-]{7,20}$').hasMatch(trimmed)) {
      _showSnackBar('يرجى إدخال رقم هاتف صحيح');
      return;
    }
    try {
      final repository = ref.read(userRepositoryProvider);
      await repository.updateUser(userId, {
        'phoneNumber': trimmed.isEmpty ? null : trimmed,
      });
      ref.invalidate(currentUserProvider);
      if (mounted) _showSnackBar('تم حفظ رقم الهاتف بنجاح', isSuccess: true);
    } catch (_) {
      if (mounted) _showSnackBar('تعذّر حفظ رقم الهاتف. يرجى المحاولة مرة أخرى');
    }
  }

  Future<void> _showEditNameDialog(UserModel user) async {
    _nameController.text = user.name;
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: _DS.r16),
          title: const Text('تعديل الاسم',
              style: TextStyle(fontWeight: FontWeight.w700, color: _DS.text1)),
          content: TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'الاسم الكامل',
              border: OutlineInputBorder(borderRadius: _DS.r12),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(ArabicLabels.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _saveName(user.uid);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.teal500,
                shape: const RoundedRectangleBorder(borderRadius: _DS.r8),
              ),
              child: const Text(ArabicLabels.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditPhoneDialog(UserModel user) async {
    _phoneController.text = user.phoneNumber ?? '';
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: _DS.r16),
          title: const Text('تعديل رقم الهاتف',
              style: TextStyle(fontWeight: FontWeight.w700, color: _DS.text1)),
          content: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '+20XXXXXXXXXX',
              border: OutlineInputBorder(borderRadius: _DS.r12),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(ArabicLabels.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _savePhone(user.uid);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.teal500,
                shape: const RoundedRectangleBorder(borderRadius: _DS.r8),
              ),
              child: const Text(ArabicLabels.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? _DS.green : null,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: _DS.r12),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────
  Future<void> _showYoutubeLinkDialog(String userId) async {
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: _DS.r16),
          title: const Text('رابط فيديو التلاوة',
              style: TextStyle(fontWeight: FontWeight.w700, color: _DS.text1)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _youtubeController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'https://youtube.com/...',
                  border: OutlineInputBorder(borderRadius: _DS.r12),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'أضف رابط YouTube لفيديو تلاوة مسجل بصوتك.',
                style: TextStyle(fontSize: 12, color: _DS.text3),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(ArabicLabels.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _saveYoutubeLink(userId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.teal500,
                shape: const RoundedRectangleBorder(borderRadius: _DS.r8),
              ),
              child: const Text(ArabicLabels.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: _DS.r16),
          title: const Text('تغيير كلمة المرور',
              style: TextStyle(fontWeight: FontWeight.w700, color: _DS.text1)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPwCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                    border: OutlineInputBorder(borderRadius: _DS.r12),
                  ),
                  validator: (val) => val?.isEmpty ?? true ? 'مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPwCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    border: OutlineInputBorder(borderRadius: _DS.r12),
                  ),
                  validator: (val) {
                    if (val?.isEmpty ?? true) return 'مطلوب';
                    if (val!.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPwCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    border: OutlineInputBorder(borderRadius: _DS.r12),
                  ),
                  validator: (val) {
                    if (val != newPwCtrl.text) return 'كلمة المرور غير متطابقة';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(ArabicLabels.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx);
                  if (mounted) {
                    _showSnackBar('تم تغيير كلمة المرور بنجاح', isSuccess: true);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.teal500,
                shape: const RoundedRectangleBorder(borderRadius: _DS.r8),
              ),
              child: const Text(ArabicLabels.save),
            ),
          ],
        ),
      ),
    );

    currentPwCtrl.dispose();
    newPwCtrl.dispose();
    confirmPwCtrl.dispose();
  }

  Future<void> _showLogoutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: _DS.r16),
          title: const Text('تسجيل الخروج',
              style: TextStyle(fontWeight: FontWeight.w700, color: _DS.text1)),
          content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(ArabicLabels.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.red,
                shape: const RoundedRectangleBorder(borderRadius: _DS.r8),
              ),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text(ArabicLabels.noData)));
        }

        final isMohaffez = user.role == 'mohaffez';

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: AppThemeConstants.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: _DS.bg,
              body: RefreshIndicator(
                color: _DS.teal500,
                backgroundColor: AppThemeConstants.surface,
                onRefresh: () async {
                  ref.invalidate(currentUserProvider);
                  await ref.read(currentUserProvider.future).catchError((_) => null);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ─── Header ──────────────────────────────────────────
                    SliverAppBar(
                      expandedHeight: isMohaffez ? 240 : 200,
                      pinned: true,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      backgroundColor: _DS.teal700,
                      surfaceTintColor: AppThemeConstants.transparent,
                      automaticallyImplyLeading: false,
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.pin,
                        background: _ProfileHeader(
                          name: user.name,
                          photoUrl: user.photoUrl,
                          isMohaffez: isMohaffez,
                          followerCount: isMohaffez ? user.followerCount : 0,
                          rating: isMohaffez ? user.rating : 0,
                          onEditPhoto: () => _showPhotoOptionsSheet(user),
                          onEditName: () => _showEditNameDialog(user),
                        ),
                      ),
                    ),

                    // ─── Body ────────────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 36),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Rewards card + wallet balance — students only (top of screen)
                          if (!isMohaffez) ...[
                            _RewardsTeaserCard(userId: user.uid, dateOfBirth: user.dateOfBirth),
                            const SizedBox(height: 12),
                            _StudentWalletCard(userId: user.uid),
                            const SizedBox(height: 12),
                          ],

                          // Bio
                          _SectionCard(
                            title: 'نبذة تعريفية',
                            icon: Icons.info_outline_rounded,
                            color: _DS.blue,
                            child: _isEditingBio
                                ? _BioEditor(
                                    controller: _bioController,
                                    onSave: () => _saveBio(user.uid),
                                    onCancel: () => setState(() => _isEditingBio = false),
                                  )
                                : _BioDisplay(
                                    bio: user.bio,
                                    onEdit: () {
                                      _bioController.text = user.bio ?? '';
                                      setState(() => _isEditingBio = true);
                                    },
                                  ),
                          ),
                          const SizedBox(height: 12),

                          // Contact info
                          _SectionCard(
                            title: 'معلومات التواصل',
                            icon: Icons.contact_mail_rounded,
                            color: _DS.green,
                            child: Column(
                              children: [
                                _ContactRow(
                                  icon: Icons.email_rounded,
                                  label: 'البريد الإلكتروني',
                                  value: user.email,
                                  color: _DS.blue,
                                  onTap: () => _sendEmail(user.email),
                                ),
                                const Divider(height: 1, color: _DS.border),
                                _ContactRow(
                                  icon: Icons.phone_rounded,
                                  label: 'رقم الهاتف',
                                  value: (user.phoneNumber?.isNotEmpty ?? false)
                                      ? user.phoneNumber!
                                      : 'أضف رقم الهاتف',
                                  color: _DS.green,
                                  onTap: () {
                                    if (user.phoneNumber?.isNotEmpty ?? false) {
                                      _makePhoneCall(user.phoneNumber!);
                                    } else {
                                      _showEditPhoneDialog(user);
                                    }
                                  },
                                  onEdit: () => _showEditPhoneDialog(user),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Mohaffez account management
                          if (isMohaffez) ...[
                            _SectionCard(
                              title: 'إدارة الحساب',
                              icon: Icons.verified_user_rounded,
                              color: _DS.purple,
                              child: Column(
                                children: [
                                  _ActionTile(
                                    icon: Icons.verified_user_rounded,
                                    title: 'الاعتمادات',
                                    subtitle: 'شهاداتك وتخصصاتك',
                                    color: _DS.purple,
                                    onTap: () => context.push('/credentials'),
                                  ),
                                  _ActionTile(
                                    icon: Icons.schedule_rounded,
                                    title: 'إدارة المواعيد',
                                    subtitle: 'أوقات الجلسات المتاحة',
                                    color: _DS.blue,
                                    onTap: () => context.push('/availability'),
                                  ),
                                  _ActionTile(
                                    icon: Icons.account_balance_wallet_rounded,
                                    title: 'محافظ الدفع المباشر',
                                    subtitle: 'InstaPay، فودافون كاش، أورانج موني',
                                    color: _DS.green,
                                    onTap: () => context.push('/wallet-settings'),
                                  ),
                                  _ActionTile(
                                    icon: Icons.ondemand_video_rounded,
                                    title: 'رابط فيديو التلاوة',
                                    subtitle: (user.youtubeVideoUrl?.isNotEmpty ?? false)
                                        ? 'تمت إضافة رابط YouTube'
                                        : 'أضف رابط YouTube لتلاوة مسجلة',
                                    color: _DS.red,
                                    onTap: () {
                                      _youtubeController.text = user.youtubeVideoUrl ?? '';
                                      _showYoutubeLinkDialog(user.uid);
                                    },
                                  ),
                                  _ActionTile(
                                    icon: Icons.videocam_rounded,
                                    title: 'روابط الاجتماعات أونلاين',
                                    subtitle: _meetingLinksSubtitle(user),
                                    color: _DS.teal500,
                                    isLast: true,
                                    onTap: () => _showMeetingLinksSheet(user),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Settings
                          _SectionCard(
                            title: 'الإعدادات',
                            icon: Icons.settings_rounded,
                            color: _DS.amber,
                            child: Column(
                              children: [
                                _ActionTile(
                                  icon: Icons.lock_rounded,
                                  title: 'تغيير كلمة المرور',
                                  subtitle: 'تحديث كلمة المرور الحالية',
                                  color: _DS.amber,
                                  onTap: _showChangePasswordDialog,
                                ),
                                _ActionTile(
                                  icon: Icons.privacy_tip_rounded,
                                  title: 'إعدادات الخصوصية',
                                  subtitle: 'التحكم في بيانات حسابك',
                                  color: _DS.purple,
                                  onTap: () => context.push('/privacy-settings'),
                                ),
                                _ActionTile(
                                  icon: Icons.policy_rounded,
                                  title: 'سياسة الإلغاء والغياب',
                                  subtitle: 'قواعد الإلغاء والاسترداد لكلا الطرفين',
                                  color: _DS.teal700,
                                  onTap: () => context.push('/cancellation-policy'),
                                ),
                                _ActionTile(
                                  icon: Icons.location_on_rounded,
                                  title: 'إعدادات الموقع',
                                  subtitle: 'حدد موقعك للظهور في البحث',
                                  color: _DS.teal500,
                                  isLast: true,
                                  onTap: () {
                                    context.push('/location-settings');
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Logout
                          Material(
                            color: AppThemeConstants.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                _showLogoutDialog();
                              },
                              borderRadius: _DS.r16,
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: _DS.redBg,
                                  borderRadius: _DS.r16,
                                  border: Border.all(color: _DS.red.withValues(alpha: 0.25)),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.logout_rounded, color: _DS.red, size: 20),
                                      SizedBox(width: 10),
                                      Text(
                                        'تسجيل الخروج',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _DS.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(
        body: ErrorDisplay(
          message: 'تعذّر تحميل الملف الشخصي. يرجى المحاولة مرة أخرى',
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════════
class _ProfileHeader extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isMohaffez;
  final int followerCount;
  final double rating;
  final VoidCallback onEditPhoto;
  final VoidCallback onEditName;

  const _ProfileHeader({
    required this.name,
    required this.photoUrl,
    required this.isMohaffez,
    required this.followerCount,
    required this.rating,
    required this.onEditPhoto,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_DS.teal800, _DS.teal600],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -50, left: -50,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppThemeConstants.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -20, right: -20,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppThemeConstants.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Avatar with edit overlay
                    Stack(
                      children: [
                        Hero(
                          tag: 'profile-avatar',
                          child: CachedAvatar(
                            imageUrl: photoUrl,
                            radius: 46,
                            semanticLabel: name,
                          ),
                        ),
                        if (!kIsWeb)
                          Positioned(
                            bottom: 0, right: 0,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onEditPhoto();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _DS.teal500,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppThemeConstants.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppThemeConstants.black.withValues(alpha: 0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.camera_alt_rounded, color: AppThemeConstants.white, size: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Name (tap pencil to edit)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800,
                              color: AppThemeConstants.white, letterSpacing: -0.3,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onEditName();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: AppThemeConstants.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Role chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppThemeConstants.white.withValues(alpha: 0.15),
                        borderRadius: _DS.r12,
                        border: Border.all(color: AppThemeConstants.white.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        isMohaffez ? 'محفّظ' : 'طالب',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppThemeConstants.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                    // Mohaffez stats
                    if (isMohaffez) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _HeaderStat(
                            icon: Icons.people_rounded,
                            label: 'المتابعون',
                            value: followerCount.toString(),
                          ),
                          Container(
                            width: 1, height: 24,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            color: AppThemeConstants.white.withValues(alpha: 0.25),
                          ),
                          _HeaderStat(
                            icon: Icons.star_rounded,
                            label: 'التقييم',
                            value: rating.toStringAsFixed(1),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppThemeConstants.white.withValues(alpha: 0.7), size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppThemeConstants.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10, color: AppThemeConstants.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: _DS.r16,
        border: Border.all(color: _DS.border),
        boxShadow: _DS.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: _DS.r8,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _DS.text1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _DS.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BIO WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════
class _BioDisplay extends StatelessWidget {
  final String? bio;
  final VoidCallback onEdit;

  const _BioDisplay({required this.bio, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasBio = bio != null && bio!.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: Text(
            hasBio ? bio! : 'لا توجد نبذة',
            style: TextStyle(
              fontSize: 14,
              color: hasBio ? _DS.text1 : _DS.text3,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppThemeConstants.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onEdit();
            },
            borderRadius: _DS.r8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: _DS.teal50,
                borderRadius: _DS.r8,
              ),
              child: const Icon(Icons.edit_rounded, size: 16, color: _DS.teal500),
            ),
          ),
        ),
      ],
    );
  }
}

class _BioEditor extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _BioEditor({
    required this.controller,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'أضف نبذة عنك...',
            hintStyle: TextStyle(color: _DS.text3),
            border: OutlineInputBorder(borderRadius: _DS.r12),
            focusedBorder: OutlineInputBorder(
              borderRadius: _DS.r12,
              borderSide: BorderSide(color: _DS.teal500, width: 1.5),
            ),
            contentPadding: EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: _DS.text2),
              child: const Text(ArabicLabels.cancel),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.teal500,
                shape: const RoundedRectangleBorder(borderRadius: _DS.r8),
              ),
              child: const Text(ArabicLabels.save),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTACT ROW
// ═══════════════════════════════════════════════════════════════════════════════
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppThemeConstants.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: _DS.r8,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: _DS.r8,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontSize: 11, color: _DS.text3)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null) ...[
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onEdit!();
                  },
                  borderRadius: _DS.r8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: _DS.teal50,
                      borderRadius: _DS.r8,
                    ),
                    child: const Icon(Icons.edit_rounded,
                        size: 14, color: _DS.teal500),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION TILE (used in Account Management & Settings sections)
// ═══════════════════════════════════════════════════════════════════════════════
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isLast;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppThemeConstants.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            borderRadius: _DS.r12,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: _DS.r12,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: _DS.text1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 12, color: _DS.text2),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: _DS.text3),
                ],
              ),
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1, color: _DS.border),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ERROR DISPLAY (fallback for this screen)
// ═══════════════════════════════════════════════════════════════════════════════
class ErrorDisplay extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorDisplay({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _DS.red, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 15, color: _DS.text1),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _DS.teal500,
                  shape: const RoundedRectangleBorder(borderRadius: _DS.r8),
                ),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Rewards teaser card (student profile) ────────────────────────────────────
class _RewardsTeaserCard extends ConsumerWidget {
  final String userId;
  final DateTime? dateOfBirth;

  const _RewardsTeaserCard({required this.userId, required this.dateOfBirth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahsAsync   = ref.watch(memorizedSurahsProvider(userId));
    final sessionsAsync = ref.watch(studentCompletedSessionsProvider(userId));

    final age      = calculateAge(dateOfBirth);
    final sessions = sessionsAsync.valueOrNull ?? 0;
    final memorized = surahsAsync.valueOrNull?.length ?? 0;
    final level    = resolveLevel(sessions, age);

    return GestureDetector(
      onTap: () => context.push('/student-rewards'),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF095752), Color(0xFF0C6F6A)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF095752).withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A44A).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4A44A).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(level.emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'لوحة المكافآت',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$sessions حلقة',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Colors.white38,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$memorized سورة محفوظة',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Student Wallet Balance Card ───────────────────────────────────────────────
class _StudentWalletCard extends ConsumerWidget {
  final String userId;
  const _StudentWalletCard({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider(
      (userId: userId, ownerType: WalletOwnerType.student),
    ));

    return Container(
      decoration: BoxDecoration(
        color: AppThemeConstants.surface,
        borderRadius: _DS.r16,
        boxShadow: _DS.subtleShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _DS.teal500.withValues(alpha: 0.12),
              borderRadius: _DS.r12,
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: _DS.teal500, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('رصيد محفظتي',
                    style: TextStyle(
                        fontSize: 13, color: AppThemeConstants.textSecondary)),
                walletAsync.when(
                  data: (w) => Text(
                    '${w.balanceEgp.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _DS.teal800,
                    ),
                  ),
                  loading: () => const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (_, __) => const Text('—',
                      style: TextStyle(
                          fontSize: 20, color: AppThemeConstants.textSecondary)),
                ),
              ],
            ),
          ),
          const Text('المبالغ المستردة\nتُضاف هنا',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: AppThemeConstants.textSecondary,
                  height: 1.4)),
        ],
      ),
    );
  }
}
