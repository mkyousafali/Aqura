<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import ApprovalMask from '$lib/components/desktop-interface/master/finance/ApprovalMask.svelte';
	import ApproverListModal from '$lib/components/desktop-interface/master/finance/ApproverListModal.svelte';
	import RequestClosureManager from '$lib/components/desktop-interface/master/finance/RequestClosureManager.svelte';

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
	$: isMasterAdmin = $currentUser?.isMasterAdmin;

	// Data
	let scheduledPayments = [];
	let expenseSchedulerPayments = [];
	let branches = [];
	let branchMap = {};
	let paymentMethods = [];
	let isLoading = false;
	let loadingProgress = 0;
	
	// Filters
	let filterBranch = '';
	let filterPaymentMethod = '';
	let filterPaymentCategory = '';

	// Modal states
	let showSplitModal = false;
	let showRescheduleModal = false;
	let splitPayment = null;
	let reschedulingPayment = null;
	let splitAmount = 0;
	let remainingAmount = 0;
	let newDateInput = '';
	let rescheduleNewDate = '';
	
	let showPaymentMethodModal = false;
	let editingPayment = null;
	let editingPaymentId = null;

	let showExpenseRescheduleModal = false;
	let reschedulingExpensePayment = null;
	let expenseNewDateInput = '';
	let expenseSplitAmount = 0;

	let showEditAmountModal = false;
	let editingAmountPayment = null;
	let editAmountForm = {
		discountAmount: 0,
		discountNotes: '',
		grrAmount: 0,
		grrReferenceNumber: '',
		grrNotes: '',
		priAmount: 0,
		priReferenceNumber: '',
		priNotes: ''
	};

	// Success popup
	let showSuccessPopup = false;
	let successMessage = '';

	function showSuccess(message) {
		console.log('🎉 Success popup triggered:', message);
		successMessage = message;
		showSuccessPopup = true;
		console.log('showSuccessPopup set to:', showSuccessPopup);
		setTimeout(() => {
			showSuccessPopup = false;
			console.log('Success popup closed');
		}, 3000);
	}

	// Approval system state
	let showApproverListModal = false;
	let pendingApprovalPayment = null;

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
				.select('id, name_en, name_ar')
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
				branchMap[branch.id] = branch.name_en;
			});
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	// Load scheduled payments for selected date
	async function loadScheduledPayments() {
		try {
			const selectedDate = `${selectedYear}-${String(selectedMonth + 1).padStart(2, '0')}-${String(selectedDay).padStart(2, '0')}`;

			const { data: scheduleData, error } = await supabase
				.from('vendor_payment_schedule')
				.select('*')
				.eq('due_date', selectedDate)
				.limit(5000);

			if (error) {
				console.error('Error loading scheduled payments:', error);
				return;
			}

			scheduledPayments = scheduleData || [];
		} catch (error) {
			console.error('Error loading scheduled payments:', error);
		}
	}

	// Load expense scheduler payments for selected date
	async function loadExpenseSchedulerPayments() {
		try {
			const selectedDate = `${selectedYear}-${String(selectedMonth + 1).padStart(2, '0')}-${String(selectedDay).padStart(2, '0')}`;

		const { data, error } = await supabase
			.from('expense_scheduler')
			.select('id, amount, is_paid, paid_date, status, branch_id, payment_method, expense_category_name_en, expense_category_name_ar, description, schedule_type, due_date, co_user_name, created_by, requisition_id, requisition_number, creator:users!created_by(username)')
			.eq('due_date', selectedDate)
			.limit(5000);			if (error) {
				console.error('Error loading expense scheduler payments:', error);
				return;
			}

			expenseSchedulerPayments = (data || [])
				.filter(payment => {
					if (payment.schedule_type === 'expense_requisition' && (payment.amount === 0 || payment.is_paid === true)) {
						return false;
					}
					return true;
				});
		} catch (error) {
			console.error('Error loading expense scheduler payments:', error);
		}
	}

	// Handle payment status change
	async function handlePaymentStatusChange(paymentId, isPaid) {
		try {
			const updateData = isPaid 
				? { is_paid: true, paid_date: new Date().toISOString() }
				: { is_paid: false, paid_date: null };

			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update(updateData)
				.eq('id', paymentId);

			if (error) {
				console.error('Error updating payment status:', error);
				alert('Failed to update payment status');
				return;
			}

			showSuccess(isPaid ? 'Payment marked as paid ✓' : 'Payment marked as unpaid');
			await loadScheduledPayments();
		} catch (error) {
			console.error('Error updating payment status:', error);
		}
	}

	// Mark expense as paid
	async function markExpenseAsPaid(paymentId) {
		if (!confirm('Mark this expense payment as paid?')) return;

		try {
			const { error } = await supabase
				.from('expense_scheduler')
				.update({ 
					is_paid: true, 
					paid_date: new Date().toISOString(),
					status: 'paid',
					updated_by: $currentUser?.id,
				})
				.eq('id', paymentId);

			if (error) {
				console.error('Error marking expense as paid:', error);
				alert('Failed to mark expense as paid');
				return;
			}

			showSuccess('Expense payment marked as paid ✓');
			await loadExpenseSchedulerPayments();
		} catch (error) {
			console.error('Error marking expense as paid:', error);
		}
	}

	// Unmark expense as paid
	async function unmarkExpenseAsPaid(paymentId) {
		if (!confirm('Mark this expense payment as unpaid?')) return;

		try {
			const { error } = await supabase
				.from('expense_scheduler')
				.update({ 
					is_paid: false, 
					paid_date: null,
					status: 'pending',
					updated_by: $currentUser?.id,
				})
				.eq('id', paymentId);

			if (error) {
				console.error('Error unmarking expense as paid:', error);
				alert('Failed to unmark expense as paid');
				return;
			}

			await loadExpenseSchedulerPayments();
		} catch (error) {
			console.error('Error unmarking expense as paid:', error);
		}
	}

	// Open payment method edit modal
	function openPaymentMethodEdit(payment) {
		editingPayment = payment;
		editingPaymentId = payment.id;
		showPaymentMethodModal = true;
	}

	// Save payment method
	async function savePaymentMethod(newMethod) {
		if (!editingPaymentId) return;
		
		try {
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update({ payment_method: newMethod })
				.eq('id', editingPaymentId);

			if (error) {
				console.error('Error updating payment method:', error);
				alert('Failed to update payment method');
				return;
			}

			showPaymentMethodModal = false;
			editingPayment = null;
			editingPaymentId = null;
			showSuccess('Payment method updated ✓');
			await loadScheduledPayments();
		} catch (error) {
			console.error('Error updating payment method:', error);
		}
	}

	// Open reschedule modal
	function openRescheduleModal(payment) {
		reschedulingPayment = payment;
		rescheduleNewDate = '';
		showRescheduleModal = true;
	}

	// Open split modal
	function openSplitModal(payment) {
		splitPayment = payment;
		splitAmount = 0;
		remainingAmount = payment.final_bill_amount;
		newDateInput = '';
		showSplitModal = true;
	}

	// Handle simple reschedule (just change date)
	async function handleReschedule() {
		if (!reschedulingPayment || !rescheduleNewDate) {
			alert('Please select a new date');
			return;
		}

		try {
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update({ due_date: rescheduleNewDate })
				.eq('id', reschedulingPayment.id);

			if (error) {
				console.error('Error rescheduling payment:', error);
				alert('Failed to reschedule payment');
				return;
			}

			showRescheduleModal = false;
			reschedulingPayment = null;
			showSuccess('Payment rescheduled successfully ✓');
			await loadScheduledPayments();
		} catch (error) {
			console.error('Error rescheduling payment:', error);
		}
	}

	// Handle split/reschedule payment
	async function handleSplitPayment() {
		if (!splitPayment || !newDateInput) {
			alert('Please select a new date');
			return;
		}

		if (splitAmount <= 0 || splitAmount >= splitPayment.final_bill_amount) {
			alert('Please enter a valid split amount');
			return;
		}

		try {
			// Update original payment amount
			const { error: updateError } = await supabase
				.from('vendor_payment_schedule')
				.update({ final_bill_amount: splitPayment.final_bill_amount - splitAmount })
				.eq('id', splitPayment.id);

			if (updateError) {
				console.error('Error updating payment:', updateError);
				alert('Failed to update payment');
				return;
			}

			// Create new payment with split amount
			// Add "SPLIT_" prefix to bill number
			const splitBillNumber = `SPLIT_${splitPayment.bill_number || ''}`;
			
			const { error: insertError } = await supabase
				.from('vendor_payment_schedule')
				.insert({
					bill_number: splitBillNumber,
					vendor_id: splitPayment.vendor_id,
					vendor_name: splitPayment.vendor_name,
					branch_id: splitPayment.branch_id,
					branch_name: splitPayment.branch_name,
					bill_amount: splitPayment.bill_amount,
					final_bill_amount: splitAmount,
					payment_method: splitPayment.payment_method,
					bank_name: splitPayment.bank_name,
					iban: splitPayment.iban,
					vat_number: splitPayment.vat_number,
					task_id: splitPayment.task_id,
					task_assignment_id: splitPayment.task_assignment_id,
					receiver_user_id: splitPayment.receiver_user_id,
					accountant_user_id: splitPayment.accountant_user_id,
					original_bill_url: splitPayment.original_bill_url,
					receiving_record_id: splitPayment.receiving_record_id,
					due_date: newDateInput,
					is_paid: false,
					paid_date: null,
					approval_status: 'pending',
					bill_date: splitPayment.bill_date
				});

			if (insertError) {
				console.error('Error creating split payment:', insertError);
				alert('Failed to create split payment');
				return;
			}

			showSplitModal = false;
			splitPayment = null;
			showSuccess('Payment split successfully ✓ - Approval required for split amount');
			await loadScheduledPayments();
		} catch (error) {
			console.error('Error splitting payment:', error);
		}
	}

	// Open edit amount modal
	function openEditAmountModal(payment) {
		editingAmountPayment = payment;
		editAmountForm = {
			discountAmount: 0,
			discountNotes: '',
			grrAmount: 0,
			grrReferenceNumber: '',
			grrNotes: '',
			priAmount: 0,
			priReferenceNumber: '',
			priNotes: ''
		};
		showEditAmountModal = true;
	}

	// Save edited amount
	async function saveEditedAmount() {
		if (!editingAmountPayment) return;

		try {
			const totalReduction = (editAmountForm.discountAmount || 0) + 
				(editAmountForm.grrAmount || 0) + (editAmountForm.priAmount || 0);
			
			const newAmount = editingAmountPayment.final_bill_amount - totalReduction;

			if (newAmount < 0) {
				alert('Total reduction cannot exceed payment amount');
				return;
			}

			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update({ 
					final_bill_amount: newAmount,
					discount_amount: editAmountForm.discountAmount,
					discount_notes: editAmountForm.discountNotes,
					grr_amount: editAmountForm.grrAmount,
					grr_reference_number: editAmountForm.grrReferenceNumber,
					grr_notes: editAmountForm.grrNotes,
					pri_amount: editAmountForm.priAmount,
					pri_reference_number: editAmountForm.priReferenceNumber,
					pri_notes: editAmountForm.priNotes
				})
				.eq('id', editingAmountPayment.id);

			if (error) {
				console.error('Error updating amount:', error);
				alert('Failed to update amount');
				return;
			}

			showEditAmountModal = false;
			editingAmountPayment = null;
			showSuccess('Payment amount updated ✓');
			await loadScheduledPayments();
		} catch (error) {
			console.error('Error updating amount:', error);
		}
	}

	// Delete vendor payment
	async function deleteVendorPayment(payment) {
		if (!confirm(`Delete payment for ${payment.vendor_name}?`)) return;

		try {
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.delete()
				.eq('id', payment.id);

			if (error) {
				console.error('Error deleting payment:', error);
				alert('Failed to delete payment');
				return;
			}

			await loadScheduledPayments();
		} catch (error) {
			console.error('Error deleting payment:', error);
		}
	}

	// Reschedule expense payment
	function openExpenseRescheduleModal(payment) {
		reschedulingExpensePayment = payment;
		expenseNewDateInput = '';
		expenseSplitAmount = 0;
		showExpenseRescheduleModal = true;
	}

	// Open request closure modal
	function openRequestClosureModal(payment) {
		const windowId = `request-closure-${payment.requisition_id}`;
		openWindow({
			id: windowId,
			title: `Close Request: #${payment.requisition_number}`,
			component: RequestClosureManager,
			props: {
				preSelectedRequestId: payment.requisition_id,
				windowId: windowId
			},
			icon: '✅',
			size: { width: 1400, height: 800 },
			resizable: true,
			maximizable: true
		});
	}

	async function handleExpenseReschedule() {
		if (!reschedulingExpensePayment || !expenseNewDateInput) {
			alert('Please select a new date');
			return;
		}

		try {
			if (expenseSplitAmount > 0 && expenseSplitAmount < reschedulingExpensePayment.amount) {
				// Split the payment
				const { error: updateError } = await supabase
					.from('expense_scheduler')
					.update({ amount: reschedulingExpensePayment.amount - expenseSplitAmount })
					.eq('id', reschedulingExpensePayment.id);

				if (updateError) {
					console.error('Error updating expense:', updateError);
					alert('Failed to update expense');
					return;
				}

				const { error: insertError } = await supabase
					.from('expense_scheduler')
					.insert({
						...reschedulingExpensePayment,
						id: undefined,
						amount: expenseSplitAmount,
						due_date: expenseNewDateInput,
						is_paid: false,
						paid_date: null
					});

				if (insertError) {
					console.error('Error creating split expense:', insertError);
					alert('Failed to create split expense');
					return;
				}
			} else {
				// Just reschedule
				const { error } = await supabase
					.from('expense_scheduler')
					.update({ due_date: expenseNewDateInput })
					.eq('id', reschedulingExpensePayment.id);

				if (error) {
					console.error('Error rescheduling expense:', error);
					alert('Failed to reschedule expense');
					return;
				}
			}

			showExpenseRescheduleModal = false;
			reschedulingExpensePayment = null;
			await loadExpenseSchedulerPayments();
		} catch (error) {
			console.error('Error rescheduling expense:', error);
		}
	}

	// Delete expense payment
	async function deleteExpensePayment(payment) {
		if (!confirm('Delete this expense payment?')) return;

		try {
			const { error } = await supabase
				.from('expense_scheduler')
				.delete()
				.eq('id', payment.id);

			if (error) {
				console.error('Error deleting expense:', error);
				alert('Failed to delete expense');
				return;
			}

			await loadExpenseSchedulerPayments();
		} catch (error) {
			console.error('Error deleting expense:', error);
		}
	}

	// Approval system functions
	function handleRequestApproval(payment) {
		if (!$currentUser?.id) {
			alert('You must be logged in to request approval');
			return;
		}
		pendingApprovalPayment = payment;
		showApproverListModal = true;
	}

	async function handleApprovalSubmitted(event) {
		const { paymentId, approvers } = event.detail;
		alert(`Payment sent for approval successfully!\n${approvers.length} approver(s) will be notified.`);
		await loadScheduledPayments();
		closeApproverModal();
	}

	function closeApproverModal() {
		showApproverListModal = false;
		pendingApprovalPayment = null;
	}

	function needsApproval(payment) {
		if (payment.is_paid) return false;
		return !payment.approval_status || payment.approval_status !== 'approved';
	}

	function getApprovalStatus(payment) {
		return payment.approval_status || 'pending';
	}

	// Get unique payment methods from current data (both vendor and expense)
	$: availablePaymentMethods = [...new Set([
		...scheduledPayments.map(p => p.payment_method).filter(Boolean),
		...expenseSchedulerPayments.map(p => p.payment_method).filter(Boolean)
	])].sort();

	// Filtered payments
	$: filteredPayments = scheduledPayments.filter(payment => {
		if (filterBranch && payment.branch_id != filterBranch) return false;
		if (filterPaymentMethod && payment.payment_method !== filterPaymentMethod) return false;
		if (filterPaymentCategory && payment.payment_method !== filterPaymentCategory) return false;
		return true;
	});

	$: filteredExpensePayments = expenseSchedulerPayments.filter(payment => {
		if (filterBranch && payment.branch_id != filterBranch) return false;
		if (filterPaymentCategory && payment.payment_method !== filterPaymentCategory) return false;
		return true;
	});

	// Load data when date changes
	let previousDate = null;
	let isInitialLoad = true;
	
	$: if (selectedYear && selectedMonth !== undefined && selectedDay) {
		const currentDate = `${selectedYear}-${selectedMonth}-${selectedDay}`;
		
		if (!isInitialLoad && previousDate && currentDate !== previousDate) {
			const monthName = months[selectedMonth];
			showSuccess(`📅 Date changed to ${monthName} ${selectedDay}, ${selectedYear}`);
		}
		
		previousDate = currentDate;
		loadData();
		
		if (isInitialLoad) {
			isInitialLoad = false;
		}
	}

	async function loadData() {
		isLoading = true;
		loadingProgress = 0;
		try {
			loadingProgress = 10;
			await loadBranches();
			loadingProgress = 40;
			await loadScheduledPayments();
			loadingProgress = 70;
			await loadExpenseSchedulerPayments();
			loadingProgress = 100;
		} finally {
			isLoading = false;
			loadingProgress = 0;
		}
	}

	onMount(() => {
		loadData();
	});
</script>

<div class="monthly-manager-container">
	{#if isLoading}
		<div class="loading-overlay">
			<div class="loading-content">
				<div class="loading-spinner"></div>
				<div class="loading-text">Loading payments...</div>
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
						<option value={branch.id}>{branch.name_en}</option>
					{/each}
				</select>
			</div>
			<div class="filter-group">
				<label for="filter-payment-category">Payment Method:</label>
				<select id="filter-payment-category" bind:value={filterPaymentCategory}>
					<option value="">All Methods</option>
					{#each availablePaymentMethods as method}
						<option value={method}>{method}</option>
					{/each}
				</select>
			</div>
		</div>
	</div>

	<!-- Vendor Payments Section -->
	<div class="payment-section">
		<div class="section-header">
			<h3 class="section-title">📦 Vendor Payments</h3>
			<div class="section-summary">
				{#if true}
					{@const totalAmount = filteredPayments.reduce((sum, p) => sum + (p.final_bill_amount || 0), 0)}
					{@const paidAmount = filteredPayments.filter(p => p.is_paid).reduce((sum, p) => sum + (p.final_bill_amount || 0), 0)}
					{@const unpaidAmount = filteredPayments.filter(p => !p.is_paid).reduce((sum, p) => sum + (p.final_bill_amount || 0), 0)}
					<span>{filteredPayments.length} payment{filteredPayments.length !== 1 ? 's' : ''}</span>
					<span>Total: {formatCurrency(totalAmount)}</span>
					<span style="color: #059669;">Paid: {formatCurrency(paidAmount)}</span>
					<span style="color: #dc2626;">Unpaid: {formatCurrency(unpaidAmount)}</span>
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
						<th>Branch</th>
						<th>Payment</th>
						<th>Bank</th>
						<th>IBAN</th>
						<th>Status</th>
						<th>Mark Paid</th>
						<th>Approval</th>
						<th>Edit Method</th>
						<th>Reschedule</th>
						<th>Split</th>
						<th>Edit Amount</th>
						<th>Delete</th>
					</tr>
				</thead>
				<tbody>
					{#if filteredPayments.length > 0}
						{#each filteredPayments as payment}
							<tr>
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
								<td>{getBranchName(payment.branch_id)}</td>
								<td>
									<span class="payment-method">{payment.payment_method || 'Cash on Delivery'}</span>
								</td>
								<td>{payment.bank_name || 'N/A'}</td>
								<td>{payment.iban || 'N/A'}</td>
								<td>
									<span class="status-badge {payment.is_paid ? 'status-paid' : 'status-scheduled'}">
										{payment.is_paid ? 'Paid' : 'Scheduled'}
									</span>
								</td>
								<td>
									{#if !needsApproval(payment)}
										<input 
											type="checkbox" 
											class="payment-checkbox"
											checked={payment.is_paid || false}
											on:change={(e) => handlePaymentStatusChange(payment.id, e.currentTarget.checked)}
											disabled={needsApproval(payment)}
										/>
									{:else}
										<span style="color: #94a3b8; font-size: 12px;">Needs Approval</span>
									{/if}
								</td>
								<td>
									{#if needsApproval(payment)}
										<ApprovalMask 
											approvalStatus={getApprovalStatus(payment)}
											onRequestApproval={() => handleRequestApproval(payment)}
											disabled={!$currentUser?.id}
										/>
									{:else}
										<span style="color: #059669; font-size: 11px;">✓ Approved</span>
									{/if}
								</td>
								<td>
									{#if !payment.is_paid && !needsApproval(payment)}
										<button 
											class="edit-payment-method-btn"
											on:click={() => openPaymentMethodEdit(payment)}
											title="Edit payment method"
										>
											✏️
										</button>
									{/if}
								</td>
								<td>
									{#if !payment.is_paid && !needsApproval(payment)}
										<button 
											class="reschedule-btn"
											on:click|stopPropagation={() => openRescheduleModal(payment)}
											title="Reschedule Payment"
										>
											📅
										</button>
									{/if}
								</td>
								<td>
									{#if !payment.is_paid && !needsApproval(payment)}
										<button 
											class="split-btn"
											on:click|stopPropagation={() => openSplitModal(payment)}
											title="Split Payment"
										>
											✂️
										</button>
									{/if}
								</td>
								<td>
									{#if !payment.is_paid && !needsApproval(payment)}
										<button 
											class="edit-amount-btn"
											on:click|stopPropagation={() => openEditAmountModal(payment)}
											title="Edit Amount (Discount/GRR/PRI)"
										>
											💰
										</button>
									{/if}
								</td>
								<td>
									{#if isMasterAdmin && !needsApproval(payment)}
										<button 
											class="delete-btn"
											on:click|stopPropagation={() => deleteVendorPayment(payment)}
											title="Delete Payment (Master Admin Only)"
										>
											🗑️
										</button>
									{/if}
								</td>
							</tr>
						{/each}
					{:else}
						<tr>
							<td colspan="16" class="empty-payments-row">
								<div class="empty-message">No vendor payments scheduled for this date</div>
							</td>
						</tr>
					{/if}
				</tbody>
			</table>
		</div>
	</div>

	<!-- Expense Scheduler Section -->
	<div class="payment-section">
		<div class="section-header">
			<h3 class="section-title">💳 Other Payments (Expense Scheduler)</h3>
			<div class="section-summary">
				{#if true}
					{@const totalExpenses = filteredExpensePayments.reduce((sum, p) => sum + (p.amount || 0), 0)}
					{@const paidExpenses = filteredExpensePayments.filter(p => p.is_paid).reduce((sum, p) => sum + (p.amount || 0), 0)}
					{@const unpaidExpenses = filteredExpensePayments.filter(p => !p.is_paid).reduce((sum, p) => sum + (p.amount || 0), 0)}
					<span>{filteredExpensePayments.length} payment{filteredExpensePayments.length !== 1 ? 's' : ''}</span>
					<span>Total: {formatCurrency(totalExpenses)}</span>
					<span style="color: #059669;">Paid: {formatCurrency(paidExpenses)}</span>
					<span style="color: #dc2626;">Unpaid: {formatCurrency(unpaidExpenses)}</span>
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
						<th>Status</th>
						<th>Mark Paid</th>
						<th>Reschedule</th>
						<th>Delete</th>
					</tr>
				</thead>
				<tbody>
					{#if filteredExpensePayments.length > 0}
						{#each filteredExpensePayments as payment}
							<tr class={payment.is_paid ? 'paid-row' : ''}>
								<td>
									<span class="bill-number-badge">#{payment.id || 'N/A'}</span>
								</td>
								<td style="text-align: left;">
									{#if payment.expense_category_name_en || payment.expense_category_name_ar}
										{payment.expense_category_name_en || payment.expense_category_name_ar}
									{:else}
										<span style="color: #f59e0b; font-style: italic;">Unknown - To Be Assigned</span>
									{/if}
								</td>
								<td style="text-align: left;">{getBranchName(payment.branch_id)}</td>
								<td>
									<span class="payment-method-badge">
										{payment.payment_method || 'Expense'}
									</span>
								</td>
								<td style="text-align: right; font-weight: 600; color: {payment.is_paid ? '#059669' : '#dc2626'};">
									{formatCurrency(payment.amount || 0)}
								</td>
								<td>
									{#if payment.is_paid && payment.paid_date}
										<span style="color: #059669; font-weight: 500;">{formatDate(payment.paid_date)}</span>
									{:else}
										<span style="color: #94a3b8;">—</span>
									{/if}
								</td>
								<td>{payment.creator?.username || 'Unknown'}</td>
								<td style="text-align: left; max-width: 200px; overflow: hidden; text-overflow: ellipsis;" title="{payment.description || ''}">
									{payment.description || 'N/A'}
								</td>
								<td>
									<span class="status-badge {payment.is_paid ? 'status-paid' : 'status-scheduled'}">
										{payment.is_paid ? 'Paid' : payment.status || 'Pending'}
									</span>
								</td>
								<td>
									{#if payment.schedule_type === 'expense_requisition'}
										<span style="color: #64748b; font-size: 12px;">Use Close Request →</span>
									{:else}
										<input 
											type="checkbox" 
											class="payment-checkbox"
											checked={payment.is_paid || false}
											on:change={(e) => {
												if (e.currentTarget.checked) {
													markExpenseAsPaid(payment.id);
												} else {
													unmarkExpenseAsPaid(payment.id);
												}
											}}
										/>
									{/if}
								</td>
								<td>
									{#if !payment.is_paid}
										<button 
											class="reschedule-btn"
											on:click|stopPropagation={() => openExpenseRescheduleModal(payment)}
											title="Reschedule Payment"
										>
											📅
										</button>
										{#if payment.requisition_id}
											<button 
												class="close-request-btn"
												on:click|stopPropagation={() => openRequestClosureModal(payment)}
												title="Close Request"
											>
												🔒
											</button>
										{/if}
									{/if}
								</td>
								<td>
									{#if isMasterAdmin}
										<button 
											class="delete-btn"
											on:click|stopPropagation={() => deleteExpensePayment(payment)}
											title="Delete Payment (Master Admin Only)"
										>
											🗑️
										</button>
									{/if}
								</td>
							</tr>
						{/each}
					{:else}
						<tr>
							<td colspan="12" class="empty-payments-row">
								<div class="empty-message">No expense payments scheduled for this date</div>
							</td>
						</tr>
					{/if}
				</tbody>
			</table>
		</div>
	</div>
</div>

<!-- Reschedule Modal (Simple Date Change) -->
{#if showRescheduleModal && reschedulingPayment}
	<div class="modal-overlay" on:click={() => showRescheduleModal = false}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">Reschedule Payment</div>
			<div class="modal-body">
				<div class="form-group">
					<label>Vendor: {reschedulingPayment.vendor_name}</label>
					<label>Amount: {formatCurrency(reschedulingPayment.final_bill_amount)}</label>
				</div>
				<div class="form-group">
					<label for="reschedule-date">New Date:</label>
					<input 
						type="date" 
						id="reschedule-date" 
						bind:value={rescheduleNewDate}
					/>
				</div>
			</div>
			<div class="modal-actions">
				<button class="btn btn-secondary" on:click={() => showRescheduleModal = false}>Cancel</button>
				<button class="btn btn-primary" on:click={handleReschedule}>Save</button>
			</div>
		</div>
	</div>
{/if}

<!-- Split/Reschedule Modal -->
{#if showSplitModal && splitPayment}
	<div class="modal-overlay" on:click={() => showSplitModal = false}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">Split Payment</div>
			<div class="modal-body">
				<div class="form-group">
					<label>Vendor: {splitPayment.vendor_name}</label>
					<label>Original Amount: {formatCurrency(splitPayment.final_bill_amount)}</label>
				</div>
				<div class="form-group">
					<label for="split-amount">Split Amount:</label>
					<input 
						type="number" 
						id="split-amount" 
						bind:value={splitAmount}
						min="0"
						max={splitPayment.final_bill_amount}
						step="0.01"
					/>
				</div>
				<div class="form-group">
					<label for="new-date">New Date for Split Amount:</label>
					<input 
						type="date" 
						id="new-date" 
						bind:value={newDateInput}
					/>
				</div>
			</div>
			<div class="modal-actions">
				<button class="btn btn-secondary" on:click={() => showSplitModal = false}>Cancel</button>
				<button class="btn btn-primary" on:click={handleSplitPayment}>Save</button>
			</div>
		</div>
	</div>
{/if}

<!-- Edit Payment Method Modal -->
{#if showPaymentMethodModal && editingPayment}
	<div class="modal-overlay" on:click={() => showPaymentMethodModal = false}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">Edit Payment Method</div>
			<div class="modal-body">
				<div class="form-group">
					<label for="payment-method">Payment Method:</label>
					<select id="payment-method" on:change={(e) => savePaymentMethod(e.target.value)}>
						<option value="Cash on Delivery" selected={editingPayment.payment_method === 'Cash on Delivery'}>Cash on Delivery</option>
						<option value="Bank Credit" selected={editingPayment.payment_method === 'Bank Credit'}>Bank Credit</option>
					</select>
				</div>
			</div>
			<div class="modal-actions">
				<button class="btn btn-secondary" on:click={() => showPaymentMethodModal = false}>Close</button>
			</div>
		</div>
	</div>
{/if}

<!-- Edit Amount Modal -->
{#if showEditAmountModal && editingAmountPayment}
	<div class="modal-overlay" on:click={() => showEditAmountModal = false}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">Edit Payment Amount</div>
			<div class="modal-body">
				<div class="form-group">
					<label>Original Amount: {formatCurrency(editingAmountPayment.final_bill_amount)}</label>
				</div>
				<div class="form-group">
					<label for="discount-amount">Discount Amount:</label>
					<input type="number" id="discount-amount" bind:value={editAmountForm.discountAmount} step="0.01" min="0" />
				</div>
				<div class="form-group">
					<label for="discount-notes">Discount Notes:</label>
					<textarea id="discount-notes" bind:value={editAmountForm.discountNotes}></textarea>
				</div>
				<div class="form-group">
					<label for="grr-amount">GRR Amount:</label>
					<input type="number" id="grr-amount" bind:value={editAmountForm.grrAmount} step="0.01" min="0" />
				</div>
				<div class="form-group">
					<label for="grr-ref">GRR Reference Number:</label>
					<input type="text" id="grr-ref" bind:value={editAmountForm.grrReferenceNumber} />
				</div>
				<div class="form-group">
					<label for="grr-notes">GRR Notes:</label>
					<textarea id="grr-notes" bind:value={editAmountForm.grrNotes}></textarea>
				</div>
				<div class="form-group">
					<label for="pri-amount">PRI Amount:</label>
					<input type="number" id="pri-amount" bind:value={editAmountForm.priAmount} step="0.01" min="0" />
				</div>
				<div class="form-group">
					<label for="pri-ref">PRI Reference Number:</label>
					<input type="text" id="pri-ref" bind:value={editAmountForm.priReferenceNumber} />
				</div>
				<div class="form-group">
					<label for="pri-notes">PRI Notes:</label>
					<textarea id="pri-notes" bind:value={editAmountForm.priNotes}></textarea>
				</div>
			</div>
			<div class="modal-actions">
				<button class="btn btn-secondary" on:click={() => showEditAmountModal = false}>Cancel</button>
				<button class="btn btn-primary" on:click={saveEditedAmount}>Save</button>
			</div>
		</div>
	</div>
{/if}

<!-- Expense Reschedule Modal -->
{#if showExpenseRescheduleModal && reschedulingExpensePayment}
	<div class="modal-overlay" on:click={() => showExpenseRescheduleModal = false}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">Reschedule Expense Payment</div>
			<div class="modal-body">
				<div class="form-group">
					<label>Original Amount: {formatCurrency(reschedulingExpensePayment.amount)}</label>
				</div>
				<div class="form-group">
					<label for="expense-split-amount">Split Amount (leave 0 to just reschedule):</label>
					<input 
						type="number" 
						id="expense-split-amount" 
						bind:value={expenseSplitAmount}
						min="0"
						max={reschedulingExpensePayment.amount}
						step="0.01"
					/>
				</div>
				<div class="form-group">
					<label for="expense-new-date">New Date:</label>
					<input 
						type="date" 
						id="expense-new-date" 
						bind:value={expenseNewDateInput}
					/>
				</div>
			</div>
			<div class="modal-actions">
				<button class="btn btn-secondary" on:click={() => showExpenseRescheduleModal = false}>Cancel</button>
				<button class="btn btn-primary" on:click={handleExpenseReschedule}>Save</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.monthly-manager-container {
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

	.priority-badge {
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
	}

	.priority-high {
		background: #fee2e2;
		color: #991b1b;
	}

	.priority-medium {
		background: #fef3c7;
		color: #92400e;
	}

	.priority-normal {
		background: #e0e7ff;
		color: #4338ca;
	}

	.status-badge {
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
	}

	.status-paid {
		background: #d1fae5;
		color: #065f46;
	}

	.status-scheduled {
		background: #fee2e2;
		color: #991b1b;
	}

	.payment-checkbox {
		width: 18px;
		height: 18px;
		cursor: pointer;
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

	.edit-payment-method-btn,
	.reschedule-btn,
	.split-btn,
	.edit-amount-btn,
	.close-request-btn,
	.delete-btn {
		background: none;
		border: none;
		cursor: pointer;
		font-size: 16px;
		padding: 4px;
		margin: 0 2px;
		transition: transform 0.2s;
	}

	.edit-payment-method-btn:hover,
	.reschedule-btn:hover,
	.split-btn:hover,
	.edit-amount-btn:hover,
	.close-request-btn:hover,
	.delete-btn:hover {
		transform: scale(1.2);
	}

	/* Modal styles */
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
		padding: 24px;
		border-radius: 8px;
		max-width: 500px;
		width: 90%;
		max-height: 80vh;
		overflow-y: auto;
	}

	.modal-header {
		font-size: 20px;
		font-weight: 600;
		margin-bottom: 16px;
		color: #1e293b;
	}

	.modal-body {
		margin-bottom: 20px;
	}

	.form-group {
		margin-bottom: 16px;
	}

	.form-group label {
		display: block;
		margin-bottom: 8px;
		font-weight: 500;
		color: #475569;
	}

	.form-group input,
	.form-group select,
	.form-group textarea {
		width: 100%;
		padding: 8px 12px;
		border: 1px solid #cbd5e1;
		border-radius: 6px;
		font-size: 14px;
	}

	.form-group textarea {
		min-height: 80px;
		resize: vertical;
	}

	.modal-actions {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
	}

	.btn {
		padding: 8px 16px;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-primary {
		background: #3b82f6;
		color: white;
	}

	.btn-primary:hover {
		background: #2563eb;
	}

	.btn-secondary {
		background: #e2e8f0;
		color: #475569;
	}

	.btn-secondary:hover {
		background: #cbd5e1;
	}

	/* Success Popup - Bottle/Container Style */
	.success-popup {
		position: fixed;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%) scale(0.8);
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		padding: 40px 50px;
		border-radius: 50px;
		box-shadow: 0 20px 60px rgba(16, 185, 129, 0.4);
		z-index: 999999;
		animation: popupBounce 0.5s ease-out forwards;
		min-width: 300px;
		text-align: center;
		border: 5px solid rgba(255, 255, 255, 0.3);
		pointer-events: none;
	}

	@keyframes popupBounce {
		0% {
			transform: translate(-50%, -50%) scale(0.5);
			opacity: 0;
		}
		60% {
			transform: translate(-50%, -50%) scale(1.1);
			opacity: 1;
		}
		100% {
			transform: translate(-50%, -50%) scale(1);
			opacity: 1;
		}
	}

	.success-popup-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 15px;
	}

	.success-icon {
		font-size: 60px;
		animation: checkmarkPop 0.6s ease-out;
	}

	@keyframes checkmarkPop {
		0%, 100% {
			transform: scale(1);
		}
		50% {
			transform: scale(1.2);
		}
	}

	.success-text {
		color: white;
		font-size: 20px;
		font-weight: 600;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.success-popup::before {
		content: '';
		position: absolute;
		top: -5px;
		left: 50%;
		transform: translateX(-50%);
		width: 60%;
		height: 30px;
		background: rgba(255, 255, 255, 0.2);
		border-radius: 50px 50px 0 0;
		box-shadow: inset 0 2px 10px rgba(255, 255, 255, 0.3);
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

	.inline-spinner {
		color: white;
		font-size: 14px;
		animation: pulse 1.5s ease-in-out infinite;
	}

	@keyframes pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.5; }
	}
</style>

{#if showSuccessPopup}
	<div class="success-popup">
		<div class="success-popup-content">
			<div class="success-icon">✓</div>
			<div class="success-text">{successMessage}</div>
		</div>
	</div>
{/if}

{#if showApproverListModal && pendingApprovalPayment}
	<ApproverListModal
		bind:isOpen={showApproverListModal}
		paymentData={pendingApprovalPayment}
		currentUserId={$currentUser?.id}
		currentUserName={$currentUser?.username || 'Unknown'}
		on:submitted={handleApprovalSubmitted}
		on:close={closeApproverModal}
	/>
{/if}
