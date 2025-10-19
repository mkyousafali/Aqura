<script>
	import { onMount } from 'svelte';
	import { supabase, supabaseAdmin } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
	import WarningDetailsModal from './WarningDetailsModal.svelte';

	let warnings = [];
	let loading = true;
	let error = null;
	let searchTerm = '';
	let selectedStatus = 'all';
	let selectedBranch = 'all';
	let branches = [];

	// Pagination
	let currentPage = 1;
	let itemsPerPage = 10;
	let totalItems = 0;

	onMount(() => {
		loadBranches();
		loadWarnings();
	});

	async function loadBranches() {
		try {
			const { data, error: branchError } = await supabase
				.from('branches')
				.select('id, name_en')
				.order('name_en');

			if (branchError) throw branchError;
			branches = data || [];
			console.log('🏢 Available branches:', branches);
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	async function loadWarnings() {
		try {
			loading = true;
			error = null;
			console.log('🔍 Loading warnings for WarningListView...');

			// Try regular client first - Fix the relationship: warnings -> hr_employees -> branches
			let query = supabase
				.from('employee_warnings')
				.select(`
					*,
					users!user_id(username),
					hr_employees(name, employee_id, branch_id, branches(name_en))
				`)
				.or('is_deleted.is.null,is_deleted.eq.false');

			// If that fails, try admin client
			let useAdminClient = false;

			// Apply filters
			if (selectedStatus !== 'all') {
				query = query.eq('warning_status', selectedStatus);
			}

			if (selectedBranch !== 'all') {
				query = query.eq('hr_employees.branch_id', selectedBranch);
			}

			if (searchTerm) {
				query = query.or(`warning_text.ilike.%${searchTerm}%,username.ilike.%${searchTerm}%`);
			}

			// Get total count for pagination - Try regular client first
			let countQuery = supabase
				.from('employee_warnings')
				.select('id', { count: 'exact', head: true })
				.or('is_deleted.is.null,is_deleted.eq.false');
				
			// Apply same filters for count
			if (selectedStatus !== 'all') {
				countQuery = countQuery.eq('warning_status', selectedStatus);
			}
			if (selectedBranch !== 'all') {
				countQuery = countQuery.eq('hr_employees.branch_id', selectedBranch);
			}
			if (searchTerm) {
				countQuery = countQuery.or(`warning_text.ilike.%${searchTerm}%,username.ilike.%${searchTerm}%`);
			}
			
			const { count } = await countQuery;
			totalItems = count || 0;

			// Get paginated data
			let { data, error: queryError } = await query
				.order('issued_at', { ascending: false })
				.range((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage - 1);

			// If regular client fails, try admin client
			if (queryError || !data || data.length === 0) {
				console.log('🔄 Regular client failed for warnings list, trying admin client...');
				const adminQuery = supabaseAdmin
					.from('employee_warnings')
					.select(`
						*,
						users!user_id(username),
						hr_employees(name, employee_id, branch_id, branches(name_en))
					`)
					.or('is_deleted.is.null,is_deleted.eq.false');

				// Apply same filters for admin query
				if (selectedStatus !== 'all') {
					adminQuery.eq('warning_status', selectedStatus);
				}
				if (selectedBranch !== 'all') {
					adminQuery.eq('hr_employees.branch_id', selectedBranch);
				}
				if (searchTerm) {
					adminQuery.or(`warning_text.ilike.%${searchTerm}%,username.ilike.%${searchTerm}%`);
				}

				const adminResult = await adminQuery
					.order('issued_at', { ascending: false })
					.range((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage - 1);

				data = adminResult.data;
				queryError = adminResult.error;
				useAdminClient = true;
			}

			if (queryError) throw queryError;
			warnings = data || [];
			console.log('📊 Loaded warnings for list view:', warnings.length, 'records', useAdminClient ? '(using admin client)' : '(using regular client)');
			console.log('🏢 Employee and branch data sample:', warnings[0]?.hr_employees, 'from warning:', warnings[0]?.employee_id);
		} catch (err) {
			console.error('Error loading warnings:', err);
			error = err.message;
		} finally {
			loading = false;
		}
	}

	function getStatusBadge(status) {
		const statusMap = {
			active: { class: 'bg-yellow-100 text-yellow-800', label: 'Active' },
			acknowledged: { class: 'bg-blue-100 text-blue-800', label: 'Acknowledged' },
			resolved: { class: 'bg-green-100 text-green-800', label: 'Resolved' },
			escalated: { class: 'bg-red-100 text-red-800', label: 'Escalated' },
			cancelled: { class: 'bg-gray-100 text-gray-800', label: 'Cancelled' }
		};
		return statusMap[status] || statusMap.active;
	}

	function getWarningTypeBadge(type) {
		const typeMap = {
			overall_performance_no_fine: { class: 'bg-blue-100 text-blue-800', label: 'Performance' },
			overall_performance_fine_threat: { class: 'bg-orange-100 text-orange-800', label: 'Performance + Threat' },
			overall_performance_with_fine: { class: 'bg-red-100 text-red-800', label: 'Performance + Fine' }
		};
		return typeMap[type] || { class: 'bg-gray-100 text-gray-800', label: 'Unknown' };
	}

	function formatCurrency(amount, currency = '') {
		if (!amount) return '-';
		return `${parseFloat(amount).toFixed(2)}`;
	}

	function formatDate(dateString) {
		if (!dateString) return '-';
		return new Date(dateString).toLocaleDateString('en-GB');
	}

	function viewWarningDetails(warning) {
		const windowId = `warning-details-${warning.id}`;
		
		windowManager.openWindow({
			id: windowId,
			title: `Warning Details - ${warning.hr_employees?.name || warning.username}`,
			component: WarningDetailsModal,
			props: { warning },
			icon: '⚠️',
			size: { width: 800, height: 700 },
			position: { 
				x: 100 + (Math.random() * 200), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function handleSearch() {
		currentPage = 1;
		loadWarnings();
	}

	function handleStatusFilter() {
		currentPage = 1;
		loadWarnings();
	}

	function handleBranchFilter() {
		currentPage = 1;
		loadWarnings();
	}

	function changePage(page) {
		currentPage = page;
		loadWarnings();
	}

	$: totalPages = Math.ceil(totalItems / itemsPerPage);
</script>

<div class="warning-list-view">
	<!-- Header -->
	<div class="header">
		<div class="title-section">
			<h1 class="title">Warning Records</h1>
			<p class="subtitle">Manage and track all employee warnings</p>
		</div>
		<button on:click={loadWarnings} class="refresh-btn" disabled={loading}>
			<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
			</svg>
			Refresh
		</button>
	</div>

	<!-- Filters -->
	<div class="filters">
		<div class="search-box">
			<input 
				type="text" 
				placeholder="Search warnings..."
				bind:value={searchTerm}
				on:input={handleSearch}
				class="search-input"
			>
			<svg class="search-icon w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
			</svg>
		</div>

		<select bind:value={selectedStatus} on:change={handleStatusFilter} class="filter-select">
			<option value="all">All Statuses</option>
			<option value="active">Active</option>
			<option value="acknowledged">Acknowledged</option>
			<option value="resolved">Resolved</option>
			<option value="escalated">Escalated</option>
			<option value="cancelled">Cancelled</option>
		</select>

		<select bind:value={selectedBranch} on:change={handleBranchFilter} class="filter-select">
			<option value="all">All Branches</option>
			{#each branches as branch}
				<option value={branch.id}>{branch.name_en}</option>
			{/each}
		</select>
	</div>

	{#if error}
		<div class="error-message">
			Error: {error}
		</div>
	{/if}

	{#if loading}
		<div class="loading-section">
			<div class="loading-spinner"></div>
			<p>Loading warnings...</p>
		</div>
	{:else if warnings.length === 0}
		<div class="empty-state">
			<div class="empty-icon">⚠️</div>
			<h3>No warnings found</h3>
			<p>No warning records match your current filters.</p>
		</div>
	{:else}
		<!-- Warnings Table -->
		<div class="table-container">
			<table class="warnings-table">
				<thead>
					<tr>
						<th>Employee</th>
						<th>Warning Type</th>
						<th>Status</th>
						<th>Fine Amount</th>
						<th>Issued Date</th>
						<th>Branch</th>
						<th>Actions</th>
					</tr>
				</thead>
				<tbody>
					{#each warnings as warning}
						<tr>
							<td>
								<div class="employee-info">
									<div class="employee-name">
										{warning.hr_employees?.name || warning.username || 'Unknown'}
									</div>
									<div class="employee-id">
										{warning.hr_employees?.employee_id || warning.users?.username || '-'}
									</div>
								</div>
							</td>
							<td>
								<span class="badge {getWarningTypeBadge(warning.warning_type).class}">
									{getWarningTypeBadge(warning.warning_type).label}
								</span>
							</td>
							<td>
								<span class="badge {getStatusBadge(warning.warning_status).class}">
									{getStatusBadge(warning.warning_status).label}
								</span>
							</td>
							<td>
								{#if warning.has_fine}
									<span class="fine-amount">
										{formatCurrency(warning.fine_amount, warning.fine_currency)}
									</span>
									<span class="fine-status {warning.fine_status}">
										({warning.fine_status})
									</span>
								{:else}
									<span class="no-fine">No Fine</span>
								{/if}
							</td>
							<td>{formatDate(warning.issued_at)}</td>
							<td>{warning.hr_employees?.branches?.name_en || 'No Branch'}</td>
							<td>
								<button 
									class="view-btn"
									on:click={() => viewWarningDetails(warning)}
									title="View Details"
								>
									<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
									</svg>
									View
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>

		<!-- Pagination -->
		{#if totalPages > 1}
			<div class="pagination">
				<button 
					class="page-btn"
					disabled={currentPage === 1}
					on:click={() => changePage(currentPage - 1)}
				>
					Previous
				</button>
				
				{#each Array.from({length: totalPages}, (_, i) => i + 1) as page}
					<button 
						class="page-btn {page === currentPage ? 'active' : ''}"
						on:click={() => changePage(page)}
					>
						{page}
					</button>
				{/each}
				
				<button 
					class="page-btn"
					disabled={currentPage === totalPages}
					on:click={() => changePage(currentPage + 1)}
				>
					Next
				</button>
			</div>
		{/if}
	{/if}
</div>

<style>
	.warning-list-view {
		padding: 24px;
		background: white;
		height: 100%;
		overflow-y: auto;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 24px;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
	}

	.title {
		font-size: 24px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.subtitle {
		font-size: 14px;
		color: #6b7280;
		margin: 4px 0 0 0;
	}

	.refresh-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.filters {
		display: flex;
		gap: 16px;
		margin-bottom: 24px;
		flex-wrap: wrap;
	}

	.search-box {
		position: relative;
		flex: 1;
		min-width: 200px;
	}

	.search-input {
		width: 100%;
		padding: 8px 40px 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.search-icon {
		position: absolute;
		right: 12px;
		top: 50%;
		transform: translateY(-50%);
		color: #6b7280;
	}

	.filter-select {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		min-width: 150px;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 16px;
		border-radius: 8px;
		margin-bottom: 24px;
	}

	.loading-section {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 48px;
		color: #6b7280;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #e5e7eb;
		border-top: 3px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.empty-state {
		text-align: center;
		padding: 48px;
		color: #6b7280;
	}

	.empty-icon {
		font-size: 48px;
		margin-bottom: 16px;
	}

	.empty-state h3 {
		margin: 0 0 8px 0;
		color: #111827;
	}

	.empty-state p {
		margin: 0;
	}

	.table-container {
		overflow-x: auto;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
	}

	.warnings-table {
		width: 100%;
		border-collapse: collapse;
	}

	.warnings-table th {
		background: #f9fafb;
		padding: 12px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
	}

	.warnings-table td {
		padding: 12px;
		border-bottom: 1px solid #e5e7eb;
		vertical-align: top;
	}

	.warnings-table tr:hover {
		background: #f9fafb;
	}

	.employee-info {
		min-width: 120px;
	}

	.employee-name {
		font-weight: 500;
		color: #111827;
		margin-bottom: 2px;
	}

	.employee-id {
		font-size: 12px;
		color: #6b7280;
	}

	.badge {
		display: inline-block;
		padding: 4px 8px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 500;
		white-space: nowrap;
	}

	.fine-amount {
		font-weight: 600;
		color: #dc2626;
	}

	.fine-status {
		display: block;
		font-size: 12px;
		color: #6b7280;
		margin-top: 2px;
	}

	.fine-status.pending {
		color: #f59e0b;
	}

	.fine-status.paid {
		color: #10b981;
	}

	.no-fine {
		color: #6b7280;
		font-style: italic;
	}

	.view-btn {
		display: flex;
		align-items: center;
		gap: 4px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 4px;
		padding: 6px 12px;
		font-size: 12px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.view-btn:hover {
		background: #2563eb;
	}

	.pagination {
		display: flex;
		justify-content: center;
		gap: 8px;
		margin-top: 24px;
	}

	.page-btn {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		background: white;
		color: #374151;
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.page-btn:hover:not(:disabled) {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.page-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.page-btn.active {
		background: #3b82f6;
		color: white;
		border-color: #3b82f6;
	}

	@media (max-width: 768px) {
		.filters {
			flex-direction: column;
		}
		
		.search-box {
			min-width: auto;
		}
		
		.filter-select {
			min-width: auto;
		}
	}
</style>