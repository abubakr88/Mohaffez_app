import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:mohaffez_finder_app/shared/widgets/teacher_discovery_editor.dart';

void main() {
  testWidgets('teacher can select multiple structured discovery values',
      (tester) async {
    var value = const TeacherDiscoverySelection(
      languages: {'ar'},
      primaryLanguage: 'ar',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TeacherDiscoveryEditor(
              initialValue: value,
              onChanged: (next) => value = next,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('تحفيظ'));
    await tester.pump();
    await tester.tap(find.text('تجويد'));
    await tester.pump();
    await tester.tap(find.text('بنين'));
    await tester.pump();
    await tester.tap(find.text('بنات'));
    await tester.pump();

    expect(value.services, containsAll(<String>{'memorization', 'tajweed'}));
    expect(value.ageGroups, {'children'});
    expect(value.learnerAudiences['children'], {
      'male': true,
      'female': true,
    });
    expect(value.languages, {'ar'});
    expect(value.primaryLanguage, 'ar');
  });
}
