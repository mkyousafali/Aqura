import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

const requestTypes = ['pos_reconciliation', 'receiving_bank_slip', 'pay_to_credit_slip'];

async function requireMasterAdmin(cookies: Parameters<typeof requireBreakUser>[0]) {
	const actor = await requireBreakUser(cookies, 'desktop');
	if (!actor.isMasterAdmin) throw new Error('MASTER_ADMIN_REQUIRED');
	return actor;
}

export const GET: RequestHandler = async ({ cookies }) => {
	try {
		await requireMasterAdmin(cookies);
		const db = databaseClient();
		const { data: requests, error } = await db.from('pos_scan_requests')
			.select('id,branch_id,requested_by,request_type,request_label,status,created_at,box_number,pos_number,receiving_record_id,payment_account_type')
			.in('request_type', requestTypes)
			.eq('status', 'pending')
			.order('created_at', { ascending: false });
		if (error) throw error;

		const branchIds = [...new Set((requests || []).map((row) => Number(row.branch_id)).filter(Number.isFinite))];
		const userIds = [...new Set((requests || []).map((row) => String(row.requested_by || '')).filter(Boolean))];
		const [{ data: branches }, { data: users }, { data: employees }] = await Promise.all([
			branchIds.length
				? db.from('branches').select('id,name_en,name_ar,location_en').in('id', branchIds)
				: Promise.resolve({ data: [] }),
			userIds.length
				? db.from('users').select('id,username').in('id', userIds)
				: Promise.resolve({ data: [] }),
			userIds.length
				? db.from('hr_employee_master').select('user_id,name_en,name_ar').in('user_id', userIds).eq('is_removed', false)
				: Promise.resolve({ data: [] })
		]);

		const branchById = new Map((branches || []).map((branch) => [Number(branch.id), branch]));
		const userById = new Map((users || []).map((user) => [String(user.id), user]));
		const employeeByUserId = new Map((employees || []).map((employee) => [String(employee.user_id), employee]));

		return json({
			success: true,
			requests: (requests || []).map((request) => {
				const branch = branchById.get(Number(request.branch_id));
				const user = userById.get(String(request.requested_by));
				const employee = employeeByUserId.get(String(request.requested_by));
				return {
					...request,
					branch_name: branch?.location_en || branch?.name_en || branch?.name_ar || `Branch ${request.branch_id || '-'}`,
					requester_name: employee?.name_en || employee?.name_ar || user?.username || String(request.requested_by || '-')
				};
			})
		}, { headers: { 'Cache-Control': 'no-store' } });
	} catch (error: any) {
		const forbidden = error?.message === 'MASTER_ADMIN_REQUIRED';
		return json({ success: false, error: forbidden ? 'Master Admin access required.' : (error?.message || 'Unable to load pending scan requests.') }, { status: forbidden ? 403 : 400 });
	}
};

export const DELETE: RequestHandler = async ({ cookies, request }) => {
	try {
		await requireMasterAdmin(cookies);
		const body = await request.json();
		const ids = [...new Set((Array.isArray(body?.ids) ? body.ids : [body?.id])
			.map((value) => String(value || '').trim()).filter(Boolean))];
		if (!ids.length) return json({ success: false, error: 'Select at least one request.' }, { status: 400 });
		if (ids.length > 500) return json({ success: false, error: 'A maximum of 500 requests can be deleted at once.' }, { status: 400 });

		const { data, error } = await databaseClient().from('pos_scan_requests')
			.delete()
			.in('id', ids)
			.eq('status', 'pending')
			.in('request_type', requestTypes)
			.select('id')
		;
		if (error) throw error;
		const deletedIds = (data || []).map((row) => row.id);
		if (!deletedIds.length) return json({ success: false, error: 'Only pending scan requests can be deleted.' }, { status: 409 });
		return json({ success: true, ids: deletedIds, deleted_count: deletedIds.length });
	} catch (error: any) {
		const forbidden = error?.message === 'MASTER_ADMIN_REQUIRED';
		return json({ success: false, error: forbidden ? 'Master Admin access required.' : (error?.message || 'Unable to delete the scan request.') }, { status: forbidden ? 403 : 400 });
	}
};
