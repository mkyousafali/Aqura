import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

/**
 * Contact Bill Details API
 * 
 * Given a single phone number, returns individual bill records (date + amount)
 * from ALL ERP branches. Used when user clicks "Details" on a contact row.
 */

const BRIDGE_API_SECRET = 'aqura-erp-bridge-2026';

interface BillDetail {
	date: string;
	amount: number;
	branchId: string;
	branchName: string;
}

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { phoneNumber } = await request.json();

		if (!phoneNumber || typeof phoneNumber !== 'string') {
			return json({ success: false, error: 'phoneNumber is required' }, { status: 400 });
		}

		// Create Supabase client
		const supabaseUrl = env.VITE_SUPABASE_URL || 'https://supabase.urbanaqura.com';
		const supabaseKey = env.VITE_SUPABASE_ANON_KEY || '';
		const supabase = createClient(supabaseUrl, supabaseKey);

		// Get all active ERP connections
		const { data: erpConfigs, error: configError } = await supabase
			.from('erp_connections')
			.select('tunnel_url, erp_branch_id, branch_id, branch_name, branches(id, location_en, location_ar)')
			.eq('is_active', true)
			.order('branch_id');

		if (configError) {
			return json({ success: false, error: configError.message }, { status: 500 });
		}

		if (!erpConfigs || erpConfigs.length === 0) {
			return json({ success: true, bills: [] });
		}

		// Clean the phone number for SQL matching
		const cleanPhone = phoneNumber.replace(/\s/g, '');

		// Query each branch in parallel for individual bills
		const allBills: BillDetail[] = [];

		const branchPromises = erpConfigs.map(async (config: any) => {
			if (!config?.tunnel_url) return;

			const baseUrl = config.tunnel_url.replace(/\/+$/, '');
			const branchData = Array.isArray(config.branches) ? config.branches[0] : config.branches;
			const branchName = config.branch_name || `Branch ${config.branch_id}`;
			const branchId = String(config.branch_id);
			const erpBranchId = config.erp_branch_id || config.branch_id;

			// Get individual bill records for this phone number
			// IMPORTANT: Filter by erp_branch_id to prevent duplicates from synced databases
			const sql = `
				SELECT 
					itm.TransactionDate as bill_date,
					itm.GrandTotal as bill_amount,
					itm.InvTransactionMasterID as bill_id
				FROM PrivilegeCards pc
				INNER JOIN InvTransactionMaster itm 
					ON itm.BranchID = pc.BranchID 
					AND LTRIM(RTRIM(itm.PartyName)) = LTRIM(RTRIM(pc.CardHolderName))
				WHERE pc.BranchID = ${erpBranchId}
					AND REPLACE(pc.Mobile, ' ', '') = '${cleanPhone}'
					AND pc.CardHolderName != ''
				ORDER BY itm.TransactionDate DESC
			`;

			try {
				const controller = new AbortController();
				const timeout = setTimeout(() => controller.abort(), 30000);

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
						allBills.push({
							date: row.bill_date || '',
							amount: row.bill_amount || 0,
							branchId,
							branchName
						});
					}
				}
			} catch (err: any) {
				console.error(`❌ Bill details branch ${branchId} error:`, err.message);
			}
		});

		await Promise.all(branchPromises);

		// Sort all bills by date descending
		allBills.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

		return json({ success: true, bills: allBills });

	} catch (error: any) {
		console.error('Contact bill details error:', error);
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};
