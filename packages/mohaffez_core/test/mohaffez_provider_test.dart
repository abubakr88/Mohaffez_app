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

  group('teacher reputation score', () {
    test('does not let one perfect rating outrank sustained high quality', () {
      final newTeacher = MohaffezModel(
        id: 'new',
        name: 'New',
        rating: 5,
        reviewCount: 1,
      );
      final establishedTeacher = MohaffezModel(
        id: 'established',
        name: 'Established',
        rating: 4.8,
        reviewCount: 30,
      );

      expect(
        establishedTeacher.reputationScore,
        greaterThan(newTeacher.reputationScore),
      );
    });

    test('returns zero until a teacher has a public review', () {
      final teacher = MohaffezModel(id: 'new', name: 'New', rating: 0);

      expect(teacher.reputationScore, 0);
    });
  });
}
