"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BookingEventType = exports.PaymentEventType = void 0;
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
var BookingEventType;
(function (BookingEventType) {
    BookingEventType["BOOKING_CONFIRMED"] = "booking_confirmed";
    BookingEventType["BOOKING_PAID"] = "booking_paid";
})(BookingEventType || (exports.BookingEventType = BookingEventType = {}));
//# sourceMappingURL=events.types.js.map