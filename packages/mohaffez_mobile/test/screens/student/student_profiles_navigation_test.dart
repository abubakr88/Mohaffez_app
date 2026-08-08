import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:mohaffez_finder_app/screens/student/student_profiles_screen.dart';

void main() {
  testWidgets(
    'student profile hides the back arrow even when the route can pop',
    (tester) async {
      final router = await _pumpProfilesRoute(tester, role: roleStudent);
      addTearDown(router.dispose);

      expect(router.canPop(), isTrue);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
      expect(find.text('بيانات الطالب'), findsOneWidget);
    },
  );

  testWidgets('parent profile keeps a working back arrow', (tester) async {
    final router = await _pumpProfilesRoute(tester, role: roleParent);
    addTearDown(router.dispose);

    expect(router.canPop(), isTrue);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Open profiles'), findsOneWidget);
  });
}

Future<GoRouter> _pumpProfilesRoute(
  WidgetTester tester, {
  required String role,
}) async {
  final user = UserModel(
    uid: 'user-1',
    name: role == roleParent ? 'Parent' : 'Student',
    email: 'user@example.com',
    role: role,
    gender: 'male',
    dateOfBirth: DateTime(2010, 1, 1),
  );
  final router = GoRouter(
    initialLocation: '/source',
    routes: [
      GoRoute(
        path: '/source',
        builder: (context, state) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => context.push('/student-profiles'),
              child: const Text('Open profiles'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/student-profiles',
        builder: (context, state) => const StudentProfilesScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        studentProfilesProvider.overrideWith(
          (ref, ownerId) => Stream.value(const <StudentProfileModel>[]),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open profiles'));
  await tester.pumpAndSettle();
  return router;
}
