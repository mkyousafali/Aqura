<script>
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import ReceivingTaskCompletionDialog from '$lib/components/desktop-interface/master/operations/receiving/ReceivingTaskCompletionDialog.svelte';

	export let task;
	export let windowId;
	export let onTaskCompleted = () => {};

	let loading = true;
	let taskDetails = null;
	let receivingRecord = null;

	$: if (task) {
		loadTaskDetails();
	}

	async function loadTaskDetails() {
		loading = true;
		try {
			// Fetch the full task details
			const { data: taskData, error: taskError } = await supabase
				.from('receiving_tasks')
				.select('*')
				.eq('id', task.id)
				.single();

			if (taskError) throw taskError;
			taskDetails = taskData;

			// Fetch the related receiving record
			if (taskData.receiving_record_id) {
				// First get the receiving record
				const { data: recordData, error: recordError } = await supabase
					.from('receiving_records')
					.select('*')
					.eq('id', taskData.receiving_record_id)
					.single();

				if (!recordError && recordData) {
					receivingRecord = recordData;

					// Get branch info separately
					const { data: branchData } = await supabase
						.from('branches')
						.select('name_en, name_ar')
						.eq('id', recordData.branch_id)
						.single();

					// Get vendor info separately using composite key
					const { data: vendorData } = await supabase
						.from('vendors')
						.select('vendor_name, erp_vendor_id')
						.eq('erp_vendor_id', recordData.vendor_id)
						.eq('branch_id', recordData.branch_id)
						.single();

					// Attach the related data
					if (branchData) {
						receivingRecord.branch = branchData;
					}
					if (vendorData) {
						receivingRecord.vendor = [vendorData]; // Keep as array to match existing code
					}
				}
			}

			// Get assigned user information
			if (taskData.assigned_user_id) {
				const { data: userData } = await supabase
					.from('users')
					.select(`
						id,
						username,
						hr_employees(name)
					`)
					.eq('id', taskData.assigned_user_id)
					.single();

				if (userData) {
					taskDetails.assigned_user_name = userData.hr_employees?.name || userData.username;
				}
			}
		} catch (error) {
			console.error('Error loading task details:', error);
		} finally {
			loading = false;
		}
	}

	function openCompletionDialog() {
		const completionWindowId = `receiving-task-completion-${task.id}`;
		openWindow({
			id: completionWindowId,
			title: 'Complete Receiving Task',
			component: ReceivingTaskCompletionDialog,
			props: {
				taskId: task.id,
				receivingRecordId: task.receiving_record_id,
				onComplete: () => {
					windowManager.closeWindow(completionWindowId);
					onTaskCompleted();
					// Close this details window too
					if (windowId) {
						windowManager.closeWindow(windowId);
					}
				}
			},
			icon: '✅',
			size: { width: 600, height: 500 },
			position: { 
				x: 150 + (Math.random() * 100), 
				y: 100 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: false,
			closable: true
		});
	}

	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		return new Date(dateString).toLocaleString();
	}

	function formatCurrency(amount) {
		if (!amount) return 'N/A';
		return new Intl.NumberFormat('en-US', { 
			style: 'currency', 
			currency: 'IQD',
			minimumFractionDigits: 0,
			maximumFractionDigits: 0
		}).format(amount);
	}
</script>

<div class="receiving-task-details">
	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>Loading task details...</p>
		</div>
	{:else if taskDetails}
		<div class="task-info">
			<div class="section">
				<h3>📦 Task Information</h3>
				<div class="info-grid">
					<div class="info-item">
						<span class="label">Task for:</span>
						<span class="value">{taskDetails.role_type || 'N/A'}</span>
					</div>
					<div class="info-item">
						<span class="label">Assigned to:</span>
						<span class="value">{taskDetails.assigned_user_name || 'N/A'}</span>
					</div>
					<div class="info-item">
						<span class="label">Priority:</span>
						<span class="value">
							<span class="priority-badge {taskDetails.priority}">
								{taskDetails.priority}
							</span>
						</span>
					</div>
					<div class="info-item">
						<span class="label">Deadline:</span>
						<span class="value">{formatDate(taskDetails.due_date)}</span>
					</div>
					<div class="info-item">
						<span class="label">Task Status:</span>
						<span class="value">
							<span class="status-badge {taskDetails.task_status}">
								{taskDetails.task_status}
							</span>
						</span>
					</div>
					<div class="info-item">
						<span class="label">Assigned on:</span>
						<span class="value">{formatDate(taskDetails.created_at)}</span>
					</div>
				</div>
			</div>

			<div class="section">
				<h3>📋 Task Description</h3>
				<div class="description">
					{taskDetails.description || 'No description available'}
				</div>
			</div>

			{#if receivingRecord}
				<div class="section">
					<h3>🏢 Receiving Record Details</h3>
					<div class="info-grid">
						<div class="info-item">
							<span class="label">Branch:</span>
							<span class="value">{receivingRecord.branch?.name_en || 'N/A'}</span>
						</div>
						<div class="info-item">
							<span class="label">Vendor:</span>
							<span class="value">{receivingRecord.vendor?.[0]?.vendor_name || 'N/A'}</span>
						</div>
						<div class="info-item">
							<span class="label">Vendor ID:</span>
							<span class="value">{receivingRecord.vendor_id || 'N/A'}</span>
						</div>
						<div class="info-item">
							<span class="label">Bill Number:</span>
							<span class="value">{receivingRecord.bill_number || 'N/A'}</span>
						</div>
						<div class="info-item">
							<span class="label">Bill Amount:</span>
							<span class="value">{formatCurrency(receivingRecord.bill_amount)}</span>
						</div>
						<div class="info-item">
							<span class="label">Received Date:</span>
							<span class="value">{formatDate(receivingRecord.bill_date)}</span>
						</div>
						<div class="info-item">
							<span class="label">Received By:</span>
							<span class="value">{receivingRecord.received_by || 'N/A'}</span>
						</div>
					</div>
				</div>

				{#if taskDetails.clearance_certificate_url}
					<div class="section">
						<h3>📄 Clearance Certificate</h3>
						<a 
							href={taskDetails.clearance_certificate_url} 
							target="_blank" 
							rel="noopener noreferrer"
							class="certificate-link"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
							</svg>
							View Clearance Certificate
						</a>
					</div>
				{/if}
			{/if}

			{#if taskDetails.task_status === 'pending'}
				<div class="actions">
					<button 
						class="complete-btn"
						on:click={openCompletionDialog}
					>
						✅ Complete Task
					</button>
				</div>
			{:else}
				<div class="completed-info">
					<p>✅ This task has been completed</p>
					{#if taskDetails.completed_at}
						<p class="completed-date">Completed on: {formatDate(taskDetails.completed_at)}</p>
					{/if}
				</div>
			{/if}
		</div>
	{:else}
		<div class="error">
			<p>❌ Failed to load task details</p>
		</div>
	{/if}
</div>

<style>
	.receiving-task-details {
		padding: 20px;
		max-height: 600px;
		overflow-y: auto;
	}

	.loading, .error {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 40px;
		text-align: center;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #f3f4f6;
		border-top: 4px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.task-info {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.section {
		background: #f9fafb;
		border-radius: 8px;
		padding: 16px;
		border: 1px solid #e5e7eb;
	}

	.section h3 {
		margin: 0 0 12px 0;
		font-size: 16px;
		font-weight: 600;
		color: #1f2937;
	}

	.info-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 12px;
	}

	.info-item {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.info-item .label {
		font-size: 12px;
		font-weight: 500;
		color: #6b7280;
		text-transform: uppercase;
	}

	.info-item .value {
		font-size: 14px;
		color: #1f2937;
		font-weight: 500;
	}

	.description {
		background: white;
		padding: 12px;
		border-radius: 6px;
		border: 1px solid #e5e7eb;
		color: #374151;
		line-height: 1.6;
		white-space: pre-wrap;
	}

	.priority-badge, .status-badge {
		display: inline-block;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		text-transform: uppercase;
	}

	.priority-badge.high {
		background: #fee2e2;
		color: #991b1b;
	}

	.priority-badge.medium {
		background: #fef3c7;
		color: #92400e;
	}

	.priority-badge.low {
		background: #dbeafe;
		color: #1e40af;
	}

	.status-badge.pending {
		background: #fef3c7;
		color: #92400e;
	}

	.status-badge.completed {
		background: #d1fae5;
		color: #065f46;
	}

	.certificate-link {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 10px 16px;
		background: #3b82f6;
		color: white;
		text-decoration: none;
		border-radius: 6px;
		font-weight: 500;
		transition: background 0.2s;
	}

	.certificate-link:hover {
		background: #2563eb;
	}

	.certificate-link svg {
		width: 16px;
		height: 16px;
	}

	.actions {
		margin-top: 8px;
		display: flex;
		justify-content: flex-end;
	}

	.complete-btn {
		padding: 12px 24px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.2s;
	}

	.complete-btn:hover {
		background: #059669;
	}

	.completed-info {
		text-align: center;
		padding: 20px;
		background: #d1fae5;
		border-radius: 8px;
		color: #065f46;
	}

	.completed-info p {
		margin: 4px 0;
		font-weight: 600;
	}

	.completed-date {
		font-size: 14px;
		font-weight: 400 !important;
	}
</style>
