import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/quran_quiz_bank.dart';
import '../../models/challenge_question.dart';
import '../../providers/challenge_questions_provider.dart';
import '../../shared/theme/app_theme_constants.dart';

// ─── Design tokens ───────────────────────────────────────────────────────────
class _DS {
  static const teal700  = Color(0xFF0C6F6A);
  static const teal600  = Color(0xFF0E8278);
  static const teal500  = Color(0xFF1A9E84);
  static const teal50   = Color(0xFFEAF6F3);
  static const teal100  = Color(0xFFD4EDE7);
  static const amber    = Color(0xFFE67E22);
  static const amberBg  = Color(0xFFFFF3E0);
  static const purple   = Color(0xFF7A5AF8);
  static const purpleBg = Color(0xFFF0EEFF);
  static const green    = Color(0xFF2E8B57);
  static const greenBg  = Color(0xFFE8F5E9);
  static const blue     = Color(0xFF2563EB);
  static const blueBg   = Color(0xFFE3F2FD);
  static const bg       = Color(0xFFF4F7F6);
  static const text1    = Color(0xFF111827);
  static const text2    = Color(0xFF4B5563);
  static const text3    = Color(0xFF9CA3AF);
  static const border   = Color(0xFFE5EDE9);
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r20 = BorderRadius.all(Radius.circular(20));
}

enum _GameMode { selector, game1, game2, game3, game4, game5 }

// ─── Root screen ─────────────────────────────────────────────────────────────
class SessionQuizScreen extends ConsumerStatefulWidget {
  final String? studentName;
  final String? mohaffezId;
  final String? studentId;

  const SessionQuizScreen({
    super.key,
    this.studentName,
    this.mohaffezId,
    this.studentId,
  });

  @override
  ConsumerState<SessionQuizScreen> createState() => _SessionQuizScreenState();
}

class _SessionQuizScreenState extends ConsumerState<SessionQuizScreen> {
  _GameMode _mode = _GameMode.selector;

  // Global score across all games this session
  int _totalCorrect = 0;
  int _totalAsked   = 0;

  // Tracks used ayah indices to avoid immediate repeats
  final List<int> _usedAyahIndices = [];
  final List<int> _usedGroupIds    = [];

  // ── Game 1 & 2 shared state ──────────────────────────────────────────────
  QuizAyah? _currentAyah;
  bool _revealed = false;
  bool? _markedCorrect;

  // ── Game 3 ───────────────────────────────────────────────────────────────
  QuizAyah? _g3Ayah;
  String?   _g3CorrectRule;
  List<String> _g3Options = [];
  String?   _g3Selected;

  // ── Game 4 ───────────────────────────────────────────────────────────────
  List<QuizAyah> _g4Group       = [];
  List<int>      _g4Selection   = []; // indices into _g4Group in tap order
  bool           _g4Submitted   = false;
  bool           _g4Correct     = false;

  // ── Game 5: teacher custom questions ─────────────────────────────────────
  int   _g5Index         = 0;
  bool  _g5Revealed      = false;
  bool? _g5MarkedCorrect;

  // ── Helpers ──────────────────────────────────────────────────────────────
  QuizAyah _nextAyah() {
    if (_usedAyahIndices.length >= QuranQuizBank.ayahs.length) _usedAyahIndices.clear();
    final a = QuranQuizBank.randomAyah(used: _usedAyahIndices);
    _usedAyahIndices.add(QuranQuizBank.indexOf(a));
    return a;
  }

  void _selectMode(_GameMode mode) {
    setState(() {
      _mode = mode;
      _revealed = false;
      _markedCorrect = null;
      if (mode == _GameMode.game1 || mode == _GameMode.game2) {
        _currentAyah = _nextAyah();
      } else if (mode == _GameMode.game3) {
        _loadGame3();
      } else if (mode == _GameMode.game4) {
        _loadGame4();
      } else if (mode == _GameMode.game5) {
        _g5Index = 0;
        _g5Revealed = false;
        _g5MarkedCorrect = null;
      }
    });
  }

  void _loadGame3() {
    final a = _nextAyah();
    _g3Ayah = a;
    _g3CorrectRule = a.tajweedRules.isNotEmpty
        ? a.tajweedRules[Random().nextInt(a.tajweedRules.length)]
        : QuranQuizBank.allTajweedRules.first;
    final wrong = QuranQuizBank.distractorsFor(_g3CorrectRule!);
    _g3Options = [_g3CorrectRule!, ...wrong]..shuffle();
    _g3Selected = null;
  }

  void _loadGame4() {
    if (_usedGroupIds.length >= QuranQuizBank.orderedGroups.length) _usedGroupIds.clear();
    final group = QuranQuizBank.randomGroup(usedGroupIds: _usedGroupIds);
    if (group.isNotEmpty && group.first.groupId != null) {
      _usedGroupIds.add(group.first.groupId!);
    }
    _g4Group = List.from(group)..shuffle();
    _g4Selection = [];
    _g4Submitted = false;
    _g4Correct   = false;
  }

  void _markAnswer(bool correct) {
    setState(() {
      _markedCorrect = correct;
      if (correct) _totalCorrect++;
      _totalAsked++;
    });
  }

  void _nextQuestion() {
    setState(() {
      _revealed      = false;
      _markedCorrect = null;
      _currentAyah   = _nextAyah();
    });
  }

  void _nextGame3() {
    setState(() { _loadGame3(); });
  }

  void _nextGame4() {
    setState(() { _loadGame4(); });
  }

  void _g4Tap(int index) {
    if (_g4Submitted) return;
    setState(() {
      if (_g4Selection.contains(index)) {
        _g4Selection.remove(index);
      } else {
        _g4Selection.add(index);
      }
    });
  }

  void _g4Submit() {
    if (_g4Selection.length != _g4Group.length) return;
    bool correct = true;
    for (int i = 0; i < _g4Selection.length; i++) {
      if (_g4Group[_g4Selection[i]].orderInGroup != i + 1) {
        correct = false;
        break;
      }
    }
    setState(() {
      _g4Submitted = true;
      _g4Correct   = correct;
      if (correct) _totalCorrect++;
      _totalAsked++;
    });
    HapticFeedback.mediumImpact();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _DS.bg,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_mode),
                  child: _buildBody(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titles = {
      _GameMode.selector: 'تحديات الجلسة',
      _GameMode.game1:    'أكمل الآية',
      _GameMode.game2:    'تحديد السورة',
      _GameMode.game3:    'أحكام التجويد',
      _GameMode.game4:    'ترتيب الآيات',
      _GameMode.game5:    'تحديات المحفظ',
    };
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_DS.teal700, _DS.teal600],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_mode == _GameMode.selector) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _mode = _GameMode.selector);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: _DS.r12,
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titles[_mode]!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.studentName != null)
                      Text(
                        widget.studentName!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              if (_totalAsked > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: _DS.r12,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$_totalCorrect / $_totalAsked',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case _GameMode.selector:
        return _buildSelector();
      case _GameMode.game1:
        return _buildGame1();
      case _GameMode.game2:
        return _buildGame2();
      case _GameMode.game3:
        return _buildGame3();
      case _GameMode.game4:
        return _buildGame4();
      case _GameMode.game5:
        return _buildGame5();
    }
  }

  // ── Mode selector ─────────────────────────────────────────────────────────
  Widget _buildSelector() {
    const modes = [
      _ModeCard(
        icon: Icons.auto_stories_rounded,
        title: 'أكمل الآية',
        subtitle: 'أكمل الآية من أولها',
        color: _DS.teal500,
        bg: _DS.teal50,
        mode: _GameMode.game1,
      ),
      _ModeCard(
        icon: Icons.search_rounded,
        title: 'تحديد السورة',
        subtitle: 'من أي سورة هذه الآية؟',
        color: _DS.amber,
        bg: _DS.amberBg,
        mode: _GameMode.game2,
      ),
      _ModeCard(
        icon: Icons.menu_book_rounded,
        title: 'أحكام التجويد',
        subtitle: 'ما الحكم الظاهر في الآية؟',
        color: _DS.purple,
        bg: _DS.purpleBg,
        mode: _GameMode.game3,
      ),
      _ModeCard(
        icon: Icons.sort_rounded,
        title: 'ترتيب الآيات',
        subtitle: 'رتب الآيات حسب ترتيبها',
        color: _DS.blue,
        bg: _DS.blueBg,
        mode: _GameMode.game4,
      ),
    ];

    // Load custom questions count if teacher–student context available
    int customCount = 0;
    if (widget.mohaffezId != null && widget.studentId != null) {
      final params = (
        mohaffezId: widget.mohaffezId!,
        studentId: widget.studentId!,
      );
      final all = ref.watch(studentChallengesProvider(params)).valueOrNull ?? [];
      customCount = all.where((q) => q.isActive).length;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            widget.studentName != null
                ? 'جلسة تحدي مع ${widget.studentName}'
                : 'اختر نوع التحدي',
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, color: _DS.text1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'تقييم تفاعلي يجعل الحفظ أكثر متعة',
            style: TextStyle(fontSize: 14, color: _DS.text2),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.92,
            ),
            itemCount: modes.length,
            itemBuilder: (_, i) => _buildModeCard(modes[i]),
          ),
          // Custom questions card — only shown when teacher has set questions
          if (customCount > 0) ...[
            const SizedBox(height: 14),
            _buildCustomQuestionsCard(customCount),
          ],
          if (_totalAsked > 0) ...[
            const SizedBox(height: 28),
            _buildSessionSummary(),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCustomQuestionsCard(int count) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _selectMode(_GameMode.game5);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B7A75), Color(0xFF0E8278)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: _DS.r20,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B7A75).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: _DS.r16,
              ),
              child: const Icon(Icons.extension_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تحديات المحفظ',
                    style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count سؤال مخصص من محفظك',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(_ModeCard m) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _selectMode(m.mode);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: _DS.r20,
          border: Border.all(color: _DS.border),
          boxShadow: [
            BoxShadow(
              color: m.color.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: m.bg, borderRadius: _DS.r16),
              child: Icon(m.icon, color: m.color, size: 28),
            ),
            const Spacer(),
            Text(
              m.title,
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: _DS.text1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              m.subtitle,
              style: const TextStyle(fontSize: 12, color: _DS.text2, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionSummary() {
    final pct = _totalAsked > 0 ? (_totalCorrect / _totalAsked * 100).round() : 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _DS.r16,
        border: Border.all(color: _DS.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: const BoxDecoration(
              color: _DS.teal50, borderRadius: _DS.r12,
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: _DS.teal500, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نتيجة الجلسة',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: _DS.text1)),
                const SizedBox(height: 2),
                Text(
                  '$_totalCorrect إجابة صحيحة من $_totalAsked سؤال',
                  style: const TextStyle(fontSize: 13, color: _DS.text2),
                ),
              ],
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: pct >= 70 ? _DS.green : pct >= 40 ? _DS.amber : AppThemeConstants.error,
            ),
          ),
        ],
      ),
    );
  }

  // ── Game 1: أكمل الآية ────────────────────────────────────────────────────
  Widget _buildGame1() {
    final ayah = _currentAyah;
    if (ayah == null) return const SizedBox.shrink();
    return _buildRevealGame(
      questionWidget: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _DS.teal50, borderRadius: _DS.r12,
              border: Border.all(color: _DS.teal100),
            ),
            child: Text(
              'الجزء ${ayah.juzNumber}',
              style: const TextStyle(
                  fontSize: 13, color: _DS.teal500, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${ayah.textStart}...',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: _DS.text1,
              height: 1.8,
              fontFamily: 'Amiri',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'أكمل الآية شفهيًا',
            style: TextStyle(fontSize: 14, color: _DS.text2),
          ),
        ],
      ),
      revealWidget: Column(
        children: [
          Text(
            ayah.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _DS.text1,
              height: 2.0,
              fontFamily: 'Amiri',
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _DS.teal50,
              borderRadius: _DS.r12,
              border: Border.all(color: _DS.teal100),
            ),
            child: Text(
              'سورة ${ayah.surahName}  ·  الآية ${ayah.ayahNumber}  ·  الجزء ${ayah.juzNumber}',
              style: const TextStyle(
                  fontSize: 13, color: _DS.teal600, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      revealed: _revealed,
      markedCorrect: _markedCorrect,
      accentColor: _DS.teal500,
      onReveal: () => setState(() => _revealed = true),
      onMark: _markAnswer,
      onNext: _nextQuestion,
    );
  }

  // ── Game 2: تحديد السورة ─────────────────────────────────────────────────
  Widget _buildGame2() {
    final ayah = _currentAyah;
    if (ayah == null) return const SizedBox.shrink();
    return _buildRevealGame(
      questionWidget: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _DS.amberBg, borderRadius: _DS.r12,
              border: Border.all(color: _DS.amber.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'من أي سورة هذه الآية؟',
              style: TextStyle(
                  fontSize: 13, color: _DS.amber, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            ayah.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _DS.text1,
              height: 2.0,
              fontFamily: 'Amiri',
            ),
          ),
        ],
      ),
      revealWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'سورة ${ayah.surahName}',
            style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900, color: _DS.teal500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoBadge(
                  label: 'السورة رقم ${ayah.surahNumber}',
                  color: _DS.amber, bg: _DS.amberBg),
              const SizedBox(width: 8),
              _InfoBadge(
                  label: 'الجزء ${ayah.juzNumber}',
                  color: _DS.teal500, bg: _DS.teal50),
              const SizedBox(width: 8),
              _InfoBadge(
                  label: 'الآية ${ayah.ayahNumber}',
                  color: _DS.purple, bg: _DS.purpleBg),
            ],
          ),
        ],
      ),
      revealed: _revealed,
      markedCorrect: _markedCorrect,
      accentColor: _DS.amber,
      onReveal: () => setState(() => _revealed = true),
      onMark: _markAnswer,
      onNext: _nextQuestion,
    );
  }

  // ── Game 5: teacher custom questions ─────────────────────────────────────
  Widget _buildGame5() {
    if (widget.mohaffezId == null || widget.studentId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('لا توجد بيانات الجلسة',
              style: TextStyle(color: _DS.text3)),
        ),
      );
    }
    final params = (
      mohaffezId: widget.mohaffezId!,
      studentId: widget.studentId!,
    );
    final questionsAsync = ref.watch(studentChallengesProvider(params));

    return questionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (all) {
        final active = all.where((q) => q.isActive).toList();
        if (active.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.extension_off_rounded,
                    size: 64, color: _DS.text3),
                const SizedBox(height: 16),
                const Text('لا توجد أسئلة مفعّلة',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _DS.text1)),
                const SizedBox(height: 8),
                const Text('فعّل بعض الأسئلة من شاشة إدارة التحديات',
                    style: TextStyle(fontSize: 14, color: _DS.text2),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                _BackToMenuButton(
                    onTap: () =>
                        setState(() => _mode = _GameMode.selector)),
              ],
            ),
          );
        }

        // All done
        if (_g5Index >= active.length) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 80, height: 80,
                  decoration: const BoxDecoration(
                    color: _DS.teal50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      size: 44, color: _DS.teal500),
                ),
                const SizedBox(height: 20),
                const Text('انتهت جميع الأسئلة!',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _DS.text1)),
                const SizedBox(height: 8),
                Text(
                  '$_totalCorrect إجابة صحيحة من ${active.length} سؤال',
                  style: const TextStyle(fontSize: 15, color: _DS.text2),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: _TealButton(
                    label: 'إعادة التحديات',
                    icon: Icons.replay_rounded,
                    onTap: () => setState(() {
                      _g5Index = 0;
                      _g5Revealed = false;
                      _g5MarkedCorrect = null;
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                _BackToMenuButton(
                    onTap: () =>
                        setState(() => _mode = _GameMode.selector)),
              ],
            ),
          );
        }

        final q = active[_g5Index];
        final typeColor = _g5TypeColor(q.type);
        final typeBg    = _g5TypeBg(q.type);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Progress indicator
              Row(
                children: [
                  Text(
                    'سؤال ${_g5Index + 1} من ${active.length}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _DS.text3),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: _DS.r12,
                      child: LinearProgressIndicator(
                        value: (_g5Index + 1) / active.length,
                        backgroundColor: _DS.border,
                        color: _DS.teal500,
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Question card
              GestureDetector(
                onTap: _g5Revealed ? null : () => setState(() => _g5Revealed = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: _DS.r20,
                    border: Border.all(
                      color: _g5MarkedCorrect == null
                          ? (_g5Revealed
                              ? typeColor.withValues(alpha: 0.4)
                              : _DS.border)
                          : _g5MarkedCorrect!
                              ? _DS.green.withValues(alpha: 0.5)
                              : AppThemeConstants.error.withValues(alpha: 0.5),
                      width: _g5MarkedCorrect != null ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: typeColor.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Type + difficulty badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: typeBg,
                              borderRadius: _DS.r12,
                              border: Border.all(
                                  color:
                                      typeColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              q.type.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: typeColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _g5DiffBg(q.difficulty),
                              borderRadius: _DS.r12,
                            ),
                            child: Text(
                              _g5DiffLabel(q.difficulty),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _g5DiffColor(q.difficulty)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Question text
                      Text(
                        q.question,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _DS.text1,
                          height: 1.6,
                        ),
                      ),
                      // Revealed: show hint + answer
                      if (_g5Revealed) ...[
                        if (q.hint != null && q.hint!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _DS.amberBg,
                              borderRadius: _DS.r12,
                              border: Border.all(
                                  color: _DS.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 16,
                                    color: _DS.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    q.hint!,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: _DS.text1,
                                        height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (q.answer != null && q.answer!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _DS.teal50,
                              borderRadius: _DS.r12,
                              border:
                                  Border.all(color: _DS.teal100),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.key_rounded,
                                    size: 16, color: _DS.teal500),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    q.answer!,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: _DS.teal700,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app_rounded,
                                size: 14,
                                color: typeColor.withValues(alpha: 0.7)),
                            const SizedBox(width: 6),
                            Text(
                              'اضغط للكشف',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: typeColor.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Result + navigation
              if (_g5MarkedCorrect != null) ...[
                _ResultBanner(correct: _g5MarkedCorrect!),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _TealButton(
                    label: _g5Index + 1 < active.length
                        ? 'السؤال التالي'
                        : 'إنهاء التحديات',
                    icon: _g5Index + 1 < active.length
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.check_circle_outline_rounded,
                    onTap: () => setState(() {
                      _g5Index++;
                      _g5Revealed = false;
                      _g5MarkedCorrect = null;
                    }),
                  ),
                ),
              ] else if (_g5Revealed) ...[
                Row(
                  children: [
                    Expanded(
                      child: _OutlineButton(
                        label: 'خطأ',
                        icon: Icons.close_rounded,
                        color: AppThemeConstants.error,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _g5MarkedCorrect = false;
                            _totalAsked++;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OutlineButton(
                        label: 'صحيح',
                        icon: Icons.check_rounded,
                        color: _DS.green,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _g5MarkedCorrect = true;
                            _totalCorrect++;
                            _totalAsked++;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _BackToMenuButton(
                  onTap: () => setState(() => _mode = _GameMode.selector)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Color _g5TypeColor(ChallengeType t) => switch (t) {
    ChallengeType.completeAyah  => _DS.teal500,
    ChallengeType.nameSurah     => _DS.amber,
    ChallengeType.tajweedRule   => _DS.purple,
    ChallengeType.wordMeaning   => _DS.blue,
    ChallengeType.openQuestion  => _DS.green,
  };
  Color _g5TypeBg(ChallengeType t) => switch (t) {
    ChallengeType.completeAyah  => _DS.teal50,
    ChallengeType.nameSurah     => _DS.amberBg,
    ChallengeType.tajweedRule   => _DS.purpleBg,
    ChallengeType.wordMeaning   => _DS.blueBg,
    ChallengeType.openQuestion  => _DS.greenBg,
  };
  Color  _g5DiffColor(String d)  => switch (d) {
    'easy'  => _DS.green,
    'hard'  => AppThemeConstants.error,
    _       => _DS.amber,
  };
  Color  _g5DiffBg(String d)    => switch (d) {
    'easy'  => _DS.greenBg,
    'hard'  => AppThemeConstants.error.withValues(alpha: 0.08),
    _       => _DS.amberBg,
  };
  String _g5DiffLabel(String d)  => switch (d) {
    'easy'  => 'سهل',
    'hard'  => 'صعب',
    _       => 'متوسط',
  };

  // ── Shared reveal-card builder (games 1 & 2) ─────────────────────────────
  Widget _buildRevealGame({
    required Widget questionWidget,
    required Widget revealWidget,
    required bool revealed,
    required bool? markedCorrect,
    required Color accentColor,
    required VoidCallback onReveal,
    required void Function(bool) onMark,
    required VoidCallback onNext,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Question / reveal card
          GestureDetector(
            onTap: revealed ? null : onReveal,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: _DS.r20,
                border: Border.all(
                  color: markedCorrect == null
                      ? (revealed ? accentColor.withValues(alpha: 0.35) : _DS.border)
                      : markedCorrect
                          ? _DS.green.withValues(alpha: 0.5)
                          : AppThemeConstants.error.withValues(alpha: 0.5),
                  width: markedCorrect != null ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.08),
                    blurRadius: 20, offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AnimatedCrossFade(
                    firstChild: questionWidget,
                    secondChild: revealWidget,
                    crossFadeState: revealed
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 350),
                  ),
                  if (!revealed) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_rounded,
                            size: 16, color: accentColor.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text(
                          'اضغط للكشف',
                          style: TextStyle(
                              fontSize: 13,
                              color: accentColor.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Result feedback
          if (markedCorrect != null)
            _ResultBanner(correct: markedCorrect),

          if (markedCorrect != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _TealButton(
                label: 'سؤال جديد',
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onNext,
              ),
            ),
          ] else if (revealed) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _OutlineButton(
                    label: 'خطأ',
                    icon: Icons.close_rounded,
                    color: AppThemeConstants.error,
                    onTap: () { HapticFeedback.lightImpact(); onMark(false); },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OutlineButton(
                    label: 'صحيح',
                    icon: Icons.check_rounded,
                    color: _DS.green,
                    onTap: () { HapticFeedback.lightImpact(); onMark(true); },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _BackToMenuButton(onTap: () => setState(() => _mode = _GameMode.selector)),
        ],
      ),
    );
  }

  // ── Game 3: أحكام التجويد ─────────────────────────────────────────────────
  Widget _buildGame3() {
    final ayah = _g3Ayah;
    if (ayah == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Ayah card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _DS.r20,
              border: Border.all(color: _DS.border),
              boxShadow: [
                BoxShadow(
                  color: _DS.purple.withValues(alpha: 0.07),
                  blurRadius: 20, offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _DS.purpleBg, borderRadius: _DS.r12,
                    border: Border.all(color: _DS.purple.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'ما الحكم التجويدي الظاهر في هذه الآية؟',
                    style: TextStyle(
                        fontSize: 13, color: _DS.purple, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  ayah.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: _DS.text1, height: 2.0, fontFamily: 'Amiri',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'سورة ${ayah.surahName}  ·  الجزء ${ayah.juzNumber}',
                  style: const TextStyle(fontSize: 12, color: _DS.text3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Options
          ...List.generate(_g3Options.length, (i) {
            final opt = _g3Options[i];
            final isSelected = _g3Selected == opt;
            final isAnswered = _g3Selected != null;
            final isCorrect  = opt == _g3CorrectRule;

            Color borderColor = _DS.border;
            Color bgColor     = Colors.white;
            Color textColor   = _DS.text1;

            if (isAnswered) {
              if (isCorrect) {
                borderColor = _DS.green;
                bgColor     = _DS.greenBg;
                textColor   = _DS.green;
              } else if (isSelected) {
                borderColor = AppThemeConstants.error;
                bgColor     = AppThemeConstants.error.withValues(alpha: 0.06);
                textColor   = AppThemeConstants.error;
              }
            } else if (isSelected) {
              borderColor = _DS.purple;
              bgColor     = _DS.purpleBg;
              textColor   = _DS.purple;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: isAnswered
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _g3Selected = opt;
                          if (opt == _g3CorrectRule) {
                            _totalCorrect++;
                          }
                          _totalAsked++;
                        });
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: _DS.r16,
                    border: Border.all(color: borderColor, width: isAnswered && isCorrect ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAnswered && isCorrect
                              ? _DS.green
                              : isAnswered && isSelected
                                  ? AppThemeConstants.error
                                  : _DS.teal50,
                        ),
                        child: isAnswered && isCorrect
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : isAnswered && isSelected
                                ? const Icon(Icons.close, color: Colors.white, size: 16)
                                : Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w700,
                                          color: _DS.teal500),
                                    ),
                                  ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),
          if (_g3Selected != null) ...[
            _ResultBanner(correct: _g3Selected == _g3CorrectRule),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _TealButton(
                label: 'سؤال جديد',
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _nextGame3,
              ),
            ),
            const SizedBox(height: 10),
          ],
          _BackToMenuButton(onTap: () => setState(() => _mode = _GameMode.selector)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Game 4: ترتيب الآيات ─────────────────────────────────────────────────
  Widget _buildGame4() {
    if (_g4Group.isEmpty) return const SizedBox.shrink();
    final surahName = _g4Group.first.surahName;
    final allSelected = _g4Selection.length == _g4Group.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _DS.r16,
              border: Border.all(color: _DS.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.sort_rounded, color: _DS.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'رتّب آيات سورة $surahName بالترتيب الصحيح',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: _DS.text1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ayah cards
          ...List.generate(_g4Group.length, (i) {
            final ayah        = _g4Group[i];
            final tapOrder    = _g4Selection.indexOf(i); // -1 if not selected
            final isSelected  = tapOrder != -1;
            final userPos     = isSelected ? tapOrder + 1 : null; // 1-based
            final correctPos  = ayah.orderInGroup;

            Color borderColor = _DS.border;
            Color bgColor     = Colors.white;

            if (_g4Submitted) {
              final isCorrectPos = isSelected && userPos == correctPos;
              borderColor = isCorrectPos
                  ? _DS.green
                  : AppThemeConstants.error;
              bgColor = isCorrectPos
                  ? _DS.greenBg
                  : AppThemeConstants.error.withValues(alpha: 0.06);
            } else if (isSelected) {
              borderColor = _DS.blue;
              bgColor     = _DS.blueBg.withValues(alpha: 0.7);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: _g4Submitted ? null : () { HapticFeedback.selectionClick(); _g4Tap(i); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: _DS.r16,
                    border: Border.all(
                      color: borderColor,
                      width: isSelected || _g4Submitted ? 1.5 : 1,
                    ),
                    boxShadow: isSelected && !_g4Submitted
                        ? [BoxShadow(
                            color: _DS.blue.withValues(alpha: 0.1),
                            blurRadius: 8, offset: const Offset(0, 3),
                          )]
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Order badge
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _g4Submitted
                              ? (userPos == correctPos ? _DS.green : AppThemeConstants.error)
                              : isSelected
                                  ? _DS.blue
                                  : _DS.teal50,
                          border: isSelected || _g4Submitted
                              ? null
                              : Border.all(color: _DS.border),
                        ),
                        child: Center(
                          child: _g4Submitted && !isSelected
                              ? const Icon(Icons.close, color: Colors.white, size: 16)
                              : _g4Submitted
                                  ? Icon(
                                      userPos == correctPos
                                          ? Icons.check_rounded
                                          : Icons.close_rounded,
                                      color: Colors.white, size: 16,
                                    )
                                  : Text(
                                      isSelected ? '$userPos' : '?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? Colors.white : _DS.text3,
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          ayah.text,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _g4Submitted
                                ? (userPos == correctPos ? _DS.green : AppThemeConstants.error)
                                : _DS.text1,
                            height: 1.8,
                            fontFamily: 'Amiri',
                          ),
                        ),
                      ),
                      if (_g4Submitted && userPos != correctPos)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: const BoxDecoration(
                              color: _DS.teal50, borderRadius: _DS.r12,
                            ),
                            child: Text(
                              'رقم $correctPos',
                              style: const TextStyle(
                                  fontSize: 11, color: _DS.teal500, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),
          if (_g4Submitted) ...[
            _ResultBanner(correct: _g4Correct),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _TealButton(
                label: 'مجموعة أخرى',
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _nextGame4,
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: AnimatedOpacity(
                opacity: allSelected ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: _TealButton(
                  label: 'تحقق من الترتيب',
                  icon: Icons.check_circle_outline_rounded,
                  onTap: allSelected ? _g4Submit : null,
                ),
              ),
            ),
            if (!allSelected) ...[
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'اضغط على الآيات بالترتيب الصحيح',
                  style: TextStyle(fontSize: 13, color: _DS.text3),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          _BackToMenuButton(onTap: () => setState(() => _mode = _GameMode.selector)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  final bool correct;
  const _ResultBanner({required this.correct});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: correct
            ? _DS.greenBg
            : AppThemeConstants.error.withValues(alpha: 0.08),
        borderRadius: _DS.r12,
        border: Border.all(
          color: correct
              ? _DS.green.withValues(alpha: 0.4)
              : AppThemeConstants.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: correct ? _DS.green : AppThemeConstants.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            correct ? 'أحسنت! إجابة صحيحة ✓' : 'إجابة خاطئة — حاول مرة أخرى',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: correct ? _DS.green : AppThemeConstants.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _TealButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _TealButton({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null ? () {
        HapticFeedback.lightImpact();
        onTap!();
      } : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_DS.teal600, _DS.teal500],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: _DS.r16,
          boxShadow: [
            BoxShadow(
              color: _DS.teal500.withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _OutlineButton({
    required this.label, required this.icon,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: _DS.r16,
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackToMenuButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackToMenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view_rounded, size: 14, color: _DS.text3),
              SizedBox(width: 6),
              Text(
                'العودة إلى القائمة',
                style: TextStyle(fontSize: 13, color: _DS.text3, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _InfoBadge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg, borderRadius: _DS.r12,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ModeCard {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bg;
  final _GameMode mode;
  const _ModeCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.bg, required this.mode,
  });
}
