<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import ApprovalMask from '$lib/components/desktop-interface/master/finance/ApprovalMask.svelte';
	import ApproverListModal from '$lib/components/desktop-interface/master/finance/ApproverListModal.svelte';
	import RequestClosureManager from '$lib/components/desktop-interface/master/finance/RequestClosureManager.svelte';
	import { iconUrlMap } from '$lib/stores/iconStore';

	$: currencySymbolUrl = $iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png';

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
	// Amounts render as a plain number; the currency symbol is the DB-managed icon
	function formatCurrency(amount) {
		if (amount === null || amount === undefined || isNaN(amount)) return '0.00';
		return Number(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
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

	// Get branch name + location as separate parts (rendered on two lines)
	function getBranchInfo(branchId) {
		const branch = branchId ? branchMap[branchId] : null;
		if (!branch) return { name: 'N/A', location: '' };
		return branch;
	}

	// Get branch name as a single line (name - location)
	function getBranchName(branchId) {
		const { name, location } = getBranchInfo(branchId);
		return location ? `${name} - ${location}` : name;
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
				branchMap[branch.id] = { name: branch.name_en || 'N/A', location: branch.location_en || '' };
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
			.select('id, amount, is_paid, paid_date, status, branch_id, payment_method, expense_category_name_en, expense_category_name_ar, description, schedule_type, due_date, co_user_name, created_by, requisition_id, requisition_number, vendor_name, creator:users!created_by(username)')
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
					bill_amount: splitAmount,
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
			discountAmount: payment.discount_amount || 0,
			discountNotes: payment.discount_notes || '',
			grrAmount: payment.grr_amount || 0,
			grrReferenceNumber: payment.grr_reference_number || '',
			grrNotes: payment.grr_notes || '',
			priAmount: payment.pri_amount || 0,
			priReferenceNumber: payment.pri_reference_number || '',
			priNotes: payment.pri_notes || ''
		};
		showEditAmountModal = true;
	}

	// Save edited amount
	async function saveEditedAmount() {
		if (!editingAmountPayment) return;

		try {
			// Calculate final amount based on original bill_amount minus all reductions
			const totalReduction = (editAmountForm.discountAmount || 0) + 
				(editAmountForm.grrAmount || 0) + (editAmountForm.priAmount || 0);
			
			// Use bill_amount as the base, not final_bill_amount
			const baseAmount = editingAmountPayment.bill_amount || editingAmountPayment.final_bill_amount;
			const newAmount = baseAmount - totalReduction;

			if (newAmount < 0) {
				alert('Total reduction cannot exceed bill amount');
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

	// Calculate final amount preview based on current form values
	$: calculatedFinalAmount = editingAmountPayment ? 
		(editingAmountPayment.bill_amount || editingAmountPayment.final_bill_amount) - 
		(editAmountForm.discountAmount || 0) - 
		(editAmountForm.grrAmount || 0) - 
		(editAmountForm.priAmount || 0) : 0;

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
		<div class="controls-row">
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
				<button 
					class="refresh-btn"
					on:click={loadData}
					disabled={isLoading}
					title="Refresh data for selected date"
				>
					{#if isLoading}
						<span class="inline-spinner">↻</span>
					{:else}
						🔄 Refresh
					{/if}
				</button>
			</div>

			<!-- Filters -->
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
					<span>Total: <img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(totalAmount)}</span>
					<span style="color: #059669;">Paid: <img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(paidAmount)}</span>
					<span style="color: #dc2626;">Unpaid: <img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(unpaidAmount)}</span>
				{/if}
			</div>
		</div>

		<div class="simple-table-container">
			<table class="simple-payments-table">
				<thead>
					<tr>
						<th class="serial-col">#</th>
						<th>Vendor</th>
						<th>Amount</th>
						<th>Bill Date</th>
						<th>Branch</th>
						<th>Status</th>
						<th>Mark Paid</th>
						<th>Approval</th>
						<th>Delete</th>
					</tr>
				</thead>
				<tbody>
					{#if filteredPayments.length > 0}
						{#each filteredPayments as payment, index}
							<tr>
								<td class="serial-col">{index + 1}</td>
								<td class="vendor-cell" title={payment.vendor_name || 'N/A'}>
									{payment.vendor_name || 'N/A'}
								</td>
								<td class="amount-cell">
									<div class="amount-value">
										<img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(payment.final_bill_amount)}
									</div>
									<div class="amount-method">
										<span class="payment-method">{payment.payment_method || 'Cash on Delivery'}</span>
									</div>
								</td>
								<td class="bill-date-cell">
									<div class="bill-date-value">{formatDate(payment.bill_date)}</div>
									<span class="bill-number-badge">#{payment.bill_number || 'N/A'}</span>
								</td>
								<td class="branch-cell">
									<div class="branch-name">{getBranchInfo(payment.branch_id).name}</div>
									{#if getBranchInfo(payment.branch_id).location}
										<div class="branch-location">{getBranchInfo(payment.branch_id).location}</div>
									{/if}
								</td>
								<td class="status-cell">
									<div class="status-value">
										<span class="status-badge {payment.is_paid ? 'status-paid' : 'status-scheduled'}">
											{payment.is_paid ? 'Paid' : 'Scheduled'}
										</span>
									</div>
									{#if !payment.is_paid && !needsApproval(payment)}
										<div class="row-actions">
											<button
												class="edit-payment-method-btn"
												on:click|stopPropagation={() => openPaymentMethodEdit(payment)}
												title="Edit payment method"
											>
												✏️
											</button>
											<button
												class="reschedule-btn"
												on:click|stopPropagation={() => openRescheduleModal(payment)}
												title="Reschedule Payment"
											>
												📅
											</button>
											<button
												class="split-btn"
												on:click|stopPropagation={() => openSplitModal(payment)}
												title="Split Payment"
											>
												✂️
											</button>
											<button
												class="edit-amount-btn"
												on:click|stopPropagation={() => openEditAmountModal(payment)}
												title="Edit Amount (Discount/GRR/PRI)"
											>
												💰
											</button>
										</div>
									{/if}
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
							<td colspan="9" class="empty-payments-row">
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
					<span>Total: <img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(totalExpenses)}</span>
					<span style="color: #059669;">Paid: <img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(paidExpenses)}</span>
					<span style="color: #dc2626;">Unpaid: <img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(unpaidExpenses)}</span>
				{/if}
			</div>
		</div>

		<div class="simple-table-container">
			<table class="simple-payments-table">
				<thead>
					<tr>
						<th class="serial-col">#</th>
						<th>Sub-Category</th>
						<th>Requester</th>
						<th>Branch</th>
						<th>Amount</th>
						<th>Paid Date</th>
						<th>Created By</th>
						<th>Description</th>
						<th>Status</th>
						<th>Mark Paid</th>
						<th>Delete</th>
					</tr>
				</thead>
				<tbody>
					{#if filteredExpensePayments.length > 0}
						{#each filteredExpensePayments as payment, index}
							<tr class={payment.is_paid ? 'paid-row' : ''}>
								<td class="serial-col">{index + 1}</td>
								<td style="text-align: left;">
									{#if payment.expense_category_name_en || payment.expense_category_name_ar}
										{payment.expense_category_name_en || payment.expense_category_name_ar}
									{:else}
										<span style="color: #f59e0b; font-style: italic;">Unknown - To Be Assigned</span>
									{/if}
								</td>
								<td style="text-align: left;">
									{#if payment.vendor_name}
										<span style="color: #8b5cf6;">🏢 {payment.vendor_name}</span>
									{:else if payment.co_user_name}
										<span style="color: #06b6d4;">👤 {payment.co_user_name}</span>
									{:else}
										<span style="color: #94a3b8;">{payment.creator?.username || '—'}</span>
									{/if}
								</td>
								<td class="branch-cell" style="text-align: left;">
									<div class="branch-name">{getBranchInfo(payment.branch_id).name}</div>
									{#if getBranchInfo(payment.branch_id).location}
										<div class="branch-location">{getBranchInfo(payment.branch_id).location}</div>
									{/if}
								</td>
								<td class="amount-cell">
									<div class="amount-value" style="color: {payment.is_paid ? '#14663f' : '#b91c1c'};">
										<img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(payment.amount || 0)}
									</div>
									<div class="amount-method">
										<span class="payment-method-badge">
											{payment.payment_method || 'Expense'}
										</span>
									</div>
								</td>
								<td class="bill-date-cell">
									<div class="bill-date-value">
										{#if payment.is_paid && payment.paid_date}
											<span style="color: #14663f; font-weight: 500;">{formatDate(payment.paid_date)}</span>
										{:else}
											<span style="color: var(--text-muted);">—</span>
										{/if}
									</div>
									<span class="bill-number-badge">#{payment.id || 'N/A'}</span>
								</td>
								<td>{payment.creator?.username || 'Unknown'}</td>
								<td style="text-align: left; max-width: 200px; overflow: hidden; text-overflow: ellipsis;" title="{payment.description || ''}">
									{payment.description || 'N/A'}
								</td>
								<td class="status-cell">
									<div class="status-value">
										<span class="status-badge {payment.is_paid ? 'status-paid' : 'status-scheduled'}">
											{payment.is_paid ? 'Paid' : payment.status || 'Pending'}
										</span>
									</div>
									{#if !payment.is_paid}
										<div class="row-actions">
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
										</div>
									{/if}
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
							<td colspan="11" class="empty-payments-row">
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
					<label>Amount: <img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(reschedulingPayment.final_bill_amount)}</label>
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
					<label>Original Amount: <img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(splitPayment.final_bill_amount)}</label>
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
					<label style="font-weight: 600; color: #1e293b;">Bill Amount (Base): <img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(editingAmountPayment.bill_amount || editingAmountPayment.final_bill_amount)}</label>
				</div>
				<hr style="margin: 16px 0; border: none; border-top: 1px solid #e2e8f0;">
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
				<hr style="margin: 16px 0; border: none; border-top: 1px solid #e2e8f0;">
				<div class="form-group">
					<label style="font-weight: 600; color: #059669; font-size: 16px;">Final Amount (Calculated): <img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(calculatedFinalAmount)}</label>
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
					<label>Original Amount: <img src={currencySymbolUrl} alt="" class="currency-icon" />{formatCurrency(reschedulingExpensePayment.amount)}</label>
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
	/* Glassmorphic light-green theme tokens */
	.monthly-manager-container {
		--glass-surface: rgba(255, 255, 255, 0.55);
		--glass-surface-strong: rgba(255, 255, 255, 0.72);
		--glass-border: rgba(134, 199, 160, 0.38);
		--glass-shadow: 0 8px 32px rgba(22, 101, 62, 0.12);
		--glass-blur: blur(14px) saturate(150%);
		--green-deep: #14663f;
		--green-mid: #16a34a;
		--green-soft: rgba(134, 239, 172, 0.28);
		--text-main: #14342a;
		--text-muted: #4b7a63;
		--page-bg: #e3f5ea;

		box-sizing: border-box;
		width: 100%;
		height: 100%;
		min-height: 100%;
		padding: 24px;
		background: var(--page-bg);
		color: var(--text-main);
		overflow-y: auto;
		overflow-x: hidden;
	}

	.monthly-manager-container :global(*) {
		box-sizing: border-box;
	}

	/* The shared window shell paints white behind the content; tint it the exact
	   same flat green so no seam or white edge shows through. Scoped with :has()
	   so only windows hosting this component are affected. */
	:global(.window-content:has(.monthly-manager-container)) {
		background: #e3f5ea;
	}

	.header-section {
		margin-bottom: 24px;
		padding: 16px;
		background: var(--glass-surface);
		backdrop-filter: var(--glass-blur);
		-webkit-backdrop-filter: var(--glass-blur);
		border: 1px solid var(--glass-border);
		border-radius: 14px;
		box-shadow: var(--glass-shadow);
	}

	/* Single row: date pickers + refresh + branch/payment-method filters */
	.controls-row {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 10px 18px;
	}

	.month-selector {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.month-selector label {
		font-weight: 600;
		color: var(--green-deep);
		font-size: 14px;
		white-space: nowrap;
	}

	.month-selector select {
		padding: 8px 12px;
		border: 1px solid var(--glass-border);
		border-radius: 8px;
		background: var(--glass-surface-strong);
		backdrop-filter: var(--glass-blur);
		-webkit-backdrop-filter: var(--glass-blur);
		font-size: 14px;
		color: var(--text-main);
		cursor: pointer;
		outline: none;
		transition: border-color 0.2s, box-shadow 0.2s;
	}

	.month-selector select:hover {
		border-color: var(--green-mid);
	}

	.month-selector select:focus {
		border-color: var(--green-mid);
		box-shadow: 0 0 0 3px rgba(22, 163, 74, 0.15);
	}

	.refresh-btn {
		padding: 8px 16px;
		background: linear-gradient(135deg, rgba(52, 211, 153, 0.92) 0%, rgba(22, 163, 74, 0.92) 100%);
		color: white;
		border: 1px solid rgba(255, 255, 255, 0.35);
		border-radius: 8px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 6px;
		box-shadow: 0 4px 12px rgba(22, 163, 74, 0.25);
	}

	.refresh-btn:hover:not(:disabled) {
		background: linear-gradient(135deg, rgba(22, 163, 74, 0.95) 0%, rgba(21, 128, 61, 0.95) 100%);
		box-shadow: 0 6px 16px rgba(22, 163, 74, 0.35);
		transform: translateY(-1px);
	}

	.refresh-btn:active:not(:disabled) {
		transform: translateY(0);
		box-shadow: 0 4px 12px rgba(22, 163, 74, 0.25);
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.filter-group {
		display: flex;
		align-items: center;
		gap: 8px;
		min-width: 0;
	}

	.filter-group label {
		font-size: 14px;
		color: var(--text-muted);
		font-weight: 500;
		white-space: nowrap;
	}

	.filter-group select {
		max-width: 220px;
		padding: 6px 10px;
		border: 1px solid var(--glass-border);
		border-radius: 6px;
		background: var(--glass-surface-strong);
		backdrop-filter: var(--glass-blur);
		-webkit-backdrop-filter: var(--glass-blur);
		font-size: 13px;
		color: var(--text-main);
		cursor: pointer;
	}

	.payment-section {
		margin-bottom: 24px;
		background: var(--glass-surface);
		backdrop-filter: var(--glass-blur);
		-webkit-backdrop-filter: var(--glass-blur);
		border: 1px solid var(--glass-border);
		border-radius: 14px;
		box-shadow: var(--glass-shadow);
		overflow: hidden;
	}

	.section-header {
		padding: 16px;
		background: linear-gradient(135deg, rgba(52, 211, 153, 0.85) 0%, rgba(16, 133, 88, 0.85) 100%);
		backdrop-filter: var(--glass-blur);
		-webkit-backdrop-filter: var(--glass-blur);
		border-bottom: 1px solid var(--glass-border);
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
		padding: 4px 10px;
		background: rgba(255, 255, 255, 0.25);
		border: 1px solid rgba(255, 255, 255, 0.35);
		border-radius: 999px;
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
		background: rgba(220, 245, 230, 0.85);
		backdrop-filter: var(--glass-blur);
		-webkit-backdrop-filter: var(--glass-blur);
	}

	/* Borders on a sticky thead are dropped under border-collapse: collapse,
	   so the header's column/bottom lines are drawn with inset shadows. */
	.simple-payments-table th {
		padding: 12px 8px;
		text-align: left;
		font-weight: 600;
		color: var(--green-deep);
		box-shadow:
			inset -1px 0 0 rgba(134, 199, 160, 0.45),
			inset 0 -2px 0 rgba(134, 199, 160, 0.55);
	}

	.simple-payments-table td {
		padding: 12px 8px;
		border-bottom: 1px solid rgba(134, 199, 160, 0.22);
		border-right: 1px solid rgba(134, 199, 160, 0.22);
		color: var(--text-main);
	}

	/* No trailing line on the last column */
	.simple-payments-table td:last-child {
		border-right: none;
	}

	.simple-payments-table th:last-child {
		box-shadow: inset 0 -2px 0 rgba(134, 199, 160, 0.55);
	}

	.simple-payments-table tbody tr:hover {
		background: var(--green-soft);
	}

	.bill-number-badge {
		background: rgba(209, 250, 229, 0.85);
		color: #0f5132;
		border: 1px solid rgba(134, 199, 160, 0.45);
		padding: 4px 8px;
		border-radius: 6px;
		font-weight: 600;
		font-size: 11px;
	}

	.currency-icon {
		height: 0.72em;
		width: auto;
		display: inline-block;
		vertical-align: baseline;
		opacity: 0.85;
		margin-inline-end: 3px;
	}

	.simple-payments-table .serial-col {
		width: 44px;
		text-align: center;
		color: var(--text-muted);
		font-weight: 600;
	}

	.vendor-cell {
		text-align: left;
		font-weight: 500;
		max-width: 190px;
		white-space: normal;
		overflow-wrap: anywhere;
		line-height: 1.35;
	}

	.amount-cell {
		text-align: right;
		white-space: nowrap;
	}

	.amount-cell .amount-value {
		font-weight: 700;
		color: var(--green-deep);
		margin-bottom: 3px;
	}

	.amount-cell .amount-method {
		margin-bottom: 0;
	}

	.status-cell {
		white-space: nowrap;
	}

	.status-cell .status-value {
		display: block;
	}

	/* Card holding the 4 row actions (edit method / reschedule / split / edit amount) */
	.status-cell .row-actions {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 2px;
		margin-top: 6px;
		padding: 2px 5px;
		background: var(--glass-surface-strong);
		backdrop-filter: var(--glass-blur);
		-webkit-backdrop-filter: var(--glass-blur);
		border: 1px solid var(--glass-border);
		border-radius: 8px;
		box-shadow: 0 2px 6px rgba(22, 101, 62, 0.1);
	}

	.status-cell .row-actions button {
		font-size: 14px;
		padding: 2px;
		margin: 0;
	}

	.branch-cell {
		white-space: nowrap;
	}

	.branch-cell .branch-name {
		font-weight: 500;
	}

	.branch-cell .branch-location {
		font-size: 11px;
		color: var(--text-muted);
		margin-top: 2px;
	}

	.bill-date-cell {
		white-space: nowrap;
	}

	.bill-date-cell .bill-date-value {
		margin-bottom: 3px;
	}

	.bill-date-cell .bill-number-badge {
		display: inline-block;
		padding: 2px 6px;
	}

	.payment-method {
		display: inline-block;
		background: rgba(236, 252, 243, 0.8);
		color: #15803d;
		border: 1px solid rgba(134, 199, 160, 0.45);
		padding: 4px 8px;
		border-radius: 999px;
		font-size: 11px;
		font-weight: 500;
	}

	.payment-method-badge {
		background: rgba(236, 252, 243, 0.8);
		color: #15803d;
		border: 1px solid rgba(134, 199, 160, 0.45);
		font-size: 11px;
		padding: 4px 8px;
		border-radius: 999px;
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
		padding: 4px 10px;
		border-radius: 999px;
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
		border: 1px solid transparent;
	}

	.status-paid {
		background: rgba(167, 243, 208, 0.75);
		border-color: rgba(16, 185, 129, 0.4);
		color: #065f46;
	}

	.status-scheduled {
		background: rgba(254, 226, 226, 0.75);
		border-color: rgba(239, 68, 68, 0.35);
		color: #991b1b;
	}

	.payment-checkbox {
		width: 18px;
		height: 18px;
		cursor: pointer;
		accent-color: var(--green-mid);
	}

	.empty-payments-row {
		text-align: center;
		padding: 40px 20px !important;
	}

	.empty-message {
		color: var(--text-muted);
		font-size: 14px;
		font-style: italic;
	}

	.paid-row {
		background: rgba(240, 253, 244, 0.7);
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
		background: rgba(12, 46, 32, 0.35);
		backdrop-filter: blur(6px);
		-webkit-backdrop-filter: blur(6px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.modal-content {
		background: linear-gradient(160deg, rgba(255, 255, 255, 0.85) 0%, rgba(236, 252, 243, 0.85) 100%);
		backdrop-filter: blur(18px) saturate(150%);
		-webkit-backdrop-filter: blur(18px) saturate(150%);
		border: 1px solid rgba(134, 199, 160, 0.45);
		padding: 24px;
		border-radius: 16px;
		box-shadow: 0 20px 50px rgba(20, 83, 45, 0.25);
		max-width: 500px;
		width: 90%;
		max-height: 80vh;
		overflow-y: auto;
	}

	.modal-header {
		font-size: 20px;
		font-weight: 600;
		margin-bottom: 16px;
		color: #14663f;
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
		color: #2f6b4f;
	}

	.form-group input,
	.form-group select,
	.form-group textarea {
		width: 100%;
		padding: 8px 12px;
		border: 1px solid rgba(134, 199, 160, 0.55);
		border-radius: 8px;
		background: rgba(255, 255, 255, 0.75);
		color: #14342a;
		font-size: 14px;
		outline: none;
		transition: border-color 0.2s, box-shadow 0.2s;
	}

	.form-group input:focus,
	.form-group select:focus,
	.form-group textarea:focus {
		border-color: #16a34a;
		box-shadow: 0 0 0 3px rgba(22, 163, 74, 0.15);
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
		border: 1px solid transparent;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-primary {
		background: linear-gradient(135deg, rgba(52, 211, 153, 0.95) 0%, rgba(22, 163, 74, 0.95) 100%);
		border-color: rgba(255, 255, 255, 0.35);
		color: white;
		box-shadow: 0 4px 12px rgba(22, 163, 74, 0.25);
	}

	.btn-primary:hover {
		background: linear-gradient(135deg, rgba(22, 163, 74, 0.95) 0%, rgba(21, 128, 61, 0.95) 100%);
	}

	.btn-secondary {
		background: rgba(255, 255, 255, 0.6);
		border-color: rgba(134, 199, 160, 0.5);
		color: #2f6b4f;
	}

	.btn-secondary:hover {
		background: rgba(236, 252, 243, 0.9);
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
		background: rgba(233, 248, 239, 0.82);
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		z-index: 9999;
		backdrop-filter: blur(10px) saturate(150%);
		-webkit-backdrop-filter: blur(10px) saturate(150%);
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
		border: 6px solid rgba(134, 199, 160, 0.35);
		border-top-color: #16a34a;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.loading-text {
		font-size: 18px;
		color: #14663f;
		font-weight: 600;
	}

	.progress-bar {
		width: 300px;
		height: 8px;
		background: rgba(255, 255, 255, 0.6);
		border: 1px solid rgba(134, 199, 160, 0.45);
		border-radius: 10px;
		overflow: hidden;
	}

	.progress-fill {
		height: 100%;
		background: linear-gradient(90deg, #34d399 0%, #16a34a 100%);
		transition: width 0.3s ease;
		border-radius: 10px;
	}

	.progress-text {
		font-size: 16px;
		color: #4b7a63;
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
