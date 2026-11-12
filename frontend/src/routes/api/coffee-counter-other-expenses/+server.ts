import { json, type RequestHandler } from '@sveltejs/kit';
import { AuthenticationRequiredError, createAuthenticatedSupabase } from '$lib/server/authenticatedSupabase';
import { coffeeOtherExpense, readCoffeeOtherExpenseTotals } from '$lib/server/coffeeOtherExpenses';
import { bakeryDate } from '$lib/types/bakery';
import type { CoffeeOtherExpense } from '$lib/types/coffeeOtherExpenses';
import { coffeePaymentEditHandler } from '$lib/server/coffeePaymentEdits';

export const PATCH = coffeePaymentEditHandler('expense');

const headers = { 'Cache-Control': 'no-store' };

async function authenticatedDb(request: Request) {
	const db = createAuthenticatedSupabase(request);
	const { data, error } = await db.auth.getUser();
	if (error || !data.user) throw new AuthenticationRequiredError('Authenticated session is required');
	return db;
}

function failure(error: unknown) {
	const unauthorized = error instanceof AuthenticationRequiredError;
	return json({ success: false, error: unauthorized ? 'Authenticated session is required' : 'Unable to load or save other expenses' }, {
		status: unauthorized ? 401 : 500, headers
	});
}

export const GET: RequestHandler = async ({ request, url }) => {
	try {
		const db = await authenticatedDb(request);
		const asOfDate = bakeryDate();
		const month = url.searchParams.get('month');
		if (month !== null && (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month) || Number(month.slice(0, 4)) < 1753 || Number(month.slice(0, 4)) > 9998)) {
			return json({ success: false, error: 'Invalid month' }, { status: 400, headers });
		}
		if (url.searchParams.get('summary') === '1' && month === null) {
			const totals = await readCoffeeOtherExpenseTotals(db, asOfDate);
			if (totals === null) throw new Error('Other expense totals are unavailable');
			return json({ success: true, asOfDate, totals, total: totals.sales + totals.operator }, { headers });
		}
		const payments: CoffeeOtherExpense[] = [];
		let offset = 0, totalRows = 0;
		do {
			let query = db.from('coffee_other_expenses')
				.select('id, amount, narration, expense_date, paid_from, created_at, updated_at, version', { count: 'exact' })
				.lte('expense_date', asOfDate).order('created_at', { ascending: false }).order('id')
				.range(offset, offset + 499);
			if (month !== null) {
				const [year, monthNumber] = month.split('-').map(Number);
				const next = new Date(Date.UTC(year, monthNumber, 1)).toISOString().slice(0, 10);
				query = query.gte('expense_date', `${month}-01`).lt('expense_date', next);
			}
			const { data, error, count } = await query;
			if (error || !data || count === null || (offset > 0 && count !== totalRows)) throw new Error('Other expenses are unavailable');
			totalRows = count;
			if (data.length !== Math.min(500, totalRows - offset)) throw new Error('Incomplete expense page');
			payments.push(...data.map(coffeeOtherExpense));
			offset += data.length;
		} while (offset < totalRows);
		// The list and its total use the same rows, including every page.
		const total = Math.round(payments.reduce((sum, payment) => sum + Math.round(payment.amount * 100), 0)) / 100;
		const totals = { sales: 0, operator: 0 };
		for (const payment of payments) totals[payment.paidFrom] += Math.round(payment.amount * 100);
		totals.sales /= 100; totals.operator /= 100;
		return json({ success: true, asOfDate, payments, total, totals }, { headers });
	} catch (error) { return failure(error); }
};

export const POST: RequestHandler = async ({ request }) => {
	try {
		const db = await authenticatedDb(request);
		const raw = await request.text();
		if (raw.length > 8192) return json({ success: false, error: 'Expense request is too large' }, { status: 400, headers });
		let body;
		try { body = JSON.parse(raw); } catch { return json({ success: false, error: 'Invalid expense request' }, { status: 400, headers }); }
		const id = typeof body?.id === 'string' ? body.id : '';
		const amount = String(body?.amount ?? '');
		const narration = typeof body?.narration === 'string' ? body.narration.trim() : '';
		const paidFrom = body?.paidFrom;
		if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id) ||
			!/^\d{1,12}(\.\d{1,2})?$/.test(amount) || Number(amount) <= 0 || narration.length < 1 || narration.length > 2000 || !['sales', 'operator'].includes(paidFrom)) {
			return json({ success: false, error: 'Enter a positive amount with at most two decimals, a narration, and a payment source' }, { status: 400, headers });
		}
		const { data, error } = await db.rpc('record_coffee_other_expense', { p_id: id, p_amount: amount, p_narration: narration, p_paid_from: paidFrom }).single();
		if (error || !data) {
			if (error?.code === '23505') return json({ success: false, error: 'Expense request already exists with different details' }, { status: 409, headers });
			throw error || new Error('Unable to save expense');
		}
		return json({ success: true, payment: coffeeOtherExpense(data as Record<string, any>) }, { headers });
	} catch (error) { return failure(error); }
};
