import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

class DSDropdownItem {
  const DSDropdownItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.dividerAfter = false,
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool dividerAfter;
}

class DSDropdownMenu extends StatefulWidget {
  const DSDropdownMenu({
    super.key,
    required this.items,
    required this.child,
    this.alignment = Alignment.bottomLeft,
  });

  final List<DSDropdownItem> items;
  final Widget child;
  final Alignment alignment;

  @override
  State<DSDropdownMenu> createState() => _DSDropdownMenuState();
}

class _DSDropdownMenuState extends State<DSDropdownMenu>
    with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  OverlayEntry? _overlay;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: DSDuration.fast);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _close();
    super.dispose();
  }

  void _open() {
    _overlay = OverlayEntry(builder: (_) => _buildOverlay());
    Overlay.of(context).insert(_overlay!);
    _ctrl.forward();
  }

  void _close() {
    _ctrl.reverse().then((_) {
      _overlay?.remove();
      _overlay = null;
    });
  }

  Widget _buildOverlay() {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          child: FadeTransition(
            opacity: _anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(_anim),
              alignment: Alignment.topLeft,
              child: _buildMenu(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
        decoration: BoxDecoration(
          color: DSColors.surface,
          borderRadius: DSRadius.lgAll,
          border: const Border.fromBorderSide(BorderSide(color: DSColors.border)),
          boxShadow: DSElevation.md,
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.items.expand((item) {
              return [
                _buildItem(item),
                if (item.dividerAfter)
                  const Divider(height: 1, color: DSColors.border),
              ];
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(DSDropdownItem item) {
    return Builder(
      builder: (context) => InkWell(
        onTap: () {
          _close();
          item.onTap();
        },
        borderRadius: DSRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DSSpacing.lg,
            vertical: DSSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 16, color: DSColors.text2),
                const SizedBox(width: DSSpacing.sm),
              ],
              Flexible(child: Text(item.label, style: DSText.body(context))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _overlay == null ? _open : _close,
        child: widget.child,
      ),
    );
  }
}
