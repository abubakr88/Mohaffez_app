import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_finder_app/tour/tour_fixtures.dart';

void main() {
  test('tour fixtures are synchronous and stable across widget rebuilds', () {
    final firstStudent = TourFixtures.loadStudent();
    final secondStudent = TourFixtures.loadStudent();
    final firstTeacher = TourFixtures.loadTeacher();
    final secondTeacher = TourFixtures.loadTeacher();

    expect(identical(firstStudent, secondStudent), isTrue);
    expect(identical(firstTeacher, secondTeacher), isTrue);

    expect(firstStudent.user.role, 'student');
    expect(firstTeacher.user.role, 'mohaffez');
  });
}
