"use strict";
// functions/src/index.ts
// Main entry point - only imports and re-exports
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendOnlineSessionReminder = exports.onMeetingStarted = exports.onSessionAcceptedCreateMeeting = exports.getMohaffezStudentCount = exports.onUserUnsuspended = exports.onUserSuspended = exports.rejectCommissionPayment = exports.mohaffezReportCommissionPayment = exports.markCommissionPaid = exports.processWeeklyCommissions = exports.refreshAdminMetrics = exports.getAdminMetrics = exports.setAdminClaim = exports.checkVersion = exports.checkMaintenanceMode = exports.checkAppVersion = exports.getBroadcastAudienceCount = exports.rejectCredential = exports.approveCredential = exports.triggerCleanupJobManually = exports.triggerCommissionJobManually = exports.sendBroadcastNotification = exports.deleteUserAccount = exports.unsuspendUser = exports.suspendUser = exports.setUserRole = exports.confirmSubscriptionSession = exports.confirmBundleDirectPayment = exports.mohaffezRejectDirectPayment = exports.mohaffezConfirmDirectPayment = exports.studentMarkedDirectPayment = exports.createSessionRequest = exports.confirmFreeSession = exports.releaseExpiredSlotLocks = exports.onPaymentCreated = exports.checkExpiredPayments = exports.projectPaymentAnalytics = exports.sendSessionReminders = exports.sendPaymentDeadlineReminders = exports.onTeacherRated = exports.onSessionCompleted = exports.onSessionCreated = exports.onSessionRequestStatusChanged = exports.onSessionRequestAccepted = exports.sendNotification = void 0;
// Notification functions
var sendNotification_1 = require("./notifications/sendNotification");
Object.defineProperty(exports, "sendNotification", { enumerable: true, get: function () { return sendNotification_1.sendNotification; } });
var triggers_1 = require("./notifications/triggers");
Object.defineProperty(exports, "onSessionRequestAccepted", { enumerable: true, get: function () { return triggers_1.onSessionRequestAccepted; } });
var triggers_2 = require("./notifications/triggers");
Object.defineProperty(exports, "onSessionRequestStatusChanged", { enumerable: true, get: function () { return triggers_2.onSessionRequestStatusChanged; } });
var triggers_3 = require("./notifications/triggers");
Object.defineProperty(exports, "onSessionCreated", { enumerable: true, get: function () { return triggers_3.onSessionCreated; } });
Object.defineProperty(exports, "onSessionCompleted", { enumerable: true, get: function () { return triggers_3.onSessionCompleted; } });
Object.defineProperty(exports, "onTeacherRated", { enumerable: true, get: function () { return triggers_3.onTeacherRated; } });
var paymentDeadlineReminders_1 = require("./notifications/paymentDeadlineReminders");
Object.defineProperty(exports, "sendPaymentDeadlineReminders", { enumerable: true, get: function () { return paymentDeadlineReminders_1.sendPaymentDeadlineReminders; } });
var sessionReminders_1 = require("./notifications/sessionReminders");
Object.defineProperty(exports, "sendSessionReminders", { enumerable: true, get: function () { return sessionReminders_1.sendSessionReminders; } });
// Payment functions
/* WEBHOOK_DISABLED - re-enable when Paymob gateway is activated
export { paymobWebhook } from './payments/paymobWebhook';
*/
var projections_1 = require("./payments/projections");
Object.defineProperty(exports, "projectPaymentAnalytics", { enumerable: true, get: function () { return projections_1.projectPaymentAnalytics; } });
var expiredPayments_1 = require("./payments/expiredPayments");
Object.defineProperty(exports, "checkExpiredPayments", { enumerable: true, get: function () { return expiredPayments_1.checkExpiredPayments; } });
var triggers_4 = require("./payments/triggers");
Object.defineProperty(exports, "onPaymentCreated", { enumerable: true, get: function () { return triggers_4.onPaymentCreated; } });
// Cleanup functions
var releaseExpiredSlotLocks_1 = require("./cleanup/releaseExpiredSlotLocks");
Object.defineProperty(exports, "releaseExpiredSlotLocks", { enumerable: true, get: function () { return releaseExpiredSlotLocks_1.releaseExpiredSlotLocks; } });
var confirmFreeSession_1 = require("./bookings/confirmFreeSession");
Object.defineProperty(exports, "confirmFreeSession", { enumerable: true, get: function () { return confirmFreeSession_1.confirmFreeSession; } });
var createSessionRequest_1 = require("./bookings/createSessionRequest");
Object.defineProperty(exports, "createSessionRequest", { enumerable: true, get: function () { return createSessionRequest_1.createSessionRequest; } });
var directPayment_1 = require("./payments/directPayment");
Object.defineProperty(exports, "studentMarkedDirectPayment", { enumerable: true, get: function () { return directPayment_1.studentMarkedDirectPayment; } });
Object.defineProperty(exports, "mohaffezConfirmDirectPayment", { enumerable: true, get: function () { return directPayment_1.mohaffezConfirmDirectPayment; } });
Object.defineProperty(exports, "mohaffezRejectDirectPayment", { enumerable: true, get: function () { return directPayment_1.mohaffezRejectDirectPayment; } });
// Bundle and subscription payment functions
var confirmBundleDirectPayment_1 = require("./payments/confirmBundleDirectPayment");
Object.defineProperty(exports, "confirmBundleDirectPayment", { enumerable: true, get: function () { return confirmBundleDirectPayment_1.confirmBundleDirectPayment; } });
var confirmSubscriptionSession_1 = require("./payments/confirmSubscriptionSession");
Object.defineProperty(exports, "confirmSubscriptionSession", { enumerable: true, get: function () { return confirmSubscriptionSession_1.confirmSubscriptionSession; } });
// Admin functions
var adminActions_1 = require("./admin/adminActions");
Object.defineProperty(exports, "setUserRole", { enumerable: true, get: function () { return adminActions_1.setUserRole; } });
Object.defineProperty(exports, "suspendUser", { enumerable: true, get: function () { return adminActions_1.suspendUser; } });
Object.defineProperty(exports, "unsuspendUser", { enumerable: true, get: function () { return adminActions_1.unsuspendUser; } });
Object.defineProperty(exports, "deleteUserAccount", { enumerable: true, get: function () { return adminActions_1.deleteUserAccount; } });
Object.defineProperty(exports, "sendBroadcastNotification", { enumerable: true, get: function () { return adminActions_1.sendBroadcastNotification; } });
Object.defineProperty(exports, "triggerCommissionJobManually", { enumerable: true, get: function () { return adminActions_1.triggerCommissionJobManually; } });
Object.defineProperty(exports, "triggerCleanupJobManually", { enumerable: true, get: function () { return adminActions_1.triggerCleanupJobManually; } });
Object.defineProperty(exports, "approveCredential", { enumerable: true, get: function () { return adminActions_1.approveCredential; } });
Object.defineProperty(exports, "rejectCredential", { enumerable: true, get: function () { return adminActions_1.rejectCredential; } });
Object.defineProperty(exports, "getBroadcastAudienceCount", { enumerable: true, get: function () { return adminActions_1.getBroadcastAudienceCount; } });
var appVersionCheck_1 = require("./admin/appVersionCheck");
Object.defineProperty(exports, "checkAppVersion", { enumerable: true, get: function () { return appVersionCheck_1.checkAppVersion; } });
var maintenanceCheck_1 = require("./admin/maintenanceCheck");
Object.defineProperty(exports, "checkMaintenanceMode", { enumerable: true, get: function () { return maintenanceCheck_1.checkMaintenanceMode; } });
var appVersion_1 = require("./admin/appVersion");
Object.defineProperty(exports, "checkVersion", { enumerable: true, get: function () { return appVersion_1.checkVersion; } });
var setAdminClaim_1 = require("./setAdminClaim");
Object.defineProperty(exports, "setAdminClaim", { enumerable: true, get: function () { return setAdminClaim_1.setAdminClaim; } });
var metrics_1 = require("./admin/metrics");
Object.defineProperty(exports, "getAdminMetrics", { enumerable: true, get: function () { return metrics_1.getAdminMetrics; } });
Object.defineProperty(exports, "refreshAdminMetrics", { enumerable: true, get: function () { return metrics_1.refreshAdminMetrics; } });
var commissions_1 = require("./payments/commissions");
Object.defineProperty(exports, "processWeeklyCommissions", { enumerable: true, get: function () { return commissions_1.processWeeklyCommissions; } });
Object.defineProperty(exports, "markCommissionPaid", { enumerable: true, get: function () { return commissions_1.markCommissionPaid; } });
Object.defineProperty(exports, "mohaffezReportCommissionPayment", { enumerable: true, get: function () { return commissions_1.mohaffezReportCommissionPayment; } });
Object.defineProperty(exports, "rejectCommissionPayment", { enumerable: true, get: function () { return commissions_1.rejectCommissionPayment; } });
// Suspension triggers
var onUserSuspended_1 = require("./onUserSuspended");
Object.defineProperty(exports, "onUserSuspended", { enumerable: true, get: function () { return onUserSuspended_1.onUserSuspended; } });
var onUserUnsuspended_1 = require("./onUserUnsuspended");
Object.defineProperty(exports, "onUserUnsuspended", { enumerable: true, get: function () { return onUserUnsuspended_1.onUserUnsuspended; } });
// Student count function
var getMohaffezStudentCount_1 = require("./getMohaffezStudentCount");
Object.defineProperty(exports, "getMohaffezStudentCount", { enumerable: true, get: function () { return getMohaffezStudentCount_1.getMohaffezStudentCount; } });
// Online sessions (teacher's personal Zoom / Meet / Teams link)
var onlineSessions_1 = require("./onlineSessions");
Object.defineProperty(exports, "onSessionAcceptedCreateMeeting", { enumerable: true, get: function () { return onlineSessions_1.onSessionAcceptedCreateMeeting; } });
Object.defineProperty(exports, "onMeetingStarted", { enumerable: true, get: function () { return onlineSessions_1.onMeetingStarted; } });
Object.defineProperty(exports, "sendOnlineSessionReminder", { enumerable: true, get: function () { return onlineSessions_1.sendOnlineSessionReminder; } });
//# sourceMappingURL=index.js.map