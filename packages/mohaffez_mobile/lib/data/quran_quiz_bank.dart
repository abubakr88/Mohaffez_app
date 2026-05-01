import 'dart:math';

class QuizAyah {
  final String text;
  final String textStart;
  final String surahName;
  final int surahNumber;
  final int juzNumber;
  final int ayahNumber;
  final List<String> tajweedRules;
  final int? groupId;
  final int orderInGroup;

  const QuizAyah({
    required this.text,
    required this.textStart,
    required this.surahName,
    required this.surahNumber,
    required this.juzNumber,
    required this.ayahNumber,
    required this.tajweedRules,
    this.groupId,
    this.orderInGroup = 0,
  });
}

abstract class QuranQuizBank {
  static const List<String> allTajweedRules = [
    'إخفاء حقيقي',
    'إدغام بغنة',
    'إدغام بلا غنة',
    'إظهار حلقي',
    'إقلاب',
    'قلقلة',
    'مد واجب متصل',
    'مد جائز منفصل',
    'مد عارض للسكون',
    'غنة مشددة',
    'لام التفخيم',
    'لام الترقيق',
  ];

  static List<String> distractorsFor(String correctRule) {
    final pool = allTajweedRules.where((r) => r != correctRule).toList()..shuffle();
    return pool.take(3).toList();
  }

  static QuizAyah randomAyah({List<int> used = const []}) {
    final pool = <int>[];
    for (int i = 0; i < ayahs.length; i++) {
      if (!used.contains(i)) pool.add(i);
    }
    if (pool.isEmpty) {
      return ayahs[Random().nextInt(ayahs.length)];
    }
    pool.shuffle();
    return ayahs[pool.first];
  }

  static int indexOf(QuizAyah a) => ayahs.indexOf(a);

  static Map<int, List<QuizAyah>> get orderedGroups {
    final map = <int, List<QuizAyah>>{};
    for (final a in ayahs.where((a) => a.groupId != null)) {
      (map[a.groupId!] ??= []).add(a);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.orderInGroup.compareTo(b.orderInGroup));
    }
    return map;
  }

  static List<QuizAyah> randomGroup({List<int> usedGroupIds = const []}) {
    final groups = orderedGroups;
    final available = groups.keys.where((k) => !usedGroupIds.contains(k)).toList();
    final keys = available.isEmpty ? groups.keys.toList() : available;
    keys.shuffle();
    return groups[keys.first]!;
  }

  static const List<QuizAyah> ayahs = [
    // ─── Group 1: Al-Fatiha 2–5 ──────────────────────────────────
    QuizAyah(
      text: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
      textStart: 'الْحَمْدُ لِلَّهِ',
      surahName: 'الفاتحة', surahNumber: 1, juzNumber: 1, ayahNumber: 2,
      tajweedRules: ['لام الترقيق', 'مد عارض للسكون'],
      groupId: 1, orderInGroup: 1,
    ),
    QuizAyah(
      text: 'الرَّحْمَنِ الرَّحِيمِ',
      textStart: 'الرَّحْمَنِ الرَّحِيمِ',
      surahName: 'الفاتحة', surahNumber: 1, juzNumber: 1, ayahNumber: 3,
      tajweedRules: ['مد طبيعي', 'مد عارض للسكون'],
      groupId: 1, orderInGroup: 2,
    ),
    QuizAyah(
      text: 'مَالِكِ يَوْمِ الدِّينِ',
      textStart: 'مَالِكِ يَوْمِ',
      surahName: 'الفاتحة', surahNumber: 1, juzNumber: 1, ayahNumber: 4,
      tajweedRules: ['مد طبيعي', 'مد عارض للسكون'],
      groupId: 1, orderInGroup: 3,
    ),
    QuizAyah(
      text: 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
      textStart: 'إِيَّاكَ نَعْبُدُ',
      surahName: 'الفاتحة', surahNumber: 1, juzNumber: 1, ayahNumber: 5,
      tajweedRules: ['إخفاء حقيقي', 'مد عارض للسكون'],
      groupId: 1, orderInGroup: 4,
    ),
    // ─── Group 2: Al-Ikhlas ──────────────────────────────────────
    QuizAyah(
      text: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
      textStart: 'قُلْ هُوَ اللَّهُ',
      surahName: 'الإخلاص', surahNumber: 112, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['لام التفخيم', 'إظهار حلقي'],
      groupId: 2, orderInGroup: 1,
    ),
    QuizAyah(
      text: 'اللَّهُ الصَّمَدُ',
      textStart: 'اللَّهُ الصَّمَدُ',
      surahName: 'الإخلاص', surahNumber: 112, juzNumber: 30, ayahNumber: 2,
      tajweedRules: ['لام التفخيم', 'مد عارض للسكون'],
      groupId: 2, orderInGroup: 2,
    ),
    QuizAyah(
      text: 'لَمْ يَلِدْ وَلَمْ يُولَدْ',
      textStart: 'لَمْ يَلِدْ وَلَمْ',
      surahName: 'الإخلاص', surahNumber: 112, juzNumber: 30, ayahNumber: 3,
      tajweedRules: ['قلقلة', 'مد عارض للسكون'],
      groupId: 2, orderInGroup: 3,
    ),
    QuizAyah(
      text: 'وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
      textStart: 'وَلَمْ يَكُن لَّهُ',
      surahName: 'الإخلاص', surahNumber: 112, juzNumber: 30, ayahNumber: 4,
      tajweedRules: ['إدغام بلا غنة', 'مد عارض للسكون'],
      groupId: 2, orderInGroup: 4,
    ),
    // ─── Group 3: Al-Falaq ───────────────────────────────────────
    QuizAyah(
      text: 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ',
      textStart: 'قُلْ أَعُوذُ بِرَبِّ',
      surahName: 'الفلق', surahNumber: 113, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['مد طبيعي', 'قلقلة'],
      groupId: 3, orderInGroup: 1,
    ),
    QuizAyah(
      text: 'مِن شَرِّ مَا خَلَقَ',
      textStart: 'مِن شَرِّ مَا',
      surahName: 'الفلق', surahNumber: 113, juzNumber: 30, ayahNumber: 2,
      tajweedRules: ['إخفاء حقيقي', 'قلقلة'],
      groupId: 3, orderInGroup: 2,
    ),
    QuizAyah(
      text: 'وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ',
      textStart: 'وَمِن شَرِّ غَاسِقٍ',
      surahName: 'الفلق', surahNumber: 113, juzNumber: 30, ayahNumber: 3,
      tajweedRules: ['إخفاء حقيقي', 'إظهار حلقي', 'قلقلة'],
      groupId: 3, orderInGroup: 3,
    ),
    QuizAyah(
      text: 'وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ',
      textStart: 'وَمِن شَرِّ النَّفَّاثَاتِ',
      surahName: 'الفلق', surahNumber: 113, juzNumber: 30, ayahNumber: 4,
      tajweedRules: ['إخفاء حقيقي', 'غنة مشددة', 'قلقلة'],
      groupId: 3, orderInGroup: 4,
    ),
    // ─── Group 4: An-Nas ─────────────────────────────────────────
    QuizAyah(
      text: 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ',
      textStart: 'قُلْ أَعُوذُ بِرَبِّ',
      surahName: 'الناس', surahNumber: 114, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['مد جائز منفصل', 'غنة مشددة'],
      groupId: 4, orderInGroup: 1,
    ),
    QuizAyah(
      text: 'مَلِكِ النَّاسِ',
      textStart: 'مَلِكِ النَّاسِ',
      surahName: 'الناس', surahNumber: 114, juzNumber: 30, ayahNumber: 2,
      tajweedRules: ['غنة مشددة', 'مد عارض للسكون'],
      groupId: 4, orderInGroup: 2,
    ),
    QuizAyah(
      text: 'إِلَهِ النَّاسِ',
      textStart: 'إِلَهِ النَّاسِ',
      surahName: 'الناس', surahNumber: 114, juzNumber: 30, ayahNumber: 3,
      tajweedRules: ['غنة مشددة', 'مد عارض للسكون'],
      groupId: 4, orderInGroup: 3,
    ),
    QuizAyah(
      text: 'مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ',
      textStart: 'مِن شَرِّ الْوَسْوَاسِ',
      surahName: 'الناس', surahNumber: 114, juzNumber: 30, ayahNumber: 4,
      tajweedRules: ['إخفاء حقيقي', 'غنة مشددة'],
      groupId: 4, orderInGroup: 4,
    ),
    // ─── Group 5: Al-Kawthar ─────────────────────────────────────
    QuizAyah(
      text: 'إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ',
      textStart: 'إِنَّا أَعْطَيْنَاكَ',
      surahName: 'الكوثر', surahNumber: 108, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['غنة مشددة', 'مد جائز منفصل'],
      groupId: 5, orderInGroup: 1,
    ),
    QuizAyah(
      text: 'فَصَلِّ لِرَبِّكَ وَانْحَرْ',
      textStart: 'فَصَلِّ لِرَبِّكَ',
      surahName: 'الكوثر', surahNumber: 108, juzNumber: 30, ayahNumber: 2,
      tajweedRules: ['إخفاء حقيقي', 'مد عارض للسكون'],
      groupId: 5, orderInGroup: 2,
    ),
    QuizAyah(
      text: 'إِنَّ شَانِئَكَ هُوَ الْأَبْتَرُ',
      textStart: 'إِنَّ شَانِئَكَ هُوَ',
      surahName: 'الكوثر', surahNumber: 108, juzNumber: 30, ayahNumber: 3,
      tajweedRules: ['غنة مشددة', 'مد عارض للسكون'],
      groupId: 5, orderInGroup: 3,
    ),
    // ─── Group 6: An-Nasr ────────────────────────────────────────
    QuizAyah(
      text: 'إِذَا جَاءَ نَصْرُ اللَّهِ وَالْفَتْحُ',
      textStart: 'إِذَا جَاءَ نَصْرُ',
      surahName: 'النصر', surahNumber: 110, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['مد واجب متصل', 'لام الترقيق'],
      groupId: 6, orderInGroup: 1,
    ),
    QuizAyah(
      text: 'وَرَأَيْتَ النَّاسَ يَدْخُلُونَ فِي دِينِ اللَّهِ أَفْوَاجًا',
      textStart: 'وَرَأَيْتَ النَّاسَ',
      surahName: 'النصر', surahNumber: 110, juzNumber: 30, ayahNumber: 2,
      tajweedRules: ['غنة مشددة', 'لام الترقيق', 'مد جائز منفصل'],
      groupId: 6, orderInGroup: 2,
    ),
    QuizAyah(
      text: 'فَسَبِّحْ بِحَمْدِ رَبِّكَ وَاسْتَغْفِرْهُ إِنَّهُ كَانَ تَوَّابًا',
      textStart: 'فَسَبِّحْ بِحَمْدِ رَبِّكَ',
      surahName: 'النصر', surahNumber: 110, juzNumber: 30, ayahNumber: 3,
      tajweedRules: ['غنة مشددة', 'مد عارض للسكون'],
      groupId: 6, orderInGroup: 3,
    ),
    // ─── Group 7: Az-Zalzalah 1–4 ────────────────────────────────
    QuizAyah(
      text: 'إِذَا زُلْزِلَتِ الْأَرْضُ زِلْزَالَهَا',
      textStart: 'إِذَا زُلْزِلَتِ الْأَرْضُ',
      surahName: 'الزلزلة', surahNumber: 99, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['مد طبيعي'],
      groupId: 7, orderInGroup: 1,
    ),
    QuizAyah(
      text: 'وَأَخْرَجَتِ الْأَرْضُ أَثْقَالَهَا',
      textStart: 'وَأَخْرَجَتِ الْأَرْضُ',
      surahName: 'الزلزلة', surahNumber: 99, juzNumber: 30, ayahNumber: 2,
      tajweedRules: ['مد جائز منفصل'],
      groupId: 7, orderInGroup: 2,
    ),
    QuizAyah(
      text: 'وَقَالَ الْإِنسَانُ مَا لَهَا',
      textStart: 'وَقَالَ الْإِنسَانُ',
      surahName: 'الزلزلة', surahNumber: 99, juzNumber: 30, ayahNumber: 3,
      tajweedRules: ['إخفاء حقيقي', 'مد طبيعي'],
      groupId: 7, orderInGroup: 3,
    ),
    QuizAyah(
      text: 'يَوْمَئِذٍ تُحَدِّثُ أَخْبَارَهَا',
      textStart: 'يَوْمَئِذٍ تُحَدِّثُ',
      surahName: 'الزلزلة', surahNumber: 99, juzNumber: 30, ayahNumber: 4,
      tajweedRules: ['إخفاء حقيقي', 'غنة مشددة'],
      groupId: 7, orderInGroup: 4,
    ),
    // ─── Group 8: Al-Asr ─────────────────────────────────────────
    QuizAyah(
      text: 'وَالْعَصْرِ',
      textStart: 'وَالْعَصْرِ',
      surahName: 'العصر', surahNumber: 103, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['مد عارض للسكون'],
      groupId: 8, orderInGroup: 1,
    ),
    QuizAyah(
      text: 'إِنَّ الْإِنسَانَ لَفِي خُسْرٍ',
      textStart: 'إِنَّ الْإِنسَانَ لَفِي',
      surahName: 'العصر', surahNumber: 103, juzNumber: 30, ayahNumber: 2,
      tajweedRules: ['غنة مشددة', 'إخفاء حقيقي'],
      groupId: 8, orderInGroup: 2,
    ),
    QuizAyah(
      text: 'إِلَّا الَّذِينَ آمَنُوا وَعَمِلُوا الصَّالِحَاتِ وَتَوَاصَوْا بِالْحَقِّ وَتَوَاصَوْا بِالصَّبْرِ',
      textStart: 'إِلَّا الَّذِينَ آمَنُوا',
      surahName: 'العصر', surahNumber: 103, juzNumber: 30, ayahNumber: 3,
      tajweedRules: ['مد واجب متصل', 'إدغام بغنة', 'مد عارض للسكون'],
      groupId: 8, orderInGroup: 3,
    ),
    // ─── Group 9: Al-Masad 1–4 ───────────────────────────────────
    QuizAyah(
      text: 'تَبَّتْ يَدَا أَبِي لَهَبٍ وَتَبَّ',
      textStart: 'تَبَّتْ يَدَا أَبِي',
      surahName: 'المسد', surahNumber: 111, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['قلقلة', 'إدغام بغنة'],
      groupId: 9, orderInGroup: 1,
    ),
    QuizAyah(
      text: 'مَا أَغْنَى عَنْهُ مَالُهُ وَمَا كَسَبَ',
      textStart: 'مَا أَغْنَى عَنْهُ',
      surahName: 'المسد', surahNumber: 111, juzNumber: 30, ayahNumber: 2,
      tajweedRules: ['إظهار حلقي', 'مد طبيعي'],
      groupId: 9, orderInGroup: 2,
    ),
    QuizAyah(
      text: 'سَيَصْلَى نَارًا ذَاتَ لَهَبٍ',
      textStart: 'سَيَصْلَى نَارًا ذَاتَ',
      surahName: 'المسد', surahNumber: 111, juzNumber: 30, ayahNumber: 3,
      tajweedRules: ['إخفاء حقيقي', 'مد طبيعي'],
      groupId: 9, orderInGroup: 3,
    ),
    QuizAyah(
      text: 'وَامْرَأَتُهُ حَمَّالَةَ الْحَطَبِ',
      textStart: 'وَامْرَأَتُهُ حَمَّالَةَ',
      surahName: 'المسد', surahNumber: 111, juzNumber: 30, ayahNumber: 4,
      tajweedRules: ['غنة مشددة', 'قلقلة'],
      groupId: 9, orderInGroup: 4,
    ),
    // ─── Group 10: Al-Kafirun 1–4 ────────────────────────────────
    QuizAyah(
      text: 'قُلْ يَا أَيُّهَا الْكَافِرُونَ',
      textStart: 'قُلْ يَا أَيُّهَا',
      surahName: 'الكافرون', surahNumber: 109, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['إدغام بغنة', 'مد عارض للسكون'],
      groupId: 10, orderInGroup: 1,
    ),
    QuizAyah(
      text: 'لَا أَعْبُدُ مَا تَعْبُدُونَ',
      textStart: 'لَا أَعْبُدُ مَا',
      surahName: 'الكافرون', surahNumber: 109, juzNumber: 30, ayahNumber: 2,
      tajweedRules: ['مد طبيعي', 'مد عارض للسكون'],
      groupId: 10, orderInGroup: 2,
    ),
    QuizAyah(
      text: 'وَلَا أَنتُمْ عَابِدُونَ مَا أَعْبُدُ',
      textStart: 'وَلَا أَنتُمْ عَابِدُونَ',
      surahName: 'الكافرون', surahNumber: 109, juzNumber: 30, ayahNumber: 3,
      tajweedRules: ['إخفاء حقيقي', 'مد جائز منفصل'],
      groupId: 10, orderInGroup: 3,
    ),
    QuizAyah(
      text: 'وَلَا أَنَا عَابِدٌ مَّا عَبَدتُّمْ',
      textStart: 'وَلَا أَنَا عَابِدٌ',
      surahName: 'الكافرون', surahNumber: 109, juzNumber: 30, ayahNumber: 4,
      tajweedRules: ['إدغام بغنة', 'غنة مشددة'],
      groupId: 10, orderInGroup: 4,
    ),
    // ─── Individual ayahs (all games 1–3) ────────────────────────
    QuizAyah(
      text: 'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
      textStart: 'اللَّهُ لَا إِلَهَ',
      surahName: 'البقرة', surahNumber: 2, juzNumber: 3, ayahNumber: 255,
      tajweedRules: ['لام التفخيم', 'مد واجب متصل', 'غنة مشددة'],
    ),
    QuizAyah(
      text: 'لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا',
      textStart: 'لَا يُكَلِّفُ اللَّهُ',
      surahName: 'البقرة', surahNumber: 2, juzNumber: 3, ayahNumber: 286,
      tajweedRules: ['لام التفخيم', 'إخفاء حقيقي', 'مد جائز منفصل'],
    ),
    QuizAyah(
      text: 'إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ',
      textStart: 'إِنَّا لِلَّهِ وَإِنَّا',
      surahName: 'البقرة', surahNumber: 2, juzNumber: 2, ayahNumber: 156,
      tajweedRules: ['غنة مشددة', 'لام الترقيق', 'مد جائز منفصل'],
    ),
    QuizAyah(
      text: 'كُلُّ نَفْسٍ ذَائِقَةُ الْمَوْتِ',
      textStart: 'كُلُّ نَفْسٍ ذَائِقَةُ',
      surahName: 'آل عمران', surahNumber: 3, juzNumber: 4, ayahNumber: 185,
      tajweedRules: ['إخفاء حقيقي', 'مد طبيعي'],
    ),
    QuizAyah(
      text: 'تَبَارَكَ الَّذِي بِيَدِهِ الْمُلْكُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
      textStart: 'تَبَارَكَ الَّذِي بِيَدِهِ',
      surahName: 'الملك', surahNumber: 67, juzNumber: 29, ayahNumber: 1,
      tajweedRules: ['مد واجب متصل', 'قلقلة', 'مد عارض للسكون'],
    ),
    QuizAyah(
      text: 'الرَّحْمَنُ عَلَّمَ الْقُرْآنَ',
      textStart: 'الرَّحْمَنُ عَلَّمَ',
      surahName: 'الرحمن', surahNumber: 55, juzNumber: 27, ayahNumber: 1,
      tajweedRules: ['غنة مشددة', 'مد واجب متصل'],
    ),
    QuizAyah(
      text: 'سَبِّحِ اسْمَ رَبِّكَ الْأَعْلَى',
      textStart: 'سَبِّحِ اسْمَ رَبِّكَ',
      surahName: 'الأعلى', surahNumber: 87, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['غنة مشددة', 'مد واجب متصل'],
    ),
    QuizAyah(
      text: 'وَالضُّحَى',
      textStart: 'وَالضُّحَى',
      surahName: 'الضحى', surahNumber: 93, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['مد عارض للسكون'],
    ),
    QuizAyah(
      text: 'وَاللَّيْلِ إِذَا سَجَى',
      textStart: 'وَاللَّيْلِ إِذَا سَجَى',
      surahName: 'الضحى', surahNumber: 93, juzNumber: 30, ayahNumber: 2,
      tajweedRules: ['لام الترقيق', 'مد طبيعي'],
    ),
    QuizAyah(
      text: 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
      textStart: 'فَإِنَّ مَعَ الْعُسْرِ',
      surahName: 'الشرح', surahNumber: 94, juzNumber: 30, ayahNumber: 5,
      tajweedRules: ['غنة مشددة', 'مد عارض للسكون'],
    ),
    QuizAyah(
      text: 'وَالسَّمَاءِ ذَاتِ الْبُرُوجِ',
      textStart: 'وَالسَّمَاءِ ذَاتِ',
      surahName: 'البروج', surahNumber: 85, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['مد واجب متصل'],
    ),
    QuizAyah(
      text: 'وَالسَّمَاءِ وَالطَّارِقِ',
      textStart: 'وَالسَّمَاءِ وَالطَّارِقِ',
      surahName: 'الطارق', surahNumber: 86, juzNumber: 30, ayahNumber: 1,
      tajweedRules: ['مد طبيعي', 'مد عارض للسكون'],
    ),
  ];
}
