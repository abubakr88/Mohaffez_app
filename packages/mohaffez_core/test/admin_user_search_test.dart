import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/src/utils/admin_user_search.dart';

void main() {
  group('admin user search', () {
    final teacher = <String, dynamic>{
      'id': 'teacher-1',
      'name': 'أبو بكر رمضان',
      'email': 'teacher@example.com',
      'phoneNumber': '0100-123-4567',
      'pricingSearchText': 'باقة الفاتحة للأطفال 8 جلسات تجويد أونلاين',
    };

    test('matches a teacher by normalized bundle name', () {
      expect(
        matchesAdminUserSearch(
          teacher,
          adminUserSearchTerms('باقه الفاتحه'),
        ),
        isTrue,
      );
    });

    test('keeps existing identity search fields working', () {
      expect(
        matchesAdminUserSearch(teacher, adminUserSearchTerms('teacher-1')),
        isTrue,
      );
      expect(
        matchesAdminUserSearch(teacher, adminUserSearchTerms('0100 123')),
        isTrue,
      );
    });

    test('requires every entered search term', () {
      expect(
        matchesAdminUserSearch(
          teacher,
          adminUserSearchTerms('الفاتحة حضوري'),
        ),
        isFalse,
      );
    });

    test('uses the longest term for the indexed lookup', () {
      expect(
        strongestAdminUserSearchTerm(['باقه', 'الفاتحه', '8']),
        'الفاتحه',
      );
    });
  });
}
