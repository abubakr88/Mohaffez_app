import * as functions from 'firebase-functions';
import { db, FieldValue } from './admin';

export interface AdminAuditLogInput {
  action: string;
  actorId: string;
  targetUserId?: string | null;
  targetId?: string | null;
  targetType?: string | null;
  reason?: string | null;
  data?: Record<string, unknown> | null;
  before?: Record<string, unknown> | null;
  after?: Record<string, unknown> | null;
  context?: functions.https.CallableContext;
}

export async function writeAdminAuditLog(
  input: AdminAuditLogInput,
): Promise<void> {
  const request = input.context?.rawRequest;
  const forwardedFor = request?.headers['x-forwarded-for'];
  const ip =
    typeof forwardedFor === 'string'
      ? forwardedFor.split(',')[0]?.trim() || null
      : Array.isArray(forwardedFor)
        ? forwardedFor[0]?.split(',')[0]?.trim() || null
        : request?.ip ?? null;
  const userAgent = request?.headers['user-agent'] ?? null;

  await db.collection('adminAuditLog').add({
    action: input.action,
    actorId: input.actorId,
    performedBy: input.actorId,
    targetUserId: input.targetUserId ?? null,
    targetId: input.targetId ?? input.targetUserId ?? null,
    targetType: input.targetType ?? null,
    reason: input.reason ?? null,
    data: input.data ?? null,
    before: input.before ?? null,
    after: input.after ?? null,
    request: {
      ip,
      userAgent,
    },
    timestamp: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  });
}
