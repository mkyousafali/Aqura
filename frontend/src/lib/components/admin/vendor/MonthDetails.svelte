<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	// Props passed from parent
	export let monthData = null;

	// Component state
	let monthDetailData = [];
	let scheduledPayments = [];
	
	// Drag and drop state
	let draggedPayment = null;
	let showSplitModal = false;
	let splitPayment = null;
	let splitAmount = 0;
	let remainingAmount = 0;

	// Initialize component
	onMount(async () => {
		if (monthData) {
			await loadScheduledPayments();
			generateAllDaysOfMonth(monthData);
		}
	});

	// Reactive statement to regenerate data when scheduledPayments change
	$: if (scheduledPayments.length >= 0 && monthData) {
		generateAllDaysOfMonth(monthData);
	}

	// Load scheduled payments from database
	async function loadScheduledPayments() {
		try {
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.select('*')
				.order('due_date', { ascending: true });

			if (error) {
				console.error('Error loading scheduled payments:', error);
				return;
			}

			scheduledPayments = data || [];
		} catch (error) {
			console.error('Error loading scheduled payments:', error);
		}
	}

	// Generate all days of the month (including days without payments)
	function generateAllDaysOfMonth(monthData) {
		const daysInMonth = new Date(monthData.year, monthData.month + 1, 0).getDate();
		monthDetailData = [];

		// Create data for each day of the month
		for (let day = 1; day <= daysInMonth; day++) {
			const dayDate = new Date(monthData.year, monthData.month, day);
			const dayInfo = {
				date: day,
				dayName: dayDate.toLocaleDateString('en-US', { weekday: 'short' }),
				fullDate: dayDate,
				dateString: dayDate.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }),
				payments: [],
				paymentsByVendor: {},
				totalAmount: 0,
				paymentCount: 0
			};

			// Find payments for this specific day
			scheduledPayments.forEach(payment => {
				const paymentDate = new Date(payment.due_date);
				if (paymentDate.toDateString() === dayDate.toDateString()) {
					dayInfo.payments.push(payment);
					dayInfo.totalAmount += (payment.final_bill_amount || 0);
					dayInfo.paymentCount++;

					// Group by vendor
					const vendorKey = payment.vendor_id || 'unknown';
					if (!dayInfo.paymentsByVendor[vendorKey]) {
						dayInfo.paymentsByVendor[vendorKey] = {
							vendor_name: payment.vendor_name || 'Unknown Vendor',
							vendor_id: payment.vendor_id,
							payments: [],
							totalAmount: 0
						};
					}
					dayInfo.paymentsByVendor[vendorKey].payments.push(payment);
					dayInfo.paymentsByVendor[vendorKey].totalAmount += (payment.final_bill_amount || 0);
				}
			});

			// Add ALL days (including empty ones)
			monthDetailData.push(dayInfo);
		}

		// Sort by date
		monthDetailData.sort((a, b) => a.date - b.date);
	}

	// Format currency display
	function formatCurrency(amount) {
		if (!amount || amount === 0) return 'SAR 0.00';
		return `SAR ${Number(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
	}

	// Format date for database without timezone conversion issues
	function formatDateForDB(date) {
		return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
	}

	// Get payment status class
	function getPaymentStatusStyle(status) {
		switch (status) {
			case 'paid': return 'status-paid';
			case 'overdue': return 'status-overdue';
			case 'cancelled': return 'status-cancelled';
			default: return 'status-scheduled';
		}
	}

	// Get unique color for each vendor
	function getVendorColor(index) {
		const colors = [
			'#f97316', // Orange
			'#3b82f6', // Blue
			'#10b981', // Emerald
			'#8b5cf6', // Violet
			'#f59e0b', // Amber
			'#ef4444', // Red
			'#06b6d4', // Cyan
			'#84cc16', // Lime
			'#ec4899', // Pink
			'#6366f1'  // Indigo
		];
		return colors[index % colors.length];
	}

	// Drag and drop functions
	function handleDragStart(event, payment) {
		draggedPayment = payment;
		event.dataTransfer.setData('text/plain', payment.id);
		event.dataTransfer.effectAllowed = 'move';
	}

	function handleDragOver(event) {
		event.preventDefault();
		event.dataTransfer.dropEffect = 'move';
	}

	function handleDrop(event, targetDate) {
		event.preventDefault();
		
		if (!draggedPayment) return;

		const targetDateString = targetDate.toDateString();
		const originalDateString = new Date(draggedPayment.due_date).toDateString();

		// Don't do anything if dropped on the same date
		if (targetDateString === originalDateString) {
			draggedPayment = null;
			return;
		}

		// Show modal to choose between full move or split
		showRescheduleModal(draggedPayment, targetDate);
	}

	function showRescheduleModal(payment, newDate) {
		splitPayment = { ...payment, newDate };
		splitAmount = parseFloat(payment.final_bill_amount || payment.bill_amount || 0);
		remainingAmount = splitAmount;
		showSplitModal = true;
	}

	function handleFullMove() {
		if (!splitPayment) return;
		
		// Update the payment's due date
		updatePaymentDate(splitPayment.id, splitPayment.newDate, splitPayment.final_bill_amount);
		closeSplitModal();
	}

	async function handleSplitMove() {
		if (!splitPayment || splitAmount <= 0 || splitAmount >= parseFloat(splitPayment.final_bill_amount)) {
			alert('Please enter a valid split amount');
			return;
		}

		const originalAmount = parseFloat(splitPayment.final_bill_amount || splitPayment.bill_amount || 0);
		const remainingAmount = originalAmount - splitAmount;

		try {
			// Create new payment record for the split amount
			await createSplitPayment(splitPayment, splitPayment.newDate, splitAmount);
			
			// Update original payment with remaining amount
			await updatePaymentAmount(splitPayment.id, remainingAmount);
			
			// Show success message
			alert(`Payment split successfully!\n\n✅ Created new payment: ${formatCurrency(splitAmount)} on ${splitPayment.newDate.toLocaleDateString()}\n✅ Updated original payment: ${formatCurrency(remainingAmount)} on ${new Date(splitPayment.due_date).toLocaleDateString()}`);
			
			closeSplitModal();
		} catch (error) {
			console.error('Error splitting payment:', error);
			alert('Failed to split payment. Please try again.');
		}
	}

	function closeSplitModal() {
		showSplitModal = false;
		splitPayment = null;
		draggedPayment = null;
		splitAmount = 0;
		remainingAmount = 0;
	}

	async function updatePaymentDate(paymentId, newDate, amount) {
		try {
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update({ 
					due_date: formatDateForDB(newDate),
					updated_at: new Date().toISOString()
				})
				.eq('id', paymentId);

			if (error) {
				console.error('Error updating payment date:', error);
				alert('Failed to reschedule payment');
				return;
			}

			// Reload data
			await loadScheduledPayments();
			alert('Payment rescheduled successfully');
		} catch (error) {
			console.error('Error updating payment:', error);
			alert('Failed to reschedule payment');
		}
	}

	async function updatePaymentAmount(paymentId, newAmount) {
		try {
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update({ 
					final_bill_amount: newAmount,
					updated_at: new Date().toISOString()
				})
				.eq('id', paymentId);

			if (error) {
				console.error('Error updating payment amount:', error);
				return;
			}
		} catch (error) {
			console.error('Error updating payment amount:', error);
		}
	}

	async function createSplitPayment(originalPayment, newDate, amount) {
		try {
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.insert({
					receiving_record_id: originalPayment.receiving_record_id,
					bill_number: originalPayment.bill_number + '-SPLIT',
					vendor_id: originalPayment.vendor_id,
					vendor_name: originalPayment.vendor_name,
					branch_id: originalPayment.branch_id,
					branch_name: originalPayment.branch_name,
					bill_date: originalPayment.bill_date,
					bill_amount: amount,
					final_bill_amount: amount,
					payment_method: originalPayment.payment_method,
					bank_name: originalPayment.bank_name,
					iban: originalPayment.iban,
					due_date: formatDateForDB(newDate),
					credit_period: originalPayment.credit_period,
					vat_number: originalPayment.vat_number,
					payment_status: 'scheduled',
					notes: (originalPayment.notes || '') + ' [Split from original payment]'
				});

			if (error) {
				console.error('Error creating split payment:', error);
				alert('Failed to create split payment');
				return;
			}

			// Reload data
			await loadScheduledPayments();
			alert('Payment split and rescheduled successfully');
		} catch (error) {
			console.error('Error creating split payment:', error);
			alert('Failed to create split payment');
		}
	}
</script>

<!-- Month Details Window Content -->
<div class="month-details-container">
	{#if monthData}
		<!-- Header Section -->
		<div class="month-details-header">
			<h2>📊 {monthData.monthName} {monthData.year} - Payment Schedule</h2>
		</div>

		<!-- Summary Section -->
		<div class="month-summary">
			<div class="summary-item">
				<span class="summary-label">Days with Payments:</span>
				<span class="summary-value">{monthDetailData.filter(d => d.paymentCount > 0).length}</span>
			</div>
			<div class="summary-item">
				<span class="summary-label">Total Payments:</span>
				<span class="summary-value">{monthData.paymentCount}</span>
			</div>
			<div class="summary-item">
				<span class="summary-label">Total Amount:</span>
				<span class="summary-value">{formatCurrency(monthData.total)}</span>
			</div>
		</div>

		<!-- Days List -->
		<div class="month-days-list">
			{#each monthDetailData as dayData}
				<div 
					class="day-details-card" 
					class:has-payments={dayData.paymentCount > 0}
					class:drop-zone={draggedPayment}
					on:dragover={handleDragOver}
					on:drop={(e) => handleDrop(e, dayData.fullDate)}
				>
					<div class="day-details-header">
						<div class="day-info">
							<div class="day-date">{dayData.date}</div>
							<div class="day-name">{dayData.dayName}</div>
							<div class="day-full-date">{dayData.dateString}</div>
						</div>
						<div class="day-summary">
							{#if dayData.paymentCount > 0}
								<div class="day-count">{dayData.paymentCount} payment{dayData.paymentCount !== 1 ? 's' : ''}</div>
								<div class="day-amount">{formatCurrency(dayData.totalAmount)}</div>
							{:else}
								<div class="day-empty">No payments scheduled</div>
							{/if}
						</div>
					</div>

					<!-- Payment Sections (always show sections with headers) -->
					<div class="payment-sections">
						
						<!-- VENDOR PAYMENTS SECTION -->
						<div class="payment-section">
							<div class="section-header">
								<h3 class="section-title">🏪 Vendor Payments</h3>
								<div class="section-summary">
									{#if dayData.paymentCount > 0}
										<span>{Object.keys(dayData.paymentsByVendor).length} vendor{Object.keys(dayData.paymentsByVendor).length !== 1 ? 's' : ''}</span>
										<span>{dayData.paymentCount} payment{dayData.paymentCount !== 1 ? 's' : ''}</span>
										<span>{formatCurrency(dayData.totalAmount)}</span>
									{:else}
										<span class="no-payments">No vendor payments scheduled</span>
									{/if}
								</div>
							</div>

								<!-- Common Table Header (separate from vendor cards) -->
								<div class="payments-table-header">
									<div class="table-header-row">
										<div class="header-column">Bill #</div>
										<div class="header-column">Amount</div>
										<div class="header-column">Bill Date</div>
										<div class="header-column">Due Date</div>
										<div class="header-column">Branch</div>
										<div class="header-column">Payment Method</div>
										<div class="header-column">Bank Name</div>
										<div class="header-column">IBAN</div>
										<div class="header-column">Status</div>
									</div>
								</div>

								<!-- Vendors Container with Payment Rows -->
								<div class="vendors-container">
									{#if dayData.paymentCount > 0}
										{#each Object.entries(dayData.paymentsByVendor) as [vendorKey, vendorGroup], vendorIndex}
										<div class="vendor-group" style="border-left: 4px solid {getVendorColor(vendorIndex)};">
											<!-- Vendor Title Row (separate from table) -->
											<div class="vendor-title-row" style="background-color: {getVendorColor(vendorIndex)}15; border-left: 4px solid {getVendorColor(vendorIndex)};">
												<h4 class="vendor-name" style="color: {getVendorColor(vendorIndex)};">
													{vendorGroup.vendor_name}
												</h4>
												<div class="vendor-summary">
													<span>{vendorGroup.payments.length} payment{vendorGroup.payments.length !== 1 ? 's' : ''}</span>
													<span>{formatCurrency(vendorGroup.totalAmount)}</span>
												</div>
											</div>
									
											<!-- Payment Rows (matching table header) -->
											<div class="vendor-payments-rows">
												{#each vendorGroup.payments as payment}
													<div 
														class="payment-row"
														draggable="true"
														class:dragging={draggedPayment && draggedPayment.id === payment.id}
														on:dragstart={(e) => handleDragStart(e, payment)}
														title="Drag to reschedule payment"
														style="border-left: 4px solid {getVendorColor(vendorIndex)};"
													>
														<div class="drag-handle" style="color: {getVendorColor(vendorIndex)};">⋮⋮</div>
														
														<div class="payment-data-row">
															<div class="data-cell">#{payment.bill_number || 'N/A'}</div>
															<div class="data-cell amount">{formatCurrency(payment.final_bill_amount)}</div>
															<div class="data-cell">{payment.bill_date ? new Date(payment.bill_date).toLocaleDateString() : 'N/A'}</div>
															<div class="data-cell">{payment.due_date ? new Date(payment.due_date).toLocaleDateString() : 'N/A'}</div>
															<div class="data-cell">{payment.branch_name || 'N/A'}</div>
															<div class="data-cell">
																<span class="payment-method">{payment.payment_method || 'Cash on Delivery'}</span>
															</div>
															<div class="data-cell">{payment.bank_name || 'N/A'}</div>
															<div class="data-cell">{payment.iban || 'N/A'}</div>
															<div class="data-cell">
																<span class="status-badge {getPaymentStatusStyle(payment.payment_status)}">
																	{payment.payment_status || 'scheduled'}
																</span>
															</div>
														</div>
													</div>
												{/each}
											</div>
								</div>
						{/each}
									{:else}
										<!-- Empty state for vendor payments -->
										<div class="empty-payments-row">
											<div class="empty-message">No vendor payments scheduled for this date</div>
										</div>
									{/if}
								</div>
							</div>

							<!-- OTHER PAYMENTS SECTION (always visible) -->
							<div class="payment-section">
								<div class="section-header">
									<h3 class="section-title">💳 Other Payments</h3>
									<div class="section-summary">
										<span class="coming-soon">Coming Soon</span>
									</div>
								</div>
								
								<!-- Other Payments Table Header (always visible) -->
								<div class="payments-table-header">
									<div class="table-header-row">
										<div class="header-column">Description</div>
										<div class="header-column">Amount</div>
										<div class="header-column">Due Date</div>
										<div class="header-column">Category</div>
										<div class="header-column">Department</div>
										<div class="header-column">Payment Method</div>
										<div class="header-column">Account</div>
										<div class="header-column">Status</div>
									</div>
								</div>
								
								<div class="section-placeholder">
									<p>Other payment types will be implemented here</p>
									<small>(Employee payments, utilities, rent, etc.)</small>
								</div>
							</div>

						</div>
				</div>
			{/each}
		</div>
	{:else}
		<div class="no-data">
			<p>No month data available</p>
		</div>
	{/if}
</div>

<!-- Split Payment Modal -->
{#if showSplitModal && splitPayment}
	<div class="modal-overlay" on:click={closeSplitModal}>
		<div class="modal-container" on:click|stopPropagation>
			<div class="modal-header">
				<h3>Reschedule Payment</h3>
				<button class="close-btn" on:click={closeSplitModal}>×</button>
			</div>
			
			<div class="modal-content">
				<div class="payment-info">
					<h4>Payment Split & Reschedule:</h4>
					<div class="payment-details-grid">
						<div class="detail-row">
							<span class="label">Vendor:</span>
							<span class="value">{splitPayment.vendor_name}</span>
						</div>
						<div class="detail-row">
							<span class="label">Bill Number:</span>
							<span class="value">{splitPayment.bill_number}</span>
						</div>
						<div class="detail-row">
							<span class="label">Original Amount:</span>
							<span class="value amount-original">{formatCurrency(splitPayment.final_bill_amount)}</span>
						</div>
						<div class="detail-row">
							<span class="label">From Date:</span>
							<span class="value">{new Date(splitPayment.due_date).toLocaleDateString()}</span>
						</div>
						<div class="detail-row">
							<span class="label">To Date:</span>
							<span class="value">{splitPayment.newDate.toLocaleDateString()}</span>
						</div>
					</div>
				</div>
				
				<div class="reschedule-options">
					<h4>Reschedule Options:</h4>
					
					<div class="option-group">
						<button class="option-btn full-move" on:click={handleFullMove}>
							<div class="option-icon">📦</div>
							<div class="option-text">
								<div class="option-title">Move Full Payment</div>
								<div class="option-desc">Move entire payment to new date</div>
							</div>
						</button>
					</div>
					
					<div class="option-group">
						<div class="split-option">
							<div class="split-header">
								<div class="option-icon">✂️</div>
								<div class="option-text">
									<div class="option-title">Split Payment</div>
									<div class="option-desc">Move partial amount to new date</div>
								</div>
							</div>
							
							<div class="split-inputs">
								<div class="input-group">
									<label>Amount to move to new date:</label>
									<input 
										type="number" 
										bind:value={splitAmount}
										max={parseFloat(splitPayment.final_bill_amount)}
										min="0.01"
										step="0.01"
										placeholder="Enter amount to split"
									/>
									<span class="currency-symbol">SAR</span>
								</div>
								
								<!-- Amount Breakdown Display -->
								{#if splitAmount > 0 && splitAmount < parseFloat(splitPayment.final_bill_amount)}
									<div class="amount-breakdown">
										<div class="breakdown-header">
											<h5>Payment Split Breakdown:</h5>
										</div>
										<div class="breakdown-row">
											<span class="breakdown-label">Amount moving to {splitPayment.newDate.toLocaleDateString()}:</span>
											<span class="breakdown-value move-amount">+ {formatCurrency(splitAmount)}</span>
										</div>
										<div class="breakdown-row">
											<span class="breakdown-label">Amount remaining on {new Date(splitPayment.due_date).toLocaleDateString()}:</span>
											<span class="breakdown-value remain-amount">= {formatCurrency(parseFloat(splitPayment.final_bill_amount) - splitAmount)}</span>
										</div>
										<div class="breakdown-divider"></div>
										<div class="breakdown-row total">
											<span class="breakdown-label">Original Total:</span>
											<span class="breakdown-value">{formatCurrency(splitPayment.final_bill_amount)}</span>
										</div>
									</div>
								{/if}
								
								<div class="remaining-info">
									<p>Remaining: {formatCurrency(parseFloat(splitPayment.final_bill_amount) - splitAmount)}</p>
								</div>
								
								<button class="option-btn split-move" on:click={handleSplitMove}>
									Split & Move
								</button>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.month-details-container {
		padding: 20px;
		max-height: 100%;
		overflow-y: auto;
		background: #f8fafc;
	}

	.month-details-header {
		margin-bottom: 24px;
		padding-bottom: 16px;
		border-bottom: 2px solid #e2e8f0;
	}

	.month-details-header h2 {
		margin: 0;
		color: #1e293b;
		font-size: 24px;
		font-weight: 600;
	}

	.month-summary {
		display: flex;
		gap: 32px;
		margin-bottom: 32px;
		padding: 20px;
		background: white;
		border-radius: 8px;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.1);
	}

	.summary-item {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.summary-label {
		font-size: 12px;
		color: #64748b;
		font-weight: 500;
	}

	.summary-value {
		font-size: 18px;
		font-weight: 700;
		color: #059669;
	}

	.month-days-list {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.day-details-card {
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		padding: 20px;
		transition: all 0.2s;
	}

	.day-details-card.has-payments {
		border-left: 4px solid #f97316;
		border: 2px solid #fed7aa;
		box-shadow: 0 2px 8px rgba(249, 115, 22, 0.1);
	}

	.day-details-card:not(.has-payments) {
		background: #f9fafb;
		border-style: dashed;
		opacity: 0.7;
	}

	.day-details-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 16px;
	}

	.day-info .day-date {
		font-size: 24px;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 2px;
	}

	.day-info .day-name {
		font-size: 14px;
		color: #475569;
		font-weight: 600;
		margin-bottom: 2px;
	}

	.day-info .day-full-date {
		font-size: 12px;
		color: #64748b;
	}

	.day-summary {
		text-align: right;
	}

	.day-count {
		font-size: 12px;
		color: #64748b;
		margin-bottom: 4px;
	}

	.day-amount {
		font-size: 18px;
		font-weight: 700;
		color: #059669;
	}

	.day-empty {
		font-size: 14px;
		color: #94a3b8;
		font-style: italic;
	}

	/* Payment Sections */
	.payment-sections {
		padding: 20px;
		display: flex;
		flex-direction: column;
		gap: 32px;
	}

	.payment-section {
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		overflow: hidden;
		background: white;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
	}

	.section-header {
		padding: 16px 20px;
		background: #f8fafc;
		border-bottom: 2px solid #e5e7eb;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.section-title {
		font-size: 18px;
		font-weight: 700;
		margin: 0;
		color: #1e293b;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.section-summary {
		display: flex;
		gap: 16px;
		font-size: 14px;
		color: #64748b;
		font-weight: 500;
	}

	.section-placeholder {
		padding: 40px 20px;
		text-align: center;
		color: #9ca3af;
		font-style: italic;
	}

	.coming-soon {
		background: #fbbf24;
		color: #92400e;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 600;
	}

	.no-payments {
		color: #9ca3af;
		font-style: italic;
		font-size: 14px;
	}

	.empty-payments-row {
		padding: 40px 20px;
		text-align: center;
		border: 1px solid #e5e7eb;
		border-top: none;
		background: #fafafa;
		border-radius: 0 0 8px 8px;
	}

	.empty-message {
		color: #9ca3af;
		font-style: italic;
		font-size: 16px;
		margin-bottom: 8px;
	}

	.section-placeholder {
		padding: 30px 20px;
		text-align: center;
		color: #9ca3af;
		font-style: italic;
		border: 1px solid #e5e7eb;
		border-top: none;
		background: #fafafa;
		border-radius: 0 0 8px 8px;
	}

	.section-placeholder small {
		display: block;
		margin-top: 8px;
		font-size: 12px;
		color: #6b7280;
	}

	.day-payments-table {
		overflow-x: auto;
	}

	.day-payments-table table {
		width: 100%;
		border-collapse: collapse;
		background: white;
		border-radius: 6px;
		overflow: hidden;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.05);
	}

	.day-payments-table th {
		background: #fff7ed;
		color: #9a3412;
		font-weight: 600;
		font-size: 11px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		padding: 16px 12px;
		text-align: left;
		border-bottom: 2px solid #f97316;
		border-top: 2px solid #f97316;
		vertical-align: top;
	}

	.day-payments-table td {
		padding: 16px 12px;
		border-bottom: 1px solid #f1f5f9;
		font-size: 13px;
		color: #374151;
		vertical-align: top;
	}

	.day-payments-table tbody tr {
		border: 2px solid #f97316;
		border-radius: 8px;
		margin-bottom: 12px;
		background: #fffbf5;
		box-shadow: 0 2px 4px rgba(249, 115, 22, 0.1);
	}

	.day-payments-table tbody tr:hover {
		background: #fff7ed;
		border-color: #ea580c;
		box-shadow: 0 4px 12px rgba(249, 115, 22, 0.3);
		transform: translateY(-1px);
	}

	/* Bill Details Cell */
	.bill-details-cell .bill-number {
		font-weight: 700;
		color: #1e293b;
		font-size: 14px;
		margin-bottom: 4px;
	}

	.bill-details-cell .bill-date,
	.bill-details-cell .due-date {
		font-size: 11px;
		color: #64748b;
		margin-bottom: 2px;
	}

	/* Vendor Details Cell */
	.vendor-details-cell .vendor-name {
		font-weight: 600;
		color: #1e293b;
		font-size: 14px;
		margin-bottom: 4px;
	}

	.vendor-details-cell .vendor-id,
	.vendor-details-cell .vat-number {
		font-size: 11px;
		color: #64748b;
		margin-bottom: 2px;
		font-family: monospace;
	}

	/* Branch Cell */
	.branch-cell .branch-name {
		font-weight: 600;
		color: #1e293b;
		font-size: 13px;
		margin-bottom: 4px;
	}

	.branch-cell .branch-id {
		font-size: 11px;
		color: #64748b;
		font-family: monospace;
	}

	/* Payment Details Cell */
	.payment-details-cell .amount {
		font-weight: 700;
		color: #059669;
		font-size: 15px;
		margin-bottom: 4px;
	}

	.payment-details-cell .original-amount {
		font-size: 11px;
		color: #64748b;
		margin-bottom: 4px;
	}

	.payment-details-cell .payment-method {
		font-size: 12px;
		color: #374151;
		background: #e5e7eb;
		padding: 2px 6px;
		border-radius: 4px;
		display: inline-block;
		margin-bottom: 4px;
	}

	.payment-details-cell .credit-period {
		font-size: 11px;
		color: #64748b;
	}

	/* Banking Cell */
	.banking-cell .bank-name {
		font-weight: 600;
		color: #1e293b;
		font-size: 13px;
		margin-bottom: 4px;
	}

	.banking-cell .iban {
		font-size: 11px;
		color: #64748b;
		font-family: monospace;
		word-break: break-all;
	}

	/* Status Cell */
	.status-cell {
		text-align: center;
	}

	.status-cell .scheduled-date,
	.status-cell .paid-date {
		font-size: 10px;
		color: #64748b;
		margin-top: 4px;
	}

	.status-cell .paid-date {
		color: #059669;
		font-weight: 600;
	}

	/* Vendor Grouping Styles */
	.vendors-container {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.vendor-group {
		border: 3px solid;
		border-radius: 12px;
		overflow: hidden;
		background: white;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
	}

	.vendor-summary {
		display: flex;
		gap: 20px;
		font-size: 14px;
		font-weight: 600;
		color: #374151;
	}

	/* Table Header Structure */
	.payments-table-header {
		background: #f1f5f9;
		border: 2px solid #e2e8f0;
		border-radius: 8px 8px 0 0;
		margin-bottom: 0;
	}

	.table-header-row {
		display: grid;
		grid-template-columns: 1fr 1fr 1fr 1fr 1fr 1.2fr 1fr 1fr;
		gap: 12px;
		padding: 16px 20px;
		font-weight: 700;
		color: #475569;
		text-transform: uppercase;
		font-size: 12px;
		letter-spacing: 0.5px;
	}

	.header-column {
		text-align: left;
	}

	/* Vendor Structure */
	.vendor-title-row {
		padding: 12px 20px;
		margin: 0;
		display: flex;
		justify-content: space-between;
		align-items: center;
		border-bottom: 1px solid #e5e7eb;
	}

	.vendor-name {
		margin: 0;
		font-size: 16px;
		font-weight: 700;
	}

	.vendor-payments-rows {
		display: flex;
		flex-direction: column;
	}

	.vendor-payments-table table {
		width: 100%;
		border-collapse: separate;
		border-spacing: 0;
		margin: 0;
	}

	.vendor-payments-table thead {
		display: none;
	}

	.vendor-payments-table tbody tr {
		border: 2px solid;
		border-radius: 8px;
		margin: 12px;
		background: white;
		display: block;
		padding: 16px;
		box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
	}

	.vendor-payments-table tbody tr:hover {
		background: #f9fafb;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	/* Payment Row Styles */
	.payment-row {
		border: 1px solid #e5e7eb;
		border-top: none;
		margin: 0;
		background: white;
		padding: 16px 20px;
		cursor: grab;
		transition: all 0.2s ease;
		position: relative;
		display: flex;
		align-items: center;
		gap: 16px;
	}

	.payment-row:last-child {
		border-radius: 0 0 8px 8px;
	}

	.payment-row:hover {
		background: #f9fafb;
		transform: translateX(2px);
	}

	.payment-row.dragging {
		opacity: 0.5;
		cursor: grabbing;
		background: #fef3c7;
	}

	.payment-data-row {
		display: grid;
		grid-template-columns: 1fr 1fr 1fr 1fr 1fr 1.2fr 1fr 1fr;
		gap: 12px;
		flex: 1;
		align-items: center;
	}

	.data-cell {
		font-size: 14px;
		color: #374151;
		display: flex;
		align-items: center;
	}

	.data-cell.amount {
		font-weight: 700;
		color: #059669;
		font-size: 15px;
	}

	.payment-method {
		background: #e5e7eb;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 600;
		display: inline-block;
		width: fit-content;
	}

	/* Drag and Drop Styles */
	.payment-row {
		cursor: grab;
		transition: all 0.2s ease;
		position: relative;
	}

	.payment-row:hover {
		background: #f8fafc;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.payment-row.dragging {
		opacity: 0.5;
		cursor: grabbing;
		background: #e2e8f0;
	}

	.drag-handle {
		position: absolute;
		left: -20px;
		top: 50%;
		transform: translateY(-50%);
		color: #f97316;
		font-size: 12px;
		cursor: grab;
		writing-mode: vertical-lr;
		line-height: 1;
		font-weight: bold;
	}

	.day-details-card.drop-zone {
		border: 2px dashed #3b82f6;
		background: #eff6ff;
		transition: all 0.2s ease;
	}

	.day-details-card.drop-zone:hover {
		border-color: #1d4ed8;
		background: #dbeafe;
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
		justify-content: center;
		align-items: center;
		z-index: 10000;
	}

	.modal-container {
		background: white;
		border-radius: 12px;
		padding: 0;
		min-width: 500px;
		max-width: 600px;
		max-height: 80vh;
		overflow-y: auto;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px 16px;
		border-bottom: 1px solid #e2e8f0;
	}

	.modal-header h3 {
		margin: 0;
		color: #1e293b;
		font-size: 20px;
		font-weight: 600;
	}

	.modal-header .close-btn {
		background: none;
		border: none;
		font-size: 24px;
		color: #64748b;
		cursor: pointer;
		padding: 0;
		width: 30px;
		height: 30px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		transition: all 0.2s;
	}

	.modal-header .close-btn:hover {
		background: #f1f5f9;
		color: #1e293b;
	}

	.modal-content {
		padding: 24px;
	}

	.payment-info {
		background: #f8fafc;
		padding: 16px;
		border-radius: 8px;
		margin-bottom: 24px;
	}

	.payment-info h4 {
		margin: 0 0 12px 0;
		color: #1e293b;
		font-size: 16px;
	}

	.payment-info p {
		margin: 4px 0;
		font-size: 14px;
		color: #475569;
	}

	.reschedule-options h4 {
		margin: 0 0 16px 0;
		color: #1e293b;
		font-size: 16px;
	}

	.option-group {
		margin-bottom: 16px;
	}

	.option-btn {
		display: flex;
		align-items: center;
		width: 100%;
		padding: 16px;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		background: white;
		cursor: pointer;
		transition: all 0.2s;
		text-align: left;
	}

	.option-btn:hover {
		border-color: #3b82f6;
		background: #f8fafc;
	}

	.option-btn.full-move:hover {
		border-color: #059669;
		background: #f0fdf4;
	}

	.option-btn.split-move {
		background: #3b82f6;
		color: white;
		border-color: #3b82f6;
		margin-top: 12px;
	}

	.option-btn.split-move:hover {
		background: #2563eb;
	}

	.option-icon {
		font-size: 24px;
		margin-right: 12px;
	}

	.option-title {
		font-weight: 600;
		color: #1e293b;
		margin-bottom: 2px;
	}

	.option-desc {
		font-size: 12px;
		color: #64748b;
	}

	.split-option {
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		padding: 16px;
	}

	.split-header {
		display: flex;
		align-items: center;
		margin-bottom: 16px;
	}

	.split-inputs {
		padding-left: 36px;
	}

	.input-group {
		margin-bottom: 12px;
	}

	.input-group label {
		display: block;
		margin-bottom: 4px;
		font-size: 14px;
		color: #374151;
		font-weight: 500;
	}

	.input-group {
		position: relative;
	}

	.input-group input {
		width: 100%;
		padding: 8px 12px;
		padding-right: 50px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
	}

	.currency-symbol {
		position: absolute;
		right: 12px;
		top: 50%;
		transform: translateY(-50%);
		color: #6b7280;
		font-weight: 600;
		font-size: 14px;
	}

	/* Payment Details Grid */
	.payment-details-grid {
		display: flex;
		flex-direction: column;
		gap: 8px;
		margin-top: 12px;
	}

	.detail-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 6px 0;
		border-bottom: 1px solid #f3f4f6;
	}

	.detail-row .label {
		font-weight: 600;
		color: #374151;
		font-size: 14px;
	}

	.detail-row .value {
		color: #1f2937;
		font-size: 14px;
	}

	.detail-row .amount-original {
		font-weight: 700;
		color: #3b82f6;
		font-size: 16px;
	}

	/* Amount Breakdown */
	.amount-breakdown {
		margin-top: 16px;
		padding: 16px;
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
	}

	.breakdown-header h5 {
		margin: 0 0 12px 0;
		font-size: 16px;
		font-weight: 700;
		color: #1e293b;
	}

	.breakdown-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 8px 0;
		font-size: 14px;
	}

	.breakdown-label {
		color: #475569;
		font-weight: 500;
	}

	.breakdown-value {
		font-weight: 700;
		color: #1f2937;
	}

	.breakdown-value.move-amount {
		color: #059669;
	}

	.breakdown-value.remain-amount {
		color: #dc2626;
	}

	.breakdown-row.total {
		border-top: 2px solid #e2e8f0;
		margin-top: 8px;
		padding-top: 12px;
		font-weight: 700;
	}

	.breakdown-divider {
		height: 1px;
		background: #e2e8f0;
		margin: 8px 0;
	}

	.input-group input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.remaining-info {
		margin-bottom: 16px;
		padding: 8px 12px;
		background: #f0fdf4;
		border-radius: 6px;
		border-left: 3px solid #059669;
	}

	.remaining-info p {
		margin: 0;
		font-size: 14px;
		color: #059669;
		font-weight: 600;
	}

	.status-badge {
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
	}

	.status-scheduled {
		background: #dbeafe;
		color: #1e40af;
	}

	.status-paid {
		background: #dcfce7;
		color: #166534;
	}

	.status-cancelled {
		background: #fef2f2;
		color: #991b1b;
	}

	.status-overdue {
		background: #fee2e2;
		color: #991b1b;
	}

	.no-data {
		display: flex;
		justify-content: center;
		align-items: center;
		height: 200px;
		color: #64748b;
		font-style: italic;
	}
</style>