<script>
	import { onMount } from 'svelte';
	import { dataService } from '$lib/utils/dataService';

	// State management
	let branches = [];
	let employees = [];
	let positions = [];
	let branchAssignments = []; // Branch-specific assignments for the employees table
	let selectedBranch = '';
	let searchTerm = '';
	let searchCriteria = 'all'; // 'all', 'name', 'employee_id'
	let filteredEmployees = []; // Add this line
	let isLoading = false;
	let errorMessage = '';
	let successMessage = '';

	// Data arrays loaded from database

	onMount(async () => {
		await loadInitialData();
	});

	async function loadInitialData() {
		isLoading = true;
		errorMessage = '';

		try {
			// Load branches from real database
			const { data: branchesData, error: branchesError } = await dataService.branches.getAll();
			if (branchesError) {
				console.error('Error loading branches:', branchesError);
				errorMessage = 'Failed to load branches: ' + (branchesError.message || branchesError);
				return;
			}
			branches = branchesData || [];

			// Load positions from real database
			const { data: positionsData, error: positionsError } = await dataService.hrPositions.getAll();
			if (positionsError) {
				console.error('Error loading positions:', positionsError);
				errorMessage = 'Failed to load positions: ' + (positionsError.message || positionsError);
				return;
			}
			positions = positionsData || [];
		} catch (error) {
			console.error('Error in loadInitialData:', error);
			errorMessage = error.message || 'Failed to load initial data';
		} finally {
			isLoading = false;
		}
	}

	async function loadEmployeesByBranch(branchId) {
		if (!branchId) {
			employees = [];
			branchAssignments = [];
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			// Load employees and assignments in parallel for better performance
			const [employeesResponse, assignmentsResponse] = await Promise.all([
				dataService.hrEmployees.getByBranch(branchId),
				dataService.hrAssignments.getByBranch(branchId)
			]);

			// Handle employees data
			if (employeesResponse.error) {
				console.error('Error loading employees:', employeesResponse.error);
				errorMessage = 'Failed to load employees: ' + (employeesResponse.error.message || employeesResponse.error);
				employees = [];
				return;
			}
			employees = employeesResponse.data || [];
			
			// Handle assignments data
			if (!assignmentsResponse.error) {
				branchAssignments = assignmentsResponse.data || [];
				console.log('Loaded branch assignments:', branchAssignments.length, branchAssignments);
			} else {
				branchAssignments = [];
				console.error('Error loading branch assignments:', assignmentsResponse.error);
			}

		} catch (error) {
			console.error('Error loading employees by branch:', error);
			errorMessage = error.message || 'Failed to load employees';
			employees = [];
			branchAssignments = [];
		} finally {
			isLoading = false;
		}
	}

	async function assignPosition(employeeId, positionId) {
		if (!positionId) return;

		isLoading = true;
		errorMessage = '';
		successMessage = '';

		try {
			// Find position details for the assignment
			const position = positions.find(p => p.id === positionId);
			if (!position) {
				errorMessage = 'Position not found';
				isLoading = false;
				return;
			}

		// Check if employee already has this position
		const existingAssignment = branchAssignments.find(
			a => a.employee_id === employeeId && a.position_id === positionId && a.is_current === true
		);

		if (existingAssignment) {
			errorMessage = 'Employee already assigned to this position';
			isLoading = false;
			return;
		}		// Create new assignment
		const assignmentData = {
			employee_id: employeeId,
			position_id: positionId,
			department_id: position.department_id || position.hr_departments?.id,
			level_id: position.level_id || position.hr_levels?.id,
			branch_id: parseInt(selectedBranch) // Convert to number if needed
		};

		console.log('Creating assignment with data:', assignmentData);
		console.log('Position object:', position);

		// Validate required fields
		if (!assignmentData.department_id) {
			errorMessage = 'Position is missing department information';
			isLoading = false;
			return;
		}

		if (!assignmentData.level_id) {
			errorMessage = 'Position is missing level information';
			isLoading = false;
			return;
		}

		const { data, error } = await dataService.hrAssignments.create(assignmentData);
		
		if (error) {
			console.error('Assignment creation error:', error);
			errorMessage = `Failed to assign position: ${error.message || error}`;
			if (error.details) {
				errorMessage += ` Details: ${error.details}`;
			}
			isLoading = false;
			return;
		}

			// Reload assignments to get updated data
			await loadEmployeesByBranch(selectedBranch);
			
			const employee = employees.find(e => e.id === employeeId);
			successMessage = `Successfully assigned ${employee?.name || 'Employee'} to ${position.position_title_en}`;

			// Clear success message after 3 seconds
			setTimeout(() => {
				successMessage = '';
			}, 3000);

		} catch (error) {
			errorMessage = 'Failed to assign position';
		} finally {
			isLoading = false;
		}
	}

	async function removeAssignment(assignmentId) {
		if (!confirm('Are you sure you want to remove this assignment?')) {
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const { error } = await dataService.hrAssignments.delete(assignmentId);
			if (error) {
				errorMessage = 'Failed to remove assignment: ' + (error.message || error);
				return;
			}

			// Reload assignments to get updated data
			await loadEmployeesByBranch(selectedBranch);
			successMessage = 'Assignment removed successfully';
			setTimeout(() => {
				successMessage = '';
			}, 3000);

		} catch (error) {
			errorMessage = error.message || 'Failed to remove assignment';
		} finally {
			isLoading = false;
		}
	}

	function getEmployeeCurrentPosition(employeeId) {
		// Get current position from branch assignments
		const activeAssignment = branchAssignments.find(
			a => a.employee_id === employeeId && a.is_current === true
		);
		
		if (activeAssignment) {
			const position = positions.find(p => p.id === activeAssignment.position_id);
			return position || null;
		}
		return null;
	}

	function getPositionName(positionId) {
		const position = positions.find(p => p.id === positionId);
		return position ? position.position_title_en : 'Unknown Position';
	}

	function getPositionNameAr(positionId) {
		const position = positions.find(p => p.id === positionId);
		return position ? position.position_title_ar : 'منصب غير معروف';
	}

	function getEmployeeName(employeeId) {
		const employee = employees.find(e => e.id === employeeId);
		return employee ? employee.name : 'Unknown Employee';
	}

	function formatDate(dateString) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function getLevelBadgeColor(level) {
		const colors = [
			'bg-red-500',    // Level 1
			'bg-orange-500', // Level 2
			'bg-yellow-500', // Level 3
			'bg-green-500',  // Level 4
			'bg-blue-500'    // Level 5
		];
		return colors[level - 1] || 'bg-gray-500';
	}

	function getBranchName(branchId) {
		const branch = branches.find(b => b.id === branchId);
		return branch ? branch.name_en : 'Unknown Branch';
	}

	// Filter employees based on search term
	function getFilteredEmployees() {
		if (!employees || employees.length === 0 || !searchTerm || !searchTerm.trim()) {
			return employees || [];
		}
		
		const search = searchTerm.toLowerCase().trim();
		return employees.filter(employee => {
			// Handle different possible field names
			const name = (employee.name || '').toString().toLowerCase();
			const empId = (employee.employee_id || '').toString().toLowerCase();
			
			switch (searchCriteria) {
				case 'name':
					return name.includes(search);
				case 'employee_id':
					return empId.includes(search);
				case 'all':
				default:
					return name.includes(search) || empId.includes(search);
			}
		});
	}

	// Reactive filtered employees - updates when employees, searchTerm, or searchCriteria change
	$: {
		if (!employees || employees.length === 0) {
			filteredEmployees = [];
		} else if (!searchTerm || !searchTerm.trim()) {
			filteredEmployees = employees;
		} else {
			filteredEmployees = getFilteredEmployees();
		}
	}

	// Reactive statement to load employees when branch is selected
	$: if (selectedBranch) {
		loadEmployeesByBranch(selectedBranch);
	}
</script>

<div class="assign-positions">
	<!-- Header -->
	<div class="header">
		<h2 class="title">Assign Positions</h2>
		<p class="subtitle">Assign employees to positions and manage existing assignments</p>
	</div>

	<!-- Content -->
	<div class="content">
		<!-- Branch Selection -->
		<div class="branch-selection">
			<div class="selection-header">
				<h3>Select Branch</h3>
				<p>Choose a branch to view and manage employee position assignments</p>
			</div>
			
			<select 
				bind:value={selectedBranch}
				disabled={isLoading}
				class="branch-select"
			>
				<option value="">Choose a branch...</option>
				{#each branches as branch}
					<option value={branch.id}>
						{branch.name_en} - {branch.location_en || ''}
					</option>
				{/each}
			</select>
		</div>

		<!-- Search Bar (shown only when branch is selected) -->
		{#if selectedBranch && employees.length > 0}
			<div class="search-section">
				<div class="search-header">
					<h4>Search Employees</h4>
					<p>Search by name or employee ID</p>
				</div>
				<div class="search-controls">
					<div class="search-criteria">
						<label for="search-criteria">Search by:</label>
						<select bind:value={searchCriteria} id="search-criteria" class="criteria-select">
							<option value="all">All Fields</option>
							<option value="name">Name Only</option>
							<option value="employee_id">Employee ID Only</option>
						</select>
					</div>
					<div class="search-input-container">
						<input
							type="text"
							bind:value={searchTerm}
							placeholder={searchCriteria === 'name' ? 'Search by name...' : 
										searchCriteria === 'employee_id' ? 'Search by employee ID...' : 
										'Search employees...'}
							class="search-input"
						/>
						<div class="search-icon">🔍</div>
						{#if searchTerm.trim()}
							<button class="clear-search" on:click={() => searchTerm = ''} title="Clear search">
								×
							</button>
						{/if}
					</div>
				</div>
				{#if searchTerm && searchTerm.trim()}
					<div class="search-results-info">
						Showing {filteredEmployees.length} of {employees.length} employees
						{#if searchCriteria !== 'all'}
							(searching by {searchCriteria === 'employee_id' ? 'Employee ID' : 'Name'})
						{/if}
					</div>
				{/if}
			</div>
		{/if}

		<!-- Messages -->
		{#if errorMessage}
			<div class="error-message">
				<strong>Error:</strong> {errorMessage}
			</div>
		{/if}

		{#if successMessage}
			<div class="success-message">
				<strong>Success:</strong> {successMessage}
			</div>
		{/if}

		<!-- Employees Assignment Table -->
		{#if selectedBranch}
			<div class="employees-section">
				<div class="section-header">
					<h3>Employees in {getBranchName(parseInt(selectedBranch))}</h3>
					<div class="employee-count">
						{#if searchTerm && searchTerm.trim()}
							{filteredEmployees.length} of {employees.length} employee{employees.length !== 1 ? 's' : ''}
						{:else}
							{employees.length} employee{employees.length !== 1 ? 's' : ''}
						{/if}
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
									<th>Branch</th>
									<th>Current Position</th>
									<th>Assign Position</th>
								</tr>
							</thead>
							<tbody>
								{#each filteredEmployees as employee (employee.id)}
									{@const currentPosition = getEmployeeCurrentPosition(employee.id)}
									<tr class="table-row">
										<td class="employee-id">{employee.employee_id}</td>
										<td class="employee-name">
											{employee.name}
										</td>
										<td class="branch">{getBranchName(employee.branch_id)}</td>
										<td class="current-position">
											{#if currentPosition}
												<div class="position-info">
													<div class="position-name">{currentPosition.position_title_en}</div>
													<div class="position-details">
														<span class="level-badge {getLevelBadgeColor(currentPosition.level)}">
															L{currentPosition.level}
														</span>
														<span class="department-name">{currentPosition.department_name}</span>
													</div>
												</div>
											{:else}
												<span class="no-position">No position assigned</span>
											{/if}
										</td>
										<td class="assign-action">
											<select
												on:change={(e) => assignPosition(employee.id, e.target.value)}
												disabled={isLoading}
												class="position-select"
											>
												<option value="">Select position...</option>
												{#each positions as position}
													<option 
														value={position.id}
														selected={currentPosition?.id === position.id}
													>
														{position.position_title_en} - {position.hr_departments?.department_name_en || position.department_name}
													</option>
												{/each}
											</select>
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
	.assign-positions {
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

	/* Search Section Styles */
	.search-section {
		background: #f8fafc;
		padding: 24px;
		border-radius: 12px;
		border: 1px solid #e2e8f0;
		margin: 24px 0;
	}

	.search-header {
		margin-bottom: 16px;
	}

	.search-header h4 {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 4px 0;
	}

	.search-header p {
		color: #6b7280;
		margin: 0;
		font-size: 14px;
	}

	.search-controls {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	@media (min-width: 640px) {
		.search-controls {
			flex-direction: row;
			align-items: center;
			justify-content: space-between;
		}

		.search-criteria {
			flex-shrink: 0;
		}

		.search-input-container {
			flex-grow: 1;
			max-width: 400px;
		}
	}

	.search-criteria {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.search-criteria label {
		font-weight: 500;
		color: #374151;
		font-size: 14px;
	}

	.criteria-select {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		background: white;
		font-size: 14px;
		color: #374151;
		transition: all 0.2s;
	}

	.criteria-select:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.1);
	}

	.search-input-container {
		position: relative;
		width: 100%;
		max-width: 500px;
	}

	.search-input {
		width: 100%;
		padding: 12px 40px 12px 44px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 16px;
		background: white;
		font-family: inherit;
		transition: all 0.2s;
		box-sizing: border-box;
	}

	.search-input:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
	}

	.search-input::placeholder {
		color: #9ca3af;
	}

	.search-icon {
		position: absolute;
		left: 14px;
		top: 50%;
		transform: translateY(-50%);
		color: #6b7280;
		font-size: 16px;
		pointer-events: none;
	}

	.clear-search {
		position: absolute;
		right: 12px;
		top: 50%;
		transform: translateY(-50%);
		background: none;
		border: none;
		color: #6b7280;
		font-size: 20px;
		cursor: pointer;
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		transition: all 0.2s;
	}

	.clear-search:hover {
		background: #f3f4f6;
		color: #374151;
	}

	.search-results-info {
		margin-top: 12px;
		color: #6b7280;
		font-size: 14px;
		font-style: italic;
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
	}

	.name-container, .employee-names {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.name-en {
		font-weight: 500;
		color: #111827;
	}

	.name-ar {
		font-size: 14px;
		color: #6b7280;
		direction: rtl;
		text-align: right;
	}

	.branch {
		color: #4b5563;
		font-size: 14px;
	}

	.current-position {
		min-width: 200px;
	}

	.position-info {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.position-name {
		font-weight: 500;
		color: #111827;
	}

	.position-details {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.level-badge {
		color: white;
		font-size: 11px;
		font-weight: 600;
		padding: 3px 6px;
		border-radius: 8px;
		text-align: center;
		min-width: 28px;
		display: inline-block;
	}

	.department-name {
		font-size: 12px;
		color: #6b7280;
	}

	.no-position {
		color: #9ca3af;
		font-style: italic;
	}

	.position-select {
		width: 100%;
		min-width: 250px;
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		font-family: inherit;
	}

	.position-select:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.1);
	}

	.position-select:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.employee-cell {
		min-width: 200px;
	}

	.employee-info {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.employee-info .employee-id {
		font-size: 12px;
	}

	.position-cell {
		min-width: 180px;
	}

	.position-names {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.position-names .name-en {
		font-weight: 500;
	}

	.position-names .name-ar {
		font-size: 13px;
	}

	.department-cell {
		color: #4b5563;
		font-size: 14px;
	}

	.level-cell {
		text-align: center;
	}

	.date-cell {
		color: #6b7280;
		font-size: 14px;
		white-space: nowrap;
	}

	.actions-cell {
		text-align: center;
	}

	.remove-btn {
		background: none;
		border: none;
		cursor: pointer;
		padding: 6px;
		border-radius: 4px;
		font-size: 14px;
		color: #ef4444;
		transition: all 0.2s;
	}

	.remove-btn:hover:not(:disabled) {
		background: #fef2f2;
	}

	.remove-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.unknown {
		color: #9ca3af;
		font-style: italic;
	}

	.spinner {
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

		.position-select {
			min-width: 200px;
		}

		.current-position,
		.position-cell,
		.employee-cell {
			min-width: unset;
		}
	}
</style>