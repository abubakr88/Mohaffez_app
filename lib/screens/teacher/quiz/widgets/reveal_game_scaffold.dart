import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'quiz_buttons.dart';
import 'quiz_design_tokens.dart';
import 'result_banner.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

/// Shared layout for "tap-to-reveal then mark صحيح/خطأ" games (Complete Ayah,
/// Name Surah, Custom Questions). Encapsulates:
///   - the reveal card with cross-fade
///   - the صحيح / خطأ outline buttons
///   - the animated result banner
///   - the "next question" CTA
///   - the back-to-menu link
class RevealGameScaffold extends StatelessWidget {
  final Widget questionWidget;
  final Widget revealWidget;
  final bool revealed;
  final bool? markedCorrect;
  final Color accentColor;
  final VoidCallback onReveal;
  final void Function(bool correct) onMark;
  final VoidCallback onNext;
  final VoidCallback onBackToMenu;
  final String nextLabel;
  final IconData nextIcon;
  final Widget? extraRevealedContent;

  const RevealGameScaffold({
    super.key,
    required this.questionWidget,
    required this.revealWidget,
    required this.revealed,
    required this.markedCorrect,
    required this.accentColor,
    required this.onReveal,
    required this.onMark,
    required this.onNext,
    required this.onBackToMenu,
    this.nextLabel = 'سؤال جديد',
    this.nextIcon = Icons.arrow_back_ios_new_rounded,
    this.extraRevealedContent,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: revealed
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onReveal();
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppThemeConstants.white,
                borderRadius: QuizDS.r20,
                border: Border.all(
                  color: markedCorrect == null
                      ? (revealed
                          ? accentColor.withValues(alpha: 0.35)
                          : QuizDS.border)
                      : markedCorrect!
                          ? QuizDS.green.withValues(alpha: 0.5)
                          : QuizDS.red.withValues(alpha: 0.5),
                  width: markedCorrect != null ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AnimatedCrossFade(
                    firstChild: questionWidget,
                    secondChild: Column(
                      children: [
                        revealWidget,
                        if (extraRevealedContent != null) ...[
                          const SizedBox(height: 16),
                          extraRevealedContent!,
                        ],
                      ],
                    ),
                    crossFadeState: revealed
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 350),
                  ),
                  if (!revealed) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 16,
                          color: accentColor.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'اضغط للكشف',
                          style: TextStyle(
                            fontSize: 13,
                            color: accentColor.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (markedCorrect != null) ...[
            AnimatedResultBanner(correct: markedCorrect!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TealButton(
                label: nextLabel,
                icon: nextIcon,
                onTap: onNext,
              ),
            ),
          ] else if (revealed) ...[
            Row(
              children: [
                Expanded(
                  child: OutlineActionButton(
                    label: 'خطأ',
                    icon: Icons.close_rounded,
                    color: QuizDS.red,
                    onTap: () => onMark(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlineActionButton(
                    label: 'صحيح',
                    icon: Icons.check_rounded,
                    color: QuizDS.green,
                    onTap: () => onMark(true),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          BackToMenuButton(onTap: onBackToMenu),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
