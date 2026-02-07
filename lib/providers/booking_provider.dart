import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_result.dart';

final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService();
});

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create session request with payment tracking
  Future<BookingResult> createSessionRequest({
    required String mohaffezId,
    required String studentId,
    required String studentName,
    required String mohaffezName,
    required String sessionType,
    required String preferredTimeSlot,
    required DateTime slotStart,
    required DateTime slotEnd,
    DateTime? slotDate,
    String? imamAddressText,
    double? imamAddressLat,
    double? imamAddressLng,
    String? mohaffezPhone,
    // ✅ NEW PAYMENT FIELDS
    String? subscriptionId,
    bool isPaid = false,
    bool requiresPaymentOnAcceptance = false,
  }) async {
    try {
      // CRITICAL FIX: Ensure slotDate is properly set
      final DateTime actualSlotDate = slotDate ?? 
          DateTime(slotStart.year, slotStart.month, slotStart.day);
      
      // Debug prints
      print('📤 BOOKING SERVICE - Creating Session Request:');
      print('   slotStart: $slotStart');
      print('   slotEnd: $slotEnd');
      print('   slotDate: $actualSlotDate');
      print('   subscriptionId: $subscriptionId');
      print('   isPaid: $isPaid');
      print('   requiresPaymentOnAcceptance: $requiresPaymentOnAcceptance');

      final Map<String, dynamic> requestData = {
        'mohaffezId': mohaffezId,
        'studentId': studentId,
        'studentName': studentName,
        'mohaffezName': mohaffezName,
        'sessionType': sessionType,
        'preferredTimeSlot': preferredTimeSlot,
        'slotStart': Timestamp.fromDate(slotStart),
        'slotEnd': Timestamp.fromDate(slotEnd),
        'slotDate': Timestamp.fromDate(actualSlotDate),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'imamAddressText': imamAddressText,
        'imamAddressLat': imamAddressLat,
        'imamAddressLng': imamAddressLng,
        'mohaffezPhone': mohaffezPhone,
        
        // ✅ PAYMENT TRACKING FIELDS
        'isPaid': isPaid,
        'subscriptionId': subscriptionId,
        'requiresPaymentOnAcceptance': requiresPaymentOnAcceptance,
      };

      print('📦 Request Data: $requestData');

      final docRef = await _firestore.collection('sessionRequests').add(requestData);
      
      print('✅ Session request created with ID: ${docRef.id}');
      
      return BookingResult.success(docRef.id);
    } catch (e) {
      print('❌ Error creating session request: $e');
      return BookingResult.failure(e.toString());
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
      return BookingResult.failure(e.toString());
    }
  }

  Stream<List<Map<String, dynamic>>> getStudentRequests(String studentId) {
    return _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
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
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }
}
