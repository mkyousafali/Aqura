import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

const printColumns = 'id,flow_id,request_id,user_id,branch_id,action_type,reason,custom_reason,printer_name,print_status,error_message,printed_at,created_at,source,pos_counter_id,pos_counter_name,pos_counter_number';

async function requireCamChecker(cookies: Parameters<typeof requireBreakUser>[0]) {
	const user = await requireBreakUser(cookies, 'desktop');
	if (user.isMasterAdmin) return user;
	const { data, error } = await databaseClient().from('cam_checker_access').select('id').eq('user_id', user.id).maybeSingle();
	if (error || !data) throw new Error('Cam Checker access denied');
	return user;
}

async function readAll(table: string, columns: string, branchId: number) {
	const db = databaseClient();
	const rows: any[] = [];
	for (let offset = 0; offset < 10000; offset += 1000) {
		const { data, error } = await db.from(table).select(columns).eq('branch_id', branchId)
			.order('created_at', { ascending: false }).range(offset, offset + 999);
		if (error) throw error;
		rows.push(...(data || []));
		if (!data || data.length < 1000) break;
	}
	return rows;
}

export const POST: RequestHandler = async ({ request, cookies }) => {
	try {
		await requireCamChecker(cookies);
		const body = await request.json().catch(() => ({}));
		const op = String(body.op || '');
		const db = databaseClient();
		const branchId = Number(body.branchId);
		let data: any;

		if (op === 'branches') {
			({ data } = await db.from('branches').select('id,name_en,name_ar,location_en,location_ar').eq('is_active', true).order('name_en'));
		} else if (op === 'erp-counters') {
			if (!Number.isSafeInteger(branchId)) throw new Error('Valid branch required');
			({ data } = await db.from('erp_counters').select('id,branch_id,erp_branch_id,counter_id,counter_name,system_name,synced_at').eq('branch_id', branchId).order('counter_id'));
		} else if (op === 'erp-counters-many') {
			const ids = Array.isArray(body.branchIds) ? body.branchIds.map(Number).filter(Number.isSafeInteger) : [];
			({ data } = await db.from('erp_counters').select('branch_id,counter_id,counter_name,system_name').in('branch_id', ids));
		} else if (op === 'erp-counters-all') {
			({ data } = await db.from('erp_counters').select('branch_id,counter_id,counter_name,system_name,synced_at').order('branch_id').order('counter_id'));
		} else if (op === 'upsert-erp-counters') {
			const rows = Array.isArray(body.rows) ? body.rows.slice(0, 5000) : [];
			const { error } = await db.from('erp_counters').upsert(rows, { onConflict: 'branch_id,counter_id' });
			if (error) throw error;
			data = { count: rows.length };
		} else if (op === 'erp-connection') {
			if (!Number.isSafeInteger(branchId)) throw new Error('Valid branch required');
			({ data } = await db.from('erp_connections').select('*').eq('branch_id', branchId).eq('is_active', true).maybeSingle());
		} else if (op === 'erp-connections') {
			({ data } = await db.from('erp_connections').select('branch_id,branch_name,tunnel_url,erp_branch_id').eq('is_active', true).order('branch_id'));
		} else if (op === 'erp-user-names') {
			if (!Number.isSafeInteger(branchId)) throw new Error('Valid branch required');
			const { data: credentials, error } = await db.from('user_erp_credentials').select('user_id,erp_username').eq('aqura_branch_id', branchId);
			if (error) throw error;
			const ids = [...new Set((credentials || []).map((row: any) => row.user_id).filter(Boolean))];
			const employees = ids.length ? (await db.from('hr_employee_master').select('user_id,name_en,name_ar').eq('is_removed', false).in('user_id', ids)).data || [] : [];
			const names = new Map(employees.map((row: any) => [row.user_id, row]));
			data = (credentials || []).map((row: any) => ({ erp_username: row.erp_username, ...names.get(row.user_id) })).filter((row: any) => row.name_en || row.name_ar);
		} else if (op === 'flagged-drawer-events') {
			const result = await db.rpc('get_flagged_drawer_events', { p_branch_id: branchId, p_date_from: body.dateFrom, p_date_to: body.dateTo });
			if (result.error) throw result.error;
			data = result.data;
		} else if (op === 'sync-app-statuses') {
			const result = await db.rpc('get_sync_app_statuses');
			if (result.error) throw result.error;
			data = result.data;
		} else if (op === 'action-report-data') {
			if (!Number.isSafeInteger(branchId) || !['safeBox', 'cashier'].includes(body.kind)) throw new Error('Invalid report request');
			const kind = body.kind;
			const [prints, operations, requests, employees, users] = await Promise.all([
				readAll('aqura_pos_print_actions', printColumns, branchId),
				kind === 'safeBox' ? readAll('aqura_safe_box_operations', 'id,user_id,branch_id,operation_type,denomination_counts,total_amount,balance_before,balance_after,printer_name,status,opened_at,completed_at,created_at,opening_print_status', branchId) : [],
				kind === 'safeBox' ? readAll('aqura_change_requests', 'id,requested_by_user_id,requested_to_user_id,branch_id,denomination_counts,total_amount,status,requested_at,created_at,received_counts,received_total,received_at,withdrawal_counts,withdrawal_total,safe_box_printed_at,processed_at,cashier_confirmed_at,completed_at,safe_box_printer_name,cashier_printer_name,request_number', branchId) : [],
				(await db.from('hr_employee_master').select('user_id,name_en,name_ar').eq('is_removed', false).eq('current_branch_id', branchId).limit(10000)).data || [],
				(await db.from('users').select('id,username').limit(10000)).data || []
			]);
			data = { prints, operations, requests, employees, users };
		} else {
			return json({ success: false, error: 'Unsupported Cam Checker operation' }, { status: 400 });
		}
		return json({ success: true, data });
	} catch (error) {
		return json({ success: false, error: error instanceof Error ? error.message : 'Cam Checker request failed' }, { status: 403 });
	}
};
