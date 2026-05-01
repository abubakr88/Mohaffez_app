// lib/models/pagination_state.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pagination_state.freezed.dart';

@freezed
class PaginationState<T> with _$PaginationState<T> {
  const factory PaginationState({
    @Default([]) List<T> items,
    DocumentSnapshot? lastDocument,
    @Default(false) bool hasMore,
    @Default(false) bool isLoadingMore,
    String? error,
  }) = _PaginationState;
}
