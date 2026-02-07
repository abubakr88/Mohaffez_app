// lib/providers/session_provider_paginated.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../repositories/session_repository.dart';

// ============================================================================
// FILTER ENUM AND PROVIDER
// ============================================================================

enum UpcomingFilter {
  all, // الكل
  today, // اليوم
  thisWeek, // هذا الأسبوع
  thisMonth, // هذا الشهر
}

final upcomingSessionsFilterProvider = StateProvider((ref) {
  return UpcomingFilter.all;
});

// ============================================================================
// COUNTERS - Real-time StreamProviders for MohaffezHome
// ============================================================================

final completedSessionsCountProvider = StreamProvider.family<int, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  },
);

// ✅ Accepted sessions count provider (all accepted sessions)
final acceptedSessionsCountProvider = StreamProvider.family<int, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  },
);

// ============================================================================
// PENDING REQUESTS - First Page Real-time
// ============================================================================

final pendingRequestsFirstPageProvider = StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        // CRITICAL FIX: Properly parse Timestamp fields
        DateTime? slotDate;
        DateTime? slotStart;
        DateTime? slotEnd;
        DateTime? createdAt;

        try {
          if (data['slotDate'] != null) {
            if (data['slotDate'] is Timestamp) {
              slotDate = (data['slotDate'] as Timestamp).toDate();
            }
          }

          if (data['slotStart'] != null) {
            if (data['slotStart'] is Timestamp) {
              slotStart = (data['slotStart'] as Timestamp).toDate();
            }
          }

          if (data['slotEnd'] != null) {
            if (data['slotEnd'] is Timestamp) {
              slotEnd = (data['slotEnd'] as Timestamp).toDate();
            }
          }

          if (data['createdAt'] != null) {
            if (data['createdAt'] is Timestamp) {
              createdAt = (data['createdAt'] as Timestamp).toDate();
            }
          }
        } catch (e) {
          print('❌ Error parsing timestamps for request ${doc.id}: $e');
        }

        return {
          'id': doc.id,
          'studentName': data['studentName'] as String? ?? '',
          'mohaffezName': data['mohaffezName'] as String? ?? '',
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
          'imamAddressText': data['imamAddressText'] as String?,
          'imamAddressLat': data['imamAddressLat'] as double?,
          'imamAddressLng': data['imamAddressLng'] as double?,
          'slotDate': slotDate,
          'slotStart': slotStart,
          'slotEnd': slotEnd,
          'createdAt': createdAt,
          'status': data['status'] as String? ?? 'pending',
          'mohaffezId': data['mohaffezId'] as String?,
          'studentId': data['studentId'] as String?,
          // ✅ NEW: Payment tracking fields
          'isPaid': data['isPaid'] as bool? ?? false,
          'subscriptionId': data['subscriptionId'] as String?,
          'requiresPaymentOnAcceptance': data['requiresPaymentOnAcceptance'] as bool? ?? false,
        };
      }).toList();
    });
  },
);

// ============================================================================
// UPCOMING SESSIONS - ALL upcoming sessions (ACCEPTED status only)
// ============================================================================

final upcomingSessionsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'accepted') // ✅ ONLY ACCEPTED
        .where('sessionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .orderBy('sessionDate', descending: false)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'studentName': data['studentName'] as String? ?? '',
          'mohaffezName': data['mohaffezName'] as String? ?? '',
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
          'location': data['location'] as String? ?? data['imamAddressText'] as String? ?? '',
          'hifzAssignment': data['hifzAssignment'] as String?,
          'murajaAssignment': data['murajaAssignment'] as String?,
          'sessionRating': data['sessionRating'] as int?,
          'sessionNotes': data['sessionNotes'] as String?,
          'status': data['status'] as String? ?? 'accepted',
          'studentId': data['studentId'] as String?,
          // ✅ NEW: Payment tracking
          'isPaid': data['isPaid'] as bool? ?? false,
          'subscriptionId': data['subscriptionId'] as String?,
        };
      }).toList();
    });
  },
);

// ✅ NEW: Filtered sessions based on selected filter
final filteredUpcomingSessionsProvider = Provider.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    final allSessions = ref.watch(upcomingSessionsProvider(mohaffezId));
    final filter = ref.watch(upcomingSessionsFilterProvider);

    return allSessions.when(
      data: (sessions) {
        final now = DateTime.now();

        switch (filter) {
          case UpcomingFilter.all:
            return sessions;

          case UpcomingFilter.today:
            final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
            return sessions.where((session) {
              final date = (session['sessionDate'] as DateTime?);
              return date != null && date.isBefore(endOfDay);
            }).toList();

          case UpcomingFilter.thisWeek:
            final endOfWeek = now.add(const Duration(days: 7));
            return sessions.where((session) {
              final date = (session['sessionDate'] as DateTime?);
              return date != null && date.isBefore(endOfWeek);
            }).toList();

          case UpcomingFilter.thisMonth:
            final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
            return sessions.where((session) {
              final date = (session['sessionDate'] as DateTime?);
              return date != null && date.isBefore(endOfMonth);
            }).toList();
        }
      },
      loading: () => [],
      error: (_, __) => [],
    );
  },
);

// ============================================================================
// COMPLETED SESSIONS - Stream Provider (Real-time)
// ============================================================================

final completedSessionsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'studentName': data['studentName'] as String? ?? '',
          'studentId': data['studentId'] as String? ?? '',
          'mohaffezName': data['mohaffezName'] as String? ?? '',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
          'completedAt': (data['completedAt'] as Timestamp?)?.toDate(),
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
          'location': data['location'] as String? ?? data['imamAddressText'] as String? ?? '',

          // ✅ التكليف الحالي
          'hifzAssignment': data['hifzAssignment'] as String?,
          'murajaAssignment': data['murajaAssignment'] as String?,

          // ✅ تقييم التكليف السابق
          'previousHifzCompleted': data['previousHifzCompleted'] as bool?,
          'previousHifzRating': data['previousHifzRating'] as int? ?? 0,
          'previousMurajaCompleted': data['previousMurajaCompleted'] as bool?,
          'previousMurajaRating': data['previousMurajaRating'] as int? ?? 0,
          'performanceNotes': data['performanceNotes'] as String?,

          // ✅ التقييم العام
          'sessionRating': data['sessionRating'] as int? ?? 0,
          'sessionNotes': data['sessionNotes'] as String?,

          // ✅ NEW: Late completion flag
          'isLateCompletion': data['isLateCompletion'] as bool? ?? false,
        };
      }).toList();
    });
  },
);

// ============================================================================
// COMPLETED SESSIONS - Paginated (Legacy - kept for compatibility)
// ============================================================================

class CompletedSessionsState {
  final List<Map<String, dynamic>> sessions;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;
  final Set<String> loadedIds;

  CompletedSessionsState({
    this.sessions = const [],
    this.lastDocument,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
    Set<String>? loadedIds,
  }) : loadedIds = loadedIds ?? {};

  CompletedSessionsState copyWith({
    List<Map<String, dynamic>>? sessions,
    DocumentSnapshot? lastDocument,
    bool? hasMore,
    bool? isLoadingMore,
    String? error,
    Set<String>? loadedIds,
  }) {
    return CompletedSessionsState(
      sessions: sessions ?? this.sessions,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      loadedIds: loadedIds ?? this.loadedIds,
    );
  }
}

class CompletedSessionsNotifier extends StateNotifier<CompletedSessionsState> {
  final String mohaffezId;
  static const int pageSize = 20;

  CompletedSessionsNotifier(this.mohaffezId) : super(CompletedSessionsState());

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      Query query = FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('mohaffezId', isEqualTo: mohaffezId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(pageSize);

      if (state.lastDocument != null) {
        query = query.startAfterDocument(state.lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        state = state.copyWith(hasMore: false, isLoadingMore: false);
        return;
      }

      final newSessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'studentName': data['studentName'] as String? ?? '',
          'studentId': data['studentId'] as String? ?? '',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
          'completedAt': (data['completedAt'] as Timestamp?)?.toDate(),
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
          'location': data['location'] as String? ?? data['imamAddressText'] as String? ?? '',
          'hifzAssignment': data['hifzAssignment'] as String?,
          'murajaAssignment': data['murajaAssignment'] as String?,
          'previousHifzCompleted': data['previousHifzCompleted'] as bool?,
          'previousHifzRating': data['previousHifzRating'] as int? ?? 0,
          'previousMurajaCompleted': data['previousMurajaCompleted'] as bool?,
          'previousMurajaRating': data['previousMurajaRating'] as int? ?? 0,
          'performanceNotes': data['performanceNotes'] as String?,
          'sessionRating': data['sessionRating'] as int? ?? 0,
          'sessionNotes': data['sessionNotes'] as String?,
          'isLateCompletion': data['isLateCompletion'] as bool? ?? false,
        };
      }).toList();

      // Filter duplicates
      final uniqueNewSessions = newSessions.where((s) {
        final id = s['id'] as String?;
        return id != null && !state.loadedIds.contains(id);
      }).toList();

      final newIds = uniqueNewSessions.map((s) => s['id'] as String).toSet();

      state = state.copyWith(
        sessions: [...state.sessions, ...uniqueNewSessions],
        lastDocument: snapshot.docs.last,
        hasMore: snapshot.docs.length == pageSize,
        isLoadingMore: false,
        loadedIds: {...state.loadedIds, ...newIds},
      );
    } catch (e) {
      state = state.copyWith(
        error: 'حدث خطأ في تحميل الجلسات. حاول مرة أخرى.',
        isLoadingMore: false,
      );
    }
  }

  void refresh() {
    state = CompletedSessionsState();
    loadMore();
  }
}

final completedSessionsPaginatedProvider = StateNotifierProvider.family<
    CompletedSessionsNotifier, CompletedSessionsState, String>(
  (ref, mohaffezId) {
    return CompletedSessionsNotifier(mohaffezId);
  },
);

// ============================================================================
// STUDENT SESSIONS - Paginated
// ============================================================================

class StudentSessionsState {
  final List<Map<String, dynamic>> sessions;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;
  final Set<String> loadedIds;

  StudentSessionsState({
    this.sessions = const [],
    this.lastDocument,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
    Set<String>? loadedIds,
  }) : loadedIds = loadedIds ?? {};

  StudentSessionsState copyWith({
    List<Map<String, dynamic>>? sessions,
    DocumentSnapshot? lastDocument,
    bool? hasMore,
    bool? isLoadingMore,
    String? error,
    Set<String>? loadedIds,
  }) {
    return StudentSessionsState(
      sessions: sessions ?? this.sessions,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      loadedIds: loadedIds ?? this.loadedIds,
    );
  }
}

class StudentSessionsNotifier extends StateNotifier<StudentSessionsState> {
  final String studentId;
  static const int pageSize = 20;

  StudentSessionsNotifier(this.studentId) : super(StudentSessionsState());

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      Query query = FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('studentId', isEqualTo: studentId)
          .orderBy('sessionDate', descending: true)
          .limit(pageSize);

      if (state.lastDocument != null) {
        query = query.startAfterDocument(state.lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        state = state.copyWith(hasMore: false, isLoadingMore: false);
        return;
      }

      final newSessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'mohaffezName': data['mohaffezName'] as String? ?? '',
          'location': data['location'] as String? ?? data['imamAddressText'] as String? ?? '',
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
          'hifzAssignment': data['hifzAssignment'] as String?,
          'murajaAssignment': data['murajaAssignment'] as String?,
          'previousHifzCompleted': data['previousHifzCompleted'] as bool?,
          'previousHifzRating': data['previousHifzRating'] as int? ?? 0,
          'previousMurajaCompleted': data['previousMurajaCompleted'] as bool?,
          'previousMurajaRating': data['previousMurajaRating'] as int? ?? 0,
          'performanceNotes': data['performanceNotes'] as String?,
          'sessionRating': data['sessionRating'] as int? ?? 0,
          'sessionNotes': data['sessionNotes'] as String?,
          'status': data['status'] as String? ?? 'pending',
          'isLateCompletion': data['isLateCompletion'] as bool? ?? false,
        };
      }).toList();

      // Filter duplicates
      final uniqueNewSessions = newSessions.where((s) {
        final id = s['id'] as String?;
        return id != null && !state.loadedIds.contains(id);
      }).toList();

      final newIds = uniqueNewSessions.map((s) => s['id'] as String).toSet();

      state = state.copyWith(
        sessions: [...state.sessions, ...uniqueNewSessions],
        lastDocument: snapshot.docs.last,
        hasMore: snapshot.docs.length == pageSize,
        isLoadingMore: false,
        loadedIds: {...state.loadedIds, ...newIds},
      );
    } catch (e) {
      state = state.copyWith(
        error: 'حدث خطأ في تحميل الجلسات. حاول مرة أخرى.',
        isLoadingMore: false,
      );
    }
  }

  void refresh() {
    state = StudentSessionsState();
    loadMore();
  }
}

final paginatedStudentSessionsProvider = StateNotifierProvider.family<
    StudentSessionsNotifier, StudentSessionsState, String>(
  (ref, studentId) {
    return StudentSessionsNotifier(studentId);
  },
);

final studentSessionsFirstPageProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, studentId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('sessionDate', descending: true)
        .limit(20)
        .get();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paginatedStudentSessionsProvider(studentId).notifier).refresh();
    });

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'mohaffezName': data['mohaffezName'] as String? ?? '',
        'location': data['location'] as String? ?? data['imamAddressText'] as String? ?? '',
        'sessionType': data['sessionType'] as String? ?? '',
        'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
        'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
        'hifzAssignment': data['hifzAssignment'] as String?,
        'murajaAssignment': data['murajaAssignment'] as String?,
        'previousHifzCompleted': data['previousHifzCompleted'] as bool?,
        'previousHifzRating': data['previousHifzRating'] as int? ?? 0,
        'previousMurajaCompleted': data['previousMurajaCompleted'] as bool?,
        'previousMurajaRating': data['previousMurajaRating'] as int? ?? 0,
        'performanceNotes': data['performanceNotes'] as String?,
        'sessionRating': data['sessionRating'] as int? ?? 0,
        'sessionNotes': data['sessionNotes'] as String?,
        'status': data['status'] as String? ?? 'pending',
        'isLateCompletion': data['isLateCompletion'] as bool? ?? false,
      };
    }).toList();
  },
);

final studentRequestsFirstPageProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, studentId) {
    return FirebaseFirestore.instance
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'mohaffezName': data['mohaffezName'] as String? ?? '',
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
          'status': data['status'] as String? ?? 'pending',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
          'imamAddressText': data['imamAddressText'] as String?,
          'rejectionReason': data['rejectionReason'] as String?,
          // ✅ NEW: Payment tracking
          'isPaid': data['isPaid'] as bool? ?? false,
          'requiresPaymentOnAcceptance': data['requiresPaymentOnAcceptance'] as bool? ?? false,
        };
      }).toList();
    });
  },
);

// ============================================================================
// SESSION ACTIONS - UPDATED WITH PAYMENT WORKFLOW
// ============================================================================

final sessionActionsProvider =
    StateNotifierProvider<SessionActionsNotifier, AsyncValue<void>>(
  (ref) => SessionActionsNotifier(),
);

class SessionActionsNotifier extends StateNotifier<AsyncValue<void>> {
  SessionActionsNotifier() : super(const AsyncValue.data(null));

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ NEW: Accept request and handle payment/subscription logic
  Future<void> acceptRequestAndCreateSession(String requestId) async {
    if (requestId.trim().isEmpty) {
      throw ArgumentError('Request ID cannot be empty');
    }

    print('🎯 Accepting request: $requestId');

    state = const AsyncValue.loading();

    try {
      // Get request details
      final requestDoc = await _firestore
          .collection('sessionRequests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      final requiresPayment = requestData['requiresPaymentOnAcceptance'] as bool? ?? false;
      final subscriptionId = requestData['subscriptionId'] as String?;
      final studentId = requestData['studentId'] as String;
      final mohaffezName = requestData['mohaffezName'] as String;

      print('📊 Request details:');
      print('   - requiresPayment: $requiresPayment');
      print('   - subscriptionId: $subscriptionId');

      // ✅ Handle payment based on type
      if (subscriptionId != null) {
        // PATH A: Has subscription - Consume credit immediately
        print('💳 Path A: Consuming subscription credit');
        await _consumeSubscriptionCredit(subscriptionId);

        // Create session immediately
        await _createSessionFromRequest(requestId, requestData);

        // Update request status
        await _firestore.collection('sessionRequests').doc(requestId).update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Session created with subscription payment');
      } else if (requiresPayment) {
        // PATH B: No subscription - Request payment from student
        print('💰 Path B: Requesting payment from student');

        // Update request to awaiting_payment status
        await _firestore.collection('sessionRequests').doc(requestId).update({
          'status': 'awaiting_payment',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        // Send payment notification to student
        await _sendPaymentRequestNotification(
          studentId: studentId,
          requestId: requestId,
          mohaffezName: mohaffezName,
          sessionDetails: requestData,
        );

        print('📧 Payment notification sent to student');

        // NOTE: Session will be created after student completes payment
      } else {
        // PATH C: Free session (trial/promotional)
        print('🎁 Path C: Free session');

        await _createSessionFromRequest(requestId, requestData);

        await _firestore.collection('sessionRequests').doc(requestId).update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Free session created');
      }

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      print('❌ Error accepting request: $e');
      print('Stack trace: $stack');
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// ✅ NEW: Consume subscription credit when teacher accepts
  Future<void> _consumeSubscriptionCredit(String subscriptionId) async {
    await _firestore.runTransaction((transaction) async {
      final subRef = _firestore.collection('subscriptions').doc(subscriptionId);
      final subDoc = await transaction.get(subRef);

      if (!subDoc.exists) {
        throw Exception('Subscription not found');
      }

      final data = subDoc.data()!;
      final remainingSessions = data['remainingSessions'] as int;

      if (remainingSessions <= 0) {
        throw Exception('No sessions remaining in subscription');
      }

      final newRemaining = remainingSessions - 1;
      final newStatus = newRemaining <= 0 ? 'depleted' : data['status'];

      transaction.update(subRef, {
        'remainingSessions': newRemaining,
        'status': newStatus,
        'lastUsedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Subscription credit consumed: $remainingSessions → $newRemaining');
    });
  }

  /// ✅ NEW: Send payment request notification to student
  Future<void> _sendPaymentRequestNotification({
    required String studentId,
    required String requestId,
    required String mohaffezName,
    required Map<String, dynamic> sessionDetails,
  }) async {
    try {
      final notificationRef = _firestore.collection('notifications').doc();

      await notificationRef.set({
        'userId': studentId,
        'title': 'تم قبول طلب الحجز! 🎉',
        'body': '$mohaffezName قبل طلبك. اضغط للدفع وتأكيد الجلسة.',
        'type': 'payment_required',
        'isRead': false,
        'requestId': requestId,
        'mohaffezName': mohaffezName,
        'sessionType': sessionDetails['sessionType'],
        'sessionDate': sessionDetails['slotDate'],
        'timeSlot': sessionDetails['preferredTimeSlot'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Payment notification created: ${notificationRef.id}');
    } catch (e) {
      print('❌ Error creating payment notification: $e');
      // Don't throw - notification failure shouldn't stop the acceptance
    }
  }

  /// ✅ NEW: Create session from accepted request
  Future<void> _createSessionFromRequest(
    String requestId,
    Map<String, dynamic> requestData,
  ) async {
    try {
      print('📝 Creating session from request: $requestId');

      final sessionData = {
        'mohaffezId': requestData['mohaffezId'],
        'studentId': requestData['studentId'],
        'studentName': requestData['studentName'],
        'mohaffezName': requestData['mohaffezName'],
        'sessionType': requestData['sessionType'],
        'sessionDate': requestData['slotDate'],
        'slotStart': requestData['slotStart'],
        'slotEnd': requestData['slotEnd'],
        'timeSlot': requestData['preferredTimeSlot'],
        'status': 'accepted',
        'isPaid': requestData['subscriptionId'] != null, // Paid if using subscription
        'subscriptionId': requestData['subscriptionId'],
        'requestId': requestId,
        'imamAddressText': requestData['imamAddressText'],
        'imamAddressLat': requestData['imamAddressLat'],
        'imamAddressLng': requestData['imamAddressLng'],
        'mohaffezPhone': requestData['mohaffezPhone'],
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
      };

      final sessionRef = await _firestore.collection('hafizSessions').add(sessionData);

      print('✅ Session created: ${sessionRef.id}');

      // Send acceptance notification
      await _sendAcceptanceNotification(
        studentId: requestData['studentId'],
        mohaffezName: requestData['mohaffezName'],
        sessionId: sessionRef.id,
        sessionDate: (requestData['slotDate'] as Timestamp).toDate(),
      );
    } catch (e) {
      print('❌ Error creating session: $e');
      rethrow;
    }
  }

  /// ✅ NEW: Send session acceptance notification
  Future<void> _sendAcceptanceNotification({
    required String studentId,
    required String mohaffezName,
    required String sessionId,
    required DateTime sessionDate,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': studentId,
        'title': 'تم قبول طلب الحجز! ✅',
        'body':
            '$mohaffezName قبل جلستك في ${DateFormat('dd/MM/yyyy', 'ar').format(sessionDate)}',
        'type': 'session_accepted',
        'isRead': false,
        'sessionId': sessionId,
        'mohaffezName': mohaffezName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error sending acceptance notification: $e');
    }
  }

  /// Reject request and release subscription credit if applicable
  Future<void> rejectRequest(String requestId, String? reason) async {
    try {
      print('🚫 Rejecting request: $requestId');

      // Get request details
      final requestDoc = await _firestore
          .collection('sessionRequests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      final subscriptionId = requestData['subscriptionId'] as String?;

      // Update request status
      await _firestore.collection('sessionRequests').doc(requestId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // NOTE: Subscription credit is NOT consumed on rejection
      // It remains available for the student to use for another booking
      if (subscriptionId != null) {
        print('💳 Subscription credit NOT consumed (request rejected)');
      }

      // Send rejection notification
      await _sendRejectionNotification(
        studentId: requestData['studentId'],
        mohaffezName: requestData['mohaffezName'],
        reason: reason,
      );

      print('✅ Request rejected successfully');
    } catch (e) {
      print('❌ Error rejecting request: $e');
      throw Exception('Failed to reject request: $e');
    }
  }

  /// ✅ NEW: Send rejection notification to student
  Future<void> _sendRejectionNotification({
    required String studentId,
    required String mohaffezName,
    String? reason,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': studentId,
        'title': 'تم رفض طلب الحجز',
        'body':
            '$mohaffezName اعتذر عن قبول الطلب${reason != null ? ": $reason" : ""}',
        'type': 'session_rejected',
        'isRead': false,
        'mohaffezName': mohaffezName,
        'rejectionReason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error sending rejection notification: $e');
    }
  }

  /// Update generic session details
  Future<void> updateSession(
    String sessionId,
    Map<String, dynamic> updates,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _firestore.collection('hafizSessions').doc(sessionId).update(updates);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Update assignment for a session
  Future<void> updateAssignment({
    required String sessionId,
    String? hifz,
    String? muraja,
    String? notes,
    int? rating,
  }) async {
    final updates = <String, dynamic>{};
    if (hifz != null) updates['hifzAssignment'] = hifz;
    if (muraja != null) updates['murajaAssignment'] = muraja;
    if (notes != null) updates['sessionNotes'] = notes;
    if (rating != null) updates['sessionRating'] = rating;

    if (updates.isNotEmpty) {
      await updateSession(sessionId, updates);
    }
  }

  /// ✅ Complete session with full details + status = COMPLETED
  Future<void> completeSessionWithDetails({
    required String sessionId,
    // تقييم التكليف السابق
    bool? previousHifzCompleted,
    int? previousHifzRating,
    bool? previousMurajaCompleted,
    int? previousMurajaRating,
    String? performanceNotes,
    // التكليف الجديد
    String? newHifzAssignment,
    String? newMurajaAssignment,
    // التقييم العام
    int sessionRating = 7,
    String? generalNotes,
    // ✅ NEW: Late completion flag
    bool isLateCompletion = false,
  }) async {
    state = const AsyncValue.loading();

    try {
      final updates = <String, dynamic>{
        'status': 'completed', // ✅ CHANGE STATUS TO COMPLETED
        'completedAt': FieldValue.serverTimestamp(),
        'sessionRating': sessionRating,
        'isLateCompletion': isLateCompletion, // ✅ NEW FIELD
      };

      // تقييم التكليف السابق
      if (previousHifzCompleted != null) {
        updates['previousHifzCompleted'] = previousHifzCompleted;
      }

      if (previousHifzRating != null) {
        updates['previousHifzRating'] = previousHifzRating;
      }

      if (previousMurajaCompleted != null) {
        updates['previousMurajaCompleted'] = previousMurajaCompleted;
      }

      if (previousMurajaRating != null) {
        updates['previousMurajaRating'] = previousMurajaRating;
      }

      if (performanceNotes != null && performanceNotes.isNotEmpty) {
        updates['performanceNotes'] = performanceNotes;
      }

      // التكليف الجديد
      if (newHifzAssignment != null && newHifzAssignment.isNotEmpty) {
        updates['hifzAssignment'] = newHifzAssignment;
      }

      if (newMurajaAssignment != null && newMurajaAssignment.isNotEmpty) {
        updates['murajaAssignment'] = newMurajaAssignment;
      }

      // الملاحظات العامة
      if (generalNotes != null && generalNotes.isNotEmpty) {
        updates['sessionNotes'] = generalNotes;
      }

      await _firestore.collection('hafizSessions').doc(sessionId).update(updates);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

// ============================================================================
// MOHAFFEZ STUDENTS PROVIDERS
// ============================================================================

/// Provider for mohaffez students list with their last session
final mohaffezStudentsProvider = StreamProvider.family<
    List<Map<String, dynamic>>,
    String>((ref, mohaffezId) {
  final firestore = FirebaseFirestore.instance;

  return firestore
      .collection('hafizSessions')
      .where('mohaffezId', isEqualTo: mohaffezId)
      .orderBy('sessionDate', descending: true)
      .snapshots()
      .map((snapshot) {
    // One aggregated entry per student
    final Map<String, Map<String, dynamic>> students = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final String? studentId = data['studentId'] as String?;
      if (studentId == null) continue;

      // We process sessions in descending order, so the first one we see
      // per student is the latest (and we keep it).
      if (!students.containsKey(studentId)) {
        final DateTime? lastSessionDate =
            (data['sessionDate'] as Timestamp?)?.toDate();

        students[studentId] = {
          // Identity
          'studentId': studentId,
          'studentName': data['studentName'] as String? ?? '',

          // Latest session info
          'lastSessionDate': lastSessionDate,
          'status': data['status'] as String? ?? 'accepted',

          // Current assignments from latest session
          'hifzAssignment': data['hifzAssignment'] as String? ?? '',
          'murajaAssignment': data['murajaAssignment'] as String? ?? '',

          // Latest session rating
          'sessionRating': data['sessionRating'] as int? ?? 0,

          // Performance evaluation saved on the session
          'previousHifzCompleted':
              data['previousHifzCompleted'] as bool?,
          'previousHifzRating':
              data['previousHifzRating'] as int? ?? 0,
          'previousMurajaCompleted':
              data['previousMurajaCompleted'] as bool?,
          'previousMurajaRating':
              data['previousMurajaRating'] as int? ?? 0,
          'performanceNotes':
              data['performanceNotes'] as String?,
        };
      }
    }

    return students.values.toList();
  });
});


/// Provider for student session count with specific mohaffez
final studentSessionCountProvider = FutureProvider.family<int, Map<String, String>>(
  (ref, params) async {
    final firestore = FirebaseFirestore.instance;
    final repository = SessionRepository(firestore);
    return repository.getStudentSessionCountWithMohaffez(
      params['mohaffezId']!,
      params['studentId']!,
    );
  },
);

/// Repository provider
final sessionRepositoryProvider = Provider((ref) {
  return SessionRepository(FirebaseFirestore.instance);
});
