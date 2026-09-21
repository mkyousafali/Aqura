import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';
import { safeBoxSchemaUnavailable } from '$lib/server/safeBoxControl';

const types = new Set(['receiver', 'depositor', 'printer']);

async function requireMaster(cookies: Parameters<typeof requireBreakUser>[0]) {
  const actor = await requireBreakUser(cookies, 'desktop');
  if (!actor.isMasterAdmin) throw new Error('Master Admin access required.');
  return actor;
}

export const GET: RequestHandler = async ({ cookies }) => {
  try {
    await requireMaster(cookies);
    const db = databaseClient();
    const [{ data: grants, error: grantsError }, { data: branches, error: branchesError }] = await Promise.all([
      db.from('aqura_safe_box_permissions').select('id,branch_id,user_id,permission_type,added_by,created_at').order('created_at', { ascending: false }),
      db.from('branches').select('id,name_en,name_ar').order('id')
    ]);
    if (safeBoxSchemaUnavailable(grantsError)) {
      return json({ error: 'Safe Box Control setup is pending: the permission table has not been installed.' }, { status: 503 });
    }
    if (grantsError || branchesError) throw grantsError || branchesError;
    const ids = [...new Set((grants || []).flatMap(row => [row.user_id, row.added_by]))];
    const [{ data: users }, { data: employees }] = ids.length ? await Promise.all([
      db.from('users').select('id,username').in('id', ids),
      db.from('hr_employee_master').select('user_id,id,name_en,name_ar').in('user_id', ids)
    ]) : [{ data: [] }, { data: [] }];
    const names = new Map((users || []).map(row => [row.id, row.username]));
    const employeeNames = new Map((employees || []).map(row => [row.user_id, row]));
    return json({ branches, grants: (grants || []).map(row => ({ ...row,
      userName: employeeNames.get(row.user_id)?.name_en || employeeNames.get(row.user_id)?.name_ar || names.get(row.user_id) || row.user_id,
      employeeId: employeeNames.get(row.user_id)?.id || '',
      addedByName: employeeNames.get(row.added_by)?.name_en || employeeNames.get(row.added_by)?.name_ar || names.get(row.added_by) || row.added_by
    })) }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Could not load Safe Box permissions.' }, { status: 403 });
  }
};

export const POST: RequestHandler = async ({ cookies, request }) => {
  try {
    const actor = await requireMaster(cookies);
    const { branchId, userId, permissionType } = await request.json();
    if (!Number.isSafeInteger(Number(branchId)) || Number(branchId) <= 0 ||
      typeof userId !== 'string' || !/^[0-9a-f-]{36}$/i.test(userId) || !types.has(permissionType)) {
      return json({ error: 'Invalid branch, user, or permission.' }, { status: 400 });
    }
    const db = databaseClient();
    const [{ data: employee }, { data: user }] = await Promise.all([
      db.from('hr_employee_master').select('user_id').eq('user_id', userId).eq('current_branch_id', branchId).maybeSingle(),
      db.from('users').select('id,status').eq('id', userId).maybeSingle()
    ]);
    if (!employee || user?.status !== 'active') return json({ error: 'User is not active in the selected branch.' }, { status: 400 });
    const { error } = await db.from('aqura_safe_box_permissions').insert({
      branch_id: Number(branchId), user_id: userId, permission_type: permissionType, added_by: actor.id
    });
    if (error) return json({ error: error.code === '23505' ? 'This permission is already assigned.' : error.message }, { status: 409 });
    return json({ success: true }, { status: 201 });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Could not add permission.' }, { status: 403 });
  }
};

export const DELETE: RequestHandler = async ({ cookies, request }) => {
  try {
    await requireMaster(cookies);
    const { id } = await request.json();
    if (typeof id !== 'string' || !/^[0-9a-f-]{36}$/i.test(id)) return json({ error: 'Invalid permission.' }, { status: 400 });
    const { error } = await databaseClient().from('aqura_safe_box_permissions').delete().eq('id', id);
    if (error) throw error;
    return json({ success: true });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Could not remove permission.' }, { status: 403 });
  }
};
