// lib/screens/teacher_rejected_screen.dart
//
// Shown when admin rejects a teacher's registration request.
// The user's status == 'rejected'.
// Options: contact support or logout.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


// Reads rejection note directly from Firestore (not in UserModel)
final _rejectionNoteProvider = StreamProvider.autoDispose<String?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data()?['rejectionNote'] as String?);
});

class TeacherRejectedScreen extends ConsumerWidget {
  const TeacherRejectedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rejectionNote = ref.watch(_rejectionNoteProvider).valueOrNull;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppThemeConstants.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F7F6),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 40),
                child: Column(
                  children: [
                    // ── Illustration ──────────────────────────────
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppThemeConstants.errorLight,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppThemeConstants.error.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.cancel_rounded,
                          size: 60, color: AppThemeConstants.accentRed),
                    ),
                    const SizedBox(height: 32),

                    // ── Title ─────────────────────────────────────
                    const Text(
                      'لم يتم قبول طلبك',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'نأسف، لم يتم قبول طلب انضمامك كمحفظ في الوقت الحالي.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF4B5563),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Rejection note (if any) ───────────────────
                    if (rejectionNote != null &&
                        rejectionNote.trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppThemeConstants.errorLight,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(12)),
                          border: Border.all(
                              color: AppThemeConstants.error.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 18,
                                    color: AppThemeConstants.error),
                                SizedBox(width: 8),
                                Text(
                                  'سبب الرفض:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppThemeConstants.error,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              rejectionNote,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppThemeConstants.errorDark,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── What to do ────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppThemeConstants.white,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(16)),
                        border: Border.all(
                            color: const Color(0xFFE5EDE9)),
                        boxShadow: [
                          BoxShadow(
                            color: AppThemeConstants.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ماذا يمكنك فعله؟',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827))),
                          SizedBox(height: 12),
                          _BulletRow(
                            icon: Icons.support_agent_rounded,
                            text:
                                'تواصل مع فريق الدعم للاستفسار عن أسباب الرفض.',
                          ),
                          SizedBox(height: 8),
                          _BulletRow(
                            icon: Icons.description_rounded,
                            text:
                                'تأكد من صحة الشهادات والبيانات المقدمة.',
                          ),
                          SizedBox(height: 8),
                          _BulletRow(
                            icon: Icons.refresh_rounded,
                            text:
                                'يمكنك إعادة التسجيل بعد مراجعة متطلبات الانضمام.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Logout button ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => ref
                            .read(authNotifierProvider.notifier)
                            .logout(),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('تسجيل الخروج',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C6F6A),
                          foregroundColor: AppThemeConstants.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(14)),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BulletRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1A9E84)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  height: 1.5)),
        ),
      ],
    );
  }
}
