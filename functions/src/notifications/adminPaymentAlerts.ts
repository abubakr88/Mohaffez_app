// functions/src/notifications/adminPaymentAlerts.ts
//
// Proactive admin alerts for the things an admin must NOT miss:
//   1. payment_failed  — a customer payment failed; someone should look.
//   2. wallet integrity — a non-system wallet's available balance went
//      negative. This should be impossible (postLedgerEntry blocks it), so if
//      it ever happens it's a data-integrity alarm, not a normal event.
//
// Both fan out to every admin via notifyAllAdmins, so the admin bell badges
// without anyone polling Firestore. Teacher-facing alerts (payout_failed,
// payout_completed) already live in walletPayout.ts.

import * as functions from 'firebase-functions';
import { notifyAllAdmins } from '../utils/notificationHelpers';
import { PaymentEventType } from '../types/events.types';

/**
 * Fires when a payment event is appended. We only act on PAYMENT_FAILED — a
 * failed charge the admin should investigate (e.g. a stuck booking, a gateway
 * decline). The notification deep-links to the payment-events page.
 */
export const onPaymentFailedAlertAdmins = functions.firestore
  .document('paymentEvents/{eventId}')
  .onCreate(async (snap, context) => {
    const event = snap.data() as Record<string, unknown>;
    if (event.eventType !== PaymentEventType.PAYMENT_FAILED) return;

    const paymentId = (event.paymentId as string | undefined) ?? '';
    const userId = (event.userId as string | undefined) ?? '';
    const data = (event.data as Record<string, unknown> | undefined) ?? {};
    const amount = data.amount != null ? String(data.amount) : '';
    const reason =
      (data.reason as string | undefined) ??
      (data.failureReason as string | undefined) ??
      '';

    const body = amount
      ? `فشل دفع بقيمة ${amount} ج.م${reason ? ` — ${reason}` : ''}`
      : `فشلت عملية دفع${reason ? ` — ${reason}` : ''}`;

    await notifyAllAdmins({
      senderId: userId || null,
      title: 'فشل عملية دفع',
      body,
      type: 'admin_payment_failed',
      highPriority: true,
      data: {
        paymentId,
        payerId: userId,
        eventId: context.params.eventId,
      },
    });
  });

/**
 * Fires when a wallet doc is updated. Alarms admins if a NON-system wallet's
 * available balance crosses into the negative. Double-entry invariants forbid
 * this, so it indicates a bug or a manual data edit that bypassed the ledger.
 * Edge-triggered (only when crossing 0→negative) to avoid repeat spam while a
 * wallet stays negative.
 */
export const onWalletNegativeAlertAdmins = functions.firestore
  .document('wallets/{walletId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as Record<string, unknown>;
    const after = change.after.data() as Record<string, unknown>;

    if (after.ownerType === 'system') return; // negative system wallets are normal

    const beforeBal = (before.balancePiastres as number | undefined) ?? 0;
    const afterBal = (after.balancePiastres as number | undefined) ?? 0;

    // Edge: only alert on the transition into negative territory.
    if (!(beforeBal >= 0 && afterBal < 0)) return;

    const walletId = context.params.walletId;
    const ownerType = (after.ownerType as string | undefined) ?? 'user';
    const egp = (afterBal / 100).toFixed(2);

    await notifyAllAdmins({
      senderId: null,
      title: 'تنبيه: رصيد محفظة سالب',
      body:
        `أصبح رصيد محفظة ${ownerType === 'mohaffez' ? 'محفّظ' : 'طالب'} ` +
        `سالبًا (${egp} ج.م). يلزم مراجعة فورية لسلامة البيانات.`,
      type: 'admin_wallet_negative',
      highPriority: true,
      data: {
        walletId,
        ownerType,
        balancePiastres: afterBal,
      },
    });
  });
