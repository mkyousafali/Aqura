import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

const headers = { 'Cache-Control': 'no-store' };

export const GET: RequestHandler = async ({ cookies, url }) => {
	const kind = url.searchParams.get('interface');
	if (kind !== 'desktop' && kind !== 'mobile') return json({ error: 'Invalid interface.' }, { status: 400, headers });
	try {
		await requireBreakUser(cookies, kind);
	} catch {
		return json({ error: 'An active signed-in session is required.' }, { status: 401, headers });
	}
	try {
		const db = databaseClient();
		const barcode = url.searchParams.get('barcode');
		if (barcode !== null) {
			const scanned = barcode.trim();
			const branchId = Number(url.searchParams.get('branchId'));
			if (!Number.isSafeInteger(branchId) || branchId <= 0) return json({ error: 'Select a valid branch.' }, { status: 400, headers });
			if (!scanned || scanned.length > 100) return json({ error: 'Enter a valid barcode.' }, { status: 400, headers });
			const columns = 'id, product_group_id, base_unit_id, data, created_at, updated_at';
			const results = await Promise.all([
				db.from('Polosys_products').select(columns).eq('data->>barcode', scanned).limit(2),
				db.from('Polosys_products').select(columns).contains('data', { multi_units: [{ barcode: scanned }] }).limit(2)
			]);
			for (const result of results) if (result.error) throw result.error;
			const matches = [...new Map(results.flatMap(result => result.data || []).map(product => [product.id, product])).values()];
			if (!matches.length) return json({ error: 'No product found in Polosys_products for this barcode.' }, { status: 404, headers });
			if (matches.length > 1) return json({ error: 'This barcode matches multiple saved products. Resolve the duplicate barcode before checking.' }, { status: 409, headers });
			const { data: check, error: checkError } = await db.from('Polosys_product_barcode_checks')
				.select('checked_at').eq('product_id', matches[0].id).eq('branch_id', branchId).eq('barcode', scanned).maybeSingle();
			if (checkError) throw checkError;
			return json({ product: matches[0], check }, { headers });
		}
		async function readLookups(table: 'Polosys_units' | 'Polosys_product_groups') {
			const rows: { id: string; name: string; name_ar?: string | null }[] = [];
			for (let offset = 0; ; offset += 1000) {
				const { data, error } = await db.from(table).select('id, name, name_ar').order('name').range(offset, offset + 999);
				if (error) throw error;
				rows.push(...(data || []));
				if (!data || data.length < 1000) return rows;
			}
		}
		const [connections, branches, units, groups] = await Promise.all([
			db.from('erp_connections').select('branch_id, branch_name').eq('is_active', true).order('branch_name'),
			db.from('branches').select('id, name_en, name_ar, location_en'),
			readLookups('Polosys_units'),
			readLookups('Polosys_product_groups')
		]);
		if (connections.error) throw connections.error;
		if (branches.error) throw branches.error;
		return json({ units, groups, branches: (connections.data || []).map(connection => {
			const branch = branches.data?.find(item => Number(item.id) === Number(connection.branch_id));
			const name = branch?.name_en || branch?.name_ar || connection.branch_name;
			return { id: Number(connection.branch_id), name: branch?.location_en?.trim() || name };
		}) }, { headers });
	} catch {
		return json({ error: 'Unable to load Checker data. Please try again.' }, { status: 500, headers });
	}
};

export const POST: RequestHandler = async ({ cookies, url, request }) => {
	const kind = url.searchParams.get('interface');
	if (kind !== 'desktop' && kind !== 'mobile') return json({ error: 'Invalid interface.' }, { status: 400, headers });
	let actor;
	try {
		actor = await requireBreakUser(cookies, kind);
	} catch {
		return json({ error: 'An active signed-in session is required.' }, { status: 401, headers });
	}
	let body;
	try {
		body = await request.json();
	} catch {
		return json({ error: 'Invalid check request.' }, { status: 400, headers });
	}
	const branchId = Number(body?.branchId);
	const barcode = typeof body?.barcode === 'string' ? body.barcode.trim() : '';
	const productId = body?.productId;
	if (!Number.isSafeInteger(branchId) || branchId <= 0 || !barcode || barcode.length > 100
		|| typeof productId !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(productId)) {
		return json({ error: 'Select a branch and scan a valid product barcode.' }, { status: 400, headers });
	}
	try {
		const db = databaseClient();
		const [productResult, branchResult] = await Promise.all([
			db.from('Polosys_products').select('id, data').eq('id', productId).maybeSingle(),
			db.from('erp_connections').select('branch_id').eq('branch_id', branchId).eq('is_active', true).maybeSingle()
		]);
		if (productResult.error) throw productResult.error;
		if (branchResult.error) throw branchResult.error;
		const product = productResult.data;
		if (!branchResult.data) return json({ error: 'This branch is no longer available. Select another branch.' }, { status: 400, headers });
		if (!product || (product.data?.barcode !== barcode && !product.data?.multi_units?.some((unit: { barcode?: string }) => unit.barcode === barcode))) {
			return json({ error: 'The product barcode has changed. Scan it again before checking.' }, { status: 409, headers });
		}
		// Ignore repeated checks so the first confirmation and its author are preserved.
		const { error: saveError } = await db.from('Polosys_product_barcode_checks').upsert({
			product_id: productId, branch_id: branchId, barcode, checked_by: actor.id
		}, { onConflict: 'product_id,branch_id,barcode', ignoreDuplicates: true });
		if (saveError) throw saveError;
		const { data: check, error: readError } = await db.from('Polosys_product_barcode_checks')
			.select('checked_at').eq('product_id', productId).eq('branch_id', branchId).eq('barcode', barcode).single();
		if (readError) throw readError;
		return json({ check }, { headers });
	} catch {
		return json({ error: 'Unable to save checked status. Please try again.' }, { status: 500, headers });
	}
};
