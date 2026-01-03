<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import IssueVoucherModal from '$lib/components/desktop-interface/master/finance/IssueVoucherModal.svelte';
	import BatchIssueModal from '$lib/components/desktop-interface/master/finance/BatchIssueModal.svelte';

	let issuedVouchers = [];
	let isLoading = false;
	let showTable = true;
	let branchMap = {};
	let userEmployeeMap = {};
	let selectedItems = new Set();
	let subscription;

	// Search options for loading
	let searchPVId = '';
	let searchSerialNumber = '';
	let hasLoaded = false;
	let loadedBy = ''; // 'pvId' or 'serial'
	let loadedValue = '';

	// Filter variables
	let filterSerialNumber = '';
	let filterLocation = '';
	let filterValue = '';

	$: selectedCount = selectedItems.size;

	onMount(async () => {
		setupRealtimeSubscription();
		await loadLookupData();

		return () => {
			if (subscription) {
				subscription.unsubscribe();
			}
		};
	});

	function setupRealtimeSubscription() {
		const channelName = `issue_purchase_voucher_${Date.now()}`;
		console.log('📡 IssuePurchaseVoucher: Setting up realtime subscription');
		
		subscription = supabase
			.channel(channelName)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'purchase_voucher_items'
				},
				(payload) => {
					console.log('🎫 IssuePurchaseVoucher: purchase_voucher_items changed', payload.eventType, payload.new?.serial_number || payload.old?.serial_number);
					handleVoucherItemUpdate(payload);
				}
			)
			.subscribe((status) => {
				console.log('📡 IssuePurchaseVoucher: Realtime subscription status:', status);
			});
	}

	function handleVoucherItemUpdate(payload) {
		const { eventType, new: newRecord, old: oldRecord } = payload;

		if (eventType === 'UPDATE' && newRecord) {
			// If issue_type changed from 'not issued' to something else, remove from list
			if (newRecord.issue_type !== 'not issued') {
				issuedVouchers = issuedVouchers.filter(item => item.id !== newRecord.id);
				selectedItems.delete(newRecord.id);
				selectedItems = selectedItems; // Trigger reactivity
				console.log('🔄 IssuePurchaseVoucher: Removed issued voucher from list:', newRecord.id);
			} else {
				// Update the item in place
				issuedVouchers = issuedVouchers.map(item => {
					if (item.id === newRecord.id) {
						return { ...item, ...newRecord };
					}
					return item;
				});
			}
		} else if (eventType === 'INSERT' && newRecord) {
			// Add new non-issued voucher
			if (newRecord.issue_type === 'not issued') {
				issuedVouchers = [...issuedVouchers, newRecord];
			}
		} else if (eventType === 'DELETE' && oldRecord) {
			issuedVouchers = issuedVouchers.filter(item => item.id !== oldRecord.id);
			selectedItems.delete(oldRecord.id);
			selectedItems = selectedItems;
		}
	}

	// Get unique filter values
	$: uniqueValues = {
		values: [...new Set(issuedVouchers.map((i) => i.value))].sort((a, b) => a - b),
		locations: [...new Set(issuedVouchers.map((i) => i.stock_location).filter(Boolean))]
	};

	// Computed filtered list
	$: filteredVouchers = issuedVouchers.filter((item) => {
		if (filterSerialNumber && !item.serial_number.toString().includes(filterSerialNumber)) return false;
		if (filterLocation && item.stock_location !== (filterLocation ? parseInt(filterLocation) : null)) return false;
		if (filterValue && item.value.toString() !== filterValue) return false;
		return true;
	});

	async function loadByPVId(pvId) {
		if (!pvId || !pvId.trim()) {
			alert('Please enter a PV ID to load');
			return;
		}
		
		isLoading = true;
		showTable = true;
		hasLoaded = true;
		loadedBy = 'pvId';
		loadedValue = pvId.trim();
		selectedItems.clear();
		selectedItems = selectedItems;
		
		try {
			const vouchersResult = await supabase
				.from('purchase_voucher_items')
				.select('id, purchase_voucher_id, serial_number, value, stock, status, issue_type, stock_location, stock_person')
				.eq('purchase_voucher_id', pvId.trim())
				.eq('issue_type', 'not issued')
				.order('serial_number', { ascending: true });

			if (vouchersResult.error) {
				console.error('Error loading non-issued vouchers:', vouchersResult.error);
				issuedVouchers = [];
			} else {
				issuedVouchers = vouchersResult.data || [];
			}
		} catch (error) {
			console.error('Error:', error);
			issuedVouchers = [];
		} finally {
			isLoading = false;
		}
	}

	async function loadBySerialNumber(serialNum) {
		if (!serialNum || !serialNum.trim()) {
			alert('Please enter a Serial Number to load');
			return;
		}
		
		isLoading = true;
		showTable = true;
		hasLoaded = true;
		loadedBy = 'serial';
		loadedValue = serialNum.trim();
		selectedItems.clear();
		selectedItems = selectedItems;
		
		try {
			const vouchersResult = await supabase
				.from('purchase_voucher_items')
				.select('id, purchase_voucher_id, serial_number, value, stock, status, issue_type, stock_location, stock_person')
				.eq('serial_number', parseInt(serialNum.trim()))
				.eq('issue_type', 'not issued')
				.order('purchase_voucher_id', { ascending: true });

			if (vouchersResult.error) {
				console.error('Error loading non-issued vouchers:', vouchersResult.error);
				issuedVouchers = [];
			} else {
				issuedVouchers = vouchersResult.data || [];
			}
		} catch (error) {
			console.error('Error:', error);
			issuedVouchers = [];
		} finally {
			isLoading = false;
		}
	}

	function handleLoadPVIdClick() {
		loadByPVId(searchPVId);
	}

	function handleLoadSerialClick() {
		loadBySerialNumber(searchSerialNumber);
	}

	function handlePVIdKeyPress(event) {
		if (event.key === 'Enter') {
			loadByPVId(searchPVId);
		}
	}

	function handleSerialKeyPress(event) {
		if (event.key === 'Enter') {
			loadBySerialNumber(searchSerialNumber);
		}
	}

	async function loadLookupData() {
		try {
			const [branchesResult, usersResult, employeesResult] = await Promise.all([
				supabase.from('branches').select('id, name_en, location_en').limit(50),
				supabase.from('users').select('id, username, employee_id').limit(200),
				supabase.from('hr_employees').select('id, name').limit(200)
			]);

			// Process branches
			if (!branchesResult.error && branchesResult.data) {
				branchMap = {};
				branchesResult.data.forEach((branch) => {
					branchMap[branch.id] = `${branch.name_en} - ${branch.location_en}`;
				});
				branchMap = branchMap; // Trigger reactivity
			}

			// Process users and employees
			if (!usersResult.error && !employeesResult.error) {
				const users = usersResult.data || [];
				const employees = employeesResult.data || [];

				const employeeMap = {};
				employees.forEach((emp) => {
					employeeMap[emp.id] = emp.name;
				});

				userEmployeeMap = {};
				users.forEach((user) => {
					if (user.employee_id && employeeMap[user.employee_id]) {
						userEmployeeMap[user.id] = `${user.username} - ${employeeMap[user.employee_id]}`;
					} else {
						userEmployeeMap[user.id] = user.username;
					}
				});
				userEmployeeMap = userEmployeeMap; // Trigger reactivity
			}
		} catch (error) {
			console.error('Error loading lookup data:', error);
		}
	}

	function toggleSelectAll() {
		if (selectedItems.size === filteredVouchers.length) {
			selectedItems.clear();
		} else {
			filteredVouchers.forEach((item) => selectedItems.add(item.id));
		}
		selectedItems = selectedItems;
	}

	function toggleItemSelection(itemId) {
		if (selectedItems.has(itemId)) {
			selectedItems.delete(itemId);
		} else {
			selectedItems.add(itemId);
		}
		selectedItems = selectedItems;
	}

	async function handleIssue(itemId) {
		const item = issuedVouchers.find((i) => i.id === itemId);
		if (!item) return;

		const windowId = `issue-voucher-${itemId}-${Date.now()}`;
		openWindow({
			id: windowId,
			title: `Issue Voucher - ${item.purchase_voucher_id}`,
			component: IssueVoucherModal,
			icon: '📝',
			size: { width: 500, height: 350 },
			position: { x: 400, y: 300 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: {
				item,
				itemId,
				windowId,
				onIssueComplete: () => {
					// Realtime will handle removing the voucher from the list
					// No need to reload the entire table
					console.log('✅ Issue complete - realtime will update the list');
				}
			}
		});
	}

	async function handleBatchIssue() {
		if (selectedItems.size === 0) return;

		const windowId = `batch-issue-${Date.now()}`;
		openWindow({
			id: windowId,
			title: `Batch Issue Vouchers (${selectedItems.size})`,
			component: BatchIssueModal,
			icon: '📦',
			size: { width: 500, height: 350 },
			position: { x: 450, y: 350 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: {
				itemIds: Array.from(selectedItems),
				count: selectedItems.size,
				windowId,
				onIssueComplete: () => {
					// Realtime will handle removing the vouchers from the list
					// Just clear the selection
					selectedItems.clear();
					selectedItems = selectedItems;
					console.log('✅ Batch issue complete - realtime will update the list');
				}
			}
		});
	}
</script>

<div class="issue-purchase-voucher">
	<div class="header">
		<h2>Issue Purchase Vouchers</h2>
		{#if selectedCount > 0}
			<button class="batch-button" on:click={handleBatchIssue}>
				Batch Issue ({selectedCount})
			</button>
		{/if}
	</div>

	<!-- Search Section -->
	<div class="search-section">
		<div class="search-options">
			<div class="search-box">
				<label for="pvIdSearch">Search by PV ID</label>
				<div class="search-input-group">
					<input 
						type="text" 
						id="pvIdSearch"
						placeholder="Enter PV ID (e.g., 100PV0001)" 
						bind:value={searchPVId}
						on:keypress={handlePVIdKeyPress}
						class="pv-search-input"
					/>
					<button class="load-button" on:click={handleLoadPVIdClick} disabled={isLoading}>
						{isLoading ? 'Loading...' : 'Load'}
					</button>
				</div>
			</div>
			
			<div class="search-divider">
				<span>OR</span>
			</div>
			
			<div class="search-box">
				<label for="serialSearch">Search by Serial Number</label>
				<div class="search-input-group">
					<input 
						type="text" 
						id="serialSearch"
						placeholder="Enter Serial Number (e.g., 101)" 
						bind:value={searchSerialNumber}
						on:keypress={handleSerialKeyPress}
						class="pv-search-input"
					/>
					<button class="load-button serial-btn" on:click={handleLoadSerialClick} disabled={isLoading}>
						{isLoading ? 'Loading...' : 'Load'}
					</button>
				</div>
			</div>
		</div>
		
		{#if hasLoaded && loadedValue}
			<div class="current-pv">
				Currently loaded by {loadedBy === 'pvId' ? 'PV ID' : 'Serial Number'}: <strong>{loadedValue}</strong>
			</div>
		{/if}
	</div>

	{#if !isLoading && issuedVouchers.length > 0}
		<div class="stats-card">
			<div class="stat-item">
				<div class="stat-label">Total Loaded</div>
				<div class="stat-value">{issuedVouchers.length}</div>
			</div>
			<div class="stat-item">
				<div class="stat-label">Filtered Results</div>
				<div class="stat-value">{filteredVouchers.length}</div>
			</div>
			<div class="stat-item">
				<div class="stat-label">Selected</div>
				<div class="stat-value highlight">{selectedCount}</div>
			</div>
		</div>
	{/if}

	{#if hasLoaded}
		{#if isLoading}
			<div class="loading">Loading non-issued vouchers...</div>
		{:else if issuedVouchers.length === 0}
			<div class="empty-state">No non-issued vouchers found for {loadedBy === 'pvId' ? 'PV ID' : 'Serial Number'}: {loadedValue}</div>
		{:else}
			<div class="filters-section">
				<div class="filter-row">
					<div class="filter-group">
						<label>Serial Number</label>
						<input type="text" placeholder="Search serial" bind:value={filterSerialNumber} />
					</div>
					<div class="filter-group">
						<label>Stock Location</label>
						<select bind:value={filterLocation}>
							<option value="">All Locations</option>
							{#each uniqueValues.locations as locId}
								<option value={locId}>{branchMap[locId] || locId}</option>
							{/each}
						</select>
					</div>
					<div class="filter-group">
						<label>Value</label>
						<select bind:value={filterValue}>
							<option value="">All Values</option>
							{#each uniqueValues.values as val}
								<option value={val.toString()}>{val}</option>
							{/each}
						</select>
					</div>
				</div>
			</div>
			<div class="table-wrapper">
				<table class="vouchers-table">
					<thead>
						<tr>
							<th style="width: 40px;">
								<input type="checkbox" checked={selectedItems.size === filteredVouchers.length && filteredVouchers.length > 0} on:change={toggleSelectAll} />
							</th>
							<th>Voucher ID</th>
							<th>Serial Number</th>
							<th>Value</th>
							<th>Stock</th>
							<th>Status</th>
							<th>Issue Type</th>
							<th>Stock Location</th>
							<th>Stock Person</th>
							<th>Action</th>
						</tr>
					</thead>
					<tbody>
						{#each filteredVouchers as item (item.id)}
							<tr>
								<td style="width: 40px;">
									<input type="checkbox" checked={selectedItems.has(item.id)} on:change={() => toggleItemSelection(item.id)} />
								</td>
								<td>{item.purchase_voucher_id}</td>
								<td>{item.serial_number}</td>
								<td>{item.value}</td>
								<td><span class="stock-badge">{item.stock}</span></td>
								<td><span class="status-badge" class:stocked={item.status === 'stocked'} class:issued={item.status === 'issued'} class:closed={item.status === 'closed'}>{item.status}</span></td>
								<td>{item.issue_type}</td>
							<td>{item.stock_location ? branchMap[item.stock_location] || item.stock_location : '-'}</td>
							<td>{item.stock_person ? userEmployeeMap[item.stock_person] || item.stock_person : '-'}</td>							<td>
								<button class="issue-btn" on:click={() => handleIssue(item.id)}>Issue</button>
							</td>							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	{/if}
</div>

<style>
	.issue-purchase-voucher {
		width: 100%;
		height: 100%;
		padding: 24px;
		background: #f8fafc;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 16px;
	}

	.header h2 {
		margin: 0;
		font-size: 24px;
		font-weight: 700;
		color: #1f2937;
	}

	.search-section {
		background: white;
		padding: 16px 20px;
		border-radius: 12px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		margin-bottom: 20px;
	}

	.search-box label {
		display: block;
		font-size: 14px;
		font-weight: 600;
		color: #374151;
		margin-bottom: 8px;
	}

	.search-input-group {
		display: flex;
		gap: 12px;
	}

	.pv-search-input {
		flex: 1;
		padding: 12px 16px;
		font-size: 16px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		transition: border-color 0.2s;
	}

	.pv-search-input:focus {
		outline: none;
		border-color: #3b82f6;
	}

	.load-button {
		padding: 12px 28px;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.load-button:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.load-button:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.load-button.serial-btn {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
	}

	.load-button.serial-btn:hover:not(:disabled) {
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
	}

	.search-options {
		display: flex;
		gap: 20px;
		align-items: flex-end;
	}

	.search-options .search-box {
		flex: 1;
	}

	.search-divider {
		display: flex;
		align-items: center;
		padding-bottom: 8px;
	}

	.search-divider span {
		padding: 6px 12px;
		background: #e5e7eb;
		border-radius: 20px;
		font-size: 12px;
		font-weight: 600;
		color: #6b7280;
	}

	.current-pv {
		margin-top: 12px;
		padding: 8px 12px;
		background: #f0fdf4;
		border: 1px solid #86efac;
		border-radius: 6px;
		font-size: 14px;
		color: #166534;
	}

	.batch-button {
		padding: 12px 24px;
		background: #f59e0b;
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.95rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.batch-button:hover {
		background: #d97706;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.4);
	}

	.stats-card {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
		gap: 16px;
		margin-bottom: 20px;
		padding: 16px;
		background: white;
		border-radius: 12px;
		border: 1px solid #e5e7eb;
		box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
	}

	.stat-item {
		display: flex;
		flex-direction: column;
		gap: 8px;
		padding: 12px;
		background: #f9fafb;
		border-radius: 8px;
		border-left: 3px solid #3b82f6;
	}

	.stat-label {
		font-size: 12px;
		font-weight: 600;
		color: #6b7280;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.stat-value {
		font-size: 28px;
		font-weight: 700;
		color: #1f2937;
	}

	.stat-value.highlight {
		color: #f59e0b;
	}

	.loading,
	.empty-state {
		padding: 32px 24px;
		text-align: center;
		color: #6b7280;
		font-size: 14px;
		background: white;
		border-radius: 12px;
		border: 1px solid #e5e7eb;
	}

	.table-wrapper {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		overflow: auto;
		max-height: 600px;
		box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
	}

	.vouchers-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
	}

	.vouchers-table thead {
		background: #f9fafb;
		position: sticky;
		top: 0;
	}

	.vouchers-table th {
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.vouchers-table td {
		padding: 12px 16px;
		border-bottom: 1px solid #f3f4f6;
		color: #4b5563;
	}

	.vouchers-table tbody tr:hover {
		background: #f9fafb;
	}

	.status-badge {
		display: inline-block;
		padding: 4px 10px;
		border-radius: 6px;
		font-size: 11px;
		font-weight: 600;
		background: #fee2e2;
		color: #dc2626;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.status-badge.stocked {
		background: #dbeafe;
		color: #1e40af;
	}

	.status-badge.issued {
		background: #fef08a;
		color: #a16207;
	}

	.status-badge.closed {
		background: #dcfce7;
		color: #16a34a;
	}

	.stock-badge {
		display: inline-block;
		padding: 2px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 600;
		background: #f3f4f6;
		color: #374151;
	}

	.issue-btn {
		padding: 6px 12px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
	}

	.issue-btn:hover {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
	}

	.issue-btn:active {
		transform: translateY(0);
	}

	input[type='checkbox'] {
		cursor: pointer;
		width: 16px;
		height: 16px;
	}

	.filters-section {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 16px;
		margin-bottom: 16px;
		box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
	}

	.filter-row {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 12px;
	}

	.filter-group {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.filter-group label {
		font-size: 12px;
		font-weight: 600;
		color: #374151;
	}

	.filter-group input,
	.filter-group select {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 13px;
		background: white;
		color: #1f2937;
	}

	.filter-group input:focus,
	.filter-group select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}

	.filter-group select {
		cursor: pointer;
	}
</style>
