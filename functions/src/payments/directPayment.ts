import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db, FieldValue } from "../utils/admin";
// FIX (Bug 3): Import parseFlutterDate so slot timestamps are stored as UTC,
// not shifted by the server's local timezone.
import {
  getWeekNumber,
  getWeekStart,
  getWeekEnd,
  getNextMonday,
  parseFlutterDate,
} from "../utils/dateHelpers";

const COMMISSION_RATE = 0.05;

const STATUS = {
  PENDING: "pending",
  AWAITINGPAYMENT: "awaitingpayment",
  AWAITINGDIRECT: "awaitingdirectpaymentconfirmation",
  ACCEPTED: "accepted",
  REJECTED: "rejected",
  CANCELLED: "cancelled",
} as const;

// 1. Student marks that they've paid
export const studentMarkedDirectPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "");
    const studentId = context.auth.uid;

    const {
      requestId,       // WHY: nullable — Path C (fresh booking) has no prior sessionRequest
      mohaffezId,
      mohaffezName,
      studentName,
      amount,
      sessionType,
      preferredTimeSlot,
      slotDate,
      slotStart,
      slotEnd,
      paymentMethod,
      studentNote,
      imamAddressText,
      imamAddressLat,
      imamAddressLng,
      mohaffezPhone,
      planType,
      planId,
      planTitle, // FIX BUG-13: Accept planTitle from client
      sessionsCount,
      validityDays,
    } = data;

    const finalPlanType = (planType as string | undefined) ?? "single";
    const finalPlanId = (planId as string | undefined) ?? "";
    const finalPlanTitle = (planTitle as string | undefined) ?? ""; // FIX BUG-13
    const finalSessionsCount = (sessionsCount as number | undefined) ?? 1;
    const finalValidityDays = (validityDays as number | null | undefined) ?? null;

    // FIX: requestId is now OPTIONAL (Path C has no prior sessionRequest).
    // Only mohaffezId, amount, and paymentMethod are always required.
    if (!mohaffezId || !amount || !paymentMethod)
      throw new functions.https.HttpsError("invalid-argument", "Missing required fields");

    // FIX BUG-14: Validate slot date format before parsing
    if (!slotDate || !slotStart || !slotEnd)
      throw new functions.https.HttpsError("invalid-argument", "Missing slot time fields");

    // FIX BUG-16: Validate future date
    const parsedSlotDate = parseFlutterDate(slotDate as string);
    if (parsedSlotDate < new Date()) {
      throw new functions.https.HttpsError("invalid-argument", "Cannot book slots in the past");
    }

    return db
      .runTransaction(async (tx) => {

        // ── Optional: only process sessionRequest if one was linked ──────────
        if (requestId) {
          const reqRef = db.collection("sessionRequests").doc(requestId as string);
          const reqSnap = await tx.get(reqRef);
          if (!reqSnap.exists)
            throw new functions.https.HttpsError("not-found", "sessionRequest not found");
          const reqData = reqSnap.data()!;

          // Idempotency guards
          if (reqData.status === STATUS.ACCEPTED)
            throw new functions.https.HttpsError(
              "already-exists",
              JSON.stringify({ success: true, message: "Already confirmed" })
            );
          if (reqData.status === STATUS.AWAITINGDIRECT)
            throw new functions.https.HttpsError(
              "already-exists",
              JSON.stringify({ success: true, message: "Already marked as paid" })
            );

          const isDirectPaymentPath =
            reqData.selectedPaymentMethod === "directpayment";
          const acceptableStatuses: string[] = [STATUS.AWAITINGPAYMENT];
          if (isDirectPaymentPath) acceptableStatuses.push(STATUS.PENDING);

          if (!acceptableStatuses.includes(reqData.status as string))
            throw new functions.https.HttpsError(
              "failed-precondition",
              `Cannot mark payment: request status is ${reqData.status as string}.`
            );

          // Update linked sessionRequest
          tx.update(reqRef, {
            status: STATUS.AWAITINGDIRECT,
            directPaymentRequestId: "", // filled below after dpRef is created
            directPaymentMethod: paymentMethod,
            directPaymentAmount: amount,
            updatedAt: FieldValue.serverTimestamp(),
            planType: finalPlanType,
            planId: finalPlanId,
            planTitle: finalPlanTitle, // FIX BUG-13
            sessionsCount: finalSessionsCount,
            validityDays: finalValidityDays,
          });
        }

        // ── Always: create directPaymentRequest ──────────────────────────────
        const dpRef = db.collection("directPaymentRequests").doc();

        tx.set(dpRef, {
          id: dpRef.id,
          // WHY: null when Path C — mohaffez confirm flow still works because
          // mohaffezConfirmDirectPayment checks dp.sessionRequestId and only
          // updates the request doc when it is non-null.
          sessionRequestId: (requestId as string | undefined) ?? null,
          studentId,
          studentName,
          mohaffezId,
          mohaffezName,
          amount,
          commissionAmount: (amount as number) * COMMISSION_RATE,
          commissionRate: COMMISSION_RATE,
          sessionType,
          preferredTimeSlot,
          sessionDate: admin.firestore.Timestamp.fromDate(
            parseFlutterDate(slotDate as string)
          ),
          slotStart: admin.firestore.Timestamp.fromDate(
            parseFlutterDate(slotStart as string)
          ),
          slotEnd: admin.firestore.Timestamp.fromDate(
            parseFlutterDate(slotEnd as string)
          ),
          imamAddressText: imamAddressText ?? null,
          imamAddressLat: imamAddressLat ?? null,
          imamAddressLng: imamAddressLng ?? null,
          mohaffezPhone: mohaffezPhone ?? null,
          paymentMethod,
          studentNote: studentNote ?? null,
          status: "pendingconfirmation",
          studentConfirmedAt: FieldValue.serverTimestamp(),
          mohaffezConfirmedAt: null,
          sessionId: null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          planType: finalPlanType,
          planId: finalPlanId,
          planTitle: finalPlanTitle, // FIX BUG-13
          sessionsCount: finalSessionsCount,
          validityDays: finalValidityDays,
        });

        // Update requestId with dpRef.id if request exists
        if (requestId) {
          tx.update(db.collection("sessionRequests").doc(requestId as string), {
            directPaymentRequestId: dpRef.id,
          });
        }

        // ── Notify mohaffez ───────────────────────────────────────────────────
        const notifRef = db.collection("notifications").doc();
        tx.set(notifRef, {
          userId: mohaffezId,
          recipientId: mohaffezId,
          senderId: studentId,
          title:
            finalPlanType === "bundle" || finalPlanType === "subscription"
              ? "طلب دفع مباشر لباقة"
              : "طلب دفع مباشر",
          body:
            finalPlanType === "bundle" || finalPlanType === "subscription"
              ? `${studentName} أكد دفع ${amount} جنيه. الباقة: ${finalPlanTitle} (${finalSessionsCount} جلسات). الطريقة: ${paymentMethod}`
              : `${studentName} أكد دفع ${amount} جنيه. الطريقة: ${paymentMethod}`,
          type: "directpaymentpending",
          isRead: false,
          data: {
            directPaymentRequestId: dpRef.id,
            sessionRequestId: (requestId as string | undefined) ?? null,
            studentId,
            studentName,
            amount: (amount as number).toString(),
            paymentMethod,
            planType: finalPlanType,
            planId: finalPlanId,
            planTitle: finalPlanTitle,
            sessionsCount: finalSessionsCount,
            validityDays: finalValidityDays,
          },
          createdAt: FieldValue.serverTimestamp(),
        });

        return {
          success: true,
          directPaymentRequestId: dpRef.id,
          message: "تم إرسال إشعار للمحفظ. يرجى الانتظار حتى يؤكد استلام المبلغ.",
        };
      })
      .catch((e: unknown) => {
        if ((e as { code?: string }).code === "already-exists")
          return JSON.parse((e as Error).message);
        throw e;
      });
  }
);

// 2. Mohaffez confirms payment received → session auto-accepted
export const mohaffezConfirmDirectPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "");
    const mohaffezId = context.auth.uid;

    // FIX BUG-10: Validate caller is actually a mohaffez
    const callerDoc = await db.collection('users').doc(mohaffezId).get();
    if (!callerDoc.exists || callerDoc.data()?.role !== 'mohaffez') {
      throw new functions.https.HttpsError('permission-denied', 'Caller must be a mohaffez');
    }

    const directPaymentRequestId = data as string;
    if (!directPaymentRequestId)
      throw new functions.https.HttpsError("invalid-argument", "directPaymentRequestId required");

    return db
      .runTransaction(async (tx) => {
        const dpRef = db
          .collection("directPaymentRequests")
          .doc(directPaymentRequestId);
        const dpSnap = await tx.get(dpRef);
        if (!dpSnap.exists) throw new functions.https.HttpsError("not-found", "Payment request not found");
        const dp = dpSnap.data()!;

        if (dp.mohaffezId !== mohaffezId)
          throw new functions.https.HttpsError("permission-denied", "This payment is not for you");

        if (dp.status === "confirmed")
          throw new functions.https.HttpsError(
            "already-exists",
            JSON.stringify({ success: true, sessionId: dp.sessionId, message: "Already confirmed" })
          );

        // FIX: sessionRequestId is now optional (Path C has no prior request).
        // Only read/validate/update the sessionRequest doc when it exists.
        let reqRef: FirebaseFirestore.DocumentReference | null = null;

        if (dp.sessionRequestId) {
          reqRef = db
            .collection("sessionRequests")
            .doc(dp.sessionRequestId as string);
          const reqSnap = await tx.get(reqRef);

          if (!reqSnap.exists)
            throw new functions.https.HttpsError("not-found", "sessionRequest not found");

          const reqData = reqSnap.data()!;

          if (reqData.status === STATUS.ACCEPTED)
            throw new functions.https.HttpsError(
              "already-exists",
              JSON.stringify({ success: true, message: "Session already accepted" })
            );
        }

        // ── Create hafizSession (ONLY place for single direct payments) ──────
        const sessionRef = db.collection("hafizSessions").doc();

        const sessionDate = dp.sessionDate as admin.firestore.Timestamp;
        const slotStart = dp.slotStart as admin.firestore.Timestamp;
        const slotEnd = dp.slotEnd as admin.firestore.Timestamp;

        tx.set(sessionRef, {
          requestId: (dp.sessionRequestId as string | null) ?? null,
          mohaffezId,
          studentId: dp.studentId,
          mohaffezName: dp.mohaffezName,
          studentName: dp.studentName,
          sessionType: dp.sessionType,
          preferredTimeSlot: dp.preferredTimeSlot,
          sessionDate,
          slotStart,
          slotEnd,
          status: "accepted",
          isPaid: true,
          sessionPrice: dp.amount,
          paymentType: "directpayment",
          directPaymentRequestId,
          mohaffezPhone: dp.mohaffezPhone ?? null,
          imamAddressText: dp.imamAddressText ?? null,
          imamAddressLat: dp.imamAddressLat ?? null,
          imamAddressLng: dp.imamAddressLng ?? null,
          createdAt: FieldValue.serverTimestamp(),
          acceptedAt: FieldValue.serverTimestamp(),
          reminder24hSent: false,
          reminder1hSent: false,
          juzCount: 1,
          sessionRating: 10,
          notificationsAlreadySent: true, // FIX BUG-12: Prevent duplicate notifications
        });

        // ── Update directPaymentRequest ──────────────────────────────────────
        tx.update(dpRef, {
          status: "confirmed",
          sessionId: sessionRef.id,
          mohaffezConfirmedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        // ── Update sessionRequest if it exists ───────────────────────────────
        if (reqRef) {
          tx.update(reqRef, {
            status: STATUS.ACCEPTED,
            isPaid: true,
            paidAt: FieldValue.serverTimestamp(),
            sessionId: sessionRef.id,
            directPaymentConfirmedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }

        // ── Commission tracking ──────────────────────────────────────────────
        const commissionAmount = (dp.amount as number) * COMMISSION_RATE;
        const sessionDateObj = sessionDate.toDate();
        const weekNumber = getWeekNumber(sessionDateObj);
        const year = sessionDateObj.getFullYear();
        const weekStart = getWeekStart(sessionDateObj);
        const weekEnd = getWeekEnd(sessionDateObj);
        const dueDate = getNextMonday(sessionDateObj);

        const commissionId = `${mohaffezId}_${year}_W${weekNumber}`;
        const commissionRef = db.collection("weeklyCommissions").doc(commissionId);
        const commissionSnap = await tx.get(commissionRef);

        if (commissionSnap.exists) {
          tx.update(commissionRef, {
            totalSessions: FieldValue.increment(1),
            totalRevenue: FieldValue.increment(dp.amount as number),
            commissionAmount: FieldValue.increment(commissionAmount),
            updatedAt: FieldValue.serverTimestamp(),
          });
        } else {
          tx.set(commissionRef, {
            mohaffezId,
            mohaffezName: dp.mohaffezName,
            weekNumber,
            year,
            totalSessions: 1,
            totalRevenue: dp.amount,
            commissionAmount,
            commissionRate: COMMISSION_RATE,
            status: "pending",
            weekStart: admin.firestore.Timestamp.fromDate(weekStart),
            weekEnd: admin.firestore.Timestamp.fromDate(weekEnd),
            dueDate: admin.firestore.Timestamp.fromDate(dueDate),
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }

        // ── Notify student ────────────────────────────────────────────────────
        const notifRef = db.collection("notifications").doc();
        tx.set(notifRef, {
          userId: dp.studentId,
          recipientId: dp.studentId,
          senderId: mohaffezId,
          title: "تم تأكيد الدفع المباشر!",
          body: `${dp.mohaffezName as string} أكد استلام المبلغ! تم تأكيد جلستك تلقائياً`,
          type: "directpaymentconfirmed",
          isRead: false,
          data: {
            sessionId: sessionRef.id,
            sessionRequestId: (dp.sessionRequestId as string | null) ?? null,
            directPaymentRequestId,
          },
          createdAt: FieldValue.serverTimestamp(),
        });

        return { success: true, sessionId: sessionRef.id, message: "تم تأكيد الدفع! تم إنشاء الجلسة تلقائياً" };
      })
      .catch((e: unknown) => {
        if ((e as { code?: string }).code === "already-exists")
          return JSON.parse((e as Error).message);
        functions.logger.error("mohaffezConfirmDirectPayment failed", e);
        throw e;
      });
  }
);

// 3. Mohaffez rejects payment (student didn't pay)
export const mohaffezRejectDirectPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "");
    const mohaffezId = context.auth.uid;

    // FIX BUG-10: Validate caller is actually a mohaffez
    const callerDoc = await db.collection('users').doc(mohaffezId).get();
    if (!callerDoc.exists || callerDoc.data()?.role !== 'mohaffez') {
      throw new functions.https.HttpsError('permission-denied', 'Caller must be a mohaffez');
    }

    const { directPaymentRequestId, rejectionReason } = data;
    if (!directPaymentRequestId)
      throw new functions.https.HttpsError(
        "invalid-argument",
        "directPaymentRequestId required"
      );

    return db
      .runTransaction(async (tx) => {
        const dpRef = db
          .collection("directPaymentRequests")
          .doc(directPaymentRequestId);
        const dpSnap = await tx.get(dpRef);
        if (!dpSnap.exists) throw new functions.https.HttpsError("not-found", "Payment request not found");
        const dp = dpSnap.data()!;

        if (dp.mohaffezId !== mohaffezId)
          throw new functions.https.HttpsError("permission-denied", "This payment is not for you");

        if (dp.status === "confirmed")
          throw new functions.https.HttpsError("failed-precondition", "Cannot reject confirmed payment");
        if (dp.status === "rejected")
          throw new functions.https.HttpsError(
            "already-exists",
            JSON.stringify({ success: true, message: "Already rejected" })
          );

        tx.update(dpRef, {
          status: "rejected",
          rejectionReason: rejectionReason ?? null,
          mohaffezRejectedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        if (dp.sessionRequestId) {
          const reqRef = db.collection("sessionRequests").doc(dp.sessionRequestId as string);
          tx.update(reqRef, {
            status: STATUS.AWAITINGPAYMENT,
            directPaymentRequestId: null,
            directPaymentRejectedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }

        const notifRef = db.collection("notifications").doc();
        tx.set(notifRef, {
          userId: dp.studentId,
          recipientId: dp.studentId,
          senderId: mohaffezId,
          title: "تم رفض الدفع المباشر",
          body: rejectionReason
            ? `${dp.mohaffezName} رفض طلب الدفع: ${rejectionReason}`
            : `${dp.mohaffezName} رفض طلب الدفع`,
          type: "directpaymentrejected",
          isRead: false,
          data: {
            sessionRequestId: dp.sessionRequestId,
            directPaymentRequestId,
          },
          createdAt: FieldValue.serverTimestamp(),
        });

        return { success: true, message: "تم رفض طلب الدفع" };
      })
      .catch((e: unknown) => {
        if ((e as { code?: string }).code === "already-exists")
          return JSON.parse((e as Error).message);
        throw e;
      });
  }
);
