import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

async function authorize(cookies: Parameters<typeof requireBreakUser>[0]) {
	const actor = await requireBreakUser(cookies, 'desktop');
	if (actor.isMasterAdmin) return actor;
	const { data, error } = await databaseClient().from('button_permissions').select('button_code')
		.eq('user_id', actor.id).eq('button_code', 'CHANGE_REQUESTS').eq('is_enabled', true).maybeSingle();
	if (error) throw error;
	if (!data) throw new Error('FORBIDDEN');
	return actor;
}

export const GET: RequestHandler = async ({ cookies }) => {
	try {
		await authorize(cookies);
		const db = databaseClient();
		const { data: requests, error } = await db.from('aqura_change_requests')
			.select('id,request_number,requested_by_user_id,requested_to_user_id,branch_id,total_amount,status,requested_at')
			.not('status', 'in', '(Completed,Cancelled)').order('requested_at', { ascending: true });
		if (error) throw error;
		const userIds = [...new Set((requests || []).flatMap((row: any) => [row.requested_by_user_id, row.requested_to_user_id]))];
		const branchIds = [...new Set((requests || []).map((row: any) => row.branch_id))];
		const [{ data: employees, error: employeeError }, { data: users, error: userError }, { data: branches, error: branchError }] = await Promise.all([
			userIds.length ? db.from('hr_employee_master').select('user_id,name_en,name_ar').eq('is_removed', false).in('user_id', userIds) : Promise.resolve({ data: [], error: null }),
			userIds.length ? db.from('users').select('id,username').in('id', userIds) : Promise.resolve({ data: [], error: null }),
			branchIds.length ? db.from('branches').select('id,name_en,name_ar').in('id', branchIds) : Promise.resolve({ data: [], error: null })
		]);
		if (employeeError || userError || branchError) throw employeeError || userError || branchError;
		const employeeMap = new Map((employees || []).map((row: any) => [row.user_id, row]));
		const userMap = new Map((users || []).map((row: any) => [row.id, row.username]));
		const branchMap = new Map((branches || []).map((row: any) => [Number(row.id), row]));
		return json({ requests: (requests || []).map((row: any) => ({
			...row,
			cashier: employeeMap.get(row.requested_by_user_id) || { name_en: userMap.get(row.requested_by_user_id) || '', name_ar: '' },
			receiver: employeeMap.get(row.requested_to_user_id) || { name_en: userMap.get(row.requested_to_user_id) || '', name_ar: '' },
			branch: branchMap.get(Number(row.branch_id)) || null
		})) }, { headers: { 'Cache-Control': 'no-store' } });
	} catch (error) {
		const message = error instanceof Error ? error.message : 'Could not load change requests.';
		return json({ error: message === 'FORBIDDEN' ? 'Change Requests permission required.' : message },
			{ status: message === 'FORBIDDEN' ? 403 : message.includes('session') ? 401 : 500 });
	}
};

export const POST: RequestHandler = async ({ cookies, request }) => {
	try {
		const actor = await authorize(cookies);
		const body = await request.json();
		if (typeof body.requestId !== 'string' || !['complete', 'cancel'].includes(body.action) ||
			typeof body.reason !== 'string' || body.reason.trim().length < 5 || body.reason.length > 1000) {
			return json({ error: 'Select an action and enter a reason of at least 5 characters.' }, { status: 400 });
		}
		const { data, error } = await databaseClient().rpc('aqura_admin_resolve_change_request', {
			p_actor_id: actor.id, p_request_id: body.requestId, p_action: body.action, p_reason: body.reason.trim()
		});
		if (error) return json({ error: error.message }, { status: 409 });
		return json(data);
	} catch (error) {
		const message = error instanceof Error ? error.message : 'Could not update change request.';
		return json({ error: message === 'FORBIDDEN' ? 'Change Requests permission required.' : message },
			{ status: message === 'FORBIDDEN' ? 403 : message.includes('session') ? 401 : 500 });
	}
};
