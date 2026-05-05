import 'package:flutter/material.dart';
import '../tokens.dart';
import '../../config/breakpoints.dart';

class DSGrid extends StatelessWidget {
  const DSGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.wideColumns = 4,
    this.spacing = DSSpacing.lg,
  });

  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final int wideColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final bp = Breakpoints.of(context);
    final cols = switch (bp) {
      Breakpoint.mobile  => mobileColumns,
      Breakpoint.tablet  => tabletColumns,
      Breakpoint.desktop => desktopColumns,
      Breakpoint.wide    => wideColumns,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final rowItems = children.sublist(
            i,
            (i + cols).clamp(0, children.length),
          );
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowItems.asMap().entries.map((e) {
                return [
                  SizedBox(width: itemWidth, child: e.value),
                  if (e.key < rowItems.length - 1) SizedBox(width: spacing),
                ];
              }).expand((x) => x).toList(),
            ),
          );
          if (i + cols < children.length) rows.add(SizedBox(height: spacing));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }
}
