import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../data/quran_challenge_generator.dart';
import '../../data/recitation_deck.dart';
import '../../providers/live_recitation_provider.dart';
import '../../services/sound_service.dart';

class StudentLiveRecitationScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String? mohaffezName;

  const StudentLiveRecitationScreen({
    super.key,
    required this.sessionId,
    this.mohaffezName,
  });

  @override
  ConsumerState<StudentLiveRecitationScreen> createState() =>
      _StudentLiveRecitationScreenState();
}

class _StudentLiveRecitationScreenState
    extends ConsumerState<StudentLiveRecitationScreen> {
  int? _loadedRoundId;
  Future<List<RecitationCard>>? _deckFuture;
  bool _selecting = false;
  String? _error;

  Future<List<RecitationCard>> _loadDeck(LiveRecitationState state) async {
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

  Future<void> _selectCard(
    LiveRecitationState state,
    int index,
  ) async {
    final actorId = ref.read(currentUserIdProvider);
    if (actorId == null ||
        _selecting ||
        state.selectedIndex != null ||
        state.results.containsKey(index) ||
        state.status != LiveRecitationStatus.playing) {
      return;
    }
    setState(() {
      _selecting = true;
      _error = null;
    });
    SoundService.play(Sfx.tap);
    try {
      await selectLiveRecitationCard(
        sessionId: widget.sessionId,
        cardIndex: index,
        actorId: actorId,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر اختيار الكرت، حاول مرة أخرى');
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(
      liveRecitationStateProvider(widget.sessionId),
    );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('كروت التسميع'),
        ),
        body: stateAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _Message(
            icon: Icons.cloud_off_rounded,
            title: 'تعذر الاتصال بالجولة',
            subtitle: 'تحقق من الاتصال ثم حاول مرة أخرى.',
            onRetry: () => ref.invalidate(
              liveRecitationStateProvider(widget.sessionId),
            ),
          ),
          data: (state) {
            if (state == null) {
              return const _Message(
                icon: Icons.hourglass_top_rounded,
                title: 'في انتظار المحفّظ',
                subtitle: 'ستظهر الكروت هنا عندما يبدأ المحفّظ الجولة.',
              );
            }
            if (state.isClosed) {
              return const _Message(
                icon: Icons.check_circle_outline_rounded,
                title: 'انتهت الجلسة',
                subtitle: 'تم إغلاق لعبة التسميع لهذه الجلسة.',
              );
            }
            if (_loadedRoundId != state.roundId || _deckFuture == null) {
              _loadedRoundId = state.roundId;
              _deckFuture = _loadDeck(state);
            }
            return FutureBuilder<List<RecitationCard>>(
              future: _deckFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || snapshot.data?.isEmpty != false) {
                  return const _Message(
                    icon: Icons.error_outline_rounded,
                    title: 'تعذر تجهيز الكروت',
                    subtitle: 'أغلق الشاشة وحاول مرة أخرى.',
                  );
                }
                return _buildDeck(state, snapshot.data!);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeck(
    LiveRecitationState state,
    List<RecitationCard> cards,
  ) {
    final finished = state.isFinished || state.results.length == cards.length;
    final mastered = state.results.values.where((value) => value).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 28),
      children: [
        Text(
          finished
              ? 'أحسنت! أتقنت $mastered من ${cards.length}'
              : state.selectedIndex == null
                  ? 'اختر كرتًا مقلوبًا'
                  : 'ابدأ التسميع، والمحفّظ يستمع إليك الآن',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        if ((widget.mohaffezName ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            'مع المحفّظ ${widget.mohaffezName}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 18),
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
            itemCount: cards.length,
            itemBuilder: (context, index) => _buildCard(
              state,
              cards[index],
              index,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
    LiveRecitationState state,
    RecitationCard card,
    int index,
  ) {
    final result = state.results[index];
    final revealed = state.selectedIndex == index || result != null;
    final disabled = _selecting ||
        state.status != LiveRecitationStatus.playing ||
        state.selectedIndex != null ||
        result != null;
    final color = result == true
        ? const Color(0xFFDCFCE7)
        : result == false
            ? const Color(0xFFFFF3CD)
            : revealed
                ? Colors.white
                : const Color(0xFF0F766E);

    return Semantics(
      button: !disabled,
      label: revealed
          ? 'سورة ${card.surahName} من الآية ${card.fromAyah} إلى ${card.toAyah}'
          : 'كرت التسميع ${index + 1}',
      child: InkWell(
        key: ValueKey('student-recitation-card-$index'),
        onTap: disabled ? null : () => _selectCard(state, index),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: result == true
                  ? const Color(0xFF22C55E)
                  : result == false
                      ? const Color(0xFFD4A44A)
                      : const Color(0xFF0F766E),
              width: 2,
            ),
          ),
          child: revealed
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      result == true
                          ? Icons.check_circle_rounded
                          : result == false
                              ? Icons.replay_circle_filled_rounded
                              : Icons.menu_book_rounded,
                      color: const Color(0xFF0F766E),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'سورة ${card.surahName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'الآيات ${card.fromAyah}–${card.toAyah}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'الجزء ${card.juzNumber} • الصفحة ${card.pageNumber}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 34,
                    ),
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
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xFF0F766E)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.5),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
