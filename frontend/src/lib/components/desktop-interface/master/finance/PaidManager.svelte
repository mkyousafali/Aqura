<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { openWindow } from '$lib/utils/windowManagerUtils';

	export let onRefresh = null;
	export let setRefreshCallback = null;

	let selectedMonth = new Date().getMonth();
	let selectedYear = new Date().getFullYear();
	let selectedDay = new Date().getDate();

	const months = [
		'January', 'February', 'March', 'April', 'May', 'June',
		'July', 'August', 'September', 'October', 'November', 'December'
	];

	$: daysInMonth = new Date(selectedYear, selectedMonth + 1, 0).getDate();

	// Data
	let paidVendorPayments = [];
	let paidExpensePayments = [];
	let branches = [];
	let branchMap = {};
	let paymentMethods = [];
	let isLoading = false;
	let loadingProgress = 0;

	// Filters
	let filterBranch = '';
	let filterPaymentMethod = '';

	// Editing state
	let editingVendorPaymentId = null;
	let editingExpensePaymentId = null;
	let editingVendorReference = '';
	let editingExpenseReference = '';

	// Pending ERP Reference modal
	let showPendingModal = false;
	let pendingVendorPayments = [];
	let pendingExpensePayments = [];

	// Inline edit popup state
	let showEditPopup = false;
	let editPopupPaymentId = null;
	let editPopupPaymentType = null; // 'vendor' or 'expense'
	let editPopupReference = '';
	let editPopupLabel = '';

	// Real-time subscriptions
	let vendorSubscription = null;
	let expenseSubscription = null;

	// Helper to format currency
	function formatCurrency(amount) {
		if (amount === null || amount === undefined || isNaN(amount)) return 'SAR 0.00';
		return `SAR ${Number(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
	}

	// Helper to format date as dd/mm/yyyy
	function formatDate(dateInput) {
		if (!dateInput) return 'N/A';
		try {
			const date = dateInput instanceof Date ? dateInput : new Date(dateInput);
			if (isNaN(date.getTime())) return 'N/A';
			const day = String(date.getDate()).padStart(2, '0');
			const month = String(date.getMonth() + 1).padStart(2, '0');
			const year = date.getFullYear();
			return `${day}/${month}/${year}`;
		} catch (error) {
			return 'N/A';
		}
	}

	// Get branch name
	function getBranchName(branchId) {
		if (!branchId) return 'N/A';
		return branchMap[branchId] || 'N/A';
	}

	// Load branches
	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en')
				.eq('is_active', true)
				.order('name_en', { ascending: true })
				.limit(5000);

			if (error) {
				console.error('Error loading branches:', error);
				return;
			}

			branches = data || [];
			branchMap = {};
			branches.forEach(branch => {
				const display = branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en;
				branchMap[branch.id] = display;
			});
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	// Load paid vendor payments for selected date
	async function loadPaidVendorPayments() {
		try {
			const selectedDate = `${selectedYear}-${String(selectedMonth + 1).padStart(2, '0')}-${String(selectedDay).padStart(2, '0')}`;
			// Calculate next day correctly (handles month/year boundaries)
			const nextDayObj = new Date(selectedYear, selectedMonth, selectedDay + 1);
			const nextDate = `${nextDayObj.getFullYear()}-${String(nextDayObj.getMonth() + 1).padStart(2, '0')}-${String(nextDayObj.getDate()).padStart(2, '0')}`;
			console.log('🔍 Loading vendor payments for due date range:', selectedDate, 'to', nextDate);

			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.select('id, bill_number, vendor_name, final_bill_amount, bill_date, branch_id, payment_method, bank_name, iban, is_paid, paid_date, due_date, payment_reference')
				.eq('is_paid', true)
				.gte('due_date', selectedDate)
				.lt('due_date', nextDate)
				.order('due_date', { ascending: false })
				.limit(5000);

			if (error) {
				console.error('Error loading paid vendor payments:', error);
				return;
			}

			console.log('✅ Vendor payments loaded:', data?.length || 0, 'records');
			paidVendorPayments = data || [];
		} catch (error) {
			console.error('Error loading paid vendor payments:', error);
		}
	}

	// Load paid expense scheduler payments for selected date
	async function loadPaidExpensePayments() {
		try {
			const selectedDate = `${selectedYear}-${String(selectedMonth + 1).padStart(2, '0')}-${String(selectedDay).padStart(2, '0')}`;
			// Calculate next day correctly (handles month/year boundaries)
			const nextDayObj = new Date(selectedYear, selectedMonth, selectedDay + 1);
			const nextDate = `${nextDayObj.getFullYear()}-${String(nextDayObj.getMonth() + 1).padStart(2, '0')}-${String(nextDayObj.getDate()).padStart(2, '0')}`;
			console.log('🔍 Loading expense payments for due date range:', selectedDate, 'to', nextDate);

			const { data, error } = await supabase
				.from('expense_scheduler')
				.select('id, amount, is_paid, paid_date, status, branch_id, payment_method, expense_category_name_en, expense_category_name_ar, description, schedule_type, due_date, co_user_name, created_by, requisition_id, requisition_number, creator:users!created_by(username), payment_reference')
				.eq('is_paid', true)
				.gte('due_date', selectedDate)
				.lt('due_date', nextDate)
				.order('due_date', { ascending: false })
				.limit(5000);

			if (error) {
				console.error('Error loading paid expense payments:', error);
				return;
			}

			console.log('✅ Expense payments loaded:', data?.length || 0, 'records');
			paidExpensePayments = data || [];
		} catch (error) {
			console.error('Error loading paid expense payments:', error);
		}
	}

	// Get unique payment methods from current data
	$: availablePaymentMethods = [...new Set([
		...paidVendorPayments.map(p => p.payment_method).filter(Boolean),
		...paidExpensePayments.map(p => p.payment_method).filter(Boolean)
	])].sort();

	// Filtered payments
	$: filteredVendorPayments = paidVendorPayments.filter(payment => {
		if (filterBranch && payment.branch_id != filterBranch) return false;
		if (filterPaymentMethod && payment.payment_method !== filterPaymentMethod) return false;
		return true;
	});

	$: filteredExpensePayments = paidExpensePayments.filter(payment => {
		if (filterBranch && payment.branch_id != filterBranch) return false;
		if (filterPaymentMethod && payment.payment_method !== filterPaymentMethod) return false;
		return true;
	});

	// Update vendor payment reference
	async function updateVendorReference(paymentId, newReference) {
		try {
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update({ payment_reference: newReference || null })
				.eq('id', paymentId);

			if (error) {
				console.error('Error updating vendor payment reference:', error);
				alert('Failed to update payment reference');
				return;
			}

			// Update local data
			paidVendorPayments = paidVendorPayments.map(p => 
				p.id === paymentId ? { ...p, payment_reference: newReference } : p
			);
			editingVendorPaymentId = null;
			console.log('✅ Vendor payment reference updated');
		} catch (error) {
			console.error('Error updating vendor payment reference:', error);
			alert('Failed to update payment reference');
		}
	}

	// Update expense payment reference
	async function updateExpenseReference(paymentId, newReference) {
		try {
			const { error } = await supabase
				.from('expense_scheduler')
				.update({ payment_reference: newReference || null })
				.eq('id', paymentId);

			if (error) {
				console.error('Error updating expense payment reference:', error);
				alert('Failed to update payment reference');
				return;
			}

			// Update local data
			paidExpensePayments = paidExpensePayments.map(p => 
				p.id === paymentId ? { ...p, payment_reference: newReference } : p
			);
			editingExpensePaymentId = null;
			console.log('✅ Expense payment reference updated');
		} catch (error) {
			console.error('Error updating expense payment reference:', error);
			alert('Failed to update payment reference');
		}
	}

	// Open edit popup for pending transaction
	function openEditPopup(paymentId, paymentType, label) {
		editPopupPaymentId = paymentId;
		editPopupPaymentType = paymentType;
		editPopupReference = '';
		editPopupLabel = label;
		showEditPopup = true;
	}

	// Save from edit popup
	async function saveFromPopup() {
		if (!editPopupReference.trim()) {
			alert('Please enter an ERP Payment Reference');
			return;
		}

		if (editPopupPaymentType === 'vendor') {
			await updateVendorReference(editPopupPaymentId, editPopupReference);
		} else if (editPopupPaymentType === 'expense') {
			await updateExpenseReference(editPopupPaymentId, editPopupReference);
		}

		showEditPopup = false;
		// Refresh pending list
		pendingVendorPayments = paidVendorPayments.filter(p => !p.payment_reference);
		pendingExpensePayments = paidExpensePayments.filter(p => !p.payment_reference);
	}

	// Get pending ERP references
	function showPendingERPReferences() {
		pendingVendorPayments = paidVendorPayments.filter(p => !p.payment_reference);
		pendingExpensePayments = paidExpensePayments.filter(p => !p.payment_reference);
		showPendingModal = true;
	}

	// Open All Vendor Paid window
	async function openAllVendorPaidWindow() {
		const { default: AllVendorPaid } = await import('$lib/components/desktop-interface/master/finance/AllVendorPaid.svelte');
		openWindow({
			id: `all-vendor-paid-${Date.now()}`,
			title: '📦 All Vendor Paid Transactions',
			component: AllVendorPaid,
			icon: '📦',
			size: { width: 1100, height: 700 },
			position: { 
				x: 80 + (Math.random() * 50), 
				y: 80 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	// Open All Expense Paid window
	async function openAllExpensePaidWindow() {
		const { default: AllExpensePaid } = await import('$lib/components/desktop-interface/master/finance/AllExpensePaid.svelte');
		openWindow({
			id: `all-expense-paid-${Date.now()}`,
			title: '💳 All Expense Paid Transactions',
			component: AllExpensePaid,
			icon: '💳',
			size: { width: 1100, height: 700 },
			position: { 
				x: 100 + (Math.random() * 50), 
				y: 100 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	async function loadData() {
		isLoading = true;
		loadingProgress = 0;
		try {
			loadingProgress = 10;
			await loadBranches();
			loadingProgress = 40;
			await loadPaidVendorPayments();
			loadingProgress = 70;
			await loadPaidExpensePayments();
			loadingProgress = 100;
		} finally {
			isLoading = false;
			loadingProgress = 0;
		}
	}

	onMount(() => {
		loadData();
		subscribeToRealtimeUpdates();

		// Cleanup subscriptions on component unmount
		return () => {
			if (vendorSubscription) {
				vendorSubscription.unsubscribe();
			}
			if (expenseSubscription) {
				expenseSubscription.unsubscribe();
			}
		};
	});

	// Subscribe to real-time updates
	function subscribeToRealtimeUpdates() {
		console.log('🔄 Setting up real-time subscriptions...');

		// Subscribe to vendor_payment_schedule changes
		vendorSubscription = supabase
			.channel('vendor_payment_schedule_changes')
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'vendor_payment_schedule',
					filter: `is_paid=eq.true`
				},
				(payload) => {
					console.log('📦 Vendor payment update received:', payload);
					handleVendorPaymentUpdate(payload);
				}
			)
			.subscribe((status) => {
				console.log('📦 Vendor subscription status:', status);
			});

		// Subscribe to expense_scheduler changes
		expenseSubscription = supabase
			.channel('expense_scheduler_changes')
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'expense_scheduler',
					filter: `is_paid=eq.true`
				},
				(payload) => {
					console.log('💳 Expense payment update received:', payload);
					handleExpensePaymentUpdate(payload);
				}
			)
			.subscribe((status) => {
				console.log('💳 Expense subscription status:', status);
			});
	}

	// Handle vendor payment updates
	function handleVendorPaymentUpdate(payload) {
		const selectedDate = `${selectedYear}-${String(selectedMonth + 1).padStart(2, '0')}-${String(selectedDay).padStart(2, '0')}`;
		const nextDate = `${selectedYear}-${String(selectedMonth + 1).padStart(2, '0')}-${String(Math.min(selectedDay + 1, 31)).padStart(2, '0')}`;

		// Check if the updated payment matches the selected date
		const paymentDate = payload.new?.due_date || payload.old?.due_date;
		if (paymentDate && paymentDate >= selectedDate && paymentDate < nextDate && payload.new?.is_paid === true) {
			if (payload.eventType === 'INSERT') {
				console.log('✨ New vendor payment added');
				paidVendorPayments = [...paidVendorPayments, payload.new];
			} else if (payload.eventType === 'UPDATE') {
				console.log('🔄 Vendor payment updated');
				paidVendorPayments = paidVendorPayments.map(p =>
					p.id === payload.new.id ? payload.new : p
				);
			} else if (payload.eventType === 'DELETE') {
				console.log('🗑️ Vendor payment deleted');
				paidVendorPayments = paidVendorPayments.filter(p => p.id !== payload.old.id);
			}
		}
	}

	// Handle expense payment updates
	function handleExpensePaymentUpdate(payload) {
		const selectedDate = `${selectedYear}-${String(selectedMonth + 1).padStart(2, '0')}-${String(selectedDay).padStart(2, '0')}`;
		const nextDate = `${selectedYear}-${String(selectedMonth + 1).padStart(2, '0')}-${String(Math.min(selectedDay + 1, 31)).padStart(2, '0')}`;

		// Check if the updated payment matches the selected date
		const paymentDate = payload.new?.due_date || payload.old?.due_date;
		if (paymentDate && paymentDate >= selectedDate && paymentDate < nextDate && payload.new?.is_paid === true) {
			if (payload.eventType === 'INSERT') {
				console.log('✨ New expense payment added');
				paidExpensePayments = [...paidExpensePayments, payload.new];
			} else if (payload.eventType === 'UPDATE') {
				console.log('🔄 Expense payment updated');
				paidExpensePayments = paidExpensePayments.map(p =>
					p.id === payload.new.id ? payload.new : p
				);
			} else if (payload.eventType === 'DELETE') {
				console.log('🗑️ Expense payment deleted');
				paidExpensePayments = paidExpensePayments.filter(p => p.id !== payload.old.id);
			}
		}
	}

	$: if (selectedYear && selectedMonth !== undefined && selectedDay) {
		loadData();
	}
</script>

<div class="paid-manager-container">
	{#if isLoading}
		<div class="loading-overlay">
			<div class="loading-content">
				<div class="loading-spinner"></div>
				<div class="loading-text">Loading paid transactions...</div>
				<div class="progress-bar">
					<div class="progress-fill" style="width: {loadingProgress}%"></div>
				</div>
				<div class="progress-text">{loadingProgress}%</div>
			</div>
		</div>
	{/if}

	<div class="header-section">
		<div class="top-controls">
			<div class="month-selector">
				<label for="month-select">Choose Month:</label>
				<select id="month-select" bind:value={selectedMonth}>
					{#each months as month, index}
						<option value={index}>{month}</option>
					{/each}
				</select>
				<select id="year-select" bind:value={selectedYear}>
					{#each Array(10) as _, i}
						<option value={new Date().getFullYear() - 5 + i}>
							{new Date().getFullYear() - 5 + i}
						</option>
					{/each}
				</select>
				<label for="day-select">Choose Day:</label>
				<select id="day-select" bind:value={selectedDay}>
					{#each Array(daysInMonth) as _, i}
						<option value={i + 1}>{i + 1}</option>
					{/each}
				</select>
			</div>
		</div>

		<!-- Filters -->
		<div class="filters-section">
			<div class="filter-group">
				<label for="filter-branch">Branch:</label>
				<select id="filter-branch" bind:value={filterBranch}>
					<option value="">All Branches</option>
					{#each branches as branch}
						<option value={branch.id}>{branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en}</option>
					{/each}
				</select>
			</div>
			<div class="filter-group">
				<label for="filter-payment-method">Payment Method:</label>
				<select id="filter-payment-method" bind:value={filterPaymentMethod}>
					<option value="">All Methods</option>
					{#each availablePaymentMethods as method}
						<option value={method}>{method}</option>
					{/each}
				</select>
			</div>
			<button class="pending-btn" on:click={showPendingERPReferences}>
				⚠️ Pending ERP References
				<span class="pending-count">
					({paidVendorPayments.filter(p => !p.payment_reference).length + paidExpensePayments.filter(p => !p.payment_reference).length})
				</span>
			</button>
			<button class="view-all-btn vendor-btn" on:click={openAllVendorPaidWindow}>
				📦 View All Vendor Paid
			</button>
			<button class="view-all-btn expense-btn" on:click={openAllExpensePaidWindow}>
				💳 View All Expense Paid
			</button>
		</div>
	</div>

	<!-- Paid Vendor Payments Section -->
	<div class="payment-section">
		<div class="section-header">
			<h3 class="section-title">📦 Paid Vendor Payments</h3>
			<div class="section-summary">
				{#if true}
					{@const totalAmount = filteredVendorPayments.reduce((sum, p) => sum + (p.final_bill_amount || 0), 0)}
					<span>{filteredVendorPayments.length} payment{filteredVendorPayments.length !== 1 ? 's' : ''}</span>
					<span>Total: {formatCurrency(totalAmount)}</span>
				{/if}
			</div>
		</div>

		<div class="simple-table-container">
			<table class="simple-payments-table">
				<thead>
					<tr>
						<th>Bill #</th>
						<th>Vendor</th>
						<th>Amount</th>
						<th>Bill Date</th>
						<th>Paid Date</th>
						<th>Branch</th>
						<th>Payment Method</th>
						<th>ERP Payment Reference</th>
					</tr>
				</thead>
				<tbody>
					{#if filteredVendorPayments.length > 0}
						{#each filteredVendorPayments as payment}
							<tr class="paid-row">
								<td>
									<span class="bill-number-badge">#{payment.bill_number || 'N/A'}</span>
								</td>
								<td style="text-align: left; font-weight: 500;">
									{payment.vendor_name || 'N/A'}
								</td>
								<td style="text-align: right; font-weight: 600; color: #059669;">
									{formatCurrency(payment.final_bill_amount)}
								</td>
								<td>{formatDate(payment.bill_date)}</td>
								<td style="color: #059669; font-weight: 500;">{formatDate(payment.paid_date)}</td>
							<td>{getBranchName(payment.branch_id)}</td>
							<td>
								<span class="payment-method">{payment.payment_method || 'Cash on Delivery'}</span>
							</td>
							<td>
								{#if editingVendorPaymentId === payment.id}
									<div class="edit-cell">
										<input 
											type="text" 
											value={editingVendorReference}
											on:change={(e) => editingVendorReference = e.target.value}
											on:keydown={(e) => {
												if (e.key === 'Enter') {
													updateVendorReference(payment.id, editingVendorReference);
												} else if (e.key === 'Escape') {
													editingVendorPaymentId = null;
												}
											}}
											placeholder="Enter ERP Reference"
											autoFocus
										/>
										<button class="save-btn" on:click={() => updateVendorReference(payment.id, editingVendorReference)}>✓</button>
										<button class="cancel-btn" on:click={() => editingVendorPaymentId = null}>✕</button>
									</div>
								{:else}
									<div class="editable-cell" on:click={() => {
										editingVendorPaymentId = payment.id;
										editingVendorReference = payment.payment_reference || '';
									}}>
										{payment.payment_reference || 'N/A'}
										<span class="edit-icon">✏️</span>
									</div>
								{/if}
							</td>
						</tr>
					{/each}
					{:else}
						<tr>
							<td colspan="8" class="empty-payments-row">
								<div class="empty-message">No paid vendor payments for this month</div>
							</td>
						</tr>
					{/if}
				</tbody>
			</table>
		</div>
	</div>

	<!-- Paid Expense Payments Section -->
	<div class="payment-section">
		<div class="section-header">
			<h3 class="section-title">💳 Paid Other Payments (Expense Scheduler)</h3>
			<div class="section-summary">
				{#if true}
					{@const totalExpenses = filteredExpensePayments.reduce((sum, p) => sum + (p.amount || 0), 0)}
					<span>{filteredExpensePayments.length} payment{filteredExpensePayments.length !== 1 ? 's' : ''}</span>
					<span>Total: {formatCurrency(totalExpenses)}</span>
				{/if}
			</div>
		</div>

		<div class="simple-table-container">
			<table class="simple-payments-table">
				<thead>
					<tr>
						<th>Voucher Number</th>
						<th>Sub-Category</th>
						<th>Branch</th>
						<th>Payment Method</th>
						<th>Amount</th>
						<th>Paid Date</th>
						<th>Created By</th>
						<th>Description</th>
						<th>ERP Payment Reference</th>
					</tr>
				</thead>
				<tbody>
					{#if filteredExpensePayments.length > 0}
						{#each filteredExpensePayments as payment}
							<tr class="paid-row">
								<td>
									<span class="bill-number-badge">#{payment.id || 'N/A'}</span>
								</td>
								<td style="text-align: left;">
									{#if payment.expense_category_name_en || payment.expense_category_name_ar}
										{payment.expense_category_name_en || payment.expense_category_name_ar}
									{:else}
										<span style="color: #f59e0b; font-style: italic;">Unknown Category</span>
									{/if}
								</td>
								<td style="text-align: left;">{getBranchName(payment.branch_id)}</td>
								<td>
									<span class="payment-method-badge">
										{payment.payment_method || 'Expense'}
									</span>
								</td>
								<td style="text-align: right; font-weight: 600; color: #059669;">
									{formatCurrency(payment.amount || 0)}
								</td>
								<td style="color: #059669; font-weight: 500;">{formatDate(payment.paid_date)}</td>
						<td>{payment.creator?.username || 'Unknown'}</td>
						<td style="text-align: left; max-width: 200px; overflow: hidden; text-overflow: ellipsis;" title="{payment.description || ''}">
							{payment.description || 'N/A'}
						</td>
						<td>
							{#if editingExpensePaymentId === payment.id}
								<div class="edit-cell">
									<input 
										type="text" 
										value={editingExpenseReference}
										on:change={(e) => editingExpenseReference = e.target.value}
										on:keydown={(e) => {
											if (e.key === 'Enter') {
												updateExpenseReference(payment.id, editingExpenseReference);
											} else if (e.key === 'Escape') {
												editingExpensePaymentId = null;
											}
										}}
										placeholder="Enter ERP Reference"
										autoFocus
									/>
									<button class="save-btn" on:click={() => updateExpenseReference(payment.id, editingExpenseReference)}>✓</button>
									<button class="cancel-btn" on:click={() => editingExpensePaymentId = null}>✕</button>
								</div>
							{:else}
								<div class="editable-cell" on:click={() => {
									editingExpensePaymentId = payment.id;
									editingExpenseReference = payment.payment_reference || '';
								}}>
									{payment.payment_reference || 'N/A'}
									<span class="edit-icon">✏️</span>
								</div>
							{/if}
						</td>
					</tr>
						{/each}
					{:else}
						<tr>
							<td colspan="9" class="empty-payments-row">
								<div class="empty-message">No paid expense payments for this month</div>
							</td>
						</tr>
					{/if}
				</tbody>
			</table>
		</div>
	</div>
</div>

<!-- Pending ERP References Modal -->
{#if showPendingModal}
	<div class="modal-overlay" on:click={() => showPendingModal = false}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2>⚠️ Pending ERP Payment References</h2>
				<p class="modal-subtitle">Selected Date: {new Date(selectedYear, selectedMonth, selectedDay).toLocaleDateString()}</p>
			</div>

			<div class="modal-body">
				<!-- Vendor Payments Summary -->
				<div class="pending-section">
					<h3 class="pending-title">📦 Vendor Payments Without ERP Reference</h3>
					<div class="pending-summary">
						<span class="count-badge vendor-badge">{pendingVendorPayments.length}</span>
						<span class="summary-text">payments missing ERP reference</span>
					</div>
					{#if pendingVendorPayments.length > 0}
						<div class="pending-list">
							{#each pendingVendorPayments as payment}
								<div class="pending-item clickable-item" on:click={() => openEditPopup(payment.id, 'vendor', `Bill #${payment.bill_number} - ${payment.vendor_name}`)}>
									<div class="pending-info">
										<span class="bill-info">Bill #{payment.bill_number}</span>
										<span class="vendor-name">{payment.vendor_name}</span>
										<span class="due-date">Due: {formatDate(payment.due_date)}</span>
									</div>
									<span class="pending-amount">{formatCurrency(payment.final_bill_amount)}</span>
								</div>
							{/each}
						</div>
					{:else}
						<p class="no-pending">✓ All vendor payments have ERP references</p>
					{/if}
				</div>

				<!-- Expense Payments Summary -->
				<div class="pending-section">
					<h3 class="pending-title">💳 Expense Payments Without ERP Reference</h3>
					<div class="pending-summary">
						<span class="count-badge expense-badge">{pendingExpensePayments.length}</span>
						<span class="summary-text">payments missing ERP reference</span>
					</div>
					{#if pendingExpensePayments.length > 0}
						<div class="pending-list">
							{#each pendingExpensePayments as payment}
								<div class="pending-item clickable-item" on:click={() => openEditPopup(payment.id, 'expense', `Voucher #${payment.id} - ${payment.expense_category_name_en || payment.expense_category_name_ar || 'Unknown'}`)}>
									<div class="pending-info">
										<span class="bill-info">Voucher #{payment.id}</span>
										<span class="vendor-name">{payment.expense_category_name_en || payment.expense_category_name_ar || 'Unknown'}</span>
										<span class="due-date">Due: {formatDate(payment.due_date)}</span>
									</div>
									<span class="pending-amount">{formatCurrency(payment.amount)}</span>
								</div>
							{/each}
						</div>
					{:else}
						<p class="no-pending">✓ All expense payments have ERP references</p>
					{/if}
				</div>

				<!-- Summary Stats -->
				<div class="pending-stats">
					<div class="stat">
						<span class="stat-label">Total Pending:</span>
						<span class="stat-value">{pendingVendorPayments.length + pendingExpensePayments.length}</span>
					</div>
					<div class="stat">
						<span class="stat-label">Total Amount:</span>
						<span class="stat-value">
							{formatCurrency(
								pendingVendorPayments.reduce((sum, p) => sum + (p.final_bill_amount || 0), 0) +
								pendingExpensePayments.reduce((sum, p) => sum + (p.amount || 0), 0)
							)}
						</span>
					</div>
				</div>
			</div>

			<div class="modal-footer">
				<button class="close-btn" on:click={() => showPendingModal = false}>Close</button>
			</div>
		</div>
	</div>
{/if}

<!-- Edit ERP Reference Popup Modal -->
{#if showEditPopup}
	<div class="modal-overlay" on:click={() => showEditPopup = false}>
		<div class="edit-popup-content" on:click|stopPropagation>
			<div class="edit-popup-header">
				<h3>📝 Edit ERP Payment Reference</h3>
				<p class="edit-popup-label">{editPopupLabel}</p>
			</div>

			<div class="edit-popup-body">
				<label for="erp-reference-input">ERP Payment Reference:</label>
				<input
					id="erp-reference-input"
					type="text"
					placeholder="Enter ERP Payment Reference"
					bind:value={editPopupReference}
					on:keydown={(e) => {
						if (e.key === 'Enter') {
							saveFromPopup();
						} else if (e.key === 'Escape') {
							showEditPopup = false;
						}
					}}
					autoFocus
				/>
			</div>

			<div class="edit-popup-footer">
				<button class="popup-cancel-btn" on:click={() => showEditPopup = false}>Cancel</button>
				<button class="popup-save-btn" on:click={saveFromPopup}>Save</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.paid-manager-container {
		width: 100%;
		height: 100%;
		padding: 24px;
		background: #f8fafc;
		overflow-y: auto;
	}

	.header-section {
		margin-bottom: 24px;
		padding: 16px;
		background: white;
		border-radius: 8px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.top-controls {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 16px;
	}

	.month-selector {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 16px;
	}

	.month-selector label {
		font-weight: 600;
		color: #1e293b;
		font-size: 14px;
	}

	.month-selector select {
		padding: 8px 12px;
		border: 1px solid #cbd5e1;
		border-radius: 6px;
		background: white;
		font-size: 14px;
		color: #1e293b;
		cursor: pointer;
		outline: none;
		transition: border-color 0.2s;
	}

	.month-selector select:hover {
		border-color: #3b82f6;
	}

	.month-selector select:focus {
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.filters-section {
		display: flex;
		gap: 16px;
		align-items: center;
	}

	.filter-group {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.filter-group label {
		font-size: 14px;
		color: #64748b;
		font-weight: 500;
	}

	.filter-group select {
		padding: 6px 10px;
		border: 1px solid #cbd5e1;
		border-radius: 4px;
		background: white;
		font-size: 13px;
		color: #1e293b;
		cursor: pointer;
	}

	.payment-section {
		margin-bottom: 24px;
		background: white;
		border-radius: 8px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		overflow: hidden;
	}

	.section-header {
		padding: 16px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.section-title {
		color: white;
		font-size: 18px;
		font-weight: 600;
		margin: 0;
	}

	.section-summary {
		display: flex;
		gap: 16px;
		color: white;
		font-size: 14px;
	}

	.section-summary span {
		padding: 4px 8px;
		background: rgba(255, 255, 255, 0.2);
		border-radius: 4px;
	}

	.simple-table-container {
		overflow-x: auto;
		max-height: 600px;
		overflow-y: auto;
	}

	.simple-payments-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
	}

	.simple-payments-table thead {
		position: sticky;
		top: 0;
		z-index: 110;
		background: #f1f5f9;
	}

	.simple-payments-table th {
		padding: 12px 8px;
		text-align: left;
		font-weight: 600;
		color: #475569;
		border-bottom: 2px solid #e2e8f0;
	}

	.simple-payments-table td {
		padding: 12px 8px;
		border-bottom: 1px solid #f1f5f9;
		color: #1e293b;
	}

	.simple-payments-table tbody tr:hover {
		background: #f8fafc;
	}

	.bill-number-badge {
		background: #e0e7ff;
		color: #4338ca;
		padding: 4px 8px;
		border-radius: 4px;
		font-weight: 600;
		font-size: 11px;
	}

	.payment-method {
		background: #fef3c7;
		color: #92400e;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 500;
	}

	.payment-method-badge {
		background: #fee2e2;
		color: #991b1b;
		font-size: 11px;
		padding: 4px 8px;
		border-radius: 4px;
		font-weight: 500;
	}

	.empty-payments-row {
		text-align: center;
		padding: 40px 20px !important;
	}

	.empty-message {
		color: #94a3b8;
		font-size: 14px;
		font-style: italic;
	}

	.paid-row {
		background: #f0fdf4;
	}

	.loading-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(255, 255, 255, 0.95);
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		z-index: 9999;
		backdrop-filter: blur(4px);
	}

	.loading-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 20px;
	}

	.loading-spinner {
		width: 60px;
		height: 60px;
		border: 6px solid #e2e8f0;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.loading-text {
		font-size: 18px;
		color: #475569;
		font-weight: 600;
	}

	.progress-bar {
		width: 300px;
		height: 8px;
		background: #e2e8f0;
		border-radius: 10px;
		overflow: hidden;
	}

	.progress-fill {
		height: 100%;
		background: linear-gradient(90deg, #3b82f6 0%, #8b5cf6 100%);
		transition: width 0.3s ease;
		border-radius: 10px;
	}

	.progress-text {
		font-size: 16px;
		color: #64748b;
		font-weight: 600;
	}

	/* Editable cell styles */
	.editable-cell {
		display: flex;
		align-items: center;
		gap: 8px;
		cursor: pointer;
		padding: 4px 8px;
		border-radius: 4px;
		transition: background-color 0.2s;
	}

	.editable-cell:hover {
		background-color: #f0f9ff;
		color: #0284c7;
	}

	.edit-icon {
		opacity: 0;
		transition: opacity 0.2s;
	}

	.editable-cell:hover .edit-icon {
		opacity: 1;
	}

	.edit-cell {
		display: flex;
		gap: 4px;
		align-items: center;
	}

	.edit-cell input {
		flex: 1;
		padding: 6px 8px;
		border: 1px solid #3b82f6;
		border-radius: 4px;
		font-size: 13px;
		outline: none;
	}

	.edit-cell input:focus {
		border-color: #1d4ed8;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}

	.save-btn,
	.cancel-btn {
		padding: 4px 8px;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 600;
		transition: all 0.2s;
	}

	.save-btn {
		background: #10b981;
		color: white;
	}

	.save-btn:hover {
		background: #059669;
	}

	.cancel-btn {
		background: #ef4444;
		color: white;
	}

	.cancel-btn:hover {
		background: #dc2626;
	}

	/* Pending ERP References Button */
	.pending-btn {
		padding: 8px 16px;
		background: linear-gradient(135deg, #f97316 0%, #ea580c 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		font-size: 14px;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 8px;
		transition: all 0.2s;
		box-shadow: 0 2px 8px rgba(249, 115, 22, 0.2);
	}

	.pending-btn:hover {
		background: linear-gradient(135deg, #fb923c 0%, #f97316 100%);
		box-shadow: 0 4px 12px rgba(249, 115, 22, 0.3);
		transform: translateY(-2px);
	}

	.pending-count {
		background: rgba(255, 255, 255, 0.3);
		padding: 2px 8px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 700;
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
		backdrop-filter: blur(4px);
	}

	.modal-content {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
		max-width: 700px;
		width: 90%;
		max-height: 85vh;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
	}

	.modal-header {
		padding: 24px;
		border-bottom: 2px solid #e2e8f0;
		background: linear-gradient(135deg, #f97316 0%, #ea580c 100%);
		color: white;
	}

	.modal-header h2 {
		margin: 0 0 8px 0;
		font-size: 24px;
		font-weight: 700;
	}

	.modal-subtitle {
		margin: 0;
		font-size: 14px;
		opacity: 0.9;
	}

	.modal-body {
		padding: 24px;
		flex: 1;
		overflow-y: auto;
	}

	.modal-footer {
		padding: 16px 24px;
		border-top: 1px solid #e2e8f0;
		display: flex;
		justify-content: flex-end;
		gap: 12px;
	}

	.close-btn {
		padding: 8px 24px;
		background: #e2e8f0;
		color: #475569;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.close-btn:hover {
		background: #cbd5e1;
	}

	/* Pending sections */
	.pending-section {
		margin-bottom: 24px;
		padding: 16px;
		background: #f8fafc;
		border-radius: 8px;
		border-left: 4px solid #f97316;
	}

	.pending-title {
		margin: 0 0 12px 0;
		font-size: 16px;
		font-weight: 600;
		color: #1e293b;
	}

	.pending-summary {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 16px;
	}

	.count-badge {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		border-radius: 50%;
		font-weight: 700;
		font-size: 18px;
		color: white;
	}

	.vendor-badge {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
	}

	.expense-badge {
		background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
	}

	.summary-text {
		font-size: 14px;
		color: #64748b;
		font-weight: 500;
	}

	.pending-list {
		display: flex;
		flex-direction: column;
		gap: 8px;
		max-height: 300px;
		overflow-y: auto;
	}

	.pending-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px;
		background: white;
		border-radius: 6px;
		border: 1px solid #e2e8f0;
		transition: all 0.2s;
	}

	.pending-item:hover {
		background: #f0f9ff;
		border-color: #3b82f6;
	}

	.pending-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.bill-info {
		font-weight: 600;
		color: #1e293b;
		font-size: 14px;
	}

	.vendor-name {
		font-size: 13px;
		color: #64748b;
	}

	.due-date {
		font-size: 12px;
		color: #94a3b8;
	}

	.pending-amount {
		font-weight: 600;
		color: #059669;
		font-size: 14px;
	}

	.no-pending {
		text-align: center;
		padding: 20px;
		color: #059669;
		font-weight: 500;
		margin: 0;
	}

	.pending-stats {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
		padding: 16px;
		background: linear-gradient(135deg, #f0f9ff 0%, #f0fdfa 100%);
		border-radius: 8px;
		margin-top: 16px;
	}

	.stat {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.stat-label {
		font-size: 13px;
		color: #64748b;
		font-weight: 500;
	}

	.stat-value {
		font-size: 18px;
		font-weight: 700;
		color: #0f766e;
	}

	/* Clickable pending items */
	.clickable-item {
		cursor: pointer;
		transition: all 0.2s;
	}

	.clickable-item:hover {
		background: #e0f2fe !important;
		border-color: #0284c7 !important;
		box-shadow: 0 2px 8px rgba(2, 132, 199, 0.15);
		transform: translateX(4px);
	}

	/* Edit Popup Styles */
	.edit-popup-content {
		background: white;
		border-radius: 12px;
		box-shadow: 0 25px 50px rgba(0, 0, 0, 0.25);
		width: 90%;
		max-width: 450px;
		display: flex;
		flex-direction: column;
		z-index: 1001;
	}

	.edit-popup-header {
		padding: 20px 24px;
		border-bottom: 2px solid #e2e8f0;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		border-radius: 12px 12px 0 0;
	}

	.edit-popup-header h3 {
		margin: 0 0 8px 0;
		font-size: 20px;
		font-weight: 700;
	}

	.edit-popup-label {
		margin: 0;
		font-size: 13px;
		opacity: 0.9;
		font-weight: 500;
	}

	.edit-popup-body {
		padding: 24px;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.edit-popup-body label {
		display: block;
		font-weight: 600;
		color: #1e293b;
		font-size: 14px;
		margin-bottom: 8px;
	}

	.edit-popup-body input {
		width: 100%;
		padding: 12px 14px;
		border: 2px solid #cbd5e1;
		border-radius: 8px;
		font-size: 15px;
		color: #1e293b;
		outline: none;
		transition: all 0.2s;
		font-family: inherit;
	}

	.edit-popup-body input:focus {
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.edit-popup-body input::placeholder {
		color: #94a3b8;
	}

	.edit-popup-footer {
		padding: 16px 24px;
		border-top: 1px solid #e2e8f0;
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		background: #f8fafc;
		border-radius: 0 0 12px 12px;
	}

	.popup-cancel-btn,
	.popup-save-btn {
		padding: 10px 24px;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.popup-cancel-btn {
		background: #e2e8f0;
		color: #475569;
	}

	.popup-cancel-btn:hover {
		background: #cbd5e1;
		transform: translateY(-2px);
	}

	.popup-save-btn {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.2);
	}

	.popup-save-btn:hover {
		box-shadow: 0 6px 20px rgba(16, 185, 129, 0.3);
		transform: translateY(-2px);
	}

	/* View All Paid Buttons */
	.view-all-btn {
		padding: 8px 16px;
		color: white;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		font-size: 14px;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 8px;
		transition: all 0.2s;
	}

	.view-all-btn.vendor-btn {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.2);
	}

	.view-all-btn.vendor-btn:hover {
		background: linear-gradient(135deg, #60a5fa 0%, #3b82f6 100%);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
		transform: translateY(-2px);
	}

	.view-all-btn.expense-btn {
		background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
		box-shadow: 0 2px 8px rgba(139, 92, 246, 0.2);
	}

	.view-all-btn.expense-btn:hover {
		background: linear-gradient(135deg, #a78bfa 0%, #8b5cf6 100%);
		box-shadow: 0 4px 12px rgba(139, 92, 246, 0.3);
		transform: translateY(-2px);
	}
</style>
