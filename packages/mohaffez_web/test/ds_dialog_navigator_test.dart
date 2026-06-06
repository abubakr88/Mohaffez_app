import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_web/design_system/feedback/ds_dialog.dart';

/// Reproduces the admin "اعتماد does nothing" bug: a page inside a go_router
/// ShellRoute (nested Navigator) opens DSDialog.confirm. Tapping the confirm
/// button must close the DIALOG and return its result — NOT pop the page route.
void main() {
  testWidgets('DSDialog.confirm closes the dialog and keeps the shell page',
      (tester) async {
    bool? result;

    final router = GoRouter(
      initialLocation: '/page',
      routes: [
        ShellRoute(
          builder: (_, __, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/page',
              builder: (context, state) => Center(
                child: Builder(
                  builder: (context) => ElevatedButton(
                    key: const Key('open'),
                    onPressed: () async {
                      result = await DSDialog.confirm(
                        context,
                        title: 'عنوان',
                        message: 'رسالة التأكيد',
                        confirmLabel: 'موافق',
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open')), findsOneWidget);

    // Open the dialog.
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('رسالة التأكيد'), findsOneWidget);

    // Tap confirm.
    await tester.tap(find.text('موافق'));
    await tester.pumpAndSettle();

    // Dialog gone, page still here, result delivered.
    expect(find.text('رسالة التأكيد'), findsNothing,
        reason: 'dialog should be dismissed');
    expect(find.byKey(const Key('open')), findsOneWidget,
        reason: 'the shell page must NOT be popped');
    expect(result, isTrue, reason: 'confirm() must return true');
  });
}
