<script>
	import { onMount, tick } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { iconUrlMap } from '$lib/stores/iconStore';

	// Component state
	let isLoading = false;
	let selectedDate = '';
	let dailyBudget = 0;
	
	// Date range state
	let showDateRange = false;
	let dateRangeStart = '';
	let dateRangeEnd = '';
	let dateRangeData = [];
	let dateRangeLoading = false;
	
	// Data arrays
	let vendorPayments = [];
	let expenseSchedules = [];
	let nonApprovedPayments = [];
	let branches = [];
	let branchMap = new Map(); // branch_id -> {name_en, location_en}
	
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
	let showPaymentMethodModal = false; // Modal for allocating budget by payment method
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
	$: breakdown = getDetailedBreakdown();
	
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

	// Sort expense schedules by vendor name
	$: sortedExpenseSchedules = [...filteredExpenseSchedules].sort((a, b) => {
		const vendorA = (a.vendor_name || '').toLowerCase();
		const vendorB = (b.vendor_name || '').toLowerCase();
		return vendorA.localeCompare(vendorB);
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

	// Print functionality
	let showPrintPreview = false;

	// Vendor grouping functionality
	let showGroupDetailsModal = false;
	let selectedGroup = null; // Will hold the grouped vendor data
	let groupExpandedRows = new Set(); // Track which groups are expanded to show individual items
	$: groupedVendorPayments = getGroupedVendorPayments(filteredVendorPayments);

	function getGroupedVendorPayments(payments) {
		// Group by vendor_id and branch_id
		const groupMap = new Map();
		
		payments.forEach(payment => {
			const groupKey = `${payment.vendor_id}|${payment.branch_id}`;
			if (!groupMap.has(groupKey)) {
				groupMap.set(groupKey, {
					vendor_id: payment.vendor_id,
					vendor_name: payment.vendor_name,
					branch_id: payment.branch_id,
					branch_name: payment.branch_name,
					payment_method: payment.payment_method,
					total_amount: 0,
					bill_count: 0,
					bills: [],
					approval_statuses: new Set()
				});
			}
			const group = groupMap.get(groupKey);
			group.total_amount += payment.final_bill_amount || payment.bill_amount;
			group.bill_count += 1;
			group.bills.push(payment);
			group.approval_statuses.add(payment.approval_status);
		});
		
		return Array.from(groupMap.values());
	}

	function openGroupDetailsModal(group) {
		selectedGroup = group;
		showGroupDetailsModal = true;
	}

	function closeGroupDetailsModal() {
		showGroupDetailsModal = false;
		selectedGroup = null;
	}

	function toggleGroupExpand(groupKey) {
		if (groupExpandedRows.has(groupKey)) {
			groupExpandedRows.delete(groupKey);
		} else {
			groupExpandedRows.add(groupKey);
		}
		groupExpandedRows = groupExpandedRows;
		calculateBudget();
	}

	function generatePrintPreview() {
		showPrintPreview = true;
	}

	function closePrintPreview() {
		showPrintPreview = false;
	}

	function printSchedule() {
		// Trigger browser's print dialog which allows saving as PDF
		window.print();
	}

	function saveAsPDF() {
		// Get the print template element
		const printTemplate = document.querySelector('#printModalOverlay .print-template');
		
		if (!printTemplate) {
			alert('Print template not found');
			return;
		}

		// Create a new window for printing
		const printWindow = window.open('', '_blank', 'width=1200,height=800');
		
		// Write the HTML content
		printWindow.document.write(`
			<!DOCTYPE html>
			<html>
			<head>
				<title>Daily Budget Schedule - ${formatDate(selectedDate)}</title>
				<style>
					@page {
						size: A4 landscape;
						margin: 8mm;
					}
					* {
						box-sizing: border-box;
					}
					body {
						margin: 0;
						padding: 10mm;
						font-family: Arial, sans-serif;
						background: white;
					}
					h1 { 
						text-align: center; 
						color: #1f2937; 
						margin: 0 0 10px 0;
						font-size: 2rem;
					}
					h2 { 
						color: #1f2937; 
						border-bottom: 2px solid #3b82f6; 
						padding-bottom: 8px; 
						margin: 0 0 15px 0;
						font-size: 1.3rem;
					}
					.print-header { 
						border-bottom: 3px solid #3b82f6; 
						padding-bottom: 15px; 
						margin-bottom: 30px; 
					}
					.print-header-top {
						display: flex;
						justify-content: space-between;
						align-items: flex-start;
						margin-bottom: 20px;
					}
					.print-logo { 
						display: flex; 
						align-items: center; 
						gap: 12px; 
					}
					.logo-img { 
						width: 50px; 
						height: 50px; 
					}
					.app-name {
						font-size: 1.3rem;
						font-weight: 700;
						color: #1f2937;
					}
					.print-meta {
						text-align: right;
						display: flex;
						flex-direction: column;
						gap: 6px;
						font-size: 0.95rem;
						color: #374151;
					}
					.print-meta strong {
						color: #1f2937;
					}
					.print-date-info {
						color: #3b82f6;
						font-size: 1.05rem;
					}
					.print-summary { 
						display: grid; 
						grid-template-columns: repeat(4, 1fr); 
						gap: 20px; 
						margin-bottom: 30px; 
						padding: 20px; 
						background: #f9fafb; 
						border: 2px solid #e5e7eb;
						border-radius: 8px;
					}
					.print-summary-item {
						display: flex;
						flex-direction: column;
						gap: 5px;
					}
					.print-label {
						font-size: 0.9rem;
						color: #6b7280;
						font-weight: 600;
					}
					.print-value {
						font-size: 1.3rem;
						color: #1f2937;
						font-weight: 700;
					}
					.print-section {
						margin-bottom: 30px;
						page-break-inside: auto;
					}
					table { 
						border-collapse: collapse; 
						width: 100%; 
						margin-bottom: 20px; 
						font-size: 8pt;
					}
					thead {
						display: table-header-group;
					}
					tbody {
						display: table-row-group;
					}
					th, td { 
						border: 1px solid #e5e7eb; 
						padding: 8px 6px; 
						text-align: left; 
					}
					th { 
						background: #3b82f6; 
						color: white; 
						font-weight: 600; 
					}
					tr:nth-child(even) { 
						background: #f9fafb; 
					}
					tr {
						page-break-inside: avoid;
					}
					.status-badge { 
						display: inline-block;
						padding: 4px 10px; 
						border-radius: 4px; 
						font-size: 0.85rem; 
						font-weight: 600; 
					}
					.status-badge.over { 
						background: #fee2e2; 
						color: #dc2626; 
					}
					.status-badge.within { 
						background: #d1fae5; 
						color: #059669; 
					}
					.status-badge.unused { 
						background: #f3f4f6; 
						color: #6b7280; 
					}
					.status-badge.approved { 
						background: #d1fae5; 
						color: #059669; 
					}
					.status-badge.pending { 
						background: #fef3c7; 
						color: #d97706; 
					}
					.negative {
						color: #dc2626;
						font-weight: 700;
					}
				</style>
			</head>
			<body>
				${printTemplate.innerHTML}
			</body>
			</html>
		`);
		
		printWindow.document.close();
		
		// Wait for content to load, then trigger print
		printWindow.onload = function() {
			printWindow.focus();
			printWindow.print();
			// Close the window after printing/saving
			setTimeout(() => printWindow.close(), 100);
		};
	}

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

		console.log('🔄 Running getDetailedBreakdown with', vendorPayments.length, 'vendors,', expenseSchedules.length, 'expenses');

		// Helper function to get payment method from an object (tries multiple field names)
		const getPaymentMethod = (obj) => {
			if (!obj) return null;
			// Try different possible field names
			return obj.payment_method 
				|| obj.payment_method_name 
				|| obj.paymentMethod
				|| obj.payment_method_en
				|| obj.method
				|| null;
		};

		// Collect all available payment methods from all data (regardless of selection)
		vendorPayments.forEach((payment, index) => {
			const method = getPaymentMethod(payment);
			if (method) {
				breakdown.allPaymentMethods.add(method);
				if (index === 0) console.log('✅ Found payment method in vendor payment:', method);
			}
		});

		expenseSchedules.forEach((expense, index) => {
			const method = getPaymentMethod(expense);
			if (method) {
				breakdown.allPaymentMethods.add(method);
				if (index === 0) console.log('✅ Found payment method in expense schedule:', method);
			}
		});

		nonApprovedPayments.forEach((payment, index) => {
			const method = getPaymentMethod(payment);
			if (method) {
				breakdown.allPaymentMethods.add(method);
				if (index === 0) console.log('✅ Found payment method in non-approved payment:', method);
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
				const method = getPaymentMethod(payment) || 'Unknown';
				
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
				const method = getPaymentMethod(expense) || 'Unknown';
				
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
				const method = getPaymentMethod(payment) || 'Unknown';
				
				breakdown.byPaymentMethod.set(method, (breakdown.byPaymentMethod.get(method) || 0) + amount);
			}
		});

		console.log('🔍 Payment Methods Found:', Array.from(breakdown.allPaymentMethods));
		console.log('💰 Payment Method Breakdown:', Object.fromEntries(breakdown.byPaymentMethod));
		if (breakdown.allPaymentMethods.size === 0) {
			console.log('⚠️ No payment methods detected!');
			console.log('📊 Vendor payments count:', vendorPayments.length);
			console.log('📊 Expense schedules count:', expenseSchedules.length);
			console.log('📊 Non-approved payments count:', nonApprovedPayments.length);
			if (vendorPayments.length > 0) {
				console.log('📋 Vendor payment fields:', Object.keys(vendorPayments[0]));
				console.log('💳 Sample vendor payment_method values:', vendorPayments.slice(0, 3).map((p, i) => `[${i}]: "${p.payment_method}"`));
			}
			if (expenseSchedules.length > 0) {
				console.log('📋 Expense schedule fields:', Object.keys(expenseSchedules[0]));
				console.log('💳 Sample expense payment_method values:', expenseSchedules.slice(0, 3).map((e, i) => `[${i}]: "${e.payment_method}"`));
			}
		}

		return breakdown;
	}

	// Get breakdown for ALL scheduled items (not filtered by selection) - for display card
	function getAllScheduledBreakdown() {
		const breakdown = new Map();

		const getPaymentMethod = (obj) => {
			if (!obj) return null;
			return obj.payment_method 
				|| obj.payment_method_name 
				|| obj.paymentMethod
				|| obj.payment_method_en
				|| obj.method
				|| null;
		};

		// Add ALL vendor payments regardless of selection
		vendorPayments.forEach(payment => {
			const amount = payment.final_bill_amount || payment.bill_amount;
			const method = getPaymentMethod(payment) || 'Unknown';
			breakdown.set(method, (breakdown.get(method) || 0) + amount);
		});

		// Add ALL expense schedules regardless of selection
		expenseSchedules.forEach(expense => {
			const amount = expense.amount;
			const method = getPaymentMethod(expense) || 'Unknown';
			breakdown.set(method, (breakdown.get(method) || 0) + amount);
		});

		// Add ALL non-approved payments regardless of selection
		nonApprovedPayments.forEach(payment => {
			const amount = payment.final_bill_amount || payment.bill_amount;
			const method = getPaymentMethod(payment) || 'Unknown';
			breakdown.set(method, (breakdown.get(method) || 0) + amount);
		});

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

	async function openPaymentMethodModal() {
		// Ensure data is loaded for the selected date
		if (!selectedDate) {
			alert('❌ Please select a date first');
			return;
		}

		// Always load fresh data to ensure we have the latest
		console.log('📋 Loading payment data...');
		isLoading = true;
		try {
			await loadScheduledItems();
			
			// Wait for Svelte to process reactive updates
			await tick();
			await tick(); // Extra tick to be sure
			
			// Manually recalculate breakdown to force update
			breakdown = getDetailedBreakdown();
			
			// Wait again for the new breakdown to be processed
			await tick();
			
			// Manually check if we have payment methods now
			console.log('✅ Data loaded. Vendor payments:', vendorPayments.length, 'Expenses:', expenseSchedules.length);
			console.log('💳 Breakdown allPaymentMethods size:', breakdown?.allPaymentMethods?.size || 0);
			console.log('💳 Payment methods found:', Array.from(breakdown?.allPaymentMethods || []));
			
			// Force a manual check of payment methods
			if (vendorPayments.length === 0 && expenseSchedules.length === 0) {
				alert('⚠️ No scheduled payments for this date');
				return;
			}
		} catch (error) {
			console.error('Error loading data:', error);
			alert('❌ Error loading data: ' + error.message);
			return;
		} finally {
			isLoading = false;
		}

		// Open modal with fresh data
		showPaymentMethodModal = true;
	}

	// Get payment method source (vendor or expense)
	function getPaymentMethodSource(method) {
		const vendorMethods = new Set();
		const expenseMethods = new Set();

		vendorPayments.forEach(p => {
			if (p.payment_method) vendorMethods.add(p.payment_method);
		});

		expenseSchedules.forEach(e => {
			if (e.payment_method) expenseMethods.add(e.payment_method);
		});

		if (vendorMethods.has(method) && !expenseMethods.has(method)) {
			return 'vendor';
		} else if (expenseMethods.has(method) && !vendorMethods.has(method)) {
			return 'expense';
		} else {
			return 'both';
		}
	}

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
		filteredVendorPayments.forEach(payment => selectedVendorPayments.add(payment.id));
		selectedVendorPayments = selectedVendorPayments;
		calculateBudget();
	}

	function selectAllExpenseSchedules() {
		filteredExpenseSchedules.forEach(expense => selectedExpenseSchedules.add(expense.id));
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

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, location_en')
				.eq('is_active', true);
			
			if (error) throw error;
			branches = data || [];
			
			// Create branch map for quick lookup
			branchMap = new Map();
			branches.forEach(branch => {
				branchMap.set(branch.id, {
					name_en: branch.name_en,
					location_en: branch.location_en,
					display: `${branch.name_en} - ${branch.location_en}`
				});
			});
			
			console.log('✅ Loaded branches:', branches.length);
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	async function loadScheduledItems() {
		if (!selectedDate) return;

		isLoading = true;
		try {
			// Load branches first, then load payments
			await loadBranches();
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

	async function toggleDateRange() {
		if (showDateRange) {
			// Toggling OFF - revert to single day view
			showDateRange = false;
			await loadScheduledItems();
		} else {
			// Toggling ON - show date range inputs
			showDateRange = true;
		}
	}

	async function loadPeriodData() {
		if (!dateRangeStart || !dateRangeEnd) {
			alert('❌ Please select both start and end dates');
			return;
		}

		if (new Date(dateRangeStart) > new Date(dateRangeEnd)) {
			alert('❌ Start date must be before end date');
			return;
		}

		dateRangeLoading = true;
		try {
			// Load vendor payments for the date range
			const { data: vendorData, error: vendorError } = await supabase
				.from('vendor_payment_schedule')
				.select('*')
				.gte('due_date', dateRangeStart)
				.lte('due_date', dateRangeEnd)
				.eq('is_paid', false)
				.in('approval_status', ['approved', 'pending'])
				.order('due_date, vendor_name');

			if (vendorError) throw vendorError;

			// Load expense schedules for the date range
			const { data: expenseData, error: expenseError } = await supabase
				.from('expense_scheduler')
				.select('*')
				.gte('due_date', dateRangeStart)
				.lte('due_date', dateRangeEnd)
				.eq('is_paid', false)
				.order('due_date, description');

			if (expenseError) throw expenseError;

			// Map branch info and store in main arrays
			await loadBranches();
			vendorPayments = (vendorData || []).map(payment => {
				const branchInfo = branchMap.get(payment.branch_id);
				return {
					...payment,
					branch_name: branchInfo ? branchInfo.display : payment.branch_name || 'Unknown Branch'
				};
			});

			expenseSchedules = (expenseData || []).map(expense => {
				const branchInfo = branchMap.get(expense.branch_id);
				return {
					...expense,
					branch_name: branchInfo ? branchInfo.display : expense.branch_name || 'Unknown Branch'
				};
			});

			showDateRange = true;
			console.log('✅ Loaded period data from', dateRangeStart, 'to', dateRangeEnd, '. Vendor payments:', vendorPayments.length, 'Expense schedules:', expenseSchedules.length);
		} catch (error) {
			console.error('❌ Error loading period data:', error);
			alert('❌ Error loading period data: ' + error.message);
			vendorPayments = [];
			expenseSchedules = [];
		} finally {
			dateRangeLoading = false;
		}
	}

	async function loadVendorPayments() {
		try {
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.select('*')
				.eq('due_date', selectedDate)
				.eq('is_paid', false)
				.in('approval_status', ['approved', 'pending'])
				.order('bill_amount', { ascending: false });

			if (error) throw error;
			
			// Debug: Log first item to see all available fields
			if (data && data.length > 0) {
				console.log('🔍 First vendor payment record:', data[0]);
				console.log('📋 Available fields:', Object.keys(data[0]));
				console.log('💰 Payment method value:', data[0].payment_method);
				console.log('🔍 All payment methods in vendor payments:', data.map(p => p.payment_method).filter(Boolean));
			}
			
			// Map branch_id to branch name + location
			vendorPayments = (data || []).map(payment => {
				const branchInfo = branchMap.get(payment.branch_id);
				return {
					...payment,
					branch_name: branchInfo ? branchInfo.display : payment.branch_name || 'Unknown Branch'
				};
			});
			
			console.log('✅ Loaded vendor payments for', selectedDate, ':', vendorPayments.length);
		} catch (error) {
			console.error('Error loading vendor payments:', error);
			vendorPayments = [];
		}
	}

	async function loadExpenseSchedules() {
		try {
			const { data, error } = await supabase
				.from('expense_scheduler')
				.select('*')
				.eq('due_date', selectedDate)
				.eq('is_paid', false)
				.order('amount', { ascending: false });

			if (error) throw error;
			
			// Debug: Log payment methods
			if (data && data.length > 0) {
				console.log('💰 Expense payment methods:', data.map(e => e.payment_method).filter(Boolean));
			}
			
			// Map branch_id to branch name + location
			expenseSchedules = (data || []).map(expense => {
				const branchInfo = branchMap.get(expense.branch_id);
				return {
					...expense,
					branch_name: branchInfo ? branchInfo.display : expense.branch_name || 'Unknown Branch'
				};
			});
			
			console.log('✅ Loaded expense schedules for', selectedDate, ':', expenseSchedules.length);
		} catch (error) {
			console.error('Error loading expense schedules:', error);
			expenseSchedules = [];
		}
	}

	async function loadNonApprovedPayments() {
		try {
			const { data, error } = await supabase
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
			
			const { error } = await supabase
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
				const { error: insertError } = await supabase
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
				const { error: updateError } = await supabase
					.from('vendor_payment_schedule')
					.update({ 
						final_bill_amount: remainingAmount,
						notes: (splitItem.notes || '') + ' [Original amount after split]'
					})
					.eq('id', splitItem.id);

				if (updateError) throw updateError;

			} else {
				// Handle expense scheduler split
				const { error: insertError } = await supabase
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
				const { error: updateError } = await supabase
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

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Header Bar - Single Row with Title, Cards, and Buttons -->
	<div class="bg-white border-b border-slate-200 px-6 py-3 shadow-sm">
		<div class="flex items-center justify-between gap-4">
			<!-- Title -->
			<div class="flex items-center gap-3 flex-shrink-0">
				<span class="text-2xl">📊</span>
				<div>
					<h2 class="text-base font-black text-slate-800 uppercase tracking-wide">Day Budget Planner</h2>
					<p class="text-[10px] text-slate-500">Plan and manage daily cash flow</p>
				</div>
			</div>

			<!-- Summary Cards - Center -->
			{#if vendorPayments.length > 0 || expenseSchedules.length > 0}
				{@const vendorTotal = vendorPayments.reduce((sum, p) => sum + (p.final_bill_amount || p.bill_amount), 0)}
				{@const expenseTotal = expenseSchedules.reduce((sum, e) => sum + e.amount, 0)}
				{@const combinedTotal = vendorTotal + expenseTotal}
				{@const vendorCount = groupedVendorPayments.length}
				{@const expenseCount = filteredExpenseSchedules.length}
				{@const totalItems = vendorPayments.length + expenseSchedules.length}
				{@const totalSelected = Array.from(selectedVendorPayments).length + selectedExpenseSchedules.size}
				
				<div class="flex gap-2 flex-1 max-w-4xl">
					<div class="bg-blue-50 border border-blue-200 rounded-lg px-3 py-1.5 flex-1">
						<p class="text-[9px] font-bold text-slate-600 uppercase mb-0.5">Total Items</p>
						<p class="text-lg font-black text-blue-600">{totalItems}</p>
					</div>
					<div class="bg-emerald-50 border border-emerald-200 rounded-lg px-3 py-1.5 flex-1">
						<p class="text-[9px] font-bold text-slate-600 uppercase mb-0.5">Combined Total</p>
						<p class="text-lg font-black text-emerald-600">{formatCurrency(combinedTotal)}</p>
					</div>
					<div class="bg-purple-50 border border-purple-200 rounded-lg px-3 py-1.5 flex-1">
						<p class="text-[9px] font-bold text-slate-600 uppercase mb-0.5">Groups + Schedules</p>
						<p class="text-lg font-black text-purple-600">{vendorCount} + {expenseCount}</p>
					</div>
					<div class="bg-orange-50 border border-orange-200 rounded-lg px-3 py-1.5 flex-1">
						<p class="text-[9px] font-bold text-slate-600 uppercase mb-0.5">Selected</p>
						<p class="text-lg font-black text-orange-600">{totalSelected}</p>
					</div>
				</div>
			{/if}

			<!-- Action Buttons - Right -->
			<div class="flex gap-2 flex-shrink-0">
				{#if vendorPayments.length > 0 || expenseSchedules.length > 0}
					<button 
						class="px-3 py-2 text-xs font-black uppercase text-slate-700 bg-white border border-slate-200 rounded-xl hover:bg-slate-50 transition-all disabled:opacity-50"
						on:click={selectAllVendorPayments}
						disabled={vendorPayments.length === 0}
					>
						Select All
					</button>
					<button 
						class="px-3 py-2 text-xs font-black uppercase text-slate-700 bg-slate-200 rounded-xl hover:bg-slate-300 transition-all disabled:opacity-50"
						on:click={clearAllSelections}
						disabled={selectedVendorPayments.size === 0 && selectedExpenseSchedules.size === 0}
					>
						Clear All
					</button>
				{/if}
				<button
					class="flex items-center gap-2 px-4 py-2 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl bg-blue-600 text-white shadow-lg shadow-blue-200 hover:bg-blue-700 hover:shadow-blue-300"
					on:click={generatePrintPreview}
				>
					<span class="text-base">🖨️</span>
					<span>Generate</span>
				</button>
			</div>
		</div>
	</div>

	<!-- Cards Section (Fixed at Top) -->
	<div class="px-4 py-6 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50 border-b border-white/50 backdrop-blur-sm z-20">
		<div class="relative w-full">
			<!-- Date Selection and Budget Summary Cards -->
			<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
				<!-- Date Selection Card -->
				<div class="bg-white/60 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6">
					<h3 class="text-sm font-bold text-slate-800 mb-4 flex items-center gap-2">
						<span class="w-8 h-8 rounded-lg bg-blue-100 flex items-center justify-center text-lg">📅</span>
						<span>Select Date</span>
					</h3>
					<input 
						id="selectedDate"
						type="date" 
						bind:value={selectedDate}
						on:change={onDateChange}
						class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
					/>

					<!-- Date Range Toggle -->
					<button
					on:click={toggleDateRange}
					class="w-full mt-3 px-3 py-2 text-xs font-bold uppercase tracking-wide text-purple-600 bg-purple-50 border border-purple-200 rounded-lg hover:bg-purple-100 transition-colors duration-200"
				>
					{showDateRange ? '📊 Hide Date Range' : '📊 Show Date Range'}
				</button>

				<!-- Date Range Inputs -->
				{#if showDateRange}
						<div class="mt-4 pt-4 border-t border-slate-200 space-y-3">
							<div>
								<label class="block text-xs font-bold text-slate-600 mb-1">Start Date</label>
								<input 
									type="date" 
									bind:value={dateRangeStart}
									class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
								/>
							</div>
							<div>
								<label class="block text-xs font-bold text-slate-600 mb-1">End Date</label>
								<input 
									type="date" 
									bind:value={dateRangeEnd}
									class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
								/>
							</div>
							<button
								on:click={loadPeriodData}
								disabled={dateRangeLoading}
								class="w-full px-3 py-2 bg-purple-600 text-white text-xs font-bold rounded-lg hover:bg-purple-700 disabled:opacity-50 transition-colors"
							>
								{dateRangeLoading ? '⏳ Loading...' : '📈 Load Period'}
							</button>
						</div>
					{/if}
				</div>

				<!-- Daily Budget Card -->
				<div class="bg-white/60 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6">
					<h3 class="text-sm font-bold text-slate-800 mb-4 flex items-center gap-2">
						<span class="w-8 h-8 rounded-lg bg-emerald-100 flex items-center justify-center text-lg">💰</span>
						<span>Daily Budget</span>
					</h3>
					<div>
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Budget Amount (SAR)</label>
						<input 
							id="dailyBudget"
							type="number" 
							bind:value={calculatedTotalBudget}
							step="0.01"
							min="0"
							placeholder="0.00"
							class="w-full px-4 py-2.5 bg-slate-100 border border-slate-200 rounded-xl text-sm text-slate-600 cursor-not-allowed font-bold"
							readonly
							title="This is calculated from payment method budgets below"
						/>
						<button 
							on:click={openPaymentMethodModal}
							class="w-full mt-3 px-4 py-2 text-xs font-bold uppercase tracking-wide text-blue-600 bg-blue-50 border border-blue-200 rounded-lg hover:bg-blue-100 transition-colors duration-200 flex items-center justify-center gap-2"
						>
							<span>💳</span>
							<span>Allocate by Payment Method</span>
						</button>
						<p class="text-[10px] text-slate-500 mt-2 italic">Auto-calculated from payment method budgets</p>
					</div>
				</div>

				<!-- Budget Status Card -->
				<div class="bg-white/60 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6">
					<h3 class="text-sm font-bold text-slate-800 mb-4 flex items-center gap-2">
						<span class="w-8 h-8 rounded-lg {budgetStatus === 'over' ? 'bg-red-100' : 'bg-emerald-100'} flex items-center justify-center text-lg">{budgetStatus === 'over' ? '⚠️' : '✅'}</span>
						<span>Budget Status</span>
					</h3>
					<div class="space-y-2">
						<div class="flex justify-between items-baseline">
							<span class="text-xs font-semibold text-slate-600 uppercase">Remaining</span>
							<span class="text-xl font-black {remainingBudget < 0 ? 'text-red-600' : 'text-emerald-600'}">
								{formatCurrency(remainingBudget)}
							</span>
						</div>
						<p class="text-xs text-slate-500">
							{#if budgetStatus === 'over'}
								<span class="font-semibold text-red-600">Over budget</span>
							{:else if budgetStatus === 'exact'}
								<span class="font-semibold text-emerald-600">Exact match</span>
							{:else}
								<span class="font-semibold text-emerald-600">Within budget</span>
							{/if}
						</p>
					</div>
				</div>

				<!-- Budget Breakdown Card (4th Card) -->
				<div class="bg-white/60 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6">
					<h3 class="text-sm font-bold text-slate-800 mb-4 flex items-center gap-2">
						<span class="w-8 h-8 rounded-lg bg-indigo-100 flex items-center justify-center text-lg">📋</span>
						<span>Breakdown</span>
					</h3>
					<div class="space-y-3 text-sm">
						<div class="flex justify-between items-center">
							<span class="text-slate-600 font-semibold">Total Budget:</span>
							<span class="font-black text-indigo-600">{formatCurrency(calculatedTotalBudget)}</span>
						</div>
						<div class="flex justify-between items-center">
							<span class="text-slate-600 font-semibold">Scheduled:</span>
							<span class="font-black text-slate-800">{formatCurrency(totalScheduled)}</span>
						</div>
						<div class="flex justify-between items-center pt-2 border-t border-slate-200">
							<span class="text-slate-600 font-semibold">Remaining:</span>
							<span class="font-black {remainingBudget < 0 ? 'text-red-600' : 'text-emerald-600'}">{formatCurrency(remainingBudget)}</span>
						</div>
						{#if true}
							{@const allScheduledBreakdown = getAllScheduledBreakdown()}
							{#if allScheduledBreakdown && allScheduledBreakdown.size > 0}
								<div class="pt-2 border-t border-slate-200">
									<p class="text-xs font-semibold text-slate-600 mb-2 uppercase">Payment Methods</p>
									<div class="text-xs space-y-1 max-h-32 overflow-y-auto">
										{#each Array.from(allScheduledBreakdown.entries()) as [method, amount]}
											<div class="flex justify-between items-center text-slate-700">
												<span class="truncate">{method}</span>
												<span class="font-semibold text-right ml-2">{formatCurrency(amount)}</span>
											</div>
										{/each}
									</div>
								</div>
							{/if}
						{/if}
					</div>
				</div>
			</div>
		</div>
	</div>

	<!-- Scrollable Content Area -->
	<div class="flex-1 px-4 py-6 overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative blurs -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-cyan-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse pointer-events-none" style="animation-delay: 2s;"></div>

		<div class="relative w-full">

	{#if isLoading}
		<div class="flex items-center justify-center h-96">
			<div class="text-center">
				<div class="animate-spin inline-block mb-4">
					<div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
				</div>
				<p class="text-slate-600 font-semibold">Loading scheduled items...</p>
			</div>
		</div>
	{:else}
		<!-- View Mode Indicator -->
		{#if showDateRange}
			<div class="mb-4 p-3 bg-purple-50 border border-purple-200 rounded-lg flex items-center gap-2">
				<span class="text-lg">📊</span>
				<span class="text-sm font-semibold text-purple-700">Date Range: {dateRangeStart} to {dateRangeEnd}</span>
			</div>
		{/if}

		<!-- Vendor Payments Section -->
		<div class="mb-6 bg-white/60 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6">
			<div class="flex items-center justify-between mb-4">
				<h3 class="text-lg font-black text-slate-800 flex items-center gap-2">
					<span class="text-2xl">💰</span>
					Vendor Payments Due ({filteredVendorPayments.length}{filteredVendorPayments.length !== vendorPayments.length ? ` of ${vendorPayments.length}` : ''})
				</h3>
				{#if vendorPayments.length > 0}
					<div class="flex gap-2">
						<button 
							class="px-3 py-2 text-xs font-black uppercase text-slate-700 bg-white border border-slate-200 rounded-lg hover:bg-slate-50 transition-all"
							on:click={() => {
								vendorPayments.forEach(p => selectedVendorPayments.add(p.id));
								selectedVendorPayments = selectedVendorPayments;
								calculateBudget();
							}}
							disabled={vendorPayments.length === 0}
						>
							Select All
						</button>
						<button 
							class="px-3 py-2 text-xs font-black uppercase text-slate-700 bg-slate-200 rounded-lg hover:bg-slate-300 transition-all"
							on:click={() => {
								vendorPayments.forEach(p => selectedVendorPayments.delete(p.id));
								selectedVendorPayments = selectedVendorPayments;
								calculateBudget();
							}}
							disabled={selectedVendorPayments.size === 0}
						>
							Clear All
						</button>
					</div>
				{/if}
			</div>

			<!-- Filters Only -->
				<div class="bg-white/40 backdrop-blur-sm rounded-lg border border-slate-200 p-3">
					<div class="grid grid-cols-1 sm:grid-cols-2 gap-2 h-full">
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-1 uppercase" for="vendor-filter">Filter by Vendor</label>
							<input 
								id="vendor-filter"
								type="text" 
								bind:value={vendorFilter} 
								placeholder="Enter vendor name..."
								class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all"
							/>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-1 uppercase" for="vendor-branch-filter">Filter by Branch</label>
							<select 
								id="vendor-branch-filter"
								bind:value={branchFilter}
								class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all"
								style="color: #000000 !important; background-color: #ffffff !important;"
							>
								<option value="">All Branches</option>
								{#each uniqueVendorBranches as branch}
									<option value={branch}>{branch}</option>
								{/each}
							</select>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-1 uppercase" for="vendor-payment-method-filter">Filter by Method</label>
							<select 
								id="vendor-payment-method-filter"
								bind:value={paymentMethodFilter}
								class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all"
								style="color: #000000 !important; background-color: #ffffff !important;"
							>
								<option value="">All Methods</option>
								{#each uniqueVendorPaymentMethods as method}
									<option value={method}>{method}</option>
								{/each}
							</select>
						</div>
						{#if vendorFilter || branchFilter || paymentMethodFilter}
							<div class="flex items-end">
								<button 
									class="w-full px-4 py-2 text-xs font-black uppercase text-slate-700 bg-slate-200 rounded-lg hover:bg-slate-300 transition-all"
									on:click={() => {vendorFilter = ''; branchFilter = ''; paymentMethodFilter = '';}}
								>
									Clear
								</button>
							</div>
						{/if}
					</div>
				</div>

			{#if vendorPayments.length > 0}
				<!-- Grouped Table with Drill-down -->
				<div class="overflow-x-auto -mx-6 px-6">
					{#if groupedVendorPayments.length > 0}
					<!-- Fixed Header Table -->
					<div class="table-header-wrapper">
						<table class="header-table vendor-header-table">
								<thead>
									<tr>
										<th class="checkbox-column vendor-select">Select</th>
										<th style="width: 40px;"></th>
										<th class="vendor-name">Vendor</th>
										<th class="vendor-branch">Branch</th>
										{#if showDateRange}
											<th class="vendor-due-date">Due Date</th>
										{/if}
										<th class="vendor-amount">Total Amount</th>
										<th class="vendor-bill-number">Bills</th>
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
									{#each groupedVendorPayments as group (group.vendor_id + '|' + group.branch_id)}
										{@const groupKey = group.vendor_id + '|' + group.branch_id}
										{@const isExpanded = groupExpandedRows.has(groupKey)}
										{@const groupSelectedCount = group.bills.filter(b => selectedVendorPayments.has(b.id)).length}
										{@const groupTotalSelected = groupSelectedCount}
										<tr class="group-row">
											<td class="checkbox-column vendor-select">
												<input 
													type="checkbox" 
													checked={groupTotalSelected === group.bills.length}
													indeterminate={groupTotalSelected > 0 && groupTotalSelected < group.bills.length}
													on:change={() => {
														// Toggle all items in group
														if (groupTotalSelected === group.bills.length) {
															// Deselect all
															group.bills.forEach(b => selectedVendorPayments.delete(b.id));
														} else {
															// Select all
															group.bills.forEach(b => selectedVendorPayments.add(b.id));
														}
														selectedVendorPayments = selectedVendorPayments;
														calculateBudget();
													}}
												/>
											</td>
											<td style="width: 40px;">
												<button 
													class="text-base hover:text-blue-600 transition"
													on:click={() => toggleGroupExpand(groupKey)}
													title={isExpanded ? 'Collapse' : 'Expand'}
												>
													{isExpanded ? '▼' : '▶'}
												</button>
											</td>
											<td class="vendor-name font-semibold">{group.vendor_name}</td>
											<td class="vendor-branch">{group.branch_name}</td>
											{#if showDateRange}
												<td class="vendor-due-date text-sm font-semibold">{new Date(group.bills[0]?.due_date).toLocaleDateString('en-US', {month: 'short', day: 'numeric'})}</td>
											{/if}
											<td class="amount vendor-amount font-bold text-blue-600">{formatCurrency(group.total_amount)}</td>
											<td class="vendor-bill-number">
												<button 
													class="px-3 py-1 text-xs font-bold text-white bg-blue-500 rounded-lg hover:bg-blue-600 transition"
													on:click={() => openGroupDetailsModal(group)}
												>
													📄 {group.bill_count} Bill{group.bill_count !== 1 ? 's' : ''}
												</button>
											</td>
											<td class="payment-method vendor-payment-method">{group.payment_method}</td>
											<td class="vendor-approval-status">
												<span class="inline-block text-xs">
													{#if group.approval_statuses.has('approved') && group.approval_statuses.size === 1}
														✅ All Approved
													{:else if group.approval_statuses.has('pending') && group.approval_statuses.size === 1}
														⏳ All Pending
													{:else if group.approval_statuses.size > 1}
														🔀 Mixed
													{:else}
														{[...group.approval_statuses][0]}
													{/if}
												</span>
											</td>
											<td class="vendor-actions">
												<button 
													class="reschedule-btn text-xs px-2 py-1"
													on:click={() => openRescheduleModal(group.bills[0], 'vendor')}
												>
													📅 Reschedule
												</button>
											</td>
										</tr>

										<!-- Expanded Detail Rows -->
										{#if isExpanded}
											{#each group.bills as bill}
												{@const adjustAmount = adjustAmounts[`vendor_${bill.id}`] || ''}
												{@const hasAdjustAmount = adjustAmount && parseFloat(adjustAmount) > 0}
												<tr class="detail-row">
													<td class="checkbox-column vendor-select" style="padding-left: 60px;">
														<input 
															type="checkbox" 
															checked={selectedVendorPayments.has(bill.id)}
															on:change={() => toggleVendorPayment(bill.id)}
														/>
													</td>
													<td></td>
													<td class="vendor-bill-number font-mono text-sm">Bill #{bill.bill_number}</td>
													<td class="vendor-branch text-sm">{bill.branch_name}</td>
													{#if showDateRange}
														<td class="vendor-due-date text-sm">{new Date(bill.due_date).toLocaleDateString('en-US', {month: 'short', day: 'numeric'})}</td>
													{/if}
													<td class="amount vendor-amount">{formatCurrency(bill.final_bill_amount || bill.bill_amount)}</td>
													<td class="adjust-amount-cell vendor-adjust-amount">
														<input 
															type="number"
															bind:value={adjustAmounts[`vendor_${bill.id}`]}
															step="0.01"
															min="0"
															placeholder="Enter amount"
															class="adjust-amount-input text-xs"
														/>
													</td>
													<td class="text-sm">{bill.payment_method}</td>
													<td class="vendor-approval-status">
														<span class="status-badge text-xs" class:approved={bill.approval_status === 'approved'} class:pending={bill.approval_status === 'pending'}>
															{#if bill.approval_status === 'approved'}
																✅ Approved
															{:else if bill.approval_status === 'pending'}
																⏳ Pending
															{:else if bill.approval_status === 'sent_for_approval'}
																📤 Sent
															{:else if bill.approval_status === 'rejected'}
																❌ Rejected
															{:else}
																❓ {bill.approval_status}
															{/if}
														</span>
													</td>
													<td class="vendor-actions">
														<div class="action-buttons text-xs">
															<button 
																class="reschedule-btn"
																on:click={() => openRescheduleModal(bill, 'vendor')}
															>
																📅 Reschedule
															</button>
															{#if hasAdjustAmount}
																<button 
																	class="split-btn"
																	on:click={() => openSplitModal(bill, 'vendor')}
																>
																	✂️ Split
																</button>
															{/if}
														</div>
													</td>
									</tr>
									{/each}
								{/if}
							{/each}
						</tbody>
					</table>
				</div>
			{:else}
				<div class="p-8 text-center">
					<p class="text-slate-600 font-semibold mb-3">No vendor payments match the current filters</p>
					<button class="px-4 py-2 text-xs font-black uppercase text-slate-700 bg-slate-200 rounded-lg hover:bg-slate-300 transition-all" on:click={() => {vendorFilter = ''; branchFilter = ''; paymentMethodFilter = '';}}>
						Clear Filters
					</button>
				</div>
			{/if}
			</div>
		{:else}
			<div class="p-8 text-center">
				<p class="text-slate-600 font-semibold">No vendor payments scheduled for {formatDate(selectedDate)}</p>
			</div>
		{/if}
		</div>

		<!-- Expense Schedules - Separate Scrollable Container -->
		<div class="table-section">
			<!-- Filters Only -->
			<div class="bg-white/40 backdrop-blur-sm rounded-lg border border-slate-200 p-3 mb-4">
				<div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-1 uppercase" for="expense-description-filter">Filter by Description</label>
							<input 
								id="expense-description-filter"
								type="text" 
								bind:value={expenseDescriptionFilter} 
								placeholder="Enter description..."
								class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all"
							/>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-1 uppercase" for="expense-category-filter">Filter by Category</label>
							<input 
								id="expense-category-filter"
								type="text" 
								bind:value={expenseCategoryFilter} 
								placeholder="Enter category..."
								class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all"
							/>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-1 uppercase" for="expense-branch-filter">Filter by Branch</label>
							<select 
								id="expense-branch-filter"
								bind:value={expenseBranchFilter}
								class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all"
								style="color: #000000 !important; background-color: #ffffff !important;"
							>
								<option value="">All Branches</option>
								{#each uniqueExpenseBranches as branch}
									<option value={branch}>{branch}</option>
								{/each}
							</select>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-1 uppercase" for="expense-payment-method-filter">Filter by Method</label>
							<select 
								id="expense-payment-method-filter"
								bind:value={expensePaymentMethodFilter}
								class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all"
								style="color: #000000 !important; background-color: #ffffff !important;"
							>
								<option value="">All Payment Methods</option>
								{#each uniqueExpensePaymentMethods as method}
									<option value={method}>{method}</option>
								{/each}
							</select>
						</div>
						{#if expenseDescriptionFilter || expenseCategoryFilter || expenseBranchFilter || expensePaymentMethodFilter}
							<div class="flex items-end col-span-2">
								<button 
									class="w-full px-4 py-2 text-xs font-black uppercase text-slate-700 bg-slate-200 rounded-lg hover:bg-slate-300 transition-all"
									on:click={() => {expenseDescriptionFilter = ''; expenseCategoryFilter = ''; expenseBranchFilter = ''; expensePaymentMethodFilter = '';}}
								>
									Clear Filters
								</button>
							</div>
						{/if}
					</div>
				</div>

			<!-- Section Header with Title and Actions -->
			<div class="section-header" style="display: flex; justify-content: space-between; align-items: center; gap: 1rem; margin-bottom: 0;">
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
			<div class="individual-table-container">
				<div class="data-section">
					{#if expenseSchedules.length > 0}
						<!-- Fixed Header Table -->
						<div class="table-header-wrapper">
							<table class="header-table">
								<thead>
									<tr>
										<th class="checkbox-column">Select</th>
										<th>Vendor Name</th>
										<th>Description</th>
										<th>Category</th>
										<th>Branch</th>
										{#if showDateRange}
											<th>Due Date</th>
										{/if}
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
									{#each sortedExpenseSchedules as expense}
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
											<td class="vendor-name font-semibold">{expense.vendor_name || 'N/A'}</td>
											<td class="description">{expense.description}</td>
											<td>{expense.expense_category_name_en || 'N/A'}</td>
											<td>{expense.branch_name}</td>
											{#if showDateRange}
												<td class="text-sm font-semibold">{new Date(expense.due_date).toLocaleDateString('en-US', {month: 'short', day: 'numeric'})}</td>
											{/if}
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
</div>

<!-- Group Details Modal -->
{#if showGroupDetailsModal && selectedGroup}
	<div class="modal-overlay" on:click={closeGroupDetailsModal} style="--modal-z-index: 25;">
		<div class="modal-content" on:click|stopPropagation style="max-width: 700px;">
			<div class="modal-header">
				<h3>📋 Vendor Group Details</h3>
				<button class="close-btn" on:click={closeGroupDetailsModal}>✕</button>
			</div>
			<div class="modal-body">
				<!-- Group Summary -->
				<div class="space-y-4">
					<div class="grid grid-cols-2 gap-4 p-4 bg-blue-50 rounded-lg">
						<div>
							<p class="text-xs font-bold text-slate-600 uppercase">Vendor</p>
							<p class="text-sm font-bold text-slate-800">{selectedGroup.vendor_name}</p>
						</div>
						<div>
							<p class="text-xs font-bold text-slate-600 uppercase">Branch</p>
							<p class="text-sm font-bold text-slate-800">{selectedGroup.branch_name}</p>
						</div>
						<div>
							<p class="text-xs font-bold text-slate-600 uppercase">Total Amount</p>
							<p class="text-lg font-black text-blue-600">{formatCurrency(selectedGroup.total_amount)}</p>
						</div>
						<div>
							<p class="text-xs font-bold text-slate-600 uppercase">Bill Count</p>
							<p class="text-lg font-black text-slate-800">{selectedGroup.bill_count}</p>
						</div>
					</div>

					<!-- Bills List -->
					<div>
						<p class="text-sm font-bold text-slate-700 mb-2">📄 Bills ({selectedGroup.bills.length}):</p>
						<div class="space-y-2 max-h-96 overflow-y-auto">
							{#each selectedGroup.bills as bill}
								<div class="p-3 border border-slate-200 rounded-lg hover:bg-slate-50 transition">
									<div class="flex items-start justify-between">
										<div>
											<p class="font-semibold text-slate-800">Bill #{bill.bill_number}</p>
											<p class="text-xs text-slate-600 mt-1">Amount: {formatCurrency(bill.final_bill_amount || bill.bill_amount)}</p>
										</div>
										<div class="text-right">
											<span class="status-badge" class:approved={bill.approval_status === 'approved'} class:pending={bill.approval_status === 'pending'}>
												{#if bill.approval_status === 'approved'}
													✅ Approved
												{:else if bill.approval_status === 'pending'}
													⏳ Pending
												{:else if bill.approval_status === 'sent_for_approval'}
													📤 Sent
												{:else if bill.approval_status === 'rejected'}
													❌ Rejected
												{:else}
													❓ {bill.approval_status}
												{/if}
											</span>
										</div>
									</div>
								</div>
							{/each}
						</div>
					</div>

					<!-- Branches in Group -->
					{#if selectedGroup.bills.length > 1}
						<div>
							<p class="text-sm font-bold text-slate-700 mb-2">🏢 Branches:</p>
							<div class="flex flex-wrap gap-2">
								{#each [...new Set(selectedGroup.bills.map(b => b.branch_name))] as branch}
									<span class="px-3 py-1 bg-indigo-100 text-indigo-700 rounded-full text-xs font-semibold">{branch}</span>
								{/each}
							</div>
						</div>
					{/if}
				</div>
			</div>
			<div class="modal-footer">
				<button class="btn-secondary" on:click={closeGroupDetailsModal}>Close</button>
			</div>
		</div>
	</div>
{/if}

<!-- Payment Method Budget Allocation Modal -->
{#if showPaymentMethodModal}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="modal-overlay" on:click={() => showPaymentMethodModal = false}>
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>💳 Allocate Budget by Payment Method</h3>
				<button class="close-btn" on:click={() => showPaymentMethodModal = false}>✕</button>
			</div>

			<div class="modal-body" style="max-height: 70vh; overflow-y-auto;">
				<!-- Budget Summary -->
				<div class="mb-6 pb-6 border-b border-slate-300">
					<div class="grid grid-cols-2 gap-4">
						<div class="text-center">
							<div class="text-xs font-bold text-slate-600 uppercase mb-1">Total Budget</div>
							<div class="text-2xl font-black text-blue-600">{formatCurrency(calculatedTotalBudget)}</div>
						</div>
						<div class="text-center">
							<div class="text-xs font-bold text-slate-600 uppercase mb-1">Remaining</div>
							<div class="text-2xl font-black {remainingBudget < 0 ? 'text-red-600' : 'text-emerald-600'}">{formatCurrency(remainingBudget)}</div>
						</div>
					</div>
				</div>

				<!-- Payment Method Budgets -->
				{#if breakdown && breakdown.allPaymentMethods.size > 0}
					<div class="space-y-4">
						{#each Array.from(breakdown.allPaymentMethods) as method}
							{@const amount = breakdown.byPaymentMethod.get(method) || 0}
							{@const budgetForMethod = paymentMethodBudgets[method] || 0}
							{@const remaining = budgetForMethod - amount}
							{@const source = getPaymentMethodSource(method)}
							{@const isVendor = source === 'vendor'}
							{@const isExpense = source === 'expense'}
							<div class="p-4 rounded-xl border transition-all {isVendor ? 'bg-blue-50 border-blue-200' : isExpense ? 'bg-emerald-50 border-emerald-200' : 'bg-purple-50 border-purple-200'}">
								<div class="flex items-center justify-between mb-3">
									<div class="flex items-center gap-2">
										<span class="font-bold {isVendor ? 'text-blue-900' : isExpense ? 'text-emerald-900' : 'text-purple-900'}">{method}</span>
										<span class="text-xs font-bold px-2 py-0.5 rounded {isVendor ? 'bg-blue-200 text-blue-700' : isExpense ? 'bg-emerald-200 text-emerald-700' : 'bg-purple-200 text-purple-700'}">
											{isVendor ? '💳 Vendor' : isExpense ? '📋 Expense' : '🔄 Both'}
										</span>
									</div>
									<span class="text-xs font-semibold {isVendor ? 'text-blue-700' : isExpense ? 'text-emerald-700' : 'text-purple-700'}">Current: {formatCurrency(amount)}</span>
								</div>
								<input 
									type="number"
									bind:value={paymentMethodBudgets[method]}
									step="0.01"
									min="0"
									placeholder="0.00"
									class="w-full px-4 py-2 border {isVendor ? 'border-blue-300 focus:ring-blue-500' : isExpense ? 'border-emerald-300 focus:ring-emerald-500' : 'border-purple-300 focus:ring-purple-500'} rounded-lg text-base font-semibold focus:outline-none focus:ring-2 transition-all"
								/>
								<div class="mt-2 text-xs {isVendor ? 'text-blue-700' : isExpense ? 'text-emerald-700' : 'text-purple-700'}">
									{#if budgetForMethod > 0}
										Budget Remaining: <span class="{remaining < 0 ? 'text-red-600 font-bold' : ''}">{formatCurrency(remaining)}</span>
									{:else}
										<span class="text-slate-500 italic">No limit set</span>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				{:else}
					<div class="text-center py-8 space-y-4">
						<div class="flex justify-center text-5xl mb-4">📭</div>
						<p class="text-slate-700 font-semibold">No Payment Methods Found</p>
						<div class="text-sm text-slate-600 space-y-2">
							<p>Selected date: <span class="font-bold text-slate-800">{selectedDate || 'Not selected'}</span></p>
							<p>
								Scheduled items loaded:
								<span class="font-bold text-slate-800">
									{vendorPayments.length + expenseSchedules.length + nonApprovedPayments.length}
								</span>
								{#if vendorPayments.length + expenseSchedules.length + nonApprovedPayments.length === 0}
									<span class="block text-xs text-amber-600 mt-2">⚠️ No scheduled payments for this date</span>
								{/if}
							</p>
						</div>
						
						{#if isLoading}
							<p class="text-sm text-blue-600 font-semibold">⏳ Loading data...</p>
						{:else if !selectedDate}
							<p class="text-sm text-amber-600 font-semibold">Select a date to load payment methods</p>
						{:else if vendorPayments.length + expenseSchedules.length + nonApprovedPayments.length === 0}
							<p class="text-sm text-slate-600">No payments scheduled for <strong>{new Date(selectedDate).toLocaleDateString()}</strong></p>
							<button 
								on:click={() => showPaymentMethodModal = false}
								class="inline-block px-4 py-2 bg-blue-600 text-white text-xs font-bold rounded-lg hover:bg-blue-700 mt-4"
							>
								Select Different Date
							</button>
						{:else}
							<p class="text-xs text-slate-500">Payment methods not detected in the scheduled items</p>
							<p class="text-xs text-slate-500 mt-2">💡 Items must have a <code class="bg-slate-100 px-1 rounded">payment_method</code> field</p>
						{/if}
					</div>
				{/if}
			</div>

			<div class="modal-footer">
				<button 
					class="close-btn" 
					on:click={() => showPaymentMethodModal = false}
					style="padding: 10px 20px; background: #f1f5f9; border: 1px solid #cbd5e1; border-radius: 8px; cursor: pointer; font-weight: bold; color: #475569;"
				>
					Done
				</button>
			</div>
		</div>
	</div>
{/if}

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

<!-- Print Preview Modal -->
{#if showPrintPreview}
	<div id="printModalOverlay" class="modal-overlay print-modal-overlay" on:click={closePrintPreview}>
		<div class="print-modal-content" on:click|stopPropagation>
			<div class="print-modal-header no-print">
				<h2>📄 Day Schedule Preview</h2>
				<button class="close-btn" on:click={closePrintPreview}>&times;</button>
			</div>

			<div class="print-modal-actions no-print">
				<button class="print-btn" on:click={saveAsPDF}>
					<span>�</span> Save as PDF
				</button>
			</div>

			<!-- A4 Landscape Print Template -->
			<div class="print-template">
				<div class="print-header">
					<div class="print-header-top">
						<div class="print-logo">
							<img src={$iconUrlMap['logo'] || '/icons/logo.png'} alt="Aqura Logo" class="logo-img" />
							<span class="app-name">Aqura Management System</span>
						</div>
						<div class="print-meta">
							<div class="print-date-info">
								<strong>Schedule Date:</strong> {formatDate(selectedDate)}
							</div>
							<div class="print-generated">
								<strong>Generated:</strong> {new Date().toLocaleString('en-US', { 
									year: 'numeric', 
									month: 'short', 
									day: 'numeric', 
									hour: '2-digit', 
									minute: '2-digit',
									hour12: true 
								})}
							</div>
							<div class="print-user">
								<strong>Prepared by:</strong> {$currentUser?.username || 'N/A'}
							</div>
						</div>
					</div>
					<h1>Daily Budget Schedule</h1>
				</div>

				<div class="print-summary">
					<div class="print-summary-item">
						<span class="print-label">Total Daily Budget:</span>
						<span class="print-value">{formatCurrency(calculatedTotalBudget)}</span>
					</div>
					<div class="print-summary-item">
						<span class="print-label">Total Scheduled:</span>
						<span class="print-value">{formatCurrency(totalScheduled)}</span>
					</div>
					<div class="print-summary-item">
						<span class="print-label">Remaining:</span>
						<span class="print-value" class:negative={remainingBudget < 0}>{formatCurrency(remainingBudget)}</span>
					</div>
					<div class="print-summary-item">
						<span class="print-label">Status:</span>
						<span class="print-value status-badge" class:over={budgetStatus === 'over'} class:exact={budgetStatus === 'exact'}>
							{#if budgetStatus === 'over'}
								⚠️ Over Budget
							{:else if budgetStatus === 'exact'}
								✅ Exact Match
							{:else}
								✅ Within Budget
							{/if}
						</span>
					</div>
				</div>

				<!-- Payment Method Budget Breakdown -->
				<div class="print-section">
					<h2 class="print-section-title">💳 Payment Method Budget Breakdown</h2>
					<table class="print-table">
						<thead>
							<tr>
								<th>Payment Method</th>
								<th>Budget Allocated</th>
								<th>Amount Spent</th>
								<th>Remaining</th>
								<th>Status</th>
							</tr>
						</thead>
						<tbody>
							{#each Array.from(breakdown.allPaymentMethods) as method}
								{@const budget = paymentMethodBudgets[method] || 0}
								{@const spent = breakdown.byPaymentMethod.get(method) || 0}
								{@const remaining = budget - spent}
								{@const isOver = remaining < 0}
								<tr>
									<td><strong>{method}</strong></td>
									<td>{formatCurrency(budget)}</td>
									<td>{formatCurrency(spent)}</td>
									<td class:negative={isOver}>{formatCurrency(remaining)}</td>
									<td>
										<span class="status-badge" class:over={isOver} class:within={!isOver && spent > 0} class:unused={spent === 0}>
											{#if isOver}
												⚠️ Over Budget
											{:else if spent === 0}
												⭕ Unused
											{:else if remaining === 0}
												✅ Exact
											{:else}
												✅ Within Budget
											{/if}
										</span>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>

				<!-- Vendor Payments -->
				{#if selectedVendorPayments.size > 0}
					<div class="print-section">
						<h2 class="print-section-title">💼 Vendor Payments ({selectedVendorPayments.size})</h2>
						<table class="print-table">
							<thead>
								<tr>
									<th>Bill Number</th>
									<th>Vendor</th>
									<th>Branch</th>
									<th>Payment Method</th>
									<th>Amount</th>
									<th>Adjusted</th>
									<th>Status</th>
								</tr>
							</thead>
							<tbody>
								{#if true}
									{@const selectedPaymentsSorted = filteredVendorPayments.filter(p => selectedVendorPayments.has(p.id)).sort((a, b) => (a.vendor_name || '').localeCompare(b.vendor_name || ''))}
									{#each (() => {
										const groups = {};
										selectedPaymentsSorted.forEach(payment => {
											const vendor = payment.vendor_name || 'Unknown';
											if (!groups[vendor]) groups[vendor] = [];
											groups[vendor].push(payment);
										});
										return Object.entries(groups);
									})() as [vendor, payments]}
										{#each payments as payment}
											<tr>
												<td>{payment.bill_number}</td>
												<td>{payment.vendor_name}</td>
												<td>{payment.branch_name}</td>
												<td>{payment.payment_method}</td>
												<td>{formatCurrency(payment.final_bill_amount || payment.bill_amount)}</td>
												<td>{formatCurrency(adjustAmounts[`vendor-${payment.id}`] || 0)}</td>
												<td>
													<span class="status-badge" class:approved={payment.approval_status === 'Approved'} class:pending={payment.approval_status === 'Pending'}>
														{payment.approval_status}
													</span>
												</td>
											</tr>
										{/each}
										{#if payments.length > 1}
											{@const vendorTotal = payments.reduce((sum, p) => sum + (p.final_bill_amount || p.bill_amount || 0), 0)}
											{@const vendorAdjusted = payments.reduce((sum, p) => sum + (parseFloat(adjustAmounts[`vendor-${p.id}`]) || 0), 0)}
											<tr style="background-color: #f3f4f6; font-weight: bold;">
												<td colspan="4" style="text-align: right;">Subtotal for {vendor}:</td>
												<td>{formatCurrency(vendorTotal)}</td>
												<td>{formatCurrency(vendorAdjusted)}</td>
												<td></td>
											</tr>
										{/if}
									{/each}
								{/if}
							</tbody>
						</table>
					</div>
				{/if}

				<!-- Expense Schedules -->
				{#if selectedExpenseSchedules.size > 0}
					<div class="print-section">
						<h2 class="print-section-title">💸 Expense Schedules ({selectedExpenseSchedules.size})</h2>
						<table class="print-table">
							<thead>
								<tr>
									<th>Vendor Name</th>
									<th>Description</th>
									<th>Category</th>
									<th>Branch</th>
									<th>Payment Method</th>
									<th>Amount</th>
									<th>Adjusted</th>
								</tr>
							</thead>
							<tbody>
								{#if true}
									{@const selectedExpensesSorted = filteredExpenseSchedules.filter(e => selectedExpenseSchedules.has(e.id)).sort((a, b) => (a.vendor_name || '').localeCompare(b.vendor_name || ''))}
									{#each (() => {
										const groups = {};
										selectedExpensesSorted.forEach(expense => {
											const vendor = expense.vendor_name || 'Unknown';
											if (!groups[vendor]) groups[vendor] = [];
											groups[vendor].push(expense);
										});
										return Object.entries(groups);
									})() as [vendor, expenses]}
										{#each expenses as expense}
											<tr>
												<td>{expense.vendor_name || 'N/A'}</td>
												<td>{expense.description}</td>
												<td>{expense.expense_category_name_en || 'N/A'}</td>
												<td>{expense.branch_name}</td>
												<td>{expense.payment_method}</td>
												<td>{formatCurrency(expense.amount)}</td>
												<td>{formatCurrency(adjustAmounts[`expense-${expense.id}`] || 0)}</td>
											</tr>
										{/each}
										{#if expenses.length > 1}
											{@const expenseTotal = expenses.reduce((sum, e) => sum + (e.amount || 0), 0)}
											{@const expenseAdjusted = expenses.reduce((sum, e) => sum + (parseFloat(adjustAmounts[`expense-${e.id}`]) || 0), 0)}
											<tr style="background-color: #f3f4f6; font-weight: bold;">
												<td colspan="5" style="text-align: right;">Subtotal for {vendor}:</td>
												<td>{formatCurrency(expenseTotal)}</td>
												<td>{formatCurrency(expenseAdjusted)}</td>
											</tr>
										{/if}
									{/each}
								{/if}
							</tbody>
						</table>
					</div>
				{/if}

				<!-- Non-Approved Payments -->
				{#if selectedNonApprovedPayments.size > 0}
					<div class="print-section">
						<h2 class="print-section-title">⚠️ Non-Approved Payments ({selectedNonApprovedPayments.size})</h2>
						<table class="print-table">
							<thead>
								<tr>
									<th>Bill Number</th>
									<th>Vendor</th>
									<th>Branch</th>
									<th>Payment Method</th>
									<th>Amount</th>
									<th>Adjusted</th>
								</tr>
							</thead>
							<tbody>
								{#each nonApprovedPayments.filter(p => selectedNonApprovedPayments.has(p.id)) as payment}
									<tr>
										<td>{payment.bill_number}</td>
										<td>{payment.vendor_name}</td>
										<td>{payment.branch_name}</td>
										<td>{payment.payment_method}</td>
										<td>{formatCurrency(payment.final_bill_amount || payment.bill_amount)}</td>
										<td>{formatCurrency(adjustAmounts[`nonapproved-${payment.id}`] || 0)}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}
</div>

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

	/* Print Modal Styles */
	.print-modal-overlay {
		z-index: 1200;
		background: rgba(0, 0, 0, 0.7);
	}

	.print-modal-content {
		width: 98%;
		max-width: 1400px;
		max-height: 95vh;
		background: white;
		border-radius: 8px;
		overflow-y: auto;
		padding: 0;
	}

	.print-modal-header {
		position: sticky;
		top: 0;
		background: white;
		padding: 20px 30px;
		border-bottom: 2px solid #e5e7eb;
		display: flex;
		justify-content: space-between;
		align-items: center;
		z-index: 10;
	}

	.print-modal-header h2 {
		margin: 0;
		color: #1f2937;
		font-size: 1.5rem;
	}

	.print-modal-actions {
		position: sticky;
		top: 76px;
		background: #f9fafb;
		padding: 15px 30px;
		border-bottom: 1px solid #e5e7eb;
		z-index: 9;
		display: flex;
		gap: 10px;
	}

	.print-btn {
		padding: 12px 24px;
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 600;
		display: flex;
		align-items: center;
		gap: 8px;
		transition: all 0.2s;
	}

	.print-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.print-template {
		padding: 30px;
		background: white;
		font-family: Arial, sans-serif;
	}

	.print-header {
		margin-bottom: 30px;
		border-bottom: 3px solid #3b82f6;
		padding-bottom: 15px;
	}

	.print-header-top {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 20px;
	}

	.print-logo {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.logo-img {
		width: 50px;
		height: 50px;
		object-fit: contain;
	}

	.app-name {
		font-size: 1.3rem;
		font-weight: 700;
		color: #1f2937;
	}

	.print-meta {
		text-align: right;
		display: flex;
		flex-direction: column;
		gap: 6px;
		font-size: 0.95rem;
		color: #374151;
	}

	.print-meta strong {
		color: #1f2937;
	}

	.print-date-info {
		color: #3b82f6;
		font-size: 1.05rem;
	}

	.print-header h1 {
		margin: 0;
		color: #1f2937;
		font-size: 2rem;
		text-align: center;
	}

	.print-summary {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 20px;
		margin-bottom: 30px;
		padding: 20px;
		background: #f9fafb;
		border-radius: 8px;
		border: 2px solid #e5e7eb;
	}

	.print-summary-item {
		display: flex;
		flex-direction: column;
		gap: 5px;
	}

	.print-label {
		font-size: 0.9rem;
		color: #6b7280;
		font-weight: 600;
	}

	.print-value {
		font-size: 1.3rem;
		color: #1f2937;
		font-weight: 700;
	}

	.print-value.negative {
		color: #dc2626;
	}

	.print-section {
		margin-bottom: 30px;
		page-break-inside: avoid;
	}

	.print-section-title {
		margin: 0 0 15px 0;
		color: #1f2937;
		font-size: 1.3rem;
		padding-bottom: 8px;
		border-bottom: 2px solid #3b82f6;
	}

	.print-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.9rem;
	}

	.print-table thead {
		background: #3b82f6;
		color: white;
	}

	.print-table th {
		padding: 12px 8px;
		text-align: left;
		font-weight: 600;
		border: 1px solid #2563eb;
	}

	.print-table td {
		padding: 10px 8px;
		border: 1px solid #e5e7eb;
		color: #374151;
	}

	.print-table td.negative {
		color: #dc2626;
		font-weight: 700;
	}

	.print-table tbody tr:nth-child(even) {
		background: #f9fafb;
	}

	.print-table tbody tr:hover {
		background: #eff6ff;
	}

	.print-table .status-badge {
		display: inline-block;
		padding: 4px 10px;
		border-radius: 4px;
		font-size: 0.85rem;
		font-weight: 600;
		white-space: nowrap;
	}

	.print-table .status-badge.over {
		background: #fee2e2;
		color: #dc2626;
	}

	.print-table .status-badge.within {
		background: #d1fae5;
		color: #059669;
	}

	.print-table .status-badge.unused {
		background: #f3f4f6;
		color: #6b7280;
	}

	.print-table .status-badge.approved {
		background: #d1fae5;
		color: #059669;
	}

	.print-table .status-badge.pending {
		background: #fef3c7;
		color: #d97706;
	}

	.print-footer {
		margin-top: 40px;
		padding-top: 20px;
		border-top: 2px solid #e5e7eb;
		text-align: center;
		color: #6b7280;
		font-size: 0.9rem;
	}

	.print-footer p {
		margin: 5px 0;
	}

	/* Print-specific styles */
	@media print {
		/* Nuclear option - hide absolutely everything globally */
		:global(*) {
			visibility: hidden !important;
			display: none !important;
		}

		/* Reset body and html */
		:global(html),
		:global(body) {
			display: block !important;
			visibility: visible !important;
			height: auto !important;
			width: 100% !important;
			overflow: visible !important;
			margin: 0 !important;
			padding: 0 !important;
			background: white !important;
		}

		/* Show ONLY the print modal and everything inside it */
		:global(#printModalOverlay),
		:global(#printModalOverlay *),
		:global(#printModalOverlay *::before),
		:global(#printModalOverlay *::after) {
			visibility: visible !important;
			display: block !important;
		}

		/* Tables */
		:global(#printModalOverlay table),
		:global(#printModalOverlay .print-table) {
			display: table !important;
		}

		:global(#printModalOverlay thead),
		:global(#printModalOverlay .print-table thead) {
			display: table-header-group !important;
		}

		:global(#printModalOverlay tbody),
		:global(#printModalOverlay .print-table tbody) {
			display: table-row-group !important;
		}

		:global(#printModalOverlay tr),
		:global(#printModalOverlay .print-table tr) {
			display: table-row !important;
		}

		:global(#printModalOverlay th),
		:global(#printModalOverlay td),
		:global(#printModalOverlay .print-table th),
		:global(#printModalOverlay .print-table td) {
			display: table-cell !important;
		}

		/* Flex containers */
		:global(#printModalOverlay .print-logo),
		:global(#printModalOverlay .print-header-top),
		:global(#printModalOverlay .print-meta),
		:global(#printModalOverlay .print-summary),
		:global(#printModalOverlay .print-summary-item) {
			display: flex !important;
		}

		/* Inline elements */
		:global(#printModalOverlay span),
		:global(#printModalOverlay strong),
		:global(#printModalOverlay .print-label),
		:global(#printModalOverlay .print-value),
		:global(#printModalOverlay .app-name) {
			display: inline !important;
		}

		/* Inline-block elements */
		:global(#printModalOverlay img),
		:global(#printModalOverlay .logo-img),
		:global(#printModalOverlay .status-badge) {
			display: inline-block !important;
		}

		/* Hide non-printable */
		:global(#printModalOverlay .no-print),
		:global(#printModalOverlay .print-modal-header),
		:global(#printModalOverlay .print-modal-actions) {
			display: none !important;
			visibility: hidden !important;
		}

		/* Position the print modal */
		:global(#printModalOverlay) {
			position: fixed !important;
			top: 0 !important;
			left: 0 !important;
			width: 100vw !important;
			height: auto !important;
			background: white !important;
			margin: 0 !important;
			padding: 0 !important;
			z-index: 999999 !important;
		}

		:global(#printModalOverlay .print-modal-content) {
			width: 100% !important;
			max-width: none !important;
			height: auto !important;
			overflow: visible !important;
			margin: 0 !important;
			padding: 0 !important;
		}

		:global(#printModalOverlay .print-template) {
			padding: 10mm !important;
			width: 100% !important;
		}

		/* Page breaks */
		:global(#printModalOverlay .print-header),
		:global(#printModalOverlay .print-summary) {
			page-break-inside: avoid !important;
			page-break-after: avoid !important;
		}

		:global(#printModalOverlay .print-section) {
			page-break-inside: auto !important;
		}

		:global(#printModalOverlay .print-table) {
			font-size: 8pt !important;
			page-break-inside: auto !important;
		}

		:global(#printModalOverlay .print-table tr) {
			page-break-inside: avoid !important;
		}

		:global(#printModalOverlay .print-table th),
		:global(#printModalOverlay .print-table td) {
			padding: 5px 3px !important;
			font-size: 8pt !important;
		}

		@page {
			size: A4 landscape;
			margin: 8mm;
		}

		body {
			-webkit-print-color-adjust: exact;
			print-color-adjust: exact;
		}
	}
</style>