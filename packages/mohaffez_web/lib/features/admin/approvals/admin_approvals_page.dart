import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../../design_system/design_system.dart';
import '../../../platform/web_download.dart';

class AdminApprovalsPage extends ConsumerWidget {
  const AdminApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingTeachers = ref.watch(pendingTeachersProvider);
    final pendingCredentials = ref.watch(pendingCredentialsProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'طلبات التحقق',
            subtitle: 'مركز مراجعة حسابات المحفظين قبل تفعيلهم للطلاب',
          ),
          const SizedBox(height: DSSpacing.xxl),
          _PendingCredentialsQueue(async: pendingCredentials),
          const SizedBox(height: DSSpacing.xxl),
          pendingTeachers.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (items) {
              if (items.isEmpty) {
                return const DSEmptyState(
                  title: 'لا توجد طلبات معلقة',
                  subtitle:
                      'ستظهر حسابات المحفظين الجدد هنا عند اكتمال بيانات المراجعة',
                  icon: Icons.verified_user_outlined,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${items.length} محفظ بانتظار المراجعة',
                    style: DSText.caption(context, color: DSColors.text3),
                  ),
                  const SizedBox(height: DSSpacing.md),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: DSSpacing.lg),
                      child: _TeacherCard(teacher: item),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PendingCredentialsQueue extends StatelessWidget {
  const _PendingCredentialsQueue({required this.async});

  final AsyncValue<List<Map<String, dynamic>>> async;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'مراجعة الشهادات'),
        const SizedBox(height: DSSpacing.md),
        async.when(
          loading: () => const DSSkeletonCard(),
          error: (e, _) => DSBanner(
            message: 'تعذر تحميل الشهادات المعلقة: $e',
            variant: DSBannerVariant.error,
          ),
          data: (items) {
            if (items.isEmpty) {
              return DSCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      color: DSColors.success,
                    ),
                    const SizedBox(width: DSSpacing.md),
                    Expanded(
                      child: Text(
                        'لا توجد شهادات بانتظار الاعتماد الآن',
                        style: DSText.body(context, color: DSColors.text2),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${items.length} شهادة بانتظار الاعتماد',
                  style: DSText.caption(context, color: DSColors.text3),
                ),
                const SizedBox(height: DSSpacing.md),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: DSSpacing.md),
                    child: _PendingCredentialCard(credential: item),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PendingCredentialCard extends ConsumerWidget {
  const _PendingCredentialCard({required this.credential});

  final Map<String, dynamic> credential;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = credential['userId'] as String? ?? '';
    final credentialId = credential['id'] as String? ?? '';
    final teacherAsync =
        userId.isEmpty ? null : ref.watch(adminUserProvider(userId));
    final teacher = teacherAsync?.valueOrNull;
    final teacherName = teacher == null
        ? (userId.isEmpty ? 'محفظ غير محدد' : userId)
        : _text(teacher, const ['name', 'displayName'], userId);
    final title = _text(credential, const ['title', 'name'], 'شهادة');
    final organization = _nullableText(
      credential,
      const ['organization', 'issuer', 'source'],
    );
    final uploadedAt = credential['uploadedAt'] ?? credential['createdAt'];
    final images = _credentialImages(credential);
    final notes = _nullableText(credential, const ['description', 'notes']);

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: DSColors.primary,
              ),
              const SizedBox(width: DSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DSText.h3(context)),
                    const SizedBox(height: DSSpacing.xs),
                    Wrap(
                      spacing: DSSpacing.sm,
                      runSpacing: DSSpacing.sm,
                      children: [
                        _MetaChip(
                          icon: Icons.person_outline_rounded,
                          label: teacherName,
                        ),
                        if (organization != null)
                          _MetaChip(
                            icon: Icons.account_balance_outlined,
                            label: organization,
                          ),
                        _MetaChip(
                          icon: Icons.schedule_outlined,
                          label: _date(uploadedAt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DSSpacing.md),
              const DSBadge(
                label: 'قيد المراجعة',
                variant: DSBadgeVariant.warning,
                dot: true,
              ),
            ],
          ),
          if (notes != null) ...[
            const SizedBox(height: DSSpacing.sm),
            Text(notes, style: DSText.caption(context, color: DSColors.text2)),
          ],
          const SizedBox(height: DSSpacing.md),
          if (images.isEmpty)
            const _EmptyPanel(
              icon: Icons.image_not_supported_outlined,
              title: 'لا توجد صور مرفقة',
              message: 'راجع بيانات الشهادة قبل الاعتماد.',
            )
          else
            Wrap(
              spacing: DSSpacing.sm,
              runSpacing: DSSpacing.sm,
              children: [
                for (final url in images)
                  _Thumbnail(
                    url: url,
                    onTap: () => _openViewer(context, images, url),
                  ),
              ],
            ),
          const SizedBox(height: DSSpacing.md),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: DSSpacing.sm,
            runSpacing: DSSpacing.sm,
            children: [
              DSButton(
                label: 'فتح ملف المحفظ',
                size: DSButtonSize.sm,
                variant: DSButtonVariant.secondary,
                leading: const Icon(Icons.open_in_new_rounded, size: 16),
                onPressed: userId.isEmpty
                    ? null
                    : () => context.go('/admin/users/$userId'),
              ),
              DSButton(
                label: 'رفض الشهادة',
                size: DSButtonSize.sm,
                variant: DSButtonVariant.destructive,
                leading: const Icon(Icons.close_rounded, size: 16),
                onPressed: userId.isEmpty || credentialId.isEmpty
                    ? null
                    : () => _reject(context, ref, userId, credentialId, title),
              ),
              DSButton(
                label: 'اعتماد الشهادة',
                size: DSButtonSize.sm,
                leading: const Icon(Icons.check_rounded, size: 16),
                onPressed: userId.isEmpty || credentialId.isEmpty
                    ? null
                    : () => _approve(context, ref, userId, credentialId, title),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, List<String> images, String current) {
    if (images.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _ImageViewer(images: images, initial: current),
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String credentialId,
    String title,
  ) async {
    final ok = await DSDialog.confirm(
      context,
      title: 'اعتماد الشهادة',
      message:
          'اعتماد شهادة "$title"؟ ستظهر للطلاب في ملف المحفظ بعد الاعتماد.',
      confirmLabel: 'اعتماد',
    );
    if (!ok || !context.mounted) return;

    await _runAction(
      context,
      ref,
      () => ref
          .read(adminActionsProvider.notifier)
          .approveCredential(userId, credentialId),
      'تم اعتماد الشهادة',
    );
    ref.invalidate(pendingCredentialsProvider);
    ref.invalidate(teacherCredentialsProvider(userId));
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String credentialId,
    String title,
  ) async {
    final reason = await _showCredentialRejectDialog(context, title);
    if (reason == null || !context.mounted) return;

    await _runAction(
      context,
      ref,
      () => ref
          .read(adminActionsProvider.notifier)
          .rejectCredential(userId, credentialId, reason),
      'تم رفض الشهادة',
    );
    ref.invalidate(pendingCredentialsProvider);
    ref.invalidate(teacherCredentialsProvider(userId));
  }
}

class _TeacherCard extends ConsumerWidget {
  const _TeacherCard({required this.teacher});

  final Map<String, dynamic> teacher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = teacher['id'] as String? ?? '';
    final name = _text(teacher, const ['name', 'displayName'], 'محفظ');
    final photo = _nullableText(teacher, const ['photoUrl', 'profileImageUrl']);
    final specialization = _nullableText(
      teacher,
      const ['specialization', 'specialty', 'subjects'],
    );
    final bio = _nullableText(teacher, const ['bio', 'about']);
    final videoUrl = _nullableText(
      teacher,
      const ['youtubeVideoUrl', 'introVideoUrl', 'videoUrl'],
    );
    final rejectionReason = _nullableText(
      teacher,
      const [
        'rejectionReason',
        'lastRejectionReason',
        'approvalRejectionReason'
      ],
    );

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TeacherHeader(
            userId: userId,
            name: name,
            photo: photo,
            submittedAt: teacher['approvalSubmittedAt'] ?? teacher['createdAt'],
          ),
          const SizedBox(height: DSSpacing.lg),
          _ReviewSignals(teacher: teacher, userId: userId),
          const SizedBox(height: DSSpacing.xl),
          _ProfileSection(
            teacher: teacher,
            specialization: specialization,
            bio: bio,
            videoUrl: videoUrl,
            rejectionReason: rejectionReason,
          ),
          const SizedBox(height: DSSpacing.xl),
          _CredentialsSection(userId: userId),
          const SizedBox(height: DSSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 880;
              if (!wide) {
                return Column(
                  children: [
                    _PricingPlansSection(userId: userId),
                    const SizedBox(height: DSSpacing.lg),
                    _AvailabilitySection(userId: userId),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _PricingPlansSection(userId: userId)),
                  const SizedBox(width: DSSpacing.lg),
                  Expanded(child: _AvailabilitySection(userId: userId)),
                ],
              );
            },
          ),
          const SizedBox(height: DSSpacing.xl),
          const Divider(height: 1, color: DSColors.border),
          const SizedBox(height: DSSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DSButton(
                label: 'رفض',
                size: DSButtonSize.sm,
                variant: DSButtonVariant.destructive,
                leading: const Icon(Icons.close_rounded, size: 16),
                onPressed: userId.isEmpty
                    ? null
                    : () => _reject(context, ref, userId, name),
              ),
              const SizedBox(width: DSSpacing.sm),
              DSButton(
                label: 'اعتماد الحساب',
                size: DSButtonSize.sm,
                leading: const Icon(Icons.check_rounded, size: 16),
                onPressed: userId.isEmpty
                    ? null
                    : () => _approve(context, ref, userId, name),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String name,
  ) async {
    final ok = await DSDialog.confirm(
      context,
      title: 'اعتماد الحساب',
      message:
          'اعتماد حساب "$name"؟ سيتم تفعيل الحساب للطلاب وتسجيل العملية في سجل الإدارة.',
      confirmLabel: 'اعتماد',
    );
    if (!ok || !context.mounted) return;
    await _runAction(
      context,
      ref,
      () => ref.read(adminActionsProvider.notifier).approveTeacher(userId),
      'تم اعتماد حساب المحفظ',
    );
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String name,
  ) async {
    final reason = await _showRejectDialog(context, name);
    if (reason == null || !context.mounted) return;
    await _runAction(
      context,
      ref,
      () =>
          ref.read(adminActionsProvider.notifier).rejectTeacher(userId, reason),
      'تم رفض طلب المحفظ',
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({
    required this.userId,
    required this.name,
    required this.photo,
    required this.submittedAt,
  });

  final String userId;
  final String name;
  final String? photo;
  final dynamic submittedAt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final identity = Row(
          children: [
            DSAvatar(name: name, imageUrl: photo, size: 48),
            const SizedBox(width: DSSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: DSText.h3(context)),
                  const SizedBox(height: DSSpacing.xs),
                  Text(
                    'تاريخ التقديم: ${_date(submittedAt)}',
                    style: DSText.caption(context, color: DSColors.text3),
                  ),
                  if (userId.isNotEmpty)
                    Text(
                      userId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DSText.caption(context, color: DSColors.text3),
                    ),
                ],
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: DSSpacing.sm,
          runSpacing: DSSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const DSBadge(
              label: 'بانتظار المراجعة',
              variant: DSBadgeVariant.warning,
              dot: true,
            ),
            DSButton(
              label: 'فتح الملف الكامل',
              size: DSButtonSize.sm,
              variant: DSButtonVariant.secondary,
              leading: const Icon(Icons.open_in_new_rounded, size: 16),
              onPressed: userId.isEmpty
                  ? null
                  : () => context.go('/admin/users/$userId'),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identity,
              const SizedBox(height: DSSpacing.md),
              actions,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: DSSpacing.lg),
            actions,
          ],
        );
      },
    );
  }
}

class _ReviewSignals extends ConsumerWidget {
  const _ReviewSignals({required this.teacher, required this.userId});

  final Map<String, dynamic> teacher;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentials = ref.watch(teacherCredentialsProvider(userId));
    final pricing = ref.watch(teacherReviewPricingPlansProvider(userId));
    final availability = ref.watch(teacherReviewAvailabilityProvider(userId));
    final hasLocation = _locationLabel(teacher) != null;
    final hasVideo = _nullableText(
          teacher,
          const ['youtubeVideoUrl', 'introVideoUrl', 'videoUrl'],
        ) !=
        null;

    return DSGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 5,
      wideColumns: 5,
      spacing: DSSpacing.md,
      children: [
        _SignalTile(
          icon: Icons.description_outlined,
          label: 'الوثائق',
          value: credentials.when(
            loading: () => '...',
            error: (_, __) => 'تعذر التحميل',
            data: (items) => '${items.length}',
          ),
          good: credentials.valueOrNull?.isNotEmpty == true,
        ),
        _SignalTile(
          icon: Icons.payments_outlined,
          label: 'خطط السعر',
          value: pricing.when(
            loading: () => '...',
            error: (_, __) => 'تعذر التحميل',
            data: (items) {
              final active = _activePricingPlans(items).length;
              return '$active / ${items.length} نشطة';
            },
          ),
          good: _activePricingPlans(pricing.valueOrNull ?? const []).isNotEmpty,
        ),
        _SignalTile(
          icon: Icons.event_available_outlined,
          label: 'التوفر',
          value: availability.when(
            loading: () => '...',
            error: (_, __) => 'تعذر التحميل',
            data: (items) {
              final days = _activeAvailabilityDays(items);
              final slots = _enabledAvailabilitySlots(items).length;
              return '$days أيام / $slots موعد';
            },
          ),
          good: _enabledAvailabilitySlots(availability.valueOrNull ?? const [])
              .isNotEmpty,
        ),
        _SignalTile(
          icon: Icons.location_on_outlined,
          label: 'الموقع',
          value: hasLocation ? 'مكتمل' : 'غير متاح',
          good: hasLocation,
        ),
        _SignalTile(
          icon: Icons.play_circle_outline_rounded,
          label: 'الفيديو',
          value: hasVideo ? 'مرفق' : 'غير مرفق',
          good: hasVideo,
        ),
      ],
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.good,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final color = good ? DSColors.success : DSColors.warning;

    return Container(
      padding: const EdgeInsets.all(DSSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: DSRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
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

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.teacher,
    required this.specialization,
    required this.bio,
    required this.videoUrl,
    required this.rejectionReason,
  });

  final Map<String, dynamic> teacher;
  final String? specialization;
  final String? bio;
  final String? videoUrl;
  final String? rejectionReason;

  @override
  Widget build(BuildContext context) {
    final email = _nullableText(teacher, const ['email']);
    final phone = _nullableText(teacher, const ['phoneNumber', 'phone']);
    final city = _nullableText(teacher, const ['city', 'governorate']);
    final address = _nullableText(
      teacher,
      const ['addressText', 'address', 'locationAddress'],
    );
    final location = _locationLabel(teacher);
    final examScore = _examScoreLabel(teacher);
    final examStatus = _examStatusLabel(teacher);
    final examTakenAt = _date(teacher['examTakenAt']);
    final examAnswers = _examAnswersLabel(teacher);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'بيانات الحساب'),
        const SizedBox(height: DSSpacing.md),
        _InfoPanel(
          children: [
            _DetailRow(label: 'التخصص', value: specialization),
            _DetailRow(label: 'البريد الإلكتروني', value: email),
            _DetailRow(label: 'الهاتف', value: phone),
            _DetailRow(label: 'المدينة', value: city),
            _DetailRow(label: 'العنوان', value: address),
            _DetailRow(label: 'الإحداثيات', value: location),
            _DetailRow(label: 'نبذة', value: bio),
            _DetailRow(label: 'نتيجة الاختبار', value: examScore),
            _DetailRow(label: 'حالة الاختبار', value: examStatus),
            if (examTakenAt != '—')
              _DetailRow(label: 'تاريخ الاختبار', value: examTakenAt),
            _DetailRow(label: 'إجابات الاختبار', value: examAnswers),
            if (videoUrl != null)
              _DetailRow(
                label: 'فيديو تعريفي',
                child: SelectableText(
                  videoUrl!,
                  style: DSText.body(context, color: DSColors.primary),
                ),
              ),
            if (rejectionReason != null)
              _DetailRow(
                label: 'سبب رفض سابق',
                child: Text(
                  rejectionReason!,
                  style: DSText.body(context, color: DSColors.error),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PricingPlansSection extends ConsumerWidget {
  const _PricingPlansSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherReviewPricingPlansProvider(userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'الخطط السعرية'),
        const SizedBox(height: DSSpacing.md),
        async.when(
          loading: () => const _SectionLoading(label: 'جاري تحميل الخطط...'),
          error: (e, _) => _SectionError(message: 'تعذر تحميل الخطط: $e'),
          data: (plans) {
            if (plans.isEmpty) {
              return const _EmptyPanel(
                icon: Icons.payments_outlined,
                title: 'لا توجد خطط سعرية',
                message: 'يجب وجود خطة سعرية نشطة قبل اعتماد المحفظ.',
              );
            }

            return _InfoPanel(
              children: [
                ...plans.map((plan) => _PricingPlanRow(plan: plan)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PricingPlanRow extends StatelessWidget {
  const _PricingPlanRow({required this.plan});

  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    final title = _text(plan, const ['title', 'name'], 'خطة بدون اسم');
    final price = _price(plan);
    final sessions = (plan['sessionsCount'] as num?)?.toInt();
    final validity = (plan['validityDays'] as num?)?.toInt();
    final sessionsPerWeek = (plan['sessionsPerWeek'] as num?)?.toInt();
    final description = _nullableText(plan, const ['description']);
    final isActive = plan['isActive'] != false;

    return _RowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: DSText.bodyMedium(context))),
              DSBadge(
                label: isActive ? 'نشطة' : 'غير نشطة',
                variant:
                    isActive ? DSBadgeVariant.success : DSBadgeVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.sm),
          Wrap(
            spacing: DSSpacing.sm,
            runSpacing: DSSpacing.sm,
            children: [
              _MetaChip(icon: Icons.payments_outlined, label: _money(price)),
              _MetaChip(icon: Icons.category_outlined, label: _planType(plan)),
              _MetaChip(
                  icon: Icons.video_camera_front_outlined,
                  label: _planMode(plan)),
              if (sessions != null)
                _MetaChip(
                  icon: Icons.event_note_outlined,
                  label: '$sessions جلسة',
                ),
              if (sessionsPerWeek != null)
                _MetaChip(
                  icon: Icons.repeat_rounded,
                  label: '$sessionsPerWeek أسبوعيا',
                ),
              if (validity != null)
                _MetaChip(
                  icon: Icons.calendar_today_outlined,
                  label: '$validity يوم',
                ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: DSSpacing.sm),
            Text(description,
                style: DSText.caption(context, color: DSColors.text2)),
          ],
        ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'المواعيد المتاحة'),
        const SizedBox(height: DSSpacing.md),
        async.when(
          loading: () => const _SectionLoading(label: 'جاري تحميل المواعيد...'),
          error: (e, _) => _SectionError(message: 'تعذر تحميل المواعيد: $e'),
          data: (items) {
            final active = items.where(_hasActiveSlots).toList();
            if (active.isEmpty) {
              return const _EmptyPanel(
                icon: Icons.event_busy_outlined,
                title: 'لا توجد مواعيد متاحة',
                message: 'يجب وجود موعد نشط واحد على الأقل قبل الاعتماد.',
              );
            }

            return _InfoPanel(
              children: [
                ...active.map((day) => _AvailabilityDayRow(day: day)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AvailabilityDayRow extends StatelessWidget {
  const _AvailabilityDayRow({required this.day});

  final Map<String, dynamic> day;

  @override
  Widget build(BuildContext context) {
    final slots = _enabledSlots(day);
    final visible = slots.take(4).toList();
    final extra = slots.length - visible.length;
    final start = _nullableText(day, const ['startTime']);
    final end = _nullableText(day, const ['endTime']);
    final types = slots
        .map((slot) => _nullableText(slot, const ['sessionType']))
        .whereType<String>()
        .toSet()
        .map(_sessionTypeLabel)
        .toList();

    return _RowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _dayLabel(day['dayOfWeek']),
                  style: DSText.bodyMedium(context),
                ),
              ),
              DSBadge(
                label: '${slots.length} موعد',
                variant: DSBadgeVariant.info,
              ),
            ],
          ),
          if (start != null && end != null) ...[
            const SizedBox(height: DSSpacing.xs),
            Text('$start - $end',
                style: DSText.caption(context, color: DSColors.text3)),
          ],
          if (types.isNotEmpty) ...[
            const SizedBox(height: DSSpacing.sm),
            Wrap(
              spacing: DSSpacing.xs,
              runSpacing: DSSpacing.xs,
              children: [
                for (final type in types)
                  DSBadge(label: type, variant: DSBadgeVariant.neutral),
              ],
            ),
          ],
          const SizedBox(height: DSSpacing.sm),
          Wrap(
            spacing: DSSpacing.xs,
            runSpacing: DSSpacing.xs,
            children: [
              for (final slot in visible)
                _MetaChip(
                  icon: Icons.schedule_rounded,
                  label: _slotLabel(slot),
                ),
              if (extra > 0)
                DSBadge(
                  label: '+$extra',
                  variant: DSBadgeVariant.primary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CredentialsSection extends ConsumerWidget {
  const _CredentialsSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherCredentialsProvider(userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'الوثائق والشهادات'),
        const SizedBox(height: DSSpacing.md),
        async.when(
          loading: () => const _SectionLoading(label: 'جاري تحميل الوثائق...'),
          error: (e, _) => _SectionError(message: 'تعذر تحميل الوثائق: $e'),
          data: (creds) {
            final images = <String>[
              for (final c in creds) ..._credentialImages(c),
            ];
            if (creds.isEmpty) {
              return const _EmptyPanel(
                icon: Icons.description_outlined,
                title: 'لم يتم رفع وثائق',
                message: 'راجع المحفظ قبل الاعتماد إذا كانت الوثائق إلزامية.',
              );
            }

            return _InfoPanel(
              children: [
                ...creds.map(
                  (credential) => _CredentialRow(
                    userId: userId,
                    credential: credential,
                    allImages: images,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CredentialRow extends ConsumerWidget {
  const _CredentialRow({
    required this.userId,
    required this.credential,
    required this.allImages,
  });

  final String userId;
  final Map<String, dynamic> credential;
  final List<String> allImages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = _text(credential, const ['title', 'name'], 'وثيقة');
    final organization = _nullableText(
      credential,
      const ['organization', 'issuer', 'source'],
    );
    final credentialId = credential['id'] as String? ?? '';
    final status = _text(credential, const ['status'], 'pending');
    final notes = _nullableText(credential, const ['description', 'notes']);
    final images = _credentialImages(credential);

    return _RowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  organization == null ? title : '$title - $organization',
                  style: DSText.bodyMedium(context),
                ),
              ),
              DSBadge(
                label: _credentialStatusLabel(status),
                variant: _credentialStatusVariant(status),
                dot: true,
              ),
            ],
          ),
          if (notes != null) ...[
            const SizedBox(height: DSSpacing.xs),
            Text(notes, style: DSText.caption(context, color: DSColors.text2)),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: DSSpacing.sm),
            Wrap(
              spacing: DSSpacing.sm,
              runSpacing: DSSpacing.sm,
              children: [
                for (final url in images)
                  _Thumbnail(
                    url: url,
                    onTap: () => _openViewer(context, allImages, url),
                  ),
              ],
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: DSSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: DSSpacing.sm,
              runSpacing: DSSpacing.sm,
              children: [
                DSButton(
                  label: 'رفض الشهادة',
                  size: DSButtonSize.sm,
                  variant: DSButtonVariant.destructive,
                  leading: const Icon(Icons.close_rounded, size: 16),
                  onPressed: userId.isEmpty || credentialId.isEmpty
                      ? null
                      : () =>
                          _reject(context, ref, userId, credentialId, title),
                ),
                DSButton(
                  label: 'اعتماد الشهادة',
                  size: DSButtonSize.sm,
                  leading: const Icon(Icons.check_rounded, size: 16),
                  onPressed: userId.isEmpty || credentialId.isEmpty
                      ? null
                      : () =>
                          _approve(context, ref, userId, credentialId, title),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, List<String> images, String current) {
    if (images.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _ImageViewer(images: images, initial: current),
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String credentialId,
    String title,
  ) async {
    final ok = await DSDialog.confirm(
      context,
      title: 'اعتماد الشهادة',
      message:
          'اعتماد شهادة "$title"؟ ستظهر للطلاب في ملف المحفظ بعد الاعتماد.',
      confirmLabel: 'اعتماد',
    );
    if (!ok || !context.mounted) return;

    await _runAction(
      context,
      ref,
      () => ref
          .read(adminActionsProvider.notifier)
          .approveCredential(userId, credentialId),
      'تم اعتماد الشهادة',
    );
    ref.invalidate(pendingCredentialsProvider);
    ref.invalidate(teacherCredentialsProvider(userId));
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String credentialId,
    String title,
  ) async {
    final reason = await _showCredentialRejectDialog(context, title);
    if (reason == null || !context.mounted) return;

    await _runAction(
      context,
      ref,
      () => ref
          .read(adminActionsProvider.notifier)
          .rejectCredential(userId, credentialId, reason),
      'تم رفض الشهادة',
    );
    ref.invalidate(pendingCredentialsProvider);
    ref.invalidate(teacherCredentialsProvider(userId));
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.children});

  final List<Widget> children;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .expand((child) => [child, const SizedBox(height: DSSpacing.sm)])
            .toList()
          ..removeLast(),
      ),
    );
  }
}

class _RowPanel extends StatelessWidget {
  const _RowPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DSSpacing.md),
      decoration: BoxDecoration(
        color: DSColors.surface,
        borderRadius: DSRadius.mdAll,
        border: Border.all(color: DSColors.border),
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    this.value,
    this.child,
  });

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (value == null && child == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: DSSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final labelWidget = Text(
            label,
            style: DSText.caption(context, color: DSColors.text3),
          );
          final valueWidget = child ??
              Text(
                value!,
                style: DSText.body(context, color: DSColors.text1),
              );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: DSSpacing.xs),
                valueWidget,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 140, child: labelWidget),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.sm,
        vertical: DSSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DSColors.surfaceMuted,
        borderRadius: DSRadius.fullAll,
        border: Border.all(color: DSColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DSColors.primary),
          const SizedBox(width: DSSpacing.xs),
          Text(label, style: DSText.micro(context, color: DSColors.text2)),
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DSSpacing.lg),
      decoration: BoxDecoration(
        color: DSColors.surfaceMuted,
        borderRadius: DSRadius.mdAll,
        border: Border.all(color: DSColors.border),
      ),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: DSColors.primary,
            ),
          ),
          const SizedBox(width: DSSpacing.sm),
          Text(label, style: DSText.caption(context, color: DSColors.text3)),
        ],
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DSBanner(message: message, variant: DSBannerVariant.error);
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DSSpacing.lg),
      decoration: BoxDecoration(
        color: DSColors.warningBg.withValues(alpha: 0.45),
        borderRadius: DSRadius.mdAll,
        border: Border.all(color: DSColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: DSColors.warning, size: 22),
          const SizedBox(width: DSSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DSText.bodyMedium(context)),
                Text(message,
                    style: DSText.caption(context, color: DSColors.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: DSRadius.mdAll,
          child: Container(
            width: 88,
            height: 88,
            color: DSColors.surfaceMuted,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (ctx, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DSColors.primary,
                        ),
                      ),
                    ),
              errorBuilder: (ctx, _, __) => const Icon(
                Icons.broken_image_outlined,
                color: DSColors.text3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.images, required this.initial});

  final List<String> images;
  final String initial;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late int _index = _initialIndex();

  int _initialIndex() {
    final index = widget.images.indexOf(widget.initial);
    if (index < 0) return 0;
    if (index >= widget.images.length) return widget.images.length - 1;
    return index;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(DSSpacing.xxl),
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image.network(widget.images[_index], fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'فتح الملف الأصلي',
                  icon: const Icon(Icons.open_in_new_rounded,
                      color: Colors.white),
                  onPressed: () => openExternalUrl(widget.images[_index]),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (widget.images.length > 1) ...[
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () => setState(
                    () => _index = (_index + 1) % widget.images.length,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () => setState(
                    () => _index = (_index - 1 + widget.images.length) %
                        widget.images.length,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${_index + 1} / ${widget.images.length}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<String?> _showCredentialRejectDialog(
  BuildContext context,
  String title,
) async {
  final controller = TextEditingController();

  try {
    return await DSDialog.show<String>(
      context,
      title: 'رفض الشهادة',
      width: 520,
      child: StatefulBuilder(
        builder: (context, setState) {
          final reason = controller.text.trim();
          final canSubmit = reason.length >= 3;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سيتم إشعار المحفظ بسبب رفض شهادة "$title". اكتب سبباً واضحاً ليعرف ما المطلوب تعديله.',
                style: DSText.body(context, color: DSColors.text2),
              ),
              const SizedBox(height: DSSpacing.lg),
              DSTextField(
                controller: controller,
                label: 'سبب رفض الشهادة',
                hint: 'مثال: الصورة غير واضحة أو لا تثبت بيانات الشهادة',
                maxLines: 3,
                autofocus: true,
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
                    label: 'رفض الشهادة',
                    variant: DSButtonVariant.destructive,
                    onPressed: canSubmit
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
  } finally {
    controller.dispose();
  }
}

Future<String?> _showRejectDialog(BuildContext context, String name) async {
  final controller = TextEditingController();

  try {
    return await DSDialog.show<String>(
      context,
      title: 'رفض الطلب',
      width: 520,
      child: StatefulBuilder(
        builder: (context, setState) {
          final reason = controller.text.trim();
          final canSubmit = reason.length >= 3;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سيتم إشعار "$name" بسبب الرفض، لذلك السبب مطلوب وواضح.',
                style: DSText.body(context, color: DSColors.text2),
              ),
              const SizedBox(height: DSSpacing.lg),
              DSTextField(
                controller: controller,
                label: 'سبب الرفض',
                hint: 'مثال: الوثائق غير واضحة أو الخطة السعرية غير مكتملة',
                maxLines: 3,
                autofocus: true,
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
                    label: 'رفض',
                    variant: DSButtonVariant.destructive,
                    onPressed: canSubmit
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
  } finally {
    controller.dispose();
  }
}

Future<void> _runAction(
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

List<String> _stringList(dynamic raw) {
  if (raw is! Iterable) return const [];
  return raw
      .whereType<Object>()
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

List<String> _credentialImages(Map<String, dynamic> credential) {
  final urls = <String>{
    ..._stringList(credential['imageUrls']),
    ..._stringList(credential['fileUrls']),
    ..._stringList(credential['downloadUrls']),
    ..._stringList(credential['urls']),
  };
  for (final key in const [
    'imageUrl',
    'fileUrl',
    'documentUrl',
    'certificateUrl',
    'downloadUrl',
    'url'
  ]) {
    final value = credential[key];
    if (value is String && value.trim().isNotEmpty) urls.add(value.trim());
  }
  return urls.toList();
}

String? _locationLabel(Map<String, dynamic> teacher) {
  final locationText = _nullableText(
    teacher,
    const ['addressText', 'address', 'locationAddress', 'city', 'governorate'],
  );
  final coords = _coordinatesLabel(teacher);
  if (locationText != null && coords != null) return '$locationText - $coords';
  return locationText ?? coords;
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
      (data['lat'] as num?)?.toDouble();
  lng ??= (data['longitude'] as num?)?.toDouble() ??
      (data['lng'] as num?)?.toDouble();

  if (lat == null || lng == null) return null;
  return '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}';
}

double _price(Map<String, dynamic> plan) {
  for (final key in const ['priceEGP', 'priceEgp', 'price', 'amount']) {
    final value = plan[key];
    if (value is num) return value.toDouble();
  }
  return 0;
}

String _money(double value) {
  return '${NumberFormat.decimalPattern('ar').format(value.round())} ج.م';
}

String? _examScoreLabel(Map<String, dynamic> teacher) {
  final score = (teacher['examScore'] as num?)?.toDouble();
  if (score == null) return null;
  final formatted =
      score % 1 == 0 ? score.toStringAsFixed(0) : score.toStringAsFixed(1);
  return '$formatted%';
}

String? _examStatusLabel(Map<String, dynamic> teacher) {
  final passed = teacher['examPassed'];
  final score = teacher['examScore'];
  if (passed is! bool && score == null) return null;
  if (passed == true) return 'ناجح';
  return 'لم يجتز';
}

String? _examAnswersLabel(Map<String, dynamic> teacher) {
  final correct = (teacher['examCorrectCount'] as num?)?.toInt();
  final total = (teacher['examQuestionCount'] as num?)?.toInt();
  if (correct == null || total == null || total <= 0) return null;
  return '$correct / $total';
}

List<Map<String, dynamic>> _activePricingPlans(
  List<Map<String, dynamic>> plans,
) {
  return plans.where((plan) => plan['isActive'] != false).toList();
}

String _planType(Map<String, dynamic> plan) {
  return switch (_text(plan, const ['type'], 'single')) {
    'bundle' => 'باقة',
    _ => 'جلسة واحدة',
  };
}

String _planMode(Map<String, dynamic> plan) {
  return switch (_text(plan, const ['mode'], 'غير محدد')) {
    'online' => 'أونلاين',
    'home' => 'منزل',
    'mosque' => 'مسجد',
    _ => 'غير محدد',
  };
}

bool _hasActiveSlots(Map<String, dynamic> day) {
  return _enabledSlots(day).isNotEmpty ||
      day['isActive'] == true ||
      (_nullableText(day, const ['startTime']) != null &&
          _nullableText(day, const ['endTime']) != null);
}

int _activeAvailabilityDays(List<Map<String, dynamic>> items) {
  return items.where(_hasActiveSlots).length;
}

List<Map<String, dynamic>> _enabledAvailabilitySlots(
  List<Map<String, dynamic>> items,
) {
  return items.expand(_enabledSlots).toList();
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

String _sessionTypeLabel(String type) {
  return switch (type) {
    'online' => 'أونلاين',
    'home' => 'منزل',
    'mosque' => 'مسجد',
    _ => type,
  };
}

String _slotLabel(Map<String, dynamic> slot) {
  final start = _nullableText(slot, const ['startTime', 'start']);
  final end = _nullableText(slot, const ['endTime', 'end']);
  if (start != null && end != null) return '$start - $end';
  return start ?? end ?? 'موعد';
}

String _credentialStatusLabel(String status) {
  return switch (status) {
    'approved' => 'معتمدة',
    'rejected' => 'مرفوضة',
    'pending' => 'قيد المراجعة',
    _ => status,
  };
}

DSBadgeVariant _credentialStatusVariant(String status) {
  return switch (status) {
    'approved' => DSBadgeVariant.success,
    'rejected' => DSBadgeVariant.error,
    'pending' => DSBadgeVariant.warning,
    _ => DSBadgeVariant.neutral,
  };
}

String _date(dynamic v) {
  if (v == null) return '—';
  try {
    final dt = v is DateTime ? v : (v as dynamic).toDate() as DateTime;
    return DateFormat('dd/MM/yyyy', 'ar').format(dt);
  } catch (_) {
    return '—';
  }
}
