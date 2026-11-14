import { json, type RequestHandler } from '@sveltejs/kit';
import { AuthenticationRequiredError, createAuthenticatedSupabase } from '$lib/server/authenticatedSupabase';
import { COFFEE_PURCHASE_BRANCH_ID } from '$lib/types/businessCounter';
import type { BakeryBranch } from '$lib/types/bakery';
import { counterEntryThroughDate } from '$lib/server/businessCounterCutoff';
import type { CoffeeAllTimeInputVat } from '$lib/types/coffeeAllTime';
import { readCoffeeVendorPayments } from '$lib/server/coffeeVendorPayments';
import { readCoffeeOtherPaymentTotal } from '$lib/server/coffeeOtherPayments';
import { readCoffeeStockValue } from '$lib/server/coffeeStock';
import { readCoffeeOtherExpenseTotals } from '$lib/server/coffeeOtherExpenses';

import { readCounterDaily as readDaily } from '$lib/server/businessCounterAllTime';

const headers = { 'Cache-Control': 'no-store' };
export const GET: RequestHandler = async ({ request, url }) => {
	try {
		const db = createAuthenticatedSupabase(request);
		const { data: auth, error: authError } = await db.auth.getUser();
		if (authError || !auth.user) throw new AuthenticationRequiredError('Authenticated session is required');
		const asOfDate = counterEntryThroughDate(url.searchParams.get('through'));
		if (asOfDate === null) return json({ success: false, error: 'Invalid report cutoff date' }, { status: 400, headers });
		const { data: configs, error } = await db.from('erp_connections')
			.select('branch_id, branch_name, erp_branch_id, tunnel_url, bridge_api_secret, branches(name_en, name_ar)')
			.eq('is_active', true).order('branch_id');
		if (error) throw error;
		const connections = configs || [];
		const arda = connections.find(config => String(config.branch_id) === COFFEE_PURCHASE_BRANCH_ID);
		const [sales, input, vendorPayments, otherPaymentsTotal, stockValues, otherExpenseTotals] = await Promise.all([
			Promise.all(connections.map(config => readDaily(config, asOfDate, 'sales'))),
			arda ? readDaily(arda, asOfDate, 'inputVat') : Promise.resolve({
				branch: { id: COFFEE_PURCHASE_BRANCH_ID, nameEn: 'Arda', nameAr: 'العارضة', status: 'unavailable' } as BakeryBranch,
				inputVat: [] as CoffeeAllTimeInputVat[]
			}),
			readCoffeeVendorPayments(arda, asOfDate),
			readCoffeeOtherPaymentTotal(db, asOfDate),
			Promise.all(connections.map(config => readCoffeeStockValue(config))),
			readCoffeeOtherExpenseTotals(db, asOfDate)
		]);
		return json({ success: true, asOfDate, branches: sales.map(result => result.branch),
			inputVatBranch: input.branch, dailySales: sales.flatMap(result => result.sales), dailyInputVat: input.inputVat, vendorPayments, otherPaymentsTotal, stockValues, otherExpenseTotals }, { headers });
	} catch (error) {
		const unauthorized = error instanceof AuthenticationRequiredError;
		return json({ success: false, error: unauthorized ? 'Authenticated session is required' : 'Unable to load all-time report' }, {
			status: unauthorized ? 401 : 500, headers
		});
	}
};
