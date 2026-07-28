import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('assignment Surah and first ayah resolve to the bundled Mushaf page',
      () async {
    final service = QuranService();

    expect(
      await service.findPageForAssignment('البقرة', fromAyah: '3'),
      2,
    );
    expect(
      await service.findPageForAssignment('سورة البقرة', fromAyah: '٢٥٣'),
      42,
    );
    expect(
      await service.findPageForAssignment('الفاتحة'),
      1,
    );
  });

  test('unknown assignment opens the manual fallback', () async {
    expect(
      await QuranService().findPageForAssignment('ورد غير محدد'),
      isNull,
    );
  });

  test('all 114 Surah names resolve to their Mushaf start pages', () async {
    final service = QuranService();

    for (final entry in QuranService.surahNames.entries) {
      expect(
        await service.findPageForAssignment(entry.value),
        QuranService.surahStartPages[entry.key],
        reason: 'Surah ${entry.key}: ${entry.value}',
      );
    }
  });
}
