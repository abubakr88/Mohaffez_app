import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

enum DSButtonVariant { primary, secondary, ghost, destructive }
enum DSButtonSize { sm, md, lg }

class DSButton extends StatefulWidget {
  const DSButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DSButtonVariant.primary,
    this.size = DSButtonSize.md,
    this.leading,
    this.trailing,
    this.loading = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DSButtonVariant variant;
  final DSButtonSize size;
  final Widget? leading;
  final Widget? trailing;
  final bool loading;
  final bool fullWidth;

  @override
  State<DSButton> createState() => _DSButtonState();
}

class _DSButtonState extends State<DSButton> {
  bool _hovered = false;

  bool get _disabled => widget.onPressed == null || widget.loading;

  (double, double, double) get _dims => switch (widget.size) {
        DSButtonSize.sm => (28.0, DSSpacing.md, 12.0),
        DSButtonSize.md => (36.0, DSSpacing.lg, 14.0),
        DSButtonSize.lg => (44.0, DSSpacing.xl, 15.0),
      };

  Color get _bg => switch (widget.variant) {
        DSButtonVariant.primary     => _hovered ? DSColors.primaryDark : DSColors.primary,
        DSButtonVariant.secondary   => _hovered ? DSColors.border : DSColors.surface,
        DSButtonVariant.ghost       => _hovered ? DSColors.surfaceMuted : Colors.transparent,
        DSButtonVariant.destructive => _hovered ? const Color(0xFFB91C1C) : DSColors.error,
      };

  Color get _fg => switch (widget.variant) {
        DSButtonVariant.primary     => Colors.white,
        DSButtonVariant.secondary   => DSColors.text1,
        DSButtonVariant.ghost       => DSColors.text2,
        DSButtonVariant.destructive => Colors.white,
      };

  Border? get _border => switch (widget.variant) {
        DSButtonVariant.secondary => Border.all(color: DSColors.border),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final (height, hPad, fontSize) = _dims;
    final textStyle = DSText.resolve(
      context,
      size: fontSize,
      weight: FontWeight.w500,
      color: _disabled ? _fg.withValues(alpha: 0.45) : _fg,
    );

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.loading) ...[
          SizedBox.square(
            dimension: fontSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_fg.withValues(alpha: 0.8)),
            ),
          ),
          const SizedBox(width: DSSpacing.sm),
        ] else if (widget.leading != null) ...[
          widget.leading!,
          const SizedBox(width: DSSpacing.sm),
        ],
        Text(widget.label, style: textStyle),
        if (widget.trailing != null && !widget.loading) ...[
          const SizedBox(width: DSSpacing.sm),
          widget.trailing!,
        ],
      ],
    );

    Widget button = MouseRegion(
      cursor: _disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _disabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: DSDuration.fast,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: hPad),
          decoration: BoxDecoration(
            color: _disabled ? _bg.withValues(alpha: 0.45) : _bg,
            borderRadius: DSRadius.mdAll,
            border: _border,
          ),
          child: Center(child: content),
        ),
      ),
    );

    return widget.fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
