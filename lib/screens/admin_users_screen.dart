import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../utils/arabic_labels.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(userFilterProvider);
    final usersAsync = ref.watch(filteredUsersProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text(ArabicLabels.allUsers)),
        body: Column(
          children: [
            // Search TextField
            Padding(
              padding: const EdgeInsets.all(AppThemeConstants.spaceSm),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو المعرف...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: filter.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => ref
                              .read(userFilterProvider.notifier)
                              .setSearch(''),
                        )
                      : null,
                  border: const OutlineInputBorder(
                    borderRadius: AppThemeConstants.borderRadiusSm,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppThemeConstants.spaceSm,
                    vertical: AppThemeConstants.spaceSm,
                  ),
                ),
                onChanged: (value) =>
                    ref.read(userFilterProvider.notifier).setSearch(value),
              ),
            ),
            // Role filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppThemeConstants.spaceSm),
              child: Row(
                children: [
                  _roleChip(context, ref, 'الكل', null),
                  _roleChip(context, ref, 'طالب', 'student'),
                  _roleChip(context, ref, 'محفظ', 'mohaffez'),
                  _roleChip(context, ref, 'أدمن', 'admin'),
                ],
              ),
            ),
            const SizedBox(height: AppThemeConstants.spaceXs),
            // Status filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppThemeConstants.spaceSm),
              child: Row(
                children: [
                  _statusChip(context, ref, 'كل الحالات', null),
                  _statusChip(context, ref, 'نشط', 'active'),
                  _statusChip(context, ref, 'موقوف', 'suspended'),
                ],
              ),
            ),
            const SizedBox(height: AppThemeConstants.spaceSm),
            // Users list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(filteredUsersProvider),
                child: usersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (users) {
                    if (users.isEmpty && filter.searchQuery.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 64,
                              color: AppThemeConstants.textSecondary,
                            ),
                            const SizedBox(height: AppThemeConstants.spaceMd),
                            Text(
                              'لا توجد نتائج لـ "${filter.searchQuery}"',
                              style: const TextStyle(
                                color: AppThemeConstants.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (users.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: AppThemeConstants.textSecondary,
                            ),
                            SizedBox(height: AppThemeConstants.spaceMd),
                            Text(
                              'لا يوجد مستخدمون',
                              style: TextStyle(
                                color: AppThemeConstants.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (_, i) {
                        final u = users[i];
                        final status = (u['status']?.toString() ?? 'active');
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: AppThemeConstants.spaceMd,
                              vertical: AppThemeConstants.spaceSm),
                          child: ListTile(
                            title: Text(u['name']?.toString() ?? '-'),
                            subtitle: Text(u['email']?.toString() ?? '-'),
                            trailing: Wrap(
                              spacing: AppThemeConstants.spaceXs,
                              children: [
                                Chip(label: Text(u['role']?.toString() ?? '-')),
                                Chip(
                                  backgroundColor: status == 'suspended'
                                      ? AppThemeConstants.error
                                          .withValues(alpha: 0.2)
                                      : AppThemeConstants.success
                                          .withValues(alpha: 0.2),
                                  label: Text(status == 'suspended'
                                      ? ArabicLabels.userBanned
                                      : ArabicLabels.userActive),
                                ),
                              ],
                            ),
                            onTap: () =>
                                context.pushNamed('admin-user-detail', extra: u),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(BuildContext context, WidgetRef ref, String label, String? value) {
    final filter = ref.watch(userFilterProvider);
    return Padding(
      padding: const EdgeInsets.only(left: AppThemeConstants.spaceSm),
      child: FilterChip(
        selected: filter.roleFilter == value,
        label: Text(label),
        onSelected: (_) =>
            ref.read(userFilterProvider.notifier).setRole(value),
      ),
    );
  }

  Widget _statusChip(BuildContext context, WidgetRef ref, String label, String? value) {
    final filter = ref.watch(userFilterProvider);
    return Padding(
      padding: const EdgeInsets.only(left: AppThemeConstants.spaceSm),
      child: FilterChip(
        selected: filter.statusFilter == value,
        label: Text(label),
        onSelected: (_) =>
            ref.read(userFilterProvider.notifier).setStatus(value),
      ),
    );
  }
}
