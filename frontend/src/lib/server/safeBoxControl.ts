import type { Cookies } from '@sveltejs/kit';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

export type SafeBoxAccess = {
  userId: string;
  branchId: number;
  isMasterAdmin: boolean;
  canRequests: boolean;
  canBalance: boolean;
  canManagement: boolean;
  canPrinter: boolean;
  controlReady: boolean;
};

const activeRequestStatuses = ['Pending', 'Cash Received', 'Safe Box Printed'];
export const safeBoxSchemaUnavailable = (error: { code?: string; message?: string } | null) =>
  error?.code === '42P01' || error?.code === 'PGRST205' ||
  /could not find the table.*aqura_safe_box_permissions/i.test(error?.message || '');

export async function safeBoxAccess(cookies: Cookies): Promise<SafeBoxAccess> {
  const user = await requireBreakUser(cookies, 'desktop');
  const db = databaseClient();
  const { data: employee, error: employeeError } = await db.from('hr_employee_master')
    .select('current_branch_id').eq('user_id', user.id).maybeSingle();
  if (employeeError || !employee?.current_branch_id) throw new Error('No current branch is assigned to this user.');
  const branchId = Number(employee.current_branch_id);
  const { data: grants, error: grantsError } = await db.from('aqura_safe_box_permissions')
    .select('permission_type').eq('user_id', user.id).eq('branch_id', branchId);
  if (safeBoxSchemaUnavailable(grantsError)) {
    return { userId: user.id, branchId, isMasterAdmin: user.isMasterAdmin,
      canRequests: true, canBalance: true, canManagement: false, canPrinter: user.isMasterAdmin,
      controlReady: false };
  }
  if (grantsError) throw grantsError;
  const permissions = new Set((grants || []).map(item => item.permission_type));
  const receiver = permissions.has('receiver');
  const depositor = permissions.has('depositor');
  const printer = permissions.has('printer');
  let hasAssignedRequest = false;
  if (receiver && !user.isMasterAdmin) {
    const { data: request, error: requestError } = await db.from('aqura_change_requests')
      .select('id').eq('requested_to_user_id', user.id).eq('branch_id', branchId)
      .in('status', activeRequestStatuses).limit(1).maybeSingle();
    if (requestError) throw requestError;
    hasAssignedRequest = !!request;
  }
  const canRequests = user.isMasterAdmin || (receiver && hasAssignedRequest);
  const canManagement = user.isMasterAdmin || depositor;
  const canPrinter = user.isMasterAdmin || printer;
  const canBalance = user.isMasterAdmin || canManagement || canRequests;
  if (!canRequests && !canManagement && !canPrinter) {
    throw new Error(receiver ? 'No pending Safe Box request is assigned to you.' : 'Safe Box access is not assigned to you.');
  }
  return { userId: user.id, branchId, isMasterAdmin: user.isMasterAdmin,
    canRequests, canBalance, canManagement, canPrinter, controlReady: true };
}

export async function isSafeBoxReceiver(db: ReturnType<typeof databaseClient>, userId: string, branchId: number): Promise<boolean> {
  const { data, error } = await db.from('aqura_safe_box_permissions').select('id')
    .eq('user_id', userId).eq('branch_id', branchId).eq('permission_type', 'receiver').maybeSingle();
  if (safeBoxSchemaUnavailable(error)) return true;
  if (error) throw error;
  return !!data;
}
