import * as functions from 'firebase-functions';
import { db } from './admin';

export type AdminRole = 'super_admin' | 'admin';

export type AdminPermission =
  | 'manageUsers'
  | 'manageUserRoles'
  | 'deleteUsers'
  | 'manageAdminAccess'
  | 'reviewTeachers'
  | 'manageFinance'
  | 'sendBroadcasts'
  | 'runMaintenance';

export const ADMIN_PERMISSION_LABELS: Record<AdminPermission, string> = {
  manageUsers: 'إدارة المستخدمين',
  manageUserRoles: 'تغيير أدوار المستخدمين',
  deleteUsers: 'حذف المستخدمين',
  manageAdminAccess: 'إدارة صلاحيات الأدمنز',
  reviewTeachers: 'مراجعة المحفظين',
  manageFinance: 'العمليات المالية',
  sendBroadcasts: 'الإشعارات الجماعية',
  runMaintenance: 'تشغيل الصيانة',
};

export const ALL_ADMIN_PERMISSIONS: AdminPermission[] = [
  'manageUsers',
  'manageUserRoles',
  'deleteUsers',
  'manageAdminAccess',
  'reviewTeachers',
  'manageFinance',
  'sendBroadcasts',
  'runMaintenance',
];

export const DEFAULT_ADMIN_PERMISSIONS: Record<AdminPermission, boolean> = {
  manageUsers: true,
  manageUserRoles: false,
  deleteUsers: false,
  manageAdminAccess: false,
  reviewTeachers: true,
  manageFinance: false,
  sendBroadcasts: true,
  runMaintenance: false,
};

export const SUPER_ADMIN_PERMISSIONS: Record<AdminPermission, boolean> =
  ALL_ADMIN_PERMISSIONS.reduce(
    (acc, permission) => ({ ...acc, [permission]: true }),
    {} as Record<AdminPermission, boolean>,
  );

export interface AdminAccess {
  uid: string;
  role: AdminRole;
  permissions: Record<AdminPermission, boolean>;
}

export function normalizeAdminRole(value: unknown): AdminRole {
  return value === 'admin' ? 'admin' : 'super_admin';
}

export function normalizeAdminPermissions(
  role: AdminRole,
  raw: unknown,
): Record<AdminPermission, boolean> {
  if (role === 'super_admin') return { ...SUPER_ADMIN_PERMISSIONS };

  const source =
    raw != null && typeof raw === 'object'
      ? (raw as Record<string, unknown>)
      : {};

  return ALL_ADMIN_PERMISSIONS.reduce(
    (acc, permission) => ({
      ...acc,
      [permission]:
        permission === 'manageAdminAccess'
          ? false
          : typeof source[permission] === 'boolean'
          ? (source[permission] as boolean)
          : DEFAULT_ADMIN_PERMISSIONS[permission],
    }),
    {} as Record<AdminPermission, boolean>,
  );
}

export async function getAdminAccess(
  context: functions.https.CallableContext,
): Promise<AdminAccess> {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
  }

  const isAdminClaim =
    context.auth?.token.admin === true || context.auth?.token.role === 'admin';
  if (!isAdminClaim) {
    throw new functions.https.HttpsError('permission-denied', 'غير مصرح');
  }

  const doc = await db.collection('users').doc(uid).get();
  const data = doc.data();
  if (data?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'غير مصرح');
  }

  const role = normalizeAdminRole(data.adminRole);
  return {
    uid,
    role,
    permissions: normalizeAdminPermissions(role, data.adminPermissions),
  };
}

export async function requireAdminAccess(
  context: functions.https.CallableContext,
  permission?: AdminPermission,
): Promise<AdminAccess> {
  const access = await getAdminAccess(context);
  if (permission != null && access.permissions[permission] !== true) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'ليست لديك صلاحية تنفيذ هذه العملية',
    );
  }
  return access;
}

export async function requireSuperAdminAccess(
  context: functions.https.CallableContext,
): Promise<AdminAccess> {
  const access = await getAdminAccess(context);
  if (access.role !== 'super_admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'هذه العملية متاحة للسوبر أدمن فقط',
    );
  }
  return access;
}

export function sanitizePermissionInput(
  raw: unknown,
): Record<AdminPermission, boolean> {
  const source =
    raw != null && typeof raw === 'object'
      ? (raw as Record<string, unknown>)
      : {};

  return ALL_ADMIN_PERMISSIONS.reduce(
    (acc, permission) => ({
      ...acc,
      [permission]:
        permission === 'manageAdminAccess' ? false : source[permission] === true,
    }),
    {} as Record<AdminPermission, boolean>,
  );
}
