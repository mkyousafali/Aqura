<script>
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';

	let issuedVouchers = [];
	let filteredVouchers = [];
	let isLoading = false;
	let branches = [];
	let users = [];
	let employees = [];
	let selectedVouchers = new Set();
	let showCloseModal = false;
	let selectedVoucherForModal = null;
	
	// Filter states
	let filterPVId = '';
	let filterSerialNumber = '';
	let filterValue = '';
	let filterIssuedTo = '';
	let filterApprovalStatus = '';
	let searchQuery = '';

	// Lookup maps
	$: branchMap = branches.reduce((map, b) => {
		map[b.id] = `${b.name_en} - ${b.location_en}`;
		return map;
	}, {});

	$: employeeMap = employees.reduce((map, e) => {
		map[e.id] = e.name;
		return map;
	}, {});

	$: userEmployeeMap = users.reduce((map, u) => {
		const empName = employeeMap[u.employee_id];
		map[u.id] = empName ? `${u.username} - ${empName}` : u.username;
		return map;
	}, {});

	// Unique filter options
	$: uniquePVIds = [...new Set(issuedVouchers.map(v => v.purchase_voucher_id))].sort();
	$: uniqueValues = [...new Set(issuedVouchers.map(v => v.value))].sort((a, b) => a - b);
	$: uniqueIssuedTo = [...new Set(issuedVouchers.map(v => v.issued_to).filter(Boolean))];
	$: uniqueApprovalStatuses = [...new Set(issuedVouchers.map(v => v.approval_status || 'none'))];

	// Apply filters
	$: {
		filteredVouchers = issuedVouchers.filter(voucher => {
			if (filterPVId && voucher.purchase_voucher_id !== filterPVId) return false;
			if (filterSerialNumber && !voucher.serial_number.toString().includes(filterSerialNumber)) return false;
			if (filterValue && voucher.value !== parseFloat(filterValue)) return false;
			if (filterIssuedTo && voucher.issued_to !== filterIssuedTo) return false;
			if (filterApprovalStatus) {
				const voucherStatus = voucher.approval_status || 'none';
				if (voucherStatus !== filterApprovalStatus) return false;
			}
			if (searchQuery) {
				const query = searchQuery.toLowerCase();
				const matchesPVId = voucher.purchase_voucher_id?.toLowerCase().includes(query);
				const matchesSerial = voucher.serial_number?.toString().includes(query);
				const matchesIssuedTo = userEmployeeMap[voucher.issued_to]?.toLowerCase().includes(query);
				if (!matchesPVId && !matchesSerial && !matchesIssuedTo) return false;
			}
			return true;
		});
	}

	onMount(async () => {
		await Promise.all([
			loadBranches(),
			loadUsers(),
			loadEmployees()
		]);
		await loadIssuedVouchers();
	});

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, location_en')
				.limit(100);
			if (!error) branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	async function loadUsers() {
		try {
			const { data, error } = await supabase
				.from('users')
				.select('id, username, employee_id')
				.limit(500);
			if (!error) users = data || [];
		} catch (error) {
			console.error('Error loading users:', error);
		}
	}

	async function loadEmployees() {
		try {
			const { data, error } = await supabase
				.from('hr_employees')
				.select('id, name')
				.limit(500);
			if (!error) employees = data || [];
		} catch (error) {
			console.error('Error loading employees:', error);
		}
	}

	async function loadIssuedVouchers() {
		isLoading = true;
		try {
			// Load vouchers that are either issued OR pending approval
			// Vouchers pending approval have status='stocked' but approval_status='pending'
			const [issuedResult, pendingResult] = await Promise.all([
				// Vouchers with status 'issued'
				supabase
					.from('purchase_voucher_items')
					.select('id, purchase_voucher_id, serial_number, value, status, issue_type, stock_location, issued_by, issued_to, issued_date, issue_remarks, approval_status')
					.eq('status', 'issued')
					.order('issued_date', { ascending: false }),
				// Vouchers pending approval (status is 'stocked' but has approval_status = 'pending')
				supabase
					.from('purchase_voucher_items')
					.select('id, purchase_voucher_id, serial_number, value, status, issue_type, stock_location, issued_by, issued_to, issued_date, issue_remarks, approval_status')
					.eq('approval_status', 'pending')
					.order('issued_date', { ascending: false })
			]);

			if (issuedResult.error) {
				console.error('Error loading issued vouchers:', issuedResult.error);
			}
			if (pendingResult.error) {
				console.error('Error loading pending vouchers:', pendingResult.error);
			}

			// Combine and deduplicate (in case a voucher is both issued and has pending status)
			const allVouchers = [...(issuedResult.data || []), ...(pendingResult.data || [])];
			const uniqueVouchers = allVouchers.filter((v, index, self) => 
				index === self.findIndex(t => t.id === v.id)
			);
			issuedVouchers = uniqueVouchers;
		} catch (error) {
			console.error('Error:', error);
			issuedVouchers = [];
		} finally {
			isLoading = false;
		}
	}

	function toggleSelectVoucher(id) {
		if (selectedVouchers.has(id)) {
			selectedVouchers.delete(id);
		} else {
			selectedVouchers.add(id);
		}
		selectedVouchers = selectedVouchers;
	}

	function toggleSelectAll() {
		if (selectedVouchers.size === filteredVouchers.length) {
			selectedVouchers.clear();
		} else {
			selectedVouchers = new Set(filteredVouchers.map(v => v.id));
		}
		selectedVouchers = selectedVouchers;
	}

	async function handleCloseSelected() {
		if (selectedVouchers.size === 0) {
			alert('Please select at least one voucher to close');
			return;
		}

		const confirmMsg = `Are you sure you want to close ${selectedVouchers.size} voucher(s)?`;
		if (!confirm(confirmMsg)) return;

		isLoading = true;
		try {
			const voucherIds = Array.from(selectedVouchers);
			const { error } = await supabase
				.from('purchase_voucher_items')
				.update({
					status: 'closed',
					closed_date: new Date().toISOString()
				})
				.in('id', voucherIds);

			if (error) {
				console.error('Error closing vouchers:', error);
				alert('Error closing vouchers: ' + error.message);
			} else {
				alert(`Successfully closed ${selectedVouchers.size} voucher(s)`);
				selectedVouchers.clear();
				await loadIssuedVouchers();
			}
		} catch (error) {
			console.error('Error:', error);
			alert('Error closing vouchers');
		} finally {
			isLoading = false;
		}
	}

	function clearFilters() {
		filterPVId = '';
		filterSerialNumber = '';
		filterValue = '';
		filterIssuedTo = '';
		filterApprovalStatus = '';
		searchQuery = '';
	}

	function openCloseModal(voucher) {
		selectedVoucherForModal = voucher;
		showCloseModal = true;
	}

	function closeModal() {
		showCloseModal = false;
		selectedVoucherForModal = null;
	}
</script>

<div class="close-purchase-voucher">
	<div class="header">
		<h2>Close Purchase Vouchers</h2>
		<p class="subtitle">Select issued vouchers to close</p>
	</div>

	{#if isLoading}
		<div class="loading">Loading issued vouchers...</div>
	{:else if issuedVouchers.length === 0}
		<div class="empty-state">
			<p>No issued vouchers found</p>
			<p class="hint">Only vouchers with status "issued" can be closed</p>
		</div>
	{:else}
		<!-- Stats Section -->
		<div class="stats-section">
			<div class="stat-card">
				<div class="stat-label">Total Issued</div>
				<div class="stat-value">{issuedVouchers.length}</div>
			</div>
			<div class="stat-card approved">
				<div class="stat-label">Approved</div>
				<div class="stat-value">{issuedVouchers.filter(v => v.approval_status === 'approved' || !v.approval_status).length}</div>
			</div>
			<div class="stat-card pending">
				<div class="stat-label">Pending Approval</div>
				<div class="stat-value">{issuedVouchers.filter(v => v.approval_status === 'pending').length}</div>
			</div>
			<div class="stat-card rejected">
				<div class="stat-label">Rejected</div>
				<div class="stat-value">{issuedVouchers.filter(v => v.approval_status === 'rejected').length}</div>
			</div>
			<div class="stat-card">
				<div class="stat-label">Filtered Results</div>
				<div class="stat-value">{filteredVouchers.length}</div>
			</div>
			<div class="stat-card highlight">
				<div class="stat-label">Selected</div>
				<div class="stat-value">{selectedVouchers.size}</div>
			</div>
		</div>

		<!-- Search and Filters -->
		<div class="filters-section">
			<div class="search-bar">
				<input 
					type="text" 
					placeholder="Search by PV ID, Serial Number, or Issued To..." 
					bind:value={searchQuery}
					class="search-input"
				/>
				{#if searchQuery}
					<button class="clear-btn" on:click={() => searchQuery = ''}>✕</button>
				{/if}
			</div>

			<div class="filter-row">
				<div class="filter-group">
					<label>PV ID</label>
					<select bind:value={filterPVId} class="filter-select">
						<option value="">All</option>
						{#each uniquePVIds as pvId}
							<option value={pvId}>{pvId}</option>
						{/each}
					</select>
				</div>

				<div class="filter-group">
					<label>Serial Number</label>
					<input 
						type="text" 
						placeholder="Search serial..." 
						bind:value={filterSerialNumber}
						class="filter-input"
					/>
				</div>

				<div class="filter-group">
					<label>Value</label>
					<select bind:value={filterValue} class="filter-select">
						<option value="">All</option>
						{#each uniqueValues as value}
							<option value={value}>{value}</option>
						{/each}
					</select>
				</div>

				<div class="filter-group">
					<label>Issued To</label>
					<select bind:value={filterIssuedTo} class="filter-select">
						<option value="">All</option>
						{#each uniqueIssuedTo as userId}
							<option value={userId}>{userEmployeeMap[userId] || userId}</option>
						{/each}
					</select>
				</div>

				<div class="filter-group">
					<label>Approval Status</label>
					<select bind:value={filterApprovalStatus} class="filter-select">
						<option value="">All</option>
						<option value="approved">Approved</option>
						<option value="pending">Pending</option>
						<option value="rejected">Rejected</option>
						<option value="none">No Approval</option>
					</select>
				</div>

				<button class="clear-filters-btn" on:click={clearFilters}>Clear Filters</button>
			</div>
		</div>

		<!-- Action Buttons -->
		{#if selectedVouchers.size > 0}
			<div class="action-section">
				<button class="close-btn" on:click={handleCloseSelected}>
					Close {selectedVouchers.size} Selected Voucher{selectedVouchers.size !== 1 ? 's' : ''}
				</button>
			</div>
		{/if}

		<!-- Vouchers Table -->
		<div class="table-container">
			<table class="vouchers-table">
				<thead>
					<tr>
						<th style="width: 50px;">
							<input 
								type="checkbox" 
								checked={selectedVouchers.size === filteredVouchers.length && filteredVouchers.length > 0}
								on:change={toggleSelectAll}
							/>
						</th>
						<th>PV ID</th>
						<th>Serial Number</th>
						<th>Value</th>
						<th>Issue Type</th>
						<th>Stock Location</th>
						<th>Issued By</th>
						<th>Issued To</th>
						<th>Issued Date</th>
						<th>Approval Status</th>
						<th>Issue Remarks</th>
						<th>Action</th>
					</tr>
				</thead>
				<tbody>
					{#each filteredVouchers as voucher (voucher.id)}
						<tr class:selected={selectedVouchers.has(voucher.id)}>
							<td>
								<input 
									type="checkbox" 
									checked={selectedVouchers.has(voucher.id)}
									on:change={() => toggleSelectVoucher(voucher.id)}
								/>
							</td>
							<td>{voucher.purchase_voucher_id}</td>
							<td>{voucher.serial_number}</td>
							<td>{voucher.value}</td>
							<td>{voucher.issue_type || 'N/A'}</td>
							<td>{voucher.stock_location ? (branchMap[voucher.stock_location] || voucher.stock_location) : 'N/A'}</td>
							<td>{voucher.issued_by ? (userEmployeeMap[voucher.issued_by] || voucher.issued_by) : 'N/A'}</td>
							<td>{voucher.issued_to ? (userEmployeeMap[voucher.issued_to] || voucher.issued_to) : 'N/A'}</td>
							<td>{voucher.issued_date ? new Date(voucher.issued_date).toLocaleDateString() : 'N/A'}</td>
							<td>
								{#if voucher.approval_status === 'approved'}
									<span class="status-badge status-approved">Approved</span>
								{:else if voucher.approval_status === 'pending'}
									<span class="status-badge status-pending">Pending</span>
								{:else if voucher.approval_status === 'rejected'}
									<span class="status-badge status-rejected">Rejected</span>
								{:else}
									<span class="status-badge status-none">No Approval</span>
								{/if}
							</td>
							<td class="remarks-cell">{voucher.issue_remarks || '-'}</td>
							<td>
								{#if voucher.approval_status === 'approved' || !voucher.approval_status}
									<button class="action-close-btn" on:click={() => openCloseModal(voucher)}>
										Close
									</button>
								{:else}
									<button class="action-close-btn disabled" disabled>
										Pending Approval
									</button>
								{/if}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}

	<!-- Close Modal -->
	{#if showCloseModal}
		<div class="modal-overlay" on:click={closeModal}>
			<div class="modal-content" on:click|stopPropagation>
				<div class="modal-header">
					<h3>Close Voucher</h3>
					<button class="modal-close-btn" on:click={closeModal}>✕</button>
				</div>
				<div class="modal-body">
					<!-- Modal content will be added later -->
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.close-purchase-voucher {
		width: 100%;
		height: 100%;
		padding: 20px;
		overflow-y: auto;
		background: #f7fafc;
	}

	.header {
		margin-bottom: 20px;
	}

	.header h2 {
		margin: 0 0 8px 0;
		font-size: 24px;
		font-weight: 600;
		color: #1a202c;
	}

	.subtitle {
		margin: 0;
		color: #718096;
		font-size: 14px;
	}

	.loading {
		padding: 40px;
		text-align: center;
		color: #718096;
		font-size: 16px;
	}

	.empty-state {
		padding: 40px;
		text-align: center;
		background: white;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
	}

	.empty-state p {
		margin: 8px 0;
		color: #718096;
	}

	.empty-state .hint {
		font-size: 14px;
		color: #a0aec0;
	}

	.stats-section {
		display: flex;
		gap: 16px;
		margin-bottom: 20px;
	}

	.stat-card {
		flex: 1;
		padding: 16px;
		background: white;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
		text-align: center;
	}

	.stat-card.highlight {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border: none;
	}

	.stat-card.approved {
		background: linear-gradient(135deg, #48bb78 0%, #38a169 100%);
		color: white;
		border: none;
	}

	.stat-card.pending {
		background: linear-gradient(135deg, #ecc94b 0%, #d69e2e 100%);
		color: white;
		border: none;
	}

	.stat-card.rejected {
		background: linear-gradient(135deg, #fc8181 0%, #e53e3e 100%);
		color: white;
		border: none;
	}

	.stat-label {
		font-size: 13px;
		font-weight: 500;
		margin-bottom: 8px;
		opacity: 0.8;
	}

	.stat-value {
		font-size: 28px;
		font-weight: 700;
	}

	.filters-section {
		background: white;
		padding: 16px;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
		margin-bottom: 16px;
	}

	.search-bar {
		position: relative;
		margin-bottom: 16px;
	}

	.search-input {
		width: 100%;
		padding: 10px 40px 10px 12px;
		border: 1px solid #cbd5e0;
		border-radius: 6px;
		font-size: 14px;
	}

	.clear-btn {
		position: absolute;
		right: 12px;
		top: 50%;
		transform: translateY(-50%);
		background: none;
		border: none;
		color: #a0aec0;
		cursor: pointer;
		font-size: 16px;
		padding: 4px;
	}

	.clear-btn:hover {
		color: #718096;
	}

	.filter-row {
		display: flex;
		gap: 12px;
		align-items: flex-end;
	}

	.filter-group {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.filter-group label {
		font-size: 13px;
		font-weight: 500;
		color: #4a5568;
	}

	.filter-select,
	.filter-input {
		padding: 8px;
		border: 1px solid #cbd5e0;
		border-radius: 6px;
		font-size: 14px;
	}

	.clear-filters-btn {
		padding: 8px 16px;
		background: #edf2f7;
		border: 1px solid #cbd5e0;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 500;
		color: #4a5568;
		white-space: nowrap;
	}

	.clear-filters-btn:hover {
		background: #e2e8f0;
	}

	.action-section {
		margin-bottom: 16px;
		display: flex;
		justify-content: flex-end;
	}

	.close-btn {
		padding: 12px 24px;
		background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.close-btn:hover {
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
		transform: translateY(-1px);
	}

	.table-container {
		background: white;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
		overflow: auto;
		max-height: 500px;
	}

	.vouchers-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
	}

	.vouchers-table thead {
		background: #f7fafc;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.vouchers-table th {
		padding: 12px 8px;
		text-align: left;
		font-weight: 600;
		color: #4a5568;
		border-bottom: 2px solid #e2e8f0;
	}

	.vouchers-table tbody tr {
		border-bottom: 1px solid #e2e8f0;
		transition: background-color 0.2s;
	}

	.vouchers-table tbody tr:hover {
		background: #f7fafc;
	}

	.vouchers-table tbody tr.selected {
		background: #ebf8ff;
	}

	.vouchers-table td {
		padding: 12px 8px;
		color: #2d3748;
	}

	.remarks-cell {
		max-width: 200px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	input[type="checkbox"] {
		cursor: pointer;
		width: 16px;
		height: 16px;
	}

	.action-close-btn {
		padding: 6px 14px;
		background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
		color: white;
		border: none;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.action-close-btn:hover {
		box-shadow: 0 2px 6px rgba(245, 87, 108, 0.3);
		transform: translateY(-1px);
	}

	.action-close-btn.disabled,
	.action-close-btn:disabled {
		background: #cbd5e0;
		cursor: not-allowed;
		transform: none;
	}

	.action-close-btn.disabled:hover,
	.action-close-btn:disabled:hover {
		box-shadow: none;
		transform: none;
	}

	.status-badge {
		padding: 4px 10px;
		border-radius: 12px;
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
		display: inline-block;
	}

	.status-approved {
		background: #d1fae5;
		color: #065f46;
	}

	.status-pending {
		background: #fef3c7;
		color: #92400e;
	}

	.status-rejected {
		background: #fee2e2;
		color: #991b1b;
	}

	.status-none {
		background: #e5e7eb;
		color: #4b5563;
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
		width: 90%;
		max-width: 600px;
		max-height: 80vh;
		overflow-y: auto;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #e2e8f0;
	}

	.modal-header h3 {
		margin: 0;
		font-size: 20px;
		font-weight: 600;
		color: #1a202c;
	}

	.modal-close-btn {
		background: none;
		border: none;
		font-size: 24px;
		color: #a0aec0;
		cursor: pointer;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 4px;
		transition: all 0.2s;
	}

	.modal-close-btn:hover {
		background: #f7fafc;
		color: #4a5568;
	}

	.modal-body {
		padding: 24px;
		min-height: 200px;
	}
</style>
