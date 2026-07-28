import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:mohaffez_finder_app/shared/widgets/quran/quran_mistake_painter.dart';

void main() {
  test('nearby mistake markers are grouped without losing their details', () {
    final mistakes = [
      _mistake('first', 0.40, 0.50),
      _mistake('second', 0.42, 0.52),
      _mistake('separate', 0.80, 0.20),
    ];

    final clusters = clusterQuranMistakes(mistakes);

    expect(clusters, hasLength(2));
    expect(
      clusters.map((cluster) => cluster.mistakes.length).toList()..sort(),
      [1, 2],
    );
    expect(
      clusters.expand((cluster) => cluster.mistakes).map((item) => item.id),
      containsAll(<String>['first', 'second', 'separate']),
    );
  });
}

QuranMistake _mistake(String id, double x, double y) {
  return QuranMistake(
    id: id,
    pageNumber: 1,
    surahNumber: 1,
    ayahNumber: 1,
    xPosition: x,
    yPosition: y,
    type: MistakeType.tajweed,
  );
}
