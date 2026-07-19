import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:mohaffez_finder_app/providers/trial_session_provider.dart';
import 'package:mohaffez_finder_app/tour/tour_mode_state.dart';
import 'package:mohaffez_finder_app/tour/tour_scope.dart';

void main() {
  testWidgets('student tour user finishes loading and survives rebuilds',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(tourModeProvider.notifier).enter(TourRole.student);

    Widget app() {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TourScope(
            child: Consumer(
              builder: (context, ref, _) {
                final activeProfile = ref.watch(activeStudentProfileProvider);
                final trialRequests = ref.watch(trialSessionRequestsProvider);
                return ref.watch(currentUserProvider).when(
                      data: (user) => activeProfile.when(
                        data: (profile) => trialRequests.when(
                          data: (requests) => Text(
                            '${user?.name ?? 'missing-user'}|'
                            '${profile?.name ?? 'missing-profile'}|'
                            '${requests.length}',
                          ),
                          loading: () => const CircularProgressIndicator(),
                          error: (error, _) => Text('trial-error: $error'),
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (error, _) => Text('profile-error: $error'),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (error, _) => Text('error: $error'),
                    );
              },
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('طالب تجريبي|طالب تجريبي|0'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('طالب تجريبي|طالب تجريبي|0'), findsOneWidget);
  });

  testWidgets('teacher tour does not read real trial requests', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(tourModeProvider.notifier).enter(TourRole.mohaffez);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TourScope(
            child: Consumer(
              builder: (context, ref, _) {
                final user = ref.watch(currentUserProvider).valueOrNull;
                final requests = ref.watch(trialSessionRequestsProvider);
                return requests.when(
                  data: (items) => Text('${user?.role}|${items.length}'),
                  loading: () => const CircularProgressIndicator(),
                  error: (error, _) => Text('trial-error: $error'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('mohaffez|0'), findsOneWidget);
  });
}
