import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';

enum DSIconButtonVariant { ghost, filled, outlined }

class DSIconButton extends StatefulWidget {
  const DSIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.variant = DSIconButtonVariant.ghost,
    this.size = 36.0,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final DSIconButtonVariant variant;
  final double size;
  final String? tooltip;
  final Color? color;

  @override
  State<DSIconButton> createState() => _DSIconButtonState();
}

class _DSIconButtonState extends State<DSIconButton> {
  bool _hovered = false;

  Color get _bg => switch (widget.variant) {
        DSIconButtonVariant.ghost    => _hovered ? DSColors.surfaceMuted : Colors.transparent,
        DSIconButtonVariant.filled   => _hovered ? DSColors.primaryDark : DSColors.primary,
        DSIconButtonVariant.outlined => _hovered ? DSColors.surfaceMuted : Colors.transparent,
      };

  Color get _iconColor {
    if (widget.color != null) return widget.color!;
    return switch (widget.variant) {
      DSIconButtonVariant.filled => Colors.white,
      _                          => DSColors.text2,
    };
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.size * 0.5;

    Widget btn = MouseRegion(
      cursor: widget.onPressed == null
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: DSDuration.fast,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: DSRadius.mdAll,
            border: widget.variant == DSIconButtonVariant.outlined
                ? Border.all(color: DSColors.border)
                : null,
          ),
          child: Center(
            child: Icon(widget.icon, size: iconSize, color: _iconColor),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      btn = Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}
