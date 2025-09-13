<script lang="ts">
	import { onMount } from 'svelte';
	import { localeData, t } from '$lib/i18n';
	import { dataService } from '$lib/utils/dataService';
	import type { Employee } from '$lib/utils/supabase';

	// State
	let employees: Employee[] = [];
	let loading = true;
	let error = '';

	// Load employees on component mount
	onMount(async () => {
		try {
			const result = await dataService.employees.getAll();
			if (result.error) {
				error = result.error;
			} else {
				employees = result.data || [];
			}
		} catch (err) {
			error = 'Failed to load employees';
			console.error('Error loading employees:', err);
		} finally {
			loading = false;
		}
	});

	// Mock data for demonstration - in real app this would come from API
	let employeesOld = [
		{
			id: '1',
			employeeId: 'EMP001',
			firstName: 'Ahmed',
			lastName: 'Al-Rahman',
			email: 'ahmed.rahman@aqura.com',
			phone: '+966 50 123 4567',
			department: 'Engineering',
			position: 'Senior Developer',
			branch: 'Riyadh HQ',
			status: 'active',
			hireDate: '2023-01-15',
			salary: 12000
		},
		{
			id: '2',
			employeeId: 'EMP002',
			firstName: 'Fatima',
			lastName: 'Mohammed',
			email: 'fatima.mohammed@aqura.com',
			phone: '+966 55 987 6543',
			department: 'HR',
			position: 'HR Manager',
			branch: 'Jeddah',
			status: 'active',
			hireDate: '2022-06-01',
			salary: 15000
		},
		{
			id: '3',
			employeeId: 'EMP003',
			firstName: 'Omar',
			lastName: 'Hassan',
			email: 'omar.hassan@aqura.com',
			phone: '+966 50 555 1234',
			department: 'Finance',
			position: 'Accountant',
			branch: 'Dammam',
			status: 'inactive',
			hireDate: '2023-03-20',
			salary: 8500
		}
	];

	let searchQuery = '';
	let selectedDepartment = '';
	let selectedStatus = '';
	let showAddModal = false;
	let showEditModal = false;
	let selectedEmployee = null;

	// Form data
	let formData = {
		employeeId: '',
		firstName: '',
		lastName: '',
		email: '',
		phone: '',
		department: '',
		position: '',
		branch: '',
		status: 'active',
		hireDate: '',
		salary: 0
	};

	const departments = ['Engineering', 'HR', 'Finance', 'Sales', 'Marketing', 'Operations'];
	const statuses = ['active', 'inactive', 'pending'];
	const branches = ['Riyadh HQ', 'Jeddah', 'Dammam', 'Mecca', 'Medina'];

	$: filteredEmployees = employees.filter(emp => {
		const matchesSearch = searchQuery === '' || 
			emp.firstName.toLowerCase().includes(searchQuery.toLowerCase()) ||
			emp.lastName.toLowerCase().includes(searchQuery.toLowerCase()) ||
			emp.employeeId.toLowerCase().includes(searchQuery.toLowerCase()) ||
			emp.email.toLowerCase().includes(searchQuery.toLowerCase());
		
		const matchesDepartment = selectedDepartment === '' || emp.department === selectedDepartment;
		const matchesStatus = selectedStatus === '' || emp.status === selectedStatus;
		
		return matchesSearch && matchesDepartment && matchesStatus;
	});

	function resetForm() {
		formData = {
			employeeId: '',
			firstName: '',
			lastName: '',
			email: '',
			phone: '',
			department: '',
			position: '',
			branch: '',
			status: 'active',
			hireDate: '',
			salary: 0
		};
	}

	function openAddModal() {
		resetForm();
		showAddModal = true;
	}

	function closeAddModal() {
		showAddModal = false;
		resetForm();
	}

	function openEditModal(employee) {
		selectedEmployee = employee;
		formData = { ...employee };
		showEditModal = true;
	}

	function closeEditModal() {
		showEditModal = false;
		selectedEmployee = null;
		resetForm();
	}

	function handleAddEmployee() {
		// Generate new ID (in real app, this would be handled by backend)
		const newEmployee = {
			...formData,
			id: (employees.length + 1).toString()
		};
		employees = [...employees, newEmployee];
		closeAddModal();
	}

	function handleEditEmployee() {
		employees = employees.map(emp => 
			emp.id === selectedEmployee.id ? { ...formData, id: selectedEmployee.id } : emp
		);
		closeEditModal();
	}

	function handleDeleteEmployee(employee) {
		if (confirm(`Are you sure you want to delete ${employee.firstName} ${employee.lastName}?`)) {
			employees = employees.filter(emp => emp.id !== employee.id);
		}
	}

	function exportData() {
		// Mock export functionality
		alert('Export functionality will be implemented with actual data export');
	}

	function importData() {
		// Mock import functionality
		alert('Import functionality will be implemented with XLSX import');
	}
</script>

<div class="hr-master">
	<!-- Header -->
	<div class="header">
		<div class="title-section">
			<h1 class="title">👥 {$localeData ? t('admin.hr.title') : 'HR Master'}</h1>
			<p class="subtitle">{$localeData ? t('admin.hr.subtitle') : 'Manage employees and staff'}</p>
		</div>
		
		<div class="header-actions">
			<button class="btn btn-secondary" on:click={importData}>
				📥 Import
			</button>
			<button class="btn btn-secondary" on:click={exportData}>
				📤 Export
			</button>
			<button class="btn btn-primary" on:click={openAddModal}>
				➕ Add Employee
			</button>
		</div>
	</div>

	<!-- Filters -->
	<div class="filters">
		<div class="search-container">
			<input
				bind:value={searchQuery}
				type="text"
				placeholder="Search employees..."
				class="search-input"
			/>
		</div>
		
		<select bind:value={selectedDepartment} class="filter-select">
			<option value="">All Departments</option>
			{#each departments as dept}
				<option value={dept}>{dept}</option>
			{/each}
		</select>
		
		<select bind:value={selectedStatus} class="filter-select">
			<option value="">All Statuses</option>
			{#each statuses as status}
				<option value={status}>{status}</option>
			{/each}
		</select>

		<div class="results-count">
			{filteredEmployees.length} employees found
		</div>
	</div>

	<!-- Stats Cards -->
	<div class="stats-grid">
		<div class="stat-card">
			<div class="stat-value">{employees.filter(e => e.status === 'active').length}</div>
			<div class="stat-label">Active Employees</div>
		</div>
		<div class="stat-card">
			<div class="stat-value">{departments.length}</div>
			<div class="stat-label">Departments</div>
		</div>
		<div class="stat-card">
			<div class="stat-value">{branches.length}</div>
			<div class="stat-label">Branches</div>
		</div>
		<div class="stat-card">
			<div class="stat-value">{employees.filter(e => e.status === 'pending').length}</div>
			<div class="stat-label">Pending Reviews</div>
		</div>
	</div>

	<!-- Employee Table -->
	<div class="table-container">
		<table class="employee-table">
			<thead>
				<tr>
					<th>Employee ID</th>
					<th>Name</th>
					<th>Email</th>
					<th>Department</th>
					<th>Position</th>
					<th>Branch</th>
					<th>Status</th>
					<th>Hire Date</th>
					<th>Actions</th>
				</tr>
			</thead>
			<tbody>
				{#each filteredEmployees as employee}
					<tr>
						<td class="employee-id">{employee.employeeId}</td>
						<td class="employee-name">
							<div class="name-cell">
								<div class="avatar">{(employee.firstName?.[0] || '?')}{(employee.lastName?.[0] || '?')}</div>
								<div>
									<div class="name">{employee.firstName || ''} {employee.lastName || ''}</div>
									<div class="phone">{employee.phone || ''}</div>
								</div>
							</div>
						</td>
						<td class="email">{employee.email || ''}</td>
						<td class="department">{employee.department || ''}</td>
						<td class="position">{employee.position || ''}</td>
						<td class="branch">{employee.branch || ''}</td>
						<td class="status">
							<span class="status-badge status-{employee.status}">
								{employee.status}
							</span>
						</td>
						<td class="hire-date">{employee.hireDate}</td>
						<td class="actions">
							<button 
								class="action-btn edit-btn"
								on:click={() => openEditModal(employee)}
								title="Edit Employee"
							>
								✏️
							</button>
							<button 
								class="action-btn delete-btn"
								on:click={() => handleDeleteEmployee(employee)}
								title="Delete Employee"
							>
								🗑️
							</button>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>

		{#if filteredEmployees.length === 0}
			<div class="empty-state">
				<div class="empty-icon">👥</div>
				<div class="empty-title">No employees found</div>
				<div class="empty-subtitle">Try adjusting your search criteria</div>
			</div>
		{/if}
	</div>
</div>

<!-- Add Employee Modal -->
{#if showAddModal}
	<div class="modal-backdrop" on:click={closeAddModal}>
		<div class="modal" on:click|stopPropagation>
			<div class="modal-header">
				<h2>Add New Employee</h2>
				<button class="modal-close" on:click={closeAddModal}>✕</button>
			</div>
			
			<form class="modal-body" on:submit|preventDefault={handleAddEmployee}>
				<div class="form-row">
					<div class="form-group">
						<label>Employee ID</label>
						<input bind:value={formData.employeeId} type="text" required />
					</div>
					<div class="form-group">
						<label>Status</label>
						<select bind:value={formData.status}>
							{#each statuses as status}
								<option value={status}>{status}</option>
							{/each}
						</select>
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>First Name</label>
						<input bind:value={formData.firstName} type="text" required />
					</div>
					<div class="form-group">
						<label>Last Name</label>
						<input bind:value={formData.lastName} type="text" required />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Email</label>
						<input bind:value={formData.email} type="email" required />
					</div>
					<div class="form-group">
						<label>Phone</label>
						<input bind:value={formData.phone} type="tel" />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Department</label>
						<select bind:value={formData.department} required>
							<option value="">Select Department</option>
							{#each departments as dept}
								<option value={dept}>{dept}</option>
							{/each}
						</select>
					</div>
					<div class="form-group">
						<label>Position</label>
						<input bind:value={formData.position} type="text" required />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Branch</label>
						<select bind:value={formData.branch} required>
							<option value="">Select Branch</option>
							{#each branches as branch}
								<option value={branch}>{branch}</option>
							{/each}
						</select>
					</div>
					<div class="form-group">
						<label>Hire Date</label>
						<input bind:value={formData.hireDate} type="date" required />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Salary (SAR)</label>
						<input bind:value={formData.salary} type="number" min="0" step="500" />
					</div>
				</div>

				<div class="modal-footer">
					<button type="button" class="btn btn-secondary" on:click={closeAddModal}>
						Cancel
					</button>
					<button type="submit" class="btn btn-primary">
						Add Employee
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}

<!-- Edit Employee Modal -->
{#if showEditModal}
	<div class="modal-backdrop" on:click={closeEditModal}>
		<div class="modal" on:click|stopPropagation>
			<div class="modal-header">
				<h2>Edit Employee</h2>
				<button class="modal-close" on:click={closeEditModal}>✕</button>
			</div>
			
			<form class="modal-body" on:submit|preventDefault={handleEditEmployee}>
				<div class="form-row">
					<div class="form-group">
						<label>Employee ID</label>
						<input bind:value={formData.employeeId} type="text" required readonly />
					</div>
					<div class="form-group">
						<label>Status</label>
						<select bind:value={formData.status}>
							{#each statuses as status}
								<option value={status}>{status}</option>
							{/each}
						</select>
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>First Name</label>
						<input bind:value={formData.firstName} type="text" required />
					</div>
					<div class="form-group">
						<label>Last Name</label>
						<input bind:value={formData.lastName} type="text" required />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Email</label>
						<input bind:value={formData.email} type="email" required />
					</div>
					<div class="form-group">
						<label>Phone</label>
						<input bind:value={formData.phone} type="tel" />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Department</label>
						<select bind:value={formData.department} required>
							<option value="">Select Department</option>
							{#each departments as dept}
								<option value={dept}>{dept}</option>
							{/each}
						</select>
					</div>
					<div class="form-group">
						<label>Position</label>
						<input bind:value={formData.position} type="text" required />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Branch</label>
						<select bind:value={formData.branch} required>
							<option value="">Select Branch</option>
							{#each branches as branch}
								<option value={branch}>{branch}</option>
							{/each}
						</select>
					</div>
					<div class="form-group">
						<label>Hire Date</label>
						<input bind:value={formData.hireDate} type="date" required />
					</div>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label>Salary (SAR)</label>
						<input bind:value={formData.salary} type="number" min="0" step="500" />
					</div>
				</div>

				<div class="modal-footer">
					<button type="button" class="btn btn-secondary" on:click={closeEditModal}>
						Cancel
					</button>
					<button type="submit" class="btn btn-primary">
						Update Employee
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}

<style>
	.hr-master {
		padding: 24px;
		height: 100%;
		display: flex;
		flex-direction: column;
		gap: 24px;
		overflow: hidden;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		gap: 16px;
	}

	.title-section {
		flex: 1;
	}

	.title {
		font-size: 24px;
		font-weight: 700;
		margin: 0 0 4px 0;
		color: #1a1a1a;
	}

	.subtitle {
		font-size: 14px;
		color: #666;
		margin: 0;
	}

	.header-actions {
		display: flex;
		gap: 12px;
	}

	.btn {
		padding: 8px 16px;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.btn-primary {
		background: #f08300;
		color: white;
	}

	.btn-primary:hover {
		background: #e07600;
	}

	.btn-secondary {
		background: #f5f5f5;
		color: #333;
		border: 1px solid #ddd;
	}

	.btn-secondary:hover {
		background: #e5e5e5;
	}

	.filters {
		display: flex;
		gap: 16px;
		align-items: center;
		padding: 16px;
		background: #f9f9f9;
		border-radius: 8px;
		border: 1px solid #e0e0e0;
	}

	.search-container {
		flex: 1;
	}

	.search-input {
		width: 100%;
		padding: 8px 12px;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 14px;
	}

	.filter-select {
		padding: 8px 12px;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		min-width: 140px;
	}

	.results-count {
		font-size: 14px;
		color: #666;
		white-space: nowrap;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 16px;
	}

	.stat-card {
		background: white;
		padding: 20px;
		border-radius: 8px;
		border: 1px solid #e0e0e0;
		text-align: center;
	}

	.stat-value {
		font-size: 32px;
		font-weight: 700;
		color: #f08300;
		margin-bottom: 4px;
	}

	.stat-label {
		font-size: 14px;
		color: #666;
	}

	.table-container {
		flex: 1;
		overflow: auto;
		background: white;
		border-radius: 8px;
		border: 1px solid #e0e0e0;
	}

	.employee-table {
		width: 100%;
		border-collapse: collapse;
	}

	.employee-table th {
		background: #f5f5f5;
		padding: 12px;
		text-align: left;
		font-weight: 600;
		font-size: 14px;
		color: #333;
		border-bottom: 1px solid #e0e0e0;
		white-space: nowrap;
	}

	.employee-table td {
		padding: 12px;
		border-bottom: 1px solid #f0f0f0;
		font-size: 14px;
	}

	.name-cell {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.avatar {
		width: 40px;
		height: 40px;
		border-radius: 50%;
		background: #f08300;
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 600;
		font-size: 12px;
	}

	.name {
		font-weight: 500;
		color: #333;
	}

	.phone {
		font-size: 12px;
		color: #666;
	}

	.status-badge {
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
		text-transform: capitalize;
	}

	.status-active {
		background: #e8f5e8;
		color: #13A538;
	}

	.status-inactive {
		background: #f5e8e8;
		color: #d32f2f;
	}

	.status-pending {
		background: #fff3e0;
		color: #f08300;
	}

	.actions {
		display: flex;
		gap: 8px;
	}

	.action-btn {
		width: 32px;
		height: 32px;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}

	.edit-btn {
		background: #fff3e0;
		color: #f08300;
	}

	.edit-btn:hover {
		background: #f08300;
		color: white;
	}

	.delete-btn {
		background: #f5e8e8;
		color: #d32f2f;
	}

	.delete-btn:hover {
		background: #d32f2f;
		color: white;
	}

	.empty-state {
		text-align: center;
		padding: 48px 24px;
		color: #666;
	}

	.empty-icon {
		font-size: 48px;
		margin-bottom: 16px;
	}

	.empty-title {
		font-size: 18px;
		font-weight: 500;
		margin-bottom: 8px;
	}

	.empty-subtitle {
		font-size: 14px;
	}

	/* Modal Styles */
	.modal-backdrop {
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
	}

	.modal {
		background: white;
		border-radius: 8px;
		max-width: 600px;
		width: 90%;
		max-height: 90vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #e0e0e0;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 18px;
		font-weight: 600;
	}

	.modal-close {
		background: none;
		border: none;
		font-size: 18px;
		cursor: pointer;
		color: #666;
		padding: 4px;
	}

	.modal-body {
		padding: 24px;
		overflow-y: auto;
		flex: 1;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
		margin-bottom: 16px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.form-group label {
		font-size: 14px;
		font-weight: 500;
		color: #333;
	}

	.form-group input,
	.form-group select {
		padding: 8px 12px;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 14px;
	}

	.form-group input:focus,
	.form-group select:focus {
		outline: none;
		border-color: #f08300;
	}

	.form-group input[readonly] {
		background: #f5f5f5;
		color: #666;
	}

	.modal-footer {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
		margin-top: 24px;
		padding-top: 16px;
		border-top: 1px solid #e0e0e0;
	}
</style>
