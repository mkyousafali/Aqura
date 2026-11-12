import { json, type RequestHandler } from '@sveltejs/kit';
import { AuthenticationRequiredError, createAuthenticatedSupabase } from '$lib/server/authenticatedSupabase';
import { COFFEE_COUNTER, COFFEE_PURCHASE_BRANCH_ID } from '$lib/types/businessCounter';
import type { BakeryExpense, BakeryExpenseBranch } from '$lib/types/bakery';

const headers = { 'Cache-Control': 'no-store' };
const PAGE_SIZE = 500;

async function loadBranch(config: any, date: string, monthly: boolean) {
	const details = Array.isArray(config.branches) ? config.branches[0] : config.branches;
	const branch: BakeryExpenseBranch = {
		id: String(config.branch_id),
		nameEn: details?.name_en || config.branch_name || String(config.branch_id),
		nameAr: details?.name_ar || config.branch_name || String(config.branch_id),
		status: 'unavailable'
	};
	const empty = () => ({ branch, expenses: [] as BakeryExpense[] });
	// Purchases are sourced only from Arda. Other sales branches have no
	// expenses in this report's scope; do not contact their ERP tunnels.
	if (branch.id !== COFFEE_PURCHASE_BRANCH_ID) {
		branch.status = 'loaded';
		return empty();
	}
	const erpBranchId = Number(config.erp_branch_id);
	if (!config.tunnel_url || !config.bridge_api_secret || !Number.isSafeInteger(erpBranchId) || erpBranchId <= 0) return empty();
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), 30000);
	try {
		const [year, month, day] = date.split('-').map(Number);
		const start = `DATEFROMPARTS(${year}, ${month}, ${day})`;
		const end = monthly ? `DATEADD(month, 1, DATEFROMPARTS(${year}, ${month}, 1))` : `DATEADD(day, 1, ${start})`;
		const group = COFFEE_COUNTER.productGroup.replace(/'/g, "''");
		const expenses: BakeryExpense[] = [];
		let offset = 0;
		let total = 0;
		do {
			// Match individual coffee lines on mixed invoices. Never use whole-bill
			// totals or recalculate input VAT from a percentage.
			const sql = `SELECT * FROM (
				SELECT d.InvTransactionDetailID AS entry_id, DAY(m.TransactionDate) AS expense_day,
					m.VoucherType AS voucher_type, m.VoucherForm AS voucher_form,
					m.VoucherPrefix AS voucher_prefix, m.VoucherNumber AS voucher_number,
					formName.VoucherTypeName AS form_name,
					COALESCE(NULLIF(LTRIM(RTRIM(m.PartyName)), N''),
						NULLIF(LTRIM(RTRIM(vendor.LedgerName)), N''), N'') AS vendor_name,
					COALESCE(NULLIF(LTRIM(RTRIM(d.ProductDescription)), N''), p.ProductName, N'') AS product_description,
					ISNULL(m.Remarks, N'') AS remarks,
					d.NetAmount AS amount_including_vat, d.TotalVatAmount AS recorded_input_vat,
					COUNT(*) OVER() AS total_rows,
					ROW_NUMBER() OVER(ORDER BY m.TransactionDate, d.InvTransactionDetailID) AS row_number
				FROM InvTransactionDetails d
				INNER JOIN InvTransactionMaster m ON m.InvTransactionMasterID = d.InvTransactionMasterID AND m.BranchID = d.BranchID
				LEFT JOIN AccLedgers vendor ON vendor.LedgerID = m.LedgerID AND vendor.BranchID = m.BranchID
				INNER JOIN ProductBatches pb ON pb.ProductBatchID = d.ProductBatchID AND pb.BranchID = d.BranchID
				INNER JOIN Products p ON p.ProductID = pb.ProductID AND p.BranchID = pb.BranchID
				INNER JOIN ProductGroups g ON g.ProductGroupID = p.ProductGroupID AND g.BranchID = p.BranchID
				OUTER APPLY (
					SELECT TOP 1 v.VoucherTypeName FROM VoucherTypeName v
					WHERE v.VoucherType = m.VoucherType AND v.BranchID IN (0, ${erpBranchId})
					ORDER BY CASE WHEN v.BranchID = ${erpBranchId} THEN 0 ELSE 1 END
				) formName
				WHERE m.BranchID = ${erpBranchId} AND m.IsActive = 1 AND m.VoucherType IN ('PI', 'PR')
					AND m.TransactionDate >= ${start} AND m.TransactionDate < ${end}
					AND LTRIM(RTRIM(g.GroupName)) = N'${group}'
			) paged WHERE row_number > ${offset} AND row_number <= ${offset + PAGE_SIZE} ORDER BY row_number`;
			const response = await fetch(`${config.tunnel_url.replace(/\/+$/, '')}/query`, {
				method: 'POST', headers: { 'Content-Type': 'application/json', 'x-api-secret': config.bridge_api_secret },
				body: JSON.stringify({ sql }), signal: controller.signal
			});
			const result = await response.json();
			if (!response.ok || result?.success !== true || !Array.isArray(result.recordset)) throw new Error('ERP purchases query failed');
			const rows = result.recordset;
			if (offset === 0 && rows.length === 0) break;
			const pageTotal = Number(rows[0]?.total_rows);
			if (!Number.isSafeInteger(pageTotal) || pageTotal < 0 || (offset > 0 && pageTotal !== total)) throw new Error('Incomplete purchases response');
			total = pageTotal;
			if (rows.length !== Math.min(PAGE_SIZE, total - offset)) throw new Error('Incomplete purchases page');
			for (const row of rows) {
				const gross = row.amount_including_vat == null ? NaN : Math.abs(Number(row.amount_including_vat));
				const tax = row.recorded_input_vat == null ? null : Math.abs(Number(row.recorded_input_vat));
				if (!Number.isFinite(gross) || (tax !== null && !Number.isFinite(tax))) throw new Error('Invalid purchase amounts');
				const expenseDay = Number(row.expense_day);
				if (!Number.isInteger(expenseDay) || expenseDay < 1 || expenseDay > 31) throw new Error('Invalid purchase date');
				const returned = row.voucher_type === 'PR';
				// NetAmount is inclusive of recorded line VAT. Expose the expense
				// before VAT so the shared profit report adds that VAT exactly once.
				const net = gross - (tax ?? 0);
				const number = [row.voucher_prefix, row.voucher_number].filter(value => value != null && value !== '').join('');
				const formType = String(row.voucher_type ?? '').trim();
				const formName = String(row.form_name ?? '').trim() || (returned ? 'Purchase Return (PR)' : 'Purchase Invoice (PI)');
				expenses.push({
					branchId: branch.id, id: String(row.entry_id),
					date: `${date.slice(0, 7)}-${String(expenseDay).padStart(2, '0')}`,
					voucher: [formType, number].filter(Boolean).join(' · '), formType,
					formName: `${formName}${String(row.voucher_form ?? '').trim() === 'VAT' ? ' (VAT)' : ''}`,
					vendorName: String(row.vendor_name ?? '').trim(),
					narration: [row.product_description, row.remarks].map(value => String(value ?? '').trim()).filter(Boolean).join(' · '),
					debit: returned ? 0 : net, credit: returned ? net : 0,
					inputVat: tax === null ? null : returned ? -tax : tax
				});
			}
			offset += rows.length;
		} while (offset < total);
		branch.status = 'loaded';
		return { branch, expenses };
	} catch {
		branch.status = controller.signal.aborted ? 'timeout' : 'failed';
		return empty();
	} finally {
		clearTimeout(timeout);
	}
}

export const GET: RequestHandler = async ({ request, url }) => {
	try {
		const db = createAuthenticatedSupabase(request);
		const { data: auth, error: authError } = await db.auth.getUser();
		if (authError || !auth.user) throw new AuthenticationRequiredError('Authenticated session is required');
		const month = url.searchParams.get('month');
		if (month !== null && (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month) || url.searchParams.has('date'))) {
			return json({ success: false, error: 'Invalid month' }, { status: 400, headers });
		}
		const date = month !== null ? `${month}-01` : url.searchParams.get('date') || '';
		const parsedDate = new Date(`${date}T00:00:00Z`);
		if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(parsedDate.getTime()) ||
			parsedDate.toISOString().slice(0, 10) !== date || Number(date.slice(0, 4)) < 1753 || Number(date.slice(0, 4)) > 9998) {
			return json({ success: false, error: 'Invalid date' }, { status: 400, headers });
		}
		const { data: configs, error } = await db.from('erp_connections')
			.select('branch_id, branch_name, erp_branch_id, tunnel_url, bridge_api_secret, branches(name_en, name_ar)')
			.eq('is_active', true).order('branch_id');
		if (error) throw error;
		if (!(configs || []).some(config => String(config.branch_id) === COFFEE_PURCHASE_BRANCH_ID)) {
			throw new Error('Arda purchase connection is unavailable');
		}
		const results = await Promise.all((configs || []).map(config => loadBranch(config, date, month !== null)));
		return json({ success: true, date, month, branches: results.map(result => result.branch),
			expenses: results.flatMap(result => result.expenses) }, { headers });
	} catch (error) {
		const unauthorized = error instanceof AuthenticationRequiredError;
		return json({ success: false, error: unauthorized ? 'Authenticated session is required' : 'Unable to load coffee purchases' }, {
			status: unauthorized ? 401 : 500, headers
		});
	}
};
