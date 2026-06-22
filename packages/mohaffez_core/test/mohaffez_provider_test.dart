import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

void main() {
  group('NearbyParams trial session filter', () {
    test('defaults to all teachers', () {
      final params = NearbyParams();

      expect(params.trialSessionFilter, TeacherTrialSessionFilter.all);
    });

    test('participates in provider family equality and hash code', () {
      final all = NearbyParams();
      final enabledOnly = NearbyParams(
        trialSessionFilter: TeacherTrialSessionFilter.enabledOnly,
      );
      final sameEnabledOnly = NearbyParams(
        trialSessionFilter: TeacherTrialSessionFilter.enabledOnly,
      );

      expect(all, isNot(enabledOnly));
      expect(enabledOnly, sameEnabledOnly);
      expect(enabledOnly.hashCode, sameEnabledOnly.hashCode);
    });
  });
}
