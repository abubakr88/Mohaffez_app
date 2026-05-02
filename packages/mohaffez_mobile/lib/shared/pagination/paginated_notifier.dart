import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pagination_result.dart';

/// Generic state notifier for paginated lists
abstract class PaginatedNotifier<T> extends StateNotifier<PaginationState<T>> {
  PaginatedNotifier() : super(const PaginationState());

  bool _isLoadingMore = false;

  /// Override this to define the pagination query
  Future<PaginationResult<T>> fetchPage(DocumentSnapshot? lastDocument);

  /// Initialize state with first page data (from stream)
  void initializeWithFirstPage(List<T> firstPage) {
    if (state.items.isEmpty && firstPage.isNotEmpty) {
      state = PaginationState(
        items: firstPage,
        lastDocument: null,
        hasMore: firstPage.length >= 20,
        isLoadingMore: false,
      );
    }
  }

  /// Load next page
  Future<void> loadMore() async {
    if (!state.hasMore || _isLoadingMore) return;

    // Initialize lastDocument if needed
    if (state.lastDocument == null && state.items.isNotEmpty) {
      final result = await fetchPage(null);
      state = state.copyWith(
        lastDocument: result.lastDocument,
        hasMore: result.hasMore,
      );
      if (!result.hasMore) return;
    }

    if (state.lastDocument == null) return;

    _isLoadingMore = true;
    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final result = await fetchPage(state.lastDocument);

      // Prevent duplicates
      final existingIds = state.items.map((e) => _getId(e)).toSet();
      final newItems = result.items
          .where((item) => !existingIds.contains(_getId(item)))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...newItems],
        lastDocument: result.lastDocument,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      _isLoadingMore = false;
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Check scroll position and trigger load more
  Future<void> checkScrollPosition(double scrollPercentage) async {
    if (scrollPercentage > 0.8 && state.hasMore && !_isLoadingMore) {
      await loadMore();
    }
  }

  /// Refresh pagination (pull-to-refresh)
  Future<void> refresh() async {
    state = const PaginationState(isLoadingMore: false);
  }

  /// Override to extract ID from item (for duplicate prevention)
  String _getId(T item) {
    // Try to get 'id' field using reflection fallback
    try {
      final dynamic dynamicItem = item;
      return dynamicItem.id as String? ?? '';
    } catch (e) {
      return item.hashCode.toString();
    }
  }
}
