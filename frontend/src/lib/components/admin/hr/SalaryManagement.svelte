<script>
	import { onMount } from 'svelte';
	import { windowManager } from '../../../stores/windowManager';
	import EmployeeSalary from './EmployeeSalary.svelte';

	// Props
	export let onClose = () => {};

	// Component state
	let selectedBranch = '';
	let filteredEmployees = [];
	let isLoading = false;
	let searchQuery = '';

	// Mock data
	const mockBranches = [
		{ id: 'BR001', name_en: 'Main Office', name_ar: 'المكتب الرئيسي', city: 'Riyadh' },
		{ id: 'BR002', name_en: 'North Branch', name_ar: 'الفرع الشمالي', city: 'Dammam' },
		{ id: 'BR003', name_en: 'West Branch', name_ar: 'الفرع الغربي', city: 'Jeddah' },
		{ id: 'BR004', name_en: 'South Branch', name_ar: 'الفرع الجنوبي', city: 'Abha' }
	];

	const mockEmployeesData = [
		{
			id: 'EMP001',
			employee_id: 'AQ-2024-001',
			name_en: 'Ahmed Al-Salem',
			name_ar: 'أحمد السالم',
			position: 'Senior Manager',
			department: 'Operations',
			branch_id: 'BR001',
			email: 'ahmed.salem@aqura.com',
			phone: '+966501234567',
			hire_date: '2021-03-15',
			status: 'active',
			salary: {
				basicSalary: 12000,
				bonus: { amount: 2000, enabled: true },
				foodAllowance: { amount: 800, enabled: true },
				accommodationAllowance: { amount: 3000, enabled: true },
				travelAllowance: { amount: 500, enabled: false },
				otherAllowances: [
					{ name: 'Transportation', amount: 600, enabled: true },
					{ name: '', amount: 0, enabled: false },
					{ name: '', amount: 0, enabled: false },
					{ name: '', amount: 0, enabled: false }
				],
				cuttings: [
					{ 
						name: 'Insurance', 
						amount: 200, 
						enabled: true,
						applicationType: 'single',
						singleMonth: '09-2025',
						startMonth: '',
						endMonth: ''
					},
					{ 
						name: 'Tax Deduction', 
						amount: 150, 
						enabled: true,
						applicationType: 'multiple',
						singleMonth: '',
						startMonth: '09-2025',
						endMonth: '12-2025'
					},
					{ 
						name: '', 
						amount: 0, 
						enabled: false,
						applicationType: 'single',
						singleMonth: '',
						startMonth: '',
						endMonth: ''
					},
					{ 
						name: '', 
						amount: 0, 
						enabled: false,
						applicationType: 'single',
						singleMonth: '',
						startMonth: '',
						endMonth: ''
					}
				],
				lastUpdated: '2025-09-20T10:30:00Z'
			}
		},
		{
			id: 'EMP002',
			employee_id: 'AQ-2024-002',
			name_en: 'Fatima Al-Zahra',
			name_ar: 'فاطمة الزهراء',
			position: 'HR Specialist',
			department: 'Human Resources',
			branch_id: 'BR001',
			email: 'fatima.zahra@aqura.com',
			phone: '+966501234568',
			hire_date: '2021-08-20',
			status: 'active',
			salary: {
				basicSalary: 8000,
				bonus: { amount: 1000, enabled: true },
				foodAllowance: { amount: 600, enabled: true },
				accommodationAllowance: { amount: 2000, enabled: true },
				travelAllowance: { amount: 300, enabled: true },
				otherAllowances: [
					{ name: 'Mobile Allowance', amount: 200, enabled: true },
					{ name: 'Internet Allowance', amount: 150, enabled: true },
					{ name: '', amount: 0, enabled: false },
					{ name: '', amount: 0, enabled: false }
				],
				cuttings: [
					{ 
						name: 'Insurance', 
						amount: 120, 
						enabled: true,
						applicationType: 'multiple',
						singleMonth: '',
						startMonth: '07-2025',
						endMonth: '12-2025'
					},
					{ 
						name: '', 
						amount: 0, 
						enabled: false,
						applicationType: 'single',
						singleMonth: '',
						startMonth: '',
						endMonth: ''
					},
					{ 
						name: '', 
						amount: 0, 
						enabled: false,
						applicationType: 'single',
						singleMonth: '',
						startMonth: '',
						endMonth: ''
					},
					{ 
						name: '', 
						amount: 0, 
						enabled: false,
						applicationType: 'single',
						singleMonth: '',
						startMonth: '',
						endMonth: ''
					}
				],
				lastUpdated: '2025-09-15T14:20:00Z'
			}
		},
		{
			id: 'EMP003',
			employee_id: 'AQ-2024-003',
			name_en: 'Mohammed Al-Rashid',
			name_ar: 'محمد الراشد',
			position: 'Sales Executive',
			department: 'Sales',
			branch_id: 'BR002',
			email: 'mohammed.rashid@aqura.com',
			phone: '+966501234569',
			hire_date: '2022-01-10',
			status: 'active',
			salary: {
				basicSalary: 6500,
				bonus: { amount: 1500, enabled: true },
				foodAllowance: { amount: 500, enabled: true },
				accommodationAllowance: { amount: 1800, enabled: true },
				travelAllowance: { amount: 800, enabled: true },
				otherAllowances: [
					{ name: 'Commission', amount: 1200, enabled: true },
					{ name: '', amount: 0, enabled: false },
					{ name: '', amount: 0, enabled: false },
					{ name: '', amount: 0, enabled: false }
				],
				cuttings: [
					{ 
						name: 'Insurance', 
						amount: 100, 
						enabled: true,
						applicationType: 'single',
						singleMonth: '09-2025',
						startMonth: '',
						endMonth: ''
					},
					{ 
						name: 'Loan Deduction', 
						amount: 300, 
						enabled: true,
						applicationType: 'multiple',
						singleMonth: '',
						startMonth: '09-2025',
						endMonth: '03-2026'
					},
					{ 
						name: '', 
						amount: 0, 
						enabled: false,
						applicationType: 'single',
						singleMonth: '',
						startMonth: '',
						endMonth: ''
					},
					{ 
						name: '', 
						amount: 0, 
						enabled: false,
						applicationType: 'single',
						singleMonth: '',
						startMonth: '',
						endMonth: ''
					}
				],
				lastUpdated: '2025-09-18T09:15:00Z'
			}
		},
		{
			id: 'EMP004',
			employee_id: 'AQ-2024-004',
			name_en: 'Sarah Al-Mansouri',
			name_ar: 'سارة المنصوري',
			position: 'Accountant',
			department: 'Finance',
			branch_id: 'BR003',
			email: 'sarah.mansouri@aqura.com',
			phone: '+966501234570',
			hire_date: '2022-06-15',
			status: 'active',
			salary: {
				basicSalary: 7000,
				bonus: { amount: 800, enabled: false },
				foodAllowance: { amount: 600, enabled: true },
				accommodationAllowance: { amount: 2200, enabled: true },
				travelAllowance: { amount: 0, enabled: false },
				otherAllowances: [
					{ name: '', amount: 0, enabled: false },
					{ name: '', amount: 0, enabled: false },
					{ name: '', amount: 0, enabled: false },
					{ name: '', amount: 0, enabled: false }
				],
				cuttings: [
					{ 
						name: 'Insurance', 
						amount: 105, 
						enabled: true,
						applicationType: 'single',
						singleMonth: '09-2025',
						startMonth: '',
						endMonth: ''
					},
					{ 
						name: '', 
						amount: 0, 
						enabled: false,
						applicationType: 'single',
						singleMonth: '',
						startMonth: '',
						endMonth: ''
					},
					{ 
						name: '', 
						amount: 0, 
						enabled: false,
						applicationType: 'single',
						singleMonth: '',
						startMonth: '',
						endMonth: ''
					},
					{ 
						name: '', 
						amount: 0, 
						enabled: false,
						applicationType: 'single',
						singleMonth: '',
						startMonth: '',
						endMonth: ''
					}
				]
			}
		},
		{
			id: 'EMP005',
			employee_id: 'AQ-2024-005',
			name_en: 'Omar Al-Khaled',
			name_ar: 'عمر الخالد',
			position: 'IT Technician',
			department: 'Information Technology',
			branch_id: 'BR001',
			email: 'omar.khaled@aqura.com',
			phone: '+966501234571',
			hire_date: '2023-02-28',
			status: 'active'
			// No salary data - will show as needs setup
		},
		{
			id: 'EMP006',
			employee_id: 'AQ-2024-006',
			name_en: 'Aisha Al-Badawi',
			name_ar: 'عائشة البدوي',
			position: 'Marketing Coordinator',
			department: 'Marketing',
			branch_id: 'BR004',
			email: 'aisha.badawi@aqura.com',
			phone: '+966501234572',
			hire_date: '2023-09-05',
			status: 'active'
			// No salary data - will show as needs setup
		}
	];

	onMount(() => {
		// Auto-select first branch if available
		if (mockBranches.length > 0) {
			selectedBranch = mockBranches[0].id;
			loadEmployees();
		}
	});

	function loadEmployees() {
		if (!selectedBranch) {
			filteredEmployees = [];
			return;
		}

		isLoading = true;

		// Simulate API call
		setTimeout(() => {
			filteredEmployees = mockEmployeesData.filter(emp => emp.branch_id === selectedBranch);
			filterEmployees();
			isLoading = false;
		}, 500);
	}

	function filterEmployees() {
		if (!searchQuery.trim()) {
			filteredEmployees = mockEmployeesData.filter(emp => emp.branch_id === selectedBranch);
		} else {
			const query = searchQuery.toLowerCase();
			filteredEmployees = mockEmployeesData
				.filter(emp => emp.branch_id === selectedBranch)
				.filter(emp => 
					emp.name_en.toLowerCase().includes(query) ||
					emp.name_ar.includes(query) ||
					emp.employee_id.toLowerCase().includes(query) ||
					emp.position.toLowerCase().includes(query) ||
					emp.department.toLowerCase().includes(query)
				);
		}
	}

	function openSalaryWindow(employee) {
		const windowId = `employee-salary-${employee.id}`;
		
		// Check if window is already open
		if (windowManager.getWindow(windowId)) {
			// Focus existing window
			windowManager.focusWindow(windowId);
			return;
		}

		// Open new salary management window
		windowManager.openWindow({
			id: windowId,
			title: `💰 Salary Management - ${employee.name_en} (${employee.employee_id})`,
			component: EmployeeSalary,
			props: {
				employee: { ...employee },
				onClose: () => windowManager.closeWindow(windowId),
				mockEmployeesData: mockEmployeesData
			},
			width: 1200,
			height: 800,
			x: 100 + Math.random() * 200,
			y: 50 + Math.random() * 100,
			minWidth: 800,
			minHeight: 600
		});
	}

	function formatCurrency(amount) {
		if (typeof amount !== 'number') return 'SAR 0.00';
		return new Intl.NumberFormat('en-SA', {
			style: 'currency',
			currency: 'SAR',
			minimumFractionDigits: 2
		}).format(amount);
	}

	function calculateNetSalary(employee) {
		const salary = employee.salary;
		if (!salary) return 0;

		let total = salary.basicSalary || 0;
		
		// Add allowances
		if (salary.bonus?.enabled) total += salary.bonus.amount || 0;
		if (salary.foodAllowance?.enabled) total += salary.foodAllowance.amount || 0;
		if (salary.accommodationAllowance?.enabled) total += salary.accommodationAllowance.amount || 0;
		if (salary.travelAllowance?.enabled) total += salary.travelAllowance.amount || 0;
		
		salary.otherAllowances?.forEach(allowance => {
			if (allowance.enabled && allowance.name) {
				total += allowance.amount || 0;
			}
		});

		// Subtract cuttings
		salary.cuttings?.forEach(cutting => {
			if (cutting.enabled && cutting.name) {
				total -= cutting.amount || 0;
			}
		});

		return total;
	}

	function getSalaryStatus(employee) {
		if (!employee.salary || !employee.salary.basicSalary) {
			return { status: 'not-set', label: 'Not Set', class: 'status-not-set' };
		}
		
		const lastUpdated = employee.salary.lastUpdated;
		if (!lastUpdated) {
			return { status: 'needs-review', label: 'Needs Review', class: 'status-needs-review' };
		}

		const updateDate = new Date(lastUpdated);
		const now = new Date();
		const daysDiff = Math.floor((now - updateDate) / (1000 * 60 * 60 * 24));

		if (daysDiff > 30) {
			return { status: 'outdated', label: 'Outdated', class: 'status-outdated' };
		} else if (daysDiff > 7) {
			return { status: 'needs-review', label: 'Needs Review', class: 'status-needs-review' };
		}

		return { status: 'current', label: 'Current', class: 'status-current' };
	}

	function formatLastUpdated(employee) {
		if (!employee.salary?.lastUpdated) return 'Never';
		
		const date = new Date(employee.salary.lastUpdated);
		return date.toLocaleDateString('en-SA', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	$: if (selectedBranch) {
		loadEmployees();
	}

	$: if (searchQuery !== undefined) {
		filterEmployees();
	}
</script>

<div class="salary-management">
	<!-- Header -->
	<div class="salary-header">
		<div class="header-content">
			<h2>💰 Salary & Wage Management</h2>
			<p class="header-description">Manage employee salaries, allowances, and deductions</p>
		</div>
	</div>

	<!-- Controls -->
	<div class="salary-controls">
		<div class="control-group">
			<label class="control-label">
				<span class="label-text">Branch</span>
				<select bind:value={selectedBranch} class="branch-select" disabled={isLoading}>
					<option value="">Select Branch</option>
					{#each mockBranches as branch}
						<option value={branch.id}>{branch.name_en} - {branch.city}</option>
					{/each}
				</select>
			</label>
		</div>

		{#if selectedBranch}
			<div class="control-group">
				<label class="control-label">
					<span class="label-text">Search Employees</span>
					<div class="search-container">
						<span class="search-icon">🔍</span>
						<input
							type="text"
							bind:value={searchQuery}
							placeholder="Search by name, ID, position..."
							class="search-input"
							disabled={isLoading}
						>
					</div>
				</label>
			</div>
		{/if}
	</div>

	<!-- Employee List -->
	{#if selectedBranch}
		<div class="employees-section">
			{#if isLoading}
				<div class="loading-state">
					<div class="spinner"></div>
					<p>Loading employees...</p>
				</div>
			{:else if filteredEmployees.length === 0}
				<div class="empty-state">
					<div class="empty-icon">👥</div>
					<h3>No employees found</h3>
					{#if searchQuery}
						<p>No employees match your search criteria.</p>
						<button 
							class="clear-search-btn"
							on:click={() => searchQuery = ''}
						>
							Clear Search
						</button>
					{:else}
						<p>No employees are assigned to this branch.</p>
					{/if}
				</div>
			{:else}
				<div class="employees-table-container">
					<div class="table-header">
						<h3>Employees ({filteredEmployees.length})</h3>
						<div class="table-info">
							<span class="branch-info">
								{mockBranches.find(b => b.id === selectedBranch)?.name_en}
							</span>
						</div>
					</div>

					<div class="table-wrapper">
						<table class="employees-table">
							<thead>
								<tr>
									<th>Employee ID</th>
									<th>Name</th>
									<th>Position</th>
									<th>Department</th>
									<th>Basic Salary</th>
									<th>Net Salary</th>
									<th>Status</th>
									<th>Last Updated</th>
									<th>Actions</th>
								</tr>
							</thead>
							<tbody>
								{#each filteredEmployees as employee}
									{@const salaryStatus = getSalaryStatus(employee)}
									<tr class="employee-row">
										<td>
											<div class="employee-id">
												<span class="id-badge">{employee.employee_id}</span>
											</div>
										</td>
										<td>
											<div class="employee-name">
												<div class="name-en">{employee.name_en}</div>
												<div class="name-ar">{employee.name_ar}</div>
											</div>
										</td>
										<td>
											<span class="position">{employee.position}</span>
										</td>
										<td>
											<span class="department">{employee.department}</span>
										</td>
										<td>
											<div class="salary-amount basic">
												{formatCurrency(employee.salary?.basicSalary || 0)}
											</div>
										</td>
										<td>
											<div class="salary-amount net">
												{formatCurrency(calculateNetSalary(employee))}
											</div>
										</td>
										<td>
											<span class="status-badge {salaryStatus.class}">
												{salaryStatus.label}
											</span>
										</td>
										<td>
											<span class="last-updated">
												{formatLastUpdated(employee)}
											</span>
										</td>
										<td>
											<button
												class="update-btn"
												on:click={() => openSalaryWindow(employee)}
												title="Update salary for {employee.name_en}"
											>
												<span class="btn-icon">✏️</span>
												Update
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{/if}
		</div>
	{:else}
		<div class="no-branch-selected">
			<div class="no-branch-icon">🏢</div>
			<h3>Select a Branch</h3>
			<p>Please select a branch to view and manage employee salaries.</p>
		</div>
	{/if}
</div>

<style>
	.salary-management {
		height: 100%;
		background: white;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.salary-header {
		padding: 24px 28px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		flex-shrink: 0;
	}

	.header-content h2 {
		font-size: 24px;
		font-weight: 600;
		margin: 0 0 8px 0;
	}

	.header-description {
		margin: 0;
		opacity: 0.9;
		font-size: 14px;
	}

	.salary-controls {
		padding: 24px 28px;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
		display: flex;
		gap: 24px;
		flex-wrap: wrap;
		flex-shrink: 0;
	}

	.control-group {
		display: flex;
		flex-direction: column;
		min-width: 250px;
	}

	.control-label {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.label-text {
		font-weight: 500;
		color: #374151;
		font-size: 14px;
	}

	.branch-select {
		padding: 12px 16px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 14px;
		background: white;
		cursor: pointer;
		transition: all 0.2s;
	}

	.branch-select:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.branch-select:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.search-container {
		position: relative;
		display: flex;
		align-items: center;
	}

	.search-icon {
		position: absolute;
		left: 12px;
		font-size: 14px;
		color: #6b7280;
		z-index: 1;
	}

	.search-input {
		width: 100%;
		padding: 12px 16px 12px 40px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 14px;
		background: white;
		transition: all 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.search-input:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.employees-section {
		flex: 1;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.loading-state, .empty-state, .no-branch-selected {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-align: center;
		padding: 48px 24px;
		color: #6b7280;
	}

	.spinner {
		width: 32px;
		height: 32px;
		border: 3px solid rgba(102, 126, 234, 0.1);
		border-top: 3px solid #667eea;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.empty-icon, .no-branch-icon {
		font-size: 48px;
		margin-bottom: 16px;
	}

	.empty-state h3, .no-branch-selected h3 {
		font-size: 18px;
		font-weight: 600;
		color: #374151;
		margin: 0 0 8px 0;
	}

	.empty-state p, .no-branch-selected p {
		margin: 0 0 16px 0;
		color: #6b7280;
	}

	.clear-search-btn {
		padding: 8px 16px;
		background: #667eea;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		transition: all 0.2s;
	}

	.clear-search-btn:hover {
		background: #5a67d8;
	}

	.employees-table-container {
		flex: 1;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		margin: 24px 28px 24px 28px;
		border: 1px solid #e2e8f0;
		border-radius: 12px;
		background: white;
	}

	.table-header {
		padding: 20px 24px;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
		display: flex;
		justify-content: space-between;
		align-items: center;
		border-radius: 12px 12px 0 0;
	}

	.table-header h3 {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.branch-info {
		background: #667eea;
		color: white;
		padding: 4px 12px;
		border-radius: 20px;
		font-size: 12px;
		font-weight: 500;
	}

	.table-wrapper {
		flex: 1;
		overflow: auto;
	}

	.employees-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 14px;
	}

	.employees-table th {
		background: #f9fafb;
		color: #374151;
		font-weight: 600;
		padding: 16px 20px;
		text-align: left;
		border-bottom: 1px solid #e5e7eb;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.employee-row {
		border-bottom: 1px solid #f3f4f6;
		transition: background-color 0.2s;
	}

	.employee-row:hover {
		background: #f9fafb;
	}

	.employees-table td {
		padding: 16px 20px;
		vertical-align: top;
	}

	.employee-id {
		display: flex;
		align-items: center;
	}

	.id-badge {
		background: #3b82f6;
		color: white;
		padding: 4px 8px;
		border-radius: 6px;
		font-family: 'Courier New', monospace;
		font-weight: 600;
		font-size: 11px;
	}

	.employee-name {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.name-en {
		font-weight: 500;
		color: #111827;
	}

	.name-ar {
		font-size: 12px;
		color: #6b7280;
		direction: rtl;
	}

	.position {
		color: #374151;
		font-weight: 500;
	}

	.department {
		color: #6b7280;
		font-size: 13px;
	}

	.salary-amount {
		font-weight: 600;
		font-family: 'Courier New', monospace;
	}

	.salary-amount.basic {
		color: #059669;
	}

	.salary-amount.net {
		color: #3b82f6;
		font-size: 15px;
	}

	.status-badge {
		padding: 4px 10px;
		border-radius: 20px;
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.status-current {
		background: #dcfce7;
		color: #166534;
	}

	.status-needs-review {
		background: #fef3c7;
		color: #92400e;
	}

	.status-outdated {
		background: #fee2e2;
		color: #991b1b;
	}

	.status-not-set {
		background: #f3f4f6;
		color: #4b5563;
	}

	.last-updated {
		color: #6b7280;
		font-size: 13px;
	}

	.update-btn {
		background: #667eea;
		color: white;
		border: none;
		padding: 8px 16px;
		border-radius: 6px;
		cursor: pointer;
		font-size: 13px;
		font-weight: 500;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.update-btn:hover {
		background: #5a67d8;
		transform: translateY(-1px);
	}

	.btn-icon {
		font-size: 12px;
	}

	@media (max-width: 1200px) {
		.employees-table {
			font-size: 12px;
		}

		.employees-table th,
		.employees-table td {
			padding: 12px 16px;
		}

		.salary-controls {
			flex-direction: column;
		}

		.control-group {
			min-width: auto;
		}
	}

	@media (max-width: 768px) {
		.salary-header {
			padding: 16px 20px;
		}

		.salary-controls {
			padding: 16px 20px;
		}

		.employees-table-container {
			margin: 16px 20px;
		}

		.table-header {
			padding: 16px 20px;
		}

		.table-wrapper {
			overflow-x: auto;
		}

		.employees-table {
			min-width: 800px;
		}

		.employees-table th,
		.employees-table td {
			padding: 8px 12px;
		}
	}
</style>