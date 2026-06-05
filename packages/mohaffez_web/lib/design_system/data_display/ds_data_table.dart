import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

class DSColumnDef<T> {
  const DSColumnDef({
    required this.key,
    required this.label,
    required this.cellBuilder,
    this.width,
    this.sortable = false,
    this.sortValue,
  });
  final String key;
  final String label;
  final Widget Function(BuildContext context, T row) cellBuilder;
  final double? width;
  final bool sortable;

  /// Returns the comparable value used when sorting by this column.
  /// Required for a column to actually sort (the header arrow is cosmetic
  /// without it).
  final Comparable<dynamic> Function(T row)? sortValue;
}

class DSDataTable<T> extends StatefulWidget {
  const DSDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.loading = false,
    this.emptyMessage = 'لا توجد بيانات',
    this.initialSortKey,
    this.initialSortAsc = true,
  });

  final List<DSColumnDef<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowTap;
  final bool loading;
  final String emptyMessage;
  final String? initialSortKey;
  final bool initialSortAsc;

  @override
  State<DSDataTable<T>> createState() => _DSDataTableState<T>();
}

class _DSDataTableState<T> extends State<DSDataTable<T>> {
  String? _sortKey;
  bool _sortAsc = true;
  int? _hoveredRow;

  @override
  void initState() {
    super.initState();
    _sortKey = widget.initialSortKey;
    _sortAsc = widget.initialSortAsc;
  }

  List<T> get _sortedRows {
    if (_sortKey == null) return widget.rows;
    DSColumnDef<T>? col;
    for (final c in widget.columns) {
      if (c.key == _sortKey) {
        col = c;
        break;
      }
    }
    final getter = col?.sortValue;
    if (getter == null) return widget.rows;
    final rows = [...widget.rows];
    rows.sort((a, b) {
      final cmp = getter(a).compareTo(getter(b));
      return _sortAsc ? cmp : -cmp;
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DSColors.surface,
        borderRadius: DSRadius.lgAll,
        border: const Border.fromBorderSide(BorderSide(color: DSColors.border)),
        boxShadow: DSElevation.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(height: 1, color: DSColors.border),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.all(DSSpacing.xxxl),
              child: CircularProgressIndicator(color: DSColors.primary),
            )
          else if (widget.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(DSSpacing.xxxl),
              child: Text(widget.emptyMessage, style: DSText.body(context, color: DSColors.text3)),
            )
          else
            ..._sortedRows.asMap().entries.map((e) => _buildRow(context, e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: DSColors.surfaceMuted,
      child: Row(
        children: widget.columns.map((col) {
          return _cellWrapper(
            col.width,
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DSSpacing.lg,
                vertical: DSSpacing.md,
              ),
              child: Row(
                children: [
                  Text(col.label, style: DSText.caption(context, color: DSColors.text2)),
                  if (col.sortable) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _sortKey == col.key
                          ? (_sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                          : Icons.unfold_more_rounded,
                      size: 14,
                      color: DSColors.text3,
                    ),
                  ],
                ],
              ),
            ),
            onTap: col.sortable
                ? () => setState(() {
                      if (_sortKey == col.key) {
                        _sortAsc = !_sortAsc;
                      } else {
                        _sortKey = col.key;
                        _sortAsc = true;
                      }
                    })
                : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index, T row) {
    final hovered = _hoveredRow == index;
    return MouseRegion(
      cursor: widget.onRowTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hoveredRow = index),
      onExit:  (_) => setState(() => _hoveredRow = null),
      child: GestureDetector(
        onTap: widget.onRowTap != null ? () => widget.onRowTap!(row) : null,
        child: AnimatedContainer(
          duration: DSDuration.fast,
          color: hovered ? DSColors.surfaceMuted : DSColors.surface,
          child: Column(
            children: [
              if (index > 0) const Divider(height: 1, color: DSColors.border),
              Row(
                children: widget.columns.map((col) {
                  return _cellWrapper(
                    col.width,
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DSSpacing.lg,
                        vertical: DSSpacing.md,
                      ),
                      child: col.cellBuilder(context, row),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cellWrapper(double? width, Widget child, {VoidCallback? onTap}) {
    final inner = onTap != null ? GestureDetector(onTap: onTap, child: child) : child;
    return width != null ? SizedBox(width: width, child: inner) : Expanded(child: inner);
  }
}
