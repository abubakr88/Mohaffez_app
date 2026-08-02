import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:mohaffez_finder_app/screens/teacher/student_challenges_v2_screen.dart';

void main() {
  testWidgets(
    'Quran question bank suggests and confirms without reading custom bank',
    (tester) async {
      var customBankWasRead = false;
      final now = DateTime.now();
      final nextSession = now.add(const Duration(hours: 2));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentChallengeBankProvider.overrideWith(
              (ref, params) async {
                customBankWasRead = true;
                return const <ChallengeQuestion>[];
              },
            ),
          ],
          child: MaterialApp(
            home: StudentChallengesV2Screen(
              mohaffezId: 'teacher-a',
              studentId: 'student-a',
              studentProfileId: null,
              studentName: 'يوسف أبوبكر',
              initialSessions: [
                {
                  'id': 'past-session',
                  'status': 'accepted',
                  'studentId': 'student-a',
                  'mohaffezId': 'teacher-a',
                  'sessionDate': now.subtract(const Duration(days: 1)),
                  'challengeAccess': const {
                    'status': 'completed',
                    'questionCount': 10,
                  },
                },
                {
                  'id': 'next-session',
                  'status': 'accepted',
                  'studentId': 'student-a',
                  'mohaffezId': 'teacher-a',
                  'sessionDate': nextSession,
                },
                {
                  'id': 'later-session',
                  'status': 'accepted',
                  'studentId': 'student-a',
                  'mohaffezId': 'teacher-a',
                  'sessionDate': now.add(const Duration(days: 2)),
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تحديات يوسف أبوبكر'), findsOneWidget);
      expect(find.text('بنك الأسئلة القرآنية'), findsOneWidget);
      expect(find.text('الأسئلة الخاصة'), findsOneWidget);
      expect(find.textContaining('سؤالًا متاحًا'), findsOneWidget);
      expect(find.text('اقتراح مجموعة'), findsOneWidget);
      expect(find.text('تأكيد الاختبار'), findsOneWidget);
      expect(find.text('التغطية:'), findsOneWidget);
      expect(find.text('الجزء 1'), findsOneWidget);
      expect(find.textContaining('Firebase'), findsNothing);
      expect(customBankWasRead, isFalse);

      await tester.ensureVisible(find.text('اقتراح مجموعة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('اقتراح مجموعة'));
      await tester.pump();
      expect(find.textContaining('7/10 اختيار مبدئي'), findsOneWidget);
      expect(customBankWasRead, isFalse);

      final quranBankScroll = find.byKey(
        const PageStorageKey<String>('quran-question-bank-scroll'),
      );
      expect(quranBankScroll, findsOneWidget);
      final quranScrollable = find.descendant(
        of: quranBankScroll,
        matching: find.byType(Scrollable),
      );
      expect(quranScrollable, findsOneWidget);
      await tester.drag(quranBankScroll, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile).hitTestable(), findsWidgets);
      final firstOrderingRange = find.text('نطاق السؤال: الآيات 1–3');
      await tester.scrollUntilVisible(
        firstOrderingRange,
        300,
        scrollable: quranScrollable,
      );
      await tester.pumpAndSettle();
      expect(firstOrderingRange, findsOneWidget);
      expect(find.text('نطاق السؤال: الآيات 2–4'), findsOneWidget);
      await tester.drag(quranBankScroll, const Offset(0, 3000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تحدي الجلسة'));
      await tester.pumpAndSettle();
      expect(find.text('لم تختر أسئلة بعد'), findsOneWidget);
      expect(find.text('0 / 10'), findsOneWidget);

      await tester.tap(find.text('بنك الأسئلة'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('تأكيد الاختبار'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد الاختبار'));
      await tester.pumpAndSettle();
      expect(find.text('الجلسة القادمة'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.textContaining('past-session'), findsNothing);
      expect(find.textContaining('later-session'), findsNothing);
      expect(find.text('الأسئلة المختارة'), findsOneWidget);
      expect(find.text('7 / 10'), findsOneWidget);
      expect(find.textContaining('سؤال قرآني'), findsWidgets);
    },
  );
}
