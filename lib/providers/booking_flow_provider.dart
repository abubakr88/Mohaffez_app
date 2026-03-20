// lib/providers/booking_flow_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/slot_context.dart';

enum BookingPath {
  useExistingBundle,
  buyNewBundle,
  newDirectRequest,
}

class BookingFlowState {
  final SlotContext? slotContext;
  final String? selectedPlanId;
  final String? selectedPlanTitle;
  final double? selectedPlanPrice;
  final int? selectedPlanSessions;
  final int? selectedPlanValidityDays;
  final BookingPath? bookingPath;
  final String? directPaymentRequestId;

  const BookingFlowState({
    this.slotContext,
    this.selectedPlanId,
    this.selectedPlanTitle,
    this.selectedPlanPrice,
    this.selectedPlanSessions,
    this.selectedPlanValidityDays,
    this.bookingPath,
    this.directPaymentRequestId,
  });

  BookingFlowState copyWith({
    SlotContext? slotContext,
    String? selectedPlanId,
    String? selectedPlanTitle,
    double? selectedPlanPrice,
    int? selectedPlanSessions,
    int? selectedPlanValidityDays,
    BookingPath? bookingPath,
    String? directPaymentRequestId,
    bool clearSlotContext = false,
    bool clearSelectedPlan = false,
    bool clearBookingPath = false,
  }) {
    return BookingFlowState(
      slotContext: clearSlotContext ? null : (slotContext ?? this.slotContext),
      selectedPlanId: clearSelectedPlan ? null : (selectedPlanId ?? this.selectedPlanId),
      selectedPlanTitle: clearSelectedPlan ? null : (selectedPlanTitle ?? this.selectedPlanTitle),
      selectedPlanPrice: clearSelectedPlan ? null : (selectedPlanPrice ?? this.selectedPlanPrice),
      selectedPlanSessions: clearSelectedPlan ? null : (selectedPlanSessions ?? this.selectedPlanSessions),
      selectedPlanValidityDays: clearSelectedPlan ? null : (selectedPlanValidityDays ?? this.selectedPlanValidityDays),
      bookingPath: clearBookingPath ? null : (bookingPath ?? this.bookingPath),
      directPaymentRequestId: directPaymentRequestId ?? this.directPaymentRequestId,
    );
  }
}

class BookingFlowNotifier extends StateNotifier<BookingFlowState> {
  BookingFlowNotifier() : super(const BookingFlowState());

  void setSlotContext(SlotContext ctx) {
    state = state.copyWith(slotContext: ctx);
  }

  void setBookingPath(BookingPath path) {
    state = state.copyWith(bookingPath: path);
  }

  void selectPlan({
    required String planId,
    required String title,
    required double price,
    required int sessions,
    int? validityDays,
  }) {
    state = state.copyWith(
      selectedPlanId: planId,
      selectedPlanTitle: title,
      selectedPlanPrice: price,
      selectedPlanSessions: sessions,
      selectedPlanValidityDays: validityDays,
    );
  }

  void reset() {
    state = const BookingFlowState();
  }

  void clearIfAbandoned() {
    // Only reset if payment has not been initiated yet.
    if (state.directPaymentRequestId == null) {
      state = const BookingFlowState();
    }
  }
}

final bookingFlowProvider =
    StateNotifierProvider<BookingFlowNotifier, BookingFlowState>(
  (ref) => BookingFlowNotifier(),
);
