import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../../../data/quran_challenge_generator.dart';
import '../../../../data/recitation_deck.dart';
import '../../../../providers/live_recitation_provider.dart';
import '../../../../services/sound_service.dart';
import '../state/quiz_session_controller.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/quiz_design_tokens.dart';

typedef LiveRecitationDeckLoader = Future<List<RecitationCard>> Function(
  LiveRecitationState state,
);

class RecitationCardsGame extends ConsumerStatefulWidget {
  final ConfettiOverlayController confetti;
  final VoidCallback onBackToMenu;
  final String? previousHifz;
  final String? previousMuraja;
  final String? previousHifzFromAyah;
  final String? previousHifzToAyah;
  final String? previousMurajaFromAyah;
  final String? previousMurajaToAyah;
  final String? sessionId;
  final String? mohaffezId;
  final String? studentId;
  final String? studentProfileId;
  final LiveRecitationDeckLoader? liveDeckLoader;

  const RecitationCardsGame({
    super.key,
    required this.confetti,
    required this.onBackToMenu,
    this.previousHifz,
    this.previousMuraja,
    this.previousHifzFromAyah,
    this.previousHifzToAyah,
    this.previousMurajaFromAyah,
    this.previousMurajaToAyah,
    this.sessionId,
    this.mohaffezId,
    this.studentId,
    this.studentProfileId,
    this.liveDeckLoader,
  });

  @override
  ConsumerState<RecitationCardsGame> createState() =>
      _RecitationCardsGameState();
}

class _RecitationCardsGameState extends ConsumerState<RecitationCardsGame> {
  final List<RecitationScope> _scopes = [];
  List<RecitationCard> _cards = const [];
  final Map<String, bool> _results = {};
  int _cardCount = 6;
  int _round = 0;
  int? _activeIndex;
  bool _loading = false;
  bool _syncing = false;
  String? _error;
  int? _liveRoundId;
  int? _loadingLiveRoundId;
  LiveRecitationState? _latestLiveState;

  bool get _isLive =>
      widget.sessionId?.isNotEmpty == true &&
      widget.mohaffezId?.isNotEmpty == true &&
      widget.studentId?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _addInitialScope(
      widget.previousHifz,
      widget.previousHifzFromAyah,
      widget.previousHifzToAyah,
    );
    _addInitialScope(
      widget.previousMuraja,
      widget.previousMurajaFromAyah,
      widget.previousMurajaToAyah,
    );
  }

  void _addInitialScope(String? name, String? from, String? to) {
    if (name == null || name.trim().isEmpty) return;
    final number = QuranService().surahNumberForName(name);
    if (number == null) return;
    final scope = RecitationScope(
      surahNumber: number,
      surahName: QuranService.surahNames[number]!,
      fromAyah: _parseNumber(from),
      toAyah: _parseNumber(to),
    );
    if (_scopes.any(
      (item) =>
          item.surahNumber == scope.surahNumber &&
          item.fromAyah == scope.fromAyah &&
          item.toAyah == scope.toAyah,
    )) {
      return;
    }
    _scopes.add(scope);
  }

  static int? _parseNumber(String? value) {
    if (value == null) return null;
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const latinDigits = '0123456789';
    var normalized = value.trim();
    for (var index = 0; index < arabicDigits.length; index++) {
      normalized = normalized.replaceAll(
        arabicDigits[index],
        latinDigits[index],
      );
    }
    return int.tryParse(normalized);
  }

  Future<void> _startRound() async {
    final enabled = _scopes.where((scope) => scope.enabled).toList();
    if (enabled.isEmpty) {
      setState(() => _error = 'أضف نطاق تسميع واحدًا على الأقل');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roundId = DateTime.now().millisecondsSinceEpoch;
      final seed = roundId;
      final generator = await QuranChallengeGenerator.load(
        enabled.map((scope) => scope.surahNumber),
      );
      final cards = RecitationDeckBuilder(generator).build(
        RecitationDeckConfig(scopes: enabled, cardCount: _cardCount),
        seed: _isLive ? seed : _round++,
      );
      if (cards.isNotEmpty && _isLive) {
        await startLiveRecitationRound(
          sessionId: widget.sessionId!,
          mohaffezId: widget.mohaffezId!,
          studentId: widget.studentId!,
          studentProfileId: widget.studentProfileId,
          scopes: enabled,
          cardCount: _cardCount,
          roundId: roundId,
          seed: seed,
        );
      }
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _liveRoundId = _isLive ? roundId : null;
        _results.clear();
        _activeIndex = null;
        _loading = false;
        if (cards.isEmpty) {
          _error = 'لا توجد مقاطع صالحة ضمن النطاقات المختارة';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تجهيز كروت التسميع';
      });
    }
  }

  Future<void> _selectCard(int index) async {
    if (_activeIndex != null || _results.containsKey(_cards[index].id)) return;
    SoundService.play(Sfx.tap);
    if (!_isLive) {
      setState(() => _activeIndex = index);
      return;
    }
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await selectLiveRecitationCard(
        sessionId: widget.sessionId!,
        cardIndex: index,
        actorId: widget.mohaffezId!,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر اختيار الكرت، حاول مرة أخرى');
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _mark(bool mastered) async {
    final index = _activeIndex;
    if (index == null) return;
    final card = _cards[index];
    if (_isLive) {
      if (_syncing) return;
      setState(() => _syncing = true);
      try {
        await gradeLiveRecitationCard(
          sessionId: widget.sessionId!,
          cardIndex: index,
          mastered: mastered,
          finishesRound: _results.length + 1 >= _cards.length,
        );
      } catch (_) {
        if (mounted) {
          setState(() => _error = 'تعذر حفظ التقييم، حاول مرة أخرى');
        }
        return;
      } finally {
        if (mounted) setState(() => _syncing = false);
      }
    }
    final streak =
        ref.read(quizSessionControllerProvider.notifier).recordAnswer(mastered);
    SoundService.play(mastered ? Sfx.clap : Sfx.tryAgain);
    if (mastered) {
      widget.confetti.celebrate(
        intensity: streak >= 3
            ? ConfettiIntensity.fireworks
            : ConfettiIntensity.normal,
      );
    }
    setState(() {
      _results[card.id] = mastered;
      _activeIndex = null;
    });
  }

  void _applyLiveState(LiveRecitationState? state) {
    if (!mounted || state == null) return;
    if (identical(_latestLiveState, state)) return;
    _latestLiveState = state;
    if (state.isClosed) {
      setState(() {
        _cards = const [];
        _results.clear();
        _activeIndex = null;
        _error = 'تم إنهاء الجلسة';
      });
      return;
    }
    if (_liveRoundId != state.roundId) {
      if (_loadingLiveRoundId != state.roundId) {
        _loadLiveRound(state);
      }
      return;
    }
    _applyLiveView(state);
  }

  Future<void> _loadLiveRound(LiveRecitationState state) async {
    _loadingLiveRoundId = state.roundId;
    if (mounted) setState(() => _loading = true);
    try {
      final cards = widget.liveDeckLoader != null
          ? await widget.liveDeckLoader!(state)
          : await _buildLiveDeck(state);
      if (!mounted || _loadingLiveRoundId != state.roundId) return;
      final latest = _latestLiveState;
      setState(() {
        _cards = cards;
        _scopes
          ..clear()
          ..addAll(state.scopes);
        _cardCount = state.cardCount;
        _liveRoundId = state.roundId;
        _loading = false;
        _error = null;
      });
      if (latest != null && latest.roundId == state.roundId) {
        _applyLiveView(latest);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل جولة التسميع المباشرة';
        });
      }
    } finally {
      if (_loadingLiveRoundId == state.roundId) {
        _loadingLiveRoundId = null;
      }
    }
  }

  Future<List<RecitationCard>> _buildLiveDeck(
    LiveRecitationState state,
  ) async {
    final generator = await QuranChallengeGenerator.load(
      state.scopes.map((scope) => scope.surahNumber),
    );
    return RecitationDeckBuilder(generator).build(
      RecitationDeckConfig(
        scopes: state.scopes,
        cardCount: state.cardCount,
      ),
      seed: state.seed,
    );
  }

  void _applyLiveView(LiveRecitationState state) {
    if (!mounted || _cards.isEmpty) return;
    setState(() {
      _results
        ..clear()
        ..addEntries(
          state.results.entries.where((entry) => entry.key < _cards.length).map(
                (entry) => MapEntry(_cards[entry.key].id, entry.value),
              ),
        );
      _activeIndex = state.selectedIndex;
      _error = null;
    });
  }

  Future<void> _editScope([int? index]) async {
    final existing = index == null ? null : _scopes[index];
    var surahNumber = existing?.surahNumber ?? 1;
    var wholeSurah = existing?.fromAyah == null || existing?.toAyah == null;
    final fromController = TextEditingController(
      text: existing?.fromAyah?.toString() ?? '',
    );
    final toController = TextEditingController(
      text: existing?.toAyah?.toString() ?? '',
    );
    final result = await showDialog<RecitationScope>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(index == null ? 'إضافة كرت تسميع' : 'تعديل النطاق'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: surahNumber,
                  decoration: const InputDecoration(labelText: 'السورة'),
                  items: QuranService.surahNames.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) surahNumber = value;
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('السورة كاملة'),
                  value: wholeSurah,
                  onChanged: (value) {
                    setDialogState(() => wholeSurah = value ?? true);
                  },
                ),
                if (!wholeSurah)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fromController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'من آية',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: toController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'إلى آية',
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final from =
                    wholeSurah ? null : _parseNumber(fromController.text);
                final to = wholeSurah ? null : _parseNumber(toController.text);
                if (!wholeSurah &&
                    (from == null || to == null || from < 1 || from > to)) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  RecitationScope(
                    surahNumber: surahNumber,
                    surahName: QuranService.surahNames[surahNumber]!,
                    fromAyah: from,
                    toAyah: to,
                    enabled: existing?.enabled ?? true,
                  ),
                );
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    fromController.dispose();
    toController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _scopes.add(result);
      } else {
        _scopes[index] = result;
      }
      _cards = const [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = widget.sessionId;
    if (_isLive && sessionId != null) {
      final liveAsync = ref.watch(liveRecitationStateProvider(sessionId));
      ref.listen<AsyncValue<LiveRecitationState?>>(
        liveRecitationStateProvider(sessionId),
        (_, next) => next.whenData(_applyLiveState),
      );
      final current = liveAsync.valueOrNull;
      if (current != null && !identical(_latestLiveState, current)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _applyLiveState(current);
        });
      }
    }
    if (_cards.isEmpty) return _buildSetup();
    return _buildDeck();
  }

  Widget _buildSetup() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const Text(
          'جهّز كروت التسميع',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: QuizDS.text1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'تُقسّم النطاقات الطويلة حسب صفحات المصحف، ويمكنك تعديلها قبل بدء الجولة.',
          style: TextStyle(color: QuizDS.text2, height: 1.5),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < _scopes.length; index++)
          Card(
            child: ListTile(
              leading: Switch(
                value: _scopes[index].enabled,
                onChanged: (value) {
                  setState(() {
                    _scopes[index] = _scopes[index].copyWith(enabled: value);
                  });
                },
              ),
              title: Text('سورة ${_scopes[index].surahName}'),
              subtitle: Text(
                _scopes[index].fromAyah == null
                    ? 'السورة كاملة'
                    : 'الآيات ${_scopes[index].fromAyah}–${_scopes[index].toAyah}',
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'تعديل',
                    onPressed: () => _editScope(index),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    onPressed: () => setState(() => _scopes.removeAt(index)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _editScope,
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة سورة أو نطاق'),
        ),
        const SizedBox(height: 18),
        const Text(
          'عدد الكروت',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final count in const [4, 6, 8])
              ChoiceChip(
                label: Text('$count كروت'),
                selected: _cardCount == count,
                onSelected: (_) => setState(() => _cardCount = count),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style:
                const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _loading ? null : _startRound,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.style_rounded),
          label: Text(_loading ? 'جارٍ تجهيز الكروت…' : 'ابدأ الجولة'),
        ),
        TextButton(
          onPressed: widget.onBackToMenu,
          child: const Text('العودة للألعاب'),
        ),
      ],
    );
  }

  Widget _buildDeck() {
    final finished = _results.length == _cards.length;
    final mastered = _results.values.where((value) => value).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        Text(
          finished
              ? 'أتممت الجولة: $mastered من ${_cards.length}'
              : _isLive
                  ? _activeIndex == null
                      ? 'في انتظار اختيار الطالب للكرت'
                      : 'استمع للطالب ثم سجّل تقييمه'
                  : 'اختر كرتًا مقلوبًا ثم ابدأ التسميع',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: QuizDS.text1,
          ),
        ),
        const SizedBox(height: 14),
        if (_activeIndex != null) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _syncing ? null : () => _mark(false),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('تحتاج مراجعة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _syncing ? null : () => _mark(true),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('أتقن'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth >= 620 ? 3 : 2,
              childAspectRatio: 0.88,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _cards.length,
            itemBuilder: (context, index) => _buildCard(index),
          ),
        ),
        if (finished) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _startRound,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('جولة جديدة'),
          ),
          OutlinedButton(
            onPressed: widget.onBackToMenu,
            child: const Text('العودة للألعاب'),
          ),
        ],
      ],
    );
  }

  Widget _buildCard(int index) {
    final card = _cards[index];
    final result = _results[card.id];
    final revealed = _activeIndex == index || result != null;
    final waitingForStudent = _isLive && _activeIndex == null && result == null;
    final disabled = _syncing ||
        waitingForStudent ||
        (_activeIndex != null && _activeIndex != index) ||
        result != null;
    final color = result == true
        ? const Color(0xFFDCFCE7)
        : result == false
            ? const Color(0xFFFFF3CD)
            : revealed
                ? Colors.white
                : QuizDS.teal500;
    return Semantics(
      button: !disabled,
      label: revealed
          ? 'سورة ${card.surahName} من الآية ${card.fromAyah} إلى ${card.toAyah}'
          : 'كرت التسميع ${index + 1}',
      child: InkWell(
        key: ValueKey('recitation-card-$index'),
        onTap: disabled || revealed ? null : () => _selectCard(index),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: result == true
                  ? const Color(0xFF22C55E)
                  : result == false
                      ? QuizDS.amber
                      : QuizDS.teal500,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween<double>(begin: 0.5, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: revealed
                ? Column(
                    key: ValueKey('front-${card.id}'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        result == true
                            ? Icons.check_circle_rounded
                            : result == false
                                ? Icons.replay_circle_filled_rounded
                                : Icons.menu_book_rounded,
                        color: QuizDS.teal500,
                        size: 30,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'سورة ${card.surahName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: QuizDS.text1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'الآيات ${card.fromAyah}–${card.toAyah}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: QuizDS.text2,
                        ),
                      ),
                      Text(
                        'الجزء ${card.juzNumber} • الصفحة ${card.pageNumber}',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 11, color: QuizDS.text2),
                      ),
                    ],
                  )
                : Column(
                    key: ValueKey('back-${card.id}'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 34),
                      const SizedBox(height: 10),
                      Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'اخترني',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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
