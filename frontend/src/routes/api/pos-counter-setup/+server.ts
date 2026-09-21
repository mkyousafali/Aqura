import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient } from '$lib/server/breakRegisterAuth';
import { cashierInBranch } from '$lib/server/cashierChangeBranch';
import { safeBoxSchemaUnavailable } from '$lib/server/safeBoxControl';

export const GET: RequestHandler = async ({ request }) => {
  const userId = request.headers.get('x-cashier-user-id');
  const sessionToken = request.headers.get('x-cashier-session-token');
  const branchId = Number(request.headers.get('x-cashier-branch-id'));
  if (!userId || !sessionToken || !Number.isSafeInteger(branchId) || branchId <= 0)
    return json({ error: 'Cashier session and branch required.' }, { status: 401 });
  try {
    const db = databaseClient();
    const { data: session, error: sessionError } = await db.rpc('heartbeat_cashier_session', {
      p_user_id: userId, p_session_token: sessionToken
    });
    if (sessionError || session?.valid !== true) return json({ error: 'Cashier session expired.' }, { status: 401 });
    const { data: user, error: userError } = await db.from('users').select('status,is_master_admin').eq('id', userId).maybeSingle();
    if (userError || user?.status !== 'active') return json({ error: 'Cashier account unavailable.' }, { status: 401 });
    if (!await cashierInBranch(db, userId, branchId)) return json({ error: 'Cashier branch mismatch.' }, { status: 403 });
    if (user.is_master_admin !== true) {
      const { data: grant, error: grantError } = await db.from('aqura_safe_box_permissions').select('id')
        .eq('user_id', userId).eq('branch_id', branchId).eq('permission_type', 'printer').maybeSingle();
      if (grantError && !safeBoxSchemaUnavailable(grantError)) throw grantError;
      if (!grant) return json({ error: 'Printer settings access required.' }, { status: 403 });
    }
    const { data, error } = await db.from('erp_counters').select('counter_id,counter_name,branch_id')
      .eq('branch_id', branchId).order('counter_id');
    if (error) throw error;
    const counters = (data || []).filter(counter => /^POS[\s-]*\d+/i.test(counter.counter_name || ''))
      .map(counter => ({ id: counter.counter_id, name: counter.counter_name,
        number: (counter.counter_name || '').match(/^POS[\s-]*(\d+)/i)?.[1] || String(counter.counter_id) }));
    return json({ branchId, counters }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    console.error('POS counter setup failed:', error);
    return json({ error: 'Could not load POS counters.' }, { status: 500 });
  }
};
