import { json, type RequestHandler } from '@sveltejs/kit';
import { AuthenticationRequiredError, createAuthenticatedSupabase } from '$lib/server/authenticatedSupabase';
import { bakeryOtherPayment, readBakeryOtherPaymentTotal } from '$lib/server/bakeryOtherPayments';
import { bakeryDate, BAKERY_REPORT_START_MONTH } from '$lib/types/bakery';
import type { CoffeeOtherPayment } from '$lib/types/coffeeOtherPayments';
import { coffeePaymentEditHandler } from '$lib/server/coffeePaymentEdits';

export const PATCH = coffeePaymentEditHandler('withdrawal', 'bakery');

const headers = { 'Cache-Control': 'no-store' };

async function authenticatedDb(request: Request) {
	const db = createAuthenticatedSupabase(request);
	const { data, error } = await db.auth.getUser();
	if (error || !data.user) throw new AuthenticationRequiredError('Authenticated session is required');
	return db;
}

function failure(error: unknown) {
	const unauthorized = error instanceof AuthenticationRequiredError;
	return json({ success: false, error: unauthorized ? 'Authenticated session is required' : 'Unable to load or save other payments' }, {
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
		if (month !== null && month < BAKERY_REPORT_START_MONTH) {
			return json({ success: false, error: 'Bakery reporting starts on 2026-11-12' }, { status: 400, headers });
		}
		if (url.searchParams.get('summary') === '1' && month === null) {
			const total = await readBakeryOtherPaymentTotal(db, asOfDate);
			if (total === null) throw new Error('Other payment total is unavailable');
			return json({ success: true, asOfDate, total }, { headers });
		}
		const payments: CoffeeOtherPayment[] = [];
		let offset = 0, totalRows = 0;
		do {
			let query = db.from('bakery_other_payments')
				.select('id, amount, narration, payment_date, created_at, updated_at, version', { count: 'exact' })
				.lte('payment_date', asOfDate).order('created_at', { ascending: false }).order('id')
				.range(offset, offset + 499);
			if (month !== null) {
				const [year, monthNumber] = month.split('-').map(Number);
				const next = new Date(Date.UTC(year, monthNumber, 1)).toISOString().slice(0, 10);
				query = query.gte('payment_date', `${month}-01`).lt('payment_date', next);
			}
			const { data, error, count } = await query;
			if (error || !data || count === null || (offset > 0 && count !== totalRows)) throw new Error('Other payments are unavailable');
			totalRows = count;
			if (data.length !== Math.min(500, totalRows - offset)) throw new Error('Incomplete payment page');
			payments.push(...data.map(bakeryOtherPayment));
			offset += data.length;
		} while (offset < totalRows);
		// The list and its total use the same rows, including every page.
		const total = Math.round(payments.reduce((sum, payment) => sum + Math.round(payment.amount * 100), 0)) / 100;
		return json({ success: true, asOfDate, payments, total }, { headers });
	} catch (error) { return failure(error); }
};

export const POST: RequestHandler = async ({ request }) => {
	try {
		const db = await authenticatedDb(request);
		const raw = await request.text();
		if (raw.length > 8192) return json({ success: false, error: 'Payment request is too large' }, { status: 400, headers });
		let body;
		try { body = JSON.parse(raw); } catch { return json({ success: false, error: 'Invalid payment request' }, { status: 400, headers }); }
		const id = typeof body?.id === 'string' ? body.id : '';
		const amount = String(body?.amount ?? '');
		const narration = typeof body?.narration === 'string' ? body.narration.trim() : '';
		if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id) ||
			!/^\d{1,12}(\.\d{1,2})?$/.test(amount) || Number(amount) <= 0 || narration.length < 1 || narration.length > 2000) {
			return json({ success: false, error: 'Enter a positive amount with at most two decimals and a narration' }, { status: 400, headers });
		}
		const { data, error } = await db.rpc('record_bakery_other_payment', { p_id: id, p_amount: amount, p_narration: narration }).single();
		if (error || !data) {
			if (error?.code === '23505') return json({ success: false, error: 'Payment request already exists with different details' }, { status: 409, headers });
			throw error || new Error('Unable to save payment');
		}
		return json({ success: true, payment: bakeryOtherPayment(data as Record<string, any>) }, { headers });
	} catch (error) { return failure(error); }
};
