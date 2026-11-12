import { json, type RequestHandler } from '@sveltejs/kit';
import { AuthenticationRequiredError, createAuthenticatedSupabase } from '$lib/server/authenticatedSupabase';
import { type BakeryBranch, type BakeryProduct } from '$lib/types/bakery';

import type { BusinessCounterProfile } from '$lib/types/businessCounter';

const headers = { 'Cache-Control': 'no-store' };
const PAGE_SIZE = 500;

function priceOrNull(value: unknown): number | null {
	if (value == null || (typeof value === 'string' && value.trim() === '')) return null;
	const price = Number(value);
	return Number.isFinite(price) ? price : null;
}

async function loadBranch(profile: BusinessCounterProfile, config: any): Promise<{ branch: BakeryBranch; products: BakeryProduct[] }> {
	const details = Array.isArray(config.branches) ? config.branches[0] : config.branches;
	const branch: BakeryBranch = {
		id: String(config.branch_id),
		nameEn: details?.name_en || config.branch_name || String(config.branch_id),
		nameAr: details?.name_ar || config.branch_name || String(config.branch_id),
		status: 'unavailable'
	};
	const erpBranchId = Number(config.erp_branch_id);
	if (!config.tunnel_url || !config.bridge_api_secret || !Number.isSafeInteger(erpBranchId) || erpBranchId <= 0) {
		return { branch, products: [] };
	}

	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), 30000);
	try {
		const products: BakeryProduct[] = [];
		let offset = 0;
		let total = 0;
		const group = profile.productGroup.replace(/'/g, "''");
		do {
			// Read product masters, including products without batches. Keep all joins
			// scoped to the connection's ERP branch; IDs can repeat across branches.
			const sql = `SELECT * FROM (
				SELECT p.ProductID AS product_id, p.ProductName AS name_en,
					p.ItemNameinSecondLanguage AS name_ar, u.UnitName AS unit_name,
					COALESCE(NULLIF(LTRIM(RTRIM(CAST(pb.MannualBarcode AS NVARCHAR(100)))), N''),
						CAST(pb.AutoBarcode AS NVARCHAR(100)), N'') AS barcode,
					pb.StdSalesPrice AS sales_price,
					pb.cost,
					COUNT(*) OVER() AS total_rows,
					ROW_NUMBER() OVER(ORDER BY p.ProductID) AS row_number
				FROM Products p
				INNER JOIN ProductGroups g ON g.ProductGroupID = p.ProductGroupID AND g.BranchID = p.BranchID
				LEFT JOIN UnitOfMeasures u ON u.UnitID = p.BasicUnitID AND u.BranchID = p.BranchID
				OUTER APPLY (SELECT TOP 1 b.MannualBarcode, b.AutoBarcode, b.StdSalesPrice,
					-- Follow the existing ERP cost preference, preserving missing values.
					COALESCE(NULLIF(b.StdPurchasePrice, 0), NULLIF(b.LastPurchaseCost, 0),
						NULLIF(b.LandingCost, 0), NULLIF(b.AvgPurchaseCost, 0),
						b.StdPurchasePrice, b.LastPurchaseCost, b.LandingCost, b.AvgPurchaseCost) AS cost
					FROM ProductBatches b
					WHERE b.ProductID = p.ProductID AND b.BranchID = p.BranchID ORDER BY b.ProductBatchID DESC) pb
				WHERE p.BranchID = ${erpBranchId} AND LTRIM(RTRIM(g.GroupName)) = N'${group}'
			) bakery WHERE row_number > ${offset} AND row_number <= ${offset + PAGE_SIZE} ORDER BY row_number`;
			const response = await fetch(`${config.tunnel_url.replace(/\/+$/, '')}/query`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json', 'x-api-secret': config.bridge_api_secret },
				body: JSON.stringify({ sql }),
				signal: controller.signal
			});
			const result = await response.json();
			if (!response.ok || result?.success !== true || !Array.isArray(result.recordset)) {
				throw new Error('ERP product query failed');
			}
			const rows = result.recordset;
			if (offset === 0 && rows.length === 0) break;
			const pageTotal = Number(rows[0]?.total_rows);
			if (!Number.isSafeInteger(pageTotal) || pageTotal < 0 || (offset > 0 && pageTotal !== total)) {
				throw new Error('Incomplete ERP product response');
			}
			total = pageTotal;
			if (rows.length !== Math.min(PAGE_SIZE, total - offset)) {
				throw new Error('Incomplete ERP product page');
			}
			for (const row of rows) {
				products.push({
					branchId: branch.id,
					productId: String(row.product_id),
					barcode: String(row.barcode ?? '').trim(),
					nameEn: String(row.name_en ?? '').trim(),
					nameAr: String(row.name_ar ?? '').trim(),
					unitName: String(row.unit_name ?? '').trim(),
					salesPrice: priceOrNull(row.sales_price),
					cost: priceOrNull(row.cost)
				});
			}
			offset += rows.length;
		} while (offset < total);
		branch.status = 'loaded';
		return { branch, products };
	} catch {
		branch.status = controller.signal.aborted ? 'timeout' : 'failed';
		return { branch, products: [] };
	} finally {
		clearTimeout(timeout);
	}
}

export function createCounterProductsHandler(profile: BusinessCounterProfile): RequestHandler {
	return async ({ request, url }) => {
	try {
		const db = createAuthenticatedSupabase(request);
		const { data: auth, error: authError } = await db.auth.getUser();
		if (authError || !auth.user) throw new AuthenticationRequiredError('Authenticated session is required');
		const branchId = url.searchParams.get('branchId');
		if (branchId !== null && (!/^\d+$/.test(branchId) || !Number.isSafeInteger(Number(branchId)) || Number(branchId) <= 0)) {
			return json({ success: false, error: 'Invalid branch' }, { status: 400, headers });
		}
		let query = db.from('erp_connections')
			.select('branch_id, branch_name, erp_branch_id, tunnel_url, bridge_api_secret, branches(name_en, name_ar)')
			.eq('is_active', true).order('branch_id');
		if (branchId) query = query.eq('branch_id', Number(branchId));
		const { data: configs, error } = await query;
		if (error) throw error;
		const results = await Promise.all((configs || []).map(config => loadBranch(profile, config)));
		return json({
			success: true,
			branches: results.map(result => result.branch),
			products: results.flatMap(result => result.products)
		}, { headers });
	} catch (error) {
		const unauthorized = error instanceof AuthenticationRequiredError;
		return json({ success: false, error: unauthorized ? 'Authenticated session is required' : `Unable to load ${profile.id} products` }, {
			status: unauthorized ? 401 : 500, headers
		});
	}
};
}
