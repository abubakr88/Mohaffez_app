import * as functions from 'firebase-functions';
import admin, { db, FieldValue } from './utils/admin';
import { isAcceptingNewBookings } from './teacherBookingPolicy';
import {
  ageAtDate,
  allowedLocalDayKeys,
  canRetryTrialRequest,
  intervalIsInsideWindow,
  localDayKey,
  normalizeTrialStudentPreparation,
} from './trialSessionPolicy';

const STATUS = {
  PENDING_TEACHER: 'pending_teacher',
  AWAITING_STUDENT: 'awaiting_student_confirmation',
  CONFIRMED: 'confirmed',
  REJECTED_TEACHER: 'rejected_teacher',
  REJECTED_STUDENT: 'rejected_student',
} as const;

const ACTIVE_SESSION_STATUSES = new Set([
  'pending',
  'accepted',
  'scheduled',
  'in_progress',
  'ongoing',
]);

const ONLINE_PROVIDERS = new Set([
  'zoom',
  'googleMeet',
  'teams',
  'phoneCall',
]);

const PROVIDER_HOSTS: Record<string, string[]> = {
  zoom: ['zoom.us'],
  googleMeet: ['meet.google.com'],
  teams: ['teams.microsoft.com', 'teams.live.com'],
};

interface TimeWindow {
  start: admin.firestore.Timestamp;
  end: admin.firestore.Timestamp;
  dayKey: string;
}

function requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }
  return uid;
}

function optionalString(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function optionalTimestamp(value: unknown): admin.firestore.Timestamp | null {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value;
  if (typeof value !== 'string') return null;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return admin.firestore.Timestamp.fromDate(parsed);
}

function onlineProviderIsAvailable(
  provider: string,
  teacher: FirebaseFirestore.DocumentData,
  student: FirebaseFirestore.DocumentData,
): boolean {
  if (provider === 'phoneCall') {
    return optionalString(teacher.phoneNumber) !== null &&
      optionalString(student.phoneNumber) !== null;
  }

  const rawLinks = teacher.meetingLinks;
  if (
    rawLinks &&
    typeof rawLinks === 'object' &&
    optionalString((rawLinks as Record<string, unknown>)[provider]) !== null
  ) {
    return true;
  }

  const legacyLink = optionalString(teacher.meetingLink)?.toLowerCase();
  return legacyLink !== undefined && legacyLink !== null &&
    (PROVIDER_HOSTS[provider] ?? []).some((host) => legacyLink.includes(host));
}

function isLearnerRole(role: unknown): boolean {
  return role === 'student' || role === 'parent';
}

function requestIdFor(
  mohaffezId: string,
  studentId: string,
  studentProfileId?: string | null,
): string {
  const profileId = (studentProfileId ?? '').trim();
  if (!profileId || profileId === 'self') {
    return `${mohaffezId}_${studentId}`;
  }
  return `${mohaffezId}_${studentId}_${profileId}`;
}

function parseIsoDate(value: unknown, field: string): Date {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${field} is required`,
    );
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${field} is invalid`,
    );
  }
  return date;
}

function timezoneOffsetMinutes(value: unknown): number {
  const offset = Number(value);
  if (!Number.isInteger(offset) || offset < -840 || offset > 840) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'timezoneOffsetMinutes is invalid',
    );
  }
  return offset;
}

function parseRequestedWindows(
  raw: unknown,
  durationMinutes: number,
  offsetMinutes: number,
): TimeWindow[] {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > 3) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Choose availability for one to three days',
    );
  }

  const now = new Date();
  const allowedDays = allowedLocalDayKeys(now, offsetMinutes);

  const seenDays = new Set<string>();
  const windows = raw.map((entry, index) => {
    if (!entry || typeof entry !== 'object') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `availabilityWindows[${index}] is invalid`,
      );
    }

    const record = entry as Record<string, unknown>;
    const start = parseIsoDate(record.start, `availabilityWindows[${index}].start`);
    const end = parseIsoDate(record.end, `availabilityWindows[${index}].end`);
    const dayKey =
      typeof record.dayKey === 'string' ? record.dayKey.trim() : '';

    if (!/^\d{4}-\d{2}-\d{2}$/.test(dayKey)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `availabilityWindows[${index}].dayKey is invalid`,
      );
    }
    if (
      localDayKey(start, offsetMinutes) !== dayKey ||
      localDayKey(end, offsetMinutes) !== dayKey
    ) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Availability does not match the selected local day',
      );
    }
    if (seenDays.has(dayKey)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Only one availability window is allowed per day',
      );
    }
    seenDays.add(dayKey);

    if (!allowedDays.has(dayKey)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Availability must be today, tomorrow, or the day after tomorrow',
      );
    }
    if (start <= now || end <= start) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Availability must be in the future',
      );
    }
    if (end.getTime() - start.getTime() < durationMinutes * 60_000) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Availability window is shorter than the trial duration',
      );
    }

    return {
      start: admin.firestore.Timestamp.fromDate(start),
      end: admin.firestore.Timestamp.fromDate(end),
      dayKey,
    };
  });

  return windows.sort(
    (left, right) => left.start.toMillis() - right.start.toMillis(),
  );
}

function isProposalInsideWindow(
  start: Date,
  end: Date,
  windows: TimeWindow[],
): boolean {
  return windows.some(
    (window) => intervalIsInsideWindow(
      start.getTime(),
      end.getTime(),
      window.start.toMillis(),
      window.end.toMillis(),
    ),
  );
}

function matchingWindow(
  start: Date,
  end: Date,
  windows: TimeWindow[],
): TimeWindow | undefined {
  return windows.find(
    (window) => intervalIsInsideWindow(
      start.getTime(),
      end.getTime(),
      window.start.toMillis(),
      window.end.toMillis(),
    ),
  );
}

function nearbySessionQuery(
  field: 'mohaffezId' | 'studentId',
  userId: string,
  proposedStart: Date,
  proposedEnd: Date,
): FirebaseFirestore.Query {
  const rangeStart = new Date(proposedStart.getTime() - 24 * 60 * 60_000);
  const rangeEnd = new Date(proposedEnd.getTime() + 24 * 60 * 60_000);
  return db
    .collection('hafizSessions')
    .where(field, '==', userId)
    .where('slotStart', '>=', admin.firestore.Timestamp.fromDate(rangeStart))
    .where('slotStart', '<', admin.firestore.Timestamp.fromDate(rangeEnd));
}

function hasActiveConflict(
  docs: FirebaseFirestore.QueryDocumentSnapshot[],
  start: Date,
  end: Date,
): boolean {
  return docs.some((doc) => {
    const session = doc.data();
    return ACTIVE_SESSION_STATUSES.has(session.status) &&
      overlaps(start, end, session);
  });
}

function localTimeText(date: Date, offsetMinutes: number): string {
  return new Date(date.getTime() + offsetMinutes * 60_000)
    .toISOString()
    .substring(11, 16);
}

function overlaps(
  start: Date,
  end: Date,
  data: FirebaseFirestore.DocumentData,
): boolean {
  const existingStart =
    data.slotStart instanceof admin.firestore.Timestamp
      ? data.slotStart.toDate()
      : data.sessionDate instanceof admin.firestore.Timestamp
        ? data.sessionDate.toDate()
        : null;
  const existingEnd =
    data.slotEnd instanceof admin.firestore.Timestamp
      ? data.slotEnd.toDate()
      : null;

  if (!existingStart || !existingEnd) return false;
  return start < existingEnd && end > existingStart;
}

function notificationData(params: {
  recipientId: string;
  senderId: string;
  type: string;
  title: string;
  body: string;
  requestId: string;
}): Record<string, unknown> {
  return {
    userId: params.recipientId,
    recipientId: params.recipientId,
    senderId: params.senderId,
    type: params.type,
    title: params.title,
    body: params.body,
    data: {
      requestId: params.requestId,
      route: '/trial-requests',
    },
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  };
}

export const createTrialSessionRequest = functions.https.onCall(
  async (data, context) => {
    const studentId = requireAuth(context);
    const mohaffezId =
      typeof data?.mohaffezId === 'string' ? data.mohaffezId.trim() : '';
    const sessionType =
      typeof data?.sessionType === 'string' ? data.sessionType.trim() : '';
    const preferredProvider = optionalString(data?.preferredProvider);
    const studentProfileId = optionalString(data?.studentProfileId);
    const studentProfileName = optionalString(data?.studentProfileName);
    const studentProfileGender = optionalString(data?.studentProfileGender);
    const studentProfileBirthDate = optionalTimestamp(
      data?.studentProfileBirthDate,
    );
    const guardianName = optionalString(data?.guardianName);
    const requestedStudentName = optionalString(data?.studentName);
    const studentPreparation = normalizeTrialStudentPreparation(
      data?.studentPreparation,
    );
    const studentAge = studentProfileBirthDate === null
      ? null
      : ageAtDate(studentProfileBirthDate.toDate(), new Date());

    if (!mohaffezId || !['online', 'home', 'mosque'].includes(sessionType)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Teacher and session type are required',
      );
    }
    if (data?.studentPreparation != null && studentPreparation === null) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Student preparation answers are invalid',
      );
    }
    if (
      sessionType === 'online' &&
      preferredProvider !== null &&
      !ONLINE_PROVIDERS.has(preferredProvider)
    ) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Choose an available communication method',
      );
    }
    if (studentId === mohaffezId) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'A teacher cannot request a trial with themselves',
      );
    }

    const requestId = requestIdFor(mohaffezId, studentId, studentProfileId);
    const requestRef = db.collection('trialSessionRequests').doc(requestId);
    const studentRef = db.collection('users').doc(studentId);
    const teacherRef = db.collection('users').doc(mohaffezId);

    return db.runTransaction(async (transaction) => {
      const [requestSnap, studentSnap, teacherSnap] = await Promise.all([
        transaction.get(requestRef),
        transaction.get(studentRef),
        transaction.get(teacherRef),
      ]);

      const previousRequest = requestSnap.data();
      if (requestSnap.exists && !canRetryTrialRequest(previousRequest?.status)) {
        throw new functions.https.HttpsError(
          'already-exists',
          'You have already requested a trial session with this teacher',
        );
      }
      if (!studentSnap.exists || !isLearnerRole(studentSnap.data()?.role)) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Only learner accounts can request trial sessions',
        );
      }
      const teacher = teacherSnap.data();
      if (
        !teacherSnap.exists ||
        teacher?.role !== 'mohaffez' ||
        teacher?.status !== 'active'
      ) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Teacher account is not available',
        );
      }
      if (!isAcceptingNewBookings(teacher)) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'This teacher is not accepting new booking requests',
        );
      }
      if (teacher?.trialSessionEnabled !== true) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'This teacher is not accepting trial-session requests',
        );
      }

      const durationMinutes = Math.min(
        60,
        Math.max(15, Number(teacher.trialSessionDurationMinutes) || 30),
      );
      const offsetMinutes = timezoneOffsetMinutes(data?.timezoneOffsetMinutes);
      const availabilityWindows = parseRequestedWindows(
        data?.availabilityWindows,
        durationMinutes,
        offsetMinutes,
      );
      const student = studentSnap.data() ?? {};
      let resolvedPreferredProvider: string | null = null;
      if (sessionType === 'online') {
        const availableProviders = [...ONLINE_PROVIDERS].filter((provider) =>
          onlineProviderIsAvailable(provider, teacher, student),
        );
        resolvedPreferredProvider =
          preferredProvider ?? availableProviders[0] ?? null;
        if (
          !resolvedPreferredProvider ||
          !availableProviders.includes(resolvedPreferredProvider)
        ) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'The selected communication method is no longer available',
          );
        }
      }
      const displayStudentName =
        studentProfileName ||
        requestedStudentName ||
        optionalString(student.name) ||
        optionalString(student.displayName) ||
        '';

      const previousRejections = Array.isArray(previousRequest?.rejectionHistory)
        ? previousRequest.rejectionHistory.slice(-4)
        : [];
      if (previousRequest?.rejectionReason) {
        previousRejections.push({
          reason: previousRequest.rejectionReason,
          rejectedAt: previousRequest.rejectedAt ?? null,
        });
      }

      transaction.set(requestRef, {
        studentId,
        studentName: displayStudentName,
        guardianId: studentId,
        guardianName: guardianName ?? optionalString(student.name),
        studentProfileId: studentProfileId ?? null,
        studentProfileName: studentProfileName ?? displayStudentName,
        studentProfileGender: studentProfileGender ?? null,
        studentProfileBirthDate: studentProfileBirthDate ?? null,
        studentAge,
        studentPreparation: studentPreparation ?? null,
        mohaffezId,
        mohaffezName: teacher.name ?? teacher.displayName ?? '',
        sessionType,
        preferredProvider: resolvedPreferredProvider,
        durationMinutes,
        timezoneOffsetMinutes: offsetMinutes,
        availabilityWindows,
        status: STATUS.PENDING_TEACHER,
        isTrial: true,
        isPaid: false,
        attemptCount: Math.max(1, Number(previousRequest?.attemptCount) + 1 || 1),
        rejectionHistory: previousRejections,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      const notificationRef = db.collection('notifications').doc();
      transaction.set(notificationRef, notificationData({
        recipientId: mohaffezId,
        senderId: studentId,
        type: 'trial_session_requested',
        title: 'طلب حلقة تجريبية جديد',
        body: `${displayStudentName || 'طالب'} أرسل أوقاتًا مقترحة لحلقة تجريبية.`,
        requestId,
      }));

      return { success: true, requestId };
    });
  },
);

export const proposeTrialSessionTime = functions.https.onCall(
  async (data, context) => {
    const mohaffezId = requireAuth(context);
    const requestId =
      typeof data?.requestId === 'string' ? data.requestId.trim() : '';
    const proposedStart = parseIsoDate(data?.proposedStart, 'proposedStart');
    if (!requestId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'requestId is required',
      );
    }
    const requestRef = db.collection('trialSessionRequests').doc(requestId);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Request not found');
    }

    const request = requestSnap.data()!;
    if (request.mohaffezId !== mohaffezId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'This request does not belong to the teacher',
      );
    }
    if (request.status !== STATUS.PENDING_TEACHER) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'This request is no longer awaiting a proposal',
      );
    }

    const durationMinutes = Number(request.durationMinutes) || 30;
    const proposedEnd = new Date(
      proposedStart.getTime() + durationMinutes * 60_000,
    );
    const windows = (request.availabilityWindows ?? []) as TimeWindow[];
    if (
      proposedStart <= new Date() ||
      !isProposalInsideWindow(proposedStart, proposedEnd, windows)
    ) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Proposed time must be inside the student availability',
      );
    }

    const sessions = await nearbySessionQuery(
      'mohaffezId',
      mohaffezId,
      proposedStart,
      proposedEnd,
    ).get();
    const hasConflict = hasActiveConflict(
      sessions.docs,
      proposedStart,
      proposedEnd,
    );
    if (hasConflict) {
      throw new functions.https.HttpsError(
        'already-exists',
        'The proposed time conflicts with another session',
      );
    }

    await db.runTransaction(async (transaction) => {
      const latest = await transaction.get(requestRef);
      if (
        !latest.exists ||
        latest.data()?.status !== STATUS.PENDING_TEACHER
      ) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Request status changed',
        );
      }

      transaction.update(requestRef, {
        status: STATUS.AWAITING_STUDENT,
        proposedStart: admin.firestore.Timestamp.fromDate(proposedStart),
        proposedEnd: admin.firestore.Timestamp.fromDate(proposedEnd),
        proposedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        db.collection('notifications').doc(),
        notificationData({
          recipientId: request.studentId,
          senderId: mohaffezId,
          type: 'trial_session_proposed',
          title: 'موعد مقترح للحلقة التجريبية',
          body: `${request.mohaffezName ?? 'المحفظ'} اقترح موعدًا لحلقتك التجريبية.`,
          requestId,
        }),
      );
    });

    return { success: true };
  },
);

export const confirmTrialSessionTime = functions.https.onCall(
  async (data, context) => {
    const studentId = requireAuth(context);
    const requestId =
      typeof data?.requestId === 'string' ? data.requestId.trim() : '';
    if (!requestId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'requestId is required',
      );
    }

    const requestRef = db.collection('trialSessionRequests').doc(requestId);
    return db.runTransaction(async (transaction) => {
      const requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Request not found');
      }

      const request = requestSnap.data()!;
      if (request.studentId !== studentId) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'This request does not belong to the student',
        );
      }
      if (request.status !== STATUS.AWAITING_STUDENT) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'There is no proposal awaiting confirmation',
        );
      }

      const proposedStart =
        (request.proposedStart as admin.firestore.Timestamp).toDate();
      const proposedEnd =
        (request.proposedEnd as admin.firestore.Timestamp).toDate();
      if (proposedStart <= new Date()) {
        throw new functions.https.HttpsError(
          'deadline-exceeded',
          'The proposed time has passed',
        );
      }

      const [teacherSessions, studentSessions] = await Promise.all([
        transaction.get(nearbySessionQuery(
          'mohaffezId',
          request.mohaffezId,
          proposedStart,
          proposedEnd,
        )),
        transaction.get(nearbySessionQuery(
          'studentId',
          studentId,
          proposedStart,
          proposedEnd,
        )),
      ]);
      const hasConflict =
        hasActiveConflict(teacherSessions.docs, proposedStart, proposedEnd) ||
        hasActiveConflict(studentSessions.docs, proposedStart, proposedEnd);
      if (hasConflict) {
        throw new functions.https.HttpsError(
          'already-exists',
          'The proposed time is no longer available',
        );
      }

      const sessionRef = db.collection('hafizSessions').doc();
      const windows = (request.availabilityWindows ?? []) as TimeWindow[];
      const selectedWindow = matchingWindow(
        proposedStart,
        proposedEnd,
        windows,
      );
      if (!selectedWindow) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'The proposal no longer matches the student availability',
        );
      }
      const offsetMinutes = Number(request.timezoneOffsetMinutes) || 0;
      const sessionDay = new Date(
        Date.parse(`${selectedWindow.dayKey}T00:00:00.000Z`) -
          offsetMinutes * 60_000,
      );
      const timeSlot =
        `${localTimeText(proposedStart, offsetMinutes)} - ` +
        `${localTimeText(proposedEnd, offsetMinutes)}`;

      transaction.set(sessionRef, {
        requestId,
        trialRequestId: requestId,
        mohaffezId: request.mohaffezId,
        studentId,
        mohaffezName: request.mohaffezName ?? '',
        studentName: request.studentName ?? '',
        guardianId: request.guardianId ?? studentId,
        guardianName: request.guardianName ?? null,
        studentProfileId: request.studentProfileId ?? null,
        studentProfileName: request.studentProfileName ?? request.studentName ?? '',
        studentProfileGender: request.studentProfileGender ?? null,
        studentProfileBirthDate: request.studentProfileBirthDate ?? null,
        sessionType: request.sessionType,
        preferredProvider:
          request.sessionType === 'online'
            ? request.preferredProvider ?? null
            : null,
        preferredTimeSlot: timeSlot,
        timeSlot,
        sessionDate: admin.firestore.Timestamp.fromDate(sessionDay),
        slotDate: admin.firestore.Timestamp.fromDate(sessionDay),
        slotStart: admin.firestore.Timestamp.fromDate(proposedStart),
        slotEnd: admin.firestore.Timestamp.fromDate(proposedEnd),
        status: 'accepted',
        bookingKind: 'trial',
        paymentType: 'trial',
        isTrial: true,
        trialDurationMinutes: request.durationMinutes,
        isPaid: false,
        sessionPrice: 0,
        paymentId: null,
        subscriptionId: null,
        createdAt: FieldValue.serverTimestamp(),
        acceptedAt: FieldValue.serverTimestamp(),
        reminder24hSent: false,
        reminder1hSent: false,
        juzCount: 1,
        sessionRating: 10,
      });
      transaction.update(requestRef, {
        status: STATUS.CONFIRMED,
        sessionId: sessionRef.id,
        confirmedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        db.collection('notifications').doc(),
        notificationData({
          recipientId: request.mohaffezId,
          senderId: studentId,
          type: 'trial_session_confirmed',
          title: 'تم تأكيد الحلقة التجريبية',
          body: `${request.studentName ?? 'الطالب'} أكد الموعد المقترح.`,
          requestId,
        }),
      );

      return { success: true, sessionId: sessionRef.id };
    });
  },
);

export const rejectTrialSessionRequest = functions.https.onCall(
  async (data, context) => {
    const uid = requireAuth(context);
    const requestId =
      typeof data?.requestId === 'string' ? data.requestId.trim() : '';
    const reason =
      typeof data?.reason === 'string' ? data.reason.trim().slice(0, 300) : '';
    if (!requestId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'requestId is required',
      );
    }
    if (!reason) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Rejection reason is required',
      );
    }

    const requestRef = db.collection('trialSessionRequests').doc(requestId);
    await db.runTransaction(async (transaction) => {
      const requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Request not found');
      }
      const request = requestSnap.data()!;
      const isTeacher = request.mohaffezId === uid;
      const isStudent = request.studentId === uid;
      if (!isTeacher && !isStudent) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'You cannot update this request',
        );
      }
      if (
        (isTeacher && request.status !== STATUS.PENDING_TEACHER) ||
        (isStudent && request.status !== STATUS.AWAITING_STUDENT)
      ) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Request cannot be rejected in its current state',
        );
      }

      const recipientId = isTeacher ? request.studentId : request.mohaffezId;
      transaction.update(requestRef, {
        status: isTeacher
          ? STATUS.REJECTED_TEACHER
          : STATUS.REJECTED_STUDENT,
        rejectionReason: reason || null,
        rejectedBy: isTeacher ? 'teacher' : 'student',
        retryAllowed: isTeacher,
        trialConsumed: false,
        rejectedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        db.collection('notifications').doc(),
        notificationData({
          recipientId,
          senderId: uid,
          type: 'trial_session_rejected',
          title: 'تعذر إكمال الحلقة التجريبية',
          body: isTeacher
            ? `تعذر الموعد المطلوب. اقتراح المحفظ: ${reason}. يمكنك طلب موعد آخر.`
            : reason,
          requestId,
        }),
      );
    });

    return { success: true };
  },
);
