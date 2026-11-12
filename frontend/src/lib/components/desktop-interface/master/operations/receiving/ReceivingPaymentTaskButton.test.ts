import { expect, it } from 'vitest';
import { render } from 'svelte/server';
import ReceivingPaymentTaskButton from './ReceivingPaymentTaskButton.svelte';
import type { ReceivingPaymentSchedule } from '$lib/utils/receivingPaymentApproval';

const payment: ReceivingPaymentSchedule = {
	id: 'payment', receiving_record_id: 'record', branch_id: 3, approval_status: 'approved',
	bill_number: '930221607050', bill_amount: 348.54, final_bill_amount: 348.54
};

it.each([undefined, 'loading'] as const)('hides Post Task until the initial approval lookup finishes (%s)', approvalStatus => {
	const { body } = render(ReceivingPaymentTaskButton, { props: { branchId: 3, payments: [payment], approvalStatus } });
	expect(body).toContain('Checking approval…');
	expect(body).toMatch(/\sdisabled(?:\s|=|>)/);
	expect(body).not.toContain('Post Task');
	expect(body).not.toContain('Send for Approval');
});

it('offers a retry instead of treating a failed initial lookup as an approval decision', () => {
	const { body } = render(ReceivingPaymentTaskButton, { props: { branchId: 3, payments: [payment], approvalStatus: 'error' } });
	expect(body).toContain('Retry approval check');
	expect(body).not.toContain('Post Task');
	expect(body).not.toMatch(/\sdisabled(?:\s|=|>)/);
});

it.each(['pending', 'rejected', null])('shows Send for Approval for an unapproved loaded payment (%s)', approval_status => {
	const { body } = render(ReceivingPaymentTaskButton, { props: { branchId: 3, approvalStatus: 'loaded', payments: [{ ...payment, approval_status }] } });
	expect(body).toContain('Send for Approval');
	expect(body).not.toContain('Post Task');
});

it('shows Post Task only after an approved payment has loaded', () => {
	const { body } = render(ReceivingPaymentTaskButton, { props: { branchId: 3, approvalStatus: 'loaded', payments: [payment] } });
	expect(body).toContain('Post Task');
	expect(body).not.toContain('Send for Approval');
});

it('shows Awaiting Approval while an approval request is pending', () => {
	const { body } = render(ReceivingPaymentTaskButton, { props: {
		branchId: 3, approvalStatus: 'loaded', payments: [{ ...payment, approval_status: 'sent_for_approval' }]
	} });
	expect(body).toContain('Awaiting Approval');
	expect(body).toMatch(/\sdisabled(?:\s|=|>)/);
	expect(body).not.toContain('Post Task');
});
