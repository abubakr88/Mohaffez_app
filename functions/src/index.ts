// functions/src/index.ts
// Main entry point - only imports and re-exports

// Notification functions
export { sendNotification } from './notifications/sendNotification';
export { onSessionRequestAccepted } from './notifications/triggers';
export { onSessionRequestStatusChanged } from './notifications/triggers';
export { onSessionCreated, onSessionCompleted } from './notifications/triggers';
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

// Admin functions
export {
  setUserRole,
  suspendUser,
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

export {
  processWeeklyCommissions,
  markCommissionPaid,
  mohaffezReportCommissionPayment,
} from './payments/commissions';
