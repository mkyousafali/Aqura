<script>
	import { onMount } from 'svelte';
	import { supabaseAdmin } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	// Component state
	let isLoading = false;
	let selectedDate = '';
	let dailyBudget = 0;
	
	// Data arrays
	let vendorPayments = [];
	let expenseSchedules = [];
	let nonApprovedPayments = [];
	
	// Checkbox selections for budget calculation
	let selectedVendorPayments = new Set();
	let selectedExpenseSchedules = new Set();
	let selectedNonApprovedPayments = new Set();
	
	// Budget tracking
	let totalScheduled = 0;
	let remainingBudget = 0;
	let budgetStatus = 'within'; // 'within', 'over', 'exact'

	// Budget management
	let showBudgetModal = false;
	let paymentMethodBudgets = {}; // payment_method -> budget amount (using object instead of Map)
	let totalBudgetLimit = 0;
	let adjustAmounts = {}; // Track adjust amounts for each item

	// Filter variables
	let vendorFilter = '';
	let branchFilter = '';
	let paymentMethodFilter = '';
	
	// Expense filter variables
	let expenseDescriptionFilter = '';
	let expenseCategoryFilter = '';
	let expenseBranchFilter = '';
	let expensePaymentMethodFilter = '';

	// Reactive breakdown calculation
	$: breakdown = getDetailedBreakdown(vendorPayments, expenseSchedules, nonApprovedPayments, selectedVendorPayments, selectedExpenseSchedules, selectedNonApprovedPayments, adjustAmounts);
	
	// Calculate total from payment method budgets reactively
	$: calculatedTotalBudget = Object.values(paymentMethodBudgets).reduce((sum, budget) => {
		const budgetValue = parseFloat(budget) || 0;
		return sum + budgetValue;
	}, 0);
	
	// Recalculate budget when payment method budgets change
	$: if (paymentMethodBudgets) {
		calculateBudget();
	}

	// Filter vendor payments
	$: filteredVendorPayments = vendorPayments.filter(payment => {
		const vendorMatch = !vendorFilter || payment.vendor_name.toLowerCase().includes(vendorFilter.toLowerCase());
		const branchMatch = !branchFilter || branchFilter === 'all' || payment.branch_name === branchFilter;
		const paymentMethodMatch = !paymentMethodFilter || paymentMethodFilter === 'all' || payment.payment_method === paymentMethodFilter;
		return vendorMatch && branchMatch && paymentMethodMatch;
	});

	// Filter expense schedules
	$: filteredExpenseSchedules = expenseSchedules.filter(expense => {
		const descriptionMatch = !expenseDescriptionFilter || expense.description.toLowerCase().includes(expenseDescriptionFilter.toLowerCase());
		const categoryMatch = !expenseCategoryFilter || (expense.expense_category_name_en && expense.expense_category_name_en.toLowerCase().includes(expenseCategoryFilter.toLowerCase()));
		const branchMatch = !expenseBranchFilter || expenseBranchFilter === 'all' || expense.branch_name === expenseBranchFilter;
		const paymentMethodMatch = !expensePaymentMethodFilter || expensePaymentMethodFilter === 'all' || expense.payment_method === expensePaymentMethodFilter;
		return descriptionMatch && categoryMatch && branchMatch && paymentMethodMatch;
	});

	// Get unique values for dropdowns
	$: uniqueVendorBranches = [...new Set(vendorPayments.map(p => p.branch_name).filter(Boolean))].sort();
	$: uniqueVendorPaymentMethods = [...new Set(vendorPayments.map(p => p.payment_method).filter(Boolean))].sort();
	$: uniqueExpenseBranches = [...new Set(expenseSchedules.map(e => e.branch_name).filter(Boolean))].sort();
	$: uniqueExpensePaymentMethods = [...new Set(expenseSchedules.map(e => e.payment_method).filter(Boolean))].sort();

	// Rescheduling modal
	let showRescheduleModal = false;
	let rescheduleItem = null;
	let rescheduleType = ''; // 'vendor' or 'expense'
	let newDueDate = '';
	
	// Split functionality
	let showSplitModal = false;
	let splitItem = null;
	let splitType = ''; // 'vendor' or 'expense'
	let splitAmount = 0;
	let remainingAmount = 0;

	onMount(() => {
		// Set default date to today
		selectedDate = new Date().toISOString().split('T')[0];
		loadScheduledItems();
	});

	// Reactive calculations
	$: {
		if (vendorPayments && expenseSchedules && dailyBudget >= 0) {
			calculateBudget();
		}
	}

	function calculateBudget() {
		// Calculate total from selected vendor payments only
		const vendorTotal = vendorPayments.reduce((sum, payment) => {
			if (selectedVendorPayments.has(payment.id)) {
				return sum + (payment.final_bill_amount || payment.bill_amount || 0);
			}
			return sum;
		}, 0);

		// Calculate total from selected expense schedules only
		const expenseTotal = expenseSchedules.reduce((sum, expense) => {
			if (selectedExpenseSchedules.has(expense.id)) {
				return sum + (expense.amount || 0);
			}
			return sum;
		}, 0);

		// Calculate total from selected non-approved payments (for awareness)
		const nonApprovedTotal = nonApprovedPayments.reduce((sum, payment) => {
			if (selectedNonApprovedPayments.has(payment.id)) {
				return sum + (payment.final_bill_amount || payment.bill_amount || 0);
			}
			return sum;
		}, 0);

		totalScheduled = vendorTotal + expenseTotal + nonApprovedTotal;

		// Calculate effective daily budget
		let effectiveDailyBudget = calculatedTotalBudget;
		
		// If total budget limit is set, use that
		if (totalBudgetLimit > 0) {
			effectiveDailyBudget = totalBudgetLimit;
		} else {
			// Otherwise, calculate total from payment method budgets
			const paymentMethodTotal = Object.values(paymentMethodBudgets).reduce((sum, budget) => {
				const budgetValue = parseFloat(budget) || 0;
				return sum + budgetValue;
			}, 0);
			
			if (paymentMethodTotal > 0) {
				effectiveDailyBudget = paymentMethodTotal;
				// Update the displayed daily budget to show the calculated total
				dailyBudget = effectiveDailyBudget;
			}
		}

		remainingBudget = effectiveDailyBudget - totalScheduled;

		// Determine budget status - check both total and individual payment methods
		let isOverBudget = remainingBudget < 0;
		let isAnyPaymentMethodOverBudget = false;
		
		// Check if any payment method is over budget
		if (breakdown && breakdown.allPaymentMethods) {
			for (const method of breakdown.allPaymentMethods) {
				const methodBudget = paymentMethodBudgets[method] || 0;
				const methodUsed = breakdown.byPaymentMethod.get(method) || 0;
				if (methodBudget > 0 && methodUsed > methodBudget) {
					isAnyPaymentMethodOverBudget = true;
					break;
				}
			}
		}
		
		// Set budget status based on overall and individual payment method status
		if (isOverBudget || isAnyPaymentMethodOverBudget) {
			budgetStatus = 'over';
		} else if (remainingBudget === 0) {
			budgetStatus = 'exact';
		} else {
			budgetStatus = 'within';
		}
	}

	// Calculate detailed breakdown by payment method
	function getDetailedBreakdown() {
		const breakdown = {
			byPaymentMethod: new Map(),
			allPaymentMethods: new Set()
		};

		// Collect all available payment methods from all data (regardless of selection)
		vendorPayments.forEach(payment => {
			if (payment.payment_method) {
				breakdown.allPaymentMethods.add(payment.payment_method);
			}
		});

		expenseSchedules.forEach(expense => {
			if (expense.payment_method) {
				breakdown.allPaymentMethods.add(expense.payment_method);
			}
		});

		nonApprovedPayments.forEach(payment => {
			if (payment.payment_method) {
				breakdown.allPaymentMethods.add(payment.payment_method);
			}
		});

		// Initialize all payment methods with 0 amounts
		breakdown.allPaymentMethods.forEach(method => {
			breakdown.byPaymentMethod.set(method, 0);
		});

		// Process selected vendor payments
		vendorPayments.forEach(payment => {
			if (selectedVendorPayments.has(payment.id)) {
				const adjustAmount = adjustAmounts[`vendor_${payment.id}`];
				const amount = (adjustAmount && parseFloat(adjustAmount) > 0) 
					? parseFloat(adjustAmount) 
					: (payment.final_bill_amount || payment.bill_amount);
				const method = payment.payment_method || 'Unknown';
				
				breakdown.byPaymentMethod.set(method, (breakdown.byPaymentMethod.get(method) || 0) + amount);
			}
		});

		// Process selected expense schedules
		expenseSchedules.forEach(expense => {
			if (selectedExpenseSchedules.has(expense.id)) {
				const adjustAmount = adjustAmounts[`expense_${expense.id}`];
				const amount = (adjustAmount && parseFloat(adjustAmount) > 0) 
					? parseFloat(adjustAmount) 
					: expense.amount;
				const method = expense.payment_method || 'Unknown';
				
				breakdown.byPaymentMethod.set(method, (breakdown.byPaymentMethod.get(method) || 0) + amount);
			}
		});

		// Process selected non-approved payments
		nonApprovedPayments.forEach(payment => {
			if (selectedNonApprovedPayments.has(payment.id)) {
				const adjustAmount = adjustAmounts[`non_approved_${payment.id}`];
				const amount = (adjustAmount && parseFloat(adjustAmount) > 0) 
					? parseFloat(adjustAmount) 
					: (payment.final_bill_amount || payment.bill_amount);
				const method = payment.payment_method || 'Unknown';
				
				breakdown.byPaymentMethod.set(method, (breakdown.byPaymentMethod.get(method) || 0) + amount);
			}
		});

		console.log('🔍 Payment Methods Found:', Array.from(breakdown.allPaymentMethods));
		console.log('💰 Payment Method Breakdown:', Object.fromEntries(breakdown.byPaymentMethod));

		return breakdown;
	}

	// Budget modal functions
	function openBudgetModal() {
		showBudgetModal = true;
	}

	function closeBudgetModal() {
		showBudgetModal = false;
	}

	function saveBudgets() {
		// Save budget settings (you might want to persist these)
		calculateBudget();
		closeBudgetModal();
	}

	// Checkbox handling functions
	function toggleVendorPayment(paymentId) {
		if (selectedVendorPayments.has(paymentId)) {
			selectedVendorPayments.delete(paymentId);
		} else {
			selectedVendorPayments.add(paymentId);
		}
		selectedVendorPayments = selectedVendorPayments; // Trigger reactivity
		calculateBudget();
	}

	function toggleExpenseSchedule(expenseId) {
		if (selectedExpenseSchedules.has(expenseId)) {
			selectedExpenseSchedules.delete(expenseId);
		} else {
			selectedExpenseSchedules.add(expenseId);
		}
		selectedExpenseSchedules = selectedExpenseSchedules; // Trigger reactivity
		calculateBudget();
	}

	function toggleNonApprovedPayment(paymentId) {
		if (selectedNonApprovedPayments.has(paymentId)) {
			selectedNonApprovedPayments.delete(paymentId);
		} else {
			selectedNonApprovedPayments.add(paymentId);
		}
		selectedNonApprovedPayments = selectedNonApprovedPayments; // Trigger reactivity
		calculateBudget();
	}

	function selectAllVendorPayments() {
		vendorPayments.forEach(payment => selectedVendorPayments.add(payment.id));
		selectedVendorPayments = selectedVendorPayments;
		calculateBudget();
	}

	function selectAllExpenseSchedules() {
		expenseSchedules.forEach(expense => selectedExpenseSchedules.add(expense.id));
		selectedExpenseSchedules = selectedExpenseSchedules;
		calculateBudget();
	}

	function clearAllSelections() {
		selectedVendorPayments.clear();
		selectedExpenseSchedules.clear();
		selectedNonApprovedPayments.clear();
		selectedVendorPayments = selectedVendorPayments;
		selectedExpenseSchedules = selectedExpenseSchedules;
		selectedNonApprovedPayments = selectedNonApprovedPayments;
		calculateBudget();
	}

	async function loadScheduledItems() {
		if (!selectedDate) return;

		isLoading = true;
		try {
			await Promise.all([
				loadVendorPayments(),
				loadExpenseSchedules(),
				loadNonApprovedPayments()
			]);
		} catch (error) {
			console.error('Error loading scheduled items:', error);
			alert('❌ Error loading scheduled items: ' + error.message);
		} finally {
			isLoading = false;
		}
	}

	async function loadVendorPayments() {
		try {
			const { data, error } = await supabaseAdmin
				.from('vendor_payment_schedule')
				.select('*')
				.eq('due_date', selectedDate)
				.eq('is_paid', false)
				.in('approval_status', ['approved', 'pending'])
				.order('bill_amount', { ascending: false });

			if (error) throw error;
			vendorPayments = data || [];
			console.log('✅ Loaded vendor payments for', selectedDate, ':', vendorPayments.length);
		} catch (error) {
			console.error('Error loading vendor payments:', error);
			vendorPayments = [];
		}
	}

	async function loadExpenseSchedules() {
		try {
			const { data, error } = await supabaseAdmin
				.from('expense_scheduler')
				.select('*')
				.eq('due_date', selectedDate)
				.eq('is_paid', false)
				.order('amount', { ascending: false });

			if (error) throw error;
			expenseSchedules = data || [];
			console.log('✅ Loaded expense schedules for', selectedDate, ':', expenseSchedules.length);
		} catch (error) {
			console.error('Error loading expense schedules:', error);
			expenseSchedules = [];
		}
	}

	async function loadNonApprovedPayments() {
		try {
			const { data, error } = await supabaseAdmin
				.from('vendor_payment_schedule')
				.select('id, vendor_name, bill_amount, final_bill_amount, due_date, approval_status')
				.eq('due_date', selectedDate)
				.eq('is_paid', false)
				.eq('approval_status', 'sent_for_approval')
				.order('bill_amount', { ascending: false });

			if (error) throw error;
			nonApprovedPayments = data || [];
			console.log('✅ Loaded non-approved payments for', selectedDate, ':', nonApprovedPayments.length);
		} catch (error) {
			console.error('Error loading non-approved payments:', error);
			nonApprovedPayments = [];
		}
	}

	function onDateChange() {
		loadScheduledItems();
	}

	function openRescheduleModal(item, type) {
		rescheduleItem = item;
		rescheduleType = type;
		newDueDate = item.due_date;
		showRescheduleModal = true;
	}

	function openSplitModal(item, type) {
		splitItem = item;
		splitType = type;
		
		// Check if there's an adjust amount for this item
		let adjustKey = '';
		if (type === 'vendor') {
			adjustKey = `vendor_${item.id}`;
		} else if (type === 'expense') {
			adjustKey = `expense_${item.id}`;
		} else if (type === 'non_approved') {
			adjustKey = `non_approved_${item.id}`;
		}
		
		const adjustAmount = adjustAmounts[adjustKey];
		const hasAdjustAmount = adjustAmount && parseFloat(adjustAmount) > 0;
		
		// Get the original total amount
		const originalAmount = type === 'vendor' 
			? (item.final_bill_amount || item.bill_amount || 0)
			: (item.amount || 0);
		
		if (hasAdjustAmount) {
			// If there's an adjust amount, the split amount should be (original - adjustment)
			// and remaining amount should be the adjustment amount
			const adjAmount = parseFloat(adjustAmount);
			splitAmount = originalAmount - adjAmount; // Amount to move to new date
			remainingAmount = adjAmount; // Amount remaining (adjustment amount)
		} else {
			// If no adjust amount, start with 0 split amount
			splitAmount = 0;
			remainingAmount = originalAmount;
		}
		newDueDate = '';
		showSplitModal = true;
	}

	function closeRescheduleModal() {
		showRescheduleModal = false;
		rescheduleItem = null;
		rescheduleType = '';
		newDueDate = '';
	}

	function closeSplitModal() {
		showSplitModal = false;
		splitItem = null;
		splitType = '';
		splitAmount = 0;
		remainingAmount = 0;
		newDueDate = '';
	}

	async function executeReschedule() {
		if (!rescheduleItem || !newDueDate || !rescheduleType) return;

		isLoading = true;
		try {
			const tableName = rescheduleType === 'vendor' ? 'vendor_payment_schedule' : 'expense_scheduler';
			
			const { error } = await supabaseAdmin
				.from(tableName)
				.update({ due_date: newDueDate })
				.eq('id', rescheduleItem.id);

			if (error) throw error;

			alert(`✅ Successfully rescheduled to ${new Date(newDueDate).toLocaleDateString()}`);
			closeRescheduleModal();
			await loadScheduledItems(); // Reload to update the display
		} catch (error) {
			console.error('Error rescheduling:', error);
			alert('❌ Error rescheduling: ' + error.message);
		} finally {
			isLoading = false;
		}
	}

	async function executeSplit() {
		if (!splitItem || !newDueDate || !splitType || splitAmount <= 0) {
			alert('Please enter valid split amount and new date');
			return;
		}

		const originalAmount = splitType === 'vendor' 
			? (splitItem.final_bill_amount || splitItem.bill_amount || 0)
			: (splitItem.amount || 0);

		if (splitAmount >= originalAmount) {
			alert('Split amount must be less than the total amount');
			return;
		}

		remainingAmount = originalAmount - splitAmount;
		isLoading = true;

		try {
			if (splitType === 'vendor') {
				// Create new vendor payment record for split amount
				const { error: insertError } = await supabaseAdmin
					.from('vendor_payment_schedule')
					.insert({
						bill_number: splitItem.bill_number + '-SPLIT',
						vendor_id: splitItem.vendor_id,
						vendor_name: splitItem.vendor_name,
						branch_id: splitItem.branch_id,
						branch_name: splitItem.branch_name,
						bill_date: splitItem.bill_date,
						bill_amount: splitItem.bill_amount,
						final_bill_amount: splitAmount,
						payment_method: splitItem.payment_method,
						bank_name: splitItem.bank_name,
						iban: splitItem.iban,
						due_date: newDueDate,
						original_due_date: splitItem.original_due_date || splitItem.due_date,
						original_bill_amount: splitItem.original_bill_amount || splitItem.bill_amount,
						original_final_amount: splitAmount,
						credit_period: splitItem.credit_period,
						vat_number: splitItem.vat_number,
						is_paid: false,
						approval_status: splitItem.approval_status,
						notes: (splitItem.notes || '') + ' [Split from original payment]',
						created_by: $currentUser?.id
					});

				if (insertError) throw insertError;

				// Update original payment with remaining amount
				const { error: updateError } = await supabaseAdmin
					.from('vendor_payment_schedule')
					.update({ 
						final_bill_amount: remainingAmount,
						notes: (splitItem.notes || '') + ' [Original amount after split]'
					})
					.eq('id', splitItem.id);

				if (updateError) throw updateError;

			} else {
				// Handle expense scheduler split
				const { error: insertError } = await supabaseAdmin
					.from('expense_scheduler')
					.insert({
						branch_id: splitItem.branch_id,
						branch_name: splitItem.branch_name,
						expense_category_id: splitItem.expense_category_id,
						expense_category_name_en: splitItem.expense_category_name_en,
						expense_category_name_ar: splitItem.expense_category_name_ar,
						requisition_id: splitItem.requisition_id,
						requisition_number: splitItem.requisition_number ? splitItem.requisition_number + '-SPLIT' : null,
						co_user_id: splitItem.co_user_id,
						co_user_name: splitItem.co_user_name,
						bill_type: splitItem.bill_type,
						payment_method: splitItem.payment_method,
						due_date: newDueDate,
						amount: splitAmount,
						description: (splitItem.description || '') + ' [Split from original schedule]',
						schedule_type: splitItem.schedule_type,
						status: splitItem.status,
						is_paid: false,
						approver_id: splitItem.approver_id,
						approver_name: splitItem.approver_name,
						created_by: $currentUser?.id
					});

				if (insertError) throw insertError;

				// Update original expense with remaining amount
				const { error: updateError } = await supabaseAdmin
					.from('expense_scheduler')
					.update({ 
						amount: remainingAmount,
						description: (splitItem.description || '') + ' [Original amount after split]'
					})
					.eq('id', splitItem.id);

				if (updateError) throw updateError;
			}

			alert(`✅ Payment split successfully!\n\n✅ Created new payment: ${formatCurrency(splitAmount)} on ${new Date(newDueDate).toLocaleDateString()}\n✅ Updated original payment: ${formatCurrency(remainingAmount)}`);
			closeSplitModal();
			await loadScheduledItems(); // Reload to update the display
		} catch (error) {
			console.error('Error splitting payment:', error);
			alert('❌ Error splitting payment: ' + error.message);
		} finally {
			isLoading = false;
		}
	}

	function formatCurrency(amount) {
		return new Intl.NumberFormat('en-US', {
			style: 'currency',
			currency: 'SAR',
			minimumFractionDigits: 2
		}).format(amount || 0);
	}

	function formatDate(dateString) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}
</script>

<div class="budget-planner">
	<!-- Combined Date Selection and Budget Summary Section -->
	<div class="unified-controls-section">
		<!-- Date Selection Card -->
		<div class="control-card">
			<div class="date-selector">
				<label for="selectedDate">📅 Select Date:</label>
				<input 
					id="selectedDate"
					type="date" 
					bind:value={selectedDate}
					on:change={onDateChange}
					class="date-input"
				/>
			</div>

			<div class="budget-input">
				<label for="dailyBudget">💰 Daily Budget (SAR):</label>
				<div class="budget-input-group">
					<input 
						id="dailyBudget"
						type="number" 
						bind:value={calculatedTotalBudget}
						step="0.01"
						min="0"
						placeholder="0.00"
						class="budget-amount"
						readonly
						title="This is calculated from payment method budgets below"
					/>
					<span class="calculated-label">Auto-calculated</span>
				</div>
			</div>
		</div>

		<!-- Budget Summary Card -->
		<div class="control-card budget-summary-card" class:over-budget={budgetStatus === 'over'} class:exact-budget={budgetStatus === 'exact'}>
			<div class="unified-budget-card">
				<!-- Left Side: Total Summary -->
				<div class="budget-summary-side">
					<div class="card-header">
						<h3>📊 Total Budget Summary</h3>
					</div>
					<div class="card-content">
					<div class="summary-item">
						<span class="label">Daily Budget:</span>
						<span class="value">{formatCurrency(calculatedTotalBudget)}</span>
					</div>
					<div class="summary-item">
						<span class="label">Total Scheduled (Selected):</span>
						<span class="value">{formatCurrency(totalScheduled)}</span>
						<span class="count-info">
							({selectedVendorPayments.size + selectedExpenseSchedules.size + selectedNonApprovedPayments.size} items selected)
						</span>
					</div>
					<div class="summary-item remaining">
						<span class="label">Remaining:</span>
						<span class="value" class:negative={remainingBudget < 0}>
							{formatCurrency(remainingBudget)}
						</span>
					</div>
					<div class="budget-status-indicator">
						{#if budgetStatus === 'over'}
							{@const totalOverBudget = remainingBudget < 0}
							
							⚠️ Over Budget
							{#if totalOverBudget}
								<div class="over-budget-detail">Total: {formatCurrency(Math.abs(remainingBudget))} over daily budget</div>
							{/if}
							
							{#if breakdown && breakdown.allPaymentMethods}
								{#each Array.from(breakdown.allPaymentMethods) as method}
									{@const methodBudget = paymentMethodBudgets[method] || 0}
									{@const methodUsed = breakdown.byPaymentMethod.get(method) || 0}
									{#if methodBudget > 0 && methodUsed > methodBudget}
										<div class="over-budget-detail">
											{method}: {formatCurrency(methodUsed - methodBudget)} over budget
										</div>
									{/if}
								{/each}
							{/if}
						{:else if budgetStatus === 'exact'}
							✅ Exact Budget Match
						{:else}
							✅ Within Budget
						{/if}
					</div>
				</div>
			</div>

			<!-- Right Side: Detailed Breakdown -->
			<div class="budget-breakdown-side">
				<div class="card-header">
					<h3>📋 Detailed Breakdown</h3>
				</div>
				<div class="card-content">
					<!-- By Payment Method Table -->
					{#if breakdown.allPaymentMethods.size > 0}
						<div class="breakdown-section">
							<h4>By Payment Method</h4>
							<div class="breakdown-table-container">
								<table class="breakdown-table">
									<thead>
										<tr>
											<th>Payment Method</th>
											<th>Budget</th>
											<th>Selected Total</th>
											<th>Remaining</th>
										</tr>
									</thead>
									<tbody>
										{#each Array.from(breakdown.allPaymentMethods) as method}
											{@const amount = breakdown.byPaymentMethod.get(method) || 0}
											{@const budgetForMethod = paymentMethodBudgets[method] || 0}
											{@const remaining = budgetForMethod - amount}
											<tr class:over-budget-row={budgetForMethod > 0 && amount > budgetForMethod}>
												<td class="method-name-cell">
													<span class="method-name">{method}</span>
												</td>
												<td class="budget-cell">
													<input 
														type="number"
														bind:value={paymentMethodBudgets[method]}
														step="0.01"
														min="0"
														placeholder="0.00"
														class="budget-input-inline"
													/>
												</td>
												<td class="selected-cell">
													<span class="selected-amount" class:over-budget={budgetForMethod > 0 && amount > budgetForMethod}>
														{formatCurrency(amount)}
													</span>
												</td>
												<td class="remaining-cell">
													{#if budgetForMethod > 0}
														<span class="remaining-amount" class:negative={remaining < 0}>
															{formatCurrency(remaining)}
														</span>
													{:else}
														<span class="no-limit-text">∞</span>
													{/if}
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
						</div>
					{:else}
						<div class="no-breakdown">
							<p>Loading payment methods...</p>
						</div>
					{/if}
				</div>
			</div>
		</div>
	</div>
	</div>

	{#if isLoading}
		<div class="loading">
			<div class="spinner"></div>
			<p>Loading scheduled items...</p>
		</div>
	{:else}
		<!-- Vendor Payments - Separate Scrollable Container -->
		<div class="table-section">
			<div class="section-header">
				<div class="section-header-content">
					<h3>💰 Vendor Payments Due ({filteredVendorPayments.length}{filteredVendorPayments.length !== vendorPayments.length ? ` of ${vendorPayments.length}` : ''})</h3>
					<div class="header-actions">
						<button 
							class="select-all-btn"
							on:click={selectAllVendorPayments}
							disabled={vendorPayments.length === 0}
						>
							Select All
						</button>
						<button 
							class="clear-all-btn"
							on:click={clearAllSelections}
							disabled={selectedVendorPayments.size === 0}
						>
							Clear All
						</button>
					</div>
				</div>
				<div class="filter-section">
					<div class="filter-group">
						<label for="vendor-filter">Filter by Vendor:</label>
						<input 
							id="vendor-filter"
							type="text" 
							bind:value={vendorFilter} 
							placeholder="Enter vendor name..."
							class="header-filter-input"
						/>
					</div>
					<div class="filter-group">
						<label for="vendor-branch-filter">Filter by Branch:</label>
						<select 
							id="vendor-branch-filter"
							bind:value={branchFilter}
							class="header-filter-input"
						>
							<option value="">All Branches</option>
							{#each uniqueVendorBranches as branch}
								<option value={branch}>{branch}</option>
							{/each}
						</select>
					</div>
					<div class="filter-group">
						<label for="vendor-payment-method-filter">Filter by Payment Method:</label>
						<select 
							id="vendor-payment-method-filter"
							bind:value={paymentMethodFilter}
							class="header-filter-input"
						>
							<option value="">All Payment Methods</option>
							{#each uniqueVendorPaymentMethods as method}
								<option value={method}>{method}</option>
							{/each}
						</select>
					</div>
					{#if vendorFilter || branchFilter || paymentMethodFilter}
						<button 
							class="clear-filters-btn"
							on:click={() => {vendorFilter = ''; branchFilter = ''; paymentMethodFilter = '';}}
						>
							Clear Filters
						</button>
					{/if}
				</div>
			</div>
			<div class="individual-table-container vendor-payment-table">
				<div class="data-section">
					{#if vendorPayments.length > 0}
						{#if filteredVendorPayments.length > 0}
						<!-- Fixed Header Table -->
						<div class="table-header-wrapper">
							<table class="header-table vendor-header-table">
								<thead>
									<tr>
										<th class="checkbox-column vendor-select">Select</th>
										<th class="vendor-bill-number">Bill Number</th>
										<th class="vendor-name">Vendor</th>
										<th class="vendor-branch">Branch</th>
										<th class="vendor-amount">Amount</th>
										<th class="vendor-adjust-amount">Adjust Amount</th>
										<th class="vendor-payment-method">Payment Method</th>
										<th class="vendor-approval-status">Approval Status</th>
										<th class="vendor-actions">Actions</th>
									</tr>
								</thead>
							</table>
						</div>
						<!-- Scrollable Body Table -->
						<div class="table-body-wrapper">
							<table class="body-table vendor-body-table">
								<tbody>
									{#each filteredVendorPayments as payment}
										{@const adjustAmount = adjustAmounts[`vendor_${payment.id}`] || ''}
										{@const hasAdjustAmount = adjustAmount && parseFloat(adjustAmount) > 0}
										<tr>
											<td class="checkbox-column vendor-select">
												<input 
													type="checkbox" 
													checked={selectedVendorPayments.has(payment.id)}
													on:change={() => toggleVendorPayment(payment.id)}
												/>
											</td>
											<td class="bill-number vendor-bill-number">{payment.bill_number}</td>
											<td class="vendor-name">{payment.vendor_name}</td>
											<td class="vendor-branch">{payment.branch_name}</td>
											<td class="amount vendor-amount">{formatCurrency(payment.final_bill_amount || payment.bill_amount)}</td>
											<td class="adjust-amount-cell vendor-adjust-amount">
												<input 
													type="number"
													bind:value={adjustAmounts[`vendor_${payment.id}`]}
													step="0.01"
													min="0"
													placeholder="Enter amount"
													class="adjust-amount-input"
												/>
											</td>
											<td class="payment-method vendor-payment-method">{payment.payment_method}</td>
											<td class="vendor-approval-status">
												<span class="status-badge" class:approved={payment.approval_status === 'approved'} class:pending={payment.approval_status === 'pending'}>
													{#if payment.approval_status === 'approved'}
														✅ Approved
													{:else if payment.approval_status === 'pending'}
														⏳ Pending
													{:else if payment.approval_status === 'sent_for_approval'}
														📤 Sent for Approval
													{:else if payment.approval_status === 'rejected'}
														❌ Rejected
													{:else}
														❓ {payment.approval_status}
													{/if}
												</span>
											</td>
											<td class="vendor-actions">
												<div class="action-buttons">
													<button 
														class="reschedule-btn"
														on:click={() => openRescheduleModal(payment, 'vendor')}
													>
														📅 Reschedule
													</button>
													{#if hasAdjustAmount}
														<button 
															class="split-btn"
															on:click={() => openSplitModal(payment, 'vendor')}
														>
															✂️ Split
														</button>
													{/if}
												</div>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
						{:else}
							<div class="no-data">
								<p>No vendor payments match the current filters</p>
								<button class="clear-filters-btn" on:click={() => {vendorFilter = ''; branchFilter = ''; paymentMethodFilter = '';}}>
									Clear Filters
								</button>
							</div>
						{/if}
			{:else}
				<div class="no-data">
					<p>No vendor payments scheduled for {formatDate(selectedDate)}</p>
				</div>
			{/if}
				</div>
			</div>
		</div>

		<!-- Expense Schedules - Separate Scrollable Container -->
		<div class="table-section">
			<div class="section-header">
				<div class="section-header-content">
					<h3>📋 Expense Schedules Due ({filteredExpenseSchedules.length}{filteredExpenseSchedules.length !== expenseSchedules.length ? ` of ${expenseSchedules.length}` : ''})</h3>
					<div class="header-actions">
						<button 
							class="select-all-btn"
							on:click={selectAllExpenseSchedules}
							disabled={expenseSchedules.length === 0}
						>
							Select All
						</button>
						<button 
							class="clear-all-btn"
							on:click={() => {
								selectedExpenseSchedules.clear();
								selectedExpenseSchedules = selectedExpenseSchedules;
								calculateBudget();
							}}
							disabled={selectedExpenseSchedules.size === 0}
						>
							Clear All
						</button>
					</div>
				</div>
				<div class="filter-section">
					<div class="filter-group">
						<label for="expense-description-filter">Filter by Description:</label>
						<input 
							id="expense-description-filter"
							type="text" 
							bind:value={expenseDescriptionFilter} 
							placeholder="Enter description..."
							class="header-filter-input"
						/>
					</div>
					<div class="filter-group">
						<label for="expense-category-filter">Filter by Category:</label>
						<input 
							id="expense-category-filter"
							type="text" 
							bind:value={expenseCategoryFilter} 
							placeholder="Enter category..."
							class="header-filter-input"
						/>
					</div>
					<div class="filter-group">
						<label for="expense-branch-filter">Filter by Branch:</label>
						<select 
							id="expense-branch-filter"
							bind:value={expenseBranchFilter}
							class="header-filter-input"
						>
							<option value="">All Branches</option>
							{#each uniqueExpenseBranches as branch}
								<option value={branch}>{branch}</option>
							{/each}
						</select>
					</div>
					<div class="filter-group">
						<label for="expense-payment-method-filter">Filter by Payment Method:</label>
						<select 
							id="expense-payment-method-filter"
							bind:value={expensePaymentMethodFilter}
							class="header-filter-input"
						>
							<option value="">All Payment Methods</option>
							{#each uniqueExpensePaymentMethods as method}
								<option value={method}>{method}</option>
							{/each}
						</select>
					</div>
					{#if expenseDescriptionFilter || expenseCategoryFilter || expenseBranchFilter || expensePaymentMethodFilter}
						<button 
							class="clear-filters-btn"
							on:click={() => {expenseDescriptionFilter = ''; expenseCategoryFilter = ''; expenseBranchFilter = ''; expensePaymentMethodFilter = '';}}
						>
							Clear Filters
						</button>
					{/if}
				</div>
			</div>
			<div class="individual-table-container">
				<div class="data-section">
					{#if expenseSchedules.length > 0}
						<!-- Fixed Header Table -->
						<div class="table-header-wrapper">
							<table class="header-table">
								<thead>
									<tr>
										<th class="checkbox-column">Select</th>
										<th>Description</th>
										<th>Category</th>
										<th>Branch</th>
										<th>Amount</th>
										<th>Adjust Amount</th>
										<th>Payment Method</th>
										<th>Type</th>
										<th>Actions</th>
									</tr>
								</thead>
							</table>
						</div>
						<!-- Scrollable Body Table -->
						<div class="table-body-wrapper">
							<table class="body-table">
								<tbody>
									{#each filteredExpenseSchedules as expense}
										{@const adjustAmount = adjustAmounts[`expense_${expense.id}`] || ''}
										{@const hasAdjustAmount = adjustAmount && parseFloat(adjustAmount) > 0}
										<tr>
											<td class="checkbox-column">
												<input 
													type="checkbox" 
													checked={selectedExpenseSchedules.has(expense.id)}
													on:change={() => toggleExpenseSchedule(expense.id)}
												/>
											</td>
											<td class="description">{expense.description}</td>
											<td>{expense.expense_category_name_en || 'N/A'}</td>
											<td>{expense.branch_name}</td>
											<td class="amount">{formatCurrency(expense.amount)}</td>
											<td class="adjust-amount-cell">
												<input 
													type="number"
													bind:value={adjustAmounts[`expense_${expense.id}`]}
													step="0.01"
													min="0"
													placeholder="Enter amount"
													class="adjust-amount-input"
												/>
											</td>
											<td class="payment-method">{expense.payment_method}</td>
											<td>
												<span class="type-badge">{expense.schedule_type}</span>
											</td>
											<td>
												<div class="action-buttons">
													<button 
														class="reschedule-btn"
														on:click={() => openRescheduleModal(expense, 'expense')}
													>
														📅 Reschedule
													</button>
													{#if hasAdjustAmount}
														<button 
															class="split-btn"
															on:click={() => openSplitModal(expense, 'expense')}
														>
															✂️ Split
														</button>
													{/if}
												</div>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
			{:else}
				<div class="no-data">
					<p>No expense schedules due for {formatDate(selectedDate)}</p>
				</div>
			{/if}
				</div>
			</div>
		</div>

		<!-- Non-Approved Vendor Payments - Separate Scrollable Container -->
		{#if nonApprovedPayments.length > 0}
			<div class="table-section">
				<div class="section-header">
					<div class="section-header-content">
						<div class="section-title-group">
							<h3>⏳ Non-Approved Vendor Payments ({nonApprovedPayments.length})</h3>
							<p class="section-description">These payments are awaiting approval and may affect your budget if approved.</p>
						</div>
						<div class="header-actions">
							<button 
								class="select-all-btn"
								on:click={() => {
									nonApprovedPayments.forEach(payment => selectedNonApprovedPayments.add(payment.id));
									selectedNonApprovedPayments = selectedNonApprovedPayments;
									calculateBudget();
								}}
								disabled={nonApprovedPayments.length === 0}
							>
								Select All
							</button>
							<button 
								class="clear-all-btn"
								on:click={() => {
									selectedNonApprovedPayments.clear();
									selectedNonApprovedPayments = selectedNonApprovedPayments;
									calculateBudget();
								}}
								disabled={selectedNonApprovedPayments.size === 0}
							>
								Clear All
							</button>
						</div>
					</div>
				</div>
				<div class="individual-table-container">
					<div class="data-section non-approved">
						<!-- Fixed Header Table -->
						<div class="table-header-wrapper">
							<table class="header-table">
								<thead>
									<tr>
										<th class="checkbox-column">Select</th>
										<th>Vendor</th>
										<th>Amount</th>
										<th>Adjust Amount</th>
										<th>Status</th>
									</tr>
								</thead>
							</table>
						</div>
						<!-- Scrollable Body Table -->
						<div class="table-body-wrapper">
							<table class="body-table simplified">
								<tbody>
									{#each nonApprovedPayments as payment}
										{@const adjustAmount = adjustAmounts[`non_approved_${payment.id}`] || ''}
										<tr class="non-approved-row">
											<td class="checkbox-column">
												<input 
													type="checkbox" 
													checked={selectedNonApprovedPayments.has(payment.id)}
													on:change={() => toggleNonApprovedPayment(payment.id)}
													title="Include in budget calculation"
												/>
											</td>
											<td class="vendor-name">{payment.vendor_name}</td>
											<td class="amount">{formatCurrency(payment.final_bill_amount || payment.bill_amount)}</td>
											<td class="adjust-amount-cell">
												<input 
													type="number"
													bind:value={adjustAmounts[`non_approved_${payment.id}`]}
													step="0.01"
													min="0"
													placeholder="Enter amount"
													class="adjust-amount-input"
												/>
											</td>
											<td>
												<span class="status-badge not-approved">Not Approved</span>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					</div>
				</div>
			</div>
		{/if}
	{/if}
</div>

<!-- Budget Settings Modal -->
{#if showBudgetModal}
	<div class="modal-overlay" on:click={closeBudgetModal}>
		<div class="modal-content budget-modal" on:click|stopPropagation>
			<div class="modal-header">
				<h3>⚙️ Budget Settings</h3>
				<button class="close-btn" on:click={closeBudgetModal}>✕</button>
			</div>

			<div class="modal-body">
				<div class="budget-settings">
					<!-- Total Budget Limit -->
					<div class="setting-group">
						<label for="totalBudgetLimit">💰 Total Daily Budget Limit (SAR):</label>
						<div class="total-budget-display">
							<input 
								id="totalBudgetLimit"
								type="number" 
								bind:value={totalBudgetLimit}
								step="0.01"
								min="0"
								placeholder="0.00"
								class="budget-input-field"
							/>
							{#if calculatedTotalBudget > 0}
								<div class="calculated-total">
									<span class="calc-label">Calculated from payment methods:</span>
									<span class="calc-amount">{formatCurrency(calculatedTotalBudget)}</span>
									<button 
										type="button" 
										class="use-calculated-btn"
										on:click={() => totalBudgetLimit = calculatedTotalBudget}
									>
										Use This Total
									</button>
								</div>
							{/if}
						</div>
					</div>

					<!-- Payment Method Budgets -->
					<div class="setting-group">
						<h4>� Payment Method Budgets</h4>
						{#each Array.from(breakdown.allPaymentMethods) as method}
							{@const currentAmount = breakdown.byPaymentMethod.get(method) || 0}
							<div class="payment-method-budget-row">
								<div class="method-label">
									<label>{method}:</label>
									{#if currentAmount > 0}
										<span class="current-amount">Current: {formatCurrency(currentAmount)}</span>
									{/if}
								</div>
								<input 
									type="number" 
									bind:value={paymentMethodBudgets[method]}
									step="0.01"
									min="0"
									placeholder="No limit"
									class="budget-input-field small"
								/>
							</div>
						{/each}
						{#if breakdown.allPaymentMethods.size === 0}
							<p class="no-methods">
								{#if vendorPayments.length === 0 && expenseSchedules.length === 0 && nonApprovedPayments.length === 0}
									No scheduled items loaded yet. Please select a date and wait for data to load.
								{:else}
									Payment methods found: {vendorPayments.length} vendor payments, {expenseSchedules.length} expense schedules. 
									Check console for details.
								{/if}
							</p>
						{/if}
					</div>
				</div>
			</div>

			<div class="modal-footer">
				<button class="cancel-btn" on:click={closeBudgetModal}>Cancel</button>
				<button class="save-btn" on:click={saveBudgets}>💾 Save Budget Settings</button>
			</div>
		</div>
	</div>
{/if}

<!-- Reschedule Modal -->
{#if showRescheduleModal}
	<div class="modal-overlay" on:click={closeRescheduleModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>📅 Reschedule {rescheduleType === 'vendor' ? 'Vendor Payment' : 'Expense Schedule'}</h3>
				<button class="close-btn" on:click={closeRescheduleModal}>✕</button>
			</div>

			<div class="modal-body">
				<div class="item-info">
					<p><strong>Item:</strong> 
						{#if rescheduleType === 'vendor'}
							{rescheduleItem.bill_number} - {rescheduleItem.vendor_name}
						{:else}
							{rescheduleItem.description}
						{/if}
					</p>
					<p><strong>Current Due Date:</strong> {formatDate(rescheduleItem.due_date)}</p>
					<p><strong>Amount:</strong> 
						{#if rescheduleType === 'vendor'}
							{formatCurrency(rescheduleItem.final_bill_amount || rescheduleItem.bill_amount)}
						{:else}
							{formatCurrency(rescheduleItem.amount)}
						{/if}
					</p>
				</div>

				<div class="reschedule-form">
					<label for="newDueDate">New Due Date:</label>
					<input 
						id="newDueDate"
						type="date" 
						bind:value={newDueDate}
						class="date-input"
						min={new Date().toISOString().split('T')[0]}
					/>
				</div>
			</div>

			<div class="modal-actions">
				<button class="cancel-btn" on:click={closeRescheduleModal}>Cancel</button>
				<button 
					class="confirm-btn" 
					on:click={executeReschedule}
					disabled={!newDueDate || newDueDate === rescheduleItem.due_date}
				>
					Confirm Reschedule
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Split Modal -->
{#if showSplitModal && splitItem}
	<div class="modal-overlay" on:click={closeSplitModal}>
		<div class="modal-content split-modal" on:click|stopPropagation>
			<div class="modal-header">
				<h3>✂️ Split & Reschedule {splitType === 'vendor' ? 'Vendor Payment' : 'Expense Schedule'}</h3>
				<button class="close-btn" on:click={closeSplitModal}>✕</button>
			</div>

			<div class="modal-body">
				<div class="split-info">
					<h4>📋 Item Information</h4>
					<div class="info-grid">
						<div class="info-item">
							<span class="label">Item:</span>
							<span class="value">
								{#if splitType === 'vendor'}
									{splitItem.bill_number} - {splitItem.vendor_name}
								{:else}
									{splitItem.description}
								{/if}
							</span>
						</div>
						<div class="info-item">
							<span class="label">Current Due Date:</span>
							<span class="value">{formatDate(splitItem.due_date)}</span>
						</div>
						<div class="info-item">
							<span class="label">Total Amount:</span>
							<span class="value total-amount">
								{#if splitType === 'vendor'}
									{formatCurrency(splitItem.final_bill_amount || splitItem.bill_amount)}
								{:else}
									{formatCurrency(splitItem.amount)}
								{/if}
							</span>
						</div>
					</div>
				</div>

				<div class="split-details">
					<h4>✂️ Split Configuration</h4>
					
					<div class="split-form">
						<div class="form-group">
							<label for="splitAmount">Amount to Move to New Date:</label>
							<input 
								id="splitAmount"
								type="number" 
								bind:value={splitAmount}
								step="0.01"
								min="0.01"
								max={splitType === 'vendor' ? (splitItem.final_bill_amount || splitItem.bill_amount) - 0.01 : splitItem.amount - 0.01}
								class="amount-input"
								on:input={() => {
									// Calculate remaining amount based on original total amount
									const originalAmount = splitType === 'vendor' 
										? (splitItem.final_bill_amount || splitItem.bill_amount || 0)
										: (splitItem.amount || 0);
									
									remainingAmount = originalAmount - splitAmount;
								}}
							/>
						</div>

						<div class="form-group">
							<label for="newSplitDate">New Due Date for Split Amount:</label>
							<input 
								id="newSplitDate"
								type="date" 
								bind:value={newDueDate}
								class="date-input"
								min={new Date().toISOString().split('T')[0]}
							/>
						</div>
					</div>

					<div class="split-summary">
						<div class="summary-row">
							<span class="summary-label">Amount moving to {newDueDate ? formatDate(newDueDate) : 'new date'}:</span>
							<span class="summary-value split-amount">{formatCurrency(splitAmount)}</span>
						</div>
						<div class="summary-row">
							<span class="summary-label">Amount remaining on {formatDate(splitItem.due_date)}:</span>
							<span class="summary-value remaining-amount">{formatCurrency(remainingAmount)}</span>
						</div>
					</div>
				</div>
			</div>

			<div class="modal-actions">
				<button class="cancel-btn" on:click={closeSplitModal}>Cancel</button>
				<button 
					class="confirm-btn split-confirm" 
					on:click={executeSplit}
					disabled={!newDueDate || splitAmount <= 0 || splitAmount >= (splitType === 'vendor' ? (splitItem.final_bill_amount || splitItem.bill_amount) : splitItem.amount)}
				>
					✂️ Split & Reschedule
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.budget-planner {
		padding: 2rem;
		background: #f8fafc;
		min-height: 100vh;
		font-size: 1.125rem; /* Increased base font size from default 1rem to 1.125rem */
	}

	/* Unified Controls Section */
	.unified-controls-section {
		position: sticky;
		top: 0;
		z-index: 1000;
		background: white;
		margin-bottom: 24px;
		display: flex;
		gap: 20px;
		padding: 20px;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.control-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 16px;
		flex: 1;
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
	}

	.budget-summary-card {
		flex: 2;
	}

	.budget-summary-card.over-budget {
		border-color: #ef4444;
		background: #fef2f2;
	}

	.budget-summary-card.exact-budget {
		border-color: #10b981;
		background: #f0fdf4;
	}

	/* Budget Controls */
	.budget-controls {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 2rem;
		margin-bottom: 2rem;
		background: white;
		padding: 2rem;
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		position: sticky;
		top: 0;
		z-index: 200;
	}

	.date-selector, .budget-input {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.budget-input-group {
		display: flex;
		gap: 10px;
		align-items: center;
	}

	.budget-settings-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 8px 12px;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
		transition: background-color 0.2s;
		white-space: nowrap;
	}

	.budget-settings-btn:hover {
		background: #2563eb;
	}

	.date-selector label, .budget-input label {
		font-weight: 600;
		color: #374151;
		font-size: 1.25rem; /* Increased from 1rem to 1.25rem */
	}

	.date-input, .budget-amount {
		padding: 0.75rem 1rem;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 1.125rem; /* Increased from 1rem to 1.125rem */
		transition: border-color 0.2s;
	}

	.date-input:focus, .budget-amount:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.budget-amount {
		font-size: 1.5rem; /* Increased from 1.25rem to 1.5rem */
		font-weight: 600;
		text-align: right;
	}

	/* Budget Summary */
	.budget-summary {
		background: white;
		padding: 2rem;
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		margin-bottom: 2rem;
		border-left: 4px solid #10b981;
	}

	.budget-summary.over-budget {
		border-left-color: #ef4444;
		background: #fef2f2;
	}

	.budget-summary.exact-budget {
		border-left-color: #f59e0b;
		background: #fffbeb;
	}

	.summary-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem 0;
		border-bottom: 1px solid #f3f4f6;
	}

	.summary-item:last-of-type {
		border-bottom: none;
	}

	.summary-item.remaining {
		font-weight: 600;
		font-size: 1.1rem;
	}

	.summary-item .label {
		color: #6b7280;
	}

	.summary-item .value {
		font-weight: 600;
		color: #1f2937;
		font-size: 1.1rem;
	}

	.summary-item .value.negative {
		color: #ef4444;
	}

	.budget-status-indicator {
		margin-top: 1rem;
		padding: 1rem;
		text-align: center;
		border-radius: 8px;
		font-weight: 600;
		background: #f0fdf4;
		color: #166534;
		border: 1px solid #bbf7d0;
	}

	.over-budget-detail {
		font-size: 0.875rem;
		font-weight: 500;
		margin-top: 0.5rem;
		color: #dc2626;
		text-align: left;
		background: #fef2f2;
		padding: 0.5rem;
		border-radius: 4px;
		border: 1px solid #fecaca;
	}

	.count-info {
		font-size: 0.875rem;
		color: #6b7280;
		font-weight: normal;
		margin-left: 0.5rem;
	}

	/* Unified Budget Section */
	.unified-budget-section {
		margin: 20px 0;
		position: sticky;
		top: 120px;
		z-index: 100;
		background: #f8fafc;
		padding: 10px;
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.unified-budget-card {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 20px;
		background: white;
		border-radius: 12px;
		border: 1px solid #e5e7eb;
		overflow: hidden;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.unified-budget-card.over-budget {
		border-color: #ef4444;
		background: #fef2f2;
	}

	.unified-budget-card.exact-budget {
		border-color: #10b981;
		background: #f0fdf4;
	}

	.budget-summary-side,
	.budget-breakdown-side {
		display: flex;
		flex-direction: column;
	}

	.budget-summary-side {
		border-right: 1px solid #e5e7eb;
	}

	.unified-budget-card {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0;
		background: white;
		height: 100%;
	}

	.budget-summary-side,
	.budget-breakdown-side {
		padding: 20px;
	}

	.budget-breakdown-side {
		border-left: 1px solid #e5e7eb;
	}

	.card-header {
		background: #f8fafc;
		padding: 16px 20px;
		border-bottom: 1px solid #e5e7eb;
	}

	.card-header h3 {
		margin: 0;
		font-size: 1.375rem; /* Increased from 1.125rem to 1.375rem */
		font-weight: 600;
		color: #374151;
	}

	.card-content {
		padding: 20px;
	}

	.total-card .summary-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px 0;
		border-bottom: 1px solid #f3f4f6;
	}

	.total-card .summary-item:last-child {
		border-bottom: none;
	}

	.total-card .summary-item.remaining {
		font-weight: 600;
		font-size: 1.125rem;
	}

	.breakdown-section {
		margin-bottom: 24px;
	}

	.breakdown-section:last-child {
		margin-bottom: 0;
	}

	.breakdown-section h4 {
		margin: 0 0 12px 0;
		font-size: 1rem;
		font-weight: 600;
		color: #374151;
		padding-bottom: 8px;
		border-bottom: 1px solid #e5e7eb;
	}

	/* Breakdown table styles */
	.breakdown-table-container {
		overflow-x: auto;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
		background: white;
	}

	.breakdown-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.875rem;
	}

	.breakdown-table thead tr {
		background-color: #f9fafb;
		border-bottom: 2px solid #e5e7eb;
	}

	.breakdown-table th {
		padding: 12px 8px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		font-size: 0.75rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.breakdown-table tbody tr {
		border-bottom: 1px solid #f3f4f6;
		transition: background-color 0.2s ease;
	}

	.breakdown-table tbody tr:hover {
		background-color: #f9fafb;
	}

	.breakdown-table tbody tr.over-budget-row {
		background-color: #fef2f2;
		border-color: #fecaca;
	}

	.breakdown-table tbody tr.over-budget-row:hover {
		background-color: #fee2e2;
	}

	.breakdown-table td {
		padding: 12px 8px;
		vertical-align: middle;
	}

	.method-name-cell {
		font-weight: 500;
		color: #1f2937;
	}

	.budget-cell {
		color: #6b7280;
	}

	.selected-cell .selected-amount {
		font-weight: 600;
		color: #1f2937;
	}

	.selected-cell .over-budget {
		color: #dc2626;
		font-weight: 700;
	}

	.remaining-cell .remaining-amount {
		font-weight: 500;
		color: #059669;
	}

	.remaining-cell .negative {
		color: #dc2626;
		font-weight: 600;
	}

	.remaining-cell .no-limit-text {
		color: #6b7280;
		font-size: 1.2em;
	}

	.budget-input-inline {
		width: 100%;
		padding: 6px 8px;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		font-size: 0.875rem;
		background-color: white;
		transition: border-color 0.2s ease;
	}

	.budget-input-inline:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 1px #3b82f6;
	}

	.budget-input-inline:hover {
		border-color: #9ca3af;
	}

	.adjust-amount-input {
		width: 100%;
		padding: 6px 8px;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		font-size: 0.875rem;
		background-color: white;
		transition: border-color 0.2s ease;
		text-align: right;
	}

	.adjust-amount-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 1px #3b82f6;
	}

	.adjust-amount-input:hover {
		border-color: #9ca3af;
	}

	.adjust-amount-cell {
		padding: 8px !important;
	}

	.filter-input {
		width: 100%;
		padding: 4px 6px;
		margin-top: 4px;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		font-size: 0.75rem;
		background-color: white;
		transition: border-color 0.2s ease;
	}

	.filter-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 1px #3b82f6;
	}

	.filter-input::placeholder {
		color: #9ca3af;
		font-size: 0.7rem;
	}

	.clear-filters-btn {
		background: #3b82f6;
		color: white;
		padding: 8px 16px;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.875rem;
		margin-top: 8px;
		transition: background-color 0.2s ease;
	}

	.clear-filters-btn:hover {
		background: #2563eb;
	}

	.filter-section {
		display: flex;
		gap: 1rem;
		padding: 1rem;
		background-color: #f8fafc;
		border-top: 1px solid #e5e7eb;
		border-radius: 0 0 8px 8px;
		margin-bottom: 1rem;
		flex-wrap: wrap;
		align-items: end;
	}

	.filter-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		min-width: 180px;
	}

	.filter-group label {
		font-size: 0.75rem;
		font-weight: 600;
		color: #374151;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.header-filter-input {
		padding: 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		font-size: 1rem; /* Increased from 0.875rem to 1rem */
		background-color: white;
		transition: border-color 0.2s ease;
	}

	.header-filter-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 1px #3b82f6;
	}

	.header-filter-input::placeholder {
		color: #9ca3af;
	}

	select.header-filter-input {
		cursor: pointer;
		background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3e%3cpath stroke='%236b7280' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='m6 8 4 4 4-4'/%3e%3c/svg%3e");
		background-position: right 0.5rem center;
		background-repeat: no-repeat;
		background-size: 1rem;
		padding-right: 2.5rem;
		appearance: none;
		-webkit-appearance: none;
		-moz-appearance: none;
	}

	.calculated-label {
		padding: 8px 12px;
		background-color: #f3f4f6;
		color: #6b7280;
		font-size: 0.75rem;
		border-radius: 4px;
		font-weight: 500;
	}

	.adjust-amount-cell {
		padding: 4px;
	}

	.adjust-amount-input {
		width: 100%;
		padding: 6px 8px;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		font-size: 0.875rem;
		background-color: white;
		transition: border-color 0.2s ease;
	}

	.adjust-amount-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 1px #3b82f6;
	}

	.adjust-amount-input:hover {
		border-color: #9ca3af;
	}

	.adjust-amount-input::placeholder {
		color: #9ca3af;
		font-size: 0.75rem;
	}

	.breakdown-item {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		padding: 12px 0;
		border-bottom: 1px solid #f9fafb;
	}

	.breakdown-item:last-child {
		border-bottom: none;
	}

	.method-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.method-name {
		font-weight: 600;
		color: #374151;
		font-size: 0.95rem;
	}

	.budget-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.budget-label {
		font-size: 0.75rem;
		color: #6b7280;
		font-weight: 500;
	}

	.remaining-label {
		font-size: 0.75rem;
		color: #059669;
		font-weight: 500;
	}

	.remaining-label.over {
		color: #dc2626;
	}

	.method-amount {
		font-weight: 600;
		color: #059669;
		font-size: 1rem;
	}

	.method-amount.over-budget {
		color: #dc2626;
	}

	.category-name, .vendor-name {
		font-weight: 500;
		color: #374151;
	}

	.category-amount, .vendor-amount {
		font-weight: 600;
		color: #059669;
	}

	.no-breakdown {
		text-align: center;
		color: #6b7280;
		font-style: italic;
		padding: 40px 0;
	}

	/* Budget Modal Styles */
	.budget-modal {
		max-width: 600px;
		max-height: 80vh;
		overflow-y: auto;
	}

	.budget-settings {
		display: flex;
		flex-direction: column;
		gap: 24px;
	}

	.setting-group {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.setting-group h4 {
		margin: 0;
		font-size: 1rem;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		padding-bottom: 8px;
	}

	.category-budget-row, .vendor-budget-row, .payment-method-budget-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 12px;
		padding: 8px 0;
	}

	.category-budget-row label, .vendor-budget-row label {
		flex: 1;
		font-weight: 500;
		color: #374151;
	}

	.method-label {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.method-label label {
		font-weight: 500;
		color: #374151;
	}

	.current-amount {
		font-size: 0.75rem;
		color: #6b7280;
		font-weight: 400;
	}

	.total-budget-display {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.calculated-total {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 12px;
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		border-radius: 6px;
		font-size: 0.875rem;
	}

	.calc-label {
		color: #166534;
		font-weight: 500;
	}

	.calc-amount {
		color: #059669;
		font-weight: 600;
	}

	.use-calculated-btn {
		background: #059669;
		color: white;
		border: none;
		padding: 4px 8px;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.75rem;
		font-weight: 500;
		transition: background-color 0.2s;
	}

	.use-calculated-btn:hover {
		background: #047857;
	}

	.budget-input-field {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 0.875rem;
		width: 100%;
	}

	.budget-input-field.small {
		width: 150px;
	}

	.no-categories, .no-vendors, .no-methods {
		color: #6b7280;
		font-style: italic;
		text-align: center;
		padding: 20px 0;
	}

	/* Checkbox styling */
	input[type="checkbox"] {
		width: 16px;
		height: 16px;
		cursor: pointer;
		accent-color: #059669;
	}

	.header-cell input[type="checkbox"] {
		margin-right: 0.5rem;
	}

	.over-budget .budget-status-indicator {
		background: #fef2f2;
		color: #991b1b;
		border-color: #fecaca;
	}

	.exact-budget .budget-status-indicator {
		background: #fffbeb;
		color: #92400e;
		border-color: #fed7aa;
	}

	/* Table Sections - Each table gets its own scrollable area */
	.table-section {
		margin-bottom: 2rem;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		background: white;
		overflow: hidden;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.section-header {
		background: #f8fafc;
		padding: 1.5rem 2rem;
		border-bottom: 1px solid #e5e7eb;
		position: sticky;
		top: 0;
		z-index: 50;
	}

	.section-header-content {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		gap: 1rem;
	}

	.section-title-group {
		flex: 1;
	}

	.section-header h3 {
		margin: 0;
		color: #1e293b;
		font-weight: 600;
		font-size: 1.5rem; /* Increased from 1.25rem to 1.5rem */
	}

	.section-description {
		margin: 0.5rem 0 0 0;
		color: #6b7280;
		font-style: italic;
		font-size: 0.875rem;
	}

	.header-actions {
		display: flex;
		gap: 0.5rem;
		flex-shrink: 0;
	}

	.select-all-btn, .clear-all-btn {
		padding: 0.5rem 1rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		background: white;
		color: #374151;
		font-size: 1rem; /* Increased from 0.875rem to 1rem */
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.select-all-btn:hover:not(:disabled) {
		background: #059669;
		color: white;
		border-color: #059669;
	}

	.clear-all-btn:hover:not(:disabled) {
		background: #ef4444;
		color: white;
		border-color: #ef4444;
	}

	.select-all-btn:disabled, .clear-all-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Special styling for non-approved payments section */
	.table-section:has(.data-section.non-approved) .section-header {
		background: #fef3c7;
	}

	.table-section:has(.data-section.non-approved) .section-header h3 {
		color: #92400e;
	}

	.section-description {
		margin: 0.5rem 0 0 0;
		color: #6b7280;
		font-style: italic;
		font-size: 0.875rem;
	}

	.individual-table-container {
		max-height: 30vh; /* Each table gets 30% of viewport height */
		overflow-y: auto;
		overflow-x: auto; /* Allow horizontal scrolling */
		position: relative; /* Important for sticky positioning */
		/* Custom scrollbar styling */
		scrollbar-width: thin;
		scrollbar-color: #cbd5e1 #f1f5f9;
	}

	.individual-table-container::-webkit-scrollbar {
		width: 8px;
	}

	.individual-table-container::-webkit-scrollbar-track {
		background: #f1f5f9;
	}

	.individual-table-container::-webkit-scrollbar-thumb {
		background: #cbd5e1;
		border-radius: 4px;
	}

	.individual-table-container::-webkit-scrollbar-thumb:hover {
		background: #94a3b8;
	}

	/* Remove the old tables-container styles and update data-section */
	.data-section {
		background: transparent;
		border: none;
		box-shadow: none;
		margin: 0;
		border-radius: 0;
		position: relative;
		height: 100%;
		overflow: visible;
	}

	.data-section.non-approved {
		/* Specific styling for non-approved sections if needed */
	}

	/* Remove old section header styles - now handled by .section-header */

	/* Table Styles with Fixed Headers */
	.table-header-wrapper {
		position: relative;
		background: white;
		border-bottom: 2px solid #e5e7eb;
		border-radius: 8px 8px 0 0;
		overflow-x: auto;
		overflow-y: hidden;
	}

	.table-body-wrapper {
		max-height: 25vh;
		overflow-y: auto;
		overflow-x: auto;
		border: 1px solid #e5e7eb;
		border-top: none;
		border-radius: 0 0 8px 8px;
		position: relative;
	}

	.header-table,
	.body-table {
		width: 100%;
		min-width: 1200px; /* Minimum width to prevent squishing */
		border-collapse: collapse;
		table-layout: fixed;
		background: white;
	}

	.header-table th,
	.body-table td {
		padding: 12px 8px;
		text-align: left;
		border-right: 1px solid #e5e7eb;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.header-table th:last-child,
	.body-table td:last-child {
		border-right: none;
	}

	.header-table th {
		background: #f8fafc;
		font-weight: 600;
		color: #374151;
		border-bottom: 2px solid #e5e7eb;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		font-size: 1rem; /* Increased from 0.875rem to 1rem */
	}

	.body-table tr:nth-child(even) {
		background: #f9fafb;
	}

	.body-table tr:hover {
		background: #f3f4f6;
	}

	.body-table td {
		border-bottom: 1px solid #f3f4f6;
		vertical-align: middle;
		font-size: 1rem; /* Added font-size to increase table cell text */
	}

	/* Column width consistency - applying to both header and body */
	.checkbox-column {
		width: 60px !important;
		text-align: center;
		padding: 0.5rem !important;
	}

	.header-table th:nth-child(2),
	.body-table td:nth-child(2) {
		width: 140px; /* Bill Number/Description */
	}

	.header-table th:nth-child(3),
	.body-table td:nth-child(3) {
		width: 160px; /* Vendor/Category */
	}

	.header-table th:nth-child(4),
	.body-table td:nth-child(4) {
		width: 100px; /* Branch */
	}

	.header-table th:nth-child(5),
	.body-table td:nth-child(5) {
		width: 100px; /* Amount */
		text-align: right;
	}

	.header-table th:nth-child(6),
	.body-table td:nth-child(6) {
		width: 120px; /* Adjust Amount */
		text-align: center;
	}

	.header-table th:nth-child(7),
	.body-table td:nth-child(7) {
		width: 120px; /* Payment Method */
	}

	.header-table th:nth-child(8),
	.body-table td:nth-child(8) {
		width: 100px; /* Due Date */
	}

	.header-table th:nth-child(9),
	.body-table td:nth-child(9) {
		width: 110px; /* Status/Type */
	}

	.header-table th:nth-child(10),
	.body-table td:nth-child(10) {
		width: 200px; /* Actions */
	}

	/* Vendor Payment Table Specific Styles */
	.vendor-payment-table .vendor-header-table th:nth-child(1),
	.vendor-payment-table .vendor-body-table td:nth-child(1) {
		width: 50px !important;
		min-width: 50px !important;
		text-align: center !important;
	}

	.vendor-payment-table .vendor-header-table th:nth-child(2),
	.vendor-payment-table .vendor-body-table td:nth-child(2) {
		width: 140px !important;
		min-width: 140px !important;
	}

	.vendor-payment-table .vendor-header-table th:nth-child(3),
	.vendor-payment-table .vendor-body-table td:nth-child(3) {
		width: 160px !important;
		min-width: 160px !important;
	}

	.vendor-payment-table .vendor-header-table th:nth-child(4),
	.vendor-payment-table .vendor-body-table td:nth-child(4) {
		width: 100px !important;
		min-width: 100px !important;
	}

	.vendor-payment-table .vendor-header-table th:nth-child(5),
	.vendor-payment-table .vendor-body-table td:nth-child(5) {
		width: 100px !important;
		min-width: 100px !important;
		text-align: right !important;
	}

	.vendor-payment-table .vendor-header-table th:nth-child(6),
	.vendor-payment-table .vendor-body-table td:nth-child(6) {
		width: 120px !important;
		min-width: 120px !important;
		text-align: center !important;
	}

	.vendor-payment-table .vendor-header-table th:nth-child(7),
	.vendor-payment-table .vendor-body-table td:nth-child(7) {
		width: 120px !important;
		min-width: 120px !important;
	}

	.vendor-payment-table .vendor-header-table th:nth-child(8),
	.vendor-payment-table .vendor-body-table td:nth-child(8) {
		width: 100px !important;
		min-width: 100px !important;
	}

	.vendor-payment-table .vendor-header-table th:nth-child(9),
	.vendor-payment-table .vendor-body-table td:nth-child(9) {
		width: 110px !important;
		min-width: 110px !important;
		text-align: center !important;
	}

	.vendor-payment-table .vendor-header-table th:nth-child(10),
	.vendor-payment-table .vendor-body-table td:nth-child(10) {
		width: 140px !important;
		min-width: 140px !important;
		text-align: center !important;
	}

	.vendor-select {
		width: 50px !important;
		text-align: center !important;
	}

	.vendor-bill-number {
		width: 140px !important;
		min-width: 140px !important;
	}

	.vendor-name {
		width: 160px !important;
		min-width: 160px !important;
	}

	.vendor-branch {
		width: 100px !important;
		min-width: 100px !important;
	}

	.vendor-amount {
		width: 100px !important;
		min-width: 100px !important;
		text-align: right !important;
	}

	.vendor-adjust-amount {
		width: 120px !important;
		min-width: 120px !important;
		text-align: center !important;
	}

	.vendor-payment-method {
		width: 120px !important;
		min-width: 120px !important;
	}

	.vendor-due-date {
		width: 100px !important;
		min-width: 100px !important;
	}

	.vendor-approval-status {
		width: 110px !important;
		min-width: 110px !important;
		text-align: center !important;
	}

	.vendor-actions {
		width: 140px !important;
		min-width: 140px !important;
		text-align: center !important;
	}

	/* Scrollbar styling for table body */
	.table-body-wrapper::-webkit-scrollbar {
		width: 8px;
	}

	.table-body-wrapper::-webkit-scrollbar-track {
		background: #f1f5f9;
		border-radius: 4px;
	}

	.table-body-wrapper::-webkit-scrollbar-thumb {
		background: #cbd5e1;
		border-radius: 4px;
	}

	.table-body-wrapper::-webkit-scrollbar-thumb:hover {
		background: #94a3b8;
	}

	/* Cell content styling */
	.status-badge {
		padding: 4px 8px;
		border-radius: 12px;
		font-size: 0.875rem; /* Increased from 0.75rem to 0.875rem */
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		display: inline-flex;
		align-items: center;
		gap: 4px;
	}

	.status-badge.approved {
		background: #dcfce7;
		color: #166534;
		border: 1px solid #bbf7d0;
	}

	.status-badge.pending {
		background: #fef3c7;
		color: #92400e;
		border: 1px solid #fde68a;
	}

	.status-badge.not-approved {
		background: #fee2e2;
		color: #dc2626;
		border: 1px solid #fecaca;
	}

	/* Table Cell Styles */
	.bill-number, .vendor-name {
		font-weight: 600;
		color: #1e293b;
	}

	.amount {
		font-weight: 600;
		text-align: right;
		color: #059669;
		font-family: 'Courier New', monospace;
	}

	.due-date {
		font-family: 'Courier New', monospace;
		color: #374151;
		font-weight: 500;
	}

	.description {
		max-width: 200px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.payment-method {
		font-size: 0.875rem;
		color: #6b7280;
	}

	/* Status Badges */
	.status-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 9999px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.status-badge.approved {
		background: #d1fae5;
		color: #065f46;
	}

	.status-badge.pending {
		background: #fef3c7;
		color: #92400e;
	}

	.status-badge.not-approved {
		background: #fee2e2;
		color: #991b1b;
	}

	.type-badge {
		display: inline-block;
		padding: 0.25rem 0.5rem;
		background: #e0e7ff;
		color: #3730a3;
		border-radius: 4px;
		font-size: 0.875rem; /* Increased from 0.75rem to 0.875rem */
		font-weight: 500;
	}

	/* Action Buttons */
	.action-buttons {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.reschedule-btn, .split-btn {
		border: none;
		padding: 0.4rem 0.8rem;
		border-radius: 6px;
		font-size: 0.875rem; /* Increased from 0.75rem to 0.875rem */
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
	}

	.reschedule-btn {
		background: #3b82f6;
		color: white;
	}

	.reschedule-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
	}

	.split-btn {
		background: #8b5cf6;
		color: white;
	}

	.split-btn:hover {
		background: #7c3aed;
		transform: translateY(-1px);
	}

	/* No Data */
	.no-data {
		padding: 3rem 2rem;
		text-align: center;
		color: #6b7280;
	}

	.no-data p {
		margin: 0;
		font-style: italic;
	}

	/* Non-approved rows */
	.non-approved-row {
		opacity: 0.7;
	}

	/* Loading */
	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #e5e7eb;
		border-top: 4px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
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
		max-width: 500px;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
	}

	.split-modal {
		max-width: 600px;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem 2rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-header h3 {
		margin: 0;
		color: #1e293b;
		font-size: 1.25rem;
		font-weight: 600;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 1.5rem;
		color: #6b7280;
		cursor: pointer;
		padding: 0.25rem;
		border-radius: 4px;
		transition: background-color 0.2s;
	}

	.close-btn:hover {
		background: #f3f4f6;
		color: #374151;
	}

	.modal-body {
		padding: 2rem;
	}

	.item-info {
		background: #f8fafc;
		padding: 1.5rem;
		border-radius: 8px;
		margin-bottom: 1.5rem;
	}

	.item-info p {
		margin: 0 0 0.5rem 0;
		color: #374151;
	}

	.item-info p:last-child {
		margin-bottom: 0;
	}

	.reschedule-form label {
		display: block;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.5rem;
	}

	.modal-actions {
		display: flex;
		gap: 1rem;
		justify-content: flex-end;
		padding: 1.5rem 2rem;
		border-top: 1px solid #e5e7eb;
		background: #f8fafc;
	}

	.cancel-btn, .confirm-btn {
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		border: none;
	}

	.cancel-btn {
		background: #f3f4f6;
		color: #374151;
	}

	.cancel-btn:hover {
		background: #e5e7eb;
	}

	.confirm-btn {
		background: #3b82f6;
		color: white;
	}

	.confirm-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.confirm-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Split Modal Specific Styles */
	.split-info {
		background: #f8fafc;
		padding: 1.5rem;
		border-radius: 8px;
		margin-bottom: 1.5rem;
	}

	.split-info h4 {
		margin: 0 0 1rem 0;
		color: #1e293b;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.info-grid {
		display: grid;
		gap: 0.75rem;
	}

	.info-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.info-item .label {
		font-weight: 600;
		color: #6b7280;
	}

	.info-item .value {
		font-weight: 500;
		color: #1f2937;
	}

	.total-amount {
		color: #059669 !important;
		font-weight: 700 !important;
		font-size: 1.1rem;
	}

	.split-details h4 {
		margin: 0 0 1rem 0;
		color: #1e293b;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.split-form {
		display: grid;
		gap: 1rem;
		margin-bottom: 1.5rem;
	}

	.split-form .form-group {
		display: flex;
		flex-direction: column;
	}

	.split-form label {
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.5rem;
	}

	.amount-input {
		padding: 0.75rem;
		border: 2px solid #e5e7eb;
		border-radius: 6px;
		font-size: 1.1rem;
		font-weight: 600;
		text-align: right;
		font-family: 'Courier New', monospace;
	}

	.amount-input:focus {
		outline: none;
		border-color: #8b5cf6;
		box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
	}

	.split-summary {
		background: #f0f9ff;
		border: 1px solid #bae6fd;
		border-radius: 8px;
		padding: 1rem;
	}

	.summary-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.5rem;
	}

	.summary-row:last-child {
		margin-bottom: 0;
	}

	.summary-label {
		color: #374151;
		font-weight: 500;
	}

	.summary-value {
		font-weight: 700;
		font-family: 'Courier New', monospace;
	}

	.split-amount {
		color: #8b5cf6;
		font-size: 1.1rem;
	}

	.remaining-amount {
		color: #059669;
		font-size: 1.1rem;
	}

	.split-confirm {
		background: #8b5cf6;
		color: white;
	}

	.split-confirm:hover:not(:disabled) {
		background: #7c3aed;
	}

	/* Responsive Design */
	@media (max-width: 768px) {
		.budget-planner {
			padding: 1rem;
		}

		.budget-controls {
			grid-template-columns: 1fr;
			gap: 1rem;
			padding: 1.5rem;
		}

		.data-table {
			font-size: 0.875rem;
		}

		.data-table th,
		.data-table td {
			padding: 0.75rem 0.5rem;
		}

		.modal-content {
			width: 95%;
			margin: 1rem;
		}

		.modal-body {
			padding: 1.5rem;
		}

		.modal-actions {
			padding: 1rem 1.5rem;
			flex-direction: column;
		}
	}
</style>