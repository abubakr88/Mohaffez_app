import * as functions from 'firebase-functions';
import { db } from '../utils/admin';
import { SessionEvent, SessionRequestEventType, SessionEventType } from '../types/events.types';

export class SessionEventStore {
  async appendEvent(event: Omit<SessionEvent, 'eventId' | 'timestamp'>): Promise<string> {
    const ref = db.collection('sessionEvents').doc();
    await ref.set({
      ...event,
      eventId: ref.id,
      timestamp: require('../utils/admin').FieldValue.serverTimestamp(),
    });
    functions.logger.info('Session event appended', {
      eventId: ref.id,
      eventType: event.eventType,
      toStatus: event.toStatus,
      requestId: event.requestId,
      sessionId: event.sessionId,
    });
    return ref.id;
  }

  async appendInsideTransaction(
    transaction: FirebaseFirestore.Transaction,
    event: Omit<SessionEvent, 'eventId' | 'timestamp'>
  ): Promise<void> {
    const ref = db.collection('sessionEvents').doc();
    transaction.set(ref, {
      ...event,
      eventId: ref.id,
      timestamp: require('../utils/admin').FieldValue.serverTimestamp(),
    });
  }
}

void SessionRequestEventType;
void SessionEventType;
