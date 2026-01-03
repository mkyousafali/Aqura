<script>
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
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
	let closeBillNumber = '';
	let closeRemarks = '';
	let isClosing = false;
	let expenseCategories = [];
	let selectedExpenseCategoryId = null;
	let expenseCategorySearch = '';
	let showCategoryDropdown = false;
	
	// Filtered expense categories based on search
	$: filteredExpenseCategories = expenseCategories.filter(cat => {
		if (!expenseCategorySearch.trim()) return true;
		const search = expenseCategorySearch.toLowerCase();
		return cat.name_en.toLowerCase().includes(search) || 
		       cat.name_ar.toLowerCase().includes(search);
	});
	
	// Get selected category display name
	$: selectedCategoryDisplay = selectedExpenseCategoryId 
		? expenseCategories.find(c => c.id === selectedExpenseCategoryId)
		: null;
	
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
			loadEmployees(),
			loadExpenseCategories()
		]);
		await loadIssuedVouchers();
	});

	async function loadExpenseCategories() {
		try {
			const { data, error } = await supabase
				.from('expense_sub_categories')
				.select('id, name_en, name_ar, parent_category_id')
				.eq('is_active', true)
				.order('name_en');
			if (!error) expenseCategories = data || [];
		} catch (error) {
			console.error('Error loading expense categories:', error);
		}
	}

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
		closeBillNumber = '';
		closeRemarks = '';
		selectedExpenseCategoryId = null;
		expenseCategorySearch = '';
		showCategoryDropdown = false;
		showCloseModal = true;
	}

	function closeModal() {
		showCloseModal = false;
		selectedVoucherForModal = null;
		closeBillNumber = '';
		closeRemarks = '';
		selectedExpenseCategoryId = null;
		expenseCategorySearch = '';
		showCategoryDropdown = false;
	}

	function selectExpenseCategory(category) {
		selectedExpenseCategoryId = category.id;
		expenseCategorySearch = '';
		showCategoryDropdown = false;
	}

	function clearSelectedCategory() {
		selectedExpenseCategoryId = null;
		expenseCategorySearch = '';
	}

	async function handleSaveClose() {
		if (!selectedVoucherForModal) return;
		
		const issueType = selectedVoucherForModal.issue_type;
		
		// Validation for sales issue type
		if (issueType === 'sales' && !closeBillNumber.trim()) {
			alert('Please enter the close bill number');
			return;
		}
		
		// Validation for gift issue type
		if (issueType === 'gift') {
			if (!selectedExpenseCategoryId) {
				alert('Please select an expense category');
				return;
			}
			if (!closeBillNumber.trim()) {
				alert('Please enter the close bill number');
				return;
			}
		}
		
		isClosing = true;
		try {
			const updateData = {
				status: 'closed',
				closed_date: new Date().toISOString(),
				close_bill_number: closeBillNumber.trim() || null,
				close_remarks: closeRemarks.trim() || null
			};
			
			// Update the voucher item
			const { error } = await supabase
				.from('purchase_voucher_items')
				.update(updateData)
				.eq('id', selectedVoucherForModal.id);
			
			if (error) {
				console.error('Error closing voucher:', error);
				alert('Error closing voucher: ' + error.message);
				return;
			}
			
			// For gift issue type, also post to expense_scheduler
			if (issueType === 'gift') {
				// Get current user from store
				if (!$currentUser?.id) {
					alert('Error: Unable to get current user. Please log in again.');
					return;
				}
				
				const selectedCategory = expenseCategories.find(c => c.id === selectedExpenseCategoryId);
				const branch = branches.find(b => b.id === selectedVoucherForModal.stock_location);
				
				const expenseData = {
					branch_id: selectedVoucherForModal.stock_location,
					branch_name: branch ? `${branch.name_en} - ${branch.location_en}` : 'Unknown Branch',
					expense_category_id: selectedExpenseCategoryId,
					expense_category_name_en: selectedCategory?.name_en || null,
					expense_category_name_ar: selectedCategory?.name_ar || null,
					co_user_id: $currentUser.id,
					co_user_name: $currentUser.username || 'Unknown User',
					bill_type: 'purchase_voucher_gift',
					bill_number: closeBillNumber.trim(),
					bill_date: new Date().toISOString().split('T')[0],
					payment_method: 'redemption',
					amount: selectedVoucherForModal.value,
					description: `Gift Purchase Voucher - ${selectedVoucherForModal.purchase_voucher_id} - Serial: ${selectedVoucherForModal.serial_number}`,
					notes: closeRemarks.trim() || null,
					is_paid: true,
					paid_date: new Date().toISOString(),
					status: 'completed',
					created_by: $currentUser.id,
					schedule_type: 'single_bill',
					due_date: new Date().toISOString().split('T')[0]
				};
				
				const { error: expenseError } = await supabase
					.from('expense_scheduler')
					.insert(expenseData);
				
				if (expenseError) {
					console.error('Error creating expense record:', expenseError);
					alert('Voucher closed but failed to create expense record: ' + expenseError.message);
					closeModal();
					await loadIssuedVouchers();
					return;
				}
			}
			
			alert('Voucher closed successfully');
			closeModal();
			await loadIssuedVouchers();
		} catch (error) {
			console.error('Error:', error);
			alert('Error closing voucher');
		} finally {
			isClosing = false;
		}
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
	{#if showCloseModal && selectedVoucherForModal}
		<div class="modal-overlay" on:click={closeModal}>
			<div class="modal-content" on:click|stopPropagation>
				<div class="modal-header">
					<h3>Close Voucher</h3>
					<button class="modal-close-btn" on:click={closeModal}>✕</button>
				</div>
				<div class="modal-body">
					<!-- Voucher Info -->
					<div class="voucher-info">
						<div class="info-row">
							<span class="info-label">PV ID:</span>
							<span class="info-value">{selectedVoucherForModal.purchase_voucher_id}</span>
						</div>
						<div class="info-row">
							<span class="info-label">Serial Number:</span>
							<span class="info-value">{selectedVoucherForModal.serial_number}</span>
						</div>
						<div class="info-row">
							<span class="info-label">Value:</span>
							<span class="info-value">{selectedVoucherForModal.value}</span>
						</div>
						<div class="info-row">
							<span class="info-label">Issue Type:</span>
							<span class="info-value issue-type-badge">{selectedVoucherForModal.issue_type || 'N/A'}</span>
						</div>
					</div>
					
					{#if selectedVoucherForModal.issue_type === 'sales'}
						<!-- Sales Close Form -->
						<div class="close-form">
							<div class="form-group">
								<label for="closeBillNumber">Close Bill Number <span class="required">*</span></label>
								<input 
									type="text" 
									id="closeBillNumber"
									bind:value={closeBillNumber}
									placeholder="Enter bill number"
									class="form-input"
								/>
							</div>
							<div class="form-group">
								<label for="closeRemarks">Close Remarks</label>
								<textarea 
									id="closeRemarks"
									bind:value={closeRemarks}
									placeholder="Enter remarks (optional)"
									class="form-textarea"
									rows="3"
								></textarea>
							</div>
						</div>
					{:else if selectedVoucherForModal.issue_type === 'gift'}
						<!-- Gift Close Form -->
						<div class="close-form">
							<div class="form-group">
								<label for="expenseCategory">Expense Category <span class="required">*</span></label>
								<div class="searchable-dropdown">
									{#if selectedCategoryDisplay}
										<div class="selected-category">
											<span>{selectedCategoryDisplay.name_en} ({selectedCategoryDisplay.name_ar})</span>
											<button type="button" class="clear-category-btn" on:click={clearSelectedCategory}>✕</button>
										</div>
									{:else}
										<input 
											type="text"
											placeholder="Search expense category..."
											bind:value={expenseCategorySearch}
											on:focus={() => showCategoryDropdown = true}
											class="form-input category-search-input"
										/>
									{/if}
									{#if showCategoryDropdown && !selectedCategoryDisplay}
										<div class="category-dropdown">
											{#if filteredExpenseCategories.length === 0}
												<div class="no-results">No categories found</div>
											{:else}
												{#each filteredExpenseCategories as category}
													<button 
														type="button"
														class="category-option"
														on:click={() => selectExpenseCategory(category)}
													>
														{category.name_en} ({category.name_ar})
													</button>
												{/each}
											{/if}
										</div>
									{/if}
								</div>
							</div>
							<div class="form-group">
								<label for="closeBillNumberGift">Close Bill Number <span class="required">*</span></label>
								<input 
									type="text" 
									id="closeBillNumberGift"
									bind:value={closeBillNumber}
									placeholder="Enter bill number"
									class="form-input"
								/>
							</div>
							<div class="form-group">
								<label for="closeRemarksGift">Close Remarks</label>
								<textarea 
									id="closeRemarksGift"
									bind:value={closeRemarks}
									placeholder="Enter remarks (optional)"
									class="form-textarea"
									rows="3"
								></textarea>
							</div>
						</div>
					{:else}
						<!-- Other issue types - will be handled later -->
						<div class="other-issue-type-notice">
							<p>This voucher has issue type: <strong>{selectedVoucherForModal.issue_type || 'N/A'}</strong></p>
							<p class="hint">Close functionality for this issue type will be added later.</p>
						</div>
					{/if}
					
					<!-- Action Buttons -->
					<div class="modal-actions">
						<button class="btn-cancel" on:click={closeModal}>Cancel</button>
						{#if selectedVoucherForModal.issue_type === 'sales' || selectedVoucherForModal.issue_type === 'gift'}
							<button 
								class="btn-save" 
								on:click={handleSaveClose}
								disabled={isClosing}
							>
								{isClosing ? 'Saving...' : 'Save & Close'}
							</button>
						{/if}
					</div>
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

	.voucher-info {
		background: #f7fafc;
		border-radius: 8px;
		padding: 16px;
		margin-bottom: 20px;
	}

	.info-row {
		display: flex;
		justify-content: space-between;
		padding: 8px 0;
		border-bottom: 1px solid #e2e8f0;
	}

	.info-row:last-child {
		border-bottom: none;
	}

	.info-label {
		font-weight: 500;
		color: #4a5568;
	}

	.info-value {
		color: #1a202c;
		font-weight: 600;
	}

	.issue-type-badge {
		padding: 4px 10px;
		background: #667eea;
		color: white;
		border-radius: 12px;
		font-size: 12px;
		text-transform: uppercase;
	}

	.close-form {
		margin-bottom: 20px;
	}

	.form-group {
		margin-bottom: 16px;
	}

	.form-group label {
		display: block;
		margin-bottom: 6px;
		font-weight: 500;
		color: #4a5568;
		font-size: 14px;
	}

	.required {
		color: #e53e3e;
	}

	.form-input,
	.form-textarea,
	.form-select {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #cbd5e0;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s;
	}

	.form-input:focus,
	.form-textarea:focus,
	.form-select:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.form-select {
		background-color: white;
		cursor: pointer;
	}

	.form-textarea {
		resize: vertical;
		min-height: 80px;
	}

	.other-issue-type-notice {
		background: #fef3c7;
		border: 1px solid #f59e0b;
		border-radius: 8px;
		padding: 16px;
		margin-bottom: 20px;
		text-align: center;
	}

	.other-issue-type-notice p {
		margin: 4px 0;
		color: #92400e;
	}

	.other-issue-type-notice .hint {
		font-size: 13px;
		color: #b45309;
	}

	.modal-actions {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding-top: 16px;
		border-top: 1px solid #e2e8f0;
	}

	.btn-cancel {
		padding: 10px 20px;
		background: #edf2f7;
		border: 1px solid #cbd5e0;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		color: #4a5568;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-cancel:hover {
		background: #e2e8f0;
	}

	.btn-save {
		padding: 10px 20px;
		background: linear-gradient(135deg, #48bb78 0%, #38a169 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-save:hover:not(:disabled) {
		box-shadow: 0 4px 8px rgba(56, 161, 105, 0.3);
		transform: translateY(-1px);
	}

	.btn-save:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	/* Searchable Dropdown Styles */
	.searchable-dropdown {
		position: relative;
	}

	.category-search-input {
		width: 100%;
	}

	.selected-category {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 10px 12px;
		border: 1px solid #cbd5e0;
		border-radius: 6px;
		background: #f0fff4;
		font-size: 14px;
	}

	.selected-category span {
		color: #276749;
		font-weight: 500;
	}

	.clear-category-btn {
		background: none;
		border: none;
		color: #a0aec0;
		cursor: pointer;
		font-size: 16px;
		padding: 0 4px;
		transition: color 0.2s;
	}

	.clear-category-btn:hover {
		color: #e53e3e;
	}

	.category-dropdown {
		position: absolute;
		top: 100%;
		left: 0;
		right: 0;
		max-height: 200px;
		overflow-y: auto;
		background: white;
		border: 1px solid #cbd5e0;
		border-top: none;
		border-radius: 0 0 6px 6px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
		z-index: 100;
	}

	.category-option {
		width: 100%;
		padding: 10px 12px;
		text-align: left;
		background: none;
		border: none;
		border-bottom: 1px solid #e2e8f0;
		cursor: pointer;
		font-size: 14px;
		color: #2d3748;
		transition: background 0.2s;
	}

	.category-option:last-child {
		border-bottom: none;
	}

	.category-option:hover {
		background: #ebf8ff;
	}

	.no-results {
		padding: 12px;
		text-align: center;
		color: #a0aec0;
		font-size: 14px;
	}
</style>
