<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import RequestClosureManager from '$lib/components/desktop-interface/master/finance/RequestClosureManager.svelte';
	import ApprovalMask from '$lib/components/desktop-interface/master/finance/ApprovalMask.svelte';
	import ApproverListModal from '$lib/components/desktop-interface/master/finance/ApproverListModal.svelte';

	// Helper function to format date as dd/mm/yyyy
	function formatDate(dateInput) {
		if (!dateInput) return 'N/A';
		try {
			const date = dateInput instanceof Date ? dateInput : new Date(dateInput);
			// Check if date is valid
			if (isNaN(date.getTime())) return 'N/A';
			const day = String(date.getDate()).padStart(2, '0');
			const month = String(date.getMonth() + 1).padStart(2, '0');
			const year = date.getFullYear();
			return `${day}/${month}/${year}`;
		} catch (error) {
			return 'N/A';
		}
	}

	// Props passed from parent
	export let monthData = null;
	export let onRefresh = null; // Window refresh callback
	export let setRefreshCallback = null; // Function to register our refresh function
	export let parentRefreshCallback = null; // Callback to refresh parent window

	// Component state
	let monthDetailData = [];
	let scheduledPayments = [];
	let expenseSchedulerPayments = []; // For expense scheduler payments
	let refreshing = false;
	let monthDetailsElement;
	let scrollableContainer; // Reference to the scrollable content section
	let selectedDate = null; // Track which date is currently selected/highlighted
	
	// Check if current user is Master Admin
	$: isMasterAdmin = $currentUser?.isMasterAdmin;
	
	// Filter state
	let filterBranch = '';
	let filterPaymentMethod = '';
	let branches = [];
	let branchMap = {}; // Map of branch_id to branch name
	let paymentMethods = [];
	
	// Drag and drop state
	let draggedPayment = null;
	let showSplitModal = false;
	let splitPayment = null;
	let splitAmount = 0;
	let remainingAmount = 0;
	let newDateInput = '';

	// Edit payment method state
	let editingPaymentId = null;
	let showPaymentMethodModal = false;
	let editingPayment = null;

	// Expense scheduler state
	let showExpenseRescheduleModal = false;
	let reschedulingExpensePayment = null;
	let expenseNewDateInput = '';
	let expenseSplitAmount = 0;

	// Edit amount state
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

	// Approval system state
	let showApproverListModal = false;
	let pendingApprovalPayment = null;

	// Initialize component
	// (Initialization moved to loadInitialData function called from main onMount)

	// Get branch name by ID from branchMap
	function getBranchName(branchId) {
		if (!branchId) return 'N/A';
		return branchMap[branchId] || 'N/A';
	}

	// Reactive statement to regenerate data when scheduledPayments change
	$: if (scheduledPayments.length >= 0 && monthData) {
		generateAllDaysOfMonth(monthData);
	}

	// Reactive statement to regenerate data when expense scheduler payments change
	$: if (expenseSchedulerPayments.length >= 0 && monthData) {
		generateAllDaysOfMonth(monthData);
	}

	// Reload expense scheduler when month changes
	$: if (monthData && (monthData.month !== undefined || monthData.year !== undefined)) {
		loadExpenseSchedulerPayments();
	}

	// Reactive statement to filter payments when filter changes
	$: filteredPayments = scheduledPayments.filter(payment => {
		if (filterBranch && payment.branch_id != filterBranch) return false;
		if (filterPaymentMethod && payment.payment_method !== filterPaymentMethod) return false;
		return true;
	});

	// Reactive statement to filter expense scheduler payments
	$: filteredExpensePayments = expenseSchedulerPayments.filter(payment => {
		if (filterBranch && payment.branch_id != filterBranch) return false;
		return true;
	});

	// Regenerate data when filters change
	$: if (monthData && (filterBranch !== undefined || filterPaymentMethod !== undefined)) {
		generateAllDaysOfMonth(monthData);
	}

	// Calculate totals by payment method for the current month
	$: totalsByPaymentMethod = filteredPayments.reduce((acc, payment) => {
		if (!payment.due_date) return acc;
		
		// Parse date manually to avoid timezone issues
		const [year, month, day] = payment.due_date.split('-').map(Number);
		const paymentDate = new Date(year, month - 1, day); // month is 0-indexed
		const currentMonth = monthData?.month;
		const currentYear = monthData?.year;
		
		// Only include payments from the current month/year
		if (currentMonth !== undefined && currentYear !== undefined && 
			paymentDate.getMonth() === currentMonth && paymentDate.getFullYear() === currentYear) {
			
			const method = payment.payment_method || 'Unknown';
			const amount = payment.final_bill_amount || 0;
			
			if (!acc[method]) {
				acc[method] = 0;
			}
			acc[method] += amount;
		}
		
		return acc;
	}, {});

	// Calculate total paid and unpaid amounts for the current month only
	$: {
		let totalScheduled = 0;
		let totalPaid = 0;
		let totalUnpaid = 0;
		
		// Calculate from scheduled payments for the current month
		const currentMonth = monthData?.month;
		const currentYear = monthData?.year;
		
		if (filteredPayments && currentMonth !== undefined && currentYear !== undefined) {
			filteredPayments.forEach(payment => {
				if (!payment.due_date) return;
				
				// Parse date manually to avoid timezone issues
				const [year, month, day] = payment.due_date.split('-').map(Number);
				const paymentDate = new Date(year, month - 1, day); // month is 0-indexed
				
				// Check if payment is in the current month/year
				if (paymentDate.getMonth() === currentMonth && paymentDate.getFullYear() === currentYear) {
					const amount = payment.final_bill_amount || 0;
					totalScheduled += amount;
					
					// Check if payment is paid (is_paid === true, not just truthy)
					if (payment.is_paid === true) {
						totalPaid += amount;
					} else {
						totalUnpaid += amount;
					}
				}
			});
		}
		
		totalPaidAmount = totalPaid;
		totalUnpaidAmount = totalUnpaid;
		
		// Update monthData.total with the calculated total for this month
		if (monthData) {
			monthData.total = totalScheduled;
		}
		
		// Debug logging
		console.log('Month totals:', { totalScheduled, totalPaid, totalUnpaid, monthTotal: monthData?.total });
	}

	// Calculate expense scheduler totals for the current month
	$: {
		let expenseScheduled = 0;
		let expensePaid = 0;
		let expenseUnpaid = 0;

		console.log('Calculating expense totals from:', filteredExpensePayments);

		if (filteredExpensePayments && filteredExpensePayments.length > 0) {
			filteredExpensePayments.forEach(payment => {
				const amount = payment.amount || 0;
				console.log('Processing expense payment:', { 
					id: payment.id, 
					amount, 
					is_paid: payment.is_paid,
					due_date: payment.due_date 
				});
				
				expenseScheduled += amount;
				
				if (payment.is_paid === true) {
					expensePaid += amount;
				} else {
					expenseUnpaid += amount;
				}
			});
		}

		totalExpensesScheduled = expenseScheduled;
		totalExpensesPaid = expensePaid;
		totalExpensesUnpaid = expenseUnpaid;
		
		console.log('Expense totals calculated:', { 
			totalExpensesScheduled, 
			totalExpensesPaid, 
			totalExpensesUnpaid 
		});
	}

	let totalPaidAmount = 0;
	let totalUnpaidAmount = 0;
	
	// Expense scheduler totals
	let totalExpensesScheduled = 0;
	let totalExpensesPaid = 0;
	let totalExpensesUnpaid = 0;

	// Load all branches from database
	async function loadBranches() {
		try {
			// Load branches with pagination to handle large datasets
			let allData = [];
			let from = 0;
			const pageSize = 1000;
			let hasMore = true;

			while (hasMore) {
				const { data: pageData, error } = await supabase
					.from('branches')
					.select('id, name_en, name_ar')
					.eq('is_active', true)
					.order('name_en', { ascending: true })
					.range(from, from + pageSize - 1);

				if (error) {
					console.error('Error loading branches:', error);
					return;
				}

				if (pageData && pageData.length > 0) {
					allData = [...allData, ...pageData];
					from += pageSize;
					
					if (pageData.length < pageSize) {
						hasMore = false;
					}
				} else {
					hasMore = false;
				}
			}

			branches = allData || [];
			
			// Build branch ID to name mapping
			branchMap = {};
			branches.forEach(branch => {
				branchMap[branch.id] = branch.name_en;
			});
			
			console.log('Loaded branches:', branches);
			console.log('Branch map:', branchMap);
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	// Load all payment methods (you can customize this list)
	async function loadPaymentMethods() {
		try {
			// Get unique payment methods from vendor_payment_schedule with pagination
			let allData = [];
			let from = 0;
			const pageSize = 1000;
			let hasMore = true;

			while (hasMore) {
				const { data: pageData, error } = await supabase
					.from('vendor_payment_schedule')
					.select('payment_method')
					.range(from, from + pageSize - 1);

				if (error) {
					console.error('Error loading payment methods:', error);
					// Fallback to default list
					paymentMethods = ['Cash on Delivery', 'Bank Credit'];
					return;
				}

				if (pageData && pageData.length > 0) {
					allData = [...allData, ...pageData];
					from += pageSize;
					
					if (pageData.length < pageSize) {
						hasMore = false;
					}
				} else {
					hasMore = false;
				}
			}

			const data = allData;

			// Extract unique payment methods
			const methodSet = new Set();
			data?.forEach(payment => {
				if (payment.payment_method && payment.payment_method.trim() !== '') {
					methodSet.add(payment.payment_method.trim());
				}
			});

			paymentMethods = Array.from(methodSet).sort();
			console.log('Loaded payment methods:', paymentMethods);
		} catch (error) {
			console.error('Error loading payment methods:', error);
			// Fallback to default list
			paymentMethods = ['Cash on Delivery', 'Bank Credit'];
		}
	}

	// Extract unique branches and payment methods for filters
	function extractFilterOptions() {
		const branchSet = new Set();
		const paymentMethodSet = new Set();
		
		scheduledPayments.forEach(payment => {
			if (payment.branch_name && payment.branch_name.trim() !== '') {
				branchSet.add(payment.branch_name.trim());
			}
			if (payment.payment_method && payment.payment_method.trim() !== '') {
				paymentMethodSet.add(payment.payment_method.trim());
			}
		});
		
		console.log('Extracted branches from payments:', Array.from(branchSet));
		console.log('Extracted payment methods from payments:', Array.from(paymentMethodSet));
	}

	// Load scheduled payments from database
	async function loadScheduledPayments() {
		try {
			if (!monthData) {
				console.warn('No monthData available, skipping payment load');
				return;
			}

			// Calculate date range for current month only
			const startDate = new Date(monthData.year, monthData.month, 1);
			const endDate = new Date(monthData.year, monthData.month + 1, 0);
			const startDateStr = startDate.toISOString().split('T')[0];
			const endDateStr = endDate.toISOString().split('T')[0];

			// Fetch only current month records (much faster)
			const { data: scheduleData, error } = await supabase
				.from('vendor_payment_schedule')
				.select(`
					*,
					receiving_records!receiving_record_id (
						accountant_user_id,
						bill_number,
						vendor_id,
						original_bill_url
					)
				`)
				.gte('due_date', startDateStr)
				.lte('due_date', endDateStr)
				.order('due_date', { ascending: true });

			if (error) {
				console.error('Error loading scheduled payments:', error);
				return;
			}

			const payments = scheduleData || [];

			// Get unique vendor IDs to fetch priorities (lazy load)
			const vendorPriorities = {};
			const uniqueVendorIds = [...new Set(payments.map(p => p.vendor_id).filter(Boolean))];
			
			if (uniqueVendorIds.length > 0) {
				const { data: vendorsData, error: vendorError } = await supabase
					.from('vendors')
					.select('erp_vendor_id, branch_id, payment_priority')
					.in('erp_vendor_id', uniqueVendorIds);
				
				if (!vendorError && vendorsData) {
					// Build vendor priorities map
					vendorsData.forEach(v => {
						const key = `${v.erp_vendor_id}-${v.branch_id}`;
						vendorPriorities[key] = v.payment_priority || 'Normal';
					});
				}
			}

			// Assign priorities to payments
			scheduledPayments = payments.map(payment => ({
				...payment,
				payment_priority: vendorPriorities[`${payment.vendor_id}-${payment.branch_id}`] || 'Normal'
			}));
		} catch (error) {
			console.error('Error loading scheduled payments:', error);
		}
	}

	// Load expense scheduler payments for the current month (OPTIMIZED)
	async function loadExpenseSchedulerPayments() {
		try {
			if (!monthData || monthData.month === undefined || monthData.year === undefined) {
				return;
			}
			
			const startDate = new Date(monthData.year, monthData.month, 1);
			const endDate = new Date(monthData.year, monthData.month + 1, 0);
			
			// Format dates for query (YYYY-MM-DD)
			const startDateStr = `${monthData.year}-${String(monthData.month + 1).padStart(2, '0')}-01`;
			const endDateStr = `${monthData.year}-${String(monthData.month + 1).padStart(2, '0')}-${String(endDate.getDate()).padStart(2, '0')}`;
			
			// Load only current month (no pagination needed for one month)
			const { data: pageData, error } = await supabase
				.from('expense_scheduler')
				.select(`
						*,
						creator:users!created_by (
							username
						),
						requisition:expense_requisitions (
							requester_name
						)
					`)
					.gte('due_date', startDateStr)
					.lte('due_date', endDateStr)
					.order('due_date', { ascending: true });

			if (error) {
				console.error('Error loading expense scheduler payments:', error);
				return;
			}

			const data = pageData || [];
			
			// Flatten the data and filter out completed/written-off requisitions
			expenseSchedulerPayments = (data || [])
				.map(payment => ({
					...payment,
					requester_name: payment.requisition?.requester_name || null
				}))
				.filter(payment => {
					// Hide expense_requisition entries that are fully paid/written-off (amount = 0 or is_paid = true)
					if (payment.schedule_type === 'expense_requisition' && (payment.amount === 0 || payment.is_paid === true)) {
						return false;
					}
					return true;
				});
		} catch (error) {
			console.error('❌ Exception loading expense scheduler payments:', error);
		}
	}

	// Mark expense scheduler payment as paid
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
					updated_at: new Date().toISOString()
				})
				.eq('id', paymentId);

			if (error) throw error;

			alert('Payment marked as paid successfully');
			await loadExpenseSchedulerPayments();
			generateAllDaysOfMonth(monthData);
		} catch (error) {
			console.error('Error marking expense as paid:', error);
			alert('Failed to mark payment as paid');
		}
	}

	// Unmark expense scheduler payment as paid
	async function unmarkExpenseAsPaid(paymentId) {
		if (!confirm('Unmark this expense payment as paid?')) return;

		try {
			const { error } = await supabase
				.from('expense_scheduler')
				.update({ 
					is_paid: false, 
					paid_date: null,
					status: 'pending',
					updated_by: $currentUser?.id,
					updated_at: new Date().toISOString()
				})
				.eq('id', paymentId);

			if (error) throw error;

			alert('Payment unmarked as paid successfully');
			await loadExpenseSchedulerPayments();
			generateAllDaysOfMonth(monthData);
		} catch (error) {
			console.error('Error unmarking expense as paid:', error);
			alert('Failed to unmark payment');
		}
	}

	// Open reschedule modal for expense payment
	function openExpenseRescheduleModal(payment) {
		reschedulingExpensePayment = payment;
		expenseNewDateInput = payment.due_date || '';
		expenseSplitAmount = 0;
		showExpenseRescheduleModal = true;
	}

	// Cancel expense reschedule
	function cancelExpenseReschedule() {
		showExpenseRescheduleModal = false;
		reschedulingExpensePayment = null;
		expenseNewDateInput = '';
		expenseSplitAmount = 0;
	}

	// Open request closure modal
	function openRequestClosureModal(payment) {
		// Open as a window using the window manager
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

	// Handle full expense payment move
	async function handleExpenseFullMove() {
		if (!expenseNewDateInput) {
			alert('Please select a new date');
			return;
		}

		if (!confirm('Move the entire payment to the new date?')) return;

		try {
			const { error } = await supabase
				.from('expense_scheduler')
				.update({ 
					due_date: expenseNewDateInput,
					updated_by: $currentUser?.id,
					updated_at: new Date().toISOString()
				})
				.eq('id', reschedulingExpensePayment.id);

			if (error) throw error;

			alert('Payment moved successfully');
			cancelExpenseReschedule();
			await loadExpenseSchedulerPayments();
			generateAllDaysOfMonth(monthData);
		} catch (error) {
			console.error('Error moving expense payment:', error);
			alert('Failed to move payment');
		}
	}

	// Handle expense payment split and move
	async function handleExpenseSplitMove() {
		if (!expenseNewDateInput) {
			alert('Please select a new date');
			return;
		}

		if (expenseSplitAmount <= 0 || expenseSplitAmount >= parseFloat(reschedulingExpensePayment.amount)) {
			alert('Please enter a valid split amount');
			return;
		}

		if (!confirm(`Split payment:\n- Move ${formatCurrency(expenseSplitAmount)} to ${expenseNewDateInput}\n- Keep ${formatCurrency(parseFloat(reschedulingExpensePayment.amount) - expenseSplitAmount)} on ${reschedulingExpensePayment.due_date}`)) {
			return;
		}

		try {
			// Update existing payment with reduced amount
			const { error: updateError } = await supabase
				.from('expense_scheduler')
				.update({ 
					amount: parseFloat(reschedulingExpensePayment.amount) - expenseSplitAmount,
					updated_by: $currentUser?.id,
					updated_at: new Date().toISOString()
				})
				.eq('id', reschedulingExpensePayment.id);

			if (updateError) throw updateError;

			// Create new payment entry for split amount
			const { error: insertError } = await supabase
				.from('expense_scheduler')
				.insert({
					branch_id: reschedulingExpensePayment.branch_id,
					branch_name: reschedulingExpensePayment.branch_name,
					expense_category_id: reschedulingExpensePayment.expense_category_id,
					expense_category_name_en: reschedulingExpensePayment.expense_category_name_en,
					expense_category_name_ar: reschedulingExpensePayment.expense_category_name_ar,
					requisition_id: reschedulingExpensePayment.requisition_id,
					requisition_number: reschedulingExpensePayment.requisition_number,
					co_user_id: reschedulingExpensePayment.co_user_id,
					co_user_name: reschedulingExpensePayment.co_user_name,
					bill_type: reschedulingExpensePayment.bill_type,
					bill_number: reschedulingExpensePayment.bill_number,
					bill_date: reschedulingExpensePayment.bill_date,
					payment_method: reschedulingExpensePayment.payment_method,
					due_date: expenseNewDateInput,
					credit_period: reschedulingExpensePayment.credit_period,
					amount: expenseSplitAmount,
					bill_file_url: reschedulingExpensePayment.bill_file_url,
					bank_name: reschedulingExpensePayment.bank_name,
					iban: reschedulingExpensePayment.iban,
					description: `Split from payment #${reschedulingExpensePayment.id} - ${reschedulingExpensePayment.description || ''}`,
					notes: reschedulingExpensePayment.notes,
					is_paid: false,
					status: 'pending',
					created_by: $currentUser?.id
				});

			if (insertError) throw insertError;

			alert('Payment split successfully');
			cancelExpenseReschedule();
			await loadExpenseSchedulerPayments();
			generateAllDaysOfMonth(monthData);
		} catch (error) {
			console.error('Error splitting expense payment:', error);
			alert('Failed to split payment');
		}
	}

	// Auto-process Cash on Delivery payments
	// REMOVED: Database trigger now handles everything automatically on INSERT
	// This function is kept for backward compatibility but does nothing
	// Migration 70 trigger auto-marks COD as paid during INSERT
	async function processCashOnDeliveryPayments() {
		// No longer needed - database trigger handles COD auto-payment on INSERT
		// See migration 70_fix_cash_on_delivery_auto_payment.sql
		console.log('✅ Cash-on-delivery auto-payment now handled by database trigger (Migration 70)');
	}

	// Generate all days of the month (including days without payments)
	function generateAllDaysOfMonth(monthData) {
		const daysInMonth = new Date(monthData.year, monthData.month + 1, 0).getDate();
		monthDetailData = [];

		// Get today's date for comparison
		const today = new Date();
		const todayDate = today.getDate();
		const todayMonth = today.getMonth();
		const todayYear = today.getFullYear();

		// Create data for each day of the month
		for (let day = 1; day <= daysInMonth; day++) {
			const dayDate = new Date(monthData.year, monthData.month, day);
			const isToday = day === todayDate && monthData.month === todayMonth && monthData.year === todayYear;
			
			const uniqueId = `day-${dayDate.getFullYear()}-${String(dayDate.getMonth() + 1).padStart(2, '0')}-${String(dayDate.getDate()).padStart(2, '0')}`;
			console.log(`📅 Day ${day}: ID = ${uniqueId}`);
			
			const dayInfo = {
				id: uniqueId, // Unique ID
				date: day,
				dayName: dayDate.toLocaleDateString('en-US', { weekday: 'short' }),
				fullDate: dayDate,
				dateString: dayDate.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }),
				isToday: isToday,
				payments: [],
				paymentsByVendor: {},
				totalAmount: 0,
				unpaidAmount: 0,
				paymentCount: 0,
				isFullyPaid: true,
				expenseCount: 0,
				expenseScheduledAmount: 0,
				expenseUnpaidAmount: 0,
				vendorCount: 0,
				vendorScheduledAmount: 0,
				vendorUnpaidAmount: 0
			};

			// Find payments for this specific day (use filteredPayments)
			const paymentsToUse = filteredPayments || scheduledPayments;
			paymentsToUse.forEach(payment => {
				if (!payment.due_date) return; // Skip if no date available
				
				// Parse date manually to avoid timezone issues
				const [year, month, day] = payment.due_date.split('-').map(Number);
				const paymentDate = new Date(year, month - 1, day); // month is 0-indexed
				
				if (paymentDate.toDateString() === dayDate.toDateString()) {
					// Log December 10 matches
					if (day === 10 && month === 12 && year === 2025) {
						console.log('✅ Dec 10 payment match:', {
							vendor: payment.vendor_name,
							amount: payment.final_bill_amount,
							due_date: payment.due_date
						});
					}
					dayInfo.payments.push(payment);
					dayInfo.totalAmount += (payment.final_bill_amount || 0);
					dayInfo.paymentCount++;
					
					// Track vendor-specific counts
					dayInfo.vendorCount++;
					dayInfo.vendorScheduledAmount += (payment.final_bill_amount || 0);

					// Calculate unpaid amount
					if (!payment.is_paid) {
						dayInfo.vendorUnpaidAmount += (payment.final_bill_amount || 0);
						dayInfo.unpaidAmount += (payment.final_bill_amount || 0);
						dayInfo.isFullyPaid = false;
					}

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

		// Also check expense scheduler payments for this day
		if (filteredExpensePayments && filteredExpensePayments.length > 0) {
			filteredExpensePayments.forEach(expense => {
				if (expense.due_date) {
					const expenseDate = new Date(expense.due_date);
					if (expenseDate.toDateString() === dayDate.toDateString()) {
						// Track expense-specific counts
						dayInfo.expenseCount++;
						dayInfo.expenseScheduledAmount += (expense.amount || 0);
						
						// Add to overall count and totals
						dayInfo.paymentCount++;
						dayInfo.totalAmount += (expense.amount || 0);

						// Calculate unpaid expense amount
						if (!expense.is_paid) {
							dayInfo.expenseUnpaidAmount += (expense.amount || 0);
							dayInfo.unpaidAmount += (expense.amount || 0);
							dayInfo.isFullyPaid = false;
						}
					}
				}
			});
		}			// Add ALL days (including empty ones)
			monthDetailData.push(dayInfo);
		}

		// Sort by date
		monthDetailData.sort((a, b) => a.date - b.date);
	}

	// Format currency display
	function formatCurrency(amount) {
		if (!amount || amount === 0) return '0.00';
		
		// Convert to number and format with exact precision (no rounding)
		const numericAmount = typeof amount === 'string' ? parseFloat(amount) : Number(amount);
		
		// Format with exactly 2 decimal places without rounding for display
		const formattedAmount = numericAmount.toFixed(2);
		
		// Add thousand separators while preserving exact decimals
		const [integer, decimal] = formattedAmount.split('.');
		const integerWithCommas = integer.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
		
		return `${integerWithCommas}.${decimal}`;
	}

	// Handle date selection and scroll to that date (legacy function for dropdown if needed)
	function handleDateSelect(event) {
		const selectedDate = event.target.value;
		
		if (selectedDate) {
			scrollToDate(selectedDate);
			// Reset the select after scrolling
			setTimeout(() => {
				event.target.value = '';
			}, 1000);
		}
	}

	// Scroll to specific date (used by calendar view)
	function scrollToDate(uniqueDateId) {
		console.log('🔍 scrollToDate called with ID:', uniqueDateId);
		
		// Set the selected date for highlighting
		selectedDate = uniqueDateId;
		
		// Use requestAnimationFrame to ensure DOM is ready
		requestAnimationFrame(() => {
			console.log('📍 Looking for element with ID:', uniqueDateId);
			const element = document.getElementById(uniqueDateId);
			console.log('✅ Found element:', element ? 'YES' : 'NO', element?.id);
			
			if (element && scrollableContainer) {
				try {
					// Find the month-days-list wrapper which is the immediate parent container
					const monthDaysList = scrollableContainer.querySelector('.month-days-list');
					if (!monthDaysList) {
						console.warn('❌ month-days-list not found');
						return;
					}
					
					// Get all day cards to find which index this element is
					const allDayCards = monthDaysList.querySelectorAll('.day-details-card');
					let dayIndex = -1;
					for (let i = 0; i < allDayCards.length; i++) {
						if (allDayCards[i].id === uniqueDateId) {
							dayIndex = i;
							break;
						}
					}
					
					console.log('📍 Found day at index:', dayIndex, 'of', allDayCards.length);
					
					// Sum up heights of all previous cards plus gaps to get exact position
					let accumulatedHeight = 0;
					const gap = 16; // from CSS: gap: 16px
					
					for (let i = 0; i < dayIndex; i++) {
						accumulatedHeight += allDayCards[i].offsetHeight + gap;
					}
					
					const elementHeight = element.offsetHeight;
					const containerHeight = scrollableContainer.clientHeight;
					
					// Add top offset to keep day header visible (don't center, just show from top)
					// This prevents the header from being hidden under the fixed calendar
					const topOffset = 100; // Keep 100px of space at top for visibility
					const targetScroll = accumulatedHeight - topOffset;
					
					// Constrain to valid range
					const maxScroll = scrollableContainer.scrollHeight - containerHeight;
					const constrainedScroll = Math.max(0, Math.min(targetScroll, maxScroll));
					
					console.log('📏 Accumulated height calculation:', {
						dayIndex,
						accumulatedHeight,
						elementHeight,
						containerHeight,
						topOffset,
						targetScroll,
						maxScroll,
						constrainedScroll
					});
					
					// Scroll smoothly
					scrollableContainer.scrollTo({
						top: constrainedScroll,
						behavior: 'smooth'
					});
				} catch (error) {
					console.error('❌ Scroll error:', error);
				}
			} else {
				console.warn('⚠️ Scroll failed - element or container missing:', { element: !!element, scrollableContainer: !!scrollableContainer });
			}
		});
	}

	// Format date for database without timezone conversion issues
	function formatDateForDB(date) {
		return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
	}

	// Function removed - now using is_paid boolean directly for styling

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

	// Function to open reschedule modal from button click
	function openRescheduleModal(payment) {
		// For button click, we need to ask user for the new date
		// We'll modify the modal to include date picker when newDate is not provided
		splitPayment = { ...payment };
		splitAmount = parseFloat(payment.final_bill_amount || payment.bill_amount || 0);
		remainingAmount = splitAmount;
		showSplitModal = true;
	}

	function handleFullMove() {
		if (!splitPayment || !splitPayment.newDate) return;
		
		// Update the payment's due date
		updatePaymentDate(splitPayment.id, splitPayment.newDate, splitPayment.final_bill_amount);
		closeSplitModal();
	}

	async function handleSplitMove() {
		if (!splitPayment || !splitPayment.newDate || splitAmount <= 0 || splitAmount >= parseFloat(splitPayment.final_bill_amount)) {
			alert('Please enter a valid split amount and new date');
			return;
		}

		const originalAmount = parseFloat(splitPayment.final_bill_amount || splitPayment.bill_amount || 0);
		remainingAmount = originalAmount - splitAmount;

		try {
			// Create new payment record for the split amount
			await createSplitPayment(splitPayment, splitPayment.newDate, splitAmount);
			
			// Update original payment with remaining amount
			await updatePaymentAmount(splitPayment.id, remainingAmount);
			
			// Reload data to show updated amounts immediately
			await loadScheduledPayments();
			
		// Show success message
		alert(`Payment split successfully!\n\n✅ Created new payment: ${formatCurrency(splitAmount)} on ${formatDate(splitPayment.newDate)}\n✅ Updated original payment: ${formatCurrency(remainingAmount)} on ${formatDate(splitPayment.due_date)}`);			closeSplitModal();
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
		newDateInput = '';
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
					receiving_record_id: originalPayment.receiving_record_id, // Keep same receiving_record_id for traceability
					bill_number: originalPayment.bill_number + '-SPLIT',
					vendor_id: originalPayment.vendor_id,
					vendor_name: originalPayment.vendor_name,
					branch_id: originalPayment.branch_id,
					branch_name: originalPayment.branch_name,
					bill_date: originalPayment.bill_date,
					bill_amount: originalPayment.bill_amount, // Keep original bill amount for reference
					final_bill_amount: amount, // But the actual payment amount is the split amount
					payment_method: originalPayment.payment_method,
					bank_name: originalPayment.bank_name,
					iban: originalPayment.iban,
					due_date: formatDateForDB(newDate),
				original_due_date: originalPayment.original_due_date, // Preserve original due date
				original_bill_amount: originalPayment.original_bill_amount, // Preserve original bill amount
				original_final_amount: amount, // The split portion becomes the "original final" for this split
				credit_period: originalPayment.credit_period,
				vat_number: originalPayment.vat_number,
				is_paid: false,
				notes: (originalPayment.notes || '') + ' [Split from original payment]',
				created_by: $currentUser?.id
			});			if (error) {
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

	// Handle payment status change (mark as paid)
	async function handlePaymentStatusChange(paymentId, isPaid, isAutoProcessed = false) {
		try {
			if (isPaid) {
				// First, get the payment details with receiving record information
				const { data: paymentData, error: paymentError } = await supabase
					.from('vendor_payment_schedule')
					.select(`
						*,
						receiving_records!receiving_record_id (
							accountant_user_id,
							bill_number,
							vendor_id,
							user_id,
							original_bill_url,
							users!user_id (
								username
							)
						)
					`)
					.eq('id', paymentId)
					.single();

				if (paymentError || !paymentData) {
					console.error('Error fetching payment data:', paymentError);
					alert('Failed to fetch payment details');
					return;
				}

			const payment = paymentData;
			const receivingRecord = payment.receiving_records;

			// Update payment status in vendor_payment_schedule
			const { error: updateError } = await supabase
				.from('vendor_payment_schedule')
				.update({ 
					is_paid: true, 
					paid_date: new Date().toISOString(),
					payment_reference: null,
					transaction_date: new Date().toISOString(),
					receiver_user_id: receivingRecord?.user_id,
					accountant_user_id: receivingRecord?.accountant_user_id,
					original_bill_url: receivingRecord?.original_bill_url,
					created_by: $currentUser?.id
				})
				.eq('id', paymentId);

			if (updateError) {
				console.error('Error updating payment status:', updateError);
				if (!isAutoProcessed) {
					alert('Failed to update payment status');
				}
				return;
			}

			if (!isAutoProcessed) {
				alert('Payment marked as paid successfully');
			}
		} else {
			// Unmark as paid - update vendor_payment_schedule
			const { error: updateError } = await supabase
				.from('vendor_payment_schedule')
				.update({ 
					is_paid: false, 
					payment_reference: null,
					paid_date: null,
					task_id: null,
					task_assignment_id: null,
					transaction_date: null
				})
				.eq('id', paymentId);

			if (updateError) {
				console.error('Error updating payment status:', updateError);
				alert('Failed to update payment status');
				return;
			}

			alert('Payment unmarked successfully');
		}			// Reload data to reflect changes
			await loadScheduledPayments();
		} catch (error) {
			console.error('Error handling payment status change:', error);
			alert('Failed to update payment status');
		}
	}

	// Edit payment method functions
	function openPaymentMethodEdit(payment) {
		editingPayment = payment;
		editingPaymentId = payment.id;
		editForm = {
			payment_method: payment.payment_method || 'Cash on Delivery',
			bank_name: payment.bank_name || '',
			iban: payment.iban || '',
			due_date: payment.due_date || '',
			credit_period: payment.credit_period || ''
		};
		showPaymentMethodModal = true;
	}

	function closePaymentMethodEdit() {
		showPaymentMethodModal = false;
		editingPayment = null;
		editingPaymentId = null;
		editForm = {
			payment_method: '',
			bank_name: '',
			iban: '',
			due_date: '',
			credit_period: ''
		};
	}

	// Edit form state
	let editForm = {
		payment_method: '',
		bank_name: '',
		iban: '',
		due_date: '',
		credit_period: ''
	};

	// Handle payment method changes to clear/show appropriate fields
	function handlePaymentMethodChange() {
		if (editForm.payment_method) {
			// Handle delivery methods
			if (editForm.payment_method === 'Cash on Delivery' || editForm.payment_method === 'Bank on Delivery') {
				editForm.credit_period = '';
				// Set due date to current date for both delivery methods
				const today = new Date();
				editForm.due_date = today.toISOString().split('T')[0];
				
				if (editForm.payment_method === 'Cash on Delivery') {
					editForm.bank_name = '';
					editForm.iban = '';
				}
			}
			// Clear bank fields for cash credit
			else if (editForm.payment_method === 'Cash Credit') {
				editForm.bank_name = '';
				editForm.iban = '';
			}
		}
	}

	// Calculate due date automatically when credit period changes for credit methods
	function handleCreditPeriodChange() {
		if (editForm.credit_period && (editForm.payment_method === 'Cash Credit' || editForm.payment_method === 'Bank Credit')) {
			const today = new Date();
			const creditDays = parseInt(editForm.credit_period);
			if (creditDays > 0) {
				const dueDate = new Date(today.getTime() + (creditDays * 24 * 60 * 60 * 1000));
				editForm.due_date = dueDate.toISOString().split('T')[0];
			}
		}
	}

	async function savePaymentMethodEdit() {
		if (!editingPaymentId || !editForm.payment_method) {
			alert('Please select a payment method');
			return;
		}

		try {
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update({ 
					payment_method: editForm.payment_method,
					bank_name: editForm.bank_name.trim() || null,
					iban: editForm.iban.trim() || null,
					due_date: editForm.due_date || null,
					credit_period: editForm.credit_period ? parseInt(editForm.credit_period) : null,
					updated_at: new Date().toISOString()
				})
				.eq('id', editingPaymentId);

			if (error) {
				console.error('Error updating payment method:', error);
				alert('Failed to update payment method');
				return;
			}

			alert('Payment method updated successfully');
			closePaymentMethodEdit();
			await loadScheduledPayments();
		} catch (error) {
			console.error('Error:', error);
			alert('An error occurred while updating payment method');
		}
	}

	// Edit amount functions
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

	function closeEditAmountModal() {
		showEditAmountModal = false;
		editingAmountPayment = null;
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
	}

	// Reactive calculations for real-time updates
	// IMPORTANT: Use bill_amount as base (not original_final_amount) to match DB constraint
	$: baseAmount = editingAmountPayment ? (editingAmountPayment.bill_amount || 0) : 0;
	$: discountAmount = parseFloat(editAmountForm.discountAmount) || 0;
	$: grrAmount = parseFloat(editAmountForm.grrAmount) || 0;
	$: priAmount = parseFloat(editAmountForm.priAmount) || 0;
	$: totalDeductions = discountAmount + grrAmount + priAmount;
	$: newFinalAmount = baseAmount - totalDeductions;
	$: isValidAmount = newFinalAmount >= 0;

	function calculateNewFinalAmount() {
		return newFinalAmount;
	}

	async function saveAmountAdjustment() {
		if (!editingAmountPayment) return;

		// Validate using reactive values
		if (!isValidAmount) {
			alert('Total deductions cannot exceed the original final amount');
			return;
		}

		// Validate GRR reference number if GRR amount is provided
		if (grrAmount > 0 && !editAmountForm.grrReferenceNumber.trim()) {
			alert('Please provide a GRR reference number');
			return;
		}

		// Validate PRI reference number if PRI amount is provided
		if (priAmount > 0 && !editAmountForm.priReferenceNumber.trim()) {
			alert('Please provide a GRR reference number');
			return;
		}

		// Validate PRI reference number if PRI amount is provided
		if (priAmount > 0 && !editAmountForm.priReferenceNumber.trim()) {
			alert('Please provide a PRI reference number');
			return;
		}

		try {
			// Create adjustment history entry
			const historyEntry = {
				date: new Date().toISOString(),
				user_id: $currentUser?.id,
				user_name: $currentUser?.full_name || $currentUser?.email,
				previous_final_amount: editingAmountPayment.final_bill_amount,
				new_final_amount: newFinalAmount,
				discount_amount: discountAmount,
				grr_amount: grrAmount,
				grr_reference: editAmountForm.grrReferenceNumber,
				pri_amount: priAmount,
				pri_reference: editAmountForm.priReferenceNumber
			};

			// Get existing history
			const { data: currentData } = await supabase
				.from('vendor_payment_schedule')
				.select('adjustment_history')
				.eq('id', editingAmountPayment.id)
				.single();

		const existingHistory = currentData?.adjustment_history || [];
		const newHistory = [...existingHistory, historyEntry];

		// 🔧 FIX: Use PostgreSQL's exact NUMERIC arithmetic to avoid floating-point errors
		// The constraint validates: final_bill_amount = bill_amount - (discount + grr + pri)
		// By doing the calculation in PostgreSQL, we ensure exact decimal precision
		
		console.log('💾 Saving adjustment with PostgreSQL NUMERIC calculation:', {
			bill_amount: editingAmountPayment.bill_amount,
			discount_amount: discountAmount,
			grr_amount: grrAmount,
			pri_amount: priAmount,
			approach: 'PostgreSQL server-side calculation'
		});

		// Use PostgreSQL function for exact calculation
		const { error } = await supabase.rpc('update_vendor_payment_with_exact_calculation', {
			payment_id: editingAmountPayment.id,
			new_discount_amount: discountAmount || null,
			new_grr_amount: grrAmount || null,
			new_pri_amount: priAmount || null,
			discount_notes_val: editAmountForm.discountNotes.trim() || null,
			grr_reference_val: editAmountForm.grrReferenceNumber.trim() || null,
			grr_notes_val: editAmountForm.grrNotes.trim() || null,
			pri_reference_val: editAmountForm.priReferenceNumber.trim() || null,
			pri_notes_val: editAmountForm.priNotes.trim() || null,
			history_val: newHistory
		});

		if (error) {
			console.error('Error updating amount:', error);
			alert('Failed to update amount: ' + error.message);
			return;
		}

		alert('Amount adjusted successfully');
		closeEditAmountModal();
		await loadScheduledPayments();

		} catch (error) {
			console.error('Error:', error);
			alert('An error occurred while updating amount');
		}
	}

	// ============================================
	// APPROVAL SYSTEM FUNCTIONS
	// ============================================

	/**
	 * Open the approver list modal for a payment
	 */
	function handleRequestApproval(payment) {
		if (!$currentUser?.id) {
			alert('You must be logged in to request approval');
			return;
		}

		pendingApprovalPayment = payment;
		showApproverListModal = true;
	}

	/**
	 * Handle successful approval submission
	 */
	async function handleApprovalSubmitted(event) {
		const { paymentId, approvers } = event.detail;
		
		// Show success message
		console.log(`✅ Payment ${paymentId} sent for approval to ${approvers.length} approver(s)`);
		alert(`Payment sent for approval successfully!\n${approvers.length} approver(s) will be notified.`);
		
		// Reload payments to reflect updated status
		await loadScheduledPayments();
		
		// Close modal
		closeApproverModal();
	}

	/**
	 * Close the approver list modal
	 */
	function closeApproverModal() {
		showApproverListModal = false;
		pendingApprovalPayment = null;
	}

	/**
	 * Delete vendor payment schedule record (Master Admin only)
	 */
	async function deleteVendorPayment(payment) {
		if (!isMasterAdmin) {
			alert('Only Master Admin can delete payment records');
			return;
		}

		const confirmMessage = `Are you sure you want to delete this payment?\n\nVendor: ${payment.vendor_name}\nBill #: ${payment.bill_number}\nAmount: ${formatCurrency(payment.final_bill_amount)}\n\nThis action cannot be undone.`;
		
		if (!confirm(confirmMessage)) return;

		try {
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.delete()
				.eq('id', payment.id);

			if (error) {
				console.error('Error deleting payment:', error);
				alert('Failed to delete payment: ' + error.message);
				return;
			}

			alert('Payment deleted successfully');
			await loadScheduledPayments();
			generateAllDaysOfMonth(monthData);
		} catch (error) {
			console.error('Error deleting payment:', error);
			alert('Failed to delete payment');
		}
	}

	/**
	 * Delete expense scheduler payment record (Master Admin only)
	 */
	async function deleteExpensePayment(payment) {
		if (!isMasterAdmin) {
			alert('Only Master Admin can delete payment records');
			return;
		}

		const confirmMessage = `Are you sure you want to delete this expense payment?\n\nRequester: ${payment.requester_name || payment.co_user_name || 'N/A'}\nRequest #: ${payment.requisition_number || 'N/A'}\nAmount: ${formatCurrency(payment.amount || 0)}\n\nThis action cannot be undone.`;
		
		if (!confirm(confirmMessage)) return;

		try {
			const { error } = await supabase
				.from('expense_scheduler')
				.delete()
				.eq('id', payment.id);

			if (error) {
				console.error('Error deleting expense payment:', error);
				alert('Failed to delete expense payment: ' + error.message);
				return;
			}

			alert('Expense payment deleted successfully');
			await loadExpenseSchedulerPayments();
			generateAllDaysOfMonth(monthData);
		} catch (error) {
			console.error('Error deleting expense payment:', error);
			alert('Failed to delete expense payment');
		}
	}

	/**
	 * Check if a payment needs approval (not approved yet)
	 */
	function needsApproval(payment) {
		// Paid payments don't need approval
		if (payment.is_paid) return false;
		// Check if approval status is not 'approved'
		// NULL or undefined means no approval status set, so it needs approval
		// 'pending', 'sent_for_approval', 'rejected' all need approval
		// Only 'approved' doesn't need approval
		const needs = !payment.approval_status || payment.approval_status !== 'approved';
		console.log(`Payment ${payment.bill_number}: is_paid=${payment.is_paid}, status=${payment.approval_status}, needsApproval=${needs}`);
		return needs;
	}

	/**
	 * Get approval status for display
	 */
	function getApprovalStatus(payment) {
		return payment.approval_status || 'pending';
	}

	// Refresh function to reload all data
	async function refreshData() {
		if (refreshing) return; // Prevent multiple simultaneous refreshes
		
		try {
			refreshing = true;
			console.log('🔄 [MonthDetails] Starting complete data refresh...');
			
			// Clear existing data first
			scheduledPayments = [];
			expenseSchedulerPayments = [];
			monthDetailData = [];
			
			// Force reload all data sources
			await Promise.all([
				loadBranches(),
				loadPaymentMethods(),
				loadScheduledPayments(),
				loadExpenseSchedulerPayments()
			]);
			
			// Regenerate calendar data
			if (monthData) {
				generateAllDaysOfMonth(monthData);
			}
			
			console.log('✅ [MonthDetails] Complete data refresh successful');
			
			// Also refresh parent window if callback provided
			if (parentRefreshCallback) {
				console.log('🔄 [MonthDetails] Refreshing parent ScheduledPayments...');
				await parentRefreshCallback();
				console.log('✅ [MonthDetails] Parent refreshed successfully');
			}
		} catch (error) {
			console.error('❌ [MonthDetails] Error during complete refresh:', error);
			alert('Error refreshing data. Please try again.');
		} finally {
			refreshing = false;
		}
	}

	// Expose refreshData function to parent/window
	$: if (monthDetailsElement) {
		monthDetailsElement.refreshData = refreshData;
	}

	// Auto-refresh when component mounts or monthData changes
	async function loadInitialData() {
		if (monthData) {
			await loadBranches();
			await loadPaymentMethods();
			await loadScheduledPayments();
			await loadExpenseSchedulerPayments();
			generateAllDaysOfMonth(monthData);
		}
	}

	onMount(() => {
		console.log('🚀 [MonthDetails] Component mounted');
		console.log('🔍 [MonthDetails] setRefreshCallback:', setRefreshCallback);
		console.log('🔍 [MonthDetails] onRefresh:', onRefresh);
		
		loadInitialData();
		
		// Register our refresh function with the window
		if (setRefreshCallback) {
			console.log('✅ [MonthDetails] Registering refreshData function with window');
			setRefreshCallback(refreshData);
		} else {
			console.log('❌ [MonthDetails] No setRefreshCallback provided');
		}
	});
</script>

<!-- Month Details Window Content -->
<div class="month-details-container" data-refresh-target bind:this={monthDetailsElement}>
	{#if monthData}
		<!-- Fixed Header Section -->
		<div class="fixed-header-section">
			<div class="header-cards-container">
			<!-- Compact Calendar Card with integrated summary -->
			<div class="header-card calendar-card">
				<div class="header-card-title">
					<h3>📅 Schedule Calendar</h3>
					<button 
						class="small-refresh-btn"
						disabled={refreshing}
						on:click={refreshData}
						title={refreshing ? "Refreshing..." : "Refresh data"}
					>
						{refreshing ? "⏳" : "🔄"}
					</button>
				</div>
				<div class="header-card-content">
					<!-- Payment Summary inside calendar -->
					<div class="calendar-summary">
						<div class="compact-stats">
							<div class="stat-item">
								<span class="stat-value">{monthDetailData.filter(d => d.paymentCount > 0).length}</span>
								<span class="stat-label">Days</span>
							</div>
							<div class="stat-item">
								<span class="stat-value">{monthData.paymentCount}</span>
								<span class="stat-label">Vendor Payments</span>
							</div>
							<div class="stat-item">
								<span class="stat-value">{expenseSchedulerPayments.length}</span>
								<span class="stat-label">Expense Payments</span>
							</div>
							<div class="stat-item total-stat">
								<span class="stat-value total">{formatCurrency(monthData.total)}</span>
								<span class="stat-label">Total Vendor Scheduled</span>
							</div>
							<div class="stat-item total-stat">
								<span class="stat-value total" style="color: #dc2626;">{formatCurrency(totalExpensesScheduled)}</span>
								<span class="stat-label">Total Expenses Scheduled</span>
							</div>
							<div class="stat-item paid-stat">
								<span class="stat-value paid">{formatCurrency(totalPaidAmount)}</span>
								<span class="stat-label">Total Vendor Paid</span>
							</div>
							<div class="stat-item paid-stat">
								<span class="stat-value paid" style="color: #059669;">{formatCurrency(totalExpensesPaid)}</span>
								<span class="stat-label">Total Expenses Paid</span>
							</div>
							<div class="stat-item unpaid-stat">
								<span class="stat-value unpaid">{formatCurrency(totalUnpaidAmount)}</span>
								<span class="stat-label">Total Vendor Unpaid</span>
							</div>
							<div class="stat-item unpaid-stat">
								<span class="stat-value unpaid" style="color: #dc2626;">{formatCurrency(totalExpensesUnpaid)}</span>
								<span class="stat-label">Total Expenses Unpaid</span>
							</div>
						</div>
						
						<!-- Compact Payment Methods -->
						<div class="compact-methods">
							{#each Object.entries(totalsByPaymentMethod) as [method, amount]}
								<div class="method-chip">
									<span class="method-name">{method}</span>
									<span class="method-value">{formatCurrency(amount)}</span>
								</div>
							{/each}
						</div>
					</div>
					
					<div class="compact-calendar-grid">
						{#each monthDetailData as dayData}
							<div 
								class="mini-calendar-day {dayData.isToday ? 'is-today' : ''} {dayData.paymentCount > 0 ? (dayData.isFullyPaid ? 'has-payments fully-paid' : 'has-payments has-unpaid') : 'no-payments'} {selectedDate === dayData.id ? 'is-selected' : ''}"
								on:click={() => scrollToDate(dayData.id)}
								title="Click to jump to {dayData.dayName}, {monthData.month} {dayData.date} - {dayData.paymentCount} payments, Total: {formatCurrency(dayData.totalAmount)}, Unpaid: {formatCurrency(dayData.unpaidAmount)}"
							>
								<div class="mini-day-info">
									<div class="mini-day-number">{dayData.date}</div>
									<div class="mini-day-name">{dayData.dayName}</div>
								</div>
								{#if dayData.paymentCount > 0}
									<div class="mini-payment-info">
										<div class="mini-count">{dayData.paymentCount} bills</div>
										<div class="mini-amount">{formatCurrency(dayData.totalAmount)}</div>
										{#if dayData.vendorCount > 0}
											<div class="mini-vendor-count" style="color: #1e40af; font-size: 9px; font-weight: 600;">
												{dayData.vendorCount} Vendor: {formatCurrency(dayData.vendorScheduledAmount)}
											</div>
											{#if dayData.vendorUnpaidAmount > 0}
												<div class="mini-vendor-unpaid" style="color: #f59e0b; font-size: 8px; font-weight: 600;">
													V.Unpaid: {formatCurrency(dayData.vendorUnpaidAmount)}
												</div>
											{/if}
										{/if}
										{#if dayData.expenseCount > 0}
											<div class="mini-expense-count" style="color: #dc2626; font-size: 9px; font-weight: 600;">
												{dayData.expenseCount} Exp: {formatCurrency(dayData.expenseScheduledAmount)}
											</div>
											{#if dayData.expenseUnpaidAmount > 0}
												<div class="mini-expense-unpaid" style="color: #dc2626; font-size: 8px; font-weight: 600;">
													E.Unpaid: {formatCurrency(dayData.expenseUnpaidAmount)}
												</div>
											{/if}
										{/if}
									</div>
								{/if}
							</div>
						{/each}
					</div>
				</div>
			</div>
		</div>
		</div>

		<!-- Scrollable Content Section -->
		<div class="scrollable-content-section" bind:this={scrollableContainer}>
			<!-- Days List -->
			<div class="month-days-list">
			{#each monthDetailData as dayData}
				<div 
					id="{dayData.id}"
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
								<div class="filter-controls">
									<select class="filter-select" bind:value={filterBranch}>
										<option value="">All Branches</option>
										{#each branches as branch}
											<option value={branch.id}>{branch.name_en}</option>
										{/each}
									</select>
									<select class="filter-select" bind:value={filterPaymentMethod}>
										<option value="">All Payment Methods</option>
										{#each paymentMethods as method}
											<option value={method}>{method}</option>
										{/each}
									</select>
								</div>
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

								<!-- Clean Simple Table -->
								<div class="simple-table-container">
									<table class="simple-payments-table">
										<thead>
											<tr>
												<th>Bill #</th>
												<th>Vendor</th>
												<th>Amount</th>
												<th>Orig. Bill</th>
												<th>Orig. Final</th>
												<th>Bill Date</th>
												<th>Due Date</th>
												<th>Orig. Due</th>
												<th>Branch</th>
												<th>Payment</th>
												<th>Priority</th>
												<th>Bank</th>
												<th>IBAN</th>
												<th>Mark Paid</th>
												<th>Status</th>
												<th>Actions</th>
											</tr>
										</thead>
										<tbody>
										{#if dayData.paymentCount > 0}
											{#each Object.entries(dayData.paymentsByVendor) as [vendorKey, vendorGroup], vendorIndex}
												{#each vendorGroup.payments as payment}
													<tr class:needs-approval-row={needsApproval(payment)} style="border-left: 4px solid {getVendorColor(vendorIndex)}; position: relative;">
														<!-- Always visible: Bill # -->
														<td class="always-visible">
															<span class="bill-number-badge">#{payment.bill_number || 'N/A'}</span>
														</td>
														
														<!-- Always visible: Vendor -->
														<td class="always-visible" style="color: {getVendorColor(vendorIndex)}; text-align: left; font-weight: 500;">
															{vendorGroup.vendor_name}
														</td>
														
														<!-- Always visible: Amount -->
														<td class="always-visible" style="text-align: right; font-weight: 600; color: #059669;">
															{formatCurrency(payment.final_bill_amount)}
														</td>
														
														<!-- Maskable columns -->
														<td class="maskable-column" style="text-align: right;">
															{formatCurrency(payment.original_bill_amount || 0)}
														</td>
														<td class="maskable-column" style="text-align: right;">
															{formatCurrency(payment.original_final_amount || 0)}
														</td>
														<td class="maskable-column">
															{formatDate(payment.bill_date)}
														</td>
														<td class="maskable-column">
															{formatDate(payment.due_date)}
														</td>
														<td class="maskable-column">
															{formatDate(payment.original_due_date)}
														</td>
														
														<!-- Always visible: Branch -->
														<td class="always-visible">
															{getBranchName(payment.branch_id)}
														</td>
														
														<!-- Always visible: Payment Method -->
														<td class="always-visible">
															<span class="payment-method">{payment.payment_method || 'Cash on Delivery'}</span>
															{#if !payment.is_paid}
																<button 
																	class="edit-payment-method-btn"
																	on:click={() => openPaymentMethodEdit(payment)}
																	title="Edit payment method"
																>
																	✏️
																</button>
															{/if}
														</td>
														
														<!-- Maskable columns -->
														<td class="maskable-column">
															{#if payment.vendor_priority}
																<span class="priority-badge priority-{payment.vendor_priority.toLowerCase()}">
																	{payment.vendor_priority}
																</span>
															{:else}
																<span class="priority-badge priority-normal">Normal</span>
															{/if}
														</td>
														<td class="maskable-column">
															{payment.bank_name || 'N/A'}
														</td>
														<td class="maskable-column">
															{payment.iban || 'N/A'}
														</td>
														<td class="maskable-column">
															<input 
																type="checkbox" 
																class="payment-checkbox"
																data-payment-id="{payment.id}"
																checked={payment.is_paid || false}
																on:change={(e) => handlePaymentStatusChange(payment.id, e.currentTarget.checked)}
																disabled={needsApproval(payment)}
															/>
														</td>
														
														<!-- Always visible: Status -->
														<td class="always-visible">
															<span class="status-badge {payment.is_paid ? 'status-paid' : 'status-scheduled'}">
																{payment.is_paid ? 'Paid' : 'Scheduled'}
															</span>
														</td>
														
													<!-- Always visible: Actions -->
													<td class="always-visible">
														{#if needsApproval(payment)}
															<ApprovalMask 
																approvalStatus={getApprovalStatus(payment)}
																onRequestApproval={() => handleRequestApproval(payment)}
																disabled={!$currentUser?.id}
															/>
														{:else if !payment.is_paid}
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
														{/if}
														{#if isMasterAdmin}
															<button 
																class="delete-btn"
																on:click|stopPropagation={() => deleteVendorPayment(payment)}
																title="Delete Payment (Master Admin Only)"
															>
																🗑️
															</button>
														{/if}
													</td>													</tr>
												{/each}
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

							<!-- OTHER PAYMENTS SECTION (Expense Scheduler) -->
							<div class="payment-section">
								<div class="section-header">
									<h3 class="section-title">💳 Other Payments (Expense Scheduler)</h3>
									<div class="section-summary">
										{#if true}
											{@const dayDateString = `${dayData.fullDate.getFullYear()}-${String(dayData.fullDate.getMonth() + 1).padStart(2, '0')}-${String(dayData.fullDate.getDate()).padStart(2, '0')}`}
											{@const dayExpenses = filteredExpensePayments.filter(p => p.due_date === dayDateString)}
											{#if dayExpenses.length > 0}
												{console.log('📅 Expense scheduler payments for', dayDateString, ':', dayExpenses.map(p => ({ id: p.id, type: p.schedule_type, amount: p.amount, due_date: p.due_date })))}
											{/if}
											{@const totalExpenses = dayExpenses.reduce((sum, p) => sum + (p.amount || 0), 0)}
											{@const paidExpenses = dayExpenses.filter(p => p.is_paid).reduce((sum, p) => sum + (p.amount || 0), 0)}
											{@const scheduledExpenses = dayExpenses.filter(p => !p.is_paid).reduce((sum, p) => sum + (p.amount || 0), 0)}
											<span>{dayExpenses.length} payment{dayExpenses.length !== 1 ? 's' : ''}</span>
											<span>Total: {formatCurrency(totalExpenses)}</span>
											<span style="color: #059669;">Paid: {formatCurrency(paidExpenses)}</span>
											<span style="color: #dc2626;">Scheduled: {formatCurrency(scheduledExpenses)}</span>
										{/if}
									</div>
								</div>
								
								<!-- Expense Scheduler Payments Table -->
								<div class="simple-table-container">
									<table class="simple-payments-table">
										<thead>
											<tr>
												<th>Requester</th>
												<th>Request #</th>
												<th>Sub-Category</th>
												<th>Branch</th>
												<th>Payment Method</th>
												<th>Amount</th>
												<th>Due Date</th>
												<th>Paid Date</th>
												<th>Created By</th>
												<th>Description</th>
												<th>Status</th>
												<th>Mark Paid</th>
												<th>Actions</th>
											</tr>
										</thead>
										<tbody>
										{#if true}
											{@const dayDateString = `${dayData.fullDate.getFullYear()}-${String(dayData.fullDate.getMonth() + 1).padStart(2, '0')}-${String(dayData.fullDate.getDate()).padStart(2, '0')}`}
											{#if filteredExpensePayments.filter(p => p.due_date === dayDateString).length > 0}
												{#each filteredExpensePayments.filter(p => p.due_date === dayDateString) as payment}
													<tr class={payment.is_paid ? 'paid-row' : ''}>
														<td style="text-align: left; font-weight: 500;">
															{payment.requester_name || payment.co_user_name || 'N/A'}
														</td>
													<td>
														<span class="bill-number-badge">#{payment.requisition_number || 'N/A'}</span>
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
														<span class="payment-method-badge" style="background: #fee2e2; color: #991b1b; font-size: 11px; padding: 4px 8px; border-radius: 4px; font-weight: 500;">
															{payment.payment_method || 'Expense'}
														</span>
													</td>
													<td style="text-align: right; font-weight: 600; color: {payment.is_paid ? '#059669' : '#dc2626'};">{formatCurrency(payment.amount || 0)}</td>
													<td>{formatDate(payment.due_date)}</td>
													<td>
														{#if payment.is_paid && payment.paid_date}
															<span style="color: #059669; font-weight: 500;">{formatDate(payment.paid_date)}</span>
														{:else}
															<span style="color: #94a3b8;">—</span>
														{/if}
													</td>
													<td>{payment.creator?.username || 'Unknown'}</td>
													<td style="text-align: left; max-width: 200px; overflow: hidden; text-overflow: ellipsis;" title="{payment.description || ''}">{payment.description || 'N/A'}</td>
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
														{#if isMasterAdmin}
															<button 
																class="delete-btn"
																on:click|stopPropagation={() => deleteExpensePayment(payment)}
																title="Delete Expense Payment (Master Admin Only)"
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
										{/if}
										</tbody>
									</table>
								</div>
							</div>

						</div>
				</div>
			{/each}
			</div>
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
							<span class="label">Current Amount:</span>
							<span class="value amount-current">{formatCurrency(splitPayment.final_bill_amount)}</span>
						</div>
						{#if splitPayment.original_final_amount || splitPayment.original_bill_amount}
						<div class="detail-row">
							<span class="label">Original Amount:</span>
							<span class="value amount-original">{formatCurrency(splitPayment.original_final_amount || splitPayment.original_bill_amount)}</span>
						</div>
						{/if}
						<div class="detail-row">
							<span class="label">Current Due Date:</span>
							<span class="value">{formatDate(splitPayment.due_date)}</span>
						</div>
						{#if splitPayment.original_due_date}
						<div class="detail-row">
							<span class="label">Original Due Date:</span>
							<span class="value">{formatDate(splitPayment.original_due_date)}</span>
						</div>
						{/if}
						<div class="detail-row">
							<span class="label">Split To Date:</span>
							<span class="value">{splitPayment.newDate ? formatDate(splitPayment.newDate) : 'Not set'}</span>
						</div>
						{#if !splitPayment.newDate}
						<div class="detail-row">
							<span class="label">Select New Date:</span>
							<input 
								type="date" 
								bind:value={newDateInput}
								on:change={(e) => {
									if (e.target.value) {
										splitPayment.newDate = new Date(e.target.value);
									}
								}}
								class="date-input"
								min={new Date().toISOString().split('T')[0]}
							/>
						</div>
						{/if}
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
								</div>
								
								<!-- Amount Breakdown Display -->
								{#if splitAmount > 0 && splitAmount < parseFloat(splitPayment.final_bill_amount)}
									<div class="amount-breakdown">
										<div class="breakdown-header">
											<h5>Payment Split Breakdown:</h5>
										</div>
										<div class="breakdown-row">
											<span class="breakdown-label">Amount moving to {splitPayment.newDate ? formatDate(splitPayment.newDate) : 'Not set'}:</span>
											<span class="breakdown-value move-amount">+ {formatCurrency(splitAmount)}</span>
										</div>
										<div class="breakdown-row">
											<span class="breakdown-label">Amount remaining on {formatDate(splitPayment.due_date)}:</span>
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

<!-- Edit Payment Method Modal -->
{#if showPaymentMethodModal && editingPayment}
	<div class="modal-overlay" on:click={closePaymentMethodEdit}>
		<div class="edit-modal" on:click|stopPropagation>
			<div class="modal-header">
				<h3>Edit Payment Details</h3>
				<button class="close-btn" on:click={closePaymentMethodEdit}>×</button>
			</div>
			
			<div class="modal-content">
				<div class="edit-form">
					<div class="form-row">
						<!-- Show Bank Name and IBAN only for Bank methods -->
						{#if editForm.payment_method && (editForm.payment_method === 'Bank on Delivery' || editForm.payment_method === 'Bank Credit')}
							<div class="form-group">
								<label for="bank_name">Bank Name</label>
								<input 
									type="text" 
									id="bank_name"
									bind:value={editForm.bank_name}
									placeholder="Enter bank name"
								/>
							</div>
							
							<div class="form-group">
								<label for="iban">IBAN</label>
								<input 
									type="text" 
									id="iban"
									bind:value={editForm.iban}
									placeholder="Enter IBAN number"
								/>
							</div>
						{:else}
							<!-- Empty placeholders when bank fields are not needed -->
							<div class="form-group placeholder-field">
								<label>Bank Name</label>
								<div class="disabled-field">Not applicable for {editForm.payment_method || 'selected payment method'}</div>
							</div>
							<div class="form-group placeholder-field">
								<label>IBAN</label>
								<div class="disabled-field">Not applicable for {editForm.payment_method || 'selected payment method'}</div>
							</div>
						{/if}
					</div>
					
					<div class="form-row">
						<div class="form-group">
							<label for="due_date">Due Date</label>
							<input 
								type="date" 
								id="due_date"
								bind:value={editForm.due_date}
								placeholder="dd/mm/yyyy"
							/>
						</div>
						
						<div class="form-group">
							<label for="payment_method">Payment Method</label>
							<select bind:value={editForm.payment_method} on:change={handlePaymentMethodChange}>
								<option value="">Select Payment Method</option>
								<option value="Cash on Delivery">Cash on Delivery</option>
								<option value="Bank on Delivery">Bank on Delivery</option>
								<option value="Cash Credit">Cash Credit</option>
								<option value="Bank Credit">Bank Credit</option>
							</select>
						</div>
					</div>
					
					<!-- Show Credit Period only for Credit methods -->
					{#if editForm.payment_method && (editForm.payment_method === 'Cash Credit' || editForm.payment_method === 'Bank Credit')}
						<div class="form-row single-column">
							<div class="form-group">
								<label for="credit_period">Credit Period (days)</label>
								<input 
									type="number" 
									id="credit_period"
									bind:value={editForm.credit_period}
									on:input={handleCreditPeriodChange}
									placeholder="Enter credit period in days"
									min="0"
								/>
							</div>
						</div>
					{:else if editForm.payment_method}
						<!-- Show disabled field for delivery methods -->
						<div class="form-row single-column">
							<div class="form-group placeholder-field">
								<label>Credit Period (days)</label>
								<div class="disabled-field">Not applicable for {editForm.payment_method}</div>
							</div>
						</div>
					{/if}
				</div>
			</div>
			
			<div class="modal-footer">
				<button class="cancel-btn" on:click={closePaymentMethodEdit}>Cancel</button>
				<button class="save-btn" on:click={savePaymentMethodEdit}>Save Changes</button>
			</div>
		</div>
	</div>
{/if}

<!-- Expense Scheduler Reschedule Modal -->
{#if showExpenseRescheduleModal && reschedulingExpensePayment}
	<div class="modal-overlay" on:click={cancelExpenseReschedule}>
		<div class="modal-container" on:click|stopPropagation>
			<div class="modal-header">
				<h3>Reschedule Expense Payment</h3>
				<button class="close-btn" on:click={cancelExpenseReschedule}>×</button>
			</div>
			
			<div class="modal-content">
				<div class="payment-info">
					<h4>Payment Split & Reschedule:</h4>
					<div class="payment-details-grid">
						<div class="detail-row">
							<span class="label">Requester:</span>
							<span class="value">{reschedulingExpensePayment.co_user_name || 'N/A'}</span>
						</div>
						<div class="detail-row">
							<span class="label">Request #:</span>
							<span class="value">{reschedulingExpensePayment.requisition_number || 'N/A'}</span>
						</div>
						<div class="detail-row">
							<span class="label">Sub-Category:</span>
							<span class="value">{reschedulingExpensePayment.expense_category_name_en || reschedulingExpensePayment.expense_category_name_ar || 'N/A'}</span>
						</div>
						<div class="detail-row">
							<span class="label">Current Amount:</span>
							<span class="value amount-current">{formatCurrency(reschedulingExpensePayment.amount || 0)}</span>
						</div>
						<div class="detail-row">
							<span class="label">Current Due Date:</span>
							<span class="value">{formatDate(reschedulingExpensePayment.due_date)}</span>
						</div>
						<div class="detail-row">
							<span class="label">Description:</span>
							<span class="value">{reschedulingExpensePayment.description || 'N/A'}</span>
						</div>
						<div class="detail-row">
							<span class="label">Select New Date:</span>
							<input 
								type="date" 
								bind:value={expenseNewDateInput}
								class="date-input"
								min={new Date().toISOString().split('T')[0]}
							/>
						</div>
					</div>
				</div>
				
				<div class="reschedule-options">
					<h4>Reschedule Options:</h4>
					
					<div class="option-group">
						<button class="option-btn full-move" on:click={handleExpenseFullMove}>
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
										bind:value={expenseSplitAmount}
										max={parseFloat(reschedulingExpensePayment.amount)}
										min="0.01"
										step="0.01"
										placeholder="Enter amount to split"
									/>
								</div>
								
								<!-- Amount Breakdown Display -->
								{#if expenseSplitAmount > 0 && expenseSplitAmount < parseFloat(reschedulingExpensePayment.amount)}
									<div class="amount-breakdown">
										<div class="breakdown-header">
											<h5>Payment Split Breakdown:</h5>
										</div>
										<div class="breakdown-row">
											<span class="breakdown-label">Amount moving to {expenseNewDateInput ? formatDate(expenseNewDateInput) : 'New Date'}:</span>
											<span class="breakdown-value move-amount">+ {formatCurrency(expenseSplitAmount)}</span>
										</div>
										<div class="breakdown-row">
											<span class="breakdown-label">Amount remaining on {formatDate(reschedulingExpensePayment.due_date)}:</span>
											<span class="breakdown-value remain-amount">= {formatCurrency(parseFloat(reschedulingExpensePayment.amount) - expenseSplitAmount)}</span>
										</div>
										<div class="breakdown-divider"></div>
										<div class="breakdown-row total">
											<span class="breakdown-label">Original Total:</span>
											<span class="breakdown-value">{formatCurrency(reschedulingExpensePayment.amount)}</span>
										</div>
									</div>
								{/if}
								
								<div class="remaining-info">
									<p>Remaining: {formatCurrency(parseFloat(reschedulingExpensePayment.amount) - expenseSplitAmount)}</p>
								</div>
								
								<button class="option-btn split-move" on:click={handleExpenseSplitMove}>
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

<!-- Edit Amount Modal -->
{#if showEditAmountModal && editingAmountPayment}
	<div class="modal-overlay" on:click={closeEditAmountModal}>
		<div class="modal-container edit-amount-modal" on:click|stopPropagation>
			<div class="modal-header">
				<h3>💰 Edit Amount - Bill #{editingAmountPayment.bill_number}</h3>
				<button class="close-btn" on:click={closeEditAmountModal}>✕</button>
			</div>
			
			<div class="modal-body">
				<div class="payment-info-section">
					<h4>Payment Information</h4>
					<div class="info-grid">
						<div class="info-item">
							<span class="info-label">Vendor:</span>
							<span class="info-value">{editingAmountPayment.vendor_name}</span>
						</div>
						<div class="info-item">
							<span class="info-label">Bill Date:</span>
							<span class="info-value">{formatDate(editingAmountPayment.bill_date)}</span>
						</div>
						<div class="info-item">
							<span class="info-label">Original Bill Amount:</span>
							<span class="info-value amount-highlight">{formatCurrency(editingAmountPayment.bill_amount)}</span>
						</div>
						<div class="info-item">
							<span class="info-label">Current Final Amount:</span>
							<span class="info-value amount-highlight">{formatCurrency(editingAmountPayment.final_bill_amount)}</span>
						</div>
					</div>
				</div>

				<div class="adjustment-section">
					<h4>Adjustments</h4>
					
					<!-- Discount Section -->
					<div class="adjustment-group">
						<label class="adjustment-label">
							<span class="adjustment-icon">🏷️</span>
							<span>Discount Amount</span>
						</label>
						<input 
							type="number" 
							step="0.01"
							min="0"
							bind:value={editAmountForm.discountAmount}
							placeholder="0.00"
							class="adjustment-input"
						/>
						<textarea 
							bind:value={editAmountForm.discountNotes}
							placeholder="Discount notes (optional)"
							class="adjustment-notes"
							rows="2"
						></textarea>
					</div>

					<!-- GRR Section -->
					<div class="adjustment-group">
						<label class="adjustment-label">
							<span class="adjustment-icon">📦</span>
							<span>GRR (Goods Receipt Return)</span>
						</label>
						<input 
							type="number" 
							step="0.01"
							min="0"
							bind:value={editAmountForm.grrAmount}
							placeholder="0.00"
							class="adjustment-input"
						/>
						<input 
							type="text" 
							bind:value={editAmountForm.grrReferenceNumber}
							placeholder="GRR Reference Number {editAmountForm.grrAmount > 0 ? '(Required)' : ''}"
							class="adjustment-input"
							required={editAmountForm.grrAmount > 0}
						/>
						<textarea 
							bind:value={editAmountForm.grrNotes}
							placeholder="GRR notes (optional)"
							class="adjustment-notes"
							rows="2"
						></textarea>
					</div>

					<!-- PRI Section -->
					<div class="adjustment-group">
						<label class="adjustment-label">
							<span class="adjustment-icon">📄</span>
							<span>PRI (Purchase Return Invoice)</span>
						</label>
						<input 
							type="number" 
							step="0.01"
							min="0"
							bind:value={editAmountForm.priAmount}
							placeholder="0.00"
							class="adjustment-input"
						/>
						<input 
							type="text" 
							bind:value={editAmountForm.priReferenceNumber}
							placeholder="PRI Reference Number {editAmountForm.priAmount > 0 ? '(Required)' : ''}"
							class="adjustment-input"
							required={editAmountForm.priAmount > 0}
						/>
						<textarea 
							bind:value={editAmountForm.priNotes}
							placeholder="PRI notes (optional)"
							class="adjustment-notes"
							rows="2"
						></textarea>
					</div>
				</div>

				<!-- Summary Section -->
				<div class="calculation-summary">
					<h4>Calculation Summary</h4>
					<div class="calculation-breakdown">
						<div class="calc-row">
							<span>Base Amount (Original Final):</span>
							<span class="calc-amount">{formatCurrency(baseAmount)}</span>
						</div>
						<div class="calc-row deduction">
							<span>- Discount:</span>
							<span class="calc-amount">{formatCurrency(discountAmount)}</span>
						</div>
						<div class="calc-row deduction">
							<span>- GRR Amount:</span>
							<span class="calc-amount">{formatCurrency(grrAmount)}</span>
						</div>
						<div class="calc-row deduction">
							<span>- PRI Amount:</span>
							<span class="calc-amount">{formatCurrency(priAmount)}</span>
						</div>
						<div class="calc-divider"></div>
						<div class="calc-row total">
							<span>New Final Amount:</span>
							<span class="calc-amount final" class:negative={!isValidAmount}>
								{formatCurrency(newFinalAmount)}
							</span>
						</div>
					</div>
					
					{#if !isValidAmount}
						<div class="error-message">
							⚠️ Total deductions cannot exceed the base amount
						</div>
					{/if}
				</div>
			</div>

			<div class="modal-footer">
				<button class="btn-cancel" on:click={closeEditAmountModal}>Cancel</button>
				<button 
					class="btn-save" 
					on:click={saveAmountAdjustment}
					disabled={!isValidAmount}
				>
					Save Adjustment
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Approver List Modal -->
<ApproverListModal 
	bind:isOpen={showApproverListModal}
	paymentData={pendingApprovalPayment}
	currentUserId={$currentUser?.id}
	currentUserName={$currentUser?.username || 'Unknown'}
	on:submitted={handleApprovalSubmitted}
	on:close={closeApproverModal}
/>

<style>
	.month-details-container {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #f8fafc;
		overflow: hidden;
	}

	.fixed-header-section {
		flex-shrink: 0;
		padding: 8px 8px 0 8px;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
	}

	.scrollable-content-section {
		flex: 1;
		overflow-y: auto;
		padding: 0 8px 8px 8px;
	}

	.month-details-header {
		margin-bottom: 24px;
		padding-bottom: 16px;
		border-bottom: 2px solid #e2e8f0;
		position: sticky;
		top: 0;
		background: white;
		z-index: 101;
		padding-top: 16px;
	}

	.month-details-header h2 {
		margin: 0;
		color: #1e293b;
		font-size: 24px;
		font-weight: 600;
	}

	.header-cards-container {
		display: block; /* Changed from grid to block for full width */
		margin-bottom: 12px;
	}

	.header-card {
		background: white;
		border-radius: 8px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		overflow: hidden;
		transition: all 0.2s ease;
		border: 1px solid #e2e8f0;
		width: 100%; /* Full width */
	}

	.header-card:hover {
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
	}

	.header-card-title {
		background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
		padding: 12px 16px;
		border-bottom: 1px solid #e2e8f0;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.header-card-title h3 {
		margin: 0;
		font-size: 14px;
		font-weight: 600;
		color: #374151;
	}

	.small-refresh-btn {
		background: rgba(255, 255, 255, 0.8);
		border: 1px solid #e2e8f0;
		border-radius: 4px;
		padding: 4px 6px;
		font-size: 12px;
		cursor: pointer;
		color: #374151;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		min-width: 24px;
		height: 24px;
	}

	.small-refresh-btn:hover {
		background: rgba(255, 255, 255, 1);
		border-color: #3b82f6;
		color: #3b82f6;
		transform: rotate(180deg);
	}

	.small-refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		pointer-events: none;
	}

	.payment-summary-card .header-card-title {
		background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%);
		border-bottom-color: #10b981;
	}

	.payment-summary-card .header-card-title h3 {
		color: #059669;
	}

	.calendar-card .header-card-title {
		background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
		border-bottom-color: #3b82f6;
	}

	.calendar-card .header-card-title h3 {
		color: #1d4ed8;
	}

	.header-card-content {
		padding: 16px;
	}

	.calendar-summary {
		margin-bottom: 12px;
		padding-bottom: 12px;
		border-bottom: 1px solid #e2e8f0;
	}

	.compact-stats {
		display: flex;
		flex-wrap: wrap;
		gap: 12px;
		margin-bottom: 0;
		align-items: center;
		justify-content: flex-start;
	}

	.stat-item {
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 6px;
		padding: 6px 12px;
		background: #f8fafc;
		border-radius: 6px;
		min-width: auto;
		flex: 0 0 auto;
		white-space: nowrap;
	}

	.stat-item.total-stat {
		background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%);
		border: 1px solid #10b981;
		margin-left: 0;
	}

	.stat-item.paid-stat {
		background: linear-gradient(135deg, #dbeafe 0%, #eff6ff 100%);
		border: 1px solid #3b82f6;
		margin-left: 0;
	}

	.stat-item.unpaid-stat {
		background: linear-gradient(135deg, #ffedd5 0%, #fff7ed 100%);
		border: 1px solid #fb923c;
		margin-left: 0;
	}

	.stat-value {
		font-weight: 700;
		color: #1e293b;
		font-size: 14px;
		line-height: 1;
	}

	.stat-value.total {
		color: #059669;
		font-size: 16px;
	}

	.stat-value.paid {
		color: #2563eb;
		font-size: 14px;
	}

	.stat-value.unpaid {
		color: #ea580c;
		font-size: 14px;
	}

	.stat-label {
		font-size: 11px;
		color: #64748b;
		font-weight: 500;
		text-align: center;
	}

	.compact-methods {
		display: none; /* Hide payment methods to save space */
	}

	.method-chip {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 6px 12px;
		background: #f1f5f9;
		border-radius: 20px;
		border: 1px solid #e2e8f0;
		font-size: 12px;
	}

	.method-name {
		color: #64748b;
		font-weight: 500;
	}

	.method-value {
		color: #059669;
		font-weight: 600;
	}

	.compact-calendar-grid {
		display: grid;
		grid-template-columns: repeat(7, 1fr);
		gap: 6px; /* Reduced from 8px */
		max-height: none; /* Remove max-height to show all dates without scrolling */
		overflow-y: visible; /* No scrolling needed */
		padding: 8px;
		background: #f8fafc;
		border-radius: 6px;
	}

	.mini-calendar-day {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 8px 6px; /* Reduced from 10px 6px */
		text-align: center;
		cursor: pointer;
		transition: all 0.2s ease;
		min-height: 50px; /* Reduced from 75px */
		display: flex;
		flex-direction: row; /* Changed to row layout */
		align-items: center;
		justify-content: space-between; /* Space between date and amount */
		font-size: 12px;
		position: relative;
	}

	.mini-calendar-day:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
	}

	/* Fully paid dates - green background */
	.mini-calendar-day.has-payments.fully-paid {
		border-color: #10b981;
		background: linear-gradient(135deg, #d1fae5 0%, #ecfdf5 100%);
	}

	.mini-calendar-day.has-payments.fully-paid:hover {
		border-color: #059669;
		background: linear-gradient(135deg, #a7f3d0 0%, #d1fae5 100%);
	}

	.mini-calendar-day.has-payments.fully-paid .mini-day-number {
		color: #059669;
	}

	/* Unpaid dates - light orange background */
	.mini-calendar-day.has-payments.has-unpaid {
		border-color: #fb923c;
		background: linear-gradient(135deg, #fed7aa 0%, #ffedd5 100%);
	}

	.mini-calendar-day.has-payments.has-unpaid:hover {
		border-color: #f97316;
		background: linear-gradient(135deg, #fdba74 0%, #fed7aa 100%);
	}

	.mini-calendar-day.has-payments.has-unpaid .mini-day-number {
		color: #ea580c;
	}

	.mini-calendar-day.no-payments {
		border-color: #e2e8f0;
		background: #f9fafb;
		opacity: 0.7;
	}

	/* Today's date - light blue background */
	.mini-calendar-day.is-today {
		border-color: #3b82f6;
		background: linear-gradient(135deg, #dbeafe 0%, #eff6ff 100%);
		border-width: 2px;
	}

	.mini-calendar-day.is-today:hover {
		border-color: #2563eb;
		background: linear-gradient(135deg, #bfdbfe 0%, #dbeafe 100%);
	}

	.mini-calendar-day.is-today .mini-day-number {
		color: #1d4ed8;
		font-weight: 800;
	}

	/* Today with payments - combine both styles */
	.mini-calendar-day.is-today.has-payments.fully-paid {
		border-color: #3b82f6;
		background: linear-gradient(135deg, #bfdbfe 0%, #d1fae5 100%);
	}

	.mini-calendar-day.is-today.has-payments.has-unpaid {
		border-color: #3b82f6;
		background: linear-gradient(135deg, #bfdbfe 0%, #fed7aa 100%);
	}

	/* Selected date - prominent highlight with purple accent */
	.mini-calendar-day.is-selected {
		border-color: #8b5cf6;
		border-width: 2px;
		background: linear-gradient(135deg, #ede9fe 0%, #f3e8ff 100%);
		box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
		font-weight: 600;
	}

	.mini-calendar-day.is-selected:hover {
		border-color: #7c3aed;
		background: linear-gradient(135deg, #ddd6fe 0%, #ede9fe 100%);
		box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.2);
	}

	.mini-calendar-day.is-selected .mini-day-number {
		color: #6d28d9;
		font-weight: 800;
	}

	.mini-day-info {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: 2px;
		flex-shrink: 0;
	}

	.mini-day-number {
		font-size: 16px; /* Reduced from 18px */
		font-weight: 700; /* Increased from 600 */
		color: #1e293b;
		line-height: 1;
		flex-shrink: 0;
	}

	.mini-day-name {
		font-size: 8px;
		color: #64748b;
		font-weight: 500;
		line-height: 1;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.mini-payment-info {
		display: flex;
		flex-direction: column;
		align-items: flex-end; /* Align to the right */
		margin-top: 0; /* Remove top margin */
		gap: 2px;
		flex: 1;
		min-width: 0;
	}

	.mini-count {
		font-size: 8px; /* Reduced from 10px */
		color: #059669;
		font-weight: 600;
		line-height: 1;
		white-space: nowrap;
	}

	.mini-amount {
		font-size: 10px; /* Reduced from 11px */
		color: #1e293b;
		font-weight: 700;
		line-height: 1;
		background: rgba(16, 185, 129, 0.15);
		padding: 2px 4px; /* Reduced from 3px 5px */
		border-radius: 3px;
		white-space: nowrap;
	}

	/* Unpaid amount styling */
	.mini-unpaid {
		font-size: 8px; /* Reduced from 10px */
		color: #ea580c;
		font-weight: 700;
		line-height: 1;
		background: rgba(249, 115, 22, 0.15);
		padding: 2px 4px; /* Reduced from 3px 5px */
		border-radius: 3px;
		margin-top: 1px;
		white-space: nowrap;
	}

	/* Update color for unpaid dates */
	.mini-calendar-day.has-unpaid .mini-count {
		color: #ea580c;
	}

	.day-number {
		font-size: 18px;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 4px;
		line-height: 1;
	}

	.calendar-day.has-payments .day-number {
		color: #059669;
	}

	.day-name {
		font-size: 11px;
		color: #64748b;
		font-weight: 500;
		margin-bottom: 6px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.payment-info {
		flex: 1;
		display: flex;
		flex-direction: column;
		justify-content: center;
		background: rgba(16, 185, 129, 0.1);
		border-radius: 6px;
		padding: 6px 4px;
		margin-top: 4px;
	}

	.payment-count {
		font-size: 10px;
		color: #059669;
		font-weight: 600;
		margin-bottom: 2px;
	}

	.payment-total {
		font-size: 10px;
		color: #1e293b;
		font-weight: 700;
	}

	.no-payment-info {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 9px;
		color: #9ca3af;
		font-weight: 500;
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
		gap: 16px;
		flex-wrap: wrap;
	}

	.filter-controls {
		display: flex;
		gap: 12px;
		align-items: center;
	}

	.filter-select {
		padding: 8px 12px;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		background: white;
		font-size: 13px;
		color: #374151;
		cursor: pointer;
		transition: all 0.2s;
		min-width: 180px;
	}

	.filter-select:hover {
		border-color: #3b82f6;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
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

	/* Enhanced Other Payments Placeholder */
	.placeholder-content {
		max-width: 600px;
		margin: 0 auto;
	}

	.future-features {
		margin-top: 20px;
		text-align: left;
		background: white;
		padding: 20px;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
	}

	.future-features h4 {
		margin: 0 0 12px 0;
		color: #374151;
		font-size: 14px;
		font-weight: 600;
	}

	.future-features ul {
		margin: 0;
		padding-left: 20px;
		color: #6b7280;
	}

	.future-features li {
		margin-bottom: 4px;
		font-size: 13px;
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
		text-align: center !important;
		margin-left: 70px !important;
		padding-left: 35px !important;
		display: flex !important;
		justify-content: flex-end !important;
		width: 100% !important;
		position: relative !important;
		right: -50px !important;
	}

	.header-column.status-header {
		margin-left: 0px;
		padding-left: 0px;
		text-align: center;
		margin-right: 0px;
		padding-right: 0px;
		width: 100%;
		display: flex;
		justify-content: center;
		overflow: visible;
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
	.vendors-scroll-container {
		min-width: 1400px;
	}

	.vendors-container {
		display: flex;
		flex-direction: column;
		gap: 0;
		border-left: 2px solid #e2e8f0;
		border-right: 2px solid #e2e8f0;
		border-bottom: 2px solid #e2e8f0;
		border-top: none;
		border-radius: 0 0 8px 8px;
		overflow: hidden;
		background: white;
	}

	.vendor-group {
		border: none;
		border-radius: 0;
		overflow: hidden;
		background: white;
		margin: 0;
		padding: 0;
	}

	.vendor-summary {
		display: flex;
		gap: 12px;
		font-size: 12px;
		font-weight: 600;
		color: #374151;
	}

	/* Table Wrapper */
	/* Clean Table Structure */
	.payments-table-wrapper {
		overflow-x: auto;
		margin: 0;
		padding: 0;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		background: white;
		width: 100%;
	}

	.payments-table {
		width: 100%;
		border-collapse: collapse;
		min-width: 1600px;
		font-size: 11px;
	}

	.table-header-row {
		background: #f8fafc;
	}

	.header-cell {
		padding: 12px 8px;
		border-right: 1px solid #e5e7eb;
		background: #f8fafc;
		text-align: center;
		font-weight: 600;
		font-size: 10px;
		letter-spacing: 0.3px;
		text-transform: uppercase;
		color: #475569;
		border-bottom: 2px solid #e2e8f0;
		white-space: nowrap;
	}

	.header-cell:first-child,
	.header-cell:nth-child(2) {
		text-align: left;
		padding-left: 16px;
	}

	.header-cell:nth-child(3),
	.header-cell:nth-child(4),
	.header-cell:nth-child(5) {
		text-align: right;
		padding-right: 12px;
	}

	.header-cell:last-child {
		border-right: none;
	}

	.payment-row {
		border-bottom: 1px solid #e5e7eb;
		transition: background-color 0.2s ease;
	}

	.payment-row:hover {
		background: #f9fafb;
	}

	.data-cell {
		padding: 12px 8px;
		border-right: 1px solid #e5e7eb;
		text-align: center;
		vertical-align: middle;
		color: #374151;
		white-space: nowrap;
	}

	.data-cell:first-child {
		text-align: left;
		padding-left: 16px;
	}

	.data-cell.vendor-cell {
		text-align: left;
		padding-left: 16px;
		font-weight: 500;
	}

	.data-cell.amount {
		text-align: right;
		padding-right: 12px;
		font-weight: 800;
		color: #059669;
		font-family: monospace;
	}

	.data-cell:last-child {
		border-right: none;
	}

	/* NEW SIMPLE TABLE STYLES */
	.simple-table-container {
		overflow-x: auto;
		margin: 0;
		padding: 0;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		background: white;
		width: 100%;
	}

	.simple-payments-table {
		width: 100%;
		border-collapse: collapse;
		min-width: 1600px;
		font-size: 11px;
	}

	.simple-payments-table th {
		padding: 12px 8px;
		border-right: 1px solid #e5e7eb;
		background: #f8fafc;
		text-align: center;
		font-weight: 600;
		font-size: 10px;
		letter-spacing: 0.3px;
		text-transform: uppercase;
		color: #475569;
		border-bottom: 2px solid #e2e8f0;
		white-space: nowrap;
	}

	.simple-payments-table th:first-child,
	.simple-payments-table th:nth-child(2) {
		text-align: left;
	}

	.simple-payments-table th:nth-child(3),
	.simple-payments-table th:nth-child(4),
	.simple-payments-table th:nth-child(5) {
		text-align: right;
	}

	.simple-payments-table td {
		padding: 12px 8px;
		border-right: 1px solid #e5e7eb;
		border-bottom: 1px solid #e5e7eb;
		text-align: center;
		vertical-align: middle;
		color: #374151;
		font-size: 11px;
	}

	.simple-payments-table td:first-child {
		text-align: left;
	}

	.simple-payments-table tr:hover {
		background: #f9fafb;
	}

	/* Distinct light colors for each column - subtle but distinguishable */
	.simple-payments-table th:nth-child(1),
	.simple-payments-table td:nth-child(1) {
		background-color: #fef7f7; /* Light red - Bill # */
	}

	.simple-payments-table th:nth-child(2),
	.simple-payments-table td:nth-child(2) {
		background-color: #f0f9ff; /* Light blue - Vendor */
	}

	.simple-payments-table th:nth-child(3),
	.simple-payments-table td:nth-child(3) {
		background-color: #f0fdf4; /* Light green - Amount */
	}

	.simple-payments-table th:nth-child(4),
	.simple-payments-table td:nth-child(4) {
		background-color: #fffbeb; /* Light yellow - Orig. Bill */
	}

	.simple-payments-table th:nth-child(5),
	.simple-payments-table td:nth-child(5) {
		background-color: #fdf4ff; /* Light purple - Orig. Final */
	}

	.simple-payments-table th:nth-child(6),
	.simple-payments-table td:nth-child(6) {
		background-color: #f0fdfa; /* Light teal - Bill Date */
	}

	.simple-payments-table th:nth-child(7),
	.simple-payments-table td:nth-child(7) {
		background-color: #fef3f2; /* Light orange - Due Date */
	}

	.simple-payments-table th:nth-child(8),
	.simple-payments-table td:nth-child(8) {
		background-color: #f8fafc; /* Light gray - Orig. Due */
	}

	.simple-payments-table th:nth-child(9),
	.simple-payments-table td:nth-child(9) {
		background-color: #f0f4ff; /* Light indigo - Branch */
	}

	.simple-payments-table th:nth-child(10),
	.simple-payments-table td:nth-child(10) {
		background-color: #fdf2f8; /* Light pink - Payment */
	}

	.simple-payments-table th:nth-child(11),
	.simple-payments-table td:nth-child(11) {
		background-color: #f7fee7; /* Light lime - Priority */
	}

	.simple-payments-table th:nth-child(12),
	.simple-payments-table td:nth-child(12) {
		background-color: #fefce8; /* Light amber - Bank */
	}

	.simple-payments-table th:nth-child(13),
	.simple-payments-table td:nth-child(13) {
		background-color: #ecfdf5; /* Light emerald - IBAN */
	}

	.simple-payments-table th:nth-child(14),
	.simple-payments-table td:nth-child(14) {
		background-color: #f1f5f9; /* Light slate - Mark Paid */
	}

	.simple-payments-table th:nth-child(15),
	.simple-payments-table td:nth-child(15) {
		background-color: #f0f8ff; /* Light sky - Status */
	}

	.simple-payments-table th:nth-child(16),
	.simple-payments-table td:nth-child(16) {
		background-color: #fafafa; /* Light neutral - Actions */
	}

	/* Light row striping overlay */
	.simple-payments-table tbody tr:nth-child(even) td {
		filter: brightness(0.98);
	}

	/* Hover effect that overrides column coloring */
	.simple-payments-table tbody tr:hover td {
		background-color: #dbeafe !important;
		transform: translateY(-1px);
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.vendors-scroll-container {
		overflow-x: auto;
		min-width: 1700px;
		width: 100%;
	}

	/* Vendor Structure */
	.vendor-title-row {
		padding: 6px 16px;
		margin: 0;
		display: flex;
		justify-content: space-between;
		align-items: center;
		border-bottom: 1px solid #e5e7eb;
		border-top: none;
		min-width: 1100px;
		font-size: 12px;
	}

	.vendor-name {
		margin: 0;
		font-size: 14px;
		font-weight: 700;
	}

	.vendor-payments-rows {
		display: flex;
		flex-direction: column;
		margin: 0;
		padding: 0;
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
		border: none;
		border-bottom: 1px solid #e5e7eb;
		margin: 0;
		background: white;
		padding: 0;
		transition: all 0.2s ease;
		position: relative;
		display: flex;
		align-items: flex-start;
		gap: 0;
		min-width: 1450px;
		min-height: 50px;
	}

	.payment-row:last-child {
		border-radius: 0 0 8px 8px;
	}

	.payment-row:hover {
		background: #f9fafb;
		transform: translateX(2px);
	}

	.data-cell {
		padding: 12px 8px;
		border-right: 1px solid #e5e7eb;
		text-align: center;
		vertical-align: middle;
		color: #374151;
		font-size: 11px;
	}

	/* Specific alignments for different cell types */
	.data-cell.bill-cell {
		text-align: left;
		padding-left: 16px;
	}

	.data-cell.vendor-cell {
		text-align: left;
		padding-left: 16px;
		font-weight: 500;
	}

	.data-cell.amount {
		text-align: right;
		padding-right: 12px;
		font-weight: 600;
		color: #059669;
		font-family: monospace;
	}

	.data-cell.status-cell {
		text-align: center;
	}

	.data-cell.actions-cell {
		text-align: center;
	}

	.data-cell:last-child {
		border-right: none;
	}

	.data-cell:first-child {
		border-left: 2px solid #e2e8f0;
	}

	/* Specific cell styling */
	.data-cell.amount {
		font-weight: 800;
		color: #059669;
		font-size: 12px;
		text-align: right;
		justify-content: flex-end;
		font-family: monospace;
		white-space: nowrap;
	}

	.data-cell.amount.original-amount {
		font-weight: 800; /* even bolder for original amounts */
		font-size: 12px; /* bigger size */
		color: #0d7377; /* slightly different green */
	}

	.data-cell.drag-handle {
		font-size: 14px;
		cursor: grab;
		opacity: 0.5;
		transition: opacity 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: bold;
		min-height: 30px;
	}

	.payment-row:hover .data-cell.drag-handle {
		opacity: 1;
	}

	.bill-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.bill-number {
		font-weight: 600;
		font-size: 11px;
		color: #1e293b;
	}

	.vendor-name-small {
		font-size: 9px;
		font-weight: 500;
		opacity: 0.8;
	}

	.data-cell.vendor-cell {
		font-weight: 600;
		font-size: 10px;
		word-wrap: break-word;
		word-break: break-word;
		hyphens: auto;
		margin-left: 0px;
		padding-left: 65px;
		display: flex;
		align-items: center;
		justify-content: flex-start;
		min-height: 40px;
		white-space: normal;
		overflow: visible;
		min-width: 280px;
		max-width: 280px;
	}

	.data-cell.bill-cell {
		display: flex;
		align-items: center;
		justify-content: flex-start;
		overflow: hidden;
		max-width: 110px;
		min-width: 110px;
		width: 110px;
		padding-left: 0px;
		margin-left: 0px;
		min-height: 40px;
	}

	.bill-number-badge {
		background: #f3f4f6;
		padding: 4px 6px;
		border-radius: 4px;
		font-size: 10px;
		font-weight: 600;
		color: #374151;
		border: 1px solid #e5e7eb;
		display: inline-block;
		white-space: normal;
		max-width: 120px;
		width: fit-content;
		text-align: center;
		word-break: break-word;
		line-height: 1.3;
	}

	.payment-method {
		background: #e5e7eb;
		padding: 1px 4px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
		display: inline-block;
		width: fit-content;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		max-width: 100%;
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
		margin-left: 0px;
		white-space: nowrap;
		display: inline-block;
		min-width: 80px;
		text-align: center;
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

	/* Responsive Design */
	@media (max-width: 1024px) {
		.header-cards-container {
			grid-template-columns: 1fr;
			gap: 12px;
		}
		
		.compact-calendar-grid {
			max-height: 140px;
		}
		
		.compact-stats {
			gap: 12px;
		}
	}

	@media (max-width: 768px) {
		.header-card-content {
			padding: 12px;
		}
		
		.header-card-title {
			padding: 10px 12px;
		}
		
		.header-card-title h3 {
			font-size: 13px;
		}
		
		.compact-calendar-grid {
			gap: 3px;
			max-height: 120px;
		}
		
		.mini-calendar-day {
			min-height: 28px;
			padding: 4px 2px;
		}
		
		.mini-day-number {
			font-size: 11px;
		}
		
		.mini-payment-indicator {
			width: 12px;
			height: 12px;
			font-size: 7px;
		}
		
		.compact-stats {
			gap: 8px;
		}
		
		.stat-item {
			padding: 6px 8px;
			min-width: 50px;
		}
		
		.stat-value {
			font-size: 14px;
		}
		
		.stat-value.total {
			font-size: 16px;
		}
		
		.method-chip {
			padding: 4px 8px;
			font-size: 11px;
		}
	}

	@media (max-width: 480px) {
		.header-cards-container {
			gap: 8px;
		}
		
		.compact-calendar-grid {
			gap: 2px;
			max-height: 100px;
			padding: 2px;
		}
		
		.mini-calendar-day {
			min-height: 24px;
			padding: 2px 1px;
		}
		
		.mini-day-number {
			font-size: 10px;
		}
		
		.mini-payment-indicator {
			width: 10px;
			height: 10px;
			font-size: 6px;
		}
		
		.compact-stats {
			flex-direction: column;
			gap: 6px;
		}
		
		.stat-item {
			flex-direction: row;
			justify-content: space-between;
			padding: 6px 10px;
		}
		
		.compact-methods {
			gap: 4px;
		}
		
		.method-chip {
			padding: 3px 6px;
			font-size: 10px;
		}
	}





	.payment-status-header {
		text-align: center;
		font-size: 10px;
		font-weight: 700;
		color: #475569;
		text-transform: uppercase;
	}

	.payment-status-cell {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 8px;
	}

	.payment-checkbox {
		width: 20px;
		height: 20px;
		cursor: pointer;
		accent-color: #10b981;
		margin: 2;
		opacity: 1 !important;
		position: relative !important;
		z-index: 10;
	}

	/* Payment Method Edit Button Styles */
	.payment-method-cell {
		display: flex;
		align-items: center;
		gap: 8px;
		justify-content: flex-start;
		position: relative;
	}

	.edit-payment-method-btn {
		background: #f59e0b;
		color: white;
		border: none;
		border-radius: 4px;
		padding: 4px 6px;
		font-size: 12px;
		cursor: pointer;
		transition: all 0.2s ease;
		opacity: 0.8;
		min-width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-left: 8px;
		flex-shrink: 0;
	}

	.edit-payment-method-btn:hover {
		background: #d97706;
		opacity: 1;
		transform: scale(1.1);
	}

	/* Priority Badge Styles */
	.priority-cell {
		text-align: center;
	}

	.priority-badge {
		display: inline-block;
		padding: 4px 10px;
		border-radius: 10px;
		font-size: 10px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		white-space: nowrap;
	}

	.priority-most {
		background: #fee2e2;
		color: #991b1b;
		border: 1px solid #fca5a5;
	}

	.priority-medium {
		background: #fed7aa;
		color: #c2410c;
		border: 1px solid #fdba74;
	}

	.priority-normal {
		background: #dbeafe;
		color: #1e40af;
		border: 1px solid #93c5fd;
	}

	.priority-low {
		background: #f3f4f6;
		color: #6b7280;
		border: 1px solid #d1d5db;
	}

	/* Edit Modal Styles - Matching PaymentManager */
	.edit-modal {
		background: white;
		border-radius: 12px;
		width: 90%;
		max-width: 600px;
		max-height: 80vh;
		overflow-y: auto;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
	}

	.edit-form {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
	}

	.form-row.single-column {
		grid-template-columns: 1fr;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.form-group label {
		font-weight: 500;
		color: #374151;
		font-size: 14px;
	}

	.form-group input,
	.form-group select {
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s ease;
	}

	.form-group input:focus,
	.form-group select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.placeholder-field {
		opacity: 0.6;
	}

	.disabled-field {
		padding: 10px 12px;
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		color: #6b7280;
		font-style: italic;
		font-size: 14px;
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding: 0 24px 24px 24px;
		border-top: 1px solid #e5e7eb;
		margin-top: 24px;
		padding-top: 24px;
	}

	.cancel-btn {
		padding: 10px 20px;
		border: 1px solid #d1d5db;
		background: white;
		color: #374151;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
		transition: all 0.2s ease;
	}

	.cancel-btn:hover {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.save-btn {
		padding: 10px 20px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
		transition: all 0.2s ease;
	}

	.save-btn:hover {
		background: #2563eb;
	}

	.actions-header {
		font-weight: 600;
		color: #374151;
		text-align: center;
	}

	.actions-cell {
		display: flex;
		justify-content: flex-start;
		align-items: center;
		padding: 8px 4px 8px 160px;
		min-width: 100px;
	}

	.reschedule-btn {
		padding: 6px 12px;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 11px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
		white-space: nowrap;
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
		display: inline-flex;
		align-items: center;
		gap: 4px;
	}

	.reschedule-btn:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
	}

	.reschedule-btn:active {
		transform: translateY(0);
	}

	.reschedule-btn:disabled {
		background: #d1d5db;
		cursor: not-allowed;
		transform: none;
		box-shadow: none;
	}

	.close-request-btn {
		padding: 6px 12px;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 11px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
		white-space: nowrap;
		box-shadow: 0 2px 4px rgba(16, 185, 129, 0.2);
		display: inline-flex;
		align-items: center;
		gap: 4px;
		margin-left: 4px;
	}

	.close-request-btn:hover {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(16, 185, 129, 0.3);
	}

	.close-request-btn:active {
		transform: translateY(0);
	}

	.paid-label {
		color: #10b981;
		font-weight: 600;
		font-size: 11px;
		padding: 4px 8px;
		background: rgba(16, 185, 129, 0.1);
		border-radius: 4px;
	}

	.date-input {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		color: #374151;
		min-width: 150px;
	}

	.date-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	/* Responsive grid for Actions column */
	@media (max-width: 1400px) {
		.payment-header-row,
		.payment-data-row {
			grid-template-columns: 35px 120px 160px 90px 100px 100px 85px 85px 95px 120px 90px 140px 130px 70px 5px 130px 100px;
		}
	}

	@media (max-width: 768px) {
		.form-row {
			grid-template-columns: 1fr;
		}
		
		.edit-modal {
			width: 95%;
			margin: 20px;
		}
	}

	/* Edit Amount Button */
	.edit-amount-btn {
		padding: 6px 10px;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 16px;
		transition: all 0.2s ease;
		margin-left: 4px;
	}

	.edit-amount-btn:hover {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(16, 185, 129, 0.3);
	}

	.delete-btn {
		padding: 6px 10px;
		background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 16px;
		transition: all 0.2s ease;
		margin-left: 4px;
	}

	.delete-btn:hover {
		background: linear-gradient(135deg, #b91c1c 0%, #991b1b 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(220, 38, 38, 0.3);
	}

	/* Edit Amount Modal */
	.edit-amount-modal {
		width: 650px;
		max-width: 95vw;
		max-height: 85vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.edit-amount-modal .modal-header {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		padding: 20px 24px;
		border-radius: 12px 12px 0 0;
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-shrink: 0;
	}

	.edit-amount-modal .modal-header h3 {
		margin: 0;
		font-size: 20px;
		font-weight: 700;
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.edit-amount-modal .close-btn {
		background: rgba(255, 255, 255, 0.2);
		color: white;
		border: none;
		width: 32px;
		height: 32px;
		border-radius: 50%;
		cursor: pointer;
		font-size: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}

	.edit-amount-modal .close-btn:hover {
		background: rgba(255, 255, 255, 0.3);
		transform: rotate(90deg);
	}

	.edit-amount-modal .modal-body {
		overflow-y: auto;
		padding: 24px;
		flex: 1;
	}

	.payment-info-section {
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		padding: 20px;
		border-radius: 12px;
		margin-bottom: 24px;
		border: 1px solid #86efac;
	}

	.payment-info-section h4 {
		margin: 0 0 16px 0;
		font-size: 14px;
		font-weight: 700;
		color: #059669;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.payment-info-section h4::before {
		content: '📋';
		font-size: 18px;
	}

	.info-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 16px;
	}

	.info-item {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.info-label {
		font-size: 11px;
		color: #059669;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.info-value {
		font-size: 15px;
		color: #1f2937;
		font-weight: 600;
	}

	.info-value.amount-highlight {
		color: #059669;
		font-weight: 700;
		font-size: 18px;
	}

	.adjustment-section {
		margin-bottom: 24px;
	}

	.adjustment-section h4 {
		margin: 0 0 20px 0;
		font-size: 14px;
		font-weight: 700;
		color: #374151;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.adjustment-section h4::before {
		content: '⚙️';
		font-size: 18px;
	}

	.adjustment-group {
		background: #ffffff;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		padding: 20px;
		margin-bottom: 16px;
		transition: all 0.3s ease;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
	}

	.adjustment-group:hover {
		border-color: #d1d5db;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
	}

	.adjustment-group:focus-within {
		border-color: #10b981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
	}

	.adjustment-label {
		display: flex;
		align-items: center;
		gap: 10px;
		font-size: 15px;
		font-weight: 700;
		color: #1f2937;
		margin-bottom: 16px;
		padding-bottom: 12px;
		border-bottom: 2px solid #f3f4f6;
	}

	.adjustment-icon {
		font-size: 22px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.adjustment-input {
		width: 100%;
		padding: 12px 16px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 15px;
		font-weight: 500;
		margin-bottom: 12px;
		transition: all 0.2s;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
	}

	.adjustment-input:hover {
		border-color: #d1d5db;
	}

	.adjustment-input:focus {
		outline: none;
		border-color: #10b981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
	}

	.adjustment-input[type="number"] {
		font-family: 'Courier New', monospace;
		font-weight: 600;
	}

	.adjustment-input::placeholder {
		color: #9ca3af;
		font-weight: 400;
	}

	.adjustment-input[required]:invalid {
		border-color: #ef4444;
	}

	.adjustment-notes {
		width: 100%;
		padding: 12px 16px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 14px;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
		resize: vertical;
		min-height: 70px;
		transition: all 0.2s;
		line-height: 1.5;
	}

	.adjustment-notes:hover {
		border-color: #d1d5db;
	}

	.adjustment-notes:focus {
		outline: none;
		border-color: #10b981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
	}

	.adjustment-notes::placeholder {
		color: #9ca3af;
	}

	.calculation-summary {
		background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
		padding: 20px;
		border-radius: 12px;
		border: 2px solid #93c5fd;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.1);
	}

	.calculation-summary h4 {
		margin: 0 0 16px 0;
		font-size: 14px;
		font-weight: 700;
		color: #1e40af;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.calculation-summary h4::before {
		content: '🧮';
		font-size: 18px;
	}

	.calculation-breakdown {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.calc-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 8px 12px;
		border-radius: 6px;
		font-size: 14px;
		background: rgba(255, 255, 255, 0.5);
	}

	.calc-row.deduction {
		color: #dc2626;
		padding-left: 24px;
		background: rgba(220, 38, 38, 0.05);
	}

	.calc-row.total {
		font-weight: 700;
		font-size: 17px;
		color: #1f2937;
		padding: 12px;
		background: white;
		border: 2px solid #10b981;
		margin-top: 8px;
	}

	.calc-amount {
		font-weight: 700;
		font-family: 'Courier New', monospace;
		letter-spacing: 0.5px;
	}

	.calc-amount.final {
		color: #059669;
		font-size: 20px;
		transition: color 0.3s ease;
	}

	.calc-amount.final.negative {
		color: #dc2626;
		animation: pulse 1s ease-in-out infinite;
	}

	@keyframes pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.7; }
	}

	.calc-divider {
		height: 2px;
		background: linear-gradient(to right, transparent, #3b82f6, transparent);
		margin: 12px 0;
		opacity: 0.5;
	}

	.error-message {
		margin-top: 16px;
		padding: 12px 16px;
		background: #fee2e2;
		color: #dc2626;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 600;
		border-left: 4px solid #dc2626;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.modal-footer {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
		padding: 20px 24px;
		border-top: 2px solid #f3f4f6;
		background: #fafafa;
		border-radius: 0 0 12px 12px;
		flex-shrink: 0;
	}

	.btn-cancel,
	.btn-save {
		padding: 12px 28px;
		border-radius: 8px;
		font-size: 15px;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		border: none;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.btn-cancel {
		background: white;
		color: #374151;
		border: 2px solid #e5e7eb;
	}

	.btn-cancel:hover {
		background: #f9fafb;
		border-color: #d1d5db;
	}

	.btn-save {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.btn-save::before {
		content: '✓';
		font-size: 18px;
	}

	.btn-save:hover:not(:disabled) {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		box-shadow: 0 6px 16px rgba(16, 185, 129, 0.4);
		transform: translateY(-2px);
	}

	.btn-save:disabled {
		opacity: 0.5;
		cursor: not-allowed;
		transform: none;
	}

	/* Fullscreen Modal Styles for Request Closure */
	.modal-overlay-fullscreen {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.7);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 9999;
		padding: 20px;
	}

	.modal-container-fullscreen {
		background: white;
		border-radius: 12px;
		width: 95vw;
		max-width: 1600px;
		height: 90vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
	}

	.modal-header-fullscreen {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem 2rem;
		border-bottom: 2px solid #e5e7eb;
		background: #f9fafb;
	}

	.modal-header-fullscreen h3 {
		font-size: 1.5rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0;
	}

	.modal-body-fullscreen {
		flex: 1;
		overflow-y: auto;
		padding: 0;
	}

	/* ============================================
	   APPROVAL SYSTEM STYLES
	   ============================================ */

	/* Table row positioning for overlay */
	.simple-payments-table tbody tr {
		position: relative;
	}

	/* Maskable columns - blur when approval is needed */
	/* Blur effect for rows that need approval */
	tr.needs-approval-row td.maskable-column {
		filter: blur(4px) !important;
		pointer-events: none !important;
		user-select: none !important;
		position: relative;
	}

	/* Always visible columns remain clear even in needs-approval rows */
	tr.needs-approval-row td.always-visible {
		filter: none !important;
		pointer-events: all !important;
		user-select: all !important;
		position: relative;
	}
</style>