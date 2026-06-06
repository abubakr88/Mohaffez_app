import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';
import '../buttons/ds_button.dart';

class DSDialog extends StatelessWidget {
  const DSDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.width = 480.0,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final double width;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    List<Widget>? actions,
    double width = 480.0,
  }) {
    return showDialog<T>(
      context: context,
      // The admin/teacher/student pages live inside a go_router ShellRoute,
      // which owns a nested Navigator. The dialog's action buttons pop via the
      // caller's page context (nested navigator), so the dialog must be pushed
      // on that SAME navigator — otherwise pop() dismisses the page route
      // instead of the dialog, unmounting the page and dropping the result.
      useRootNavigator: false,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => DSDialog(
        title: title,
        actions: actions,
        width: width,
        child: child,
      ),
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    bool destructive = false,
  }) async {
    final result = await show<bool>(
      context,
      title: title,
      child: Text(message, style: DSText.body(context, color: DSColors.text2)),
      actions: [
        DSButton(
          label: cancelLabel,
          variant: DSButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DSButton(
          label: confirmLabel,
          variant: destructive ? DSButtonVariant.destructive : DSButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: DSColors.surface,
          borderRadius: DSRadius.xlAll,
          boxShadow: DSElevation.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DSSpacing.xl, DSSpacing.xl, DSSpacing.xl, DSSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: DSText.h2(context))),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded, size: 20, color: DSColors.text2),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: DSColors.border),
            Padding(
              padding: const EdgeInsets.all(DSSpacing.xl),
              child: child,
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const Divider(height: 1, color: DSColors.border),
              Padding(
                padding: const EdgeInsets.all(DSSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!
                      .expand((a) => [a, const SizedBox(width: DSSpacing.sm)])
                      .toList()
                    ..removeLast(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
