import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import 'meeting_links_sheet.dart' show MeetingProviderSpec, meetingProviders;

const _phoneCallProvider = MeetingProviderSpec(
  id: 'phoneCall',
  label: 'مكالمة هاتفية',
  hostMatch: '',
  hint: '',
  icon: Icons.phone_rounded,
  color: AppThemeConstants.success,
);

/// Lets the student pick which communication channel (Zoom / Meet / Teams /
/// phone call) to use
/// for an online session, restricted to providers the teacher has actually
/// configured in `users/{teacherId}.meetingLinks`.
///
/// Calls [onChanged] with the selected provider id, or `null` if nothing is
/// selected (e.g. teacher has zero providers configured).
class MeetingProviderPicker extends ConsumerWidget {
  final String teacherId;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final bool showValidationError;

  const MeetingProviderPicker({
    super.key,
    required this.teacherId,
    required this.selected,
    required this.onChanged,
    this.showValidationError = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherAsync = ref.watch(userByIdProvider(teacherId));
    return teacherAsync.when(
      loading: () => const _LoadingCard(),
      error: (_, __) => const _ErrorCard(),
      data: (teacher) {
        if (teacher == null) return const _ErrorCard();
        final currentUser = ref.watch(currentUserProvider).valueOrNull;
        final available = meetingProviders
            .where((p) => (teacher.meetingLinks[p.id] ?? '').trim().isNotEmpty)
            .toList();
        final hasTeacherPhone = (teacher.phoneNumber ?? '').trim().isNotEmpty;
        final hasStudentPhone =
            (currentUser?.phoneNumber ?? '').trim().isNotEmpty;

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

        if (hasTeacherPhone && hasStudentPhone) {
          available.add(_phoneCallProvider);
        }

        if (available.isEmpty) return const _NoProvidersCard();

        // Auto-select if there's only one option and nothing chosen yet.
        if (available.length == 1 && selected == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChanged(available.first.id);
          });
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: showValidationError
                ? AppThemeConstants.error.withValues(alpha: 0.05)
                : AppThemeConstants.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: showValidationError
                  ? AppThemeConstants.error
                  : selected != null
                      ? AppThemeConstants.primary
                      : AppThemeConstants.primary.withValues(alpha: 0.35),
              width: showValidationError || selected != null ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppThemeConstants.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.forum_rounded,
                      size: 20,
                      color: AppThemeConstants.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اختر وسيلة التواصل',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppThemeConstants.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'كيف تريد حضور الجلسة الأونلاين؟',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppThemeConstants.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected != null
                          ? AppThemeConstants.success.withValues(alpha: 0.12)
                          : AppThemeConstants.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      selected != null ? 'تم الاختيار' : 'مطلوب',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: selected != null
                            ? AppThemeConstants.success
                            : AppThemeConstants.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  final itemWidth = available.length == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 8,
                    children: [
                      for (final p in available)
                        SizedBox(
                          width: itemWidth,
                          child: _ProviderOption(
                            label: p.label,
                            icon: p.icon,
                            color: p.color,
                            selected: selected == p.id,
                            onTap: () => onChanged(p.id),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    showValidationError
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 17,
                    color: showValidationError
                        ? AppThemeConstants.error
                        : AppThemeConstants.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      showValidationError
                          ? 'اختر وسيلة تواصل واحدة لإرسال الطلب.'
                          : 'سيستخدم المعلم وسيلة التواصل التي تختارها عند بدء الجلسة.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: showValidationError
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: showValidationError
                            ? AppThemeConstants.error
                            : AppThemeConstants.textSecondary,
                      ),
                    ),
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

class _ProviderOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ProviderOption({
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
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? color : AppThemeConstants.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 21,
              color: selected ? color : AppThemeConstants.grey400,
            ),
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
