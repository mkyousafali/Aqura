<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	let users = [];
	let branches = [];
	let isLoading = false;
	let errorMessage = '';
	let positions = {};
	let branchMap = {};
	let userSearchQuery = '';
	let selectedBranchFilter = '';
	let isSaving = false;
	let successMessage = '';

	// Modal state
	let isModalOpen = false;
	let selectedBranch = null;
	let selectedUserIndex = null;
	let selectedUsername = '';
	let branchEmployees = [];
	let employeeSearchQuery = '';
	let modalIsLoading = false;

	// Name modal state
	let isNameModalOpen = false;
	let nameModalUserIndex = null;
	let englishNameInput = '';
	let arabicNameInput = '';

	onMount(() => {
		loadUsers();
	});

	async function loadUsers() {
		isLoading = true;
		errorMessage = '';
		successMessage = '';

		try {
			// Fetch all users
			const { data: usersData, error: usersError } = await supabase
				.from('users')
				.select('id, username, status, position_id, branch_id')
				.limit(1000000);

			if (usersError) {
				throw new Error(usersError.message);
			}

			// Fetch all positions
			const { data: positionsData, error: positionsError } = await supabase
				.from('hr_positions')
				.select('id, position_title_en')
				.limit(100000);

			if (positionsError) {
				throw new Error(positionsError.message);
			}

			// Fetch all branches
			const { data: branchesData, error: branchesError } = await supabase
				.from('branches')
				.select('id, name_en')
				.order('name_en')
				.limit(100000);

			if (branchesError) {
				throw new Error(branchesError.message);
			}

			// Fetch all employees
			const { data: employeesData, error: employeesError } = await supabase
				.from('hr_employees')
				.select('id, employee_id, name, branch_id')
				.limit(1000000);

			if (employeesError) {
				throw new Error(employeesError.message);
			}

			// Fetch existing master records (CRITICAL: must load ALL to prevent duplicate EMP IDs)
			const { data: masterData, error: masterError } = await supabase
				.from('hr_employee_master')
				.select('user_id, id, name_en, name_ar, employee_id_mapping, current_branch_id, current_position_id')
				.limit(1000000);

			if (masterError) {
				throw new Error(masterError.message);
			}

			// Create a map of master records by user_id
			const masterMap = {};
			masterData?.forEach(record => {
				masterMap[record.user_id] = record;
			});

			// Create a map of positions by id
			positions = {};
			positionsData.forEach(pos => {
				positions[pos.id] = pos.position_title_en;
			});

			// Create a map of branches by id
			branchMap = {};
			branchesData.forEach(branch => {
				branchMap[branch.id] = branch.name_en;
			});

			// Populate users with master data and auto-fill current branch employee info
			usersData.forEach(user => {
				// Load from master record if exists
				const master = masterMap[user.id];
				if (master) {
					user.master_id = master.id;
					user.english_name = master.name_en;
					user.arabic_name = master.name_ar;
					user.employee_id_mapping = master.employee_id_mapping || {};
					
					// Populate individual branch properties from mapping
					Object.entries(user.employee_id_mapping).forEach(([branchId, employeeId]) => {
						user[`branch_${branchId}_employee`] = employeeId;
					});
				} else {
					user.employee_id_mapping = {};
				}
			});

			branches = branchesData || [];
			users = usersData || [];
		} catch (error) {
			console.error('Error loading users:', error);
			errorMessage = error.message || 'Failed to load users';
		} finally {
			isLoading = false;
		}
	}

	async function openBranchModal(branchId, userIndex) {
		selectedBranch = branchId;
		selectedUserIndex = userIndex;
		selectedUsername = users[userIndex].username;
		employeeSearchQuery = selectedUsername.substring(0, 3);
		modalIsLoading = true;
		isModalOpen = true;

		try {
			const { data, error } = await supabase
				.from('hr_employees')
				.select('id, employee_id, name')
				.eq('branch_id', branchId);

			if (error) {
				throw new Error(error.message);
			}

			branchEmployees = data || [];
		} catch (error) {
			console.error('Error loading employees:', error);
			branchEmployees = [];
		} finally {
			modalIsLoading = false;
		}
	}

	function closeModal() {
		isModalOpen = false;
		selectedBranch = null;
		selectedUserIndex = null;
		selectedUsername = '';
		branchEmployees = [];
		employeeSearchQuery = '';
	}

	function openNameModal(userIndex) {
		nameModalUserIndex = userIndex;
		englishNameInput = users[userIndex].english_name || '';
		arabicNameInput = users[userIndex].arabic_name || '';
		isNameModalOpen = true;
	}

	function closeNameModal() {
		isNameModalOpen = false;
		nameModalUserIndex = null;
		englishNameInput = '';
		arabicNameInput = '';
	}

	function saveNames() {
		if (nameModalUserIndex !== null) {
			users[nameModalUserIndex].english_name = englishNameInput;
			users[nameModalUserIndex].arabic_name = arabicNameInput;
		}
		closeNameModal();
	}

	async function saveAllData() {
		isSaving = true;
		errorMessage = '';
		successMessage = '';

		try {
			if (!$currentUser) {
				throw new Error('Not logged in. Please log in to save data.');
			}

			if (users.length === 0) {
				throw new Error('No users to save');
			}

			// Find the highest existing EMPID from loaded users
			let nextNumber = 1;
			const existingEmpIds = users
				.filter(u => u.master_id && u.master_id.startsWith('EMP'))
				.map(u => {
					const match = u.master_id.match(/EMP(\d+)/);
					return match ? parseInt(match[1]) : 0;
				});

			if (existingEmpIds.length > 0) {
				const maxExisting = Math.max(...existingEmpIds);
				nextNumber = maxExisting + 1;
			}

			console.log(`Found ${existingEmpIds.length} existing EMP IDs. Starting new IDs from EMP${nextNumber}`);

			let savedCount = 0;
			const dataToSaveArray = [];
			const batchSize = 50;

			// Build data for all users
			users.forEach(user => {
				// Build employee_id_mapping from branch columns
				const employeeIdMapping = {};
				branches.forEach(branch => {
					const employeeId = user[`branch_${branch.id}_employee`];
					if (employeeId) {
						employeeIdMapping[branch.id.toString()] = employeeId;
					}
				});

				const dataToSave = {
					user_id: user.id,
					current_branch_id: user.branch_id,
					current_position_id: user.position_id,
					name_en: user.english_name || null,
					name_ar: user.arabic_name || null,
					employee_id_mapping: employeeIdMapping
				};

				// If user already has master_id (existing record), use it
				// Otherwise generate new EMPID for new records
				if (user.master_id) {
					dataToSave.id = user.master_id;
				} else {
					dataToSave.id = `EMP${nextNumber}`;
					nextNumber++;
				}

				dataToSaveArray.push(dataToSave);
			});

			console.log('Data to save for all users:', dataToSaveArray);

			// Check for duplicate IDs in the data being saved
			const idCounts = {};
			dataToSaveArray.forEach(item => {
				if (idCounts[item.id]) {
					idCounts[item.id]++;
				} else {
					idCounts[item.id] = 1;
				}
			});
			
			const duplicates = Object.entries(idCounts).filter(([id, count]) => count > 1);
			if (duplicates.length > 0) {
				throw new Error(`Duplicate IDs found in data: ${duplicates.map(([id, count]) => `${id} (${count} times)`).join(', ')}`);
			}

			// Upsert data in batches to avoid URL length issues
			for (let i = 0; i < dataToSaveArray.length; i += batchSize) {
				const batch = dataToSaveArray.slice(i, i + batchSize);
				
				const { data, error } = await supabase
					.from('hr_employee_master')
					.upsert(batch, {
						onConflict: 'user_id'
					});

				console.log('Batch response:', { data, error });

				if (error) {
					console.error('Full error:', JSON.stringify(error));
					
					// Try to identify which record caused the issue
					if (error.code === '23505') {
						const problematicIds = batch.map(item => item.id).join(', ');
						throw new Error(`Duplicate key error. IDs in this batch: ${problematicIds}. Error: ${error.message}`);
					}
					
					throw new Error(error.message);
				}
			}

			savedCount = dataToSaveArray.length;
			successMessage = `Successfully saved ${savedCount} user${savedCount !== 1 ? 's' : ''}`;
		} catch (error) {
			console.error('Error saving data:', error);
			errorMessage = error.message || 'Failed to save data';
		} finally {
			isSaving = false;
		}
	}

	function selectEmployee(employee) {
		if (selectedUserIndex !== null && selectedBranch !== null) {
			const branchIndex = branches.findIndex(b => b.id === selectedBranch);
			if (branchIndex >= 0) {
				users[selectedUserIndex][`branch_${selectedBranch}_employee`] = employee.employee_id;
			}
		}
		closeModal();
	}

	$: filteredEmployees = branchEmployees.filter(emp => 
		emp.name.toLowerCase().includes(employeeSearchQuery.toLowerCase()) ||
		emp.employee_id.toLowerCase().includes(employeeSearchQuery.toLowerCase())
	);

	$: filteredUsers = users.filter(user =>
		(user.username.toLowerCase().includes(userSearchQuery.toLowerCase()) ||
		(user.master_id && user.master_id.toLowerCase().includes(userSearchQuery.toLowerCase()))) &&
		(selectedBranchFilter === '' || user.branch_id === parseInt(selectedBranchFilter))
	);
</script>

<div class="container">
	<div class="button-cards-section">
		<div class="button-card">
			<button class="card-button">Button 1</button>
		</div>
		<div class="button-card">
			<button class="card-button">Button 2</button>
		</div>
		<div class="button-card">
			<button class="card-button">Button 3</button>
		</div>
		<div class="button-card">
			<button class="card-button">Button 4</button>
		</div>
	</div>

	<div class="header-section">
		<button class="load-users-btn" on:click={loadUsers} disabled={isLoading}>
			{isLoading ? 'Loading...' : 'Load Users'}
		</button>
		
		{#if users.length > 0}
			<button class="save-all-btn" on:click={saveAllData} disabled={isSaving}>
				{isSaving ? 'Saving...' : '💾 Save All'}
			</button>
		{/if}
	</div>

	{#if errorMessage}
		<div class="error-message">
			{errorMessage}
		</div>
	{/if}

	{#if successMessage}
		<div class="success-message">
			{successMessage}
		</div>
	{/if}

	{#if users.length > 0}
		<div class="search-bar">
			<input 
				type="text" 
				placeholder="Search by username or EMP ID..." 
				bind:value={userSearchQuery}
				class="search-input"
			/>
			<select 
				bind:value={selectedBranchFilter}
				class="branch-filter"
			>
				<option value="">All Branches</option>
				{#each branches as branch (branch.id)}
					<option value={branch.id}>{branch.name_en}</option>
				{/each}
			</select>
		</div>

		<div class="table-wrapper">
			<table class="users-table">
				<thead>
					<tr>
						<th>EMP ID</th>
						<th>Username</th>
						<th>Status</th>
						<th>Current Branch</th>
						<th>Name</th>
						{#each branches as branch (branch.id)}
							<th>{branch.name_en}</th>
						{/each}
					</tr>
				</thead>
				<tbody>
					{#each filteredUsers as user, userIndex (user.id)}
						<tr class:inactive-row={user.status === 'inactive'} class:missing-master={!user.master_id || !branches.some(b => user[`branch_${b.id}_employee`])}>
							<td>{user.master_id || '-'}</td>
							<td>{user.username}</td>
							<td>{user.status || '-'}</td>
							<td>{branchMap[user.branch_id] || '-'}</td>
							<td class="cell-with-button">
								<div 
									class="cell-content"
									on:dblclick={() => openNameModal(userIndex)}
									role="button"
									tabindex="0"
								>
									{#if user.english_name || user.arabic_name}
										<div class="name-line">{user.english_name || ''}</div>
										<div class="name-line">{user.arabic_name || ''}</div>
									{/if}
								</div>
								{#if !user.english_name && !user.arabic_name}
									<button 
										class="add-btn"
										on:click={() => openNameModal(userIndex)}
										title="Add names"
									>
										+
									</button>
								{/if}
							</td>
							{#each branches as branch (branch.id)}
								<td class="cell-with-button">
									<div 
										class="cell-content"
										on:dblclick={() => openBranchModal(branch.id, userIndex)}
										role="button"
										tabindex="0"
									>
										{user[`branch_${branch.id}_employee`] || ''}
									</div>
									{#if user[`branch_${branch.id}_employee`]}
										<button 
											class="clear-btn"
											on:click={() => user[`branch_${branch.id}_employee`] = ''}
											title="Clear employee"
										>
											×
										</button>
									{:else}
										<button 
											class="add-btn"
											on:click={() => openBranchModal(branch.id, userIndex)}
											title="Add employee"
										>
											+
										</button>
									{/if}
								</td>
							{/each}
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>

<!-- Modal -->
{#if isModalOpen}
	<div class="modal-overlay" on:click={closeModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2>Select Employee</h2>
				<button class="close-btn" on:click={closeModal}>×</button>
			</div>

			<div class="modal-search">
				<input 
					type="text" 
					placeholder="Search by name or employee ID..." 
					bind:value={employeeSearchQuery}
					class="search-input"
				/>
			</div>

			{#if modalIsLoading}
				<div class="loading-state">Loading employees...</div>
			{:else if filteredEmployees.length === 0}
				<div class="empty-state">No employees found</div>
			{:else}
				<div class="modal-table-wrapper">
					<table class="modal-table">
						<thead>
							<tr>
								<th>Employee ID</th>
								<th>Name</th>
								<th>Action</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredEmployees as employee (employee.id)}
								<tr>
									<td>{employee.employee_id}</td>
									<td>{employee.name}</td>
									<td>
										<button 
											class="select-btn"
											on:click={() => selectEmployee(employee)}
										>
											Select
										</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	</div>
{/if}

<!-- Name Modal -->
{#if isNameModalOpen}
	<div class="modal-overlay" on:click={closeNameModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2>Add Names</h2>
				<button class="close-btn" on:click={closeNameModal}>×</button>
			</div>

			<div class="name-modal-body">
				<div class="form-group">
					<label for="english-name">English Name</label>
					<input 
						id="english-name"
						type="text" 
						placeholder="Enter English name..." 
						bind:value={englishNameInput}
						class="name-input"
					/>
				</div>

				<div class="form-group">
					<label for="arabic-name">Arabic Name</label>
					<input 
						id="arabic-name"
						type="text" 
						placeholder="Enter Arabic name..." 
						bind:value={arabicNameInput}
						class="name-input"
					/>
				</div>

				<div class="modal-footer">
					<button class="cancel-btn" on:click={closeNameModal}>Cancel</button>
					<button class="save-btn" on:click={saveNames}>Save</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.container {
		padding: 16px;
		height: 100%;
		display: flex;
		flex-direction: column;
	}

	.button-cards-section {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 12px;
		margin-bottom: 16px;
		flex-shrink: 0;
	}

	.button-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.card-button {
		padding: 10px 20px;
		background: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		width: 100%;
	}

	.card-button:hover {
		background: #e5e7eb;
		border-color: #9ca3af;
	}

	.header-section {
		display: flex;
		gap: 12px;
		margin-bottom: 16px;
		flex-shrink: 0;
	}

	.load-users-btn {
		padding: 8px 16px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
		align-self: flex-start;
	}

	.load-users-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.load-users-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	.save-all-btn {
		padding: 8px 16px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
		align-self: flex-start;
	}

	.save-all-btn:hover:not(:disabled) {
		background: #059669;
	}

	.save-all-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	.error-message {
		padding: 12px;
		background: #fee2e2;
		color: #991b1b;
		border-radius: 6px;
		margin-bottom: 16px;
		font-size: 14px;
	}

	.success-message {
		padding: 12px;
		background: #dcfce7;
		color: #166534;
		border-radius: 6px;
		margin-bottom: 16px;
		font-size: 14px;
	}

	.search-bar {
		margin-bottom: 16px;
		flex-shrink: 0;
		display: flex;
		gap: 12px;
	}

	.search-input {
		flex: 1;
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.branch-filter {
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		cursor: pointer;
	}

	.branch-filter:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.table-wrapper {
		overflow-y: auto;
		overflow-x: auto;
		flex: 1;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
	}

	.users-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 14px;
	}

	.users-table thead {
		background: #f3f4f6;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.users-table th {
		padding: 12px;
		text-align: left;
		font-weight: 600;
		color: #111827;
		border-bottom: 2px solid #e5e7eb;
	}

	.users-table td {
		padding: 12px;
		border-bottom: 1px solid #e5e7eb;
		color: #374151;
	}

	.users-table tbody tr:hover {
		background: #f9fafb;
	}

	.inactive-row {
		background-color: #fee2e2 !important;
	}

	.inactive-row:hover {
		background-color: #fecaca !important;
	}

	.missing-master {
		background-color: #fef9c3 !important;
	}

	.missing-master:hover {
		background-color: #fef08a !important;
	}

	.cell-with-button {
		position: relative;
	}

	.cell-content {
		display: inline-block;
		margin-right: 8px;
		min-width: 60px;
		cursor: pointer;
		padding: 2px 4px;
		border-radius: 3px;
		transition: background 0.2s;
	}

	.cell-content:hover {
		background: #f0f9ff;
	}

	.name-line {
		font-size: 13px;
		line-height: 1.4;
	}

	.add-btn {
		background: #10b981;
		color: white;
		border: none;
		border-radius: 4px;
		width: 24px;
		height: 24px;
		font-size: 16px;
		cursor: pointer;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		transition: background 0.2s;
		padding: 0;
	}

	.add-btn:hover {
		background: #059669;
	}

	.clear-btn {
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 4px;
		width: 24px;
		height: 24px;
		font-size: 16px;
		cursor: pointer;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		transition: background 0.2s;
		padding: 0;
	}

	.clear-btn:hover {
		background: #dc2626;
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
		border-radius: 12px;
		box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
		max-width: 600px;
		width: 90%;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 18px;
		color: #111827;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 28px;
		color: #6b7280;
		cursor: pointer;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.close-btn:hover {
		color: #111827;
	}

	.modal-search {
		padding: 16px 20px;
		border-bottom: 1px solid #e5e7eb;
	}

	.search-input {
		width: 100%;
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.loading-state, .empty-state {
		padding: 40px 20px;
		text-align: center;
		color: #6b7280;
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.modal-table-wrapper {
		overflow-y: auto;
		flex: 1;
		padding: 0 20px;
	}

	.modal-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 14px;
	}

	.modal-table thead {
		background: #f9fafb;
		position: sticky;
		top: 0;
	}

	.modal-table th {
		padding: 12px 0;
		text-align: left;
		font-weight: 600;
		color: #111827;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-table td {
		padding: 12px 0;
		border-bottom: 1px solid #e5e7eb;
		color: #374151;
	}

	.modal-table tbody tr:hover {
		background: #f3f4f6;
	}

	.select-btn {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 4px;
		padding: 6px 12px;
		font-size: 12px;
		cursor: pointer;
		transition: background 0.2s;
	}

	.select-btn:hover {
		background: #2563eb;
	}

	/* Name Modal Styles */
	.name-modal-body {
		padding: 24px;
	}

	.form-group {
		margin-bottom: 16px;
	}

	.form-group label {
		display: block;
		margin-bottom: 8px;
		font-weight: 500;
		color: #111827;
		font-size: 14px;
	}

	.name-input {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		box-sizing: border-box;
	}

	.name-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.modal-footer {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
		margin-top: 20px;
	}

	.cancel-btn {
		background: #e5e7eb;
		color: #111827;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}

	.cancel-btn:hover {
		background: #d1d5db;
	}

	.save-btn {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}

	.save-btn:hover {
		background: #2563eb;
	}
</style>
