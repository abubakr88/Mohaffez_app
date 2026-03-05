import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../utils/arabic_labels.dart';

class AdminAuditLogScreen extends ConsumerWidget {
  const AdminAuditLogScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLog = ref.watch(auditLogProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text(ArabicLabels.auditLogTitle)),
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
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: AppThemeConstants.icon3xl,
                      color: AppThemeConstants.textSecondary,
                    ),
                    SizedBox(height: AppThemeConstants.spaceMd),
                    Text(
                      ArabicLabels.noAuditLogs,
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
              padding: const EdgeInsets.all(AppThemeConstants.spaceSm),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final entry = list[i];
                final action = entry['action']?.toString() ?? '-';
                final performedBy = entry['performedBy']?.toString();
                final targetUserId = entry['targetUserId']?.toString();
                final timestamp = entry['timestamp'] as Timestamp?;
                final data = entry['data'] as Map<String, dynamic>?;

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
                            color: AppThemeConstants.primaryAmber,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: AppThemeConstants.spaceXs),
                        // performedBy UID (truncated)
                        Row(
                          children: [
                            const Icon(
                              Icons.admin_panel_settings,
                              size: AppThemeConstants.iconSm,
                              color: AppThemeConstants.textSecondary,
                            ),
                            const SizedBox(width: AppThemeConstants.spaceXs),
                            Text(
                              '${ArabicLabels.performedBy}: ${_truncateUid(performedBy)}',
                              style: const TextStyle(
                                color: AppThemeConstants.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        // targetUserId if present (grey, smaller)
                        if (targetUserId != null && targetUserId.isNotEmpty) ...[
                          const SizedBox(height: AppThemeConstants.spaceXs),
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: AppThemeConstants.iconSm,
                                color: AppThemeConstants.textSecondary,
                              ),
                              const SizedBox(width: AppThemeConstants.spaceXs),
                              Text(
                                '${ArabicLabels.targetUser}: ${_truncateUid(targetUserId)}',
                                style: const TextStyle(
                                  color: AppThemeConstants.textSecondary,
                                  fontSize: 12,
                                ),
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
                                  color: AppThemeConstants.backgroundLight,
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
