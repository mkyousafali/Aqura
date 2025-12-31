/**
 * Permission Utility Functions
 * Provides centralized permission checking for all features
 * 
 * Usage:
 *   import { hasPermission, canCreate, canView } from '$lib/utils/permissions';
 *   
 *   if (hasPermission('USER_MGMT', 'can_edit')) {
 *     // Show edit button
 *   }
 *   
 *   if (canCreate('BRANCH_MASTER')) {
 *     // Show create form
 *   }
 */

import { get } from 'svelte/store';
import { currentUser } from './persistentAuth';

/**
 * Function codes for all system functions
 * Used to check permissions and control UI visibility
 */
export const FUNCTION_CODES = {
  // Administration
  DASHBOARD: 'DASHBOARD',
  USER_MGMT: 'USER_MGMT',
  SETTINGS: 'SETTINGS',

  // Master Data
  BRANCH_MASTER: 'BRANCH_MASTER',
  HR_MASTER: 'HR_MASTER',
  TASK_MASTER: 'TASK_MASTER',

  // Operations
  RECEIVING_MGMT: 'RECEIVING_MGMT',
  VENDOR_MGMT: 'VENDOR_MGMT',
  PURCHASE_ORDERS: 'PURCHASE_ORDERS',
  INVENTORY_CTRL: 'INVENTORY_CTRL',

  // Finance
  EXPENSE_MGMT: 'EXPENSE_MGMT',
  REQUISITION_MGMT: 'REQUISITION_MGMT',
  PAYMENT_SCHEDULER: 'PAYMENT_SCHEDULER',
  BUDGET_TRACKING: 'BUDGET_TRACKING',
  FINANCIAL_REPORTS: 'FINANCIAL_REPORTS',

  // Customer
  CUSTOMER_MGMT: 'CUSTOMER_MGMT',
  CUSTOMER_REG: 'CUSTOMER_REG',
  CUSTOMER_RECOVERY: 'CUSTOMER_RECOVERY',
  CUSTOMER_ACCESS: 'CUSTOMER_ACCESS',

  // Product
  PRODUCT_MGMT: 'PRODUCT_MGMT',
  PRODUCT_CATEGORIES: 'PRODUCT_CATEGORIES',
  PRODUCT_UNITS: 'PRODUCT_UNITS',
  TAX_CATEGORIES: 'TAX_CATEGORIES',
  PRICE_MGMT: 'PRICE_MGMT',

  // Offers & Promotions
  OFFER_MGMT: 'OFFER_MGMT',
  BUNDLE_OFFERS: 'BUNDLE_OFFERS',
  BOGO_OFFERS: 'BOGO_OFFERS',
  CART_TIER_OFFERS: 'CART_TIER_OFFERS',
  COUPON_MGMT: 'COUPON_MGMT',
  COUPON_REDEMPTION: 'COUPON_REDEMPTION',

  // Notifications
  NOTIFICATION_CENTER: 'NOTIFICATION_CENTER',
  PUSH_NOTIFICATIONS: 'PUSH_NOTIFICATIONS',
  NOTIFICATION_QUEUE: 'NOTIFICATION_QUEUE',
  NOTIFICATION_TEMPLATES: 'NOTIFICATION_TEMPLATES',

  // Reports
  SALES_REPORTS: 'SALES_REPORTS',
  HR_REPORTS: 'HR_REPORTS',
  INVENTORY_REPORTS: 'INVENTORY_REPORTS',
  CUSTOMER_REPORTS: 'CUSTOMER_REPORTS',

  // System
  AUDIT_LOGS: 'AUDIT_LOGS',
  SESSION_MGMT: 'SESSION_MGMT',
  DEVICE_MGMT: 'DEVICE_MGMT',
  BACKUP_RESTORE: 'BACKUP_RESTORE'
} as const;

/**
 * Permission action types
 */
export type PermissionAction = 'can_view' | 'can_add' | 'can_edit' | 'can_delete' | 'can_export';

/**
 * User permissions structure
 */
export interface UserPermissions {
  [functionCode: string]: {
    can_view: boolean;
    can_add: boolean;
    can_edit: boolean;
    can_delete: boolean;
    can_export: boolean;
  };
}

/**
 * Check if current user has permission for a function
 * 
 * @param functionCode - Function code to check (e.g., 'USER_MGMT')
 * @param action - Action to check (e.g., 'can_view', 'can_edit')
 * @returns true if user has permission, false otherwise
 * 
 * Backward compatibility: If user doesn't have explicit permissions,
 * falls back to role type checks (Master Admin/Admin have full access)
 */
export function hasPermission(functionCode: string, action: PermissionAction): boolean {
  const user = get(currentUser);

  if (!user) {
    return false;
  }

  // Master Admin and Admin always have full access (backward compatibility)
  if (user.isMasterAdmin || user.isAdmin) {
    // However, only Master Admin can delete
    if (action === 'can_delete' && user.isAdmin && !user.isMasterAdmin) {
      return false;
    }
    return true;
  }

  // Check explicit permissions if user has them
  if (user.permissions && user.permissions[functionCode]) {
    return user.permissions[functionCode][action] === true;
  }

  // No permission found
  return false;
}

/**
 * Check if user can VIEW a function
 */
export function canView(functionCode: string): boolean {
  return hasPermission(functionCode, 'can_view');
}

/**
 * Check if user can CREATE in a function
 */
export function canCreate(functionCode: string): boolean {
  return hasPermission(functionCode, 'can_add');
}

/**
 * Check if user can EDIT in a function
 */
export function canEdit(functionCode: string): boolean {
  return hasPermission(functionCode, 'can_edit');
}

/**
 * Check if user can DELETE in a function
 */
export function canDelete(functionCode: string): boolean {
  return hasPermission(functionCode, 'can_delete');
}

/**
 * Check if user can EXPORT from a function
 */
export function canExport(functionCode: string): boolean {
  return hasPermission(functionCode, 'can_export');
}

/**
 * Get all permissions for a function
 */
export function getPermissions(functionCode: string) {
  const user = get(currentUser);

  if (!user) {
    return {
      can_view: false,
      can_add: false,
      can_edit: false,
      can_delete: false,
      can_export: false
    };
  }

  // Master Admin full access
  if (user.isMasterAdmin) {
    return {
      can_view: true,
      can_add: true,
      can_edit: true,
      can_delete: true,
      can_export: true
    };
  }

  // Admin access (no delete)
  if (user.isAdmin) {
    return {
      can_view: true,
      can_add: true,
      can_edit: true,
      can_delete: false,
      can_export: true
    };
  }

  // Explicit permissions
  if (user.permissions && user.permissions[functionCode]) {
    return user.permissions[functionCode];
  }

  // Default: no access
  return {
    can_view: false,
    can_add: false,
    can_edit: false,
    can_delete: false,
    can_export: false
  };
}

/**
 * Check if user is admin (Master Admin or Admin)
 */
export function isAdmin(): boolean {
  const user = get(currentUser);
  return (user?.isMasterAdmin || user?.isAdmin) ?? false;
}

/**
 * Check if user is Master Admin
 */
export function isMasterAdmin(): boolean {
  const user = get(currentUser);
  return user?.isMasterAdmin ?? false;
}

/**
 * Get user's username
 */
export function getUsername(): string | undefined {
  const user = get(currentUser);
  return user?.username;
}

/**
 * Check if user has ANY permission for a function
 * (can perform at least one action)
 */
export function hasAnyPermission(functionCode: string): boolean {
  const perms = getPermissions(functionCode);
  return perms.can_view || perms.can_add || perms.can_edit || perms.can_delete || perms.can_export;
}

/**
 * Get a list of functions the user can access
 */
export function getAccessibleFunctions(): string[] {
  const user = get(currentUser);

  if (!user) {
    return [];
  }

  // Master Admin and Admin have access to all
  if (user.isMasterAdmin || user.isAdmin) {
    return Object.values(FUNCTION_CODES);
  }

  // For position-based users, return functions they have access to
  if (user.permissions) {
    return Object.keys(user.permissions).filter(code => hasAnyPermission(code));
  }

  return [];
}

/**
 * Format permission for display
 */
export function formatPermission(action: PermissionAction): string {
  const labels: Record<PermissionAction, string> = {
    can_view: 'View',
    can_add: 'Create',
    can_edit: 'Edit',
    can_delete: 'Delete',
    can_export: 'Export'
  };
  return labels[action];
}
