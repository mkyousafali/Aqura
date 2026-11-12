import { json, type RequestHandler } from '@sveltejs/kit';
import { AuthenticationRequiredError, createAuthenticatedSupabase } from '$lib/server/authenticatedSupabase';
import { COFFEE_COUNTER, COFFEE_PURCHASE_BRANCH_ID } from '$lib/types/businessCounter';
import { bakeryDate, type BakeryBranch } from '$lib/types/bakery';
import type { CoffeeSupplier } from '$lib/types/coffeeSuppliers';

const headers = { 'Cache-Control': 'no-store' };
const PAGE_SIZE = 500;
const sqlText = (value: string) => `N'${value.replace(/'/g, "''")}'`;

function branchInfo(config: any): BakeryBranch {
	const details = Array.isArray(config.branches) ? config.branches[0] : config.branches;
	return {
		id: String(config.branch_id), nameEn: details?.name_en || config.branch_name || String(config.branch_id),
		nameAr: details?.name_ar || config.branch_name || String(config.branch_id), status: 'unavailable'
	};
}

async function readBranch(config: any, branch: BakeryBranch, select: (erpBranchId: number) => string) {
	const erpBranchId = Number(config.erp_branch_id);
	if (!config.tunnel_url || !config.bridge_api_secret || !Number.isSafeInteger(erpBranchId) || erpBranchId <= 0) {
		branch.status = 'unavailable';
		return null;
	}
	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), 30000);
	try {
		const records: Record<string, unknown>[] = [];
		let offset = 0;
		let total = 0;
		do {
			const sql = `SELECT * FROM (
				SELECT source.*, COUNT(*) OVER() AS total_rows,
					ROW_NUMBER() OVER(ORDER BY source.ledger_id) AS row_number
				FROM (${select(erpBranchId)}) source
			) paged WHERE row_number > ${offset} AND row_number <= ${offset + PAGE_SIZE} ORDER BY row_number`;
			const response = await fetch(`${config.tunnel_url.replace(/\/+$/, '')}/query`, {
				method: 'POST', headers: { 'Content-Type': 'application/json', 'x-api-secret': config.bridge_api_secret },
				body: JSON.stringify({ sql }), signal: controller.signal
			});
			const result = await response.json();
			if (!response.ok || result?.success !== true || !Array.isArray(result.recordset)) throw new Error('Supplier query failed');
			const rows = result.recordset;
			if (offset === 0 && rows.length === 0) break;
			const pageTotal = Number(rows[0]?.total_rows);
			if (!Number.isSafeInteger(pageTotal) || pageTotal < 0 || (offset > 0 && pageTotal !== total)) throw new Error('Incomplete supplier response');
			total = pageTotal;
			if (rows.length !== Math.min(PAGE_SIZE, total - offset)) throw new Error('Incomplete supplier page');
			records.push(...rows);
			offset += rows.length;
		} while (offset < total);
		branch.status = 'loaded';
		return records;
	} catch {
		branch.status = controller.signal.aborted ? 'timeout' : 'failed';
		return null;
	} finally {
		clearTimeout(timeout);
	}
}

export const GET: RequestHandler = async ({ request }) => {
	try {
		const db = createAuthenticatedSupabase(request);
		const { data: auth, error: authError } = await db.auth.getUser();
		if (authError || !auth.user) throw new AuthenticationRequiredError('Authenticated session is required');
		const { data: config, error } = await db.from('erp_connections')
			.select('branch_id, branch_name, erp_branch_id, tunnel_url, bridge_api_secret, branches(name_en, name_ar)')
			.eq('is_active', true).eq('branch_id', Number(COFFEE_PURCHASE_BRANCH_ID)).single();
		if (error) throw error;
		if (!config) throw new Error('Arda connection is unavailable');
		const branch = branchInfo(config);
		const asOfDate = bakeryDate();
		const [year, month, day] = asOfDate.split('-').map(Number);
		const end = `DATEADD(day, 1, DATEFROMPARTS(${year}, ${month}, ${day}))`;
		const group = sqlText(COFFEE_COUNTER.productGroup);
		// Read each related supplier and its full balance directly from Arda.
		// No cross-branch discovery, account matching, or balance requests.
		const rows = await readBranch(config, branch, erp => `
			SELECT l.LedgerID AS ledger_id, l.LedgerCode AS ledger_code, l.LedgerName AS ledger_name,
				ISNULL(balance.amount, 0) AS balance
			FROM AccLedgers l
			OUTER APPLY (
				SELECT SUM(ISNULL(ad.Debit, 0) - ISNULL(ad.Credit, 0)) AS amount
				FROM AccTransactionDetails ad
				INNER JOIN AccTransactionMaster m ON m.AccTransactionMasterID = ad.AccTransactionMasterID AND m.BranchID = ad.BranchID
				WHERE ad.BranchID = l.BranchID AND ad.LedgerID = l.LedgerID
					AND m.IsActive = 1 AND m.TransactionDate < ${end}
			) balance
			WHERE l.BranchID = ${erp} AND EXISTS (
				SELECT 1 FROM InvTransactionMaster m
				INNER JOIN InvTransactionDetails d ON d.InvTransactionMasterID = m.InvTransactionMasterID AND d.BranchID = m.BranchID
				INNER JOIN ProductBatches pb ON pb.ProductBatchID = d.ProductBatchID AND pb.BranchID = d.BranchID
				INNER JOIN Products p ON p.ProductID = pb.ProductID AND p.BranchID = pb.BranchID
				INNER JOIN ProductGroups g ON g.ProductGroupID = p.ProductGroupID AND g.BranchID = p.BranchID
				WHERE m.BranchID = l.BranchID AND m.LedgerID = l.LedgerID AND m.IsActive = 1
					AND m.VoucherType IN ('PI', 'PR') AND m.TransactionDate < ${end}
					AND LTRIM(RTRIM(g.GroupName)) = ${group}
			)`);
		const suppliers: CoffeeSupplier[] = [];
		for (const row of rows || []) {
			const balance = row.balance == null ? NaN : Number(row.balance);
			if (!Number.isFinite(balance)) {
				branch.status = 'failed';
				suppliers.length = 0;
				break;
			}
			suppliers.push({ key: String(row.ledger_id), name: String(row.ledger_name ?? '').trim(),
				ledgerCode: String(row.ledger_code ?? '').trim(), balance });
		}
		return json({ success: true, asOfDate, branches: [branch], suppliers: suppliers.sort((a, b) => a.name.localeCompare(b.name)) }, { headers });
	} catch (error) {
		const unauthorized = error instanceof AuthenticationRequiredError;
		return json({ success: false, error: unauthorized ? 'Authenticated session is required' : 'Unable to load coffee suppliers' }, {
			status: unauthorized ? 401 : 500, headers
		});
	}
};
