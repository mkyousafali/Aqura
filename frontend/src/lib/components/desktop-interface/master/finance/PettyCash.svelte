<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	interface Branch {
		id: number;
		name_en: string;
		name_ar: string;
		location_en: string;
		is_active: boolean;
	}

	interface BoxOperation {
		id: string;
		box_number: number;
		total_after: number;
		start_time: string;
		user_id: string;
		status: string;
		closing_details: {
			cash_sales?: number;
			bank_total?: number;
			total_sales?: number;
			closing_total?: number;
			bank_mada?: number;
			bank_visa?: number;
			bank_mastercard?: number;
			bank_google_pay?: number;
			bank_other?: number;
		} | null;
		hr_employee_master?: {
			name_en: string;
			name_ar: string;
		};
	}

	interface PettyCashTransaction {
		id: string;
		transaction_type: 'vendor' | 'expenses' | 'user';
		entity_name: string;
		amount: number;
		remarks: string;
		created_at: string;
		apply_denomination: boolean;
		denomination_details?: Record<string, number>;
	}

	let branches: Branch[] = [];
	let selectedBranchId: number | null = null;
	let defaultBranchId: number | null = null;
	let loading = true;
	let saving = false;
	let successMessage = '';
	let errorMessage = '';
	let availableBoxes: BoxOperation[] = [];
	let loadingBoxes = false;
	let employeeMap: Map<string, string> = new Map();
	let selectedBox: BoxOperation | null = null;
	let pettyCashBalance = 0;
	let loadingPettyCash = false;
	let pettyCashTransactions: PettyCashTransaction[] = [];

	// Payment modal state
	let showPaymentModal = false;
	let paymentModalType: 'vendor' | 'expenses' | 'user' | null = null;
	let paymentAmount = 0;
	let paymentRemarks = 'Paid from petty cash';
	let selectedEntity: any = null;
	let applyDenomination = true;
	let paymentDenominationCounts: Record<string, number> = {};
	let pettyCashCounts: Record<string, number> = {};
	let vendors: any[] = [];
	let expenses: any[] = [];
	let users: any[] = [];
	let vendorSearch = '';
	let expenseSearch = '';
	let userSearch = '';
	let paymentSearch = '';
	let savingPayment = false;
	let paymentMessage = '';
	let paymentError = '';
	let branchesChannel: any;
	let boxesChannel: any;
	let pettyCashChannel: any;
	let transferQuantities: Record<string, number> = {};
	let savingTransfer = false;
	let transferMessage = '';
	let transferError = '';
	let exceedMessage = '';

	onMount(async () => {
		try {
			// Fetch all active branches
			const { data: branchesData, error: branchesError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar, is_active')
				.eq('is_active', true)
				.order('name_en');

			if (branchesError) throw branchesError;
			branches = branchesData || [];

			// Set up real-time listener for branches
			branchesChannel = supabase
				.channel('branches-changes')
				.on(
					'postgres_changes',
					{ event: '*', schema: 'public', table: 'branches' },
					async (payload) => {
						console.log('Branch update:', payload);
						// Refresh branches list
						const { data: updatedBranches } = await supabase
							.from('branches')
							.select('id, name_en, name_ar, location_en, location_ar, is_active')
							.eq('is_active', true)
							.order('name_en');
						if (updatedBranches) {
							branches = updatedBranches;
						}
					}
				)
				.subscribe();

			// Fetch user's default branch preference
			if ($currentUser?.id) {
				const { data: prefData, error: prefError } = await supabase
					.from('denomination_user_preferences')
					.select('default_branch_id')
					.eq('user_id', $currentUser.id)
					.single();

				if (prefData) {
					defaultBranchId = prefData.default_branch_id;
					selectedBranchId = prefData.default_branch_id;
					if (selectedBranchId) {
						await loadAvailableBoxes();
						setupBoxesRealtime();
						await loadPettyCashBalance();
						setupPettyCashRealtime();
					}
				}
			}
		} catch (err) {
			console.error('Error loading branch data:', err);
			errorMessage = 'Failed to load branches';
		} finally {
			loading = false;
		}

		return () => {
			// Cleanup subscriptions on unmount
			if (branchesChannel) {
				supabase.removeChannel(branchesChannel);
			}
			if (boxesChannel) {
				supabase.removeChannel(boxesChannel);
			}
			if (pettyCashChannel) {
				supabase.removeChannel(pettyCashChannel);
			}
		};
	});

	$: if (selectedBranchId) {
		loadAvailableBoxes();
		loadPettyCashBalance();
		setupBoxesRealtime();
		setupPettyCashRealtime();
	}

	// Validate transfer quantities
	$: {
		exceedMessage = '';
		if (selectedBox?.closing_details?.closing_counts) {
			for (const [key, qty] of Object.entries(transferQuantities)) {
				const availableCount = selectedBox.closing_details.closing_counts[key] || 0;
				if (qty > availableCount) {
					exceedMessage = `⚠️ Cannot transfer more than available. ${getDenominationLabel(key)}: only ${availableCount} available, you entered ${qty}`;
					break;
				}
			}
		}
	}

	function setupBoxesRealtime() {
		// Clean up old subscription
		if (boxesChannel) {
			supabase.removeChannel(boxesChannel);
		}

		if (!selectedBranchId) return;

		// Set up real-time listener for box operations
		boxesChannel = supabase
			.channel(`boxes-${selectedBranchId}`)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'box_operations',
					filter: `branch_id=eq.${selectedBranchId}`
				},
				async (payload) => {
					console.log('Box operation update:', payload);
					// Refresh available boxes
					await loadAvailableBoxes();
				}
			)
			.subscribe();
	}

	function setupPettyCashRealtime() {
		// Clean up old subscription
		if (pettyCashChannel) {
			supabase.removeChannel(pettyCashChannel);
		}

		if (!selectedBranchId) return;

		console.log('🔄 Setting up petty cash real-time subscription for branch:', selectedBranchId);

		// Set up real-time listener for petty cash records and transactions
		pettyCashChannel = supabase
			.channel(`petty-cash-${selectedBranchId}-${Date.now()}`) // Add timestamp to ensure unique channel
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'denomination_records',
					filter: `branch_id=eq.${selectedBranchId}`
				},
				async (payload) => {
					console.log('📡 Petty cash denomination_records event:', payload.eventType, payload);
					// Reload balance whenever any denomination_records change happens for petty_cash_box
					if (payload.new?.record_type === 'petty_cash_box' || payload.old?.record_type === 'petty_cash_box') {
						console.log('🔄 Reloading petty cash balance due to real-time update...');
						await loadPettyCashBalance();
					}
				}
			)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'denomination_transactions',
					filter: `branch_id=eq.${selectedBranchId}`
				},
				async (payload) => {
					console.log('📡 Denomination transaction event:', payload.eventType, payload);
					// Reload transactions list and balance
					await loadPettyCashTransactions();
					await loadPettyCashBalance();
				}
			)
			.subscribe((status) => {
				console.log('📡 Petty cash channel subscription status:', status);
				if (status === 'SUBSCRIBED') {
					console.log('✅ Successfully subscribed to petty cash real-time updates');
				} else if (status === 'CHANNEL_ERROR') {
					console.error('❌ Error subscribing to petty cash channel');
				}
			});
	}

	$: if (selectedBranchId) {
		loadAvailableBoxes();
		loadPettyCashBalance();
		setupBoxesRealtime();
		setupPettyCashRealtime();
	}

	async function loadPettyCashBalance() {
		if (!selectedBranchId) {
			console.log('⚠️ loadPettyCashBalance: No branch selected');
			return;
		}
		
		console.log('🔄 Loading petty cash balance for branch:', selectedBranchId);
		
		try {
			loadingPettyCash = true;
			const { data: pettyCash, error } = await supabase
				.from('denomination_records')
				.select('grand_total, counts')
				.eq('branch_id', selectedBranchId)
				.eq('record_type', 'petty_cash_box')
				.order('created_at', { ascending: false })
				.limit(1)
				.single();

			console.log('📊 Petty cash query result:', { data: pettyCash, error });

			if (error && error.code !== 'PGRST116') {
				console.error('❌ Error loading petty cash balance:', error);
				pettyCashBalance = 0;
				pettyCashCounts = {};
			} else {
				const newBalance = pettyCash?.grand_total || 0;
				const newCounts = pettyCash?.counts || {};
				
				console.log('✅ Updating petty cash balance from', pettyCashBalance, 'to', newBalance);
				pettyCashBalance = newBalance;
				pettyCashCounts = newCounts;
			}
			
			// Also load transactions
			await loadPettyCashTransactions();
		} catch (err) {
			console.error('❌ Exception loading petty cash balance:', err);
			pettyCashBalance = 0;
		} finally {
			loadingPettyCash = false;
		}
	}

	async function setDefaultBranch() {
		if (!selectedBranchId || !$currentUser?.id) {
			errorMessage = 'Please select a branch first';
			return;
		}

		saving = true;
		successMessage = '';
		errorMessage = '';

		try {
			// Check if preference record exists
			const { data: existingPrefs } = await supabase
				.from('denomination_user_preferences')
				.select('id')
				.eq('user_id', $currentUser.id)
				.single();

			if (existingPrefs) {
				// Update existing preference
				const { error } = await supabase
					.from('denomination_user_preferences')
					.update({ default_branch_id: selectedBranchId, updated_at: new Date().toISOString() })
					.eq('user_id', $currentUser.id);

				if (error) throw error;
			} else {
				// Create new preference
				const { error } = await supabase
					.from('denomination_user_preferences')
					.insert({
						user_id: $currentUser.id,
						default_branch_id: selectedBranchId
					});

				if (error) throw error;
			}

			defaultBranchId = selectedBranchId;
			successMessage = 'Default branch set successfully!';
			await loadAvailableBoxes();
			setTimeout(() => (successMessage = ''), 3000);
		} catch (err) {
			console.error('Error setting default branch:', err);
			errorMessage = 'Failed to set default branch';
		} finally {
			saving = false;
		}
	}

	async function loadAvailableBoxes() {
		if (!selectedBranchId) {
			availableBoxes = [];
			return;
		}

		loadingBoxes = true;
		try {
			// First, fetch all employees to build a mapping
			const { data: employees, error: empError } = await supabase
				.from('hr_employee_master')
				.select('user_id, name_en, name_ar');

			if (empError) throw empError;

			// Build employee map
			employeeMap = new Map();
			if (employees) {
				employees.forEach((emp) => {
					employeeMap.set(emp.user_id, emp.name_en);
				});
			}

			// Then fetch box operations
			const { data, error } = await supabase
				.from('box_operations')
				.select('id, box_number, total_after, start_time, user_id, status, closing_details')
				.eq('branch_id', selectedBranchId)
				.eq('status', 'pending_close')
				.order('box_number', { ascending: true });

			if (error) throw error;
			
			// Fetch all petty cash transfers to calculate what was transferred from each box
			const { data: pettyCashTransfers, error: pcError } = await supabase
				.from('denomination_records')
				.select('petty_cash_operation')
				.eq('branch_id', selectedBranchId)
				.eq('record_type', 'petty_cash_box');

			if (pcError) throw pcError;

			// Calculate total transferred from each box (per denomination)
			const transferredFromBox: Record<string, number> = {};
			const transferredDenominations: Record<string, Record<string, number>> = {};
			
			if (pettyCashTransfers) {
				pettyCashTransfers.forEach((record) => {
					// Handle both single operation and array of operations
					const operations = Array.isArray(record.petty_cash_operation) 
						? record.petty_cash_operation 
						: (record.petty_cash_operation ? [record.petty_cash_operation] : []);
					
					operations.forEach((operation: any) => {
						if (operation?.transferred_from_box_id && 
							operation?.transferred_from_branch_id === selectedBranchId) {
							const boxId = operation.transferred_from_box_id;
							const denom = operation.transferred_denominations || {};
							
							// Initialize if not exists
							if (!transferredDenominations[boxId]) {
								transferredDenominations[boxId] = {};
							}
							
							let amount = 0;
							Object.entries(denom).forEach(([key, qty]: [string, any]) => {
								// Track per-denomination transfers
								transferredDenominations[boxId][key] = (transferredDenominations[boxId][key] || 0) + qty;
								// Calculate total amount
								if (key !== 'coins') {
									amount += parseFloat(key.replace('d', '')) * qty;
								}
							});
							transferredFromBox[boxId] = (transferredFromBox[boxId] || 0) + amount;
						}
					});
				});
			}

			// Store the transferred amounts for display calculation
			availableBoxes = data || [];
			availableBoxes = availableBoxes.map(box => ({
				...box,
				_transferredAmount: transferredFromBox[box.id] || 0,
				_transferredDenominations: transferredDenominations[box.id] || {}
			}));
		} catch (err) {
			console.error('Error loading available boxes:', err);
		} finally {
			loadingBoxes = false;
		}
	}

	function getBranchDisplay(branchId: number | null) {
		if (!branchId) return 'No default branch set';
		const branch = branches.find(b => b.id === branchId);
		return branch ? `${branch.name_en} - ${branch.location_en}` : 'Unknown';
	}

	function formatCurrency(value: number) {
		return new Intl.NumberFormat('en-US', {
			style: 'currency',
			currency: 'SAR'
		}).format(value);
	}

	function formatDate(dateString: string) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function getDenominationLabel(key: string): string {
		const labels: Record<string, string> = {
			d500: '500 SR',
			d200: '200 SR',
			d100: '100 SR',
			d50: '50 SR',
			d20: '20 SR',
			d10: '10 SR',
			d5: '5 SR',
			d2: '2 SR',
			d1: '1 SR',
			d025: '0.25 SR',
			d05: '0.50 SR',
			coins: 'Coins'
		};
		return labels[key] || key;
	}

	function openPaymentModal(type: 'vendor' | 'expenses' | 'user') {
		paymentModalType = type;
		showPaymentModal = true;
		paymentAmount = 0;
		selectedEntity = null;
		paymentError = '';
		paymentMessage = '';
		applyDenomination = true;
		paymentDenominationCounts = {};
		paymentSearch = '';
		
		// Load data for the selected type
		if (type === 'vendor' && vendors.length === 0) loadVendors();
		if (type === 'expenses' && expenses.length === 0) loadExpenses();
		if (type === 'user' && users.length === 0) loadUsers();
	}

	function closePaymentModal() {
		showPaymentModal = false;
		paymentModalType = null;
		paymentAmount = 0;
		selectedEntity = null;
		paymentError = '';
		paymentMessage = '';
		applyDenomination = true;
		paymentDenominationCounts = {};
		vendorSearch = '';
		expenseSearch = '';
		userSearch = '';
	}

	async function loadVendors() {
		try {
			const { data, error } = await supabase
				.from('vendors')
				.select('erp_vendor_id, vendor_name, vat_number')
				.eq('branch_id', selectedBranchId)
				.eq('status', 'Active')
				.order('vendor_name');
			
			if (error) throw error;
			vendors = (data || []).map(v => ({ id: v.erp_vendor_id, name: v.vendor_name, code: v.vat_number }));
		} catch (err) {
			console.error('Error loading vendors:', err);
			paymentError = 'Failed to load vendors';
		}
	}

	async function loadExpenses() {
		try {
			const { data, error } = await supabase
				.from('requesters')
				.select('id, requester_id, requester_name, contact_number')
				.order('requester_name');
			
			if (error) throw error;
			expenses = (data || []).map(e => ({ 
				id: e.id, 
				name: e.requester_name,
				requester_id: e.requester_id,
				contact: e.contact_number
			}));
		} catch (err) {
			console.error('Error loading expenses:', err);
			paymentError = 'Failed to load requesters';
		}
	}

	async function loadUsers() {
		try {
			const { data, error } = await supabase
				.from('users')
				.select('id, username')
				.eq('status', 'active')
				.order('username');
			
			if (error) throw error;
			users = (data || []).map(u => ({ id: u.id, name: u.username }));
		} catch (err) {
			console.error('Error loading users:', err);
			paymentError = 'Failed to load users';
		}
	}

	async function savePaymentTransaction() {
		if (!selectedEntity || paymentAmount <= 0 || !selectedBranchId || !$currentUser?.id) {
			paymentError = 'Please fill all required fields';
			return;
		}

		if (paymentAmount > pettyCashBalance) {
			paymentError = `Insufficient balance. Available: ${formatCurrency(pettyCashBalance)}`;
			return;
		}

		savingPayment = true;
		paymentError = '';
		paymentMessage = '';

		try {
			// Create entity data object
			const entityData: any = {
				paid_from_petty_cash: true
			};

			if (paymentModalType === 'vendor') {
				entityData.vendor_id = selectedEntity.id;
				entityData.vendor_name = selectedEntity.name;
			} else if (paymentModalType === 'expenses') {
				entityData.requester_id = selectedEntity.id;
				entityData.requester_name = selectedEntity.name;
				entityData.requester_code = selectedEntity.requester_id;
				entityData.contact_number = selectedEntity.contact;
			} else if (paymentModalType === 'user') {
				entityData.user_id = selectedEntity.id;
				entityData.username = selectedEntity.username;
			}

			// Save transaction to denomination_transactions
			// Note: apply_denomination is set to FALSE for petty cash payments
			// so Denomination component treats it as "Not Applied" in calculations
			const { data: transactionData, error: transactionError } = await supabase
				.from('denomination_transactions')
				.insert({
					branch_id: selectedBranchId,
					section: 'paid',
					transaction_type: paymentModalType,
					amount: paymentAmount,
					remarks: 'Paid from petty cash',
					apply_denomination: false,
					entity_data: entityData,
					created_by: $currentUser.id
				})
				.select();

			if (transactionError) throw transactionError;

			// Get current petty cash record
			const { data: currentRecord } = await supabase
				.from('denomination_records')
				.select('*')
				.eq('branch_id', selectedBranchId)
				.eq('record_type', 'petty_cash_box')
				.order('created_at', { ascending: false })
				.limit(1)
				.single();

			if (!currentRecord) {
				throw new Error('Petty cash record not found');
			}

			// Simply deduct payment amount from grand total
			const newGrandTotal = currentRecord.grand_total - paymentAmount;

			// Update petty cash record (only update grand_total, keep counts as is)
			const { error: updateError } = await supabase
				.from('denomination_records')
				.update({
					grand_total: newGrandTotal,
					updated_at: new Date().toISOString()
				})
				.eq('id', currentRecord.id);

			if (updateError) throw updateError;

			paymentMessage = `✅ Payment of ${formatCurrency(paymentAmount)} saved successfully!`;
			
			// Refresh data
			await loadPettyCashBalance();
			await loadPettyCashTransactions();
			
			// Close modal and reset
			setTimeout(() => {
				closePaymentModal();
				paymentMessage = '';
			}, 2000);

		} catch (err) {
			console.error('Error saving payment transaction:', err);
			paymentError = 'Failed to save payment transaction';
		} finally {
			savingPayment = false;
		}
	}

	async function loadPettyCashTransactions() {
		if (!selectedBranchId) return;

		try {
			const { data, error } = await supabase
				.from('denomination_transactions')
				.select('*')
				.eq('branch_id', selectedBranchId)
				.eq('section', 'paid')
				.contains('entity_data', { paid_from_petty_cash: true })
				.order('created_at', { ascending: false });

			if (error) throw error;

			pettyCashTransactions = (data || []).map(t => ({
				id: t.id,
				transaction_type: t.transaction_type,
				entity_name: t.entity_data?.vendor_name || t.entity_data?.requester_name || t.entity_data?.expense_name || t.entity_data?.username || 'Unknown',
				amount: t.amount,
				remarks: t.remarks,
				created_at: t.created_at,
				apply_denomination: t.apply_denomination,
				denomination_details: t.denomination_details
			}));
		} catch (err) {
			console.error('Error loading petty cash transactions:', err);
		}
	}

	async function deletePaymentTransaction(transactionId: string) {
		if (!confirm('Are you sure you want to delete this transaction?')) return;

		try {
			// Get the transaction to retrieve payment amount
			const { data: transactionData, error: fetchError } = await supabase
				.from('denomination_transactions')
				.select('amount, denomination_details')
				.eq('id', transactionId)
				.single();

			if (fetchError) throw fetchError;

			// Get current petty cash record
			const { data: currentRecord, error: recordError } = await supabase
				.from('denomination_records')
				.select('*')
				.eq('branch_id', selectedBranchId)
				.eq('record_type', 'petty_cash_box')
				.order('created_at', { ascending: false })
				.limit(1)
				.single();

			if (recordError) throw recordError;

			// Simply add back the payment amount to grand_total
			const newGrandTotal = currentRecord.grand_total + (transactionData?.amount || 0);

			// Update petty cash record (only update grand_total)
			const { error: updateError } = await supabase
				.from('denomination_records')
				.update({
					grand_total: newGrandTotal,
					updated_at: new Date().toISOString()
				})
				.eq('id', currentRecord.id);

			if (updateError) throw updateError;

			// Delete the transaction
			const { error: deleteError } = await supabase
				.from('denomination_transactions')
				.delete()
				.eq('id', transactionId);

			if (deleteError) throw deleteError;

			// Refresh data
			await loadPettyCashBalance();
			await loadPettyCashTransactions();

		} catch (err) {
			console.error('Error deleting transaction:', err);
			alert('Failed to delete transaction');
		}
	}

	function selectBox(box: BoxOperation) {
		selectedBox = selectedBox?.id === box.id ? null : box;
		if (selectedBox) {
			transferQuantities = {};
			transferMessage = '';
			transferError = '';
		}
	}

	async function saveTransferToPettyCash() {
		if (!selectedBox || !selectedBranchId || !$currentUser?.id) return;

		// Validate quantities don't exceed available counts
		for (const [key, qty] of Object.entries(transferQuantities)) {
			const availableCount = selectedBox.closing_details?.closing_counts[key] || 0;
			if (qty > availableCount) {
				transferError = `Cannot transfer more than available. ${getDenominationLabel(key)}: available ${availableCount}, requested ${qty}`;
				return;
			}
		}

		// Calculate total to transfer
		const totalToTransfer = Object.entries(transferQuantities).reduce((sum, [key, qty]) => {
			if (key !== 'coins' && qty > 0) {
				return sum + parseFloat(key.replace('d', '')) * qty;
			}
			return sum;
		}, 0);

		if (totalToTransfer <= 0) {
			transferError = 'Please enter quantities to transfer';
			return;
		}

		savingTransfer = true;
		transferMessage = '';
		transferError = '';

		try {
			// Get current petty cash record
			const { data: currentRecord } = await supabase
				.from('denomination_records')
				.select('*')
				.eq('branch_id', selectedBranchId)
				.eq('record_type', 'petty_cash_box')
				.order('created_at', { ascending: false })
				.limit(1)
				.single();

			// Build new counts with transferred amounts added
			const newCounts = currentRecord?.counts || {};
			Object.entries(transferQuantities).forEach(([key, qty]) => {
				if (qty > 0) {
					newCounts[key] = (newCounts[key] || 0) + qty;
				}
			});

			// Calculate new grand total
			let newGrandTotal = 0;
			Object.entries(newCounts).forEach(([key, count]) => {
				if (key !== 'coins') {
					newGrandTotal += parseFloat(key.replace('d', '')) * count;
				}
			});

			console.log('Current Counts:', currentRecord?.counts);
			console.log('New Counts:', newCounts);
			console.log('Current Grand Total:', currentRecord?.grand_total);
			console.log('New Grand Total:', newGrandTotal);

			// Create petty_cash_operation details with box info, user ID, and only transferred denominations
			const transferredDenominations = {};
			Object.entries(transferQuantities).forEach(([key, qty]) => {
				if (qty > 0) {
					transferredDenominations[key] = qty;
				}
			});

			const pettyCashOperation = {
				transferred_from_branch_id: selectedBranchId,
				transferred_from_box_id: selectedBox.id,
				transferred_from_box_number: selectedBox.box_number,
				transferred_from_user_id: selectedBox.user_id,
				transferred_denominations: transferredDenominations,
				transfer_timestamp: new Date().toISOString()
			};

			// Update or create petty cash record
			if (currentRecord?.id) {
				// Get existing operations array or create new one
				const existingOperations = Array.isArray(currentRecord.petty_cash_operation) 
					? currentRecord.petty_cash_operation 
					: (currentRecord.petty_cash_operation ? [currentRecord.petty_cash_operation] : []);
				
				// Append new operation to the array
				const updatedOperations = [...existingOperations, pettyCashOperation];

				const { error } = await supabase
					.from('denomination_records')
					.update({
						counts: newCounts,
						grand_total: newGrandTotal,
						petty_cash_operation: updatedOperations,
						updated_at: new Date().toISOString()
					})
					.eq('id', currentRecord.id);

				if (error) throw error;
			} else {
				const { error } = await supabase
					.from('denomination_records')
					.insert({
						branch_id: selectedBranchId,
						record_type: 'petty_cash_box',
						counts: newCounts,
						grand_total: newGrandTotal,
						petty_cash_operation: [pettyCashOperation],
						created_by: $currentUser.id
					});

				if (error) throw error;
			}

			transferMessage = `✅ Successfully transferred ${formatCurrency(totalToTransfer)} to petty cash!`;
			await loadPettyCashBalance();
			await loadAvailableBoxes();
			transferQuantities = {};
			selectedBox = null;
			setTimeout(() => {
				transferMessage = '';
			}, 3000);
		} catch (err) {
			console.error('Error transferring to petty cash:', err);
			transferError = 'Failed to transfer to petty cash';
		} finally {
			savingTransfer = false;
		}
	}

	function calculateDenominationTotal(): number {
		if (!selectedBox?.closing_details?.closing_counts) return 0;
		
		let total = 0;
		Object.entries(selectedBox.closing_details.closing_counts).forEach(([key, count]) => {
			if (key !== 'coins') {
				total += parseFloat(key.replace('d', '')) * count;
			}
		});
		return total;
	}

	function getBoxDenominationTotal(box: BoxOperation): number {
		if (!box?.closing_details?.closing_counts) return 0;
		
		let total = 0;
		Object.entries(box.closing_details.closing_counts).forEach(([key, count]) => {
			if (key !== 'coins') {
				total += parseFloat(key.replace('d', '')) * count;
			}
		});
		return total;
	}

	function getBoxBalanceAfterTransfer(box: BoxOperation & { _transferredAmount?: number }): number {
		const originalTotal = getBoxDenominationTotal(box);
		
		// If there are pending transfer quantities in the modal, use those
		if (selectedBox && selectedBox.id === box.id) {
			const pendingTransfer = Object.entries(transferQuantities).reduce((sum, [key, qty]) => {
				if (key !== 'coins' && qty > 0) {
					return sum + parseFloat(key.replace('d', '')) * qty;
				}
				return sum;
			}, 0);
			if (pendingTransfer > 0) {
				return originalTotal - pendingTransfer;
			}
		}
		
		// Otherwise, use the transferred amount from completed transfers
		const alreadyTransferred = box._transferredAmount || 0;
		return originalTotal - alreadyTransferred;
	}
</script>

<div class="petty-cash-container">
	<div class="cards-grid">
		<!-- Card 1: Branch Selection -->
		<div class="card card-1">
			<div class="card-header">
				<h2>💼 Card 1</h2>
				<span class="card-number">1</span>
			</div>
			<div class="card-content">
				<div class="section-title">Branch Selection</div>

				{#if loading}
					<div class="loading">Loading branches...</div>
				{:else}
					<div class="form-group">
						<label for="branch-select">Select Branch:</label>
						<select
							id="branch-select"
							bind:value={selectedBranchId}
							class="branch-select"
							disabled={saving}
						>
							<option value={null}>-- Select a Branch --</option>
							{#each branches as branch (branch.id)}
								<option value={branch.id}>
									{branch.name_en} - {branch.location_en}
								</option>
							{/each}
						</select>
					</div>

					<div class="default-branch-info">
						<div class="info-label">Current Default:</div>
						<div class="info-value">{getBranchDisplay(defaultBranchId)}</div>
					</div>

					<button
						on:click={setDefaultBranch}
						disabled={saving || !selectedBranchId}
						class="set-default-btn"
					>
						{#if saving}
							<span class="spinner"></span> Setting...
						{:else}
							⭐ Set as Default Branch
						{/if}
					</button>

					{#if successMessage}
						<div class="success-message">{successMessage}</div>
					{/if}

					{#if errorMessage}
						<div class="error-message">{errorMessage}</div>
					{/if}
				{/if}
			</div>
		</div>

		<!-- Card 2: Blank -->
		<div class="card card-2">
			<div class="card-header">
				<h2>� Card 2</h2>
				<span class="card-number">2</span>
			</div>
			<div class="card-content">
				<div class="section-title">Available Cash Boxes</div>

				{#if !selectedBranchId}
					<div class="no-branch-message">
						<p>Select a branch in Card 1 to view available cash boxes</p>
					</div>
				{:else if loadingBoxes}
					<div class="loading">Loading boxes...</div>
				{:else if availableBoxes.length === 0}
					<div class="no-boxes-message">
						<p>No pending boxes for this branch</p>
					</div>
				{:else}
					<div class="boxes-list">
						{#each availableBoxes as box (box.id)}
							<div class="box-item" on:click={() => selectBox(box)} style="cursor: pointer;">
								<div class="box-number-badge">Box {box.box_number}</div>
								<div class="box-info">
									<div class="box-cashier">👤 {employeeMap.get(box.user_id) || 'Unknown'}</div>
									<div class="box-balances">
										<div class="balance-original">
											Original: {#if box.closing_details?.closing_counts}
												{formatCurrency(getBoxDenominationTotal(box))}
											{:else}
												{formatCurrency(box.total_after)}
											{/if}
										</div>
										<div class="balance-after">
											After Transfer: {formatCurrency(getBoxBalanceAfterTransfer(box))}
										</div>
									</div>
									<div class="box-time">{formatDate(box.start_time)}</div>
								</div>
							</div>
						{/each}
					</div>
				{/if}
			</div>
		</div>

		<!-- Card 3: Petty Cash Balance -->
		<div class="card card-3">
			<div class="card-header">
				<h2>💰 Card 3</h2>
				<span class="card-number">3</span>
			</div>
			<div class="card-content">
				<div class="section-title">Petty Cash Balance</div>

				{#if !selectedBranchId}
					<div class="no-branch-message">
						<p>Select a branch in Card 1 to view petty cash balance</p>
					</div>
				{:else if loadingPettyCash}
					<div class="loading">Loading balance...</div>
				{:else}
					<div class="petty-cash-display">
						<div class="balance-label">Current Balance</div>
						<div class="balance-amount">
							💵 {pettyCashBalance.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 2 })} SAR
						</div>
					</div>
				{/if}
			</div>
		</div>
	</div>

	<!-- Payment Buttons Section -->
	{#if selectedBranchId}
		<div class="payment-buttons-section">
			<h3 class="section-heading">💳 Make Payment from Petty Cash</h3>
			<div class="payment-buttons-grid">
				<button 
					class="payment-btn vendor-btn"
					on:click={() => openPaymentModal('vendor')}
					disabled={pettyCashBalance <= 0}
					title={pettyCashBalance <= 0 ? 'No balance available' : 'Pay to vendor'}
				>
					🏪 Vendor Payment
				</button>
				<button 
					class="payment-btn expense-btn"
					on:click={() => openPaymentModal('expenses')}
					disabled={pettyCashBalance <= 0}
					title={pettyCashBalance <= 0 ? 'No balance available' : 'Pay to requester'}
				>
					📊 Requester Payment
				</button>
				<button 
					class="payment-btn user-btn"
					on:click={() => openPaymentModal('user')}
					disabled={pettyCashBalance <= 0}
					title={pettyCashBalance <= 0 ? 'No balance available' : 'Pay to user'}
				>
					👤 User Payment
				</button>
			</div>
		</div>

		<!-- Petty Cash Transactions History -->
		{#if pettyCashTransactions.length > 0}
			<div class="transactions-history-section">
				<h3 class="section-heading">📝 Payment History</h3>
				<div class="transactions-table-wrapper">
					<table class="transactions-table">
						<thead>
							<tr>
								<th>Type</th>
								<th>Vendor/Expense/User</th>
								<th>Amount</th>
								<th>Remarks</th>
								<th>Date/Time</th>
								<th>Action</th>
							</tr>
						</thead>
						<tbody>
							{#each pettyCashTransactions as transaction (transaction.id)}
								<tr>
									<td class="type-cell">
										<span class="type-badge {transaction.transaction_type}">
											{transaction.transaction_type === 'vendor' ? '🏪' : transaction.transaction_type === 'expenses' ? '📊' : '👤'} 
											{transaction.transaction_type.charAt(0).toUpperCase() + transaction.transaction_type.slice(1)}
										</span>
									</td>
									<td>{transaction.entity_name}</td>
									<td class="amount-cell">{formatCurrency(transaction.amount)}</td>
									<td class="remarks-cell">{transaction.remarks}</td>
									<td class="date-cell">{formatDate(transaction.created_at)}</td>
									<td class="action-cell">
										<button 
											class="delete-btn"
											on:click={() => deletePaymentTransaction(transaction.id)}
											title="Delete transaction"
										>
											🗑️ Delete
										</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}
	{/if}


	<!-- Modal Popup for Denominations -->
	{#if selectedBox && selectedBox.closing_details?.closing_counts}
		<div class="modal-overlay" on:click={() => (selectedBox = null)}>
			<div class="modal-content" on:click={(e) => e.stopPropagation()}>
				<div class="modal-header">
					<h3>📊 Denominations - Box {selectedBox.box_number} ({employeeMap.get(selectedBox.user_id) || 'Unknown'})</h3>
					<button class="modal-close-btn" on:click={() => (selectedBox = null)}>✕</button>
				</div>
				
				<div class="modal-body">					<table class="denominations-table">
						<thead>
							<tr>
								<th>Denomination</th>
								<th>Count</th>
								<th>Amount</th>
								<th>Transfer Qty</th>
								<th>Transfer Amount</th>
							</tr>
						</thead>
						<tbody>
							{#each Object.entries(selectedBox.closing_details.closing_counts) as [key, count]}
								{@const transferred = selectedBox._transferredDenominations?.[key] || 0}
								{@const remaining = count - transferred}
								<tr>
									<td>{getDenominationLabel(key)}</td>
									<td class="count-col">
										{remaining}
										{#if transferred > 0}
											<span style="font-size: 0.85em; color: #999; margin-left: 4px;" title="Original: {count}">
												(was {count})
											</span>
										{/if}
									</td>
									<td class="amount-col">
										{#if key === 'coins'}
											—
										{:else}
											{formatCurrency(
												parseFloat(key.replace('d', '')) * remaining
											)}
										{/if}
									</td>
									<td class="transfer-col">
										{#if key !== 'coins' && remaining > 0}
											<input
												type="number"
												min="0"
												max={remaining}
												bind:value={transferQuantities[key]}
												placeholder="0"
												class="transfer-input"
												disabled={savingTransfer}
											/>
										{:else}
											<span class="disabled-text">—</span>
										{/if}
									</td>
									<td class="transfer-amount-col">
										{#if key === 'coins'}
											—
										{:else if transferQuantities[key] > 0}
											{formatCurrency(
												parseFloat(key.replace('d', '')) * (transferQuantities[key] || 0)
											)}
										{:else}
											—
										{/if}
									</td>
								</tr>
							{/each}
							<tr class="total-row">
								<td colspan="2" style="font-weight: 600; color: #333;">💵 Cash Total</td>
								<td class="amount-col" style="font-weight: 700; color: #2e7d32;">
									{formatCurrency(calculateDenominationTotal())}
								</td>
								<td class="transfer-col" style="font-weight: 600; color: #1976d2;">Transfer Total</td>
								<td class="transfer-amount-col" style="font-weight: 700; color: #1976d2;">
									{formatCurrency(
										Object.entries(transferQuantities).reduce((sum, [key, qty]) => {
											if (key !== 'coins' && qty > 0) {
												return sum + parseFloat(key.replace('d', '')) * qty;
											}
											return sum;
										}, 0)
									)}
								</td>
							</tr>
						</tbody>
					</table>
				</div>

				{#if Object.values(transferQuantities).some(v => v > 0)}
					<div class="modal-footer">
						{#if exceedMessage}
							<div class="warning-message">{exceedMessage}</div>
						{/if}
						<button
							on:click={saveTransferToPettyCash}
							disabled={savingTransfer || exceedMessage}
							class="save-transfer-btn"
						>
							{#if savingTransfer}
								<span class="spinner"></span> Saving...
							{:else}
								💾 Save Transfer to Petty Cash
							{/if}
						</button>
						{#if transferMessage}
							<div class="success-message transfer-message">{transferMessage}</div>
						{/if}
						{#if transferError}
							<div class="error-message transfer-message">{transferError}</div>
						{/if}
					</div>
				{/if}
			</div>
		</div>
	{/if}

	<!-- Payment Modal -->
	{#if showPaymentModal && paymentModalType}
		<div class="modal-overlay" on:click={() => closePaymentModal()}>
			<div class="modal-content payment-modal" on:click={(e) => e.stopPropagation()}>
				<div class="modal-header">
					<h3>
						{paymentModalType === 'vendor' ? '🏪 Vendor Payment' : paymentModalType === 'expenses' ? '📊 Expense Payment' : '👤 User Payment'}
					</h3>
					<button class="modal-close-btn" on:click={() => closePaymentModal()}>✕</button>
				</div>

				<div class="modal-body">
					<!-- Search/Select Entity -->
					<div class="form-group">
						<label>
							{paymentModalType === 'vendor' ? 'Select Vendor' : paymentModalType === 'expenses' ? 'Select Requester' : 'Select User'}:
						</label>
						<div class="search-input-wrapper">
							<input
								type="text"
								class="search-input"
								placeholder="Search..."
								bind:value={paymentSearch}
								disabled={savingPayment}
							/>
						</div>

						{#if selectedEntity}
							<div class="selected-entity">
								<div class="entity-badge">
									✓ {selectedEntity.name || selectedEntity.name_en || selectedEntity.username}
									{#if selectedEntity.contact}
										<span style="font-size: 0.9em; color: #666; margin-left: 8px;">({selectedEntity.contact})</span>
									{/if}
								</div>
								<button 
									type="button" 
									class="clear-btn" 
									on:click={() => selectedEntity = null}
									disabled={savingPayment}
								>
									✕
								</button>
							</div>
						{:else}
							<div class="dropdown-list">
								{#each (paymentModalType === 'vendor' ? vendors : paymentModalType === 'expenses' ? expenses : users).filter(e => {
									const name = e.name || e.name_en || e.username || '';
									const contact = e.contact || '';
									const search = paymentSearch.toLowerCase();
									return name.toLowerCase().includes(search) || contact.includes(search);
								}) as entity (entity.id)}
									<div 
										class="dropdown-item" 
										on:click={() => { selectedEntity = entity; }}
									>
										<div class="entity-name">
											{entity.name || entity.name_en || entity.username}
											{#if entity.contact}
												<span style="font-size: 0.85em; color: #666; margin-left: 8px;">({entity.contact})</span>
											{/if}
										</div>
										{#if entity.vendor_code}
											<div class="entity-code">{entity.vendor_code}</div>
										{:else if entity.requester_id}
											<div class="entity-code">{entity.requester_id}</div>
										{/if}
									</div>
								{/each}
							</div>
						{/if}
					</div>

					{#if selectedEntity}
						<!-- Amount Input -->
						<div class="form-group">
							<label for="payment-amount">Payment Amount:</label>
							<input
								id="payment-amount"
								type="number"
								min="0"
								max={pettyCashBalance}
								step="0.01"
								bind:value={paymentAmount}
								class="form-input"
								placeholder="Enter amount"
								disabled={savingPayment}
							/>
							<div class="available-balance">Available: {formatCurrency(pettyCashBalance)}</div>
						</div>
					{/if}

					{#if selectedEntity && paymentAmount > 0}
						<div class="modal-footer">
							{#if paymentError}
								<div class="error-message">{paymentError}</div>
							{/if}
							<button
								class="btn-cancel"
								on:click={() => closePaymentModal()}
								disabled={savingPayment}
							>
								Cancel
							</button>
							<button
								class="btn-save"
								on:click={() => savePaymentTransaction()}
								disabled={savingPayment || paymentAmount <= 0}
							>
								{#if savingPayment}
									<span class="spinner"></span> Saving...
								{:else}
									💾 Save Payment
								{/if}
							</button>
						</div>
						{#if paymentMessage}
							<div class="success-message" style="margin: 12px 16px 0; margin-bottom: 0;">{paymentMessage}</div>
						{/if}
					{/if}
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.petty-cash-container {
		padding: 24px;
		height: 100%;
		width: 100%;
		background: linear-gradient(135deg, #f5f5f5 0%, #fafafa 100%);
		overflow-y: auto;
	}

	.cards-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 16px;
		max-width: 100%;
		margin: 0 auto;
	}

	.card {
		background: white;
		border-radius: 16px;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
		overflow: hidden;
		transition: all 0.3s ease;
		transform: perspective(1000px) rotateY(0deg);
		border: 2px solid transparent;
	}

	.card:hover {
		transform: perspective(1000px) translateY(-8px);
		box-shadow: 0 12px 32px rgba(0, 0, 0, 0.18);
	}

	.card-1 {
		border-color: #ff9800;
		background: linear-gradient(135deg, #fff8f0 0%, #fff 100%);
	}

	.card-1:hover {
		box-shadow: 0 12px 32px rgba(255, 152, 0, 0.25);
	}

	.card-2 {
		border-color: #4caf50;
		background: linear-gradient(135deg, #f1f8f4 0%, #fff 100%);
	}

	.card-2:hover {
		box-shadow: 0 12px 32px rgba(76, 175, 80, 0.25);
	}

	.card-3 {
		border-color: #2196f3;
		background: linear-gradient(135deg, #f0f7ff 0%, #fff 100%);
	}

	.card-3:hover {
		box-shadow: 0 12px 32px rgba(33, 150, 243, 0.25);
	}

	.card-header {
		padding: 6px 8px;
		background: linear-gradient(135deg, #fff 0%, #fafafa 100%);
		border-bottom: 2px solid rgba(0, 0, 0, 0.05);
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.card-header h2 {
		margin: 0;
		font-size: 11px;
		font-weight: 600;
		color: #333;
	}

	.card-number {
		background: linear-gradient(135deg, #ff9800 0%, #f57c00 100%);
		color: white;
		width: 20px;
		height: 20px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: bold;
		font-size: 10px;
		box-shadow: 0 4px 8px rgba(255, 152, 0, 0.3);
	}

	.card-2 .card-number {
		background: linear-gradient(135deg, #4caf50 0%, #45a049 100%);
		box-shadow: 0 4px 8px rgba(76, 175, 80, 0.3);
	}

	.card-3 .card-number {
		background: linear-gradient(135deg, #2196f3 0%, #1976d2 100%);
		box-shadow: 0 4px 8px rgba(33, 150, 243, 0.3);
	}

	.card-content {
		padding: 12px;
		min-height: 150px;
		display: flex;
		flex-direction: column;
	}

	.section-title {
		font-size: 10px;
		font-weight: 600;
		color: #ff9800;
		margin-bottom: 6px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.form-group {
		margin-bottom: 6px;
	}

	.form-group label {
		display: block;
		font-size: 9px;
		font-weight: 600;
		color: #555;
		margin-bottom: 3px;
	}

	.branch-select {
		width: 100%;
		padding: 4px 6px;
		border: 2px solid #e0e0e0;
		border-radius: 4px;
		font-size: 9px;
		background-color: white;
		color: #333;
		cursor: pointer;
		transition: all 0.3s ease;
		font-family: inherit;
	}

	.branch-select:hover:not(:disabled) {
		border-color: #ff9800;
		box-shadow: 0 2px 8px rgba(255, 152, 0, 0.15);
	}

	.branch-select:focus {
		outline: none;
		border-color: #ff9800;
		box-shadow: 0 0 0 3px rgba(255, 152, 0, 0.1);
	}

	.branch-select:disabled {
		background-color: #f5f5f5;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.default-branch-info {
		background: linear-gradient(135deg, #fff9c4 0%, #fffde7 100%);
		padding: 6px;
		border-radius: 4px;
		margin-bottom: 6px;
		border-left: 3px solid #fbc02d;
	}

	.info-label {
		font-size: 8px;
		color: #f57f17;
		font-weight: 600;
		text-transform: uppercase;
		margin-bottom: 2px;
	}

	.info-value {
		font-size: 9px;
		color: #333;
		font-weight: 500;
	}

	.set-default-btn {
		padding: 4px 8px;
		background: linear-gradient(135deg, #ff9800 0%, #f57c00 100%);
		color: white;
		border: none;
		border-radius: 4px;
		font-size: 8px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 4px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		box-shadow: 0 4px 12px rgba(255, 152, 0, 0.3);
		margin-bottom: 6px;
	}

	.set-default-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(255, 152, 0, 0.4);
	}

	.set-default-btn:active:not(:disabled) {
		transform: translateY(0px);
		box-shadow: 0 2px 8px rgba(255, 152, 0, 0.3);
	}

	.set-default-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.spinner {
		display: inline-block;
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.loading {
		padding: 10px 5px;
		text-align: center;
		color: #999;
		font-size: 9px;
	}

	.success-message {
		padding: 6px 8px;
		background-color: #c8e6c9;
		color: #2e7d32;
		border-radius: 4px;
		border-left: 3px solid #4caf50;
		font-size: 8px;
		font-weight: 500;
		animation: slideIn 0.3s ease;
	}

	.error-message {
		padding: 6px 8px;
		background-color: #ffcdd2;
		color: #c62828;
		border-radius: 4px;
		border-left: 3px solid #f44336;
		font-size: 8px;
		font-weight: 500;
		animation: slideIn 0.3s ease;
	}

	.warning-message {
		padding: 10px 12px;
		background-color: #fff3cd;
		color: #856404;
		border-radius: 6px;
		border-left: 4px solid #ffc107;
		font-size: 12px;
		font-weight: 500;
		margin-bottom: 12px;
		animation: slideIn 0.3s ease;
	}

	@keyframes slideIn {
		from {
			opacity: 0;
			transform: translateY(-8px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.placeholder {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
		font-size: 9px;
		color: #999;
		font-weight: 500;
	}

	.no-branch-message,
	.no-boxes-message {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
		text-align: center;
	}

	.no-branch-message p,
	.no-boxes-message p {
		font-size: 10px;
		color: #999;
		margin: 0;
	}

	.boxes-list {
		display: flex;
		flex-direction: column;
		gap: 6px;
		max-height: 140px;
		overflow-y: auto;
	}

	.box-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px;
		background: linear-gradient(135deg, #e8f5e9 0%, #f1f8f4 100%);
		border-radius: 6px;
		border-left: 3px solid #4caf50;
	}

	.box-number-badge {
		background: linear-gradient(135deg, #4caf50 0%, #45a049 100%);
		color: white;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 9px;
		font-weight: 600;
		min-width: 50px;
		text-align: center;
		box-shadow: 0 2px 4px rgba(76, 175, 80, 0.2);
	}

	.box-info {
		flex: 1;
	}

	.box-cashier {
		font-size: 9px;
		font-weight: 600;
		color: #333;
		margin-bottom: 2px;
	}

	.box-total {
		font-size: 10px;
		font-weight: 600;
		color: #2e7d32;
	}

	.box-balances {
		display: flex;
		flex-direction: column;
		gap: 2px;
		margin: 2px 0;
	}

	.balance-original {
		font-size: 9px;
		font-weight: 600;
		color: #1976d2;
	}

	.balance-after {
		font-size: 9px;
		font-weight: 600;
		color: #2e7d32;
		padding: 2px 4px;
		background: #f0f7ff;
		border-radius: 3px;
	}

	.box-breakdown {
		display: flex;
		gap: 6px;
		margin-top: 2px;
		flex-wrap: wrap;
	}

	.breakdown-item {
		font-size: 8px;
		color: #555;
		background: white;
		padding: 2px 4px;
		border-radius: 3px;
		white-space: nowrap;
	}

	.box-time {
		font-size: 8px;
		color: #999;
		margin-top: 2px;
	}

	/* Denominations Table Styles */
	.denominations-section {
		margin-top: 24px;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
		overflow: hidden;
		animation: slideIn 0.3s ease;
	}

	.table-header {
		padding: 16px;
		background: linear-gradient(135deg, #4caf50 0%, #45a049 100%);
		color: white;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.table-header h3 {
		margin: 0;
		font-size: 14px;
		font-weight: 600;
	}

	.close-btn {
		background: rgba(255, 255, 255, 0.2);
		border: none;
		color: white;
		width: 28px;
		height: 28px;
		border-radius: 50%;
		font-size: 16px;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.close-btn:hover {
		background: rgba(255, 255, 255, 0.3);
		transform: scale(1.1);
	}

	.table-wrapper {
		padding: 16px;
		overflow-x: auto;
	}

	.denominations-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 12px;
	}

	.denominations-table thead {
		background: #f5f5f5;
		border-bottom: 2px solid #4caf50;
	}

	.denominations-table th {
		padding: 10px;
		text-align: left;
		font-weight: 600;
		color: #333;
	}

	.denominations-table td {
		padding: 10px;
		border-bottom: 1px solid #e0e0e0;
		color: #555;
	}

	.denominations-table tr:hover {
		background: #fafafa;
	}

	.count-col {
		text-align: center;
		font-weight: 500;
		color: #2e7d32;
	}

	.amount-col {
		text-align: right;
		font-weight: 600;
		color: #1976d2;
	}

	.total-row {
		background: linear-gradient(135deg, #f0f7ff 0%, #e3f2fd 100%);
		border-top: 2px solid #4caf50;
		border-bottom: 2px solid #4caf50;
		font-weight: 600;
	}

	.total-row td {
		padding: 12px 10px;
	}

	.transfer-col {
		text-align: center;
		padding: 10px 5px;
	}

	.disabled-text {
		color: #ccc;
		font-weight: 500;
	}

	.transfer-input {
		width: 60px;
		padding: 6px;
		border: 2px solid #e0e0e0;
		border-radius: 4px;
		font-size: 12px;
		text-align: center;
		transition: all 0.3s ease;
	}

	.transfer-input:focus {
		outline: none;
		border-color: #2196f3;
		box-shadow: 0 0 0 3px rgba(33, 150, 243, 0.1);
	}

	.transfer-input:disabled {
		background-color: #f5f5f5;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.transfer-amount-col {
		text-align: right;
		font-weight: 600;
		color: #1976d2;
	}

	.transfer-actions {
		padding: 16px;
		background: linear-gradient(135deg, #f0f7ff 0%, #e3f2fd 100%);
		border-top: 2px solid #2196f3;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.save-transfer-btn {
		padding: 10px 16px;
		background: linear-gradient(135deg, #2196f3 0%, #1976d2 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		box-shadow: 0 4px 12px rgba(33, 150, 243, 0.3);
	}

	.save-transfer-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(33, 150, 243, 0.4);
	}

	.save-transfer-btn:active:not(:disabled) {
		transform: translateY(0px);
		box-shadow: 0 2px 8px rgba(33, 150, 243, 0.3);
	}

	.save-transfer-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.transfer-message {
		margin: 0;
	}

	.petty-cash-display {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		padding: 1.5rem;
		background: linear-gradient(135deg, #f0f7ff 0%, #e3f2fd 100%);
		border-radius: 8px;
		text-align: center;
	}

	.balance-label {
		font-size: 0.9rem;
		color: #666;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.balance-amount {
		font-size: 1.75rem;
		font-weight: 700;
		color: #2196f3;
		line-height: 1.2;
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
		animation: fadeIn 0.3s ease;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	.modal-content {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
		display: flex;
		flex-direction: column;
		max-width: 90vw;
		max-height: 90vh;
		animation: slideUp 0.3s ease;
	}

	@keyframes slideUp {
		from {
			opacity: 0;
			transform: translateY(40px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.modal-header {
		padding: 20px;
		background: linear-gradient(135deg, #4caf50 0%, #45a049 100%);
		color: white;
		display: flex;
		justify-content: space-between;
		align-items: center;
		border-radius: 12px 12px 0 0;
	}

	.modal-header h3 {
		margin: 0;
		font-size: 16px;
		font-weight: 600;
	}

	.modal-close-btn {
		background: rgba(255, 255, 255, 0.2);
		border: none;
		color: white;
		width: 32px;
		height: 32px;
		border-radius: 50%;
		font-size: 18px;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.modal-close-btn:hover {
		background: rgba(255, 255, 255, 0.3);
		transform: scale(1.1);
	}

	.modal-body {
		padding: 20px;
		overflow-y: auto;
		flex: 1;
	}

	.modal-footer {
		padding: 20px;
		background: linear-gradient(135deg, #f0f7ff 0%, #e3f2fd 100%);
		border-top: 2px solid #2196f3;
		display: flex;
		flex-direction: column;
		gap: 12px;
		border-radius: 0 0 12px 12px;
	}

	/* Payment Buttons Section */
	.payment-buttons-section {
		margin-top: 24px;
		padding: 20px;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
	}

	.section-heading {
		margin: 0 0 16px 0;
		font-size: 14px;
		font-weight: 600;
		color: #333;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.payment-buttons-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
		gap: 12px;
	}

	.payment-btn {
		padding: 12px 16px;
		border: none;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.payment-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.payment-btn.vendor-btn {
		background: linear-gradient(135deg, #ff9800 0%, #f57c00 100%);
		color: white;
	}

	.payment-btn.vendor-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(255, 152, 0, 0.3);
	}

	.payment-btn.expense-btn {
		background: linear-gradient(135deg, #4caf50 0%, #45a049 100%);
		color: white;
	}

	.payment-btn.expense-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(76, 175, 80, 0.3);
	}

	.payment-btn.user-btn {
		background: linear-gradient(135deg, #2196f3 0%, #1976d2 100%);
		color: white;
	}

	.payment-btn.user-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(33, 150, 243, 0.3);
	}

	/* Transaction History Section */
	.transactions-history-section {
		margin-top: 24px;
		padding: 20px;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
	}

	.transactions-table-wrapper {
		overflow-x: auto;
		margin-top: 16px;
	}

	.transactions-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 12px;
	}

	.transactions-table thead {
		background: #f5f5f5;
		border-bottom: 2px solid #ddd;
	}

	.transactions-table th {
		padding: 10px;
		text-align: left;
		font-weight: 600;
		color: #333;
	}

	.transactions-table td {
		padding: 10px;
		border-bottom: 1px solid #eee;
		color: #555;
	}

	.transactions-table tbody tr:hover {
		background: #fafafa;
	}

	.type-cell {
		text-align: center;
	}

	.type-badge {
		display: inline-block;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 600;
		color: white;
	}

	.type-badge.vendor {
		background: #ff9800;
	}

	.type-badge.expenses {
		background: #4caf50;
	}

	.type-badge.user {
		background: #2196f3;
	}

	.amount-cell {
		text-align: right;
		font-weight: 600;
		color: #2e7d32;
	}

	.remarks-cell {
		font-size: 11px;
		color: #999;
	}

	.date-cell {
		font-size: 11px;
		color: #999;
		white-space: nowrap;
	}

	.action-cell {
		text-align: center;
	}

	.delete-btn {
		padding: 4px 8px;
		background: #f44336;
		color: white;
		border: none;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.delete-btn:hover {
		background: #d32f2f;
		transform: scale(1.05);
	}

	.delete-btn:active {
		transform: scale(0.95);
	}

	/* Payment Modal Styles */
	.payment-modal {
		max-width: 500px;
	}

	.search-input-wrapper {
		position: relative;
		margin-bottom: 8px;
	}

	.search-input {
		width: 100%;
		padding: 8px 12px;
		border: 2px solid #e0e0e0;
		border-radius: 4px;
		font-size: 12px;
		transition: all 0.2s ease;
	}

	.search-input:focus {
		outline: none;
		border-color: #2196f3;
		box-shadow: 0 0 0 3px rgba(33, 150, 243, 0.1);
	}

	.dropdown-list {
		max-height: 200px;
		overflow-y: auto;
		border: 1px solid #e0e0e0;
		border-radius: 4px;
		background: white;
	}

	.dropdown-item {
		padding: 10px 12px;
		cursor: pointer;
		transition: background 0.2s ease;
		border-bottom: 1px solid #f0f0f0;
	}

	.dropdown-item:hover {
		background: #f5f5f5;
	}

	.entity-name {
		font-size: 12px;
		font-weight: 600;
		color: #333;
	}

	.entity-code {
		font-size: 10px;
		color: #999;
		margin-top: 2px;
	}

	.selected-entity {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 12px;
		background: #e3f2fd;
		border: 2px solid #2196f3;
		border-radius: 4px;
		margin-top: 8px;
	}

	.entity-badge {
		font-size: 12px;
		font-weight: 600;
		color: #1976d2;
	}

	.clear-btn {
		background: none;
		border: none;
		color: #1976d2;
		cursor: pointer;
		font-size: 16px;
		padding: 0 4px;
		transition: transform 0.2s ease;
	}

	.clear-btn:hover {
		transform: scale(1.2);
	}

	.form-input {
		width: 100%;
		padding: 8px 12px;
		border: 2px solid #e0e0e0;
		border-radius: 4px;
		font-size: 12px;
		transition: all 0.2s ease;
	}

	.form-input:focus {
		outline: none;
		border-color: #2196f3;
		box-shadow: 0 0 0 3px rgba(33, 150, 243, 0.1);
	}

	.available-balance {
		font-size: 11px;
		color: #999;
		margin-top: 4px;
	}

	.checkbox-group {
		display: flex;
		align-items: center;
	}

	.checkbox-group label {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 12px;
		color: #555;
		cursor: pointer;
		margin: 0;
	}

	.checkbox-group input {
		cursor: pointer;
		width: 16px;
		height: 16px;
	}

	.denomination-breakdown {
		margin-top: 12px;
		padding: 12px;
		background: #f9f9f9;
		border-radius: 4px;
		border: 1px solid #e0e0e0;
	}

	.denomination-breakdown h4 {
		margin: 0 0 12px 0;
		font-size: 12px;
		font-weight: 600;
		color: #333;
	}

	.denomination-grid-3col {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 12px;
	}

	.denom-field {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.denom-field label {
		font-size: 11px;
		font-weight: 600;
		color: #555;
	}

	.available-qty {
		font-size: 10px;
		color: #2196f3;
		font-weight: 600;
		margin-top: 2px;
	}

	.denom-input {
		padding: 6px 8px;
		border: 1px solid #ddd;
		border-radius: 3px;
		font-size: 12px;
		text-align: center;
	}

	.denom-input:focus {
		outline: none;
		border-color: #2196f3;
		box-shadow: 0 0 0 2px rgba(33, 150, 243, 0.1);
	}

	.denom-total {
		margin-top: 12px;
		padding: 8px 12px;
		background: white;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 600;
		color: #2196f3;
		text-align: right;
		border: 1px solid #2196f3;
	}

	.btn-cancel,
	.btn-save {
		padding: 10px 16px;
		border: none;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.btn-cancel {
		background: #e0e0e0;
		color: #333;
	}

	.btn-cancel:hover:not(:disabled) {
		background: #d0d0d0;
	}

	.btn-save {
		background: linear-gradient(135deg, #2196f3 0%, #1976d2 100%);
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
	}

	.btn-save:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(33, 150, 243, 0.3);
	}

	.btn-save:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>
