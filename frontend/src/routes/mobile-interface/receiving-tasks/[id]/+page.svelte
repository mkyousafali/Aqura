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

	/** Convert URLs in text to clickable button links */
	function linkifyText(text: string): string {
		if (!text) return '';
		const urlRegex = /(https?:\/\/[^\s<>"]+)/g;
		return text.replace(urlRegex, '<br/><a href="$1" target="_blank" rel="noopener noreferrer" class="url-btn"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>View Clearance Certificate</a>');
	}
</script>

<svelte:head>
	<title>Receiving Task Details - Aqura Mobile</title>
</svelte:head>

<div class="mobile-receiving-task-details">
	{#if isLoading}
		<div class="loading-state">
			<div class="loading-spinner"></div>
			<p>Loading...</p>
		</div>
	{:else if !taskDetails}
		<div class="error-state">
			<p>Task not found or not accessible.</p>
			<button class="back-btn" on:click={() => goto('/mobile-interface/tasks')}>← Back</button>
		</div>
	{:else}
		<!-- Header -->
		<div class="header-section">
			<h1>{taskDetails.title}</h1>
			<div class="status-row">
				<span class="status-badge" style="background-color: {getStatusColor(taskDetails.task_status)}20; color: {getStatusColor(taskDetails.task_status)};">
					<span class="status-dot" style="background-color: {getStatusColor(taskDetails.task_status)};"></span>
					{taskDetails.task_status || 'Unknown'}
				</span>
				<span class="priority-badge" style="background-color: {getPriorityColor(taskDetails.priority)}20; color: {getPriorityColor(taskDetails.priority)};">
					{taskDetails.priority || 'Normal'}
				</span>
			</div>
		</div>

		<!-- Task Information -->
		<div class="info-section">
			<h3>Task Information</h3>
			<div class="info-grid">
				<div class="info-row">
					<span class="info-label">Role</span>
					<span class="role-badge">{getRoleDisplayName(taskDetails.role_type)}</span>
				</div>
				<div class="info-row">
					<span class="info-label">Due</span>
					<span>{formatDueDateWithRemaining(taskDetails.due_date)}</span>
				</div>
				<div class="info-row">
					<span class="info-label">Received</span>
					<span>{formatDateTime(taskDetails.created_at)}</span>
				</div>
				{#if taskDetails.description}
					<div class="info-row" style="flex-direction: column; align-items: flex-start; gap: 0.2rem;">
						<span class="info-label">Description</span>
						<span class="description">{@html linkifyText(taskDetails.description)}</span>
					</div>
				{/if}
			</div>
		</div>

		<!-- Receiving Record Details -->
		{#if receivingRecord}
			<div class="info-section">
				<h3>Record Details</h3>
				<div class="info-grid">
					<div class="info-row">
						<span class="info-label">Branch</span>
						<span>{receivingRecord.branch_name || 'Unknown'}</span>
					</div>
					<div class="info-row">
						<span class="info-label">Vendor</span>
						<span>{receivingRecord.vendor_name || 'Unknown'}</span>
					</div>
					<div class="info-row">
						<span class="info-label">Bill #</span>
						<span>{receivingRecord.bill_number || 'N/A'}</span>
					</div>
					<div class="info-row">
						<span class="info-label">Amount</span>
						<span class="amount">{formatCurrency(receivingRecord.bill_amount)}</span>
					</div>
					<div class="info-row">
						<span class="info-label">Bill Date</span>
						<span>{receivingRecord.bill_date ? formatDate(receivingRecord.bill_date) : 'Not set'}</span>
					</div>
					{#if receivingRecord.notes}
						<div class="info-row" style="flex-direction: column; align-items: flex-start; gap: 0.2rem;">
							<span class="info-label">Notes</span>
							<span class="description">{@html linkifyText(receivingRecord.notes)}</span>
						</div>
					{/if}
				</div>
			</div>

			<!-- Current Progress -->
			<div class="info-section">
				<h3>Progress</h3>
				<div class="info-grid">
					<div class="info-row">
						<span class="info-label">ERP Ref</span>
						<span class:status-ok={receivingRecord.erp_purchase_invoice_uploaded} class:status-pending={!receivingRecord.erp_purchase_invoice_uploaded}>
							{receivingRecord.erp_purchase_invoice_uploaded ? '✓ ' + (receivingRecord.erp_purchase_invoice_reference || 'Done') : '○ Not entered'}
						</span>
					</div>
					<div class="info-row">
						<span class="info-label">PR Excel</span>
						<span class:status-ok={receivingRecord.pr_excel_file_uploaded} class:status-pending={!receivingRecord.pr_excel_file_uploaded}>
							{receivingRecord.pr_excel_file_uploaded ? '✓ Uploaded' : '○ Not uploaded'}
						</span>
					</div>
					<div class="info-row">
						<span class="info-label">Original Bill</span>
						<span class:status-ok={receivingRecord.original_bill_uploaded} class:status-pending={!receivingRecord.original_bill_uploaded}>
							{receivingRecord.original_bill_uploaded ? '✓ Uploaded' : '○ Not uploaded'}
						</span>
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
			<button class="secondary-btn" on:click={() => goto('/mobile-interface/tasks')}>← Back</button>
			<button 
				class="primary-btn" 
				on:click={() => goto(`/mobile-interface/receiving-tasks/${taskId}/complete`)}
				disabled={taskDetails.task_status === 'completed'}
			>
				{taskDetails.task_status === 'completed' ? 'Completed' : 'Complete Task'}
			</button>
		</div>
	{/if}
</div>

<style>
	.mobile-receiving-task-details {
		min-height: 100%;
		background: #F8FAFC;
		padding: 0;
		padding-bottom: 0.5rem;
	}

	.loading-state,
	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem 1rem;
		text-align: center;
		min-height: 40vh;
		font-size: 0.82rem;
		color: #6B7280;
	}

	.loading-spinner {
		width: 24px;
		height: 24px;
		border: 2px solid #E5E7EB;
		border-top: 2px solid #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 0.5rem;
	}

	.header-section {
		background: white;
		padding: 0.5rem 0.75rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.header-top {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 0.25rem;
	}

	.back-button {
		background: #F3F4F6;
		border: 1px solid #E5E7EB;
		border-radius: 6px;
		padding: 0.3rem;
		color: #374151;
		cursor: pointer;
		flex-shrink: 0;
	}

	.header-section h1 {
		margin: 0;
		font-size: 0.88rem;
		font-weight: 600;
		color: #1F2937;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.status-row {
		display: flex;
		gap: 0.4rem;
		margin-top: 0.15rem;
	}

	.status-badge,
	.priority-badge {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.2rem 0.5rem;
		border-radius: 4px;
		font-size: 0.68rem;
		font-weight: 500;
		text-transform: capitalize;
	}

	.status-dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
	}

	.info-section {
		background: white;
		margin: 0.4rem 0.6rem;
		padding: 0.5rem 0.7rem;
		border-radius: 6px;
		border: 1px solid #E5E7EB;
	}

	.info-section h3 {
		margin: 0 0 0.4rem 0;
		font-size: 0.82rem;
		font-weight: 600;
		color: #1F2937;
	}

	.info-grid {
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
	}

	.info-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.25rem 0;
		border-bottom: 1px solid #F3F4F6;
		font-size: 0.78rem;
	}

	.info-row:last-child {
		border-bottom: none;
	}

	.info-label {
		font-weight: 500;
		color: #6B7280;
		font-size: 0.76rem;
	}

	.info-row span {
		color: #1F2937;
		font-size: 0.78rem;
	}

	.role-badge {
		background: #3B82F6;
		color: white !important;
		padding: 0.15rem 0.4rem;
		border-radius: 4px;
		font-size: 0.7rem;
		font-weight: 500;
	}

	.amount {
		font-weight: 600;
		color: #059669 !important;
	}

	.description {
		line-height: 1.4;
		color: #4B5563;
		font-size: 0.76rem;
		word-break: break-word;
		overflow-wrap: break-word;
		white-space: pre-wrap;
		max-width: 100%;
	}

	.description :global(.url-btn) {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		margin-top: 0.3rem;
		padding: 0.3rem 0.6rem;
		background: #3B82F6;
		color: white;
		border-radius: 5px;
		font-size: 0.74rem;
		font-weight: 500;
		text-decoration: none;
		transition: background 0.2s;
	}

	.description :global(.url-btn:hover) {
		background: #2563EB;
	}

	.status-ok {
		color: #059669 !important;
		font-weight: 500;
	}

	.status-pending {
		color: #9CA3AF !important;
	}

	.message {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.4rem 0.7rem;
		margin: 0.4rem 0.6rem;
		border-radius: 6px;
		font-size: 0.78rem;
		font-weight: 500;
	}

	.message.error {
		background: #FEF2F2;
		color: #DC2626;
		border: 1px solid #FECACA;
	}

	.actions {
		display: flex;
		gap: 0.5rem;
		padding: 0.5rem 0.7rem;
		background: white;
		border-top: 1px solid #E5E7EB;
		position: sticky;
		bottom: 0;
	}

	.secondary-btn,
	.primary-btn {
		flex: 1;
		padding: 0.5rem 0.7rem;
		border-radius: 6px;
		font-weight: 600;
		font-size: 0.8rem;
		cursor: pointer;
		transition: all 0.2s;
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 36px;
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
		border-radius: 6px;
		padding: 0.4rem 0.8rem;
		font-size: 0.8rem;
		font-weight: 500;
		cursor: pointer;
		margin-top: 0.5rem;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	@supports (padding: max(0px)) {
		.actions {
			padding-bottom: max(0.5rem, env(safe-area-inset-bottom));
		}
	}
</style>
