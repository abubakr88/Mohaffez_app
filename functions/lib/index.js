"use strict";
// functions/src/index.ts
// Main entry point - only imports and re-exports
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkVersion = exports.checkMaintenanceMode = exports.checkAppVersion = exports.getBroadcastAudienceCount = exports.rejectCredential = exports.approveCredential = exports.triggerCleanupJobManually = exports.triggerCommissionJobManually = exports.sendBroadcastNotification = exports.deleteUserAccount = exports.suspendUser = exports.setUserRole = exports.markCommissionPaid = exports.processWeeklyCommissions = exports.mohaffezRejectDirectPayment = exports.mohaffezConfirmDirectPayment = exports.studentMarkedDirectPayment = exports.createSessionRequest = exports.confirmFreeSession = exports.releaseExpiredSlotLocks = exports.onPaymentCreated = exports.checkExpiredPayments = exports.projectPaymentAnalytics = exports.sendSessionReminders = exports.sendPaymentDeadlineReminders = exports.onSessionCompleted = exports.onSessionCreated = exports.onSessionRequestStatusChanged = exports.onSessionRequestAccepted = exports.sendNotification = void 0;
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
var commissions_1 = require("./payments/commissions");
Object.defineProperty(exports, "processWeeklyCommissions", { enumerable: true, get: function () { return commissions_1.processWeeklyCommissions; } });
Object.defineProperty(exports, "markCommissionPaid", { enumerable: true, get: function () { return commissions_1.markCommissionPaid; } });
// Admin functions
var adminActions_1 = require("./admin/adminActions");
Object.defineProperty(exports, "setUserRole", { enumerable: true, get: function () { return adminActions_1.setUserRole; } });
Object.defineProperty(exports, "suspendUser", { enumerable: true, get: function () { return adminActions_1.suspendUser; } });
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
//# sourceMappingURL=index.js.map