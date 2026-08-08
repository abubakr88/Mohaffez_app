import 'dart:convert';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart' hide AppThemeConstants;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/practice_challenge_bank.dart';
import '../../providers/quiz_access_provider.dart';
import '../../shared/theme/app_theme_constants.dart';

class StudentChallengeScreen extends StatefulWidget {
  final SessionChallengeInfo? sessionChallenge;

  const StudentChallengeScreen({
    super.key,
    this.sessionChallenge,
  });

  bool get isPractice => sessionChallenge == null;

  @override
  State<StudentChallengeScreen> createState() => _StudentChallengeScreenState();
}

class _StudentChallengeScreenState extends State<StudentChallengeScreen> {
  static const _teal = Color(0xFF0F766E);
  static const _gold = Color(0xFFD4A44A);
  static const _surface = Color(0xFFF6FAF9);
  static const _border = Color(0xFFD9E6E3);

  bool _started = false;
  bool _submitting = false;
  int _index = 0;
  String _attemptId = '';
  final Map<String, dynamic> _responses = {};
  final Map<String, List<String>> _orderDrafts = {};
  Map<String, dynamic>? _serverResult;
  int? _practiceCorrect;
  ChallengeType? _selectedPracticeType;
  bool _replayMode = false;
  bool _replayCompleted = false;
  late final ConfettiController _celebrationBurst;
  late final ConfettiController _leftFireworks;
  late final ConfettiController _rightFireworks;

  List<ChallengeQuestion> get _questions {
    final sessionQuestions = widget.sessionChallenge?.questions;
    if (sessionQuestions != null) return sessionQuestions;
    final selectedType = _selectedPracticeType;
    if (selectedType == null) return const [];
    return practiceChallengeQuestions
        .where((question) => question.type == selectedType)
        .toList();
  }

  String? get _draftKey {
    final challenge = widget.sessionChallenge;
    if (challenge == null) return null;
    return 'challenge_draft_${challenge.sessionId}_${challenge.setVersion}';
  }

  @override
  void initState() {
    super.initState();
    _celebrationBurst = ConfettiController(
      duration: const Duration(milliseconds: 900),
    );
    _leftFireworks = ConfettiController(
      duration: const Duration(milliseconds: 1300),
    );
    _rightFireworks = ConfettiController(
      duration: const Duration(milliseconds: 1300),
    );
    _attemptId = createChallengeAttemptId();
    _replayMode = widget.sessionChallenge?.hasScoredAttempt ?? false;
    if (!widget.isPractice && !_replayMode) {
      _restoreDraft();
    }
  }

  @override
  void dispose() {
    _celebrationBurst.dispose();
    _leftFireworks.dispose();
    _rightFireworks.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final key = _draftKey;
    if (key == null) return;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    if (raw == null || !mounted) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final rawResponses = data['responses'];
      setState(() {
        _attemptId = data['attemptId'] as String? ?? _attemptId;
        _index = ((data['index'] as num?)?.toInt() ?? 0)
            .clamp(0, max(0, _questions.length - 1));
        _started = data['started'] == true;
        if (rawResponses is Map) {
          _responses
            ..clear()
            ..addAll(Map<String, dynamic>.from(rawResponses));
        }
      });
    } catch (_) {
      await preferences.remove(key);
    }
  }

  Future<void> _persistDraft() async {
    final key = _draftKey;
    if (key == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      key,
      jsonEncode({
        'attemptId': _attemptId,
        'index': _index,
        'started': _started,
        'responses': _responses,
      }),
    );
  }

  Future<void> _clearDraft() async {
    final key = _draftKey;
    if (key == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }

  void _setResponse(String questionId, dynamic answer) {
    setState(() => _responses[questionId] = answer);
    _persistDraft();
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_index >= _questions.length - 1) {
      _finish();
      return;
    }
    setState(() => _index += 1);
    _persistDraft();
  }

  void _startPracticeType(ChallengeType type) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedPracticeType = type;
      _index = 0;
      _responses.clear();
      _orderDrafts.clear();
      _practiceCorrect = null;
      _started = true;
    });
  }

  void _returnToPracticeMenu() {
    setState(() {
      _selectedPracticeType = null;
      _index = 0;
      _responses.clear();
      _orderDrafts.clear();
      _practiceCorrect = null;
      _started = false;
    });
  }

  Future<void> _finish() async {
    if (_replayMode) {
      setState(() => _replayCompleted = true);
      _scheduleCelebration();
      return;
    }
    if (widget.isPractice) {
      var correct = 0;
      for (final question in _questions) {
        final response = _responses[question.id];
        if (question.answerMode == ChallengeAnswerMode.multipleChoice &&
            response == question.correctOptionId) {
          correct += 1;
        } else if (question.answerMode == ChallengeAnswerMode.ordering &&
            response is List &&
            response.length == question.correctOrder.length &&
            List.generate(
              response.length,
              (index) => response[index] == question.correctOrder[index],
            ).every((matches) => matches)) {
          correct += 1;
        }
      }
      setState(() => _practiceCorrect = correct);
      _scheduleCelebration(perfect: correct == _questions.length);
      return;
    }

    final challenge = widget.sessionChallenge!;
    setState(() => _submitting = true);
    try {
      final result = await submitSessionChallenge(
        sessionId: challenge.sessionId,
        setVersion: challenge.setVersion,
        studentProfileId: challenge.studentProfileId,
        clientAttemptId: _attemptId,
        responses: challenge.questions
            .map((question) => {
                  'questionId': question.id,
                  'answer': _responses[question.id],
                })
            .toList(),
      );
      await _clearDraft();
      if (mounted) {
        setState(() => _serverResult = result);
        final correct = (result['correct'] as num?)?.toInt() ?? 0;
        final asked = (result['asked'] as num?)?.toInt() ?? 0;
        final pending = (result['pendingReviewCount'] as num?)?.toInt() ?? 0;
        _scheduleCelebration(
          perfect: asked > 0 && correct == asked && pending == 0,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: AppThemeConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _scheduleCelebration({bool perfect = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (MediaQuery.maybeOf(context)?.disableAnimations == true) return;
      if (perfect) {
        _leftFireworks.play();
        _rightFireworks.play();
      } else {
        _celebrationBurst.play();
      }
    });
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('already-exists')) {
      return 'تم احتساب محاولة سابقة لهذه الجلسة';
    }
    if (text.contains('deadline-exceeded')) {
      return 'انتهى وقت التحدي';
    }
    return 'تعذّر حفظ النتيجة. إجاباتك محفوظة على الجهاز، حاول مجددًا';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          title: Text(widget.isPractice ? 'مغامرة التحديات' : 'تحديات جلستك'),
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _resultVisible
                      ? _buildResult()
                      : !_started
                          ? _buildIntro()
                          : _buildQuestion(),
                ),
              ),
              Positioned.fill(child: _buildCelebrationOverlay()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationOverlay() {
    const colors = [
      Color(0xFF14B8A6),
      Color(0xFFF5B942),
      Color(0xFF7C3AED),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
      Color(0xFF22A35A),
    ];

    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              key: const Key('challenge-celebration-burst'),
              confettiController: _celebrationBurst,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 22,
              maxBlastForce: 20,
              minBlastForce: 9,
              gravity: 0.28,
              shouldLoop: false,
              colors: colors,
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              key: const Key('challenge-fireworks-left'),
              confettiController: _leftFireworks,
              blastDirection: pi / 4,
              emissionFrequency: 0.04,
              numberOfParticles: 32,
              maxBlastForce: 25,
              minBlastForce: 12,
              gravity: 0.25,
              shouldLoop: false,
              colors: colors,
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              key: const Key('challenge-fireworks-right'),
              confettiController: _rightFireworks,
              blastDirection: 3 * pi / 4,
              emissionFrequency: 0.04,
              numberOfParticles: 32,
              maxBlastForce: 25,
              minBlastForce: 12,
              gravity: 0.25,
              shouldLoop: false,
              colors: colors,
            ),
          ),
        ],
      ),
    );
  }

  bool get _resultVisible =>
      _practiceCorrect != null || _serverResult != null || _replayCompleted;

  Widget _buildIntro() {
    if (widget.isPractice) return _buildPracticeIntro();

    final challenge = widget.sessionChallenge;
    return Center(
      key: const ValueKey('intro'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F766E),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.extension_rounded,
                    color: _teal,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _replayMode
                      ? 'أعد تحدي جلستك كتدريب'
                      : 'تحدٍ مخصص من ${challenge?.mohaffezName ?? 'محفّظك'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF173B37),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _replayMode
                      ? '${_questions.length} أسئلة من جلستك السابقة لتتدرب عليها مرة أخرى وتثبت ما تعلمته.'
                      : '${_questions.length} أسئلة • الإجابات الموضوعية تُصحح تلقائيًا، والشفهية يعتمدها المحفّظ.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF5D716E),
                  ),
                ),
                if (!widget.isPractice) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(
                        icon: Icons.quiz_outlined,
                        label: '${_questions.length} أسئلة',
                      ),
                      if (!_replayMode)
                        const _InfoPill(
                          icon: Icons.star_outline_rounded,
                          label: '10 نقاط لكل إجابة مؤكدة',
                          color: _gold,
                        ),
                      if (challenge?.expiresAt != null)
                        _InfoPill(
                          icon: Icons.schedule_rounded,
                          label:
                              'متاح حتى ${_timeLabel(challenge!.expiresAt!)}',
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() => _started = true);
                      _persistDraft();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _replayMode ? 'ابدأ التدريب' : 'ابدأ التحدي',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPracticeIntro() {
    const categories = [
      (
        type: ChallengeType.completeAyah,
        icon: Icons.auto_stories_rounded,
        label: 'أكمل الآية',
        color: Color(0xFF7C3AED),
      ),
      (
        type: ChallengeType.nameSurah,
        icon: Icons.menu_book_rounded,
        label: 'اسم السورة',
        color: Color(0xFF0E8278),
      ),
      (
        type: ChallengeType.tajweedRule,
        icon: Icons.record_voice_over_rounded,
        label: 'أحكام التجويد',
        color: Color(0xFFF59E0B),
      ),
      (
        type: ChallengeType.orderAyahs,
        icon: Icons.reorder_rounded,
        label: 'ترتيب الآيات',
        color: Color(0xFF3B82F6),
      ),
      (
        type: ChallengeType.wordMeaning,
        icon: Icons.lightbulb_rounded,
        label: 'معاني الكلمات',
        color: Color(0xFFEC4899),
      ),
      (
        type: ChallengeType.openQuestion,
        icon: Icons.favorite_rounded,
        label: 'مواقف جميلة',
        color: Color(0xFF22A35A),
      ),
    ];

    return Container(
      key: const ValueKey('practice-intro'),
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0FDFA), Color(0xFFFFF8ED)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 24,
            right: 28,
            child: Icon(
              Icons.star_rounded,
              color: Color(0x55F5B942),
              size: 34,
            ),
          ),
          const Positioned(
            top: 92,
            left: 30,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0x447C3AED),
              size: 28,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFD7EAE6)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F0F766E),
                        blurRadius: 30,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [Color(0xFF15A99B), Color(0xFF0F766E)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x3315A99B),
                              blurRadius: 18,
                              offset: Offset(0, 7),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 46,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'جاهز لمغامرة التحديات؟',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF173B37),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'اختر المغامرة التي تحبها وابدأ التحدي!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: Color(0xFF5D716E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final tileWidth = (constraints.maxWidth - 10) / 2;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final category in categories)
                                SizedBox(
                                  width: tileWidth,
                                  child: _PracticeCategoryTile(
                                    icon: category.icon,
                                    label: category.label,
                                    color: category.color,
                                    onTap: () =>
                                        _startPracticeType(category.type),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFE3A6)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFFE69A13),
                              size: 24,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'وفي حلقاتك يصمم لك محفّظك تحديات خاصة تناسب '
                                'تكليفك ومستواك، لتتقدم خطوة بعد خطوة 🌟',
                                style: TextStyle(
                                  height: 1.55,
                                  color: Color(0xFF76551B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            color: _teal,
                            size: 19,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'اضغط على نوع التحدي لتبدأ',
                            style: TextStyle(
                              color: _teal,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'م' : 'ص'}';
  }

  Widget _buildQuestion() {
    final question = _questions[_index];
    final answered = _responses.containsKey(question.id);
    return Column(
      key: ValueKey('question-${question.id}'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '${widget.isPractice ? 'التحدي' : 'السؤال'} '
                    '${_index + 1} من ${_questions.length}',
                    style: const TextStyle(
                      color: Color(0xFF48625E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.isPractice &&
                            question.type == ChallengeType.openQuestion
                        ? 'موقف وتفكير'
                        : ChallengeTypeX(question.type).label,
                    style: const TextStyle(
                      color: _teal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_index + 1) / _questions.length,
                  minHeight: 8,
                  backgroundColor: _border,
                  color: _teal,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          question.question,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontFamilyFallback: [
                              'Noto Naskh Arabic',
                              'Noto Sans Arabic',
                              'Arial',
                            ],
                            fontSize: 21,
                            height: 2,
                            fontWeight: FontWeight.w400,
                            leadingDistribution: TextLeadingDistribution.even,
                            color: Color(0xFF173B37),
                          ),
                          strutStyle: const StrutStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 21,
                            height: 2,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                        ),
                        if (question.hint?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          Text(
                            question.hint!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF8A6A24),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildAnswer(question),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: answered && !_submitting ? _next : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _index == _questions.length - 1
                            ? widget.isPractice
                                ? 'إنهاء المغامرة'
                                : 'إنهاء التحدي'
                            : widget.isPractice
                                ? 'التحدي التالي'
                                : 'السؤال التالي',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswer(ChallengeQuestion question) {
    return switch (question.answerMode) {
      ChallengeAnswerMode.multipleChoice => _buildMultipleChoice(question),
      ChallengeAnswerMode.ordering => _buildOrdering(question),
      ChallengeAnswerMode.oral => _buildOral(question),
      ChallengeAnswerMode.teacherReview => _buildTeacherReview(question),
    };
  }

  Widget _buildMultipleChoice(ChallengeQuestion question) {
    final selected = _responses[question.id] as String?;
    return Column(
      children: question.options.map((option) {
        final isSelected = selected == option.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            button: true,
            selected: isSelected,
            child: InkWell(
              onTap: () => _setResponse(question.id, option.id),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE7F4F1) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? _teal : _border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected ? _teal : const Color(0xFF8BA09C),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option.text,
                        style: const TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontFamilyFallback: [
                            'Noto Naskh Arabic',
                            'Noto Sans Arabic',
                            'Arial',
                          ],
                          fontSize: 16,
                          height: 1.8,
                          fontWeight: FontWeight.w400,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                        strutStyle: const StrutStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 16,
                          height: 1.8,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrdering(ChallengeQuestion question) {
    final draft = _orderDrafts.putIfAbsent(
      question.id,
      () =>
          (_responses[question.id] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          question.options.map((option) => option.id).toList(),
    );
    final byId = {for (final option in question.options) option.id: option};
    return Column(
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: draft.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = draft.removeAt(oldIndex);
              draft.insert(newIndex, item);
              _responses.remove(question.id);
            });
            _persistDraft();
          },
          itemBuilder: (context, index) {
            final id = draft[index];
            return Container(
              key: ValueKey(id),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFE7F4F1),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: _teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      byId[id]?.text ?? id,
                      style: const TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontFamilyFallback: [
                          'Noto Naskh Arabic',
                          'Noto Sans Arabic',
                          'Arial',
                        ],
                        fontSize: 16,
                        height: 1.8,
                        fontWeight: FontWeight.w400,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                      strutStyle: const StrutStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 16,
                        height: 1.8,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ),
                  const Icon(Icons.drag_handle_rounded),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _setResponse(question.id, List<String>.from(draft)),
          icon: const Icon(Icons.check_rounded),
          label: Text(
            _responses.containsKey(question.id)
                ? 'تم اعتماد الترتيب'
                : 'اعتماد هذا الترتيب',
          ),
        ),
      ],
    );
  }

  Widget _buildOral(ChallengeQuestion question) {
    final completed = _responses.containsKey(question.id);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(Icons.record_voice_over_rounded, size: 38, color: _gold),
          const SizedBox(height: 10),
          const Text(
            'أجب شفهيًا أمام محفّظك، ثم أكد إتمام الإجابة. ستبقى النتيجة معلقة حتى يعتمدها.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5, color: Color(0xFF5D716E)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed:
                completed ? null : () => _setResponse(question.id, 'completed'),
            icon: const Icon(Icons.mic_rounded),
            label: Text(completed ? 'تم تسجيل الإجابة' : 'أجبت شفهيًا'),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherReview(ChallengeQuestion question) {
    return TextFormField(
      initialValue: _responses[question.id]?.toString() ?? '',
      minLines: 3,
      maxLines: 6,
      textDirection: TextDirection.rtl,
      onChanged: (value) {
        if (value.trim().isEmpty) {
          setState(() => _responses.remove(question.id));
          _persistDraft();
        } else {
          _setResponse(question.id, value.trim());
        }
      },
      decoration: InputDecoration(
        labelText: 'اكتب إجابتك',
        helperText: 'يراجع المحفّظ هذه الإجابة قبل احتساب النقاط',
        alignLabelWithHint: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final isPractice = widget.isPractice;
    final isReplay = _replayMode;
    final correct = isPractice
        ? _practiceCorrect ?? 0
        : (_serverResult?['correct'] as num?)?.toInt() ?? 0;
    final asked = isPractice
        ? _questions.length
        : (_serverResult?['asked'] as num?)?.toInt() ?? 0;
    final points = (_serverResult?['confirmedPoints'] as num?)?.toInt() ?? 0;
    final pending =
        (_serverResult?['pendingReviewCount'] as num?)?.toInt() ?? 0;
    return Center(
      key: const ValueKey('result'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 8),
                Text(
                  isPractice ? _practiceResultTitle(correct) : 'أحسنت!',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF173B37),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isPractice
                      ? 'أكملت مغامرة ${_selectedPracticeTypeLabel()} وأجبت '
                          '$correct من $asked إجابة صحيحة'
                      : isReplay
                          ? 'أكملت جولة تدريبية جديدة بنجاح'
                          : 'أجبت $correct من $asked إجابة مؤكدة',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF5D716E),
                    fontSize: 15,
                  ),
                ),
                if (!isPractice && !isReplay) ...[
                  const SizedBox(height: 14),
                  _InfoPill(
                    icon: Icons.star_rounded,
                    label: '$points نقطة مؤكدة',
                    color: _gold,
                  ),
                  if (pending > 0) ...[
                    const SizedBox(height: 8),
                    _InfoPill(
                      icon: Icons.hourglass_top_rounded,
                      label: '$pending إجابات بانتظار المحفّظ',
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 16),
                  Text(
                    isReplay
                        ? 'رائع! كل مرة تتدرب فيها يزداد حفظك قوة وثباتًا.'
                        : 'استمر يا بطل! وفي حلقاتك يصمم لك محفّظك تحديات خاصة تناسب تكليفك ومستواك.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      height: 1.6,
                      color: Color(0xFF5D716E),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (isPractice) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _returnToPracticeMenu,
                      style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.grid_view_rounded),
                      label: const Text(
                        'اختر مغامرة أخرى',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _index = 0;
                        _responses.clear();
                        _orderDrafts.clear();
                        _practiceCorrect = null;
                        _started = true;
                      });
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('أعد هذه المغامرة'),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('العودة للرئيسية'),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'العودة للرئيسية',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _replayMode = true;
                        _serverResult = null;
                        _index = 0;
                        _responses.clear();
                        _orderDrafts.clear();
                        _practiceCorrect = null;
                        _replayCompleted = false;
                        _started = true;
                      });
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('إعادة التدريب'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _practiceResultTitle(int correct) {
    if (correct == 3) return 'أنت بطل هذه المغامرة! 🏆';
    if (correct == 2) return 'أداء رائع يا بطل! ⭐';
    if (correct == 1) return 'تقدّم جميل! 🌟';
    return 'بداية موفقة! 🚀';
  }

  String _selectedPracticeTypeLabel() {
    final type = _selectedPracticeType;
    if (type == ChallengeType.openQuestion) return 'مواقف جميلة';
    return type == null ? 'التحديات' : ChallengeTypeX(type).label;
  }
}

class _PracticeCategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PracticeCategoryTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'ابدأ تحديات $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF284A46),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '3 تحديات',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: color,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF0F766E),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

String createChallengeAttemptId({
  Random? random,
  DateTime? now,
}) {
  final generator = random ?? Random.secure();
  final first = generator.nextInt(0x10000).toRadixString(36).padLeft(4, '0');
  final second = generator.nextInt(0x10000).toRadixString(36).padLeft(4, '0');
  final timestamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
  return '$timestamp-$first$second';
}
