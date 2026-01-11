// lib/models/booking_result.dart (FIXED)

class BookingResult {
  final bool success;
  final String? sessionId;
  final String? errorMessage;

  // Remove const from constructor
  BookingResult({
    required this.success,
    this.sessionId,
    this.errorMessage,
  });

  factory BookingResult.success(String sessionId) {
    return BookingResult(
      success: true,
      sessionId: sessionId,
      errorMessage: null,
    );
  }

  factory BookingResult.failure(String errorMessage) {
    return BookingResult(
      success: false,
      sessionId: null,
      errorMessage: errorMessage,
    );
  }

  // Add helper getters
  bool get isSuccess => success;
  bool get isFailure => !success;
}
