// lib/models/request_status.dart

/// Single source of truth for sessionRequests.status values.
/// Must match exactly what the Cloud Functions write (all lowercase).
abstract class RequestStatus {
  static const String pending = 'pending';
  static const String awaitingPayment = 'awaitingpayment';          // lowercase!
  static const String awaitingDirectPayment = 'awaitingdirectpaymentconfirmation';
  static const String accepted = 'accepted';
  static const String confirmed = 'confirmed';  // non-canonical, for legacy poisoned docs
  static const String rejected = 'rejected';
  static const String cancelled = 'cancelled';

  /// All statuses visible to the teacher in the pending inbox
  static const List<String> teacherInbox = [
    pending,
    awaitingPayment,
    awaitingDirectPayment,
  ];

  /// All statuses NOT visible to the teacher in the pending inbox (i.e., completed/closed states)
  /// This is used with whereNotIn query for defensive handling of legacy poisoned docs
  static const List<String> teacherInboxExcluded = [
    accepted,
    confirmed,
    rejected,
    cancelled,
    'expired',
  ];

  /// All statuses visible to the student in their requests list
  static const List<String> studentVisible = [
    pending,
    awaitingPayment,
    awaitingDirectPayment,
    accepted,
    rejected,
    cancelled,
  ];
}
