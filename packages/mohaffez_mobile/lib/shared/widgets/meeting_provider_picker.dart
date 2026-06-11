import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import 'meeting_links_sheet.dart' show meetingProviders;

/// Lets the student pick which meeting platform (Zoom / Meet / Teams) to use
/// for an online session, restricted to providers the teacher has actually
/// configured in `users/{teacherId}.meetingLinks`.
///
/// Calls [onChanged] with the selected provider id, or `null` if nothing is
/// selected (e.g. teacher has zero providers configured).
class MeetingProviderPicker extends ConsumerWidget {
  final String teacherId;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const MeetingProviderPicker({
    super.key,
    required this.teacherId,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherAsync = ref.watch(userByIdProvider(teacherId));
    return teacherAsync.when(
      loading: () => const _LoadingCard(),
      error: (_, __) => const _ErrorCard(),
      data: (teacher) {
        if (teacher == null) return const _ErrorCard();
        final available = meetingProviders
            .where((p) => (teacher.meetingLinks[p.id] ?? '').trim().isNotEmpty)
            .toList();

        // Legacy fallback: if teacher only has the old single meetingLink,
        // treat its host as one provider so booking still works during migration.
        if (available.isEmpty &&
            (teacher.meetingLink?.trim().isNotEmpty ?? false)) {
          final legacy = teacher.meetingLink!.trim();
          final match = meetingProviders
              .where((p) => legacy.toLowerCase().contains(p.hostMatch))
              .toList();
          if (match.isNotEmpty) available.addAll(match);
        }

        if (available.isEmpty) return const _NoProvidersCard();

        // Auto-select if there's only one option and nothing chosen yet.
        if (available.length == 1 && selected == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChanged(available.first.id);
          });
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          decoration: BoxDecoration(
            color: AppThemeConstants.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppThemeConstants.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.videocam_rounded,
                      size: 20, color: AppThemeConstants.primary),
                  SizedBox(width: 8),
                  Text(
                    'اختر منصة الاجتماع',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppThemeConstants.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'سيُستخدم رابط المعلم على المنصة التي تختارها.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppThemeConstants.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in available)
                    _ProviderChip(
                      label: p.label,
                      icon: p.icon,
                      color: p.color,
                      selected: selected == p.id,
                      onTap: () => onChanged(p.id),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProviderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ProviderChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppThemeConstants.grey300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? color : AppThemeConstants.textPrimary,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle_rounded, size: 16, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppThemeConstants.grey50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('جاري تحميل المنصات المتاحة...',
                style: TextStyle(fontSize: 13)),
          ],
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppThemeConstants.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppThemeConstants.error.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'تعذّر تحميل منصات الاجتماع المتاحة',
          style: TextStyle(fontSize: 13, color: AppThemeConstants.error),
        ),
      );
}

class _NoProvidersCard extends StatelessWidget {
  const _NoProvidersCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppThemeConstants.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppThemeConstants.warning.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 20, color: AppThemeConstants.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'هذا المعلم لم يضف رابط اجتماع بعد. لا يمكن حجز جلسة أونلاين معه حالياً.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      );
}
