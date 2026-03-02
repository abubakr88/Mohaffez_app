"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BookingEventType = exports.SessionEventType = exports.SessionRequestEventType = exports.PaymentEventType = void 0;
var PaymentEventType;
(function (PaymentEventType) {
    PaymentEventType["PAYMENT_CREATED"] = "payment_created";
    PaymentEventType["PAYMENT_PROCESSING"] = "payment_processing";
    PaymentEventType["PAYMENT_COMPLETED"] = "payment_completed";
    PaymentEventType["PAYMENT_FAILED"] = "payment_failed";
    PaymentEventType["WEBHOOK_RECEIVED"] = "webhook_received";
    PaymentEventType["SUBSCRIPTION_CREATED"] = "subscription_created";
    PaymentEventType["BOOKING_CONFIRMED"] = "booking_confirmed";
})(PaymentEventType || (exports.PaymentEventType = PaymentEventType = {}));
var SessionRequestEventType;
(function (SessionRequestEventType) {
    SessionRequestEventType["REQUEST_CREATED"] = "request_created";
    SessionRequestEventType["AWAITING_PAYMENT"] = "awaiting_payment";
    SessionRequestEventType["AWAITING_DIRECT"] = "awaiting_direct_payment";
    SessionRequestEventType["ACCEPTED"] = "accepted";
    SessionRequestEventType["REJECTED"] = "rejected";
    SessionRequestEventType["CANCELLED"] = "cancelled";
    SessionRequestEventType["EXPIRED"] = "expired";
})(SessionRequestEventType || (exports.SessionRequestEventType = SessionRequestEventType = {}));
var SessionEventType;
(function (SessionEventType) {
    SessionEventType["SESSION_CREATED"] = "session_created";
    SessionEventType["SESSION_COMPLETED"] = "session_completed";
})(SessionEventType || (exports.SessionEventType = SessionEventType = {}));
var BookingEventType;
(function (BookingEventType) {
    BookingEventType["BOOKING_CONFIRMED"] = "booking_confirmed";
    BookingEventType["BOOKING_PAID"] = "booking_paid";
})(BookingEventType || (exports.BookingEventType = BookingEventType = {}));
//# sourceMappingURL=events.types.js.map