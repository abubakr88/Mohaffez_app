import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../data/quran_challenge_generator.dart';
import '../../providers/quiz_access_provider.dart';

class StudentChallengesV2Screen extends ConsumerStatefulWidget {
  final String mohaffezId;
  final String studentId;
  final String? studentProfileId;
  final String studentName;
  final List<Map<String, dynamic>> initialSessions;

  const StudentChallengesV2Screen({
    super.key,
    required this.mohaffezId,
    required this.studentId,
    required this.studentProfileId,
    required this.studentName,
    this.initialSessions = const [],
  });

  @override
  ConsumerState<StudentChallengesV2Screen> createState() =>
      _StudentChallengesV2ScreenState();
}

class _StudentChallengesV2ScreenState
    extends ConsumerState<StudentChallengesV2Screen>
    with SingleTickerProviderStateMixin {
  static const _teal = Color(0xFF0F766E);
  static const _ink = Color(0xFF17211F);
  static const _muted = Color(0xFF66736F);
  static const _surface = Color(0xFFF4F8F7);

  late final ChallengeBankParams _params;
  late final TabController _tabController;
  QuranChallengeGenerator? _quranGenerator;
  late List<Map<String, dynamic>> _sessions;
  List<ChallengeQuestion> _questions = [];
  List<ChallengeQuestion> _generatedQuestions = [];
  final List<String> _draftOrder = [];
  final List<String> _publishOrder = [];
  final Map<String, ChallengeQuestion> _confirmedQuestionsById = {};
  final Set<int> _selectedSurahs = {1};
  final Set<ChallengeType> _generatedTypes = {
    ChallengeType.nameSurah,
    ChallengeType.completeAyah,
    ChallengeType.orderAyahs,
  };
  final Map<String, Map<String, bool>> _reviewVerdicts = {};

  _ChallengeBankView _bankView = _ChallengeBankView.quran;
  int _suggestedCount = 7;
  int _shuffleCounter = 0;
  int _quranLoadRequest = 0;
  int? _coverageJuz;
  int? _coverageFromAyah;
  int? _coverageToAyah;
  bool _loading = false;
  bool _loadingQuran = true;
  bool _customBankLoaded = false;
  bool _saving = false;
  bool _publishing = false;
  bool _refreshingSessions = false;
  bool _importingLegacy = false;
  bool _dirty = false;
  String? _error;
  String? _selectedSessionId;
  String _search = '';
  ChallengeType? _typeFilter;
  String? _difficultyFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _params = (
      mohaffezId: widget.mohaffezId,
      studentId: widget.studentId,
      studentProfileId: widget.studentProfileId,
    );
    _sessions = widget.initialSessions.map(Map<String, dynamic>.from).toList();
    _selectDefaultSession();
    _loadQuranGenerator(_selectedSurahs);
    if (_sessions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshSessions();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _acceptedSessions {
    final normalizedProfile = _normalizeProfile(widget.studentProfileId);
    final now = DateTime.now();
    final result = _sessions.where((session) {
      final start = _sessionStart(session);
      final end = _sessionEnd(session);
      return session['status'] == 'accepted' &&
          _normalizeProfile(session['studentProfileId'] as String?) ==
              normalizedProfile &&
          start != null &&
          end != null &&
          end.isAfter(now);
    }).toList();
    result.sort((a, b) {
      return _sessionStart(a)!.compareTo(_sessionStart(b)!);
    });
    return result.take(1).toList(growable: false);
  }

  List<ChallengeQuestion> get _filteredQuestions {
    final query = _search.trim().toLowerCase();
    return _questions.where((question) {
      final matchesSearch = query.isEmpty ||
          question.question.toLowerCase().contains(query) ||
          (question.hint ?? '').toLowerCase().contains(query);
      return matchesSearch &&
          (_typeFilter == null || question.type == _typeFilter) &&
          (_difficultyFilter == null ||
              question.difficulty == _difficultyFilter);
    }).toList();
  }

  List<ChallengeQuestion> get _allAvailableQuestions => [
        ..._generatedQuestions,
        ..._questions.where((question) => question.isActive),
      ];

  Set<String> get _draftSelection => _draftOrder.toSet();

  List<ChallengeQuestion> get _draftSelectedQuestions {
    final byId = {
      for (final question in _allAvailableQuestions) question.id: question,
    };
    return _draftOrder
        .map((id) => byId[id])
        .whereType<ChallengeQuestion>()
        .toList();
  }

  List<ChallengeQuestion> get _selectedQuestions => _publishOrder
      .map((id) => _confirmedQuestionsById[id])
      .whereType<ChallengeQuestion>()
      .toList();

  QuranChallengeScope get _quranScope => QuranChallengeScope(
        juzNumber: _coverageJuz,
        fromAyah: _coverageFromAyah,
        toAyah: _coverageToAyah,
      );

  void _selectDefaultSession() {
    final accepted = _acceptedSessions;
    final nextId = accepted.isEmpty ? null : accepted.first['id'] as String?;
    if (_selectedSessionId != nextId) {
      _selectedSessionId = nextId;
      _draftOrder.clear();
      _publishOrder.clear();
      _confirmedQuestionsById.clear();
      _shuffleCounter = 0;
    }
  }

  Future<void> _loadBank() async {
    if (_loading || _customBankLoaded) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final questions =
          await ref.read(studentChallengeBankProvider(_params).future);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _customBankLoaded = true;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<bool> _saveBank() async {
    if (!_dirty) return true;
    setState(() => _saving = true);
    try {
      await saveChallengeBank(params: _params, questions: _questions);
      ref.invalidate(studentChallengeBankProvider(_params));
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      _showMessage('تم حفظ كل تغييرات البنك في كتابة واحدة');
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _saving = false);
      _showMessage('تعذر حفظ بنك الأسئلة: $error', error: true);
      return false;
    }
  }

  Future<void> _openEditor([ChallengeQuestion? existing]) async {
    if (existing == null && _questions.length >= maxChallengeBankQuestions) {
      _showMessage('الحد الأقصى للبنك 30 سؤالًا', error: true);
      return;
    }
    final result = await Navigator.of(context).push<_QuestionEditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _QuestionEditorScreen(existing: existing),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final index =
          _questions.indexWhere((item) => item.id == result.question.id);
      if (index == -1) {
        _questions.add(result.question);
      } else {
        _questions[index] = result.question;
      }
      if (result.addToCurrentSession &&
          _draftOrder.length < maxPublishedChallengeQuestions) {
        _draftOrder.add(result.question.id);
      }
      _dirty = true;
    });
  }

  Future<void> _importLegacyUnassigned() async {
    setState(() => _importingLegacy = true);
    try {
      final legacy = await loadLegacyUnassignedChallengeBank(
        mohaffezId: widget.mohaffezId,
        studentId: widget.studentId,
      );
      if (!mounted) return;
      if (legacy.isEmpty) {
        setState(() => _importingLegacy = false);
        _showMessage('لا توجد أسئلة قديمة غير معيّنة');
        return;
      }
      final room = maxChallengeBankQuestions - _questions.length;
      final existingIds = _questions.map((question) => question.id).toSet();
      final imported = legacy.take(room).map((question) {
        return existingIds.contains(question.id)
            ? question.copyWithId(_newQuestionId())
            : question;
      }).toList();
      setState(() {
        _questions.addAll(imported);
        _importingLegacy = false;
        _dirty = imported.isNotEmpty || _dirty;
      });
      _showMessage(
        imported.isEmpty
            ? 'البنك ممتلئ؛ لم يتم استيراد أسئلة'
            : 'تمت إضافة ${imported.length} أسئلة محليًا؛ احفظ لتثبيتها لهذا الطفل',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _importingLegacy = false);
      _showMessage('تعذر قراءة الأسئلة القديمة: $error', error: true);
    }
  }

  void _duplicate(ChallengeQuestion question) {
    if (_questions.length >= maxChallengeBankQuestions) {
      _showMessage('الحد الأقصى للبنك 30 سؤالًا', error: true);
      return;
    }
    final copy = ChallengeQuestion(
      id: _newQuestionId(),
      type: question.type,
      answerMode: question.answerMode,
      source: 'teacher_bank',
      question: '${question.question} (نسخة)',
      hint: question.hint,
      answer: question.answer,
      options: question.options,
      correctOptionId: question.correctOptionId,
      correctOrder: question.correctOrder,
      difficulty: question.difficulty,
      isActive: question.isActive,
      createdAt: DateTime.now(),
    );
    setState(() {
      _questions.add(copy);
      _dirty = true;
    });
  }

  void _delete(ChallengeQuestion question) {
    setState(() {
      _questions.removeWhere((item) => item.id == question.id);
      _draftOrder.remove(question.id);
      _dirty = true;
    });
  }

  void _setQuestionSelected(ChallengeQuestion question, bool selected) {
    setState(() {
      if (selected) {
        if (_draftOrder.length < maxPublishedChallengeQuestions &&
            !_draftOrder.contains(question.id)) {
          _draftOrder.add(question.id);
        }
      } else {
        _draftOrder.remove(question.id);
      }
    });
  }

  Future<void> _loadQuranGenerator(
    Set<int> surahs, {
    bool commitSelection = false,
  }) async {
    final request = ++_quranLoadRequest;
    final replacingExisting = _quranGenerator != null;
    setState(() {
      _loadingQuran = true;
      if (!replacingExisting) _error = null;
    });
    try {
      final generator = await QuranChallengeGenerator.load(surahs);
      if (!mounted || request != _quranLoadRequest) return;
      setState(() {
        if (commitSelection) {
          _selectedSurahs
            ..clear()
            ..addAll(surahs);
          _coverageJuz = null;
          _coverageFromAyah = null;
          _coverageToAyah = null;
        }
        _quranGenerator = generator;
        _loadingQuran = false;
        _refreshGeneratedQuestions();
      });
    } catch (error) {
      if (!mounted || request != _quranLoadRequest) return;
      setState(() {
        _loadingQuran = false;
        if (!replacingExisting) _error = error.toString();
      });
      if (replacingExisting) {
        _showMessage('تعذر تحميل السور المختارة، حاول مرة أخرى', error: true);
      }
    }
  }

  void _refreshGeneratedQuestions() {
    final generator = _quranGenerator;
    if (generator == null) return;
    final generated = _selectedSurahs
        .expand(
          (surah) => generator.candidatesForSurah(
            surah,
            types: _generatedTypes,
            scope: _quranScope,
          ),
        )
        .toList();
    final validIds = generated.map((question) => question.id).toSet();
    _generatedQuestions = generated;
    _draftOrder.removeWhere(
      (id) => id.startsWith('qv') && !validIds.contains(id),
    );
  }

  void _suggestQuestions() {
    final generator = _quranGenerator;
    if (generator == null || _loadingQuran) return;
    final customIds = _draftSelectedQuestions
        .where((question) => question.source != quranGeneratedQuestionSource)
        .map((question) => question.id)
        .take(_suggestedCount)
        .toList();
    final generatedCount = _suggestedCount - customIds.length;
    final suggested = generatedCount == 0
        ? const <ChallengeQuestion>[]
        : generator.suggest(
            surahNumbers: _selectedSurahs,
            types: _generatedTypes,
            count: generatedCount,
            seed: '${_selectedSessionId ?? 'no-session'}:${_shuffleCounter++}',
            scope: _quranScope,
          );
    setState(() {
      _draftOrder
        ..clear()
        ..addAll(customIds)
        ..addAll(suggested.map((question) => question.id));
    });
    if (_draftOrder.length < _suggestedCount) {
      _showMessage(
        'توفر ${_draftOrder.length} أسئلة فقط لهذه الاختيارات؛ اختر سورة أو نوعًا إضافيًا.',
        error: true,
      );
    }
  }

  void _confirmTestSelection() {
    final draft = _draftSelectedQuestions;
    final count = draft.length;
    if (count < minPublishedChallengeQuestions ||
        count > maxPublishedChallengeQuestions) {
      _showMessage(
        'اختر من $minPublishedChallengeQuestions إلى '
        '$maxPublishedChallengeQuestions أسئلة لتأكيد الاختبار.',
        error: true,
      );
      return;
    }
    setState(() {
      _publishOrder
        ..clear()
        ..addAll(draft.map((question) => question.id));
      _confirmedQuestionsById
        ..clear()
        ..addEntries(
          draft.map((question) => MapEntry(question.id, question)),
        );
    });
    _tabController.animateTo(1);
  }

  void _replaceGeneratedQuestion(ChallengeQuestion question) {
    final generator = _quranGenerator;
    if (generator == null || _loadingQuran) return;
    final replacement = generator.suggest(
      surahNumbers: _selectedSurahs,
      types: _generatedTypes,
      count: 1,
      seed:
          '${_selectedSessionId ?? 'no-session'}:replace:${_shuffleCounter++}',
      scope: _quranScope,
      excludedIds: {
        ..._draftOrder,
        ..._publishOrder,
      },
    );
    if (replacement.isEmpty) {
      _showMessage('لا يوجد سؤال بديل ضمن الفلاتر الحالية', error: true);
      return;
    }
    setState(() {
      final index = _publishOrder.indexOf(question.id);
      if (index != -1) {
        _publishOrder[index] = replacement.single.id;
        _confirmedQuestionsById
          ..remove(question.id)
          ..[replacement.single.id] = replacement.single;
      }
    });
  }

  void _removeConfirmedQuestion(ChallengeQuestion question) {
    setState(() {
      _publishOrder.remove(question.id);
      _confirmedQuestionsById.remove(question.id);
    });
  }

  void _movePublishedQuestion(int index, int offset) {
    final destination = index + offset;
    if (destination < 0 || destination >= _publishOrder.length) return;
    setState(() {
      final id = _publishOrder.removeAt(index);
      _publishOrder.insert(destination, id);
    });
  }

  Future<void> _pickSurahs() async {
    final generator = _quranGenerator;
    if (generator == null || _loadingQuran) return;
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _SurahPickerDialog(
        generator: generator,
        initialSelection: _selectedSurahs,
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    await _loadQuranGenerator(result, commitSelection: true);
  }

  void _move(ChallengeQuestion question, int offset) {
    final index = _questions.indexOf(question);
    final destination = index + offset;
    if (destination < 0 || destination >= _questions.length) return;
    setState(() {
      final item = _questions.removeAt(index);
      _questions.insert(destination, item);
      _dirty = true;
    });
  }

  Future<void> _publish() async {
    final sessionId = _selectedSessionId;
    if (sessionId == null) {
      _showMessage('اختر جلسة مقبولة أولًا', error: true);
      return;
    }
    final selected = _selectedQuestions;
    if (selected.length < minPublishedChallengeQuestions ||
        selected.length > maxPublishedChallengeQuestions) {
      _showMessage('اختر من 5 إلى 10 أسئلة مفعّلة', error: true);
      return;
    }
    if (!await _saveBank()) return;

    setState(() => _publishing = true);
    try {
      final response = await publishSessionChallenge(
        sessionId: sessionId,
        studentId: widget.studentId,
        studentProfileId: widget.studentProfileId,
        questions: selected,
      );
      if (!mounted) return;
      setState(() {
        _publishing = false;
        final index = _sessions.indexWhere((item) => item['id'] == sessionId);
        if (index != -1) {
          _sessions[index] = {
            ..._sessions[index],
            'challengeAccess': {
              'status': 'open',
              'questionCount': selected.length,
              'setVersion': response['setVersion'],
              'studentProfileId': widget.studentProfileId ?? 'self',
            },
          };
        }
      });
      _showMessage('تم نشر ${selected.length} أسئلة للجلسة بنجاح');
    } catch (error) {
      if (!mounted) return;
      setState(() => _publishing = false);
      _showMessage('تعذر نشر التحدي: $error', error: true);
    }
  }

  Future<void> _refreshSessions() async {
    setState(() => _refreshingSessions = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('mohaffezId', isEqualTo: widget.mohaffezId)
          .where('studentId', isEqualTo: widget.studentId)
          .limit(20)
          .get();
      final sessions = snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          ...data,
          'id': doc.id,
          'sessionDate': _date(data['sessionDate']),
        };
      }).toList();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _refreshingSessions = false;
        _selectDefaultSession();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _refreshingSessions = false);
      _showMessage('تعذر تحديث الجلسات: $error', error: true);
    }
  }

  Future<void> _reviewSession(Map<String, dynamic> session) async {
    final sessionId = session['id'] as String? ?? '';
    final pendingIds = _pendingIds(session);
    final verdicts = _reviewVerdicts[sessionId] ?? const <String, bool>{};
    if (pendingIds.any((id) => !verdicts.containsKey(id))) {
      _showMessage('اعتمد أو ارفض كل الإجابات أولًا', error: true);
      return;
    }
    try {
      await reviewSessionChallenge(
        sessionId: sessionId,
        verdicts: {for (final id in pendingIds) id: verdicts[id]!},
      );
      if (!mounted) return;
      setState(() {
        final index = _sessions.indexWhere((item) => item['id'] == sessionId);
        if (index != -1) {
          final oldResult = Map<String, dynamic>.from(
            _sessions[index]['challengeResult'] as Map? ?? const {},
          );
          _sessions[index] = {
            ..._sessions[index],
            'challengeResult': {
              ...oldResult,
              'pendingReview': false,
              'pendingQuestionIds': <String>[],
              'reviewVerdicts': verdicts,
            },
          };
        }
      });
      _showMessage('تم اعتماد المجموعة في استدعاء واحد');
    } catch (error) {
      if (!mounted) return;
      _showMessage('تعذر اعتماد الإجابات: $error', error: true);
    }
  }

  void _showMessage(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, textDirection: TextDirection.rtl),
          backgroundColor: error ? const Color(0xFFB42318) : _teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: _surface,
          appBar: AppBar(
            centerTitle: true,
            title: Text(
              'تحديات ${widget.studentName.trim()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFFC4E5E0),
              tabs: const [
                Tab(
                    text: 'بنك الأسئلة',
                    icon: Icon(Icons.inventory_2_outlined)),
                Tab(text: 'تحدي الجلسة', icon: Icon(Icons.bolt_rounded)),
                Tab(
                    text: 'تحتاج مراجعة',
                    icon: Icon(Icons.fact_check_outlined)),
              ],
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(message: _error!, onRetry: _loadBank)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBankTab(),
                        _buildPublishTab(),
                        _buildReviewTab(),
                      ],
                    ),
          floatingActionButton: _loading ||
                  _error != null ||
                  _bankView != _ChallengeBankView.custom ||
                  !_customBankLoaded
              ? null
              : FloatingActionButton.extended(
                  onPressed: _openEditor,
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('سؤال جديد'),
                ),
        ),
      ),
    );
  }

  Widget _buildBankTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<_ChallengeBankView>(
              segments: const [
                ButtonSegment(
                  value: _ChallengeBankView.quran,
                  icon: Icon(Icons.menu_book_rounded),
                  label: Text('بنك الأسئلة القرآنية'),
                ),
                ButtonSegment(
                  value: _ChallengeBankView.custom,
                  icon: Icon(Icons.person_outline_rounded),
                  label: Text('الأسئلة الخاصة'),
                ),
              ],
              selected: {_bankView},
              onSelectionChanged: (selection) {
                setState(() => _bankView = selection.first);
                if (_bankView == _ChallengeBankView.custom) {
                  _loadBank();
                }
              },
            ),
          ),
        ),
        Expanded(
          child: _bankView == _ChallengeBankView.quran
              ? _buildQuranBankTab()
              : _buildCustomBankTab(),
        ),
      ],
    );
  }

  Widget _buildQuranBankTab() {
    final generator = _quranGenerator;
    if (generator == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loadingQuran) const CircularProgressIndicator(),
            if (_loadingQuran) const SizedBox(height: 12),
            Text(
              _loadingQuran
                  ? 'جارٍ تحميل السورة المختارة من الأصول المحلية…'
                  : 'تعذر تحميل الأسئلة القرآنية',
            ),
            if (!_loadingQuran)
              TextButton.icon(
                onPressed: () => _loadQuranGenerator(_selectedSurahs),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
          ],
        ),
      );
    }
    final selectedIds = _draftSelection;
    final selectedSurahNames = _selectedSurahs.toList()..sort();
    final surahSummary =
        selectedSurahNames.take(3).map(generator.surahName).join('، ');
    final extraSurahs = selectedSurahNames.length - 3;
    final availableJuz = _selectedSurahs
        .expand(generator.juzNumbersForSurah)
        .toSet()
        .toList()
      ..sort();
    final singleSurah =
        _selectedSurahs.length == 1 ? _selectedSurahs.single : null;
    final singleSurahVerseCount =
        singleSurah == null ? null : generator.verseCount(singleSurah);

    return CustomScrollView(
      key: const PageStorageKey<String>('quran-question-bank-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                const _InfoCard(
                  icon: Icons.auto_awesome_rounded,
                  title: 'أسئلة قرآنية جاهزة للجلسة',
                  body:
                      'اختر السور وأنواع الأسئلة المناسبة للطالب، ثم اقترح مجموعة وراجعها قبل نشر التحدي.',
                ),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading:
                      const Icon(Icons.library_books_outlined, color: _teal),
                  title: Text(
                    selectedSurahNames.length == 1
                        ? surahSummary
                        : '${selectedSurahNames.length} سور مختارة',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    extraSurahs > 0
                        ? '$surahSummary و$extraSurahs أخرى'
                        : 'اضغط لاختيار سورة أو أكثر',
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: _pickSurahs,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'التغطية:',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      ChoiceChip(
                        label: const Text('السورة كاملة'),
                        selected:
                            _coverageJuz == null && _coverageFromAyah == null,
                        onSelected: (_) {
                          setState(() {
                            _coverageJuz = null;
                            _coverageFromAyah = null;
                            _coverageToAyah = null;
                            _refreshGeneratedQuestions();
                          });
                        },
                      ),
                      for (final juz in availableJuz)
                        ChoiceChip(
                          label: Text('الجزء $juz'),
                          selected: _coverageJuz == juz,
                          onSelected: (_) {
                            setState(() {
                              _coverageJuz = juz;
                              _coverageFromAyah = null;
                              _coverageToAyah = null;
                              _refreshGeneratedQuestions();
                            });
                          },
                        ),
                    ],
                  ),
                ),
              if (singleSurahVerseCount != null &&
                  singleSurahVerseCount > 1 &&
                  _coverageJuz == null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'نطاق الآيات: '
                        '${_coverageFromAyah ?? 1}–'
                        '${_coverageToAyah ?? singleSurahVerseCount}',
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (_coverageFromAyah != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _coverageFromAyah = null;
                              _coverageToAyah = null;
                              _refreshGeneratedQuestions();
                            });
                          },
                          child: const Text('إعادة الضبط'),
                        ),
                    ],
                  ),
                  RangeSlider(
                    min: 1,
                    max: singleSurahVerseCount.toDouble(),
                    divisions: singleSurahVerseCount - 1,
                    labels: RangeLabels(
                      '${_coverageFromAyah ?? 1}',
                      '${_coverageToAyah ?? singleSurahVerseCount}',
                    ),
                    values: RangeValues(
                      (_coverageFromAyah ?? 1).toDouble(),
                      (_coverageToAyah ?? singleSurahVerseCount).toDouble(),
                    ),
                    onChanged: (values) {
                      setState(() {
                        _coverageJuz = null;
                        _coverageFromAyah = values.start.round();
                        _coverageToAyah = values.end.round();
                      });
                    },
                    onChangeEnd: (_) {
                      setState(_refreshGeneratedQuestions);
                    },
                  ),
                ],
                if (_loadingQuran) ...[
                  const SizedBox(height: 4),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        QuranChallengeGenerator.generatedTypes.map((type) {
                      return FilterChip(
                        selected: _generatedTypes.contains(type),
                        label: Text(type.label),
                        onSelected: (selected) {
                          if (!selected && _generatedTypes.length == 1) {
                            _showMessage(
                              'يجب إبقاء نوع سؤال واحد على الأقل',
                              error: true,
                            );
                            return;
                          }
                          setState(() {
                            if (selected) {
                              _generatedTypes.add(type);
                            } else {
                              _generatedTypes.remove(type);
                            }
                            _refreshGeneratedQuestions();
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'عدد الاقتراح:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<int>(
                      value: _suggestedCount,
                      items: [
                        for (var count = minPublishedChallengeQuestions;
                            count <= maxPublishedChallengeQuestions;
                            count++)
                          DropdownMenuItem(value: count, child: Text('$count')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _suggestedCount = value);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loadingQuran ? null : _suggestQuestions,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('اقتراح مجموعة'),
                        style: FilledButton.styleFrom(backgroundColor: _teal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loadingQuran ? null : _confirmTestSelection,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('تأكيد الاختبار'),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_generatedQuestions.length} سؤالًا متاحًا • '
                    '${_draftSelectedQuestions.length}/$maxPublishedChallengeQuestions اختيار مبدئي',
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final question = _generatedQuestions[index];
                final orderingRange = _orderingAyahRange(question);
                final location = generator.locationFor(
                  question.surahNumber!,
                  question.anchorAyah!,
                );
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 9),
                  child: CheckboxListTile(
                    value: selectedIds.contains(question.id),
                    onChanged: (selectedIds.contains(question.id) ||
                            _draftOrder.length < maxPublishedChallengeQuestions)
                        ? (value) =>
                            _setQuestionSelected(question, value == true)
                        : null,
                    activeColor: _teal,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.question,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontFamilyFallback: [
                              'Noto Naskh Arabic',
                              'Noto Sans Arabic',
                              'Arial',
                            ],
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            height: 1.9,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                          strutStyle: const StrutStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 17,
                            height: 1.9,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                        ),
                        if (orderingRange != null) ...[
                          const SizedBox(height: 4),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE4F3F1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              child: Text(
                                orderingRange,
                                style: const TextStyle(
                                  color: _teal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${question.type.label} • '
                      '${generator.surahName(question.surahNumber!)} • '
                      'الجزء ${location.juzNumber} • '
                      'الصفحة ${location.pageNumber}',
                    ),
                    secondary: const Icon(
                      Icons.offline_bolt_rounded,
                      color: _teal,
                    ),
                  ),
                );
              },
              childCount: _generatedQuestions.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomBankTab() {
    final visible = _filteredQuestions;
    return Column(
      children: [
        if (_dirty)
          MaterialBanner(
            content: const Text(
              'التعديلات محلية الآن؛ لن تُرسل كتابة عند كل تغيير.',
            ),
            leading: const Icon(Icons.savings_outlined, color: _teal),
            actions: [
              TextButton(
                onPressed: _saving ? null : _saveBank,
                child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ التغييرات'),
              ),
            ],
          ),
        if (_normalizeProfile(widget.studentProfileId) != 'self')
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.archive_outlined, color: Color(0xFF9A6700)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'لديك حساب ولي أمر؟ يمكنك استيراد الأسئلة القديمة غير المعيّنة لهذا الطفل.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
                TextButton(
                  onPressed: _importingLegacy ? null : _importLegacyUnassigned,
                  child: Text(_importingLegacy ? 'جارٍ…' : 'استيراد'),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  hintText: 'ابحث في السؤال أو التلميح',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DropdownButton<ChallengeType?>(
                      value: _typeFilter,
                      hint: const Text('كل الأنواع'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('كل الأنواع'),
                        ),
                        ...ChallengeType.values.map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _typeFilter = value),
                    ),
                    const SizedBox(width: 18),
                    DropdownButton<String?>(
                      value: _difficultyFilter,
                      hint: const Text('كل الصعوبات'),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('كل الصعوبات'),
                        ),
                        DropdownMenuItem(value: 'easy', child: Text('سهل')),
                        DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                        DropdownMenuItem(value: 'hard', child: Text('صعب')),
                      ],
                      onChanged: (value) =>
                          setState(() => _difficultyFilter = value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${_questions.length}/$maxChallengeBankQuestions سؤالًا',
                style: const TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: visible.isEmpty
                    ? null
                    : () {
                        setState(() {
                          for (final question in visible) {
                            final index = _questions.indexOf(question);
                            _questions[index] =
                                question.copyWith(isActive: true);
                          }
                          _dirty = true;
                        });
                      },
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('تفعيل الظاهر'),
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const _EmptyView(
                  icon: Icons.quiz_outlined,
                  title: 'لا توجد أسئلة مطابقة',
                  subtitle: 'أضف سؤالًا جديدًا أو غيّر عوامل التصفية.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final question = visible[index];
                    final originalIndex = _questions.indexOf(question);
                    return _QuestionCard(
                      question: question,
                      selected: _draftSelection.contains(question.id),
                      canSelect:
                          _draftOrder.length < maxPublishedChallengeQuestions,
                      onSelected: (selected) =>
                          _setQuestionSelected(question, selected),
                      onActiveChanged: (active) {
                        setState(() {
                          _questions[originalIndex] =
                              question.copyWith(isActive: active);
                          if (!active) {
                            _draftOrder.remove(question.id);
                          }
                          _dirty = true;
                        });
                      },
                      onEdit: () => _openEditor(question),
                      onDuplicate: () => _duplicate(question),
                      onDelete: () => _delete(question),
                      onMoveUp:
                          originalIndex == 0 ? null : () => _move(question, -1),
                      onMoveDown: originalIndex == _questions.length - 1
                          ? null
                          : () => _move(question, 1),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPublishTab() {
    final sessions = _acceptedSessions;
    final selected = _selectedQuestions;
    final selectedCount = selected.length;
    final selectedSession = sessions
        .where((session) => session['id'] == _selectedSessionId)
        .firstOrNull;
    final access = selectedSession?['challengeAccess'] as Map?;
    final alreadyPublished = access?['status'] == 'open';
    final selectedResult = selectedSession?['challengeResult'] as Map?;
    final alreadyScored =
        (selectedResult?['scoredAttemptId'] as String?)?.isNotEmpty == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _InfoCard(
          icon: Icons.fact_check_outlined,
          title: 'راجع الاختبار قبل نشره',
          body:
              'اختر من 5 إلى 10 أسئلة مناسبة للطالب، ثم راجع ترتيبها وانشرها للجلسة القادمة.',
        ),
        const SizedBox(height: 16),
        Text(
          'الجلسة القادمة',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: _ink),
        ),
        const SizedBox(height: 8),
        if (sessions.isEmpty)
          const _EmptyView(
            icon: Icons.event_busy_outlined,
            title: 'لا توجد جلسة قادمة',
            subtitle: 'يمكن نشر الاختبار بعد حجز جلسة قادمة لهذا الطالب.',
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD6E3E0)),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F7F3),
                child: Icon(Icons.event_available_rounded, color: _teal),
              ),
              title: const Text(
                'موعد الجلسة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                _sessionLabel(sessions.first),
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
              trailing: const Icon(Icons.lock_outline_rounded, color: _muted),
            ),
          ),
        if (alreadyPublished || alreadyScored) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F7F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              alreadyScored
                  ? 'اكتملت محاولة النقاط لهذه الجلسة. يمكن للطالب إعادة الأسئلة كتدريب محلي فقط.'
                  : 'التحدي منشور حاليًا (${access?['questionCount'] ?? 0} أسئلة). '
                      'النشر مرة أخرى ينشئ إصدارًا جديدًا ولا يتأثر بتعديلات البنك غير المنشورة.',
              style: const TextStyle(color: _teal, height: 1.45),
            ),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Text(
              'الأسئلة المختارة',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: _ink),
            ),
            const Spacer(),
            Text(
              '$selectedCount / $maxPublishedChallengeQuestions',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selectedCount >= minPublishedChallengeQuestions
                    ? _teal
                    : const Color(0xFFB54708),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (selected.isEmpty)
          const _EmptyView(
            icon: Icons.playlist_add_rounded,
            title: 'لم تختر أسئلة بعد',
            subtitle:
                'استخدم بنك الأسئلة القرآنية لاقتراح مجموعة، أو اختر من أسئلة الطالب الخاصة.',
          )
        else
          ...selected.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final generated = question.source == quranGeneratedQuestionSource;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  question.question,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: generated
                      ? const TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontFamilyFallback: [
                            'Noto Naskh Arabic',
                            'Noto Sans Arabic',
                            'Arial',
                          ],
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.9,
                          leadingDistribution: TextLeadingDistribution.even,
                        )
                      : null,
                  strutStyle: generated
                      ? const StrutStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 16,
                          height: 1.9,
                          leadingDistribution: TextLeadingDistribution.even,
                        )
                      : null,
                ),
                subtitle: Text(
                  '${question.type.label} • '
                  '${generated ? 'سؤال قرآني' : 'سؤال خاص'}',
                ),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    if (generated)
                      IconButton(
                        onPressed: () => _replaceGeneratedQuestion(question),
                        tooltip: 'استبدال بسؤال آخر',
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    IconButton(
                      onPressed: index == 0
                          ? null
                          : () => _movePublishedQuestion(index, -1),
                      tooltip: 'تحريك لأعلى',
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    ),
                    IconButton(
                      onPressed: index == selected.length - 1
                          ? null
                          : () => _movePublishedQuestion(index, 1),
                      tooltip: 'تحريك لأسفل',
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                    IconButton(
                      onPressed: () => _removeConfirmedQuestion(question),
                      tooltip: 'إزالة من الجلسة',
                      color: const Color(0xFFB42318),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _publishing || alreadyScored ? null : _publish,
          icon: _publishing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(alreadyPublished
                  ? Icons.refresh_rounded
                  : Icons.publish_rounded),
          label: Text(
            _publishing
                ? 'جارٍ النشر…'
                : alreadyScored
                    ? 'تم احتساب محاولة الجلسة'
                    : alreadyPublished
                        ? 'إعادة نشر التحدي'
                        : 'نشر تحدي الجلسة',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _teal,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewTab() {
    final pendingSessions =
        _sessions.where((session) => _pendingIds(session).isNotEmpty).toList();
    return RefreshIndicator(
      onRefresh: _refreshSessions,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: _InfoCard(
                  icon: Icons.rule_folder_outlined,
                  title: 'اعتماد جماعي',
                  body:
                      'اعتمد كل الإجابات الشفهية والمفتوحة للمجموعة ثم أرسلها في استدعاء واحد.',
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _refreshingSessions ? null : _refreshSessions,
                tooltip: 'تحديث يدوي دون مستمع',
                icon: _refreshingSessions
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pendingSessions.isEmpty)
            const _EmptyView(
              icon: Icons.task_alt_rounded,
              title: 'لا توجد إجابات معلقة',
              subtitle:
                  'هذه القائمة لا تستخدم مستمعًا حيًا؛ استخدم التحديث اليدوي عند الحاجة.',
            )
          else
            ...pendingSessions.map(_buildReviewSessionCard),
        ],
      ),
    );
  }

  Widget _buildReviewSessionCard(Map<String, dynamic> session) {
    final sessionId = session['id'] as String? ?? '';
    final pendingIds = _pendingIds(session);
    final result = Map<String, dynamic>.from(
      session['challengeResult'] as Map? ?? const {},
    );
    final responses = Map<String, dynamic>.from(
      result['responses'] as Map? ?? const {},
    );
    final questionMaps = (session['challengeSet'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final verdicts = _reviewVerdicts.putIfAbsent(sessionId, () => {});

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sessionLabel(session),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Divider(height: 24),
            ...pendingIds.map((id) {
              final question =
                  questionMaps.where((item) => item['id'] == id).firstOrNull;
              final answer = responses[id];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question?['question'] as String? ?? 'سؤال شفهي',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      answer == null || answer.toString().trim().isEmpty
                          ? 'أجاب الطالب شفهيًا أثناء الجلسة'
                          : 'إجابة الطالب: $answer',
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('صحيحة'),
                          icon: Icon(Icons.check_rounded),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('غير صحيحة'),
                          icon: Icon(Icons.close_rounded),
                        ),
                      ],
                      selected: verdicts.containsKey(id)
                          ? <bool>{verdicts[id]!}
                          : const <bool>{},
                      emptySelectionAllowed: true,
                      onSelectionChanged: (selection) {
                        if (selection.isEmpty) return;
                        setState(() => verdicts[id] = selection.first);
                      },
                    ),
                  ],
                ),
              );
            }),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _reviewSession(session),
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('اعتماد كل الإجابات'),
                style: FilledButton.styleFrom(backgroundColor: _teal),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _pendingIds(Map<String, dynamic> session) {
    final result = session['challengeResult'];
    if (result is! Map || result['pendingReview'] != true) return const [];
    return (result['pendingQuestionIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
  }

  static String _normalizeProfile(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty || cleaned == 'self'
        ? 'self'
        : cleaned;
  }

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static DateTime? _sessionStart(Map<String, dynamic> session) =>
      _date(session['slotStart']) ?? _date(session['sessionDate']);

  static DateTime? _sessionEnd(Map<String, dynamic> session) {
    final explicitEnd = _date(session['slotEnd']);
    if (explicitEnd != null) return explicitEnd;
    final start = _sessionStart(session);
    if (start == null) return null;
    final duration = (session['sessionDurationMinutes'] as num?)?.toInt() ?? 60;
    return start.add(Duration(minutes: duration.clamp(15, 240)));
  }

  static String? _orderingAyahRange(ChallengeQuestion question) {
    final start = question.anchorAyah;
    if (question.type != ChallengeType.orderAyahs ||
        start == null ||
        question.options.isEmpty) {
      return null;
    }
    final end = start + question.options.length - 1;
    return 'نطاق السؤال: الآيات $start–$end';
  }

  static String _sessionLabel(Map<String, dynamic> session) {
    final date = _sessionStart(session)?.toLocal();
    if (date == null) return 'موعد الجلسة القادمة';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} • $hour:$minute';
  }
}

enum _ChallengeBankView { quran, custom }

class _SurahPickerDialog extends StatefulWidget {
  final QuranChallengeGenerator generator;
  final Set<int> initialSelection;

  const _SurahPickerDialog({
    required this.generator,
    required this.initialSelection,
  });

  @override
  State<_SurahPickerDialog> createState() => _SurahPickerDialogState();
}

class _SurahPickerDialogState extends State<_SurahPickerDialog> {
  late final Set<int> _selection;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selection = {...widget.initialSelection};
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.trim();
    final visible = [
      for (var number = 1; number <= 114; number++)
        if (query.isEmpty ||
            '$number'.contains(query) ||
            widget.generator.surahName(number).contains(query))
          number,
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('اختر السور'),
        content: SizedBox(
          width: 560,
          height: 520,
          child: Column(
            children: [
              TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _search = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'ابحث باسم السورة أو رقمها',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${_selection.length} مختارة'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _selection
                        ..clear()
                        ..addAll(List.generate(114, (index) => index + 1));
                    }),
                    child: const Text('اختيار الكل'),
                  ),
                  TextButton(
                    onPressed: () => setState(_selection.clear),
                    child: const Text('مسح'),
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final number = visible[index];
                    return CheckboxListTile(
                      value: _selection.contains(number),
                      title: Text(widget.generator.surahName(number)),
                      subtitle: Text(
                        'سورة $number • '
                        '${widget.generator.verseCount(number)} آيات',
                      ),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selection.add(number);
                          } else {
                            _selection.remove(number);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _selection.isEmpty
                ? null
                : () => Navigator.pop(context, _selection),
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final ChallengeQuestion question;
  final bool selected;
  final bool canSelect;
  final ValueChanged<bool> onSelected;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _QuestionCard({
    required this.question,
    required this.selected,
    required this.canSelect,
    required this.onSelected,
    required this.onActiveChanged,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected,
                  onChanged: question.isActive && (canSelect || selected)
                      ? (value) => onSelected(value == true)
                      : null,
                  activeColor: const Color(0xFF0F766E),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.question,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Tag(question.type.label),
                          _Tag(question.answerMode.label),
                          _Tag(_difficultyLabel(question.difficulty)),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: question.isActive,
                  onChanged: onActiveChanged,
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                IconButton(
                  onPressed: onMoveUp,
                  tooltip: 'تحريك لأعلى',
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                IconButton(
                  onPressed: onMoveDown,
                  tooltip: 'تحريك لأسفل',
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onDuplicate,
                  tooltip: 'نسخ',
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'تعديل',
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'حذف',
                  color: const Color(0xFFB42318),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _difficultyLabel(String value) => switch (value) {
        'easy' => 'سهل',
        'hard' => 'صعب',
        _ => 'متوسط',
      };
}

class _QuestionEditorResult {
  final ChallengeQuestion question;
  final bool addToCurrentSession;

  const _QuestionEditorResult(this.question, this.addToCurrentSession);
}

class _QuestionEditorScreen extends StatefulWidget {
  final ChallengeQuestion? existing;

  const _QuestionEditorScreen({this.existing});

  @override
  State<_QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<_QuestionEditorScreen> {
  static const _teal = Color(0xFF0F766E);
  final _questionController = TextEditingController();
  final _hintController = TextEditingController();
  final _referenceController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());

  int _step = 0;
  late ChallengeType _type;
  late ChallengeAnswerMode _answerMode;
  late String _difficulty;
  int _correctOption = 0;
  bool _addToCurrentSession = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? ChallengeType.completeAyah;
    _answerMode = existing?.answerMode ?? ChallengeAnswerMode.oral;
    _difficulty = existing?.difficulty ?? 'medium';
    _questionController.text = existing?.question ?? '';
    _hintController.text = existing?.hint ?? '';
    _referenceController.text = existing?.answer ?? '';
    final sourceOptions = existing?.options ?? const <ChallengeOption>[];
    for (var index = 0; index < _optionControllers.length; index++) {
      if (index < sourceOptions.length) {
        _optionControllers[index].text = sourceOptions[index].text;
      }
    }
    if (_answerMode == ChallengeAnswerMode.ordering &&
        existing != null &&
        sourceOptions.isNotEmpty) {
      final byId = {for (final option in sourceOptions) option.id: option.text};
      final ordered = existing.correctOrder
          .map((id) => byId[id])
          .whereType<String>()
          .toList();
      for (var index = 0;
          index < ordered.length && index < _optionControllers.length;
          index++) {
        _optionControllers[index].text = ordered[index];
      }
    } else if (existing?.correctOptionId != null) {
      final found = sourceOptions
          .indexWhere((option) => option.id == existing!.correctOptionId);
      if (found >= 0) _correctOption = found;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _hintController.dispose();
    _referenceController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing == null ? 'إضافة سؤال' : 'تعديل السؤال'),
          backgroundColor: _teal,
          foregroundColor: Colors.white,
        ),
        body: Stepper(
          currentStep: _step,
          onStepTapped: (value) => setState(() => _step = value),
          onStepContinue: _continue,
          onStepCancel: _step == 0 ? () => Navigator.pop(context) : _previous,
          controlsBuilder: (context, details) => Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              children: [
                FilledButton(
                  onPressed: details.onStepContinue,
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  child: Text(_step == 6 ? 'إضافة السؤال' : 'التالي'),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: Text(_step == 0 ? 'إلغاء' : 'السابق'),
                ),
              ],
            ),
          ),
          steps: [
            Step(
              title: const Text('نوع السؤال'),
              isActive: _step >= 0,
              content: DropdownButtonFormField<ChallengeType>(
                key: ValueKey(_type),
                initialValue: _type,
                items: ChallengeType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _type = value;
                    _answerMode = _recommendedMode(value);
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'اختر النوع',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Step(
              title: const Text('نص السؤال'),
              isActive: _step >= 1,
              content: TextField(
                controller: _questionController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'ما السؤال الذي سيظهر للطالب؟',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Step(
              title: const Text('طريقة الإجابة'),
              isActive: _step >= 2,
              content: DropdownButtonFormField<ChallengeAnswerMode>(
                key: ValueKey(_answerMode),
                initialValue: _answerMode,
                items: ChallengeAnswerMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _answerMode = value ?? _answerMode),
                decoration: const InputDecoration(
                  labelText: 'طريقة التصحيح',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Step(
              title: const Text('الإجابة والتلميح'),
              isActive: _step >= 3,
              content: Column(
                children: [
                  if (_answerMode == ChallengeAnswerMode.multipleChoice)
                    ...List.generate(
                      4,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  setState(() => _correctOption = index),
                              tooltip: 'تحديد الإجابة الصحيحة',
                              icon: Icon(
                                _correctOption == index
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: _correctOption == index
                                    ? _teal
                                    : Colors.grey,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _optionControllers[index],
                                decoration: InputDecoration(
                                  labelText: 'الخيار ${index + 1}',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_answerMode == ChallengeAnswerMode.ordering)
                    ...List.generate(
                      4,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: _optionControllers[index],
                          decoration: InputDecoration(
                            labelText: 'العنصر ${index + 1} بالترتيب الصحيح',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    )
                  else
                    TextField(
                      controller: _referenceController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'الإجابة المرجعية (لا تظهر للطالب)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hintController,
                    decoration: const InputDecoration(
                      labelText: 'تلميح اختياري',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('الصعوبة'),
              isActive: _step >= 4,
              content: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'easy', label: Text('سهل')),
                  ButtonSegment(value: 'medium', label: Text('متوسط')),
                  ButtonSegment(value: 'hard', label: Text('صعب')),
                ],
                selected: {_difficulty},
                onSelectionChanged: (value) =>
                    setState(() => _difficulty = value.first),
              ),
            ),
            Step(
              title: const Text('المعاينة'),
              isActive: _step >= 5,
              content: Card(
                color: const Color(0xFFF4F8F7),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _type.label,
                        style: const TextStyle(
                          color: _teal,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _questionController.text.trim().isEmpty
                            ? 'سيظهر نص السؤال هنا'
                            : _questionController.text.trim(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_answerMode.label),
                      if (_answerMode == ChallengeAnswerMode.multipleChoice ||
                          _answerMode == ChallengeAnswerMode.ordering) ...[
                        const SizedBox(height: 12),
                        ..._optionControllers
                            .map((controller) => controller.text.trim())
                            .where((text) => text.isNotEmpty)
                            .map(
                              (text) => Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFD7E4E1),
                                  ),
                                ),
                                child: Text(text),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Step(
              title: const Text('مكان الإضافة'),
              isActive: _step >= 6,
              content: SwitchListTile(
                value: _addToCurrentSession,
                onChanged: (value) =>
                    setState(() => _addToCurrentSession = value),
                title: const Text('اختياره لتحدي الجلسة الحالية'),
                subtitle: const Text(
                  'سيُضاف دائمًا إلى البنك أولًا، ولا يُنشر حتى تضغط «نشر».',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _continue() {
    if (_step == 1 && _questionController.text.trim().isEmpty) {
      _error('أدخل نص السؤال');
      return;
    }
    if (_step == 3 && !_answerIsValid()) return;
    if (_step < 6) {
      setState(() => _step += 1);
      return;
    }
    _finish();
  }

  void _previous() => setState(() => _step -= 1);

  bool _answerIsValid() {
    final values = _optionControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (_answerMode == ChallengeAnswerMode.multipleChoice &&
        values.length < 2) {
      _error('أدخل خيارين على الأقل وحدد الإجابة الصحيحة');
      return false;
    }
    if (_answerMode == ChallengeAnswerMode.multipleChoice &&
        _optionControllers[_correctOption].text.trim().isEmpty) {
      _error('الخيار المحدد كإجابة صحيحة فارغ');
      return false;
    }
    if (_answerMode == ChallengeAnswerMode.ordering && values.length < 3) {
      _error('أدخل ثلاثة عناصر على الأقل بالترتيب الصحيح');
      return false;
    }
    return true;
  }

  void _finish() {
    if (_questionController.text.trim().isEmpty || !_answerIsValid()) return;
    final options = <ChallengeOption>[
      for (var index = 0; index < _optionControllers.length; index++)
        if (_optionControllers[index].text.trim().isNotEmpty)
          ChallengeOption(
            id: 'o${index + 1}',
            text: _optionControllers[index].text.trim(),
          ),
    ];
    final question = ChallengeQuestion(
      id: widget.existing?.id ?? _newQuestionId(),
      type: _type,
      answerMode: _answerMode,
      source: widget.existing?.source ?? 'teacher_bank',
      question: _questionController.text.trim(),
      hint: _hintController.text.trim(),
      answer: _referenceController.text.trim(),
      options: options,
      correctOptionId: _answerMode == ChallengeAnswerMode.multipleChoice
          ? 'o${_correctOption + 1}'
          : null,
      correctOrder: _answerMode == ChallengeAnswerMode.ordering
          ? options.map((option) => option.id).toList()
          : const [],
      difficulty: _difficulty,
      isActive: widget.existing?.isActive ?? true,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    Navigator.pop(
      context,
      _QuestionEditorResult(question, _addToCurrentSession),
    );
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: const Color(0xFFB42318),
      ),
    );
  }

  static ChallengeAnswerMode _recommendedMode(ChallengeType type) =>
      switch (type) {
        ChallengeType.completeAyah => ChallengeAnswerMode.oral,
        ChallengeType.nameSurah => ChallengeAnswerMode.multipleChoice,
        ChallengeType.tajweedRule => ChallengeAnswerMode.multipleChoice,
        ChallengeType.orderAyahs => ChallengeAnswerMode.ordering,
        ChallengeType.wordMeaning => ChallengeAnswerMode.multipleChoice,
        ChallengeType.openQuestion => ChallengeAnswerMode.teacherReview,
      };
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0F766E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF4F625D),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0xFF8FA29D)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF66736F), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFB42318)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
                onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4F625D),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _newQuestionId() {
  final now = DateTime.now();
  return 'q_${now.microsecondsSinceEpoch}';
}
