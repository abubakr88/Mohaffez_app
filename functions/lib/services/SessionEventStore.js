"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SessionEventStore = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const events_types_1 = require("../types/events.types");
class SessionEventStore {
    async appendEvent(event) {
        const ref = admin_1.db.collection('sessionEvents').doc();
        await ref.set(Object.assign(Object.assign({}, event), { eventId: ref.id, timestamp: require('../utils/admin').FieldValue.serverTimestamp() }));
        functions.logger.info('Session event appended', {
            eventId: ref.id,
            eventType: event.eventType,
            toStatus: event.toStatus,
            requestId: event.requestId,
            sessionId: event.sessionId,
        });
        return ref.id;
    }
    async appendInsideTransaction(transaction, event) {
        const ref = admin_1.db.collection('sessionEvents').doc();
        transaction.set(ref, Object.assign(Object.assign({}, event), { eventId: ref.id, timestamp: require('../utils/admin').FieldValue.serverTimestamp() }));
    }
}
exports.SessionEventStore = SessionEventStore;
void events_types_1.SessionRequestEventType;
void events_types_1.SessionEventType;
//# sourceMappingURL=SessionEventStore.js.map