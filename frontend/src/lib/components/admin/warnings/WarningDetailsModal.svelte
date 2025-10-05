<script>
	import { createEventDispatcher } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	
	export let warning;
	
	const dispatch = createEventDispatcher();
	
	let loading = false;
	let error = null;
	let updateError = null;
	let isUpdating = false;
	
	// Editable fields
	let editableStatus = warning.warning_status;
	let editableNotes = warning.resolution_notes || '';
	let editableFineStatus = warning.fine_status || 'pending';
	
	// Format date for display
	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		return new Date(dateString).toLocaleString();
	}
	
	// Format currency
	function formatCurrency(amount, currency = 'USD') {
		if (!amount) return 'N/A';
		return new Intl.NumberFormat('en-US', {
			style: 'currency',
			currency: currency
		}).format(amount);
	}
	
	// Get status badge class
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
	
	// Get warning type badge
	function getWarningTypeBadge(type) {
		const typeMap = {
			overall_performance_no_fine: { class: 'bg-blue-100 text-blue-800', label: 'Performance' },
			overall_performance_fine_threat: { class: 'bg-orange-100 text-orange-800', label: 'Performance + Threat' },
			overall_performance_with_fine: { class: 'bg-red-100 text-red-800', label: 'Performance + Fine' },
			task_specific_no_fine: { class: 'bg-purple-100 text-purple-800', label: 'Task Specific' },
			task_specific_fine_threat: { class: 'bg-pink-100 text-pink-800', label: 'Task + Threat' },
			task_specific_with_fine: { class: 'bg-red-100 text-red-800', label: 'Task + Fine' }
		};
		return typeMap[type] || { class: 'bg-gray-100 text-gray-800', label: type };
	}
	
	// Update warning status
	async function updateWarningStatus() {
		if (isUpdating) return;
		
		isUpdating = true;
		updateError = null;
		
		try {
			const updates = {
				warning_status: editableStatus,
				resolution_notes: editableNotes,
				fine_status: editableFineStatus
			};
			
			// Set resolved timestamp if status is resolved
			if (editableStatus === 'resolved' && warning.warning_status !== 'resolved') {
				updates.resolved_at = new Date().toISOString();
				updates.resolved_by = 'current-user-id'; // Should get from auth
			}
			
			// Set acknowledged timestamp if status is acknowledged  
			if (editableStatus === 'acknowledged' && warning.warning_status !== 'acknowledged') {
				updates.acknowledged_at = new Date().toISOString();
				updates.acknowledged_by = 'current-user-id'; // Should get from auth
			}
			
			const { error } = await supabase
				.from('employee_warnings')
				.update(updates)
				.eq('id', warning.id);
			
			if (error) throw error;
			
			// Update local warning object
			warning = { ...warning, ...updates };
			
			alert('Warning updated successfully!');
			
		} catch (err) {
			console.error('Error updating warning:', err);
			updateError = 'Failed to update warning: ' + err.message;
		} finally {
			isUpdating = false;
		}
	}
	
	// Mark fine as paid
	async function markFineAsPaid() {
		if (isUpdating) return;
		
		isUpdating = true;
		updateError = null;
		
		try {
			const updates = {
				fine_status: 'paid',
				fine_paid_date: new Date().toISOString(),
				fine_paid_at: new Date().toISOString()
			};
			
			const { error } = await supabase
				.from('employee_warnings')
				.update(updates)
				.eq('id', warning.id);
			
			if (error) throw error;
			
			// Update local warning object
			warning = { ...warning, ...updates };
			editableFineStatus = 'paid';
			
			alert('Fine marked as paid successfully!');
			
		} catch (err) {
			console.error('Error updating fine status:', err);
			updateError = 'Failed to update fine status: ' + err.message;
		} finally {
			isUpdating = false;
		}
	}
	
	function onClose() {
		dispatch('close');
	}
</script>

<div class="warning-details-modal">
	<div class="modal-header">
		<h2 class="modal-title">Warning Details</h2>
		<button class="close-btn" on:click={onClose}>
			<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
			</svg>
		</button>
	</div>
	
	<div class="modal-body">
		{#if error}
			<div class="error-message">
				<p>Error: {error}</p>
			</div>
		{/if}
		
		{#if updateError}
			<div class="update-error">
				<p>{updateError}</p>
			</div>
		{/if}
		
		<!-- Employee Information -->
		<div class="section">
			<h3 class="section-title">Employee Information</h3>
			<div class="info-grid">
				<div class="info-item">
					<label>Employee Name:</label>
					<span>{warning.hr_employees?.name || 'N/A'}</span>
				</div>
				<div class="info-item">
					<label>Employee ID:</label>
					<span>{warning.hr_employees?.employee_id || 'N/A'}</span>
				</div>
				<div class="info-item">
					<label>Username:</label>
					<span>{warning.username || 'N/A'}</span>
				</div>
				<div class="info-item">
					<label>Branch:</label>
					<span>{warning.branches?.name_en || 'N/A'}</span>
				</div>
			</div>
		</div>
		
		<!-- Warning Information -->
		<div class="section">
			<h3 class="section-title">Warning Details</h3>
			<div class="info-grid">
				<div class="info-item">
					<label>Warning Reference:</label>
					<span class="reference">{warning.warning_reference || 'N/A'}</span>
				</div>
				<div class="info-item">
					<label>Warning Type:</label>
					<span class="badge {getWarningTypeBadge(warning.warning_type).class}">
						{getWarningTypeBadge(warning.warning_type).label}
					</span>
				</div>
				<div class="info-item">
					<label>Severity Level:</label>
					<span class="severity severity-{warning.severity_level}">
						{warning.severity_level || 'medium'}
					</span>
				</div>
				<div class="info-item">
					<label>Language:</label>
					<span>{warning.language_code || 'en'}</span>
				</div>
			</div>
			
			<div class="info-item full-width">
				<label>Warning Text:</label>
				<div class="warning-text">
					{warning.warning_text || 'No warning text available'}
				</div>
			</div>
		</div>
		
		<!-- Task Information (if applicable) -->
		{#if warning.task_id || warning.assignment_id}
			<div class="section">
				<h3 class="section-title">Task Information</h3>
				<div class="info-grid">
					<div class="info-item">
						<label>Task Title:</label>
						<span>{warning.task_title || 'N/A'}</span>
					</div>
					<div class="info-item">
						<label>Total Assigned:</label>
						<span>{warning.total_tasks_assigned || 0}</span>
					</div>
					<div class="info-item">
						<label>Completed:</label>
						<span>{warning.total_tasks_completed || 0}</span>
					</div>
					<div class="info-item">
						<label>Overdue:</label>
						<span>{warning.total_tasks_overdue || 0}</span>
					</div>
					<div class="info-item">
						<label>Completion Rate:</label>
						<span>{warning.completion_rate || 0}%</span>
					</div>
				</div>
				
				{#if warning.task_description}
					<div class="info-item full-width">
						<label>Task Description:</label>
						<div class="task-description">
							{warning.task_description}
						</div>
					</div>
				{/if}
			</div>
		{/if}
		
		<!-- Fine Information (if applicable) -->
		{#if warning.has_fine}
			<div class="section">
				<h3 class="section-title">Fine Information</h3>
				<div class="info-grid">
					<div class="info-item">
						<label>Fine Amount:</label>
						<span class="fine-amount">
							{formatCurrency(warning.fine_amount, warning.fine_currency)}
						</span>
					</div>
					<div class="info-item">
						<label>Fine Status:</label>
						<select bind:value={editableFineStatus} class="status-select">
							<option value="pending">Pending</option>
							<option value="paid">Paid</option>
							<option value="waived">Waived</option>
							<option value="cancelled">Cancelled</option>
						</select>
					</div>
					<div class="info-item">
						<label>Due Date:</label>
						<span>{warning.fine_due_date ? formatDate(warning.fine_due_date) : 'N/A'}</span>
					</div>
					<div class="info-item">
						<label>Paid Date:</label>
						<span>{warning.fine_paid_date ? formatDate(warning.fine_paid_date) : 'N/A'}</span>
					</div>
				</div>
				
				{#if warning.fine_status !== 'paid'}
					<div class="fine-actions">
						<button 
							class="btn btn-success"
							on:click={markFineAsPaid}
							disabled={isUpdating}
						>
							{isUpdating ? 'Processing...' : 'Mark as Paid'}
						</button>
					</div>
				{/if}
			</div>
		{/if}
		
		<!-- Status and Management -->
		<div class="section">
			<h3 class="section-title">Status Management</h3>
			<div class="info-grid">
				<div class="info-item">
					<label>Current Status:</label>
					<select bind:value={editableStatus} class="status-select">
						<option value="active">Active</option>
						<option value="acknowledged">Acknowledged</option>
						<option value="resolved">Resolved</option>
						<option value="escalated">Escalated</option>
						<option value="cancelled">Cancelled</option>
					</select>
				</div>
				<div class="info-item">
					<label>Issued By:</label>
					<span>{warning.issued_by_username || 'N/A'}</span>
				</div>
				<div class="info-item">
					<label>Issued Date:</label>
					<span>{formatDate(warning.issued_at)}</span>
				</div>
				<div class="info-item">
					<label>Last Updated:</label>
					<span>{formatDate(warning.updated_at)}</span>
				</div>
			</div>
			
			<div class="info-item full-width">
				<label>Resolution Notes:</label>
				<textarea 
					bind:value={editableNotes}
					class="notes-textarea"
					placeholder="Add resolution notes..."
					rows="3"
				></textarea>
			</div>
			
			<div class="status-actions">
				<button 
					class="btn btn-primary"
					on:click={updateWarningStatus}
					disabled={isUpdating}
				>
					{isUpdating ? 'Updating...' : 'Update Warning'}
				</button>
			</div>
		</div>
		
		<!-- Timestamps -->
		<div class="section">
			<h3 class="section-title">Timeline</h3>
			<div class="timeline">
				<div class="timeline-item">
					<strong>Created:</strong> {formatDate(warning.created_at)}
				</div>
				{#if warning.acknowledged_at}
					<div class="timeline-item">
						<strong>Acknowledged:</strong> {formatDate(warning.acknowledged_at)}
					</div>
				{/if}
				{#if warning.resolved_at}
					<div class="timeline-item">
						<strong>Resolved:</strong> {formatDate(warning.resolved_at)}
					</div>
				{/if}
			</div>
		</div>
	</div>
</div>

<style>
	.warning-details-modal {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: white;
		border-radius: 8px;
		overflow: hidden;
	}
	
	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
		background: #f9fafb;
	}
	
	.modal-title {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}
	
	.close-btn {
		background: none;
		border: none;
		color: #6b7280;
		cursor: pointer;
		padding: 4px;
		border-radius: 4px;
	}
	
	.close-btn:hover {
		background: #f3f4f6;
		color: #374151;
	}
	
	.modal-body {
		flex: 1;
		overflow-y: auto;
		padding: 24px;
	}
	
	.section {
		margin-bottom: 32px;
		padding-bottom: 24px;
		border-bottom: 1px solid #f3f4f6;
	}
	
	.section:last-child {
		border-bottom: none;
		margin-bottom: 0;
	}
	
	.section-title {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 16px 0;
	}
	
	.info-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 16px;
		margin-bottom: 16px;
	}
	
	.info-item {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}
	
	.info-item.full-width {
		grid-column: 1 / -1;
	}
	
	.info-item label {
		font-size: 12px;
		font-weight: 500;
		color: #6b7280;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}
	
	.info-item span {
		font-size: 14px;
		color: #111827;
	}
	
	.reference {
		font-family: monospace;
		background: #f3f4f6;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
	}
	
	.badge {
		display: inline-block;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
		text-align: center;
		max-width: fit-content;
	}
	
	.severity {
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
		text-transform: capitalize;
	}
	
	.severity-low { background: #d1fae5; color: #065f46; }
	.severity-medium { background: #fef3c7; color: #92400e; }
	.severity-high { background: #fed7aa; color: #9a3412; }
	.severity-critical { background: #fecaca; color: #991b1b; }
	
	.warning-text, .task-description {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		padding: 12px;
		font-size: 14px;
		line-height: 1.5;
		white-space: pre-wrap;
	}
	
	.fine-amount {
		font-size: 16px;
		font-weight: 600;
		color: #dc2626;
	}
	
	.status-select, .notes-textarea {
		border: 1px solid #d1d5db;
		border-radius: 6px;
		padding: 8px 12px;
		font-size: 14px;
		background: white;
	}
	
	.status-select:focus, .notes-textarea:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}
	
	.notes-textarea {
		width: 100%;
		resize: vertical;
		min-height: 80px;
	}
	
	.btn {
		padding: 8px 16px;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		border: none;
		cursor: pointer;
		transition: all 0.2s;
	}
	
	.btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
	
	.btn-primary {
		background: #3b82f6;
		color: white;
	}
	
	.btn-primary:hover:not(:disabled) {
		background: #2563eb;
	}
	
	.btn-success {
		background: #10b981;
		color: white;
	}
	
	.btn-success:hover:not(:disabled) {
		background: #059669;
	}
	
	.fine-actions, .status-actions {
		margin-top: 16px;
		display: flex;
		gap: 12px;
	}
	
	.timeline {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	
	.timeline-item {
		font-size: 14px;
		color: #6b7280;
	}
	
	.timeline-item strong {
		color: #111827;
	}
	
	.error-message, .update-error {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 12px;
		border-radius: 6px;
		margin-bottom: 16px;
		font-size: 14px;
	}
</style>