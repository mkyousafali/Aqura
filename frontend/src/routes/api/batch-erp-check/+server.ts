import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

/**
 * Batch ERP Existence Check API
 * 
 * Checks if phone numbers exist in the ERP's PrivilegeCards table
 * across ALL branches via their Cloudflare tunnels.
 * 
 * This is separate from bill counts — a customer can exist in ERP
 * (registered with a PrivilegeCard) but have zero bills.
 */

const BRIDGE_API_SECRET = 'aqura-erp-bridge-2026';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { phoneNumbers } = await request.json();

		if (!phoneNumbers || !Array.isArray(phoneNumbers) || phoneNumbers.length === 0) {
			return json({ success: false, error: 'phoneNumbers array is required' }, { status: 400 });
		}

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
			const empty: Record<string, { exists: boolean; branches: string[] }> = {};
			for (const phone of phoneNumbers) {
				empty[phone] = { exists: false, branches: [] };
			}
			return json({ success: true, results: empty });
		}

		console.log(`🔍 ERP check: ${phoneNumbers.length} contacts × ${erpConfigs.length} branches`);

		const phoneSet = new Set(phoneNumbers.map((p: string) => p.trim()));

		// Build a lookup map: last 9 digits -> original phone number(s)
		// This handles ERP storing "96XXXXXXXXX" vs Aqura "966XXXXXXXXX"
		const phoneSuffixMap = new Map<string, string[]>();
		for (const phone of phoneNumbers) {
			const clean = phone.trim().replace(/\s/g, '');
			const suffix = clean.slice(-9); // last 9 digits = local Saudi number
			if (!phoneSuffixMap.has(suffix)) phoneSuffixMap.set(suffix, []);
			phoneSuffixMap.get(suffix)!.push(phone);
		}

		// Results: phone -> { exists, branches[] }
		const results: Record<string, { exists: boolean; branches: string[] }> = {};
		for (const phone of phoneNumbers) {
			results[phone] = { exists: false, branches: [] };
		}

		// Query each branch in parallel — check PrivilegeCards only (no bill join)
		const branchPromises = erpConfigs.map(async (config: any) => {
			if (!config?.tunnel_url) return;

			const baseUrl = config.tunnel_url.replace(/\/+$/, '');
			const branchName = config.branch_name || `Branch ${config.branch_id}`;
			const erpBranchId = config.erp_branch_id || config.branch_id;

			// Query PrivilegeCards only — just check if phone exists
			const sql = `
				SELECT DISTINCT
					REPLACE(pc.Mobile, ' ', '') as phone_number
				FROM PrivilegeCards pc
				WHERE pc.BranchID = ${erpBranchId}
					AND pc.Mobile IS NOT NULL
					AND pc.Mobile != ''
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
					let matched = 0;
					for (const row of result.recordset) {
						const phone = row.phone_number?.trim();
						if (!phone) continue;

						// Try exact match first
						if (phoneSet.has(phone)) {
							matched++;
							results[phone].exists = true;
							if (!results[phone].branches.includes(branchName)) {
								results[phone].branches.push(branchName);
							}
							continue;
						}

						// Fuzzy match by last 9 digits (handles 96X vs 966X mismatch)
						const suffix = phone.slice(-9);
						const matchedPhones = phoneSuffixMap.get(suffix);
						if (matchedPhones) {
							matched++;
							for (const origPhone of matchedPhones) {
								results[origPhone].exists = true;
								if (!results[origPhone].branches.includes(branchName)) {
									results[origPhone].branches.push(branchName);
								}
							}
						}
					}
					console.log(`✅ ERP check branch ${config.branch_id} (${branchName}): ${result.recordset.length} cards, ${matched} matched`);
				}
			} catch (err: any) {
				console.error(`❌ ERP check branch ${config.branch_id} error:`, err.message);
			}
		});

		await Promise.all(branchPromises);

		const existCount = Object.values(results).filter(r => r.exists).length;
		console.log(`🔍 ERP check complete: ${existCount}/${phoneNumbers.length} exist in ERP`);

		return json({ success: true, results });
	} catch (error: any) {
		console.error('ERP check error:', error);
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};
