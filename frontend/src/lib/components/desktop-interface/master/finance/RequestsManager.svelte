<script>
	// Requests Manager Component - Display all available requests
	import { onMount } from 'svelte';
	import { supabaseAdmin } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationService } from '$lib/utils/notificationManagement';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import RequestClosureManager from '$lib/components/desktop-interface/master/finance/RequestClosureManager.svelte';

	let allRequests = [];
	let filteredRequests = [];
	let loading = true;
	let searchQuery = '';
	let selectedStatus = 'all';
	let selectedRequest = null;
	let showDetailModal = false;
	let isProcessing = false;

	// Stats
	let stats = {
		total: 0,
		active: 0,
		deactivated: 0,
		pending: 0,
		approved: 0,
		rejected: 0,
		closed: 0
	};

	onMount(() => {
		loadAllRequests();
	});

	async function loadAllRequests() {
		try {
			loading = true;

		// Check if user is logged in
		if (!$currentUser?.id) {
			console.error('User not logged in');
			loading = false;
			return;
		}			console.log('🔍 Loading all requisitions for user:', $currentUser.username);

			// Load all requisitions (data is already denormalized)
			const { data: requisitionsData, error: reqError } = await supabaseAdmin
				.from('expense_requisitions')
				.select('*')
				.order('created_at', { ascending: false });

			if (reqError) {
				console.error('❌ Error loading requisitions:', reqError);
				throw reqError;
			}

			// Fetch usernames for all unique created_by IDs
			let userMap = {};
			if (requisitionsData && requisitionsData.length > 0) {
				const userIds = [...new Set(requisitionsData.map(r => r.created_by).filter(Boolean))];
				
				if (userIds.length > 0) {
					const { data: usersData } = await supabaseAdmin
						.from('users')
						.select('id, username')
						.in('id', userIds);
					
					// Create a map of user IDs to usernames
					if (usersData) {
						usersData.forEach(user => {
							userMap[user.id] = user.username;
						});
					}
				}
			}

			// Map requisitions to normalized structure
			allRequests = (requisitionsData || []).map(req => ({
				...req,
				request_type: 'requisition',
				request_id: req.requisition_number,
				request_date: req.created_at,
				creator_name: userMap[req.created_by] || req.created_by || 'Unknown',
				approver_name: req.approver_name || 'Not Assigned',
				branch_name: req.branch_name || 'N/A',
				category_name_en: req.expense_category_name_en || 'N/A',
				category_name_ar: req.expense_category_name_ar || 'غير متوفر',
				requester_name: req.requester_name || 'N/A',
				requester_id_display: req.requester_id || 'N/A',
				is_active: req.is_active !== false // Default to true if not set
			}));

			// Sort: Active records first, then by created_at
			allRequests.sort((a, b) => {
				if (a.is_active === b.is_active) {
					return new Date(b.created_at) - new Date(a.created_at);
				}
				return a.is_active ? -1 : 1;
			});
			
		// Calculate stats
		stats.total = allRequests.length;
		stats.active = allRequests.filter(r => r.is_active).length;
		stats.deactivated = allRequests.filter(r => !r.is_active).length;
		stats.pending = allRequests.filter(r => r.status === 'pending').length;
		stats.approved = allRequests.filter(r => r.status === 'approved').length;
		stats.rejected = allRequests.filter(r => r.status === 'rejected').length;
		stats.closed = allRequests.filter(r => r.status === 'closed').length;

		console.log('✅ Loaded requisitions:', stats);			// Initial filter
			filterRequests();

		} catch (err) {
			console.error('❌ Error loading requests:', err);
			alert('Error loading requests: ' + err.message);
		} finally {
			loading = false;
		}
	}

	function filterRequests() {
		let filtered = allRequests;

		// Filter by status (only active requisitions in status filters)
		if (selectedStatus !== 'all') {
			filtered = filtered.filter(req => req.status === selectedStatus && req.is_active);
		}

		// Filter by search query (only active requisitions in search)
		if (searchQuery.trim()) {
			const query = searchQuery.toLowerCase();
			filtered = filtered.filter(req => {
				return req.is_active && (
					req.request_id?.toLowerCase().includes(query) ||
					req.branch_name?.toLowerCase().includes(query) ||
					req.creator_name?.toLowerCase().includes(query) ||
					req.approver_name?.toLowerCase().includes(query) ||
					req.category_name_en?.toLowerCase().includes(query) ||
					req.requester_name?.toLowerCase().includes(query) ||
					req.description?.toLowerCase().includes(query)
				);
			});
		}

		// Sort: Active records first, then by date
		filtered.sort((a, b) => {
			if (a.is_active === b.is_active) {
				return new Date(b.created_at) - new Date(a.created_at);
			}
			return a.is_active ? -1 : 1;
		});

		filteredRequests = filtered;
	}

	function handleStatusFilter(status) {
		selectedStatus = status;
		filterRequests();
	}

	function handleSearch() {
		filterRequests();
	}

	async function toggleActiveStatus(requisition) {
		if (isProcessing) return;

		const newStatus = !requisition.is_active;
		const action = newStatus ? 'activate' : 'deactivate';
		
		if (!confirm(`Are you sure you want to ${action} requisition ${requisition.request_id}?`)) {
			return;
		}

		try {
			isProcessing = true;

			const { error } = await supabaseAdmin
				.from('expense_requisitions')
				.update({ 
					is_active: newStatus,
					updated_at: new Date().toISOString()
				})
				.eq('id', requisition.id);

			if (error) {
				console.error(`❌ Error ${action}ing requisition:`, error);
				alert(`Failed to ${action} requisition: ${error.message}`);
				return;
			}

			// Update local state
			requisition.is_active = newStatus;
			
			// Recalculate stats
			stats.active = allRequests.filter(r => r.is_active).length;
			stats.deactivated = allRequests.filter(r => !r.is_active).length;
			stats.pending = allRequests.filter(r => r.status === 'pending' && r.is_active).length;
			stats.approved = allRequests.filter(r => r.status === 'approved' && r.is_active).length;
			stats.rejected = allRequests.filter(r => r.status === 'rejected' && r.is_active).length;

			// Re-filter and sort
			filterRequests();

			alert(`✅ Requisition ${requisition.request_id} has been ${action}d successfully`);
		} catch (err) {
			console.error(`❌ Error ${action}ing requisition:`, err);
			alert(`Error: ${err.message}`);
		} finally {
			isProcessing = false;
		}
	}

	function formatCurrency(amount) {
		return new Intl.NumberFormat('en-US', {
			style: 'currency',
			currency: 'SAR',
			minimumFractionDigits: 2
		}).format(amount || 0);
	}

	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		return new Date(dateString).toLocaleDateString('en-GB', {
			day: '2-digit',
			month: 'short',
			year: 'numeric'
		});
	}

	function getStatusClass(status) {
		switch (status?.toLowerCase()) {
			case 'pending': return 'status-pending';
			case 'approved': return 'status-approved';
			case 'rejected': return 'status-rejected';
			default: return '';
		}
	}

	function getTypeLabel(type) {
		return type === 'requisition' ? 'Requisition' : 'Payment Schedule';
	}

	function openDetail(request) {
		selectedRequest = request;
		showDetailModal = true;
	}

	function closeDetailModal() {
		showDetailModal = false;
		selectedRequest = null;
	}

	function exportToCSV() {
		const headers = ['Requisition Number', 'Branch', 'Creator', 'Approver', 'Category', 'Requester', 'Amount', 'Status', 'Date'];
		const rows = filteredRequests.map(req => [
			req.request_id,
			req.branch_name,
			req.creator_name,
			req.approver_name,
			req.category_name_en,
			req.requester_name,
			req.amount || 0,
			req.status,
			formatDate(req.request_date)
		]);

		const csvContent = [
			headers.join(','),
			...rows.map(row => row.map(cell => `"${cell}"`).join(','))
		].join('\n');

		const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
		const link = document.createElement('a');
		link.href = URL.createObjectURL(blob);
		link.download = `requisitions_export_${new Date().toISOString().split('T')[0]}.csv`;
		link.click();
	}
</script>

<div class="requests-manager">
	<div class="header">
		<div class="title-section">
			<h1 class="title">📋 Requests Manager</h1>
			<p class="subtitle">View and manage all expense requisitions</p>
		</div>
		<button class="btn-export" on:click={exportToCSV} disabled={filteredRequests.length === 0}>
			📥 Export CSV
		</button>
	</div>

	{#if loading}
		<div class="loading-container">
			<div class="loading-spinner"></div>
			<p>Loading requests...</p>
		</div>
	{:else}
		<!-- Stats Cards -->
		<div class="stats-grid">
			<button class="stat-card total clickable" on:click={() => handleStatusFilter('all')}>
				<div class="stat-icon">📊</div>
				<div class="stat-content">
					<div class="stat-value">{stats.total}</div>
					<div class="stat-label">Total Requisitions</div>
				</div>
			</button>

			<button class="stat-card active clickable" on:click={() => handleStatusFilter('all')}>
				<div class="stat-icon">✔️</div>
				<div class="stat-content">
					<div class="stat-value">{stats.active}</div>
					<div class="stat-label">Active</div>
				</div>
			</button>

			<button class="stat-card deactivated clickable" on:click={() => handleStatusFilter('all')}>
				<div class="stat-icon">🚫</div>
				<div class="stat-content">
					<div class="stat-value">{stats.deactivated}</div>
					<div class="stat-label">Deactivated</div>
				</div>
			</button>

			<button class="stat-card pending clickable" on:click={() => handleStatusFilter('pending')}>
				<div class="stat-icon">⏳</div>
				<div class="stat-content">
					<div class="stat-value">{stats.pending}</div>
					<div class="stat-label">Pending</div>
				</div>
			</button>

			<button class="stat-card approved clickable" on:click={() => handleStatusFilter('approved')}>
				<div class="stat-icon">✅</div>
				<div class="stat-content">
					<div class="stat-value">{stats.approved}</div>
					<div class="stat-label">Approved</div>
				</div>
			</button>

			<button class="stat-card rejected clickable" on:click={() => handleStatusFilter('rejected')}>
				<div class="stat-icon">❌</div>
				<div class="stat-content">
					<div class="stat-value">{stats.rejected}</div>
				</div>
			</button>
		</div>

		<!-- Filters and Search -->
		<div class="filters-section">
			<div class="filter-group">
				<span class="filter-label">Status:</span>
				<select bind:value={selectedStatus} on:change={handleSearch} aria-label="Filter by status">
					<option value="all">All Statuses</option>
					<option value="pending">Pending</option>
					<option value="approved">Approved</option>
					<option value="rejected">Rejected</option>
				</select>
			</div>

			<div class="search-group">
				<input 
					type="text" 
					placeholder="🔍 Search requisitions..." 
					bind:value={searchQuery}
					on:input={handleSearch}
					aria-label="Search requisitions"
				/>
			</div>

			<div class="filter-count">
				Showing {filteredRequests.length} of {stats.total} requisitions
			</div>
		</div>

		<!-- Requests Table -->
		{#if filteredRequests.length === 0}
			<div class="empty-state">
				<div class="empty-icon">📭</div>
				<h3>No Requisitions Found</h3>
				<p>No requisitions match your current filters.</p>
			</div>
		{:else}
			<div class="table-wrapper">
				<table class="requests-table">
					<thead>
						<tr>
							<th>Requisition #</th>
							<th>Branch</th>
							<th>Creator</th>
							<th>Approver</th>
							<th>Category</th>
							<th>Requester</th>
							<th>Amount</th>
							<th>Remaining Balance</th>
							<th>Approval Status</th>
							<th>Date</th>
							<th>Actions</th>
						</tr>
					</thead>
					<tbody>
						{#each filteredRequests as req}
							<tr on:click={() => openDetail(req)} class="clickable-row {!req.is_active ? 'deactivated-row' : ''}">
								<td class="req-id">
									{#if !req.is_active}
										<span class="inactive-indicator">🚫</span>
									{/if}
									{req.request_id}
								</td>
								<td>{req.branch_name}</td>
								<td>{req.creator_name}</td>
								<td>{req.approver_name}</td>
								<td>
									<div class="category-info">
										<div>{req.category_name_en}</div>
										<div class="category-ar">{req.category_name_ar}</div>
									</div>
								</td>
								<td>{req.requester_name}</td>
								<td class="amount">{formatCurrency(req.amount)}</td>
								<td class="amount remaining-balance" class:zero-balance={req.remaining_balance === 0}>
									{formatCurrency(req.remaining_balance || 0)}
								</td>
								<td>
									<span class="approval-badge" class:approved={req.status === 'approved'} class:pending={req.status === 'pending'} class:rejected={req.status === 'rejected'}>
										{#if req.status === 'approved'}
											✅ Approved
										{:else if req.status === 'pending'}
											⏳ Pending
										{:else if req.status === 'rejected'}
											❌ Rejected
										{:else if req.status === 'closed'}
											🔒 Closed
										{:else}
											{req.status?.toUpperCase()}
										{/if}
									</span>
								</td>
								<td>{formatDate(req.request_date)}</td>
								<td class="actions-cell">
									<button class="btn-view" on:click|stopPropagation={() => openDetail(req)}>
										👁️ View
									</button>
									{#if req.status === 'closed' || !req.is_active}
										<button
											class="btn-closed"
											disabled
										>
											🔒 Closed
										</button>
									{:else if req.status === 'approved' && req.is_active}
										{#if req.remaining_balance !== null && req.remaining_balance !== undefined && req.remaining_balance <= 0}
											<button
												class="btn-closed"
												disabled
											>
												🔒 Closed
											</button>
										{:else}
											<button
												class="btn-close-request"
												on:click|stopPropagation={() => openWindow({
													id: `request-closure-${req.id}`,
													title: `🔒 Close Request: ${req.requisition_number}`,
													component: RequestClosureManager,
													props: {
														preSelectedRequestId: req.id,
														windowId: `request-closure-${req.id}`
													},
													icon: '🔒',
													size: { width: 1400, height: 800 },
													resizable: true,
													maximizable: true
												})}
											>
												✅ Close Request
											</button>
										{/if}
									{/if}
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	{/if}
</div>

<!-- Detail Modal -->
{#if showDetailModal && selectedRequest}
	<div class="modal-overlay" on:click={closeDetailModal} role="button" tabindex="0" on:keydown={(e) => e.key === 'Escape' && closeDetailModal()}>
		<div class="modal-content" on:click|stopPropagation on:keydown={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">
			<div class="modal-header">
				<h2>Requisition Details</h2>
				<button class="btn-close" on:click={closeDetailModal}>×</button>
			</div>
			<div class="modal-body">
				<div class="detail-grid">
					<div class="detail-item">
						<strong class="detail-label">Requisition Number:</strong>
						<span>{selectedRequest.request_id}</span>
					</div>
					<div class="detail-item">
						<strong class="detail-label">Branch:</strong>
						<span>{selectedRequest.branch_name}</span>
					</div>
					<div class="detail-item">
						<strong class="detail-label">Creator:</strong>
						<span>{selectedRequest.creator_name}</span>
					</div>
					<div class="detail-item">
						<strong class="detail-label">Approver:</strong>
						<span>{selectedRequest.approver_name}</span>
					</div>
					<div class="detail-item">
						<strong class="detail-label">Category:</strong>
						<span>{selectedRequest.category_name_en} / {selectedRequest.category_name_ar}</span>
					</div>
					<div class="detail-item">
						<strong class="detail-label">Amount:</strong>
						<span class="amount-large">{formatCurrency(selectedRequest.amount)}</span>
					</div>
					<div class="detail-item">
						<strong class="detail-label">Status:</strong>
						<span class="status-badge {getStatusClass(selectedRequest.status)}">
							{selectedRequest.status?.toUpperCase()}
						</span>
					</div>
					<div class="detail-item">
						<strong class="detail-label">Created Date:</strong>
						<span>{formatDate(selectedRequest.request_date)}</span>
					</div>
					{#if selectedRequest.requester_name}
						<div class="detail-item">
							<strong class="detail-label">Requester:</strong>
							<span>{selectedRequest.requester_name} ({selectedRequest.requester_id_display})</span>
						</div>
					{/if}
					{#if selectedRequest.due_date}
						<div class="detail-item">
							<strong class="detail-label">Due Date:</strong>
							<span>{formatDate(selectedRequest.due_date)}</span>
						</div>
					{/if}
					{#if selectedRequest.payment_category}
						<div class="detail-item">
							<strong class="detail-label">Payment Type:</strong>
							<span>{selectedRequest.payment_category.replace(/_/g, ' ')}</span>
						</div>
					{/if}
					{#if selectedRequest.description}
						<div class="detail-item full-width">
							<strong class="detail-label">Description:</strong>
							<span>{selectedRequest.description}</span>
						</div>
					{/if}
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.requests-manager {
		padding: 24px;
		background: #f8fafc;
		height: 100%;
		overflow-y: auto;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 24px;
		padding-bottom: 16px;
		border-bottom: 2px solid #e5e7eb;
	}

	.title-section {
		flex: 1;
	}

	.title {
		font-size: 2rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0 0 8px 0;
	}

	.subtitle {
		color: #64748b;
		font-size: 1rem;
		margin: 0;
	}

	.btn-export {
		background: #10b981;
		color: white;
		border: none;
		padding: 12px 24px;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-export:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-2px);
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
	}

	.btn-export:disabled {
		background: #d1d5db;
		cursor: not-allowed;
	}

	.loading-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 64px 0;
		color: #64748b;
	}

	.loading-spinner {
		width: 48px;
		height: 48px;
		border: 4px solid #e5e7eb;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 16px;
		margin-bottom: 24px;
	}

	@media (max-width: 1024px) {
		.stats-grid {
			grid-template-columns: repeat(2, 1fr);
		}
	}

	@media (max-width: 640px) {
		.stats-grid {
			grid-template-columns: 1fr;
		}
	}

	.stat-card {
		background: white;
		border-radius: 12px;
		padding: 20px;
		display: flex;
		align-items: center;
		gap: 16px;
		box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
		transition: all 0.2s;
		border: none;
		width: 100%;
		text-align: left;
	}

	.stat-card.clickable {
		cursor: pointer;
	}

	.stat-card.clickable:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
	}

	.stat-card.total { border-left: 4px solid #3b82f6; }
	.stat-card.active { border-left: 4px solid #10b981; }
	.stat-card.deactivated { border-left: 4px solid #6b7280; }
	.stat-card.pending { border-left: 4px solid #f59e0b; }
	.stat-card.approved { border-left: 4px solid #10b981; }
	.stat-card.rejected { border-left: 4px solid #ef4444; }

	.stat-icon {
		font-size: 28px;
	}

	.stat-content {
		flex: 1;
	}

	.stat-value {
		font-size: 28px;
		font-weight: 700;
		color: #1e293b;
		line-height: 1;
		margin-bottom: 4px;
	}

	.stat-label {
		font-size: 13px;
		color: #64748b;
		font-weight: 500;
	}

	.filters-section {
		display: flex;
		gap: 16px;
		align-items: center;
		background: white;
		padding: 20px;
		border-radius: 12px;
		margin-bottom: 24px;
		box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
		flex-wrap: wrap;
	}

	.filter-group {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.filter-label {
		font-size: 14px;
		font-weight: 600;
		color: #475569;
	}

	.filter-group select {
		padding: 8px 16px;
		border: 1px solid #e2e8f0;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		cursor: pointer;
	}

	.search-group {
		flex: 1;
		min-width: 250px;
	}

	.search-group input {
		width: 100%;
		padding: 8px 16px;
		border: 1px solid #e2e8f0;
		border-radius: 6px;
		font-size: 14px;
	}

	.filter-count {
		font-size: 14px;
		color: #64748b;
		font-weight: 500;
		margin-left: auto;
	}

	.table-wrapper {
		background: white;
		border-radius: 12px;
		overflow: hidden;
		box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
	}

	.requests-table {
		width: 100%;
		border-collapse: collapse;
	}

	.requests-table thead {
		background: #f8fafc;
		border-bottom: 2px solid #e5e7eb;
	}

	.requests-table th {
		padding: 16px;
		text-align: left;
		font-size: 13px;
		font-weight: 600;
		color: #475569;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.requests-table td {
		padding: 16px;
		border-bottom: 1px solid #f1f5f9;
		font-size: 14px;
		color: #334155;
	}

	.clickable-row {
		cursor: pointer;
		transition: background 0.15s;
	}

	.clickable-row:hover {
		background: #f8fafc;
	}

	.deactivated-row {
		background: #f9fafb;
		opacity: 0.7;
	}

	.deactivated-row td {
		color: #6b7280;
	}

	.inactive-indicator {
		display: inline-block;
		margin-right: 4px;
		font-size: 14px;
	}

	.req-id {
		font-weight: 600;
		color: #3b82f6;
	}

	.type-badge {
		display: inline-block;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
	}

	.type-badge.requisition {
		background: #dbeafe;
		color: #1e40af;
	}

	.type-badge.payment_schedule {
		background: #e0e7ff;
		color: #4338ca;
	}

	.category-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.category-ar {
		font-size: 12px;
		color: #94a3b8;
	}

	.amount {
		font-weight: 600;
		color: #059669;
	}

	.remaining-balance {
		font-weight: 700;
		color: #0891b2;
		background: linear-gradient(135deg, #e0f2fe 0%, #bae6fd 100%);
		padding: 8px 12px;
		border-radius: 6px;
		text-align: center;
	}

	.remaining-balance.zero-balance {
		color: #64748b;
		background: #f1f5f9;
		text-decoration: line-through;
		opacity: 0.7;
	}

	.approval-badge {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 6px 14px;
		border-radius: 16px;
		font-size: 13px;
		font-weight: 600;
		white-space: nowrap;
	}

	.approval-badge.approved {
		background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
		color: #065f46;
		border: 2px solid #10b981;
	}

	.approval-badge.pending {
		background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
		color: #92400e;
		border: 2px solid #f59e0b;
		animation: pulse 2s infinite;
	}

	.approval-badge.rejected {
		background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%);
		color: #991b1b;
		border: 2px solid #ef4444;
	}

	@keyframes pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.7; }
	}

	.status-badge {
		display: inline-block;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 11px;
		font-weight: 600;
		letter-spacing: 0.5px;
	}

	.status-badge.status-pending {
		background: #fef3c7;
		color: #92400e;
	}

	.status-badge.status-approved {
		background: #d1fae5;
		color: #065f46;
	}

	.status-badge.status-rejected {
		background: #fee2e2;
		color: #991b1b;
	}

	.btn-view {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 6px 12px;
		border-radius: 6px;
		font-size: 12px;
		cursor: pointer;
		transition: background 0.2s;
	}

	.btn-view:hover {
		background: #2563eb;
	}

	.actions-cell {
		display: flex;
		gap: 8px;
		align-items: center;
	}

	.btn-toggle {
		border: none;
		padding: 6px 12px;
		border-radius: 6px;
		font-size: 12px;
		cursor: pointer;
		transition: background 0.2s;
		font-weight: 500;
		white-space: nowrap;
	}

	.btn-deactivate {
		background: #fef3c7;
		color: #92400e;
	}

	.btn-deactivate:hover:not(:disabled) {
		background: #fde68a;
	}

	.btn-activate {
		background: #d1fae5;
		color: #065f46;
	}

	.btn-activate:hover:not(:disabled) {
		background: #a7f3d0;
	}

	.btn-toggle:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.btn-close-request {
		padding: 8px 16px;
		border: 2px solid #10b981;
		background: #d1fae5;
		color: #065f46;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		transition: all 0.2s;
		white-space: nowrap;
		font-size: 14px;
	}

	.btn-close-request:hover {
		background: #10b981;
		color: white;
		transform: translateY(-1px);
		box-shadow: 0 4px 6px rgba(16, 185, 129, 0.3);
	}

	.btn-closed {
		padding: 8px 16px;
		border: 2px solid #6b7280;
		background: #e5e7eb;
		color: #374151;
		border-radius: 8px;
		cursor: not-allowed;
		font-weight: 600;
		white-space: nowrap;
		font-size: 14px;
		opacity: 0.7;
	}

	.empty-state {
		text-align: center;
		padding: 64px 24px;
		background: white;
		border-radius: 12px;
	}

	.empty-icon {
		font-size: 64px;
		margin-bottom: 16px;
	}

	.empty-state h3 {
		font-size: 20px;
		color: #1e293b;
		margin: 0 0 8px 0;
	}

	.empty-state p {
		color: #64748b;
		margin: 0;
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
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 24px;
	}

	.modal-content {
		background: white;
		border-radius: 16px;
		max-width: 800px;
		width: 100%;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 24px;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-header h2 {
		font-size: 24px;
		font-weight: 700;
		color: #1e293b;
		margin: 0;
	}

	.btn-close {
		background: none;
		border: none;
		font-size: 32px;
		color: #94a3b8;
		cursor: pointer;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 4px;
		transition: all 0.2s;
	}

	.btn-close:hover {
		background: #f1f5f9;
		color: #1e293b;
	}

	.modal-body {
		padding: 24px;
	}

	.detail-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 20px;
	}

	.detail-item {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.detail-item.full-width {
		grid-column: 1 / -1;
	}

	.detail-label {
		font-size: 12px;
		font-weight: 600;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.detail-item span {
		font-size: 15px;
		color: #1e293b;
		font-weight: 500;
	}

	.amount-large {
		font-size: 20px !important;
		font-weight: 700 !important;
		color: #059669 !important;
	}

	/* Fullscreen Modal for Request Closure */
	.modal-overlay-fullscreen {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.7);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 2000;
		padding: 20px;
	}

	.modal-content-fullscreen {
		background: white;
		border-radius: 12px;
		width: 95vw;
		max-width: 1600px;
		height: 90vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
	}

	.modal-header-fullscreen {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem 2rem;
		border-bottom: 2px solid #e5e7eb;
		background: #f9fafb;
	}

	.modal-header-fullscreen h2 {
		font-size: 1.5rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0;
	}

	.modal-body-fullscreen {
		flex: 1;
		overflow-y: auto;
		padding: 0;
	}
</style>
