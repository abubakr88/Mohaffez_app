import 'package:cloud_firestore/cloud_firestore.dart';

/// Generic result model for paginated Firestore queries
class PaginationResult<T> {
  final List<T> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const PaginationResult({
    required this.items,
    this.lastDocument,
    required this.hasMore,
  });

  PaginationResult<T> copyWith({
    List<T>? items,
    DocumentSnapshot? lastDocument,
    bool? hasMore,
  }) {
    return PaginationResult<T>(
      items: items ?? this.items,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}
