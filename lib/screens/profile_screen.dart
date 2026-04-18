import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../repositories/user_repository.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/cached_avatar.dart';
import '../utils/arabic_labels.dart';

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

  @override
  void dispose() {
    _bioController.dispose();
    _youtubeController.dispose();
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
    } catch (e) {
      if (mounted) _showSnackBar('${ArabicLabels.error}: $e');
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
    } catch (e) {
      if (mounted) _showSnackBar('${ArabicLabels.error}: $e');
    }
  }

  bool _isValidYoutubeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') || host.contains('youtu.be');
  }

  Future<void> _pickAndUploadPhoto(String userId) async {
    if (_isUploadingPhoto) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        if (mounted) setState(() => _isUploadingPhoto = false);
        return;
      }

      if (!mounted) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
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
      if (cropped == null) return;

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

      final repository = ref.read(userRepositoryProvider);
      await repository.uploadProfilePhoto(userId, File(cropped.path));

      if (!mounted) return;
      final ctx = loadingCtx;
      if (ctx != null && ctx.mounted && Navigator.canPop(ctx)) {
        Navigator.of(ctx).pop();
      }
      ref.invalidate(currentUserProvider);
      _showSnackBar('تم تحديث الصورة بنجاح', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).maybePop();
      _showSnackBar('${ArabicLabels.error}: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveBio(String userId) async {
    try {
      final repository = ref.read(userRepositoryProvider);
      await repository.updateUser(userId, {'bio': _bioController.text.trim()});
      ref.invalidate(currentUserProvider);
      setState(() => _isEditingBio = false);
      if (mounted) _showSnackBar('تم حفظ النبذة بنجاح', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnackBar('${ArabicLabels.error}: $e');
    }
  }

  Future<void> _saveYoutubeLink(String userId) async {
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
      if (mounted) _showSnackBar('${ArabicLabels.error}: $e');
    }
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
            statusBarColor: Colors.transparent,
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
                      surfaceTintColor: Colors.transparent,
                      automaticallyImplyLeading: false,
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.pin,
                        background: _ProfileHeader(
                          name: user.name,
                          photoUrl: user.photoUrl,
                          isMohaffez: isMohaffez,
                          followerCount: isMohaffez ? user.followerCount : 0,
                          rating: isMohaffez ? user.rating : 0,
                          onEditPhoto: () => _pickAndUploadPhoto(user.uid),
                        ),
                      ),
                    ),

                    // ─── Body ────────────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 36),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
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
                                if (user.phoneNumber?.isNotEmpty ?? false) ...[
                                  const Divider(height: 1, color: _DS.border),
                                  _ContactRow(
                                    icon: Icons.phone_rounded,
                                    label: 'رقم الهاتف',
                                    value: user.phoneNumber!,
                                    color: _DS.green,
                                    onTap: () => _makePhoneCall(user.phoneNumber!),
                                  ),
                                ],
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
                                    isLast: true,
                                    onTap: () {
                                      _youtubeController.text = user.youtubeVideoUrl ?? '';
                                      _showYoutubeLinkDialog(user.uid);
                                    },
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
                            color: Colors.transparent,
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
      error: (e, _) => Scaffold(
        body: ErrorDisplay(
          message: '${ArabicLabels.error}: $e',
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

  const _ProfileHeader({
    required this.name,
    required this.photoUrl,
    required this.isMohaffez,
    required this.followerCount,
    required this.rating,
    required this.onEditPhoto,
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
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -20, right: -20,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
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
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Name
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: -0.3,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Role chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: _DS.r12,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        isMohaffez ? 'محفّظ' : 'طالب',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.95),
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
                            color: Colors.white.withValues(alpha: 0.25),
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
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10, color: Colors.white.withValues(alpha: 0.7),
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
        color: Colors.white,
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
          color: Colors.transparent,
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

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
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
          color: Colors.transparent,
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
