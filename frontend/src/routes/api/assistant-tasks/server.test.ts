import { beforeEach, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({ user: vi.fn(), from: vi.fn(), queries: [] as any[], results: [] as any[] }));
vi.mock('@supabase/supabase-js', () => ({ createClient: () => ({ from: mocks.from }) }));
vi.mock('$env/dynamic/private', () => ({ env: { VITE_SUPABASE_URL: 'https://database.test', SUPABASE_SERVICE_ROLE_KEY: 'test' } }));
vi.mock('$lib/server/breakRegisterAuth', () => ({ requireBreakUser: mocks.user, databaseClient: () => ({ from: mocks.from }) }));
import { GET, POST } from './+server';

const originalId = '33333333-3333-4333-8333-333333333333';
const reversalId = '44444444-4444-4444-8444-444444444444';
const reversal = (payload: Record<string, unknown> = {}) => ({
	id: reversalId, task_type: 'salary_vikin_adjustment_jv', assigned_to: 'current-user', status: 'pending',
	payload: { entry_kind: 'reversal', depends_on_task_id: originalId, lines: [{ ledger_code: 'AL98', side: 'Credit', amount: '2000.00' }], ...payload }
});
const call = () => GET({ cookies: {}, url: new URL('https://aqura.test/api/assistant-tasks') } as any);

beforeEach(() => {
	vi.resetAllMocks();
	mocks.queries.length = 0;
	mocks.results.length = 0;
	mocks.user.mockResolvedValue({ id: 'current-user', isMasterAdmin: false });
	mocks.from.mockImplementation(() => {
		const result = mocks.results.shift() || { data: [], error: null };
		const query: any = {
			select: vi.fn(), eq: vi.fn(), in: vi.fn(), order: vi.fn(), range: vi.fn(), maybeSingle: vi.fn(), single: vi.fn(), insert: vi.fn(),
			then: (resolve: (value: unknown) => unknown) => Promise.resolve(result).then(resolve)
		};
		for (const method of [query.select, query.eq, query.in, query.order, query.range, query.maybeSingle, query.single, query.insert]) method.mockReturnValue(query);
		mocks.queries.push(query);
		return query;
	});
});

it('exposes the current completed original status without changing the immutable reversal payload', async () => {
	const task = reversal({ depends_on_status: 'pending' });
	mocks.results.push({ data: [task], error: null }, { data: [{ id: originalId, status: 'completed' }], error: null });
	const response = await call();
	expect(response.status).toBe(200);
	expect(await response.json()).toEqual({ success: true, tasks: [{ ...task, depends_on_task_id: originalId, depends_on_status: 'completed' }] });
	expect(task.payload.depends_on_status).toBe('pending');
	expect(mocks.queries[0].eq).toHaveBeenCalledWith('assigned_to', 'current-user');
	expect(mocks.queries[0].in).toHaveBeenCalledWith('status', ['pending', 'in_progress', 'failed']);
	expect(mocks.queries[1].select).toHaveBeenCalledWith('id,status');
	expect(mocks.queries[1].eq.mock.calls).toEqual([['assigned_to', 'current-user'], ['task_type', 'salary_vikin_adjustment_jv']]);
	expect(mocks.queries[1].in).toHaveBeenCalledWith('id', [originalId]);
});

it.each(['pending', 'in_progress', 'failed', 'cancelled'])('uses authoritative original status %s instead of a payload hint', async status => {
	const task = reversal({ depends_on_status: 'completed' });
	mocks.results.push({ data: [task], error: null }, { data: [{ id: originalId, status }], error: null });
	expect((await (await call()).json()).tasks[0].depends_on_status).toBe(status);
});

it('keeps the reversal blocked when its original is missing or belongs to another assignee', async () => {
	mocks.results.push({ data: [reversal()], error: null }, { data: [], error: null });
	expect((await (await call()).json()).tasks[0].depends_on_status).toBeNull();
	expect(mocks.queries[1].eq).toHaveBeenCalledWith('assigned_to', 'current-user');
});

it('leaves unrelated tasks, original JVs and legacy no-save tasks unchanged without querying parents', async () => {
	const tasks = [
		{ ...reversal(), task_type: 'bank_planner_jv' },
		{ ...reversal(), payload: { entry_kind: 'adjustment' } },
		{ ...reversal(), task_type: 'salary_vikin_adjustment_test_jv' }
	];
	mocks.results.push({ data: tasks, error: null });
	expect(await (await call()).json()).toEqual({ success: true, tasks });
	expect(mocks.from).toHaveBeenCalledOnce();
});

it('loads each original only once when multiple returned reversals refer to it', async () => {
	mocks.results.push({ data: [reversal(), { ...reversal(), id: 'another-reversal' }], error: null },
		{ data: [{ id: originalId, status: 'completed' }], error: null });
	const response = await (await call()).json();
	expect(response.tasks.every((task: any) => task.depends_on_status === 'completed')).toBe(true);
	expect(mocks.queries[1].in).toHaveBeenCalledWith('id', [originalId]);
});

it.each(['not-a-uuid', '', null])('does not send malformed dependency ID %j to the database', async depends_on_task_id => {
	mocks.results.push({ data: [reversal({ depends_on_task_id })], error: null });
	expect((await (await call()).json()).tasks[0].depends_on_status).toBeNull();
	expect(mocks.from).toHaveBeenCalledOnce();
});

it('returns an error rather than claiming a dependency is completed when its query fails', async () => {
	mocks.results.push({ data: [reversal()], error: null }, { data: null, error: { message: 'Parent status unavailable' } });
	const response = await (await call()).json();
	expect(response.success).toBe(false);
	expect(response.tasks).toBeUndefined();
});

it('requires a desktop session before accessing tasks or dependencies', async () => {
	mocks.user.mockRejectedValue(new Error('Desktop session required'));
	expect((await call()).status).toBe(401);
	expect(mocks.from).not.toHaveBeenCalled();
});

const receivingId = '55555555-5555-4555-8555-555555555555';
const paymentTypes = ['receiving_bank_payment', 'receiving_cash_payment'];
const receivingPost = (task_type: string) => POST({ cookies: {}, request: new Request('https://aqura.test/api/assistant-tasks', {
	method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ task_type, receiving_record_id: receivingId })
}) } as any);
const payment = (approval_status: string | null = 'approved', extra = {}) => ({
	id: 'payment-id', receiving_record_id: receivingId, branch_id: 2,
	approval_status, bill_amount: 100, final_bill_amount: 100, ...extra
});

function receivingFixture(taskType: string, payments: any[]) {
	mocks.user.mockResolvedValue({ id: 'current-user', isMasterAdmin: true });
	mocks.results.push({ data: {
		id: receivingId, branch_id: 2, vendor_id: 77, user_id: 'receiver', bill_number: 'B-1',
		payment_method: taskType === 'receiving_bank_payment' ? 'Bank on Delivery' : 'Cash on Delivery',
		pr_excel_file_url: '/pr.xlsx', original_bill_check_result: { status: 'matched' },
		erp_check_result: { status: 'matched' }, final_bill_amount: 100
	}, error: null }, { data: payments, error: null });
}

it.each(paymentTypes)('blocks unapproved %s tasks, including for master admins and bills labelled paid', async taskType => {
	for (const status of [null, 'pending', 'sent_for_approval', 'rejected']) {
		receivingFixture(taskType, [payment(status, { is_paid: true })]);
		const response = await receivingPost(taskType);
		expect(response.status).toBe(400);
		expect((await response.json()).error).toContain('Payment approval is required');
	}
	expect(mocks.from.mock.calls.some(([table]) => table === 'assistant_workflow_tasks')).toBe(false);
});

it.each(paymentTypes)('requires all linked installments to be approved for %s', async taskType => {
	receivingFixture(taskType, [payment(), payment('pending', { id: 'split-payment' })]);
	expect((await receivingPost(taskType)).status).toBe(400);
	expect(mocks.from.mock.calls.some(([table]) => table === 'assistant_workflow_tasks')).toBe(false);
});

it.each(paymentTypes)('blocks %s when the payment schedule is missing or belongs to another branch', async taskType => {
	for (const payments of [[], [payment('approved', { branch_id: 3 })]]) {
		receivingFixture(taskType, payments);
		expect((await receivingPost(taskType)).status).toBe(400);
	}
	expect(mocks.from.mock.calls.some(([table]) => table === 'assistant_workflow_tasks')).toBe(false);
});

it.each(paymentTypes)('creates %s after payment approval while preserving the receiving task payload', async taskType => {
	receivingFixture(taskType, [payment()]);
	mocks.results.push(
		{ data: { entry_task_user_id: 'entry-user', bank_delivery_ledger_id: 9, bank_delivery_ledger_name: 'Bank' }, error: null },
		{ data: { vendor_name: 'Supplier' }, error: null },
		{ data: { username: 'Receiver' }, error: null }
	);
	if (taskType === 'receiving_bank_payment') mocks.results.push({ data: { check_result: { status: 'matched' } }, error: null });
	mocks.results.push(
		{ data: { name_en: 'Receiver' }, error: null },
		{ data: { user_id: 'entry-user' }, error: null },
		{ data: { id: 'task-id', status: 'pending' }, error: null }
	);
	const response = await receivingPost(taskType);
	expect(response.status).toBe(200);
	expect((await response.json()).success).toBe(true);
	const insert = mocks.queries.at(-1).insert;
	expect(insert).toHaveBeenCalledWith(expect.objectContaining({
		task_type: taskType, source_record_id: receivingId, branch_id: 2, status: 'pending', assigned_to: 'entry-user',
		payload: expect.objectContaining({ receiving_record_id: receivingId, ledger_name: 'Supplier', amount: '100.00', payment_schedule_ids: ['payment-id'], vendor_id: 77 })
	}));
});

it.each(paymentTypes)('does not create %s when approval status cannot be loaded', async taskType => {
	receivingFixture(taskType, []);
	mocks.results[1] = { data: null, error: { message: 'Approval lookup unavailable' } };
	const response = await receivingPost(taskType);
	expect(response.status).toBe(400);
	expect((await response.json()).error).toBe('Approval lookup unavailable');
	expect(mocks.from.mock.calls.some(([table]) => table === 'assistant_workflow_tasks')).toBe(false);
});
