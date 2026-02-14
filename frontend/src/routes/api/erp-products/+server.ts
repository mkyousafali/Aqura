import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

/**
 * ERP Products API — HTTP Bridge Proxy
 * 
 * Instead of connecting directly to SQL Server (impossible from Vercel),
 * this proxies requests to the ERP Bridge API running on each branch's
 * server, exposed via Cloudflare Tunnel.
 * 
 * Bridge endpoints: /test, /sync, /update-expiry
 * Auth: x-api-secret header
 */

const BRIDGE_API_SECRET = 'aqura-erp-bridge-2026';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const body = await request.json();
		const { action, tunnelUrl, erpBranchId, appBranchId, barcode, newExpiryDate } = body;

		if (!tunnelUrl) {
			return json({ success: false, error: 'No tunnel URL configured for this branch' }, { status: 400 });
		}

		// Normalize tunnel URL (remove trailing slash)
		const baseUrl = tunnelUrl.replace(/\/+$/, '');

		if (action === 'test') {
			return await proxyTest(baseUrl);
		} else if (action === 'sync') {
			return await proxySync(baseUrl, erpBranchId, appBranchId);
		} else if (action === 'update-expiry') {
			return await proxyUpdateExpiry(baseUrl, barcode, newExpiryDate);
		}

		return json({ error: 'Invalid action' }, { status: 400 });
	} catch (error: any) {
		console.error('ERP Products API error:', error);
		return json({ error: error.message || 'Internal server error' }, { status: 500 });
	}
};

async function proxyTest(baseUrl: string) {
	try {
		const resp = await fetch(`${baseUrl}/test`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'x-api-secret': BRIDGE_API_SECRET
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

async function proxySync(baseUrl: string, erpBranchId?: number, appBranchId?: number) {
	try {
		const resp = await fetch(`${baseUrl}/sync`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'x-api-secret': BRIDGE_API_SECRET
			},
			body: JSON.stringify({ erpBranchId, appBranchId })
		});
		const data = await resp.json();
		return json(data, { status: resp.ok ? 200 : 500 });
	} catch (error: any) {
		console.error('Bridge sync error:', error);
		return json({ success: false, error: `Bridge unreachable: ${error.message}` }, { status: 500 });
	}
}

async function proxyUpdateExpiry(baseUrl: string, barcode: string, newExpiryDate: string) {
	try {
		const resp = await fetch(`${baseUrl}/update-expiry`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'x-api-secret': BRIDGE_API_SECRET
			},
			body: JSON.stringify({ barcode, newExpiryDate })
		});
		const data = await resp.json();
		return json(data, { status: resp.ok ? 200 : 500 });
	} catch (error: any) {
		console.error('Bridge update-expiry error:', error);
		return json({ success: false, error: `Bridge unreachable: ${error.message}` }, { status: 500 });
	}
}
