<script>
	import { createEventDispatcher, onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	export let isOpen = false;

	const dispatch = createEventDispatcher();

	let tasks = [];
	let filteredTasks = [];
	let searchQuery = '';
	let selectedBranch = '';
	let selectedStatus = '';
	let dateFrom = '';
	let dateTo = '';

	// Filter options
	let uniqueBranches = [];
	let uniqueStatuses = [];

	// Load tasks data - First get payment transactions with task_ids, then get their completion status
	async function loadTasks() {
		
		try {
			console.log('TaskStatusDetails: Starting to load tasks...');
			
			// Step 1: Get all payment_transactions that have task_ids (exact same query as card)
			const { data: paymentTasks, error: paymentError } = await supabase
				.from('payment_transactions')
				.select('*')
				.not('task_id', 'is', null);

			console.log('TaskStatusDetails: Payment transactions query result:', { 
				data: paymentTasks, 
				error: paymentError,
				count: paymentTasks?.length || 0
			});

			if (paymentError) {
				console.error('Error loading payment transactions:', paymentError);
				return;
			}

			if (!paymentTasks || paymentTasks.length === 0) {
				tasks = [];
				uniqueBranches = [];
				uniqueStatuses = [];
				console.log('TaskStatusDetails: No payment transactions with task_ids found');
				return;
			}

			// Step 2: Get task completion data for the task_ids we found
			const taskIds = paymentTasks.map(t => t.task_id).filter(Boolean);
			console.log('TaskStatusDetails: Extracted task IDs:', taskIds);
			
			let taskCompletionsMap = {};
			if (taskIds.length > 0) {
				const { data: completions, error: completionError } = await supabase
					.from('task_completions')
					.select('*')
					.in('task_id', taskIds);

				console.log('TaskStatusDetails: Task completions query result:', { 
					data: completions, 
					error: completionError,
					count: completions?.length || 0
				});

				if (!completionError && completions) {
					// Create map of task_id to completion data
					completions.forEach(completion => {
						taskCompletionsMap[completion.task_id] = completion;
					});
				}
			}

			// Step 3: Get additional data (receiving records, branches) separately
			const receivingRecordIds = [...new Set(paymentTasks.map(t => t.receiving_record_id).filter(Boolean))];
			let receivingRecordsMap = {};
			
			if (receivingRecordIds.length > 0) {
				const { data: receivingRecords, error: receivingError } = await supabase
					.from('receiving_records')
					.select(`
						id,
						bill_number,
						erp_purchase_invoice_reference,
						created_at,
						branch_id,
						vendor_id,
						branches (
							name_en,
							name_ar
						)
					`)
					.in('id', receivingRecordIds);

				if (!receivingError && receivingRecords) {
					// Get vendor information
					const vendorIds = [...new Set(receivingRecords.map(r => r.vendor_id).filter(Boolean))];
					let vendorsMap = {};
					
					if (vendorIds.length > 0) {
						const { data: vendors, error: vendorError } = await supabase
							.from('vendors')
							.select('erp_vendor_id, vendor_name, branch_id')
							.in('erp_vendor_id', vendorIds);

						if (!vendorError && vendors) {
							vendors.forEach(vendor => {
								const key = `${vendor.erp_vendor_id}_${vendor.branch_id}`;
								vendorsMap[key] = vendor.vendor_name;
							});
						}
					}

					// Add vendor names to receiving records
					receivingRecords.forEach(record => {
						if (record.vendor_id && record.branch_id) {
							const key = `${record.vendor_id}_${record.branch_id}`;
							record.vendor_name = vendorsMap[key] || 'Unknown Vendor';
						}
						receivingRecordsMap[record.id] = record;
					});
				}
			}

			// Step 4: Combine all the data
			tasks = paymentTasks.map(transaction => ({
				...transaction,
				task_completion: taskCompletionsMap[transaction.task_id] || null,
				receiving_record_data: receivingRecordsMap[transaction.receiving_record_id] || null
			}));

			console.log(`TaskStatusDetails: Final tasks loaded:`, tasks.length);

			// Update filter options
			uniqueBranches = [...new Set(tasks.map(t => t.receiving_record_data?.branches?.name_en).filter(Boolean))].sort();
			
			// Create completion status options based on task completion data
			const completionStatuses = tasks.map(task => getCompletionStatus(task));
			uniqueStatuses = [...new Set(completionStatuses)].sort();

		} catch (err) {
			console.error('Error loading tasks:', err);
		}
	}

	// Get completion status for a task
	function getCompletionStatus(task) {
		if (task.task_completion) {
			const completion = task.task_completion;
			if (completion.task_finished_completed && completion.photo_uploaded_completed && completion.erp_reference_completed) {
				return 'Completed';
			} else if (completion.task_finished_completed || completion.photo_uploaded_completed || completion.erp_reference_completed) {
				return 'Partially Completed';
			} else {
				return 'In Progress';
			}
		}
		return 'Pending';
	}

	// Filter tasks based on search and filters
	$: {
		filteredTasks = tasks.filter(task => {
			// Search filter
			if (searchQuery) {
				const query = searchQuery.toLowerCase();
				const completionStatus = getCompletionStatus(task);
				const matchesSearch = 
					task.reference_number?.toLowerCase().includes(query) ||
					task.id?.toLowerCase().includes(query) ||
					task.receiving_record_data?.branches?.name_en?.toLowerCase().includes(query) ||
					task.receiving_record_data?.bill_number?.toLowerCase().includes(query) ||
					task.receiving_record_data?.erp_purchase_invoice_reference?.toLowerCase().includes(query) ||
					task.amount?.toString().includes(query) ||
					completionStatus?.toLowerCase().includes(query) ||
					task.task_completion?.completed_by_name?.toLowerCase().includes(query) ||
					task.task_id?.toLowerCase().includes(query);
				
				if (!matchesSearch) return false;
			}

			// Branch filter
			if (selectedBranch && task.receiving_record_data?.branches?.name_en !== selectedBranch) {
				return false;
			}

			// Status filter
			if (selectedStatus) {
				const completionStatus = getCompletionStatus(task);
				if (completionStatus !== selectedStatus) {
					return false;
				}
			}

			// Date range filter
			if (dateFrom && task.transaction_date < dateFrom) {
				return false;
			}
			if (dateTo && task.transaction_date > dateTo) {
				return false;
			}

			return true;
		});
	}

	// Calculate filtered totals
	$: filteredTotal = filteredTasks.reduce((sum, t) => sum + (parseFloat(t.amount) || 0), 0);

	// Format currency
	function formatCurrency(amount) {
		if (!amount) return 'SAR 0.00';
		return `SAR ${parseFloat(amount).toFixed(2)}`;
	}

	// Clear all filters
	function clearFilters() {
		searchQuery = '';
		selectedBranch = '';
		selectedStatus = '';
		dateFrom = '';
		dateTo = '';
	}

	// Get status color class
	function getStatusClass(status) {
		switch(status?.toLowerCase()) {
			case 'completed': return 'status-completed';
			case 'partially completed': return 'status-in-progress';
			case 'in progress': return 'status-in-progress';
			case 'pending': return 'status-pending';
			default: return 'status-unknown';
		}
	}

	// Load data on component mount
	onMount(() => {
		loadTasks();
	});
</script>

<div class="task-status-window">
	<div class="window-header">
		<h2>Task Status Details</h2>
		<div class="summary">
			Showing: {filteredTasks.length} of {tasks.length} records | 
			Filtered Total: {formatCurrency(filteredTotal)} | 
			Grand Total: {formatCurrency(tasks.reduce((sum, t) => sum + (parseFloat(t.amount) || 0), 0))}
		</div>
	</div>

	<!-- Filters and Search -->
	<div class="filters-section">
		<div class="search-row">
			<div class="search-input-wrapper">
				<input 
					type="text" 
					bind:value={searchQuery}
					placeholder="Search by reference, task ID, branch, vendor, bill number, completion status, completed by..."
					class="search-input"
				/>
				<span class="search-icon">🔍</span>
			</div>
			
			{#if searchQuery || selectedBranch || selectedStatus || dateFrom || dateTo}
				<button class="clear-filters-btn" on:click={clearFilters}>
					Clear Filters
				</button>
			{/if}
		</div>

		<div class="filter-row">
			<div class="filter-group">
				<label for="branch-filter">Branch:</label>
				<select id="branch-filter" bind:value={selectedBranch} class="filter-select">
					<option value="">All Branches</option>
					{#each uniqueBranches as branch}
						<option value={branch}>{branch}</option>
					{/each}
				</select>
			</div>

			<div class="filter-group">
				<label for="status-filter">Status:</label>
				<select id="status-filter" bind:value={selectedStatus} class="filter-select">
					<option value="">All Statuses</option>
					{#each uniqueStatuses as status}
						<option value={status}>{status}</option>
					{/each}
				</select>
			</div>

			<div class="filter-group">
				<label for="date-from">Date From:</label>
				<input 
					type="date" 
					id="date-from"
					bind:value={dateFrom} 
					class="filter-input"
				/>
			</div>

			<div class="filter-group">
				<label for="date-to">Date To:</label>
				<input 
					type="date" 
					id="date-to"
					bind:value={dateTo} 
					class="filter-input"
				/>
			</div>
		</div>
	</div>

	<!-- Tasks Table -->
	<div class="table-container">
		{#if filteredTasks.length > 0}
			<table class="tasks-table">
				<thead>
					<tr>
						<th>Transaction Date</th>
						<th>Amount</th>
						<th>Reference Number</th>
						<th>Vendor</th>
						<th>Branch</th>
						<th>Bill Number</th>
						<th>ERP Invoice Number</th>
						<th>Task Status</th>
						<th>Completed By</th>
						<th>Completion Date</th>
						<th>Task Details</th>
					</tr>
				</thead>
				<tbody>
					{#each filteredTasks as task}
						<tr>
							<td class="date-cell">
								{task.transaction_date ? new Date(task.transaction_date).toLocaleDateString('en-GB') : 'N/A'}
							</td>
							<td class="amount-cell">
								{formatCurrency(task.amount)}
							</td>
							<td class="reference-cell">
								{task.reference_number || 'N/A'}
							</td>
							<td class="vendor-cell">
								{task.receiving_record_data?.vendor_name || 'N/A'}
							</td>
							<td class="branch-cell">
								{task.receiving_record_data?.branches?.name_en || 'N/A'}
							</td>
							<td class="bill-number-cell">
								{task.receiving_record_data?.bill_number || 'N/A'}
							</td>
							<td class="erp-invoice-cell">
								{task.receiving_record_data?.erp_purchase_invoice_reference || 'N/A'}
							</td>
							<td class="status-cell">
								<span class="status-badge {getStatusClass(getCompletionStatus(task))}">
									{getCompletionStatus(task)}
								</span>
							</td>
							<td class="completed-by-cell">
								{task.task_completion?.completed_by_name || 'Not Assigned'}
							</td>
							<td class="completion-date-cell">
								{task.task_completion?.completed_at ? new Date(task.task_completion.completed_at).toLocaleDateString('en-GB') : 'N/A'}
							</td>
							<td class="task-details-cell">
								<div class="task-progress">
									<div class="progress-item {task.task_completion?.task_finished_completed ? 'completed' : 'pending'}">
										<span class="progress-icon">{task.task_completion?.task_finished_completed ? '✅' : '⏳'}</span>
										<span class="progress-label">Task Finished</span>
									</div>
									<div class="progress-item {task.task_completion?.photo_uploaded_completed ? 'completed' : 'pending'}">
										<span class="progress-icon">{task.task_completion?.photo_uploaded_completed ? '✅' : '📷'}</span>
										<span class="progress-label">Photo Uploaded</span>
									</div>
									<div class="progress-item {task.task_completion?.erp_reference_completed ? 'completed' : 'pending'}">
										<span class="progress-icon">{task.task_completion?.erp_reference_completed ? '✅' : '📋'}</span>
										<span class="progress-label">ERP Reference</span>
									</div>
								</div>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		{:else}
			<div class="no-data">
				<div class="no-data-icon">📋</div>
				<p class="no-data-message">No task records found</p>
				<p class="no-data-suggestion">Try adjusting your filters or search query</p>
			</div>
		{/if}
	</div>
</div>

<style>
	.task-status-window {
		width: 100%;
		height: 100%;
		background: white;
		display: flex;
		flex-direction: column;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}

	.window-header {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		padding: 1rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-shrink: 0;
	}

	.window-header h2 {
		margin: 0;
		font-size: 1.5rem;
		font-weight: 600;
	}

	.summary {
		font-size: 0.9rem;
		opacity: 0.9;
	}

	.filters-section {
		background: #f8f9fa;
		padding: 1rem;
		border-bottom: 1px solid #e9ecef;
		flex-shrink: 0;
	}

	.search-row {
		display: flex;
		gap: 1rem;
		margin-bottom: 1rem;
	}

	.search-input-wrapper {
		flex: 1;
		position: relative;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem 2.5rem 0.75rem 1rem;
		border: 2px solid #e9ecef;
		border-radius: 8px;
		font-size: 0.9rem;
		transition: border-color 0.3s ease;
	}

	.search-input:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.search-icon {
		position: absolute;
		right: 1rem;
		top: 50%;
		transform: translateY(-50%);
		color: #6c757d;
		pointer-events: none;
	}

	.clear-filters-btn {
		background: #dc3545;
		color: white;
		border: none;
		padding: 0.75rem 1rem;
		border-radius: 6px;
		font-size: 0.9rem;
		cursor: pointer;
		transition: background-color 0.3s ease;
		white-space: nowrap;
	}

	.clear-filters-btn:hover {
		background: #c82333;
	}

	.filter-row {
		display: flex;
		gap: 1rem;
		flex-wrap: wrap;
	}

	.filter-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.filter-group label {
		font-size: 0.85rem;
		font-weight: 500;
		color: #495057;
	}

	.filter-select,
	.filter-input {
		padding: 0.5rem;
		border: 1px solid #ced4da;
		border-radius: 4px;
		font-size: 0.9rem;
		min-width: 120px;
	}

	.table-container {
		flex: 1;
		overflow: auto;
		background: white;
	}

	.tasks-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.85rem;
	}

	.tasks-table th {
		background: #f8f9fa;
		color: #495057;
		font-weight: 600;
		padding: 0.75rem 0.5rem;
		text-align: left;
		border-bottom: 2px solid #dee2e6;
		white-space: nowrap;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.tasks-table td {
		padding: 0.75rem 0.5rem;
		border-bottom: 1px solid #e9ecef;
		vertical-align: top;
	}

	.tasks-table tbody tr:hover {
		background-color: #f8f9fa;
	}

	.date-cell,
	.created-date-cell {
		min-width: 90px;
		font-size: 12px;
	}

	.amount-cell {
		min-width: 100px;
		font-weight: 600;
		color: #28a745;
		text-align: right;
	}

	.reference-cell,
	.transaction-id-cell {
		min-width: 120px;
		font-size: 12px;
		font-family: monospace;
	}

	.vendor-cell {
		min-width: 150px;
	}

	.branch-cell {
		min-width: 120px;
	}

	.bill-number-cell,
	.erp-invoice-cell {
		min-width: 100px;
		font-size: 12px;
	}

	.status-cell {
		min-width: 100px;
	}

	.status-badge {
		display: inline-block;
		padding: 0.25rem 0.5rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.status-completed {
		background: #d4edda;
		color: #155724;
		border: 1px solid #c3e6cb;
	}

	.status-pending {
		background: #fff3cd;
		color: #856404;
		border: 1px solid #ffeaa7;
	}

	.status-in-progress {
		background: #d1ecf1;
		color: #0c5460;
		border: 1px solid #bee5eb;
	}

	.status-failed {
		background: #f8d7da;
		color: #721c24;
		border: 1px solid #f5c6cb;
	}

	.status-unknown {
		background: #e2e3e5;
		color: #383d41;
		border: 1px solid #d6d8db;
	}

	.vendor-cell,
	.completed-by-cell,
	.completion-date-cell {
		min-width: 100px;
		font-size: 12px;
	}

	.task-details-cell {
		min-width: 200px;
		padding: 0.5rem;
	}

	.task-progress {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.progress-item {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.75rem;
	}

	.progress-item.completed {
		color: #155724;
	}

	.progress-item.pending {
		color: #856404;
	}

	.progress-icon {
		font-size: 0.8rem;
	}

	.progress-label {
		font-size: 0.7rem;
		font-weight: 500;
	}

	.no-data {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem;
		color: #6c757d;
		text-align: center;
	}

	.no-data-icon {
		font-size: 3rem;
		margin-bottom: 1rem;
		opacity: 0.6;
	}

	.no-data-message {
		font-size: 1.1rem;
		font-weight: 500;
		margin: 0 0 0.5rem 0;
	}

	.no-data-suggestion {
		font-size: 0.9rem;
		margin: 0;
		opacity: 0.8;
	}

	/* Mobile Responsive */
	@media (max-width: 768px) {
		.filter-row {
			flex-direction: column;
		}

		.filter-group {
			min-width: 100%;
		}

		.tasks-table {
			font-size: 11px;
		}

		.tasks-table th,
		.tasks-table td {
			padding: 0.5rem 0.25rem;
		}

		.date-cell,
		.created-date-cell,
		.reference-cell,
		.transaction-id-cell,
		.bill-number-cell,
		.erp-invoice-cell {
			min-width: 80px;
			font-size: 11px;
		}

		.vendor-cell {
			min-width: 120px;
		}

		.branch-cell {
			min-width: 100px;
		}

		.task-id-cell,
		.completed-by-cell,
		.completion-date-cell {
			min-width: 80px;
			font-size: 11px;
		}

		.task-details-cell {
			min-width: 150px;
		}

		.progress-item {
			font-size: 0.65rem;
		}

		.progress-label {
			font-size: 0.6rem;
		}
	}
</style>