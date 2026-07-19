String normalizeAdminUserSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll('ـ', '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[^\w\u0600-\u06FF]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> adminUserSearchTerms(String rawQuery) {
  final normalized = normalizeAdminUserSearchText(rawQuery);
  if (normalized.isEmpty) return const [];

  return normalized
      .split(' ')
      .where((term) => term.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

String strongestAdminUserSearchTerm(List<String> terms) {
  if (terms.isEmpty) return '';

  return terms.reduce(
    (current, next) => next.length > current.length ? next : current,
  );
}

bool matchesAdminUserSearch(
  Map<String, dynamic> user,
  List<String> terms,
) {
  if (terms.isEmpty) return true;

  final searchableText = normalizeAdminUserSearchText(
    [
      user['name'],
      user['id'],
      user['email'],
      user['phoneNumber'],
      user['pricingSearchText'],
    ].whereType<Object>().join(' '),
  );

  return terms.every(searchableText.contains);
}
