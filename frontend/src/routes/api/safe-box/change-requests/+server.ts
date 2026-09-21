import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient } from '$lib/server/breakRegisterAuth';
import { safeBoxAccess } from '$lib/server/safeBoxControl';

export const GET: RequestHandler = async ({ cookies }) => {
  try {
    const access = await safeBoxAccess(cookies);
    if (!access.canRequests) return json({ error: 'Safe Box request access denied.' }, { status: 403 });
    const userId = access.userId;
    const db = databaseClient();
    const { data: requests, error } = await db.from('aqura_change_requests')
      .select('id,request_number,requested_by_user_id,branch_id,denomination_counts,total_amount,status,requested_at,received_counts,received_total,withdrawal_counts,withdrawal_total')
      .eq('requested_to_user_id', userId).eq('branch_id', access.branchId).in('status', ['Pending', 'Cash Received', 'Safe Box Printed'])
      .order('requested_at', { ascending: false });
    if (error) throw error;
    const senderIds = [...new Set((requests || []).map(row => row.requested_by_user_id))];
    const branchIds = [...new Set((requests || []).map(row => row.branch_id))];
    const [{ data: senders }, { data: employees }, { data: branches }] = await Promise.all([
      senderIds.length ? db.from('users').select('id,username').in('id', senderIds) : Promise.resolve({ data: [] }),
      senderIds.length ? db.from('hr_employee_master').select('user_id,name_en,name_ar').in('user_id', senderIds) : Promise.resolve({ data: [] }),
      branchIds.length ? db.from('branches').select('id,name_en,name_ar,location_en,location_ar').in('id', branchIds) : Promise.resolve({ data: [] })
    ]);
    const userNames = new Map((senders || []).map(row => [row.id, row.username]));
    const employeeNames = new Map((employees || []).map(row => [row.user_id, row.name_en || row.name_ar]));
    const branchNames = new Map((branches || []).map(row => [row.id, [row.name_en || row.name_ar, row.location_en || row.location_ar].filter(Boolean).join(' - ')]));
    return json((requests || []).map(row => ({
      id: row.id,
      requestNumber: row.request_number,
      requestedBy: employeeNames.get(row.requested_by_user_id) || userNames.get(row.requested_by_user_id) || 'Cashier',
      branch: branchNames.get(row.branch_id) || `Branch ${row.branch_id}`,
      denominationCounts: row.denomination_counts,
      totalAmount: row.total_amount,
      status: row.status,
      requestedAt: row.requested_at,
      receivedCounts: row.received_counts,
      receivedTotal: row.received_total,
      withdrawalCounts: row.withdrawal_counts,
      withdrawalTotal: row.withdrawal_total,
      requestedByUserId: row.requested_by_user_id
    })));
  } catch (error) {
    console.error('Safe Box request load failed:', error);
    return json({ error: 'Unable to load assigned requests' }, { status: 401 });
  }
};
