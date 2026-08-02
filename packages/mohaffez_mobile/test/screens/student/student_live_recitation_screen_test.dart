import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_finder_app/data/recitation_deck.dart';
import 'package:mohaffez_finder_app/providers/live_recitation_provider.dart';
import 'package:mohaffez_finder_app/screens/student/student_live_recitation_screen.dart';

void main() {
  testWidgets('shows the card selected in the synchronized round', (
    tester,
  ) async {
    const state = LiveRecitationState(
      sessionId: 'session-1',
      mohaffezId: 'teacher-1',
      studentId: 'student-1',
      studentProfileId: null,
      status: LiveRecitationStatus.playing,
      roundId: 1,
      seed: 1,
      cardCount: 4,
      scopes: [
        RecitationScope(
          surahNumber: 1,
          surahName: 'الفاتحة',
          fromAyah: 1,
          toAyah: 7,
        ),
      ],
      selectedIndex: 0,
      results: {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveRecitationStateProvider.overrideWith(
            (ref, _) => Stream.value(state),
          ),
        ],
        child: const MaterialApp(
          home: StudentLiveRecitationScreen(sessionId: 'session-1'),
        ),
      ),
    );

    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(find.text('ابدأ التسميع، والمحفّظ يستمع إليك الآن'), findsOneWidget);
    expect(find.byKey(const ValueKey('student-recitation-card-0')),
        findsOneWidget);
    expect(find.text('سورة الفاتحة'), findsOneWidget);
  });
}
