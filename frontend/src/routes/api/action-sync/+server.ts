import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

async function requireActionSync(cookies: Parameters<typeof requireBreakUser>[0]) {
	const user = await requireBreakUser(cookies, 'desktop');
	if (user.isMasterAdmin) return user;
	const { data, error } = await databaseClient().from('action_sync_access').select('id').eq('user_id', user.id).maybeSingle();
	if (error || !data) throw new Error('Action Sync access denied');
	return user;
}

export const POST: RequestHandler = async ({ request, cookies }) => {
	try {
		await requireActionSync(cookies);
		const body = await request.json().catch(() => ({}));
		const op = String(body.op || '');
		const db = databaseClient();
		let data: any;
		if (op === 'ping') {
			data = { authenticated: true };
		} else if (op === 'branches') {
			const result = await db.from('branches').select('id,name_en,name_ar').eq('is_active', true).order('name_en');
			if (result.error) throw result.error;
			data = result.data || [];
		} else if (op === 'erp-connection') {
			const branchId = Number(body.branchId);
			if (!Number.isSafeInteger(branchId)) throw new Error('Valid branch required');
			const result = await db.from('erp_connections').select('branch_id,branch_name,server_ip,server_name,database_name,username,password,erp_branch_id,tunnel_url').eq('branch_id', branchId).eq('is_active', true).maybeSingle();
			if (result.error) throw result.error;
			data = result.data;
		} else if (op === 'upsert-print-actions') {
			const rows = Array.isArray(body.rows) ? body.rows.slice(0, 200) : [];
			if (!rows.length || rows.some((row: any) => !Number.isSafeInteger(Number(row.branch_id)))) throw new Error('Valid print actions required');
			const result = await db.from('erp_print_actions').upsert(rows, { onConflict: 'branch_id,event_time,byte_size,printer_name' });
			if (result.error) throw result.error;
			data = { count: rows.length };
		} else if (op === 'heartbeat') {
			const result = await db.rpc('sync_app_heartbeat', body.payload || {});
			if (result.error) throw result.error;
			data = result.data;
		} else {
			return json({ success: false, error: 'Unsupported Action Sync operation' }, { status: 400 });
		}
		return json({ success: true, data });
	} catch (error) {
		return json({ success: false, error: error instanceof Error ? error.message : 'Action Sync request failed' }, { status: 403 });
	}
};
