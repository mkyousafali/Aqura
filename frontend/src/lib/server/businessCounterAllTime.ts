import { COFFEE_COUNTER, type BusinessCounterProfile } from '$lib/types/businessCounter';
import type { BakeryBranch } from '$lib/types/bakery';
import type { CoffeeAllTimeSale, CoffeeAllTimeInputVat } from '$lib/types/coffeeAllTime';
import { counterSalesScope } from './businessCounterScope';

const PAGE_SIZE = 500;

function branchInfo(config: any): BakeryBranch {
	const details = Array.isArray(config.branches) ? config.branches[0] : config.branches;
	return {
		id: String(config.branch_id), nameEn: details?.name_en || config.branch_name || String(config.branch_id),
		nameAr: details?.name_ar || config.branch_name || String(config.branch_id), status: 'unavailable'
	};
}

export async function readCounterDaily(config: any, asOfDate: string, source: 'sales' | 'inputVat', profile: BusinessCounterProfile = COFFEE_COUNTER) {
	const branch = branchInfo(config);
	const empty = () => ({ branch, sales: [] as CoffeeAllTimeSale[], inputVat: [] as CoffeeAllTimeInputVat[] });
	const erpBranchId = Number(config.erp_branch_id);
	if (!config.tunnel_url || !config.bridge_api_secret || !Number.isSafeInteger(erpBranchId) || erpBranchId <= 0) return empty();
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), 30000);
	try {
		const [year, month, day] = asOfDate.split('-').map(Number);
		const [startYear, startMonth, startDay] = profile.reportStartDate.split('-').map(Number);
		const start = `DATEFROMPARTS(${startYear}, ${startMonth}, ${startDay})`;
		const end = `DATEADD(day, 1, DATEFROMPARTS(${year}, ${month}, ${day}))`;
		const group = profile.productGroup.replace(/'/g, "''");
		const scope = source === 'sales' ? counterSalesScope(profile, config.branch_id) : `LTRIM(RTRIM(g.GroupName)) = N'${group}'`;
		const vouchers = source === 'sales' ? "'SI', 'SR'" : "'PI', 'PR'";
		const amounts = source === 'sales' ? `
			SUM(CASE WHEN m.VoucherType = 'SR' THEN -ABS(ISNULL(d.NetAmount, 0)) ELSE ISNULL(d.NetAmount, 0) END) AS sales_including_vat,
			SUM(CASE WHEN m.VoucherType = 'SR' THEN -ABS(ISNULL(d.TotalVatAmount, 0)) ELSE ISNULL(d.TotalVatAmount, 0) END) AS output_vat` : `
			SUM(CASE WHEN m.VoucherType = 'PR' THEN -ABS(ISNULL(d.TotalVatAmount, 0)) ELSE ABS(ISNULL(d.TotalVatAmount, 0)) END) AS input_vat,
			SUM((CASE WHEN m.VoucherType = 'PR' THEN -1 ELSE 1 END) *
				(ABS(ISNULL(d.NetAmount, 0)) - ABS(ISNULL(d.TotalVatAmount, 0)))) AS expenses_excluding_vat,
			SUM(CASE WHEN d.TotalVatAmount IS NULL OR d.NetAmount IS NULL THEN 1 ELSE 0 END) AS missing_purchase_amounts`;
		const sales: CoffeeAllTimeSale[] = [];
		const inputVat: CoffeeAllTimeInputVat[] = [];
		let offset = 0;
		let total = 0;
		do {
			// Aggregate product lines over the complete history in SQL, then page
			// actual calendar dates. No month-by-month fan-out or whole-bill totals.
			const sql = `SELECT * FROM (
				SELECT grouped.*, COUNT(*) OVER() AS total_rows,
					ROW_NUMBER() OVER(ORDER BY report_year, report_month, report_day) AS row_number
				FROM (
					SELECT YEAR(m.TransactionDate) AS report_year, MONTH(m.TransactionDate) AS report_month,
						DAY(m.TransactionDate) AS report_day, ${amounts}
					FROM InvTransactionDetails d
					INNER JOIN InvTransactionMaster m ON m.InvTransactionMasterID = d.InvTransactionMasterID AND m.BranchID = d.BranchID
					INNER JOIN ProductBatches pb ON pb.ProductBatchID = d.ProductBatchID AND pb.BranchID = d.BranchID
					INNER JOIN Products p ON p.ProductID = pb.ProductID AND p.BranchID = pb.BranchID
					LEFT JOIN ProductGroups g ON g.ProductGroupID = p.ProductGroupID AND g.BranchID = p.BranchID
					WHERE m.BranchID = ${erpBranchId} AND m.IsActive = 1 AND m.VoucherType IN (${vouchers})
						AND m.TransactionDate >= ${start} AND m.TransactionDate < ${end}
						AND ${scope}
					GROUP BY YEAR(m.TransactionDate), MONTH(m.TransactionDate), DAY(m.TransactionDate)
				) grouped
			) paged WHERE row_number > ${offset} AND row_number <= ${offset + PAGE_SIZE} ORDER BY row_number`;
			const response = await fetch(`${config.tunnel_url.replace(/\/+$/, '')}/query`, {
				method: 'POST', headers: { 'Content-Type': 'application/json', 'x-api-secret': config.bridge_api_secret },
				body: JSON.stringify({ sql }), signal: controller.signal
			});
			const result = await response.json();
			if (!response.ok || result?.success !== true || !Array.isArray(result.recordset)) throw new Error('ERP all-time query failed');
			const rows = result.recordset;
			if (offset === 0 && rows.length === 0) break;
			const pageTotal = Number(rows[0]?.total_rows);
			if (!Number.isSafeInteger(pageTotal) || pageTotal < 0 || (offset > 0 && pageTotal !== total)) throw new Error('Incomplete all-time response');
			total = pageTotal;
			if (rows.length !== Math.min(PAGE_SIZE, total - offset)) throw new Error('Incomplete all-time page');
			for (const row of rows) {
				const y = Number(row.report_year), m = Number(row.report_month), d = Number(row.report_day);
				if (![y, m, d].every(Number.isInteger) || y < 1753 || y > 9998 || m < 1 || m > 12 || d < 1 || d > 31) throw new Error('Invalid report date');
				const date = `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
				if (source === 'sales') {
					const salesIncludingVat = row.sales_including_vat == null ? NaN : Number(row.sales_including_vat);
					const outputVat = row.output_vat == null ? NaN : Number(row.output_vat);
					if (![salesIncludingVat, outputVat].every(Number.isFinite)) throw new Error('Invalid sales amounts');
					sales.push({ branchId: branch.id, date, salesIncludingVat, outputVat });
				} else {
					const tax = row.input_vat == null ? NaN : Number(row.input_vat);
					const expensesExcludingVat = row.expenses_excluding_vat == null ? NaN : Number(row.expenses_excluding_vat);
					if (![tax, expensesExcludingVat].every(Number.isFinite) || Number(row.missing_purchase_amounts) !== 0) throw new Error('Recorded purchase expenses or VAT are incomplete');
					inputVat.push({ branchId: branch.id, date, inputVat: tax, expensesExcludingVat });
				}
			}
			offset += rows.length;
		} while (offset < total);
		branch.status = 'loaded';
		return { branch, sales, inputVat };
	} catch {
		branch.status = controller.signal.aborted ? 'timeout' : 'failed';
		return empty();
	} finally {
		clearTimeout(timeout);
	}
}

