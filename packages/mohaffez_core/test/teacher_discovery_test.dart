import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

void main() {
  group('teacher discovery taxonomy', () {
    test('maps configurable age boundaries without overlap', () {
      expect(TeacherDiscoveryTaxonomy.ageGroupForAge(10), 'children');
      expect(TeacherDiscoveryTaxonomy.ageGroupForAge(11), 'teens');
      expect(TeacherDiscoveryTaxonomy.ageGroupForAge(15), 'teens');
      expect(TeacherDiscoveryTaxonomy.ageGroupForAge(16), 'adults');
      expect(TeacherDiscoveryTaxonomy.ageGroupForAge(30), 'adults');
      expect(
        TeacherDiscoveryTaxonomy.ageGroupForAge(
          12,
          childrenMaxAge: 12,
          teenMaxAge: 17,
        ),
        'children',
      );
      expect(TeacherDiscoveryTaxonomy.ageGroupForAge(null), isNull);
    });

    test('normalizes known learner levels without guessing unknown values', () {
      expect(TeacherDiscoveryTaxonomy.normalizeLevel('مبتدئ'), 'beginner');
      expect(
        TeacherDiscoveryTaxonomy.normalizeLevel('intermediate'),
        'intermediate',
      );
      expect(TeacherDiscoveryTaxonomy.normalizeLevel('متقدم'), 'advanced');
      expect(TeacherDiscoveryTaxonomy.normalizeLevel('غير محدد'), isNull);
    });

    test('legacy specialization migration only derives teaching services', () {
      final services = TeacherDiscoveryTaxonomy.legacyServiceIds(
        'حفظ القرآن، تجويد، تعليم الأطفال، اللغة العربية',
      );

      expect(services, containsAll(<String>['memorization', 'tajweed']));
      expect(services, isNot(contains('children')));
      expect(services, isNot(contains('ar')));
    });
  });

  group('TeacherDiscoverySelection', () {
    test('requires every matching dimension and a selected primary language',
        () {
      const incomplete = TeacherDiscoverySelection(
        services: {'memorization'},
        languages: {'ar'},
        primaryLanguage: 'ar',
      );
      expect(incomplete.isComplete, isFalse);
      expect(incomplete.validationMessage, isNotNull);

      const complete = TeacherDiscoverySelection(
        services: {'memorization', 'tajweed'},
        learnerAudiences: {
          'children': {'female': true},
        },
        levels: {'beginner'},
        languages: {'ar', 'en'},
        primaryLanguage: 'ar',
      );
      expect(complete.isComplete, isTrue);
      expect(complete.validationMessage, isNull);
      expect(complete.toFirestore()['discoveryProfileVersion'], 2);
      expect(
        complete.toFirestore()['teachingServices'],
        {'memorization': true, 'tajweed': true},
      );
    });

    test('parses only enabled values and uses legacy services as fallback', () {
      final selection = TeacherDiscoverySelection.fromData({
        'specialization': 'تحفيظ ومراجعة',
        'teachingServices': {'tajweed': false},
        'learnerAgeGroups': {'children': true, 'adults': false},
        'learnerGenders': {'male': true},
      });

      expect(selection.services, {'memorization', 'review'});
      expect(selection.ageGroups, {'children'});
      expect(selection.learnerAudiences['children'], {'male': true});
    });

    test('v2 audience matrix takes precedence over legacy cross product', () {
      final selection = TeacherDiscoverySelection.fromData({
        'learnerAudiences': {
          'children': {'male': true, 'female': true},
          'adults': {'female': true},
        },
        'learnerAgeGroups': {'adults': true},
        'learnerGenders': {'male': true},
      });

      expect(selection.learnerAudiences['children'], {
        'male': true,
        'female': true,
      });
      expect(selection.learnerAudiences['adults'], {'female': true});
    });
  });

  test('MohaffezModel exposes at most three compact discovery badges', () {
    final teacher = MohaffezModel(
      id: 'teacher-1',
      name: 'Teacher',
      teachingServices: const {'memorization': true, 'tajweed': true},
      learnerAudiences: const {
        'children': {'male': true},
      },
      teachingLanguages: const {'en': true},
    );

    expect(teacher.discoveryBadges(), ['تحفيظ', 'تجويد', 'أطفال']);
    expect(teacher.discoveryBadges().length, 3);
  });

  test('audience matrix keeps adult women separate from boys and adult men',
      () {
    final teacher = MohaffezModel(
      id: 'teacher-2',
      name: 'Teacher',
      learnerAudiences: const {
        'children': {'male': true, 'female': true},
        'teens': {'female': true},
        'adults': {'female': true},
      },
      learnerLevels: const {'advanced': true},
      teachingLanguages: const {'en': true},
    );

    expect(
      teacher.teachesAudience('adults', 'female'),
      isTrue,
    );
    expect(
      teacher.teachesAudience('children', 'male'),
      isTrue,
    );
    expect(
      teacher.teachesAudience('adults', 'male'),
      isFalse,
    );
  });

  test('all six audience combinations are evaluated independently', () {
    const groups = ['children', 'teens', 'adults'];
    const genders = ['male', 'female'];
    for (final selectedGroup in groups) {
      for (final selectedGender in genders) {
        final teacher = MohaffezModel(
          id: '$selectedGroup-$selectedGender',
          name: 'Teacher',
          learnerAudiences: {
            selectedGroup: {selectedGender: true},
          },
        );
        for (final group in groups) {
          for (final gender in genders) {
            expect(
              teacher.teachesAudience(group, gender),
              group == selectedGroup && gender == selectedGender,
            );
          }
        }
      }
    }
  });

  test('legacy audience uses cross product and missing data follows policy',
      () {
    final legacy = MohaffezModel(
      id: 'legacy',
      name: 'Legacy',
      learnerAgeGroups: const {'children': true, 'adults': true},
      learnerGenders: const {'female': true},
    );
    final missing = MohaffezModel(id: 'missing', name: 'Missing');

    expect(legacy.teachesAudience('children', 'female'), isTrue);
    expect(legacy.teachesAudience('children', 'male'), isFalse);
    expect(
      missing.teachesAudience(
        'children',
        'male',
        allowIncomplete: true,
      ),
      isTrue,
    );
    expect(missing.teachesAudience('children', 'male'), isFalse);
  });

  test('smart matching prioritizes service and language before audience', () {
    final exact = MohaffezModel(
      id: 'exact',
      name: 'Exact',
      teachingServices: const {'tajweed': true},
      teachingLanguages: const {'en': true},
      primaryTeachingLanguage: 'en',
    );
    final audienceOnly = MohaffezModel(
      id: 'audience',
      name: 'Audience',
      learnerAudiences: const {
        'children': {'female': true},
      },
      learnerLevels: const {'beginner': true},
    );

    expect(
      exact.discoveryMatchScore(service: 'tajweed', teachingLanguage: 'en'),
      greaterThan(
        audienceOnly.discoveryMatchScore(
          ageGroup: 'children',
          learnerGender: 'female',
          learnerLevel: 'beginner',
        ),
      ),
    );
  });
}
