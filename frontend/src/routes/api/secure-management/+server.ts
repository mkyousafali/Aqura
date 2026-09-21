import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

export const POST: RequestHandler = async ({ cookies, request }) => {
  try {
    const actor = await requireBreakUser(cookies, 'desktop');
    if (!actor.isAdmin && !actor.isMasterAdmin) return json({ error: 'Manager access denied' }, { status: 403 });
    const body = await request.json();
    const db = databaseClient();
    let result: { data: any; error: any };
    switch (body.action) {
      case 'createUser': {
        const u = body.user || {};
        result = await db.rpc('create_user', {
          p_username: u.username, p_password: u.password,
          p_is_master_admin: actor.isMasterAdmin && u.isMasterAdmin === true,
          p_is_admin: u.isAdmin === true, p_user_type: u.userType,
          p_branch_id: u.branchId || null, p_employee_id: u.employeeId || null,
          p_position_id: u.positionId || null, p_quick_access_code: u.quickAccessCode || null,
          p_requesting_user_id: actor.id
        });
        break;
      }
      case 'updateUser': {
        const u = body.updates || {};
        if (!actor.isMasterAdmin && u.p_is_master_admin === true) return json({ error: 'Master admin required' }, { status: 403 });
        result = await db.rpc('update_user', {
          p_user_id: body.userId, p_username: u.username ?? null,
          p_is_master_admin: actor.isMasterAdmin ? u.p_is_master_admin ?? null : null,
          p_is_admin: u.p_is_admin ?? null, p_user_type: u.user_type ?? null,
          p_branch_id: u.branch_id ?? null, p_employee_id: u.employee_id || null,
          p_position_id: u.position_id || null, p_status: u.status ?? null,
          p_avatar: u.avatar ?? null, p_requesting_user_id: actor.id
        });
        break;
      }
      case 'deactivateUser':
        result = await db.from('users').update({ status: 'inactive' }).eq('id', body.userId);
        break;
      case 'resetPassword': {
        if (typeof body.password !== 'string' || body.password.length < 6) return json({ error: 'Invalid password' }, { status: 400 });
        const salt = await db.rpc('generate_salt');
        if (salt.error) throw salt.error;
        const hash = await db.rpc('hash_password', { password: body.password, salt: salt.data });
        if (hash.error) throw hash.error;
        result = await db.from('users').update({ password_hash: hash.data, salt: salt.data,
          is_first_login: true, failed_login_attempts: 0,
          last_password_change: new Date().toISOString() }).eq('id', body.userId);
        break;
      }
      case 'generateCode': {
        const code = await db.rpc('generate_unique_quick_access_code');
        if (code.error) throw code.error;
        const salt = await db.rpc('generate_salt');
        if (salt.error) throw salt.error;
        const hash = await db.rpc('hash_password', { password: code.data, salt: salt.data });
        if (hash.error) throw hash.error;
        result = await db.from('users').update({ quick_access_code: hash.data, quick_access_salt: salt.data }).eq('id', body.userId);
        if (result.error) throw result.error;
        return json({ code: code.data });
      }
      case 'changeBranch': {
        if (body.branchId !== null && !Number.isInteger(body.branchId)) return json({ error: 'Invalid branch' }, { status: 400 });
        result = await db.from('users').update({ branch_id: body.branchId }).eq('id', body.userId);
        if (result.error) throw result.error;
        result = await db.from('hr_employee_master').update({ current_branch_id: body.branchId }).eq('user_id', body.userId);
        break;
      }
      case 'updateEmployee': {
        const u = body.employee || {};
        result = await db.rpc('update_employee_master_basic', {
          p_id: u.p_id, p_name_en: u.p_name_en ?? null, p_name_ar: u.p_name_ar ?? null,
          p_current_branch_id: u.p_current_branch_id ?? null,
          p_current_position_id: u.p_current_position_id ?? null,
          p_whatsapp_number: u.p_whatsapp_number ?? null, p_email: u.p_email ?? null
        });
        break;
      }
      case 'interfacePermission': {
        const p = body.permission || {};
        if (typeof p.user_id !== 'string') return json({ error: 'Invalid user' }, { status: 400 });
        const existing = await db.from('interface_permissions')
          .select('desktop_enabled,mobile_enabled,customer_enabled,cashier_enabled').eq('user_id', p.user_id).maybeSingle();
        if (existing.error) throw existing.error;
        result = await db.from('interface_permissions').upsert({
          user_id: p.user_id, desktop_enabled: p.desktop_enabled ?? existing.data?.desktop_enabled ?? true,
          mobile_enabled: p.mobile_enabled ?? existing.data?.mobile_enabled ?? true,
          customer_enabled: p.customer_enabled ?? existing.data?.customer_enabled ?? false,
          cashier_enabled: p.cashier_enabled ?? existing.data?.cashier_enabled ?? false, updated_by: actor.id,
          updated_at: new Date().toISOString()
        }, { onConflict: 'user_id' });
        break;
      }
      default: return json({ error: 'Unknown action' }, { status: 400 });
    }
    if (result.error) throw result.error;
    return json({ data: result.data, success: true });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Management update failed' }, { status: 403 });
  }
};
