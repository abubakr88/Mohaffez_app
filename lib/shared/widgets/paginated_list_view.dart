import 'package:flutter/material.dart';

class PaginatedListView<T> extends StatefulWidget {
  final List<T> items;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  
  // ✅ Performance optimizations
  final double? itemExtent;     // Fixed height for each item
  final double? cacheExtent;    // Preload distance

  const PaginatedListView({
    super.key,
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRefresh,
    this.error,
    this.itemExtent,    // ✅ ADDED
    this.cacheExtent,   // ✅ ADDED
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (widget.hasMore && !widget.isLoadingMore) {
        widget.onLoadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && !widget.isLoadingMore) {
      return const Center(
        child: Text('لا توجد عناصر'),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemExtent: widget.itemExtent,     // ✅ Performance boost
        cacheExtent: widget.cacheExtent,   // ✅ Performance boost
        itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= widget.items.length) {
            // Loading indicator
            if (widget.error != null) {
              return Center(
                child: Padding(
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
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          return widget.itemBuilder(context, widget.items[index], index);
        },
      ),
    );
  }
}
