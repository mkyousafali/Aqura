import { expect, it, vi } from 'vitest';
import {
	createReceivingPaymentApprovalLoader, isReceivingPaymentApproved,
	loadReceivingPaymentSchedules, receivingPaymentStatus, type ReceivingPaymentSchedule
} from './receivingPaymentApproval';

const payment = (recordId: string, branchId = 2, status = 'approved'): ReceivingPaymentSchedule => ({
	id: `payment-${recordId}`, receiving_record_id: recordId, branch_id: branchId,
	approval_status: status, bill_number: 'same-bill-number', bill_amount: 100, final_bill_amount: 100
});

function deferred() {
	let resolve!: (payments: ReceivingPaymentSchedule[]) => void;
	let reject!: (error: Error) => void;
	const promise = new Promise<ReceivingPaymentSchedule[]>((yes, no) => { resolve = yes; reject = no; });
	return { promise, resolve, reject };
}

it('keeps the same approval decisions in All Branches and a selected branch across multiple query batches', async () => {
	const rows = Array.from({ length: 205 }, (_, index) => payment(`record-${index}`, index % 2 ? 3 : 2,
		index % 3 ? 'approved' : 'pending'));
	const client = { from: vi.fn(() => {
		let selected: string[] = [];
		const query: any = {
			select: () => query, order: () => query,
			in: (_column: string, ids: string[]) => {
				if (ids.length > 20) throw new Error('502: approval filter exceeds proxy limit');
				selected = ids; return query;
			},
			range: (from: number, to: number) => Promise.resolve({
				data: rows.filter(row => selected.includes(row.receiving_record_id)).slice(from, to + 1), error: null
			})
		};
		return query;
	}) };
	let state: Record<string, ReceivingPaymentSchedule[]> = {};
	const load = createReceivingPaymentApprovalLoader(ids => loadReceivingPaymentSchedules(client, ids), next => { state = next; });
	await load(rows.map(row => row.receiving_record_id));
	const allBranches = Object.fromEntries(rows.map(row => [row.receiving_record_id,
		isReceivingPaymentApproved(state[row.receiving_record_id], row.branch_id)]));
	const branchRows = rows.filter(row => row.branch_id === 2);
	await load(branchRows.map(row => row.receiving_record_id));
	for (const row of rows) {
		expect(isReceivingPaymentApproved(state[row.receiving_record_id], row.branch_id)).toBe(allBranches[row.receiving_record_id]);
		expect(allBranches[row.receiving_record_id]).toBe(row.approval_status === 'approved');
	}
	expect(client.from).toHaveBeenCalledTimes(17);
});

it('merges an overlapping branch response without discarding other branches or restoring an older approval', async () => {
	const all = deferred();
	const branch = deferred();
	const query = vi.fn().mockReturnValueOnce(all.promise).mockReturnValueOnce(branch.promise);
	let state: Record<string, ReceivingPaymentSchedule[]> = {};
	const load = createReceivingPaymentApprovalLoader(query, next => { state = next; });
	const allLoad = load(['branch-2-record', 'branch-3-record']);
	const branchLoad = load(['branch-2-record']);
	branch.resolve([payment('branch-2-record', 2, 'pending')]);
	await branchLoad;
	all.resolve([payment('branch-2-record'), payment('branch-3-record', 3)]);
	await allLoad;
	expect(isReceivingPaymentApproved(state['branch-2-record'], 2)).toBe(false);
	expect(isReceivingPaymentApproved(state['branch-3-record'], 3)).toBe(true);
});

it('preserves other displayed records when realtime refreshes only one payment', async () => {
	let state: Record<string, ReceivingPaymentSchedule[]> = {};
	const query = vi.fn().mockResolvedValueOnce([payment('a'), payment('b', 3)])
		.mockResolvedValueOnce([payment('a', 2, 'sent_for_approval')]);
	const load = createReceivingPaymentApprovalLoader(query, next => { state = next; });
	await load(['a', 'b']);
	const refresh = load(['a']);
	expect(isReceivingPaymentApproved(state.a, 2)).toBe(false);
	expect(isReceivingPaymentApproved(state.b, 3)).toBe(true);
	await refresh;
	expect(state.a[0].approval_status).toBe('sent_for_approval');
	expect(isReceivingPaymentApproved(state.b, 3)).toBe(true);
});

it('keeps a failed refresh blocked even if an older approved response arrives later', async () => {
	const old = deferred();
	const current = deferred();
	const query = vi.fn().mockReturnValueOnce(old.promise).mockReturnValueOnce(current.promise);
	let state: Record<string, ReceivingPaymentSchedule[]> = {};
	const load = createReceivingPaymentApprovalLoader(query, next => { state = next; });
	const oldLoad = load(['a']);
	const currentLoad = load(['a']);
	current.reject(new Error('Approval lookup failed'));
	await expect(currentLoad).rejects.toThrow('Approval lookup failed');
	old.resolve([payment('a')]);
	await oldLoad;
	expect(isReceivingPaymentApproved(state.a, 2)).toBe(false);
});

it('removes a deleted schedule instead of retaining its approved status', async () => {
	let state: Record<string, ReceivingPaymentSchedule[]> = {};
	const query = vi.fn().mockResolvedValueOnce([payment('a')]).mockResolvedValueOnce([]);
	const load = createReceivingPaymentApprovalLoader(query, next => { state = next; });
	await load(['a']);
	await load(['a']);
	expect(isReceivingPaymentApproved(state.a, 2)).toBe(false);
});

it('reports checking, loaded and failed lookups separately on initial load', async () => {
	const first = deferred();
	const query = vi.fn().mockReturnValueOnce(first.promise).mockRejectedValueOnce(new Error('502'));
	const changes = vi.fn();
	const load = createReceivingPaymentApprovalLoader(query, changes);
	const initial = load(['a']);
	expect(changes).toHaveBeenLastCalledWith({}, { a: 'loading' });
	first.resolve([payment('a')]);
	await initial;
	expect(changes).toHaveBeenLastCalledWith({ a: [payment('a')] }, { a: 'loaded' });
	await expect(load(['a'])).rejects.toThrow('502');
	expect(changes).toHaveBeenLastCalledWith({}, { a: 'error' });
});

it('keeps an approved on-delivery bill unpaid until its saved payment is marked paid', () => {
	const lusin = { ...payment('lusin', 3), bill_number: '930221607050', is_paid: false };
	expect(isReceivingPaymentApproved([lusin], 3)).toBe(true);
	expect(receivingPaymentStatus([lusin])).toEqual({ is_paid: false, is_scheduled: true, has_multiple_schedules: false });
});

it('does not show a partly paid split bill as fully paid', () => {
	expect(receivingPaymentStatus([{ is_paid: true }, { is_paid: false }])).toEqual({
		is_paid: false, is_scheduled: true, has_multiple_schedules: true
	});
	expect(receivingPaymentStatus([{ is_paid: true }, { is_paid: true }]).is_paid).toBe(true);
});

it('does not infer a paid payment when the schedule is missing', () => {
	expect(receivingPaymentStatus([])).toEqual({ is_paid: false, is_scheduled: false, has_multiple_schedules: false });
});

it('reflects Mark Paid and unmarking after payment schedule refreshes', async () => {
	const query = vi.fn().mockResolvedValueOnce([{ ...payment('a'), is_paid: false }])
		.mockResolvedValueOnce([{ ...payment('a'), is_paid: true }])
		.mockResolvedValueOnce([{ ...payment('a'), is_paid: false }]);
	let paid: boolean | undefined;
	const load = createReceivingPaymentApprovalLoader(query, (payments, statuses) => {
		if (statuses.a === 'loaded') paid = receivingPaymentStatus(payments.a).is_paid;
	});
	await load(['a']);
	expect(paid).toBe(false);
	await load(['a']);
	expect(paid).toBe(true);
	await load(['a']);
	expect(paid).toBe(false);
});
