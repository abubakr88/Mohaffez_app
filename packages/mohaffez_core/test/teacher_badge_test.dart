import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

void main() {
  group('UserBadges', () {
    test('treats missing and null badge data as inactive', () {
      expect(UserBadges.fromJson(null).foundingTeacher.enabled, isFalse);
      expect(
        UserBadges.fromJson(<String, dynamic>{}).foundingTeacher.enabled,
        isFalse,
      );
    });

    test('parses founding teacher metadata safely', () {
      final grantedAt = DateTime.utc(2026, 6, 21);
      final badges = UserBadges.fromJson({
        'foundingTeacher': {
          'enabled': true,
          'grantedAt': Timestamp.fromDate(grantedAt),
          'grantedBy': 'admin-1',
          'grantedByName': 'Admin',
        },
      });

      expect(badges.foundingTeacher.enabled, isTrue);
      expect(badges.foundingTeacher.grantedAt?.toUtc(), grantedAt);
      expect(badges.foundingTeacher.grantedBy, 'admin-1');
    });
  });

  group('FoundingTeacherBadge', () {
    testWidgets('does not render when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoundingTeacherBadge(enabled: false),
          ),
        ),
      );

      expect(find.byType(FoundingTeacherBadge), findsOneWidget);
      expect(find.text('Founding'), findsNothing);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
    });

    testWidgets('renders compact English and Arabic labels', (tester) async {
      Future<void> pump(Locale locale) {
        return tester.pumpWidget(
          Localizations(
            locale: locale,
            delegates: const [
              DefaultWidgetsLocalizations.delegate,
            ],
            child: Directionality(
              textDirection: locale.languageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: const Material(
                child: FoundingTeacherBadge(showTooltip: false),
              ),
            ),
          ),
        );
      }

      await pump(const Locale('en'));
      await tester.pump();
      expect(find.text('Founding'), findsOneWidget);

      await pump(const Locale('ar'));
      await tester.pump();
      expect(find.text('مؤسس'), findsOneWidget);
    });

    testWidgets('can render the full compact label', (tester) async {
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('ar'),
          delegates: const [
            DefaultWidgetsLocalizations.delegate,
          ],
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Material(
              child: FoundingTeacherBadge(
                useFullLabel: true,
                showTooltip: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('المحفّظ المؤسس'), findsOneWidget);
    });
  });
}
