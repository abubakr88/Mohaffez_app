import 'package:flutter/material.dart';

/// Design tokens shared across all quiz games.
///
/// Kept playful but reverent — soft teal/gold base palette aligned with
/// the rest of the app, plus accent colors for per-game theming.
class QuizDS {
  QuizDS._();

  // Brand
  static const teal700  = Color(0xFF0C6F6A);
  static const teal600  = Color(0xFF0E8278);
  static const teal500  = Color(0xFF1A9E84);
  static const teal100  = Color(0xFFD4EDE7);
  static const teal50   = Color(0xFFEAF6F3);

  // Per-game accents
  static const amber    = Color(0xFFE67E22);
  static const amberBg  = Color(0xFFFFF3E0);
  static const purple   = Color(0xFF7A5AF8);
  static const purpleBg = Color(0xFFF0EEFF);
  static const blue     = Color(0xFF2563EB);
  static const blueBg   = Color(0xFFE3F2FD);

  // Status
  static const green    = Color(0xFF2E8B57);
  static const greenBg  = Color(0xFFE8F5E9);
  static const red      = Color(0xFFE53935);
  static const redBg    = Color(0xFFFFEBEE);

  // Surface
  static const bg       = Color(0xFFF4F7F6);
  static const text1    = Color(0xFF111827);
  static const text2    = Color(0xFF4B5563);
  static const text3    = Color(0xFF9CA3AF);
  static const border   = Color(0xFFE5EDE9);

  // Confetti palette — bright but limited so it stays tasteful
  static const confettiColors = <Color>[
    teal500,
    amber,
    purple,
    blue,
    green,
    Color(0xFFFFD54F), // soft gold
  ];

  // Radii
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r20 = BorderRadius.all(Radius.circular(20));
  static const r24 = BorderRadius.all(Radius.circular(24));
}
