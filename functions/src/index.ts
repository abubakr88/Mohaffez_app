// functions/src/index.ts
// Main entry point - only imports and re-exports

// Notification functions
export { sendNotification } from './notifications/sendNotification';
export { onSessionRequestAccepted } from './notifications/triggers';
export { onSessionRequestStatusChanged } from './notifications/triggers';
export { onSessionCreated, onSessionCompleted, onTeacherRated } from './notifications/triggers';
export { sendPaymentDeadlineReminders } from './notifications/paymentDeadlineReminders';
export { sendSessionReminders } from './notifications/sessionReminders';

// Payment functions
/* WEBHOOK_DISABLED - re-enable when Paymob gateway is activated
export { paymobWebhook } from './payments/paymobWebhook';
*/
export { projectPaymentAnalytics } from './payments/projections';
export { checkExpiredPayments } from './payments/expiredPayments';
export { onPaymentCreated } from './payments/triggers';

// Cleanup functions
export { releaseExpiredSlotLocks } from './cleanup/releaseExpiredSlotLocks';

export { confirmFreeSession } from './bookings/confirmFreeSession';
export { createSessionRequest } from './bookings/createSessionRequest';
export { studentMarkedDirectPayment, mohaffezConfirmDirectPayment, mohaffezRejectDirectPayment } from './payments/directPayment';

// Bundle and subscription payment functions
export { confirmBundleDirectPayment } from './payments/confirmBundleDirectPayment';
export { confirmSubscriptionSession } from './payments/confirmSubscriptionSession';

// Admin functions
export {
  setUserRole,
  suspendUser,
  unsuspendUser,
  deleteUserAccount,
  sendBroadcastNotification,
  triggerCommissionJobManually,
  triggerCleanupJobManually,
  approveCredential,
  rejectCredential,
  getBroadcastAudienceCount,
} from './admin/adminActions';
export { checkAppVersion } from './admin/appVersionCheck';
export { checkMaintenanceMode } from './admin/maintenanceCheck';
export { checkVersion } from './admin/appVersion';
export { setAdminClaim } from './setAdminClaim';
export { getAdminMetrics, refreshAdminMetrics } from './admin/metrics';

export {
  processWeeklyCommissions,
  markCommissionPaid,
  mohaffezReportCommissionPayment,
  rejectCommissionPayment,
} from './payments/commissions';

// Suspension triggers
export { onUserSuspended } from './onUserSuspended';
export { onUserUnsuspended } from './onUserUnsuspended';

// Student count function
export { getMohaffezStudentCount } from './getMohaffezStudentCount';

// Online sessions (teacher's personal Zoom / Meet / Teams link)
export {
  onSessionAcceptedCreateMeeting,
  onMeetingStarted,
  sendOnlineSessionReminder,
} from './onlineSessions';

// Wallet system (double-entry ledger)
export {
  verifyWalletTopUp,
  rejectWalletTopUp,
  adminCreditWallet,
} from './wallet/walletTopUp';
export { payFromWallet, refundSessionPayment } from './wallet/walletPaySession';
export {
  requestPayout,
  startPayout,
  completePayout,
  failPayout,
} from './wallet/walletPayout';
