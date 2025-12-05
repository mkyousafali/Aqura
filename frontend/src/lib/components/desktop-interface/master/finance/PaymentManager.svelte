<script>
	// Payment Manager component (placeholder)
	// TODO: Implement payment management functionality
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { supabaseAdmin } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import ScheduledPayments from '$lib/components/desktop-interface/master/finance/ScheduledPayments.svelte';
	import PaidPaymentsDetails from '$lib/components/desktop-interface/master/finance/PaidPaymentsDetails.svelte';
	import UnpaidScheduledDetails from '$lib/components/desktop-interface/master/finance/UnpaidScheduledDetails.svelte';
	import TaskStatusDetails from '$lib/components/desktop-interface/master/finance/TaskStatusDetails.svelte';
	import ExpensesManager from '$lib/components/desktop-interface/master/finance/ExpensesManager.svelte';

	// Data variables
	let receivingRecords = [];
	let filteredRecords = [];
	let branches = [];
	let scheduledPayments = new Map(); // Map to track scheduled payments by receiving_record_id
	let paidPayments = []; // Store paid payments from vendor_payment_schedule table where is_paid=true
	let expenseSchedulerPayments = []; // Store expense scheduler payments
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
	
	// Pagination variables
	let currentPage = 1;
	let pageSize = 100;
	let totalPages = 1;

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

	// Load initial data
	onMount(async () => {
		// Load branches and scheduled payments first (needed for table logic)
		await Promise.all([
			loadBranches(),
			loadScheduledPayments() // Single load for all scheduled payments data
		]);
		
		// Load remaining data in parallel
		await Promise.all([
			loadPaidPayments(),
			loadExpenseSchedulerPayments(),
			loadTaskStatusData(),
			loadReceivingRecords()
		]);
		
		// COD auto-processing removed - manual payments only
		console.log('ℹ️ COD auto-processing disabled - all payments require manual marking');
		
		// Single calculation after all data is loaded
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
	// Also loads all data needed for cards in a single query
	async function loadScheduledPayments() {
		try {
			// Fetch ALL records using pagination (Supabase default limit is 1000)
			let allData = [];
			let page = 0;
			const pageSize = 1000;
			let hasMore = true;

			while (hasMore) {
				const { data, error: scheduleError } = await supabase
					.from('vendor_payment_schedule')
					.select('*')
					.range(page * pageSize, (page + 1) * pageSize - 1);

				if (scheduleError) {
					console.error('Error loading scheduled payments:', scheduleError);
					return;
				}

				if (data && data.length > 0) {
					allData = allData.concat(data);
					if (data.length < pageSize) {
						hasMore = false;
					} else {
						page++;
					}
				} else {
					hasMore = false;
				}
			}

			// Store full data for cards
			allScheduledPaymentsData = allData;

			// Create a map for quick lookup - store is_paid status
			scheduledPayments = new Map();
			allData.forEach(schedule => {
				scheduledPayments.set(schedule.receiving_record_id, {
					is_paid: schedule.is_paid
				});
			});
			console.log(`✅ Total scheduled payments loaded: ${scheduledPayments.size} (all pages)`);
		} catch (err) {
			console.error('Error loading scheduled payments:', err);
		}
	}

	// All scheduled payments data for cards (loaded in loadScheduledPayments)
	let allScheduledPaymentsData = [];
	
	// Frontend Fallback Payment Processing System - DISABLED
	// COD auto-processing has been completely removed
	// All payments now require manual marking

	// Comprehensive sync function that handles ALL manually marked payments missing transactions
	async function syncAllMissingTransactions() {
		console.log('🔄 Running comprehensive transaction sync (MANUAL PAYMENTS ONLY)...');
		syncMessage = 'Scanning manually marked payments for missing transactions...';
		
		try {
			// Get ALL payments marked as paid
			const { data: allPaidPayments, error: paidError } = await supabase
				.from('vendor_payment_schedule')
				.select(`
					*,
					receiving_records!receiving_record_id (
						accountant_user_id,
						user_id,
						bill_number,
						original_bill_url,
						users!user_id (
							username
						)
					)
				`)
				.eq('is_paid', true)
				.order('paid_date', { ascending: false });

			if (paidError) {
				console.error('Error fetching all paid payments:', paidError);
				syncStats.errors++;
				return;
			}

			console.log(`📊 Found ${allPaidPayments?.length || 0} payments marked as paid (manually)`);
			syncStats.found = allPaidPayments?.length || 0;

			// Get ALL existing transactions
			const { data: allTransactions, error: transError } = await supabase
				.from('payment_transactions')
				.select('payment_schedule_id');

			if (transError) {
				console.error('Error fetching existing transactions:', transError);
				syncStats.errors++;
				return;
			}

			// Create a Set of payment IDs that already have transactions
			const existingTransactionIds = new Set(
				allTransactions?.map(t => t.payment_schedule_id) || []
			);

			console.log(`� Found ${allTransactions?.length || 0} existing transaction records`);

			let processed = 0;
			const missingTransactions = [];

			// Check each paid payment for missing transaction
			for (const payment of allPaidPayments || []) {
				if (!existingTransactionIds.has(payment.id)) {
					missingTransactions.push(payment);
					const paymentType = payment.payment_method?.toLowerCase().includes('cash on delivery') ? 'COD (Manual)' : 'Manual';
					console.log(`❌ Missing transaction for payment ID: ${payment.id}, Bill: ${payment.bill_number}, Vendor: ${payment.vendor_name}, Method: ${payment.payment_method} (${paymentType})`);
				}
			}

			console.log(`🔍 Found ${missingTransactions.length} manually marked payments missing transaction records`);

			// Process each missing transaction
			for (const payment of missingTransactions) {
				try {
					const paymentType = payment.payment_method?.toLowerCase().includes('cash on delivery') ? 'COD Manual Sync' : 'Manual Payment Sync';
					await createMissingTransaction(payment, paymentType);
					processed++;
					syncStats.fixed++;
					
					syncMessage = `Processing missing transactions... (${processed}/${missingTransactions.length})`;
				} catch (error) {
					console.error(`Error creating transaction for payment ${payment.id}:`, error);
					syncStats.errors++;
				}
			}

			if (processed > 0) {
				console.log(`🔧 Successfully created ${processed} missing transaction records for manually marked payments`);
				// Reload transaction data to update UI
				await loadPaidPayments();
			}
		} catch (error) {
			console.error('Error in comprehensive sync:', error);
			syncStats.errors++;
		}
	}

	// New function to sync existing transactions that don't have tasks
	async function syncExistingTransactionsWithoutTasks() {
		console.log('🔄 Checking existing transactions for missing tasks...');
		syncMessage = 'Scanning existing transactions for missing tasks...';
		
		try {
			// Get all payment transactions with their related payment schedule data
			const { data: allTransactions, error: transError } = await supabase
				.from('payment_transactions')
				.select(`
					*,
					vendor_payment_schedule!payment_schedule_id (
						*,
						receiving_records!receiving_record_id (
							accountant_user_id,
							user_id,
							bill_number,
							original_bill_url,
							users!user_id (
								username
							)
						)
					)
				`)
				.order('transaction_date', { ascending: false });

			if (transError) {
				console.error('Error fetching existing transactions:', transError);
				syncStats.errors++;
				return;
			}

			syncStats.existingTransactions = allTransactions?.length || 0;
			console.log(`📊 Found ${syncStats.existingTransactions} existing transaction records`);

			// Filter transactions that don't have tasks assigned
			const transactionsWithoutTasks = allTransactions?.filter(transaction => !transaction.task_id) || [];
			
			console.log(`🔍 Found ${transactionsWithoutTasks.length} transactions without tasks`);

			let tasksCreated = 0;

			// Process each transaction without a task
			for (const transaction of transactionsWithoutTasks) {
				try {
					const paymentSchedule = transaction.vendor_payment_schedule;
					const receivingRecord = paymentSchedule?.receiving_records;

					// Skip if no accountant assigned
					if (!receivingRecord?.accountant_user_id) {
						console.log(`⚠️ Transaction ${transaction.id} has no accountant assigned - skipping task creation`);
						continue;
					}

					console.log(`📋 Creating missing task for transaction ${transaction.id}:`, {
						bill_number: transaction.bill_number,
						vendor_name: transaction.vendor_name,
						amount: transaction.amount,
						accountant_id: receivingRecord.accountant_user_id
					});

					// Create task for this transaction
					const receiverName = receivingRecord.users?.username || 'Unknown';
					
					const { data: taskData, error: taskError } = await supabaseAdmin
						.from('tasks')
						.insert({
							title: 'Payment transaction requires ERP entry and receipt upload',
							description: `Transaction Details:
- Transaction ID: ${transaction.id}
- Bill Number: ${transaction.bill_number || 'N/A'}
- Bill Amount: ${(transaction.amount || 0).toLocaleString()}
- Vendor Name: ${transaction.vendor_name || 'N/A'}
- Receiver: ${receiverName}
- Payment Method: ${transaction.payment_method || 'N/A'}
- Transaction Date: ${transaction.transaction_date ? new Date(transaction.transaction_date).toLocaleDateString() : 'N/A'}

This payment transaction was found without an associated task. Please enter into ERP, update reference, and upload receipt.`,
							created_by: receivingRecord.user_id,
							created_by_name: 'System - Transaction Task Sync',
							require_task_finished: true,
							priority: 'medium',
							status: 'active'
						})
						.select()
						.single();

					if (taskError) {
						console.error('❌ Error creating task for transaction:', taskError);
						syncStats.errors++;
						continue;
					}

					console.log('✅ Task created successfully:', taskData.id);

					// Create task assignment
					const { data: assignmentData, error: assignmentError } = await supabase
						.from('task_assignments')
						.insert({
							task_id: taskData.id,
							assignment_type: 'user',
							assigned_to_user_id: receivingRecord.accountant_user_id,
							assigned_by: receivingRecord.user_id,
							assigned_by_name: 'System - Transaction Task Sync',
							deadline_date: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString().split('T')[0],
							require_task_finished: true,
							status: 'assigned'
						})
						.select()
						.single();

					if (assignmentError) {
						console.error('❌ Error creating task assignment:', assignmentError);
						syncStats.errors++;
						continue;
					}

					console.log('✅ Task assignment created successfully:', assignmentData.id);

					// Update the transaction record with the task ID
					const { error: updateError } = await supabase
						.from('payment_transactions')
						.update({
							task_id: taskData.id,
							task_assignment_id: assignmentData.id,
							updated_at: new Date().toISOString()
						})
						.eq('id', transaction.id);

					if (updateError) {
						console.error('❌ Error updating transaction with task ID:', updateError);
					} else {
						console.log('✅ Transaction updated with task references');
					}

					// Create notification
					const { error: notificationError } = await supabase
						.from('notifications')
						.insert({
							title: 'Payment Transaction Task Assigned',
							message: `You have been assigned a task for payment transaction ${transaction.bill_number || transaction.id}. Amount: ${(transaction.amount || 0).toLocaleString()} (Retroactive task creation)`,
							type: 'task_assigned',
							priority: 'medium',
							target_type: 'specific_users',
							target_users: JSON.stringify([receivingRecord.accountant_user_id]),
							created_by: receivingRecord.user_id,
							created_by_name: 'System - Transaction Task Sync',
							task_id: taskData.id,
							task_assignment_id: assignmentData.id
						});

					if (notificationError) {
						console.error('❌ Error creating notification:', notificationError);
					} else {
						console.log('✅ Notification created successfully');
					}

					tasksCreated++;
					syncStats.tasksCreated++;
					
					syncMessage = `Creating tasks for existing transactions... (${tasksCreated}/${transactionsWithoutTasks.length})`;

				} catch (error) {
					console.error(`❌ Error processing transaction ${transaction.id}:`, error);
					syncStats.errors++;
				}
			}

			if (tasksCreated > 0) {
				console.log(`🔧 Successfully created ${tasksCreated} tasks for existing transactions`);
			} else {
				console.log('✅ All existing transactions already have tasks assigned');
			}

		} catch (error) {
			console.error('Error in existing transaction task sync:', error);
			syncStats.errors++;
		}
	}

	// Sync missing payment transactions for COD payments
	async function syncCODPayments() {
		// This function is now part of syncAllMissingTransactions
		// Keeping for backward compatibility
		console.log('� COD sync is now handled by comprehensive sync function');
	}

	// Sync missing transaction records for manual payments  
	async function syncManualPayments() {
		// This function is now part of syncAllMissingTransactions
		// Keeping for backward compatibility
		console.log('🔄 Manual payment sync is now handled by comprehensive sync function');
	}

	// Generic function to create missing transaction and task
	async function createMissingTransaction(payment, source) {
		try {
			const receivingRecord = payment.receiving_records;
			console.log(`🔧 Creating transaction for payment ${payment.id}:`, {
				bill_number: payment.bill_number,
				vendor_name: payment.vendor_name,
				payment_method: payment.payment_method,
				accountant_user_id: receivingRecord?.accountant_user_id,
				receiver_user_id: receivingRecord?.user_id
			});

			// Create payment transaction record
			const { error: transactionError } = await supabaseAdmin
				.from('payment_transactions')
				.insert({
					payment_schedule_id: payment.id,
					receiving_record_id: payment.receiving_record_id,
					receiver_user_id: receivingRecord?.user_id,
					accountant_user_id: receivingRecord?.accountant_user_id,
					transaction_date: payment.paid_date || new Date().toISOString(),
					amount: payment.final_bill_amount || payment.bill_amount,
					payment_method: payment.payment_method,
					bank_name: payment.bank_name,
					iban: payment.iban,
					vendor_name: payment.vendor_name,
					bill_number: payment.bill_number,
					original_bill_url: receivingRecord?.original_bill_url,
					notes: `Auto-generated by frontend fallback system - ${source}`,
					created_by: null // System generated
				});

			if (transactionError) {
				console.error('❌ Error creating transaction:', transactionError);
				return;
			}

			console.log('✅ Transaction record created successfully');

			// Create task for accountant if accountant exists
			if (receivingRecord?.accountant_user_id) {
				console.log(`📋 Creating task for accountant: ${receivingRecord.accountant_user_id}`);
				
				// Create the task (removed duplicate checking for simplicity)
				const receiverName = receivingRecord.users?.username || 'Unknown';

				const { data: taskData, error: taskError } = await supabaseAdmin
					.from('tasks')
					.insert({
						title: 'New payment made — enter into the ERP, update the ERP reference, and upload the payment receipt',
						description: `Payment Details:
- Bill Number: ${payment.bill_number || 'N/A'}
- Bill Amount: ${(payment.final_bill_amount || payment.bill_amount || 0).toLocaleString()}
- Vendor Name: ${payment.vendor_name || 'N/A'}
- Receiver: ${receiverName}
- Payment Method: ${payment.payment_method || 'N/A'}

Auto-generated by frontend fallback system (${source})`,
						created_by: receivingRecord.user_id,
						created_by_name: `System - ${source}`,
						require_task_finished: true,
						priority: 'medium',
						status: 'active'
					})
					.select()
					.single();

				if (taskError) {
					console.error('❌ Error creating task:', taskError);
				} else if (taskData) {
					console.log('✅ Task created successfully:', taskData.id);
					
					// Create task assignment
					const { data: assignmentData, error: assignmentError } = await supabaseAdmin
						.from('task_assignments')
						.insert({
							task_id: taskData.id,
							assignment_type: 'user',
							assigned_to_user_id: receivingRecord.accountant_user_id,
							assigned_by: receivingRecord.user_id,
							assigned_by_name: `System - ${source}`,
							deadline_date: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString().split('T')[0],
							require_task_finished: true,
							status: 'assigned'
						})
						.select()
						.single();

					if (assignmentError) {
						console.error('❌ Error creating task assignment:', assignmentError);
					} else if (assignmentData) {
						console.log('✅ Task assignment created successfully:', assignmentData.id);
						syncStats.tasksCreated++; // Track task creation
						
						// Create notification
						const { error: notificationError } = await supabaseAdmin
							.from('notifications')
							.insert({
								title: 'Payment Task Assigned (Auto-Generated)',
								message: `You have been assigned a payment processing task for ${payment.vendor_name || 'vendor'}. Bill Amount: ${(payment.final_bill_amount || payment.bill_amount || 0).toLocaleString()} (Generated by ${source})`,
								type: 'task_assigned',
								priority: 'medium',
								target_type: 'specific_users',
								target_users: JSON.stringify([receivingRecord.accountant_user_id]),
								created_by: receivingRecord.user_id,
								created_by_name: `System - ${source}`,
								task_id: taskData.id,
								task_assignment_id: assignmentData.id
							});

						if (notificationError) {
							console.error('❌ Error creating notification:', notificationError);
						} else {
							console.log('✅ Notification created successfully');
						}
					}
				}
			} else {
				console.log('⚠️ No accountant assigned to this receiving record - skipping task creation');
			}

			console.log(`✅ Completed processing for payment ${payment.id} (${source})`);
		} catch (error) {
			console.error(`❌ Error creating missing transaction for payment ${payment.id}:`, error);
		}
	}

	// Sync function removed - no longer needed as payment_status column has been removed
	// Now using only is_paid boolean column
	// loadAllScheduledPaymentsForCards removed - data now loaded in loadScheduledPayments

	// Load task status data for Card 4
	async function loadTaskStatusData() {
		try {
			// Get all task_ids from vendor_payment_schedule table where is_paid=true
			const { data: paymentTasks, error: paymentError } = await supabase
				.from('vendor_payment_schedule')
				.select('task_id')
				.eq('is_paid', true)
				.not('task_id', 'is', null);

			if (paymentError) {
				console.error('Error loading payment tasks:', paymentError);
				return;
			}

			// Get unique task_ids
			const uniqueTaskIds = [...new Set(paymentTasks?.map(p => p.task_id).filter(Boolean) || [])];

			if (uniqueTaskIds.length === 0) {
				taskStatusData = { totalTasks: 0, completedTasks: 0, pendingTasks: 0 };
				return;
			}

			// Batch query task completions in PARALLEL chunks to avoid URL length limit
			const BATCH_SIZE = 200;
			const batches = [];
			
			// Create batch promises
			for (let i = 0; i < uniqueTaskIds.length; i += BATCH_SIZE) {
				const batch = uniqueTaskIds.slice(i, i + BATCH_SIZE);
				batches.push(
					supabase
						.from('task_completions')
						.select('task_id')
						.in('task_id', batch)
				);
			}

			// Execute all batches in parallel
			const results = await Promise.allSettled(batches);
			
			// Collect all successful results
			const allCompletions = [];
			results.forEach((result, index) => {
				if (result.status === 'fulfilled' && result.value.data) {
					allCompletions.push(...result.value.data);
				} else if (result.status === 'rejected') {
					console.error(`Error loading task completions batch ${index}:`, result.reason);
				}
			});

			const completedTaskIds = new Set(allCompletions.map(c => c.task_id));
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

	// Load expense scheduler payments
	async function loadExpenseSchedulerPayments() {
		try {
			// Fetch ALL expense records using pagination
			let allData = [];
			let page = 0;
			const pageSize = 1000;
			let hasMore = true;

			while (hasMore) {
				const { data, error } = await supabaseAdmin
					.from('expense_scheduler')
					.select('*')
					.order('due_date', { ascending: true })
					.range(page * pageSize, (page + 1) * pageSize - 1);

				if (error) {
					console.error('Error loading expense scheduler payments:', error);
					return;
				}

				if (data && data.length > 0) {
					allData = allData.concat(data);
					if (data.length < pageSize) {
						hasMore = false;
					} else {
						page++;
					}
				} else {
					hasMore = false;
				}
			}

			console.log('✅ Loaded expense scheduler payments:', allData.length);
			expenseSchedulerPayments = allData;
		} catch (err) {
			console.error('Error loading expense scheduler payments:', err);
		}
	}

	// Load detailed paid payments data for modal
	async function loadPaidPaymentsDetails() {
		try {
			// Fetch ALL paid payment details using pagination
			let allData = [];
			let page = 0;
			const pageSize = 1000;
			let hasMore = true;

			while (hasMore) {
				const { data, error } = await supabase
					.from('vendor_payment_schedule')
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
					.eq('is_paid', true)
					.order('paid_date', { ascending: false })
					.range(page * pageSize, (page + 1) * pageSize - 1);

				if (error) {
					console.error('Error loading paid payments details:', error);
					return [];
				}

				if (data && data.length > 0) {
					allData = allData.concat(data);
					if (data.length < pageSize) {
						hasMore = false;
					} else {
						page++;
					}
				} else {
					hasMore = false;
				}
			}

			const data = allData;

			// Process the data to set vendor_name and branch info
			if (data && data.length > 0) {
				// Get vendor IDs that need lookup (those with receiving_records but no vendor_name in schedule)
				const vendorIds = [...new Set(data
					.filter(payment => payment.receiving_records?.vendor_id && !payment.vendor_name)
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

						// Add vendor names to payments that need it
						data.forEach(payment => {
							// For payments with receiving_records, use the looked up vendor name
							if (payment.receiving_records?.vendor_id && payment.receiving_records?.branch_id && !payment.vendor_name) {
								const key = `${payment.receiving_records.vendor_id}_${payment.receiving_records.branch_id}`;
								payment.vendor_name = vendorMap[key] || 'Unknown Vendor';
							}
						});
					}
				}

				// Get branch info for manual entries (those without receiving_records)
				const branchIds = [...new Set(data
					.filter(payment => !payment.receiving_records && payment.branch_id)
					.map(payment => payment.branch_id))];

				if (branchIds.length > 0) {
					const { data: branchesData, error: branchesError } = await supabase
						.from('branches')
						.select('id, name_en, name_ar')
						.in('id', branchIds);

					if (!branchesError && branchesData) {
						// Create a map of branch_id to branch info
						const branchMap = {};
						branchesData.forEach(branch => {
							branchMap[branch.id] = {
								name_en: branch.name_en,
								name_ar: branch.name_ar
							};
						});

						// Add branch info to manual entries
						data.forEach(payment => {
							if (!payment.receiving_records && payment.branch_id) {
								// Create a receiving_records-like structure for consistency
								payment.receiving_records = {
									branches: branchMap[payment.branch_id] || { name_en: payment.branch_name || 'N/A', name_ar: null }
								};
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
		openWindow({
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
		openWindow({
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

	// Open overdue payments modal
	async function openOverdueModal() {
		console.log('Opening overdue payments modal...');
		try {
			const overduePayments = await loadOverduePayments();
			console.log('Loaded overdue payments:', overduePayments);
			console.log('Number of overdue payments:', overduePayments.length);
			
			// Open new application window using window manager
			openWindow({
				id: 'overdue-payments-details',
				title: 'Overdue Payments Details',
				component: UnpaidScheduledDetails,
				props: {
					payments: overduePayments
				},
				icon: '🔴',
				size: { width: 1300, height: 700 },
				minSize: { width: 900, height: 500 },
				position: { x: 170, y: 170 }
			});
		} catch (error) {
			console.error('Error in openOverdueModal:', error);
			alert('Error loading overdue payments: ' + error.message);
		}
	}

	// Open task status details in new application window
	async function openTaskStatusModal() {
		console.log('Opening task status modal...');
		
		// Open new application window using window manager
		openWindow({
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

	// Open expenses manager in new application window
	function openExpensesManager() {
		console.log('Opening expenses manager...');
		
		// Open new application window using window manager
		openWindow({
			id: `expenses-manager-${Date.now()}`,
			title: 'Expenses Manager',
			component: ExpensesManager,
			props: {},
			icon: '💸',
			size: { width: 1200, height: 800 },
			minSize: { width: 800, height: 600 },
			position: { x: 220, y: 220 }
		});
	}

	// Load unpaid scheduled payments details
	async function loadUnpaidScheduledPayments() {
		try {
			// Fetch ALL unpaid scheduled payments using pagination
			let allData = [];
			let page = 0;
			const pageSize = 1000;
			let hasMore = true;

			while (hasMore) {
				const { data: scheduleData, error } = await supabase
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
					.order('due_date', { ascending: true })
					.range(page * pageSize, (page + 1) * pageSize - 1);

				if (error) {
					console.error('Error loading unpaid scheduled payments:', error);
					return [];
				}

				if (scheduleData && scheduleData.length > 0) {
					allData = allData.concat(scheduleData);
					if (scheduleData.length < pageSize) {
						hasMore = false;
					} else {
						page++;
					}
				} else {
					hasMore = false;
				}
			}

			const scheduleData = allData;

			// Get unique vendor IDs and branch IDs to fetch priorities
			const vendorKeys = [...new Set(scheduleData.map(p => `${p.vendor_id}-${p.branch_id}`))].filter(k => k !== 'undefined-undefined');
			
			// Fetch vendor priorities
			const vendorPriorities = {};
			if (vendorKeys.length > 0) {
				const { data: vendors } = await supabase
					.from('vendors')
					.select('erp_vendor_id, branch_id, payment_priority');
				
				if (vendors) {
					vendors.forEach(v => {
						vendorPriorities[`${v.erp_vendor_id}-${v.branch_id}`] = v.payment_priority;
					});
				}
			}

			// Attach vendor priority to each payment
			const dataWithPriority = scheduleData.map(payment => ({
				...payment,
				vendor_priority: vendorPriorities[`${payment.vendor_id}-${payment.branch_id}`] || 'Normal'
			}));

			return dataWithPriority || [];
		} catch (err) {
			console.error('Error loading unpaid scheduled payments:', err);
			return [];
		}
	}

	// Load overdue payments (5+ days overdue) from vendor_payment_schedule
	async function loadOverduePayments() {
		try {
			console.log('loadOverduePayments: Starting to load...');
			
			// Use Saudi Arabia timezone for consistent date handling
			const saudiToday = new Date().toLocaleString('en-CA', { 
				timeZone: 'Asia/Riyadh',
				year: 'numeric',
				month: '2-digit',
				day: '2-digit'
			});
			const todaySaudi = new Date(saudiToday + 'T00:00:00');

			// Calculate date 5 days from now in Saudi timezone
			const fiveDaysFromNow = new Date(todaySaudi);
			fiveDaysFromNow.setDate(fiveDaysFromNow.getDate() + 5);
			const fiveDaysFromNowStr = fiveDaysFromNow.toISOString().split('T')[0];

			console.log('loadOverduePayments: Query date cutoff:', fiveDaysFromNowStr);

			// Fetch ALL overdue payments using pagination
			let allData = [];
			let page = 0;
			const pageSize = 1000;
			let hasMore = true;

			while (hasMore) {
				const { data: scheduleData, error } = await supabase
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
					.lte('due_date', fiveDaysFromNowStr)
					.order('due_date', { ascending: true })
					.range(page * pageSize, (page + 1) * pageSize - 1);

				if (error) {
					console.error('Error loading overdue payments:', error);
					return [];
				}

				if (scheduleData && scheduleData.length > 0) {
					allData = allData.concat(scheduleData);
					if (scheduleData.length < pageSize) {
						hasMore = false;
					} else {
						page++;
					}
				} else {
					hasMore = false;
				}
			}

			const scheduleData = allData;

			console.log('loadOverduePayments: Raw scheduleData:', scheduleData);
			console.log('loadOverduePayments: Number of records:', scheduleData?.length || 0);

			// Get unique vendor IDs and branch IDs to fetch priorities
			const vendorKeys = [...new Set(scheduleData.map(p => `${p.vendor_id}-${p.branch_id}`))].filter(k => k !== 'undefined-undefined');
			
			// Fetch vendor priorities
			const vendorPriorities = {};
			if (vendorKeys.length > 0) {
				const { data: vendors } = await supabase
					.from('vendors')
					.select('erp_vendor_id, branch_id, payment_priority');
				
				if (vendors) {
					vendors.forEach(v => {
						vendorPriorities[`${v.erp_vendor_id}-${v.branch_id}`] = v.payment_priority;
					});
				}
			}

			// Attach vendor priority to each payment
			const dataWithPriority = scheduleData.map(payment => ({
				...payment,
				vendor_priority: vendorPriorities[`${payment.vendor_id}-${payment.branch_id}`] || 'Normal'
			}));

			console.log('loadOverduePayments: Final data with priorities:', dataWithPriority);
			console.log('loadOverduePayments: Returning', dataWithPriority?.length || 0, 'payments');

			return dataWithPriority || [];
		} catch (err) {
			console.error('Error loading overdue payments:', err);
			return [];
		}
	}

	// Close paid payments modal
	function viewOriginalBill(url) {
		if (url) {
			window.open(url, '_blank');
		}
	}

	// Load paid payments from vendor_payment_schedule table where is_paid=true
	async function loadPaidPayments() {
		try {
			// Fetch ALL paid records using pagination
			let allData = [];
			let page = 0;
			const pageSize = 1000;
			let hasMore = true;

			while (hasMore) {
				const { data, error: paymentError } = await supabase
					.from('vendor_payment_schedule')
					.select(`
						*,
						receiving_records(
							id,
							vendor_id,
							branches(
								name_en,
								name_ar
							)
						)
					`)
					.eq('is_paid', true)
					.range(page * pageSize, (page + 1) * pageSize - 1);

				if (paymentError) {
					console.error('Error loading paid payments:', paymentError);
					return;
				}

				if (data && data.length > 0) {
					allData = allData.concat(data);
					if (data.length < pageSize) {
						hasMore = false;
					} else {
						page++;
					}
				} else {
					hasMore = false;
				}
			}

			paidPayments = allData;
			console.log('💰 Loaded paid payments data:', {
				count: paidPayments.length,
				sample: paidPayments[0]
			});
		} catch (err) {
			console.error('Error loading paid payments:', err);
		}
	}

	// Check if a payment is already scheduled
	function isPaymentScheduled(receivingRecordId) {
		return scheduledPayments.has(receivingRecordId);
	}

	// Check if a payment is marked as paid
	function isPaymentPaid(receivingRecordId) {
		const scheduleInfo = scheduledPayments.get(receivingRecordId);
		return scheduleInfo?.is_paid === true;
	}

	// Get payment schedule status
	function getPaymentScheduleStatus(receivingRecordId) {
	const scheduleInfo = scheduledPayments.get(receivingRecordId);
	if (!scheduleInfo) return null;
	
	// Return 'paid' if is_paid is true, otherwise 'scheduled'
	return scheduleInfo.is_paid === true ? 'paid' : 'scheduled';
}	// Sort records to show unpaid payments first (by due date), then paid payments - OPTIMIZED
	async function sortRecordsByPaymentStatus() {
		const today = new Date();
		
		// Pre-compute payment status for all records to avoid repeated Map lookups
		const statusCache = new Map();
		receivingRecords.forEach(record => {
			const scheduleInfo = scheduledPayments.get(record.id);
			statusCache.set(record.id, scheduleInfo?.is_paid === true);
		});

		receivingRecords.sort((a, b) => {
			const aPaid = statusCache.get(a.id);
			const bPaid = statusCache.get(b.id);

			// If one is paid and one is unpaid, unpaid comes first
			if (aPaid && !bPaid) return 1;
			if (!aPaid && bPaid) return -1;

			// If both are unpaid, sort by due date (earliest/most urgent first)
			if (!aPaid && !bPaid) {
				// Handle overdue payments first (no due date or past due)
				if (!a.due_date && !b.due_date) return 0;
				if (!a.due_date) return 1; // Records without due date go after those with due dates
				if (!b.due_date) return -1;
				
				const aDueDate = new Date(a.due_date);
				const bDueDate = new Date(b.due_date);
				
				const aOverdue = aDueDate < today;
				const bOverdue = bDueDate < today;
				
				// Overdue payments come first, sorted by how overdue they are
				if (aOverdue && !bOverdue) return -1;
				if (!aOverdue && bOverdue) return 1;
				
				// Both overdue or both not overdue - sort by due date
				return aDueDate - bDueDate;
			}

			// If both are paid, sort by created date (newest first)
			if (aPaid && bPaid) {
				return new Date(b.created_at) - new Date(a.created_at);
			}

			return 0;
		});
	}

	// Load receiving records
	async function loadReceivingRecords() {
		try {
		isLoading = true;
		error = '';

		// Get total count first
		let countQuery = supabase
			.from('receiving_records')
			.select('id', { count: 'exact', head: true });
		
		// Apply branch filtering to count
		if (branchFilterMode === 'branch' && selectedBranch) {
			countQuery = countQuery.eq('branch_id', selectedBranch);
		}
		
		const { count } = await countQuery;
		totalRecords = count || 0;
		totalPages = Math.ceil(totalRecords / pageSize);
		
		// Load receiving records with proper JOIN to vendors and branches tables
		const startRange = (currentPage - 1) * pageSize;
		const endRange = startRange + pageSize - 1;
		
		let query = supabase
			.from('receiving_records')
			.select(`
				*,
				branches(name_en, name_ar),
				vendors!receiving_records_vendor_fkey(erp_vendor_id, vendor_name, bank_name, iban, vat_number)
			`)
			.order('created_at', { ascending: false })
			.range(startRange, endRange);			// Apply branch filtering
			if (branchFilterMode === 'branch' && selectedBranch) {
				query = query.eq('branch_id', selectedBranch);
			}

			const { data: receivingData, error: receivingError } = await query;

			if (receivingError) throw receivingError;

		// No need for manual vendor matching anymore - data comes with proper JOINs
		// Show ALL records (both paid and unpaid) but sort unpaid ones first
		receivingRecords = receivingData || [];

		// Sort records: unpaid first (by due date), then paid records
		await sortRecordsByPaymentStatus();

		filteredRecords = receivingRecords;

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
		currentPage = 1; // Reset to first page
		await loadReceivingRecords();
		calculateStatistics(); // Recalculate stats after filter change
	}
	
	// Pagination handlers
	async function goToPage(page) {
		if (page < 1 || page > totalPages) return;
		currentPage = page;
		await loadReceivingRecords();
	}
	
	async function nextPage() {
		if (currentPage < totalPages) {
			currentPage++;
			await loadReceivingRecords();
		}
	}
	
	async function previousPage() {
		if (currentPage > 1) {
			currentPage--;
			await loadReceivingRecords();
		}
	}
	
	async function changePageSize(newSize) {
		pageSize = newSize;
		currentPage = 1; // Reset to first page
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

	// Sort filtered records by payment status and due date - OPTIMIZED
	function sortFilteredRecords() {
		const today = new Date();
		
		// Pre-compute payment status for filtered records
		const statusCache = new Map();
		filteredRecords.forEach(record => {
			const scheduleInfo = scheduledPayments.get(record.id);
			statusCache.set(record.id, scheduleInfo?.is_paid === true);
		});

		filteredRecords.sort((a, b) => {
			const aPaid = statusCache.get(a.id);
			const bPaid = statusCache.get(b.id);

			// If one is paid and one is unpaid, unpaid comes first
			if (aPaid && !bPaid) return 1;
			if (!aPaid && bPaid) return -1;

			// If both are unpaid, sort by due date (earliest/most urgent first)
			if (!aPaid && !bPaid) {
				if (!a.due_date && !b.due_date) return 0;
				if (!a.due_date) return 1; // Records without due date go after those with due dates
				if (!b.due_date) return -1;
				
				const aDueDate = new Date(a.due_date);
				const bDueDate = new Date(b.due_date);
				
				const aOverdue = aDueDate < today;
				const bOverdue = bDueDate < today;
				
				// Overdue payments come first, sorted by how overdue they are
				if (aOverdue && !bOverdue) return -1;
				if (!aOverdue && bOverdue) return 1;
				
				// Both overdue or both not overdue - sort by due date
				return aDueDate - bDueDate;
			}

			// If both are paid, sort by created date (newest first)
			if (aPaid && bPaid) {
				return new Date(b.created_at) - new Date(a.created_at);
			}

			return 0;
		});
	}

	// Calculate statistics from the loaded data - OPTIMIZED FOR SPEED
	function calculateStatistics() {
		const today = new Date();
		const todayTime = today.getTime(); // Cache timestamp for faster comparisons

		// Get unique vendors from scheduled payments
		const uniqueVendors = new Set();
		for (const record of allScheduledPaymentsData) {
			if (record.vendor_id) uniqueVendors.add(record.vendor_id);
		}

		// Initialize counters
		let totalThisMonth = 0;
		let pending = 0;
		let completed = 0;
		let processing = 0;
		let overdue = 0;
		
		// Scheduled payments calculations (from vendor_payment_schedule table)
		let scheduledAmount = 0;
		let scheduledByPaymentMethod = {};
		let totalScheduledBills = 0;
		let unpaidScheduledAmount = 0;
		let unpaidScheduledByPaymentMethod = {};
		let unpaidScheduledBills = 0;
		let overdueAmount = 0;
		let overdueByPaymentMethod = {};
		let overdueBills = 0;

		// Initialize all payment categories with 0
		paymentCategories.forEach(category => {
			scheduledByPaymentMethod[category] = 0;
			unpaidScheduledByPaymentMethod[category] = 0;
			overdueByPaymentMethod[category] = 0;
		});

		// Calculate from vendor_payment_schedule table - optimized loop
		for (const scheduleRecord of allScheduledPaymentsData) {
			// Count total scheduled bills (both paid and unpaid)
			totalScheduledBills++;
			
			// Get amount from vendor_payment_schedule fields
			const amount = scheduleRecord.final_bill_amount || scheduleRecord.bill_amount || 0;
			scheduledAmount += amount;

			// Count by payment status
			if (scheduleRecord.is_paid === true) {
				completed++;
				processing++;
			} else {
				// Count unpaid scheduled payments
				unpaidScheduledBills++;
				unpaidScheduledAmount += amount;
				processing++;

				// Check if overdue for unpaid scheduled payments
				if (scheduleRecord.due_date) {
					const dueDate = new Date(scheduleRecord.due_date + 'T00:00:00').getTime();
					const daysDiff = Math.floor((dueDate - todayTime) / 86400000);
					
					// Count bills that are already due or will be due in next 5 days
					if (daysDiff <= 5) {
						overdueBills++;
						overdueAmount += amount;
						
						// Add to overdue by payment method
						const rawPaymentMethod = scheduleRecord.payment_method || 'Cash on Delivery';
						let overduePaymentMethod = 'Cash on Delivery';
						
						if (rawPaymentMethod.toLowerCase().includes('cash on delivery') || rawPaymentMethod.toLowerCase().includes('cod')) {
							overduePaymentMethod = 'Cash on Delivery';
						} else if (rawPaymentMethod.toLowerCase().includes('bank on delivery') || rawPaymentMethod.toLowerCase().includes('bod')) {
							overduePaymentMethod = 'Bank on Delivery';
						} else if (rawPaymentMethod.toLowerCase().includes('cash credit')) {
							overduePaymentMethod = 'Cash Credit';
						} else if (rawPaymentMethod.toLowerCase().includes('bank credit')) {
							overduePaymentMethod = 'Bank Credit';
						}
						
						overdueByPaymentMethod[overduePaymentMethod] += amount;
					}
				}
			}

			// Normalize payment method - optimized
			const rawPaymentMethod = scheduleRecord.payment_method || 'Cash on Delivery';
			const lowerMethod = rawPaymentMethod.toLowerCase();
			let paymentMethod = 'Cash on Delivery';
			
			if (lowerMethod.includes('bank credit')) {
				paymentMethod = 'Bank Credit';
			} else if (lowerMethod.includes('cash credit')) {
				paymentMethod = 'Cash Credit';
			} else if (lowerMethod.includes('bank') || lowerMethod.includes('bod')) {
				paymentMethod = 'Bank on Delivery';
			}

			// Add to scheduled totals
			scheduledByPaymentMethod[paymentMethod] += amount;
			
			// Add to unpaid totals if not paid
			if (scheduleRecord.is_paid !== true) {
				unpaidScheduledByPaymentMethod[paymentMethod] += amount;
			}
		}

		// Count pending payments from receiving_records that are NOT in vendor_payment_schedule
		for (const record of receivingRecords) {
			if (!scheduledPayments.has(record.id)) {
				pending++;
			}
		}

		// Calculate paid amounts (from vendor_payment_schedule where is_paid=true)
		let paidAmount = 0;
		let paidByPaymentMethod = {};
		let paidTransactionsCount = 0;

		// Initialize all payment categories with 0 for paid payments
		paymentCategories.forEach(category => {
			paidByPaymentMethod[category] = 0;
		});

		// Calculate from paid payments (vendor_payment_schedule where is_paid=true)
		for (const payment of paidPayments) {
			paidTransactionsCount++;
			
			// Get amount from vendor_payment_schedule
			const amount = payment.final_bill_amount || payment.bill_amount || 0;
			paidAmount += amount;

			// Get payment method from vendor_payment_schedule - optimized
			const lowerMethod = (payment.payment_method || 'Cash on Delivery').toLowerCase();
			let standardPaymentMethod = 'Cash on Delivery';
			
			if (lowerMethod.includes('bank credit')) {
				standardPaymentMethod = 'Bank Credit';
			} else if (lowerMethod.includes('cash credit')) {
				standardPaymentMethod = 'Cash Credit';
			} else if (lowerMethod.includes('bank') || lowerMethod.includes('bod')) {
				standardPaymentMethod = 'Bank on Delivery';
			}

			paidByPaymentMethod[standardPaymentMethod] += amount;
		}

		// Calculate expense scheduler totals - SIMPLIFIED (NO DATE CALCULATIONS)
		let expenseScheduledAmount = 0;
		let expensePaidAmount = 0;
		let expenseUnpaidAmount = 0;
		let expenseOverdueAmount = 0;
		let expenseScheduledCount = 0;
		let expensePaidCount = 0;
		let expenseUnpaidCount = 0;
		let expenseOverdueCount = 0;

		for (const expense of expenseSchedulerPayments) {
			const amount = expense.amount || 0;
			expenseScheduledCount++;
			expenseScheduledAmount += amount;

			if (expense.is_paid) {
				expensePaidCount++;
				expensePaidAmount += amount;
			} else {
				expenseUnpaidCount++;
				expenseUnpaidAmount += amount;

				// Check if expense is overdue
				if (expense.due_date) {
					const dueDate = new Date(expense.due_date + 'T00:00:00');
					const daysDiff = Math.floor((dueDate - today) / (1000 * 60 * 60 * 24));
					
					// Count expenses that are already due or will be due in next 5 days
					if (daysDiff <= 5) {
						expenseOverdueAmount += amount;
						expenseOverdueCount++;
					}
				}
			}
		}

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
			overdueAmount: overdueAmount + expenseOverdueAmount,
			overdueByPaymentMethod: overdueByPaymentMethod,
			overdueBills: overdueBills,
			paidAmount: paidAmount,
			paidByPaymentMethod: paidByPaymentMethod,
			paidTransactionsCount: paidTransactionsCount,
			taskStatus: taskStatusData || { totalTasks: 0, completedTasks: 0, pendingTasks: 0 },
			expenseScheduledAmount: expenseScheduledAmount,
			expensePaidAmount: expensePaidAmount,
			expenseUnpaidAmount: expenseUnpaidAmount,
			expenseOverdueAmount: expenseOverdueAmount,
			expenseOverdueCount: expenseOverdueCount,
			expenseScheduledCount: expenseScheduledCount,
			expensePaidCount: expensePaidCount,
			expenseUnpaidCount: expenseUnpaidCount
		};

		// Optimized logging
		console.log('📊 Payment Manager Stats (Optimized):', {
			vendorScheduled: totalScheduledBills,
			vendorOverdue: overdueBills,
			expenseScheduled: expenseScheduledCount,
			expenseOverdue: expenseOverdueCount,
			vendorPaid: paidTransactionsCount,
			expensePaid: expensePaidCount,
			vendorUnpaid: unpaidScheduledBills,
			expenseUnpaid: expenseUnpaidCount
		});
	}

	// Format currency
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
		
		openWindow({
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
			.select('id, is_paid')
			.eq('receiving_record_id', schedulingRecord.id)
			.single();		if (checkError && checkError.code !== 'PGRST116') { // PGRST116 = no rows found
			throw checkError;
		}

		if (existingSchedule) {
			const statusText = existingSchedule.is_paid ? 'Paid' : 'Scheduled';
			alert(`⚠️ Payment Already ${statusText}!\n\nThis payment is already in the schedule.\n\nPlease check the payment schedule for updates.`);
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
				is_paid: false,
				scheduled_date: new Date().toISOString(),
				notes: `Scheduled from Payment Manager on ${new Date().toLocaleDateString()}`
			})
			.select();

		if (error) throw error;		// Immediately update the local scheduledPayments Map to show green tick without refresh
		scheduledPayments.set(schedulingRecord.id, 'scheduled');
		// Force reactivity by reassigning the Map
		scheduledPayments = scheduledPayments;
		
		alert(`✅ Payment Successfully Scheduled!\n\nBill #${schedulingRecord.bill_number}\nVendor: ${schedulingRecord.vendors?.vendor_name || 'N/A'}\nAmount: ${formatCurrency(schedulingRecord.bill_amount)}\nDue: ${formatDate(schedulingRecord.due_date)}\n\nPayment has been added to the schedule.`);
		
		// Refresh scheduled payments to update button states (for consistency)
		await loadScheduledPayments();
		
		// Re-sort records after scheduling
		await sortRecordsByPaymentStatus();
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
			const { error } = await supabaseAdmin
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
	// Refresh data function - optimized for performance
	async function refreshData() {
		isLoading = true;
		// Load in parallel for better performance
		await Promise.all([
			loadScheduledPayments(), // Single load for all scheduled data
			loadPaidPayments(),
			loadExpenseSchedulerPayments(),
			loadTaskStatusData()
		]);
		await loadReceivingRecords();
		
		// COD auto-processing removed - manual payments only
		console.log('ℹ️ Data refreshed - COD auto-processing disabled');
		
		// Single calculation after all data is loaded
		calculateStatistics();
		isLoading = false;
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
						<p class="total-amount">{stats.totalScheduledBills + (stats.expenseScheduledCount || 0)} Total</p>
						<div class="card-subsection">
							<div class="subsection-header">Vendor Payments</div>
							<p class="count-label"><strong>{stats.totalScheduledBills}</strong> bills</p>
						</div>
						{#if stats.expenseScheduledCount > 0}
							<div class="card-subsection expense-section">
								<div class="subsection-header" style="color: #dc2626;">Expenses</div>
								<p class="count-label" style="color: #dc2626;"><strong>{stats.expenseScheduledCount}</strong> expenses</p>
							</div>
						{/if}
						<p class="click-hint">Click to view details</p>
					</div>
				</div>
				
				<div class="status-card paid-card clickable" on:click={openPaidPaymentsModal}>
					<div class="card-icon">💰</div>
					<div class="card-content">
						<h3>Paid Payments</h3>
						<p class="total-amount">{stats.paidTransactionsCount + (stats.expensePaidCount || 0)} Total</p>
						<div class="card-subsection">
							<div class="subsection-header">Vendor Payments</div>
							<p class="count-label"><strong>{stats.paidTransactionsCount}</strong> transactions</p>
						</div>
						{#if stats.expensePaidCount > 0}
							<div class="card-subsection expense-section">
								<div class="subsection-header" style="color: #059669;">Expenses Paid</div>
								<p class="count-label" style="color: #059669;"><strong>{stats.expensePaidCount}</strong> expenses</p>
							</div>
						{/if}
						<p class="click-hint">Click to view details</p>
					</div>
				</div>
				
				<div class="status-card unpaid-scheduled-card clickable" on:click={openUnpaidScheduledModal}>
					<div class="card-icon">⏳</div>
					<div class="card-content">
						<h3>Unpaid Scheduled</h3>
						<p class="total-amount">{stats.unpaidScheduledBills + (stats.expenseUnpaidCount || 0)} Total</p>
						<div class="card-subsection">
							<div class="subsection-header">Vendor Payments</div>
							<p class="count-label"><strong>{stats.unpaidScheduledBills}</strong> bills</p>
						</div>
						{#if stats.expenseUnpaidCount > 0}
							<div class="card-subsection expense-section">
								<div class="subsection-header" style="color: #dc2626;">Expenses Unpaid</div>
								<p class="count-label" style="color: #dc2626;"><strong>{stats.expenseUnpaidCount}</strong> expenses</p>
							</div>
						{/if}
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
				
				<div class="status-card expenses-card clickable" on:click={openExpensesManager}>
					<div class="card-icon">💸</div>
					<div class="card-content">
						<h3>Expenses Manager</h3>
						<p class="card-description">Track and manage all business expenses</p>
						<p class="click-hint">Click to open</p>
					</div>
				</div>
				
				<div class="status-card overdue-card clickable" on:click={openOverdueModal}>
					<div class="card-icon">🔴</div>
					<div class="card-content">
						<h3>Overdue</h3>
						<p class="total-amount">{stats.overdueBills + (stats.expenseOverdueCount || 0)} Total</p>
						<div class="card-subsection">
							<div class="subsection-header">Vendor Payments</div>
							<p class="count-label"><strong>{stats.overdueBills}</strong> bills</p>
						</div>
						{#if stats.expenseOverdueCount > 0}
							<div class="card-subsection expense-section">
								<div class="subsection-header" style="color: #dc2626;">Expenses Overdue</div>
								<p class="count-label" style="color: #dc2626;"><strong>{stats.expenseOverdueCount}</strong> expenses</p>
							</div>
						{/if}
						<p class="click-hint">Click to view details</p>
					</div>
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
					<div class="info-left">
						<span>Page {currentPage} of {totalPages} ({totalRecords} total records)</span>
						<select bind:value={pageSize} on:change={() => changePageSize(pageSize)} class="page-size-select">
							<option value={50}>50 per page</option>
							<option value={100}>100 per page</option>
							<option value={200}>200 per page</option>
							<option value={500}>500 per page</option>
						</select>
					</div>
					<div class="payment-summary">
						<span class="unpaid-count">📋 {filteredRecords.filter(r => !isPaymentPaid(r.id)).length} Unpaid</span>
						<span class="paid-count">✅ {filteredRecords.filter(r => isPaymentPaid(r.id)).length} Paid</span>
					</div>
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
							<div class="header-cell">Amounts</div>
							<div class="header-cell">ERP Invoice Ref</div>
							<div class="header-cell">Edit</div>
							<div class="header-cell">Schedule</div>
						</div>
						
						{#each filteredRecords as record}
							<div class="table-row {isPaymentPaid(record.id) ? 'paid-record' : 'unpaid-record'}">
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
										{#if isPaymentPaid(record.id)}
											<div class="payment-status-badge paid">✅ PAID</div>
										{:else}
											<div class="payment-status-badge unpaid">⏳ UNPAID</div>
										{/if}
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
									<div class="amounts">
										<div>Bill: {parseFloat(record.bill_amount || 0).toFixed(2)}</div>
										<div>Final: {parseFloat(record.final_bill_amount || record.bill_amount || 0).toFixed(2)}</div>
									</div>
								</div>
								
							<div class="cell">
								<div class="erp-reference">
									{#if record.erp_purchase_invoice_reference}
										<span>{record.erp_purchase_invoice_reference}</span>
									{:else}
										<span class="erp-ref-empty">Not Entered</span>
									{/if}
								</div>
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
				
				<!-- Pagination Controls -->
				{#if totalPages > 1}
					<div class="pagination-controls">
						<button 
							on:click={previousPage} 
							disabled={currentPage === 1}
							class="pagination-btn"
						>
							← Previous
						</button>
						
						<div class="pagination-pages">
							{#if currentPage > 2}
								<button class="pagination-btn" on:click={() => goToPage(1)}>1</button>
								{#if currentPage > 3}
									<span class="pagination-ellipsis">...</span>
								{/if}
							{/if}
							
							{#if currentPage > 1}
								<button class="pagination-btn" on:click={() => goToPage(currentPage - 1)}>{currentPage - 1}</button>
							{/if}
							
							<button class="pagination-btn active">{currentPage}</button>
							
							{#if currentPage < totalPages}
								<button class="pagination-btn" on:click={() => goToPage(currentPage + 1)}>{currentPage + 1}</button>
							{/if}
							
							{#if currentPage < totalPages - 1}
								{#if currentPage < totalPages - 2}
									<span class="pagination-ellipsis">...</span>
								{/if}
								<button class="pagination-btn" on:click={() => goToPage(totalPages)}>{totalPages}</button>
							{/if}
						</div>
						
						<button 
							on:click={nextPage} 
							disabled={currentPage === totalPages}
							class="pagination-btn"
						>
							Next →
						</button>
					</div>
				{/if}
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

	/* Sync Status Styles - REMOVED (COD auto-processing disabled) */

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

	.expenses-card {
		display: flex;
		align-items: flex-start;
		gap: 16px;
		padding: 24px;
		text-align: left;
		min-height: 200px;
	}

	.expenses-card .card-icon {
		background: #10b981;
		color: white;
	}

	.expenses-card:hover {
		border-color: #10b981;
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.15);
	}

	.overdue-card {
		display: flex;
		align-items: flex-start;
		gap: 16px;
		padding: 24px;
		text-align: left;
		min-height: 200px;
		border-color: #ef4444;
	}

	.overdue-card .card-icon {
		background: #ef4444;
		color: white;
		font-size: 28px;
	}

	.overdue-card:hover {
		border-color: #dc2626;
		box-shadow: 0 4px 12px rgba(239, 68, 68, 0.2);
	}

	.overdue-card .total-amount {
		color: #dc2626;
	}

	.card-description {
		font-size: 14px;
		color: #6b7280;
		margin: 12px 0;
		line-height: 1.5;
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

	.card-subsection {
		margin-bottom: 16px;
		padding-bottom: 12px;
		border-bottom: 1px solid #e5e7eb;
	}

	.card-subsection.expense-section {
		border-bottom: none;
		padding-bottom: 0;
	}

	.subsection-header {
		font-size: 13px;
		font-weight: 600;
		color: #374151;
		margin-bottom: 8px;
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
		display: flex;
		justify-content: space-between;
		align-items: center;
	}
	
	.info-left {
		display: flex;
		align-items: center;
		gap: 1rem;
	}
	
	.page-size-select {
		padding: 0.375rem 0.75rem;
		border: 1px solid #e2e8f0;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		background: white;
		cursor: pointer;
	}
	
	.payment-summary {
		display: flex;
		gap: 1rem;
		align-items: center;
	}
	
	.unpaid-count, .paid-count {
		padding: 0.25rem 0.75rem;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 500;
	}
	
	.unpaid-count {
		background: #fef3c7;
		color: #92400e;
	}
	
	.paid-count {
		background: #d1fae5;
		color: #065f46;
	}
	
	/* Pagination Controls */
	.pagination-controls {
		display: flex;
		justify-content: center;
		align-items: center;
		gap: 0.5rem;
		padding: 1rem;
		background: #f8fafc;
		border-top: 1px solid #e2e8f0;
	}
	
	.pagination-btn {
		padding: 0.5rem 0.75rem;
		border: 1px solid #e2e8f0;
		border-radius: 0.375rem;
		background: white;
		color: #374151;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
		min-width: 40px;
	}
	
	.pagination-btn:hover:not(:disabled):not(.active) {
		background: #f3f4f6;
		border-color: #d1d5db;
	}
	
	.pagination-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
	
	.pagination-btn.active {
		background: #3b82f6;
		color: white;
		border-color: #3b82f6;
		font-weight: 600;
	}
	
	.pagination-pages {
		display: flex;
		gap: 0.25rem;
		align-items: center;
	}
	
	.pagination-ellipsis {
		padding: 0 0.5rem;
		color: #6b7280;
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

	/* Payment Status Styling */
	.paid-record {
		background: #f0fdf4;
		border-left: 4px solid #10b981;
		opacity: 0.8;
	}

	.unpaid-record {
		background: #fefefe;
		border-left: 4px solid #f59e0b;
	}

	.unpaid-record.overdue {
		background: #fef2f2;
		border-left: 4px solid #ef4444;
	}

	.payment-status-badge {
		margin-top: 4px;
		padding: 2px 6px;
		border-radius: 12px;
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		display: inline-block;
		width: fit-content;
	}

	.payment-status-badge.paid {
		background: #dcfce7;
		color: #166534;
		border: 1px solid #bbf7d0;
	}

	.payment-status-badge.unpaid {
		background: #fef3c7;
		color: #92400e;
		border: 1px solid #fde68a;
	}

	.payment-summary {
		display: flex;
		gap: 16px;
		margin-top: 8px;
		align-items: center;
	}

	.unpaid-count {
		background: #fef3c7;
		color: #92400e;
		padding: 4px 8px;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 600;
		border: 1px solid #fde68a;
	}

	.paid-count {
		background: #dcfce7;
		color: #166534;
		padding: 4px 8px;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 600;
		border: 1px solid #bbf7d0;
	}


</style>