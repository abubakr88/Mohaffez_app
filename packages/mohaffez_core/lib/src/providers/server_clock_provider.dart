import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ntp/ntp.dart';

/// How often to refresh the NTP offset. Phones can drift, change timezone,
/// or be edited manually mid-session — refreshing avoids stale offsets.
const Duration _kRefreshInterval = Duration(minutes: 30);

/// If the device clock differs from server time by more than this, surface
/// a banner so the user knows to fix their phone clock. (Silent correction
/// alone is confusing because the lock-screen clock will still be wrong.)
const Duration kClockSkewWarningThreshold = Duration(minutes: 2);

/// Per-call NTP timeout. Keep tight so app start isn't blocked.
const Duration _kLookupTimeout = Duration(seconds: 4);

/// Holds the most recently measured offset between server time and device
/// time: `serverNow ≈ DateTime.now().add(offset)`. `null` means we never
/// successfully synced and are falling back to device time.
class ServerClockState {
  final Duration? offset;
  final DateTime? lastSyncedAt;

  const ServerClockState({this.offset, this.lastSyncedAt});

  bool get isSynced => offset != null;

  /// Absolute skew between device and server clocks. Returns `Duration.zero`
  /// if not synced (so the warning banner stays hidden until we know).
  Duration get skew {
    final o = offset;
    if (o == null) return Duration.zero;
    return o.isNegative ? -o : o;
  }
}

/// Notifier that fetches the NTP offset on creation and refreshes it every
/// [_kRefreshInterval]. Failures are swallowed and we fall back to device
/// time — clock sync is best-effort, not a blocker.
class ServerClockNotifier extends StateNotifier<ServerClockState> {
  ServerClockNotifier() : super(const ServerClockState()) {
    _sync();
    _timer = Timer.periodic(_kRefreshInterval, (_) => _sync());
  }

  Timer? _timer;

  Future<void> _sync() async {
    try {
      final ms = await NTP.getNtpOffset(timeout: _kLookupTimeout);
      state = ServerClockState(
        offset: Duration(milliseconds: ms),
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('NTP sync failed: $e');
      // Keep prior offset (or null) — don't clobber a good value with a fail.
    }
  }

  /// Force a refresh — useful after the app comes back from background.
  Future<void> refresh() => _sync();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final serverClockProvider =
    StateNotifierProvider<ServerClockNotifier, ServerClockState>(
        (_) => ServerClockNotifier());

/// Returns the best estimate of the current server time.
///
/// NTP correction is currently **disabled** because the `ntp` package was
/// returning an incorrect offset (~-5 h) on some devices, which shifted
/// every countdown and date comparison in the app. The device clock is
/// correct in practice, so we fall back to it unconditionally until a
/// more reliable server-time source is available.
DateTime serverNow(WidgetRef ref) {
  // ignore: unused_local_variable
  final _ = ref.read(serverClockProvider); // keep provider alive for banner
  return DateTime.now();
}

/// Read-only variant for providers / non-widget contexts.
DateTime serverNowFromRef(Ref ref) {
  // ignore: unused_local_variable
  final _ = ref.read(serverClockProvider);
  return DateTime.now();
}

/// True when the device clock is off by more than the warning threshold.
/// Watch this to show a "fix your phone clock" banner.
final clockSkewWarningProvider = Provider<bool>((ref) {
  final s = ref.watch(serverClockProvider);
  if (!s.isSynced) return false;
  return s.skew > kClockSkewWarningThreshold;
});
