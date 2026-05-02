import 'package:cloud_firestore/cloud_firestore.dart';
import 'pagination_result.dart';

/// Reusable mixin for Firestore pagination logic
mixin FirestorePaginationMixin {
  static const int defaultPageSize = 20;

  /// Generic paginated query executor
  Future<PaginationResult<T>> executePaginatedQuery<T>({
    required Query query,
    required T Function(DocumentSnapshot doc) fromFirestore,
    DocumentSnapshot? lastDocument,
    int pageSize = defaultPageSize,
  }) async {
    Query paginatedQuery = query;

    // Apply cursor if provided
    if (lastDocument != null) {
      paginatedQuery = paginatedQuery.startAfterDocument(lastDocument);
    }

    final snapshot = await paginatedQuery.limit(pageSize).get();

    return PaginationResult<T>(
      items: snapshot.docs.map((doc) => fromFirestore(doc)).toList(),
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Stream-based pagination for real-time first page
  Stream<List<T>> watchFirstPage<T>({
    required Query query,
    required T Function(DocumentSnapshot doc) fromFirestore,
    int pageSize = defaultPageSize,
  }) {
    return query.limit(pageSize).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => fromFirestore(doc)).toList(),
        );
  }
}
