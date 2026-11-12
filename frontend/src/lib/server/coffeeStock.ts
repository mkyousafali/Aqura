import { COFFEE_COUNTER, type BusinessCounterProfile } from '$lib/types/businessCounter';
import type { CoffeeBranchStockValue } from '$lib/types/coffeeStock';

export async function readCoffeeStockValue(config: any, profile: BusinessCounterProfile = COFFEE_COUNTER): Promise<CoffeeBranchStockValue> {
	const details = Array.isArray(config.branches) ? config.branches[0] : config.branches;
	const result: CoffeeBranchStockValue = {
		branch: { id: String(config.branch_id), nameEn: details?.name_en || config.branch_name || String(config.branch_id),
			nameAr: details?.name_ar || config.branch_name || String(config.branch_id), status: 'unavailable' },
		value: null, missingCostBatches: 0, missingQuantityBatches: 0, negativeStockBatches: 0
	};
	const erpBranchId = Number(config.erp_branch_id);
	if (!config.tunnel_url || !config.bridge_api_secret || !Number.isSafeInteger(erpBranchId) || erpBranchId <= 0) return result;
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), 30000);
	try {
		const group = profile.productGroup.replace(/'/g, "''");
		// Stock is the ERP's maintained batch balance. Include every batch and
		// preserve negative balances. Use the same pre-VAT cost priority as Products.
		const sql = `SELECT ISNULL(SUM(pb.Stock * batchCost.cost), 0) AS stock_value,
			ISNULL(SUM(CASE WHEN pb.Stock <> 0 AND batchCost.cost IS NULL THEN 1 ELSE 0 END), 0) AS missing_cost_batches,
			ISNULL(SUM(CASE WHEN pb.Stock IS NULL THEN 1 ELSE 0 END), 0) AS missing_quantity_batches,
			ISNULL(SUM(CASE WHEN pb.Stock < 0 THEN 1 ELSE 0 END), 0) AS negative_stock_batches
			FROM ProductBatches pb
			INNER JOIN Products p ON p.ProductID = pb.ProductID AND p.BranchID = pb.BranchID
			INNER JOIN ProductGroups g ON g.ProductGroupID = p.ProductGroupID AND g.BranchID = p.BranchID
			CROSS APPLY (SELECT COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0),
				NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0),
				pb.StdPurchasePrice, pb.LastPurchaseCost, pb.LandingCost, pb.AvgPurchaseCost) AS cost) batchCost
			WHERE pb.BranchID = ${erpBranchId} AND LTRIM(RTRIM(g.GroupName)) = N'${group}'`;
		const response = await fetch(`${config.tunnel_url.replace(/\/+$/, '')}/query`, {
			method: 'POST', headers: { 'Content-Type': 'application/json', 'x-api-secret': config.bridge_api_secret },
			body: JSON.stringify({ sql }), signal: controller.signal
		});
		const data = await response.json();
		if (!response.ok || data?.success !== true || !Array.isArray(data.recordset) || data.recordset.length !== 1) throw new Error('ERP stock valuation failed');
		const row = data.recordset[0];
		const value = row.stock_value == null ? NaN : Number(row.stock_value);
		const missingCost = Number(row.missing_cost_batches), missingQuantity = Number(row.missing_quantity_batches), negativeStock = Number(row.negative_stock_batches);
		if (!Number.isFinite(value) || ![missingCost, missingQuantity, negativeStock].every(count => Number.isSafeInteger(count) && count >= 0)) throw new Error('Incomplete ERP stock valuation');
		result.missingCostBatches = missingCost;
		result.missingQuantityBatches = missingQuantity;
		result.negativeStockBatches = negativeStock;
		result.value = missingCost === 0 && missingQuantity === 0 ? value : null;
		result.branch.status = 'loaded';
	} catch {
		result.branch.status = controller.signal.aborted ? 'timeout' : 'failed';
	} finally {
		clearTimeout(timeout);
	}
	return result;
}
