import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

/**
 * Branch Supabase Proxy — bypasses CORS for tunnel requests
 * 
 * When syncing data to a branch Supabase via Cloudflare Tunnel,
 * the browser blocks XHR due to CORS. This endpoint proxies
 * the request server-side where CORS doesn't apply.
 */

export const POST: RequestHandler = async ({ request }) => {
	try {
		const body = await request.json();
		const { method, baseUrl, path, apiKey, payload } = body;

		if (!baseUrl || !path) {
			return json({ success: false, error: 'Missing baseUrl or path' }, { status: 400 });
		}

		const url = `${baseUrl.replace(/\/+$/, '')}${path}`;
		const headers: Record<string, string> = {
			'Content-Type': 'application/json'
		};

		if (apiKey) {
			headers['apikey'] = apiKey;
			headers['Authorization'] = `Bearer ${apiKey}`;
		}

		if (method === 'POST') {
			headers['Prefer'] = 'return=minimal';
		}

		const fetchOptions: RequestInit = {
			method: method || 'GET',
			headers,
			signal: AbortSignal.timeout(120000) // 120s timeout for large syncs/deploys
		};

		if (payload && (method === 'POST' || method === 'PATCH' || method === 'PUT')) {
			fetchOptions.body = JSON.stringify(payload);
		}

		const response = await fetch(url, fetchOptions);
		const responseText = await response.text();

		if (!response.ok) {
			// Always return 200 from proxy — errors are in the JSON body
			// This prevents browser console from showing red 404/400 errors
			// for expected failures (e.g., deleting tables that don't exist on branch)
			return json({
				success: false,
				statusCode: response.status,
				error: `${method} ${path}: ${response.status} ${responseText}`
			});
		}

		// Try to parse JSON, or return null for empty responses
		let data = null;
		if (responseText) {
			try {
				data = JSON.parse(responseText);
			} catch {
				data = null;
			}
		}

		return json({ success: true, data });
	} catch (err: any) {
		return json({
			success: false,
			error: err.message || 'Proxy request failed'
		}, { status: 500 });
	}
};
