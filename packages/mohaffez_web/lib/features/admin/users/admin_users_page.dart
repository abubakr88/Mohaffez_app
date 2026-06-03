import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminUsersPage extends ConsumerWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(userFilterProvider);
    final usersAsync = ref.watch(filteredUsersProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'المستخدمون',
            subtitle: 'إدارة جميع مستخدمي المنصة',
          ),
          const SizedBox(height: DSSpacing.xl),

          // ── Search + filters ────────────────────────────────────────────
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 720;
              final search = SizedBox(
                width: wide ? 320 : double.infinity,
                child: DSSearchField(
                  hint: 'بحث بالاسم أو المعرّف',
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
                        .setStatus(filter.statusFilter == 'active'
                            ? null
                            : 'active'),
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
            data: (users) {
              if (users.isEmpty) {
                return const DSEmptyState(
                  title: 'لا يوجد مستخدمون',
                  subtitle: 'جرّب تغيير عوامل التصفية أو البحث',
                  icon: Icons.people_outline_rounded,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إجمالي النتائج: ${users.length}',
                    style: DSText.caption(context, color: DSColors.text3),
                  ),
                  const SizedBox(height: DSSpacing.sm),
                  DSDataTable<Map<String, dynamic>>(
                    initialSortKey: 'name',
                    columns: [
                      DSColumnDef(
                        key: 'name',
                        label: 'الاسم',
                        sortable: true,
                        sortValue: (u) => (u['name'] as String? ?? '').toLowerCase(),
                        cellBuilder: (ctx, u) {
                          final name = u['name'] as String? ?? '—';
                          final photo = u['photoUrl'] as String?;
                          return Row(
                            children: [
                              DSAvatar(name: name, imageUrl: photo, size: 32),
                              const SizedBox(width: DSSpacing.sm),
                              Flexible(
                                child: Text(
                                  name,
                                  style: DSText.bodyMedium(ctx),
                                  overflow: TextOverflow.ellipsis,
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
                          return DSBadge(
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
                            label: status == 'active' ? 'نشط' : 'معلّق',
                            variant: status == 'active'
                                ? DSBadgeVariant.success
                                : DSBadgeVariant.warning,
                            dot: true,
                          );
                        },
                      ),
                      DSColumnDef(
                        key: 'joined',
                        label: 'تاريخ التسجيل',
                        width: 130,
                        sortable: true,
                        sortValue: (u) => _toDate(u['createdAt'])?.millisecondsSinceEpoch ?? 0,
                        cellBuilder: (ctx, u) {
                          final dt = _toDate(u['createdAt']);
                          final label = dt == null
                              ? '—'
                              : '${dt.day}/${dt.month}/${dt.year}';
                          return Text(label,
                              style:
                                  DSText.body(ctx, color: DSColors.text2));
                        },
                      ),
                      DSColumnDef(
                        key: 'actions',
                        label: '',
                        width: 56,
                        cellBuilder: (ctx, u) => _UserActionsMenu(user: u),
                      ),
                    ],
                    rows: users,
                  ),
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
}

// ── Row actions menu ──────────────────────────────────────────────────────
class _UserActionsMenu extends ConsumerWidget {
  const _UserActionsMenu({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = user['id'] as String? ?? '';
    final name = user['name'] as String? ?? 'المستخدم';
    final status = user['status'] as String? ?? 'active';
    final role = user['role'] as String? ?? 'student';
    final suspended = status == 'suspended';

    return DSDropdownMenu(
      items: [
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
        if (role != 'admin')
          DSDropdownItem(
            label: 'تغيير الدور',
            icon: Icons.swap_horiz_rounded,
            onTap: () => _changeRole(context, ref, id, name, role),
          ),
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

  Future<void> _suspend(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final ok = await DSDialog.confirm(
      context,
      title: 'تعليق الحساب',
      message: 'سيتم منع "$name" من استخدام التطبيق حتى يتم إلغاء التعليق. متابعة؟',
      confirmLabel: 'تعليق',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(adminActionsProvider.notifier)
          .suspendUser(id, 'تم التعليق من لوحة التحكم', null),
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
    final ok = await DSDialog.confirm(
      context,
      title: 'حذف الحساب',
      message:
          'سيتم حذف حساب "$name" نهائيًا وإلغاء طلباته الحيّة. لا يمكن التراجع. متابعة؟',
      confirmLabel: 'حذف نهائي',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(adminActionsProvider.notifier).deleteUserData(id),
      'تم حذف الحساب',
    );
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

// ── Small UI helpers ──────────────────────────────────────────────────────
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
