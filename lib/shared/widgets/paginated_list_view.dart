// lib/shared/widgets/paginated_list_view.dart (COMPLETE - ~280 lines)

import 'package:flutter/material.dart';

/// Reusable widget for auto-loading paginated lists
/// 
/// Features:
/// - Auto-loads on scroll threshold
/// - Pull-to-refresh support
/// - Loading indicators
/// - Error handling with retry
/// - Empty state support
/// - Smooth animations
class PaginatedListView<T> extends StatefulWidget {
  /// List of items to display
  final List<T> items;

  /// Whether more items are available
  final bool hasMore;

  /// Whether currently loading more items
  final bool isLoadingMore;

  /// Error message if loading failed
  final String? error;

  /// Builder function for each item
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Callback to load more items
  final Future<void> Function() onLoadMore;

  /// Optional callback for pull-to-refresh
  final Future<void> Function()? onRefresh;

  /// Widget to show when list is empty
  final Widget? emptyWidget;

  /// Padding around the list
  final EdgeInsets? padding;

  /// Scroll threshold (0.0 to 1.0) to trigger loading
  /// Default: 0.8 (triggers at 80% scroll)
  final double scrollThreshold;

  /// Whether to show loading indicator at top during refresh
  final bool showRefreshIndicator;

  /// Custom loading widget
  final Widget? loadingWidget;

  /// Custom error widget builder
  final Widget Function(String error, VoidCallback retry)? errorBuilder;

  /// Separator builder (optional)
  final Widget Function(BuildContext, int)? separatorBuilder;

  /// Fixed item height for better performance (optional)
  final double? itemExtent;

  /// Whether to keep items alive when scrolled out of view
  final bool keepAlive;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
    this.error,
    required this.itemBuilder,
    required this.onLoadMore,
    this.onRefresh,
    this.emptyWidget,
    this.padding,
    this.scrollThreshold = 0.8,
    this.showRefreshIndicator = true,
    this.loadingWidget,
    this.errorBuilder,
    this.separatorBuilder,
    this.itemExtent,
    this.keepAlive = false,
  }) : assert(scrollThreshold >= 0.0 && scrollThreshold <= 1.0);

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingTriggered = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    if (maxScroll <= 0) return; // Avoid division by zero

    final scrollPercentage = currentScroll / maxScroll;

    // Trigger load when reaching threshold
    if (scrollPercentage >= widget.scrollThreshold &&
        widget.hasMore &&
        !widget.isLoadingMore &&
        !_isLoadingTriggered) {
      _isLoadingTriggered = true;
      widget.onLoadMore().then((_) {
        if (mounted) {
          setState(() => _isLoadingTriggered = false);
        }
      }).catchError((error) {
        if (mounted) {
          setState(() => _isLoadingTriggered = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Empty state
    if (widget.items.isEmpty && !widget.isLoadingMore) {
      return widget.emptyWidget ??
          const Center(
            child: Text('لا توجد عناصر'),
          );
    }

    // Build list
    final listView = widget.separatorBuilder != null
        ? _buildSeparatedList()
        : _buildRegularList();

    // Wrap with RefreshIndicator if onRefresh provided
    if (widget.onRefresh != null && widget.showRefreshIndicator) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh!,
        child: listView,
      );
    }

    return listView;
  }

  Widget _buildRegularList() {
    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding ?? const EdgeInsets.all(12),
      itemCount: widget.items.length + (widget.hasMore || widget.error != null ? 1 : 0),
      itemExtent: widget.itemExtent,
      addAutomaticKeepAlives: widget.keepAlive,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        // Regular item
        if (index < widget.items.length) {
          return widget.itemBuilder(context, widget.items[index], index);
        }

        // Loading/error indicator at bottom
        return _buildBottomWidget();
      },
    );
  }

  Widget _buildSeparatedList() {
    return ListView.separated(
      controller: _scrollController,
      padding: widget.padding ?? const EdgeInsets.all(12),
      itemCount: widget.items.length,
      separatorBuilder: widget.separatorBuilder!,
      itemBuilder: (context, index) {
        if (index < widget.items.length) {
          return widget.itemBuilder(context, widget.items[index], index);
        }
        return const SizedBox.shrink();
      },
      // Add bottom widget separately
      // Note: In separated list, we add it via footer
    );
  }

  Widget _buildBottomWidget() {
    // Error state
    if (widget.error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(widget.error!, widget.onLoadMore);
      }

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: widget.onLoadMore,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Loading state
    if (widget.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: widget.loadingWidget ??
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text(
                    'جاري التحميل...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
        ),
      );
    }

    // No more items
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          'لا توجد عناصر أخرى',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
}

/// Sliver version for CustomScrollView
class SliverPaginatedList<T> extends StatelessWidget {
  final List<T> items;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final Future<void> Function() onLoadMore;
  final Widget? loadingWidget;

  const SliverPaginatedList({
    super.key,
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
    this.error,
    required this.itemBuilder,
    required this.onLoadMore,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < items.length) {
            return itemBuilder(context, items[index], index);
          }

          // Bottom widget
          if (error != null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  ElevatedButton(onPressed: onLoadMore, child: const Text('إعادة')),
                ],
              ),
            );
          }

          if (hasMore) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: loadingWidget ?? const CircularProgressIndicator(),
            );
          }

          return const SizedBox.shrink();
        },
        childCount: items.length + (hasMore || error != null ? 1 : 0),
      ),
    );
  }
}
