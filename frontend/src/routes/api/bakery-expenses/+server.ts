import { json, type RequestHandler } from '@sveltejs/kit';
import { AuthenticationRequiredError, createAuthenticatedSupabase } from '$lib/server/authenticatedSupabase';
import {
	BAKERY_EXPENSE_LEDGER_NAME, BAKERY_EXPENSE_LEDGER_REFERENCE,
	BAKERY_REPORT_START_DATE, BAKERY_REPORT_START_MONTH,
	type BakeryExpenseBranch, type BakeryExpense
} from '$lib/types/bakery';

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
	const erpBranchId = Number(config.erp_branch_id);
	if (!config.tunnel_url || !config.bridge_api_secret || !Number.isSafeInteger(erpBranchId) || erpBranchId <= 0) return empty();
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), 30000);
	try {
		async function query(sql: string): Promise<Record<string, any>[]> {
			const response = await fetch(`${config.tunnel_url.replace(/\/+$/, '')}/query`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json', 'x-api-secret': config.bridge_api_secret },
				body: JSON.stringify({ sql }), signal: controller.signal
			});
			const result = await response.json();
			if (!response.ok || result?.success !== true || !Array.isArray(result.recordset)) {
				throw new Error(String(result?.error || result?.message || 'ERP expense query failed'));
			}
			return result.recordset;
		}

		// Resolve by name within each ERP branch. The reference can be a code or
		// an ID, and is only used to disambiguate matching bakery expense ledgers.
		const ledgerName = BAKERY_EXPENSE_LEDGER_NAME.replace(/'/g, "''");
		const candidates = await query(`SELECT l.LedgerID, l.LedgerCode, l.LedgerName
			FROM AccLedgers l WHERE l.BranchID = ${erpBranchId} AND l.IsActive = 1
			AND (UPPER(l.LedgerName) LIKE N'%${ledgerName}%' OR l.LedgerName LIKE N'%مصاريف%مخبز%')`);
		const named = candidates.filter(ledger => {
			const name = String(ledger.LedgerName || '').replace(/\s+/g, ' ').toUpperCase();
			return name.includes(BAKERY_EXPENSE_LEDGER_NAME) || /مصاريف.*مخبز/.test(name);
		});
		const referenced = named.filter(ledger => String(ledger.LedgerID) === BAKERY_EXPENSE_LEDGER_REFERENCE || String(ledger.LedgerCode ?? '').trim() === BAKERY_EXPENSE_LEDGER_REFERENCE);
		const matches = referenced.length === 1 ? referenced : named;
		if (matches.length !== 1) {
			branch.status = matches.length === 0 ? 'ledgerMissing' : 'ledgerAmbiguous';
			return empty();
		}
		const ledgerId = Number(matches[0].LedgerID);
		if (!Number.isSafeInteger(ledgerId) || ledgerId <= 0) throw new Error('Invalid expense ledger ID');
		const [year, month, day] = date.split('-').map(Number);
		const start = `DATEFROMPARTS(${year}, ${month}, ${day})`;
		const end = monthly ? `DATEADD(month, 1, DATEFROMPARTS(${year}, ${month}, 1))` : `DATEADD(day, 1, ${start})`;
		const formLookup = `OUTER APPLY (
			SELECT TOP 1 v.VoucherTypeName FROM VoucherTypeName v
			WHERE v.VoucherType = COALESCE(NULLIF(LTRIM(RTRIM(m.FormType)), ''), m.VoucherType)
				AND v.BranchID IN (0, ${erpBranchId})
			ORDER BY CASE WHEN v.BranchID = ${erpBranchId} THEN 0 ELSE 1 END
		) formName`;
		const range = `FROM AccTransactionDetails ad
			INNER JOIN AccTransactionMaster m ON m.AccTransactionMasterID = ad.AccTransactionMasterID AND m.BranchID = ad.BranchID
			${formLookup}
			OUTER APPLY (
				SELECT SUM(t.TaxAmount) AS input_vat
				FROM TaxOnExpenses t
				WHERE t.BranchID = ad.BranchID
					AND t.AccTransactionMasterID = ad.AccTransactionMasterID
					AND t.AccTransactionDetailID = ad.AccTransactionDetailID
			) expenseTax
			WHERE ad.BranchID = ${erpBranchId} AND ad.LedgerID = ${ledgerId} AND m.IsActive = 1
			AND m.TransactionDate >= ${start} AND m.TransactionDate < ${end}`;
		const expenses: BakeryExpense[] = [];
		let offset = 0;
		let total = 0;
		do {
			const sql = `SELECT * FROM (
				SELECT ad.AccTransactionDetailID AS entry_id, m.VoucherType AS voucher_type,
					DAY(m.TransactionDate) AS expense_day,
					m.VoucherPrefix AS voucher_prefix, m.VoucherNumber AS voucher_number,
					COALESCE(NULLIF(LTRIM(RTRIM(m.FormType)), ''), m.VoucherType) AS form_type,
					formName.VoucherTypeName AS form_name,
					COALESCE(NULLIF(LTRIM(RTRIM(ad.Narration)), N''),
						NULLIF(LTRIM(RTRIM(m.CommonNarration)), N''), NULLIF(LTRIM(RTRIM(m.Remarks)), N''), N'') AS narration,
					ISNULL(ad.Debit, 0) AS debit, ISNULL(ad.Credit, 0) AS credit,
					expenseTax.input_vat,
					COUNT(*) OVER() AS total_rows,
					ROW_NUMBER() OVER(ORDER BY m.TransactionDate, ad.AccTransactionDetailID) AS row_number
				${range}
			) paged WHERE row_number > ${offset} AND row_number <= ${offset + PAGE_SIZE} ORDER BY row_number`;
			const rows = await query(sql);
			if (offset === 0 && rows.length === 0) break;
			const pageTotal = Number(rows[0]?.total_rows);
			if (!Number.isSafeInteger(pageTotal) || pageTotal < 0 || (offset > 0 && pageTotal !== total)) throw new Error('Incomplete expense response');
			total = pageTotal;
			if (rows.length !== Math.min(PAGE_SIZE, total - offset)) throw new Error('Incomplete expense page');
			for (const row of rows) {
				const debit = Number(row.debit);
				const credit = Number(row.credit);
				if (![debit, credit].every(Number.isFinite)) throw new Error('Invalid expense amounts');
				const expenseDay = Number(row.expense_day);
				if (!Number.isInteger(expenseDay) || expenseDay < 1 || expenseDay > 31) throw new Error('Invalid expense day');
				const voucherNumber = [row.voucher_prefix, row.voucher_number].filter(value => value != null && value !== '').join('');
				const formType = String(row.form_type ?? '').trim();
				// Use this exact expense line's recorded tax, never the whole voucher
				// tax or a percentage estimate. Missing records remain distinguishable from zero.
				const inputVat = row.input_vat == null ? null : Number(row.input_vat);
				if (inputVat !== null && !Number.isFinite(inputVat)) throw new Error('Invalid recorded input VAT');
				expenses.push({ branchId: branch.id, id: String(row.entry_id),
					date: `${date.slice(0, 7)}-${String(expenseDay).padStart(2, '0')}`, debit, credit, inputVat,
					voucher: [row.voucher_type, voucherNumber].filter(value => value != null && value !== '').join(' · '),
					formType, formName: String(row.form_name ?? '').trim(),
					narration: String(row.narration ?? '').trim() });
			}
			offset += rows.length;
		} while (offset < total);
		branch.status = 'loaded';
		return { branch, expenses };
	} catch (error) {
		const reason = (error instanceof Error ? error.message : 'Unknown ERP error')
			.replaceAll(config.bridge_api_secret, '[redacted]').replaceAll(config.tunnel_url, '[redacted]').slice(0, 500);
		console.error('[Bakery expenses] Branch read failed', { branchId: branch.id, date, reason });
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
		let date = month !== null ? `${month}-01` : url.searchParams.get('date') || '';
		const parsed = new Date(`${date}T00:00:00Z`);
		if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(parsed.getTime()) ||
			parsed.toISOString().slice(0, 10) !== date || Number(date.slice(0, 4)) < 1753 || Number(date.slice(0, 4)) > 9998) {
			return json({ success: false, error: 'Invalid date' }, { status: 400, headers });
		}
		if ((month !== null && month < BAKERY_REPORT_START_MONTH) || (month === null && date < BAKERY_REPORT_START_DATE)) {
			return json({ success: false, error: `Bakery reports are only available from ${BAKERY_REPORT_START_DATE}` }, { status: 400, headers });
		}
		if (date < BAKERY_REPORT_START_DATE) date = BAKERY_REPORT_START_DATE;
		const { data: configs, error } = await db.from('erp_connections')
			.select('branch_id, branch_name, erp_branch_id, tunnel_url, bridge_api_secret, branches(name_en, name_ar)')
			.eq('is_active', true).order('branch_id');
		if (error) throw error;
		const results = await Promise.all((configs || []).map(config => loadBranch(config, date, month !== null)));
		return json({ success: true, date, month, branches: results.map(result => result.branch),
			expenses: results.flatMap(result => result.expenses) }, { headers });
	} catch (error) {
		const unauthorized = error instanceof AuthenticationRequiredError;
		return json({ success: false, error: unauthorized ? 'Authenticated session is required' : 'Unable to load bakery expenses' }, {
			status: unauthorized ? 401 : 500, headers
		});
	}
};
