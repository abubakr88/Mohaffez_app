// lib/screens/profile_screen_widgets.dart
import 'package:flutter/material.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/widgets/cached_avatar.dart';
import '../../models/user_model.dart';
import '../../services/profile_completion_service.dart';
import '../../shared/utils/specialization_constants.dart';

/// App bar with profile photo and name
class ProfileAppBar extends StatelessWidget {
  final UserModel user;

  const ProfileAppBar({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
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
                  colors: [AppThemeConstants.primary, AppThemeConstants.primaryVariant],
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
                  // Avatar photo
                  CachedAvatar(
                    imageUrl: user.photoUrl,
                    radius: 50,
                    semanticLabel: user.name,
                  ),
                  const SizedBox(height: 8),
                  // Name
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.onPrimary,
                    ),
                  ),
                  // Role
                  Text(
                    user.role == 'mohaffez' ? 'محفّظ' : 'طالب',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppThemeConstants.onPrimary.withValues(alpha: 0.7),
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
}

/// Profile completion card
class ProfileCompletionCard extends StatelessWidget {
  final String userId;

  const ProfileCompletionCard({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
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
            color: AppThemeConstants.onPrimary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppThemeConstants.onPrimary.withValues(alpha: 0.05),
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
                    color: isComplete ? AppThemeConstants.secondary : AppThemeConstants.warning,
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
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? AppThemeConstants.secondary : AppThemeConstants.primary,
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
                  valueColor: AlwaysStoppedAnimation(
                    isComplete ? AppThemeConstants.secondary : AppThemeConstants.primary,
                  ),
                ),
              ),
              // Missing fields
              if (!isComplete && data.missingFields.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'حقول مفقودة:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (data.missingFields as List)
                      .map(
                        (field) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeConstants.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppThemeConstants.warning.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            field.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Basic info section with editable fields
class BasicInfoSection extends StatelessWidget {
  final UserModel user;
  final TextEditingController bioController;
  final TextEditingController phoneController;
  final TextEditingController specializationController;
  final bool isEditingBio;
  final bool isEditingPhone;
  final bool isEditingSpecialization;
  final VoidCallback onEditBio;
  final VoidCallback onSaveBio;
  final VoidCallback onCancelBio;
  final VoidCallback onEditPhone;
  final VoidCallback onSavePhone;
  final VoidCallback onCancelPhone;
  final VoidCallback onEditSpecialization;
  final VoidCallback onSaveSpecialization;
  final VoidCallback onCancelSpecialization;
  final VoidCallback onUpdateLocation;
  final VoidCallback onPickPhoto;

  const BasicInfoSection({
    super.key,
    required this.user,
    required this.bioController,
    required this.phoneController,
    required this.specializationController,
    required this.isEditingBio,
    required this.isEditingPhone,
    required this.isEditingSpecialization,
    required this.onEditBio,
    required this.onSaveBio,
    required this.onCancelBio,
    required this.onEditPhone,
    required this.onSavePhone,
    required this.onCancelPhone,
    required this.onEditSpecialization,
    required this.onSaveSpecialization,
    required this.onCancelSpecialization,
    required this.onUpdateLocation,
    required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
          // Email (read-only)
          _buildInfoRow(
            icon: Icons.email,
            label: 'البريد الإلكتروني',
            value: user.email,
          ),
          const SizedBox(height: 12),
          // Bio (Mohaffez only, editable)
          if (user.role == 'mohaffez')
            _buildEditableField(
              icon: Icons.description,
              label: 'السيرة الذاتية',
              value: user.bio ?? 'لم يتم تعيين السيرة الذاتية',
              controller: bioController,
              isEditing: isEditingBio,
              onEdit: onEditBio,
              onSave: onSaveBio,
              onCancel: onCancelBio,
              maxLines: 3,
            ),
          if (user.role == 'mohaffez') const SizedBox(height: 12),
          // Phone (editable)
          _buildEditableField(
            icon: Icons.phone,
            label: 'رقم الهاتف',
            value: user.phoneNumber ?? 'لم يتم تعيين رقم الهاتف',
            controller: phoneController,
            isEditing: isEditingPhone,
            onEdit: onEditPhone,
            onSave: onSavePhone,
            onCancel: onCancelPhone,
          ),
          // Specialization (Mohaffez only, editable)
          if (user.role == 'mohaffez') ...[
            const SizedBox(height: 12),
            _buildEditableField(
              icon: Icons.book,
              label: 'التخصص',
              value: user.specialization ?? 'لم يتم تعيين التخصص',
              controller: specializationController,
              isEditing: isEditingSpecialization,
              onEdit: onEditSpecialization,
              onSave: onSaveSpecialization,
              onCancel: onCancelSpecialization,
              showSpecializationChips: true,
            ),
          ],
          // Location
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.location_on,
            label: 'الموقع',
            value: user.addressText ?? 'لم يتم تعيين الموقع',
            trailing: IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: onUpdateLocation,
            ),
          ),
          // Follower/Following counts (Mohaffez only)
          if (user.role == 'mohaffez') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    label: 'متابعون',
                    value: user.followerCount.toString(),
                    icon: Icons.people,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    label: 'التقييم',
                    value: user.rating.toStringAsFixed(1),
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
        Icon(icon, size: 20, color: AppThemeConstants.primary),
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
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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
    bool showSpecializationChips = false,
  }) {
    if (isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppThemeConstants.primary),
              const SizedBox(width: 8),
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
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),
          if (showSpecializationChips) ...[
            const Text(
              'اختر من التخصصات الشائعة:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SpecializationConstants.specializations
                  .map((spec) => _specializationChip(
                        label: spec,
                        onTap: () {
                          final currentText = controller.text.trim();
                          if (currentText.isEmpty) {
                            controller.text = spec;
                          } else if (!currentText.contains(spec)) {
                            controller.text = '$currentText، $spec';
                          }
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
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

  Widget _specializationChip({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppThemeConstants.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppThemeConstants.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppThemeConstants.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
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
        color: AppThemeConstants.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppThemeConstants.primary),
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
                    color: AppThemeConstants.primary,
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
}

/// Mohaffez management section (credentials and availability)
class MohaffezManagementSection extends StatelessWidget {
  const MohaffezManagementSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إدارة حساب المحفّظ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          // Credentials
          _ManagementCard(
            icon: Icons.verified_user,
            title: 'الشهادات والمؤهلات',
            subtitle: 'إدارة شهاداتك وإجازاتك',
            color: Colors.blue,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MohaffezCredentialsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Availability
          _ManagementCard(
            icon: Icons.access_time,
            title: 'الأوقات المتاحة',
            subtitle: 'إدارة جدول الأوقات المتاحة',
            color: AppThemeConstants.secondary,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AvailabilityManagementScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
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
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
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
}

/// Account management section (change password, privacy)
class AccountManagementSection extends StatelessWidget {
  final VoidCallback onChangePassword;

  const AccountManagementSection({
    super.key,
    required this.onChangePassword,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إدارة الحساب',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          // Change password
          _ManagementCard(
            icon: Icons.lock,
            title: 'تغيير كلمة المرور',
            subtitle: 'قم بتحديث كلمة مرورك',
            color: Colors.orange,
            onTap: onChangePassword,
          ),
          const SizedBox(height: 12),
          // Privacy settings
          _ManagementCard(
            icon: Icons.privacy_tip,
            title: 'إعدادات الخصوصية',
            subtitle: 'التحكم في من يمكنه رؤية معلوماتك',
            color: Colors.purple,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PrivacySettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Import the missing screens
class MohaffezCredentialsScreen extends StatelessWidget {
  const MohaffezCredentialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Mohaffez Credentials Screen')),
    );
  }
}

class AvailabilityManagementScreen extends StatelessWidget {
  const AvailabilityManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Availability Management Screen')),
    );
  }
}

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Privacy Settings Screen')),
    );
  }
}
