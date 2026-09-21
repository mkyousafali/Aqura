import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

async function requireManager(cookies: Parameters<typeof requireBreakUser>[0]) {
	const user = await requireBreakUser(cookies, 'desktop');
	if (!user.isAdmin && !user.isMasterAdmin) throw new Error('Manager access denied');
	return user;
}

export const GET: RequestHandler = async ({ cookies }) => {
	try {
		await requireManager(cookies);
		const db = databaseClient();
		const [users, permissions, employees] = await Promise.all([
			db.from('users').select('id,username,employee_id').eq('status', 'active').order('username'),
			db.from('break_register_permissions').select('user_id,can_see_own_breaks,can_see_branch_breaks,can_see_all_breaks'),
			db.from('hr_employee_master').select('user_id,name_en,name_ar')
		]);
		if (users.error || permissions.error || employees.error) throw users.error || permissions.error || employees.error;
		const byPermission = new Map((permissions.data || []).map(row => [row.user_id, row]));
		const byEmployee = new Map((employees.data || []).map(row => [row.user_id, row]));
		return json({ rows: (users.data || []).map(user => {
			const permission = byPermission.get(user.id);
			const employee = byEmployee.get(user.id);
			return { user_id: user.id, username: user.username, employee_name_en: employee?.name_en || null,
				employee_name_ar: employee?.name_ar || null, can_see_own_breaks: true,
				can_see_branch_breaks: permission?.can_see_branch_breaks ?? false,
				can_see_all_breaks: permission?.can_see_all_breaks ?? false };
		}) });
	} catch {
		return json({ error: 'Manager access denied' }, { status: 403 });
	}
};

export const PUT: RequestHandler = async ({ cookies, request }) => {
	try {
		await requireManager(cookies);
		const body = await request.json();
		if (typeof body.user_id !== 'string' || typeof body.can_see_branch_breaks !== 'boolean' || typeof body.can_see_all_breaks !== 'boolean') {
			return json({ error: 'Invalid permission update' }, { status: 400 });
		}
		const { error } = await databaseClient().from('break_register_permissions').upsert({
			user_id: body.user_id, can_see_own_breaks: true,
			can_see_branch_breaks: body.can_see_branch_breaks,
			can_see_all_breaks: body.can_see_all_breaks,
			updated_at: new Date().toISOString()
		}, { onConflict: 'user_id' });
		if (error) throw error;
		return json({ success: true });
	} catch {
		return json({ error: 'Permission update failed' }, { status: 403 });
	}
};
