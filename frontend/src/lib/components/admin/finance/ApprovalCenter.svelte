<script>
	// Approval Center Component
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	let requisitions = [];
	let filteredRequisitions = [];
	let loading = true;
	let selectedStatus = 'pending';
	let searchQuery = '';
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
			loading = false;
			return;
		}

		console.log('🔐 Current user:', $currentUser);

		// Get current user's approval permissions using user ID
		const { data: userData, error: userError } = await supabase
			.from('users')
			.select('id, username, can_approve_payments, approval_amount_limit')
			.eq('id', $currentUser.id)
			.single();

		console.log('👤 User query result:', { userData, userError });

		if (userError) {
			console.error('Error fetching user data:', userError);
			alert('❌ Error checking user permissions: ' + userError.message);
			loading = false;
			return;
		}

		// Store user's approval permission status (don't block viewing)
		userCanApprove = userData?.can_approve_payments || false;
		console.log('👤 User approval permission:', userCanApprove);

		console.log('✅ Loading approval center for user:', userData.username);			// IMPORTANT: Use supabaseAdmin for queries that need to bypass RLS
			// since we're using custom auth, not Supabase Auth
			console.log('🔍 Fetching requisitions from expense_requisitions table...');
			
			// Import supabaseAdmin for admin queries
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			
			// Fetch requisitions (without JOIN to avoid FK requirement)
			const { data, error } = await supabaseAdmin
				.from('expense_requisitions')
				.select('*')
				.order('created_at', { ascending: false });

			console.log('📊 Query result:', { data, error, count: data?.length });

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
			
			console.log('✅ Loaded requisitions:', requisitions.length);		// Calculate stats
		stats.total = requisitions.length;
		stats.pending = requisitions.filter(r => r.status === 'pending').length;
		stats.approved = requisitions.filter(r => r.status === 'approved').length;
		stats.rejected = requisitions.filter(r => r.status === 'rejected').length;

		console.log('📈 Stats:', stats);

		filterRequisitions();
		} catch (err) {
			console.error('Error loading requisitions:', err);
			alert('Error loading requisitions: ' + err.message);
		} finally {
			loading = false;
		}
	}

	function filterRequisitions() {
		let filtered = requisitions;

		console.log('🔍 Filtering requisitions:', {
			total: requisitions.length,
			selectedStatus,
			searchQuery
		});

		// Filter by status
		if (selectedStatus !== 'all') {
			filtered = filtered.filter(r => r.status === selectedStatus);
			console.log(`  ↳ After status filter (${selectedStatus}):`, filtered.length);
		}

		// Filter by search query
		if (searchQuery.trim()) {
			const query = searchQuery.toLowerCase();
			filtered = filtered.filter(r =>
				r.requisition_number.toLowerCase().includes(query) ||
				r.branch_name.toLowerCase().includes(query) ||
				r.requester_name.toLowerCase().includes(query) ||
				r.expense_category_name_en?.toLowerCase().includes(query) ||
				r.description?.toLowerCase().includes(query)
			);
			console.log(`  ↳ After search filter (${query}):`, filtered.length);
		}

		filteredRequisitions = filtered;
		console.log('✅ Final filtered requisitions:', filteredRequisitions.length);
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

	async function approveRequisition(requisitionId) {
		if (!confirm('Are you sure you want to approve this requisition?')) return;

		try {
			isProcessing = true;

			// Use supabaseAdmin for update operations
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			
			const { error } = await supabaseAdmin
				.from('expense_requisitions')
				.update({
					status: 'approved',
					updated_at: new Date().toISOString()
				})
				.eq('id', requisitionId);

			if (error) throw error;

			alert('✅ Requisition approved successfully!');
			closeDetail();
			await loadRequisitions();
		} catch (err) {
			console.error('Error approving requisition:', err);
			alert('Error approving requisition: ' + err.message);
		} finally {
			isProcessing = false;
		}
	}

	async function rejectRequisition(requisitionId) {
		const reason = prompt('Please provide a reason for rejection:');
		if (!reason) return;

		try {
			isProcessing = true;

			// Use supabaseAdmin for update operations
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			
			const { error } = await supabaseAdmin
				.from('expense_requisitions')
				.update({
					status: 'rejected',
					updated_at: new Date().toISOString()
				})
				.eq('id', requisitionId);

			if (error) throw error;

			alert('❌ Requisition rejected successfully!');
			closeDetail();
			await loadRequisitions();
		} catch (err) {
			console.error('Error rejecting requisition:', err);
			alert('Error rejecting requisition: ' + err.message);
		} finally {
			isProcessing = false;
		}
	}

	function getStatusClass(status) {
		switch (status) {
			case 'pending': return 'status-pending';
			case 'approved': return 'status-approved';
			case 'rejected': return 'status-rejected';
			default: return '';
		}
	}

	function formatCurrency(amount) {
		return new Intl.NumberFormat('en-SA', {
			style: 'currency',
			currency: 'SAR'
		}).format(amount);
	}

	function formatDate(dateString) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}
</script>

<div class="approval-center">
	<div class="header">
		<h1 class="title">✅ Approval Center</h1>
		<p class="subtitle">Review and approve expense requests</p>
	</div>

	<!-- Stats Cards -->
	<div class="stats-grid">
		<div class="stat-card pending clickable" on:click={() => filterByStatus('pending')}>
			<div class="stat-icon">⏳</div>
			<div class="stat-content">
				<div class="stat-value">{stats.pending}</div>
				<div class="stat-label">Pending</div>
			</div>
		</div>
		<div class="stat-card approved clickable" on:click={() => filterByStatus('approved')}>
			<div class="stat-icon">✅</div>
			<div class="stat-content">
				<div class="stat-value">{stats.approved}</div>
				<div class="stat-label">Approved</div>
			</div>
		</div>
		<div class="stat-card rejected clickable" on:click={() => filterByStatus('rejected')}>
			<div class="stat-icon">❌</div>
			<div class="stat-content">
				<div class="stat-value">{stats.rejected}</div>
				<div class="stat-label">Rejected</div>
			</div>
		</div>
		<div class="stat-card total clickable" on:click={() => filterByStatus('all')}>
			<div class="stat-icon">📊</div>
			<div class="stat-content">
				<div class="stat-value">{stats.total}</div>
				<div class="stat-label">Total</div>
			</div>
		</div>
	</div>

	<!-- Filters -->
	<div class="filters">
		<div class="filter-group">
			<label>Status:</label>
			<select bind:value={selectedStatus} on:change={filterRequisitions}>
				<option value="all">All</option>
				<option value="pending">Pending</option>
				<option value="approved">Approved</option>
				<option value="rejected">Rejected</option>
			</select>
		</div>
		<div class="filter-group search">
			<input
				type="text"
				bind:value={searchQuery}
				on:input={filterRequisitions}
				placeholder="🔍 Search by number, branch, requester, category..."
			/>
		</div>
		<button class="btn-refresh" on:click={loadRequisitions}>🔄 Refresh</button>
	</div>

	<!-- Requisitions Table -->
	<div class="content">
		{#if loading}
			<div class="loading">
				<div class="spinner"></div>
				<p>Loading requisitions...</p>
			</div>
		{:else if filteredRequisitions.length === 0}
			<div class="empty-state">
				<div class="empty-icon">�</div>
				<h3>No Requisitions Found</h3>
				<p>There are no requisitions matching your filters.</p>
			</div>
		{:else}
			<div class="table-wrapper">
				<table class="requisitions-table">
					<thead>
						<tr>
							<th>Requisition #</th>
							<th>Branch</th>
							<th>Generated By</th>
							<th>Requester</th>
							<th>Category</th>
							<th>Amount</th>
							<th>Payment Type</th>
							<th>Status</th>
							<th>Date</th>
							<th>Actions</th>
						</tr>
					</thead>
					<tbody>
						{#each filteredRequisitions as req}
							<tr>
								<td class="req-number">{req.requisition_number}</td>
								<td>{req.branch_name}</td>
								<td>
									<div class="generated-by-info">
										<div class="generated-by-name">👤 {req.created_by_username || 'Unknown'}</div>
									</div>
								</td>
								<td>
									<div class="requester-info">
										<div class="requester-name">{req.requester_name}</div>
										<div class="requester-id">ID: {req.requester_id}</div>
									</div>
								</td>
								<td>
									<div class="category-info">
										<div>{req.expense_category_name_en}</div>
										<div class="category-ar">{req.expense_category_name_ar}</div>
									</div>
								</td>
								<td class="amount">{formatCurrency(req.amount)}</td>
								<td class="payment-type">{req.payment_category.replace(/_/g, ' ')}</td>
								<td>
									<span class="status-badge {getStatusClass(req.status)}">
										{req.status.toUpperCase()}
									</span>
								</td>
								<td class="date">{formatDate(req.created_at)}</td>
								<td>
									<button class="btn-view" on:click={() => openDetail(req)}>
										👁️ View
									</button>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	</div>
</div>

<!-- Detail Modal -->
{#if showDetailModal && selectedRequisition}
	<div class="modal-overlay" on:click={closeDetail}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2>📄 Requisition Details</h2>
				<button class="modal-close" on:click={closeDetail}>×</button>
			</div>

			<div class="modal-body">
				<div class="detail-grid">
					<div class="detail-item">
						<label>Requisition Number</label>
						<div class="detail-value">{selectedRequisition.requisition_number}</div>
					</div>

					<div class="detail-item">
						<label>Status</label>
						<span class="status-badge {getStatusClass(selectedRequisition.status)}">
							{selectedRequisition.status.toUpperCase()}
						</span>
					</div>

					<div class="detail-item">
						<label>Branch</label>
						<div class="detail-value">{selectedRequisition.branch_name}</div>
					</div>

					<div class="detail-item">
						<label>Approver</label>
						<div class="detail-value">{selectedRequisition.approver_name || 'Not Assigned'}</div>
					</div>

					<div class="detail-item">
						<label>Category</label>
						<div class="detail-value">
							{selectedRequisition.expense_category_name_en}
							<br>
							<span class="category-ar">{selectedRequisition.expense_category_name_ar}</span>
						</div>
					</div>

					<div class="detail-item">
						<label>Requester</label>
						<div class="detail-value">
							{selectedRequisition.requester_name}
							<br>
							<small>ID: {selectedRequisition.requester_id}</small>
							<br>
							<small>Contact: {selectedRequisition.requester_contact}</small>
						</div>
					</div>

					<div class="detail-item">
						<label>Amount</label>
						<div class="detail-value amount-large">{formatCurrency(selectedRequisition.amount)}</div>
					</div>

					<div class="detail-item">
						<label>VAT Applicable</label>
						<div class="detail-value">{selectedRequisition.vat_applicable ? 'Yes' : 'No'}</div>
					</div>

					<div class="detail-item">
						<label>Payment Category</label>
						<div class="detail-value">{selectedRequisition.payment_category.replace(/_/g, ' ')}</div>
					</div>

					{#if selectedRequisition.credit_period}
						<div class="detail-item">
							<label>Credit Period</label>
							<div class="detail-value">{selectedRequisition.credit_period} days</div>
						</div>
					{/if}

					{#if selectedRequisition.bank_name}
						<div class="detail-item">
							<label>Bank Name</label>
							<div class="detail-value">{selectedRequisition.bank_name}</div>
						</div>
					{/if}

					{#if selectedRequisition.iban}
						<div class="detail-item">
							<label>IBAN</label>
							<div class="detail-value">{selectedRequisition.iban}</div>
						</div>
					{/if}

					{#if selectedRequisition.description}
						<div class="detail-item full-width">
							<label>Description</label>
							<div class="detail-value description">{selectedRequisition.description}</div>
						</div>
					{/if}

					{#if selectedRequisition.image_url}
						<div class="detail-item full-width">
							<label>Attachment</label>
							<div class="detail-value">
								<img src={selectedRequisition.image_url} alt="Requisition" class="attachment-image" />
							</div>
						</div>
					{/if}

					<div class="detail-item">
						<label>Created Date</label>
						<div class="detail-value">{formatDate(selectedRequisition.created_at)}</div>
					</div>

					<div class="detail-item">
						<label>Created By</label>
						<div class="detail-value">{selectedRequisition.created_by_username || 'Unknown'}</div>
					</div>
				</div>
			</div>

			<div class="modal-footer">
				{#if selectedRequisition.status === 'pending'}
					{#if !userCanApprove}
						<div class="permission-notice">
							ℹ️ You do not have permission to approve or reject requisitions.
							<br><small>Please contact your administrator for approval permissions.</small>
						</div>
					{/if}
					<button
						class="btn-approve"
						on:click={() => approveRequisition(selectedRequisition.id)}
						disabled={isProcessing || !userCanApprove}
						title={!userCanApprove ? 'You need approval permissions to approve requisitions' : 'Approve this requisition'}
					>
						{isProcessing ? '⏳ Processing...' : '✅ Approve'}
					</button>
					<button
						class="btn-reject"
						on:click={() => rejectRequisition(selectedRequisition.id)}
						disabled={isProcessing || !userCanApprove}
						title={!userCanApprove ? 'You need approval permissions to reject requisitions' : 'Reject this requisition'}
					>
						{isProcessing ? '⏳ Processing...' : '❌ Reject'}
					</button>
				{:else}
					<div class="status-info">
						This requisition has been {selectedRequisition.status}
					</div>
				{/if}
				<button class="btn-close" on:click={closeDetail}>Close</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.approval-center {
		padding: 2rem;
		background: #f8fafc;
		height: 100%;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		gap: 1.5rem;
	}

	.header {
		text-align: center;
	}

	.title {
		font-size: 2rem;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 0.5rem;
	}

	.subtitle {
		color: #64748b;
		font-size: 1rem;
		margin: 0;
	}

	/* Stats Grid */
	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1rem;
	}

	.stat-card {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		display: flex;
		align-items: center;
		gap: 1rem;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
		transition: transform 0.2s, box-shadow 0.2s;
	}

	.stat-card.clickable {
		cursor: pointer;
		user-select: none;
	}

	.stat-card.clickable:hover {
		transform: translateY(-4px);
		box-shadow: 0 6px 12px rgba(0, 0, 0, 0.15);
	}

	.stat-card.clickable:active {
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
	}

	.stat-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
	}

	.stat-icon {
		font-size: 2.5rem;
		min-width: 60px;
		text-align: center;
	}

	.stat-content {
		flex: 1;
	}

	.stat-value {
		font-size: 2rem;
		font-weight: 700;
		margin-bottom: 0.25rem;
	}

	.stat-label {
		color: #64748b;
		font-size: 0.875rem;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.stat-card.pending .stat-value {
		color: #f59e0b;
	}

	.stat-card.approved .stat-value {
		color: #10b981;
	}

	.stat-card.rejected .stat-value {
		color: #ef4444;
	}

	.stat-card.total .stat-value {
		color: #3b82f6;
	}

	/* Filters */
	.filters {
		display: flex;
		gap: 1rem;
		align-items: center;
		background: white;
		padding: 1rem;
		border-radius: 12px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.filter-group {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.filter-group.search {
		flex: 1;
	}

	.filter-group label {
		font-weight: 600;
		color: #475569;
		white-space: nowrap;
	}

	.filter-group select,
	.filter-group input {
		padding: 0.5rem;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		font-size: 0.875rem;
	}

	.filter-group.search input {
		width: 100%;
	}

	.btn-refresh {
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		transition: background 0.2s;
	}

	.btn-refresh:hover {
		background: #2563eb;
	}

	/* Content */
	.content {
		flex: 1;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		padding: 1.5rem;
		overflow: auto;
	}

	.loading,
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		color: #64748b;
	}

	.spinner {
		width: 50px;
		height: 50px;
		border: 4px solid #e2e8f0;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.empty-icon {
		font-size: 4rem;
		margin-bottom: 1rem;
	}

	.empty-state h3 {
		color: #1e293b;
		margin-bottom: 0.5rem;
	}

	/* Table */
	.table-wrapper {
		overflow-x: auto;
	}

	.requisitions-table {
		width: 100%;
		border-collapse: collapse;
	}

	.requisitions-table th,
	.requisitions-table td {
		padding: 1rem;
		text-align: left;
		border-bottom: 1px solid #e2e8f0;
	}

	.requisitions-table th {
		background: #f8fafc;
		font-weight: 600;
		color: #475569;
		text-transform: uppercase;
		font-size: 0.75rem;
		letter-spacing: 0.5px;
	}

	.requisitions-table tbody tr:hover {
		background: #f8fafc;
	}

	.req-number {
		font-weight: 600;
		color: #3b82f6;
	}

	.generated-by-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.generated-by-name {
		font-weight: 600;
		color: #6366f1;
		font-size: 0.875rem;
	}

	.requester-info,
	.category-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.requester-name {
		font-weight: 600;
	}

	.requester-id {
		font-size: 0.75rem;
		color: #64748b;
	}

	.category-ar {
		font-size: 0.875rem;
		color: #64748b;
		direction: rtl;
	}

	.amount {
		font-weight: 700;
		color: #10b981;
	}

	.payment-type {
		text-transform: capitalize;
		font-size: 0.875rem;
	}

	.date {
		font-size: 0.875rem;
		color: #64748b;
	}

	.status-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
	}

	.status-pending {
		background: #fef3c7;
		color: #92400e;
	}

	.status-approved {
		background: #d1fae5;
		color: #065f46;
	}

	.status-rejected {
		background: #fee2e2;
		color: #991b1b;
	}

	.btn-view {
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 600;
		transition: background 0.2s;
	}

	.btn-view:hover {
		background: #2563eb;
	}

	/* Modal */
	.modal-overlay {
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
		padding: 2rem;
	}

	.modal-content {
		background: white;
		border-radius: 16px;
		max-width: 900px;
		width: 100%;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 1px solid #e2e8f0;
	}

	.modal-header h2 {
		margin: 0;
		color: #1e293b;
	}

	.modal-close {
		background: none;
		border: none;
		font-size: 2rem;
		cursor: pointer;
		color: #64748b;
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 8px;
		transition: background 0.2s;
	}

	.modal-close:hover {
		background: #f1f5f9;
	}

	.modal-body {
		padding: 1.5rem;
		overflow-y: auto;
		flex: 1;
	}

	.detail-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1.5rem;
	}

	.detail-item {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.detail-item.full-width {
		grid-column: 1 / -1;
	}

	.detail-item label {
		font-weight: 600;
		color: #475569;
		font-size: 0.875rem;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.detail-value {
		color: #1e293b;
		font-size: 1rem;
	}

	.detail-value.amount-large {
		font-size: 1.5rem;
		font-weight: 700;
		color: #10b981;
	}

	.detail-value.description {
		padding: 1rem;
		background: #f8fafc;
		border-radius: 8px;
		white-space: pre-wrap;
	}

	.attachment-image {
		max-width: 100%;
		border-radius: 8px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
		margin-top: 0.5rem;
	}

	.modal-footer {
		display: flex;
		gap: 1rem;
		padding: 1.5rem;
		border-top: 1px solid #e2e8f0;
		justify-content: flex-end;
		flex-wrap: wrap;
	}

	.permission-notice {
		flex: 1 0 100%;
		padding: 0.75rem 1rem;
		background: #fef3c7;
		border: 1px solid #fbbf24;
		border-radius: 8px;
		color: #92400e;
		font-size: 0.875rem;
		text-align: center;
		margin-bottom: 0.5rem;
	}

	.permission-notice small {
		font-size: 0.75rem;
		color: #b45309;
	}

	.btn-approve {
		padding: 0.75rem 1.5rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		transition: background 0.2s;
	}

	.btn-approve:hover:not(:disabled) {
		background: #059669;
	}

	.btn-reject {
		padding: 0.75rem 1.5rem;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		transition: background 0.2s;
	}

	.btn-reject:hover:not(:disabled) {
		background: #dc2626;
	}

	.btn-close {
		padding: 0.75rem 1.5rem;
		background: #64748b;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		transition: background 0.2s;
	}

	.btn-close:hover {
		background: #475569;
	}

	.btn-approve:disabled,
	.btn-reject:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.status-info {
		flex: 1;
		padding: 0.75rem;
		background: #f1f5f9;
		border-radius: 8px;
		text-align: center;
		font-weight: 600;
		color: #475569;
	}
</style>
