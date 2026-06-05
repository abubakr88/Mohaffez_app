import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

/// Admin profile page for a single user. For a mohaffez it shows full teaching
/// statistics (sessions, students, revenue, rating), submitted credentials, and
/// a recent-sessions table. Reached from the users table by clicking a teacher.
class AdminUserDetailPage extends ConsumerWidget {
  const AdminUserDetailPage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(adminUserProvider(userId));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DSButton(
            label: 'عودة إلى المستخدمين',
            variant: DSButtonVariant.ghost,
            size: DSButtonSize.sm,
            onPressed: () => context.go('/admin/users'),
          ),
          const SizedBox(height: DSSpacing.md),
          userAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (user) {
              if (user == null) {
                return const DSEmptyState(
                  title: 'المستخدم غير موجود',
                  subtitle: 'ربما تم حذف هذا الحساب',
                  icon: Icons.person_off_outlined,
                );
              }
              return _Profile(userId: userId, user: user);
            },
          ),
        ],
      ),
    );
  }
}

class _Profile extends ConsumerWidget {
  const _Profile({required this.userId, required this.user});
  final String userId;
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user['name'] as String? ?? '—';
    final role = user['role'] as String? ?? 'student';
    final status = user['status'] as String? ?? 'active';
    final photo = user['photoUrl'] as String?;
    final spec = user['specialization'] as String? ?? '';
    final bio = user['bio'] as String? ?? '';
    final isTeacher = role == 'mohaffez';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Profile header ───────────────────────────────────────────────
        DSCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DSAvatar(name: name, imageUrl: photo, size: 64),
              const SizedBox(width: DSSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: DSText.h2(context)),
                    const SizedBox(height: DSSpacing.sm),
                    Wrap(
                      spacing: DSSpacing.sm,
                      runSpacing: DSSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DSBadge(
                          label: _roleLabel(role),
                          variant: role == 'mohaffez'
                              ? DSBadgeVariant.primary
                              : role == 'admin'
                                  ? DSBadgeVariant.warning
                                  : DSBadgeVariant.neutral,
                        ),
                        DSBadge(
                          label: _statusLabel(status),
                          variant: _statusVariant(status),
                          dot: true,
                        ),
                        Text('انضم في ${_date(user['createdAt'])}',
                            style:
                                DSText.caption(context, color: DSColors.text3)),
                      ],
                    ),
                    if (spec.isNotEmpty) ...[
                      const SizedBox(height: DSSpacing.md),
                      _Field(label: 'التخصص', value: spec),
                    ],
                    if (bio.isNotEmpty) _Field(label: 'نبذة', value: bio),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (!isTeacher) ...[
          const SizedBox(height: DSSpacing.lg),
          const DSBanner(
            message: 'الإحصائيات التفصيلية متاحة لحسابات المحفظين فقط.',
            variant: DSBannerVariant.info,
          ),
        ] else ...[
          const SizedBox(height: DSSpacing.xl),
          _StatsSection(userId: userId),
          const SizedBox(height: DSSpacing.xl),
          Row(
            children: [
              Expanded(child: Text('المحفظة', style: DSText.h3(context))),
              _CreditWalletButton(userId: userId, name: name),
            ],
          ),
          const SizedBox(height: DSSpacing.md),
          _WalletSection(userId: userId),
          const SizedBox(height: DSSpacing.xl),
          Text('الشهادات والوثائق', style: DSText.h3(context)),
          const SizedBox(height: DSSpacing.md),
          _CredentialsSection(userId: userId),
          const SizedBox(height: DSSpacing.xl),
          Text('أحدث الجلسات', style: DSText.h3(context)),
          const SizedBox(height: DSSpacing.md),
          _RecentSessionsSection(userId: userId),
        ],
      ],
    );
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherStatsProvider(userId));
    return async.when(
      loading: () => const DSSkeletonCard(),
      error: (e, _) =>
          DSBanner(message: '$e', variant: DSBannerVariant.error),
      data: (s) {
        final cards = <Widget>[
          _stat('إجمالي الجلسات', '${s.total}', Icons.event_note_outlined,
              DSColors.primary),
          _stat('مكتملة', '${s.completed}', Icons.check_circle_outline,
              DSColors.success),
          _stat('قادمة', '${s.upcoming}', Icons.schedule_rounded,
              DSColors.info),
          _stat('ملغاة', '${s.cancelled}', Icons.cancel_outlined,
              DSColors.error),
          _stat('عدد الطلاب', '${s.studentCount}', Icons.people_outline_rounded,
              DSColors.primary),
          _stat('قيمة الجلسات المكتملة', _money(s.revenue),
              Icons.payments_outlined, DSColors.secondary),
          _stat(
              'التقييم',
              s.avgRating == null
                  ? '—'
                  : '${s.avgRating!.toStringAsFixed(1)} (${s.ratingCount})',
              Icons.star_outline_rounded,
              DSColors.secondary),
        ];
        return Wrap(
          spacing: DSSpacing.md,
          runSpacing: DSSpacing.md,
          children: cards
              .map((c) => SizedBox(width: 220, child: c))
              .toList(),
        );
      },
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) =>
      DSStatCard(label: label, value: value, icon: icon, iconColor: color);
}

class _CredentialsSection extends ConsumerWidget {
  const _CredentialsSection({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherCredentialsProvider(userId));
    return async.when(
      loading: () => Text('جارٍ تحميل الوثائق…',
          style: DSText.caption(context, color: DSColors.text3)),
      error: (e, _) => Text('تعذّر تحميل الوثائق',
          style: DSText.caption(context, color: DSColors.text3)),
      data: (creds) {
        if (creds.isEmpty) {
          return Text('لم يرفع المحفظ أي وثائق',
              style: DSText.caption(context, color: DSColors.text3));
        }
        return DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < creds.length; i++) ...[
                if (i > 0) const Divider(height: DSSpacing.lg),
                _credentialRow(context, creds[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _credentialRow(BuildContext context, Map<String, dynamic> c) {
    final title = c['title'] as String? ?? '—';
    final org = c['organization'] as String? ?? '';
    final cStatus = c['status'] as String? ?? 'pending';
    final imgs = (c['imageUrls'] as List?)?.cast<String>() ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(org.isEmpty ? title : '$title — $org',
                  style: DSText.body(context)),
            ),
            DSBadge(
              label: _credStatusLabel(cStatus),
              variant: cStatus == 'approved'
                  ? DSBadgeVariant.success
                  : cStatus == 'rejected'
                      ? DSBadgeVariant.error
                      : DSBadgeVariant.warning,
            ),
          ],
        ),
        if (imgs.isNotEmpty) ...[
          const SizedBox(height: DSSpacing.sm),
          Wrap(
            spacing: DSSpacing.sm,
            runSpacing: DSSpacing.sm,
            children: imgs
                .map((url) => _Thumb(
                      url: url,
                      onTap: () => showDialog<void>(
                        context: context,
                        barrierColor: Colors.black.withValues(alpha: 0.85),
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(DSSpacing.xxl),
                          child: Stack(
                            children: [
                              Center(
                                child: InteractiveViewer(
                                  maxScale: 4,
                                  child:
                                      Image.network(url, fit: BoxFit.contain),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      color: Colors.white),
                                  onPressed: () => Navigator.of(context,
                                          rootNavigator: true)
                                      .pop(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _RecentSessionsSection extends ConsumerWidget {
  const _RecentSessionsSection({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherStatsProvider(userId));
    return async.when(
      loading: () => const DSSkeletonCard(),
      error: (e, _) =>
          DSBanner(message: '$e', variant: DSBannerVariant.error),
      data: (s) {
        if (s.recentSessions.isEmpty) {
          return Text('لا توجد جلسات بعد',
              style: DSText.caption(context, color: DSColors.text3));
        }
        return DSDataTable<Map<String, dynamic>>(
          initialSortKey: 'date',
          columns: [
            DSColumnDef(
              key: 'date',
              label: 'التاريخ',
              width: 140,
              sortable: true,
              sortValue: (r) =>
                  _toDate(r['sessionDate'] ?? r['slotStart'])
                      ?.millisecondsSinceEpoch ??
                  0,
              cellBuilder: (ctx, r) => Text(
                  _date(r['sessionDate'] ?? r['slotStart']),
                  style: DSText.body(ctx, color: DSColors.text2)),
            ),
            DSColumnDef(
              key: 'student',
              label: 'الطالب',
              cellBuilder: (ctx, r) => Text(
                  r['studentName'] as String? ?? '—',
                  style: DSText.body(ctx)),
            ),
            DSColumnDef(
              key: 'status',
              label: 'الحالة',
              width: 130,
              cellBuilder: (ctx, r) {
                final st = (r['status'] as String? ?? '').toLowerCase();
                return DSBadge(
                  label: _sessionStatusLabel(st),
                  variant: _sessionStatusVariant(st),
                );
              },
            ),
            DSColumnDef(
              key: 'price',
              label: 'السعر',
              width: 110,
              cellBuilder: (ctx, r) => Text(
                  _money((r['sessionPrice'] as num?)?.toDouble() ?? 0),
                  style: DSText.body(ctx, color: DSColors.text2)),
            ),
          ],
          rows: s.recentSessions,
        );
      },
    );
  }
}

class _WalletSection extends ConsumerWidget {
  const _WalletSection({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider(
        (userId: userId, ownerType: WalletOwnerType.mohaffez)));
    final txAsync = ref.watch(walletTransactionsProvider(userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        walletAsync.when(
          loading: () => const DSSkeletonCard(),
          error: (e, _) =>
              DSBanner(message: '$e', variant: DSBannerVariant.error),
          data: (w) => Wrap(
            spacing: DSSpacing.md,
            runSpacing: DSSpacing.md,
            children: [
              SizedBox(
                  width: 220,
                  child: DSStatCard(
                      label: 'الرصيد المتاح',
                      value: _money(w.balanceEgp),
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: DSColors.primary)),
              SizedBox(
                  width: 220,
                  child: DSStatCard(
                      label: 'رصيد معلّق',
                      value: _money(w.pendingCycleEgp),
                      icon: Icons.schedule_rounded,
                      iconColor: DSColors.info)),
              SizedBox(
                  width: 220,
                  child: DSStatCard(
                      label: 'عمولة مستحقة',
                      value: _money(w.directCommissionOwedEgp),
                      icon: Icons.trending_down_rounded,
                      iconColor: DSColors.error)),
            ],
          ),
        ),
        const SizedBox(height: DSSpacing.lg),
        txAsync.when(
          loading: () => const DSSkeletonCard(),
          error: (e, _) =>
              DSBanner(message: '$e', variant: DSBannerVariant.error),
          data: (txs) {
            if (txs.isEmpty) {
              return Text('لا توجد حركات على المحفظة',
                  style: DSText.caption(context, color: DSColors.text3));
            }
            return DSDataTable<WalletTransactionModel>(
              columns: [
                DSColumnDef(
                  key: 'date',
                  label: 'التاريخ',
                  width: 140,
                  cellBuilder: (ctx, t) => Text(_date(t.createdAt),
                      style: DSText.body(ctx, color: DSColors.text2)),
                ),
                DSColumnDef(
                  key: 'reason',
                  label: 'البيان',
                  cellBuilder: (ctx, t) =>
                      Text(t.reason, style: DSText.body(ctx)),
                ),
                DSColumnDef(
                  key: 'amount',
                  label: 'المبلغ',
                  width: 120,
                  cellBuilder: (ctx, t) {
                    final positive = t.amountPiastres >= 0;
                    return Text(
                      '${positive ? '+' : '−'}${_money(t.absAmountEgp)}',
                      style: DSText.bodyMedium(ctx,
                          color: positive ? DSColors.success : DSColors.error),
                    );
                  },
                ),
              ],
              rows: txs,
            );
          },
        ),
      ],
    );
  }
}

class _CreditWalletButton extends ConsumerWidget {
  const _CreditWalletButton({required this.userId, required this.name});
  final String userId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DSButton(
      label: 'شحن يدوي',
      size: DSButtonSize.sm,
      variant: DSButtonVariant.ghost,
      onPressed: () => _credit(context, ref),
    );
  }

  Future<void> _credit(BuildContext context, WidgetRef ref) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final ok = await DSDialog.show<bool>(
      context,
      title: 'شحن يدوي للمحفظة',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('إضافة رصيد إلى محفظة "$name".',
              style: DSText.body(context, color: DSColors.text2)),
          const SizedBox(height: DSSpacing.md),
          DSTextField(
            controller: amountCtrl,
            label: 'المبلغ (ج.م)',
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          const SizedBox(height: DSSpacing.sm),
          DSTextField(
            controller: reasonCtrl,
            label: 'السبب',
            hint: 'مثال: تعويض، تصحيح رصيد',
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        DSButton(
            label: 'إلغاء',
            variant: DSButtonVariant.ghost,
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false)),
        DSButton(
            label: 'شحن',
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(true)),
      ],
    );
    if (ok != true || !context.mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    final reason = reasonCtrl.text.trim();
    if (amount <= 0 || reason.length < 3) {
      DSToast.show(context, 'أدخل مبلغًا صحيحًا وسببًا واضحًا',
          type: DSToastType.error);
      return;
    }
    await ref.read(adminActionsProvider.notifier).creditWallet(
          userId: userId,
          ownerType: 'mohaffez',
          amountEgp: amount,
          reason: reason,
        );
    if (!context.mounted) return;
    ref.read(adminActionsProvider).when(
          data: (_) =>
              DSToast.show(context, 'تم شحن المحفظة', type: DSToastType.success),
          loading: () {},
          error: (e, _) =>
              DSToast.show(context, 'فشل العملية: $e', type: DSToastType.error),
        );
  }
}

// ── Small helpers ──────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DSSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: DSText.caption(context, color: DSColors.text3)),
          ),
          Expanded(child: Text(value, style: DSText.body(context))),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.onTap});
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
            width: 72,
            height: 72,
            color: DSColors.surfaceMuted,
            child: Image.network(url, fit: BoxFit.cover,
                errorBuilder: (ctx, _, __) => const Icon(
                    Icons.broken_image_outlined,
                    color: DSColors.text3)),
          ),
        ),
      ),
    );
  }
}

String _roleLabel(String role) => switch (role) {
      'mohaffez' => 'محفظ',
      'admin' => 'مدير',
      _ => 'طالب',
    };

String _statusLabel(String status) => switch (status) {
      'active' => 'نشط',
      'pending_approval' => 'بانتظار المراجعة',
      'rejected' => 'مرفوض',
      'suspended' => 'معلّق',
      _ => 'معلّق',
    };

DSBadgeVariant _statusVariant(String status) => switch (status) {
      'active' => DSBadgeVariant.success,
      'pending_approval' => DSBadgeVariant.info,
      'rejected' => DSBadgeVariant.error,
      'suspended' => DSBadgeVariant.warning,
      _ => DSBadgeVariant.warning,
    };

String _credStatusLabel(String s) => switch (s) {
      'approved' => 'معتمدة',
      'rejected' => 'مرفوضة',
      _ => 'قيد المراجعة',
    };

String _sessionStatusLabel(String s) {
  if (s == 'completed') return 'مكتملة';
  if (s == 'accepted') return 'مقبولة';
  if (s == 'pending') return 'قيد الانتظار';
  if (s.contains('awaitingpayment') || s.contains('awaiting')) {
    return 'بانتظار الدفع';
  }
  if (s.contains('cancel')) return 'ملغاة';
  if (s.contains('no_show') || s.contains('noshow')) return 'لم يحضر';
  return s.isEmpty ? '—' : s;
}

DSBadgeVariant _sessionStatusVariant(String s) {
  if (s == 'completed') return DSBadgeVariant.success;
  if (s == 'accepted' || s == 'pending') return DSBadgeVariant.info;
  if (s.contains('cancel') || s.contains('no')) return DSBadgeVariant.error;
  return DSBadgeVariant.neutral;
}

String _money(double v) => '${NumberFormat('#,##0', 'en').format(v)} ج.م';

String _date(dynamic v) {
  final dt = _toDate(v);
  return dt == null ? '—' : DateFormat('dd/MM/yyyy', 'ar').format(dt);
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  try {
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}
