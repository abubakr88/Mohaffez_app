// functions/src/cancellations/cancellationPolicy.ts
//
// Pure policy logic for cancellation refunds and commission penalties.
// Extracted from index.ts so it can be unit-tested without Firestore.
//
// Refund and penalty values must match docs/TEACHER_PAYMENT_GUIDE_AR.md
// and docs/STUDENT_PAYMENT_GUIDE_AR.md.

export interface CancellationInput {
  cancelledBy: 'student' | 'teacher';
  teacherNoShow: boolean;
  sessionDate: Date | null;
  cancelledAt: Date;
}

export interface CancellationOutcome {
  refundPercent: 0 | 50 | 100;
  penaltyPercent: 0 | 0.5 | 1 | 1.5;
}

export function computeCancellationOutcome(input: CancellationInput): CancellationOutcome {
  const { cancelledBy, teacherNoShow, sessionDate, cancelledAt } = input;

  // Teacher no-show: full refund + max penalty
  if (teacherNoShow) {
    return { refundPercent: 100, penaltyPercent: 1.5 };
  }

  const hoursUntil = sessionDate
    ? (sessionDate.getTime() - cancelledAt.getTime()) / 3_600_000
    : null;

  if (cancelledBy === 'teacher') {
    // Teacher always refunds student 100%; penalty depends on lead time
    let penaltyPercent: CancellationOutcome['penaltyPercent'] = 0;
    if (hoursUntil !== null) {
      if (hoursUntil < 1) penaltyPercent = 1;
      else if (hoursUntil <= 3) penaltyPercent = 0.5;
    }
    return { refundPercent: 100, penaltyPercent };
  }

  // Student cancellation: refund depends on lead time, no penalty
  let refundPercent: CancellationOutcome['refundPercent'] = 0;
  if (hoursUntil !== null) {
    if (hoursUntil > 3) refundPercent = 100;
    else if (hoursUntil >= 1) refundPercent = 50;
  }
  return { refundPercent, penaltyPercent: 0 };
}
