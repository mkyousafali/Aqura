import { json, type RequestHandler } from '@sveltejs/kit';
import { AuthenticationRequiredError, createAuthenticatedSupabase } from '$lib/server/authenticatedSupabase';
import { type BakeryBranch, type BakerySale, type BakeryDailySale } from '$lib/types/bakery';

import type { BusinessCounterProfile } from '$lib/types/businessCounter';

import { counterSalesScope } from './businessCounterScope';

const headers = { 'Cache-Control': 'no-store' };
const PAGE_SIZE = 500;

async function loadBranch(profile: BusinessCounterProfile, config: any, date: string, monthly = false): Promise<{ branch: BakeryBranch; sales: BakerySale[]; dailySales: BakeryDailySale[] }> {
	const details = Array.isArray(config.branches) ? config.branches[0] : config.branches;
	const branch: BakeryBranch = {
		id: String(config.branch_id),
		nameEn: details?.name_en || config.branch_name || String(config.branch_id),
		nameAr: details?.name_ar || config.branch_name || String(config.branch_id),
		status: 'unavailable'
	};
	const erpBranchId = Number(config.erp_branch_id);
	if (!config.tunnel_url || !config.bridge_api_secret || !Number.isSafeInteger(erpBranchId) || erpBranchId <= 0) {
		return { branch, sales: [], dailySales: [] };
	}
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), 30000);
	try {
		const sales: BakerySale[] = [];
		const dailySales: BakeryDailySale[] = [];
		let offset = 0;
		let total = 0;
		const salesScope = counterSalesScope(profile, config.branch_id);
		// The branch servers reject the string-to-datetime conversion even with
		// style 23. Build a date from the validated numeric parts instead.
		const [year, month, day] = date.split('-').map(Number);
		const saleDate = `DATEFROMPARTS(${year}, ${month}, ${day})`;
		do {
			// Sum only matching product lines. Whole-bill GrandTotal would include
			// other groups on mixed baskets. NetAmount already includes line VAT.
			const sql = monthly ? `SELECT * FROM (
				SELECT grouped.*, COUNT(*) OVER() AS total_rows,
					ROW_NUMBER() OVER(ORDER BY sale_day) AS row_number
				FROM (
					SELECT DAY(m.TransactionDate) AS sale_day,
						SUM(CASE WHEN m.VoucherType = 'SI' THEN ISNULL(d.NetAmount, 0) ELSE 0 END) AS sales_amount,
						SUM(CASE WHEN m.VoucherType = 'SR' THEN ABS(ISNULL(d.NetAmount, 0)) ELSE 0 END) AS return_amount,
						SUM(CASE WHEN m.VoucherType = 'SR' THEN -ABS(ISNULL(d.TotalVatAmount, 0)) ELSE ISNULL(d.TotalVatAmount, 0) END) AS output_vat
					FROM InvTransactionDetails d
					INNER JOIN InvTransactionMaster m ON m.InvTransactionMasterID = d.InvTransactionMasterID AND m.BranchID = d.BranchID
					INNER JOIN ProductBatches pb ON pb.ProductBatchID = d.ProductBatchID AND pb.BranchID = d.BranchID
					INNER JOIN Products p ON p.ProductID = pb.ProductID AND p.BranchID = pb.BranchID
					LEFT JOIN ProductGroups g ON g.ProductGroupID = p.ProductGroupID AND g.BranchID = p.BranchID
					WHERE m.BranchID = ${erpBranchId} AND m.IsActive = 1 AND m.VoucherType IN ('SI', 'SR')
						AND m.TransactionDate >= ${saleDate}
						AND m.TransactionDate < DATEADD(month, 1, DATEFROMPARTS(${year}, ${month}, 1))
						AND ${salesScope}
					GROUP BY DAY(m.TransactionDate)
				) grouped
			) paged WHERE row_number > ${offset} AND row_number <= ${offset + PAGE_SIZE} ORDER BY row_number` : `SELECT * FROM (
				SELECT grouped.*, COUNT(*) OVER() AS total_rows,
					ROW_NUMBER() OVER(ORDER BY product_id, unit_id) AS row_number
				FROM (
					SELECT p.ProductID AS product_id, d.UnitID AS unit_id,
						p.ProductName AS name_en, p.ItemNameinSecondLanguage AS name_ar, u.UnitName AS unit_name,
						SUM(CASE WHEN m.VoucherType = 'SR' THEN -ABS(ISNULL(d.Quantity, 0)) ELSE ISNULL(d.Quantity, 0) END) AS quantity,
						SUM(CASE WHEN m.VoucherType = 'SI' THEN ISNULL(d.NetAmount, 0) ELSE 0 END) AS sales_amount,
						SUM(CASE WHEN m.VoucherType = 'SR' THEN ABS(ISNULL(d.NetAmount, 0)) ELSE 0 END) AS return_amount,
						SUM(CASE WHEN m.VoucherType = 'SR' THEN -ABS(ISNULL(d.TotalVatAmount, 0)) ELSE ISNULL(d.TotalVatAmount, 0) END) AS output_vat
					FROM InvTransactionDetails d
					INNER JOIN InvTransactionMaster m ON m.InvTransactionMasterID = d.InvTransactionMasterID AND m.BranchID = d.BranchID
					INNER JOIN ProductBatches pb ON pb.ProductBatchID = d.ProductBatchID AND pb.BranchID = d.BranchID
					INNER JOIN Products p ON p.ProductID = pb.ProductID AND p.BranchID = pb.BranchID
					LEFT JOIN ProductGroups g ON g.ProductGroupID = p.ProductGroupID AND g.BranchID = p.BranchID
					LEFT JOIN UnitOfMeasures u ON u.UnitID = d.UnitID AND u.BranchID = d.BranchID
					WHERE m.BranchID = ${erpBranchId} AND m.IsActive = 1 AND m.VoucherType IN ('SI', 'SR')
						AND m.TransactionDate >= ${saleDate}
						AND m.TransactionDate < DATEADD(day, 1, ${saleDate})
						AND ${salesScope}
					GROUP BY p.ProductID, d.UnitID, p.ProductName, p.ItemNameinSecondLanguage, u.UnitName
				) grouped
			) paged WHERE row_number > ${offset} AND row_number <= ${offset + PAGE_SIZE} ORDER BY row_number`;
			const response = await fetch(`${config.tunnel_url.replace(/\/+$/, '')}/query`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json', 'x-api-secret': config.bridge_api_secret },
				body: JSON.stringify({ sql }), signal: controller.signal
			});
			const result = await response.json();
			if (!response.ok || result?.success !== true || !Array.isArray(result.recordset)) {
				throw new Error(String(result?.error || result?.message || 'ERP sales query failed'));
			}
			const rows = result.recordset;
			if (offset === 0 && rows.length === 0) break;
			const pageTotal = Number(rows[0]?.total_rows);
			if (!Number.isSafeInteger(pageTotal) || pageTotal < 0 || (offset > 0 && pageTotal !== total)) throw new Error('Incomplete sales response');
			total = pageTotal;
			if (rows.length !== Math.min(PAGE_SIZE, total - offset)) throw new Error('Incomplete sales page');
			for (const row of rows) {
				const salesAmount = Number(row.sales_amount);
				const returnAmount = Number(row.return_amount);
				const outputVat = Number(row.output_vat);
				if (![salesAmount, returnAmount, outputVat].every(Number.isFinite)) throw new Error('Invalid sales amounts');
				if (monthly) {
					const saleDay = Number(row.sale_day);
					if (!Number.isInteger(saleDay) || saleDay < 1 || saleDay > 31) throw new Error('Invalid sales day');
					dailySales.push({ branchId: branch.id, date: `${date.slice(0, 7)}-${String(saleDay).padStart(2, '0')}`, salesAmount, returnAmount, outputVat });
					continue;
				}
				const quantity = Number(row.quantity);
				if (!Number.isFinite(quantity)) throw new Error('Invalid sales quantity');
				sales.push({
					branchId: branch.id, productId: String(row.product_id), unitId: String(row.unit_id ?? ''),
					nameEn: String(row.name_en ?? '').trim(), nameAr: String(row.name_ar ?? '').trim(),
					unitName: String(row.unit_name ?? '').trim(), quantity, salesAmount, returnAmount, outputVat
				});
			}
			offset += rows.length;
		} while (offset < total);
		branch.status = 'loaded';
		return { branch, sales, dailySales };
	} catch (error) {
		const reason = (error instanceof Error ? error.message : 'Unknown ERP error')
			.replaceAll(config.bridge_api_secret, '[redacted]')
			.replaceAll(config.tunnel_url, '[redacted]').slice(0, 500);
		console.error(`[${profile.id} sales] Branch read failed`, { branchId: branch.id, date, reason });
		branch.status = controller.signal.aborted ? 'timeout' : 'failed';
		return { branch, sales: [], dailySales: [] };
	} finally {
		clearTimeout(timeout);
	}
}

export function createCounterSalesHandler(profile: BusinessCounterProfile): RequestHandler {
	return async ({ request, url }) => {
	try {
		const db = createAuthenticatedSupabase(request);
		const { data: auth, error: authError } = await db.auth.getUser();
		if (authError || !auth.user) throw new AuthenticationRequiredError('Authenticated session is required');
		const month = url.searchParams.get('month');
		if (month !== null && (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month) || url.searchParams.has('date'))) {
			return json({ success: false, error: 'Invalid month' }, { status: 400, headers });
		}
		let date = month !== null ? `${month}-01` : url.searchParams.get('date') || '';
		const parsedDate = new Date(`${date}T00:00:00Z`);
		if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(parsedDate.getTime()) ||
			parsedDate.toISOString().slice(0, 10) !== date || Number(date.slice(0, 4)) < 1753 || Number(date.slice(0, 4)) > 9998) {
			return json({ success: false, error: 'Invalid date' }, { status: 400, headers });
		}
		if ((month !== null && month < profile.reportStartDate.slice(0, 7)) || (month === null && date < profile.reportStartDate)) {
			return json({ success: false, error: `${profile.id} reports are only available from ${profile.reportStartDate}` }, { status: 400, headers });
		}
		// November 2026 begins on the arrangement start, while the upper bound
		// remains December 1 rather than one month after November 12.
		if (date < profile.reportStartDate) date = profile.reportStartDate;
		const { data: configs, error } = await db.from('erp_connections')
			.select('branch_id, branch_name, erp_branch_id, tunnel_url, bridge_api_secret, branches(name_en, name_ar)')
			.eq('is_active', true).order('branch_id');
		if (error) throw error;
		const results = await Promise.all((configs || []).map(config => loadBranch(profile, config, date, month !== null)));
		if (month !== null) {
			return json({ success: true, month, branches: results.map(result => result.branch), dailySales: results.flatMap(result => result.dailySales) }, { headers });
		}
		return json({ success: true, date, branches: results.map(result => result.branch), sales: results.flatMap(result => result.sales) }, { headers });
	} catch (error) {
		const unauthorized = error instanceof AuthenticationRequiredError;
		return json({ success: false, error: unauthorized ? 'Authenticated session is required' : `Unable to load ${profile.id} sales` }, {
			status: unauthorized ? 401 : 500, headers
		});
	}
};
}
