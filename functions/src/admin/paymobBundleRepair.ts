import * as functions from 'firebase-functions';
import admin, { db, FieldValue } from '../utils/admin';
import { requireSuperAdminAccess } from '../utils/adminPermissions';
import { writeAdminAuditLog } from '../utils/auditLog';
import { sanitizeForFirestore } from '../utils/firestoreSanitizer';
import { PaymentEventType } from '../types/events.types';
import {
  buildBundleEntitlementValues,
  isBundlePlan,
  paymobBundleSubscriptionId,
  promoBundleSubscriptionId,
} from '../payments/paymobBundleEntitlement';

type Data = Record<string, unknown>;
type BundleRepairSource = 'paymob' | 'promo';

interface RepairCandidate {
  source: BundleRepairSource;
  paymentId: string;
  payment: Data;
  requestId: string;
  request: Data;
  sessionId: string;
  session: Data;
  subscriptionId: string;
}

const stringValue = (...values: unknown[]): string => {
  for (const value of values) {
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
  }
  return '';
};

const mapValue = (value: unknown): Data =>
  value != null && typeof value === 'object' ? value as Data : {};

const timestampValue = (...values: unknown[]): admin.firestore.Timestamp | null => {
  for (const value of values) {
    if (value instanceof admin.firestore.Timestamp) return value;
  }
  return null;
};

const isCompleted = (payment: Data): boolean =>
  stringValue(payment.status).toLowerCase() === 'completed';

const isPaymobPayment = (payment: Data): boolean => {
  const gatewayResponse = mapValue(payment.gatewayResponse);
  const provider = stringValue(
    payment.gateway,
    payment.paymentGateway,
    gatewayResponse.provider,
  ).toLowerCase();
  return provider === 'paymob' || provider === 'paymob_flash';
};

const isFreePromoPayment = (payment: Data): boolean => {
  const metadata = mapValue(payment.metadata);
  const amount = typeof payment.amount === 'number'
    ? payment.amount
    : Number(payment.amount);
  const promoCode = stringValue(payment.promoCode, metadata.promoCode);
  return Number.isFinite(amount) && amount <= 0.01 && promoCode.length > 0;
};

function subscriptionIdFor(
  source: BundleRepairSource,
  paymentId: string,
): string {
  return source === 'promo'
    ? promoBundleSubscriptionId(paymentId)
    : paymobBundleSubscriptionId(paymentId);
}

function existingSubscriptionId(
  payment: Data,
  request: Data,
  session: Data,
): string {
  return stringValue(
    payment.subscriptionId,
    request.subscriptionId,
    session.subscriptionId,
  );
}

function assertCandidateDocuments(candidate: RepairCandidate): void {
  const { payment, request, session, source } = candidate;
  if (!isCompleted(payment)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'payment-not-completed',
    );
  }
  if (source === 'paymob' && !isPaymobPayment(payment)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'payment-is-not-paymob',
    );
  }
  if (source === 'promo' && !isFreePromoPayment(payment)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'payment-is-not-a-free-promo-payment',
    );
  }
  if (!isBundlePlan(mapValue(payment.metadata), payment)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'payment-is-not-a-bundle',
    );
  }

  const studentId = stringValue(payment.studentId);
  const mohaffezId = stringValue(payment.mohaffezId);
  if (
    !studentId ||
    !mohaffezId ||
    request.studentId !== studentId ||
    request.mohaffezId !== mohaffezId ||
    session.studentId !== studentId ||
    session.mohaffezId !== mohaffezId
  ) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'linked-documents-do-not-match-payment',
    );
  }

  const requestSessionId = stringValue(request.sessionId);
  const sessionRequestId = stringValue(session.requestId);
  if (
    (requestSessionId && requestSessionId !== candidate.sessionId) ||
    (sessionRequestId && sessionRequestId !== candidate.requestId)
  ) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'request-session-links-do-not-match',
    );
  }
}

async function loadCandidate(
  source: BundleRepairSource,
  paymentId: string,
): Promise<RepairCandidate> {
  const paymentRef = db.collection('payments').doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'payment-not-found');
  }

  const payment = paymentSnap.data() as Data;
  const metadata = mapValue(payment.metadata);
  const requestId = stringValue(payment.requestId, metadata.requestId);
  if (!requestId) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'payment-has-no-session-request',
    );
  }

  const requestRef = db.collection('sessionRequests').doc(requestId);
  const requestSnap = await requestRef.get();
  if (!requestSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'session-request-not-found');
  }
  const request = requestSnap.data() as Data;
  const sessionId = stringValue(payment.sessionId, request.sessionId);
  if (!sessionId) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'payment-has-no-created-session',
    );
  }

  const sessionRef = db.collection('hafizSessions').doc(sessionId);
  const sessionSnap = await sessionRef.get();
  if (!sessionSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'linked-session-not-found');
  }

  const candidate: RepairCandidate = {
    source,
    paymentId,
    payment,
    requestId,
    request,
    sessionId,
    session: sessionSnap.data() as Data,
    subscriptionId: subscriptionIdFor(source, paymentId),
  };
  assertCandidateDocuments(candidate);
  return candidate;
}

function candidatePreview(candidate: RepairCandidate): Data {
  const metadata = mapValue(candidate.payment.metadata);
  const entitlement = buildBundleEntitlementValues({
    paymentId: candidate.paymentId,
    payment: candidate.payment,
    metadata,
    requestId: candidate.requestId,
    request: candidate.request,
    sessionId: candidate.sessionId,
    session: candidate.session,
    transactionId: stringValue(
      candidate.payment.gatewayTransactionId,
      candidate.payment.transactionReference,
      candidate.paymentId,
    ),
    subscriptionId: candidate.subscriptionId,
    paymentType: candidate.source,
    paymentGateway: candidate.source,
    promoCode: candidate.source === 'promo'
      ? stringValue(metadata.promoCode, candidate.payment.promoCode)
      : undefined,
  });
  const linkedSubscriptionId = existingSubscriptionId(
    candidate.payment,
    candidate.request,
    candidate.session,
  );
  return {
    paymentId: candidate.paymentId,
    requestId: candidate.requestId,
    sessionId: candidate.sessionId,
    subscriptionId: linkedSubscriptionId || entitlement.subscriptionId,
    alreadyRepaired: linkedSubscriptionId.length > 0,
    eligible: linkedSubscriptionId.length === 0,
    totalSessions: entitlement.totalSessions,
    remainingSessions: entitlement.remainingSessions,
    studentId: candidate.payment.studentId,
    studentName: candidate.payment.studentName,
    mohaffezId: candidate.payment.mohaffezId,
    mohaffezName: candidate.payment.mohaffezName,
    planTitle: metadata.planTitle ?? candidate.payment.planTitle ?? null,
    amount: candidate.payment.amount,
    source: candidate.source,
  };
}

async function repairMissingBundleSubscription(
  source: BundleRepairSource,
  data: Record<string, unknown>,
  context: functions.https.CallableContext,
) {
    const access = await requireSuperAdminAccess(context);
    const paymentId = stringValue(data?.paymentId);
    const dryRun = data?.dryRun !== false;
    if (!paymentId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'paymentId-required',
      );
    }

    const initialCandidate = await loadCandidate(source, paymentId);
    const preview = candidatePreview(initialCandidate);
    if (dryRun || preview.alreadyRepaired === true) {
      functions.logger.info('Bundle entitlement repair inspected', {
        actorId: access.uid,
        paymentId,
        source,
        dryRun,
        eligible: preview.eligible,
        alreadyRepaired: preview.alreadyRepaired,
      });
      return {
        success: true,
        dryRun,
        changed: false,
        ...preview,
      };
    }

    const paymentRef = db.collection('payments').doc(paymentId);
    const result = await db.runTransaction(async (transaction) => {
      const paymentSnap = await transaction.get(paymentRef);
      if (!paymentSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'payment-not-found');
      }
      const payment = paymentSnap.data() as Data;
      const metadata = mapValue(payment.metadata);
      const requestId = stringValue(payment.requestId, metadata.requestId);
      if (!requestId) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'payment-has-no-session-request',
        );
      }
      const requestRef = db.collection('sessionRequests').doc(requestId);
      const requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'session-request-not-found');
      }
      const request = requestSnap.data() as Data;
      const sessionId = stringValue(payment.sessionId, request.sessionId);
      if (!sessionId) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'payment-has-no-created-session',
        );
      }
      const sessionRef = db.collection('hafizSessions').doc(sessionId);
      const subscriptionId = subscriptionIdFor(source, paymentId);
      const subscriptionRef = db.collection('subscriptions').doc(subscriptionId);
      const [sessionSnap, subscriptionSnap] = await Promise.all([
        transaction.get(sessionRef),
        transaction.get(subscriptionRef),
      ]);
      if (!sessionSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'linked-session-not-found');
      }

      const candidate: RepairCandidate = {
        source,
        paymentId,
        payment,
        requestId,
        request,
        sessionId,
        session: sessionSnap.data() as Data,
        subscriptionId,
      };
      assertCandidateDocuments(candidate);

      const alreadyLinked = existingSubscriptionId(
        payment,
        request,
        candidate.session,
      );
      if (alreadyLinked || subscriptionSnap.exists) {
        if (!alreadyLinked && subscriptionSnap.exists) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'deterministic-subscription-exists-without-links',
          );
        }
        return {
          changed: false,
          subscriptionId: alreadyLinked || subscriptionId,
          ...candidatePreview(candidate),
        };
      }

      const entitlement = buildBundleEntitlementValues({
        paymentId,
        payment,
        metadata,
        requestId,
        request,
        sessionId,
        session: candidate.session,
        transactionId: stringValue(
          payment.gatewayTransactionId,
          payment.transactionReference,
          paymentId,
        ),
        subscriptionId,
        paymentType: source,
        paymentGateway: source,
        promoCode: source === 'promo'
          ? stringValue(metadata.promoCode, payment.promoCode)
          : undefined,
      });
      const originalStart = timestampValue(
        payment.paidAt,
        payment.completedAt,
        payment.createdAt,
        request.paidAt,
        candidate.session.acceptedAt,
        candidate.session.createdAt,
      ) ?? admin.firestore.Timestamp.now();
      const expiryDate = entitlement.validityDays == null
        ? null
        : admin.firestore.Timestamp.fromMillis(
            originalStart.toMillis() + entitlement.validityDays * 86400000,
          );
      const timestamp = FieldValue.serverTimestamp();
      const teacherWalletLedgerGroupId = stringValue(
        payment.teacherWalletLedgerGroupId,
        candidate.session.teacherWalletLedgerGroupId,
      );

      transaction.set(subscriptionRef, sanitizeForFirestore({
        ...entitlement.data,
        startDate: originalStart,
        expiryDate,
        ...(teacherWalletLedgerGroupId
          ? { teacherWalletLedgerGroupId }
          : {}),
        repairedAt: timestamp,
        repairedBy: access.uid,
        createdAt: originalStart,
        updatedAt: timestamp,
      }));
      transaction.update(paymentRef, {
        subscriptionId,
        bundleEntitlementRepairedAt: timestamp,
        bundleEntitlementRepairedBy: access.uid,
        bundleEntitlementRepairSource: source,
        updatedAt: timestamp,
      });
      transaction.update(requestRef, {
        subscriptionId,
        paymentType: source,
        planType: 'bundle',
        updatedAt: timestamp,
      });
      transaction.update(sessionRef, {
        subscriptionId,
        paymentType: source,
        paymentGateway: source,
        planType: 'bundle',
        updatedAt: timestamp,
      });

      const eventRef = db.collection('paymentEvents').doc();
      transaction.set(eventRef, sanitizeForFirestore({
        eventId: eventRef.id,
        eventType: PaymentEventType.SUBSCRIPTION_REPAIRED,
        paymentId,
        userId: payment.studentId,
        data: {
          requestId,
          sessionId,
          subscriptionId,
          totalSessions: entitlement.totalSessions,
          remainingSessions: entitlement.remainingSessions,
        },
        metadata: { source: 'admin' },
        timestamp,
      }));
      await writeAdminAuditLog({
        action: source === 'promo'
          ? 'FREE_PROMO_BUNDLE_SUBSCRIPTION_REPAIRED'
          : 'PAYMOB_BUNDLE_SUBSCRIPTION_REPAIRED',
        actorId: access.uid,
        actorEmail: stringValue(context.auth?.token.email) || null,
        actorRole: access.role,
        source: 'adminDashboard',
        targetUserId: stringValue(payment.studentId) || null,
        targetId: paymentId,
        targetType: 'payment',
        reason: source === 'promo'
          ? 'Create missing bundle entitlement after completed 100% promo payment'
          : 'Create missing bundle entitlement after completed Paymob payment',
        before: {
          paymentSubscriptionId: null,
          requestSubscriptionId: null,
          sessionSubscriptionId: null,
        },
        after: { subscriptionId },
        data: {
          requestId,
          sessionId,
          totalSessions: entitlement.totalSessions,
          remainingSessions: entitlement.remainingSessions,
          financialFieldsChanged: false,
          promoRedemptionChanged: false,
          source,
        },
        context,
        transaction,
      });

      return {
        changed: true,
        subscriptionId,
        totalSessions: entitlement.totalSessions,
        remainingSessions: entitlement.remainingSessions,
        requestId,
        sessionId,
      };
    });

    functions.logger.warn('Missing bundle entitlement repaired', {
      actorId: access.uid,
      paymentId,
      source,
      changed: result.changed,
      subscriptionId: result.subscriptionId,
    });
    return {
      success: true,
      dryRun: false,
      ...result,
    };
}

export const repairMissingPaymobBundleSubscription = functions.https.onCall(
  (data, context) => repairMissingBundleSubscription('paymob', data, context),
);

export const repairMissingFreePromoBundleSubscription = functions.https.onCall(
  (data, context) => repairMissingBundleSubscription('promo', data, context),
);
