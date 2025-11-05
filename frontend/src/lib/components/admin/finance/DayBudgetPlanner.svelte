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
	
	// Budget tracking
	let totalScheduled = 0;
	let remainingBudget = 0;
	let budgetStatus = 'within'; // 'within', 'over', 'exact'

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
		// Calculate total from vendor payments
		const vendorTotal = vendorPayments.reduce((sum, payment) => {
			return sum + (payment.final_bill_amount || payment.bill_amount || 0);
		}, 0);

		// Calculate total from expense schedules
		const expenseTotal = expenseSchedules.reduce((sum, expense) => {
			return sum + (expense.amount || 0);
		}, 0);

		totalScheduled = vendorTotal + expenseTotal;
		remainingBudget = dailyBudget - totalScheduled;

		// Determine budget status
		if (remainingBudget < 0) {
			budgetStatus = 'over';
		} else if (remainingBudget === 0) {
			budgetStatus = 'exact';
		} else {
			budgetStatus = 'within';
		}
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
		const amount = type === 'vendor' 
			? (item.final_bill_amount || item.bill_amount || 0)
			: (item.amount || 0);
		splitAmount = amount;
		remainingAmount = amount;
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
	<div class="planner-header">
		<h2>📊 Day Budget Planner</h2>
		<p>Plan and manage your daily budget for scheduled payments and expenses</p>
	</div>

	<!-- Date Selection and Budget Input -->
	<div class="budget-controls">
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
			<input 
				id="dailyBudget"
				type="number" 
				bind:value={dailyBudget}
				step="0.01"
				min="0"
				placeholder="0.00"
				class="budget-amount"
			/>
		</div>
	</div>

	<!-- Budget Summary -->
	<div class="budget-summary" class:over-budget={budgetStatus === 'over'} class:exact-budget={budgetStatus === 'exact'}>
		<div class="summary-item">
			<span class="label">Daily Budget:</span>
			<span class="value">{formatCurrency(dailyBudget)}</span>
		</div>
		<div class="summary-item">
			<span class="label">Total Scheduled:</span>
			<span class="value">{formatCurrency(totalScheduled)}</span>
		</div>
		<div class="summary-item remaining">
			<span class="label">Remaining:</span>
			<span class="value" class:negative={remainingBudget < 0}>
				{formatCurrency(remainingBudget)}
			</span>
		</div>
		<div class="budget-status-indicator">
			{#if budgetStatus === 'over'}
				⚠️ Over Budget by {formatCurrency(Math.abs(remainingBudget))}
			{:else if budgetStatus === 'exact'}
				✅ Exact Budget Match
			{:else}
				✅ Within Budget
			{/if}
		</div>
	</div>

	{#if isLoading}
		<div class="loading">
			<div class="spinner"></div>
			<p>Loading scheduled items...</p>
		</div>
	{:else}
		<!-- Vendor Payments Table -->
		<div class="data-section">
			<h3>💰 Vendor Payments Due ({vendorPayments.length})</h3>
			{#if vendorPayments.length > 0}
				<div class="table-container">
					<table class="data-table">
						<thead>
							<tr>
								<th>Bill Number</th>
								<th>Vendor</th>
								<th>Branch</th>
								<th>Amount</th>
								<th>Payment Method</th>
								<th>Due Date</th>
								<th>Status</th>
								<th>Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each vendorPayments as payment}
								<tr>
									<td class="bill-number">{payment.bill_number}</td>
									<td class="vendor-name">{payment.vendor_name}</td>
									<td>{payment.branch_name}</td>
									<td class="amount">{formatCurrency(payment.final_bill_amount || payment.bill_amount)}</td>
									<td class="payment-method">{payment.payment_method}</td>
									<td class="due-date">{formatDate(payment.due_date)}</td>
									<td>
										<span class="status-badge" class:approved={payment.approval_status === 'approved'} class:pending={payment.approval_status === 'pending'}>
											{payment.approval_status === 'approved' ? '✅ Approved' : '⏳ Pending'}
										</span>
									</td>
									<td>
										<div class="action-buttons">
											<button 
												class="reschedule-btn"
												on:click={() => openRescheduleModal(payment, 'vendor')}
											>
												📅 Reschedule
											</button>
											<button 
												class="split-btn"
												on:click={() => openSplitModal(payment, 'vendor')}
											>
												✂️ Split
											</button>
										</div>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{:else}
				<div class="no-data">
					<p>No vendor payments scheduled for {formatDate(selectedDate)}</p>
				</div>
			{/if}
		</div>

		<!-- Expense Schedules Table -->
		<div class="data-section">
			<h3>📋 Expense Schedules Due ({expenseSchedules.length})</h3>
			{#if expenseSchedules.length > 0}
				<div class="table-container">
					<table class="data-table">
						<thead>
							<tr>
								<th>Description</th>
								<th>Category</th>
								<th>Branch</th>
								<th>Amount</th>
								<th>Payment Method</th>
								<th>Due Date</th>
								<th>Type</th>
								<th>Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each expenseSchedules as expense}
								<tr>
									<td class="description">{expense.description}</td>
									<td>{expense.expense_category_name_en || 'N/A'}</td>
									<td>{expense.branch_name}</td>
									<td class="amount">{formatCurrency(expense.amount)}</td>
									<td class="payment-method">{expense.payment_method}</td>
									<td class="due-date">{formatDate(expense.due_date)}</td>
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
											<button 
												class="split-btn"
												on:click={() => openSplitModal(expense, 'expense')}
											>
												✂️ Split
											</button>
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

		<!-- Non-Approved Vendor Payments (Limited Details) -->
		{#if nonApprovedPayments.length > 0}
			<div class="data-section non-approved">
				<h3>⏳ Non-Approved Vendor Payments ({nonApprovedPayments.length})</h3>
				<p class="section-description">These payments are awaiting approval and may affect your budget if approved.</p>
				<div class="table-container">
					<table class="data-table simplified">
						<thead>
							<tr>
								<th>Vendor</th>
								<th>Amount</th>
								<th>Due Date</th>
								<th>Status</th>
							</tr>
						</thead>
						<tbody>
							{#each nonApprovedPayments as payment}
								<tr class="non-approved-row">
									<td class="vendor-name">{payment.vendor_name}</td>
									<td class="amount">{formatCurrency(payment.final_bill_amount || payment.bill_amount)}</td>
									<td>{formatDate(payment.due_date)}</td>
									<td>
										<span class="status-badge not-approved">Not Approved</span>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}
	{/if}
</div>

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
									const total = splitType === 'vendor' ? (splitItem.final_bill_amount || splitItem.bill_amount) : splitItem.amount;
									remainingAmount = total - splitAmount;
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
	}

	.planner-header {
		text-align: center;
		margin-bottom: 2rem;
	}

	.planner-header h2 {
		color: #1e293b;
		margin: 0 0 0.5rem 0;
		font-size: 2rem;
		font-weight: 700;
	}

	.planner-header p {
		color: #64748b;
		margin: 0;
		font-size: 1.1rem;
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
	}

	.date-selector, .budget-input {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.date-selector label, .budget-input label {
		font-weight: 600;
		color: #374151;
		font-size: 1rem;
	}

	.date-input, .budget-amount {
		padding: 0.75rem 1rem;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 1rem;
		transition: border-color 0.2s;
	}

	.date-input:focus, .budget-amount:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.budget-amount {
		font-size: 1.25rem;
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

	/* Data Sections */
	.data-section {
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		margin-bottom: 2rem;
		overflow: hidden;
	}

	.data-section h3 {
		background: #f8fafc;
		margin: 0;
		padding: 1.5rem 2rem;
		border-bottom: 1px solid #e5e7eb;
		color: #1e293b;
		font-weight: 600;
		font-size: 1.25rem;
	}

	.data-section.non-approved h3 {
		background: #fef3c7;
		color: #92400e;
	}

	.section-description {
		padding: 1rem 2rem 0;
		color: #6b7280;
		font-style: italic;
		margin: 0;
	}

	/* Tables */
	.table-container {
		overflow-x: auto;
	}

	.data-table {
		width: 100%;
		border-collapse: collapse;
	}

	.data-table th {
		background: #f8fafc;
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 2px solid #e5e7eb;
		font-size: 0.875rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.data-table td {
		padding: 1rem;
		border-bottom: 1px solid #f3f4f6;
		vertical-align: top;
	}

	.data-table tr:hover {
		background: #f8fafc;
	}

	.data-table.simplified th,
	.data-table.simplified td {
		padding: 0.75rem 1rem;
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
		font-size: 0.75rem;
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
		font-size: 0.75rem;
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