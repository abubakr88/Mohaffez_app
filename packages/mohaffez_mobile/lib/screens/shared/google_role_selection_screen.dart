import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GoogleRoleSelectionScreen extends ConsumerStatefulWidget {
  final String name;
  final String email;
  final String? photoUrl;

  const GoogleRoleSelectionScreen({
    super.key,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  @override
  ConsumerState<GoogleRoleSelectionScreen> createState() =>
      _GoogleRoleSelectionScreenState();
}

class _GoogleRoleSelectionScreenState
    extends ConsumerState<GoogleRoleSelectionScreen> {
  String? _selectedRole;
  String _selectedGender = 'male';
  String? _selectedHonorific;
  bool _isLoading = false;

  IconData _genderIcon(String gender) {
    return gender == 'female' ? Icons.woman_rounded : Icons.man_rounded;
  }

  IconData get _roleBadgeIcon {
    if (_selectedRole == roleMohaffez) return Icons.menu_book_rounded;
    if (_selectedRole == roleParent) return Icons.family_restroom_rounded;
    return Icons.school_rounded;
  }

  Future<void> _submit() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار نوع الحساب'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
      return;
    }

    final teacherRegistrationEnabled = ref
            .read(systemConfigProvider)
            .valueOrNull
            ?.teacherRegistrationEnabled ??
        true;
    if (_selectedRole == roleMohaffez && !teacherRegistrationEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تسجيل المحفظين الجدد متوقف حالياً. يرجى المحاولة لاحقاً.',
          ),
          backgroundColor: AppThemeConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final notifier = ref.read(authNotifierProvider.notifier);
    await notifier.completeGoogleSignIn(
      role: _selectedRole!,
      gender: _selectedGender,
      honorific: _selectedHonorific,
    );

    if (!mounted) return;

    final state = ref.read(authNotifierProvider);
    if (state.hasError) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error.toString()),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    }
    // On success, authStateProvider will trigger redirect via GoRouter
  }

  @override
  Widget build(BuildContext context) {
    final teacherRegistrationEnabled = ref
            .watch(systemConfigProvider)
            .valueOrNull
            ?.teacherRegistrationEnabled ??
        true;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B4A4A), Color(0xFF0B7A75)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // Profile avatar
                  Center(
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.white24,
                      backgroundImage: widget.photoUrl != null
                          ? NetworkImage(widget.photoUrl!)
                          : null,
                      child: widget.photoUrl == null
                          ? const Icon(Icons.person,
                              size: 48, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
                    decoration: const BoxDecoration(
                      color: AppThemeConstants.surface,
                      borderRadius: AppThemeConstants.borderRadiusXl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'اختر نوع الحساب',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        _RoleCard(
                          title: 'طالب',
                          subtitle: 'أبحث عن محفظ لحفظ القرآن',
                          icon: Icons.school_rounded,
                          value: roleStudent,
                          selectedValue: _selectedRole,
                          onSelected: (v) => setState(() => _selectedRole = v),
                        ),
                        const SizedBox(height: 12),
                        _RoleCard(
                          title: 'ولي أمر',
                          subtitle: 'أدير حجوزات ودروس أبنائي',
                          icon: Icons.family_restroom_rounded,
                          value: roleParent,
                          selectedValue: _selectedRole,
                          onSelected: (v) => setState(() => _selectedRole = v),
                        ),
                        const SizedBox(height: 12),
                        _RoleCard(
                          title: 'محفظ',
                          subtitle: 'أرغب في تدريس وتسميع القرآن',
                          icon: Icons.menu_book_rounded,
                          value: roleMohaffez,
                          selectedValue: _selectedRole,
                          enabled: teacherRegistrationEnabled,
                          onSelected: (v) => setState(() => _selectedRole = v),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'الجنس',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Cairo',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _GenderCard(
                                title: 'ذكر',
                                icon: _genderIcon('male'),
                                badgeIcon: _roleBadgeIcon,
                                isSelected: _selectedGender == 'male',
                                onTap: () =>
                                    setState(() => _selectedGender = 'male'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GenderCard(
                                title: 'أنثى',
                                icon: _genderIcon('female'),
                                badgeIcon: _roleBadgeIcon,
                                isSelected: _selectedGender == 'female',
                                onTap: () =>
                                    setState(() => _selectedGender = 'female'),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedRole == roleMohaffez) ...[
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String?>(
                            initialValue: _selectedHonorific,
                            decoration: const InputDecoration(
                              labelText: 'اللقب قبل الاسم',
                              prefixIcon:
                                  Icon(Icons.workspace_premium_outlined),
                              border: OutlineInputBorder(
                                borderRadius: AppThemeConstants.borderRadiusMd,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('بدون لقب'),
                              ),
                              ...teacherHonorifics.map(
                                (title) => DropdownMenuItem<String?>(
                                  value: title,
                                  child: Text(title),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedHonorific = value);
                            },
                          ),
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeConstants.primary,
                              foregroundColor: AppThemeConstants.onPrimary,
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppThemeConstants.borderRadiusMd,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'إكمال إنشاء الحساب',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final String? selectedValue;
  final bool enabled;
  final ValueChanged<String> onSelected;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.selectedValue,
    this.enabled = true,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedValue == value;
    return InkWell(
      onTap: enabled ? () => onSelected(value) : null,
      borderRadius: AppThemeConstants.borderRadiusMd,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppThemeConstants.primary.withValues(alpha: 0.1)
                : AppThemeConstants.background,
            border: Border.all(
              color:
                  isSelected ? AppThemeConstants.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: AppThemeConstants.borderRadiusMd,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppThemeConstants.primary
                      : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppThemeConstants.primary
                            : Colors.black87,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 2),
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
              if (isSelected)
                const Icon(Icons.check_circle,
                    color: AppThemeConstants.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final IconData badgeIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.title,
    required this.icon,
    required this.badgeIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppThemeConstants.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppThemeConstants.primary.withValues(alpha: 0.1)
              : AppThemeConstants.background,
          border: Border.all(
            color:
                isSelected ? AppThemeConstants.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: AppThemeConstants.borderRadiusMd,
        ),
        child: Column(
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      icon,
                      size: 34,
                      color: isSelected
                          ? AppThemeConstants.primary
                          : Colors.grey.shade600,
                    ),
                  ),
                  PositionedDirectional(
                    end: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppThemeConstants.primary
                            : Colors.grey.shade500,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemeConstants.surface,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        badgeIcon,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppThemeConstants.primary : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
