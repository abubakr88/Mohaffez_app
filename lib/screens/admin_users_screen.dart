import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../utils/arabic_labels.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String? roleFilter;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider(roleFilter));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text(ArabicLabels.allUsers)),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(AppThemeConstants.spaceSm),
              child: Row(
                children: [
                  _chip(ArabicLabels.all, null),
                  _chip(ArabicLabels.student, 'student'),
                  _chip(ArabicLabels.mohaffez, 'mohaffez'),
                  _chip(ArabicLabels.admin, 'admin'),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(allUsersProvider(roleFilter)),
                child: usersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (users) => ListView.builder(
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(left: AppThemeConstants.spaceSm),
      child: FilterChip(
        selected: roleFilter == value,
        label: Text(label),
        onSelected: (_) => setState(() => roleFilter = value),
      ),
    );
  }
}
