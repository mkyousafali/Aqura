import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

export const GET: RequestHandler = async ({ cookies, url }) => {
  try {
    const actor = await requireBreakUser(cookies, 'desktop');
    if (!actor.isMasterAdmin) return json({ error: 'Master Admin access required.' }, { status: 403 });
    const branchId = Number(url.searchParams.get('branchId'));
    const term = (url.searchParams.get('search') || '').trim();
    if (!Number.isSafeInteger(branchId) || branchId <= 0 || term.length < 1 || term.length > 100) {
      return json({ users: [] });
    }
    const db = databaseClient();
    const pattern = `%${term.replace(/[%_]/g, '\\$&')}%`;
    const [english, arabic, employeeId] = await Promise.all([
      db.from('hr_employee_master').select('user_id,id,name_en,name_ar').eq('current_branch_id', branchId).ilike('name_en', pattern).limit(25),
      db.from('hr_employee_master').select('user_id,id,name_en,name_ar').eq('current_branch_id', branchId).ilike('name_ar', pattern).limit(25),
      db.from('hr_employee_master').select('user_id,id,name_en,name_ar').eq('current_branch_id', branchId).ilike('id', pattern).limit(25)
    ]);
    if (english.error || arabic.error || employeeId.error) throw english.error || arabic.error || employeeId.error;
    const employees = [...new Map([...(english.data || []), ...(arabic.data || []), ...(employeeId.data || [])]
      .map(item => [item.user_id, item])).values()];
    if (!employees.length) return json({ users: [] });
    const { data: active, error } = await db.from('users').select('id').eq('status', 'active')
      .in('id', employees.map(item => item.user_id));
    if (error) throw error;
    const activeIds = new Set((active || []).map(item => item.id));
    return json({ users: employees.filter(item => activeIds.has(item.user_id)).slice(0, 30) },
      { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Could not search branch users.' }, { status: 403 });
  }
};
