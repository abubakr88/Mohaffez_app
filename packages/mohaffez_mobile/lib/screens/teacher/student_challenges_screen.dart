import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


// ─── Design tokens ────────────────────────────────────────────────────────────
class _DS {
  static const bg     = Color(0xFFF4F7F6);
  static const text1  = Color(0xFF111827);
  static const text2  = Color(0xFF4B5563);
  static const text3  = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5EDE9);
  static const r12    = BorderRadius.all(Radius.circular(12));
  static const r16    = BorderRadius.all(Radius.circular(16));

  // per-type colours
  static Color typeColor(ChallengeType t) => switch (t) {
    ChallengeType.completeAyah  => const Color(0xFF1A9E84),
    ChallengeType.nameSurah     => const Color(0xFFE67E22),
    ChallengeType.tajweedRule   => const Color(0xFF7A5AF8),
    ChallengeType.wordMeaning   => const Color(0xFF2563EB),
    ChallengeType.openQuestion  => const Color(0xFF2E8B57),
  };
  static Color typeBg(ChallengeType t) => switch (t) {
    ChallengeType.completeAyah  => const Color(0xFFEAF6F3),
    ChallengeType.nameSurah     => const Color(0xFFFFF3E0),
    ChallengeType.tajweedRule   => const Color(0xFFF0EEFF),
    ChallengeType.wordMeaning   => const Color(0xFFE3F2FD),
    ChallengeType.openQuestion  => const Color(0xFFE8F5E9),
  };
  static IconData typeIcon(ChallengeType t) => switch (t) {
    ChallengeType.completeAyah  => Icons.auto_stories_rounded,
    ChallengeType.nameSurah     => Icons.search_rounded,
    ChallengeType.tajweedRule   => Icons.menu_book_rounded,
    ChallengeType.wordMeaning   => Icons.translate_rounded,
    ChallengeType.openQuestion  => Icons.help_outline_rounded,
  };
}

class StudentChallengesScreen extends ConsumerWidget {
  final String mohaffezId;
  final String studentId;
  final String studentName;

  const StudentChallengesScreen({
    super.key,
    required this.mohaffezId,
    required this.studentId,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (mohaffezId: mohaffezId, studentId: studentId);
    final questionsAsync = ref.watch(studentChallengesProvider(params));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _DS.bg,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تحديات الجلسة',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(studentName,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppThemeConstants.white70)),
            ],
          ),
          backgroundColor: AppThemeConstants.primary,
          foregroundColor: AppThemeConstants.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: questionsAsync.when(
          data: (questions) => _buildBody(context, ref, questions, params),
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('تعذّر التحميل: $e',
                style: const TextStyle(color: AppThemeConstants.error)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<ChallengeQuestion> all,
    ({String mohaffezId, String studentId}) params,
  ) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Banner
              _InfoBanner(total: all.length, active: all.where((q) => q.isActive).length),
              const SizedBox(height: 24),

              // One section per challenge type
              ...ChallengeType.values.map((type) {
                final typed = all.where((q) => q.type == type).toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _TypeSection(
                    type: type,
                    questions: typed,
                    onAdd: () => _showQuestionSheet(context, ref, params,
                        type: type, existing: null),
                    onEdit: (q) => _showQuestionSheet(context, ref, params,
                        type: type, existing: q),
                    onDelete: (q) => _confirmDelete(context, ref, params, q),
                    onToggle: (q, val) => updateChallengeQuestion(
                      mohaffezId: params.mohaffezId,
                      studentId: params.studentId,
                      questionId: q.id,
                      fields: {'isActive': val},
                    ),
                  ),
                );
              }),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _showQuestionSheet(
    BuildContext context,
    WidgetRef ref,
    ({String mohaffezId, String studentId}) params, {
    required ChallengeType type,
    required ChallengeQuestion? existing,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppThemeConstants.transparent,
      builder: (_) => _QuestionSheet(
        type: type,
        existing: existing,
        onSave: (q) async {
          if (existing == null) {
            await addChallengeQuestion(
              mohaffezId: params.mohaffezId,
              studentId: params.studentId,
              question: q,
            );
          } else {
            await updateChallengeQuestion(
              mohaffezId: params.mohaffezId,
              studentId: params.studentId,
              questionId: existing.id,
              fields: q.toMap()..remove('createdAt'),
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ({String mohaffezId, String studentId}) params,
    ChallengeQuestion q,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف السؤال'),
          content: Text('هل تريد حذف هذا السؤال نهائيًا؟\n"${q.question}"',
              maxLines: 3, overflow: TextOverflow.ellipsis),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف',
                  style: TextStyle(color: AppThemeConstants.error)),
            ),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await deleteChallengeQuestion(
        mohaffezId: params.mohaffezId,
        studentId: params.studentId,
        questionId: q.id,
      );
    }
  }
}

// ─── Info banner ──────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final int total;
  final int active;
  const _InfoBanner({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeConstants.primary.withValues(alpha: 0.07),
        borderRadius: _DS.r16,
        border: Border.all(
            color: AppThemeConstants.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppThemeConstants.primary.withValues(alpha: 0.12),
              borderRadius: _DS.r12,
            ),
            child: const Icon(Icons.extension_rounded,
                color: AppThemeConstants.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total سؤال ($active مفعّل)',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _DS.text1),
                ),
                const SizedBox(height: 2),
                const Text(
                  'الأسئلة المفعّلة تظهر للطالب عند فتح التحديات',
                  style: TextStyle(fontSize: 12, color: _DS.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Per-type section ─────────────────────────────────────────────────────────
class _TypeSection extends StatelessWidget {
  final ChallengeType type;
  final List<ChallengeQuestion> questions;
  final VoidCallback onAdd;
  final void Function(ChallengeQuestion) onEdit;
  final void Function(ChallengeQuestion) onDelete;
  final void Function(ChallengeQuestion, bool) onToggle;

  const _TypeSection({
    required this.type,
    required this.questions,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color  = _DS.typeColor(type);
    final bg     = _DS.typeBg(type);
    final icon   = _DS.typeIcon(type);

    return Container(
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: _DS.r16,
        border: Border.all(color: _DS.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: _DS.r12),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ChallengeTypeX(type).label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: _DS.r12,
                  ),
                  child: Text(
                    '${questions.length}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
              ],
            ),
          ),

          // Question list
          if (questions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: _DS.text3),
                  SizedBox(width: 8),
                  Text('لا توجد أسئلة بعد',
                      style: TextStyle(fontSize: 13, color: _DS.text3)),
                ],
              ),
            )
          else
            ...questions.asMap().entries.map((e) {
              final idx = e.key;
              final q   = e.value;
              return Column(
                children: [
                  if (idx > 0)
                    const Divider(height: 1, color: _DS.border),
                  _QuestionTile(
                    question: q,
                    onEdit: () => onEdit(q),
                    onDelete: () => onDelete(q),
                    onToggle: (val) => onToggle(q, val),
                  ),
                ],
              );
            }),

          // Add button
          InkWell(
            onTap: () { HapticFeedback.lightImpact(); onAdd(); },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: color.withValues(alpha: 0.2))),
                color: bg.withValues(alpha: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text('إضافة سؤال',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Question tile ────────────────────────────────────────────────────────────
class _QuestionTile extends StatelessWidget {
  final ChallengeQuestion question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(bool) onToggle;

  const _QuestionTile({
    required this.question,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final diffColor = switch (question.difficulty) {
      'easy'   => const Color(0xFF2E8B57),
      'hard'   => AppThemeConstants.error,
      _        => const Color(0xFFE67E22),
    };
    final diffLabel = switch (question.difficulty) {
      'easy'   => 'سهل',
      'hard'   => 'صعب',
      _        => 'متوسط',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active toggle
          Transform.scale(
            scale: 0.82,
            child: Switch.adaptive(
              value: question.isActive,
              activeThumbColor: AppThemeConstants.secondary,
              activeTrackColor:
                  AppThemeConstants.secondary.withValues(alpha: 0.4),
              onChanged: onToggle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.question,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: question.isActive ? _DS.text1 : _DS.text3,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: diffColor.withValues(alpha: 0.1),
                        borderRadius: _DS.r12,
                        border: Border.all(
                            color: diffColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(diffLabel,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: diffColor)),
                    ),
                    if (question.hint != null &&
                        question.hint!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lightbulb_outline_rounded,
                          size: 12, color: _DS.text3),
                      const SizedBox(width: 2),
                      const Text('تلميح',
                          style:
                              TextStyle(fontSize: 10, color: _DS.text3)),
                    ],
                    if (question.answer != null &&
                        question.answer!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.key_rounded,
                          size: 12, color: _DS.text3),
                      const SizedBox(width: 2),
                      const Text('إجابة مرجعية',
                          style:
                              TextStyle(fontSize: 10, color: _DS.text3)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Edit / delete actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                size: 18, color: _DS.text3),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('حذف',
                    style: TextStyle(color: AppThemeConstants.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Add / Edit bottom sheet ──────────────────────────────────────────────────
class _QuestionSheet extends StatefulWidget {
  final ChallengeType type;
  final ChallengeQuestion? existing;
  final Future<void> Function(ChallengeQuestion) onSave;

  const _QuestionSheet({
    required this.type,
    required this.existing,
    required this.onSave,
  });

  @override
  State<_QuestionSheet> createState() => _QuestionSheetState();
}

class _QuestionSheetState extends State<_QuestionSheet> {
  late final TextEditingController _questionCtrl;
  late final TextEditingController _hintCtrl;
  late final TextEditingController _answerCtrl;
  late String _difficulty;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _questionCtrl = TextEditingController(text: e?.question ?? '');
    _hintCtrl     = TextEditingController(text: e?.hint ?? '');
    _answerCtrl   = TextEditingController(text: e?.answer ?? '');
    _difficulty   = e?.difficulty ?? 'medium';
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _hintCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final q = _questionCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _saving = true);
    try {
      final question = ChallengeQuestion(
        id: widget.existing?.id ?? '',
        type: widget.type,
        question: q,
        hint: _hintCtrl.text.trim().isEmpty ? null : _hintCtrl.text.trim(),
        answer: _answerCtrl.text.trim().isEmpty ? null : _answerCtrl.text.trim(),
        difficulty: _difficulty,
        isActive: widget.existing?.isActive ?? true,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );
      await widget.onSave(question);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color  = _DS.typeColor(widget.type);
    final isEdit = widget.existing != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: AppThemeConstants.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _DS.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title row
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: _DS.r12,
                    ),
                    child: Icon(_DS.typeIcon(widget.type), color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'تعديل السؤال' : 'سؤال جديد',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(ChallengeTypeX(widget.type).label,
                            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Question field
              _buildLabel('السؤال *'),
              const SizedBox(height: 6),
              TextField(
                controller: _questionCtrl,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: _hintForType(widget.type),
                  hintStyle: const TextStyle(color: _DS.text3),
                  border: const OutlineInputBorder(borderRadius: _DS.r12),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: _DS.r12,
                    borderSide: BorderSide(color: color, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Hint field
              _buildLabel('تلميح (اختياري)'),
              const SizedBox(height: 6),
              TextField(
                controller: _hintCtrl,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'تلميح يظهر للطالب عند الكشف',
                  hintStyle: const TextStyle(color: _DS.text3),
                  border: const OutlineInputBorder(borderRadius: _DS.r12),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: _DS.r12,
                    borderSide: BorderSide(color: color, width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.lightbulb_outline_rounded,
                      color: _DS.text3, size: 18),
                ),
              ),
              const SizedBox(height: 16),

              // Answer field (teacher reference)
              _buildLabel('الإجابة المرجعية (للمحفظ فقط)'),
              const SizedBox(height: 6),
              TextField(
                controller: _answerCtrl,
                maxLines: 2,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'الإجابة الصحيحة — لا تُعرض للطالب',
                  hintStyle: const TextStyle(color: _DS.text3),
                  border: const OutlineInputBorder(borderRadius: _DS.r12),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: _DS.r12,
                    borderSide: BorderSide(color: color, width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.key_rounded,
                      color: _DS.text3, size: 18),
                ),
              ),
              const SizedBox(height: 20),

              // Difficulty
              _buildLabel('مستوى الصعوبة'),
              const SizedBox(height: 8),
              Row(
                children: ['easy', 'medium', 'hard'].map((d) {
                  final label = switch (d) {
                    'easy'  => 'سهل',
                    'hard'  => 'صعب',
                    _       => 'متوسط',
                  };
                  final dColor = switch (d) {
                    'easy'  => const Color(0xFF2E8B57),
                    'hard'  => AppThemeConstants.error,
                    _       => const Color(0xFFE67E22),
                  };
                  final selected = _difficulty == d;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _difficulty = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? dColor.withValues(alpha: 0.12)
                                : _DS.bg,
                            borderRadius: _DS.r12,
                            border: Border.all(
                              color: selected
                                  ? dColor
                                  : _DS.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected ? dColor : _DS.text2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primary,
                    foregroundColor: AppThemeConstants.white,
                    shape: const RoundedRectangleBorder(borderRadius: _DS.r16),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppThemeConstants.white),
                        )
                      : Text(
                          isEdit ? 'حفظ التعديلات' : 'إضافة السؤال',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: _DS.text2),
      );

  String _hintForType(ChallengeType t) => switch (t) {
    ChallengeType.completeAyah  => 'مثال: وَلَا تَقُولَنَّ لِشَيْءٍ...',
    ChallengeType.nameSurah     => 'مثال: اكتب الآية التي تريد أن يحدد سورتها',
    ChallengeType.tajweedRule   => 'مثال: ما حكم الميم الساكنة في: أَم مَّنْ...؟',
    ChallengeType.wordMeaning   => 'مثال: ما معنى كلمة "الصِّرَاط"؟',
    ChallengeType.openQuestion  => 'مثال: كم عدد آيات سورة الفاتحة؟',
  };
}
