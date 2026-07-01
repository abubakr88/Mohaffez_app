// functions/src/index.ts
// Main entry point - only imports and re-exports

// Notification functions
export { sendNotification } from "./notifications/sendNotification";
export { onSessionRequestAccepted } from "./notifications/triggers";
export { onSessionRequestStatusChanged } from "./notifications/triggers";
export {
  onSessionCreated,
  onSessionCompleted,
  onTeacherRated,
} from "./notifications/triggers";
export { sendPaymentDeadlineReminders } from "./notifications/paymentDeadlineReminders";
export { sendSessionReminders } from "./notifications/sessionReminders";

// Payment functions
// Paymob webhook is always exported; gated at runtime by
// systemConfig/global.paymobEnabled. Admin toggles from the web panel.
export { paymobWebhook } from "./payments/paymobWebhook";
export { createPaymobIntention } from "./payments/createPaymobIntention";
export {
  reconcilePaymobPayment,
  reconcilePendingPaymobPayments,
} from "./payments/reconcilePaymobPayment";
export { projectPaymentAnalytics } from "./payments/projections";
export { checkExpiredPayments } from "./payments/expiredPayments";
export { onPaymentCreated } from "./payments/triggers";

// Cleanup functions
export { releaseExpiredSlotLocks } from "./cleanup/releaseExpiredSlotLocks";

export { confirmFreeSession } from "./bookings/confirmFreeSession";
export { createSessionRequest } from "./bookings/createSessionRequest";
export {
  createTrialSessionRequest,
  proposeTrialSessionTime,
  confirmTrialSessionTime,
  rejectTrialSessionRequest,
} from "./trialSessions";
export {
  studentMarkedDirectPayment,
  mohaffezConfirmDirectPayment,
  mohaffezRejectDirectPayment,
} from "./payments/directPayment";

// Bundle and subscription payment functions
export { confirmBundleDirectPayment } from "./payments/confirmBundleDirectPayment";
export { confirmBundleSession } from "./payments/confirmBundleSession";

// Admin functions
export {
  setUserRole,
  suspendUser,
  unsuspendUser,
  deleteUserAccount,
  deleteMyAccount,
  sendBroadcastNotification,
  triggerCleanupJobManually,
  approveCredential,
  rejectCredential,
  approveTeacher,
  rejectTeacher,
  updateAdminAccess,
  getBroadcastAudienceCount,
} from "./admin/adminActions";
export { checkAppVersion } from "./admin/appVersionCheck";
export { checkMaintenanceMode } from "./admin/maintenanceCheck";
export { checkVersion } from "./admin/appVersion";
export { setAdminClaim } from "./setAdminClaim";
export { getAdminMetrics, refreshAdminMetrics } from "./admin/metrics";
export { setTeacherFoundingBadge } from "./admin/teacherBadges";

// Per-teacher commission tier recompute (rolling 30-day revenue → tier).
export {
  recomputeTeacherTiers,
  recomputeTeacherTiersNow,
} from "./payments/recomputeTeacherTiers";

// Suspension triggers
export { onUserSuspended } from "./onUserSuspended";
export { onUserUnsuspended } from "./onUserUnsuspended";

// Student count function
export { getMohaffezStudentCount } from "./getMohaffezStudentCount";
export { getPublicTeacherProfile } from "./publicTeacherProfile";

// Online sessions (teacher's personal Zoom / Meet / Teams link)
export {
  onSessionAcceptedCreateMeeting,
  onMeetingStarted,
  sendOnlineSessionReminder,
  autoEndOverdueSessions,
} from "./onlineSessions";

// Cancellation & no-show policy
export {
  onSessionCancelled,
  onStudentNoShowReported,
  onTeacherNoShowReported,
} from "./cancellations";

// Wallet system (double-entry ledger)
export {
  verifyWalletTopUp,
  rejectWalletTopUp,
  adminCreditWallet,
} from "./wallet/walletTopUp";
export { payFromWallet, refundSessionPayment } from "./wallet/walletPaySession";
export {
  requestPayout,
  startPayout,
  completePayout,
  failPayout,
} from "./wallet/walletPayout";

// Proactive admin alerts (badge the admin bell on critical payment events)
export {
  onPaymentFailedAlertAdmins,
  onWalletNegativeAlertAdmins,
} from "./notifications/adminPaymentAlerts";
