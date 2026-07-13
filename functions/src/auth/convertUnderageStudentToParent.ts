import * as functions from 'firebase-functions';

import admin, { db, FieldValue } from '../utils/admin';

const DEFAULT_MINIMUM_STUDENT_AGE = 18;

function parseIsoDate(value: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return null;
  }
  return date;
}

function calculateAge(dateOfBirth: Date, now: Date): number {
  let age = now.getUTCFullYear() - dateOfBirth.getUTCFullYear();
  const birthdayNotReached =
    now.getUTCMonth() < dateOfBirth.getUTCMonth() ||
    (now.getUTCMonth() === dateOfBirth.getUTCMonth() &&
      now.getUTCDate() < dateOfBirth.getUTCDate());
  if (birthdayNotReached) age -= 1;
  return age;
}

/**
 * Converts an incomplete student account to a parent account when the entered
 * birth date is below the admin-configured independent-student age.
 */
export const convertUnderageStudentToParent = functions.https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'يجب تسجيل الدخول أولاً',
      );
    }

    const rawBirthDate =
      typeof data?.dateOfBirth === 'string' ? data.dateOfBirth.trim() : '';
    const dateOfBirth = parseIsoDate(rawBirthDate);
    const now = new Date();
    if (
      dateOfBirth == null ||
      dateOfBirth.getUTCFullYear() < 1900 ||
      dateOfBirth.getTime() > now.getTime()
    ) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'تاريخ الميلاد غير صحيح',
      );
    }

    const userRef = db.collection('users').doc(uid);
    const configRef = db.collection('systemConfig').doc('global');

    const result = await db.runTransaction(async (transaction) => {
      const [userSnap, configSnap] = await Promise.all([
        transaction.get(userRef),
        transaction.get(configRef),
      ]);
      if (!userSnap.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'حساب المستخدم غير موجود',
        );
      }

      const user = userSnap.data() ?? {};
      if (user.role !== 'student') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'هذه العملية متاحة لحساب طالب غير مكتمل فقط',
        );
      }
      if (user.setupCompleted === true) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'لا يمكن تغيير نوع حساب مكتمل من هذه الشاشة',
        );
      }

      const configuredAge = Number(
        configSnap.data()?.minimumIndependentStudentAge ??
          DEFAULT_MINIMUM_STUDENT_AGE,
      );
      const minimumAge = Number.isFinite(configuredAge)
        ? Math.min(30, Math.max(5, Math.trunc(configuredAge)))
        : DEFAULT_MINIMUM_STUDENT_AGE;
      const age = calculateAge(dateOfBirth, now);
      if (age >= minimumAge) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'العمر يسمح باستخدام حساب طالب مستقل',
        );
      }

      transaction.update(userRef, {
        role: 'parent',
        accountType: 'guardian',
        activeStudentProfileId: null,
        dateOfBirth: admin.firestore.Timestamp.fromDate(dateOfBirth),
        roleConvertedAt: FieldValue.serverTimestamp(),
        roleConversionReason: 'underage_student',
        updatedAt: FieldValue.serverTimestamp(),
      });

      return { age, minimumAge };
    });

    functions.logger.info('Underage student account converted to parent', {
      uid,
      age: result.age,
      minimumAge: result.minimumAge,
    });
    return { success: true, ...result };
  },
);
