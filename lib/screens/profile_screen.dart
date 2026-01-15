// screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

import '../shared/constants/app_theme.dart';
import '../shared/widgets/cached_avatar.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../shared/utils/error_handler.dart';
import '../services/profile_completion_service.dart';
import 'mohaffez_credentials_screen.dart';
import 'availability_management_screen.dart';
import 'privacy_settings_screen.dart';
import 'login_screen.dart';
import '../repositories/user_repository.dart'; // ✅ ADD THIS LINE

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Edit mode flags
  bool isEditingBio = false;
  bool isEditingPhone = false;
  bool isEditingSpecialization = false;

  // Controllers
  final bioController = TextEditingController();
  final phoneController = TextEditingController();
  final specializationController = TextEditingController();

  @override
  void dispose() {
    bioController.dispose();
    phoneController.dispose();
    specializationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: userAsync.when(
          data: (user) {
            if (user == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('لم يتم تسجيل الدخول'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      child: const Text('تسجيل الدخول'),
                    ),
                  ],
                ),
              );
            }

            final isMohaffez = user.role == 'mohaffez';

            return CustomScrollView(
              slivers: [
                _buildAppBar(user),
                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    
                    // Profile completion card (Mohaffez only)
                    if (isMohaffez) _buildProfileCompletion(user.uid),
                    
                    // Basic info
                    _buildBasicInfo(user),
                    const SizedBox(height: 16),
                    
                    // Mohaffez management
                    if (isMohaffez) ...[
                      _buildMohaffezManagement(),
                      const SizedBox(height: 16),
                    ],
                    
                    // Account management
                    _buildManagementSection(),
                    const SizedBox(height: 16),
                    
                    // Logout button
                    _buildLogoutButton(),
                    const SizedBox(height: 32),
                  ]),
                ),
              ],
            );
          },
          loading: () => CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
                      ),
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  ShimmerWidgets.profile(),
                ]),
              ),
            ],
          ),
          error: (e, _) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(currentUserProvider),
          ),
        ),
      ),
    );
  }

  // ==================== App Bar ====================
  Widget _buildAppBar(user) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            
            // Profile info
            Positioned(
              bottom: 20,
              right: 0,
              left: 0,
              child: Column(
                children: [
                  // Avatar with edit button
                  Stack(
                    children: [
                      CachedAvatar(
                        imageUrl: user.photoUrl,
                        radius: 50,
                        semanticLabel: user.name,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _pickAndUploadPhoto(user.uid),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Name
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  
                  // Role
                  Text(
                    user.role == 'mohaffez' ? 'محفظ' : 'طالب',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Profile Completion ====================
  Widget _buildProfileCompletion(String userId) {
    return FutureBuilder<ProfileCompletionData>(
      future: ProfileCompletionService.calculateCompletion(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!;
        final percentage = data.percentage;
        final isComplete = percentage >= 100;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    isComplete ? Icons.check_circle : Icons.info_outline,
                    color: isComplete ? AppTheme.accentGreen : AppTheme.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'اكتمال الملف الشخصي',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${percentage.toInt()}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? AppTheme.accentGreen : AppTheme.primaryAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? AppTheme.accentGreen : AppTheme.primaryAmber,
                  ),
                ),
              ),
              
              // Missing fields
              if (!isComplete && data.missingFields.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'الحقول المطلوبة:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: data.missingFields.map((field) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.warning.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _getFieldLabel(field),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _getFieldLabel(String field) {
    switch (field) {
      case 'name': return 'الاسم';
      case 'email': return 'البريد الإلكتروني';
      case 'photo': return 'الصورة الشخصية';
      case 'bio': return 'نبذة تعريفية';
      case 'location': return 'الموقع';
      case 'specialization': return 'التخصص';
      case 'credentials': return 'المؤهلات';
      case 'availability': return 'الأوقات المتاحة';
      case 'phoneVerified': return 'تأكيد رقم الهاتف';
      default: return field;
    }
  }

  // ==================== Basic Info ====================
  Widget _buildBasicInfo(user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المعلومات الأساسية',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          
          // Email
          _buildInfoRow(
            icon: Icons.email,
            label: 'البريد الإلكتروني',
            value: user.email ?? '',
          ),
          const SizedBox(height: 12),
          
          // Bio (Mohaffez only)
          if (user.role == 'mohaffez') ...[
            _buildEditableField(
              icon: Icons.description,
              label: 'نبذة تعريفية',
              value: user.bio ?? 'لم يتم الإضافة',
              controller: bioController,
              isEditing: isEditingBio,
              onEdit: () {
                setState(() {
                  bioController.text = user.bio ?? '';
                  isEditingBio = true;
                });
              },
              onSave: () async {
                await _updateProfile(user.uid, {'bio': bioController.text.trim()});
                setState(() => isEditingBio = false);
              },
              onCancel: () {
                setState(() => isEditingBio = false);
              },
              maxLines: 3,
            ),
            const SizedBox(height: 12),
          ],
          
          // Phone
          _buildEditableField(
            icon: Icons.phone,
            label: 'رقم الهاتف',
            value: user.phoneNumber ?? 'لم يتم الإضافة',
            controller: phoneController,
            isEditing: isEditingPhone,
            onEdit: () {
              setState(() {
                phoneController.text = user.phoneNumber ?? '';
                isEditingPhone = true;
              });
            },
            onSave: () async {
              await _updateProfile(user.uid, {'phoneNumber': phoneController.text.trim()});
              setState(() => isEditingPhone = false);
            },
            onCancel: () {
              setState(() => isEditingPhone = false);
            },
          ),
          
          // Specialization (Mohaffez only)
          if (user.role == 'mohaffez') ...[
            const SizedBox(height: 12),
            _buildEditableField(
              icon: Icons.book,
              label: 'التخصص',
              value: user.specialization ?? 'لم يتم الإضافة',
              controller: specializationController,
              isEditing: isEditingSpecialization,
              onEdit: () {
                setState(() {
                  specializationController.text = user.specialization ?? '';
                  isEditingSpecialization = true;
                });
              },
              onSave: () async {
                await _updateProfile(
                  user.uid,
                  {'specialization': specializationController.text.trim()},
                );
                setState(() => isEditingSpecialization = false);
              },
              onCancel: () {
                setState(() => isEditingSpecialization = false);
              },
            ),
          ],
          
          // Location
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.location_on,
            label: 'الموقع',
            value: user.addressText ?? 'لم يتم الإضافة',
            trailing: IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _updateLocation(user.uid),
            ),
          ),
          
          // Follower/Following counts (Mohaffez only)
          if (user.role == 'mohaffez') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    label: 'المتابعون',
                    value: '${user.followerCount ?? 0}',
                    icon: Icons.people,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    label: 'التقييم',
                    value: (user.rating ?? 0.0).toStringAsFixed(1),
                    icon: Icons.star,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryAmber),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required String value,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    int maxLines = 1,
  }) {
    if (isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryAmber),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onCancel,
                child: const Text('إلغاء'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onSave,
                child: const Text('حفظ'),
              ),
            ],
          ),
        ],
      );
    }

    return _buildInfoRow(
      icon: icon,
      label: label,
      value: value,
      trailing: IconButton(
        icon: const Icon(Icons.edit, size: 18),
        onPressed: onEdit,
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryAmber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryAmber,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Mohaffez Management ====================
  Widget _buildMohaffezManagement() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إدارة المحفظ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          
          // Credentials
          _buildManagementCard(
            icon: Icons.verified_user,
            title: 'المؤهلات والشهادات',
            subtitle: 'إدارة الإجازات والشهادات',
            color: Colors.blue,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MohaffezCredentialsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          
          // Availability
          _buildManagementCard(
            icon: Icons.access_time,
            title: 'الأوقات المتاحة',
            subtitle: 'تحديث جدول المواعيد',
            color: AppTheme.accentGreen,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AvailabilityManagementScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== Account Management ====================
  Widget _buildManagementSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إعدادات الحساب',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          
          // Change password
          _buildManagementCard(
            icon: Icons.lock,
            title: 'تغيير كلمة المرور',
            subtitle: 'تحديث كلمة مرور حسابك',
            color: Colors.orange,
            onTap: _showChangePasswordDialog,
          ),
          const SizedBox(height: 12),
          
          // Privacy settings
          _buildManagementCard(
            icon: Icons.privacy_tip,
            title: 'إعدادات الخصوصية',
            subtitle: 'التحكم في البيانات المرئية',
            color: Colors.purple,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
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
    );
  }

  // ==================== Logout Button ====================
  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout),
        label: const Text('تسجيل الخروج'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // ==================== Actions ====================
  
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
      ErrorHandler.showSuccess(context, 'تم تحديث الصورة بنجاح');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ErrorHandler.showError(context, e);
    }
  }

  Future<void> _updateProfile(String userId, Map<String, dynamic> updates) async {
    try {
      final repository = ref.read(userRepositoryProvider);
      // ✅ FIXED: Call updateUser (which exists) instead of updateProfile with wrong params
      await repository.updateUser(userId, updates);
      
      // Refresh user data
      ref.invalidate(currentUserProvider);
      
      if (!mounted) return;
      ErrorHandler.showSuccess(context, 'تم التحديث بنجاح');
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, e);
    }
  }

  Future<void> _updateLocation(String userId) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Get location
      final position = await Geolocator.getCurrentPosition();

      // For demo, use coordinates as address (in production, use geocoding)
      final addressText = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      // ✅ FIXED: Call updateUser instead of updateLocation
      final repository = ref.read(userRepositoryProvider);
      await repository.updateUser(userId, {
        'addressLat': position.latitude,
        'addressLng': position.longitude,
        'addressText': addressText,
      });

      // Refresh user data
      ref.invalidate(currentUserProvider);

      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ErrorHandler.showSuccess(context, 'تم تحديث الموقع بنجاح');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ErrorHandler.showError(context, e);
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ErrorHandler.showError(context, 'كلمات المرور غير متطابقة');
                  return;
                }

                if (newPasswordController.text.length < 8) {
                  ErrorHandler.showError(context, 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser!;
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPasswordController.text,
                  );

                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPasswordController.text);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ErrorHandler.showSuccess(context, 'تم تغيير كلمة المرور بنجاح');
                  }
                } catch (e) {
                  if (mounted) ErrorHandler.showError(context, e);
                }
              },
              child: const Text('تغيير'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
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
              child: const Text('إلغاء'),
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
      final notifier = ref.read(authNotifierProvider.notifier);
      await notifier.logout();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
