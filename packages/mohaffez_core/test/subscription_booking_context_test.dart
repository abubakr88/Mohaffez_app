import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

void main() {
  group('SubscriptionModel booking context', () {
    test('parses the exact session and learner snapshot', () {
      final subscription = SubscriptionModel.fromJson({
        'id': 'subscription-1',
        'studentId': 'guardian-1',
        'studentName': 'Mariam',
        'mohaffezId': 'teacher-1',
        'mohaffezName': 'Teacher',
        'planId': 'plan-1',
        'planTitle': '8 sessions',
        'planType': 'bundle',
        'sessionType': 'online',
        'sessionDurationMinutes': 30,
        'guardianId': 'guardian-1',
        'guardianName': 'Parent',
        'studentProfileId': 'child-1',
        'studentProfileName': 'Mariam',
        'studentProfileGender': 'female',
        'studentProfilePhotoUrl': 'https://example.com/child.jpg',
        'totalSessions': 8,
        'remainingSessions': 7,
        'totalPaid': 340.0,
        'paymentTransactionId': 'payment-1',
        'status': 'active',
      });

      expect(subscription.sessionType, 'online');
      expect(subscription.sessionDurationMinutes, 30);
      expect(subscription.studentProfileId, 'child-1');
      expect(subscription.studentProfileName, 'Mariam');
      expect(subscription.canBookSession, isTrue);
    });

    test('legacy subscriptions keep an empty session type', () {
      final subscription = SubscriptionModel.fromJson({
        'studentId': 'student-1',
        'studentName': 'Student',
        'mohaffezId': 'teacher-1',
        'mohaffezName': 'Teacher',
        'planId': 'legacy-plan',
        'planTitle': 'Legacy bundle',
        'planType': 'bundle',
        'totalSessions': 5,
        'remainingSessions': 2,
        'totalPaid': 200.0,
        'paymentTransactionId': 'payment-legacy',
      });

      expect(subscription.sessionType, isEmpty);
      expect(subscription.sessionDurationMinutes, isNull);
      expect(subscription.canBookSession, isTrue);
    });
  });

  test('booking flow preserves the selected subscription ID', () {
    final notifier = BookingFlowNotifier();

    notifier.setSelectedSubscription('subscription-1');
    notifier.setBookingPath(BookingPath.useExistingBundle);

    expect(notifier.state.selectedSubscriptionId, 'subscription-1');
    expect(notifier.state.bookingPath, BookingPath.useExistingBundle);

    notifier.reset();
    expect(notifier.state.selectedSubscriptionId, isNull);
  });
}
