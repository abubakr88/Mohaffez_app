import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_web/features/admin/users/admin_users_csv.dart';

void main() {
  test('exports teacher image and public profile URLs', () {
    final rows = buildAdminUsersCsvRows([
      {
        'id': 'teacher-1',
        'name': 'أحمد المعلم',
        'role': 'mohaffez',
        'status': 'active',
        'photoUrl': 'https://cdn.example.com/teacher.jpg',
        'badges': {
          'foundingTeacher': {'enabled': true},
        },
      },
    ]);

    expect(rows, hasLength(1));
    expect(rows.single[0], 'teacher-1');
    expect(rows.single[3], 'محفظ');
    expect(rows.single[15], 'https://cdn.example.com/teacher.jpg');
    expect(rows.single[16], 'https://app.mohafezy.com/p/t/teacher-1');
    expect(rows.single[21], 'نعم');
  });

  test('does not expose a public profile URL for non-teachers', () {
    final rows = buildAdminUsersCsvRows([
      {
        'id': 'student-1',
        'name': 'طالب',
        'role': 'student',
      },
    ]);

    expect(rows.single[16], isEmpty);
  });
}
