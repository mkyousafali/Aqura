import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

async function requireLockGuard(cookies: Parameters<typeof requireBreakUser>[0]) {
	const user = await requireBreakUser(cookies, 'desktop');
	if (user.isMasterAdmin) return user;
	const { data, error } = await databaseClient().from('pc_lock_guard_access').select('id').eq('user_id', user.id).maybeSingle();
	if (error || !data) throw new Error('PC Lock Guard access denied');
	return user;
}

export const POST: RequestHandler = async ({ request, cookies }) => {
	try {
		await requireLockGuard(cookies);
		const body = await request.json().catch(() => ({}));
		const op = String(body.op || '');
		const db = databaseClient();
		let data: unknown;

		if (op === 'health') {
			data = { connected: true };
		} else if (op === 'branches') {
			const result = await db.from('branches').select('id,name_en,name_ar').eq('is_active', true).order('name_en');
			if (result.error) throw result.error;
			data = result.data || [];
		} else if (op === 'erp-connection') {
			const branchId = Number(body.branchId);
			if (!Number.isSafeInteger(branchId)) throw new Error('Valid branch required');
			const result = await db.from('erp_connections')
				.select('branch_id,branch_name,server_ip,server_name,database_name,username,password,erp_branch_id,tunnel_url')
				.eq('branch_id', branchId).eq('is_active', true).maybeSingle();
			if (result.error) throw result.error;
			data = result.data || null;
		} else if (op === 'heartbeat') {
			const result = await db.rpc('lockguard_heartbeat', body.params || {});
			if (result.error) throw result.error;
			data = result.data;
		} else if (op === 'upload-events') {
			const rows = Array.isArray(body.rows) ? body.rows.slice(0, 100) : [];
			if (rows.length) {
				const result = await db.from('lockguard_events').insert(rows);
				if (result.error) throw result.error;
			}
			data = { count: rows.length };
		} else if (op === 'remote-actions') {
			const deviceId = String(body.deviceId || '');
			if (!deviceId) throw new Error('Device ID required');
			const result = await db.from('lockguard_remote_actions').select('*')
				.eq('device_id', deviceId).eq('status', 'pending').order('created_at');
			if (result.error) throw result.error;
			data = result.data || [];
		} else if (op === 'update-remote-action') {
			const id = String(body.id || '');
			const values = body.values && typeof body.values === 'object' ? body.values : {};
			if (!id) throw new Error('Action ID required');
			const result = await db.from('lockguard_remote_actions').update(values).eq('id', id);
			if (result.error) throw result.error;
			data = { updated: true };
		} else {
			return json({ success: false, error: 'Unsupported PC Lock Guard operation' }, { status: 400 });
		}

		return json({ success: true, data });
	} catch (error) {
		return json({ success: false, error: error instanceof Error ? error.message : 'PC Lock Guard request failed' }, { status: 403 });
	}
};
