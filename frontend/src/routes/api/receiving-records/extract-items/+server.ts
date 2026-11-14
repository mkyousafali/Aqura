import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { AuthenticationRequiredError, createAuthenticatedSupabase } from '$lib/server/authenticatedSupabase';
import { extractPurchaseBill } from '$lib/server/purchaseBillExtraction';

const headers = { 'Cache-Control': 'no-store' };

export const POST: RequestHandler = async ({ request }) => {
	try {
		const db = createAuthenticatedSupabase(request);
		const { data: auth, error: authError } = await db.auth.getUser();
		if (authError || !auth.user) return json({ error: 'An active signed-in session is required.' }, { status: 401, headers });

		const body = await request.json().catch(() => null);
		const recordId = body?.recordId;
		if (!['string', 'number'].includes(typeof recordId) || !String(recordId).trim()) {
			return json({ error: 'A receiving record is required.' }, { status: 400, headers });
		}
		const { data: record, error } = await db.from('receiving_records')
			.select('original_bill_url,bill_number').eq('id', recordId).maybeSingle();
		if (error) throw error;
		if (!record?.original_bill_url) {
			return json({ error: 'Upload an Original Bill for this receiving record first.' }, { status: 404, headers });
		}

		const documentUrl = new URL(record.original_bill_url);
		const storageUrl = new URL(env.VITE_SUPABASE_URL || '');
		const path = documentUrl.pathname.match(/^\/storage\/v1\/object\/(?:public|sign|authenticated)\/original-bills\/(.+)$/);
		if (documentUrl.origin !== storageUrl.origin || !path) {
			return json({ error: 'The Original Bill must be an uploaded bill document.' }, { status: 400, headers });
		}
		const storagePath = decodeURIComponent(path[1]);
		const { data: document, error: downloadError } = await db.storage.from('original-bills').download(storagePath);
		if (downloadError || !document) throw downloadError || new Error('The Original Bill could not be downloaded.');
		if (document.size > 50 * 1024 * 1024) {
			return json({ error: 'The Original Bill must be 50 MB or smaller.' }, { status: 413, headers });
		}
		const mimeTypes: Record<string, string> = {
			pdf: 'application/pdf', jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp', gif: 'image/gif'
		};
		const contentType = document.type.split(';')[0].trim().toLowerCase();
		const extension = storagePath.split('.').pop()?.toLowerCase() || '';
		const mimeType = Object.values(mimeTypes).includes(contentType) ? contentType : mimeTypes[extension];
		if (!mimeType) {
			return json({ error: 'Use a PDF, JPEG, PNG, WebP or GIF Original Bill.' }, { status: 415, headers });
		}

		const bill = await extractPurchaseBill(mimeType, Buffer.from(await document.arrayBuffer()).toString('base64'), String(record.bill_number || ''));
		return json({ success: true, bill }, { headers });
	} catch (error) {
		if (error instanceof AuthenticationRequiredError) {
			return json({ error: error.message }, { status: 401, headers });
		}
		console.error('Original Bill item extraction failed:', error instanceof Error ? error.message : error);
		return json({ error: error instanceof Error ? error.message : 'Unable to read the Original Bill.' }, { status: 500, headers });
	}
};
