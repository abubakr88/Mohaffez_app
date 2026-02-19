"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.markCommissionPaid = exports.processWeeklyCommissions = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const admin_1 = require("../utils/admin");
const notificationHelpers_1 = require("../utils/notificationHelpers");
// Runs every Monday at 09:00 Cairo time to send overdue reminders
exports.processWeeklyCommissions = functions.pubsub
    .schedule("every monday 09:00")
    .timeZone("Africa/Cairo")
    .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const overdue = await admin_1.db.collection("weeklyCommissionSummaries")
        .where("status", "==", "pending")
        .where("dueDate", "<=", now)
        .get();
    for (const doc of overdue.docs) {
        const d = doc.data();
        await doc.ref.update({ status: "overdue", updatedAt: admin_1.FieldValue.serverTimestamp() });
        if (d.mohaffezId && d.commissionAmount > 0) {
            await (0, notificationHelpers_1.createAndSendNotification)({
                userId: d.mohaffezId,
                senderId: "system",
                title: "⚠️ عمولة متأخرة",
                body: `لديك عمولة متأخرة ${d.commissionAmount.toFixed(2)} ج.م عن الأسبوع ${d.weekNumber}`,
                type: "commission_overdue", isRead: false,
                data: { weeklyCommissionSummaryId: doc.id,
                    commissionAmount: d.commissionAmount.toString() },
                highPriority: true,
            });
        }
    }
    functions.logger.info("Weekly commissions processed", { count: overdue.size });
    return null;
});
// Called by admin to mark a summary as paid
exports.markCommissionPaid = functions.https.onCall(async (data, context) => {
    var _a;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "غير مصادق عليه");
    const callerDoc = await admin_1.db.collection("users").doc(context.auth.uid).get();
    if (((_a = callerDoc.data()) === null || _a === void 0 ? void 0 : _a.role) !== "admin")
        throw new functions.https.HttpsError("permission-denied", "غير مصرح لك");
    const { weeklyCommissionSummaryId } = data;
    const summaryRef = admin_1.db.collection("weeklyCommissionSummaries").doc(weeklyCommissionSummaryId);
    await summaryRef.update({
        status: "paid", paidAt: admin_1.FieldValue.serverTimestamp(),
        markedPaidBy: context.auth.uid, updatedAt: admin_1.FieldValue.serverTimestamp(),
    });
    const summarySnap = await summaryRef.get();
    const s = summarySnap.data();
    const pending = await admin_1.db.collection("commissions")
        .where("mohaffezId", "==", s.mohaffezId)
        .where("weekNumber", "==", s.weekNumber)
        .where("status", "==", "pending").get();
    const batch = admin_1.db.batch();
    pending.docs.forEach(d => batch.update(d.ref, { status: "paid", paidAt: admin_1.FieldValue.serverTimestamp() }));
    await batch.commit();
    await (0, notificationHelpers_1.createAndSendNotification)({
        userId: s.mohaffezId, senderId: context.auth.uid,
        title: "✅ تم تسجيل سداد العمولة",
        body: `تم تسجيل سداد عمولتك الأسبوع ${s.weekNumber}: ${s.commissionAmount.toFixed(2)} ج.م`,
        type: "commission_paid", isRead: false,
        data: { weeklyCommissionSummaryId },
    });
    return { success: true };
});
//# sourceMappingURL=commissions.js.map