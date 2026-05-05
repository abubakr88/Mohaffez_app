import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

class DSMenuEntry {
  const DSMenuEntry({required this.label, required this.onTap, this.icon, this.destructive = false});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool destructive;
}

class DSMenuButton extends StatelessWidget {
  const DSMenuButton({
    super.key,
    required this.entries,
    required this.child,
  });

  final List<DSMenuEntry> entries;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      shape: const RoundedRectangleBorder(
        borderRadius: DSRadius.lgAll,
        side: BorderSide(color: DSColors.border),
      ),
      elevation: 4,
      color: DSColors.surface,
      itemBuilder: (_) => entries.asMap().entries.map((e) {
        final entry = e.value;
        return PopupMenuItem<int>(
          value: e.key,
          onTap: entry.onTap,
          child: Row(
            children: [
              if (entry.icon != null) ...[
                Icon(entry.icon, size: 16, color: entry.destructive ? DSColors.error : DSColors.text2),
                const SizedBox(width: DSSpacing.sm),
              ],
              Text(
                entry.label,
                style: DSText.body(context, color: entry.destructive ? DSColors.error : DSColors.text1),
              ),
            ],
          ),
        );
      }).toList(),
      child: child,
    );
  }
}
