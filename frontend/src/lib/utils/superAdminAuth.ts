import { writable, get } from 'svelte/store';
import type { UserSession } from '$lib/utils/persistentAuth';

export const SUPER_ADMIN_CREDENTIALS = {
  username: 'yousafalimkimanihayath@966548357066XYZ',
  password: '@#Imanihayath120',
  securityQuestion: 'What is 1 + 25?',
  securityAnswer: '999'
} as const;

export const SUPER_ADMIN_SESSION: UserSession = {
  id: 'super-admin-hardcoded-id',
  username: SUPER_ADMIN_CREDENTIALS.username,
  isMasterAdmin: true,
  isAdmin: true,
  userType: 'global',
  employeeName: 'Super Admin',
  branchName: 'Headquarters',
  loginTime: new Date().toISOString(),
  deviceId: 'super-admin-device',
  loginMethod: 'password',
  isActive: true
};

export function isSuperAdminSession(user: UserSession | null | undefined): boolean {
  if (!user) return false;
  return user.id === SUPER_ADMIN_SESSION.id || user.username === SUPER_ADMIN_CREDENTIALS.username;
}
