const adminUsersCsvHeader = <String>[
  'المعرّف',
  'الاسم',
  'اللقب',
  'الدور',
  'الحالة',
  'البريد الإلكتروني',
  'رقم الهاتف',
  'النوع',
  'تاريخ الميلاد',
  'المدينة',
  'الدولة',
  'كود الدولة',
  'العنوان',
  'التخصص',
  'النبذة',
  'رابط الصورة',
  'رابط الملف العام',
  'إعداد الحساب مكتمل',
  'حالة التحقق',
  'اجتاز الاختبار',
  'درجة الاختبار',
  'المعلم المؤسس',
  'نوع الحساب',
  'تاريخ التسجيل',
  'آخر نشاط',
];

List<List<Object?>> buildAdminUsersCsvRows(
  Iterable<Map<String, dynamic>> users,
) {
  final sorted = users.toList()
    ..sort((a, b) => _text(a, const ['name', 'displayName'])
        .toLowerCase()
        .compareTo(_text(b, const ['name', 'displayName']).toLowerCase()));

  return sorted.map((user) {
    final id = _text(user, const ['id', 'uid']);
    final role = _text(user, const ['role', 'userType'], fallback: 'student');
    final lastActivity = _firstValue(user, const [
      'lastActiveAt',
      'lastLoginAt',
      'updatedAt',
      'createdAt',
    ]);

    return <Object?>[
      id,
      _text(user, const ['name', 'displayName']),
      _text(user, const ['honorific']),
      _roleLabel(role),
      _statusLabel(_text(user, const ['status'], fallback: 'active')),
      _text(user, const ['email']),
      _text(user, const ['phoneNumber', 'phone']),
      _genderLabel(_text(user, const ['gender'])),
      _dateValue(_firstValue(user, const ['dateOfBirth', 'birthDate'])),
      _text(user, const ['city']),
      _text(user, const ['countryName', 'country']),
      _text(user, const ['countryCode']),
      _text(user, const ['addressText', 'address']),
      _text(user, const ['specialization']),
      _text(user, const ['bio']),
      _text(user, const ['photoUrl', 'profileImageUrl', 'photoURL']),
      role == 'mohaffez' && id.isNotEmpty
          ? 'https://app.mohafezy.com/p/t/$id'
          : '',
      _yesNo(user['setupCompleted']),
      _text(user, const ['verificationStatus', 'verificationState']),
      _yesNo(user['examPassed']),
      _numberText(user['examScore']),
      _foundingTeacherEnabled(user['badges']) ? 'نعم' : 'لا',
      _text(user, const ['accountType']),
      _dateTimeValue(user['createdAt']),
      _dateTimeValue(lastActivity),
    ];
  }).toList();
}

String _text(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return fallback;
}

dynamic _firstValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null) return value;
  }
  return null;
}

String _roleLabel(String role) => switch (role.trim().toLowerCase()) {
      'mohaffez' => 'محفظ',
      'parent' => 'ولي أمر',
      'admin' => 'مدير',
      'organization_admin' => 'مدير مؤسسة',
      'organization_teacher' => 'معلم مؤسسة',
      'organization_student' => 'طالب مؤسسة',
      _ => 'طالب',
    };

String _statusLabel(String status) => switch (status.trim().toLowerCase()) {
      'active' => 'نشط',
      'pending_approval' => 'بانتظار المراجعة',
      'rejected' => 'مرفوض',
      'suspended' => 'معلّق',
      'deleted' => 'محذوف',
      _ => status,
    };

String _genderLabel(String gender) => switch (gender.trim().toLowerCase()) {
      'male' => 'ذكر',
      'female' => 'أنثى',
      _ => gender,
    };

String _yesNo(dynamic value) => value == true ? 'نعم' : 'لا';

String _numberText(dynamic value) {
  if (value is num) return value.toString();
  return value?.toString().trim() ?? '';
}

bool _foundingTeacherEnabled(dynamic badges) {
  if (badges is! Map) return false;
  final founding = badges['foundingTeacher'];
  if (founding is bool) return founding;
  if (founding is Map) return founding['enabled'] == true;
  return false;
}

String _dateValue(dynamic value) {
  final date = _asDateTime(value);
  if (date == null) return value?.toString() ?? '';
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _dateTimeValue(dynamic value) {
  final date = _asDateTime(value);
  if (date == null) return value?.toString() ?? '';
  return date.toUtc().toIso8601String();
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}
