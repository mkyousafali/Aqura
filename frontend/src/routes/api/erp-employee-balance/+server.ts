import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

const BRIDGE_API_SECRET = 'aqura-erp-bridge-2026';

/**
 * ERP Employee Balance API
 * POST { branchId: number, erpEmployeeId: number }
 * Returns employee name, ledger balance from ERP via tunnel.
 */
export const POST: RequestHandler = async ({ request }) => {
	try {
		const { branchId, erpEmployeeId } = await request.json();

		if (!branchId || !erpEmployeeId) {
			return json({ success: false, error: 'branchId and erpEmployeeId are required' }, { status: 400 });
		}

		// Get tunnel URL from erp_connections
		const supabaseUrl = env.VITE_SUPABASE_URL || 'https://supabase.urbanaqura.com';
		const supabaseKey = env.VITE_SUPABASE_SERVICE_KEY || env.VITE_SUPABASE_ANON_KEY || '';
		const supabase = createClient(supabaseUrl, supabaseKey);
		const { data: conn, error: connError } = await supabase
			.from('erp_connections')
			.select('tunnel_url, erp_branch_id, database_name')
			.eq('branch_id', branchId)
			.eq('is_active', true)
			.single();

		if (connError || !conn?.tunnel_url) {
			return json({ success: false, error: `No active ERP connection found for branch ${branchId}` }, { status: 404 });
		}

		const baseUrl = conn.tunnel_url.replace(/\/+$/, '');
		const empId = parseInt(erpEmployeeId, 10);

		const erpBranchId = conn.erp_branch_id;
		const simpleBranchFilter = erpBranchId ? `AND BranchID = ${parseInt(erpBranchId)}` : '';
		const joinedBranchFilter = erpBranchId ? `AND e.BranchID = ${parseInt(erpBranchId)}` : '';

		// Query 1: Get employee info (simple query, no alias)
		const empSql = `SELECT TOP 1 EmployeeID, EmployeeName, EmployeeCode FROM Employees WHERE EmployeeID=${empId} ${simpleBranchFilter}`;
		const empResp = await fetch(`${baseUrl}/query`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', 'x-api-secret': BRIDGE_API_SECRET },
			body: JSON.stringify({ sql: empSql }),
			signal: AbortSignal.timeout(15000)
		});

		if (!empResp.ok) {
			return json({ success: false, error: `Bridge error: HTTP ${empResp.status}` }, { status: 502 });
		}

		const empData = await empResp.json();
		if (!empData.success || empData.rowCount === 0) {
			return json({ success: false, error: `Employee ID ${erpEmployeeId} not found in ERP` }, { status: 404 });
		}

		const emp = empData.recordset[0];

		// Query 2: Get ledger balance via employee code → ledger code link (uses alias e)
		const balSql = `SELECT l.LedgerID, l.LedgerName, SUM(d.Debit) as TotalDebit, SUM(d.Credit) as TotalCredit, SUM(d.Debit-d.Credit) as NetBalance FROM Employees e JOIN AccLedgers l ON l.LedgerCode=e.EmployeeCode AND l.BranchID=e.BranchID JOIN AccTransactionMaster m ON m.BranchID=l.BranchID JOIN AccTransactionDetails d ON d.AccTransactionMasterID=m.AccTransactionMasterID AND d.BranchID=m.BranchID AND d.LedgerID=l.LedgerID WHERE e.EmployeeID=${empId} ${joinedBranchFilter} AND m.IsActive='True' GROUP BY l.LedgerID,l.LedgerName`;

		const balResp = await fetch(`${baseUrl}/query`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', 'x-api-secret': BRIDGE_API_SECRET },
			body: JSON.stringify({ sql: balSql }),
			signal: AbortSignal.timeout(20000)
		});

		let balance = null;
		if (balResp.ok) {
			const balData = await balResp.json();
			if (balData.success && balData.rowCount > 0) {
				const row = balData.recordset[0];
				const net = parseFloat(row.NetBalance) || 0;
				balance = {
					ledgerName: row.LedgerName,
					totalDebit: parseFloat(row.TotalDebit) || 0,
					totalCredit: parseFloat(row.TotalCredit) || 0,
					netBalance: Math.abs(net),
					direction: net > 0 ? 'Dr' : net < 0 ? 'Cr' : 'Nil'
				};
			}
		}

		return json({
			success: true,
			employee: {
				erpEmployeeId: parseInt(emp.EmployeeID),
				name: emp.EmployeeName,
				code: emp.EmployeeCode
			},
			balance
		});
	} catch (error: any) {
		console.error('ERP employee balance error:', error);
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};

/**
 * GET ?branchId=X&query=SARFAS
 * Search employees in ERP by name or code for a given branch.
 */
export const GET: RequestHandler = async ({ url }) => {
	try {
		const branchId = url.searchParams.get('branchId');
		const query = url.searchParams.get('query') || '';

		if (!branchId) {
			return json({ success: false, error: 'branchId is required' }, { status: 400 });
		}

		const supabaseUrl = env.VITE_SUPABASE_URL || 'https://supabase.urbanaqura.com';
		const supabaseKey = env.VITE_SUPABASE_SERVICE_KEY || env.VITE_SUPABASE_ANON_KEY || '';
		const supabase = createClient(supabaseUrl, supabaseKey);
		const { data: conn, error: connError } = await supabase
			.from('erp_connections')
			.select('tunnel_url, erp_branch_id')
			.eq('branch_id', parseInt(branchId))
			.eq('is_active', true)
			.single();

		if (connError || !conn?.tunnel_url) {
			return json({ success: false, error: `No active ERP connection for branch ${branchId}` }, { status: 404 });
		}

		const baseUrl = conn.tunnel_url.replace(/\/+$/, '');
		const safeQuery = query.replace(/'/g, "''");
		const erpBranchId = conn.erp_branch_id;
		const branchFilter = erpBranchId ? `AND BranchID = ${parseInt(erpBranchId)}` : '';
		const searchSql = `SELECT TOP 50 EmployeeID, EmployeeName, EmployeeCode FROM Employees WHERE IsActive=1 ${branchFilter} AND (EmployeeName LIKE '%${safeQuery}%' OR EmployeeCode LIKE '%${safeQuery}%' OR CAST(EmployeeID AS NVARCHAR) LIKE '%${safeQuery}%') ORDER BY EmployeeName`;

		const resp = await fetch(`${baseUrl}/query`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', 'x-api-secret': BRIDGE_API_SECRET },
			body: JSON.stringify({ sql: searchSql }),
			signal: AbortSignal.timeout(15000)
		});

		if (!resp.ok) {
			return json({ success: false, error: `Bridge error: HTTP ${resp.status}` }, { status: 502 });
		}

		const data = await resp.json();
		return json({
			success: true,
			employees: data.recordset || [],
			rowCount: data.rowCount || 0
		});
	} catch (error: any) {
		console.error('ERP employee search error:', error);
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};
