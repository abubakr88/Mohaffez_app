import { describe, expect, it } from 'vitest';
import { buildPaymobTeacherEarningLedger } from '../handlers';
import { SYSTEM_WALLETS, walletIdForUser } from '../../wallet/walletUtils';

const payment = {
  amount: 100,
  status: 'processing',
  studentId: 'student-1',
  studentName: 'Student',
  mohaffezId: 'teacher-1',
  mohaffezName: 'Teacher',
  metadata: {
    planTitle: 'Single session',
    planType: 'single',
  },
} as const;

describe('Paymob teacher wallet accounting', () => {
  it('credits the full gross payment to teacher pending exactly once per payment', () => {
    const ledger = buildPaymobTeacherEarningLedger(
      payment,
      { paymentId: 'payment-1', transactionId: 'paymob-tx-1' },
      { sessionId: 'session-1' },
    );

    expect(ledger).not.toBeNull();
    expect(ledger?.groupId).toBe('paymob_earning_payment-1');
    expect(ledger?.relatedPaymentId).toBe('payment-1');
    expect(ledger?.relatedSessionId).toBe('session-1');
    expect(ledger?.legs).toEqual([
      {
        walletId: SYSTEM_WALLETS.topups,
        ownerType: 'system',
        amountPiastres: -10000,
      },
      {
        walletId: walletIdForUser('teacher-1'),
        ownerType: 'mohaffez',
        amountPiastres: 10000,
        target: 'pending',
      },
    ]);
  });

  it('does not create earnings for free or non-Paymob handler calls', () => {
    expect(buildPaymobTeacherEarningLedger(payment, undefined)).toBeNull();
    expect(
      buildPaymobTeacherEarningLedger(
        { ...payment, amount: 0 },
        { paymentId: 'free-payment', transactionId: 'free-tx' },
      ),
    ).toBeNull();
  });
});
