import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

/**
 * ERP Products API — HTTP Bridge Proxy
 *
 * Instead of connecting directly to SQL Server (impossible from Vercel),
 * this proxies requests to the ERP Bridge API running on each branch's
 * server, exposed via Cloudflare Tunnel.
 *
 * Bridge endpoints: /test, /sync, /price-check, /query
 * Auth: x-api-secret header
 *
 * AQ-SEC-003: callers send only { action, branchId, ... } — never a tunnel URL or secret.
 * Both are looked up here, server-side, from erp_connections.bridge_api_secret /
 * erp_connections.tunnel_url for that branch. There is no hardcoded fallback, so a branch
 * that hasn't been saved to erp_connections yet simply can't be tested — "Test Connection"
 * only works after the connection is saved.
 */

export const POST: RequestHandler = async ({ request }) => {
	try {
		const body = await request.json();
		const { action, branchId, barcode, limit, offset } = body;

		if (!branchId) {
			return json({ success: false, error: 'branchId is required' }, { status: 400 });
		}

		const supabaseUrl = env.VITE_SUPABASE_URL || '';
		const supabaseKey = env.VITE_SUPABASE_ANON_KEY || '';
		const supabase = createClient(supabaseUrl, supabaseKey);

		const { data: conn, error: connError } = await supabase
			.from('erp_connections')
			.select('tunnel_url, erp_branch_id, bridge_api_secret')
			.eq('branch_id', branchId)
			.eq('is_active', true)
			.single();

		if (connError || !conn?.tunnel_url || !conn?.bridge_api_secret) {
			return json({ success: false, error: 'No active ERP connection configured for this branch' }, { status: 404 });
		}

		const baseUrl = conn.tunnel_url.replace(/\/+$/, '');
		const secret = conn.bridge_api_secret;
		const erpBranchId = conn.erp_branch_id;

		if (action === 'test') {
			return await proxyTest(baseUrl, secret);
		} else if (action === 'sync') {
			return await proxySync(baseUrl, secret, erpBranchId, limit, offset);
		} else if (action === 'update-expiry') {
			return json(
				{ success: false, error: 'ERP expiry updates are disabled; expiry dates are managed in Supabase only.' },
				{ status: 410 }
			);
		} else if (action === 'price-check') {
			return await proxyPriceCheck(baseUrl, secret, barcode, erpBranchId);
		} else if (action === 'query') {
			const { sql } = body;
			return await proxyQuery(baseUrl, secret, sql);
		}

		return json({ error: 'Invalid action' }, { status: 400 });
	} catch (error: any) {
		console.error('ERP Products API error:', error);
		return json({ error: error.message || 'Internal server error' }, { status: 500 });
	}
};

async function proxyTest(baseUrl: string, secret: string) {
	try {
		const resp = await fetch(`${baseUrl}/test`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'x-api-secret': secret
			},
			body: JSON.stringify({})
		});
		const data = await resp.json();
		return json(data);
	} catch (error: any) {
		console.error('Bridge test error:', error);
		return json({ success: false, message: `Bridge unreachable: ${error.message}` });
	}
}

async function proxySync(baseUrl: string, secret: string, erpBranchId?: number, limit?: number, offset?: number) {
	try {
		// 45s timeout to avoid Cloudflare/Vercel gateway timeouts
		const controller = new AbortController();
		const timeout = setTimeout(() => controller.abort(), 45000);

		const resp = await fetch(`${baseUrl}/sync`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'x-api-secret': secret
			},
			body: JSON.stringify({ erpBranchId, limit, offset }),
			signal: controller.signal
		});
		clearTimeout(timeout);

		// Check if response is HTML (Cloudflare error page) instead of JSON
		const contentType = resp.headers.get('content-type') || '';
		if (!contentType.includes('application/json')) {
			const text = await resp.text();
			console.error('Bridge returned non-JSON:', text.substring(0, 200));
			// If the bridge is still building, tell client to retry
			return json({
				success: true, status: 'building', retry: true,
				message: 'Bridge is processing... please wait (retrying automatically)'
			});
		}

		const data = await resp.json();
		return json(data, { status: resp.ok ? 200 : 500 });
	} catch (error: any) {
		console.error('Bridge sync error:', error);
		// On timeout or network error, tell client to retry instead of failing
		if (error.name === 'AbortError') {
			return json({
				success: true, status: 'building', retry: true,
				message: 'Bridge is still processing (timeout). Retrying automatically...'
			});
		}
		return json({ success: false, error: `Bridge unreachable: ${error.message}` }, { status: 500 });
	}
}

async function proxyQuery(baseUrl: string, secret: string, sql: string) {
	try {
		const controller = new AbortController();
		const timeout = setTimeout(() => controller.abort(), 30000);

		const resp = await fetch(`${baseUrl}/query`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', 'x-api-secret': secret },
			body: JSON.stringify({ sql }),
			signal: controller.signal
		});
		clearTimeout(timeout);

		const contentType = resp.headers.get('content-type') || '';
		if (!contentType.includes('application/json')) {
			return json({ success: false, error: 'Bridge returned non-JSON response' }, { status: 502 });
		}

		const data = await resp.json();
		return json(data, { status: resp.ok ? 200 : 500 });
	} catch (error: any) {
		console.error('Bridge query error:', error);
		if (error.name === 'AbortError') {
			return json({ success: false, error: 'Bridge timed out' }, { status: 504 });
		}
		return json({ success: false, error: `Bridge unreachable: ${error.message}` }, { status: 500 });
	}
}

async function proxyPriceCheck(baseUrl: string, secret: string, barcode: string, erpBranchId?: number) {
	try {
		const controller = new AbortController();
		const timeout = setTimeout(() => controller.abort(), 15000);

		// Single round-trip to bridge — all SQL done server-side
		const resp = await fetch(`${baseUrl}/price-check`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', 'x-api-secret': secret },
			body: JSON.stringify({ barcode, erpBranchId }),
			signal: controller.signal
		});
		clearTimeout(timeout);
		const data = await resp.json();
		return json(data, { status: data.success ? 200 : 404 });
	} catch (error: any) {
		console.error('Bridge price-check error:', error);
		if (error.name === 'AbortError') {
			return json({ success: false, error: 'Bridge timed out' }, { status: 504 });
		}
		return json({ success: false, error: `Bridge unreachable: ${error.message}` }, { status: 500 });
	}
}
