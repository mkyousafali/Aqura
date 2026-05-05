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

		// Format dates for SQL Server — ISO 8601 yyyy-mm-dd
		const fmtDate = (d: string) => d.split('T')[0];
		const sqlAfter  = fmtDate(afterDate);
		const sqlBefore = fmtDate(beforeDate);

		// Validate the resulting date strings look sane before inserting into SQL
		const dateRe = /^\d{4}-\d{2}-\d{2}$/;
		if (!dateRe.test(sqlAfter) || !dateRe.test(sqlBefore)) {
			return json({ success: false, error: 'Invalid date format' }, { status: 400 });
		}

		console.log('[broadcast-analytics] date range:', sqlAfter, '→', sqlBefore, '| phones:', phoneNumbers.length);

		// Initialize results for every phone — with per-branch breakdown
		interface BranchEntry { branchId: string; branchName: string; billCount: number; totalAmount: number; lastBillDate: string | null; }
		interface PhoneResult { billCount: number; totalAmount: number; lastBillDate: string | null; branches: BranchEntry[]; }
		const phoneSet = new Set(phoneNumbers.map((p: string) => p.trim()));
		const results: Record<string, PhoneResult> = {};
		for (const p of phoneNumbers) {
			results[p.trim()] = { billCount: 0, totalAmount: 0, lastBillDate: null, branches: [] };
		}

		if (!erpConfigs || erpConfigs.length === 0) {
			return json({ success: true, results, branchCount: 0, branches: [] });
		}

		// Query each branch in parallel — date filtering done in JS to avoid SQL Server locale issues
		await Promise.all(erpConfigs.map(async (config: any) => {
			if (!config?.tunnel_url) return;

			const baseUrl = config.tunnel_url.replace(/\/+$/, '');
			const erpBranchId = config.erp_branch_id || config.branch_id;
			const branchData = Array.isArray(config.branches) ? config.branches[0] : config.branches;
			const branchName = config.branch_name || `Branch ${config.branch_id}`;

			// Use direct date column comparison — TransactionDate is SQL Server date type,
			// so ISO string literals compare correctly without CONVERT.
			const sql = `
				SELECT
					REPLACE(pc.Mobile, ' ', '') AS phone_number,
					CONVERT(varchar(10), itm.TransactionDate, 23) AS bill_date,
					ISNULL(itm.GrandTotal, 0) AS bill_amt
				FROM PrivilegeCards pc
				INNER JOIN InvTransactionMaster itm
					ON itm.BranchID = pc.BranchID
					AND LTRIM(RTRIM(itm.PartyName)) = LTRIM(RTRIM(pc.CardHolderName))
				WHERE pc.BranchID = ${erpBranchId}
					AND pc.CardHolderName != ''
					AND pc.Mobile IS NOT NULL
					AND pc.Mobile != ''
					AND itm.TransactionDate >= '${sqlAfter}'
					AND itm.TransactionDate <= '${sqlBefore}'
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
					console.log(`[broadcast-analytics] branch ${erpBranchId} → ${result.recordset.length} rows | sample bill_date:`, result.recordset[0]?.bill_date, typeof result.recordset[0]?.bill_date);
					// Aggregate per-phone in JS — SQL already filtered by date, JS filter is safety net
					const phoneTotals = new Map<string, { billCount: number; totalAmount: number; lastBillDate: string | null }>();

					for (const row of result.recordset) {
						const phone = row.phone_number?.trim();
						if (!phone || !phoneSet.has(phone)) continue;

						// Normalise bill_date to yyyy-mm-dd string (handle Date objects too)
						const rawDate = row.bill_date;
						const billDate: string = rawDate instanceof Date
							? rawDate.toISOString().substring(0, 10)
							: String(rawDate || '').substring(0, 10);
						if (!billDate || billDate < sqlAfter || billDate > sqlBefore) continue;

						const amt = row.bill_amt || 0;
						const cur = phoneTotals.get(phone) || { billCount: 0, totalAmount: 0, lastBillDate: null };
						cur.billCount++;
						cur.totalAmount += amt;
						if (!cur.lastBillDate || billDate > cur.lastBillDate) cur.lastBillDate = billDate;
						phoneTotals.set(phone, cur);
					}

					// Merge into results
					for (const [phone, totals] of phoneTotals.entries()) {
						results[phone].billCount   += totals.billCount;
						results[phone].totalAmount += totals.totalAmount;
						const d = totals.lastBillDate;
						if (d) {
							const existing = results[phone].lastBillDate;
							if (!existing || d > existing) results[phone].lastBillDate = d;
						}
						results[phone].branches.push({
							branchId: String(config.branch_id),
							branchName,
							billCount: totals.billCount,
							totalAmount: totals.totalAmount,
							lastBillDate: totals.lastBillDate
						});
					}
				}
			} catch (_) {
				// Branch offline — skip silently
			}
		}));

		// Collect list of unique branches that had any activity (for the filter dropdown)
		const branchMap = new Map<string, string>();
		for (const r of Object.values(results)) {
			for (const b of r.branches) {
				if (!branchMap.has(b.branchId)) branchMap.set(b.branchId, b.branchName);
			}
		}
		const branches = Array.from(branchMap.entries()).map(([id, name]) => ({ id, name }));

		return json({ success: true, results, branchCount: erpConfigs.length, branches });

	} catch (error: any) {
		console.error('Broadcast analytics error:', error);
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};
