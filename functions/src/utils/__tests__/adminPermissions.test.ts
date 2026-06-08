import { describe, expect, it } from 'vitest';
import {
  normalizeAdminPermissions,
  sanitizePermissionInput,
} from '../adminPermissions';

describe('Admin permission normalization', () => {
  it('grants every permission to super admin', () => {
    const permissions = normalizeAdminPermissions('super_admin', {});

    expect(Object.values(permissions).every((value) => value === true)).toBe(
      true,
    );
    expect(permissions.manageAdminAccess).toBe(true);
  });

  it('uses safe defaults for limited admins', () => {
    const permissions = normalizeAdminPermissions('admin', {});

    expect(permissions.manageUsers).toBe(true);
    expect(permissions.reviewTeachers).toBe(true);
    expect(permissions.sendBroadcasts).toBe(true);
    expect(permissions.manageUserRoles).toBe(false);
    expect(permissions.deleteUsers).toBe(false);
    expect(permissions.manageAdminAccess).toBe(false);
    expect(permissions.manageFinance).toBe(false);
    expect(permissions.runMaintenance).toBe(false);
  });

  it('never grants admin-access management to limited admins from stored data', () => {
    const permissions = normalizeAdminPermissions('admin', {
      deleteUsers: true,
      manageAdminAccess: true,
      manageFinance: true,
    });

    expect(permissions.deleteUsers).toBe(true);
    expect(permissions.manageFinance).toBe(true);
    expect(permissions.manageAdminAccess).toBe(false);
  });

  it('strips admin-access management from callable input', () => {
    const permissions = sanitizePermissionInput({
      manageUsers: true,
      manageAdminAccess: true,
      runMaintenance: true,
    });

    expect(permissions.manageUsers).toBe(true);
    expect(permissions.runMaintenance).toBe(true);
    expect(permissions.manageAdminAccess).toBe(false);
  });
});
