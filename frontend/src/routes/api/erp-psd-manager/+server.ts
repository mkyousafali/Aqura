import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

async function requireErpPasswordManager(cookies: Parameters<typeof requireBreakUser>[0]) {
	const user = await requireBreakUser(cookies, 'desktop');
	if (user.isMasterAdmin) return user;
	const { data, error } = await databaseClient().from('erp_psd_manager_access').select('id').eq('user_id', user.id).maybeSingle();
	if (error || !data) throw new Error('ERP Password Manager access denied');
	return user;
}

export const POST: RequestHandler = async ({ request, cookies }) => {
	try {
		await requireErpPasswordManager(cookies);
		const body = await request.json().catch(() => ({}));
		const op = String(body.op || '');
		const branchId = Number(body.branchId);
		const db = databaseClient();
		let data: any;

		if (op === 'branches') {
			const result = await db.from('branches').select('id,name_en,name_ar').eq('is_active', true).order('name_en');
			if (result.error) throw result.error;
			data = result.data || [];
		} else if (op === 'erp-connection') {
			if (!Number.isSafeInteger(branchId)) throw new Error('Valid branch required');
			const result = await db.from('erp_connections').select('branch_id,branch_name,server_ip,server_name,database_name,username,password,erp_branch_id,tunnel_url,bridge_api_secret').eq('branch_id', branchId).eq('is_active', true).maybeSingle();
			if (result.error) throw result.error;
			data = result.data;
		} else if (op === 'linked-credentials') {
			if (!Number.isSafeInteger(branchId)) throw new Error('Valid branch required');
			const result = await db.from('user_erp_credentials').select('id,erp_username,bulk_rotation_enabled,erp_login_password_rotated_at,erp_password_rotated_at').eq('aqura_branch_id', branchId).not('erp_username', 'is', null);
			if (result.error) throw result.error;
			data = result.data || [];
		} else if (op === 'set-bulk-rotation') {
			if (!Number.isSafeInteger(branchId) || typeof body.userName !== 'string') throw new Error('Invalid update request');
			const result = await db.from('user_erp_credentials').update({ bulk_rotation_enabled: body.enabled === true }).eq('aqura_branch_id', branchId).ilike('erp_username', body.userName.trim()).select('id').maybeSingle();
			if (result.error) throw result.error;
			if (!result.data) throw new Error('No linked ERP credential found');
			data = { updated: true };
		} else if (op === 'sync-password') {
			if (!Number.isSafeInteger(branchId) || typeof body.userName !== 'string' || !/^\d{12}$/.test(String(body.password || ''))) throw new Error('Invalid password sync request');
			const login = body.kind === 'login';
			if (!login && body.kind !== 'auth') throw new Error('Invalid password kind');
			const update = login ? { erp_login_password: body.password, erp_login_password_rotated_at: body.rotatedAt } : { erp_password: body.password, erp_password_rotated_at: body.rotatedAt };
			const result = await db.from('user_erp_credentials').update(update).eq('aqura_branch_id', branchId).ilike('erp_username', body.userName.trim()).select('id').maybeSingle();
			if (result.error) throw result.error;
			if (!result.data) throw new Error('No linked ERP credential found');
			data = { updated: true };
		} else {
			return json({ success: false, error: 'Unsupported ERP Password Manager operation' }, { status: 400 });
		}
		return json({ success: true, data });
	} catch (error) {
		return json({ success: false, error: error instanceof Error ? error.message : 'ERP Password Manager request failed' }, { status: 403 });
	}
};
