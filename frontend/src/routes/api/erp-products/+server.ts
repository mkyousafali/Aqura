import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createAuthenticatedSupabase } from '$lib/server/authenticatedSupabase';
import { closestPurchasedProducts } from '$lib/server/purchaseProductMatching';

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

		const supabase = createAuthenticatedSupabase(request);

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
		} else if (action === 'purchase-product') {
			return await lookupPurchaseProduct(baseUrl, secret, barcode, erpBranchId);
		} else if (action === 'purchase-name-matches') {
			return await matchPreviouslyPurchasedProducts(baseUrl, secret, body.vendorId, body.names, erpBranchId);
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

async function lookupPurchaseProduct(baseUrl: string, secret: string, barcode: unknown, erpBranchId?: number) {
	const scannedBarcode = typeof barcode === 'string' ? barcode.trim() : '';
	const branchId = Number(erpBranchId);
	if (!scannedBarcode || scannedBarcode.length > 100 || /[\u0000-\u001f\u007f]/.test(scannedBarcode)) {
		return json({ success: false, error: 'Enter a valid barcode.' }, { status: 400 });
	}
	if (!Number.isSafeInteger(branchId) || branchId <= 0) {
		return json({ success: false, error: 'The branch ERP mapping is unavailable.' }, { status: 400 });
	}

	const escapedBarcode = scannedBarcode.replace(/'/g, "''");
	const matchedSql = `SELECT DISTINCT pb.ProductID FROM ProductBatches pb
		WHERE pb.BranchID = ${branchId} AND (
			pb.MannualBarcode = N'${escapedBarcode}'
			OR CAST(pb.AutoBarcode AS NVARCHAR(100)) = N'${escapedBarcode}'
			OR pb.Unit2Barcode = N'${escapedBarcode}'
			OR pb.Unit3Barcode = N'${escapedBarcode}'
			OR EXISTS (SELECT 1 FROM ProductUnits pu WHERE pu.ProductBatchID = pb.ProductBatchID
				AND pu.BranchID = pb.BranchID AND pu.BarCode = N'${escapedBarcode}')
			OR EXISTS (SELECT 1 FROM ProductBarcodes pbc WHERE pbc.ProductBatchID = pb.ProductBatchID
				AND pbc.Barcode = N'${escapedBarcode}')
		)`;
	const response = await proxyQuery(baseUrl, secret, purchaseProductSql(branchId, matchedSql));
	const result = await response.json();
	if (!response.ok || result.success !== true || !Array.isArray(result.recordset)) {
		return json({ success: false, error: result.error || 'Unable to load ERP product barcodes.' }, { status: 502 });
	}
	const rows = result.recordset;
	if (!rows.length) return json({ success: false, error: 'Barcode not found in the branch ERP.' }, { status: 404 });
	if (new Set(rows.map((row: any) => String(row.ProductID))).size > 1) {
		return json({ success: false, error: 'This barcode matches multiple ERP products.' }, { status: 409 });
	}
	const product = purchaseProductsFromRows(rows)[0];
	if (!product) return json({ success: false, error: 'The ERP product has no English name.' }, { status: 422 });
	return json({
		success: true,
		product: {
			...product,
			id: rows[0].ProductID,
			scannedBarcode: product.barcodes.find((code) => code.barcode.toLowerCase() === scannedBarcode.toLowerCase())?.barcode || scannedBarcode
		}
	}, { headers: { 'Cache-Control': 'no-store' } });
}

function purchaseProductSql(branchId: number, matchedSql: string) {
	return `SELECT p.ProductID, p.ProductName, codes.Barcode, codes.UnitName, codes.MultiFactor
	FROM (${matchedSql}) matched
	INNER JOIN Products p ON p.ProductID = matched.ProductID AND p.BranchID = ${branchId}
	INNER JOIN ProductBatches pb ON pb.ProductID = p.ProductID AND pb.BranchID = p.BranchID
	CROSS APPLY (
		SELECT CAST(pu.BarCode AS NVARCHAR(100)) AS Barcode,
			(SELECT TOP 1 u.UnitName FROM UnitOfMeasures u WHERE u.UnitID = pu.UnitID AND u.BranchID = pb.BranchID) AS UnitName,
			pu.MultiFactor, 0 AS SourcePriority
		FROM ProductUnits pu WHERE pu.ProductBatchID = pb.ProductBatchID AND pu.BranchID = pb.BranchID
		UNION ALL
		SELECT direct.Barcode,
			(SELECT TOP 1 u.UnitName FROM UnitOfMeasures u WHERE u.UnitID = direct.UnitID AND u.BranchID = pb.BranchID),
			direct.MultiFactor, 1
		FROM (VALUES
			(CAST(pb.MannualBarcode AS NVARCHAR(100)), COALESCE(pb.PackingUnitID, p.BasicUnitID), 1),
			(CAST(pb.AutoBarcode AS NVARCHAR(100)), COALESCE(pb.PackingUnitID, p.BasicUnitID), 1),
			(CAST(pb.Unit2Barcode AS NVARCHAR(100)), pb.Unit2ID, pb.Unit2Qty),
			(CAST(pb.Unit3Barcode AS NVARCHAR(100)), pb.Unit3ID, pb.Unit3Qty)
		) direct(Barcode, UnitID, MultiFactor)
		UNION ALL
		SELECT CAST(pbc.Barcode AS NVARCHAR(100)),
			(SELECT TOP 1 u.UnitName FROM UnitOfMeasures u WHERE u.UnitID = pbc.UnitID AND u.BranchID = pb.BranchID),
			COALESCE(
				(SELECT TOP 1 pu.MultiFactor FROM ProductUnits pu WHERE pu.ProductBatchID = pb.ProductBatchID
					AND pu.BranchID = pb.BranchID AND pu.UnitID = pbc.UnitID),
				CASE
					WHEN pbc.UnitID = pb.Unit2ID THEN pb.Unit2Qty
					WHEN pbc.UnitID = pb.Unit3ID THEN pb.Unit3Qty
					WHEN pbc.UnitID IN (pb.PackingUnitID, p.BasicUnitID) THEN 1
				END
			), 2
		FROM ProductBarcodes pbc WHERE pbc.ProductBatchID = pb.ProductBatchID
	) codes
	WHERE NULLIF(LTRIM(RTRIM(codes.Barcode)), '') IS NOT NULL
	ORDER BY codes.SourcePriority, pb.ProductBatchID DESC, codes.MultiFactor`;
}

type PurchaseProduct = {
	id: string;
	name: string;
	barcodes: { barcode: string; unit: string; multiFactor: number | null }[];
};

function purchaseProductsFromRows(rows: Record<string, unknown>[]): PurchaseProduct[] {
	const products = new Map<string, PurchaseProduct>();
	for (const row of rows) {
		const id = String(row.ProductID);
		const name = String(row.ProductName || '').trim();
		if (!name) continue;
		if (!products.has(id)) products.set(id, { id, name, barcodes: [] });
		const product = products.get(id)!;
		const code = String(row.Barcode || '').trim();
		if (!code || product.barcodes.some((entry) => entry.barcode.toLowerCase() === code.toLowerCase())) continue;
		const multiFactor = Number(row.MultiFactor);
		product.barcodes.push({
			barcode: code,
			unit: String(row.UnitName || '').trim(),
			multiFactor: Number.isFinite(multiFactor) && multiFactor > 0 ? multiFactor : null
		});
	}
	return [...products.values()];
}

async function matchPreviouslyPurchasedProducts(baseUrl: string, secret: string, vendorId: unknown, names: unknown, erpBranchId?: number) {
	const branchId = Number(erpBranchId);
	const vendorCode = typeof vendorId === 'string' || typeof vendorId === 'number' ? String(vendorId).trim() : '';
	if (!Number.isSafeInteger(branchId) || branchId <= 0 || !vendorCode || vendorCode.length > 50
		|| /[\u0000-\u001f\u007f]/.test(vendorCode)) {
		return json({ success: false, error: 'A valid branch ERP mapping and vendor are required.' }, { status: 400 });
	}
	if (!Array.isArray(names) || !names.length || names.length > 500
		|| names.some((name) => typeof name !== 'string' || name.length > 500)) {
		return json({ success: false, error: 'Provide up to 500 bill product names.' }, { status: 400 });
	}
	const escapedVendorCode = vendorCode.replace(/'/g, "''");
	const historySql = `SELECT p.ProductID, p.ProductName FROM Products p
		WHERE p.BranchID = ${branchId} AND EXISTS (
			SELECT 1 FROM InvTransactionMaster m
			INNER JOIN AccLedgers vendor ON vendor.LedgerID = m.LedgerID AND vendor.BranchID = m.BranchID
			INNER JOIN InvTransactionDetails d ON d.InvTransactionMasterID = m.InvTransactionMasterID AND d.BranchID = m.BranchID
			INNER JOIN ProductBatches pb ON pb.ProductBatchID = d.ProductBatchID AND pb.BranchID = d.BranchID
			WHERE m.BranchID = p.BranchID AND pb.ProductID = p.ProductID
				AND m.VoucherType = 'PI' AND m.IsActive = 1 AND vendor.LedgerCode = N'${escapedVendorCode}'
		)`;
	const historyResponse = await proxyQuery(baseUrl, secret, historySql);
	const history = await historyResponse.json();
	if (!historyResponse.ok || history.success !== true || !Array.isArray(history.recordset)) {
		return json({ success: false, error: history.error || 'Unable to load this vendor\'s previous ERP purchases.' }, { status: 502 });
	}
	const products = history.recordset.map((row: Record<string, unknown>) => ({
		id: String(row.ProductID), name: String(row.ProductName || '').trim()
	})).filter((product: { id: string; name: string }) => product.name && /^\d+$/.test(product.id));
	const rankedIds = closestPurchasedProducts(names, products);
	const selectedIds = [...new Set(rankedIds.flat())];
	let details = new Map<string, PurchaseProduct>();
	if (selectedIds.length) {
		const response = await proxyQuery(baseUrl, secret, purchaseProductSql(branchId,
			`SELECT ProductID FROM Products WHERE BranchID = ${branchId} AND ProductID IN (${selectedIds.join(',')})`));
		const result = await response.json();
		if (!response.ok || result.success !== true || !Array.isArray(result.recordset)) {
			return json({ success: false, error: result.error || 'Unable to load ERP product units.' }, { status: 502 });
		}
		details = new Map(purchaseProductsFromRows(result.recordset).map((product) => [product.id, product]));
	}
	return json({ success: true, matches: rankedIds.map((ids) => ids.map((id) =>
		details.get(id) || { ...products.find((product: { id: string }) => product.id === id), barcodes: [] }))
	}, { headers: { 'Cache-Control': 'no-store' } });
}

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
