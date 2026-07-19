import { PaymentDocument, PaymentMetadata } from '../types/payment.types';

const BUNDLE_PLAN_TYPE = 'bundle';

const stringValue = (...values: unknown[]): string => {
  for (const value of values) {
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
  }
  return '';
};

const numberValue = (...values: unknown[]): number | null => {
  for (const value of values) {
    if (typeof value === 'number' && Number.isFinite(value)) return value;
  }
  return null;
};

const optionalValue = (...values: unknown[]): unknown => {
  for (const value of values) {
    if (value !== undefined && value !== null && value !== '') return value;
  }
  return null;
};

const mapValue = (value: unknown): Record<string, unknown> =>
  value != null && typeof value === 'object'
    ? value as Record<string, unknown>
    : {};

export function paymobBundleSubscriptionId(paymentId: string): string {
  return `paymob_${paymentId}`;
}

export function promoBundleSubscriptionId(paymentId: string): string {
  return `promo_${paymentId}`;
}

export function isBundlePlan(
  metadata: PaymentMetadata | Record<string, unknown> | undefined,
  payment?: PaymentDocument | Record<string, unknown>,
): boolean {
  const paymentData = mapValue(payment);
  const metadataData = mapValue(metadata);
  const planType = stringValue(
    metadataData.planType,
    paymentData.planType,
  ).toLowerCase();
  const sessionsCount = numberValue(
    metadataData.sessionsCount,
    paymentData.sessionsCount,
  );
  return planType === BUNDLE_PLAN_TYPE && (sessionsCount ?? 0) > 1;
}

export function isRequestBackedBundlePayment(
  metadata: PaymentMetadata | Record<string, unknown> | undefined,
  payment?: PaymentDocument | Record<string, unknown>,
): boolean {
  const data = mapValue(metadata);
  return data.confirmBooking === true &&
    stringValue(data.requestId).length > 0 &&
    isBundlePlan(data, payment);
}

export interface BundleEntitlementInput {
  paymentId: string;
  payment: PaymentDocument | Record<string, unknown>;
  metadata?: PaymentMetadata | Record<string, unknown>;
  requestId: string;
  request: Record<string, unknown>;
  sessionId: string;
  session?: Record<string, unknown>;
  transactionId: string;
  subscriptionId?: string;
  paymentType?: string;
  paymentGateway?: string;
  promoCode?: string;
}

export interface BundleEntitlementValues {
  subscriptionId: string;
  totalSessions: number;
  remainingSessions: number;
  validityDays: number | null;
  data: Record<string, unknown>;
}

export function buildBundleEntitlementValues(
  input: BundleEntitlementInput,
): BundleEntitlementValues {
  const payment = mapValue(input.payment);
  const paymentMetadata = mapValue(payment.metadata);
  const metadata = {
    ...paymentMetadata,
    ...mapValue(input.metadata),
  };
  const sessionDetails = mapValue(metadata.sessionDetails);
  const request = input.request;
  const session = input.session ?? {};

  const totalSessions = Math.trunc(numberValue(
    metadata.sessionsCount,
    payment.sessionsCount,
  ) ?? 0);
  if (totalSessions <= 1) {
    throw new Error('A paid bundle must contain more than one session');
  }

  const planType = stringValue(
    metadata.planType,
    payment.planType,
  ).toLowerCase();
  if (planType !== BUNDLE_PLAN_TYPE) {
    throw new Error('Payment is not a bundle payment');
  }

  const validityValue = numberValue(
    metadata.validityDays,
    payment.validityDays,
  );
  const validityDays = validityValue != null && validityValue > 0
    ? Math.trunc(validityValue)
    : null;
  const remainingSessions = Math.max(0, totalSessions - 1);
  const subscriptionId = stringValue(input.subscriptionId) ||
    paymobBundleSubscriptionId(input.paymentId);
  const paymentType = stringValue(input.paymentType) || 'paymob';
  const paymentGateway = stringValue(input.paymentGateway) || paymentType;
  const promoCode = stringValue(input.promoCode, metadata.promoCode);
  const sessionDurationMinutes = numberValue(
    request.sessionDurationMinutes,
    session.sessionDurationMinutes,
    sessionDetails.sessionDurationMinutes,
    metadata.sessionDurationMinutes,
  );

  const studentId = stringValue(payment.studentId, request.studentId);
  const mohaffezId = stringValue(payment.mohaffezId, request.mohaffezId);
  if (!studentId || !mohaffezId) {
    throw new Error('Bundle owner or teacher is missing');
  }

  const data: Record<string, unknown> = {
    studentId,
    studentName: stringValue(
      request.studentProfileName,
      request.studentName,
      payment.studentName,
    ),
    guardianId: optionalValue(request.guardianId, metadata.guardianId, studentId),
    guardianName: optionalValue(request.guardianName, metadata.guardianName),
    studentProfileId: optionalValue(
      request.studentProfileId,
      session.studentProfileId,
      metadata.studentProfileId,
    ),
    studentProfileName: optionalValue(
      request.studentProfileName,
      session.studentProfileName,
      metadata.studentProfileName,
      request.studentName,
      payment.studentName,
    ),
    studentProfileGender: optionalValue(
      request.studentProfileGender,
      session.studentProfileGender,
      metadata.studentProfileGender,
    ),
    studentProfileBirthDate: optionalValue(
      request.studentProfileBirthDate,
      session.studentProfileBirthDate,
      metadata.studentProfileBirthDate,
    ),
    studentAge: optionalValue(
      request.studentAge,
      session.studentAge,
      metadata.studentAge,
    ),
    mohaffezId,
    mohaffezName: stringValue(
      request.mohaffezName,
      payment.mohaffezName,
    ),
    planId: stringValue(metadata.planId, payment.planId, request.planId),
    planTitle: stringValue(
      metadata.planTitle,
      payment.planTitle,
      request.planTitle,
    ),
    planType: BUNDLE_PLAN_TYPE,
    sessionType: stringValue(
      request.sessionType,
      session.sessionType,
      sessionDetails.sessionType,
      metadata.sessionType,
    ),
    totalSessions,
    remainingSessions,
    totalPaid: numberValue(payment.amount) ?? 0,
    paymentTransactionId: input.transactionId,
    paymentType,
    paymentGateway,
    sourcePaymentId: input.paymentId,
    sessionRequestId: input.requestId,
    firstSessionId: input.sessionId,
    status: remainingSessions > 0 ? 'active' : 'depleted',
    studentCountryCode: optionalValue(
      request.studentCountryCode,
      metadata.studentCountryCode,
    ),
    studentCountryName: optionalValue(
      request.studentCountryName,
      metadata.studentCountryName,
    ),
    displayCurrencyCode: optionalValue(
      request.displayCurrencyCode,
      metadata.displayCurrencyCode,
    ),
    displayCurrencyLabel: optionalValue(
      request.displayCurrencyLabel,
      metadata.displayCurrencyLabel,
    ),
    displayAmount: optionalValue(request.displayAmount, metadata.displayAmount),
    fxRateToEGP: optionalValue(request.fxRateToEGP, metadata.fxRateToEGP),
    chargedAmountEGP: optionalValue(
      request.chargedAmountEGP,
      metadata.chargedAmountEGP,
      payment.amount,
    ),
    sessionDurationMinutes: sessionDurationMinutes == null
      ? null
      : Math.trunc(sessionDurationMinutes),
    ...(promoCode ? { promoCode } : {}),
  };

  return {
    subscriptionId,
    totalSessions,
    remainingSessions,
    validityDays,
    data,
  };
}
