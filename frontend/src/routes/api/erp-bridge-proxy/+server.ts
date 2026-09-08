import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

/**
 * ERP Bridge Proxy (AQ-SEC-003 remediation)
 *
 * Browser components (CloseBox.svelte, CounterCheck.svelte, CompleteBox.svelte) used to call
 * each branch's ERP bridge tunnel directly, with the shared bridge secret hardcoded in the
 * browser bundle. This route lets them call our own server instead — the tunnel URL and the
 * per-branch secret are looked up here, server-side only, and never sent to the browser.
 *
 * Contract: POST { branchId: <aqura branch_id>, sql: <string> }
 * The bridge's response (status + body) is mirrored back verbatim, so existing callers'
 * response.ok / response.json() / response.text() handling is unaffected.
 *
 * Both the tunnel URL and the secret come from erp_connections — no hardcoded fallback.
 * A branch row missing either value fails loudly instead of silently reusing a shared secret.
 */

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { branchId, sql } = await request.json();

		if (!branchId || !sql || typeof sql !== 'string') {
			return json({ success: false, error: 'branchId and sql are required' }, { status: 400 });
		}

		const supabaseUrl = env.VITE_SUPABASE_URL || '';
		const supabaseKey = env.VITE_SUPABASE_ANON_KEY || '';
		const supabase = createClient(supabaseUrl, supabaseKey);

		const { data: erpConfig, error: configError } = await supabase
			.from('erp_connections')
			.select('tunnel_url, bridge_api_secret')
			.eq('branch_id', branchId)
			.eq('is_active', true)
			.maybeSingle();

		if (configError) {
			return json({ success: false, error: configError.message }, { status: 500 });
		}
		if (!erpConfig?.tunnel_url || !erpConfig?.bridge_api_secret) {
			return json(
				{ success: false, error: 'No active ERP connection configured for this branch' },
				{ status: 404 }
			);
		}

		const baseUrl = erpConfig.tunnel_url.replace(/\/+$/, '');
		const secret = erpConfig.bridge_api_secret;

		const controller = new AbortController();
		const timeout = setTimeout(() => controller.abort(), 30000);

		let bridgeResponse: Response;
		try {
			bridgeResponse = await fetch(`${baseUrl}/query`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json', 'x-api-secret': secret },
				body: JSON.stringify({ sql }),
				signal: controller.signal
			});
		} finally {
			clearTimeout(timeout);
		}

		const bodyText = await bridgeResponse.text();
		return new Response(bodyText, {
			status: bridgeResponse.status,
			headers: { 'Content-Type': bridgeResponse.headers.get('content-type') || 'application/json' }
		});
	} catch (error: any) {
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};
