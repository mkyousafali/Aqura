import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

export const POST: RequestHandler = async ({ cookies, request }) => {
	let actor;
	try {
		actor = await requireBreakUser(cookies, 'desktop');
	} catch {
		return json({ success: false, error: 'Desktop session required.' }, { status: 401 });
	}

	try {
		const db = databaseClient();
		if (!actor.isMasterAdmin) {
			const { data: permission, error } = await db
				.from('button_permissions')
				.select('button_code')
				.eq('user_id', actor.id)
				.eq('button_code', 'DRAWER_ACTION_MONITOR')
				.eq('is_enabled', true)
				.maybeSingle();
			if (error) throw error;
			if (!permission) return json({ success: false, error: 'Drawer Action report access required.' }, { status: 403 });
		}

		const body = await request.json();
		const requestedBranchId = Number(body?.branchId || 0);
		const sql = typeof body?.sql === 'string' ? body.sql.trim() : '';
		if (!Number.isSafeInteger(requestedBranchId) || requestedBranchId <= 0 || !sql) {
			return json({ success: false, error: 'Valid branchId and SQL are required.' }, { status: 400 });
		}
		if (!/^(select|with)\b/i.test(sql) || /\b(insert|update|delete|merge|drop|alter|truncate|exec(?:ute)?|create|grant|revoke)\b/i.test(sql)) {
			return json({ success: false, error: 'Only read-only ERP queries are permitted.' }, { status: 400 });
		}

		if (!actor.isMasterAdmin) {
			const { data: employee, error } = await db
				.from('hr_employee_master')
				.select('current_branch_id')
				.eq('user_id', actor.id)
				.maybeSingle();
			if (error) throw error;
			const ownBranchId = Number(employee?.current_branch_id || 0);
			if (!ownBranchId || requestedBranchId !== ownBranchId) {
				return json({ success: false, error: 'Branch access denied.' }, { status: 403 });
			}
		}

		const { data: connection, error: connectionError } = await db
			.from('erp_connections')
			.select('tunnel_url, bridge_api_secret')
			.eq('branch_id', requestedBranchId)
			.eq('is_active', true)
			.maybeSingle();
		if (connectionError) throw connectionError;
		if (!connection?.tunnel_url || !connection?.bridge_api_secret) {
			return json({ success: false, error: 'No active ERP connection configured for this branch.' }, { status: 404 });
		}

		const response = await fetch(`${connection.tunnel_url.replace(/\/+$/, '')}/query`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', 'x-api-secret': connection.bridge_api_secret },
			body: JSON.stringify({ sql }),
			signal: AbortSignal.timeout(30000)
		});
		const result = await response.json().catch(() => ({}));
		if (!response.ok) {
			return json({ success: false, error: result?.error || `ERP query failed (HTTP ${response.status})` }, { status: response.status });
		}
		return json(result);
	} catch (error) {
		const timedOut = error instanceof Error && ['AbortError', 'TimeoutError'].includes(error.name);
		return json(
			{ success: false, error: timedOut ? 'ERP query timed out.' : (error instanceof Error ? error.message : 'ERP query failed.') },
			{ status: timedOut ? 504 : 500 }
		);
	}
};
