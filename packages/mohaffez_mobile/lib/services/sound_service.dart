import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reward / quiz sound effects. Each maps to a file in `assets/sounds/`
/// (see that folder's README). Missing files fail silently.
enum Sfx {
  clap('sounds/clap.mp3'),
  tryAgain('sounds/try_again.mp3'),
  tap('sounds/tap.mp3'),
  levelUp('sounds/level_up.mp3'),
  badge('sounds/badge.mp3'),
  complete('sounds/complete.mp3');

  const Sfx(this.asset);
  final String asset;
}

/// Lightweight, app-wide sound effect player with a persisted mute toggle.
///
/// Designed to be fire-and-forget: every call is wrapped so a missing asset or
/// platform hiccup can never crash a flow or block the UI. Pairs each effect
/// with an appropriate haptic so feedback still lands even when muted.
class SoundService {
  SoundService._();

  static const _prefKey = 'soundEffectsEnabled';
  static final AudioPlayer _player = AudioPlayer(playerId: 'sfx')
    ..setReleaseMode(ReleaseMode.stop);

  static bool _enabled = true;
  static bool get enabled => _enabled;

  /// Load the persisted preference. Safe to call multiple times.
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? true;
    } catch (_) {
      _enabled = true;
    }
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {/* ignore */}
  }

  /// Plays [sfx] (if enabled) and fires a matching haptic. Never throws.
  static Future<void> play(Sfx sfx, {bool haptic = true}) async {
    if (haptic) _haptic(sfx);
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(sfx.asset), volume: 1.0);
    } catch (e) {
      // Missing file or unsupported platform — ignore, keep the flow alive.
      if (kDebugMode) debugPrint('SoundService: could not play ${sfx.asset}: $e');
    }
  }

  static void _haptic(Sfx sfx) {
    try {
      switch (sfx) {
        case Sfx.clap:
        case Sfx.levelUp:
        case Sfx.badge:
        case Sfx.complete:
          HapticFeedback.mediumImpact();
        case Sfx.tryAgain:
          HapticFeedback.heavyImpact();
        case Sfx.tap:
          HapticFeedback.selectionClick();
      }
    } catch (_) {/* ignore */}
  }

  static Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {/* ignore */}
  }
}
