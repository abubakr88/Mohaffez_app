import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mohaffez_core/mohaffez_core.dart';

class TeacherActiveBundleCard extends StatelessWidget {
  const TeacherActiveBundleCard({
    super.key,
    required this.bundle,
    this.compact = false,
    this.onTap,
  });

  final TeacherActiveBundleInfo bundle;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final expiryLabel = _expiryLabel(bundle.expiryDate);
    final expiryWarning = _expiresSoon(bundle.expiryDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: expiryWarning
              ? AppThemeConstants.warning.withValues(alpha: 0.55)
              : AppThemeConstants.grey300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => showTeacherBundleDetails(context, bundle),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LearnerAvatar(bundle: bundle, radius: compact ? 22 : 25),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bundle.learnerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppThemeConstants.textPrimary,
                          ),
                        ),
                        if (bundle.guardianDisplayName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'ولي الأمر: ${bundle.guardianDisplayName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppThemeConstants.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'نشطة',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppThemeConstants.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                bundle.planTitle.isEmpty ? 'باقة جلسات' : bundle.planTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppThemeConstants.textPrimary,
                ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _BundleMeta(
                    icon: Icons.video_camera_front_rounded,
                    label: teacherSessionTypeLabel(bundle.sessionType),
                  ),
                  if (bundle.sessionDurationMinutes != null)
                    _BundleMeta(
                      icon: Icons.schedule_rounded,
                      label: '${bundle.sessionDurationMinutes} دقيقة',
                    ),
                  if (expiryLabel != null)
                    _BundleMeta(
                      icon: Icons.event_available_rounded,
                      label: expiryLabel,
                      warning: expiryWarning,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'متبقي ${bundle.remainingSessions} من ${bundle.totalSessions} جلسة',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppThemeConstants.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'المستخدم ${bundle.usedSessions}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppThemeConstants.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: bundle.progress,
                  minHeight: 6,
                  backgroundColor: AppThemeConstants.grey200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppThemeConstants.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearnerAvatar extends StatelessWidget {
  const _LearnerAvatar({required this.bundle, required this.radius});

  final TeacherActiveBundleInfo bundle;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photoUrl = bundle.studentProfilePhotoUrl?.trim() ?? '';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppThemeConstants.primary.withValues(alpha: 0.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl.isEmpty
          ? const Icon(Icons.school_rounded, color: AppThemeConstants.primary)
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.school_rounded,
                color: AppThemeConstants.primary,
              ),
            ),
    );
  }
}

class _BundleMeta extends StatelessWidget {
  const _BundleMeta({
    required this.icon,
    required this.label,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color =
        warning ? AppThemeConstants.warning : AppThemeConstants.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: warning
            ? AppThemeConstants.warning.withValues(alpha: 0.1)
            : AppThemeConstants.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

Future<void> showTeacherBundleDetails(
  BuildContext context,
  TeacherActiveBundleInfo bundle,
) {
  final dateFormat = DateFormat('d MMMM y', 'ar');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تفاصيل الباقة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              _DetailRow(label: 'الطالب', value: bundle.learnerName),
              if (bundle.guardianDisplayName != null)
                _DetailRow(
                  label: 'ولي الأمر',
                  value: bundle.guardianDisplayName!,
                ),
              _DetailRow(label: 'الباقة', value: bundle.planTitle),
              _DetailRow(
                label: 'نوع الجلسة',
                value: teacherSessionTypeLabel(bundle.sessionType),
              ),
              if (bundle.sessionDurationMinutes != null)
                _DetailRow(
                  label: 'مدة الجلسة',
                  value: '${bundle.sessionDurationMinutes} دقيقة',
                ),
              _DetailRow(
                label: 'الجلسات',
                value:
                    '${bundle.remainingSessions} متبقية من ${bundle.totalSessions}',
              ),
              if (bundle.startDate != null)
                _DetailRow(
                  label: 'تاريخ البدء',
                  value: dateFormat.format(bundle.startDate!),
                ),
              _DetailRow(
                label: 'تاريخ الانتهاء',
                value: bundle.expiryDate == null
                    ? 'بدون تاريخ انتهاء'
                    : dateFormat.format(bundle.expiryDate!),
              ),
              if (bundle.totalPaid > 0)
                _DetailRow(
                  label: 'قيمة الباقة',
                  value: '${bundle.totalPaid.toStringAsFixed(2)} ج.م',
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppThemeConstants.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppThemeConstants.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String teacherSessionTypeLabel(String sessionType) {
  return switch (sessionType) {
    'online' => 'أونلاين',
    'mosque' => 'في المسجد',
    'home' => 'زيارة منزلية',
    _ => sessionType.trim().isEmpty ? 'غير محدد' : sessionType,
  };
}

String? _expiryLabel(DateTime? expiryDate) {
  if (expiryDate == null) return null;
  final days = expiryDate.difference(DateTime.now()).inDays;
  if (days <= 0) return 'تنتهي اليوم';
  if (days <= 7) return 'تنتهي خلال $days يوم';
  return 'حتى ${DateFormat('d/M/y').format(expiryDate)}';
}

bool _expiresSoon(DateTime? expiryDate) {
  if (expiryDate == null) return false;
  return expiryDate.difference(DateTime.now()).inDays <= 7;
}
