import { json, type RequestHandler } from '@sveltejs/kit';
import { AuthenticationRequiredError, createAuthenticatedSupabase } from '$lib/server/authenticatedSupabase';
import { readCounterDaily } from '$lib/server/businessCounterAllTime';
import { readBakeryAllTimeExpenses } from '$lib/server/bakeryAllTimeExpenses';
import { readBakeryOtherPaymentTotal } from '$lib/server/bakeryOtherPayments';
import { readBakeryOtherExpenseTotals } from '$lib/server/bakeryOtherExpenses';
import { BAKERY_COUNTER } from '$lib/types/businessCounter';
import { bakeryDate } from '$lib/types/bakery';

const headers = { 'Cache-Control': 'no-store' };

export const GET: RequestHandler = async ({ request }) => {
	try {
		const db = createAuthenticatedSupabase(request);
		const { data: auth, error: authError } = await db.auth.getUser();
		if (authError || !auth.user) throw new AuthenticationRequiredError('Authenticated session is required');
		const { data: configs, error } = await db.from('erp_connections')
			.select('branch_id, branch_name, erp_branch_id, tunnel_url, bridge_api_secret, branches(name_en, name_ar)')
			.eq('is_active', true).order('branch_id');
		if (error) throw error;
		const connections = configs || [];
		const asOfDate = bakeryDate(-1);
		if (asOfDate < BAKERY_COUNTER.reportStartDate) {
			const branches = connections.map(config => {
				const details = Array.isArray(config.branches) ? config.branches[0] : config.branches;
				return { id: String(config.branch_id), nameEn: details?.name_en || config.branch_name || String(config.branch_id),
					nameAr: details?.name_ar || config.branch_name || String(config.branch_id), status: 'loaded' as const };
			});
			return json({ success: true, asOfDate, branches, expenseBranches: branches, inputVatBranch: null,
				dailySales: [], dailyInputVat: [], vendorPayments: null, otherPaymentsTotal: 0,
				otherExpenseTotals: { sales: 0, operator: 0 }, stockValues: [] }, { headers });
		}
		const [sales, expenses, otherPaymentsTotal, otherExpenseTotals] = await Promise.all([
			Promise.all(connections.map(config => readCounterDaily(config, asOfDate, 'sales', BAKERY_COUNTER))),
			Promise.all(connections.map(config => readBakeryAllTimeExpenses(config, asOfDate))),
			readBakeryOtherPaymentTotal(db, asOfDate),
			readBakeryOtherExpenseTotals(db, asOfDate)
		]);
		return json({ success: true, asOfDate, branches: sales.map(result => result.branch),
			expenseBranches: expenses.map(result => result.branch), inputVatBranch: null,
			dailySales: sales.flatMap(result => result.sales), dailyInputVat: expenses.flatMap(result => result.inputVat),
			vendorPayments: null, otherPaymentsTotal, otherExpenseTotals, stockValues: [] }, { headers });
	} catch (error) {
		const unauthorized = error instanceof AuthenticationRequiredError;
		return json({ success: false, error: unauthorized ? 'Authenticated session is required' : 'Unable to load Bakery all-time report' }, { status: unauthorized ? 401 : 500, headers });
	}
};
