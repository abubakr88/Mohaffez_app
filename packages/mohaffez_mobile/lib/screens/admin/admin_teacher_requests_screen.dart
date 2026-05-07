// lib/screens/admin_teacher_requests_screen.dart
//
// Admin screen: lists all teachers with status == 'pending_approval'.
// Admin can expand each card to review profile data + certificates,
// then approve (→ status: 'active') or reject (→ status: 'rejected' + note).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/notification_service.dart';
import '../../shared/utils/time_formatter.dart';
import '../../shared/widgets/admin_app_bar.dart';

// ─── Provider ────────────────────────────────────────────────────────────────
final pendingTeacherRequestsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'mohaffez')
      .where('status', isEqualTo: 'pending_approval')
      .orderBy('approvalSubmittedAt', descending: false)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList());
});

// ─── Screen ──────────────────────────────────────────────────────────────────
class AdminTeacherRequestsScreen extends ConsumerWidget {
  const AdminTeacherRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingTeacherRequestsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        appBar: const AdminAppBar(title: 'طلبات الانضمام — المحافظون'),
        body: requestsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ في التحميل: $e')),
          data: (requests) {
            if (requests.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 64, color: Color(0xFF1A9E84)),
                    SizedBox(height: 16),
                    Text('لا توجد طلبات معلقة',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563))),
                    SizedBox(height: 8),
                    Text('جميع طلبات الانضمام تمت مراجعتها.',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _RequestCard(data: requests[i]),
            );
          },
        ),
      ),
    );
  }
}

// ─── Request card ─────────────────────────────────────────────────────────────
class _RequestCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _RequestCard({required this.data});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _expanded = false;
  bool _loading = false;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String get _uid => widget.data['id'] as String;
  String get _name => widget.data['name'] as String? ?? '—';
  String get _email => widget.data['email'] as String? ?? '—';
  String? get _bio => widget.data['bio'] as String?;
  String? get _specialization => widget.data['specialization'] as String?;
  String? get _phone => widget.data['phoneNumber'] as String?;
  String? get _city => widget.data['city'] as String?;
  String? get _videoUrl => widget.data['youtubeVideoUrl'] as String?;
  double? get _examScore => (widget.data['examScore'] as num?)?.toDouble();
  DateTime? get _submittedAt {
    final raw = widget.data['approvalSubmittedAt'];
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'status': 'active',
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectionNote': FieldValue.delete(),
      });
      await NotificationService.sendTeacherApprovedNotification(
        teacherId: _uid,
        teacherName: _name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول المحفظ بنجاح'),
            backgroundColor: AppThemeConstants.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e'),
              backgroundColor: AppThemeConstants.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة سبب الرفض'),
          backgroundColor: AppThemeConstants.warning,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'status': 'rejected',
        'rejectionNote': note,
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      await NotificationService.sendTeacherRejectedNotification(
        teacherId: _uid,
        teacherName: _name,
        rejectionNote: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض الطلب'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e'),
              backgroundColor: AppThemeConstants.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeConstants.surface,
        borderRadius: AppThemeConstants.borderRadiusLg,
        border: Border.all(color: AppThemeConstants.divider),
        boxShadow: const [
          BoxShadow(
            color: AppThemeConstants.shadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: AppThemeConstants.borderRadiusLg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppThemeConstants.accentBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _name.isNotEmpty ? _name[0] : 'م',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppThemeConstants.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827))),
                        const SizedBox(height: 2),
                        Text(_email,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF4B5563))),
                        if (_submittedAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'قُدِّم: ${formatDateTimeToArabicAmPm(_submittedAt!, separator: ' – ')}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Exam score badge
                  if (_examScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _examScore! >= 70
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF3E0),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Text(
                        '${_examScore!.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _examScore! >= 70
                              ? const Color(0xFF2E8B57)
                              : const Color(0xFFE67E22),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF9CA3AF),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded details ────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFFE5EDE9)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Details grid
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (_phone != null)
                        _InfoChip(icon: Icons.phone_rounded, label: _phone!),
                      if (_city != null)
                        _InfoChip(
                            icon: Icons.location_on_rounded, label: _city!),
                      if (_specialization != null)
                        _InfoChip(
                            icon: Icons.auto_stories_rounded,
                            label: _specialization!),
                    ],
                  ),

                  if (_bio != null && _bio!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('النبذة التعريفية:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 4),
                    Text(_bio!,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4B5563),
                            height: 1.5)),
                  ],

                  if (_videoUrl != null && _videoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('رابط فيديو التلاوة:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF6F3),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10)),
                        border: Border.all(color: const Color(0xFFB2D8D2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_outline_rounded,
                              size: 18, color: AppThemeConstants.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _videoUrl!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppThemeConstants.primary,
                                  decoration: TextDecoration.underline),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Certificates sub-list
                  const SizedBox(height: 16),
                  const Text('الشهادات المرفوعة:',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  _CertificatesList(uid: _uid),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE5EDE9)),
                  const SizedBox(height: 12),

                  // Rejection note field
                  TextField(
                    controller: _noteController,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'سبب الرفض (مطلوب عند الرفض فقط)...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      filled: true,
                      fillColor: Color(0xFFF4F7F6),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action buttons
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _reject,
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text('رفض'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppThemeConstants.error,
                                  side: const BorderSide(
                                      color: AppThemeConstants.error),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _approve,
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: const Text('قبول وتفعيل'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppThemeConstants.primary,
                                  foregroundColor: AppThemeConstants.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Certificates sub-list (fetched from Firestore) ──────────────────────────
class _CertificatesList extends StatelessWidget {
  final String uid;
  const _CertificatesList({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('credentials')
          .orderBy('uploadedAt', descending: false)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text('لا توجد شهادات مرفوعة.',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)));
        }
        return Column(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final title = d['title'] as String? ?? '—';
            final org = d['organization'] as String? ?? '—';
            final imgs = (d['imageUrls'] as List?)?.cast<String>() ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFEAF6F3),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      size: 18, color: Color(0xFF0C6F6A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827))),
                        Text(org,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF4B5563))),
                      ],
                    ),
                  ),
                  if (imgs.isNotEmpty)
                    TextButton(
                      onPressed: () => _showImages(context, imgs),
                      child: Text('${imgs.length} صور',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF0C6F6A))),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showImages(BuildContext context, List<String> urls) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('صور الشهادة'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: urls.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: CachedNetworkImage(
                    imageUrl: urls[i],
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_rounded,
                        size: 40,
                        color: AppThemeConstants.grey500)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small info chip ──────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F6),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: const Color(0xFFE5EDE9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppThemeConstants.primary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
        ],
      ),
    );
  }
}
