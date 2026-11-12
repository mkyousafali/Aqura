import { BAKERY_EXPENSE_LEDGER_NAME, BAKERY_EXPENSE_LEDGER_REFERENCE, BAKERY_REPORT_START_DATE, type BakeryExpenseBranch } from '$lib/types/bakery';
import type { CoffeeAllTimeInputVat } from '$lib/types/coffeeAllTime';

export async function readBakeryAllTimeExpenses(config: any, asOfDate: string) {
	const details = Array.isArray(config.branches) ? config.branches[0] : config.branches;
	const branch: BakeryExpenseBranch = {
		id: String(config.branch_id), nameEn: details?.name_en || config.branch_name || String(config.branch_id),
		nameAr: details?.name_ar || config.branch_name || String(config.branch_id), status: 'unavailable'
	};
	const empty = () => ({ branch, inputVat: [] as CoffeeAllTimeInputVat[] });
	const erp = Number(config.erp_branch_id);
	if (!config.tunnel_url || !config.bridge_api_secret || !Number.isSafeInteger(erp) || erp <= 0) return empty();
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), 30000);
	try {
		async function query(sql: string) {
			const response = await fetch(`${config.tunnel_url.replace(/\/+$/, '')}/query`, {
				method: 'POST', headers: { 'Content-Type': 'application/json', 'x-api-secret': config.bridge_api_secret },
				body: JSON.stringify({ sql }), signal: controller.signal
			});
			const result = await response.json();
			if (!response.ok || result?.success !== true || !Array.isArray(result.recordset)) throw new Error('ERP bakery expense query failed');
			return result.recordset;
		}
		const name = BAKERY_EXPENSE_LEDGER_NAME.replace(/'/g, "''");
		const candidates = await query(`SELECT l.LedgerID, l.LedgerCode, l.LedgerName FROM AccLedgers l
			WHERE l.BranchID = ${erp} AND l.IsActive = 1
				AND (UPPER(l.LedgerName) LIKE N'%${name}%' OR l.LedgerName LIKE N'%مصاريف%مخبز%')`);
		const named = candidates.filter((ledger: any) => {
			const label = String(ledger.LedgerName || '').replace(/\s+/g, ' ').toUpperCase();
			return label.includes(BAKERY_EXPENSE_LEDGER_NAME) || /مصاريف.*مخبز/.test(label);
		});
		const referenced = named.filter((ledger: any) => String(ledger.LedgerID) === BAKERY_EXPENSE_LEDGER_REFERENCE || String(ledger.LedgerCode ?? '').trim() === BAKERY_EXPENSE_LEDGER_REFERENCE);
		const matches = referenced.length === 1 ? referenced : named;
		if (matches.length !== 1) { branch.status = matches.length === 0 ? 'ledgerMissing' : 'ledgerAmbiguous'; return empty(); }
		const ledger = Number(matches[0].LedgerID);
		if (!Number.isSafeInteger(ledger) || ledger <= 0) throw new Error('Invalid bakery expense ledger');
		const [sy, sm, sd] = BAKERY_REPORT_START_DATE.split('-').map(Number);
		const [ey, em, ed] = asOfDate.split('-').map(Number);
		const start = `DATEFROMPARTS(${sy}, ${sm}, ${sd})`;
		const end = `DATEADD(day, 1, DATEFROMPARTS(${ey}, ${em}, ${ed}))`;
		const inputVat: CoffeeAllTimeInputVat[] = [];
		let offset = 0, total = 0;
		do {
			const rows = await query(`SELECT * FROM (
				SELECT grouped.*, COUNT(*) OVER() AS total_rows,
					ROW_NUMBER() OVER(ORDER BY report_year, report_month, report_day) AS row_number
				FROM (
					SELECT YEAR(m.TransactionDate) AS report_year, MONTH(m.TransactionDate) AS report_month,
						DAY(m.TransactionDate) AS report_day,
						SUM(ISNULL(ad.Debit, 0) - ISNULL(ad.Credit, 0)) AS expense_amount,
						SUM(ISNULL(expenseTax.input_vat, 0)) AS input_vat
					FROM AccTransactionDetails ad
					INNER JOIN AccTransactionMaster m ON m.AccTransactionMasterID = ad.AccTransactionMasterID AND m.BranchID = ad.BranchID
					OUTER APPLY (
						SELECT SUM(t.TaxAmount) AS input_vat FROM TaxOnExpenses t
						WHERE t.BranchID = ad.BranchID AND t.AccTransactionMasterID = ad.AccTransactionMasterID
							AND t.AccTransactionDetailID = ad.AccTransactionDetailID
					) expenseTax
					WHERE ad.BranchID = ${erp} AND ad.LedgerID = ${ledger} AND m.IsActive = 1
						AND m.TransactionDate >= ${start} AND m.TransactionDate < ${end}
					GROUP BY YEAR(m.TransactionDate), MONTH(m.TransactionDate), DAY(m.TransactionDate)
				) grouped
			) paged WHERE row_number > ${offset} AND row_number <= ${offset + 500} ORDER BY row_number`);
			if (offset === 0 && rows.length === 0) break;
			const pageTotal = Number(rows[0]?.total_rows);
			if (!Number.isSafeInteger(pageTotal) || pageTotal < 0 || (offset > 0 && pageTotal !== total)) throw new Error('Incomplete bakery expense response');
			total = pageTotal;
			if (rows.length !== Math.min(500, total - offset)) throw new Error('Incomplete bakery expense page');
			for (const row of rows) {
				const expensesExcludingVat = row.expense_amount == null ? NaN : Number(row.expense_amount);
				const tax = row.input_vat == null ? NaN : Number(row.input_vat);
				const y = Number(row.report_year), m = Number(row.report_month), d = Number(row.report_day);
				if (![expensesExcludingVat, tax].every(Number.isFinite) || ![y, m, d].every(Number.isInteger) || y < 1753 || y > 9998 || m < 1 || m > 12 || d < 1 || d > 31) throw new Error('Invalid bakery expense amounts or date');
				inputVat.push({ branchId: branch.id, date: `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`, inputVat: tax, expensesExcludingVat });
			}
			offset += rows.length;
		} while (offset < total);
		branch.status = 'loaded';
		return { branch, inputVat };
	} catch {
		branch.status = controller.signal.aborted ? 'timeout' : 'failed';
		return empty();
	} finally {
		clearTimeout(timeout);
	}
}
