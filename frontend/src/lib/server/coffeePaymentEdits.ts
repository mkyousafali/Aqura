import { json, type RequestHandler } from '@sveltejs/kit';
import { AuthenticationRequiredError, createAuthenticatedSupabase } from './authenticatedSupabase';
import { coffeeOtherPayment } from './coffeeOtherPayments';
import { coffeeOtherExpense } from './coffeeOtherExpenses';
import { counterPostingDate } from './businessCounterCutoff';

const headers = { 'Cache-Control': 'no-store' };

export function coffeePaymentEditHandler(kind: 'withdrawal' | 'expense', counter: 'coffee' | 'bakery' = 'coffee'): RequestHandler {
	return async ({ request }) => {
		try {
			const db = createAuthenticatedSupabase(request);
			const { data: auth, error: authError } = await db.auth.getUser();
			if (authError || !auth.user) throw new AuthenticationRequiredError('Authenticated session is required');
			const { data: allowed, error: accessError } = await db.rpc(`${counter}_master_admin_allowed`);
			if (accessError) throw new Error('Unable to verify edit access');
			if (allowed !== true) return json({ success: false, error: 'Master admin required' }, { status: 403, headers });
			const raw = await request.text();
			if (raw.length > 8192) return json({ success: false, error: 'Request is too large' }, { status: 400, headers });
			let body;
			try { body = JSON.parse(raw); } catch { return json({ success: false, error: 'Invalid request' }, { status: 400, headers }); }
			const id = typeof body?.id === 'string' ? body.id : '';
			const amount = String(body?.amount ?? '');
			const narration = typeof body?.narration === 'string' ? body.narration.trim() : '';
			const version = body?.expectedVersion;
			const postingDate = body?.postingDate === undefined ? undefined : counterPostingDate(body.postingDate, counter);
			if (postingDate === null) return json({ success: false, error: 'Invalid posting date' }, { status: 400, headers });
			if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id) ||
				!/^\d{1,12}(\.\d{1,2})?$/.test(amount) || Number(amount) <= 0 || narration.length < 1 || narration.length > 2000 ||
				!Number.isSafeInteger(version) || version < 1 || (kind === 'expense' && !['sales', 'operator'].includes(body?.paidFrom))) {
				return json({ success: false, error: 'Invalid entry details' }, { status: 400, headers });
			}
			const parameters = { p_id: id, p_expected_version: version, p_amount: amount, p_narration: narration,
				...(postingDate === undefined ? {} : { p_posting_date: postingDate }) };
			const { data, error } = kind === 'expense'
				? await db.rpc(`edit_${counter}_other_expense`, { ...parameters, p_paid_from: body.paidFrom }).single()
				: await db.rpc(`edit_${counter}_withdrawal`, parameters).single();
			if (error || !data) {
				const status = error?.code === '42501' ? 403 : error?.code === '40001' ? 409 : error?.code === 'P0002' ? 404 : error?.code === '22023' ? 400 : 500;
				return json({ success: false, error: status === 409 ? 'Entry changed; refresh before editing' : status === 403 ? 'Master admin required' : 'Unable to update entry' }, { status, headers });
			}
			const row = data as Record<string, any>;
			return json({ success: true, payment: kind === 'expense' ? coffeeOtherExpense(row) : coffeeOtherPayment(row) }, { headers });
		} catch (error) {
			const unauthorized = error instanceof AuthenticationRequiredError;
			return json({ success: false, error: unauthorized ? 'Authenticated session is required' : 'Unable to update entry' }, { status: unauthorized ? 401 : 500, headers });
		}
	};
}
