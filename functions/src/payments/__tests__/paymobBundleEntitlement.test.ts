import { describe, expect, it } from 'vitest';
import {
  buildBundleEntitlementValues,
  isRequestBackedBundlePayment,
  paymobBundleSubscriptionId,
  promoBundleSubscriptionId,
} from '../paymobBundleEntitlement';

const bundlePayment = {
  amount: 340,
  status: 'completed',
  studentId: 'parent-1',
  studentName: 'Parent',
  mohaffezId: 'teacher-1',
  mohaffezName: 'Teacher',
  planType: 'bundle',
  sessionsCount: 8,
  validityDays: 60,
  metadata: {
    confirmBooking: true,
    requestId: 'request-1',
    planId: 'plan-8',
    planTitle: '8 sessions',
    planType: 'bundle',
    sessionsCount: 8,
    validityDays: 60,
  },
} as const;

const request = {
  studentId: 'parent-1',
  studentName: 'Parent',
  guardianId: 'parent-1',
  guardianName: 'Parent',
  studentProfileId: 'child-1',
  studentProfileName: 'Child',
  studentProfileGender: 'female',
  studentProfileBirthDate: '2015-05-10',
  studentAge: 11,
  mohaffezId: 'teacher-1',
  mohaffezName: 'Teacher',
  planId: 'plan-8',
  planTitle: '8 sessions',
  sessionType: 'online',
  sessionDurationMinutes: 45,
  studentCountryCode: 'EG',
  displayCurrencyCode: 'EGP',
  displayAmount: 340,
  fxRateToEGP: 1,
  chargedAmountEGP: 340,
};

describe('request-backed Paymob bundle entitlements', () => {
  it('routes only accepted request-backed bundle payments to the bundle path', () => {
    expect(
      isRequestBackedBundlePayment(bundlePayment.metadata, bundlePayment),
    ).toBe(true);
    expect(
      isRequestBackedBundlePayment(
        { ...bundlePayment.metadata, planType: 'single', sessionsCount: 1 },
        { ...bundlePayment, planType: 'single', sessionsCount: 1 },
      ),
    ).toBe(false);
    expect(
      isRequestBackedBundlePayment(
        { ...bundlePayment.metadata, confirmBooking: false },
        bundlePayment,
      ),
    ).toBe(false);
  });

  it('creates an active 8-session entitlement with the first session consumed', () => {
    const result = buildBundleEntitlementValues({
      paymentId: 'payment-1',
      payment: bundlePayment,
      requestId: 'request-1',
      request,
      sessionId: 'session-1',
      session: { status: 'scheduled' },
      transactionId: 'paymob-494817359',
    });

    expect(result.subscriptionId).toBe('paymob_payment-1');
    expect(result.totalSessions).toBe(8);
    expect(result.remainingSessions).toBe(7);
    expect(result.validityDays).toBe(60);
    expect(result.data).toMatchObject({
      status: 'active',
      studentId: 'parent-1',
      guardianId: 'parent-1',
      studentProfileId: 'child-1',
      studentProfileName: 'Child',
      mohaffezId: 'teacher-1',
      planId: 'plan-8',
      sessionType: 'online',
      sessionDurationMinutes: 45,
      totalSessions: 8,
      remainingSessions: 7,
      sourcePaymentId: 'payment-1',
      sessionRequestId: 'request-1',
      firstSessionId: 'session-1',
      paymentType: 'paymob',
    });
  });

  it('uses a deterministic subscription id for webhook retries', () => {
    expect(paymobBundleSubscriptionId('payment-1')).toBe('paymob_payment-1');
    expect(paymobBundleSubscriptionId('payment-1')).toBe(
      paymobBundleSubscriptionId('payment-1'),
    );
  });

  it('creates a deterministic free-promo bundle entitlement', () => {
    const payment = {
      ...bundlePayment,
      amount: 0,
      method: 'free',
      metadata: {
        ...bundlePayment.metadata,
        promoCode: 'ALFATEHA',
      },
    };
    const subscriptionId = promoBundleSubscriptionId('promo-payment-1');
    const result = buildBundleEntitlementValues({
      paymentId: 'promo-payment-1',
      payment,
      requestId: 'request-1',
      request,
      sessionId: 'session-1',
      session: { status: 'scheduled' },
      transactionId: 'promo-payment-1',
      subscriptionId,
      paymentType: 'promo',
      paymentGateway: 'promo',
      promoCode: 'ALFATEHA',
    });

    expect(result.subscriptionId).toBe('promo_promo-payment-1');
    expect(result.totalSessions).toBe(8);
    expect(result.remainingSessions).toBe(7);
    expect(result.data).toMatchObject({
      status: 'active',
      totalPaid: 0,
      totalSessions: 8,
      remainingSessions: 7,
      paymentType: 'promo',
      paymentGateway: 'promo',
      promoCode: 'ALFATEHA',
      sourcePaymentId: 'promo-payment-1',
      firstSessionId: 'session-1',
    });
  });

  it('rejects non-bundle entitlement creation', () => {
    expect(() => buildBundleEntitlementValues({
      paymentId: 'payment-single',
      payment: { ...bundlePayment, planType: 'single', sessionsCount: 1 },
      metadata: { planType: 'single', sessionsCount: 1 },
      requestId: 'request-1',
      request,
      sessionId: 'session-1',
      transactionId: 'paymob-single',
    })).toThrow('more than one session');
  });
});
