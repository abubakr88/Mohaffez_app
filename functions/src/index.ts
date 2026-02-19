// functions/src/index.ts
// Main entry point - only imports and re-exports

// Notification functions
export { sendNotification } from './notifications/sendNotification';
export { onSessionRequestAccepted } from './notifications/triggers';
export { sendPaymentDeadlineReminders } from './notifications/paymentDeadlineReminders';
export { sendSessionReminders } from './notifications/sessionReminders';

// Payment functions
export { paymobWebhook } from './payments/paymobWebhook';
export { projectPaymentAnalytics } from './payments/projections';
export { checkExpiredPayments } from './payments/expiredPayments';
export { onPaymentCreated } from './payments/triggers';

// Cleanup functions
export { releaseExpiredSlotLocks } from './cleanup/releaseExpiredSlotLocks';

export { confirmFreeSession } from './bookings/confirmFreeSession';
export { studentMarkedDirectPayment, mohaffezConfirmDirectPayment, mohaffezRejectDirectPayment } from './payments/directPayment';
export { processWeeklyCommissions, markCommissionPaid } from './payments/commissions';
