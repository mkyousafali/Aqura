<script>
	import { onMount } from 'svelte';
	import { dataService } from '$lib/utils/dataService';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import EmployeeDocumentManager from '$lib/components/desktop-interface/master/hr/EmployeeDocumentManager.svelte';

	// State management
	let branches = [];
	let employees = [];
	let documents = [];
	let selectedBranch = '';
	let isLoading = false;
	let errorMessage = '';



	onMount(async () => {
		await loadBranches();
	});

	async function loadBranches() {
		isLoading = true;
		errorMessage = '';

		try {
			const result = await dataService.branches.getAll();
			if (result.error) {
				throw new Error(result.error);
			}
			branches = result.data || [];
		} catch (error) {
			console.error('Failed to load branches:', error);
			errorMessage = 'Failed to load branches';
			branches = [];
		} finally {
			isLoading = false;
		}
	}

	async function loadEmployeesByBranch(branchId) {
		if (!branchId) {
			employees = [];
			documents = [];
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			// Load employees for the branch
			const employeesResult = await dataService.hrEmployees.getByBranch(branchId.toString());
			if (employeesResult.error) {
				throw new Error(employeesResult.error);
			}
			
			// Load documents for the branch
			const documentsResult = await dataService.hrDocuments.getByBranch(parseInt(branchId));
			if (documentsResult.error) {
				throw new Error(documentsResult.error);
			}
			
			employees = employeesResult.data || [];
			documents = documentsResult.data || [];
			
			// Debug: Log the first employee to see the actual structure
			if (employees.length > 0) {
				console.log('Employee data structure:', employees[0]);
				console.log('Available fields:', Object.keys(employees[0]));
				
				// Check for department-related fields
				const deptFields = Object.keys(employees[0]).filter(key => 
					key.toLowerCase().includes('dept') || 
					key.toLowerCase().includes('department')
				);
				console.log('Department-related fields:', deptFields);
				
				// Check for position-related fields  
				const posFields = Object.keys(employees[0]).filter(key => 
					key.toLowerCase().includes('pos') || 
					key.toLowerCase().includes('title') ||
					key.toLowerCase().includes('job')
				);
				console.log('Position-related fields:', posFields);
			}
			
			// Merge document counts with employees
			employees = employees.map(employee => ({
				...employee,
				documentCount: documents.filter(doc => doc.employee_id === employee.id).length,
				expiring_documents: documents.filter(doc => {
					if (!doc.employee_id === employee.id || !doc.expiry_date) return false;
					const expiry = new Date(doc.expiry_date);
					const today = new Date();
					const daysDiff = Math.ceil((expiry.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
					return daysDiff <= 30 && daysDiff >= 0;
				}).length
			}));
			
		} catch (error) {
			console.error('Failed to load employees and documents:', error);
			errorMessage = 'Failed to load employees and documents';
			employees = [];
			documents = [];
		} finally {
			isLoading = false;
		}
	}

	function openDocumentWindow(employee) {
		const windowId = `employee-documents-${employee.id}-${Date.now()}`;
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `📄 Document Management - ${employee.name} (#${instanceNumber})`,
			component: EmployeeDocumentManager,
			props: { employee },
			icon: '📄',
			size: { width: 1000, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}



	function getBranchName(branchId) {
		const branch = branches.find(b => b.id === parseInt(branchId));
		return branch ? `${branch.name_en || branch.name_ar || 'Unknown'} - ${branch.location_en || branch.location_ar || 'Unknown Location'}` : 'Unknown Branch';
	}

	function getStatusColor(status) {
		return status === 'active' ? 'text-green-600 bg-green-50' : 'text-red-600 bg-red-50';
	}

	// Reactive statement to load employees when branch is selected
	$: if (selectedBranch) {
		loadEmployeesByBranch(selectedBranch);
	}
</script>

<div class="document-management">
	<!-- Header -->
	<div class="header">
		<h2 class="title">Document Management</h2>
		<p class="subtitle">Manage employee documents, certificates, and file uploads</p>
	</div>

	<!-- Content -->
	<div class="content">
		<!-- Branch Selection -->
		<div class="branch-selection">
			<div class="selection-header">
				<h3>Select Branch</h3>
				<p>Choose a branch to view and manage employee documents</p>
			</div>
			
			<select 
				bind:value={selectedBranch}
				disabled={isLoading}
				class="branch-select"
			>
				<option value="">Choose a branch...</option>
				{#each branches as branch}
					<option value={branch.id}>
						{branch.name_en || branch.name_ar || 'Unknown'} - {branch.location_en || branch.location_ar || 'Unknown Location'}
					</option>
				{/each}
			</select>
		</div>

		<!-- Messages -->
		{#if errorMessage}
			<div class="error-message">
				<strong>Error:</strong> {errorMessage}
			</div>
		{/if}

		<!-- Employees Table -->
		{#if selectedBranch}
			<div class="employees-section">
				<div class="section-header">
					<h3>Employees in {getBranchName(parseInt(selectedBranch))}</h3>
					<div class="employee-count">
						{employees.length} employee{employees.length !== 1 ? 's' : ''}
					</div>
				</div>

				{#if isLoading && employees.length === 0}
					<div class="loading-state">
						<div class="spinner large"></div>
						<p>Loading employees...</p>
					</div>
				{:else if employees.length === 0}
					<div class="empty-state">
						<div class="empty-icon">👥</div>
						<h4>No Employees Found</h4>
						<p>No employees found in the selected branch</p>
					</div>
				{:else}
					<div class="table-container">
						<table class="employees-table">
							<thead>
								<tr>
									<th>Employee ID</th>
									<th>Name</th>
									<th>Department</th>
									<th>Position</th>
									<th>Documents Count</th>
									<th>Expiring Soon</th>
									<th>Status</th>
									<th>Actions</th>
								</tr>
							</thead>
							<tbody>
								{#each employees as employee (employee.id)}
									<tr class="table-row">
										<td class="employee-id">{employee.employee_id}</td>
										<td class="employee-name">
											<div class="name-container">
												<div class="name-en">{employee.name}</div>
											</div>
										</td>
										<td class="department">{employee.department || employee.department_name || employee.dept || 'N/A'}</td>
										<td class="position">{employee.position || employee.position_title || employee.job_title || 'N/A'}</td>
										<td class="document-count">
											<span class="count-badge">
												{employee.documentCount || 0} documents
											</span>
										</td>
										<td class="expiring-docs">
											{#if employee.expiring_documents && employee.expiring_documents > 0}
												<span class="expiring-badge warning">
													{employee.expiring_documents} expiring
												</span>
											{:else}
												<span class="expiring-badge good">All current</span>
											{/if}
										</td>
										<td class="status">
											<span class="status-badge {getStatusColor(employee.status)}">
												{employee.status === 'active' ? 'Active' : 'Inactive'}
											</span>
										</td>
										<td class="actions">
											<button 
												class="manage-btn"
												on:click={() => openDocumentWindow(employee)}
												disabled={isLoading}
												title="Manage Documents"
											>
												<span class="icon">📄</span>
												Manage Documents
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>



<style>
	.document-management {
		padding: 24px;
		height: 100%;
		overflow-y: auto;
		background: white;
	}

	.header {
		margin-bottom: 32px;
		text-align: center;
	}

	.title {
		font-size: 28px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.subtitle {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.content {
		max-width: 1600px;
		margin: 0 auto;
		display: flex;
		flex-direction: column;
		gap: 32px;
	}

	.branch-selection {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 24px;
	}

	.selection-header {
		margin-bottom: 20px;
	}

	.selection-header h3 {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.selection-header p {
		color: #6b7280;
		margin: 0;
	}

	.branch-select {
		width: 100%;
		max-width: 500px;
		padding: 12px 16px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 16px;
		background: white;
		font-family: inherit;
		transition: all 0.2s;
	}

	.branch-select:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
	}

	.branch-select:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.error-message, .success-message {
		padding: 12px 16px;
		border-radius: 8px;
		margin-bottom: 20px;
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
	}

	.success-message {
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		color: #059669;
	}

	.employees-section {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		overflow: hidden;
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
	}

	.section-header h3 {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.employee-count {
		background: #3b82f6;
		color: white;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 14px;
		font-weight: 500;
	}

	.loading-state, .empty-state {
		padding: 48px;
		text-align: center;
		color: #6b7280;
	}

	.spinner {
		border: 2px solid #f3f4f6;
		border-top: 2px solid #3b82f6;
		border-radius: 50%;
		width: 16px;
		height: 16px;
		animation: spin 1s linear infinite;
		display: inline-block;
	}

	.spinner.large {
		width: 24px;
		height: 24px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.empty-icon {
		font-size: 48px;
		margin-bottom: 16px;
	}

	.empty-state h4 {
		margin: 0 0 8px 0;
		color: #111827;
	}

	.empty-state p {
		margin: 0;
	}

	.table-container {
		overflow-x: auto;
	}

	.employees-table {
		width: 100%;
		border-collapse: collapse;
	}

	.employees-table th {
		background: #f9fafb;
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.employees-table td {
		padding: 16px;
		border-bottom: 1px solid #f3f4f6;
		vertical-align: top;
	}

	.table-row:hover {
		background: #f9fafb;
	}

	.employee-id {
		font-family: 'Courier New', monospace;
		font-weight: 600;
		color: #3b82f6;
		min-width: 100px;
	}

	.name-container {
		display: flex;
		flex-direction: column;
		gap: 4px;
		min-width: 200px;
	}

	.name-en {
		font-weight: 500;
		color: #111827;
	}

	.department, .position {
		color: #4b5563;
		min-width: 120px;
	}

	.count-badge {
		background: #e0e7ff;
		color: #3730a3;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		white-space: nowrap;
	}

	.expiring-badge {
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		white-space: nowrap;
	}

	.expiring-badge.warning {
		background: #fef3c7;
		color: #d97706;
	}

	.expiring-badge.good {
		background: #d1fae5;
		color: #059669;
	}

	.status-badge {
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		display: inline-block;
	}

	.manage-btn {
		background: #7c3aed;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 12px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 6px;
		transition: all 0.2s;
		white-space: nowrap;
	}

	.manage-btn:hover:not(:disabled) {
		background: #6d28d9;
		transform: translateY(-1px);
	}

	.manage-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.icon {
		font-size: 14px;
	}



	@media (max-width: 768px) {
		.section-header {
			flex-direction: column;
			gap: 12px;
			align-items: flex-start;
		}

		.employees-table th,
		.employees-table td {
			padding: 8px 12px;
			font-size: 14px;
		}

		.name-container {
			min-width: unset;
		}


	}
</style>