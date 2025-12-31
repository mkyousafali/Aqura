<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';

	// Get task ID from URL params
	let taskId = '';
	let isLoading = true;
	let errorMessage = '';

	// Task data
	let taskDetails: any = null;
	let receivingRecord: any = null;

	// Current user
	$: currentUserData = $currentUser;

	onMount(async () => {
		taskId = $page.params.id;
		
		if (!$isAuthenticated || !currentUserData) {
			goto('/login');
			return;
		}

		if (taskId) {
			await loadTaskDetails();
		}
		isLoading = false;
	});

	async function loadTaskDetails() {
		try {
			isLoading = true;
			
			// First get the receiving task with receiving record
			const { data: task, error: taskError } = await supabase
				.from('receiving_tasks')
				.select(`
					*,
					receiving_record:receiving_records(*)
				`)
				.eq('id', taskId)
				.eq('assigned_user_id', currentUserData.id)
				.single();

			if (taskError || !task) {
				throw new Error('Task not found or not accessible');
			}

			taskDetails = task;
			receivingRecord = task.receiving_record;

			// Now get branch and vendor info separately if we have a receiving record
			if (receivingRecord) {
				// Get branch info
				const { data: branchData } = await supabase
					.from('branches')
					.select('name_en')
					.eq('id', receivingRecord.branch_id)
					.single();

				// Get vendor info
				const { data: vendorData } = await supabase
					.from('vendors')
					.select('vendor_name')
					.eq('erp_vendor_id', receivingRecord.vendor_id)
					.eq('branch_id', receivingRecord.branch_id)
					.single();

				// Attach the fetched data
				if (branchData) {
					receivingRecord.branch_name = branchData.name_en;
				}
				if (vendorData) {
					receivingRecord.vendor_name = vendorData.vendor_name;
				}
			}

		} catch (error) {
			console.error('Error loading task details:', error);
			errorMessage = error.message || 'Failed to load task details';
		} finally {
			isLoading = false;
		}
	}

	function formatDate(dateString: string) {
		if (!dateString) return 'Not set';
		const date = new Date(dateString);
		return date.toLocaleDateString('en-US', {
			weekday: 'long',
			year: 'numeric',
			month: 'long',
			day: 'numeric'
		});
	}

	function formatDateTime(dateString: string) {
		if (!dateString) return 'Not set';
		const date = new Date(dateString);
		return date.toLocaleString('en-US', {
			weekday: 'short',
			month: 'short', 
			day: 'numeric',
			year: 'numeric',
			hour: 'numeric',
			minute: '2-digit',
			hour12: true
		});
	}

	function formatDueDateWithRemaining(dateString: string) {
		if (!dateString) return 'Not set';
		const dueDate = new Date(dateString);
		const now = new Date();
		const diffTime = dueDate.getTime() - now.getTime();
		const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		
		const dateStr = dueDate.toLocaleDateString('en-US', {
			weekday: 'short',
			month: 'short',
			day: 'numeric',
			year: 'numeric'
		});
		
		const timeStr = dueDate.toLocaleTimeString('en-US', {
			hour: 'numeric',
			minute: '2-digit',
			hour12: true
		});
		
		let remainingStr = '';
		if (diffDays < 0) {
			remainingStr = ` (${Math.abs(diffDays)} days overdue)`;
		} else if (diffDays === 0) {
			remainingStr = ' (Due today)';
		} else if (diffDays === 1) {
			remainingStr = ' (1 day remaining)';
		} else {
			remainingStr = ` (${diffDays} days remaining)`;
		}
		
		return `${dateStr} at ${timeStr}${remainingStr}`;
	}

	function formatCurrency(amount: number) {
		if (!amount) return '0.00';
		return new Intl.NumberFormat('en-US', {
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		}).format(amount);
	}

	function getStatusColor(status: string) {
		switch (status?.toLowerCase()) {
			case 'pending': return '#F59E0B';
			case 'in_progress': return '#3B82F6';
			case 'completed': return '#10B981';
			case 'cancelled': return '#EF4444';
			default: return '#6B7280';
		}
	}

	function getPriorityColor(priority: string) {
		switch (priority?.toLowerCase()) {
			case 'low': return '#10B981';
			case 'medium': return '#F59E0B';
			case 'high': return '#EF4444';
			case 'urgent': return '#DC2626';
			default: return '#6B7280';
		}
	}

	function getRoleDisplayName(roleType: string) {
		switch (roleType) {
			case 'inventory_manager': return 'Inventory Manager';
			case 'accountant': return 'Accountant';
			case 'manager': return 'Manager';
			default: return roleType || 'Unknown';
		}
	}
</script>

<svelte:head>
	<title>Receiving Task Details - Aqura Mobile</title>
</svelte:head>

<div class="mobile-receiving-task-details">
	{#if isLoading}
		<div class="loading-state">
			<div class="loading-spinner"></div>
			<p>Loading task details...</p>
		</div>
	{:else if !taskDetails}
		<div class="error-state">
			<div class="error-icon">
				<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
					<circle cx="12" cy="12" r="10"/>
					<line x1="12" y1="8" x2="12" y2="12"/>
					<line x1="12" y1="16" x2="12.01" y2="16"/>
				</svg>
			</div>
			<h2>Task Not Found</h2>
			<p>This receiving task doesn't exist or you don't have access to it.</p>
			<button class="back-btn" on:click={() => goto('/mobile-interface/tasks')}>
				← Back to Tasks
			</button>
		</div>
	{:else}
		<!-- Header -->
		<div class="header-section">
			<div class="header-top">
				<button class="back-button" on:click={() => goto('/mobile-interface/tasks')}>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M19 12H5M12 19l-7-7 7-7"/>
					</svg>
				</button>
				<h1>📦 Receiving Task</h1>
			</div>
			<p class="task-title">{taskDetails.title}</p>
		</div>

		<!-- Status and Priority -->
		<div class="status-section">
			<div class="status-badge" style="background-color: {getStatusColor(taskDetails.task_status)}20; color: {getStatusColor(taskDetails.task_status)};">
				<span class="status-dot" style="background-color: {getStatusColor(taskDetails.task_status)};"></span>
				{taskDetails.task_status || 'Unknown'}
			</div>
			<div class="priority-badge" style="background-color: {getPriorityColor(taskDetails.priority)}20; color: {getPriorityColor(taskDetails.priority)};">
				{taskDetails.priority || 'Normal'} Priority
			</div>
		</div>

		<!-- Task Information -->
		<div class="info-section">
			<h3>📋 Task Information</h3>
			<div class="info-grid">
				<div class="info-item">
					<label>Role Required:</label>
					<span class="role-badge">{getRoleDisplayName(taskDetails.role_type)}</span>
				</div>
				<div class="info-item">
					<label>Due Date:</label>
					<span class="due-date">{formatDueDateWithRemaining(taskDetails.due_date)}</span>
				</div>
				<div class="info-item">
					<label>Received Date:</label>
					<span>{formatDateTime(taskDetails.created_at)}</span>
				</div>
				{#if taskDetails.description}
					<div class="info-item full-width">
						<label>Description:</label>
						<span class="description">{taskDetails.description}</span>
					</div>
				{/if}
			</div>
		</div>

		<!-- Receiving Record Details -->
		{#if receivingRecord}
			<div class="info-section">
				<h3>📄 Receiving Record Details</h3>
				<div class="info-grid">
					<div class="info-item">
						<label>Branch:</label>
						<span>{receivingRecord.branch_name || 'Unknown'}</span>
					</div>
					<div class="info-item">
						<label>Vendor:</label>
						<span>{receivingRecord.vendor_name || 'Unknown'}</span>
					</div>
					<div class="info-item">
						<label>Bill Number:</label>
						<span>{receivingRecord.bill_number || 'N/A'}</span>
					</div>
					<div class="info-item">
						<label>Bill Amount:</label>
						<span class="amount">{formatCurrency(receivingRecord.bill_amount)}</span>
					</div>
					<div class="info-item">
						<label>Bill Date:</label>
						<span>{receivingRecord.bill_date ? formatDate(receivingRecord.bill_date) : 'Not set'}</span>
					</div>
					{#if receivingRecord.notes}
						<div class="info-item full-width">
							<label>Notes:</label>
							<span class="description">{receivingRecord.notes}</span>
						</div>
					{/if}
				</div>
			</div>

			<!-- Current Progress -->
			<div class="info-section">
				<h3>✅ Current Progress</h3>
				<div class="progress-grid">
					<div class="progress-item" class:completed={receivingRecord.erp_purchase_invoice_uploaded}>
						<div class="progress-indicator">
							{#if receivingRecord.erp_purchase_invoice_uploaded}
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M20 6L9 17l-5-5"/>
								</svg>
							{:else}
								<div class="empty-circle"></div>
							{/if}
						</div>
						<div class="progress-content">
							<span class="progress-label">ERP Reference</span>
							<span class="progress-value">{receivingRecord.erp_purchase_invoice_reference || 'Not entered'}</span>
						</div>
					</div>
					
					<div class="progress-item" class:completed={receivingRecord.pr_excel_file_uploaded}>
						<div class="progress-indicator">
							{#if receivingRecord.pr_excel_file_uploaded}
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M20 6L9 17l-5-5"/>
								</svg>
							{:else}
								<div class="empty-circle"></div>
							{/if}
						</div>
						<div class="progress-content">
							<span class="progress-label">PR Excel File</span>
							<span class="progress-value">{receivingRecord.pr_excel_file_uploaded ? 'Uploaded' : 'Not uploaded'}</span>
						</div>
					</div>
					
					<div class="progress-item" class:completed={receivingRecord.original_bill_uploaded}>
						<div class="progress-indicator">
							{#if receivingRecord.original_bill_uploaded}
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M20 6L9 17l-5-5"/>
								</svg>
							{:else}
								<div class="empty-circle"></div>
							{/if}
						</div>
						<div class="progress-content">
							<span class="progress-label">Original Bill</span>
							<span class="progress-value">{receivingRecord.original_bill_uploaded ? 'Uploaded' : 'Not uploaded'}</span>
						</div>
					</div>
				</div>
			</div>
		{/if}

		<!-- Error Message -->
		{#if errorMessage}
			<div class="message error">
				<span class="icon">❌</span>
				{errorMessage}
			</div>
		{/if}

		<!-- Actions -->
		<div class="actions">
			<button class="secondary-btn" on:click={() => goto('/mobile-interface/tasks')}>
				← Back to Tasks
			</button>
			<button 
				class="primary-btn" 
				on:click={() => goto(`/mobile-interface/receiving-tasks/${taskId}/complete`)}
				disabled={taskDetails.task_status === 'completed'}
			>
				{#if taskDetails.task_status === 'completed'}
					Task Completed
				{:else}
					Complete Task
				{/if}
			</button>
		</div>
	{/if}
</div>

<style>
	.mobile-receiving-task-details {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	.loading-state,
	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
		min-height: 50vh;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #E5E7EB;
		border-top: 3px solid #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	.error-icon {
		color: #EF4444;
		margin-bottom: 1rem;
	}

	.header-section {
		background: white;
		padding: 1rem 1.5rem 1.5rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.header-top {
		display: flex;
		align-items: center;
		gap: 1rem;
		margin-bottom: 0.5rem;
	}

	.back-button {
		background: #F3F4F6;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		padding: 0.5rem;
		color: #374151;
		cursor: pointer;
		transition: background 0.2s;
	}

	.back-button:hover {
		background: #E5E7EB;
	}

	.header-section h1 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
	}

	.task-title {
		margin: 0;
		font-size: 0.875rem;
		color: #6B7280;
		font-weight: 500;
	}

	.status-section {
		display: flex;
		gap: 0.75rem;
		padding: 1rem 1.5rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
	}

	.status-badge,
	.priority-badge {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 0.75rem;
		border-radius: 8px;
		font-size: 0.75rem;
		font-weight: 500;
		text-transform: capitalize;
	}

	.status-dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
	}

	.info-section {
		background: white;
		margin: 1rem;
		padding: 1.5rem;
		border-radius: 12px;
		border: 1px solid #E5E7EB;
	}

	.info-section h3 {
		margin: 0 0 1rem 0;
		font-size: 1rem;
		font-weight: 600;
		color: #1F2937;
	}

	.info-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 0.75rem;
	}

	.info-item {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		padding: 0.75rem;
		background: #F9FAFB;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.info-item.full-width {
		flex-direction: column;
		align-items: flex-start;
		gap: 0.5rem;
	}

	.info-item label {
		font-weight: 500;
		color: #374151;
		font-size: 0.875rem;
		min-width: 80px;
	}

	.info-item span {
		color: #1F2937;
		font-size: 0.875rem;
		text-align: right;
		flex: 1;
	}

	.info-item.full-width span {
		text-align: left;
	}

	.role-badge {
		background: #3B82F6;
		color: white;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 500;
	}

	.amount {
		font-weight: 600;
		color: #059669;
	}

	.due-date {
		font-weight: 500;
	}

	.description {
		line-height: 1.5;
		color: #4B5563;
	}

	.progress-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 1rem;
	}

	.progress-item {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1rem;
		background: #F9FAFB;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
		transition: all 0.2s;
	}

	.progress-item.completed {
		background: #F0FDF4;
		border-color: #BBF7D0;
	}

	.progress-indicator {
		width: 32px;
		height: 32px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #E5E7EB;
		color: #9CA3AF;
		flex-shrink: 0;
	}

	.progress-item.completed .progress-indicator {
		background: #10B981;
		color: white;
	}

	.empty-circle {
		width: 12px;
		height: 12px;
		border: 2px solid #9CA3AF;
		border-radius: 50%;
	}

	.progress-content {
		flex: 1;
	}

	.progress-label {
		display: block;
		font-weight: 500;
		color: #374151;
		font-size: 0.875rem;
		margin-bottom: 0.25rem;
	}

	.progress-value {
		display: block;
		color: #6B7280;
		font-size: 0.75rem;
	}

	.progress-item.completed .progress-value {
		color: #059669;
		font-weight: 500;
	}

	.message {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem 1.5rem;
		margin: 1rem;
		border-radius: 12px;
		font-size: 0.875rem;
		font-weight: 500;
	}

	.message.error {
		background: #FEF2F2;
		color: #DC2626;
		border: 1px solid #FECACA;
	}

	.actions {
		display: flex;
		gap: 1rem;
		padding: 1.5rem;
		background: white;
		border-top: 1px solid #E5E7EB;
		position: sticky;
		bottom: 0;
	}

	.secondary-btn,
	.primary-btn {
		flex: 1;
		padding: 1rem 1.5rem;
		border-radius: 12px;
		font-weight: 600;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 48px;
	}

	.secondary-btn {
		background: #F3F4F6;
		color: #374151;
		border: 1px solid #D1D5DB;
	}

	.secondary-btn:hover:not(:disabled) {
		background: #E5E7EB;
	}

	.primary-btn {
		background: #10B981;
		color: white;
	}

	.primary-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
	}

	.primary-btn:disabled {
		background: #D1D5DB;
		color: #9CA3AF;
		cursor: not-allowed;
		transform: none;
	}

	.back-btn {
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 0.75rem 1.5rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
		margin-top: 1rem;
	}

	.back-btn:hover {
		background: #2563EB;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Mobile optimizations */
	@media (max-width: 640px) {
		.info-section {
			margin: 0.75rem;
		}

		.actions {
			flex-direction: column;
		}

		.secondary-btn,
		.primary-btn {
			width: 100%;
		}
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.actions {
			padding-bottom: max(1.5rem, env(safe-area-inset-bottom));
		}
	}
</style>
