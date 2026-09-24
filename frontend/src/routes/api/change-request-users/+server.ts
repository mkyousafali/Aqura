import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient } from '$lib/server/breakRegisterAuth';
import { cashierInBranch } from '$lib/server/cashierChangeBranch';
import { safeBoxSchemaUnavailable } from '$lib/server/safeBoxControl';

export const GET: RequestHandler = async ({ request, url }) => {
  const userId = request.headers.get('x-cashier-user-id');
  const sessionToken = request.headers.get('x-cashier-session-token');
  const term = (url.searchParams.get('search') || '').trim();
  const branchId = Number(url.searchParams.get('branchId'));
  if (!userId || !sessionToken || term.length > 100 || !Number.isSafeInteger(branchId) || branchId <= 0) {
    return json({ error: 'Invalid search or branch' }, { status: 400 });
  }
  try {
    const db = databaseClient();
    const { data: session, error: sessionError } = await db.rpc('heartbeat_cashier_session', {
      p_user_id: userId, p_session_token: sessionToken
    });
    if (sessionError || session?.valid !== true) return json({ error: 'Cashier session expired' }, { status: 401 });
    if (!await cashierInBranch(db, userId, branchId)) return json({ error: 'Cashier branch mismatch.' }, { status: 403 });
    const employeeResults = term
      ? await Promise.all([
          db.from('hr_employee_master').select('user_id,name_en,name_ar').eq('current_branch_id', branchId)
            .ilike('name_en', `%${term.replace(/[%_]/g, '\\$&')}%`).limit(30),
          db.from('hr_employee_master').select('user_id,name_en,name_ar').eq('current_branch_id', branchId)
            .ilike('name_ar', `%${term.replace(/[%_]/g, '\\$&')}%`).limit(30)
        ])
      : [await db.from('hr_employee_master').select('user_id,name_en,name_ar')
          .eq('current_branch_id', branchId).limit(100)];
    for (const result of employeeResults) if (result.error) throw result.error;
    const employees = [...new Map(employeeResults.flatMap(result => result.data || [])
      .map(item => [item.user_id, item])).values()];
    if (!employees.length) return json({ users: [] }, { headers: { 'Cache-Control': 'no-store' } });
    const employeeIds = employees.map(item => item.user_id);
    const [{ data: activeUsers, error }, { data: receivers, error: receiverError }] = await Promise.all([
      db.from('users').select('id').eq('status', 'active').in('id', employeeIds),
      db.from('aqura_safe_box_permissions').select('user_id').eq('branch_id', branchId)
        .eq('permission_type', 'receiver').in('user_id', employeeIds)
    ]);
    if (error || (receiverError && !safeBoxSchemaUnavailable(receiverError))) throw error || receiverError;
    const activeIds = new Set((activeUsers || []).map(item => item.id));
    const receiverIds = new Set((receivers || []).map(item => item.user_id));
    const users = employees.filter(item => activeIds.has(item.user_id) &&
      (safeBoxSchemaUnavailable(receiverError) || receiverIds.has(item.user_id)))
      .map(item => ({ id: item.user_id, name_en: item.name_en, name_ar: item.name_ar }))
      .sort((a, b) => (a.name_en || a.name_ar || '').localeCompare(b.name_en || b.name_ar || ''))
      .slice(0, 20);
    return json({ users }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    console.error('Change request user search failed:', error);
    return json({ error: 'Could not load users' }, { status: 500 });
  }
};
