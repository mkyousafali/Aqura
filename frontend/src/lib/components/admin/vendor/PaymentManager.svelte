<script>
	// Payment Manager component (placeholder)
	// TODO: Implement payment management functionality
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
	import ScheduledPayments from './ScheduledPayments.svelte';
	import PaidPaymentsDetails from './PaidPaymentsDetails.svelte';
	import UnpaidScheduledDetails from './UnpaidScheduledDetails.svelte';
	import TaskStatusDetails from './TaskStatusDetails.svelte';

	// Data variables
	let receivingRecords = [];
	let filteredRecords = [];
	let branches = [];
	let scheduledPayments = new Map(); // Map to track scheduled payments by receiving_record_id
	let paidTransactions = []; // Store paid transactions from payment_transactions table
	let taskStatusData = { totalTasks: 0, completedTasks: 0, pendingTasks: 0 }; // Store task status data for Card 4
	let isLoading = false;
	let error = '';
	let searchQuery = '';
	
	// Paid Payments variables
	let paidPaymentsDetails = [];
	
	// Filter variables
	let branchFilterMode = 'all'; // 'all', 'branch'
	let selectedBranch = null;
	let totalRecords = 0;

	// Define the actual payment categories used in the app
	const paymentCategories = [
		'Cash on Delivery',
		'Bank on Delivery',
		'Cash Credit',
		'Bank Credit'
	];

	// Statistics variables
	let stats = {
		totalPayments: 0,
		pending: 0,
		completed: 0,
		processing: 0,
		overdue: 0,
		totalVendors: 0,
		scheduledAmount: 0,
		scheduledByPaymentMethod: {},
		totalScheduledBills: 0,
		unpaidScheduledAmount: 0,
		unpaidScheduledByPaymentMethod: {},
		unpaidScheduledBills: 0,
		paidAmount: 0,
		paidByPaymentMethod: {},
		paidTransactionsCount: 0,
		taskStatus: { totalTasks: 0, completedTasks: 0, pendingTasks: 0 }
	};

	// Reactive statement to recalculate stats when data changes
	$: if (scheduledPayments && receivingRecords.length > 0 && paidTransactions) {
		calculateStatistics();
	}

	// Load initial data
	onMount(async () => {
		await loadBranches();
		await loadScheduledPayments(); // Load scheduled payments FIRST (for table logic)
		await loadAllScheduledPaymentsForCards(); // Load all scheduled payments (for cards)
		await loadPaidTransactions(); // Load paid transactions
		await loadTaskStatusData(); // Load task status data (for Card 4)
		await loadReceivingRecords();
		
		// Auto-process Cash on Delivery payments
		await processCashOnDeliveryPayments();
		
		// Final calculation after all data is loaded
		calculateStatistics();
	});

	// Load branches for filter
	async function loadBranches() {
		try {
			const { data, error: branchError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.order('name_en');

			if (branchError) throw branchError;
			branches = data || [];
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	// Load scheduled payments to track which ones are already scheduled and paid
	async function loadScheduledPayments() {
		try {
			const { data, error: scheduleError } = await supabase
				.from('vendor_payment_schedule')
				.select('receiving_record_id, payment_status, is_paid');

			if (scheduleError) {
				console.error('Error loading scheduled payments:', scheduleError);
				return;
			}

			// Create a map for quick lookup - store both payment_status and is_paid
			scheduledPayments = new Map();
			data?.forEach(schedule => {
				scheduledPayments.set(schedule.receiving_record_id, {
					payment_status: schedule.payment_status,
					is_paid: schedule.is_paid
				});
			});
			console.log(`Total scheduled payments loaded: ${scheduledPayments.size}`);
		} catch (err) {
			console.error('Error loading scheduled payments:', err);
		}
	}

	// Load all scheduled payments data for cards (separate from table logic)
	let allScheduledPaymentsData = [];
	
	// Auto-process Cash on Delivery payments
	// REMOVED: Database trigger now handles everything automatically on INSERT
	// This function is kept for backward compatibility but does nothing
	// Migration 70 trigger auto-marks COD as paid during INSERT
	async function processCashOnDeliveryPayments() {
		// No longer needed - database trigger handles COD auto-payment on INSERT
		// See migration 70_fix_cash_on_delivery_auto_payment.sql
		console.log('✅ Cash-on-delivery auto-payment now handled by database trigger (Migration 70)');
	}
	
	async function loadAllScheduledPaymentsForCards() {
		try {
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.select('*');

			if (error) {
				console.error('Error loading all scheduled payments for cards:', error);
				return;
			}

			allScheduledPaymentsData = data || [];
		} catch (err) {
			console.error('Error loading all scheduled payments for cards:', err);
		}
	}

	// Load task status data for Card 4
	async function loadTaskStatusData() {
		try {
			// Get all task_ids from payment_transactions table
			const { data: paymentTasks, error: paymentError } = await supabase
				.from('payment_transactions')
				.select('task_id')
				.not('task_id', 'is', null);

			if (paymentError) {
				console.error('Error loading payment transaction tasks:', paymentError);
				return;
			}

			// Get unique task_ids
			const uniqueTaskIds = [...new Set(paymentTasks?.map(p => p.task_id).filter(Boolean) || [])];

			if (uniqueTaskIds.length === 0) {
				taskStatusData = { totalTasks: 0, completedTasks: 0, pendingTasks: 0 };
				return;
			}

			// Get task completions for these task_ids
			const { data: completions, error: completionError } = await supabase
				.from('task_completions')
				.select('task_id')
				.in('task_id', uniqueTaskIds);

			if (completionError) {
				console.error('Error loading task completions:', completionError);
				return;
			}

			const completedTaskIds = new Set(completions?.map(c => c.task_id) || []);
			const totalTasks = uniqueTaskIds.length;
			const completedTasks = completedTaskIds.size;
			const pendingTasks = totalTasks - completedTasks;

			taskStatusData = {
				totalTasks,
				completedTasks,
				pendingTasks
			};

		} catch (err) {
			console.error('Error loading task status data:', err);
			taskStatusData = { totalTasks: 0, completedTasks: 0, pendingTasks: 0 };
		}
	}

	// Load detailed paid payments data for modal
	async function loadPaidPaymentsDetails() {
		try {
			const { data, error } = await supabase
				.from('payment_transactions')
				.select(`
					*,
					receiving_records (
						vendor_id,
						original_bill_url,
						branch_id,
						branches (
							name_en,
							name_ar
						)
					)
				`)
				.order('transaction_date', { ascending: false });

			if (error) {
				console.error('Error loading paid payments details:', error);
				return [];
			}

			// Now get vendor names by fetching from vendors table
			if (data && data.length > 0) {
				const vendorIds = [...new Set(data
					.filter(payment => payment.receiving_records?.vendor_id)
					.map(payment => payment.receiving_records.vendor_id))];

				if (vendorIds.length > 0) {
					const { data: vendorsData, error: vendorsError } = await supabase
						.from('vendors')
						.select('erp_vendor_id, vendor_name, branch_id')
						.in('erp_vendor_id', vendorIds);

					if (!vendorsError && vendorsData) {
						// Create a map of vendor_id to vendor_name by branch
						const vendorMap = {};
						vendorsData.forEach(vendor => {
							const key = `${vendor.erp_vendor_id}_${vendor.branch_id}`;
							vendorMap[key] = vendor.vendor_name;
						});

						// Add vendor names to the payment data
						data.forEach(payment => {
							if (payment.receiving_records?.vendor_id && payment.receiving_records?.branch_id) {
								const key = `${payment.receiving_records.vendor_id}_${payment.receiving_records.branch_id}`;
								payment.vendor_name = vendorMap[key] || 'Unknown Vendor';
							}
						});
					}
				}
			}

			return data || [];
		} catch (err) {
			console.error('Error loading paid payments details:', err);
			return [];
		}
	}

	// Open paid payments in new application window
	async function openPaidPaymentsModal() {
		const paidPayments = await loadPaidPaymentsDetails();
		
		// Open new application window using window manager
		windowManager.openWindow({
			id: 'paid-payments-details',
			title: 'Paid Payments Details',
			component: PaidPaymentsDetails,
			props: {
				payments: paidPayments
			},
			icon: '💰',
			size: { width: 1200, height: 700 },
			minSize: { width: 800, height: 500 },
			position: { x: 100, y: 100 }
		});
	}

	// Open unpaid scheduled payments in new application window
	async function openUnpaidScheduledModal() {
		console.log('Opening unpaid scheduled modal...');
		const unpaidScheduled = await loadUnpaidScheduledPayments();
		
		// Open new application window using window manager
		windowManager.openWindow({
			id: 'unpaid-scheduled-details',
			title: 'Unpaid Scheduled Payments Details',
			component: UnpaidScheduledDetails,
			props: {
				payments: unpaidScheduled
			},
			icon: '📅',
			size: { width: 1300, height: 700 },
			minSize: { width: 900, height: 500 },
			position: { x: 150, y: 150 }
		});
	}

	// Open task status details in new application window
	async function openTaskStatusModal() {
		console.log('Opening task status modal...');
		
		// Open new application window using window manager
		windowManager.openWindow({
			id: 'task-status-details',
			title: 'Task Status Details',
			component: TaskStatusDetails,
			props: {},
			icon: '📋',
			size: { width: 1400, height: 700 },
			minSize: { width: 1000, height: 500 },
			position: { x: 200, y: 200 }
		});
	}

	// Load unpaid scheduled payments details
	async function loadUnpaidScheduledPayments() {
		try {
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.select(`
					*,
					branches (
						name_en,
						name_ar
					),
					receiving_records (
						original_bill_url,
						erp_purchase_invoice_reference,
						created_at
					)
				`)
				.eq('is_paid', false)
				.order('due_date', { ascending: true });

			if (error) {
				console.error('Error loading unpaid scheduled payments:', error);
				return [];
			}

			return data || [];
		} catch (err) {
			console.error('Error loading unpaid scheduled payments:', err);
			return [];
		}
	}

	// Close paid payments modal
	function viewOriginalBill(url) {
		if (url) {
			window.open(url, '_blank');
		}
	}

	// Load paid transactions from payment_transactions table as per migration 58
	async function loadPaidTransactions() {
		try {
			const { data, error: transactionError } = await supabase
				.from('payment_transactions')
				.select('*');

			if (transactionError) {
				console.error('Error loading paid transactions:', transactionError);
				return;
			}

			paidTransactions = data || [];
			console.log(`Total paid transactions loaded: ${paidTransactions.length}`);
		} catch (err) {
			console.error('Error loading paid transactions:', err);
		}
	}

	// Check if a payment is already scheduled
	function isPaymentScheduled(receivingRecordId) {
		return scheduledPayments.has(receivingRecordId);
	}

	// Check if a payment is marked as paid
	function isPaymentPaid(receivingRecordId) {
		const scheduleInfo = scheduledPayments.get(receivingRecordId);
		console.log(`Checking payment status for ${receivingRecordId}:`, scheduleInfo);
		return scheduleInfo?.is_paid === true;
	}

	// Get payment schedule status
	function getPaymentScheduleStatus(receivingRecordId) {
		const scheduleInfo = scheduledPayments.get(receivingRecordId);
		if (!scheduleInfo) return null;
		
		// If is_paid is true, return 'paid' regardless of payment_status
		if (scheduleInfo.is_paid === true) {
			return 'paid';
		}
		
		// Otherwise return the payment_status
		return scheduleInfo.payment_status || 'scheduled';
	}

	// Sort records to show unscheduled payments first, ordered by due date
	async function sortRecordsByScheduleStatus() {
		receivingRecords.sort((a, b) => {
			const aScheduled = isPaymentScheduled(a.id);
			const bScheduled = isPaymentScheduled(b.id);

			// If one is scheduled and one is not, unscheduled comes first
			if (aScheduled && !bScheduled) return 1;
			if (!aScheduled && bScheduled) return -1;

			// If both are unscheduled, sort by due date (earliest first)
			if (!aScheduled && !bScheduled) {
				if (!a.due_date && !b.due_date) return 0;
				if (!a.due_date) return 1; // Records without due date go to end
				if (!b.due_date) return -1;
				return new Date(a.due_date) - new Date(b.due_date);
			}

			// If both are scheduled, sort by due date as well
			if (aScheduled && bScheduled) {
				if (!a.due_date && !b.due_date) return 0;
				if (!a.due_date) return 1;
				if (!b.due_date) return -1;
				return new Date(a.due_date) - new Date(b.due_date);
			}

			return 0;
		});
	}

	// Load receiving records
	async function loadReceivingRecords() {
		try {
			isLoading = true;
			error = '';

			// Load receiving records with proper JOIN to vendors and branches tables
			let query = supabase
				.from('receiving_records')
				.select(`
					*,
					branches(name_en, name_ar),
					vendors!receiving_records_vendor_fkey(erp_vendor_id, vendor_name, bank_name, iban, vat_number)
				`)
				.order('created_at', { ascending: false })
				.range(0, 99999);

			// Apply branch filtering
			if (branchFilterMode === 'branch' && selectedBranch) {
				query = query.eq('branch_id', selectedBranch);
			}

			const { data: receivingData, error: receivingError } = await query;

			if (receivingError) throw receivingError;

			// Ensure scheduled payments are loaded before filtering
			await loadScheduledPayments();

			// No need for manual vendor matching anymore - data comes with proper JOINs
			// Filter out bills that are marked as paid
			receivingRecords = (receivingData || []).filter(record => {
				const isPaid = isPaymentPaid(record.id);

				return !isPaid;
			});

			// Sort records: unscheduled payments first (by due date), then scheduled payments
			await sortRecordsByScheduleStatus();

			filteredRecords = receivingRecords;
			totalRecords = receivingRecords.length;

			// Calculate statistics
			calculateStatistics();

			// Filter by search query if exists
			if (searchQuery.trim()) {
				handleSearch();
			}

		} catch (err) {
			error = err.message;
			console.error('Error loading receiving records:', err);
		} finally {
			isLoading = false;
		}
	}

	// Handle branch filter change
	async function handleBranchFilterChange() {
		await loadScheduledPayments(); // Reload scheduled payments first
		await loadReceivingRecords();
	}

	// Search functionality
	function handleSearch() {
		if (!searchQuery.trim()) {
			filteredRecords = receivingRecords;
		} else {
			const query = searchQuery.toLowerCase();
			filteredRecords = receivingRecords.filter(record => 
				record.bill_number?.toLowerCase().includes(query) ||
				record.vendors?.vendor_name?.toLowerCase().includes(query) ||
				record.vendors?.erp_vendor_id?.toString().includes(query) ||
				record.bill_amount?.toString().includes(query) ||
				record.branches?.name_en?.toLowerCase().includes(query)
			);
		}
		
		// Apply the same sorting to filtered results
		sortFilteredRecords();
	}

	// Sort filtered records by schedule status and due date
	function sortFilteredRecords() {
		filteredRecords.sort((a, b) => {
			const aScheduled = isPaymentScheduled(a.id);
			const bScheduled = isPaymentScheduled(b.id);

			// If one is scheduled and one is not, unscheduled comes first
			if (aScheduled && !bScheduled) return 1;
			if (!aScheduled && bScheduled) return -1;

			// If both are unscheduled, sort by due date (earliest first)
			if (!aScheduled && !bScheduled) {
				if (!a.due_date && !b.due_date) return 0;
				if (!a.due_date) return 1; // Records without due date go to end
				if (!b.due_date) return -1;
				return new Date(a.due_date) - new Date(b.due_date);
			}

			// If both are scheduled, sort by due date as well
			if (aScheduled && bScheduled) {
				if (!a.due_date && !b.due_date) return 0;
				if (!a.due_date) return 1;
				if (!b.due_date) return -1;
				return new Date(a.due_date) - new Date(b.due_date);
			}

			return 0;
		});
	}

	// Calculate statistics from the loaded data
	function calculateStatistics() {
		const today = new Date();
		const currentMonth = today.getMonth();
		const currentYear = today.getFullYear();

		// Get unique vendors from receiving records
		const uniqueVendors = new Set();
		receivingRecords.forEach(record => {
			if (record.vendor_id) {
				uniqueVendors.add(record.vendor_id);
			}
		});

		// Initialize counters
		let totalThisMonth = 0;
		let pending = 0;
		let completed = 0;
		let processing = 0;
		let overdue = 0;
		let scheduledAmount = 0;
		let scheduledByPaymentMethod = {};
		let totalScheduledBills = 0;
		let unpaidScheduledAmount = 0;
		let unpaidScheduledByPaymentMethod = {};
		let unpaidScheduledBills = 0;

		// Initialize all payment categories with 0 for scheduled payments
		paymentCategories.forEach(category => {
			scheduledByPaymentMethod[category] = 0;
			unpaidScheduledByPaymentMethod[category] = 0;
		});

		// Calculate scheduled payments (directly from vendor_payment_schedule table)
		// This shows ALL scheduled payments whether paid or not, from vendor_payment_schedule only
		allScheduledPaymentsData.forEach(scheduleRecord => {
			// Count total scheduled bills (both paid and unpaid)
			totalScheduledBills++;
			
			// Get amount from vendor_payment_schedule fields
			const amount = scheduleRecord.final_bill_amount || scheduleRecord.bill_amount || 0;
			
			scheduledAmount += amount;

			// Count by status for processing/completed counters
			if (scheduleRecord.is_paid === true) {
				completed++;
			} else {
				processing++;
				// Count unpaid scheduled payments
				unpaidScheduledBills++;
				unpaidScheduledAmount += amount;
			}

			// Get payment method from vendor_payment_schedule table directly
			const rawPaymentMethod = scheduleRecord.payment_method || 'Cash on Delivery';

			let paymentMethod = 'Cash on Delivery';
			
			if (rawPaymentMethod.toLowerCase().includes('cash on delivery') || rawPaymentMethod.toLowerCase().includes('cod')) {
				paymentMethod = 'Cash on Delivery';
			} else if (rawPaymentMethod.toLowerCase().includes('bank on delivery') || rawPaymentMethod.toLowerCase().includes('bod')) {
				paymentMethod = 'Bank on Delivery';
			} else if (rawPaymentMethod.toLowerCase().includes('cash credit')) {
				paymentMethod = 'Cash Credit';
			} else if (rawPaymentMethod.toLowerCase().includes('bank credit')) {
				paymentMethod = 'Bank Credit';
			}

			scheduledByPaymentMethod[paymentMethod] += amount;
			
			// Add to unpaid totals if not paid
			if (scheduleRecord.is_paid !== true) {
				unpaidScheduledByPaymentMethod[paymentMethod] += amount;
			}
		});

		// Calculate other statistics from receiving_records (for table and unscheduled payments)
		receivingRecords.forEach(record => {
			const recordDate = new Date(record.created_at);
			const isThisMonth = recordDate.getMonth() === currentMonth && recordDate.getFullYear() === currentYear;
			
			if (isThisMonth) {
				totalThisMonth++;
			}

			// Check if payment is NOT scheduled for pending/overdue counts
			const isScheduled = isPaymentScheduled(record.id);
			if (!isScheduled) {
				// Check if overdue based on due date for unscheduled payments
				if (record.due_date) {
					const dueDate = new Date(record.due_date);
					if (dueDate < today) {
						overdue++;
					} else {
						pending++;
					}
				} else {
					pending++;
				}
			}
		});

		// Calculate paid amounts (from payment_transactions table)
		let paidAmount = 0;
		let paidByPaymentMethod = {};
		let paidTransactionsCount = 0;

		// Initialize all payment categories with 0 for paid payments
		paymentCategories.forEach(category => {
			paidByPaymentMethod[category] = 0;
		});

		paidTransactions.forEach(transaction => {
			paidTransactionsCount++;
			// Get amount from payment_transactions table amount column (migration 58)
			const amount = transaction.amount || 0;
			paidAmount += amount;

			// Get payment method from payment_transactions table payment_method column (migration 58)
			const paymentMethod = transaction.payment_method || 'Cash on Delivery';

			// Map payment method to standard category
			let standardPaymentMethod = 'Cash on Delivery';
			if (paymentMethod.toLowerCase().includes('cash on delivery') || paymentMethod.toLowerCase().includes('cod')) {
				standardPaymentMethod = 'Cash on Delivery';
			} else if (paymentMethod.toLowerCase().includes('bank on delivery') || paymentMethod.toLowerCase().includes('bod')) {
				standardPaymentMethod = 'Bank on Delivery';
			} else if (paymentMethod.toLowerCase().includes('cash credit')) {
				standardPaymentMethod = 'Cash Credit';
			} else if (paymentMethod.toLowerCase().includes('bank credit')) {
				standardPaymentMethod = 'Bank Credit';
			}

			paidByPaymentMethod[standardPaymentMethod] += amount;
		});

		stats = {
			totalPayments: totalThisMonth,
			pending: pending,
			completed: completed,
			processing: processing,
			overdue: overdue,
			totalVendors: uniqueVendors.size,
			scheduledAmount: scheduledAmount,
			scheduledByPaymentMethod: scheduledByPaymentMethod,
			totalScheduledBills: totalScheduledBills,
			unpaidScheduledAmount: unpaidScheduledAmount,
			unpaidScheduledByPaymentMethod: unpaidScheduledByPaymentMethod,
			unpaidScheduledBills: unpaidScheduledBills,
			paidAmount: paidAmount,
			paidByPaymentMethod: paidByPaymentMethod,
			paidTransactionsCount: paidTransactionsCount,
			taskStatus: taskStatusData || { totalTasks: 0, completedTasks: 0, pendingTasks: 0 }
		};
	}

	// Format currency
	function formatCurrency(amount) {
		return new Intl.NumberFormat('en-US', {
			style: 'currency',
			currency: 'SAR'
		}).format(amount || 0);
	}

	// Format date
	function formatDate(dateString) {
		if (!dateString) return '-';
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	// Calculate days remaining until due date
	function getDaysRemaining(dueDateString) {
		if (!dueDateString) return 'No Due Date';
		
		const dueDate = new Date(dueDateString);
		const today = new Date();
		today.setHours(0, 0, 0, 0);
		dueDate.setHours(0, 0, 0, 0);
		
		const diffTime = dueDate.getTime() - today.getTime();
		const daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		
		if (daysRemaining < 0) {
			return `${Math.abs(daysRemaining)} days overdue`;
		} else if (daysRemaining === 0) {
			return 'Due today';
		} else {
			return `${daysRemaining} days`;
		}
	}

	// Get CSS class for days remaining color coding
	function getDaysRemainingClass(dueDateString) {
		if (!dueDateString) return 'no-due-date';
		
		const dueDate = new Date(dueDateString);
		const today = new Date();
		today.setHours(0, 0, 0, 0);
		dueDate.setHours(0, 0, 0, 0);
		
		const diffTime = dueDate.getTime() - today.getTime();
		const daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		
		if (daysRemaining < 0) {
			return 'overdue'; // Red
		} else if (daysRemaining >= 0 && daysRemaining <= 2) {
			return 'urgent'; // Orange
		} else if (daysRemaining >= 3 && daysRemaining <= 5) {
			return 'upcoming'; // Light green
		} else {
			return 'safe'; // Green
		}
	}

	// Open schedule modal for a record
	function openSchedule(record) {
		schedulingRecord = record;
		showScheduleModal = true;
	}

	function closeScheduleModal() {
		showScheduleModal = false;
		schedulingRecord = null;
	}

	// Generate unique window ID
	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Open scheduled payments window
	function openScheduledPayments() {
		const windowId = generateWindowId('scheduled-payments');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `Scheduled Payments #${instanceNumber}`,
			component: ScheduledPayments,
			icon: '📋',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	async function addToSchedule() {
		if (!schedulingRecord) return;
		
		// Check if payment already has a due date - if so, don't schedule automatically
		if (!schedulingRecord.due_date) {
			alert('❌ Cannot schedule payment!\n\nThis payment does not have a due date set. Please set a due date first through the Edit button before scheduling.');
			return;
		}
		
		try {
			// Check if this payment is already scheduled
			const { data: existingSchedule, error: checkError } = await supabase
				.from('vendor_payment_schedule')
				.select('id, payment_status')
				.eq('receiving_record_id', schedulingRecord.id)
				.single();

			if (checkError && checkError.code !== 'PGRST116') { // PGRST116 = no rows found
				throw checkError;
			}

			if (existingSchedule) {
				alert(`⚠️ Payment Already Scheduled!\n\nThis payment is already in the schedule with status: ${existingSchedule.payment_status}\n\nPlease check the payment schedule for updates.`);
				closeScheduleModal();
				return;
			}

			// Insert data into vendor_payment_schedule table
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.insert({
					receiving_record_id: schedulingRecord.id,
					bill_number: schedulingRecord.bill_number,
					vendor_id: schedulingRecord.vendor_id,
					vendor_name: schedulingRecord.vendors?.vendor_name,
					branch_id: schedulingRecord.branch_id,
					branch_name: schedulingRecord.branches?.name_en,
					bill_date: schedulingRecord.bill_date,
					bill_amount: schedulingRecord.bill_amount,
					final_bill_amount: schedulingRecord.final_bill_amount || schedulingRecord.bill_amount,
					payment_method: schedulingRecord.payment_method,
					bank_name: schedulingRecord.bank_name || schedulingRecord.vendors?.bank_name,
					iban: schedulingRecord.iban || schedulingRecord.vendors?.iban,
					due_date: schedulingRecord.due_date,
					credit_period: schedulingRecord.credit_period,
					vat_number: schedulingRecord.vendors?.vat_number,
					payment_status: 'scheduled',
					scheduled_date: new Date().toISOString(),
					notes: `Scheduled from Payment Manager on ${new Date().toLocaleDateString()}`
				})
				.select();

			if (error) throw error;

		// Immediately update the local scheduledPayments Map to show green tick without refresh
		scheduledPayments.set(schedulingRecord.id, 'scheduled');
		// Force reactivity by reassigning the Map
		scheduledPayments = scheduledPayments;
		
		alert(`✅ Payment Successfully Scheduled!\n\nBill #${schedulingRecord.bill_number}\nVendor: ${schedulingRecord.vendors?.vendor_name || 'N/A'}\nAmount: ${formatCurrency(schedulingRecord.bill_amount)}\nDue: ${formatDate(schedulingRecord.due_date)}\n\nPayment has been added to the schedule.`);
		
		// Refresh scheduled payments to update button states (for consistency)
		await loadScheduledPayments();
		
		// Re-sort records after scheduling
		await sortRecordsByScheduleStatus();
		if (searchQuery.trim()) {
			handleSearch();
		} else {
			filteredRecords = receivingRecords;
		}
		
		// Recalculate statistics
		calculateStatistics();
		
		closeScheduleModal();

		} catch (err) {
			console.error('Error scheduling payment:', err);
			alert('❌ Error scheduling payment: ' + err.message);
		}
	}

	// View certificate in new window
	function viewCertificate(certificateUrl) {
		if (certificateUrl) {
			window.open(certificateUrl, '_blank', 'width=800,height=600,scrollbars=yes,resizable=yes');
		}
	}

	// Check if file is PDF
	function isPdfFile(url) {
		if (!url) return false;
		return url.toLowerCase().includes('.pdf');
	}

	// Edit modal functionality
	let showEditModal = false;
	let editingRecord = null;
	let editForm = {
		bank_name: '',
		iban: '',
		due_date: '',
		payment_method: '',
		credit_period: ''
	};

	// Schedule modal functionality
	let showScheduleModal = false;
	let schedulingRecord = null;

	function openEditModal(record) {
		editingRecord = record;
		editForm = {
			bank_name: record.bank_name || record.vendors?.bank_name || '',
			iban: record.iban || record.vendors?.iban || '',
			due_date: record.due_date || '',
			payment_method: record.payment_method || '',
			credit_period: record.credit_period || ''
		};
		showEditModal = true;
	}

	function closeEditModal() {
		showEditModal = false;
		editingRecord = null;
		editForm = {
			bank_name: '',
			iban: '',
			due_date: '',
			payment_method: '',
			credit_period: ''
		};
	}

	async function saveEdit() {
		if (!editingRecord) return;

		try {
			const { error } = await supabase
				.from('receiving_records')
				.update({
					bank_name: editForm.bank_name.trim() || null,
					iban: editForm.iban.trim() || null,
					due_date: editForm.due_date || null,
					payment_method: editForm.payment_method.trim() || null,
					credit_period: editForm.credit_period ? parseInt(editForm.credit_period) : null
				})
				.eq('id', editingRecord.id);

			if (error) throw error;

			// Update the local data
			receivingRecords = receivingRecords.map(record => 
				record.id === editingRecord.id 
					? { 
						...record, 
						bank_name: editForm.bank_name.trim() || null,
						iban: editForm.iban.trim() || null,
						due_date: editForm.due_date || null,
						payment_method: editForm.payment_method.trim() || null,
						credit_period: editForm.credit_period ? parseInt(editForm.credit_period) : null
					}
					: record
			);

			closeEditModal();
		} catch (err) {
			console.error('Error saving edit:', err);
			alert('Error saving changes: ' + err.message);
		}
	}

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

	// Refresh data function
	async function refreshData() {
		await loadScheduledPayments(); // Load scheduled payments first (for table logic)
		await loadAllScheduledPaymentsForCards(); // Load all scheduled payments (for cards)
		await loadPaidTransactions(); // Load paid transactions
		await loadTaskStatusData(); // Load task status data (for Card 4)
		await loadReceivingRecords();
		
		// Auto-process Cash on Delivery payments
		await processCashOnDeliveryPayments();
		
		// Final calculation after all data is loaded
		calculateStatistics();
	}
</script>

<!-- Payment Manager Window -->
<div class="payment-manager">
	<div class="header">
		<div class="title-section">
			<h1 class="title">💳 Payment Manager</h1>
			<p class="subtitle">Vendor Payment Management System</p>
		</div>
		<div class="header-actions">
			<button class="refresh-btn" on:click={refreshData} title="Refresh Data">
				<span class="refresh-icon">🔄</span>
				<span class="refresh-text">Refresh</span>
			</button>
		</div>
	</div>

	<div class="content">
		<!-- Status Cards Section -->
		<div class="status-section">
			<div class="status-grid">
				<div class="status-card clickable scheduled-card" on:click={openScheduledPayments}>
					<div class="card-icon">📋</div>
					<div class="card-content">
						<h3>Scheduled Payments</h3>
						<p class="total-amount">{formatCurrency(stats.scheduledAmount)}</p>
						<div class="payment-breakdown">
							{#each Object.entries(stats.scheduledByPaymentMethod || {}) as [method, amount]}
								<div class="payment-method-item">
									<span class="method-name">{method}:</span>
									<span class="method-amount">{formatCurrency(amount)}</span>
								</div>
							{/each}
						</div>
						<p class="count-label">{stats.totalScheduledBills} bills scheduled</p>
						<p class="click-hint">Click to view details</p>
					</div>
				</div>
				
				<div class="status-card paid-card clickable" on:click={openPaidPaymentsModal}>
					<div class="card-icon">💰</div>
					<div class="card-content">
						<h3>Paid Payments</h3>
						<p class="total-amount">{formatCurrency(stats.paidAmount)}</p>
						<div class="payment-breakdown">
							{#each Object.entries(stats.paidByPaymentMethod || {}) as [method, amount]}
								<div class="payment-method-item">
									<span class="method-name">{method}:</span>
									<span class="method-amount">{formatCurrency(amount)}</span>
								</div>
							{/each}
						</div>
						<p class="count-label">{stats.paidTransactionsCount} transactions completed</p>
						<p class="click-hint">Click to view details</p>
					</div>
				</div>
				
				<div class="status-card unpaid-scheduled-card clickable" on:click={openUnpaidScheduledModal}>
					<div class="card-icon">⏳</div>
					<div class="card-content">
						<h3>Unpaid Scheduled</h3>
						<p class="total-amount">{formatCurrency(stats.unpaidScheduledAmount)}</p>
						<div class="payment-breakdown">
							{#each Object.entries(stats.unpaidScheduledByPaymentMethod || {}) as [method, amount]}
								<div class="payment-method-item">
									<span class="method-name">{method}:</span>
									<span class="method-amount">{formatCurrency(amount)}</span>
								</div>
							{/each}
						</div>
						<p class="count-label">{stats.unpaidScheduledBills} bills pending payment</p>
						<p class="click-hint">Click to view details</p>
					</div>
				</div>
				
				<div class="status-card task-status-card clickable" on:click={openTaskStatusModal}>
					<div class="card-icon">📋</div>
					<div class="card-content">
						<h3>Task Status</h3>
						<p class="total-amount">{stats.taskStatus.totalTasks} Total</p>
						<div class="task-breakdown">
							<div class="task-status-item">
								<span class="status-name">Completed:</span>
								<span class="status-count completed">{stats.taskStatus.completedTasks}</span>
							</div>
							<div class="task-status-item">
								<span class="status-name">Pending:</span>
								<span class="status-count pending">{stats.taskStatus.pendingTasks}</span>
							</div>
						</div>
						<p class="count-label">From payment transactions</p>
						<p class="click-hint">Click to view details</p>
					</div>
				</div>
				
				<div class="status-card">
					<p class="status-value">5</p>
				</div>
				
				<div class="status-card">
					<p class="status-value">6</p>
				</div>
			</div>
		</div>

		<!-- Receiving Records Section -->
		<div class="records-section">
			<!-- Branch Filter -->
			<div class="filter-section">
				<div class="filter-group">
					<h4>🏢 Filter by Branch</h4>
					<div class="radio-group">
						<label class="radio-option">
							<input 
								type="radio" 
								bind:group={branchFilterMode} 
								value="all"
								on:change={handleBranchFilterChange}
							/>
							<span class="radio-text">All Branches ({totalRecords})</span>
						</label>
						<label class="radio-option">
							<input 
								type="radio" 
								bind:group={branchFilterMode} 
								value="branch"
								on:change={handleBranchFilterChange}
							/>
							<span class="radio-text">By Branch</span>
						</label>
					</div>
				</div>

				{#if branchFilterMode === 'branch'}
					<div class="branch-select">
						<select bind:value={selectedBranch} on:change={handleBranchFilterChange}>
							<option value={null}>Select a branch...</option>
							{#each branches as branch}
								<option value={branch.id}>{branch.name_en}</option>
							{/each}
						</select>
					</div>
				{/if}
			</div>

			<!-- Search -->
			<div class="search-section">
				<input 
					type="text" 
					bind:value={searchQuery}
					on:input={handleSearch}
					placeholder="Search by bill number, vendor name, vendor ID, amount, or branch..."
					class="search-input"
				/>
			</div>

			<!-- Records Table -->
			{#if isLoading}
				<div class="loading">
					<div class="spinner"></div>
					<span>Loading receiving records...</span>
				</div>
			{:else if error}
				<div class="error">
					<span class="error-icon">⚠️</span>
					<span>Error loading data: {error}</span>
				</div>
			{:else if filteredRecords.length === 0}
				<div class="no-data">
					<span class="no-data-icon">📋</span>
					<span>No receiving records found</span>
				</div>
			{:else}
				<div class="table-info">
					<span>Showing {filteredRecords.length} of {totalRecords} records</span>
				</div>

				<div class="records-container">
					<div class="records-table">
						<div class="table-header">
							<div class="header-cell">Certificate</div>
							<div class="header-cell">Original Bill</div>
							<div class="header-cell">Bill Info</div>
							<div class="header-cell">Vendor Details</div>
							<div class="header-cell">Branch</div>
							<div class="header-cell">Bank Name</div>
							<div class="header-cell">IBAN</div>
							<div class="header-cell">Payment Info</div>
							<div class="header-cell">Days to Due</div>
							<div class="header-cell">Amounts</div>
							<div class="header-cell">ERP Invoice Ref</div>
							<div class="header-cell">Date</div>
							<div class="header-cell">Edit</div>
							<div class="header-cell">Schedule</div>
						</div>
						
						{#each filteredRecords as record}
							<div class="table-row">
								<div class="cell certificate-cell">
									{#if record.certificate_url}
										<div class="certificate-thumbnail" on:click={() => viewCertificate(record.certificate_url)}>
											<img src={record.certificate_url} alt="Certificate" loading="lazy" />
											<div class="thumbnail-overlay">
												<span>🔍</span>
											</div>
										</div>
									{:else}
										<div class="no-certificate">
											<span>�</span>
											<small>No Certificate</small>
										</div>
									{/if}
								</div>
								
								<div class="cell certificate-cell">
									{#if record.original_bill_url}
										<div class="certificate-thumbnail" on:click={() => viewOriginalBill(record.original_bill_url)}>
											{#if isPdfFile(record.original_bill_url)}
												<div class="pdf-thumbnail">
													<div class="pdf-icon">📄</div>
													<div class="pdf-label">PDF</div>
												</div>
											{:else}
												<img src={record.original_bill_url} alt="Original Bill" loading="lazy" />
											{/if}
											<div class="thumbnail-overlay">
												<span>🔍</span>
											</div>
										</div>
									{:else}
										<div class="upload-bill-container">
											<button class="upload-bill-btn">
												<span>�</span>
												<small>Original Bill Not Uploaded</small>
											</button>
										</div>
									{/if}
								</div>
								
								<div class="cell">
									<div class="bill-info">
										<strong>#{record.bill_number || 'N/A'}</strong>
										<small>{formatDate(record.bill_date)}</small>
									</div>
								</div>
								
								<div class="cell">
									<div class="vendor-info">
										<strong>{record.vendors?.vendor_name || 'N/A'}</strong>
										<small>ID: {record.vendors?.erp_vendor_id || record.vendor_id || 'N/A'}</small>
										<small>VAT: {record.vendors?.vat_number || 'N/A'}</small>
									</div>
								</div>
								
								<div class="cell">
									<span>{record.branches?.name_en || 'N/A'}</span>
								</div>
								
								<div class="cell">
									<div class="bank-info">
										<span>{record.bank_name || record.vendors?.bank_name || 'N/A'}</span>
									</div>
								</div>
								
								<div class="cell">
									<div class="iban-info">
										<span>{record.iban || record.vendors?.iban || 'N/A'}</span>
									</div>
								</div>
								
								<div class="cell">
									<div class="payment-info">
										<strong>{record.payment_method || 'N/A'}</strong>
										<small>Due: {formatDate(record.due_date)}</small>
										{#if record.credit_period}
											<small>{record.credit_period} days</small>
										{/if}
									</div>
								</div>
								
								<div class="cell">
									<div class="days-remaining {getDaysRemainingClass(record.due_date)}">
										<span>{getDaysRemaining(record.due_date)}</span>
									</div>
								</div>
								
								<div class="cell">
									<div class="amounts">
										<div>Bill: {parseFloat(record.bill_amount || 0).toFixed(2)}</div>
										<div>Final: {parseFloat(record.final_bill_amount || record.bill_amount || 0).toFixed(2)}</div>
									</div>
								</div>
								
								<div class="cell">
									<div class="erp-reference">
										<span class="erp-ref-empty">Not Entered</span>
									</div>
								</div>
								
								<div class="cell">
									<span>{formatDate(record.created_at)}</span>
								</div>
								
								<div class="cell">
									<button class="edit-btn" on:click={() => openEditModal(record)}>
										<span>✏️</span>
										<small>Edit</small>
									</button>
								</div>
								
								<div class="cell">
									{#if isPaymentScheduled(record.id)}
										<button class="schedule-btn scheduled" disabled>
											<span>✅</span>
											<small>{getPaymentScheduleStatus(record.id) === 'paid' ? 'Paid' : 'Scheduled'}</small>
										</button>
									{:else}
										<button class="schedule-btn" on:click={() => openSchedule(record)}>
											<span>📅</span>
											<small>Schedule</small>
										</button>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>



<!-- Edit Modal -->
{#if showEditModal && editingRecord}
	<div class="modal-overlay" on:click={closeEditModal}>
		<div class="edit-modal" on:click|stopPropagation>
			<div class="modal-header">
				<h3>Edit Payment Details</h3>
				<button class="close-btn" on:click={closeEditModal}>×</button>
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
				<button class="cancel-btn" on:click={closeEditModal}>Cancel</button>
				<button class="save-btn" on:click={saveEdit}>Save Changes</button>
			</div>
		</div>
	</div>
{/if}

<!-- Schedule Modal -->
{#if showScheduleModal && schedulingRecord}
	<div class="modal-overlay" on:click={closeScheduleModal}>
		<div class="schedule-modal" on:click|stopPropagation>
			<div class="modal-header">
				<h3>Schedule Payment</h3>
				<button class="close-btn" on:click={closeScheduleModal}>×</button>
			</div>
			
			<div class="modal-content">
				<div class="schedule-details">
					<div class="detail-section">
						<h4>Bill Information</h4>
						<div class="detail-grid">
							<div class="detail-item">
								<label>Bill Number:</label>
								<span>#{schedulingRecord.bill_number || 'N/A'}</span>
							</div>
							<div class="detail-item">
								<label>Bill Date:</label>
								<span>{formatDate(schedulingRecord.bill_date)}</span>
							</div>
							<div class="detail-item">
								<label>Bill Amount:</label>
								<span>{formatCurrency(schedulingRecord.bill_amount)}</span>
							</div>
							<div class="detail-item">
								<label>Final Amount:</label>
								<span>{formatCurrency(schedulingRecord.final_bill_amount || schedulingRecord.bill_amount)}</span>
							</div>
						</div>
					</div>

					<div class="detail-section">
						<h4>Vendor Information</h4>
						<div class="detail-grid">
							<div class="detail-item">
								<label>Vendor Name:</label>
								<span>{schedulingRecord.vendors?.vendor_name || 'N/A'}</span>
							</div>
							<div class="detail-item">
								<label>Vendor ID:</label>
								<span>{schedulingRecord.vendors?.erp_vendor_id || schedulingRecord.vendor_id || 'N/A'}</span>
							</div>
							<div class="detail-item">
								<label>VAT Number:</label>
								<span>{schedulingRecord.vendors?.vat_number || 'N/A'}</span>
							</div>
							<div class="detail-item">
								<label>Branch:</label>
								<span>{schedulingRecord.branches?.name_en || 'N/A'}</span>
							</div>
						</div>
					</div>

					<div class="detail-section">
						<h4>Payment Details</h4>
						<div class="detail-grid">
							<div class="detail-item">
								<label>Payment Method:</label>
								<span>{schedulingRecord.payment_method || 'N/A'}</span>
							</div>
							<div class="detail-item">
								<label>Due Date:</label>
								<span class="due-date {getDaysRemainingClass(schedulingRecord.due_date)}">
									{formatDate(schedulingRecord.due_date)} ({getDaysRemaining(schedulingRecord.due_date)})
								</span>
							</div>
							<div class="detail-item">
								<label>Bank Name:</label>
								<span>{schedulingRecord.bank_name || schedulingRecord.vendors?.bank_name || 'N/A'}</span>
							</div>
							<div class="detail-item">
								<label>IBAN:</label>
								<span class="iban-display">{schedulingRecord.iban || schedulingRecord.vendors?.iban || 'N/A'}</span>
							</div>
							{#if schedulingRecord.credit_period}
								<div class="detail-item">
									<label>Credit Period:</label>
									<span>{schedulingRecord.credit_period} days</span>
								</div>
							{/if}
						</div>
					</div>

					<div class="detail-section">
						<h4>Additional Information</h4>
						<div class="detail-grid">
							<div class="detail-item">
								<label>Created Date:</label>
								<span>{formatDate(schedulingRecord.created_at)}</span>
							</div>
							<div class="detail-item">
								<label>ERP Invoice Ref:</label>
								<span class="erp-ref">Not Entered</span>
							</div>
						</div>
					</div>
				</div>
			</div>
			
			<div class="modal-footer">
				<button class="cancel-btn" on:click={closeScheduleModal}>Cancel</button>
				<button class="schedule-btn" on:click={addToSchedule}>Add to Schedule</button>
			</div>
		</div>
	</div>
{/if}



<style>
	.payment-manager {
		padding: 24px;
		height: 100vh;
		background: white;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.header {
		margin-bottom: 32px;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.title-section {
		text-align: left;
	}

	.title-section .title {
		font-size: 28px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.title-section .subtitle {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.header-actions {
		display: flex;
		gap: 12px;
		align-items: center;
	}

	.refresh-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 16px;
		background: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
		font-size: 14px;
		font-weight: 500;
	}

	.refresh-btn:hover {
		background: #e5e7eb;
		border-color: #9ca3af;
		transform: translateY(-1px);
	}

	.refresh-btn:active {
		transform: translateY(0);
	}

	.refresh-icon {
		font-size: 16px;
		transition: transform 0.3s ease;
	}

	.refresh-btn:hover .refresh-icon {
		transform: rotate(180deg);
	}

	.refresh-text {
		font-weight: 500;
	}

	.content {
		display: flex;
		flex-direction: column;
		height: calc(100% - 120px);
	}

	.status-section {
		margin-bottom: 32px;
	}

	.status-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
		gap: 24px;
		margin-bottom: 32px;
	}

	.status-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 16px;
		padding: 32px 24px;
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		transition: all 0.3s ease;
		box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
		min-height: 160px;
		justify-content: center;
	}

	.status-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
		border-color: #d1d5db;
	}

	.status-card.clickable {
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.status-card.clickable:hover {
		background: #f8fafc;
		border-color: #3b82f6;
	}

	.scheduled-card {
		display: flex;
		align-items: flex-start;
		gap: 16px;
		padding: 24px;
		text-align: left;
		min-height: 200px;
	}

	.paid-card {
		display: flex;
		align-items: flex-start;
		gap: 16px;
		padding: 24px;
		text-align: left;
		min-height: 200px;
	}

	.paid-card .card-icon {
		background: #10b981;
	}

	.paid-card .total-amount {
		color: #10b981;
	}

	.unpaid-scheduled-card {
		display: flex;
		align-items: flex-start;
		gap: 16px;
		padding: 24px;
		text-align: left;
		min-height: 200px;
	}

	.unpaid-scheduled-card .card-icon {
		background: #f59e0b;
		color: white;
	}

	.unpaid-scheduled-card .total-amount {
		color: #f59e0b;
	}

	.unpaid-scheduled-card.clickable:hover {
		background: #fffbeb;
		border-color: #f59e0b;
		transform: translateY(-2px);
		box-shadow: 0 8px 25px rgba(245, 158, 11, 0.1);
	}

	.unpaid-scheduled-card.clickable:active {
		transform: translateY(0);
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.15);
	}

	.task-status-card {
		display: flex;
		align-items: flex-start;
		gap: 16px;
		padding: 24px;
		text-align: left;
		min-height: 200px;
	}

	.task-status-card .card-icon {
		background: #8b5cf6;
		color: white;
	}

	.task-status-card .total-amount {
		color: #8b5cf6;
	}

	.task-breakdown {
		margin: 0 0 12px 0;
	}

	.task-status-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 4px;
		padding: 2px 0;
	}

	.status-name {
		font-size: 12px;
		color: #6b7280;
		font-weight: 500;
	}

	.status-count {
		font-size: 12px;
		font-weight: 600;
	}

	.status-count.completed {
		color: #10b981;
	}

	.status-count.pending {
		color: #f59e0b;
	}

	.card-icon {
		font-size: 32px;
		background: #3b82f6;
		color: white;
		width: 56px;
		height: 56px;
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.card-content {
		flex: 1;
	}

	.card-content h3 {
		margin: 0 0 12px 0;
		font-size: 16px;
		font-weight: 600;
		color: #1f2937;
	}

	.total-amount {
		margin: 0 0 12px 0;
		font-size: 24px;
		font-weight: 700;
		color: #3b82f6;
		border-bottom: 1px solid #e5e7eb;
		padding-bottom: 8px;
	}

	.payment-breakdown {
		margin: 0 0 12px 0;
	}

	.payment-method-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 4px;
		padding: 2px 0;
	}

	.method-name {
		font-size: 12px;
		color: #6b7280;
		font-weight: 500;
	}

	.method-amount {
		font-size: 12px;
		color: #374151;
		font-weight: 600;
	}

	.count-label {
		margin: 0 0 4px 0;
		font-size: 14px;
		color: #6b7280;
		font-weight: 500;
	}

	.click-hint {
		margin: 0;
		font-size: 12px;
		color: #9ca3af;
		font-style: italic;
	}

	.status-icon {
		font-size: 48px;
		width: 80px;
		height: 80px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
		border-radius: 20px;
		margin-bottom: 16px;
		flex-shrink: 0;
	}

	.status-info {
		width: 100%;
	}

	.status-info h3 {
		font-size: 16px;
		font-weight: 600;
		color: #374151;
		margin: 0 0 8px 0;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.status-value {
		font-size: 42px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 8px 0;
		line-height: 1;
	}

	.status-label {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
		font-weight: 500;
	}

	/* Receiving Records Section */
	.records-section {
		margin-top: 2rem;
		background: white;
		border-radius: 8px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		overflow: hidden;
	}

	.filter-section {
		padding: 1.5rem;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
	}

	.filter-group h4 {
		margin: 0 0 0.75rem 0;
		color: #374151;
		font-weight: 600;
	}

	.radio-group {
		display: flex;
		gap: 1.5rem;
		flex-wrap: wrap;
	}

	.radio-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		padding: 0.5rem;
		border-radius: 6px;
		transition: background-color 0.2s;
	}

	.radio-option:hover {
		background: rgba(124, 58, 237, 0.1);
	}

	.radio-option input[type="radio"] {
		margin: 0;
		accent-color: #7c3aed;
	}

	.radio-text {
		color: #374151;
		font-weight: 500;
	}

	.branch-select {
		margin-top: 1rem;
		max-width: 300px;
	}

	.branch-select select {
		width: 100%;
		padding: 0.75rem;
		border: 2px solid #e2e8f0;
		border-radius: 6px;
		background: white;
		color: #374151;
		font-size: 0.875rem;
		transition: border-color 0.2s;
	}

	.branch-select select:focus {
		outline: none;
		border-color: #7c3aed;
		box-shadow: 0 0 0 3px rgba(124, 58, 237, 0.1);
	}

	.search-section {
		padding: 1rem 1.5rem;
		background: white;
		border-bottom: 1px solid #e2e8f0;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem 1rem;
		border: 2px solid #e2e8f0;
		border-radius: 6px;
		font-size: 0.875rem;
		transition: border-color 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: #7c3aed;
		box-shadow: 0 0 0 3px rgba(124, 58, 237, 0.1);
	}

	.loading, .error, .no-data {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 3rem;
		gap: 0.75rem;
		color: #6b7280;
		text-align: center;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #f3f4f6;
		border-left: 4px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin: 0 auto 16px;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.error {
		color: #dc2626;
	}

	.error-icon {
		font-size: 1.25rem;
	}

	.no-data-icon {
		font-size: 2rem;
		opacity: 0.5;
	}

	.table-info {
		padding: 0.75rem 1.5rem;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
		color: #6b7280;
		font-size: 0.875rem;
	}

	.records-container {
		background: white;
		border-radius: 12px;
		border: 1px solid #e2e8f0;
		overflow: hidden;
		flex: 1;
		max-height: 70vh;
		display: flex;
		flex-direction: column;
	}

	.records-table {
		display: flex;
		flex-direction: column;
		flex: 1;
		overflow: auto;
	}

	.table-header {
		display: grid;
		grid-template-columns: 120px 120px 1fr 1fr 1fr 150px 180px 1fr 120px 1fr 140px 100px 100px 120px;
		gap: 16px;
		padding: 16px;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
		font-weight: 600;
		color: #374151;
		font-size: 14px;
		position: sticky;
		top: 0;
		z-index: 10;
		flex-shrink: 0;
	}

	.header-cell {
		display: flex;
		align-items: center;
		font-weight: 600;
		color: #374151;
		font-size: 14px;
	}

	.table-row {
		display: grid;
		grid-template-columns: 120px 120px 1fr 1fr 1fr 150px 180px 1fr 120px 1fr 140px 100px 100px 120px;
		gap: 16px;
		padding: 16px;
		border-bottom: 1px solid #f1f5f9;
		transition: background-color 0.2s ease;
	}

	.table-row:hover {
		background: #f8fafc;
	}

	.cell {
		display: flex;
		align-items: center;
		font-size: 14px;
		color: #374151;
	}

	.certificate-cell {
		justify-content: center;
	}

	.certificate-thumbnail {
		width: 80px;
		height: 60px;
		border-radius: 8px;
		overflow: hidden;
		cursor: pointer;
		position: relative;
		border: 2px solid #e2e8f0;
		transition: all 0.2s ease;
	}

	.certificate-thumbnail:hover {
		border-color: #3b82f6;
		transform: scale(1.05);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.certificate-thumbnail img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.thumbnail-overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.7);
		display: flex;
		align-items: center;
		justify-content: center;
		opacity: 0;
		transition: opacity 0.2s ease;
		color: white;
		font-size: 20px;
	}

	.certificate-thumbnail:hover .thumbnail-overlay {
		opacity: 1;
	}

	.pdf-thumbnail {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
		color: white;
		border-radius: 6px;
		position: relative;
	}

	.pdf-icon {
		font-size: 24px;
		margin-bottom: 2px;
	}

	.pdf-label {
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 0.5px;
	}

	.no-certificate {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
		color: #9ca3af;
		font-size: 24px;
	}

	.no-certificate small {
		font-size: 10px;
		color: #6b7280;
	}

	.upload-bill-container,
	.upload-excel-container {
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.upload-bill-btn,
	.upload-excel-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
		padding: 8px;
		border: 2px dashed #d1d5db;
		border-radius: 8px;
		background: #f9fafb;
		color: #6b7280;
		cursor: pointer;
		transition: all 0.2s ease;
		font-size: 18px;
		min-width: 80px;
		min-height: 60px;
	}

	.upload-bill-btn:hover,
	.upload-excel-btn:hover {
		border-color: #3b82f6;
		background: #eff6ff;
		color: #3b82f6;
	}

	.upload-bill-btn small,
	.upload-excel-btn small {
		font-size: 9px;
		text-align: center;
		line-height: 1.2;
	}

	.schedule-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 8px 12px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
		font-size: 12px;
		gap: 4px;
		width: 100%;
		min-height: 60px;
	}

	.schedule-btn.scheduled {
		background: #10b981;
		cursor: not-allowed;
		opacity: 0.9;
	}

	.schedule-btn.scheduled:hover {
		background: #10b981;
		transform: none;
	}

	.edit-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 8px 12px;
		background: #f59e0b;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
		font-size: 12px;
		gap: 4px;
		width: 100%;
		min-height: 60px;
	}

	.edit-btn:hover {
		background: #d97706;
		transform: translateY(-1px);
	}

	.edit-btn span {
		font-size: 16px;
	}

	.edit-btn small {
		font-size: 10px;
		font-weight: 500;
	}

	.schedule-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
	}

	.schedule-btn span {
		font-size: 16px;
	}

	.schedule-btn small {
		font-size: 10px;
		font-weight: 500;
	}

	.excel-file-container {
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.excel-file-link {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
		padding: 8px;
		border: 2px solid #10b981;
		border-radius: 8px;
		background: #ecfdf5;
		color: #10b981;
		text-decoration: none;
		transition: all 0.2s ease;
		min-width: 80px;
		min-height: 60px;
	}

	.excel-file-link:hover {
		background: #d1fae5;
		transform: scale(1.05);
	}

	.excel-icon {
		font-size: 24px;
	}

	.excel-file-link small {
		font-size: 10px;
		font-weight: 600;
	}

	.certificate-placeholder,
	.bill-placeholder,
	.excel-placeholder {
		width: 60px;
		height: 45px;
		border-radius: 8px;
		border: 2px solid #e2e8f0;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f8fafc;
		color: #9ca3af;
		font-size: 18px;
	}

	.bill-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.bill-info strong {
		font-weight: 600;
		color: #1f2937;
	}

	.bill-info small {
		color: #6b7280;
		font-size: 12px;
	}

	.vendor-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.vendor-info strong {
		font-weight: 600;
		color: #1f2937;
	}

	.vendor-info small {
		color: #6b7280;
		font-size: 12px;
	}

	.bank-info {
		display: flex;
		align-items: center;
		font-weight: 500;
		color: #374151;
		font-size: 13px;
	}

	.iban-info {
		display: flex;
		align-items: center;
		font-family: monospace;
		font-size: 12px;
		color: #1f2937;
		background: #f8fafc;
		padding: 4px 8px;
		border-radius: 4px;
		border: 1px solid #e2e8f0;
	}

	.iban-info span {
		word-break: break-all;
	}

	.payment-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.payment-info strong {
		font-weight: 600;
		color: #1f2937;
	}

	.payment-info small {
		color: #6b7280;
		font-size: 12px;
	}

	.days-remaining {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 6px 12px;
		border-radius: 6px;
		font-weight: 600;
		font-size: 12px;
		border: 1px solid;
		transition: all 0.2s ease;
	}

	/* Color coding for days remaining */
	.days-remaining.overdue {
		background: #fef2f2;
		color: #dc2626;
		border-color: #fecaca;
	}

	.days-remaining.urgent {
		background: #fff7ed;
		color: #ea580c;
		border-color: #fed7aa;
	}

	.days-remaining.upcoming {
		background: #f0fdf4;
		color: #16a34a;
		border-color: #bbf7d0;
	}

	.days-remaining.safe {
		background: #dcfce7;
		color: #166534;
		border-color: #bbf7d0;
	}

	.days-remaining.no-due-date {
		background: #f9fafb;
		color: #6b7280;
		border-color: #e5e7eb;
	}

	.amounts {
		display: flex;
		flex-direction: column;
		gap: 2px;
		font-size: 12px;
	}

	.amounts div {
		color: #374151;
	}

	.erp-reference {
		display: flex;
		align-items: center;
	}

	.erp-ref-empty {
		color: #9ca3af;
		font-style: italic;
		font-size: 12px;
	}

	.placeholder {
		text-align: center;
		padding: 40px;
		border: 2px dashed #d1d5db;
		border-radius: 16px;
		background: #f9fafb;
		max-width: 400px;
		margin: 0 auto;
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
	}

	.placeholder-icon {
		font-size: 64px;
		margin-bottom: 16px;
	}

	.placeholder h2 {
		font-size: 24px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 12px 0;
	}

	.placeholder p {
		font-size: 16px;
		color: #6b7280;
		margin: 8px 0;
		line-height: 1.5;
	}

	/* Edit Modal Styles */
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

	.edit-modal {
		background: white;
		border-radius: 12px;
		width: 90%;
		max-width: 600px;
		max-height: 80vh;
		overflow-y: auto;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 24px 24px 0 24px;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-header h3 {
		font-size: 18px;
		font-weight: 600;
		color: #1f2937;
		margin: 0;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		color: #9ca3af;
		cursor: pointer;
		padding: 4px;
		line-height: 1;
	}

	.close-btn:hover {
		color: #6b7280;
	}

	.modal-content {
		padding: 24px;
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

	/* Schedule Modal Styles */
	.schedule-modal {
		background: white;
		border-radius: 12px;
		width: 90%;
		max-width: 800px;
		max-height: 85vh;
		overflow-y: auto;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
	}

	.schedule-details {
		display: flex;
		flex-direction: column;
		gap: 24px;
	}

	.detail-section {
		background: #f8fafc;
		border-radius: 8px;
		padding: 20px;
		border: 1px solid #e2e8f0;
	}

	.detail-section h4 {
		font-size: 16px;
		font-weight: 600;
		color: #1e293b;
		margin: 0 0 16px 0;
		padding-bottom: 8px;
		border-bottom: 2px solid #e2e8f0;
	}

	.detail-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 16px;
	}

	.detail-item {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.detail-item label {
		font-weight: 500;
		color: #475569;
		font-size: 13px;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.detail-item span {
		font-weight: 500;
		color: #1e293b;
		font-size: 14px;
		padding: 6px 0;
	}

	.due-date {
		padding: 4px 8px;
		border-radius: 4px;
		font-weight: 600;
		font-size: 12px;
		border: 1px solid;
		display: inline-block;
		width: fit-content;
	}

	.iban-display {
		font-family: monospace;
		font-size: 12px;
		background: #f1f5f9;
		padding: 4px 8px;
		border-radius: 4px;
		border: 1px solid #e2e8f0;
		word-break: break-all;
	}

	.erp-ref {
		color: #9ca3af;
		font-style: italic;
		font-size: 12px;
	}

	.schedule-btn {
		padding: 10px 20px;
		background: #059669;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
		transition: all 0.2s ease;
	}

	.schedule-btn:hover {
		background: #047857;
	}

	/* Clickable Task Status Card */
	.task-status-card.clickable {
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.task-status-card.clickable:hover {
		background: #f0f4ff;
		border-color: #667eea;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.15);
	}

	.task-status-card.clickable:active {
		transform: translateY(0);
		box-shadow: 0 2px 8px rgba(102, 126, 234, 0.2);
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


</style>