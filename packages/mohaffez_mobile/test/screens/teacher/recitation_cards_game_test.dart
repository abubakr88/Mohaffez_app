import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_finder_app/screens/teacher/quiz/games/recitation_cards_game.dart';
import 'package:mohaffez_finder_app/screens/teacher/quiz/widgets/confetti_overlay.dart';
import 'package:mohaffez_finder_app/data/recitation_deck.dart';
import 'package:mohaffez_finder_app/providers/live_recitation_provider.dart';

void main() {
  testWidgets('student reveals one card and teacher grades it', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: RecitationCardsGame(
                confetti: ConfettiOverlayController(),
                onBackToMenu: () {},
                previousHifz: 'البقرة',
                previousHifzFromAyah: '1',
                previousHifzToAyah: '100',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('سورة البقرة'), findsOneWidget);
    expect(find.text('6 كروت'), findsOneWidget);
    await tester.tap(find.text('ابدأ الجولة'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('اخترني'), findsNWidgets(6));
    await tester.tap(find.byKey(const ValueKey('recitation-card-0')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('أتقن'), findsOneWidget);
    expect(find.text('تحتاج مراجعة'), findsOneWidget);
    expect(find.textContaining('الجزء'), findsOneWidget);
    expect(find.textContaining('الصفحة'), findsOneWidget);

    await tester.tap(find.text('أتقن'));
    await tester.pump();
    expect(find.text('أتقن'), findsNothing);
    expect(find.text('اخترني'), findsNWidgets(5));
  });

  testWidgets('teacher sees the card selected on the student device', (
    tester,
  ) async {
    const liveState = LiveRecitationState(
      sessionId: 'session-1',
      mohaffezId: 'teacher-1',
      studentId: 'student-1',
      studentProfileId: null,
      status: LiveRecitationStatus.playing,
      roundId: 12,
      seed: 12,
      cardCount: 4,
      scopes: [
        RecitationScope(
          surahNumber: 2,
          surahName: 'البقرة',
          fromAyah: 1,
          toAyah: 100,
        ),
      ],
      selectedIndex: 0,
      results: {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveRecitationStateProvider.overrideWith(
            (ref, _) => Stream.value(liveState),
          ),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: RecitationCardsGame(
                confetti: ConfettiOverlayController(),
                onBackToMenu: () {},
                sessionId: 'session-1',
                mohaffezId: 'teacher-1',
                studentId: 'student-1',
                liveDeckLoader: (_) async => const [
                  RecitationCard(
                    id: 'card-0',
                    surahNumber: 2,
                    surahName: 'البقرة',
                    fromAyah: 1,
                    toAyah: 5,
                    pageNumber: 2,
                    juzNumber: 1,
                  ),
                  RecitationCard(
                    id: 'card-1',
                    surahNumber: 2,
                    surahName: 'البقرة',
                    fromAyah: 6,
                    toAyah: 10,
                    pageNumber: 3,
                    juzNumber: 1,
                  ),
                  RecitationCard(
                    id: 'card-2',
                    surahNumber: 2,
                    surahName: 'البقرة',
                    fromAyah: 11,
                    toAyah: 15,
                    pageNumber: 3,
                    juzNumber: 1,
                  ),
                  RecitationCard(
                    id: 'card-3',
                    surahNumber: 2,
                    surahName: 'البقرة',
                    fromAyah: 16,
                    toAyah: 20,
                    pageNumber: 4,
                    juzNumber: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    for (var attempt = 0;
        attempt < 20 &&
            find.text('استمع للطالب ثم سجّل تقييمه').evaluate().isEmpty;
        attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('استمع للطالب ثم سجّل تقييمه'), findsOneWidget);
    expect(find.text('أتقن'), findsOneWidget);
    expect(find.text('تحتاج مراجعة'), findsOneWidget);
    expect(find.text('سورة البقرة'), findsOneWidget);
  });
}
