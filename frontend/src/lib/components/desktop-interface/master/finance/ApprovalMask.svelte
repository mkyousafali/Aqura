<script>
	/**
	 * ApprovalMask Component
	 * Displays a blur overlay over content that requires approval
	 * Shows approval status and action button
	 */
	export let approvalStatus = 'pending'; // 'pending' | 'sent_for_approval' | 'approved' | 'rejected'
	export let onRequestApproval = () => {}; // Callback when "Send for Approval" is clicked
	export let disabled = false; // Disable the button

	// Status label mapping
	const statusLabels = {
		pending: 'Approval Not Requested',
		sent_for_approval: 'Sent for Approval',
		approved: 'Approved',
		rejected: 'Rejected'
	};

	// Status colors
	const statusColors = {
		pending: 'bg-yellow-500',
		sent_for_approval: 'bg-blue-500',
		approved: 'bg-green-500',
		rejected: 'bg-red-500'
	};

	$: statusLabel = statusLabels[approvalStatus] || 'Unknown Status';
	$: statusColor = statusColors[approvalStatus] || 'bg-gray-500';
	$: showButton = approvalStatus === 'pending' || approvalStatus === 'rejected';
</script>

<div class="approval-mask-container">
	<!-- Show button when pending or rejected (to allow resend) -->
	{#if approvalStatus === 'pending'}
		<button
			class="approval-send-button"
			on:click={onRequestApproval}
			disabled={disabled}
			title="Send for Approval - Status: {statusLabel}"
		>
			Send
		</button>
	{:else if approvalStatus === 'rejected'}
		<button
			class="approval-resend-button"
			on:click={onRequestApproval}
			disabled={disabled}
			title="Resend for Approval - Previously Rejected"
		>
			🔄 Resend
		</button>
	{:else if approvalStatus === 'sent_for_approval'}
		<span class="approval-status-text waiting" title="{statusLabel}">
			⏳ Waiting
		</span>
	{:else if approvalStatus === 'approved'}
		<span class="approval-status-text approved" title="{statusLabel}">
			✓ Approved
		</span>
	{/if}
</div>

<style>
	.approval-mask-container {
		position: relative;
		width: 100%;
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.approval-send-button {
		padding: 0.5rem 1rem;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		font-weight: 600;
		font-size: 0.875rem;
		border: none;
		border-radius: 0.375rem;
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
		white-space: nowrap;
		z-index: 105;
		position: relative;
	}

	.approval-send-button:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
	}

	.approval-send-button:active:not(:disabled) {
		transform: translateY(0);
	}

	.approval-send-button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.approval-resend-button {
		padding: 0.5rem 1rem;
		background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
		color: white;
		font-weight: 600;
		font-size: 0.875rem;
		border: none;
		border-radius: 0.375rem;
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
		white-space: nowrap;
		z-index: 105;
		position: relative;
	}

	.approval-resend-button:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
		background: linear-gradient(135deg, #f87171 0%, #ef4444 100%);
	}

	.approval-resend-button:active:not(:disabled) {
		transform: translateY(0);
	}

	.approval-resend-button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.approval-status-text {
		padding: 0.5rem 1rem;
		font-weight: 600;
		font-size: 0.875rem;
		border-radius: 0.375rem;
		white-space: nowrap;
		display: inline-flex;
		align-items: center;
		gap: 0.375rem;
	}

	.approval-status-text.waiting {
		background: #3b82f6;
		color: white;
	}

	.approval-status-text.approved {
		background: #10b981;
		color: white;
	}
</style>
