import { beforeEach, describe, expect, it, vi } from 'vitest';

const state = vi.hoisted(() => ({ tables: {} as Record<string, any[]>, inserted: [] as any[], fail: '' }));
vi.mock('$lib/server/breakRegisterAuth', () => ({
	requireBreakUser: async () => ({ id: 'actor', username: 'Tester', isMasterAdmin: true }),
	databaseClient: () => client
}));
vi.mock('$env/dynamic/private', () => ({ env: {} }));
import { creditItem, creditSelection, creditVendorName, loadPayToCreditItems } from './payToCreditItems';
import { POST } from '../../routes/api/assistant-tasks/+server';

const supplier = 'UMMU MAJED';
const client: any = {
	from(table: string) {
		let data = [...(state.tables[table] || [])];
		const query: any = {
			select: () => query,
			eq: (key: string, value: any) => { data = data.filter(row => row[key] === value); return query; },
			is: (key: string, value: any) => { data = data.filter(row => (row[key] ?? null) === value); return query; },
			in: (key: string, values: any[]) => { data = data.filter(row => values.map(String).includes(String(row[key]))); return query; },
			ilike: (key: string, value: string) => {
				data = data.filter(row => String(row[key] || '').toLowerCase() === value.replace(/\\(.)/g, '$1').toLowerCase());
				return query;
			},
			order: () => query,
			range: async (start: number, end: number) => ({ data: data.slice(start, end + 1), error: state.fail === table ? new Error('query failed') : null }),
			insert: (row: any) => { state.inserted.push(row); data = [{ id: 'task-id', ...row }]; return query; },
			maybeSingle: async () => ({ data: data[0] || null, error: null }),
			single: async () => ({ data: data[0] || null, error: null }),
			then: (resolve: any) => Promise.resolve({ data, error: state.fail === table ? new Error('query failed') : null }).then(resolve)
		};
		return query;
	}
};

beforeEach(() => {
	state.fail = '';
	state.inserted = [];
	state.tables = {
		vendors: [{ branch_id: 2, erp_vendor_id: 77, vendor_name: supplier }],
		vendor_payment_schedule_with_vendor: [{ id: '1', branch_id: 2, vendor_name: supplier, is_paid: false, final_bill_amount: 100, approval_status: 'approved' }],
		expense_scheduler: [{ id: 1, branch_id: 2, vendor_id: 77, is_paid: false, amount: 200, requisition_id: 9, bill_number: 'EXP-1' }],
		expense_requisitions: [{ id: 9, status: 'completed' }],
		pos_scan_requests: [{ id: 'scan', branch_id: 2, request_type: 'pay_to_credit_slip', request_label: `Pay to Credit · ${supplier}`, extracted_amount: 1000, payment_account_type: 'cash' }],
		branch_default_positions: [{ branch_id: 2, entry_task_user_id: 'employee', bank_delivery_ledger_name: 'Bank' }],
		hr_employee_master: [{ user_id: 'employee', current_branch_id: 2, is_removed: false }]
	};
});

const post = async (taskType = 'receiving_cash_payment', overrides = {}) => {
	const response = await POST({ cookies: {}, request: new Request('http://localhost/api/assistant-tasks', {
		method: 'POST', body: JSON.stringify({ task_type: taskType, pay_to_credit_transaction_id: 'scan', payment_schedule_ids: ['1'], expense_schedule_ids: ['1'], ...overrides })
	}) } as any);
	return { status: response.status, body: await response.json() };
};

describe('Pay to Credit bills and expenses', () => {
	it('includes expenses when the supplier has no vendor bills', async () => {
		state.tables.vendor_payment_schedule_with_vendor = [];
		const items = await loadPayToCreditItems(client, 2, supplier);
		expect(items).toHaveLength(1);
		expect(items[0]).toMatchObject({ id: 'Expense:1', source_id: '1', final_bill_amount: 200, approval_status: 'approved' });
	});
	it('separates identical bill/expense IDs and submits the original IDs by type', async () => {
		const items = await loadPayToCreditItems(client, 2, supplier);
		expect(creditSelection(items, items.map(item => item.id))).toEqual({ bills: ['1'], expenses: ['1'] });
		expect(creditSelection(items, ['Expense:1'])).toEqual({ bills: [], expenses: ['1'] });
	});
	it('excludes another supplier, another branch and paid expenses', async () => {
		state.tables.expense_scheduler.push(
			{ id: 2, branch_id: 2, vendor_id: 88, amount: 10, is_paid: false },
			{ id: 3, branch_id: 3, vendor_id: 77, amount: 10, is_paid: false },
			{ id: 4, branch_id: 2, vendor_id: 77, amount: 10, is_paid: true }
		);
		expect((await loadPayToCreditItems(client, 2, supplier)).map(item => item.id)).toEqual(['Bill:1', 'Expense:1']);
	});
	it('uses the canonical vendor ID even when an expense has a stale supplier name', async () => {
		state.tables.expense_scheduler[0].vendor_name = 'Old name';
		expect((await loadPayToCreditItems(client, 2, supplier))).toHaveLength(2);
	});
	it('loads expenses beyond the first database page', async () => {
		state.tables.expense_scheduler = Array.from({ length: 1001 }, (_, index) => ({
			id: index + 1, branch_id: 2, vendor_id: 77, is_paid: false, amount: 1
		}));
		expect((await loadPayToCreditItems(client, 2, supplier)).filter(item => item.source_type === 'Expense')).toHaveLength(1001);
	});
	it('includes legacy name-only expenses without matching partial supplier names', async () => {
		state.tables.expense_scheduler = [
			{ id: 1, branch_id: 2, vendor_name: '  ummu  majed ', vendor_id: null, is_paid: false, amount: 50 },
			{ id: 2, branch_id: 2, vendor_name: 'UMMU MAJED TWO', vendor_id: null, is_paid: false, amount: 50 }
		];
		expect((await loadPayToCreditItems(client, 2, supplier)).filter(item => item.source_type === 'Expense').map(item => item.id)).toEqual(['Expense:1']);
	});
	it('keeps a pending or missing requisition unapproved', async () => {
		state.tables.expense_requisitions = [];
		expect((await loadPayToCreditItems(client, 2, supplier)).find(item => item.source_type === 'Expense')?.approval_status).toBe('unknown');
	});
	it('does not hide query failures behind an empty table', async () => {
		state.fail = 'expense_scheduler';
		await expect(loadPayToCreditItems(client, 2, supplier)).rejects.toThrow('query failed');
	});
	it('normalizes expense amounts without replacing a zero bill balance', () => {
		expect(creditItem({ id: 1, amount: '15.25' }, 'Expense').final_bill_amount).toBe(15.25);
		expect(creditItem({ id: 'bill', final_bill_amount: 0, bill_amount: 100 }, 'Bill').final_bill_amount).toBe(0);
		expect(creditVendorName('Pay to Credit · UMMU MAJED')).toBe(supplier);
	});
});

describe('Pay to Credit task creation', () => {
	it.each(['receiving_cash_payment', 'receiving_bank_payment'])('accepts mixed bill and expense selections for %s', async type => {
		if (type === 'receiving_bank_payment') state.tables.pos_scan_requests[0].payment_account_type = 'bank';
		const result = await post(type);
		expect(result.status).toBe(200);
		expect(state.inserted[0].payload).toMatchObject({ amount: '300.00', ledger_name: supplier, payment_schedule_ids: ['1'], expense_schedule_ids: ['1'] });
	});
	it('accepts an expense-only selection', async () => {
		expect((await post('receiving_cash_payment', { payment_schedule_ids: [] })).status).toBe(200);
		expect(state.inserted[0].payload.amount).toBe('200.00');
	});
	it.each(['paid', 'other-vendor', 'other-branch', 'unapproved', 'too-much'])('rejects %s expenses before creating a task', async reason => {
		if (reason === 'paid') state.tables.expense_scheduler[0].is_paid = true;
		if (reason === 'other-vendor') state.tables.expense_scheduler[0].vendor_id = 88;
		if (reason === 'other-branch') state.tables.expense_scheduler[0].branch_id = 3;
		if (reason === 'unapproved') state.tables.expense_requisitions[0].status = 'pending';
		if (reason === 'too-much') state.tables.pos_scan_requests[0].extracted_amount = 250;
		expect((await post()).status).toBe(400);
		expect(state.inserted).toEqual([]);
	});
});
