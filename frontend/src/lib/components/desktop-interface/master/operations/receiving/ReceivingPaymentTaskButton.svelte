<script lang="ts">
	import { isReceivingPaymentApproved, type ReceivingPaymentSchedule, type ReceivingPaymentApprovalStatus } from '$lib/utils/receivingPaymentApproval';

	export let approvalStatus: ReceivingPaymentApprovalStatus | undefined = undefined;
	export let payments: ReceivingPaymentSchedule[] = [];
	export let branchId: number;
	export let sending = false;
	export let taskSent = false;
	export let requestingApproval = false;
	export let approvalRequestBusy = false;
	export let onPost: () => void = () => {};
	export let onRequestApproval: () => void = () => {};
	export let onRetry: () => void = () => {};

	$: approved = approvalStatus === 'loaded' && isReceivingPaymentApproved(payments, branchId);
	$: awaitingApproval = payments.some(payment => payment.approval_status === 'sent_for_approval') &&
		payments.every(payment => ['approved', 'sent_for_approval'].includes(payment.approval_status || ''));
</script>

{#if approvalStatus !== 'loaded'}
	<button type="button" class="inline-flex items-center gap-1 px-2 py-1 text-[10px] font-bold rounded-md border border-slate-300 bg-slate-50 text-slate-700 disabled:opacity-50 disabled:cursor-not-allowed"
		on:click={onRetry} disabled={approvalStatus !== 'error'}>{approvalStatus === 'error' ? 'Retry approval check' : 'Checking approval…'}</button>
{:else if approved}
	<button type="button" class="inline-flex items-center gap-1 px-2 py-1 text-[10px] font-bold rounded-md border border-indigo-300 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 disabled:opacity-50 disabled:cursor-not-allowed"
		on:click={onPost} disabled={sending || taskSent} title="Send payment task to the branch default Entry Task User">{sending ? '⏳ Sending' : taskSent ? '✓ Task Sent' : '➤ Post Task'}</button>
{:else}
	<button type="button" class="inline-flex items-center gap-1 px-2 py-1 text-[10px] font-bold rounded-md border border-amber-300 bg-amber-50 text-amber-700 hover:bg-amber-100 disabled:opacity-50 disabled:cursor-not-allowed"
		on:click={onRequestApproval} disabled={approvalRequestBusy || awaitingApproval}>{requestingApproval ? 'Loading...' : awaitingApproval ? 'Awaiting Approval' : 'Send for Approval'}</button>
{/if}
