import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db, FieldValue } from "../utils/admin";

const COMMISSION_RATE = 0.05;
const STATUS = {
  PENDING: 'pending',
  AWAITING_PAYMENT: 'awaitingpayment',
  AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
  ACCEPTED: 'accepted',
  REJECTED: 'rejected',
  CANCELLED: 'cancelled',
} as const;

// ─── Helpers ──────────────────────────────────────────────────────────────────
function getWeekNumber(date: Date): number {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil((((d.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
}
function getWeekStart(date: Date): Date {
  const d = new Date(date);
  const day = d.getDay();
  d.setDate(d.getDate() - day + (day === 0 ? -6 : 1));
  d.setHours(0, 0, 0, 0);
  return d;
}
function getWeekEnd(date: Date): Date {
  const ws = getWeekStart(date);
  ws.setDate(ws.getDate() + 6);
  ws.setHours(23, 59, 59, 999);
  return ws;
}
function getNextMonday(date: Date): Date {
  const d = new Date(date);
  d.setDate(d.getDate() + 1);
  d.setHours(12, 0, 0, 0);
  return d;
}

// ─── 1. Student marks that they've paid ───────────────────────────────────────
export const studentMarkedDirectPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth)
      throw new functions.https.HttpsError("unauthenticated", "غير مصادق عليه");

    const studentId = context.auth.uid;
    const {
      requestId, mohaffezId, mohaffezName, studentName,
      amount, sessionType, preferredTimeSlot,
      slotDate, slotStart, slotEnd,
      paymentMethod, studentNote,
      imamAddressText, imamAddressLat, imamAddressLng, mohaffezPhone,
    } = data;

    if (!requestId || !mohaffezId || !amount || !paymentMethod)
      throw new functions.https.HttpsError("invalid-argument", "بيانات غير مكتملة");

    return db.runTransaction(async (tx) => {
      const reqRef = db.collection("sessionRequests").doc(requestId);
      const reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists)
        throw new functions.https.HttpsError("not-found", "الطلب غير موجود");

      const reqData = reqSnap.data()!;

      if (reqData.status === STATUS.ACCEPTED)
        throw new functions.https.HttpsError("already-exists",
          JSON.stringify({ success: true, message: "الجلسة مقبولة بالفعل" }));

      if (reqData.status === STATUS.AWAITING_DIRECT)
        throw new functions.https.HttpsError("already-exists",
          JSON.stringify({ success: true, message: "تم إرسال إشعار الدفع بالفعل، انتظر تأكيد المحفظ" }));

      const dpRef = db.collection("directPaymentRequests").doc();
      tx.set(dpRef, {
        id: dpRef.id,
        sessionRequestId: requestId,
        studentId, studentName, mohaffezId, mohaffezName,
        amount,
        commissionAmount: amount * COMMISSION_RATE,
        commissionRate: COMMISSION_RATE,
        sessionType, preferredTimeSlot,
        sessionDate: admin.firestore.Timestamp.fromDate(new Date(slotDate)),
        slotStart: admin.firestore.Timestamp.fromDate(new Date(slotStart)),
        slotEnd: admin.firestore.Timestamp.fromDate(new Date(slotEnd)),
        imamAddressText: imamAddressText || null,
        imamAddressLat: imamAddressLat || null,
        imamAddressLng: imamAddressLng || null,
        mohaffezPhone: mohaffezPhone || null,
        paymentMethod,
        studentNote: studentNote || null,
        status: "pending_confirmation",
        studentConfirmedAt: FieldValue.serverTimestamp(),
        mohaffezConfirmedAt: null,
        sessionId: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      tx.update(reqRef, {
        status: STATUS.AWAITING_DIRECT,
        directPaymentRequestId: dpRef.id,
        directPaymentMethod: paymentMethod,
        directPaymentAmount: amount,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Notify mohaffez
      const notifRef = db.collection("notifications").doc();
      tx.set(notifRef, {
        userId: mohaffezId, recipientId: mohaffezId, senderId: studentId,
        title: "💰 طالب يدعي دفع الرسوم",
        body: `${studentName} يقول أنه أرسل ${amount} ج.م عبر ${paymentMethod}`,
        type: "direct_payment_pending",
        isRead: false,
        data: {
          directPaymentRequestId: dpRef.id,
          sessionRequestId: requestId,
          studentId, studentName,
          amount: amount.toString(), paymentMethod,
        },
        createdAt: FieldValue.serverTimestamp(),
      });

      return { success: true, directPaymentRequestId: dpRef.id,
        message: "تم إرسال إشعار الدفع للمحفظ. انتظر التأكيد." };

    }).catch((e) => {
      if (e.code === "already-exists") return JSON.parse(e.message);
      throw e;
    });
  }
);

// ─── 2. Mohaffez confirms payment received → session auto-accepted ─────────────
export const mohaffezConfirmDirectPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth)
      throw new functions.https.HttpsError("unauthenticated", "غير مصادق عليه");

    const mohaffezId = context.auth.uid;
    const { directPaymentRequestId } = data;
    if (!directPaymentRequestId)
      throw new functions.https.HttpsError("invalid-argument", "معرف الطلب مطلوب");

    return db.runTransaction(async (tx) => {
      const dpRef = db.collection("directPaymentRequests").doc(directPaymentRequestId);
      const dpSnap = await tx.get(dpRef);
      if (!dpSnap.exists) throw new functions.https.HttpsError("not-found", "طلب الدفع غير موجود");

      const dp = dpSnap.data()!;
      if (dp.mohaffezId !== mohaffezId)
        throw new functions.https.HttpsError("permission-denied", "غير مصرح لك");

      if (dp.status === "confirmed")
        throw new functions.https.HttpsError("already-exists",
          JSON.stringify({ success: true, sessionId: dp.sessionId, message: "تم التأكيد مسبقاً" }));

      const reqRef = db.collection("sessionRequests").doc(dp.sessionRequestId);
      const reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw new functions.https.HttpsError("not-found", "الطلب غير موجود");

      const sessionRef = db.collection("hafizSessions").doc();

      // Create hafiz session
      tx.set(sessionRef, {
        requestId: dp.sessionRequestId, directPaymentRequestId,
        mohaffezId, studentId: dp.studentId,
        mohaffezName: dp.mohaffezName, studentName: dp.studentName,
        sessionType: dp.sessionType,
        location: dp.imamAddressText || "",
        mohaffezPhone: dp.mohaffezPhone || null,
        imamAddressLat: dp.imamAddressLat || null,
        imamAddressLng: dp.imamAddressLng || null,
        imamAddressText: dp.imamAddressText || null,
        preferredTimeSlot: dp.preferredTimeSlot,
        timeSlot: dp.preferredTimeSlot,
        sessionDate: dp.sessionDate,
        slotStart: dp.slotStart,
        slotEnd: dp.slotEnd,
        status: STATUS.ACCEPTED,
        isPaid: true,
        sessionPrice: dp.amount,
        paymentMethod: dp.paymentMethod,
        createdAt: FieldValue.serverTimestamp(),
        acceptedAt: FieldValue.serverTimestamp(),
        reminder24hSent: false, reminder1hSent: false,
        juzCount: 1, sessionRating: 10,
      });

      // Update request
      tx.update(reqRef, {
        status: STATUS.ACCEPTED, isPaid: true,
        paidAt: FieldValue.serverTimestamp(),
        sessionId: sessionRef.id,
        directPaymentConfirmedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Update direct payment record
      tx.update(dpRef, {
        status: "confirmed", sessionId: sessionRef.id,
        mohaffezConfirmedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Track commission
      const now = new Date();
      const weekNumber = getWeekNumber(now);
      const weekStart = getWeekStart(now);
      const weekEnd = getWeekEnd(now);

      const commRef = db.collection("commissions").doc();
      tx.set(commRef, {
        id: commRef.id, mohaffezId, mohaffezName: dp.mohaffezName,
        studentId: dp.studentId, sessionId: sessionRef.id,
        directPaymentRequestId, sessionRequestId: dp.sessionRequestId,
        amount: dp.amount, commissionAmount: dp.commissionAmount,
        commissionRate: COMMISSION_RATE, paymentMethod: dp.paymentMethod,
        status: STATUS.PENDING, weekNumber, year: now.getFullYear(),
        weekStart: admin.firestore.Timestamp.fromDate(weekStart),
        weekEnd: admin.firestore.Timestamp.fromDate(weekEnd),
        createdAt: FieldValue.serverTimestamp(), paidAt: null,
      });

      // Upsert weekly summary
      const summaryId = `${mohaffezId}_${now.getFullYear()}_w${weekNumber}`;
      const summaryRef = db.collection("weeklyCommissionSummaries").doc(summaryId);
      tx.set(summaryRef, {
        mohaffezId, mohaffezName: dp.mohaffezName,
        weekNumber, year: now.getFullYear(),
        weekStart: admin.firestore.Timestamp.fromDate(weekStart),
        weekEnd: admin.firestore.Timestamp.fromDate(weekEnd),
        totalSessions: FieldValue.increment(1),
        totalRevenue: FieldValue.increment(dp.amount),
        commissionAmount: FieldValue.increment(dp.commissionAmount),
        commissionRate: COMMISSION_RATE, status: STATUS.PENDING,
        dueDate: admin.firestore.Timestamp.fromDate(getNextMonday(weekEnd)),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      // Notify student
      const notifRef = db.collection("notifications").doc();
      tx.set(notifRef, {
        userId: dp.studentId, recipientId: dp.studentId, senderId: mohaffezId,
        title: "✅ تم تأكيد الدفع!",
        body: `${dp.mohaffezName} أكد استلام دفعتك. تم قبول الجلسة!`,
        type: "direct_payment_confirmed", isRead: false,
        data: { sessionId: sessionRef.id, sessionRequestId: dp.sessionRequestId,
          directPaymentRequestId },
        createdAt: FieldValue.serverTimestamp(),
      });

      return { success: true, sessionId: sessionRef.id,
        message: "تم تأكيد الدفع وقبول الجلسة!" };

    }).catch((e) => {
      if (e.code === "already-exists") return JSON.parse(e.message);
      functions.logger.error("mohaffezConfirmDirectPayment failed", { e });
      throw e;
    });
  }
);

// ─── 3. Mohaffez rejects payment (student didn't pay) ─────────────────────────
// ✅ FIX: Changed from db.batch() to db.runTransaction() so the status
//    re-check at dp.status happens on a consistent snapshot, preventing
//    a race condition where confirm and reject execute simultaneously.
export const mohaffezRejectDirectPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }
    const mohaffezId = context.auth.uid;
    const { directPaymentRequestId, rejectionReason } = data;

    if (!directPaymentRequestId) {
      throw new functions.https.HttpsError('invalid-argument', 'directPaymentRequestId مطلوب');
    }

    return db.runTransaction(async (tx) => {
      // ── READ (inside transaction — guarantees latest snapshot) ────────────
      const dpRef  = db.collection('directPaymentRequests').doc(directPaymentRequestId);
      const dpSnap = await tx.get(dpRef);   // ✅ was: dpRef.get() outside transaction

      if (!dpSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'طلب الدفع غير موجود');
      }
      const dp = dpSnap.data()!;

      if (dp.mohaffezId !== mohaffezId) {
        throw new functions.https.HttpsError('permission-denied', 'غير مصرح لك');
      }

      // ── STATUS GUARD (now atomic — no TOCTOU race) ────────────────────────
      if (dp.status === 'confirmed') {
        // Cannot reject an already-confirmed payment
        throw new functions.https.HttpsError(
          'failed-precondition',
          'تم تأكيد الدفع بالفعل ولا يمكن رفضه',
        );
      }

      if (dp.status === STATUS.REJECTED) {
        // Idempotent early return
        throw new functions.https.HttpsError(
          'already-exists',
          JSON.stringify({ success: true, message: 'تم الرفض مسبقاً' }),
        );
      }

      // ── READS for related docs ─────────────────────────────────────────────
      const reqRef  = db.collection('sessionRequests').doc(dp.sessionRequestId);
      const reqSnap = await tx.get(reqRef);

      if (!reqSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'طلب الجلسة غير موجود');
      }

      // ── WRITES ────────────────────────────────────────────────────────────
      const notifRef = db.collection('notifications').doc();

      tx.update(dpRef, {
        status:             STATUS.REJECTED,
        rejectionReason:    rejectionReason || '',
        mohaffezConfirmedAt: FieldValue.serverTimestamp(),
        updatedAt:           FieldValue.serverTimestamp(),
      });

      tx.update(reqRef, {
        status:                  STATUS.AWAITING_PAYMENT,
        directPaymentRejectedAt:  FieldValue.serverTimestamp(),
        updatedAt:                FieldValue.serverTimestamp(),
      });

      tx.set(notifRef, {
        userId:      dp.studentId,
        recipientId: dp.studentId,
        senderId:    mohaffezId,
        title:       'لم يتم تأكيد دفعتك',
        body:        `${dp.mohaffezName} لم يتأكد من استلام دفعتك. يرجى المحاولة مرة أخرى.`,
        type:        'directpaymentrejected',
        isRead:      false,
        data: {
          sessionRequestId:      dp.sessionRequestId,
          directPaymentRequestId,
          rejectionReason:       rejectionReason || '',
        },
        createdAt: FieldValue.serverTimestamp(),
      });

      return { success: true, message: 'تم رفض الدفع وإعادة الطالب لمرحلة الدفع' };

    }).catch((e: any) => {
      if (e.code === 'already-exists') return JSON.parse(e.message);
      functions.logger.error('mohaffezRejectDirectPayment failed', e);
      throw e;
    });
  },
);

