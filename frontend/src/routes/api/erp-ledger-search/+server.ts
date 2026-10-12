import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

export const GET: RequestHandler = async ({ url }) => {
	try {
		const branchId = Number(url.searchParams.get('branchId'));
		const query = (url.searchParams.get('query') || '').trim();
		if (!Number.isInteger(branchId) || branchId <= 0) {
			return json({ success: false, error: 'A valid branchId is required' }, { status: 400 });
		}

		const supabaseUrl = env.VITE_SUPABASE_URL || '';
		const supabaseKey = env.SUPABASE_SERVICE_ROLE_KEY || env.VITE_SUPABASE_SERVICE_KEY || '';
		if (!supabaseUrl || !supabaseKey) {
			return json({ success: false, error: 'Server database configuration is missing' }, { status: 500 });
		}

		const supabase = createClient(supabaseUrl, supabaseKey);
		const { data: connection, error } = await supabase
			.from('erp_connections')
			.select('tunnel_url, erp_branch_id, bridge_api_secret')
			.eq('branch_id', branchId)
			.eq('is_active', true)
			.single();

		if (error || !connection?.tunnel_url || !connection?.bridge_api_secret) {
			return json({ success: false, error: `No active ERP connection found for branch ${branchId}` }, { status: 404 });
		}

		const safeQuery = query.replace(/'/g, "''");
		const erpBranchId = Number(connection.erp_branch_id);
		const branchFilter = Number.isInteger(erpBranchId) && erpBranchId > 0 ? `AND BranchID = ${erpBranchId}` : '';
		const sql = `SELECT TOP 50 LedgerID, LedgerCode, LedgerName FROM AccLedgers WHERE IsActive = 1 ${branchFilter} AND (LedgerName LIKE '%${safeQuery}%' OR CAST(LedgerCode AS NVARCHAR(100)) LIKE '%${safeQuery}%' OR CAST(LedgerID AS NVARCHAR(100)) LIKE '%${safeQuery}%') ORDER BY LedgerName`;

		const response = await fetch(`${connection.tunnel_url.replace(/\/+$/, '')}/query`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', 'x-api-secret': connection.bridge_api_secret },
			body: JSON.stringify({ sql }),
			signal: AbortSignal.timeout(15000)
		});

		if (!response.ok) {
			return json({ success: false, error: `ERP bridge error: HTTP ${response.status}` }, { status: 502 });
		}

		const data = await response.json();
		if (!data.success) {
			return json({ success: false, error: data.error || 'ERP ledger search failed' }, { status: 502 });
		}

		return json({ success: true, ledgers: data.recordset || [] });
	} catch (error: any) {
		console.error('ERP ledger search error:', error);
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};
