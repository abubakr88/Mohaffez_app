"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificationService = void 0;
const admin_1 = require("../utils/admin");
const payment_types_1 = require("../types/payment.types");
class NotificationService {
    async send(payload) {
        var _a;
        await admin_1.db.collection('notifications').add({
            recipientId: payload.recipientId,
            senderId: payload.senderId,
            type: payload.type,
            title: payload.title,
            message: payload.message,
            body: payload.message,
            data: (_a = payload.data) !== null && _a !== void 0 ? _a : {},
            isRead: false,
            createdAt: (0, payment_types_1.serverTimestamp)(),
        });
    }
}
exports.NotificationService = NotificationService;
//# sourceMappingURL=NotificationService.js.map