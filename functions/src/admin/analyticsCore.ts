export type NumericTree = {
  [key: string]: number | NumericTree;
};

export interface AnalyticsProjection {
  eventKey: string;
  occurredAt: Date;
  deltas: NumericTree;
  teacherId?: string;
  teacherName?: string;
  teacherDeltas?: NumericTree;
}

const CAIRO_TIME_ZONE = 'Africa/Cairo';

export function dateKey(date: Date, timeZone = CAIRO_TIME_ZONE): string {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

export function monthKey(date: Date, timeZone = CAIRO_TIME_ZONE): string {
  return dateKey(date, timeZone).slice(0, 7);
}

export function pendingDateKeys(
  lastProcessed: unknown,
  through: string,
  maxDays = 31,
): string[] {
  if (typeof lastProcessed !== 'string' || lastProcessed.length !== 10) {
    return [through];
  }
  if (lastProcessed >= through) return [];

  const keys: string[] = [];
  const cursor = new Date(`${lastProcessed}T12:00:00.000Z`);
  if (Number.isNaN(cursor.getTime())) return [through];

  while (keys.length < maxDays) {
    cursor.setUTCDate(cursor.getUTCDate() + 1);
    const key = cursor.toISOString().slice(0, 10);
    if (key > through) break;
    keys.push(key);
  }
  return keys;
}

export function safeDimension(value: unknown, fallback = 'unknown'): string {
  if (typeof value !== 'string' || value.trim().length === 0) return fallback;
  const normalized = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '_')
    .replace(/^_+|_+$/g, '');
  return normalized || fallback;
}

export function finiteNumber(value: unknown, fallback = 0): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

export function nonEmptyString(value: unknown, fallback = ''): string {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : fallback;
}

export function mergeNumericTrees(
  target: NumericTree,
  source: NumericTree,
): NumericTree {
  for (const [key, value] of Object.entries(source)) {
    if (typeof value === 'number') {
      const current = target[key];
      target[key] = (typeof current === 'number' ? current : 0) + value;
      continue;
    }
    const current = target[key];
    const nested =
      current != null && typeof current === 'object' ? current : {};
    target[key] = mergeNumericTrees(nested, value);
  }
  return target;
}

export function userCreatedDeltas(data: Record<string, unknown>): NumericTree {
  const role = safeDimension(data.role, 'unknown');
  return {
    growth: {
      signups: 1,
      signupsByRole: { [role]: 1 },
    },
  };
}

export function requestCreatedDeltas(
  data: Record<string, unknown>,
): NumericTree {
  const sessionType = safeDimension(data.sessionType, 'unknown');
  const planType = safeDimension(data.planType, 'single');
  return {
    funnel: {
      requestsCreated: 1,
      requestsBySessionType: { [sessionType]: 1 },
      requestsByPlanType: { [planType]: 1 },
    },
  };
}

export function requestStatusDeltas(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
): NumericTree | null {
  const beforeStatus = safeDimension(before.status, 'unknown');
  const afterStatus = safeDimension(after.status, 'unknown');
  if (beforeStatus === afterStatus) return null;

  const fieldByStatus: Record<string, string> = {
    accepted: 'requestsAccepted',
    awaitingpayment: 'requestsAwaitingPayment',
    awaitingdirectpaymentconfirmation: 'requestsAwaitingDirectConfirmation',
    rejected: 'requestsRejected',
    cancelled: 'requestsCancelled',
    expired: 'requestsExpired',
  };
  const field = fieldByStatus[afterStatus];
  if (!field) return null;
  return { funnel: { [field]: 1 } };
}

export function paymentCreatedDeltas(
  data: Record<string, unknown>,
): NumericTree {
  const method = safeDimension(data.method ?? data.paymentMethod, 'unknown');
  return {
    payments: {
      created: 1,
      createdByMethod: { [method]: 1 },
    },
  };
}

export function paymentStatusDeltas(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
): NumericTree | null {
  const beforeStatus = safeDimension(before.status, 'unknown');
  const afterStatus = safeDimension(after.status, 'unknown');
  if (beforeStatus === afterStatus) return null;

  if (afterStatus === 'failed') {
    return { payments: { failed: 1 }, operations: { failedPayments: 1 } };
  }
  if (afterStatus === 'processing') {
    return { payments: { processing: 1 } };
  }

  const amount = Math.max(0, finiteNumber(after.amount));
  const method = safeDimension(after.method ?? after.paymentMethod, 'unknown');
  const planType = safeDimension(after.type ?? after.planType, 'single');

  if (afterStatus === 'completed') {
    return {
      funnel: { paymentsCompleted: 1 },
      payments: {
        completed: 1,
        grossRevenueEgp: amount,
        netRevenueEgp: amount,
        completedByMethod: { [method]: 1 },
        revenueByMethod: { [method]: amount },
        completedByPlanType: { [planType]: 1 },
        revenueByPlanType: { [planType]: amount },
      },
    };
  }

  if (afterStatus === 'refunded') {
    const refund = Math.max(0, finiteNumber(after.refundAmount, amount));
    return {
      payments: {
        refunded: 1,
        refundedAmountEgp: refund,
        netRevenueEgp: -refund,
      },
    };
  }

  return null;
}

export function sessionCreatedDeltas(
  data: Record<string, unknown>,
): NumericTree {
  const sessionType = safeDimension(data.sessionType, 'unknown');
  return {
    sessions: {
      created: 1,
      createdByType: { [sessionType]: 1 },
    },
  };
}

export function sessionStatusDeltas(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
): NumericTree | null {
  const beforeStatus = safeDimension(before.status, 'unknown');
  const afterStatus = safeDimension(after.status, 'unknown');
  const deltas: NumericTree = {};

  if (beforeStatus !== afterStatus) {
    if (afterStatus === 'completed') {
      mergeNumericTrees(deltas, {
        funnel: { sessionsCompleted: 1 },
        sessions: { completed: 1 },
      });
    } else if (afterStatus === 'cancelled') {
      mergeNumericTrees(deltas, { sessions: { cancelled: 1 } });
    } else if (afterStatus === 'student_no_show') {
      mergeNumericTrees(deltas, { sessions: { studentNoShows: 1 } });
    } else if (afterStatus === 'teacher_no_show') {
      mergeNumericTrees(deltas, { sessions: { teacherNoShows: 1 } });
    }
  }

  if (before.studentNoShow !== true && after.studentNoShow === true) {
    mergeNumericTrees(deltas, { sessions: { studentNoShows: 1 } });
  }
  if (before.teacherNoShow !== true && after.teacherNoShow === true) {
    mergeNumericTrees(deltas, { sessions: { teacherNoShows: 1 } });
  }

  return Object.keys(deltas).length > 0 ? deltas : null;
}

export function walletGroupDeltas(
  data: Record<string, unknown>,
): NumericTree | null {
  const type = nonEmptyString(data.type);
  const metadata =
    data.metadata != null && typeof data.metadata === 'object'
      ? (data.metadata as Record<string, unknown>)
      : {};

  if (type === 'direct_session_commission') {
    const amount = Math.max(0, finiteNumber(metadata.commissionEgp));
    return { finance: { commissionAccruedEgp: amount } };
  }
  if (type === 'direct_session_commission_reversal') {
    const amount = Math.max(0, finiteNumber(metadata.commissionEgp));
    return { finance: { commissionReversedEgp: amount } };
  }
  if (type === 'cycle_settlement') {
    const amount = Math.max(0, finiteNumber(metadata.commissionPiastres)) / 100;
    return amount > 0
      ? { finance: { commissionAccruedEgp: amount } }
      : null;
  }
  if (type === 'topup') {
    const amount =
      (Math.max(0, finiteNumber(metadata.duesCreditPiastres)) +
        Math.max(0, finiteNumber(metadata.availableCreditPiastres))) /
      100;
    return { finance: { walletTopUpsEgp: amount, walletTopUpsCount: 1 } };
  }
  if (type === 'session_refund') {
    return { finance: { walletRefundsCount: 1 } };
  }
  return null;
}
