import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/admin_app_bar.dart';
import '../shared/widgets/admin_empty_state.dart';
import '../utils/arabic_labels.dart';

/// Cache for user names to avoid repeated fetches
final _userNameCache = <String, String>{};

class AdminAuditLogScreen extends ConsumerStatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  ConsumerState<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends ConsumerState<AdminAuditLogScreen> {
  final Map<String, String> _userNames = {};

  String _truncateUid(String? uid) {
    if (uid == null || uid.isEmpty) return '-';
    if (uid.length <= 12) return uid;
    return '${uid.substring(0, 12)}...';
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    final dateFormat = DateFormat.yMd('ar_EG');
    final timeFormat = DateFormat.jm('ar_EG');
    return '${dateFormat.format(date)} ${timeFormat.format(date)}';
  }

  Future<String> _getUserName(String userId) async {
    if (userId.isEmpty) return '-';
    // Check cache first
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    // Check local state
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }
    // Fetch from Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final name = doc.data()?['displayName'] ??
          doc.data()?['name'] ??
          doc.data()?['email'] ??
          _truncateUid(userId);
      _userNameCache[userId] = name;
      if (mounted) {
        setState(() => _userNames[userId] = name);
      }
      return name;
    } catch (e) {
      return _truncateUid(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auditLog = ref.watch(auditLogProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: ArabicLabels.auditLogTitle),
        body: auditLog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Card(
              margin: const EdgeInsets.all(AppThemeConstants.spaceMd),
              color: AppThemeConstants.error,
              child: Padding(
                padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
                child: Text(
                  e.toString(),
                  style: const TextStyle(color: AppThemeConstants.onPrimary),
                ),
              ),
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const AdminEmptyState(
                icon: Icons.history,
                message: ArabicLabels.noAuditLogs,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(AppThemeConstants.spaceSm),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final entry = list[i];
                final action = entry['action']?.toString() ?? '-';
                final performedBy = entry['performedBy']?.toString() ?? '';
                final targetUserId = entry['targetUserId']?.toString() ?? '';
                final timestamp = entry['timestamp'] as Timestamp?;
                final data = entry['data'] as Map<String, dynamic>?;

                // Fetch user names asynchronously
                if (performedBy.isNotEmpty && !_userNames.containsKey(performedBy)) {
                  _getUserName(performedBy);
                }
                if (targetUserId.isNotEmpty && !_userNames.containsKey(targetUserId)) {
                  _getUserName(targetUserId);
                }

                final performedByName = _userNames[performedBy] ?? _truncateUid(performedBy);
                final targetUserName = _userNames[targetUserId] ?? _truncateUid(targetUserId);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: AppThemeConstants.spaceXs,
                    horizontal: AppThemeConstants.spaceSm,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppThemeConstants.spaceSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Action name (bold, amber color)
                        Text(
                          action,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppThemeConstants.primary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: AppThemeConstants.spaceXs),
                        // performedBy with name (or truncated UID)
                        Row(
                          children: [
                            const Icon(
                              Icons.admin_panel_settings,
                              size: AppThemeConstants.iconSm,
                              color: AppThemeConstants.textSecondary,
                            ),
                            const SizedBox(width: AppThemeConstants.spaceXs),
                            Expanded(
                              child: Text(
                                '${ArabicLabels.performedBy}: $performedByName',
                                style: const TextStyle(
                                  color: AppThemeConstants.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_userNames[performedBy] == null && performedBy.isNotEmpty)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        // targetUserId if present
                        if (targetUserId.isNotEmpty) ...[
                          const SizedBox(height: AppThemeConstants.spaceXs),
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: AppThemeConstants.iconSm,
                                color: AppThemeConstants.textSecondary,
                              ),
                              const SizedBox(width: AppThemeConstants.spaceXs),
                              Expanded(
                                child: Text(
                                  '${ArabicLabels.targetUser}: $targetUserName',
                                  style: const TextStyle(
                                    color: AppThemeConstants.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_userNames[targetUserId] == null)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                        ],
                        // Timestamp formatted as Arabic date+time
                        const SizedBox(height: AppThemeConstants.spaceXs),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: AppThemeConstants.iconSm,
                              color: AppThemeConstants.textSecondary,
                            ),
                            const SizedBox(width: AppThemeConstants.spaceXs),
                            Text(
                              _formatTimestamp(timestamp),
                              style: const TextStyle(
                                color: AppThemeConstants.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        // Data map shown as ExpansionTile
                        if (data != null && data.isNotEmpty) ...[
                          const SizedBox(height: AppThemeConstants.spaceXs),
                          ExpansionTile(
                            title: const Text(
                              ArabicLabels.auditData,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            tilePadding: EdgeInsets.zero,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(
                                  AppThemeConstants.spaceSm,
                                ),
                                decoration: const BoxDecoration(
                                  color: AppThemeConstants.background,
                                  borderRadius:
                                      AppThemeConstants.borderRadiusSm,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: data.entries.map((e) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppThemeConstants.spaceXs,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${e.key}: ',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              e.value.toString(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppThemeConstants
                                                    .textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}


