import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

/**
 * Broadcast Analytics API
 *
 * Given a list of phone numbers (broadcast recipients) and a date window
 * [afterDate, beforeDate], queries every ERP branch in parallel for bill
 * activity in that window, then returns per-phone results.
 *
 * Uses the same ERP matching logic as /api/batch-bill-counts:
 *   PrivilegeCards.Mobile (spaces stripped) → phone_number
 *   InvTransactionMaster joined by BranchID + CardHolderName
 */

const BRIDGE_API_SECRET = 'aqura-erp-bridge-2026';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { phoneNumbers, afterDate, beforeDate } = await request.json();

		if (!phoneNumbers || !Array.isArray(phoneNumbers) || phoneNumbers.length === 0) {
			return json({ success: false, error: 'phoneNumbers array is required' }, { status: 400 });
		}
		if (!afterDate || !beforeDate) {
			return json({ success: false, error: 'afterDate and beforeDate are required' }, { status: 400 });
		}
		if (new Date(beforeDate) < new Date(afterDate)) {
			return json({ success: false, error: '"Up to date" must be on or after the broadcast date' }, { status: 400 });
		}

		const supabaseUrl = env.VITE_SUPABASE_URL || 'https://supabase.urbanaqura.com';
		const supabaseKey = env.VITE_SUPABASE_ANON_KEY || '';
		const supabase = createClient(supabaseUrl, supabaseKey);

		// Load active ERP branch connections
		const { data: erpConfigs, error: configError } = await supabase
			.from('erp_connections')
			.select('tunnel_url, erp_branch_id, branch_id, branch_name, branches(id, location_en, location_ar)')
			.eq('is_active', true)
			.order('branch_id');

		if (configError) {
			return json({ success: false, error: configError.message }, { status: 500 });
		}

		// Format dates for SQL Server (YYYY-MM-DD)
		const fmtDate = (d: string) => d.split('T')[0];
		const sqlAfter  = fmtDate(afterDate);
		const sqlBefore = fmtDate(beforeDate);

		// Initialize results for every phone
		const phoneSet = new Set(phoneNumbers.map((p: string) => p.trim()));
		const results: Record<string, { billCount: number; totalAmount: number; lastBillDate: string | null }> = {};
		for (const p of phoneNumbers) {
			results[p.trim()] = { billCount: 0, totalAmount: 0, lastBillDate: null };
		}

		if (!erpConfigs || erpConfigs.length === 0) {
			return json({ success: true, results, branchCount: 0 });
		}

		// Query each branch in parallel — date-filtered
		await Promise.all(erpConfigs.map(async (config: any) => {
			if (!config?.tunnel_url) return;

			const baseUrl = config.tunnel_url.replace(/\/+$/, '');
			const erpBranchId = config.erp_branch_id || config.branch_id;

			const sql = `
				SELECT
					REPLACE(pc.Mobile, ' ', '') AS phone_number,
					COUNT(itm.InvTransactionMasterID) AS bill_cnt,
					ISNULL(SUM(itm.GrandTotal), 0) AS bill_amt,
					MAX(itm.TransactionDate) AS last_bill_date
				FROM PrivilegeCards pc
				INNER JOIN InvTransactionMaster itm
					ON itm.BranchID = pc.BranchID
					AND LTRIM(RTRIM(itm.PartyName)) = LTRIM(RTRIM(pc.CardHolderName))
				WHERE pc.BranchID = ${erpBranchId}
					AND pc.CardHolderName != ''
					AND pc.Mobile IS NOT NULL
					AND pc.Mobile != ''
					AND CONVERT(date, itm.TransactionDate) >= '${sqlAfter}'
					AND CONVERT(date, itm.TransactionDate) <= '${sqlBefore}'
				GROUP BY REPLACE(pc.Mobile, ' ', '')
			`;

			try {
				const controller = new AbortController();
				const timeout = setTimeout(() => controller.abort(), 60000);

				const response = await fetch(`${baseUrl}/query`, {
					method: 'POST',
					headers: {
						'Content-Type': 'application/json',
						'x-api-secret': BRIDGE_API_SECRET
					},
					body: JSON.stringify({ sql }),
					signal: controller.signal
				});
				clearTimeout(timeout);

				const contentType = response.headers.get('content-type') || '';
				if (!contentType.includes('application/json')) return;

				const result = await response.json();
				if (result.success && result.recordset) {
					for (const row of result.recordset) {
						const phone = row.phone_number?.trim();
						if (phone && phoneSet.has(phone)) {
							results[phone].billCount   += (row.bill_cnt || 0);
							results[phone].totalAmount += (row.bill_amt || 0);
							const d = row.last_bill_date || null;
							if (d) {
								const existing = results[phone].lastBillDate;
								if (!existing || new Date(d) > new Date(existing)) {
									results[phone].lastBillDate = d;
								}
							}
						}
					}
				}
			} catch (_) {
				// Branch offline — skip silently, same as batch-bill-counts
			}
		}));

		return json({ success: true, results, branchCount: erpConfigs.length });

	} catch (error: any) {
		console.error('Broadcast analytics error:', error);
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};
