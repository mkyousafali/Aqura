<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	interface FingerprintTransaction {
		id: string;
		employee_id: string;
		name: string | null;
		branch_id: number;
		date: string;
		time: string;
		status: string;
		device_id: string | null;
		location: string | null;
		created_at: string;
		employee_name_en?: string;
		employee_name_ar?: string;
		branch_name_en?: string;
		branch_name_ar?: string;
		branch_location_en?: string;
		branch_location_ar?: string;
		is_fallback?: boolean;
	}

	interface Branch {
		id: number;
		name_en: string;
		name_ar: string;
	}

	let transactions: FingerprintTransaction[] = [];
	let filteredTransactions: FingerprintTransaction[] = [];
	let branches: Branch[] = [];
	let loading = false;
	let error = '';

	// Employee search modal
	let showEmployeeModal = false;
	let allEmployees: any[] = [];
	let employeeSearchTerm = '';
	let filteredEmployees: any[] = [];

	// Period selection modal
	let showPeriodModal = false;
	let periodStartDate = '';
	let periodEndDate = '';
	let periodBranch: number | null = null;

	// Pagination
	let currentPage = 1;
	let pageSize = 500;
	let totalRecords = 0;
	let totalPages = 0;

	// Filters
	let selectedBranch: number | null = null;
	let selectedStatus = '';
	let selectedEmployee = '';
	let selectedDate = ''; // Single date filter
	let startDate = '';
	let endDate = '';

	const statusOptions = [
		'Check In',
		'Check Out',
		'Break In',
		'Break Out',
		'Overtime In',
		'Overtime Out'
	];

	let transactionsSubscription: any;
	let employeesSubscription: any;

	onMount(async () => {
		await loadBranches();
		await loadAllEmployees();
		setupRealtimeSubscriptions();
	});

	onDestroy(() => {
		// Clean up subscriptions
		if (transactionsSubscription) {
			supabase.removeChannel(transactionsSubscription);
		}
		if (employeesSubscription) {
			supabase.removeChannel(employeesSubscription);
		}
	});

	function setupRealtimeSubscriptions() {
		// Subscribe to fingerprint transactions changes
		transactionsSubscription = supabase
			.channel('fingerprint_transactions_changes')
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'hr_fingerprint_transactions'
				},
				() => {
					loadTransactions();
				}
			)
			.subscribe();

		// Subscribe to employee master changes
		employeesSubscription = supabase
			.channel('employee_master_changes')
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'hr_employee_master'
				},
				() => {
					loadTransactions();
				}
			)
			.subscribe();
	}

	async function loadBranches() {
		try {
			const { data, error: branchError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.order('name_en');

			if (branchError) throw branchError;
			branches = data || [];
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	async function loadAllEmployees() {
		try {
			const { data, error: empError } = await supabase
				.from('hr_employee_master')
				.select('id, name_en, name_ar, employee_id_mapping')
				.order('name_en');

			if (empError) throw empError;
			allEmployees = data || [];
			filteredEmployees = allEmployees;
		} catch (err) {
			console.error('Error loading employees:', err);
		}
	}

	function loadLast30Days() {
		// Clear all filters
		selectedBranch = null;
		selectedStatus = '';
		selectedEmployee = '';
		selectedDate = '';
		endDate = '';
		
		// Set start date to 30 days ago
		const thirtyDaysAgo = new Date();
		thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
		startDate = thirtyDaysAgo.toISOString().split('T')[0];
		
		currentPage = 1;
		loadTransactions();
	}

	function loadAllData() {
		// Clear all filters including dates
		selectedBranch = null;
		selectedStatus = '';
		selectedEmployee = '';
		selectedDate = '';
		startDate = '';
		endDate = '';
		
		currentPage = 1;
		loadTransactions();
	}

	function openEmployeeSelector() {
		showEmployeeModal = true;
		employeeSearchTerm = '';
		filteredEmployees = allEmployees;
	}

	function closeEmployeeModal() {
		showEmployeeModal = false;
	}

	function filterEmployees() {
		const search = employeeSearchTerm.toLowerCase();
		filteredEmployees = allEmployees.filter(emp => 
			emp.name_en?.toLowerCase().includes(search) || 
			emp.name_ar?.includes(employeeSearchTerm) ||
			emp.id?.toLowerCase().includes(search)
		);
	}

	function selectEmployee(employee: any) {
		// Clear date filters
		selectedDate = '';
		startDate = '';
		endDate = '';
		
		// Set employee filter
		selectedEmployee = employee.name_en || employee.id;
		
		closeEmployeeModal();
		currentPage = 1;
		loadTransactions();
	}

	function openPeriodSelector() {
		showPeriodModal = true;
		// Set default to last 30 days
		const thirtyDaysAgo = new Date();
		thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
		periodStartDate = thirtyDaysAgo.toISOString().split('T')[0];
		periodEndDate = new Date().toISOString().split('T')[0];
		periodBranch = null;
	}

	function closePeriodModal() {
		showPeriodModal = false;
	}

	function loadForPeriod() {
		if (!periodStartDate || !periodEndDate) {
			alert('Please select both start and end dates');
			return;
		}

		// Clear other filters
		selectedEmployee = '';
		selectedStatus = '';
		selectedDate = '';
		
		// Set period filters
		startDate = periodStartDate;
		endDate = periodEndDate;
		selectedBranch = periodBranch;
		
		closePeriodModal();
		currentPage = 1;
		loadTransactions();
	}

	async function loadTransactions() {
		loading = true;
		error = '';

		try {
			// Build base query with filters
			let countQuery = supabase
				.from('hr_fingerprint_transactions')
				.select('*', { count: 'exact', head: true });

			let dataQuery = supabase
				.from('hr_fingerprint_transactions')
				.select(`
					id,
					employee_id,
					name,
					branch_id,
					date,
					time,
					status,
					device_id,
					location,
					created_at
				`)
				.order('date', { ascending: false })
				.order('time', { ascending: false })
				.range((currentPage - 1) * pageSize, currentPage * pageSize - 1);

			// Apply filters to both queries
			if (selectedBranch) {
				countQuery = countQuery.eq('branch_id', selectedBranch);
				dataQuery = dataQuery.eq('branch_id', selectedBranch);
			}
			if (selectedStatus) {
				countQuery = countQuery.eq('status', selectedStatus);
				dataQuery = dataQuery.eq('status', selectedStatus);
			}
			// Single date filter takes priority
			if (selectedDate) {
				countQuery = countQuery.eq('date', selectedDate);
				dataQuery = dataQuery.eq('date', selectedDate);
			} else {
				// Otherwise use date range
				if (startDate) {
					countQuery = countQuery.gte('date', startDate);
					dataQuery = dataQuery.gte('date', startDate);
				}
				if (endDate) {
					countQuery = countQuery.lte('date', endDate);
					dataQuery = dataQuery.lte('date', endDate);
				}
			}

			// Execute all queries in parallel
			const [
				{ count },
				{ data: transData, error: transError },
				{ data: empData, error: empError },
				{ data: branchData, error: branchError },
				{ data: hrEmpData, error: hrEmpError }
			] = await Promise.all([
				countQuery,
				dataQuery,
				supabase.from('hr_employee_master').select('id, name_en, name_ar, employee_id_mapping'),
				supabase.from('branches').select('id, name_en, name_ar, location_en, location_ar'),
				supabase.from('hr_employees').select('employee_id, branch_id, name')
			]);

			if (transError) throw transError;
			if (empError) throw empError;
			if (branchError) throw branchError;
			if (hrEmpError) throw hrEmpError;

			// Set pagination info
			totalRecords = count || 0;
			totalPages = Math.ceil(totalRecords / pageSize);

			// Create branch lookup
			const branchLookup: Record<number, { name_en: string; name_ar: string; location_en: string; location_ar: string }> = {};
			branchData?.forEach(b => {
				branchLookup[b.id] = { name_en: b.name_en, name_ar: b.name_ar, location_en: b.location_en, location_ar: b.location_ar };
			});

			// Map transactions with employee data
			transactions = (transData || []).map(trans => {
				// Find matching employee by checking employee_id_mapping
				const matchingEmployee = empData?.find(emp => {
					const mapping = emp.employee_id_mapping as Record<string, string>;
					const branchKey = trans.branch_id.toString();
					return mapping && mapping[branchKey] === trans.employee_id;
				});

				// Fallback to hr_employees if not found in master
				let employeeNameEn = matchingEmployee?.name_en;
				let employeeNameAr = matchingEmployee?.name_ar;
				let isFallback = false;

				if (!employeeNameEn && !employeeNameAr) {
					const hrEmployee = hrEmpData?.find(
						emp => emp.employee_id === trans.employee_id && emp.branch_id === trans.branch_id
					);
					if (hrEmployee) {
						employeeNameEn = hrEmployee.name;
						employeeNameAr = hrEmployee.name;
						isFallback = true;
					}
				}

				return {
					...trans,
					employee_name_en: employeeNameEn,
					employee_name_ar: employeeNameAr,
					branch_name_en: branchLookup[trans.branch_id]?.name_en,
					branch_name_ar: branchLookup[trans.branch_id]?.name_ar,
					branch_location_en: branchLookup[trans.branch_id]?.location_en,
					branch_location_ar: branchLookup[trans.branch_id]?.location_ar,
					is_fallback: isFallback
				};
			});

			// Sort by date (descending), then by employee name (ascending), then by time (ascending)
			transactions.sort((a, b) => {
				// First by date (newest first)
				const dateCompare = new Date(b.date).getTime() - new Date(a.date).getTime();
				if (dateCompare !== 0) return dateCompare;
				
				// Then by employee name (alphabetically)
				const nameA = a.employee_name_en || a.employee_id;
				const nameB = b.employee_name_en || b.employee_id;
				const nameCompare = nameA.localeCompare(nameB);
				if (nameCompare !== 0) return nameCompare;
				
				// Finally by time (earliest first)
				return a.time.localeCompare(b.time);
			});

			applyFilters();
		} catch (err: any) {
			error = err.message || 'Failed to load transactions';
			console.error('Error loading transactions:', err);
		} finally {
			loading = false;
		}
	}

	function applyFilters() {
		filteredTransactions = transactions.filter(trans => {
			if (selectedEmployee) {
				const searchLower = selectedEmployee.toLowerCase();
				const matchesName = 
					trans.employee_name_en?.toLowerCase().includes(searchLower) ||
					trans.employee_name_ar?.includes(selectedEmployee) ||
					trans.employee_id.toLowerCase().includes(searchLower);
				if (!matchesName) return false;
			}
			return true;
		});
	}

	function handleFilterChange() {
		applyFilters();
	}

	function goToPage(page: number) {
		if (page >= 1 && page <= totalPages) {
			currentPage = page;
			loadTransactions();
		}
	}

	function nextPage() {
		if (currentPage < totalPages) {
			currentPage++;
			loadTransactions();
		}
	}

	function prevPage() {
		if (currentPage > 1) {
			currentPage--;
			loadTransactions();
		}
	}

	function onFilterChange() {
		currentPage = 1;
		loadTransactions();
	}

	function formatTime(time: string) {
		const [hours, minutes] = time.split(':');
		let hour = parseInt(hours);
		const ampm = hour >= 12 ? 'PM' : 'AM';
		hour = hour % 12;
		hour = hour ? hour : 12; // 0 should be 12
		return `${hour}:${minutes} ${ampm}`;
	}

	function formatDate(date: string) {
		return new Date(date).toLocaleDateString('en-GB');
	}
</script>

<div class="fingerprint-transactions-container">
	{#if error}
		<div class="error-message">{error}</div>
	{/if}

	<!-- Load Action Buttons -->
	<div class="load-actions">
		<button class="action-btn primary" on:click={loadLast30Days} disabled={loading}>
			📅 Load Last 30 Days
		</button>
		<button class="action-btn secondary" on:click={loadAllData} disabled={loading}>
			📊 Load All Data
		</button>
		<button class="action-btn tertiary" on:click={openEmployeeSelector} disabled={loading}>
			👤 Load for Specific Employee
		</button>
		<button class="action-btn quaternary" on:click={openPeriodSelector} disabled={loading}>
			📆 Load for Specific Period
		</button>
	</div>

	<!-- Filters -->
	<div class="filters">
		<div class="filter-group">
			<label>Branch:</label>
			<select bind:value={selectedBranch} on:change={onFilterChange}>
				<option value={null}>All Branches</option>
				{#each branches as branch}
					<option value={branch.id}>{branch.name_en}</option>
				{/each}
			</select>
		</div>

		<div class="filter-group">
			<label>Status:</label>
			<select bind:value={selectedStatus} on:change={onFilterChange}>
				<option value="">All Status</option>
				{#each statusOptions as status}
					<option value={status}>{status}</option>
				{/each}
			</select>
		</div>

		<div class="filter-group">
			<label>📅 Specific Date:</label>
			<input type="date" bind:value={selectedDate} on:change={onFilterChange} />
		</div>

		<div class="filter-group">
			<label>Start Date:</label>
			<input type="date" bind:value={startDate} on:change={onFilterChange} disabled={!!selectedDate} />
		</div>

		<div class="filter-group">
			<label>End Date:</label>
			<input type="date" bind:value={endDate} on:change={onFilterChange} disabled={!!selectedDate} />
		</div>

		<div class="filter-group">
			<label>Employee:</label>
			<input 
				type="text" 
				placeholder="Search by name or ID..." 
				bind:value={selectedEmployee} 
				on:input={handleFilterChange}
			/>
		</div>
	</div>

	<!-- Results Count and Pagination -->
	<div class="pagination-controls">
		<div class="results-info">
			Showing {filteredTransactions.length} of {totalRecords} transactions
			{#if totalPages > 1}
				<span class="page-info">| Page {currentPage} of {totalPages}</span>
			{/if}
		</div>
		
		{#if totalPages > 1}
			<div class="pagination-buttons">
				<button on:click={prevPage} disabled={currentPage === 1 || loading}>
					← Previous
				</button>
				<span class="page-numbers">
					{#if currentPage > 2}
						<button on:click={() => goToPage(1)}>1</button>
						{#if currentPage > 3}
							<span class="ellipsis">...</span>
						{/if}
					{/if}
					
					{#if currentPage > 1}
						<button on:click={() => goToPage(currentPage - 1)}>{currentPage - 1}</button>
					{/if}
					
					<button class="active">{currentPage}</button>
					
					{#if currentPage < totalPages}
						<button on:click={() => goToPage(currentPage + 1)}>{currentPage + 1}</button>
					{/if}
					
					{#if currentPage < totalPages - 1}
						{#if currentPage < totalPages - 2}
							<span class="ellipsis">...</span>
						{/if}
						<button on:click={() => goToPage(totalPages)}>{totalPages}</button>
					{/if}
				</span>
				<button on:click={nextPage} disabled={currentPage === totalPages || loading}>
					Next →
				</button>
			</div>
		{/if}
	</div>

	<!-- Table -->
	<div class="table-container">
		{#if loading}
			<div class="loading">Loading transactions...</div>
		{:else if filteredTransactions.length === 0}
			<div class="no-data">
				<div class="no-data-icon">📋</div>
				<h3>No Transactions Loaded</h3>
				<p>To view fingerprint transactions, please use one of the load options above:</p>
				<ul class="instructions">
					<li><strong>📅 Load Last 30 Days</strong> - View recent transactions from the past 30 days</li>
					<li><strong>📊 Load All Data</strong> - View all transactions in the database</li>
					<li><strong>👤 Load for Specific Employee</strong> - View all transactions for a selected employee</li>
					<li><strong>📆 Load for Specific Period</strong> - View transactions for a custom date range and branch</li>
				</ul>
				<p class="tip">💡 Tip: You can also use the filters below after loading data to refine your search</p>
			</div>
		{:else}
			<table>
				<thead>
					<tr>
						<th>Date</th>
						<th>Time</th>
						<th>Employee Name</th>
						<th>Employee ID</th>
						<th>Status</th>
						<th>Branch</th>
						<th>Location</th>
					</tr>
				</thead>
				<tbody>
					{#each filteredTransactions as trans}
						<tr>
							<td>{formatDate(trans.date)}</td>
							<td>{formatTime(trans.time)}</td>
							<td>
								<div class="employee-name">
									<div class="name-en">
										{trans.employee_name_en || '-'}
										{#if trans.is_fallback}
											<span class="fallback-badge" title="Not in master employee table">⚠️</span>
										{/if}
									</div>
									<div class="name-ar">{trans.employee_name_ar || '-'}</div>
								</div>
							</td>
							<td class="employee-id">{trans.employee_id}</td>
							<td>
								<span class="status-badge status-{trans.status.toLowerCase().replace(/\s+/g, '-')}">
									{trans.status}
								</span>
							</td>
							<td>
								<div class="branch-name">
									<div class="name-en">{trans.branch_name_en || '-'}</div>
									<div class="name-ar">{trans.branch_name_ar || '-'}</div>
								</div>
							</td>
							<td>
								<div class="location">
									<div class="location-en">{trans.branch_location_en || '-'}</div>
									<div class="location-ar">{trans.branch_location_ar || '-'}</div>
								</div>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	</div>
</div>

<!-- Employee Selection Modal -->
{#if showEmployeeModal}
	<div class="modal-overlay" on:click={closeEmployeeModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>Select Employee</h3>
				<button class="close-btn" on:click={closeEmployeeModal}>✕</button>
			</div>
			
			<div class="modal-search">
				<input 
					type="text" 
					placeholder="Search by name or ID..." 
					bind:value={employeeSearchTerm}
					on:input={filterEmployees}
				/>
			</div>

			<div class="employee-list">
				{#each filteredEmployees as employee}
					<button class="employee-item" on:click={() => selectEmployee(employee)}>
						<div class="employee-info">
							<div class="employee-name-en">{employee.name_en}</div>
							<div class="employee-name-ar">{employee.name_ar}</div>
							<div class="employee-id">{employee.id}</div>
						</div>
					</button>
				{/each}
				{#if filteredEmployees.length === 0}
					<div class="no-employees">No employees found</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<!-- Period Selection Modal -->
{#if showPeriodModal}
	<div class="modal-overlay" on:click={closePeriodModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>📆 Select Period</h3>
				<button class="close-btn" on:click={closePeriodModal}>✕</button>
			</div>
			
			<div class="period-form">
				<div class="form-group">
					<label>Start Date:</label>
					<input type="date" bind:value={periodStartDate} />
				</div>

				<div class="form-group">
					<label>End Date:</label>
					<input type="date" bind:value={periodEndDate} />
				</div>

				<div class="form-group">
					<label>Branch:</label>
					<select bind:value={periodBranch}>
						<option value={null}>All Branches</option>
						{#each branches as branch}
							<option value={branch.id}>{branch.name_en}</option>
						{/each}
					</select>
				</div>

				<button class="load-btn" on:click={loadForPeriod}>
					Load Data
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.fingerprint-transactions-container {
		padding: 1rem;
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #f5f5f5;
	}

	.error-message {
		background: #f44336;
		color: white;
		padding: 1rem;
		border-radius: 4px;
		margin-bottom: 1rem;
	}

	.load-actions {
		display: flex;
		gap: 1rem;
		padding: 1rem;
		background: white;
		border-radius: 8px;
		box-shadow: 0 2px 4px rgba(0,0,0,0.1);
		margin-bottom: 1rem;
		flex-wrap: wrap;
	}

	.action-btn {
		padding: 0.75rem 1.5rem;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.95rem;
		font-weight: 500;
		transition: all 0.2s;
		flex: 1;
		min-width: 180px;
	}

	.action-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(0,0,0,0.15);
	}

	.action-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.action-btn.primary {
		background: #4CAF50;
		color: white;
	}

	.action-btn.primary:hover:not(:disabled) {
		background: #45a049;
	}

	.action-btn.secondary {
		background: #2196F3;
		color: white;
	}

	.action-btn.secondary:hover:not(:disabled) {
		background: #1976d2;
	}

	.action-btn.tertiary {
		background: #FF9800;
		color: white;
	}

	.action-btn.tertiary:hover:not(:disabled) {
		background: #f57c00;
	}

	.action-btn.quaternary {
		background: #9C27B0;
		color: white;
	}

	.action-btn.quaternary:hover:not(:disabled) {
		background: #7B1FA2;
	}

	.filters {
		display: flex;
		flex-wrap: wrap;
		gap: 1.5rem;
		padding: 1.5rem;
		background: linear-gradient(135deg, #ffffff 0%, #f8f9fa 100%);
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(0,0,0,0.08);
		margin-bottom: 1rem;
		border: 2px solid #e8e8e8;
		position: relative;
		overflow: hidden;
	}

	.filters::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 4px;
		background: linear-gradient(90deg, #4CAF50 0%, #FF9800 50%, #4CAF50 100%);
	}

	.filter-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		min-width: 160px;
		flex: 1;
	}

	.filter-group label {
		font-size: 0.8rem;
		font-weight: 600;
		color: #555;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		display: flex;
		align-items: center;
		gap: 0.3rem;
	}

	.filter-group select,
	.filter-group input {
		padding: 0.75rem 1rem;
		border: 2px solid #e0e0e0;
		border-radius: 8px;
		font-size: 0.95rem;
		transition: all 0.3s ease;
		background: white;
		color: #333;
		font-weight: 500;
	}

	.filter-group select:focus,
	.filter-group input:focus {
		outline: none;
		border-color: #4CAF50;
		box-shadow: 0 0 0 3px rgba(76, 175, 80, 0.1);
		transform: translateY(-1px);
	}

	.filter-group select:hover,
	.filter-group input:hover:not(:disabled) {
		border-color: #FF9800;
	}

	.filter-group input:disabled {
		background: #f5f5f5;
		cursor: not-allowed;
		opacity: 0.6;
		border-color: #e0e0e0;
	}

	.results-info {
		padding: 0.5rem 1rem;
		background: white;
		border-radius: 8px;
		font-size: 0.9rem;
		color: #666;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.page-info {
		color: #999;
	}

	.pagination-controls {
		background: white;
		border-radius: 8px;
		margin-bottom: 1rem;
		padding: 1rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-wrap: wrap;
		gap: 1rem;
	}

	.pagination-buttons {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.pagination-buttons button {
		padding: 0.5rem 1rem;
		background: white;
		border: 1px solid #ddd;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
		transition: all 0.2s;
	}

	.pagination-buttons button:hover:not(:disabled) {
		background: #f5f5f5;
		border-color: #4CAF50;
	}

	.pagination-buttons button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.pagination-buttons button.active {
		background: #4CAF50;
		color: white;
		border-color: #4CAF50;
		font-weight: 600;
	}

	.page-numbers {
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.ellipsis {
		padding: 0 0.5rem;
		color: #999;
	}

	.table-container {
		flex: 1;
		overflow: auto;
		background: white;
		border-radius: 8px;
		box-shadow: 0 2px 4px rgba(0,0,0,0.1);
	}

	.loading {
		padding: 3rem;
		text-align: center;
		color: #666;
		font-size: 1.1rem;
	}

	.no-data {
		padding: 3rem 2rem;
		text-align: center;
		color: #666;
		max-width: 600px;
		margin: 0 auto;
	}

	.no-data-icon {
		font-size: 4rem;
		margin-bottom: 1rem;
		opacity: 0.5;
	}

	.no-data h3 {
		color: #333;
		margin-bottom: 1rem;
		font-size: 1.5rem;
	}

	.no-data p {
		color: #666;
		margin-bottom: 1.5rem;
		line-height: 1.6;
	}

	.instructions {
		text-align: left;
		list-style: none;
		padding: 0;
		margin: 1.5rem 0;
		background: #f8f9fa;
		border-radius: 8px;
		padding: 1.5rem;
	}

	.instructions li {
		padding: 0.75rem 0;
		color: #444;
		line-height: 1.6;
	}

	.instructions li strong {
		color: #333;
	}

	.tip {
		background: #fff3e0;
		padding: 1rem;
		border-radius: 6px;
		color: #e65100;
		font-size: 0.95rem;
		border-left: 4px solid #ff9800;
	}

	table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.9rem;
	}

	thead {
		position: sticky;
		top: 0;
		background: #f8f9fa;
		z-index: 1;
	}

	th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #333;
		border-bottom: 2px solid #ddd;
		white-space: nowrap;
	}

	td {
		padding: 0.75rem 1rem;
		border-bottom: 1px solid #eee;
	}

	tbody tr:hover {
		background: #f8f9fa;
	}

	.employee-name {
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
	}

	.branch-name {
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
	}

	.name-en {
		font-weight: 500;
		color: #333;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.fallback-badge {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		background: #f44336;
		color: white;
		font-size: 0.75rem;
		padding: 0.15rem 0.4rem;
		border-radius: 10px;
		font-weight: 600;
		cursor: help;
	}

	.name-ar {
		font-size: 0.85rem;
		color: #666;
		direction: rtl;
	}

	.employee-id {
		font-family: monospace;
		color: #666;
	}

	.employee-id {
		font-family: monospace;
		color: #666;
		font-weight: 600;
		font-size: 0.9rem;
	}

	.status-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.85rem;
		font-weight: 500;
		white-space: nowrap;
	}

	.status-check-in {
		background: #e3f2fd;
		color: #1976d2;
	}

	.status-check-out {
		background: #fff3e0;
		color: #f57c00;
	}

	.status-break-in {
		background: #f3e5f5;
		color: #7b1fa2;
	}

	.status-break-out {
		background: #e8f5e9;
		color: #388e3c;
	}

	.status-overtime-in {
		background: #fff9c4;
		color: #f57f17;
	}

	.status-overtime-out {
		background: #ffebee;
		color: #c62828;
	}

	.location {
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
	}

	.location-en {
		font-size: 0.85rem;
		color: #666;
	}

	.location-ar {
		font-size: 0.85rem;
		color: #666;
		direction: rtl;
	}

	.device-id {
		font-family: monospace;
		font-size: 0.8rem;
		color: #999;
	}

	/* Modal Styles */
	.modal-overlay {
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

	.modal-content {
		background: white;
		border-radius: 8px;
		width: 90%;
		max-width: 600px;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 4px 20px rgba(0,0,0,0.3);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 1px solid #eee;
	}

	.modal-header h3 {
		margin: 0;
		color: #333;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 1.5rem;
		cursor: pointer;
		color: #999;
		padding: 0;
		width: 30px;
		height: 30px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 4px;
	}

	.close-btn:hover {
		background: #f5f5f5;
		color: #333;
	}

	.modal-search {
		padding: 1rem 1.5rem;
		border-bottom: 1px solid #eee;
	}

	.modal-search input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #ddd;
		border-radius: 4px;
		font-size: 1rem;
	}

	.employee-list {
		overflow-y: auto;
		max-height: 400px;
		padding: 0.5rem;
	}

	.employee-item {
		width: 100%;
		padding: 1rem;
		margin-bottom: 0.5rem;
		background: white;
		border: 1px solid #ddd;
		border-radius: 6px;
		cursor: pointer;
		text-align: left;
		transition: all 0.2s;
	}

	.employee-item:hover {
		background: #f8f9fa;
		border-color: #4CAF50;
		box-shadow: 0 2px 4px rgba(0,0,0,0.1);
	}

	.employee-info {
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
	}

	.employee-name-en {
		font-weight: 500;
		color: #333;
		font-size: 1rem;
	}

	.employee-name-ar {
		color: #666;
		font-size: 0.9rem;
		direction: rtl;
	}

	.employee-id {
		color: #999;
		font-size: 0.85rem;
		font-family: monospace;
	}

	.no-employees {
		padding: 2rem;
		text-align: center;
		color: #999;
	}

	/* Period Form Styles */
	.period-form {
		padding: 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.form-group label {
		font-weight: 600;
		color: #333;
		font-size: 0.9rem;
	}

	.form-group input,
	.form-group select {
		padding: 0.75rem;
		border: 2px solid #e0e0e0;
		border-radius: 6px;
		font-size: 1rem;
		transition: all 0.2s;
	}

	.form-group input:focus,
	.form-group select:focus {
		outline: none;
		border-color: #9C27B0;
		box-shadow: 0 0 0 3px rgba(156, 39, 176, 0.1);
	}

	.load-btn {
		padding: 0.875rem;
		background: #4CAF50;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		margin-top: 0.5rem;
	}

	.load-btn:hover {
		background: #45a049;
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(0,0,0,0.2);
	}
</style>
