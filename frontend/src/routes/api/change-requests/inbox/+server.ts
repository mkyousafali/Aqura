import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient } from '$lib/server/breakRegisterAuth';
import { cashierInBranch } from '$lib/server/cashierChangeBranch';

export const GET: RequestHandler = async ({ request, url }) => {
  const userId = request.headers.get('x-cashier-user-id');
  const token = request.headers.get('x-cashier-session-token');
  const branchId = Number(url.searchParams.get('branchId'));
  if (!userId || !token || !Number.isSafeInteger(branchId) || branchId <= 0) return json({ error: 'Invalid cashier session.' }, { status: 400 });
  try {
    const db = databaseClient();
    const { data: session, error: authError } = await db.rpc('heartbeat_cashier_session', {
      p_user_id: userId, p_session_token: token
    });
    if (authError || session?.valid !== true) return json({ error: 'Cashier session expired.' }, { status: 401 });
    if (!await cashierInBranch(db, userId, branchId)) return json({ error: 'Cashier branch mismatch.' }, { status: 403 });
    const { data, error } = await db.from('aqura_change_requests')
      .select('id,request_number,requested_to_user_id,denomination_counts,total_amount,status,requested_at,withdrawal_counts,withdrawal_total,cashier_confirmed_at')
      .eq('requested_by_user_id', userId).eq('branch_id', branchId)
      .in('status', ['Ready for Cashier Confirmation', 'Cashier Confirmed'])
      .order('requested_at', { ascending: false }).limit(30);
    if (error) throw error;
    const recipientIds = [...new Set((data || []).map(item => item.requested_to_user_id))];
    const { data: employees } = recipientIds.length
      ? await db.from('hr_employee_master').select('user_id,name_en,name_ar').in('user_id', recipientIds)
      : { data: [] };
    const names = new Map((employees || []).map(item => [item.user_id, { name_en: item.name_en, name_ar: item.name_ar }]));
    return json((data || []).map(item => ({ ...item, safeBoxUser: names.get(item.requested_to_user_id) || null })),
      { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    console.error('Cashier change request inbox failed:', error);
    return json({ error: 'Could not load change request updates.' }, { status: 500 });
  }
};
