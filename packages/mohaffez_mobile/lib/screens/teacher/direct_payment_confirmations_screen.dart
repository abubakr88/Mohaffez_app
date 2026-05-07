// lib/screens/direct_payment_confirmations_screen.dart
// CHANGES vs original:
// • _confirm(): replaced `rethrow` in `on FirebaseFunctionsException` with
//   inline error handling + snackbar. In Dart, rethrow inside a catch block
//   exits the ENTIRE try-catch chain — the sibling `on Exception` handler
//   below it can never catch a re-thrown FirebaseFunctionsException.
//   This was the direct cause of the INTERNAL crash shown in the debugger.
// • Added mounted check inside the FirebaseFunctionsException handler
//   (was missing — only the already-exists branch had it).
// • FIX: Added bare `catch (e, stack)` tier after `on Exception` to catch
//   Dart Errors (TypeError, StateError, etc.) that are NOT Exceptions.
//   Without this, a TypeError thrown by `result.data as Map` in
//   mohaffezConfirm() bypassed ALL catch blocks, hit only `finally`,
//   silently reset _loading → button re-enabled with zero feedback,
//   causing the repeated-tap bug seen in logs.
// • All other logic, UI, reject flow, commission hint, bundle badge: UNCHANGED.

import 'dart:ui' as ui;
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/utils/time_formatter.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DirectPaymentConfirmationsScreen extends ConsumerWidget {
  final String? directPaymentRequestId;

  const DirectPaymentConfirmationsScreen({
    super.key,
    this.directPaymentRequestId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mohaffezId = FirebaseAuth.instance.currentUser!.uid;
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: const Text('تأكيد المدفوعات المباشرة'),
          backgroundColor: AppThemeConstants.primary,
          foregroundColor: AppThemeConstants.onPrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث (بيانات مباشرة)',
              onPressed: () {},
            ),
          ],
        ),
        body: _buildBody(mohaffezId, ref),
      ),
    );
  }

  // ── Build body ─────────────────────────────────────────────────────────────
  Widget _buildBody(String mohaffezId, WidgetRef ref) {
    if (directPaymentRequestId != null && directPaymentRequestId!.isNotEmpty) {
      return StreamBuilder<DirectPaymentModel?>(
        stream:
            DirectPaymentService.watchDirectPayment(directPaymentRequestId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppThemeConstants.error),
                  const SizedBox(height: 12),
                  Text(
                    'خطأ في التحميل: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppThemeConstants.error),
                  ),
                ],
              ),
            );
          }
          final payment = snapshot.data;
          if (payment == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: AppThemeConstants.success),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد مدفوعات بانتظار التأكيد',
                    style: TextStyle(
                        fontSize: 16, color: AppThemeConstants.textSecondary),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: 1,
            itemBuilder: (_, i) => _PaymentConfirmationCard(
              payment: payment,
              commissionRate: _getCommissionRate(ref),
            ),
          );
        },
      );
    }

    return StreamBuilder<List<DirectPaymentModel>>(
      stream: DirectPaymentService.watchPendingConfirmations(mohaffezId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppThemeConstants.error),
                const SizedBox(height: 12),
                Text(
                  'خطأ في التحميل: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppThemeConstants.error),
                ),
              ],
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: AppThemeConstants.success),
                SizedBox(height: 16),
                Text(
                  'لا توجد مدفوعات بانتظار التأكيد',
                  style: TextStyle(
                      fontSize: 16, color: AppThemeConstants.textSecondary),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (_, i) => _PaymentConfirmationCard(
            payment: items[i],
            commissionRate: _getCommissionRate(ref),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Get dynamic commission rate from system config, defaulting to 5%
double _getCommissionRate(WidgetRef ref) {
  final configAsync = ref.watch(systemConfigProvider);
  return configAsync.when(
    data: (config) => config.commissionRate,
    loading: () => 0.05,
    error: (_, __) => 0.05,
  );
}

class _PaymentConfirmationCard extends StatefulWidget {
  final DirectPaymentModel payment;
  final double commissionRate;
  const _PaymentConfirmationCard({
    required this.payment,
    required this.commissionRate,
  });

  @override
  State<_PaymentConfirmationCard> createState() =>
      _PaymentConfirmationCardState();
}

class _PaymentConfirmationCardState extends State<_PaymentConfirmationCard> {
  bool _loading = false;
  bool _confirmed = false;

  // ── Confirm ────────────────────────────────────────────────────────────────
  Future<void> _confirm() async {
    final planType = widget.payment.planType ?? 'single';
    final isBundleOrSubscription =
        planType == 'bundle' || planType == 'subscription';

    final String confirmMessage;
    if (isBundleOrSubscription) {
      confirmMessage =
          'هل تأكد استلام مبلغ ${widget.payment.amount.toStringAsFixed(0)} جنيه'
          ' من ${widget.payment.studentName}'
          ' مقابل ${planType == 'bundle' ? "حزمة ${widget.payment.sessionsCount ?? 1} جلسات" : "اشتراك شهري"}؟';
    } else {
      confirmMessage =
          'هل تأكد استلام مبلغ ${widget.payment.amount.toStringAsFixed(0)} جنيه'
          ' من ${widget.payment.studentName}؟';
    }

    // Capture BEFORE any async gap — safe even if widget is disposed later.
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد استلام الدفع'),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => context.pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeConstants.secondary,
            ),
            child: const Text('نعم'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    debugPrint('🔵 [BUNDLE_FLOW] Step5_MohaffezConfirm_TAPPED: '
        'paymentId=${widget.payment.id}, '
        'studentName=${widget.payment.studentName}, '
        'amount=${widget.payment.amount}, '
        'planType=${widget.payment.planType}, '
        'sessionsCount=${widget.payment.sessionsCount}');

    debugPrint('🔵 [BUNDLE_FLOW] Step5_PostDialog mounted=$mounted');
    if (mounted) setState(() => _loading = true);

    try {
      debugPrint('🔵 [BUNDLE_FLOW] Step5_CALLING_CF '
          'isBundleOrSubscription=$isBundleOrSubscription');
      if (isBundleOrSubscription) {
        await DirectPaymentService.mohaffezConfirmBundlePayment(
          paymentId: widget.payment.id,
        );
        debugPrint('✅ [BUNDLE_FLOW] Step5_BundleConfirm_SUCCESS: '
            'paymentId=${widget.payment.id}, '
            'sessionsCount=${widget.payment.sessionsCount}');
        if (mounted) setState(() => _confirmed = true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'تم شراء الباقة وإرسال طلب الجلسة الأولى بنجاح ✓',
            ),
            duration: Duration(seconds: 4),
            backgroundColor: AppThemeConstants.success,
          ),
        );
        // Defer navigation to avoid Navigator lock during dialog dismissal
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/pending-requests');
        });
      } else {
        await DirectPaymentService.mohaffezConfirm(widget.payment.id);
        debugPrint('✅ [BUNDLE_FLOW] Step5_SingleConfirm_SUCCESS: '
            'paymentId=${widget.payment.id}');
        if (mounted) setState(() => _confirmed = true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✅ تم قبول الجلسة وإشعار الطالب!'),
            backgroundColor: AppThemeConstants.success,
          ),
        );
        // Defer navigation to avoid Navigator lock during dialog dismissal
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/pending-requests');
        });
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [BUNDLE_FLOW] Step5_Confirm_FIREBASE_ERROR: '
          'paymentId=${widget.payment.id}, '
          'code=${e.code}, message=${e.message}');

      // Handle already-confirmed case (idempotency)
      if (e.code == 'already-exists') {
        if (mounted) setState(() => _confirmed = true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد هذه الدفعية من قبل'),
            backgroundColor: AppThemeConstants.warning,
          ),
        );
        return;
      }

      final msg = switch (e.code) {
        'resource-exhausted' => e.message != null && e.message!.isNotEmpty
            ? e.message!
            : 'لديك باقة نشطة بالفعل لهذا النوع من الجلسات',
        'permission-denied' => 'ليس لديك صلاحية تأكيد هذه المدفوعة',
        'not-found' => 'لم يتم العثور على طلب الدفع',
        _ => e.message ?? 'حدث خطأ أثناء التأكيد',
      };
      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } on Exception catch (e) {
      debugPrint('❌ [BUNDLE_FLOW] Step5_Confirm_ERROR: '
          'paymentId=${widget.payment.id}, error=$e');
      messenger.showSnackBar(
        SnackBar(
            content: Text('خطأ: $e'), backgroundColor: AppThemeConstants.error),
      );
    } catch (e, stack) {
      // FIX: Catches Dart Errors (TypeError, StateError, AssertionError, …)
      // that extend Error — NOT Exception — so they are invisible to every
      // `on XxxException` and `on Exception` handler above.
      //
      // Concrete trigger: DirectPaymentService.mohaffezConfirm() contains
      //   `result.data as Map`
      // If the CF returns null, a bool, or any non-Map value that cast throws
      // a TypeError.  Without this block the TypeError skips both catch tiers,
      // goes straight to `finally`, resets _loading = false in milliseconds,
      // the button re-enables with zero feedback — exactly the repeated-tap
      // symptom visible in the logs.
      debugPrint('❌ [BUNDLE_FLOW] Step5_Confirm_UNHANDLED_ERROR: '
          'paymentId=${widget.payment.id}, error=$e');
      debugPrintStack(stackTrace: stack);
      messenger.showSnackBar(
        SnackBar(
          content: Text('خطأ غير متوقع — يرجى المحاولة مجدداً: $e'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Reject ─────────────────────────────────────────────────────────────────
  Future<void> _reject() async {
    // Capture BEFORE showDialog — showDialog is also async.
    final messenger = ScaffoldMessenger.of(context);

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            title: const Text('سبب الرفض'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'مثال: لم يصلني أي تحويل',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => context.pop(ctrl.text.trim()),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.error),
                child: const Text(
                  'رفض',
                  style: TextStyle(color: AppThemeConstants.onPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (reason == null) return;
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      await DirectPaymentService.mohaffezReject(
          widget.payment.id, reason.isEmpty ? null : reason);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم إرسال إشعار الرفض للطالب'),
          backgroundColor: AppThemeConstants.warning,
        ),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('خطأ: $e'), backgroundColor: AppThemeConstants.error));
    } catch (e, stack) {
      // Same safety net for the reject path.
      debugPrint('❌ [BUNDLE_FLOW] Reject_UNHANDLED_ERROR: '
          'paymentId=${widget.payment.id}, error=$e');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('خطأ غير متوقع: $e'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_confirmed) return const SizedBox.shrink();
    final p = widget.payment;
    final method = DirectPaymentMethod.fromValue(p.paymentMethod);
    final dateStr = p.studentConfirmedAt != null
        ? formatDateTimeToArabicAmPm(
            p.studentConfirmedAt!,
            datePattern: 'dd/MM',
            separator: ' ',
          )
        : '–';
    final sessionDateStr = p.sessionDate != null
        ? DateFormat('EEEE d MMMM', 'ar').format(p.sessionDate!)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(children: [
              CircleAvatar(
                backgroundColor:
                    AppThemeConstants.secondary.withValues(alpha: 0.15),
                child: Text(
                  p.studentName.isNotEmpty ? p.studentName[0] : '؟',
                  style: const TextStyle(
                      color: AppThemeConstants.success,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.studentName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('أرسل إشعار الدفع: $dateStr',
                        style: const TextStyle(
                            color: AppThemeConstants.textSecondary,
                            fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppThemeConstants.secondary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${p.amount.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                      color: AppThemeConstants.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ]),

            // ── Bundle badge ──────────────────────────────────────────
            if (p.planType != null &&
                (p.planType == 'bundle' || p.planType == 'subscription')) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppThemeConstants.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppThemeConstants.primary),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.collections_bookmark_outlined,
                      size: 14, color: AppThemeConstants.primary),
                  const SizedBox(width: 4),
                  Text(
                    p.planType == 'bundle'
                        ? 'حزمة ${p.sessionsCount ?? ''} جلسات'
                        : 'اشتراك شهري',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.primaryVariant,
                    ),
                  ),
                ]),
              ),
            ],

            const Divider(height: 20),

            // ── Info rows ─────────────────────────────────────────────
            _row(Icons.payment, 'طريقة الدفع', method.label),
            _row(Icons.schedule, 'الموعد',
                formatTimeToArabicAmPm(p.preferredTimeSlot)),
            if (sessionDateStr != null)
              _row(Icons.calendar_today, 'تاريخ الجلسة', sessionDateStr),
            if (p.studentNote != null && p.studentNote!.isNotEmpty)
              _row(Icons.note_outlined, 'ملاحظة الطالب', p.studentNote!),

            // ── Commission hint ────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppThemeConstants.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppThemeConstants.primary.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: AppThemeConstants.primary, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'عمولة التطبيق (${(widget.commissionRate * 100).toInt()}%): '
                    '${p.commissionAmount.toStringAsFixed(2)} ج.م  —  '
                    'يصلك صافي: '
                    '${(p.amount - p.commissionAmount).toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                        fontSize: 12, color: AppThemeConstants.primary),
                  ),
                ),
              ]),
            ),

            // ── Action buttons ────────────────────────────────────────
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check,
                        color: AppThemeConstants.onPrimary),
                    label: const Text(
                      'استلمت الدفع',
                      style: TextStyle(
                          color: AppThemeConstants.white,
                          fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _reject,
                  icon: const Icon(Icons.close, color: AppThemeConstants.error),
                  label: const Text('لم أستلم',
                      style: TextStyle(color: AppThemeConstants.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppThemeConstants.error),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: AppThemeConstants.textSecondary),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(
                  color: AppThemeConstants.textSecondary, fontSize: 13)),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
      );
}
