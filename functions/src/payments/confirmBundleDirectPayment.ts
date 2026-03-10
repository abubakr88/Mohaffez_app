import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db, FieldValue } from "../utils/admin";
import { getWeekNumber, getWeekStart, getWeekEnd, getNextMonday } from "../utils/dateHelpers";
import { createAndSendNotification } from "../utils/notificationHelpers";

const COMMISSION_RATE = 0.05;

class AlreadyConfirmedError extends Error {
  constructor(public readonly existingSubscriptionId: string) {
    super("AlreadyConfirmed");
    this.name = "AlreadyConfirmedError";
  }
}

export const confirmBundleDirectPayment = functions.https.onCall(
  async (data, context) => {
    functions.logger.info("confirmBundleDirectPayment Starting", {
      timestamp: new Date().toISOString(),
    });

    // 1. Auth
    if (!context.auth)
      throw new functions.https.HttpsError("unauthenticated", "");
    const studentId = context.auth.uid;

    // 2. Extract params
    const {
      paymentId,
      studentId: _studentId,
      planId,
      planTitle,
      planType,
      sessionsCount,
      validityDays,
      // Slot fields — present only when isSlotCoupled
      slotDate,
      slotStart,
      slotEnd,
      preferredTimeSlot,
      sessionType: slotSessionType,
      mohaffezPhone,
      imamAddressText,
      imamAddressLat,
      imamAddressLng,
    } = data;

    // 3. Validate required params
    if (!paymentId || !planId || !planTitle || !planType || !sessionsCount)
      throw new functions.https.HttpsError("invalid-argument", "");

    // 4. isSlotCoupled = all five slot fields present
    const isSlotCoupled =
      typeof slotDate === "string" &&
      slotDate.length > 0 &&
      typeof slotStart === "string" &&
      slotStart.length > 0 &&
      typeof slotEnd === "string" &&
      slotEnd.length > 0 &&
      typeof preferredTimeSlot === "string" &&
      preferredTimeSlot.length > 0 &&
      typeof slotSessionType === "string" &&
      slotSessionType.length > 0;

    functions.logger.info("confirmBundleDirectPayment params", {
      paymentId,
      planType,
      sessionsCount,
      isSlotCoupled,
    });

    try {
      // 5. Pre-parse slot timestamps (pure, no IO) — only when slot-coupled
      const slotDateTs = isSlotCoupled
        ? admin.firestore.Timestamp.fromDate(new Date((slotDate as string) + "Z"))
        : null;
      const slotStartTs = isSlotCoupled
        ? admin.firestore.Timestamp.fromDate(new Date((slotStart as string) + "Z"))
        : null;
      const slotEndTs = isSlotCoupled
        ? admin.firestore.Timestamp.fromDate(new Date((slotEnd as string) + "Z"))
        : null;

      // 6. Read directPaymentRequest
      const dpRef = db.collection("directPaymentRequests").doc(paymentId);
      const dpSnap = await dpRef.get();
      if (!dpSnap.exists)
        throw new functions.https.HttpsError("not-found", "directPaymentRequest not found");
      const dp = dpSnap.data()!;

      // 7. Idempotency guard (pre-transaction)
      if (dp.status === "confirmed" && dp.subscriptionId) {
        functions.logger.info(
          "confirmBundleDirectPayment: already confirmed (pre-tx check)",
          { paymentId, subscriptionId: dp.subscriptionId }
        );
        return {
          success: true,
          subscriptionId: dp.subscriptionId,
          message: "Already confirmed",
        };
      }

      const mohaffezId = dp.mohaffezId as string;

      // 8. Main transaction
      const result = await db.runTransaction(async (transaction) => {
        // Re-read dpRef inside transaction for consistency
        const dpSnapTx = await transaction.get(dpRef);
        if (!dpSnapTx.exists)
          throw new functions.https.HttpsError("not-found", "");
        const dpTx = dpSnapTx.data()!;

        // Idempotency check inside transaction
        if (dpTx.status === "confirmed" && dpTx.subscriptionId) {
          throw new AlreadyConfirmedError(dpTx.subscriptionId as string);
        }

        // 8a. Read system config for maxActiveSubscriptions
        const configSnap = await transaction.get(
          db.collection("systemConfig").doc("global")
        );
        const maxActive: number =
          (configSnap.data()?.maxActiveSubscriptions as number) ?? 3;

        // FIX 3: Resolve sessionType with explicit priority order
        const dpMetadata = (dp as Record<string, unknown>).metadata as
          | Record<string, unknown>
          | undefined;
        const resolvedSessionType: string = (() => {
          if (isSlotCoupled && typeof slotSessionType === "string" && slotSessionType.trim())
            return slotSessionType.trim();
          if (typeof dp.sessionType === "string" && (dp.sessionType as string).trim())
            return (dp.sessionType as string).trim();
          if (typeof dpMetadata?.sessionType === "string" && (dpMetadata.sessionType as string).trim())
            return (dpMetadata.sessionType as string).trim();
          throw new functions.https.HttpsError(
            "invalid-argument",
            "sessionType could not be resolved from payment request or slot params"
          );
        })();

        // FIX 3: Uniqueness constraint — student + mohaffez + sessionType
        const activeSubsSnap = await transaction.get(
          db
            .collection("subscriptions")
            .where("studentId", "==", studentId)
            .where("mohaffezId", "==", mohaffezId)
            .where("sessionType", "==", resolvedSessionType)
            .where("status", "==", "active")
        );
        if (activeSubsSnap.size >= maxActive)
          throw new functions.https.HttpsError("resource-exhausted", "");

        // 8b. Compute expiry
        const now = new Date();
        const expiryDate =
          validityDays != null
            ? admin.firestore.Timestamp.fromDate(
                new Date(now.getTime() + (validityDays as number) * 86400000)
              )
            : null;

        // 8c. Deterministic transaction tag
        const transactionTag = `bundle-${paymentId}`;

        // 8d. Document refs
        const subscriptionRef = db.collection("subscriptions").doc();
        const sessionRef = isSlotCoupled
          ? db.collection("hafizSessions").doc()
          : null;
        const newRequestRef = isSlotCoupled
          ? db.collection("sessionRequests").doc()
          : null;

        // FIX 5: initialRemaining computed in-place — avoids a second write
        const initialRemaining = isSlotCoupled
          ? (sessionsCount as number) - 1
          : (sessionsCount as number);

        // 8e. Write subscription
        transaction.set(subscriptionRef, {
          studentId,
          studentName: dp.studentName,
          mohaffezId,
          mohaffezName: dp.mohaffezName,
          planId,
          planTitle,
          planType,
          sessionType: resolvedSessionType, // FIX 3: stored for future queries
          totalSessions: sessionsCount,
          remainingSessions: initialRemaining, // FIX 5
          totalPaid: dp.amount,
          paymentTransactionId: transactionTag,
          startDate: FieldValue.serverTimestamp(),
          expiryDate,
          status: "active",
          directPaymentRequestId: paymentId,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        // 8f. Slot-coupled: create first session + linked request
        let createdSessionId: string | null = null;
        let createdRequestId: string | null = null;

        if (
          isSlotCoupled &&
          sessionRef &&
          newRequestRef &&
          slotDateTs &&
          slotStartTs &&
          slotEndTs
        ) {
          createdSessionId = sessionRef.id;
          createdRequestId = newRequestRef.id;

          transaction.set(sessionRef, {
            studentId,
            studentName: dp.studentName,
            mohaffezId,
            mohaffezName: dp.mohaffezName,
            sessionType: resolvedSessionType,
            preferredTimeSlot,
            sessionDate: slotDateTs,
            slotStart: slotStartTs,
            slotEnd: slotEndTs,
            status: "accepted",
            isPaid: true,
            paymentType: "bundle",
            subscriptionId: subscriptionRef.id,
            paymentTransactionId: transactionTag,
            requestId: newRequestRef.id,
            mohaffezPhone: mohaffezPhone ?? null,
            imamAddressText: imamAddressText ?? null,
            imamAddressLat: imamAddressLat ?? null,
            imamAddressLng: imamAddressLng ?? null,
            createdAt: FieldValue.serverTimestamp(),
            acceptedAt: FieldValue.serverTimestamp(),
            reminder24hSent: false,
            reminder1hSent: false,
            juzCount: 1,
            sessionRating: 10,
            // FIX (Bug 4): Prevents the onSessionCreated Firestore trigger from
            // firing a duplicate push notification. The confirmation flow already
            // notifies the student below (step 9).
            notificationsAlreadySent: true,
          });

          transaction.set(newRequestRef, {
            studentId,
            studentName: dp.studentName,
            mohaffezId,
            mohaffezName: dp.mohaffezName,
            sessionType: resolvedSessionType,
            preferredTimeSlot,
            slotDate: slotDateTs,
            slotStart: slotStartTs,
            slotEnd: slotEndTs,
            status: "accepted",
            paymentType: "bundle",
            subscriptionId: subscriptionRef.id,
            sessionId: sessionRef.id,
            paymentId,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }

        // 8g. Confirm the directPaymentRequest
        transaction.update(dpRef, {
          status: "confirmed",
          subscriptionId: subscriptionRef.id,
          mohaffezConfirmedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        // 8h. Update pre-existing linked sessionRequest (if student booked first)
        if (dp.sessionRequestId) {
          transaction.update(
            db.collection("sessionRequests").doc(dp.sessionRequestId as string),
            {
              status: "accepted",
              isPaid: true,
              paidAt: FieldValue.serverTimestamp(),
              subscriptionId: subscriptionRef.id,
              directPaymentConfirmedAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            }
          );
        }

        functions.logger.info("confirmBundleDirectPayment Subscription created", {
          paymentId,
          subscriptionId: subscriptionRef.id,
          isSlotCoupled,
          sessionId: createdSessionId,
        });

        return {
          subscriptionId: subscriptionRef.id,
          createdSessionId,
          createdRequestId,
        };
      });

      // 9. Post-transaction notifications (non-blocking for atomicity)
      let notificationBody =
        planType === "bundle"
          ? `${planTitle as string} . ${sessionsCount as number} .`
          : `${planTitle as string} . ${sessionsCount as number} .`;
      if (isSlotCoupled) notificationBody += " .";

      await createAndSendNotification({
        userId: studentId as string,
        senderId: mohaffezId,
        title: planType === "bundle" ? "" : "",
        body: notificationBody,
        type: "subscriptioncreated",
        highPriority: true,
        data: {
          subscriptionId: result.subscriptionId,
          planTitle: planTitle as string,
          planType: planType as string,
          sessionsCount: String(sessionsCount),
        },
      });

      functions.logger.info("confirmBundleDirectPayment Completed successfully", {
        paymentId,
        subscriptionId: result.subscriptionId,
      });

      // 10. Return success
      const response: Record<string, unknown> = {
        success: true,
        subscriptionId: result.subscriptionId,
        message:
          planType === "bundle"
            ? `${sessionsCount as number}`
            : `${sessionsCount as number}`,
      };
      if (isSlotCoupled && result.createdSessionId && result.createdRequestId) {
        response.sessionId = result.createdSessionId;
        response.requestId = result.createdRequestId;
      }
      return response;
    } catch (error) {
      // Idempotency shortcut thrown from inside the transaction
      if (error instanceof AlreadyConfirmedError) {
        functions.logger.info(
          "confirmBundleDirectPayment: idempotent transaction path",
          { paymentId }
        );
        return {
          success: true,
          subscriptionId: error.existingSubscriptionId,
          message: "Already confirmed",
        };
      }
      // Re-throw HttpsErrors as-is
      if (error instanceof functions.https.HttpsError) throw error;
      const message =
        error instanceof Error ? error.message : "Unknown error";
      functions.logger.error("confirmBundleDirectPayment failed", {
        paymentId,
        error: message,
      });
      throw new functions.https.HttpsError("internal", message);
    }
  }
);
