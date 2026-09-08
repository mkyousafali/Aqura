<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { _ as t, currentLocale } from '$lib/i18n';

	$: isArabic = $currentLocale === 'ar';
	$: displayName = (user) => isArabic ? (user.arabic_name || user.english_name || '') : (user.english_name || user.arabic_name || '');

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

	// Tab state
	let activeTab = 'biometric'; // 'biometric' | 'erp'

	// ERP Link state
	let erpBranches = [];
	let erpSelectedBranch = null;
	let erpSearchQuery = '';
	let erpSearchResults = [];
	let erpIsSearching = false;
	let erpSearchError = '';
	let erpSelectedEmployee = null; // { erpEmployeeId, name, code }

	// User search for ERP tab
	let erpUserSearchQuery = '';
	let erpSelectedUserId = null;
	let erpBalance = null; // { netBalance, direction, totalDebit, totalCredit, ledgerName }
	let erpIsLoadingBalance = false;
	let erpSaveSuccess = '';
	let erpSaveError = '';
	let erpLinkedMap = {}; // user_id -> { branch_id -> erp_employee_id }
	let erpLinkedBalances = {}; // `${userId}_${branchId}` -> balance object
	let erpLinkedBalancesLoading = false;

	async function loadLinkedBalances(userId) {
		const links = erpLinkedMap[userId];
		console.log('[ERP Balance] loadLinkedBalances called', userId, links);
		if (!links || Object.keys(links).length === 0) return;
		erpLinkedBalancesLoading = true;
		for (const [branchId, empId] of Object.entries(links)) {
			try {
				console.log('[ERP Balance] fetching', branchId, empId);
				const resp = await fetch('/api/erp-employee-balance', {
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({ branchId: parseInt(branchId), erpEmployeeId: empId })
				});
				const data = await resp.json();
				console.log('[ERP Balance] result', data);
				if (data.success && data.balance) {
					erpLinkedBalances[`${userId}_${branchId}`] = data.balance;
					erpLinkedBalances = { ...erpLinkedBalances };
				}
			} catch (e) { console.error('[ERP Balance] error', e); }
		}
		erpLinkedBalancesLoading = false;
	}

	onMount(() => {
		loadUsers();
		loadErpBranches();
	});

	async function loadErpBranches() {
		const { data, error } = await supabase
			.from('erp_connections')
			.select('id, branch_id, branch_name, tunnel_url')
			.eq('is_active', true)
			.order('branch_id');
		if (!error && data) {
			erpBranches = data;
			if (data.length > 0) erpSelectedBranch = data[0];
		}
	}

	async function searchErpEmployees() {
		if (!erpSelectedBranch || erpSearchQuery.trim().length < 2) return;
		erpIsSearching = true;
		erpSearchError = '';
		erpSearchResults = [];
		try {
			const resp = await fetch(`/api/erp-employee-balance?branchId=${erpSelectedBranch.branch_id}&query=${encodeURIComponent(erpSearchQuery.trim())}`);
			const data = await resp.json();
			if (data.success) {
				erpSearchResults = data.employees;
			} else {
				erpSearchError = data.error || 'Search failed';
			}
		} catch (e) {
			erpSearchError = 'Connection error';
		} finally {
			erpIsSearching = false;
		}
	}

	function selectErpEmployee(emp) {
		erpSelectedEmployee = {
			erpEmployeeId: parseInt(emp.EmployeeID),
			name: emp.EmployeeName,
			code: emp.EmployeeCode
		};
		erpSearchResults = [];
		erpSearchQuery = `${emp.EmployeeCode} - ${emp.EmployeeName}`;
		erpBalance = null;
		if (erpSelectedUserId) loadErpBalance();
	}

	async function loadErpBalance() {
		if (!erpSelectedEmployee || !erpSelectedBranch) return;
		erpIsLoadingBalance = true;
		erpBalance = null;
		try {
			const resp = await fetch('/api/erp-employee-balance', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ branchId: erpSelectedBranch.branch_id, erpEmployeeId: erpSelectedEmployee.erpEmployeeId })
			});
			const data = await resp.json();
			if (data.success && data.balance) {
				erpBalance = data.balance;
			}
		} catch (e) {
			console.error('Balance load error', e);
		} finally {
			erpIsLoadingBalance = false;
		}
	}

	async function saveErpLink() {
		if (!erpSelectedUserId || !erpSelectedEmployee || !erpSelectedBranch) return;
		erpSaveError = '';
		erpSaveSuccess = '';

		// Get current master record for this user
		const { data: master, error: masterError } = await supabase
			.from('hr_employee_master')
			.select('id, erp_employee_id_mapping')
			.eq('user_id', erpSelectedUserId)
			.single();

		if (masterError || !master) {
			erpSaveError = 'User has no master record. Please save in the Biometric tab first.';
			return;
		}

		const currentMapping = master.erp_employee_id_mapping || {};
		const newMapping = { ...currentMapping, [erpSelectedBranch.branch_id.toString()]: erpSelectedEmployee.erpEmployeeId };

		const { error: updateError } = await supabase
			.from('hr_employee_master')
			.update({ erp_employee_id_mapping: newMapping, updated_at: new Date().toISOString() })
			.eq('id', master.id);

		if (updateError) {
			erpSaveError = updateError.message;
		} else {
			erpSaveSuccess = `Linked ERP Employee #${erpSelectedEmployee.erpEmployeeId} (${erpSelectedEmployee.name}) to this user for ${erpSelectedBranch.branch_name}`;
			// Update local map
			if (!erpLinkedMap[erpSelectedUserId]) erpLinkedMap[erpSelectedUserId] = {};
			erpLinkedMap[erpSelectedUserId][erpSelectedBranch.branch_id] = erpSelectedEmployee.erpEmployeeId;
			erpLinkedMap = { ...erpLinkedMap };
			// Load balance
			await loadErpBalance();
			await loadLinkedBalances(erpSelectedUserId);
		}
	}

	async function removeErpLink(userId, branchId) {
		const { data: master } = await supabase
			.from('hr_employee_master')
			.select('id, erp_employee_id_mapping')
			.eq('user_id', userId)
			.single();

		if (!master) return;
		const newMapping = { ...master.erp_employee_id_mapping };
		delete newMapping[branchId.toString()];
		await supabase.from('hr_employee_master').update({ erp_employee_id_mapping: newMapping }).eq('id', master.id);
		if (erpLinkedMap[userId]) {
			delete erpLinkedMap[userId][branchId];
			erpLinkedMap = { ...erpLinkedMap };
		}
	}

	$: erpFilteredUsers = users.filter(u =>
		u.status !== 'inactive' &&
		(u.username.toLowerCase().includes(erpUserSearchQuery.toLowerCase()) ||
		(u.master_id && u.master_id.toLowerCase().includes(erpUserSearchQuery.toLowerCase())))
	).slice(0, 100);

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
				.select('id, name_en, name_ar')
				.eq('is_active', true)
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
				.select('user_id, id, name_en, name_ar, employee_id_mapping, erp_employee_id_mapping, current_branch_id, current_position_id')
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
				branchMap[branch.id] = branch;
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

			// Populate ERP linked map from master data
			const newErpLinkedMap = {};
			masterData?.forEach(record => {
				if (record.erp_employee_id_mapping && Object.keys(record.erp_employee_id_mapping).length > 0) {
					newErpLinkedMap[record.user_id] = record.erp_employee_id_mapping;
				}
			});
			erpLinkedMap = newErpLinkedMap;
		} catch (error) {
			console.error('Error loading users:', error);
			errorMessage = error.message || 'Failed to load users';
		} finally {
			isLoading = false;
		}
	}

	async function openBranchModal(branchId, userId) {
		const userIndex = users.findIndex(u => u.id === userId);
		if (userIndex === -1) return;
		
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

	function openNameModal(userId) {
		const userIndex = users.findIndex(u => u.id === userId);
		if (userIndex === -1) return;
		
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
		user.status !== 'inactive' &&
		(user.username.toLowerCase().includes(userSearchQuery.toLowerCase()) ||
		(user.master_id && user.master_id.toLowerCase().includes(userSearchQuery.toLowerCase()))) &&
		(selectedBranchFilter === '' || user.branch_id === parseInt(selectedBranchFilter))
	);
</script>

<div class="container">

	<!-- Tab bar -->
	<div class="tab-bar">
		<button class="tab-btn" class:active={activeTab === 'biometric'} on:click={() => activeTab = 'biometric'}>
			🖐 Biometric Link
		</button>
		<button class="tab-btn" class:active={activeTab === 'erp'} on:click={() => activeTab = 'erp'}>
			🏢 ERP Employee Link
		</button>
	</div>

	<!-- ===================== BIOMETRIC TAB ===================== -->
	{#if activeTab === 'biometric'}

	<div class="header-section">
		<button class="load-users-btn" on:click={loadUsers} disabled={isLoading}>
		{isLoading ? `⏳ ${$t('hr.linkId.loading')}` : `🔄 ${$t('hr.linkId.loadUsers')}`}
		</button>
		
		{#if users.length > 0}
			<button class="save-all-btn" on:click={saveAllData} disabled={isSaving}>
				{isSaving ? `⏳ ${$t('hr.linkId.saving')}` : `💾 ${$t('hr.linkId.saveAll')}`}
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
				placeholder={$t('hr.linkId.searchPlaceholder')} 
				bind:value={userSearchQuery}
				class="search-input"
			/>
			<select 
				bind:value={selectedBranchFilter}
				class="branch-filter"
			>
				<option value="">{$t('hr.linkId.allBranches')}</option>
				{#each branches as branch (branch.id)}
					<option value={branch.id}>{isArabic ? (branch.name_ar || branch.name_en) : branch.name_en}</option>
				{/each}
			</select>
		</div>

		<div class="table-wrapper">
			<table class="users-table">
				<thead>
					<tr>
						<th>{$t('hr.linkId.empId')}</th>
						<th>{$t('hr.linkId.username')}</th>
						<th>{$t('hr.linkId.status')}</th>
						<th>{$t('hr.linkId.currentBranch')}</th>
						<th>{$t('hr.linkId.name')}</th>
						{#each branches as branch (branch.id)}
							<th>{isArabic ? (branch.name_ar || branch.name_en) : branch.name_en}</th>
						{/each}
					</tr>
				</thead>
				<tbody>
					{#each filteredUsers as user, userIndex (user.id)}
						<tr class:inactive-row={user.status === 'inactive'} class:missing-master={!user.master_id || !branches.some(b => user[`branch_${b.id}_employee`])}>
							<td>{user.master_id || '-'}</td>
							<td>{user.username}</td>
							<td>{user.status || '-'}</td>
								<td>{branchMap[user.branch_id] ? (isArabic ? (branchMap[user.branch_id].name_ar || branchMap[user.branch_id].name_en) : branchMap[user.branch_id].name_en) : '-'}</td>
							<td class="cell-with-button">
								<div 
									class="cell-content"
									on:dblclick={() => openNameModal(user.id)}
									role="button"
									tabindex="0"
								>
									{#if user.english_name || user.arabic_name}
										<div class="name-line">{isArabic ? (user.arabic_name || user.english_name || '') : (user.english_name || user.arabic_name || '')}</div>
									{/if}
								</div>
								{#if !user.english_name && !user.arabic_name}
									<button 
										class="add-btn"
										on:click={() => openNameModal(user.id)}
										title={$t('hr.linkId.addNamesTooltip')}
									>
										+
									</button>
								{/if}
							</td>
							{#each branches as branch (branch.id)}
								<td class="cell-with-button">
									<div 
										class="cell-content"
										on:dblclick={() => openBranchModal(branch.id, user.id)}
										role="button"
										tabindex="0"
									>
										{user[`branch_${branch.id}_employee`] || ''}
									</div>
									{#if user[`branch_${branch.id}_employee`]}
										<button 
											class="clear-btn"
											on:click={() => user[`branch_${branch.id}_employee`] = ''}
											title={$t('hr.linkId.clearEmployee')}
										>
											×
										</button>
									{:else}
										<button 
											class="add-btn"
											on:click={() => openBranchModal(branch.id, user.id)}
											title={$t('hr.linkId.addEmployee')}
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

	{/if}
	<!-- END BIOMETRIC TAB -->

	<!-- ===================== ERP EMPLOYEE LINK TAB ===================== -->
	{#if activeTab === 'erp'}
	<div class="erp-tab">

		<div class="erp-columns">

			<!-- LEFT: User selector -->
			<div class="erp-panel">
				<h3 class="erp-panel-title">👤 Select User</h3>
				<input
					type="text"
					class="search-input"
					placeholder="Search username or EMP ID..."
					bind:value={erpUserSearchQuery}
				/>
				<div class="erp-user-list">
					{#each erpFilteredUsers as user (user.id)}
						<button
							class="erp-user-item"
							class:selected={erpSelectedUserId === user.id}
							on:click={() => { erpSelectedUserId = user.id; erpSaveSuccess = ''; erpSaveError = ''; erpBalance = null; if (erpSelectedEmployee) loadErpBalance(); loadLinkedBalances(user.id); }}
						>
							<span class="erp-user-emp">{user.master_id || '—'}</span>
							<span class="erp-user-name">{user.username}</span>
							{#if erpLinkedMap[user.id] && Object.keys(erpLinkedMap[user.id]).length > 0}
								<span class="erp-linked-badge">🔗 {Object.keys(erpLinkedMap[user.id]).length}</span>
							{/if}
						</button>
					{/each}
					{#if erpFilteredUsers.length === 0 && users.length === 0}
						<div class="erp-empty">Load users first (click Biometric tab → Load Users)</div>
					{/if}
				</div>
			</div>

			<!-- RIGHT: ERP Search + Balance -->
			<div class="erp-panel right">
				<h3 class="erp-panel-title">🏢 ERP Employee</h3>

				<!-- Branch selector -->
				<div class="erp-branch-row">
					<!-- svelte-ignore a11y-label-has-associated-control -->
					<label>Branch:</label>
					<select class="erp-branch-select" bind:value={erpSelectedBranch}>
						{#each erpBranches as b (b.branch_id)}
							<option value={b}>{b.branch_name}</option>
						{/each}
					</select>
				</div>

				<!-- ERP employee search -->
				<div class="erp-search-row">
					<input
						type="text"
						class="search-input"
						placeholder="Search ERP employee by name, code or ID..."
						bind:value={erpSearchQuery}
						on:keydown={(e) => e.key === 'Enter' && searchErpEmployees()}
					/>
					<button class="erp-search-btn" on:click={searchErpEmployees} disabled={erpIsSearching}>
						{erpIsSearching ? '⏳' : '🔍'}
					</button>
				</div>

				{#if erpSearchError}
					<div class="erp-error">{erpSearchError}</div>
				{/if}

				<!-- Search results dropdown -->
				{#if erpSearchResults.length > 0}
					<div class="erp-results">
						{#each erpSearchResults as emp (emp.EmployeeID)}
							<button class="erp-result-item" on:click={() => selectErpEmployee(emp)}>
								<span class="erp-result-id">#{emp.EmployeeID}</span>
								<span class="erp-result-code">{emp.EmployeeCode}</span>
								<span class="erp-result-name">{emp.EmployeeName}</span>
							</button>
						{/each}
					</div>
				{/if}

				<!-- Selected ERP employee -->
				{#if erpSelectedEmployee}
					<div class="erp-selected-emp">
						<div class="erp-selected-row">
							<span class="erp-label">ERP ID:</span>
							<span class="erp-value">{erpSelectedEmployee.erpEmployeeId}</span>
						</div>
						<div class="erp-selected-row">
							<span class="erp-label">Code:</span>
							<span class="erp-value">{erpSelectedEmployee.code}</span>
						</div>
						<div class="erp-selected-row">
							<span class="erp-label">Name:</span>
							<span class="erp-value">{erpSelectedEmployee.name}</span>
						</div>
					</div>

					<!-- Balance -->
					{#if erpIsLoadingBalance}
						<div class="erp-balance-loading">⏳ Loading balance...</div>
					{:else if erpBalance}
						<div class="erp-balance" class:balance-dr={erpBalance.direction === 'Dr'} class:balance-cr={erpBalance.direction === 'Cr'}>
							<div class="erp-balance-title">📊 Ledger Balance — {erpSelectedBranch?.branch_name}</div>
							<div class="erp-balance-row"><span>Debit:</span><span>{erpBalance.totalDebit.toFixed(2)}</span></div>
							<div class="erp-balance-row"><span>Credit:</span><span>{erpBalance.totalCredit.toFixed(2)}</span></div>
							<div class="erp-balance-main">
								<span>Balance:</span>
								<span class="erp-balance-amount">{erpBalance.netBalance.toFixed(2)} {erpBalance.direction}</span>
							</div>
						</div>
					{/if}

					<!-- Link / Save button -->
					{#if erpSelectedUserId}
						<button
							class="erp-link-btn"
							on:click={saveErpLink}
							disabled={!erpSelectedEmployee || !erpSelectedBranch}
						>
							🔗 Link ERP Employee to Selected User
						</button>
					{:else}
						<div class="erp-hint">← Select a user on the left to link</div>
					{/if}
				{/if}

				{#if erpSaveSuccess}
					<div class="erp-success">{erpSaveSuccess}</div>
				{/if}
				{#if erpSaveError}
					<div class="erp-error">{erpSaveError}</div>
				{/if}
			</div>
		</div>

		<!-- Linked ERP IDs table for selected user -->
		{#if erpSelectedUserId}
			{@const selectedUser = users.find(u => u.id === erpSelectedUserId)}
			{#if selectedUser}
			<div class="erp-links-section">
				<h3 class="erp-panel-title">🔗 ERP Links for: {selectedUser.username} ({selectedUser.master_id || '—'})</h3>
				{#if Object.keys(erpLinkedMap[erpSelectedUserId] || {}).length === 0}
					<div class="erp-empty">No ERP links yet for this user.</div>
				{:else}
					<table class="erp-links-table">
						<thead>
							<tr><th>Branch</th><th>ERP ID</th><th>Debit</th><th>Credit</th><th>Balance</th><th>Action</th></tr>
						</thead>
						<tbody>
							{#each Object.entries(erpLinkedMap[erpSelectedUserId] || {}) as [branchId, empId]}
								{@const branchInfo = erpBranches.find(b => b.branch_id.toString() === branchId)}
								{@const bal = erpLinkedBalances[`${erpSelectedUserId}_${branchId}`]}
								<tr>
									<td>{branchInfo?.branch_name || `Branch ${branchId}`}</td>
									<td>{empId}</td>
									<td class="num-cell">{bal ? bal.totalDebit.toFixed(2) : (erpLinkedBalancesLoading ? '…' : '—')}</td>
									<td class="num-cell">{bal ? bal.totalCredit.toFixed(2) : (erpLinkedBalancesLoading ? '…' : '—')}</td>
									<td class="balance-cell" class:bal-dr={bal?.direction === 'Dr'} class:bal-cr={bal?.direction === 'Cr'}>
										{bal ? `${bal.netBalance.toFixed(2)} ${bal.direction}` : (erpLinkedBalancesLoading ? '⏳' : '—')}
									</td>
									<td>
										<button class="erp-remove-btn" on:click={() => removeErpLink(erpSelectedUserId, parseInt(branchId))}>Remove</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				{/if}
			</div>
			{/if}
		{/if}

	</div>
	{/if}
	<!-- END ERP TAB -->

</div>

<!-- Modal -->
{#if isModalOpen}
	<div class="modal-overlay" on:click={closeModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2>{$t('hr.linkId.selectEmployee')}</h2>
				<button class="close-btn" on:click={closeModal}>×</button>
			</div>

			<div class="modal-search">
				<input 
					type="text" 
					placeholder={$t('hr.linkId.searchEmployeePlaceholder')} 
					bind:value={employeeSearchQuery}
					class="search-input"
				/>
			</div>

			{#if modalIsLoading}
				<div class="loading-state">{$t('hr.linkId.loadingEmployees')}</div>
			{:else if filteredEmployees.length === 0}
				<div class="empty-state">{$t('hr.linkId.noEmployeesFound')}</div>
			{:else}
				<div class="modal-table-wrapper">
					<table class="modal-table">
						<thead>
							<tr>
								<th>{$t('hr.linkId.employeeId')}</th>
								<th>{$t('hr.linkId.name')}</th>
								<th>{$t('hr.linkId.action')}</th>
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
				<h2>{$t('hr.linkId.addNames')}</h2>
				<button class="close-btn" on:click={closeNameModal}>×</button>
			</div>

			<div class="name-modal-body">
				<div class="form-group">
					<label for="english-name">{$t('hr.linkId.englishName')}</label>
					<input 
						id="english-name"
						type="text" 
						placeholder={$t('hr.linkId.enterEnglishName')} 
						bind:value={englishNameInput}
						class="name-input"
					/>
				</div>

				<div class="form-group">
					<label for="arabic-name">{$t('hr.linkId.arabicName')}</label>
					<input 
						id="arabic-name"
						type="text" 
						placeholder={$t('hr.linkId.enterArabicName')} 
						bind:value={arabicNameInput}
						class="name-input"
					/>
				</div>

				<div class="modal-footer">
					<button class="cancel-btn" on:click={closeNameModal}>{$t('hr.linkId.cancel')}</button>
					<button class="save-btn" on:click={saveNames}>{$t('hr.linkId.save')}</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.container {
		position: absolute;
		inset: 0;
		padding: 16px;
		box-sizing: border-box;
		display: flex;
		flex-direction: column;
		background: linear-gradient(135deg, #f5f3ff 0%, #fff7ed 50%, #f0fdf4 100%);
		font-family: inherit;
		overflow: hidden;
	}

	/* ---- Tab bar ---- */
	.tab-bar {
		display: flex;
		gap: 6px;
		margin-bottom: 12px;
		flex-shrink: 0;
	}
	.tab-btn {
		padding: 8px 18px;
		border: 2px solid #e2e8f0;
		border-radius: 10px;
		background: #fff;
		color: #475569;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}
	.tab-btn.active {
		background: linear-gradient(135deg, #7c3aed, #6d28d9);
		color: #fff;
		border-color: #7c3aed;
	}
	.tab-btn:hover:not(.active) {
		background: #f1f5f9;
		border-color: #7c3aed;
		color: #7c3aed;
	}

	/* ---- ERP Tab ---- */
	.erp-tab {
		flex: 1;
		overflow: hidden;
		display: grid;
		grid-template-rows: 1fr auto;
		gap: 10px;
	}
	.erp-columns {
		display: grid;
		grid-template-columns: 325px 1fr;
		gap: 10px;
		overflow: hidden;
	}
	.erp-panel {
		background: #fff;
		border: 1px solid #e2e8f0;
		border-radius: 10px;
		padding: 10px;
		display: flex;
		flex-direction: column;
		gap: 7px;
		overflow: hidden;
	}
	.erp-panel-title {
		font-size: 12px;
		font-weight: 700;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		margin: 0;
		flex-shrink: 0;
	}
	.erp-user-list {
		flex: 1;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 2px;
	}
	.erp-user-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 7px 10px;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		background: #fff;
		cursor: pointer;
		text-align: left;
		font-size: 12px;
		transition: all 0.12s;
		width: 100%;
		box-shadow: 0 1px 3px rgba(0,0,0,0.04);
	}
	.erp-user-item:hover { background: #ede9fe; border-color: #c4b5fd; box-shadow: 0 2px 6px rgba(124,58,237,0.12); }
	.erp-user-item.selected { background: linear-gradient(135deg, #7c3aed, #6d28d9); color: #fff; border-color: #7c3aed; box-shadow: 0 2px 8px rgba(124,58,237,0.3); }
	.erp-user-emp { font-weight: 700; min-width: 48px; font-size: 10px; opacity: 0.8; flex-shrink: 0; }
	.erp-user-name { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.erp-linked-badge { background: #22c55e; color: #fff; border-radius: 999px; padding: 1px 5px; font-size: 10px; font-weight: 700; flex-shrink: 0; }

	/* Right panel scrollable */
	.erp-panel.right { overflow-y: auto; }

	.erp-branch-row { display: flex; align-items: center; gap: 6px; font-size: 12px; flex-shrink: 0; }
	.erp-branch-row label { color: #64748b; font-weight: 600; white-space: nowrap; }
	.erp-branch-select { flex: 1; padding: 5px 8px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 12px; background: #f8fafc; }

	.erp-search-row { display: flex; gap: 5px; flex-shrink: 0; }
	.erp-search-row .search-input { font-size: 12px; padding: 6px 10px; }
	.erp-search-btn {
		padding: 6px 12px;
		background: linear-gradient(135deg, #7c3aed, #6d28d9);
		color: #fff;
		border: none;
		border-radius: 7px;
		font-size: 13px;
		cursor: pointer;
		flex-shrink: 0;
	}
	.erp-search-btn:disabled { opacity: 0.6; }

	.erp-results {
		border: 1px solid #e2e8f0;
		border-radius: 7px;
		max-height: 130px;
		overflow-y: auto;
		background: #fff;
		flex-shrink: 0;
	}
	.erp-result-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 5px 10px;
		width: 100%;
		background: none;
		border: none;
		border-bottom: 1px solid #f1f5f9;
		cursor: pointer;
		text-align: left;
		font-size: 11px;
		transition: background 0.12s;
	}
	.erp-result-item:hover { background: #ede9fe; }
	.erp-result-id { font-weight: 700; color: #7c3aed; min-width: 30px; }
	.erp-result-code { color: #64748b; min-width: 44px; }
	.erp-result-name { flex: 1; }

	.erp-selected-emp {
		background: #f0fdf4;
		border: 1px solid #86efac;
		border-radius: 8px;
		padding: 7px 10px;
		display: flex;
		gap: 12px;
		flex-wrap: wrap;
		flex-shrink: 0;
	}
	.erp-selected-row { display: flex; gap: 5px; font-size: 12px; align-items: center; }
	.erp-label { font-weight: 600; color: #475569; }
	.erp-value { color: #1e293b; }

	.erp-balance {
		border-radius: 8px;
		padding: 8px 12px;
		display: flex;
		align-items: center;
		gap: 16px;
		font-size: 12px;
		flex-shrink: 0;
		flex-wrap: wrap;
	}
	.balance-dr { background: #fff7ed; border: 1px solid #fdba74; }
	.balance-cr { background: #f0fdf4; border: 1px solid #86efac; }
	.erp-balance-title { font-weight: 700; font-size: 11px; color: #64748b; white-space: nowrap; }
	.erp-balance-row { display: flex; gap: 4px; color: #475569; }
	.erp-balance-main { display: flex; gap: 6px; font-weight: 700; font-size: 14px; color: #1e293b; margin-left: auto; }
	.erp-balance-amount { color: #7c3aed; }
	.erp-balance-loading { font-size: 12px; color: #64748b; flex-shrink: 0; }

	.erp-link-btn {
		padding: 8px 16px;
		background: linear-gradient(135deg, #16a34a, #15803d);
		color: #fff;
		border: none;
		border-radius: 8px;
		font-size: 12px;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		flex-shrink: 0;
		align-self: flex-start;
	}
	.erp-link-btn:hover:not(:disabled) { opacity: 0.88; }
	.erp-link-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.erp-hint { font-size: 11px; color: #94a3b8; }

	.erp-success { background: #f0fdf4; border: 1px solid #86efac; color: #166534; border-radius: 7px; padding: 6px 10px; font-size: 11px; flex-shrink: 0; }
	.erp-error { background: #fef2f2; border: 1px solid #fca5a5; color: #991b1b; border-radius: 7px; padding: 6px 10px; font-size: 11px; flex-shrink: 0; }
	.erp-empty { font-size: 11px; color: #94a3b8; }

	.erp-links-section {
		background: #fff;
		border: 1px solid #e2e8f0;
		border-radius: 10px;
		padding: 10px 12px;
		flex-shrink: 0;
	}
	.erp-links-table { width: 100%; border-collapse: collapse; font-size: 12px; }
	.erp-links-table th { background: #f8fafc; padding: 6px 10px; text-align: left; font-weight: 600; color: #475569; border-bottom: 1px solid #e2e8f0; }
	.erp-links-table td { padding: 6px 10px; border-bottom: 1px solid #f1f5f9; }
	.num-cell { text-align: right; color: #475569; font-variant-numeric: tabular-nums; }
	.balance-cell { text-align: right; font-weight: 700; font-variant-numeric: tabular-nums; }
	.bal-dr { color: #c2410c; }
	.bal-cr { color: #15803d; }
	.erp-remove-btn {
		padding: 4px 10px;
		background: #fee2e2;
		color: #991b1b;
		border: 1px solid #fca5a5;
		border-radius: 6px;
		font-size: 12px;
		cursor: pointer;
	}
	.erp-remove-btn:hover { background: #fca5a5; }

	.header-section {
		display: flex;
		gap: 10px;
		margin-bottom: 14px;
		flex-shrink: 0;
		align-items: center;
	}

	.load-users-btn {
		padding: 9px 20px;
		background: linear-gradient(135deg, #7c3aed, #6d28d9);
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 2px 8px rgba(124,58,237,0.3);
		letter-spacing: 0.01em;
	}
	.load-users-btn:hover:not(:disabled) {
		background: linear-gradient(135deg, #6d28d9, #5b21b6);
		box-shadow: 0 4px 14px rgba(124,58,237,0.4);
		transform: translateY(-1px);
	}
	.load-users-btn:disabled { background: #c4b5fd; cursor: not-allowed; box-shadow: none; }

	.save-all-btn {
		padding: 9px 20px;
		background: linear-gradient(135deg, #22c55e, #16a34a);
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 2px 8px rgba(34,197,94,0.3);
	}
	.save-all-btn:hover:not(:disabled) {
		background: linear-gradient(135deg, #16a34a, #15803d);
		box-shadow: 0 4px 14px rgba(34,197,94,0.4);
		transform: translateY(-1px);
	}
	.save-all-btn:disabled { background: #86efac; cursor: not-allowed; box-shadow: none; }

	.error-message {
		padding: 11px 16px;
		background: rgba(254,226,226,0.8);
		color: #991b1b;
		border: 1px solid rgba(239,68,68,0.2);
		border-radius: 10px;
		margin-bottom: 12px;
		font-size: 13px;
		backdrop-filter: blur(8px);
	}

	.success-message {
		padding: 11px 16px;
		background: rgba(220,252,231,0.8);
		color: #166534;
		border: 1px solid rgba(34,197,94,0.2);
		border-radius: 10px;
		margin-bottom: 12px;
		font-size: 13px;
		backdrop-filter: blur(8px);
	}

	.search-bar {
		margin-bottom: 14px;
		flex-shrink: 0;
		display: flex;
		gap: 10px;
	}

	.erp-panel .search-input {
		padding: 5px 10px;
		font-size: 12px;
		border-radius: 7px;
		flex: none;
		width: 100%;
		box-sizing: border-box;
	}
	/* search row needs flex:1 on input so button stays visible */
	.erp-search-row .search-input {
		flex: 1;
		width: auto;
	}

	.search-input {
		flex: 1;
		padding: 9px 14px;
		border: 1.5px solid rgba(139,92,246,0.25);
		border-radius: 10px;
		font-size: 13px;
		background: rgba(255,255,255,0.8);
		backdrop-filter: blur(8px);
		color: #1e293b;
		transition: border-color 0.2s, box-shadow 0.2s;
	}
	.search-input:focus {
		outline: none;
		border-color: #7c3aed;
		box-shadow: 0 0 0 3px rgba(124,58,237,0.12);
	}

	.branch-filter {
		padding: 9px 14px;
		border: 1.5px solid rgba(139,92,246,0.25);
		border-radius: 10px;
		font-size: 13px;
		background: rgba(255,255,255,0.8);
		backdrop-filter: blur(8px);
		color: #1e293b;
		cursor: pointer;
		transition: border-color 0.2s;
	}
	.branch-filter:focus {
		outline: none;
		border-color: #7c3aed;
		box-shadow: 0 0 0 3px rgba(124,58,237,0.12);
	}

	.table-wrapper {
		overflow-y: auto;
		overflow-x: auto;
		flex: 1;
		border-radius: 14px;
		background: rgba(255,255,255,0.85);
		backdrop-filter: blur(10px);
		border: 1px solid rgba(139,92,246,0.15);
		box-shadow: 0 4px 20px rgba(0,0,0,0.06);
	}

	.users-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
	}

	.users-table thead th {
		padding: 11px 14px;
		text-align: left;
		font-size: 11px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #7c3aed;
		background: linear-gradient(135deg, rgba(237,233,254,0.9), rgba(255,247,237,0.9));
		border-bottom: 1px solid rgba(139,92,246,0.15);
		white-space: nowrap;
		position: sticky;
		top: 0;
		z-index: 2;
	}

	.users-table tbody tr {
		border-bottom: 1px solid rgba(226,232,240,0.7);
		transition: background 0.15s;
	}
	.users-table tbody tr:hover { background: rgba(237,233,254,0.25); }

	.users-table td {
		padding: 9px 14px;
		color: #334155;
		vertical-align: middle;
	}

	.inactive-row { background: rgba(254,226,226,0.4) !important; }
	.inactive-row:hover { background: rgba(254,202,202,0.5) !important; }
	.missing-master { background: rgba(254,249,195,0.4) !important; }
	.missing-master:hover { background: rgba(254,240,138,0.5) !important; }

	.cell-with-button {
		position: relative;
		white-space: nowrap;
	}

	.cell-content {
		display: inline-block;
		margin-right: 6px;
		min-width: 50px;
		cursor: pointer;
		padding: 2px 5px;
		border-radius: 5px;
		transition: background 0.15s;
		vertical-align: middle;
	}
	.cell-content:hover { background: rgba(139,92,246,0.08); }

	.name-line { font-size: 12px; line-height: 1.4; color: #1e293b; }

	.add-btn {
		background: linear-gradient(135deg, #22c55e, #16a34a);
		color: white;
		border: none;
		border-radius: 6px;
		width: 24px;
		height: 24px;
		font-size: 16px;
		cursor: pointer;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
		padding: 0;
		vertical-align: middle;
		box-shadow: 0 1px 4px rgba(34,197,94,0.3);
	}
	.add-btn:hover { transform: scale(1.15); box-shadow: 0 2px 8px rgba(34,197,94,0.4); }

	.clear-btn {
		background: linear-gradient(135deg, #f97316, #ea580c);
		color: white;
		border: none;
		border-radius: 6px;
		width: 24px;
		height: 24px;
		font-size: 16px;
		cursor: pointer;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
		padding: 0;
		vertical-align: middle;
		box-shadow: 0 1px 4px rgba(249,115,22,0.3);
	}
	.clear-btn:hover { transform: scale(1.15); box-shadow: 0 2px 8px rgba(249,115,22,0.4); }

	/* Modal */
	.modal-overlay {
		position: fixed;
		top: 0; left: 0; right: 0; bottom: 0;
		background: rgba(15,23,42,0.45);
		backdrop-filter: blur(4px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.modal-content {
		background: rgba(255,255,255,0.96);
		backdrop-filter: blur(20px);
		border-radius: 18px;
		box-shadow: 0 20px 60px rgba(0,0,0,0.2), 0 0 0 1px rgba(139,92,246,0.15);
		max-width: 600px;
		width: 90%;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 18px 22px;
		background: linear-gradient(135deg, rgba(237,233,254,0.8), rgba(255,247,237,0.8));
		border-bottom: 1px solid rgba(139,92,246,0.15);
	}
	.modal-header h2 {
		margin: 0;
		font-size: 16px;
		font-weight: 700;
		color: #4c1d95;
	}

	.close-btn {
		background: rgba(139,92,246,0.1);
		border: none;
		font-size: 20px;
		color: #7c3aed;
		cursor: pointer;
		padding: 0;
		width: 30px;
		height: 30px;
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}
	.close-btn:hover { background: rgba(139,92,246,0.2); color: #4c1d95; }

	.modal-search {
		padding: 14px 20px;
		border-bottom: 1px solid rgba(139,92,246,0.1);
	}
	.modal-search .search-input { width: 100%; box-sizing: border-box; }

	.loading-state, .empty-state {
		padding: 40px 20px;
		text-align: center;
		color: #94a3b8;
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 14px;
	}

	.modal-table-wrapper { overflow-y: auto; flex: 1; padding: 0 20px; }

	.modal-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
	}
	.modal-table thead { position: sticky; top: 0; background: white; }
	.modal-table th {
		padding: 10px 0;
		text-align: left;
		font-size: 11px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #7c3aed;
		border-bottom: 1px solid rgba(139,92,246,0.15);
	}
	.modal-table td {
		padding: 10px 0;
		border-bottom: 1px solid rgba(226,232,240,0.6);
		color: #334155;
	}
	.modal-table tbody tr:hover { background: rgba(237,233,254,0.2); }

	.select-btn {
		background: linear-gradient(135deg, #7c3aed, #6d28d9);
		color: white;
		border: none;
		border-radius: 6px;
		padding: 5px 12px;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 1px 4px rgba(124,58,237,0.3);
	}
	.select-btn:hover { background: linear-gradient(135deg, #6d28d9, #5b21b6); transform: translateY(-1px); }

	/* Name Modal */
	.name-modal-body { padding: 22px; }

	.form-group { margin-bottom: 16px; }
	.form-group label {
		display: block;
		margin-bottom: 6px;
		font-weight: 600;
		color: #4c1d95;
		font-size: 13px;
	}

	.name-input {
		width: 100%;
		padding: 10px 14px;
		border: 1.5px solid rgba(139,92,246,0.25);
		border-radius: 10px;
		font-size: 13px;
		box-sizing: border-box;
		background: rgba(255,255,255,0.9);
		color: #1e293b;
		transition: border-color 0.2s, box-shadow 0.2s;
	}
	.name-input:focus {
		outline: none;
		border-color: #7c3aed;
		box-shadow: 0 0 0 3px rgba(124,58,237,0.12);
	}

	.modal-footer {
		display: flex;
		gap: 10px;
		justify-content: flex-end;
		margin-top: 20px;
	}

	.cancel-btn {
		background: rgba(226,232,240,0.8);
		color: #475569;
		border: 1px solid rgba(148,163,184,0.3);
		border-radius: 8px;
		padding: 8px 18px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}
	.cancel-btn:hover { background: #e2e8f0; }

	.save-btn {
		background: linear-gradient(135deg, #f59e0b, #d97706);
		color: white;
		border: none;
		border-radius: 8px;
		padding: 8px 18px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 2px 8px rgba(245,158,11,0.3);
	}
	.save-btn:hover { background: linear-gradient(135deg, #d97706, #b45309); transform: translateY(-1px); }
</style>


