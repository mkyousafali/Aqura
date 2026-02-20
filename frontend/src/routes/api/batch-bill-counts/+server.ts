import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';

/**
 * Batch Bill Counts API
 * 
 * Takes an array of phone numbers, queries ALL ERP branches in parallel
 * through their Cloudflare tunnels, and returns aggregated bill counts
 * for every contact in a single response.
 * 
 * This replaces 100+ individual frontend calls with ONE server-side batch.
 */

const BRIDGE_API_SECRET = 'aqura-erp-bridge-2026';

interface BranchResult {
	branchId: string;
	branchName: string;
	locationEn: string;
	locationAr: string;
	count: number;
	total: number;
	lastBillDate: string | null;
}

interface ContactResult {
	phoneNumber: string;
	branchResults: BranchResult[];
	totalCount: number;
	totalAmount: number;
	lastBillDate: string | null;
	broadcastStats: { sent: number; delivered: number; read: number };
}

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { phoneNumbers } = await request.json();

		if (!phoneNumbers || !Array.isArray(phoneNumbers) || phoneNumbers.length === 0) {
			return json({ success: false, error: 'phoneNumbers array is required' }, { status: 400 });
		}

		// Create admin Supabase client
		const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://supabase.urbanaqura.com';
		const supabaseKey = import.meta.env.VITE_SUPABASE_SERVICE_KEY || '';
		const supabase = createClient(supabaseUrl, supabaseKey);

		// 1. Get all active ERP connections with branch locations (ONE query for all)
		const { data: erpConfigs, error: configError } = await supabase
			.from('erp_connections')
			.select('tunnel_url, erp_branch_id, branch_id, branch_name, branches(id, location_en, location_ar)')
			.eq('is_active', true)
			.order('branch_id');

		if (configError) {
			console.error('Failed to load ERP configs:', configError);
			return json({ success: false, error: configError.message }, { status: 500 });
		}

		if (!erpConfigs || erpConfigs.length === 0) {
			// Return empty results for all contacts
			const emptyResults: Record<string, ContactResult> = {};
			for (const phone of phoneNumbers) {
				emptyResults[phone] = {
					phoneNumber: phone,
					branchResults: [],
					totalCount: 0,
					totalAmount: 0,
					lastBillDate: null,
					broadcastStats: { sent: 0, delivered: 0, read: 0 }
				};
			}
			return json({ success: true, results: emptyResults });
		}

		console.log(`📊 Batch bill counts: ${phoneNumbers.length} contacts × ${erpConfigs.length} branches`);

		// 2. Get broadcast stats for ALL contacts — chunk to avoid URL length limits
		const broadcastMap: Record<string, { sent: number; delivered: number; read: number }> = {};
		
		// Supabase .in() can fail with very large arrays; chunk at 500
		const CHUNK_SIZE = 500;
		const broadcastPromises: Promise<void>[] = [];
		for (let i = 0; i < phoneNumbers.length; i += CHUNK_SIZE) {
			const chunk = phoneNumbers.slice(i, i + CHUNK_SIZE);
			broadcastPromises.push((async () => {
				const { data: broadcastData } = await supabase
					.from('wa_broadcast_recipients')
					.select('phone_number, status')
					.in('phone_number', chunk);

				if (broadcastData) {
					for (const row of broadcastData) {
						if (!broadcastMap[row.phone_number]) {
							broadcastMap[row.phone_number] = { sent: 0, delivered: 0, read: 0 };
						}
						if (row.status === 'sent') broadcastMap[row.phone_number].sent++;
						else if (row.status === 'delivered') broadcastMap[row.phone_number].delivered++;
						else if (row.status === 'read') broadcastMap[row.phone_number].read++;
					}
				}
			})());
		}
		await Promise.all(broadcastPromises);

		// 3. For each branch, query ALL contacts at once with a single SQL call
		// Build SQL that returns counts per mobile number
		const results: Record<string, ContactResult> = {};

		// Initialize results for all contacts
		for (const phone of phoneNumbers) {
			results[phone] = {
				phoneNumber: phone,
				branchResults: [],
				totalCount: 0,
				totalAmount: 0,
				lastBillDate: null,
				broadcastStats: broadcastMap[phone] || { sent: 0, delivered: 0, read: 0 }
			};
		}

		// Build a lookup Set for fast phone matching
		const phoneSet = new Set(phoneNumbers.map((p: string) => p.trim()));

		// Query each branch in parallel — get ALL customers with bills, match in-memory
		const branchPromises = erpConfigs.map(async (config: any) => {
			if (!config?.tunnel_url) return;

			const baseUrl = config.tunnel_url.replace(/\/+$/, '');
			const branchData = Array.isArray(config.branches) ? config.branches[0] : config.branches;
			const branchMeta = {
				branchId: String(config.branch_id),
				branchName: config.branch_name || `Branch ${config.branch_id}`,
				locationEn: branchData?.location_en || 'Location N/A',
				locationAr: branchData?.location_ar || 'الموقع غير متاح'
			};

			// Query ALL customers with bills from this branch (no phone filter in SQL)
			// This avoids a massive IN clause with 21k+ values
			// IMPORTANT: Filter by erp_branch_id to prevent duplicates from synced databases
			const erpBranchId = config.erp_branch_id || config.branch_id;
			const sql = `
				SELECT 
					REPLACE(pc.Mobile, ' ', '') as phone_number,
					COUNT(itm.InvTransactionMasterID) as bill_cnt,
					ISNULL(SUM(itm.GrandTotal), 0) as bill_amt,
					MAX(itm.TransactionDate) as last_bill_date
				FROM PrivilegeCards pc
				INNER JOIN InvTransactionMaster itm 
					ON itm.BranchID = pc.BranchID 
					AND LTRIM(RTRIM(itm.PartyName)) = LTRIM(RTRIM(pc.CardHolderName))
				WHERE pc.BranchID = ${erpBranchId}
					AND pc.CardHolderName != ''
					AND pc.Mobile IS NOT NULL
					AND pc.Mobile != ''
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
				if (!contentType.includes('application/json')) {
					console.error(`Branch ${config.branch_id}: non-JSON response`);
					return;
				}

				const result = await response.json();

				if (result.success && result.recordset) {
					let matched = 0;
					for (const row of result.recordset) {
						const phone = row.phone_number?.trim();
						if (phone && phoneSet.has(phone)) {
							matched++;
							const branchLastDate = row.last_bill_date || null;
							results[phone].branchResults.push({
								...branchMeta,
								count: row.bill_cnt || 0,
								total: row.bill_amt || 0,
								lastBillDate: branchLastDate
							});
							results[phone].totalCount += (row.bill_cnt || 0);
							results[phone].totalAmount += (row.bill_amt || 0);
							// Track the latest bill date across all branches
							if (branchLastDate) {
								const existing = results[phone].lastBillDate;
								if (!existing || new Date(branchLastDate) > new Date(existing)) {
									results[phone].lastBillDate = branchLastDate;
								}
							}
						}
					}
					console.log(`✅ Branch ${config.branch_id} (${config.branch_name}): ${result.recordset.length} ERP customers, ${matched} matched`);
				} else {
					console.log(`⚠️ Branch ${config.branch_id}: no recordset returned`);
				}
			} catch (err: any) {
				console.error(`❌ Branch ${config.branch_id} error:`, err.message);
			}
		});

		await Promise.all(branchPromises);

		console.log(`📊 Batch complete: ${phoneNumbers.length} contacts processed`);
		return json({ success: true, results });

	} catch (error: any) {
		console.error('Batch bill counts error:', error);
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};
