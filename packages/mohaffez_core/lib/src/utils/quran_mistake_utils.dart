// lib/utils/quran_mistake_utils.dart
//
// Flutter-aware helpers for QuranMistake / MistakeType.
// Import this file in any widget that needs Colors, IconData, or UI helpers.
// Keep quran_mistake_model.dart free of Flutter imports.

import 'package:flutter/material.dart';
import '../models/quran_mistake_model.dart';
import '../theme/app_theme_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOR
// ─────────────────────────────────────────────────────────────────────────────

Color getMistakeColor(MistakeType type) {
  switch (type) {
    case MistakeType.tajweed:       return AppThemeConstants.warning;
    case MistakeType.pronunciation: return AppThemeConstants.error;
    case MistakeType.reading:       return AppThemeConstants.accentPurple;
    case MistakeType.skip:          return AppThemeConstants.accentBlue;
    case MistakeType.addition:      return AppThemeConstants.success;
    case MistakeType.other:         return AppThemeConstants.grey500;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ICON
// ─────────────────────────────────────────────────────────────────────────────

IconData getMistakeIcon(MistakeType type) {
  switch (type) {
    case MistakeType.tajweed:       return Icons.auto_fix_high;
    case MistakeType.pronunciation: return Icons.record_voice_over;
    case MistakeType.reading:       return Icons.error_outline;
    case MistakeType.skip:          return Icons.fast_forward;
    case MistakeType.addition:      return Icons.add_circle_outline;
    case MistakeType.other:         return Icons.help_outline;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI EXTENSION ON MistakeType
// (convenience so call sites can write: type.color / type.icon)
// ─────────────────────────────────────────────────────────────────────────────

extension MistakeTypeUI on MistakeType {
  Color get color => getMistakeColor(this);
  IconData get icon => getMistakeIcon(this);

  /// Colored circular avatar — used in lists, chips, and dialogs.
  Widget buildAvatar({double radius = 16}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, size: radius, color: color),
    );
  }

  /// Compact chip for displaying the mistake type inline.
  Widget buildChip() {
    return Chip(
      avatar: Icon(icon, size: 14, color: AppThemeConstants.white),
      label: Text(
        arabicLabel,
        style: const TextStyle(fontSize: 11, color: AppThemeConstants.white),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI EXTENSION ON QuranMistake
// (convenience so call sites can write: mistake.color / mistake.hasComment)
// ─────────────────────────────────────────────────────────────────────────────

extension QuranMistakeUI on QuranMistake {
  Color get color     => getMistakeColor(type);
  IconData get icon   => getMistakeIcon(type);
  String get label    => type.fullLabel;

  /// Builds the marker stack: main colored circle + optional blue comment badge.
  Widget buildMarker({VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Main circle ────────────────────────────────────────────────────
          Tooltip(
            message: label,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(color: AppThemeConstants.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeConstants.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 16, color: AppThemeConstants.white),
            ),
          ),

          // ── Blue comment badge ─────────────────────────────────────────────
          if (hasComment)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: AppThemeConstants.accentBlueDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppThemeConstants.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeConstants.accentBlue.withValues(alpha: 0.4),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child:
                    const Icon(Icons.chat_bubble, size: 8, color: AppThemeConstants.white),
              ),
            ),
        ],
      ),
    );
  }

  /// Summary card used in the student session feedback screen.
  Widget buildSummaryTile({VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),

            // Location + word text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locationText,
                    style: const TextStyle(
                        fontSize: 12, color: AppThemeConstants.grey600),
                  ),
                ],
              ),
            ),

            // Comment indicator
            if (hasComment)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.chat_bubble,
                    size: 16, color: AppThemeConstants.accentBlueDark),
              ),

            const Icon(Icons.chevron_left,
                size: 18, color: AppThemeConstants.grey500),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIST HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Returns mistakes on [page], sorted by vertical position (top → bottom).
List<QuranMistake> getMistakesOnPage(
        List<QuranMistake> mistakes, int page) =>
    mistakes
        .where((m) => m.pageNumber == page)
        .toList()
      ..sort((a, b) => a.yPosition.compareTo(b.yPosition));

/// Groups mistakes by [MistakeType] and returns a count map.
Map<MistakeType, int> groupMistakesByType(List<QuranMistake> mistakes) {
  final map = <MistakeType, int>{};
  for (final m in mistakes) {
    map[m.type] = (map[m.type] ?? 0) + 1;
  }
  return map;
}

/// Returns how many mistakes in [mistakes] have a teacher comment.
int countWithComments(List<QuranMistake> mistakes) =>
    mistakes.where((m) => m.hasComment).length;
