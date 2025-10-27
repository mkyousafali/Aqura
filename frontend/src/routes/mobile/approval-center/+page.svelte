<script>
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { goto } from '$app/navigation';

	let loading = true;
	let requisitions = [];
	let filteredRequisitions = [];
	let selectedStatus = 'pending';
	let selectedRequisition = null;
	let showDetailModal = false;
	let isProcessing = false;
	let userCanApprove = false; // Track if current user has approval permissions

	// Stats
	let stats = {
		pending: 0,
		approved: 0,
		rejected: 0,
		total: 0
	};

	onMount(() => {
		loadRequisitions();
	});

	async function loadRequisitions() {
		try {
			loading = true;
			
			// Check if user is logged in
			if (!$currentUser?.id) {
				alert('❌ Please login to access the approval center');
				goto('/mobile-login');
				return;
			}

		// Get current user's approval permissions
		const { supabase } = await import('$lib/utils/supabase');
		const { data: userData, error: userError } = await supabase
			.from('users')
			.select('id, username, can_approve_payments, approval_amount_limit')
			.eq('id', $currentUser.id)
			.single();

		if (userError) {
			console.error('Error checking user permissions:', userError);
		}

		// Store user's approval permission status (don't block viewing)
		userCanApprove = userData?.can_approve_payments || false;
		console.log('👤 User approval permission:', userCanApprove);			// Import supabaseAdmin for admin queries
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			
			// Fetch requisitions (without JOIN to avoid FK requirement)
			const { data, error } = await supabaseAdmin
				.from('expense_requisitions')
				.select('*')
				.order('created_at', { ascending: false });

			if (error) {
				console.error('❌ Supabase query error:', error);
				throw error;
			}

			requisitions = data || [];
			
			// Fetch usernames for all unique created_by IDs
			if (requisitions.length > 0) {
				const userIds = [...new Set(requisitions.map(r => r.created_by).filter(Boolean))];
				
				if (userIds.length > 0) {
					const { data: usersData } = await supabaseAdmin
						.from('users')
						.select('id, username')
						.in('id', userIds);
					
					// Create a map of user IDs to usernames
					const userMap = {};
					if (usersData) {
						usersData.forEach(user => {
							userMap[user.id] = user.username;
						});
					}
					
					// Add username to each requisition
					requisitions = requisitions.map(req => ({
						...req,
						created_by_username: userMap[req.created_by] || req.created_by || 'Unknown'
					}));
				}
			}

			// Calculate stats
			stats.total = requisitions.length;
			stats.pending = requisitions.filter(r => r.status === 'pending').length;
			stats.approved = requisitions.filter(r => r.status === 'approved').length;
			stats.rejected = requisitions.filter(r => r.status === 'rejected').length;

			filterRequisitions();
		} catch (err) {
			console.error('Error loading requisitions:', err);
			alert('Error loading requisitions: ' + err.message);
		} finally {
			loading = false;
		}
	}

	function filterRequisitions() {
		if (selectedStatus === 'all') {
			filteredRequisitions = requisitions;
		} else {
			filteredRequisitions = requisitions.filter(r => r.status === selectedStatus);
		}
	}

	function filterByStatus(status) {
		selectedStatus = status;
		filterRequisitions();
	}

	function openDetail(requisition) {
		selectedRequisition = requisition;
		showDetailModal = true;
	}

	function closeDetail() {
		showDetailModal = false;
		selectedRequisition = null;
	}

	async function approveRequisition() {
		if (!selectedRequisition || isProcessing) return;

		try {
			isProcessing = true;
		const { supabaseAdmin } = await import('$lib/utils/supabase');

		const { error } = await supabaseAdmin
			.from('expense_requisitions')
			.update({
				status: 'approved',
				updated_at: new Date().toISOString()
			})
			.eq('id', selectedRequisition.id);

		if (error) throw error;			alert('✅ Requisition approved successfully!');
			closeDetail();
			await loadRequisitions();
		} catch (err) {
			console.error('Error approving requisition:', err);
			alert('Error approving requisition: ' + err.message);
		} finally {
			isProcessing = false;
		}
	}

	async function rejectRequisition() {
		if (!selectedRequisition || isProcessing) return;

		const reason = prompt('Please enter rejection reason:');
		if (!reason) return;

		try {
			isProcessing = true;
		const { supabaseAdmin } = await import('$lib/utils/supabase');

		const { error } = await supabaseAdmin
			.from('expense_requisitions')
			.update({
				status: 'rejected',
				updated_at: new Date().toISOString(),
				description: selectedRequisition.description 
					? `${selectedRequisition.description}\n\nRejection Reason: ${reason}`
					: `Rejection Reason: ${reason}`
			})
			.eq('id', selectedRequisition.id);

		if (error) throw error;			alert('❌ Requisition rejected.');
			closeDetail();
			await loadRequisitions();
		} catch (err) {
			console.error('Error rejecting requisition:', err);
			alert('Error rejecting requisition: ' + err.message);
		} finally {
			isProcessing = false;
		}
	}

	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function formatAmount(amount) {
		if (!amount) return '0.00';
		return parseFloat(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
	}
</script>

<div class="mobile-approval-center">
	<div class="page-header">
		<h1>✅ Approval Center</h1>
		<p>Review and approve expense requests</p>
	</div>

	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>Loading requisitions...</p>
		</div>
	{:else}
		<!-- Stats Cards -->
		<div class="stats-grid">
			<div class="stat-card pending" on:click={() => filterByStatus('pending')}>
				<div class="stat-value">{stats.pending}</div>
				<div class="stat-label">⏳ Pending</div>
			</div>
			<div class="stat-card approved" on:click={() => filterByStatus('approved')}>
				<div class="stat-value">{stats.approved}</div>
				<div class="stat-label">✅ Approved</div>
			</div>
			<div class="stat-card rejected" on:click={() => filterByStatus('rejected')}>
				<div class="stat-value">{stats.rejected}</div>
				<div class="stat-label">❌ Rejected</div>
			</div>
			<div class="stat-card total" on:click={() => filterByStatus('all')}>
				<div class="stat-value">{stats.total}</div>
				<div class="stat-label">📊 Total</div>
			</div>
		</div>

		<!-- Filter Tabs -->
		<div class="filter-tabs">
			<button 
				class="tab" 
				class:active={selectedStatus === 'pending'} 
				on:click={() => filterByStatus('pending')}
			>
				Pending ({stats.pending})
			</button>
			<button 
				class="tab" 
				class:active={selectedStatus === 'approved'} 
				on:click={() => filterByStatus('approved')}
			>
				Approved ({stats.approved})
			</button>
			<button 
				class="tab" 
				class:active={selectedStatus === 'rejected'} 
				on:click={() => filterByStatus('rejected')}
			>
				Rejected ({stats.rejected})
			</button>
			<button 
				class="tab" 
				class:active={selectedStatus === 'all'} 
				on:click={() => filterByStatus('all')}
			>
				All ({stats.total})
			</button>
		</div>

		<!-- Requisitions List -->
		<div class="requisitions-list">
			{#if filteredRequisitions.length === 0}
				<div class="empty-state">
					<div class="empty-icon">📋</div>
					<p>No requisitions found</p>
				</div>
			{:else}
				{#each filteredRequisitions as req}
					<div class="req-card" on:click={() => openDetail(req)}>
						<div class="req-header">
							<div class="req-number">{req.requisition_number}</div>
							<div class="status-badge status-{req.status}">{req.status}</div>
						</div>
						<div class="req-info">
							<div class="info-row">
								<span class="label">Branch:</span>
								<span class="value">{req.branch_name}</span>
							</div>
							<div class="info-row">
								<span class="label">Generated by:</span>
								<span class="value">👤 {req.created_by_username}</span>
							</div>
							<div class="info-row">
								<span class="label">Amount:</span>
								<span class="value amount">SAR {formatAmount(req.requisition_amount)}</span>
							</div>
							<div class="info-row">
								<span class="label">Date:</span>
								<span class="value">{formatDate(req.created_at)}</span>
							</div>
						</div>
					</div>
				{/each}
			{/if}
		</div>
	{/if}
</div>

<!-- Detail Modal -->
{#if showDetailModal && selectedRequisition}
	<div class="modal-overlay" on:click={closeDetail}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2>Requisition Details</h2>
				<button class="close-btn" on:click={closeDetail}>✕</button>
			</div>

			<div class="modal-body">
				<div class="detail-section">
					<div class="detail-item">
						<span class="label">Requisition #:</span>
						<span class="value">{selectedRequisition.requisition_number}</span>
					</div>
					<div class="detail-item">
						<span class="label">Branch:</span>
						<span class="value">{selectedRequisition.branch_name}</span>
					</div>
					<div class="detail-item">
						<span class="label">Generated by:</span>
						<span class="value">{selectedRequisition.created_by_username}</span>
					</div>
					<div class="detail-item">
						<span class="label">Requester:</span>
						<span class="value">{selectedRequisition.requester_name}</span>
					</div>
					<div class="detail-item">
						<span class="label">Category:</span>
						<span class="value">{selectedRequisition.expense_category_name_en}</span>
					</div>
					<div class="detail-item">
						<span class="label">Amount:</span>
						<span class="value amount-large">SAR {formatAmount(selectedRequisition.requisition_amount)}</span>
					</div>
					<div class="detail-item">
						<span class="label">Payment Type:</span>
						<span class="value">{selectedRequisition.payment_type}</span>
					</div>
					<div class="detail-item">
						<span class="label">Status:</span>
						<span class="status-badge status-{selectedRequisition.status}">{selectedRequisition.status}</span>
					</div>
					<div class="detail-item">
						<span class="label">Date:</span>
						<span class="value">{formatDate(selectedRequisition.created_at)}</span>
					</div>
					{#if selectedRequisition.description}
						<div class="detail-item full-width">
							<span class="label">Description:</span>
							<span class="value">{selectedRequisition.description}</span>
						</div>
					{/if}
				</div>

				{#if selectedRequisition.status === 'pending'}
					{#if !userCanApprove}
						<div class="permission-notice">
							ℹ️ You do not have permission to approve or reject requisitions.
							<br><small>Please contact your administrator for approval permissions.</small>
						</div>
					{/if}
					<div class="action-buttons">
						<button 
							class="btn-approve" 
							on:click={approveRequisition} 
							disabled={isProcessing || !userCanApprove}
							title={!userCanApprove ? 'You need approval permissions' : 'Approve this requisition'}
						>
							✅ Approve
						</button>
						<button 
							class="btn-reject" 
							on:click={rejectRequisition} 
							disabled={isProcessing || !userCanApprove}
							title={!userCanApprove ? 'You need approval permissions' : 'Reject this requisition'}
						>
							❌ Reject
						</button>
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.mobile-approval-center {
		padding: 1rem;
		padding-bottom: 5rem;
	}

	.page-header {
		margin-bottom: 1.5rem;
	}

	.page-header h1 {
		font-size: 1.5rem;
		font-weight: 700;
		color: #1F2937;
		margin-bottom: 0.25rem;
	}

	.page-header p {
		color: #6B7280;
		font-size: 0.875rem;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem 1rem;
		color: #6B7280;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 3px solid #E5E7EB;
		border-top-color: #3B82F6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.75rem;
		margin-bottom: 1.5rem;
	}

	.stat-card {
		background: white;
		border-radius: 12px;
		padding: 1rem;
		text-align: center;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
		cursor: pointer;
		transition: all 0.2s;
	}

	.stat-card:active {
		transform: scale(0.98);
	}

	.stat-value {
		font-size: 2rem;
		font-weight: 700;
		margin-bottom: 0.25rem;
	}

	.stat-label {
		font-size: 0.75rem;
		color: #6B7280;
		text-transform: uppercase;
		font-weight: 600;
	}

	.stat-card.pending .stat-value { color: #F59E0B; }
	.stat-card.approved .stat-value { color: #10B981; }
	.stat-card.rejected .stat-value { color: #EF4444; }
	.stat-card.total .stat-value { color: #3B82F6; }

	.filter-tabs {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 1rem;
		overflow-x: auto;
		padding-bottom: 0.5rem;
	}

	.tab {
		padding: 0.5rem 1rem;
		border-radius: 20px;
		border: 1px solid #E5E7EB;
		background: white;
		color: #6B7280;
		font-size: 0.875rem;
		font-weight: 500;
		white-space: nowrap;
		cursor: pointer;
		transition: all 0.2s;
	}

	.tab.active {
		background: #3B82F6;
		color: white;
		border-color: #3B82F6;
	}

	.requisitions-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.req-card {
		background: white;
		border-radius: 12px;
		padding: 1rem;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
		cursor: pointer;
		transition: all 0.2s;
	}

	.req-card:active {
		transform: scale(0.98);
	}

	.req-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.75rem;
		padding-bottom: 0.75rem;
		border-bottom: 1px solid #F3F4F6;
	}

	.req-number {
		font-weight: 700;
		color: #1F2937;
		font-size: 0.875rem;
	}

	.status-badge {
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
	}

	.status-badge.status-pending {
		background: #FEF3C7;
		color: #D97706;
	}

	.status-badge.status-approved {
		background: #D1FAE5;
		color: #059669;
	}

	.status-badge.status-rejected {
		background: #FEE2E2;
		color: #DC2626;
	}

	.req-info {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.info-row {
		display: flex;
		justify-content: space-between;
		font-size: 0.875rem;
	}

	.info-row .label {
		color: #6B7280;
		font-weight: 500;
	}

	.info-row .value {
		color: #1F2937;
		font-weight: 600;
		text-align: right;
	}

	.info-row .value.amount {
		color: #10B981;
		font-family: 'Courier New', monospace;
	}

	.empty-state {
		text-align: center;
		padding: 3rem 1rem;
		color: #9CA3AF;
	}

	.empty-icon {
		font-size: 3rem;
		margin-bottom: 1rem;
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: flex-end;
		z-index: 2000;
		animation: fadeIn 0.2s;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	.modal-content {
		background: white;
		width: 100%;
		max-height: 85vh;
		border-radius: 20px 20px 0 0;
		overflow-y: auto;
		animation: slideUp 0.3s;
	}

	@keyframes slideUp {
		from { transform: translateY(100%); }
		to { transform: translateY(0); }
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.25rem;
		border-bottom: 1px solid #F3F4F6;
		position: sticky;
		top: 0;
		background: white;
		z-index: 10;
	}

	.modal-header h2 {
		font-size: 1.25rem;
		font-weight: 700;
		color: #1F2937;
	}

	.close-btn {
		width: 32px;
		height: 32px;
		border-radius: 50%;
		border: none;
		background: #F3F4F6;
		color: #6B7280;
		font-size: 1.25rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.modal-body {
		padding: 1.25rem;
	}

	.detail-section {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		margin-bottom: 1.5rem;
	}

	.detail-item {
		display: flex;
		justify-content: space-between;
		padding: 0.75rem;
		background: #F9FAFB;
		border-radius: 8px;
	}

	.detail-item.full-width {
		flex-direction: column;
		gap: 0.5rem;
	}

	.detail-item .label {
		color: #6B7280;
		font-weight: 500;
		font-size: 0.875rem;
	}

	.detail-item .value {
		color: #1F2937;
		font-weight: 600;
		font-size: 0.875rem;
		text-align: right;
	}

	.amount-large {
		color: #10B981 !important;
		font-family: 'Courier New', monospace;
		font-size: 1.125rem !important;
	}

	.permission-notice {
		padding: 0.875rem 1rem;
		background: #fef3c7;
		border: 1px solid #fbbf24;
		border-radius: 12px;
		color: #92400e;
		font-size: 0.875rem;
		text-align: center;
		margin-bottom: 1rem;
	}

	.permission-notice small {
		font-size: 0.75rem;
		color: #b45309;
		display: block;
		margin-top: 0.25rem;
	}

	.action-buttons {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		padding-top: 1rem;
		border-top: 1px solid #F3F4F6;
	}

	.btn-approve,
	.btn-reject {
		padding: 1rem;
		border-radius: 12px;
		border: none;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-approve {
		background: #10B981;
		color: white;
	}

	.btn-approve:active {
		background: #059669;
		transform: scale(0.98);
	}

	.btn-reject {
		background: #EF4444;
		color: white;
	}

	.btn-reject:active {
		background: #DC2626;
		transform: scale(0.98);
	}

	.btn-approve:disabled,
	.btn-reject:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
</style>
