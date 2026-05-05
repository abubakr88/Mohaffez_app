// lib/models/booking_result.dart (FIXED)

class BookingResult {
  final bool success;
  final String? sessionId;
  final String? errorMessage;
  final bool isDuplicate;

  // Remove const from constructor
  BookingResult({
    required this.success,
    this.sessionId,
    this.errorMessage,
    this.isDuplicate = false,
  });

  factory BookingResult.success(String sessionId, {bool isDuplicate = false}) {
    return BookingResult(
      success: true,
      sessionId: sessionId,
      errorMessage: null,
      isDuplicate: isDuplicate,
    );
  }

  factory BookingResult.failure(String errorMessage) {
    return BookingResult(
      success: false,
      sessionId: null,
      errorMessage: errorMessage,
      isDuplicate: false,
    );
  }

  // Add helper getters
  bool get isSuccess => success;
  bool get isFailure => !success;
}
