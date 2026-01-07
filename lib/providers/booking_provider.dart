import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Booking loading state
final bookingLoadingProvider = StateProvider<bool>((ref) => false);

// Session booking notifier
class SessionBookingNotifier extends StateNotifier<AsyncValue<void>> {
  SessionBookingNotifier() : super(const AsyncValue.data(null));

  Future<bool> bookSession({
    required String mohaffezId,
    required String studentId,
    required DateTime slotStart,
    required DateTime slotEnd,
    required String sessionType,
    required String timeSlot,
    required Map<String, dynamic> additionalData,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final result = await FirebaseFirestore.instance.runTransaction<bool>(
        (transaction) async {
          // Check for conflicts
          final conflictQuery = await FirebaseFirestore.instance
              .collection('sessionRequests')
              .where('mohaffezId', isEqualTo: mohaffezId)
              .where('slotStart', isEqualTo: Timestamp.fromDate(slotStart))
              .where('status', whereIn: ['pending', 'accepted'])
              .get();

          if (conflictQuery.docs.isNotEmpty) {
            return false;
          }

          // Create booking
          final newRequestRef = FirebaseFirestore.instance
              .collection('sessionRequests')
              .doc();

          transaction.set(newRequestRef, {
            'studentId': studentId,
            'mohaffezId': mohaffezId,
            'sessionType': sessionType,
            'preferredTimeSlot': timeSlot,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'slotStart': Timestamp.fromDate(slotStart),
            'slotEnd': Timestamp.fromDate(slotEnd),
            ...additionalData,
          });

          return true;
        },
      );

      state = const AsyncValue.data(null);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final sessionBookingProvider =
    StateNotifierProvider<SessionBookingNotifier, AsyncValue<void>>((ref) {
  return SessionBookingNotifier();
});
