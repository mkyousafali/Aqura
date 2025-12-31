<script>
	/**
	 * ApproverListModal Component
	 * Displays a list of eligible approvers and allows submitting for approval
	 */
	import { supabase } from '$lib/utils/supabase';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { createEventDispatcher } from 'svelte';

	export let isOpen = false;
	export let paymentData = null; // The payment being sent for approval
	export let currentUserId = null; // ID of user requesting approval
	export let currentUserName = 'Unknown'; // Name of user requesting approval

	const dispatch = createEventDispatcher();

	let approvers = [];
	let loading = true;
	let error = null;
	let selectedApprover = null;
	let submitting = false;
	let searchQuery = '';
	
	// Filtered approvers based on search
	$: filteredApprovers = approvers.filter(approver => {
		if (!searchQuery) return true;
		const query = searchQuery.toLowerCase();
		return (
			approver.username.toLowerCase().includes(query) ||
			approver.roleType.toLowerCase().includes(query)
		);
	});

	// Load eligible approvers when modal opens
	$: if (isOpen && paymentData) {
		loadApprovers();
	}

	async function loadApprovers() {
		loading = true;
		error = null;
		approvers = [];

		try {
			const paymentAmount = paymentData.final_bill_amount || paymentData.bill_amount || 0;

			// Query approval_permissions to find eligible approvers
			const { data, error: queryError } = await supabase
				.from('approval_permissions')
				.select(`
					id,
					user_id,
					vendor_payment_amount_limit,
					users!approval_permissions_user_id_fkey (
						id,
						username,
						is_master_admin,
						is_admin
					)
				`)
				.eq('can_approve_vendor_payments', true)
				.eq('is_active', true);

			if (queryError) throw queryError;

			// Filter approvers by amount limit and exclude current user
			approvers = (data || [])
				.filter(perm => {
					// Exclude the current user who is requesting approval
					if (perm.user_id === currentUserId) return false;
					
					// Check if user data exists (basic validation)
					if (!perm.users) return false;
					
					// If limit is 0, it means unlimited
					if (perm.vendor_payment_amount_limit === 0) return true;
					// Otherwise check if limit is >= payment amount
					return perm.vendor_payment_amount_limit >= paymentAmount;
				})
			.map(perm => ({
				userId: perm.user_id,
				username: perm.users?.username || 'Unknown',
				roleType: perm.users?.is_master_admin ? 'Master Admin' : perm.users?.is_admin ? 'Admin' : 'User',
				amountLimit: perm.vendor_payment_amount_limit
			}));			if (approvers.length === 0) {
				error = 'No eligible approvers found for this payment amount.';
			}
		} catch (err) {
			console.error('Error loading approvers:', err);
			error = err.message || 'Failed to load approvers';
		} finally {
			loading = false;
		}
	}

	async function submitForApproval() {
		if (!paymentData || !currentUserId) return;

		submitting = true;
		error = null;

		try {
			// Update the payment record with approval request
			const { error: updateError } = await supabase
				.from('vendor_payment_schedule')
				.update({
					approval_status: 'sent_for_approval',
					approval_requested_by: currentUserId,
					approval_requested_at: new Date().toISOString(),
					updated_at: new Date().toISOString()
				})
				.eq('id', paymentData.id);

			if (updateError) throw updateError;

			// Send notification to approvers
			try {
				const approverUserIds = approvers.map(a => a.userId);
				const paymentAmount = formatAmount(paymentData.final_bill_amount || paymentData.bill_amount);
				
				await notificationManagement.createNotification({
					title: '💰 Vendor Payment Approval Request',
					message: `A vendor payment requires your approval:\n\nBill #: ${paymentData.bill_number}\nVendor: ${paymentData.vendor_name}\nAmount: ${paymentAmount} SAR\nBranch: ${paymentData.branch_name}\n\nRequested by: ${currentUserName}`,
					type: 'approval_request',
					priority: 'high',
					target_type: 'specific_users',
					target_users: approverUserIds
				}, currentUserId);
				
				console.log('✅ Approval notification sent to approvers:', approverUserIds);
			} catch (notifError) {
				console.error('⚠️ Failed to send approval notification:', notifError);
				// Don't fail the whole operation if notification fails
			}

			// Dispatch success event
			dispatch('submitted', {
				paymentId: paymentData.id,
				approvers: approvers
			});

			// Close modal
			closeModal();
		} catch (err) {
			console.error('Error submitting for approval:', err);
			error = err.message || 'Failed to submit for approval';
		} finally {
			submitting = false;
		}
	}

	function closeModal() {
		isOpen = false;
		selectedApprover = null;
		approvers = [];
		error = null;
		searchQuery = '';
		dispatch('close');
	}

	function formatAmount(amount) {
		return new Intl.NumberFormat('en-US', {
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		}).format(amount || 0);
	}
</script>

{#if isOpen}
	<div class="modal-backdrop" on:click={closeModal}>
		<div class="modal-container" on:click|stopPropagation>
			<!-- Modal Header -->
			<div class="modal-header">
				<h2 class="modal-title">Send for Approval</h2>
				<button class="close-button" on:click={closeModal}>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
					</svg>
				</button>
			</div>

			<!-- Modal Body -->
			<div class="modal-body">
				<!-- Payment Info -->
				{#if paymentData}
					<div class="payment-info-card">
						<h3 class="section-title">Payment Details</h3>
						<div class="info-grid">
							<div class="info-item">
								<span class="info-label">Bill #:</span>
								<span class="info-value">{paymentData.bill_number}</span>
							</div>
							<div class="info-item">
								<span class="info-label">Vendor:</span>
								<span class="info-value">{paymentData.vendor_name}</span>
							</div>
							<div class="info-item">
								<span class="info-label">Amount:</span>
								<span class="info-value amount">{formatAmount(paymentData.final_bill_amount || paymentData.bill_amount)}</span>
							</div>
							<div class="info-item">
								<span class="info-label">Branch:</span>
								<span class="info-value">{paymentData.branch_name}</span>
							</div>
						</div>
					</div>
				{/if}

				<!-- Approvers List -->
				<div class="approvers-section">
					<h3 class="section-title">Eligible Approvers</h3>

					{#if loading}
						<div class="loading-state">
							<svg class="animate-spin w-8 h-8" fill="none" viewBox="0 0 24 24">
								<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
								<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
							</svg>
							<p>Loading approvers...</p>
						</div>
					{:else if error}
						<div class="error-state">
							<svg class="w-12 h-12 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
							</svg>
							<p>{error}</p>
						</div>
					{:else if approvers.length > 0}
						<!-- Search Box -->
						<div class="search-container">
							<svg class="search-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
							</svg>
							<input 
								type="text" 
								class="search-input"
								placeholder="Search approvers by name or role..."
								bind:value={searchQuery}
							/>
							{#if searchQuery}
								<button class="clear-search" on:click={() => searchQuery = ''}>
									<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
									</svg>
								</button>
							{/if}
						</div>

						<!-- Results count -->
						{#if searchQuery}
							<p class="results-count">
								Found {filteredApprovers.length} of {approvers.length} approver{filteredApprovers.length !== 1 ? 's' : ''}
							</p>
						{/if}

						<div class="approvers-list">
							{#each filteredApprovers as approver (approver.userId)}
								<div 
									class="approver-card" 
									class:selected={selectedApprover?.userId === approver.userId}
									on:click={() => selectedApprover = selectedApprover?.userId === approver.userId ? null : approver}
								>
									<div class="approver-avatar">
										<svg class="w-8 h-8" fill="currentColor" viewBox="0 0 20 20">
											<path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd" />
										</svg>
									</div>
									<div class="approver-info">
										<p class="approver-name">{approver.username}</p>
										<p class="approver-role">{approver.roleType}</p>
										{#if approver.amountLimit === 0}
											<span class="limit-badge unlimited">Unlimited</span>
										{:else}
											<span class="limit-badge">Limit: {formatAmount(approver.amountLimit)}</span>
										{/if}
									</div>
									{#if selectedApprover?.userId === approver.userId}
										<div class="selected-indicator">
											<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
												<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
											</svg>
										</div>
									{/if}
								</div>
							{/each}
						</div>
						
						{#if filteredApprovers.length === 0}
							<div class="no-results">
								<svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
								</svg>
								<p>No approvers found matching "{searchQuery}"</p>
							</div>
						{:else}
							<p class="approvers-note">
								<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
									<path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
								</svg>
								{#if selectedApprover}
									<strong>{selectedApprover.username}</strong> will be notified and can approve this payment.
								{:else}
									Click to select an approver (optional) or submit to notify all eligible approvers.
								{/if}
							</p>
						{/if}
					{/if}
				</div>
			</div>

			<!-- Modal Footer -->
			<div class="modal-footer">
				<button class="btn-cancel" on:click={closeModal} disabled={submitting}>
					Cancel
				</button>
				<button 
					class="btn-submit" 
					on:click={submitForApproval} 
					disabled={submitting || loading || filteredApprovers.length === 0}
				>
					{#if submitting}
						<svg class="animate-spin w-5 h-5 mr-2" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Submitting...
					{:else}
						<svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
						</svg>
						{#if selectedApprover}
							Send to {selectedApprover.username}
						{:else}
							Submit for Approval
						{/if}
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.modal-backdrop {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 1rem;
	}

	.modal-container {
		background: white;
		border-radius: 1rem;
		max-width: 600px;
		width: 100%;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1.5rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-title {
		font-size: 1.5rem;
		font-weight: 700;
		color: #111827;
		margin: 0;
	}

	.close-button {
		background: none;
		border: none;
		color: #6b7280;
		cursor: pointer;
		padding: 0.5rem;
		border-radius: 0.5rem;
		transition: all 0.2s;
	}

	.close-button:hover {
		background: #f3f4f6;
		color: #111827;
	}

	.modal-body {
		flex: 1;
		overflow-y: auto;
		padding: 1.5rem;
	}

	.payment-info-card {
		background: #f9fafb;
		border-radius: 0.75rem;
		padding: 1.25rem;
		margin-bottom: 1.5rem;
	}

	.section-title {
		font-size: 1rem;
		font-weight: 600;
		color: #374151;
		margin: 0 0 1rem 0;
	}

	.info-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
	}

	.info-item {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.info-label {
		font-size: 0.75rem;
		font-weight: 500;
		color: #6b7280;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.info-value {
		font-size: 0.875rem;
		font-weight: 600;
		color: #111827;
	}

	.info-value.amount {
		color: #059669;
		font-size: 1rem;
	}

	.approvers-section {
		margin-top: 1.5rem;
	}

	.search-container {
		position: relative;
		margin-bottom: 1rem;
	}

	.search-icon {
		position: absolute;
		left: 1rem;
		top: 50%;
		transform: translateY(-50%);
		width: 1.25rem;
		height: 1.25rem;
		color: #9ca3af;
		pointer-events: none;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem 3rem 0.75rem 3rem;
		border: 2px solid #e5e7eb;
		border-radius: 0.75rem;
		font-size: 0.875rem;
		transition: all 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: #8b5cf6;
		box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
	}

	.clear-search {
		position: absolute;
		right: 1rem;
		top: 50%;
		transform: translateY(-50%);
		background: #f3f4f6;
		border: none;
		border-radius: 9999px;
		padding: 0.25rem;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		color: #6b7280;
	}

	.clear-search:hover {
		background: #e5e7eb;
		color: #374151;
	}

	.results-count {
		font-size: 0.875rem;
		color: #6b7280;
		margin: 0 0 0.75rem 0;
		padding-left: 0.25rem;
	}

	.no-results {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem 2rem;
		gap: 1rem;
		color: #9ca3af;
	}

	.no-results svg {
		opacity: 0.5;
	}

	.no-results p {
		margin: 0;
		font-size: 0.875rem;
	}

	.loading-state,
	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem;
		gap: 1rem;
		color: #6b7280;
	}

	.error-state {
		color: #ef4444;
	}

	.approvers-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		margin-bottom: 1rem;
	}

	.approver-card {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1rem;
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 0.75rem;
		transition: all 0.2s;
		cursor: pointer;
		position: relative;
	}

	.approver-card:hover {
		border-color: #8b5cf6;
		box-shadow: 0 4px 6px -1px rgba(139, 92, 246, 0.1);
		transform: translateY(-1px);
	}

	.approver-card.selected {
		border-color: #8b5cf6;
		background: #f5f3ff;
		box-shadow: 0 4px 12px -1px rgba(139, 92, 246, 0.2);
	}

	.approver-avatar {
		width: 3rem;
		height: 3rem;
		border-radius: 9999px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		flex-shrink: 0;
	}

	.approver-info {
		flex: 1;
	}

	.approver-name {
		font-weight: 600;
		color: #111827;
		margin: 0 0 0.25rem 0;
	}

	.approver-role {
		font-size: 0.875rem;
		color: #6b7280;
		margin: 0 0 0.5rem 0;
	}

	.limit-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		background: #e0e7ff;
		color: #4338ca;
		font-size: 0.75rem;
		font-weight: 600;
		border-radius: 9999px;
	}

	.limit-badge.unlimited {
		background: #d1fae5;
		color: #065f46;
	}

	.selected-indicator {
		position: absolute;
		right: 1rem;
		top: 50%;
		transform: translateY(-50%);
		color: #8b5cf6;
		animation: scaleIn 0.2s ease-out;
	}

	@keyframes scaleIn {
		from {
			transform: translateY(-50%) scale(0);
		}
		to {
			transform: translateY(-50%) scale(1);
		}
	}

	.approvers-note {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 1rem;
		background: #eff6ff;
		border-radius: 0.5rem;
		color: #1e40af;
		font-size: 0.875rem;
		margin: 0;
	}

	.modal-footer {
		display: flex;
		align-items: center;
		justify-content: flex-end;
		gap: 0.75rem;
		padding: 1.5rem;
		border-top: 1px solid #e5e7eb;
	}

	.btn-cancel,
	.btn-submit {
		padding: 0.75rem 1.5rem;
		border-radius: 0.5rem;
		font-weight: 600;
		border: none;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
	}

	.btn-cancel {
		background: #f3f4f6;
		color: #374151;
	}

	.btn-cancel:hover:not(:disabled) {
		background: #e5e7eb;
	}

	.btn-submit {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
	}

	.btn-submit:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 10px 15px -3px rgba(139, 92, 246, 0.3);
	}

	.btn-cancel:disabled,
	.btn-submit:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	@media (max-width: 640px) {
		.modal-container {
			max-height: 95vh;
		}

		.info-grid {
			grid-template-columns: 1fr;
		}

		.approver-card {
			flex-direction: column;
			text-align: center;
		}
	}
</style>
