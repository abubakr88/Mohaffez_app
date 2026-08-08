import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/quran_local_store.dart';

typedef QuranLocalProviderScope = ({
  String userId,
  String? studentProfileId,
});

QuranLocalScope quranLocalScopeFromProvider(QuranLocalProviderScope scope) {
  return QuranLocalScope(
    userId: scope.userId,
    studentProfileId: scope.studentProfileId,
  );
}

final quranLocalProgressProvider = FutureProvider.autoDispose
    .family<QuranLocalProgress, QuranLocalProviderScope>((ref, scope) async {
  final store = await QuranLocalStore.create();
  return store.loadProgress(quranLocalScopeFromProvider(scope));
});

final quranCachedSessionsProvider = FutureProvider.autoDispose
    .family<List<CachedQuranSession>, QuranLocalProviderScope>(
        (ref, scope) async {
  final store = await QuranLocalStore.create();
  return store.loadSessions(quranLocalScopeFromProvider(scope));
});

void invalidateQuranLocalData(
  WidgetRef ref,
  QuranLocalProviderScope scope,
) {
  ref.invalidate(quranLocalProgressProvider(scope));
  ref.invalidate(quranCachedSessionsProvider(scope));
}
