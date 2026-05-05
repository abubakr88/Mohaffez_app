import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/quran_quiz_bank.dart';
import '../state/quiz_session_controller.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/quiz_buttons.dart';
import '../widgets/quiz_design_tokens.dart';
import '../widgets/result_banner.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

class OrderAyahsGame extends ConsumerStatefulWidget {
  final ConfettiOverlayController confetti;
  final VoidCallback onBackToMenu;

  const OrderAyahsGame({
    super.key,
    required this.confetti,
    required this.onBackToMenu,
  });

  @override
  ConsumerState<OrderAyahsGame> createState() => _OrderAyahsGameState();
}

class _OrderAyahsGameState extends ConsumerState<OrderAyahsGame> {
  List<QuizAyah> _group = [];
  final List<int> _selection = []; // tap order — indices into _group
  bool _submitted = false;
  bool _correct = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNext();
    });
  }

  void _loadNext() {
    final used = ref.read(quizSessionControllerProvider).usedGroupIds;
    final ctrl = ref.read(quizSessionControllerProvider.notifier);
    if (used.length >= QuranQuizBank.orderedGroups.length) ctrl.clearUsedGroups();
    final group = QuranQuizBank.randomGroup(usedGroupIds: used);
    if (group.isNotEmpty && group.first.groupId != null) {
      ctrl.markGroupUsed(group.first.groupId!);
    }
    if (!mounted) return;
    setState(() {
      _group = List.from(group)..shuffle();
      _selection.clear();
      _submitted = false;
      _correct = false;
    });
  }

  void _tap(int index) {
    if (_submitted) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_selection.contains(index)) {
        _selection.remove(index);
      } else {
        _selection.add(index);
      }
    });
  }

  void _submit() {
    if (_selection.length != _group.length) return;
    bool ok = true;
    for (int i = 0; i < _selection.length; i++) {
      if (_group[_selection[i]].orderInGroup != i + 1) {
        ok = false;
        break;
      }
    }
    final newStreak =
        ref.read(quizSessionControllerProvider.notifier).recordAnswer(ok);
    setState(() {
      _submitted = true;
      _correct = ok;
    });
    HapticFeedback.mediumImpact();
    if (ok) {
      // Order game is harder — use fireworks on a single correct answer too
      widget.confetti.celebrate(
        intensity: newStreak >= 2
            ? ConfettiIntensity.fireworks
            : ConfettiIntensity.normal,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_group.isEmpty) return const SizedBox.shrink();
    final surahName = _group.first.surahName;
    final allSelected = _selection.length == _group.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppThemeConstants.white,
              borderRadius: QuizDS.r16,
              border: Border.all(color: QuizDS.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.sort_rounded, color: QuizDS.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'رتّب آيات سورة $surahName بالترتيب الصحيح',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: QuizDS.text1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_group.length, (i) => _buildAyahCard(i)),
          const SizedBox(height: 8),
          if (_submitted) ...[
            AnimatedResultBanner(correct: _correct),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TealButton(
                label: 'مجموعة أخرى',
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: _loadNext,
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: AnimatedOpacity(
                opacity: allSelected ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: TealButton(
                  label: 'تحقق من الترتيب',
                  icon: Icons.check_circle_outline_rounded,
                  onTap: allSelected ? _submit : null,
                ),
              ),
            ),
            if (!allSelected) ...[
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'اضغط على الآيات بالترتيب الصحيح',
                  style: TextStyle(fontSize: 13, color: QuizDS.text3),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          BackToMenuButton(onTap: widget.onBackToMenu),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAyahCard(int i) {
    final ayah = _group[i];
    final tapOrder = _selection.indexOf(i);
    final isSelected = tapOrder != -1;
    final userPos = isSelected ? tapOrder + 1 : null;
    final correctPos = ayah.orderInGroup;

    Color borderColor = QuizDS.border;
    Color bgColor = AppThemeConstants.white;
    Color badgeColor = QuizDS.teal50;

    if (_submitted) {
      final isCorrectPos = isSelected && userPos == correctPos;
      borderColor = isCorrectPos ? QuizDS.green : QuizDS.red;
      bgColor = isCorrectPos ? QuizDS.greenBg : QuizDS.red.withValues(alpha: 0.06);
      badgeColor = isCorrectPos ? QuizDS.green : QuizDS.red;
    } else if (isSelected) {
      borderColor = QuizDS.blue;
      bgColor = QuizDS.blueBg.withValues(alpha: 0.7);
      badgeColor = QuizDS.blue;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: _submitted ? null : () => _tap(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: QuizDS.r16,
            border: Border.all(
              color: borderColor,
              width: isSelected || _submitted ? 1.5 : 1,
            ),
            boxShadow: isSelected && !_submitted
                ? [
                    BoxShadow(
                      color: QuizDS.blue.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected || _submitted ? badgeColor : QuizDS.teal50,
                  border: isSelected || _submitted
                      ? null
                      : Border.all(color: QuizDS.border),
                ),
                child: Center(
                  child: _submitted && !isSelected
                      ? const Icon(Icons.close, color: AppThemeConstants.white, size: 16)
                      : _submitted
                          ? Icon(
                              userPos == correctPos
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              color: AppThemeConstants.white,
                              size: 16,
                            )
                          : Text(
                              isSelected ? '$userPos' : '?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? AppThemeConstants.white : QuizDS.text3,
                              ),
                            ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  ayah.text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _submitted
                        ? (userPos == correctPos ? QuizDS.green : QuizDS.red)
                        : QuizDS.text1,
                    height: 1.8,
                    fontFamily: 'Amiri',
                  ),
                ),
              ),
              if (_submitted && userPos != correctPos)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(
                      color: QuizDS.teal50,
                      borderRadius: QuizDS.r12,
                    ),
                    child: Text(
                      'رقم $correctPos',
                      style: const TextStyle(
                        fontSize: 11,
                        color: QuizDS.teal500,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
