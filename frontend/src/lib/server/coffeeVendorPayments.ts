import { COFFEE_COUNTER, COFFEE_PURCHASE_BRANCH_ID } from '$lib/types/businessCounter';
import type { CoffeeVendorPayments } from '$lib/types/coffeeAllTime';

export async function readCoffeeVendorPayments(config: any, asOfDate: string): Promise<CoffeeVendorPayments> {
	const details = Array.isArray(config?.branches) ? config.branches[0] : config?.branches;
	const report: CoffeeVendorPayments = {
		asOfDate,
		firstPaymentDate: null,
		branch: { id: COFFEE_PURCHASE_BRANCH_ID, nameEn: details?.name_en || config?.branch_name || 'Arda',
			nameAr: details?.name_ar || config?.branch_name || 'العارضة', status: 'unavailable' },
		cashAndBankAmount: null, journalAmount: null, total: null
	};
	const erp = Number(config?.erp_branch_id);
	if (String(config?.branch_id) !== COFFEE_PURCHASE_BRANCH_ID || !config?.tunnel_url || !config?.bridge_api_secret || !Number.isSafeInteger(erp) || erp <= 0) return report;
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), 30000);
	try {
		const [year, month, day] = asOfDate.split('-').map(Number);
		const end = `DATEADD(day, 1, DATEFROMPARTS(${year}, ${month}, ${day}))`;
		const group = COFFEE_COUNTER.productGroup.replace(/'/g, "''");
		let offset = 0, totalRows = 0, cashAndBank = 0, journals = 0;
		do {
			// Sum only the supplier's own accounting line, not the voucher total or
			// its balancing bank/cash line. EXISTS prevents mixed invoices from
			// duplicating payments. Purchase returns are not payments.
			const sql = `SELECT * FROM (
				SELECT ad.AccTransactionDetailID AS entry_id, m.AccTransactionMasterID AS master_id,
					ad.LedgerID AS ledger_id, m.VoucherType AS voucher_type,
					YEAR(m.TransactionDate) AS report_year, MONTH(m.TransactionDate) AS report_month, DAY(m.TransactionDate) AS report_day,
					ISNULL(ad.Debit, 0) AS debit, ISNULL(ad.Credit, 0) AS credit,
					COUNT(*) OVER() AS total_rows,
					ROW_NUMBER() OVER(ORDER BY m.TransactionDate, m.AccTransactionMasterID, ad.AccTransactionDetailID) AS row_number
				FROM AccTransactionDetails ad
				INNER JOIN AccTransactionMaster m ON m.AccTransactionMasterID = ad.AccTransactionMasterID AND m.BranchID = ad.BranchID
				WHERE ad.BranchID = ${erp} AND m.IsActive = 1 AND m.TransactionDate < ${end}
					AND m.VoucherType IN ('CP', 'BP', 'JV', 'MJV')
					AND (ISNULL(ad.Debit, 0) <> 0 OR ISNULL(ad.Credit, 0) <> 0)
					AND EXISTS (
						SELECT 1 FROM InvTransactionMaster purchase
						INNER JOIN InvTransactionDetails d ON d.InvTransactionMasterID = purchase.InvTransactionMasterID AND d.BranchID = purchase.BranchID
						INNER JOIN ProductBatches pb ON pb.ProductBatchID = d.ProductBatchID AND pb.BranchID = d.BranchID
						INNER JOIN Products p ON p.ProductID = pb.ProductID AND p.BranchID = pb.BranchID
						INNER JOIN ProductGroups g ON g.ProductGroupID = p.ProductGroupID AND g.BranchID = p.BranchID
						WHERE purchase.BranchID = ad.BranchID AND purchase.LedgerID = ad.LedgerID AND purchase.IsActive = 1
							AND purchase.VoucherType IN ('PI', 'PR') AND purchase.TransactionDate < ${end}
							AND LTRIM(RTRIM(g.GroupName)) = N'${group}'
					)
			) paged WHERE row_number > ${offset} AND row_number <= ${offset + 500} ORDER BY row_number`;
			const response = await fetch(`${config.tunnel_url.replace(/\/+$/, '')}/query`, {
				method: 'POST', headers: { 'Content-Type': 'application/json', 'x-api-secret': config.bridge_api_secret },
				body: JSON.stringify({ sql }), signal: controller.signal
			});
			const result = await response.json();
			if (!response.ok || result?.success !== true || !Array.isArray(result.recordset)) throw new Error('ERP vendor payments query failed');
			const rows = result.recordset;
			if (offset === 0 && rows.length === 0) break;
			const pageTotal = Number(rows[0]?.total_rows);
			if (!Number.isSafeInteger(pageTotal) || pageTotal < 0 || (offset > 0 && pageTotal !== totalRows)) throw new Error('Incomplete payments response');
			totalRows = pageTotal;
			if (rows.length !== Math.min(500, totalRows - offset)) throw new Error('Incomplete payments page');
			for (const row of rows) {
				const debit = Number(row.debit), credit = Number(row.credit);
				if (![debit, credit].every(Number.isFinite)) throw new Error('Invalid payment amount');
				const entryDate = `${String(row.report_year).padStart(4, '0')}-${String(row.report_month).padStart(2, '0')}-${String(row.report_day).padStart(2, '0')}`;
				if (!/^\d{4}-\d{2}-\d{2}$/.test(entryDate)) throw new Error('Invalid payment date');
				if (!report.firstPaymentDate || entryDate < report.firstPaymentDate) report.firstPaymentDate = entryDate;
				if (row.voucher_type === 'CP' || row.voucher_type === 'BP') { cashAndBank += debit - credit; continue; }
				// The user confirmed all related suppliers' journal payments,
				// including JV/MJV entries across the complete reporting history.
				journals += debit - credit;
			}
			offset += rows.length;
		} while (offset < totalRows);
		const round = (value: number) => Math.sign(value) * Math.round((Math.abs(value) + Number.EPSILON) * 100) / 100;
		report.cashAndBankAmount = round(cashAndBank);
		report.journalAmount = round(journals);
		report.total = round(report.cashAndBankAmount + report.journalAmount);
		report.branch.status = 'loaded';
	} catch {
		report.branch.status = controller.signal.aborted ? 'timeout' : 'failed';
	} finally {
		clearTimeout(timeout);
	}
	return report;
}
