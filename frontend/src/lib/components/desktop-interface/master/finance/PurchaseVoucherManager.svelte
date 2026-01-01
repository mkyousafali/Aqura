<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import AddPurchaseVoucher from '$lib/components/desktop-interface/master/finance/AddPurchaseVoucher.svelte';
	import IssuePurchaseVoucher from '$lib/components/desktop-interface/master/finance/IssuePurchaseVoucher.svelte';
	import ClosePurchaseVoucher from '$lib/components/desktop-interface/master/finance/ClosePurchaseVoucher.svelte';
	import PurchaseVoucherStockManager from '$lib/components/desktop-interface/master/finance/PurchaseVoucherStockManager.svelte';

	let purchaseVoucherItems = [];
	let isLoading = false;
	let subscription;
	let branchMap = {};
	let userEmployeeMap = {};
	let customerMap = {};

	// Filter variables
	let filterPVId = '';
	let filterSerialNumber = '';
	let filterValue = '';
	let filterStatus = '';
	let filterIssueType = '';
	let filterStockLocation = '';
	let filterStockPerson = '';
	let filterIssuedTo = '';
	let filterIssuedBy = '';

	// Computed filtered list
	$: filteredItems = purchaseVoucherItems.filter((item) => {
		if (filterPVId && item.purchase_voucher_id !== filterPVId) return false;
		if (filterSerialNumber && !item.serial_number.toString().includes(filterSerialNumber)) return false;
		if (filterValue && item.value.toString() !== filterValue) return false;
		if (filterStatus && item.status !== filterStatus) return false;
		if (filterIssueType && item.issue_type !== filterIssueType) return false;
		if (filterStockLocation && item.stock_location !== (filterStockLocation ? parseInt(filterStockLocation) : null)) return false;
		if (filterStockPerson && item.stock_person !== filterStockPerson) return false;
		if (filterIssuedTo && item.issued_to !== filterIssuedTo) return false;
		if (filterIssuedBy && item.issued_by !== filterIssuedBy) return false;
		return true;
	});

	// Get unique filter values
	$: uniqueValues = {
		pvIds: [...new Set(purchaseVoucherItems.map((i) => i.purchase_voucher_id))],
		values: [...new Set(purchaseVoucherItems.map((i) => i.value))].sort((a, b) => a - b),
		statuses: [...new Set(purchaseVoucherItems.map((i) => i.status))],
		issueTypes: [...new Set(purchaseVoucherItems.map((i) => i.issue_type))],
		stockLocations: [...new Set(purchaseVoucherItems.map((i) => i.stock_location).filter(Boolean))],
		stockPersons: [...new Set(purchaseVoucherItems.map((i) => i.stock_person).filter(Boolean))],
		issuedTos: [...new Set(purchaseVoucherItems.map((i) => i.issued_to).filter(Boolean))],
		issuedBys: [...new Set(purchaseVoucherItems.map((i) => i.issued_by).filter(Boolean))]
	};

	onMount(async () => {
		await Promise.all([loadBranches(), loadUsers()]);
		await loadPurchaseVoucherItems();
		setupRealtimeSubscriptions();

		return () => {
			if (subscription) {
				subscription.unsubscribe();
			}
		};
	});

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, location_en');

			if (!error && data) {
				branchMap = {};
				data.forEach((branch) => {
					branchMap[branch.id] = `${branch.name_en} - ${branch.location_en}`;
				});
			}
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	async function loadUsers() {
		try {
			const [usersResult, employeesResult] = await Promise.all([
				supabase.from('users').select('id, username, employee_id').limit(1000),
				supabase.from('hr_employees').select('id, name').limit(1000)
			]);

			if (usersResult.error || employeesResult.error) {
				console.error('Error loading users/employees:', usersResult.error || employeesResult.error);
				return;
			}

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
		} catch (error) {
			console.error('Error loading users:', error);
		}
	}

	function setupRealtimeSubscriptions() {
		subscription = supabase
			.channel('purchase_voucher_items_changes')
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'purchase_voucher_items'
				},
				() => {
					loadPurchaseVoucherItems();
				}
			)
			.subscribe();
	}

	async function loadPurchaseVoucherItems() {
		isLoading = true;
		try {
			const { data, error } = await supabase
				.from('purchase_voucher_items')
				.select('*')
				.order('created_at', { ascending: false });

			if (error) {
				console.error('Error loading purchase voucher items:', error);
				purchaseVoucherItems = [];
			} else {
				purchaseVoucherItems = data || [];
			}
		} catch (error) {
			console.error('Error:', error);
		} finally {
			isLoading = false;
		}
	}

	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function handleAddPurchaseVoucher() {
		const windowId = generateWindowId('add-purchase-voucher');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `Add Purchase Voucher #${instanceNumber}`,
			component: AddPurchaseVoucher,
			icon: '➕',
			size: { width: 1000, height: 700 },
			position: { x: 100, y: 100 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			onClose: loadPurchaseVoucherItems
		});
	}

	function handleIssuePurchaseVoucher() {
		const windowId = generateWindowId('issue-purchase-voucher');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `Issue Purchase Voucher #${instanceNumber}`,
			component: IssuePurchaseVoucher,
			icon: '📤',
			size: { width: 1000, height: 700 },
			position: { x: 150, y: 150 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function handleClosePurchaseVoucher() {
		const windowId = generateWindowId('close-purchase-voucher');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `Close Purchase Voucher #${instanceNumber}`,
			component: ClosePurchaseVoucher,
			icon: '✅',
			size: { width: 1000, height: 700 },
			position: { x: 200, y: 200 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function handlePurchaseVoucherStockManager() {
		const windowId = generateWindowId('purchase-voucher-stock-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `Purchase Voucher Stock Manager #${instanceNumber}`,
			component: PurchaseVoucherStockManager,
			icon: '📦',
			size: { width: 1000, height: 700 },
			position: { x: 250, y: 250 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}
</script>

<div class="purchase-voucher-manager">
	<div class="status-grid">
		<div class="status-card">1</div>
		<div class="status-card">2</div>
		<div class="status-card">3</div>
		<div class="status-card">4</div>
	</div>
	<div class="button-group">
		<button class="action-button" on:click={handleAddPurchaseVoucher}>Add Purchase Voucher</button>
		<button class="action-button" on:click={handleIssuePurchaseVoucher}>Issue Purchase Voucher</button>
		<button class="action-button" on:click={handleClosePurchaseVoucher}>Close Purchase Voucher</button>
		<button class="action-button" on:click={handlePurchaseVoucherStockManager}>Purchase Voucher Stock Manager</button>
	</div>

	<div class="table-section">
		<h3 class="table-title">Purchase Voucher Items</h3>
		{#if isLoading}
			<div class="loading">Loading purchase voucher items...</div>
		{:else if purchaseVoucherItems.length === 0}
			<div class="empty-state">No purchase voucher items found</div>
		{:else}
			<div class="filters-section">
				<div class="filter-row">
					<div class="filter-group">
						<label>PV ID</label>
						<select bind:value={filterPVId}>
							<option value="">All PV IDs</option>
							{#each uniqueValues.pvIds as pvId}
								<option value={pvId}>{pvId}</option>
							{/each}
						</select>
					</div>
					<div class="filter-group">
						<label>Serial Number</label>
						<input type="text" placeholder="Search serial" bind:value={filterSerialNumber} />
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
					<div class="filter-group">
						<label>Status</label>
						<select bind:value={filterStatus}>
							<option value="">All Statuses</option>
							{#each uniqueValues.statuses as status}
								<option value={status}>{status}</option>
							{/each}
						</select>
					</div>
					<div class="filter-group">
						<label>Issue Type</label>
						<select bind:value={filterIssueType}>
							<option value="">All Issue Types</option>
							{#each uniqueValues.issueTypes as type}
								<option value={type}>{type}</option>
							{/each}
						</select>
					</div>
				</div>
				<div class="filter-row">
					<div class="filter-group">
						<label>Stock Location</label>
						<select bind:value={filterStockLocation}>
							<option value="">All Locations</option>
							{#each uniqueValues.stockLocations as locId}
								<option value={locId}>{branchMap[locId] || locId}</option>
							{/each}
						</select>
					</div>
					<div class="filter-group">
						<label>Stock Person</label>
						<select bind:value={filterStockPerson}>
							<option value="">All Persons</option>
							{#each uniqueValues.stockPersons as personId}
								<option value={personId}>{userEmployeeMap[personId] || personId}</option>
							{/each}
						</select>
					</div>
					<div class="filter-group">
						<label>Issued To</label>
						<select bind:value={filterIssuedTo}>
							<option value="">All Customers</option>
							{#each uniqueValues.issuedTos as custId}
								<option value={custId}>{customerMap[custId] || custId}</option>
							{/each}
						</select>
					</div>
					<div class="filter-group">
						<label>Issued By</label>
						<select bind:value={filterIssuedBy}>
							<option value="">All Users</option>
							{#each uniqueValues.issuedBys as userId}
								<option value={userId}>{userEmployeeMap[userId] || userId}</option>
							{/each}
						</select>
					</div>
				</div>
			</div>
			<div class="table-wrapper">
				<table class="vouchers-table">
					<thead>
						<tr>
							<th>Voucher ID</th>
							<th>Serial Number</th>
							<th>Value</th>
							<th>Stock</th>
							<th>Status</th>
							<th>Issue Type</th>
							<th>Stock Location</th>
							<th>Stock Person</th>
							<th>Issued To</th>
							<th>Issued By</th>
							<th>Created</th>
						</tr>
					</thead>
					<tbody>
						{#each filteredItems as item (item.id)}
							<tr>
								<td>{item.purchase_voucher_id}</td>
								<td>{item.serial_number}</td>
								<td>{item.value}</td>
								<td><span class="stock-badge">{item.stock}</span></td>
								<td><span class="status-badge" class:stocked={item.status === 'stocked'} class:issued={item.status === 'issued'} class:closed={item.status === 'closed'}>{item.status}</span></td>
								<td>{item.issue_type}</td>
								<td>{item.stock_location ? branchMap[item.stock_location] || item.stock_location : '-'}</td>
								<td>{item.stock_person ? userEmployeeMap[item.stock_person] || item.stock_person : '-'}</td>
								<td>{item.issued_to || '-'}</td>
								<td>{item.issued_by || '-'}</td>
								<td>{new Date(item.created_at).toLocaleDateString()}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	</div>
</div>

<style>
	.purchase-voucher-manager {
		width: 100%;
		height: 100%;
		padding: 24px;
		background: #f8fafc;
	}

	.status-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 24px;
	}

	.status-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 16px;
		padding: 32px 24px;
		min-height: 200px;
		box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
		transition: all 0.3s ease;
	}

	.status-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
		border-color: #d1d5db;
	}

	.button-group {
		display: flex;
		gap: 16px;
		margin-top: 24px;
	}

	.action-button {
		padding: 12px 24px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.95rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.action-button:hover {
		background: #2563eb;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.action-button:active {
		transform: translateY(0);
	}

	.table-section {
		margin-top: 32px;
		border-top: 1px solid #e5e7eb;
		padding-top: 24px;
	}

	.table-title {
		margin: 0 0 16px 0;
		font-size: 18px;
		font-weight: 600;
		color: #1f2937;
	}

	.loading,
	.empty-state {
		padding: 32px 24px;
		text-align: center;
		color: #6b7280;
		font-size: 14px;
	}

	.table-wrapper {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		overflow: auto;
		max-height: 400px;
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

	.item-id {
		font-family: 'Monaco', 'Courier New', monospace;
		font-size: 11px;
		color: #6b7280;
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
		margin-bottom: 12px;
	}

	.filter-row:last-child {
		margin-bottom: 0;
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
