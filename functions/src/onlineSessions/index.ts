import * as functions from 'firebase-functions';
import admin, { db, FieldValue } from '../utils/admin';
import { createAndSendNotification } from '../utils/notificationHelpers';

type SessionDoc = Record<string, unknown>;

function detectProvider(url: string): string {
  if (url.includes('zoom.us')) return 'zoom';
  if (url.includes('meet.google.com')) return 'google-meet';
  if (url.includes('teams.microsoft.com') || url.includes('teams.live.com')) return 'teams';
  return 'custom';
}

const asString = (v: unknown, fallback = ''): string =>
  typeof v === 'string' && v.trim().length > 0 ? v : fallback;

/**
 * Firestore trigger: when a hafizSession is in 'accepted' status with sessionType == 'online'
 * and has no meeting yet, copy the teacher's personal meetingLink (Zoom / Meet / Teams)
 * into the session's meeting{} map. If the teacher hasn't set a meetingLink, notify them.
 * Handles both creation (status created as 'accepted', e.g. from payment flows) and
 * pending → accepted updates. Idempotent: skipped if meeting is already present.
 */
export const onSessionAcceptedCreateMeeting = functions.firestore
  .document('hafizSessions/{sessionId}')
  .onWrite(async (change, context) => {
    if (!change.after.exists) return;
    const after = change.after.data() as SessionDoc;

    if (asString(after.status) !== 'accepted') return;
    if (asString(after.sessionType) !== 'online') return;
    if (after.meeting != null) return;

    const sessionId = context.params.sessionId;
    const studentId = asString(after.studentId);
    const mohaffezId = asString(after.mohaffezId);
    const mohaffezName = asString(after.mohaffezName, 'المحفظ');

    // Prefer `slotStart` (full datetime) over `sessionDate` (day-only at
    // midnight). Using `sessionDate` collapses every session on the same day
    // to the same `joinWindowOpensAt`, so all sessions on that day show an
    // identical countdown.
    const sessionDateRaw = after.slotStart ?? after.sessionDate;
    if (!sessionDateRaw) {
      functions.logger.warn('onSessionAcceptedCreateMeeting: no slotStart/sessionDate', { sessionId });
      return;
    }

    const sessionDateMs =
      sessionDateRaw instanceof admin.firestore.Timestamp
        ? sessionDateRaw.toMillis()
        : typeof sessionDateRaw === 'number'
        ? sessionDateRaw
        : Date.now();

    const joinWindowOpensAt = admin.firestore.Timestamp.fromMillis(
      sessionDateMs - 10 * 60 * 1000
    );
    const joinWindowClosesAt = admin.firestore.Timestamp.fromMillis(
      sessionDateMs + 30 * 60 * 1000
    );

    const preferredProvider = asString(after.preferredProvider);

    if (preferredProvider === 'phoneCall') {
      try {
        await change.after.ref.update({
          meeting: {
            provider: 'phoneCall',
            roomId: 'phoneCall',
            url: '',
            createdAt: FieldValue.serverTimestamp(),
            startedAt: null,
            endedAt: null,
            participants: {
              studentJoinedAt: null,
              teacherJoinedAt: null,
            },
            joinWindowOpensAt,
            joinWindowClosesAt,
          },
          meetingReminderSent: false,
          updatedAt: FieldValue.serverTimestamp(),
        });

        if (studentId) {
          await createAndSendNotification({
            userId: studentId,
            senderId: mohaffezId,
            title: 'تم تأكيد جلستك أونلاين ✅',
            body: `${mohaffezName} قبل جلستك. ستكون الجلسة عبر مكالمة هاتفية في موعدها.`,
            type: 'online_session_accepted',
            isRead: false,
            highPriority: true,
            data: {
              type: 'online_session_accepted',
              sessionId,
              provider: 'phoneCall',
            },
          });
        }
      } catch (error) {
        functions.logger.error('Failed to create phone-call meeting', { sessionId, error });
      }
      return;
    }

    let teacherLink = '';
    let resolvedProvider = '';
    if (mohaffezId) {
      try {
        const teacherSnap = await db.collection('users').doc(mohaffezId).get();
        const data = teacherSnap.data() ?? {};
        const links = (data.meetingLinks ?? {}) as Record<string, unknown>;

        // 1. Prefer the provider the student picked at booking time.
        if (preferredProvider) {
          teacherLink = asString(links[preferredProvider]);
          if (teacherLink) resolvedProvider = preferredProvider;
        }

        // 2. Fallback to any non-empty entry in the map.
        if (!teacherLink) {
          for (const [key, value] of Object.entries(links)) {
            const v = asString(value);
            if (v) {
              teacherLink = v;
              resolvedProvider = key;
              break;
            }
          }
        }

        // 3. Legacy fallback to the single meetingLink field.
        if (!teacherLink) {
          teacherLink = asString(data.meetingLink);
          if (teacherLink) resolvedProvider = detectProvider(teacherLink);
        }
      } catch (err) {
        functions.logger.error('Failed to read teacher meetingLinks', { mohaffezId, err });
      }
    }

    if (!teacherLink) {
      functions.logger.warn('Teacher has no meetingLink — notifying teacher to set one', {
        sessionId, mohaffezId,
      });
      if (mohaffezId) {
        await createAndSendNotification({
          userId: mohaffezId,
          senderId: mohaffezId,
          title: '⚠️ أضف رابط الاجتماع أونلاين',
          body: 'لديك جلسة مقبولة أونلاين بدون رابط. افتح ملفك الشخصي وأضف رابط Zoom أو Google Meet لتتمكن من بدء الجلسة.',
          type: 'online_meeting_link_missing',
          isRead: false,
          highPriority: true,
          data: { type: 'online_meeting_link_missing', sessionId },
        });
      }
      return;
    }

    const provider = resolvedProvider || detectProvider(teacherLink);
    const url = teacherLink;
    const roomId = teacherLink;

    try {
      await change.after.ref.update({
        meeting: {
          provider,
          roomId,
          url,
          createdAt: FieldValue.serverTimestamp(),
          startedAt: null,
          endedAt: null,
          participants: {
            studentJoinedAt: null,
            teacherJoinedAt: null,
          },
          joinWindowOpensAt,
          joinWindowClosesAt,
        },
        meetingReminderSent: false,
        updatedAt: FieldValue.serverTimestamp(),
      });

      functions.logger.info('Online meeting created', { sessionId, roomId });

      if (studentId) {
        await createAndSendNotification({
          userId: studentId,
          senderId: mohaffezId,
          title: 'تم تأكيد جلستك أونلاين ✅',
          body: `${mohaffezName} قبل جلستك. افتح تفاصيل الجلسة لبدء الاجتماع.`,
          type: 'online_session_accepted',
          isRead: false,
          highPriority: true,
          data: {
            type: 'online_session_accepted',
            sessionId,
            meetingUrl: url,
          },
        });
      }
    } catch (error) {
      functions.logger.error('Failed to create online meeting', { sessionId, error });
    }
  });

/**
 * Firestore trigger: when the teacher writes meetingStartedAt on a session,
 * push a high-priority FCM to the student so they see the join banner even
 * if the app is backgrounded.
 */
export const onMeetingStarted = functions.firestore
  .document('hafizSessions/{sessionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as SessionDoc;
    const after = change.after.data() as SessionDoc;

    if (before.meetingStartedAt != null) return;
    if (after.meetingStartedAt == null) return;
    if (asString(after.sessionType) !== 'online') return;

    const sessionId = context.params.sessionId;
    const studentId = asString(after.studentId);
    const mohaffezId = asString(after.mohaffezId);
    const mohaffezName = asString(after.mohaffezName, 'المحفظ');
    const meeting = after.meeting as Record<string, unknown> | null | undefined;
    const meetingUrl = asString(meeting?.url);

    if (!studentId) return;

    try {
      await createAndSendNotification({
        userId: studentId,
        senderId: mohaffezId,
        title: '🎥 بدأ المحفظ الجلسة الآن',
        body: `${mohaffezName} ينتظرك — افتح التطبيق وانضم إلى الجلسة`,
        type: 'online_session_started',
        isRead: false,
        highPriority: true,
        data: {
          type: 'online_session_started',
          sessionId,
          meetingUrl,
        },
      });
    } catch (error) {
      functions.logger.error('Failed to send online_session_started notification', {
        sessionId,
        error,
      });
    }
  });

/**
 * Scheduled: every 5 minutes. For online sessions whose join window opens within the
 * next 5 minutes and whose reminder has not been sent, send FCM to both parties.
 * Uses meetingReminderSent root flag (set to false on creation) for atomic dedup.
 */
export const sendOnlineSessionReminder = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async () => {
    const nowMs = Date.now();
    const windowLower = admin.firestore.Timestamp.fromDate(new Date(nowMs));
    const windowUpper = admin.firestore.Timestamp.fromDate(
      new Date(nowMs + 5 * 60 * 1000)
    );

    const snapshot = await db
      .collection('hafizSessions')
      .where('status', '==', 'accepted')
      .where('sessionType', '==', 'online')
      .where('meetingReminderSent', '==', false)
      .get();

    let sent = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data() as SessionDoc;
      const meeting = data.meeting as Record<string, unknown> | null | undefined;
      if (!meeting) continue;

      const opensAt = meeting.joinWindowOpensAt;
      if (!(opensAt instanceof admin.firestore.Timestamp)) continue;
      if (opensAt.toMillis() < windowLower.toMillis()) continue;
      if (opensAt.toMillis() > windowUpper.toMillis()) continue;

      const studentId = asString(data.studentId);
      const mohaffezId = asString(data.mohaffezId);
      const mohaffezName = asString(data.mohaffezName, 'المحفظ');
      const studentName = asString(data.studentName, 'الطالب');
      const meetingUrl = asString((meeting as Record<string, unknown>).url);
      const sessionId = doc.id;

      if (!studentId || !mohaffezId) continue;

      let shouldSend = false;
      try {
        await db.runTransaction(async (transaction) => {
          const fresh = await transaction.get(doc.ref);
          if (!fresh.exists) return;
          if (fresh.data()?.meetingReminderSent === true) return;
          transaction.update(doc.ref, {
            meetingReminderSent: true,
            meetingReminderSentAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
          shouldSend = true;
        });
      } catch (err) {
        functions.logger.error('Failed to claim meetingReminderSent flag', {
          sessionId,
          error: err,
        });
        continue;
      }

      if (!shouldSend) continue;

      try {
        await createAndSendNotification({
          userId: studentId,
          senderId: mohaffezId,
          title: '🎥 ستبدأ جلستك خلال 10 دقائق',
          body: `استعد للانضمام مع ${mohaffezName}`,
          type: 'online_session_reminder',
          isRead: false,
          highPriority: true,
          data: { type: 'online_session_reminder', sessionId, meetingUrl },
        });

        await createAndSendNotification({
          userId: mohaffezId,
          senderId: studentId,
          title: '🎥 ستبدأ جلستك خلال 10 دقائق',
          body: `الطالب ${studentName} ينتظر`,
          type: 'online_session_reminder',
          isRead: false,
          highPriority: true,
          data: { type: 'online_session_reminder', sessionId, meetingUrl },
        });

        sent++;
      } catch (err) {
        functions.logger.error('Failed to send online session reminder', {
          sessionId,
          error: err,
        });
      }
    }

    functions.logger.info('Online session reminders completed', { checked: snapshot.size, sent });
    return null;
  });

/**
 * Scheduled: every 10 minutes. Finds sessions whose `meetingStartedAt` is older
 * than the configured `sessionMaxDurationMinutes` (default 90) and that are still
 * not marked `completed`, then auto-completes them.
 *
 * Why: prevents a session from hanging in an open state forever if the teacher
 * forgets to tap "End Session". The session is treated like any other completed
 * session — it counts toward the teacher's commission tier and pays out normally.
 * Distinguished from manual completion by the `autoCompleted: true` flag, so the
 * UI can show "تم إنهاؤها تلقائياً" and any rating-required code paths can skip
 * since no rating was captured.
 */
const DEFAULT_SESSION_MAX_DURATION_MIN = 90;
const AUTO_END_BATCH_SIZE = 100;

async function loadSessionMaxDurationMinutes(): Promise<number> {
  try {
    const snap = await db.collection('systemConfig').doc('global').get();
    const raw = snap.data()?.sessionMaxDurationMinutes;
    const parsed = typeof raw === 'number' ? raw : Number(raw);
    if (Number.isFinite(parsed) && parsed > 0) return parsed;
  } catch (err) {
    functions.logger.warn('autoEndOverdueSessions: failed to read config, using default', { err });
  }
  return DEFAULT_SESSION_MAX_DURATION_MIN;
}

export const autoEndOverdueSessions = functions
  .region('us-central1')
  .pubsub.schedule('every 10 minutes')
  .onRun(async () => {
    const maxMinutes = await loadSessionMaxDurationMinutes();
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - maxMinutes * 60 * 1000,
    );

    // We can't combine `status != completed` with `meetingStartedAt <= cutoff`
    // in a single Firestore query (composite inequality not supported), so we
    // query by `meetingStartedAt` and filter status in-memory. Sessions older
    // than the cutoff that are already completed are simply skipped.
    //
    // We deliberately do NOT filter `meetingEndedAt == null` in the query:
    // Firestore's `== null` only matches docs where the field exists AND is
    // null. The teacher-start flow never initializes `meetingEndedAt`, so
    // every in-progress session is missing the field and would be excluded.
    // Filter in-memory below instead.
    const snap = await db
      .collection('hafizSessions')
      .where('meetingStartedAt', '<=', cutoff)
      .orderBy('meetingStartedAt', 'asc')
      .limit(AUTO_END_BATCH_SIZE)
      .get();

    let endedCount = 0;
    for (const doc of snap.docs) {
      const data = doc.data() as SessionDoc;
      if (data.meetingEndedAt) continue;
      const status = asString(data.status);
      if (status === 'completed' || status === 'cancelled' || status === 'rejected') {
        continue;
      }
      try {
        await doc.ref.update({
          status: 'completed',
          completedAt: FieldValue.serverTimestamp(),
          meetingEndedAt: FieldValue.serverTimestamp(),
          autoCompleted: true,
          autoCompletedReason: 'max_duration_exceeded',
          autoCompletedMaxMinutes: maxMinutes,
          updatedAt: FieldValue.serverTimestamp(),
        });
        endedCount++;

        const mohaffezId = asString(data.mohaffezId);
        if (mohaffezId) {
          await createAndSendNotification({
            userId: mohaffezId,
            senderId: mohaffezId,
            title: 'تم إنهاء الحلقة تلقائياً',
            body: `تجاوزت الحلقة الحد الأقصى (${maxMinutes} دقيقة) فتم تسجيلها كمكتملة. تذكّر الضغط على "إنهاء الحلقة" في المرة القادمة.`,
            type: 'session_auto_ended',
            isRead: false,
            highPriority: false,
            data: { type: 'session_auto_ended', sessionId: doc.id },
          });
        }
      } catch (err) {
        functions.logger.error('autoEndOverdueSessions: failed to end session', {
          sessionId: doc.id,
          err,
        });
      }
    }

    functions.logger.info('autoEndOverdueSessions complete', {
      maxMinutes,
      scanned: snap.size,
      ended: endedCount,
    });

    // ── Online teacher no-show detection ──────────────────────────────────
    // If an online session's slotStart was > 60 minutes ago and the teacher
    // never joined, flag it as teacher no-show. Triggers onSessionCancelled
    // which issues full refund + 1.5% penalty.
    //
    // We can't filter `meetingTeacherJoinedAt == null` in the query because
    // session creation doesn't initialize the field — Firestore's `== null`
    // only matches docs where the field exists AND is null, not docs missing
    // the field entirely. So we filter in-code below.
    //
    // Wrapped in try/catch so a query failure (e.g. missing index) doesn't
    // silently kill the whole scheduled run — auto-end-overdue above it
    // must still complete + be observable in logs.
    try {
      const noShowCutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 60 * 60 * 1000);
      const noShowSnap = await db
        .collection('hafizSessions')
        .where('sessionType', '==', 'online')
        .where('status', '==', 'accepted')
        .where('slotStart', '<=', noShowCutoff)
        .limit(AUTO_END_BATCH_SIZE)
        .get();

      let noShowCount = 0;
      for (const doc of noShowSnap.docs) {
        const d = doc.data() as SessionDoc;
        if (d.teacherNoShow === true || d.studentNoShow === true) continue;
        if (d.meetingTeacherJoinedAt) continue; // teacher actually joined
        try {
          await doc.ref.update({
            teacherNoShow: true,
            status: 'cancelled',
            cancelledBy: 'teacher',
            cancelledAt: FieldValue.serverTimestamp(),
            autoNoShow: true,
            updatedAt: FieldValue.serverTimestamp(),
          });
          noShowCount++;
        } catch (err) {
          functions.logger.error('autoEndOverdueSessions: failed to flag teacher no-show', {
            sessionId: doc.id, err,
          });
        }
      }

      functions.logger.info('autoEndOverdueSessions: no-show scan complete', {
        scanned: noShowSnap.size, noShowCount,
      });
    } catch (err) {
      functions.logger.error('autoEndOverdueSessions: no-show query failed', { err });
    }

    return null;
  });
