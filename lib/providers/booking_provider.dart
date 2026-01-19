import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_result.dart';

final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService();
});

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<BookingResult> createSessionRequest({
    required String mohaffezId,
    required String studentId,
    required String studentName,
    required String mohaffezName,
    required String sessionType,
    required String preferredTimeSlot,
    required DateTime slotStart,
    required DateTime slotEnd,
    String? imamAddressText,
    double? imamAddressLat,
    double? imamAddressLng,
    String? mohaffezPhone,
  }) async {
    try {
      final docRef = await _firestore.collection('sessionRequests').add({
        'mohaffezId': mohaffezId,
        'studentId': studentId,
        'studentName': studentName,
        'mohaffezName': mohaffezName,
        'sessionType': sessionType,
        'preferredTimeSlot': preferredTimeSlot,
        'slotStart': Timestamp.fromDate(slotStart),
        'slotEnd': Timestamp.fromDate(slotEnd),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'imamAddressText': imamAddressText,
        'imamAddressLat': imamAddressLat,
        'imamAddressLng': imamAddressLng,
        'mohaffezPhone': mohaffezPhone,
      });

      return BookingResult.success(docRef.id);
    } catch (e) {
      return BookingResult.failure('فشل في إرسال الطلب: ${e.toString()}');
    }
  }

  Future<BookingResult> cancelSessionRequest(String requestId) async {
    try {
      await _firestore
          .collection('sessionRequests')
          .doc(requestId)
          .update({'status': 'cancelled'});

      return BookingResult.success(requestId);
    } catch (e) {
      return BookingResult.failure('فشل في إلغاء الطلب: ${e.toString()}');
    }
  }

  Stream<List<Map<String, dynamic>>> getStudentRequests(String studentId) {
    return _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList());
  }

  Stream<List<Map<String, dynamic>>> getMohaffezRequests(String mohaffezId) {
    return _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList());
  }
}
