import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart'; // ✅ ADD THIS
import 'package:go_router/go_router.dart'; // ✅ ADD THIS

import '../shared/constants/app_theme.dart';
import '../shared/widgets/cached_avatar.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../repositories/user_repository.dart';
import '../utils/arabic_labels.dart';
import 'location_settings_screen.dart';
import 'mohaffez_wallet_settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool isEditingBio = false;
  final bioController = TextEditingController();

  @override
  void dispose() {
    bioController.dispose();
    super.dispose();
  }

  // ✅ ADD: Helper to make phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن فتح تطبيق الهاتف')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ArabicLabels.error}: $e')),
        );
      }
    }
  }

  // ✅ ADD: Helper to send email
  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(scheme: 'mailto', path: email);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن فتح تطبيق البريد')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ArabicLabels.error}: $e')),
        );
      }
    }
  }

  // ✅ ADD: Helper to show change password dialog
  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val?.isEmpty ?? true ? 'مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val?.isEmpty ?? true) return 'مطلوب';
                    if (val!.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val != newPasswordController.text) {
                      return 'كلمة المرور غير متطابقة';
                    }
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
                  try {
                    // TODO: Implement password change logic
                    // await ref.read(authProvider.notifier).changePassword(...)
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تغيير كلمة المرور بنجاح'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text(ArabicLabels.save),
            ),
          ],
        ),
      ),
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text(ArabicLabels.noData)));
        }

        final isMohaffez = user.role == 'mohaffez';

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentUserProvider);
                await ref
                    .read(currentUserProvider.future)
                    .catchError((_) => null);
              },
              child: CustomScrollView(
                slivers: [
                  // Profile Header
                  SliverAppBar(
                    expandedHeight: 300,
                    pinned: true,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'تحديث',
                        onPressed: () => ref.invalidate(currentUserProvider),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Gradient Background
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryAmber,
                                  AppTheme.lightAmber,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          // Profile Content
                          SafeArea(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Avatar with edit button
                                Stack(
                                  children: [
                                    Hero(
                                      tag: 'profile-avatar',
                                      child: CachedAvatar(
                                        imageUrl: user.photoUrl,
                                        radius: 60,
                                        semanticLabel: user.name,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _pickAndUploadPhoto(user.uid),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryAmber,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.2),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Name
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Role
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isMohaffez ? 'محفّظ' : 'طالب',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Stats (if mohaffez)
                                if (isMohaffez)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _StatItem(
                                        label: 'المتابعون',
                                        value: user.followerCount.toString(),
                                      ),
                                      const SizedBox(width: 32),
                                      _StatItem(
                                        label: 'التقييم',
                                        value: user.rating.toStringAsFixed(1),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Bio Section
                        _ProfileSection(
                          title: 'نبذة تعريفية',
                          icon: Icons.info_outline,
                          color: Colors.blue,
                          child: isEditingBio
                              ? Column(
                                  children: [
                                    TextField(
                                      controller: bioController,
                                      maxLines: 4,
                                      maxLength: 200,
                                      decoration: const InputDecoration(
                                        hintText: 'أضف نبذة عنك...',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              isEditingBio = false;
                                            });
                                          },
                                          child:
                                              const Text(ArabicLabels.cancel),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () => _saveBio(user.uid),
                                          child: const Text(ArabicLabels.save),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (user.bio?.isEmpty ?? true)
                                            ? 'لا توجد نبذة'
                                            : user.bio!,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: (user.bio?.isEmpty ?? true)
                                              ? Colors.grey.shade500
                                              : Colors.black87,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          bioController.text = user.bio ?? '';
                                          isEditingBio = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),

                        // ✅ FIXED: Contact Info - Now Clickable
                        _ProfileSection(
                          title: 'معلومات التواصل',
                          icon: Icons.contact_page,
                          color: Colors.green,
                          child: Column(
                            children: [
                              // Email - Clickable
                              InkWell(
                                onTap: () => _sendEmail(user.email),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.email,
                                        size: 20,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'البريد الإلكتروني',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              user.email,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14,
                                        color: Colors.blue,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Phone - Clickable
                              if (user.phoneNumber?.isNotEmpty ?? false) ...[
                                const Divider(height: 24),
                                InkWell(
                                  onTap: () =>
                                      _makePhoneCall(user.phoneNumber!),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          size: 20,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'رقم الهاتف',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                user.phoneNumber!,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: Colors.green,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ✅ FIXED: Mohaffez-only sections - Now Clickable
                        if (isMohaffez) ...[
                          _ProfileSection(
                            title: 'إدارة الحساب',
                            icon: Icons.verified_user,
                            color: Colors.purple,
                            child: Column(
                              children: [
                                _ManagementTile(
                                  icon: Icons.verified_user,
                                  title: 'الاعتمادات',
                                  subtitle: 'شهاداتك وتخصصاتك',
                                  color: Colors.purple,
                                  onTap: () => context.push('/credentials'),
                                ),
                                const SizedBox(height: 12),
                                _ManagementTile(
                                  icon: Icons.schedule,
                                  title: 'إدارة المواعيد',
                                  subtitle: 'أوقات الجلسات المتاحة',
                                  color: Colors.blue,
                                  onTap: () => context.push('/availability'),
                                ),
                                const SizedBox(height: 12), // ← ADD THIS
                                _ManagementTile(
                                  // ← ADD THIS TILE
                                  icon: Icons.account_balance_wallet,
                                  title: 'محافظ الدفع المباشر',
                                  subtitle:
                                      'InstaPay، فودافون كاش، أورانج موني، ...',
                                  color: Colors.green,
                                  onTap: () => context.push('/wallet-settings'),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ✅ FIXED: Settings - Now Clickable
                        _ProfileSection(
                          title: 'الإعدادات',
                          icon: Icons.settings,
                          color: Colors.orange,
                          child: Column(
                            children: [
                              _SettingsTile(
                                icon: Icons.lock,
                                title: 'تغيير كلمة المرور',
                                onTap: _showChangePasswordDialog, // ✅ FIXED
                              ),
                              const Divider(height: 1),
                              _SettingsTile(
                                icon: Icons.privacy_tip,
                                title: 'إعدادات الخصوصية',
                                onTap: () => context
                                    .push('/privacy-settings'), // ✅ FIXED
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const SizedBox(height: 12),
                        _ManagementTile(
                          icon: Icons.location_on,
                          title: 'إعدادات الموقع',
                          subtitle: 'حدد موقعك للظهور في البحث',
                          color: Colors.red,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LocationSettingsScreen(),
                              ),
                            );
                          },
                        ),

                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showLogoutDialog(context),
                            icon: const Icon(Icons.logout),
                            label: const Text('تسجيل الخروج'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side:
                                  const BorderSide(color: Colors.red, width: 2),
                              foregroundColor: Colors.red,
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
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('${ArabicLabels.error}: $e')),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(String userId) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Upload photo
      final repository = ref.read(userRepositoryProvider);
      await repository.uploadProfilePhoto(userId, File(image.path));

      // Refresh user data
      ref.invalidate(currentUserProvider);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الصورة بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ArabicLabels.error}: $e')),
      );
    }
  }

  Future<void> _saveBio(String userId) async {
    try {
      final repository = ref.read(userRepositoryProvider);
      // ✅ FIXED: Pass bio as a Map entry, not a named parameter
      await repository.updateUser(userId, {
        'bio': bioController.text.trim(),
      });
      ref.invalidate(currentUserProvider);

      setState(() {
        isEditingBio = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ النبذة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ArabicLabels.error}: $e')),
        );
      }
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(ArabicLabels.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ManagementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ManagementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
