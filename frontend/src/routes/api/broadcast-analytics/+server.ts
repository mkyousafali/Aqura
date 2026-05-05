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

		// Format dates for SQL Server — use ISO 8601 (format 23: yyyy-mm-dd) for unambiguous conversion
		const fmtDate = (d: string) => d.split('T')[0];
		const sqlAfter  = fmtDate(afterDate);
		const sqlBefore = fmtDate(beforeDate);

		// Validate the resulting date strings look sane before inserting into SQL
		const dateRe = /^\d{4}-\d{2}-\d{2}$/;
		if (!dateRe.test(sqlAfter) || !dateRe.test(sqlBefore)) {
			return json({ success: false, error: 'Invalid date format' }, { status: 400 });
		}

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

			// Return individual rows with date as yyyy-mm-dd string (CONVERT style 23 is locale-independent).
			// NO date filter in SQL — we filter in JavaScript below to avoid any SQL Server
			// DATEFORMAT / column-type ambiguity that caused "0 results" bugs.
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
					// Aggregate per-phone in JS, applying the date range filter here
					const phoneTotals = new Map<string, { billCount: number; totalAmount: number; lastBillDate: string | null }>();

					for (const row of result.recordset) {
						const phone = row.phone_number?.trim();
						if (!phone || !phoneSet.has(phone)) continue;

						// bill_date is yyyy-mm-dd from CONVERT style 23 — safe for string comparison
						const billDate: string = (row.bill_date || '').substring(0, 10);
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
