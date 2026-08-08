import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/generated/app_localizations.dart';

class AdminUserDetailPage extends ConsumerWidget {
  const AdminUserDetailPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(adminUserProvider(userId));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DSButton(
            label: 'عودة إلى المستخدمين',
            variant: DSButtonVariant.ghost,
            size: DSButtonSize.sm,
            leading: const Icon(Icons.arrow_back_rounded, size: 16),
            onPressed: () => context.go('/admin/users'),
          ),
          const SizedBox(height: DSSpacing.md),
          userAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (user) {
              if (user == null) {
                return const DSEmptyState(
                  title: 'المستخدم غير موجود',
                  subtitle: 'ربما تم حذف هذا الحساب أو تغيّر معرّفه',
                  icon: Icons.person_off_outlined,
                );
              }
              return _UserProfile(userId: userId, user: user);
            },
          ),
        ],
      ),
    );
  }
}

enum _DetailTab {
  account('الحساب', Icons.badge_outlined),
  sessions('الجلسات', Icons.event_note_outlined),
  wallet('المحفظة', Icons.account_balance_wallet_outlined),
  review('مراجعة المحفظ', Icons.verified_user_outlined),
  support('الدعم', Icons.support_agent_outlined),
  notifications('الإشعارات والأجهزة', Icons.notifications_none_rounded);

  const _DetailTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _UserProfile extends ConsumerStatefulWidget {
  const _UserProfile({required this.userId, required this.user});

  final String userId;
  final Map<String, dynamic> user;

  @override
  ConsumerState<_UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends ConsumerState<_UserProfile> {
  _DetailTab _selected = _DetailTab.account;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final userId = widget.userId;
    final role = _text(user, const ['role'], 'student');
    final status = _text(user, const ['status'], 'active');
    final name = _text(user, const ['name', 'displayName'], 'مستخدم');
    final photo = _nullableText(user, const ['photoUrl', 'profileImageUrl']);
    final access = ref.watch(currentAdminAccessProvider).valueOrNull ??
        AdminAccessState.none();
    final tabs = _tabsFor(role, access);

    if (!tabs.contains(_selected)) _selected = tabs.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileHeader(
          userId: userId,
          user: user,
          name: name,
          role: role,
          status: status,
          photo: photo,
        ),
        const SizedBox(height: DSSpacing.lg),
        _TabStrip(
          tabs: tabs,
          selected: _selected,
          onSelected: (tab) => setState(() => _selected = tab),
        ),
        const SizedBox(height: DSSpacing.lg),
        AnimatedSwitcher(
          duration: DSDuration.fast,
          child: switch (_selected) {
            _DetailTab.account => _AccountTab(userId: userId, user: user),
            _DetailTab.sessions => _SessionsTab(userId: userId),
            _DetailTab.wallet => _WalletTab(userId: userId, user: user),
            _DetailTab.review => _TeacherReviewTab(userId: userId),
            _DetailTab.support => _SupportTab(user: user),
            _DetailTab.notifications => _NotificationsAndDevicesTab(
                userId: userId,
                user: user,
              ),
          },
        ),
      ],
    );
  }

  List<_DetailTab> _tabsFor(String role, AdminAccessState access) {
    final canOpenUsers = access.isSuperAdmin ||
        access.can(AdminPermission.manageUsers) ||
        access.can(AdminPermission.manageUserRoles) ||
        access.can(AdminPermission.deleteUsers);
    final canViewSessions = access.can(AdminPermission.manageUsers) ||
        access.can(AdminPermission.manageFinance);
    final canViewWallet = access.can(AdminPermission.manageFinance) &&
        (isLearnerAccountRole(role) || role == 'mohaffez');

    return [
      _DetailTab.account,
      if (canViewSessions) _DetailTab.sessions,
      if (canViewWallet) _DetailTab.wallet,
      if (role == 'mohaffez' && access.can(AdminPermission.reviewTeachers))
        _DetailTab.review,
      if (canOpenUsers) _DetailTab.support,
      if (canOpenUsers) _DetailTab.notifications,
    ];
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.userId,
    required this.user,
    required this.name,
    required this.role,
    required this.status,
    required this.photo,
  });

  final String userId;
  final Map<String, dynamic> user;
  final String name;
  final String role;
  final String status;
  final String? photo;

  Uri get _publicTeacherProfileUri => Uri.https(
        'app.mohafezy.com',
        '/p/t/$userId',
      );

  Future<void> _copyPublicTeacherProfile(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: _publicTeacherProfileUri.toString()),
    );
    if (!context.mounted) return;
    DSToast.show(
      context,
      'تم نسخ رابط ملف المحفظ العام',
      type: DSToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final identity = Row(
            children: [
              DSAvatar(name: name, imageUrl: photo, size: 64),
              const SizedBox(width: DSSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: DSText.h2(context)),
                    const SizedBox(height: DSSpacing.sm),
                    Wrap(
                      spacing: DSSpacing.sm,
                      runSpacing: DSSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DSBadge(
                          label: _roleLabel(role),
                          variant: _roleVariant(role),
                        ),
                        DSBadge(
                          label: _statusLabel(status),
                          variant: _statusVariant(status),
                          dot: true,
                        ),
                        if (_adminRole(user) != null)
                          DSBadge(
                            label: _adminRole(user)!,
                            variant: _adminRole(user) == 'Super Admin'
                                ? DSBadgeVariant.error
                                : DSBadgeVariant.info,
                          ),
                      ],
                    ),
                    const SizedBox(height: DSSpacing.sm),
                    SelectableText(
                      userId,
                      style: DSText.caption(context, color: DSColors.text3),
                    ),
                  ],
                ),
              ),
            ],
          );

          final summary = Wrap(
            spacing: DSSpacing.md,
            runSpacing: DSSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HeaderFact(
                label: 'انضم',
                value: _date(user['createdAt']),
                icon: Icons.person_add_alt_1_outlined,
              ),
              _HeaderFact(
                label: 'آخر تحديث',
                value: _date(user['updatedAt']),
                icon: Icons.update_rounded,
              ),
              _HeaderFact(
                label: 'آخر نشاط',
                value: _date(user['lastActiveAt'] ?? user['lastLoginAt']),
                icon: Icons.access_time_rounded,
              ),
              if (role == 'mohaffez')
                DSButton(
                  label: 'مشاركة رابط الملف',
                  size: DSButtonSize.sm,
                  variant: DSButtonVariant.secondary,
                  leading: const Icon(Icons.link_rounded, size: 16),
                  onPressed: () => _copyPublicTeacherProfile(context),
                ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: DSSpacing.lg),
                summary,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identity),
              const SizedBox(width: DSSpacing.xl),
              summary,
            ],
          );
        },
      ),
    );
  }
}

class _HeaderFact extends StatelessWidget {
  const _HeaderFact({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(DSSpacing.md),
      decoration: BoxDecoration(
        color: DSColors.surfaceMuted,
        borderRadius: DSRadius.mdAll,
        border: Border.all(color: DSColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DSColors.primary),
          const SizedBox(width: DSSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: DSText.caption(context, color: DSColors.text3)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DSText.bodyMedium(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<_DetailTab> tabs;
  final _DetailTab selected;
  final ValueChanged<_DetailTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DSSpacing.sm,
      runSpacing: DSSpacing.sm,
      children: [
        for (final tab in tabs)
          _TabButton(
            tab: tab,
            selected: tab == selected,
            onTap: () => onSelected(tab),
          ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _DetailTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : DSColors.text2;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DSDuration.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: DSSpacing.lg,
            vertical: DSSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? DSColors.primary : DSColors.surface,
            borderRadius: DSRadius.fullAll,
            border: Border.all(
              color: selected ? DSColors.primary : DSColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 16, color: fg),
              const SizedBox(width: DSSpacing.xs),
              Text(tab.label, style: DSText.caption(context, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTab extends ConsumerWidget {
  const _AccountTab({required this.userId, required this.user});

  final String userId;
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = _text(user, const ['role'], 'student');
    final status = _text(user, const ['status'], 'active');
    final adminPermissions = _adminPermissionsLabel(user);
    final access = ref.watch(currentAdminAccessProvider).valueOrNull ??
        AdminAccessState.none();
    final actionState = ref.watch(adminActionsProvider);
    final canEditAdminAccess = role == 'admin' &&
        status != 'deleted' &&
        access.can(AdminPermission.manageAdminAccess) &&
        access.uid != userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'بيانات الحساب'),
        const SizedBox(height: DSSpacing.md),
        DSGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 3,
          children: [
            _InfoCard(
              label: 'الاسم',
              value: _text(user, const ['name', 'displayName']),
              icon: Icons.person_outline_rounded,
            ),
            _InfoCard(
              label: 'الدور',
              value: _roleLabel(role),
              icon: Icons.admin_panel_settings_outlined,
            ),
            _InfoCard(
              label: 'الحالة',
              value: _statusLabel(status),
              icon: Icons.verified_outlined,
            ),
            _InfoCard(
              label: 'البريد الإلكتروني',
              value: _nullableText(user, const ['email']) ?? '—',
              icon: Icons.email_outlined,
            ),
            _InfoCard(
              label: 'الهاتف',
              value: _nullableText(user, const ['phoneNumber', 'phone']) ?? '—',
              icon: Icons.phone_outlined,
            ),
            _InfoCard(
              label: 'المدينة',
              value: _nullableText(user, const ['city', 'governorate']) ?? '—',
              icon: Icons.location_city_outlined,
            ),
            _InfoCard(
              label: 'التخصص',
              value: _nullableText(user, const ['specialization']) ?? '—',
              icon: Icons.school_outlined,
            ),
            _InfoCard(
              label: 'العنوان',
              value: _nullableText(
                    user,
                    const ['addressText', 'address', 'locationAddress'],
                  ) ??
                  '—',
              icon: Icons.location_on_outlined,
            ),
            _InfoCard(
              label: 'إحداثيات الموقع',
              value: _coordinatesLabel(user) ?? '—',
              icon: Icons.map_outlined,
            ),
            _InfoCard(
              label: 'تاريخ التسجيل',
              value: _date(user['createdAt']),
              icon: Icons.calendar_today_outlined,
            ),
            _InfoCard(
              label: 'آخر نشاط',
              value: _date(user['lastActiveAt'] ?? user['lastLoginAt']),
              icon: Icons.access_time_outlined,
            ),
            _InfoCard(
              label: 'حالة التحقق',
              value: _verificationLabel(user),
              icon: Icons.fact_check_outlined,
            ),
          ],
        ),
        const SizedBox(height: DSSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 780;
            final notes = [
              _TextPanel(
                title: 'نبذة',
                value: _nullableText(user, const ['bio', 'about']) ?? '—',
              ),
              _TextPanel(
                title: 'ملاحظات/أسباب إدارية',
                value: _nullableText(
                      user,
                      const [
                        'suspensionReason',
                        'deleteReason',
                        'rejectionReason',
                        'lastRejectionReason',
                      ],
                    ) ??
                    '—',
              ),
              if (adminPermissions != null)
                _TextPanel(
                  title: 'صلاحيات الأدمن',
                  value: adminPermissions,
                  trailing: canEditAdminAccess
                      ? DSButton(
                          label: 'تعديل',
                          size: DSButtonSize.sm,
                          variant: DSButtonVariant.secondary,
                          leading: const Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 16,
                          ),
                          loading: actionState.isLoading,
                          onPressed: actionState.isLoading
                              ? null
                              : () => _editAdminAccess(context, ref),
                        )
                      : null,
                ),
            ];

            if (!wide) {
              return Column(
                children: [
                  for (final panel in notes) ...[
                    panel,
                    const SizedBox(height: DSSpacing.md),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: notes
                  .map(
                    (panel) => Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: DSSpacing.md,
                        ),
                        child: panel,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        if (role == 'mohaffez') ...[
          const SizedBox(height: DSSpacing.xl),
          _FoundingBadgeAdminSection(userId: userId, user: user),
        ],
      ],
    );
  }

  Future<void> _editAdminAccess(BuildContext context, WidgetRef ref) async {
    final name = _text(user, const ['name', 'displayName'], 'مستخدم');
    final input = await _showAdminAccessDialog(context, name, user);
    if (input == null || !context.mounted) return;

    await ref.read(adminActionsProvider.notifier).updateAdminAccess(
          userId: userId,
          adminRole: input.adminRole,
          permissions: input.permissions,
        );
    if (!context.mounted) return;

    ref.read(adminActionsProvider).when(
          data: (_) {
            ref.invalidate(adminUserProvider(userId));
            DSToast.show(
              context,
              'تم تحديث صلاحيات الأدمن',
              type: DSToastType.success,
            );
          },
          loading: () {},
          error: (e, _) => DSToast.show(
            context,
            'فشل تحديث الصلاحيات: $e',
            type: DSToastType.error,
          ),
        );
  }
}

Future<_AdminAccessInput?> _showAdminAccessDialog(
  BuildContext context,
  String name,
  Map<String, dynamic> user,
) async {
  var selectedRole = _adminRoleKey(user);
  final permissions = _limitedAdminPermissionsFromUser(user);

  return DSDialog.show<_AdminAccessInput>(
    context,
    title: 'إدارة صلاحيات الأدمن',
    width: 620,
    child: StatefulBuilder(
      builder: (context, setState) {
        final isLimitedAdmin = selectedRole == 'admin';

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DSText.bodyMedium(context, color: DSColors.text1),
            ),
            const SizedBox(height: DSSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _AdminRoleOption(
                    label: 'Super Admin',
                    icon: Icons.workspace_premium_rounded,
                    selected: selectedRole == 'super_admin',
                    onTap: () => setState(() => selectedRole = 'super_admin'),
                  ),
                ),
                const SizedBox(width: DSSpacing.sm),
                Expanded(
                  child: _AdminRoleOption(
                    label: 'Admin',
                    icon: Icons.admin_panel_settings_rounded,
                    selected: isLimitedAdmin,
                    onTap: () => setState(() => selectedRole = 'admin'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DSSpacing.lg),
            AnimatedSwitcher(
              duration: DSDuration.fast,
              child: isLimitedAdmin
                  ? ConstrainedBox(
                      key: const ValueKey('limited-admin-permissions'),
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final permission
                                in _assignableAdminPermissions)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  permission.label,
                                  style: DSText.body(
                                    context,
                                    color: DSColors.text1,
                                  ),
                                ),
                                value: permissions[permission] == true,
                                onChanged: (value) => setState(
                                  () =>
                                      permissions[permission] = value ?? false,
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      key: const ValueKey('super-admin-note'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(DSSpacing.lg),
                      decoration: BoxDecoration(
                        color: DSColors.errorBg,
                        borderRadius: DSRadius.mdAll,
                        border: Border.all(
                          color: DSColors.error.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            color: DSColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: DSSpacing.sm),
                          Expanded(
                            child: Text(
                              'صلاحية كاملة لكل أدوات الإدارة.',
                              style: DSText.body(
                                context,
                                color: DSColors.text1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: DSSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DSButton(
                  label: 'إلغاء',
                  variant: DSButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: DSSpacing.sm),
                DSButton(
                  label: 'حفظ الصلاحيات',
                  onPressed: () {
                    Navigator.of(context).pop(
                      _AdminAccessInput(
                        adminRole: selectedRole,
                        permissions: selectedRole == 'admin'
                            ? Map<AdminPermission, bool>.from(permissions)
                            : {
                                for (final permission in AdminPermission.values)
                                  permission: true,
                              },
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

Map<AdminPermission, bool> _limitedAdminPermissionsFromUser(
  Map<String, dynamic> user,
) {
  final raw = user['adminPermissions'];
  final rawMap = raw is Map ? raw : const {};

  return {
    for (final permission in _assignableAdminPermissions)
      permission: rawMap[permission.key] is bool
          ? rawMap[permission.key] as bool
          : defaultAdminPermissions[permission] ?? false,
  };
}

const _assignableAdminPermissions = [
  AdminPermission.manageUsers,
  AdminPermission.manageUserRoles,
  AdminPermission.manageTeacherBadges,
  AdminPermission.deleteUsers,
  AdminPermission.reviewTeachers,
  AdminPermission.manageFinance,
  AdminPermission.sendBroadcasts,
  AdminPermission.runMaintenance,
];

class _AdminAccessInput {
  const _AdminAccessInput({
    required this.adminRole,
    required this.permissions,
  });

  final String adminRole;
  final Map<AdminPermission, bool> permissions;
}

class _AdminRoleOption extends StatelessWidget {
  const _AdminRoleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DSColors.primary : DSColors.text2;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DSDuration.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: DSSpacing.lg,
            vertical: DSSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected
                ? DSColors.primary.withValues(alpha: 0.08)
                : DSColors.surfaceMuted,
            borderRadius: DSRadius.mdAll,
            border: Border.all(
              color: selected ? DSColors.primary : DSColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: DSSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DSText.bodyMedium(context, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoundingBadgeAdminSection extends ConsumerWidget {
  const _FoundingBadgeAdminSection({
    required this.userId,
    required this.user,
  });

  final String userId;
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final assignment = UserBadges.fromJson(user['badges']).foundingTeacher;
    final internalReason = assignment.enabled
        ? assignment.reason
        : assignment.revocationReason ?? assignment.reason;
    final access = ref.watch(currentAdminAccessProvider).valueOrNull ??
        AdminAccessState.none();
    final actionState = ref.watch(adminActionsProvider);
    final canManage = access.can(AdminPermission.manageTeacherBadges);
    final isLoading = actionState.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.badgesAndRecognition),
        const SizedBox(height: DSSpacing.md),
        DSCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final details = Wrap(
                spacing: DSSpacing.xl,
                runSpacing: DSSpacing.md,
                children: [
                  _BadgeFact(
                    label: l10n.grantedAt,
                    value: _date(assignment.grantedAt),
                  ),
                  _BadgeFact(
                    label: l10n.grantedBy,
                    value: assignment.grantedByName ?? '—',
                  ),
                  _BadgeFact(
                    label: l10n.lastUpdated,
                    value: _date(assignment.updatedAt),
                  ),
                  if ((internalReason ?? '').isNotEmpty)
                    _BadgeFact(
                      label: l10n.internalReason,
                      value: internalReason!,
                    ),
                ],
              );

              final identity = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FoundingTeacherBadge(
                    compact: true,
                    showLabel: true,
                    size: compact ? 30 : 38,
                  ),
                  const SizedBox(width: DSSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.foundingTeacherBadge,
                          style: DSText.h3(context),
                        ),
                        const SizedBox(height: DSSpacing.sm),
                        DSBadge(
                          label: assignment.enabled
                              ? l10n.badgeActive
                              : l10n.badgeInactive,
                          variant: assignment.enabled
                              ? DSBadgeVariant.success
                              : DSBadgeVariant.neutral,
                          dot: true,
                        ),
                        if (assignment.enabled ||
                            assignment.updatedAt != null) ...[
                          const SizedBox(height: DSSpacing.lg),
                          details,
                        ],
                      ],
                    ),
                  ),
                ],
              );

              final action = Semantics(
                button: true,
                label: assignment.enabled ? l10n.revokeBadge : l10n.grantBadge,
                child: Tooltip(
                  message:
                      assignment.enabled ? l10n.revokeBadge : l10n.grantBadge,
                  child: DSButton(
                    label:
                        assignment.enabled ? l10n.revokeBadge : l10n.grantBadge,
                    variant: assignment.enabled
                        ? DSButtonVariant.destructive
                        : DSButtonVariant.primary,
                    leading: Icon(
                      assignment.enabled
                          ? Icons.remove_circle_outline_rounded
                          : Icons.workspace_premium_rounded,
                      size: 17,
                    ),
                    loading: isLoading,
                    onPressed: canManage && !isLoading
                        ? () => _changeBadge(
                              context,
                              ref,
                              enabled: !assignment.enabled,
                            )
                        : null,
                  ),
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const SizedBox(height: DSSpacing.lg),
                    action,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: DSSpacing.xl),
                  action,
                ],
              );
            },
          ),
        ),
        if (!canManage) ...[
          const SizedBox(height: DSSpacing.sm),
          DSBanner(
            message: l10n.badgePermissionDenied,
            variant: DSBannerVariant.warning,
          ),
        ],
      ],
    );
  }

  Future<void> _changeBadge(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();
    try {
      final reason = await DSDialog.show<String>(
        context,
        title: enabled ? l10n.grantBadgeTitle : l10n.revokeBadgeTitle,
        width: 560,
        child: StatefulBuilder(
          builder: (context, setState) {
            final length = reasonController.text.trim().length;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? l10n.grantBadgeMessage : l10n.revokeBadgeMessage,
                  style: DSText.body(context, color: DSColors.text2),
                ),
                const SizedBox(height: DSSpacing.lg),
                DSTextField(
                  controller: reasonController,
                  label: enabled
                      ? l10n.grantReasonOptional
                      : l10n.revocationReasonOptional,
                  maxLines: 3,
                  autofocus: true,
                  helper: '$length/500',
                  error: length > 500 ? l10n.reasonTooLong : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: DSSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DSButton(
                      label: l10n.cancel,
                      variant: DSButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: DSSpacing.sm),
                    DSButton(
                      label: enabled ? l10n.grantBadge : l10n.revokeBadge,
                      variant: enabled
                          ? DSButtonVariant.primary
                          : DSButtonVariant.destructive,
                      onPressed: length <= 500
                          ? () => Navigator.of(context)
                              .pop(reasonController.text.trim())
                          : null,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
      if (reason == null || !context.mounted) return;

      await ref.read(adminActionsProvider.notifier).setTeacherFoundingBadge(
            teacherId: userId,
            enabled: enabled,
            reason: reason,
          );
      if (!context.mounted) return;

      final result = ref.read(adminActionsProvider);
      if (result.hasError) {
        DSToast.show(
          context,
          _badgeErrorMessage(context, result.error),
          type: DSToastType.error,
        );
        return;
      }

      ref.invalidate(adminUserProvider(userId));
      DSToast.show(
        context,
        enabled ? l10n.badgeGrantedSuccess : l10n.badgeRevokedSuccess,
        type: DSToastType.success,
      );
    } finally {
      reasonController.dispose();
    }
  }
}

class _BadgeFact extends StatelessWidget {
  const _BadgeFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DSText.caption(context, color: DSColors.text3)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DSText.bodyMedium(context),
          ),
        ],
      ),
    );
  }
}

String _badgeErrorMessage(BuildContext context, Object? error) {
  final l10n = AppLocalizations.of(context);
  if (error is FirebaseFunctionsException) {
    final details = error.details;
    final detailCode = details is Map ? details['code']?.toString() : null;
    if (error.code == 'permission-denied') {
      return l10n.badgePermissionDenied;
    }
    if (detailCode == 'target-not-teacher' ||
        detailCode == 'account-deleted' ||
        detailCode == 'account-suspended') {
      return l10n.badgeInvalidTeacher;
    }
  }
  return l10n.badgeActionFailed;
}

class _SessionsTab extends ConsumerWidget {
  const _SessionsTab({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminUserSessionsProvider(userId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'الجلسات'),
        const SizedBox(height: DSSpacing.md),
        async.when(
          loading: () => const DSSkeletonCard(),
          error: (e, _) =>
              DSBanner(message: '$e', variant: DSBannerVariant.error),
          data: (sessions) {
            if (sessions.isEmpty) {
              return const DSCard(
                child: DSEmptyState(
                  title: 'لا توجد جلسات',
                  icon: Icons.event_busy_outlined,
                ),
              );
            }
            return DSDataTable<Map<String, dynamic>>(
              initialSortKey: 'date',
              initialSortAsc: false,
              columns: [
                DSColumnDef(
                  key: 'date',
                  label: 'التاريخ',
                  width: 140,
                  sortable: true,
                  sortValue: (r) =>
                      _toDate(r['sessionDate'] ??
                              r['slotStart'] ??
                              r['createdAt'])
                          ?.millisecondsSinceEpoch ??
                      0,
                  cellBuilder: (ctx, r) => Text(
                    _date(r['sessionDate'] ?? r['slotStart'] ?? r['createdAt']),
                    style: DSText.body(ctx, color: DSColors.text2),
                  ),
                ),
                DSColumnDef(
                  key: 'student',
                  label: 'الطالب',
                  cellBuilder: (ctx, r) => Text(
                    _text(r, const ['studentName', 'studentId']),
                    overflow: TextOverflow.ellipsis,
                    style: DSText.body(ctx),
                  ),
                ),
                DSColumnDef(
                  key: 'teacher',
                  label: 'المحفظ',
                  cellBuilder: (ctx, r) => Text(
                    _text(
                        r, const ['mohaffezName', 'teacherName', 'mohaffezId']),
                    overflow: TextOverflow.ellipsis,
                    style: DSText.body(ctx),
                  ),
                ),
                DSColumnDef(
                  key: 'status',
                  label: 'الحالة',
                  width: 130,
                  cellBuilder: (ctx, r) {
                    final status = _text(r, const ['status'], '').toLowerCase();
                    return DSBadge(
                      label: _sessionStatusLabel(status),
                      variant: _sessionStatusVariant(status),
                    );
                  },
                ),
                DSColumnDef(
                  key: 'price',
                  label: 'السعر',
                  width: 110,
                  cellBuilder: (ctx, r) => Text(
                    _money((r['sessionPrice'] as num?)?.toDouble() ?? 0),
                    style: DSText.body(ctx, color: DSColors.text2),
                  ),
                ),
              ],
              rows: sessions,
            );
          },
        ),
      ],
    );
  }
}

class _WalletTab extends ConsumerWidget {
  const _WalletTab({required this.userId, required this.user});

  final String userId;
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = _text(user, const ['role'], 'student');
    final ownerType =
        role == 'mohaffez' ? WalletOwnerType.mohaffez : WalletOwnerType.student;
    final walletAsync =
        ref.watch(walletProvider((userId: userId, ownerType: ownerType)));
    final txAsync = ref.watch(walletTransactionsProvider(userId));
    final eventsAsync = ref.watch(adminUserPaymentEventsProvider(userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'المحفظة والمدفوعات')),
            _CreditWalletButton(
              userId: userId,
              name: _text(user, const ['name'], 'مستخدم'),
              ownerType: ownerType,
            ),
          ],
        ),
        const SizedBox(height: DSSpacing.md),
        walletAsync.when(
          loading: () => const DSSkeletonCard(),
          error: (e, _) =>
              DSBanner(message: '$e', variant: DSBannerVariant.error),
          data: (wallet) => DSGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 4,
            children: [
              DSStatCard(
                label: 'الرصيد المتاح',
                value: _money(wallet.balanceEgp),
                icon: Icons.account_balance_wallet_outlined,
                iconColor: DSColors.primary,
              ),
              DSStatCard(
                label: 'رصيد قيد التسوية',
                value: _money(wallet.pendingCycleEgp),
                icon: Icons.schedule_rounded,
                iconColor: DSColors.info,
              ),
              DSStatCard(
                label: 'عمولة مستحقة',
                value: _money(wallet.directCommissionOwedEgp),
                icon: Icons.trending_down_rounded,
                iconColor:
                    wallet.hasDuesOwed ? DSColors.error : DSColors.success,
              ),
              DSStatCard(
                label: 'آخر تسوية',
                value: _date(wallet.lastSettledAt),
                icon: Icons.fact_check_outlined,
                iconColor: DSColors.secondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: DSSpacing.xl),
        _WalletTransactionsTable(async: txAsync),
        const SizedBox(height: DSSpacing.xl),
        _PaymentEventsTable(async: eventsAsync),
      ],
    );
  }
}

class _WalletTransactionsTable extends StatelessWidget {
  const _WalletTransactionsTable({required this.async});

  final AsyncValue<List<WalletTransactionModel>> async;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'حركات المحفظة'),
        const SizedBox(height: DSSpacing.md),
        async.when(
          loading: () => const DSSkeletonCard(),
          error: (e, _) =>
              DSBanner(message: '$e', variant: DSBannerVariant.error),
          data: (txs) {
            if (txs.isEmpty) {
              return const DSCard(
                child: DSEmptyState(
                  title: 'لا توجد حركات على المحفظة',
                  icon: Icons.receipt_long_outlined,
                ),
              );
            }

            return DSDataTable<WalletTransactionModel>(
              columns: [
                DSColumnDef(
                  key: 'date',
                  label: 'التاريخ',
                  width: 140,
                  cellBuilder: (ctx, tx) => Text(
                    _date(tx.createdAt),
                    style: DSText.body(ctx, color: DSColors.text2),
                  ),
                ),
                DSColumnDef(
                  key: 'type',
                  label: 'النوع',
                  width: 160,
                  cellBuilder: (ctx, tx) => DSBadge(
                    label: _walletTxTypeLabel(tx.type),
                    variant: tx.isCredit
                        ? DSBadgeVariant.success
                        : DSBadgeVariant.warning,
                  ),
                ),
                DSColumnDef(
                  key: 'reason',
                  label: 'البيان',
                  cellBuilder: (ctx, tx) => Text(
                    tx.reason,
                    overflow: TextOverflow.ellipsis,
                    style: DSText.body(ctx),
                  ),
                ),
                DSColumnDef(
                  key: 'amount',
                  label: 'المبلغ',
                  width: 120,
                  cellBuilder: (ctx, tx) => Text(
                    '${tx.isCredit ? '+' : '-'}${_money(tx.absAmountEgp)}',
                    style: DSText.bodyMedium(
                      ctx,
                      color: tx.isCredit ? DSColors.success : DSColors.error,
                    ),
                  ),
                ),
              ],
              rows: txs,
            );
          },
        ),
      ],
    );
  }
}

class _PaymentEventsTable extends StatelessWidget {
  const _PaymentEventsTable({required this.async});

  final AsyncValue<List<Map<String, dynamic>>> async;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'أحداث الدفع المرتبطة'),
        const SizedBox(height: DSSpacing.md),
        async.when(
          loading: () => const DSSkeletonCard(),
          error: (e, _) =>
              DSBanner(message: '$e', variant: DSBannerVariant.error),
          data: (events) {
            if (events.isEmpty) {
              return const DSCard(
                child: DSEmptyState(
                  title: 'لا توجد أحداث دفع مرتبطة',
                  icon: Icons.payments_outlined,
                ),
              );
            }

            return DSDataTable<Map<String, dynamic>>(
              columns: [
                DSColumnDef(
                  key: 'type',
                  label: 'النوع',
                  width: 150,
                  cellBuilder: (ctx, event) => DSBadge(
                    label: _paymentEventLabel(_text(event, const ['type'])),
                    variant: _paymentEventVariant(_text(event, const ['type'])),
                  ),
                ),
                DSColumnDef(
                  key: 'paymentId',
                  label: 'Payment ID',
                  cellBuilder: (ctx, event) => Text(
                    _text(event, const ['paymentId', 'id']),
                    overflow: TextOverflow.ellipsis,
                    style: DSText.body(ctx),
                  ),
                ),
                DSColumnDef(
                  key: 'amount',
                  label: 'المبلغ',
                  width: 120,
                  cellBuilder: (ctx, event) {
                    final amount = (event['amount'] as num?)?.toDouble();
                    return Text(
                      amount == null ? '—' : _money(amount),
                      style: DSText.body(ctx, color: DSColors.text2),
                    );
                  },
                ),
                DSColumnDef(
                  key: 'date',
                  label: 'التاريخ',
                  width: 140,
                  cellBuilder: (ctx, event) => Text(
                    _date(event['timestamp'] ?? event['createdAt']),
                    style: DSText.body(ctx, color: DSColors.text2),
                  ),
                ),
              ],
              rows: events,
            );
          },
        ),
      ],
    );
  }
}

class _TeacherReviewTab extends ConsumerWidget {
  const _TeacherReviewTab({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'ملف مراجعة المحفظ'),
        const SizedBox(height: DSSpacing.md),
        _StatsSection(userId: userId),
        const SizedBox(height: DSSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 880;
            final sections = [
              _CredentialsSection(userId: userId),
              _PricingPlansSection(userId: userId),
              _AvailabilitySection(userId: userId),
            ];

            if (!wide) {
              return Column(
                children: [
                  for (final section in sections) ...[
                    section,
                    const SizedBox(height: DSSpacing.lg),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  Expanded(child: sections[i]),
                  if (i < sections.length - 1)
                    const SizedBox(width: DSSpacing.lg),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherStatsProvider(userId));
    return async.when(
      loading: () => const DSSkeletonCard(),
      error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
      data: (stats) => DSGrid(
        mobileColumns: 1,
        tabletColumns: 2,
        desktopColumns: 4,
        children: [
          DSStatCard(
            label: 'إجمالي الجلسات',
            value: '${stats.total}',
            icon: Icons.event_note_outlined,
            iconColor: DSColors.primary,
          ),
          DSStatCard(
            label: 'مكتملة',
            value: '${stats.completed}',
            icon: Icons.check_circle_outline,
            iconColor: DSColors.success,
          ),
          DSStatCard(
            label: 'طلاب',
            value: '${stats.studentCount}',
            icon: Icons.people_outline_rounded,
            iconColor: DSColors.primary,
          ),
          DSStatCard(
            label: 'التقييم',
            value: stats.avgRating == null
                ? '—'
                : '${stats.avgRating!.toStringAsFixed(1)} (${stats.ratingCount})',
            icon: Icons.star_outline_rounded,
            iconColor: DSColors.secondary,
            onTap: stats.ratings.isEmpty
                ? null
                : () => _showTeacherRatings(context, stats),
          ),
        ],
      ),
    );
  }
}

Future<void> _showTeacherRatings(
  BuildContext context,
  TeacherStats stats,
) {
  final maxListHeight =
      (MediaQuery.sizeOf(context).height * 0.52).clamp(148.0, 520.0).toDouble();
  final listHeight =
      (stats.ratings.length * 148.0).clamp(148.0, maxListHeight).toDouble();

  return DSDialog.show<void>(
    context,
    title: 'تقييمات المحفظ',
    width: 760,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: DSSpacing.sm,
          runSpacing: DSSpacing.sm,
          children: [
            _RatingSummaryChip(
              icon: Icons.star_rounded,
              label: stats.avgRating == null
                  ? 'لا يوجد متوسط'
                  : 'المتوسط ${stats.avgRating!.toStringAsFixed(1)} من 5',
            ),
            _RatingSummaryChip(
              icon: Icons.rate_review_outlined,
              label:
                  '${stats.ratingCount} تقييم محتسب من ${stats.ratings.length} مرسل',
            ),
          ],
        ),
        const SizedBox(height: DSSpacing.lg),
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            itemCount: stats.ratings.length,
            separatorBuilder: (_, __) => const SizedBox(height: DSSpacing.sm),
            itemBuilder: (context, index) =>
                _TeacherRatingItem(rating: stats.ratings[index]),
          ),
        ),
      ],
    ),
  );
}

class _RatingSummaryChip extends StatelessWidget {
  const _RatingSummaryChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: DSColors.secondary.withValues(alpha: 0.08),
        borderRadius: DSRadius.mdAll,
        border: Border.all(
          color: DSColors.secondary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: DSColors.secondary),
          const SizedBox(width: DSSpacing.xs),
          Text(label, style: DSText.bodyMedium(context)),
        ],
      ),
    );
  }
}

class _TeacherRatingItem extends StatelessWidget {
  const _TeacherRatingItem({required this.rating});

  final Map<String, dynamic> rating;

  @override
  Widget build(BuildContext context) {
    final score = (rating['teacherRating'] as num?)?.toDouble() ?? 0;
    final scoreScale =
        (rating['teacherRatingScale'] as num?)?.toInt() ?? (score > 5 ? 10 : 5);
    final isLegacy = (rating['teacherRatingScale'] as num?)?.toInt() != 5;
    final isTechnicalOnly = rating['teacherRatingReason'] == 'technical_only';
    final technicalIssueSource =
        _technicalIssueSourceLabel(rating['technicalIssueSource']);
    final learnerName = _nullableText(
          rating,
          const ['studentProfileName', 'learnerName', 'studentName'],
        ) ??
        'طالب';
    final guardianName = _nullableText(
      rating,
      const ['guardianName', 'studentName'],
    );
    final comment =
        _nullableText(rating, const ['studentFeedback', 'reviewNotes']);
    final ratedAt = _toDate(
      rating['teacherRatedAt'] ??
          rating['sessionDate'] ??
          rating['slotStart'] ??
          rating['completedAt'] ??
          rating['updatedAt'],
    );
    final isInferredDate = rating['teacherRatedAt'] == null;
    final initial = learnerName.trim().isEmpty ? 'ط' : learnerName.trim()[0];

    return Container(
      padding: const EdgeInsets.all(DSSpacing.lg),
      decoration: BoxDecoration(
        color: DSColors.surfaceMuted,
        borderRadius: DSRadius.mdAll,
        border: Border.all(color: DSColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: DSColors.primary.withValues(alpha: 0.1),
                child: Text(
                  initial,
                  style: DSText.bodyMedium(context, color: DSColors.primary),
                ),
              ),
              const SizedBox(width: DSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(learnerName, style: DSText.bodyMedium(context)),
                    if (guardianName != null && guardianName != learnerName)
                      Text(
                        'ولي الأمر: $guardianName',
                        style: DSText.caption(
                          context,
                          color: DSColors.text3,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      ratedAt == null
                          ? 'وقت التقييم غير متاح'
                          : '${isInferredDate ? 'تاريخ الجلسة' : 'وقت التقييم'}: '
                              '${DateFormat('dd/MM/yyyy - hh:mm a', 'ar').format(ratedAt)}',
                      style: DSText.caption(context, color: DSColors.text3),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DSSpacing.sm,
                  vertical: DSSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: DSColors.secondary.withValues(alpha: 0.12),
                  borderRadius: DSRadius.mdAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 17,
                      color: DSColors.secondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${score.toStringAsFixed(score % 1 == 0 ? 0 : 1)}/$scoreScale',
                      style: DSText.bodyMedium(
                        context,
                        color: DSColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.md),
          if (isLegacy) ...[
            Text(
              'تقييم تاريخي غير محتسب في المتوسط العام',
              style: DSText.caption(context, color: DSColors.text3),
            ),
            const SizedBox(height: DSSpacing.xs),
          ] else if (isTechnicalOnly) ...[
            Text(
              'مستبعد من المتوسط العام: بلاغ تقني فقط',
              style: DSText.caption(context, color: DSColors.primary),
            ),
            const SizedBox(height: DSSpacing.xs),
          ],
          if (technicalIssueSource != null) ...[
            Text(
              'المشكلة التقنية: $technicalIssueSource',
              style: DSText.caption(context, color: DSColors.text3),
            ),
            const SizedBox(height: DSSpacing.xs),
          ],
          Text(
            comment ?? 'لم يضف الطالب تعليقًا.',
            style: DSText.body(
              context,
              color: comment == null ? DSColors.text3 : DSColors.text1,
            ),
          ),
        ],
      ),
    );
  }
}

String? _technicalIssueSourceLabel(dynamic source) {
  return switch (source) {
    'none' => 'لم توجد مشكلة',
    'student' => 'اتصال الطالب',
    'teacher' => 'اتصال المحفظ',
    'app' => 'التطبيق أو رابط الاجتماع',
    'unknown' => 'المصدر غير معروف',
    _ => null,
  };
}

class _CredentialsSection extends ConsumerWidget {
  const _CredentialsSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherCredentialsProvider(userId));
    return _ReviewPanel(
      title: 'الشهادات والوثائق',
      child: async.when(
        loading: () => _miniLoading(context),
        error: (e, _) => Text(
          'تعذر تحميل الوثائق',
          style: DSText.caption(context, color: DSColors.error),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Text(
              'لا توجد وثائق',
              style: DSText.caption(context, color: DSColors.text3),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items) ...[
                _ReviewLine(
                  title: _text(item, const ['title', 'name'], 'وثيقة'),
                  subtitle: _nullableText(
                    item,
                    const ['organization', 'issuer', 'status'],
                  ),
                  badge: _text(item, const ['status'], 'pending'),
                ),
                const SizedBox(height: DSSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PricingPlansSection extends ConsumerWidget {
  const _PricingPlansSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherReviewPricingPlansProvider(userId));
    return _ReviewPanel(
      title: 'الخطط السعرية',
      child: async.when(
        loading: () => _miniLoading(context),
        error: (e, _) => Text(
          'تعذر تحميل الخطط',
          style: DSText.caption(context, color: DSColors.error),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Text(
              'لا توجد خطط سعرية',
              style: DSText.caption(context, color: DSColors.text3),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items.take(6)) ...[
                _ReviewLine(
                  title: _text(item, const ['title', 'name'], 'خطة'),
                  subtitle: '${_money(_number(item, const [
                        'priceEGP',
                        'price'
                      ]))} - ${_text(item, const ['type'], 'single')}',
                  badge: item['isActive'] == false ? 'inactive' : 'active',
                ),
                const SizedBox(height: DSSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AvailabilitySection extends ConsumerWidget {
  const _AvailabilitySection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherReviewAvailabilityProvider(userId));
    return _ReviewPanel(
      title: 'التوفر',
      child: async.when(
        loading: () => _miniLoading(context),
        error: (e, _) => Text(
          'تعذر تحميل المواعيد',
          style: DSText.caption(context, color: DSColors.error),
        ),
        data: (items) {
          final active = items.where(_hasActiveSlots).toList();
          if (active.isEmpty) {
            return Text(
              'لا توجد مواعيد نشطة',
              style: DSText.caption(context, color: DSColors.text3),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in active.take(7)) ...[
                _ReviewLine(
                  title: _dayLabel(item['dayOfWeek']),
                  subtitle:
                      '${_enabledSlots(item).length} موعد - ${_nullableText(item, const [
                                'startTime'
                              ]) ?? '—'} / ${_nullableText(item, const ['endTime']) ?? '—'}',
                ),
                const SizedBox(height: DSSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SupportTab extends StatelessWidget {
  const _SupportTab({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'الشكاوى والدعم'),
        const SizedBox(height: DSSpacing.md),
        const DSCard(
          child: DSEmptyState(
            title: 'لا توجد تذاكر دعم مفعّلة بعد',
            subtitle:
                'هذه المساحة جاهزة للربط مع نظام التذاكر عند إضافة collection مخصصة للدعم.',
            icon: Icons.support_agent_outlined,
          ),
        ),
        const SizedBox(height: DSSpacing.lg),
        _TextPanel(
          title: 'ملاحظات مرتبطة بالحساب',
          value: _nullableText(
                user,
                const [
                  'supportNotes',
                  'adminNotes',
                  'suspensionReason',
                  'rejectionReason',
                ],
              ) ??
              '—',
        ),
      ],
    );
  }
}

class _NotificationsAndDevicesTab extends ConsumerWidget {
  const _NotificationsAndDevicesTab({
    required this.userId,
    required this.user,
  });

  final String userId;
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(adminUserNotificationsProvider(userId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'الأجهزة و FCM'),
        const SizedBox(height: DSSpacing.md),
        DSGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 3,
          children: [
            _InfoCard(
              label: 'FCM Token',
              value: _shortToken(_nullableText(user, const ['fcmToken'])),
              icon: Icons.vpn_key_outlined,
            ),
            _InfoCard(
              label: 'آخر تحديث للتوكن',
              value: _date(user['fcmTokenUpdatedAt']),
              icon: Icons.update_rounded,
            ),
            _InfoCard(
              label: 'عدد التوكنات',
              value: '${_tokenCount(user)}',
              icon: Icons.devices_outlined,
            ),
          ],
        ),
        const SizedBox(height: DSSpacing.xl),
        const SectionHeader(title: 'آخر الإشعارات'),
        const SizedBox(height: DSSpacing.md),
        notifications.when(
          loading: () => const DSSkeletonCard(),
          error: (e, _) =>
              DSBanner(message: '$e', variant: DSBannerVariant.error),
          data: (items) {
            if (items.isEmpty) {
              return const DSCard(
                child: DSEmptyState(
                  title: 'لا توجد إشعارات',
                  icon: Icons.notifications_off_outlined,
                ),
              );
            }

            return DSDataTable<Map<String, dynamic>>(
              columns: [
                DSColumnDef(
                  key: 'type',
                  label: 'النوع',
                  width: 140,
                  cellBuilder: (ctx, item) => DSBadge(
                    label: _text(item, const ['type'], 'system'),
                    variant: item['isRead'] == true
                        ? DSBadgeVariant.neutral
                        : DSBadgeVariant.info,
                    dot: item['isRead'] != true,
                  ),
                ),
                DSColumnDef(
                  key: 'title',
                  label: 'العنوان',
                  cellBuilder: (ctx, item) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(item, const ['title'], 'إشعار'),
                        overflow: TextOverflow.ellipsis,
                        style: DSText.bodyMedium(ctx),
                      ),
                      Text(
                        _text(item, const ['body'], ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DSText.caption(ctx, color: DSColors.text3),
                      ),
                    ],
                  ),
                ),
                DSColumnDef(
                  key: 'date',
                  label: 'التاريخ',
                  width: 140,
                  cellBuilder: (ctx, item) => Text(
                    _date(item['createdAt']),
                    style: DSText.body(ctx, color: DSColors.text2),
                  ),
                ),
              ],
              rows: items,
            );
          },
        ),
      ],
    );
  }
}

class _CreditWalletButton extends ConsumerWidget {
  const _CreditWalletButton({
    required this.userId,
    required this.name,
    required this.ownerType,
  });

  final String userId;
  final String name;
  final WalletOwnerType ownerType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DSButton(
      label: 'شحن يدوي',
      size: DSButtonSize.sm,
      variant: DSButtonVariant.secondary,
      leading: const Icon(Icons.add_rounded, size: 16),
      onPressed: () => _credit(context, ref),
    );
  }

  Future<void> _credit(BuildContext context, WidgetRef ref) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    try {
      final input = await DSDialog.show<_WalletCreditInput>(
        context,
        title: 'شحن يدوي للمحفظة',
        width: 520,
        child: StatefulBuilder(
          builder: (context, setState) {
            final amount = double.tryParse(amountController.text.trim()) ?? 0;
            final reason = reasonController.text.trim();
            final canSubmit = amount > 0 && reason.length >= 3;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة رصيد إلى محفظة "$name". السبب مطلوب لأنه يظهر في سجل العمليات.',
                  style: DSText.body(context, color: DSColors.text2),
                ),
                const SizedBox(height: DSSpacing.lg),
                DSTextField(
                  controller: amountController,
                  label: 'المبلغ (ج.م)',
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: DSSpacing.md),
                DSTextField(
                  controller: reasonController,
                  label: 'السبب',
                  hint: 'مثال: تعويض، تصحيح رصيد، رصيد ترويجي',
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: DSSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DSButton(
                      label: 'إلغاء',
                      variant: DSButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: DSSpacing.sm),
                    DSButton(
                      label: 'شحن',
                      onPressed: canSubmit
                          ? () => Navigator.of(context).pop(
                                _WalletCreditInput(
                                  amount: amount,
                                  reason: reason,
                                ),
                              )
                          : null,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
      if (input == null || !context.mounted) return;

      await ref.read(adminActionsProvider.notifier).creditWallet(
            userId: userId,
            ownerType:
                ownerType == WalletOwnerType.mohaffez ? 'mohaffez' : 'student',
            amountEgp: input.amount,
            reason: input.reason,
          );
      if (!context.mounted) return;
      ref.read(adminActionsProvider).when(
            data: (_) => DSToast.show(
              context,
              'تم شحن المحفظة',
              type: DSToastType.success,
            ),
            loading: () {},
            error: (e, _) => DSToast.show(
              context,
              'فشل العملية: $e',
              type: DSToastType.error,
            ),
          );
    } finally {
      amountController.dispose();
      reasonController.dispose();
    }
  }
}

class _WalletCreditInput {
  const _WalletCreditInput({required this.amount, required this.reason});

  final double amount;
  final String reason;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DSSpacing.lg),
      decoration: BoxDecoration(
        color: DSColors.surface,
        borderRadius: DSRadius.lgAll,
        border: Border.all(color: DSColors.border),
        boxShadow: DSElevation.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DSSpacing.sm),
            decoration: BoxDecoration(
              color: DSColors.primary.withValues(alpha: 0.08),
              borderRadius: DSRadius.mdAll,
            ),
            child: Icon(icon, size: 18, color: DSColors.primary),
          ),
          const SizedBox(width: DSSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: DSText.caption(context, color: DSColors.text3)),
                SelectableText(
                  value,
                  maxLines: 2,
                  style: DSText.bodyMedium(context, color: DSColors.text1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextPanel extends StatelessWidget {
  const _TextPanel({
    required this.title,
    required this.value,
    this.trailing,
  });

  final String title;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: DSText.h3(context))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: DSSpacing.sm),
          SelectableText(
            value,
            style: DSText.body(context, color: DSColors.text2),
          ),
        ],
      ),
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DSText.h3(context)),
          const SizedBox(height: DSSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({
    required this.title,
    this.subtitle,
    this.badge,
  });

  final String title;
  final String? subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DSSpacing.md),
      decoration: BoxDecoration(
        color: DSColors.surfaceMuted,
        borderRadius: DSRadius.mdAll,
        border: Border.all(color: DSColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DSText.bodyMedium(context)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DSText.caption(context, color: DSColors.text3),
                  ),
              ],
            ),
          ),
          if (badge != null)
            DSBadge(
              label: _compactBadgeLabel(badge!),
              variant: _compactBadgeVariant(badge!),
            ),
        ],
      ),
    );
  }
}

Widget _miniLoading(BuildContext context) {
  return Row(
    children: [
      const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: DSColors.primary,
        ),
      ),
      const SizedBox(width: DSSpacing.sm),
      Text('جاري التحميل...',
          style: DSText.caption(context, color: DSColors.text3)),
    ],
  );
}

String _text(
  Map<String, dynamic> data,
  List<String> keys, [
  String fallback = '—',
]) {
  return _nullableText(data, keys) ?? fallback;
}

String? _nullableText(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is Iterable) {
      final joined = value
          .whereType<Object>()
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .join('، ');
      if (joined.isNotEmpty) return joined;
    }
  }
  return null;
}

double _number(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is num) return value.toDouble();
  }
  return 0;
}

String? _coordinatesLabel(Map<String, dynamic> data) {
  double? lat;
  double? lng;

  void readPair(dynamic source) {
    if (source == null) return;
    if (source is Map) {
      lat ??= (source['latitude'] as num?)?.toDouble() ??
          (source['lat'] as num?)?.toDouble();
      lng ??= (source['longitude'] as num?)?.toDouble() ??
          (source['lng'] as num?)?.toDouble();
      return;
    }
    try {
      lat ??= (source as dynamic).latitude as double?;
      lng ??= (source as dynamic).longitude as double?;
    } catch (_) {}
  }

  readPair(data['location']);
  readPair(data['geoPoint']);
  lat ??= (data['latitude'] as num?)?.toDouble() ??
      (data['lat'] as num?)?.toDouble() ??
      (data['addressLat'] as num?)?.toDouble();
  lng ??= (data['longitude'] as num?)?.toDouble() ??
      (data['lng'] as num?)?.toDouble() ??
      (data['addressLng'] as num?)?.toDouble();

  if (lat == null || lng == null) return null;
  return '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}';
}

String _roleLabel(String role) => switch (role) {
      'mohaffez' => 'محفظ',
      'admin' => 'مدير',
      _ => 'طالب',
    };

DSBadgeVariant _roleVariant(String role) => switch (role) {
      'mohaffez' => DSBadgeVariant.primary,
      'admin' => DSBadgeVariant.warning,
      _ => DSBadgeVariant.neutral,
    };

String _statusLabel(String status) => switch (status) {
      'active' => 'نشط',
      'pending_approval' => 'بانتظار المراجعة',
      'rejected' => 'مرفوض',
      'suspended' => 'معلّق',
      'deleted' => 'محذوف',
      'flagged' || 'suspicious' || 'under_review' => 'قيد المراجعة',
      _ => status.isEmpty ? '—' : status,
    };

DSBadgeVariant _statusVariant(String status) => switch (status) {
      'active' => DSBadgeVariant.success,
      'pending_approval' => DSBadgeVariant.info,
      'rejected' => DSBadgeVariant.error,
      'suspended' => DSBadgeVariant.warning,
      'deleted' => DSBadgeVariant.error,
      'flagged' || 'suspicious' || 'under_review' => DSBadgeVariant.warning,
      _ => DSBadgeVariant.neutral,
    };

String? _adminRole(Map<String, dynamic> user) {
  if (user['role'] != 'admin') return null;
  return user['adminRole'] == 'admin' ? 'Admin' : 'Super Admin';
}

String _adminRoleKey(Map<String, dynamic> user) {
  return user['adminRole'] == 'admin' ? 'admin' : 'super_admin';
}

String? _adminPermissionsLabel(Map<String, dynamic> user) {
  if (user['role'] != 'admin') return null;
  if (user['adminRole'] != 'admin') return 'صلاحية كاملة';
  final raw = user['adminPermissions'];
  if (raw is! Map) return 'صلاحيات افتراضية';
  final enabled = _assignableAdminPermissions
      .where((permission) => raw[permission.key] == true)
      .map((permission) => permission.label)
      .toList();
  return enabled.isEmpty ? 'لا توجد صلاحيات مفعّلة' : enabled.join('، ');
}

String _verificationLabel(Map<String, dynamic> user) {
  if (user['role'] != 'mohaffez') return 'غير مطلوب';
  if (user['status'] == 'active') return 'معتمد';
  if (user['status'] == 'pending_approval') return 'بانتظار المراجعة';
  if (user['status'] == 'rejected') return 'مرفوض';
  return 'غير مكتمل';
}

String _sessionStatusLabel(String status) {
  if (status == 'completed') return 'مكتملة';
  if (status == 'accepted') return 'مقبولة';
  if (status == 'pending') return 'قيد الانتظار';
  if (status.contains('awaitingpayment') || status.contains('awaiting')) {
    return 'بانتظار الدفع';
  }
  if (status.contains('cancel')) return 'ملغاة';
  if (status.contains('no_show') || status.contains('noshow')) {
    return 'لم يحضر';
  }
  return status.isEmpty ? '—' : status;
}

DSBadgeVariant _sessionStatusVariant(String status) {
  if (status == 'completed') return DSBadgeVariant.success;
  if (status == 'accepted' || status == 'pending') return DSBadgeVariant.info;
  if (status.contains('cancel') || status.contains('no')) {
    return DSBadgeVariant.error;
  }
  return DSBadgeVariant.neutral;
}

String _walletTxTypeLabel(WalletTxType type) => switch (type) {
      WalletTxType.topup => 'شحن',
      WalletTxType.sessionPayment => 'دفع جلسة',
      WalletTxType.sessionRefund => 'استرداد',
      WalletTxType.cycleSettlement => 'تسوية',
      WalletTxType.payout => 'سحب',
      WalletTxType.payoutReversal => 'عكس سحب',
      WalletTxType.promoCredit => 'رصيد ترويجي',
      WalletTxType.directSessionCommission => 'عمولة مباشرة',
      WalletTxType.directSessionCommissionReversal => 'عكس عمولة',
      WalletTxType.adjustment => 'تعديل',
      WalletTxType.commissionRateChange => 'تغيير عمولة',
      WalletTxType.penaltyApplied => 'غرامة',
    };

String _paymentEventLabel(String type) => switch (type.toLowerCase()) {
      'paymentcompleted' => 'مكتمل',
      'paymentfailed' => 'فشل',
      'webhookreceived' => 'Webhook',
      'bookingconfirmed' => 'حجز',
      'subscriptioncreated' => 'اشتراك',
      'paymentcreated' => 'جديد',
      _ => type,
    };

DSBadgeVariant _paymentEventVariant(String type) {
  final normalized = type.toLowerCase();
  if (normalized == 'paymentcompleted' || normalized == 'bookingconfirmed') {
    return DSBadgeVariant.success;
  }
  if (normalized == 'paymentfailed') return DSBadgeVariant.error;
  if (normalized == 'webhookreceived') return DSBadgeVariant.primary;
  return DSBadgeVariant.neutral;
}

String _compactBadgeLabel(String value) => switch (value.toLowerCase()) {
      'approved' => 'معتمد',
      'rejected' => 'مرفوض',
      'pending' => 'معلق',
      'active' => 'نشط',
      'inactive' => 'غير نشط',
      _ => value,
    };

DSBadgeVariant _compactBadgeVariant(String value) =>
    switch (value.toLowerCase()) {
      'approved' || 'active' => DSBadgeVariant.success,
      'rejected' || 'inactive' => DSBadgeVariant.error,
      'pending' => DSBadgeVariant.warning,
      _ => DSBadgeVariant.neutral,
    };

bool _hasActiveSlots(Map<String, dynamic> day) {
  return _enabledSlots(day).isNotEmpty ||
      day['isActive'] == true ||
      (_nullableText(day, const ['startTime']) != null &&
          _nullableText(day, const ['endTime']) != null);
}

List<Map<String, dynamic>> _enabledSlots(Map<String, dynamic> day) {
  final raw = day['timeSlots'];
  if (raw is! Iterable) return const [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((slot) => slot['enabled'] != false)
      .toList();
}

String _dayLabel(dynamic value) {
  final day = (value as num?)?.toInt();
  if (day != null && day >= 1 && day <= ScheduleConstants.arabicDays.length) {
    return ScheduleConstants.arabicDays[day - 1];
  }
  return 'يوم غير محدد';
}

String _shortToken(String? token) {
  if (token == null || token.isEmpty) return '—';
  if (token.length <= 22) return token;
  return '${token.substring(0, 10)}...${token.substring(token.length - 8)}';
}

int _tokenCount(Map<String, dynamic> user) {
  final tokens = user['fcmTokens'];
  if (tokens is Iterable) return tokens.length;
  if (tokens is Map) return tokens.length;
  return _nullableText(user, const ['fcmToken']) == null ? 0 : 1;
}

String _money(double value) {
  return '${NumberFormat.decimalPattern('ar').format(value.round())} ج.م';
}

String _date(dynamic value) {
  final date = _toDate(value);
  return date == null ? '—' : DateFormat('dd/MM/yyyy', 'ar').format(date);
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}
