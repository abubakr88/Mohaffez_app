// lib/screens/teacher_certificates_screen.dart
//
// Step 3 of mohaffez registration: upload certificates then submit for approval.
// Reached after passing the exam (exam_result_screen passes score ≥ passing).
// On submit → sets status='pending_approval', setupCompleted=true → redirects
// to /teacher-pending where the teacher waits for admin decision.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mohaffez_core/src/providers/user_provider.dart';
import '../../services/credential_service.dart';
import 'package:mohaffez_core/src/theme/app_theme_constants.dart';
import 'package:mohaffez_core/src/utils/specialization_constants.dart';

// ─── Design tokens (matching app teal theme) ─────────────────────────────────
class _DS {
  static const teal800 = Color(0xFF095752);
  static const teal700 = Color(0xFF0C6F6A);
  static const teal500 = Color(0xFF1A9E84);
  static const teal50  = Color(0xFFEAF6F3);
  static const amber   = Color(0xFFE67E22);
  static const amberBg = Color(0xFFFFF3E0);
  static const text1   = Color(0xFF111827);
  static const text2   = Color(0xFF4B5563);
  static const border  = Color(0xFFE5EDE9);
  static const bg      = Color(0xFFF4F7F6);
  static const r12     = BorderRadius.all(Radius.circular(12));
  static const r16     = BorderRadius.all(Radius.circular(16));
}

class TeacherCertificatesScreen extends ConsumerStatefulWidget {
  const TeacherCertificatesScreen({super.key});

  @override
  ConsumerState<TeacherCertificatesScreen> createState() =>
      _TeacherCertificatesScreenState();
}

class _TeacherCertificatesScreenState
    extends ConsumerState<TeacherCertificatesScreen> {
  // ─── Certificate form ─────────────────────────────────────────────────────
  final _titleController          = TextEditingController();
  final _organizationController   = TextEditingController();
  final _bioController            = TextEditingController();
  final _specializationController = TextEditingController();
  final _videoUrlController       = TextEditingController();

  final List<_CertEntry> _certificates = [];
  bool _submitting = false;

  Widget _specializationChip({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _DS.teal50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _DS.teal500.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _DS.teal700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _organizationController.dispose();
    _bioController.dispose();
    _specializationController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  // ─── Add certificate dialog ───────────────────────────────────────────────
  Future<void> _showAddCertDialog() async {
    final titleCtrl = TextEditingController();
    final orgCtrl   = TextEditingController();
    final List<XFile> picked = [];
    DateTime? issueDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppThemeConstants.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              top: 24, left: 20, right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(
                        color: _DS.teal50, shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium_rounded,
                          color: _DS.teal500, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('إضافة شهادة / مؤهل',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: _DS.text1)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الشهادة *',
                    border: OutlineInputBorder(borderRadius: _DS.r12),
                    filled: true, fillColor: _DS.bg,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orgCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'الجهة المانحة *',
                    border: OutlineInputBorder(borderRadius: _DS.r12),
                    filled: true, fillColor: _DS.bg,
                  ),
                ),
                const SizedBox(height: 12),
                // Date picker
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime(2020),
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setLocal(() => issueDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: _DS.border),
                      borderRadius: _DS.r12,
                      color: _DS.bg,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 18, color: _DS.teal500),
                        const SizedBox(width: 10),
                        Text(
                          issueDate == null
                              ? 'تاريخ الإصدار *'
                              : '${issueDate!.year}/${issueDate!.month}/${issueDate!.day}',
                          style: TextStyle(
                            color: issueDate == null
                                ? _DS.text2
                                : _DS.text1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Image picker
                OutlinedButton.icon(
                  onPressed: () async {
                    final imgs = await ImagePicker().pickMultiImage();
                    if (imgs.isNotEmpty) {
                      setLocal(() {
                        picked.clear();
                        picked.addAll(imgs.take(3));
                      });
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: Text(picked.isEmpty
                      ? 'إرفاق صورة الشهادة (اختياري)'
                      : 'تم اختيار ${picked.length} صورة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _DS.teal500,
                    side: const BorderSide(color: _DS.teal500),
                    shape: const RoundedRectangleBorder(
                        borderRadius: _DS.r12),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty ||
                          orgCtrl.text.trim().isEmpty ||
                          issueDate == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('يرجى ملء الحقول المطلوبة (*)'),
                              backgroundColor: AppThemeConstants.error),
                        );
                        return;
                      }
                      setState(() {
                        _certificates.add(_CertEntry(
                          title: titleCtrl.text.trim(),
                          organization: orgCtrl.text.trim(),
                          issueDate: issueDate!,
                          images: List.from(picked),
                        ));
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _DS.teal700,
                      foregroundColor: AppThemeConstants.white,
                      shape: const RoundedRectangleBorder(
                          borderRadius: _DS.r12),
                    ),
                    child: const Text('إضافة',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Submit ───────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_submitting) return;
    if (_bioController.text.trim().isEmpty) {
      _snack('يرجى كتابة نبذة تعريفية');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _snack('خطأ: المستخدم غير مسجل');
      return;
    }

    setState(() => _submitting = true);
    try {
      // 1 — Upload each certificate via CredentialService
      for (final cert in _certificates) {
        final urls = await CredentialService.uploadCredentialImages(
            cert.images, uid);
        await CredentialService.addCredential(
          type: 'academic',
          title: cert.title,
          organization: cert.organization,
          issueDate: cert.issueDate,
          imageUrls: urls,
        );
      }

      // 2 — Update user doc: bio, specialization, status → pending_approval
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'bio': _bioController.text.trim(),
        'specialization': _specializationController.text.trim().isEmpty
            ? null
            : _specializationController.text.trim(),
        'youtubeVideoUrl': _videoUrlController.text.trim().isEmpty
            ? null
            : _videoUrlController.text.trim(),
        'status': 'pending_approval',
        'setupCompleted': true,
        'approvalSubmittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3 — Invalidate user provider so guards re-evaluate
      ref.invalidate(currentUserProvider);

      if (mounted) context.go('/teacher-pending');
    } catch (e) {
      if (mounted) _snack('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppThemeConstants.error : _DS.teal500,
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppThemeConstants.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: _DS.bg,
            body: CustomScrollView(
              slivers: [
                // ── Teal header ──────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 160,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: _DS.teal700,
                  surfaceTintColor: AppThemeConstants.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_DS.teal800, _DS.teal500],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: AppThemeConstants.white
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.workspace_premium_rounded,
                                        color: AppThemeConstants.white, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('الملف المهني والشهادات',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: AppThemeConstants.white)),
                                        SizedBox(height: 4),
                                        Text(
                                            'أضف نبذتك وشهاداتك ثم أرسل طلب الانضمام',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: AppThemeConstants.white70)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Step indicator
                              const _StepIndicator(currentStep: 3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Body ─────────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Bio
                      _SectionCard(
                        title: 'النبذة التعريفية',
                        icon: Icons.person_outline_rounded,
                        child: TextField(
                          controller: _bioController,
                          textDirection: TextDirection.rtl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'اكتب نبذة تعريفية عن خبرتك في تحفيظ القرآن الكريم...',
                            border: OutlineInputBorder(
                                borderRadius: _DS.r12),
                            filled: true,
                            fillColor: _DS.bg,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Specialization
                      _SectionCard(
                        title: 'التخصص (اختياري)',
                        icon: Icons.auto_stories_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _specializationController,
                              textDirection: TextDirection.rtl,
                              decoration: const InputDecoration(
                                hintText:
                                    'مثال: حفظ القرآن، تجويد، قراءات عشر...',
                                border: OutlineInputBorder(
                                    borderRadius: _DS.r12),
                                filled: true,
                                fillColor: _DS.bg,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'اختر من التخصصات الشائعة:',
                              style: TextStyle(
                                fontSize: 12,
                                color: _DS.text2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: SpecializationConstants.specializations
                                  .map((spec) => _specializationChip(
                                        label: spec,
                                        onTap: () {
                                          final currentText =
                                              _specializationController.text.trim();
                                          if (currentText.isEmpty) {
                                            _specializationController.text = spec;
                                          } else if (!currentText.contains(spec)) {
                                            _specializationController.text =
                                                '$currentText، $spec';
                                          }
                                        },
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Recitation video URL
                      _SectionCard(
                        title: 'رابط فيديو التلاوة (اختياري)',
                        icon: Icons.play_circle_outline_rounded,
                        child: TextField(
                          controller: _videoUrlController,
                          textDirection: TextDirection.ltr,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            hintText: 'https://youtube.com/...',
                            hintTextDirection: TextDirection.ltr,
                            border: OutlineInputBorder(
                                borderRadius: _DS.r12),
                            filled: true,
                            fillColor: _DS.bg,
                            prefixIcon: Icon(Icons.link_rounded,
                                color: _DS.teal500),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Certificates section
                      _SectionCard(
                        title: 'الشهادات والمؤهلات',
                        icon: Icons.verified_rounded,
                        trailing: TextButton.icon(
                          onPressed: _showAddCertDialog,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('إضافة'),
                          style: TextButton.styleFrom(
                              foregroundColor: _DS.teal500),
                        ),
                        child: _certificates.isEmpty
                            ? _EmptyHint(
                                onAdd: _showAddCertDialog,
                              )
                            : Column(
                                children: _certificates
                                    .asMap()
                                    .entries
                                    .map((e) => _CertTile(
                                          cert: e.value,
                                          onRemove: () => setState(
                                              () => _certificates
                                                  .removeAt(e.key)),
                                        ))
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Info banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _DS.amberBg,
                          borderRadius: _DS.r12,
                          border: Border.all(
                              color: _DS.amber.withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: _DS.amber, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'بعد الإرسال، سيقوم فريق الإدارة بمراجعة طلبك '
                                'والرد عليك خلال 24-48 ساعة.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF92400E),
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _DS.teal700,
                            foregroundColor: AppThemeConstants.white,
                            shape: const RoundedRectangleBorder(
                                borderRadius: _DS.r16),
                            elevation: 0,
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppThemeConstants.white),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text('إرسال طلب الانضمام',
                                        style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Data model ──────────────────────────────────────────────────────────────
class _CertEntry {
  final String title;
  final String organization;
  final DateTime issueDate;
  final List<XFile> images;

  const _CertEntry({
    required this.title,
    required this.organization,
    required this.issueDate,
    required this.images,
  });
}

// ─── Widgets ─────────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep; // 1-based, total 3
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final active = i + 1 <= currentStep;
        final current = i + 1 == currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: active
                        ? AppThemeConstants.white
                        : AppThemeConstants.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: EdgeInsets.only(left: i < 2 ? 6 : 0),
                ),
              ),
              if (current)
                Container(
                  width: 20, height: 20,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                      color: AppThemeConstants.white, shape: BoxShape.circle),
                  child: Center(
                    child: Text('$currentStep',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _DS.teal700)),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: _DS.r16,
        border: Border.all(color: _DS.border),
        boxShadow: [
          BoxShadow(
              color: AppThemeConstants.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _DS.teal500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _DS.text1)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyHint({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: _DS.r12,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: _DS.teal50,
          borderRadius: _DS.r12,
          border: Border.all(color: _DS.teal500.withValues(alpha: 0.3),
              style: BorderStyle.solid),
        ),
        child: const Column(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 32, color: _DS.teal500),
            SizedBox(height: 8),
            Text('اضغط لإضافة شهادة أو مؤهل',
                style:
                    TextStyle(fontSize: 14, color: _DS.teal500)),
          ],
        ),
      ),
    );
  }
}

class _CertTile extends StatelessWidget {
  final _CertEntry cert;
  final VoidCallback onRemove;
  const _CertTile({required this.cert, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _DS.teal50,
        borderRadius: _DS.r12,
        border: Border.all(color: _DS.teal500.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
                color: _DS.teal500, shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium_rounded,
                color: AppThemeConstants.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cert.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _DS.text1)),
                Text(cert.organization,
                    style: const TextStyle(
                        fontSize: 12, color: _DS.text2)),
                if (cert.images.isNotEmpty)
                  Text('${cert.images.length} صورة مرفقة',
                      style: const TextStyle(
                          fontSize: 11, color: _DS.teal500)),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded,
                color: AppThemeConstants.error, size: 20),
            tooltip: 'إزالة',
          ),
        ],
      ),
    );
  }
}
