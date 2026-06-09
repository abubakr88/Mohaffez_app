import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../auth/auth_provider.dart' as web_auth;

class AdminUsersPage extends ConsumerWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(userFilterProvider);
    final usersAsync = ref.watch(filteredUsersProvider);
    final adminAccess = ref.watch(currentAdminAccessProvider).valueOrNull ??
        AdminAccessState.none();

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'المستخدمون',
            subtitle: 'إدارة جميع مستخدمي المنصة',
            actions: [
              if (adminAccess.isSuperAdmin)
                DSButton(
                  label: 'إضافة أدمن',
                  leading: const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 18,
                  ),
                  onPressed: () => _addAdmin(context, ref),
                ),
            ],
          ),
          const SizedBox(height: DSSpacing.xl),

          // ── Search + filters ────────────────────────────────────────────
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 720;
              final search = SizedBox(
                width: wide ? 380 : double.infinity,
                child: DSSearchField(
                  hint: 'بحث بالاسم، البريد، الهاتف أو المعرّف',
                  onChanged: (v) =>
                      ref.read(userFilterProvider.notifier).setSearch(v),
                ),
              );
              final filters = Wrap(
                spacing: DSSpacing.sm,
                runSpacing: DSSpacing.sm,
                children: [
                  _FilterChip(
                    label: 'الكل',
                    selected: filter.roleFilter == null,
                    onTap: () =>
                        ref.read(userFilterProvider.notifier).setRole(null),
                  ),
                  _FilterChip(
                    label: 'محفظون',
                    selected: filter.roleFilter == 'mohaffez',
                    onTap: () => ref
                        .read(userFilterProvider.notifier)
                        .setRole('mohaffez'),
                  ),
                  _FilterChip(
                    label: 'طلاب',
                    selected: filter.roleFilter == 'student',
                    onTap: () => ref
                        .read(userFilterProvider.notifier)
                        .setRole('student'),
                  ),
                  _FilterChip(
                    label: 'مديرون',
                    selected: filter.roleFilter == 'admin',
                    onTap: () =>
                        ref.read(userFilterProvider.notifier).setRole('admin'),
                  ),
                  const _VDivider(),
                  _FilterChip(
                    label: 'نشط',
                    selected: filter.statusFilter == 'active',
                    onTap: () => ref
                        .read(userFilterProvider.notifier)
                        .setStatus(
                            filter.statusFilter == 'active' ? null : 'active'),
                  ),
                  _FilterChip(
                    label: 'بانتظار المراجعة',
                    selected: filter.statusFilter == 'pending_approval',
                    onTap: () => ref
                        .read(userFilterProvider.notifier)
                        .setStatus(filter.statusFilter == 'pending_approval'
                            ? null
                            : 'pending_approval'),
                  ),
                  _FilterChip(
                    label: 'مرفوض',
                    selected: filter.statusFilter == 'rejected',
                    onTap: () => ref
                        .read(userFilterProvider.notifier)
                        .setStatus(filter.statusFilter == 'rejected'
                            ? null
                            : 'rejected'),
                  ),
                  _FilterChip(
                    label: 'معلّق',
                    selected: filter.statusFilter == 'suspended',
                    onTap: () => ref
                        .read(userFilterProvider.notifier)
                        .setStatus(filter.statusFilter == 'suspended'
                            ? null
                            : 'suspended'),
                  ),
                  _FilterChip(
                    label: 'محذوف',
                    selected: filter.statusFilter == 'deleted',
                    onTap: () => ref
                        .read(userFilterProvider.notifier)
                        .setStatus(filter.statusFilter == 'deleted'
                            ? null
                            : 'deleted'),
                  ),
                ],
              );

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    search,
                    const SizedBox(width: DSSpacing.lg),
                    Expanded(child: filters),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  search,
                  const SizedBox(height: DSSpacing.md),
                  filters,
                ],
              );
            },
          ),
          const SizedBox(height: DSSpacing.xl),

          usersAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (result) {
              final users = result.users;
              if (users.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DSEmptyState(
                      title: 'لا يوجد مستخدمون',
                      subtitle:
                          'جرّب تغيير عوامل التصفية أو تحميل نطاق أكبر من النتائج',
                      icon: Icons.people_outline_rounded,
                    ),
                    if (result.hasMore) ...[
                      const SizedBox(height: DSSpacing.md),
                      Center(
                        child: DSButton(
                          label: 'تحميل المزيد',
                          variant: DSButtonVariant.secondary,
                          leading:
                              const Icon(Icons.expand_more_rounded, size: 18),
                          onPressed: () =>
                              ref.read(userFilterProvider.notifier).loadMore(),
                        ),
                      ),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المعروض: ${users.length} من ${result.loadedCount}'
                    '${result.hasMore ? ' - توجد نتائج أخرى' : ''}',
                    style: DSText.caption(context, color: DSColors.text3),
                  ),
                  const SizedBox(height: DSSpacing.sm),
                  DSDataTable<Map<String, dynamic>>(
                    initialSortKey: 'name',
                    onRowTap: (u) {
                      final id = u['id'] as String? ?? '';
                      if (id.isNotEmpty) context.go('/admin/users/$id');
                    },
                    columns: [
                      DSColumnDef(
                        key: 'name',
                        label: 'الاسم',
                        sortable: true,
                        sortValue: (u) =>
                            (u['name'] as String? ?? '').toLowerCase(),
                        cellBuilder: (ctx, u) {
                          final name = u['name'] as String? ?? '—';
                          final photo = u['photoUrl'] as String?;
                          final id = u['id'] as String? ?? '';
                          return Row(
                            children: [
                              DSAvatar(name: name, imageUrl: photo, size: 32),
                              const SizedBox(width: DSSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: DSText.bodyMedium(
                                        ctx,
                                        color: DSColors.primary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (id.isNotEmpty)
                                      Text(
                                        id,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: DSText.caption(
                                          ctx,
                                          color: DSColors.text3,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      DSColumnDef(
                        key: 'contact',
                        label: 'التواصل',
                        sortable: true,
                        sortValue: (u) =>
                            (u['email'] as String? ?? '').toLowerCase(),
                        cellBuilder: (ctx, u) {
                          final email = u['email'] as String? ?? '';
                          final phone = u['phoneNumber'] as String? ?? '';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                email.isEmpty ? '—' : email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DSText.body(ctx, color: DSColors.text2),
                              ),
                              if (phone.isNotEmpty)
                                Text(
                                  phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DSText.caption(
                                    ctx,
                                    color: DSColors.text3,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      DSColumnDef(
                        key: 'role',
                        label: 'الدور',
                        width: 110,
                        sortable: true,
                        sortValue: (u) => u['role'] as String? ?? 'student',
                        cellBuilder: (ctx, u) {
                          final role = u['role'] as String? ?? 'student';
                          return Wrap(
                            spacing: DSSpacing.xs,
                            runSpacing: DSSpacing.xs,
                            children: [
                              DSBadge(
                                label: role == 'mohaffez'
                                    ? 'محفظ'
                                    : role == 'admin'
                                        ? 'مدير'
                                        : 'طالب',
                                variant: role == 'mohaffez'
                                    ? DSBadgeVariant.primary
                                    : role == 'admin'
                                        ? DSBadgeVariant.warning
                                        : DSBadgeVariant.neutral,
                              ),
                              if (role == 'admin')
                                DSBadge(
                                  label: _adminRoleLabel(u),
                                  variant: _adminRole(u) == 'super_admin'
                                      ? DSBadgeVariant.error
                                      : DSBadgeVariant.info,
                                ),
                            ],
                          );
                        },
                      ),
                      DSColumnDef(
                        key: 'status',
                        label: 'الحالة',
                        width: 100,
                        sortable: true,
                        sortValue: (u) => u['status'] as String? ?? 'active',
                        cellBuilder: (ctx, u) {
                          final status = u['status'] as String? ?? 'active';
                          return DSBadge(
                            label: _statusLabel(status),
                            variant: _statusVariant(status),
                            dot: true,
                          );
                        },
                      ),
                      DSColumnDef(
                        key: 'joined',
                        label: 'تاريخ التسجيل',
                        width: 130,
                        sortable: true,
                        sortValue: (u) =>
                            _toDate(u['createdAt'])?.millisecondsSinceEpoch ??
                            0,
                        cellBuilder: (ctx, u) {
                          final dt = _toDate(u['createdAt']);
                          return Text(_dateLabel(dt),
                              style: DSText.body(ctx, color: DSColors.text2));
                        },
                      ),
                      DSColumnDef(
                        key: 'activity',
                        label: 'آخر تحديث',
                        width: 130,
                        sortable: true,
                        sortValue: (u) =>
                            _activityDate(u)?.millisecondsSinceEpoch ?? 0,
                        cellBuilder: (ctx, u) {
                          return Text(
                            _dateLabel(_activityDate(u)),
                            style: DSText.body(ctx, color: DSColors.text2),
                          );
                        },
                      ),
                      DSColumnDef(
                        key: 'actions',
                        label: '',
                        width: 56,
                        cellBuilder: (ctx, u) => _UserActionsMenu(
                          user: u,
                          adminAccess: adminAccess,
                        ),
                      ),
                    ],
                    rows: users,
                  ),
                  if (result.hasMore) ...[
                    const SizedBox(height: DSSpacing.md),
                    Align(
                      alignment: Alignment.center,
                      child: DSButton(
                        label: 'تحميل المزيد',
                        variant: DSButtonVariant.secondary,
                        leading:
                            const Icon(Icons.expand_more_rounded, size: 18),
                        onPressed: () =>
                            ref.read(userFilterProvider.notifier).loadMore(),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  static DateTime? _activityDate(Map<String, dynamic> user) {
    return _toDate(user['lastActiveAt']) ??
        _toDate(user['lastLoginAt']) ??
        _toDate(user['updatedAt']) ??
        _toDate(user['createdAt']);
  }

  static String _dateLabel(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String _adminRole(Map<String, dynamic> user) {
    return user['adminRole'] == 'admin' ? 'admin' : 'super_admin';
  }

  static String _adminRoleLabel(Map<String, dynamic> user) {
    return _adminRole(user) == 'super_admin' ? 'Super' : 'Admin';
  }

  static String _statusLabel(String status) => switch (status) {
        'active' => 'نشط',
        'pending_approval' => 'بانتظار المراجعة',
        'rejected' => 'مرفوض',
        'suspended' => 'معلّق',
        'deleted' => 'محذوف',
        _ => 'معلّق',
      };

  static DSBadgeVariant _statusVariant(String status) => switch (status) {
        'active' => DSBadgeVariant.success,
        'pending_approval' => DSBadgeVariant.info,
        'rejected' => DSBadgeVariant.error,
        'suspended' => DSBadgeVariant.warning,
        'deleted' => DSBadgeVariant.error,
        _ => DSBadgeVariant.warning,
      };

  Future<void> _addAdmin(BuildContext context, WidgetRef ref) async {
    final input = await _showAddAdminDialog(context);
    if (input == null || !context.mounted) return;

    await ref.read(adminActionsProvider.notifier).grantAdminAccessByEmail(
          email: input.email,
          adminRole: input.adminRole,
          permissions: input.permissions,
        );
    if (!context.mounted) return;

    final state = ref.read(adminActionsProvider);
    state.when(
      data: (_) {
        DSToast.show(
          context,
          'تمت إضافة الأدمن وتحديث صلاحياته',
          type: DSToastType.success,
        );
        ref.invalidate(filteredUsersProvider);
      },
      loading: () {},
      error: (e, _) =>
          DSToast.show(context, 'فشل العملية: $e', type: DSToastType.error),
    );
  }

  Future<_AddAdminInput?> _showAddAdminDialog(BuildContext context) async {
    final emailController = TextEditingController();
    var selectedRole = 'admin';
    final permissions = {
      for (final permission in _assignableAdminPermissions)
        permission: defaultAdminPermissions[permission] ?? false,
    };

    try {
      return DSDialog.show<_AddAdminInput>(
        context,
        title: 'إضافة أدمن',
        width: 620,
        child: StatefulBuilder(
          builder: (context, setState) {
            final isLimitedAdmin = selectedRole == 'admin';

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DSTextField(
                  controller: emailController,
                  label: 'البريد الإلكتروني',
                  hint: 'admin@example.com',
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  leading: const Icon(Icons.email_outlined, size: 18),
                ),
                const SizedBox(height: DSSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _AdminRoleOption(
                        label: 'Super Admin',
                        icon: Icons.workspace_premium_rounded,
                        selected: selectedRole == 'super_admin',
                        onTap: () =>
                            setState(() => selectedRole = 'super_admin'),
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
                          key: const ValueKey('new-admin-permissions'),
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
                                      () => permissions[permission] =
                                          value ?? false,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          key: const ValueKey('new-super-admin-note'),
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
                      label: 'إضافة الأدمن',
                      onPressed: () {
                        final email = emailController.text.trim();
                        if (!email.contains('@')) {
                          DSToast.show(
                            context,
                            'يرجى إدخال بريد إلكتروني صحيح',
                            type: DSToastType.error,
                          );
                          return;
                        }
                        Navigator.of(context).pop(
                          _AddAdminInput(
                            email: email,
                            adminRole: selectedRole,
                            permissions: selectedRole == 'admin'
                                ? Map<AdminPermission, bool>.from(permissions)
                                : {
                                    for (final permission
                                        in AdminPermission.values)
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
    } finally {
      emailController.dispose();
    }
  }
}

// ── Row actions menu ──────────────────────────────────────────────────────
class _UserActionsMenu extends ConsumerWidget {
  const _UserActionsMenu({
    required this.user,
    required this.adminAccess,
  });

  final Map<String, dynamic> user;
  final AdminAccessState adminAccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = user['id'] as String? ?? '';
    final name = user['name'] as String? ?? 'المستخدم';
    final status = user['status'] as String? ?? 'active';
    final role = user['role'] as String? ?? 'student';
    final currentUid = adminAccess.uid.isNotEmpty
        ? adminAccess.uid
        : ref.watch(web_auth.authProvider).user?.uid;
    final isCurrentAdmin = id.isNotEmpty && id == currentUid;
    final suspended = status == 'suspended';
    final deleted = status == 'deleted' || user['isDeleted'] == true;
    final canManageUsers = adminAccess.can(AdminPermission.manageUsers);
    final canManageRoles = adminAccess.can(AdminPermission.manageUserRoles);
    final canDeleteUsers = adminAccess.can(AdminPermission.deleteUsers);
    final canManageAdminAccess = adminAccess.isSuperAdmin;
    final canSuspend = !deleted && !isCurrentAdmin && canManageUsers;
    final canChangeRole =
        !deleted && role != 'admin' && !isCurrentAdmin && canManageRoles;
    final canEditAdminAccess =
        !deleted && role == 'admin' && !isCurrentAdmin && canManageAdminAccess;
    final canDelete = !deleted && !isCurrentAdmin && canDeleteUsers;
    final hasMoreActions =
        canSuspend || canChangeRole || canEditAdminAccess || canDelete;

    return DSDropdownMenu(
      items: [
        DSDropdownItem(
          label: 'عرض التفاصيل',
          icon: Icons.open_in_new_rounded,
          dividerAfter: hasMoreActions,
          onTap: () {
            if (id.isNotEmpty) context.go('/admin/users/$id');
          },
        ),
        if (canSuspend)
          if (suspended)
            DSDropdownItem(
              label: 'إلغاء التعليق',
              icon: Icons.lock_open_rounded,
              onTap: () => _unsuspend(context, ref, id, name),
            )
          else
            DSDropdownItem(
              label: 'تعليق الحساب',
              icon: Icons.block_rounded,
              onTap: () => _suspend(context, ref, id, name),
            ),
        if (canChangeRole)
          DSDropdownItem(
            label: 'تغيير الدور',
            icon: Icons.swap_horiz_rounded,
            onTap: () => _changeRole(context, ref, id, name, role),
          ),
        if (canEditAdminAccess)
          DSDropdownItem(
            label: 'إدارة الصلاحيات',
            icon: Icons.admin_panel_settings_rounded,
            onTap: () => _manageAdminAccess(context, ref, id, name),
          ),
        if (canDelete)
          DSDropdownItem(
            label: 'حذف الحساب',
            icon: Icons.delete_outline_rounded,
            dividerAfter: false,
            onTap: () => _delete(context, ref, id, name),
          ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(DSSpacing.xs),
        child: Icon(Icons.more_vert_rounded, size: 18, color: DSColors.text2),
      ),
    );
  }

  Future<void> _manageAdminAccess(
    BuildContext context,
    WidgetRef ref,
    String id,
    String name,
  ) async {
    final input = await _showAdminAccessDialog(context, name, user);
    if (input == null || !context.mounted) return;

    await _run(
      context,
      ref,
      () => ref.read(adminActionsProvider.notifier).updateAdminAccess(
            userId: id,
            adminRole: input.adminRole,
            permissions: input.permissions,
          ),
      'تم تحديث صلاحيات الأدمن',
    );
  }

  Future<void> _suspend(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final result = await _showSuspendDialog(context, name);
    if (result == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(adminActionsProvider.notifier)
          .suspendUser(id, result.reason, result.expiresAt),
      'تم تعليق الحساب',
    );
  }

  Future<void> _unsuspend(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final ok = await DSDialog.confirm(
      context,
      title: 'إلغاء التعليق',
      message: 'سيتمكّن "$name" من استخدام التطبيق مجددًا. متابعة؟',
      confirmLabel: 'إلغاء التعليق',
    );
    if (!ok || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(adminActionsProvider.notifier).unsuspendUser(id),
      'تم إلغاء التعليق',
    );
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref, String id,
      String name, String currentRole) async {
    // NOTE: setUserRole only writes the Firestore role field, not the admin
    // custom claim. Admin privilege is granted separately via setAdminClaim,
    // so we deliberately restrict switching to student ↔ mohaffez here.
    final newRole = currentRole == 'mohaffez' ? 'student' : 'mohaffez';
    final newLabel = newRole == 'mohaffez' ? 'محفظ' : 'طالب';
    final ok = await DSDialog.confirm(
      context,
      title: 'تغيير الدور',
      message: 'تغيير دور "$name" إلى "$newLabel"؟',
      confirmLabel: 'تغيير',
    );
    if (!ok || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(adminActionsProvider.notifier).updateUserRole(id, newRole),
      'تم تغيير الدور إلى $newLabel',
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final reason = await _showDeleteDialog(context, name);
    if (reason == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(adminActionsProvider.notifier).deleteUserData(id, reason),
      'تم تعطيل الحساب وحذفه مبدئيًا',
    );
  }

  Future<_SuspendInput?> _showSuspendDialog(
    BuildContext context,
    String name,
  ) async {
    final reasonController = TextEditingController();
    final daysController = TextEditingController();

    try {
      return await DSDialog.show<_SuspendInput>(
        context,
        title: 'تعليق الحساب',
        width: 520,
        child: StatefulBuilder(
          builder: (context, setState) {
            final reason = reasonController.text.trim();
            final daysText = daysController.text.trim();
            final days = daysText.isEmpty ? null : int.tryParse(daysText);
            final hasDaysError =
                daysText.isNotEmpty && (days == null || days <= 0);
            final canSubmit = reason.isNotEmpty && !hasDaysError;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سيتم منع "$name" من استخدام التطبيق حتى يتم إلغاء التعليق أو انتهاء المدة.',
                  style: DSText.body(context, color: DSColors.text2),
                ),
                const SizedBox(height: DSSpacing.lg),
                DSTextField(
                  controller: reasonController,
                  label: 'سبب التعليق',
                  hint: 'مثال: مخالفة شروط الاستخدام',
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: DSSpacing.md),
                DSTextField(
                  controller: daysController,
                  label: 'مدة التعليق بالأيام',
                  hint: 'اتركها فارغة لتعليق مفتوح',
                  keyboardType: TextInputType.number,
                  error: hasDaysError ? 'أدخل رقم أيام صحيح' : null,
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
                      label: 'تعليق',
                      variant: DSButtonVariant.destructive,
                      onPressed: canSubmit
                          ? () {
                              final expiresAt = days == null
                                  ? null
                                  : DateTime.now().add(Duration(days: days));
                              Navigator.of(context).pop(
                                _SuspendInput(
                                  reason: reason,
                                  expiresAt: expiresAt,
                                ),
                              );
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    } finally {
      reasonController.dispose();
      daysController.dispose();
    }
  }

  Future<String?> _showDeleteDialog(BuildContext context, String name) async {
    final confirmController = TextEditingController();
    final reasonController = TextEditingController();

    try {
      final result = await DSDialog.show<String>(
        context,
        title: 'حذف مبدئي للحساب',
        width: 520,
        child: StatefulBuilder(
          builder: (context, setState) {
            final reason = reasonController.text.trim();
            final canDelete =
                confirmController.text.trim() == 'DELETE' && reason.length >= 3;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سيتم تعطيل دخول "$name" وإلغاء طلباته الحيّة مع الاحتفاظ بالسجلات التاريخية والمالية للمراجعة.',
                  style: DSText.body(context, color: DSColors.text2),
                ),
                const SizedBox(height: DSSpacing.lg),
                DSTextField(
                  controller: reasonController,
                  label: 'سبب الحذف',
                  hint: 'مثال: طلب من المستخدم، إساءة استخدام، حساب مكرر',
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: DSSpacing.md),
                DSTextField(
                  controller: confirmController,
                  label: 'اكتب DELETE للتأكيد',
                  hint: 'DELETE',
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
                      label: 'حذف مبدئي',
                      variant: DSButtonVariant.destructive,
                      onPressed: canDelete
                          ? () => Navigator.of(context).pop(reason)
                          : null,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
      return result;
    } finally {
      confirmController.dispose();
      reasonController.dispose();
    }
  }

  Future<_AdminAccessInput?> _showAdminAccessDialog(
    BuildContext context,
    String name,
    Map<String, dynamic> user,
  ) async {
    var selectedRole = AdminUsersPage._adminRole(user);
    final permissions = _limitedPermissionsFromUser(user);

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
                                    () => permissions[permission] =
                                        value ?? false,
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
                                  for (final permission
                                      in AdminPermission.values)
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

  Map<AdminPermission, bool> _limitedPermissionsFromUser(
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

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String successMsg,
  ) async {
    await action();
    if (!context.mounted) return;
    final state = ref.read(adminActionsProvider);
    state.when(
      data: (_) => DSToast.show(context, successMsg, type: DSToastType.success),
      loading: () {},
      error: (e, _) =>
          DSToast.show(context, 'فشل العملية: $e', type: DSToastType.error),
    );
  }
}

const _assignableAdminPermissions = [
  AdminPermission.manageUsers,
  AdminPermission.manageUserRoles,
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

class _AddAdminInput {
  const _AddAdminInput({
    required this.email,
    required this.adminRole,
    required this.permissions,
  });

  final String email;
  final String adminRole;
  final Map<AdminPermission, bool> permissions;
}

class _SuspendInput {
  const _SuspendInput({
    required this.reason,
    required this.expiresAt,
  });

  final String reason;
  final DateTime? expiresAt;
}

// ── Small UI helpers ──────────────────────────────────────────────────────
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          child: Text(
            label,
            style: DSText.caption(
              context,
              color: selected ? Colors.white : DSColors.text2,
            ),
          ),
        ),
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: DSSpacing.xs),
        color: DSColors.border,
      );
}
