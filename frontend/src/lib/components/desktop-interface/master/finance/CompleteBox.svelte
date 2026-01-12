<script lang="ts">
	import { createClient } from '@supabase/supabase-js';
	import { currentLocale } from '$lib/i18n';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import IssuePurchaseVoucher from './IssuePurchaseVoucher.svelte';
	import ClosePurchaseVoucher from './ClosePurchaseVoucher.svelte';

	export let windowId: string;
	export let operation: any;
	export let branch: any;

	let currencySymbolUrl = '/icons/saudi-currency.png';

	// Parse notes JSON to get names and POS number
	let operationData: any = {};
	let selectedPosNumber = 1;
	let posBeforeUrl: string = '';
	
	console.log('📦 CloseBox received operation:', operation);
	
	// Initialize Supabase client
	const supabase = createClient(
		import.meta.env.VITE_SUPABASE_URL,
		import.meta.env.VITE_SUPABASE_ANON_KEY
	);

	// Check if completed operation exists and load from there
	async function checkAndLoadCompletedOperation() {
		if (!operation?.id || hasCheckedForCompleted) return;
		
		hasCheckedForCompleted = true;

		try {
		console.log('🔍 Checking if closing already started for operation:', operation.id);
		
		// Check if closing process has been started
		const { data: op, error } = await supabase
			.from('box_operations')
			.select('*')
			.eq('id', operation.id)
			.single();

		if (error) {
			console.error('❌ Error checking operation:', error);
			return;
		}

		// If completed_by_name exists, closing has been started
		if (op?.completed_by_name) {
			console.log('✅ Closing already started, loading state');
			operation = op;
			completedByName = op.completed_by_name;
			closingStarted = true;
			
			// Load branch name from the branch prop passed to component
			console.log('🏢 Branch prop received:', branch);
			branchName = branch?.name_en || branch?.name || 'N/A';
			console.log('✅ Loaded branch name:', branchName);
			
			// Reset guards to allow re-initialization
			hasInitializedCounts = false;
			hasFetchedUrl = false;
			initializeClosingCounts();
			await fetchPosBeforeUrl();
		}
	} catch (e) {
		console.error('❌ Exception checking operation:', e);
	}
}

// Run check on component mount (only once)
$: if (operation?.id && !hasCheckedForCompleted) {
		checkAndLoadCompletedOperation();
	}

	// Fetch pos_before_url if not in operation
	async function fetchPosBeforeUrl() {
		if (operation?.id) {
			try {
				console.log('🔍 Fetching pos_before_url for operation:', operation.id);
				
			const { data, error } = await supabase
				.from('box_operations')

				if (error) {
					console.error('Error fetching pos_before_url:', error);
				} else if (data?.pos_before_url) {
					posBeforeUrl = data.pos_before_url;
					console.log('✅ Fetched pos_before_url:', posBeforeUrl);
				}
			} catch (e) {
				console.error('Exception fetching pos_before_url:', e);
			}
		}
	}
	
	try {
		if (operation?.notes) {
			operationData = typeof operation.notes === 'string' 
				? JSON.parse(operation.notes) 
				: operation.notes;
			selectedPosNumber = operationData.pos_number || 1;
		}
	} catch (e) {
		console.error('Error parsing operation notes:', e);
	}
	
	// Fetch pos_before_url on component mount
	$: if (operation?.id && !hasFetchedUrl) {
		fetchPosBeforeUrl();
		hasFetchedUrl = true;
	}
	
	console.log('📝 Parsed operation data:', operationData);

	// Denomination values
	const denomValues: Record<string, number> = {
		'd500': 500,
		'd200': 200,
		'd100': 100,
		'd50': 50,
		'd20': 20,
		'd10': 10,
		'd5': 5,
		'd2': 2,
		'd1': 1,
		'd05': 0.5,
		'd025': 0.25,
		'coins': 1
	};

	const denomLabels: Record<string, string> = {
		'd500': '500',
		'd200': '200',
		'd100': '100',
		'd50': '50',
		'd20': '20',
		'd10': '10',
		'd5': '5',
		'd2': '2',
		'd1': '1',
		'd05': '0.5',
		'd025': '0.25',
		'coins': 'Coins'
	};

	// Closing cash counts - load from operation data
	let closingCounts: Record<string, number> = {};
	let closingDetails: any = {};
	
	// Verification checkboxes for each denomination
	let denomVerified: Record<string, boolean> = {};
	
	// Edit mode tracking for denominations
	let denomEditMode: Record<string, boolean> = {};
	let denomEditedValues: Record<string, number> = {};
	
	// Track if denominations have been added to main record
	let denominationsAdded: boolean = false;
	
	// Voucher verification and edit tracking
	let voucherVerified: Record<number, boolean> = {};
	let voucherEditMode: Record<number, {serial: boolean, amount: boolean}> = {};
	let voucherEditedValues: Record<number, {serial?: string, amount?: number}> = {};
	
	// Unified auto-save function - saves everything to complete_details
	let saveTimeout: ReturnType<typeof setTimeout> | null = null;
	
	async function autoSaveCompleteDetails() {
		if (!operation?.id) {
			console.warn('⚠️ Cannot auto-save: no operation ID');
			return;
		}
		
		console.log('💾 Starting auto-save of complete_details...');
		
		// Get current complete_details or start from closing_details
		let currentCompleteDetails;
		if (operation?.complete_details) {
			currentCompleteDetails = typeof operation.complete_details === 'string'
				? JSON.parse(operation.complete_details)
				: operation.complete_details;
		} else if (operation?.closing_details) {
			currentCompleteDetails = typeof operation.closing_details === 'string'
				? JSON.parse(operation.closing_details)
				: operation.closing_details;
		} else {
			currentCompleteDetails = {};
		}
		
		// Base values are already updated by edit handlers, so just save them directly
		const updatedCompleteDetails = {
			...currentCompleteDetails,
			// Supervisor info (already updated)
			supervisor_code: supervisorCode || '',
			cashier_confirm_code: cashierConfirmCode || '',
			completed_by_name: completedByName || '',
			cashier_name: cashierName || '',
			branch_name: branchName || '',
			// Closing counts (already updated)
			closing_counts: closingCounts,
			closing_total: closingTotal,
			cash_sales: cashSales,
			total_cash_sales: totalCashSales,
			total_sales: totalSales,
			// Vouchers data (already updated)
			vouchers: vouchers,
			vouchers_total: vouchersTotal,
			// Bank reconciliation (already updated)
			bank_mada: Number(madaAmount) || 0,
			bank_visa: Number(visaAmount) || 0,
			bank_mastercard: Number(masterCardAmount) || 0,
			bank_google_pay: Number(googlePayAmount) || 0,
			bank_other: Number(otherAmount) || 0,
			bank_total: bankTotal,
			// System/ERP details (already updated)
			system_cash_sales: Number(systemCashSales) || 0,
			system_card_sales: Number(systemCardSales) || 0,
			system_return: Number(systemReturn) || 0,
			system_total_cash_sales: totalSystemCashSales,
			system_total: totalSystemSales,
			// Recharge cards (already updated)
			recharge_opening_balance: Number(openingBalance) || 0,
			recharge_close_balance: Number(closeBalance) || 0,
			recharge_sales: sales,
			recharge_transaction_start_date: startDateInput || '',
			recharge_transaction_start_time: startTimeInput || '',
			recharge_transaction_end_date: endDateInput || '',
			recharge_transaction_end_time: endTimeInput || '',
			// Differences (calculated)
			difference_cash_sales: differenceInCashSales,
			difference_card_sales: differenceInCardSales,
			total_difference: totalDifference,
			// All edit tracking
			denom_edits: denomEditedValues,
			voucher_edits: voucherEditedValues,
			bank_edits: bankEditedValues,
			system_edits: systemEditedValues,
			recharge_edits: rechargeEditedValues,
			date_time_edits: {
				startDate: rechargeEditedValues['startDate'],
				startTime: rechargeEditedValues['startTime'],
				endDate: rechargeEditedValues['endDate'],
				endTime: rechargeEditedValues['endTime']
			},
			// All verification tracking
			denom_verified: denomVerified,
			voucher_verified: voucherVerified,
			bank_verified: bankVerified,
			system_verified: systemVerified,
			recharge_verified: rechargeVerified
		};
		
		console.log('📝 Complete details to save:', updatedCompleteDetails);
		
		try {
			const { error } = await supabase
				.from('box_operations')
				.update({ 
					complete_details: updatedCompleteDetails,
					updated_at: new Date().toISOString()
				})
				.eq('id', operation.id);
			
			if (error) {
				console.error('❌ Error auto-saving complete_details:', error);
			} else {
				console.log('✅ Auto-saved complete_details successfully');
			}
		} catch (e) {
			console.error('❌ Exception auto-saving complete_details:', e);
		}
	}
	
	// Debounced auto-save trigger
	function triggerAutoSave() {
		if (saveTimeout) {
			clearTimeout(saveTimeout);
		}
		saveTimeout = setTimeout(() => {
			autoSaveCompleteDetails();
		}, 1000); // Save after 1 second of inactivity
	}
	
	// Function to save edited denomination values to complete_details
	async function saveDenomEdits() {
		triggerAutoSave();
	}
	
	// Function to save voucher edits and verification to complete_details
	async function saveVoucherData() {
		triggerAutoSave();
	}
	
	// Ensure closingCounts is always initialized properly
	function initializeClosingCounts() {
		console.log('🔄 Initializing closing counts from operation:', operation);
		
		// Load from complete_details FIRST (this is where edits are stored)
		if (operation?.complete_details) {
			const completeDetails = typeof operation.complete_details === 'string' 
				? JSON.parse(operation.complete_details)
				: operation.complete_details;
			
			console.log('📋 Loading from complete_details:', completeDetails);
			
			closingDetails = completeDetails;
			closingCounts = { ...completeDetails.closing_counts || {} };
			
			// Load supervisor info
			supervisorName = completeDetails.supervisor_name || '';
			supervisorCode = completeDetails.supervisor_code || '';
			
			// Load bank reconciliation
			madaAmount = completeDetails.bank_mada || '';
			visaAmount = completeDetails.bank_visa || '';
			masterCardAmount = completeDetails.bank_mastercard || '';
			googlePayAmount = completeDetails.bank_google_pay || '';
			otherAmount = completeDetails.bank_other || '';
			
			// Load ERP details
			systemCashSales = completeDetails.system_cash_sales || '';
			systemCardSales = completeDetails.system_card_sales || '';
			systemReturn = completeDetails.system_return || '';
			
			// Load recharge details
			openingBalance = completeDetails.recharge_opening_balance || '';
			closeBalance = completeDetails.recharge_close_balance || '';
			
			// Load supervisor confirm codes
			cashierConfirmCode = completeDetails.cashier_confirm_code || '';
			completedByName = completeDetails.completed_by_name || operation?.completed_by_name || '';
			cashierName = completeDetails.cashier_name || operation?.cashier_name || '';
			
			// Load branch info from multiple sources
			branchName = completeDetails.branch_name || operation?.branch?.name_en || operation?.branch?.name || branch?.name_en || branch?.name || operation?.branchName || '';
			
			startDateInput = completeDetails.recharge_transaction_start_date || '';
			startTimeInput = completeDetails.recharge_transaction_start_time || '';
			endDateInput = completeDetails.recharge_transaction_end_date || '';
			endTimeInput = completeDetails.recharge_transaction_end_time || '';
			
			// Parse time if available
			if (startTimeInput) {
				const [time, period] = startTimeInput.split(' ');
				const [hour, minute] = time.split(':');
				startHour = hour || '12';
				startMinute = minute || '00';
				startAmPm = period || 'AM';
			}
			if (endTimeInput) {
				const [time, period] = endTimeInput.split(' ');
				const [hour, minute] = time.split(':');
				endHour = hour || '12';
				endMinute = minute || '00';
				endAmPm = period || 'AM';
			}
			
			// Load vouchers
			vouchers = completeDetails.vouchers || [];
			
			// Load all edit and verification states from complete_details
			voucherEditedValues = completeDetails.voucher_edits || {};
			voucherVerified = completeDetails.voucher_verified || {};
			bankEditedValues = completeDetails.bank_edits || {};
			bankVerified = completeDetails.bank_verified || {};
			systemEditedValues = completeDetails.system_edits || {};
			systemVerified = completeDetails.system_verified || {};
			rechargeEditedValues = completeDetails.recharge_edits || {};
			rechargeVerified = completeDetails.recharge_verified || {};
			denomEditedValues = completeDetails.denom_edits || {};
			denomVerified = completeDetails.denom_verified || {};
			
			console.log('✅ Loaded ALL data from complete_details');
			
		} else if (operation?.closing_details) {
			// Fallback to closing_details if complete_details not available yet
			const details = typeof operation.closing_details === 'string' 
				? JSON.parse(operation.closing_details)
				: operation.closing_details;
			
			console.log('⚠️ Fallback: Loading from closing_details:', details);
			closingDetails = details;
			closingCounts = { ...details.closing_counts || {} };
			
			// Load all the same fields as above
			supervisorName = details.supervisor_name || operationData.supervisor_name || '';
			madaAmount = details.bank_mada || '';
			visaAmount = details.bank_visa || '';
			masterCardAmount = details.bank_mastercard || '';
			googlePayAmount = details.bank_google_pay || '';
			otherAmount = details.bank_other || '';
			systemCashSales = details.system_cash_sales || '';
			systemCardSales = details.system_card_sales || '';
			systemReturn = details.system_return || '';
			openingBalance = details.recharge_opening_balance || '';
			closeBalance = details.recharge_close_balance || '';
			startDateInput = details.recharge_transaction_start_date || '';
			startTimeInput = details.recharge_transaction_start_time || '';
			endDateInput = details.recharge_transaction_end_date || '';
			endTimeInput = details.recharge_transaction_end_time || '';
			
			// Parse loaded times
			if (startTimeInput) {
				const [time, period] = startTimeInput.split(' ');
				const [hour, minute] = time.split(':');
				startHour = hour || '12';
				startMinute = minute || '00';
				startAmPm = period || 'AM';
			}
			if (endTimeInput) {
				const [time, period] = endTimeInput.split(' ');
				const [hour, minute] = time.split(':');
				endHour = hour || '12';
				endMinute = minute || '00';
				endAmPm = period || 'AM';
			}
			
			vouchers = details.vouchers || [];
			
		} else if (operation?.counts_after) {
			// Fallback to counts_after if neither available
			closingCounts = { ...operation.counts_after };
			branchName = operation?.branch?.name || branch?.name || operation?.branchName || 'N/A';
			console.log('✅ Loaded closing counts from counts_after:', closingCounts);
		} else {
			// Initialize with zeros if no data available
			closingCounts = {};
			branchName = operation?.branch?.name || branch?.name || operation?.branchName || 'N/A';
			Object.keys(denomValues).forEach(key => {
				closingCounts[key] = 0;
			});
			console.log('⚠️ No closing data found, initialized with zeros');
		}
	
		hasInitializedCounts = true;
	}

	// Calculate total
	$: closingTotal = Object.keys(closingCounts).reduce((sum, key) => {
		const count = closingCounts[key] || 0;
		const denomValue = denomValues[key] || 0;
		return sum + (count * denomValue);
	}, 0);

	// Calculate cash sales (closing total - checked amount)
	$: cashSales = closingTotal - (operation?.total_after || 0);

	// Purchase vouchers
	let vouchers: Array<{serial: string, amount: number}> = [];
	let newVoucherSerial = '';
	let newVoucherAmount: number | '' = '';

	function addVoucher() {
		if (newVoucherSerial && newVoucherAmount) {
			// Check for duplicates (same serial and amount)
			const isDuplicate = vouchers.some(v => 
				v.serial === newVoucherSerial && v.amount === Number(newVoucherAmount)
			);
			
			if (isDuplicate) {
				alert('This voucher (same serial and amount) already exists!');
				return;
			}

			vouchers = [...vouchers, {
				serial: newVoucherSerial,
				amount: Number(newVoucherAmount)
			}];
			newVoucherSerial = '';
			newVoucherAmount = '';
		}
	}

	function removeVoucher(index: number) {
		vouchers = vouchers.filter((_, i) => i !== index);
	}

	// Calculate vouchers total
	$: vouchersTotal = vouchers.reduce((sum, v) => sum + v.amount, 0);

	// Calculate total cash sales (cash sales + vouchers - recharge sales)
	$: totalCashSales = (cashSales + vouchersTotal) - (Number(sales) || 0);

	// Bank reconciliation payment methods
	let madaAmount: number | '' = '';
	let visaAmount: number | '' = '';
	let masterCardAmount: number | '' = '';
	let googlePayAmount: number | '' = '';
	let otherAmount: number | '' = '';

	// Bank edit state tracking
	let bankVerified: Record<string, boolean> = {}; // Track verification status
	let bankEditMode: Record<string, boolean> = {}; // Track edit mode for each field
	let bankEditedValues: Record<string, number> = {}; // Store edited values

	// Save bank edits to closing_details
	async function saveBankData() {
		triggerAutoSave();
	}

	// Calculate bank reconciliation total using edited values
	$: bankTotal = (
		(Number(madaAmount) || 0) +
		(Number(visaAmount) || 0) +
		(Number(masterCardAmount) || 0) +
		(Number(googlePayAmount) || 0) +
		(Number(otherAmount) || 0)
	);

	// Calculate total sales (total cash sales + total bank sales)
	$: totalSales = totalCashSales + bankTotal;

	// System sales
	let systemCashSales: number | '' = '';
	let systemCardSales: number | '' = '';
	let systemReturn: number | '' = '';

	// System sales edit state tracking
	let systemVerified: Record<string, boolean> = {}; // Track verification status
	let systemEditMode: Record<string, boolean> = {}; // Track edit mode for each field
	let systemEditedValues: Record<string, number> = {}; // Store edited values

	// Save system sales edits to complete_details
	async function saveSystemData() {
		triggerAutoSave();
	}

	// Calculate system sales totals using edited values
	$: totalSystemCashSales = (
		(Number(systemCashSales) || 0) -
		(Number(systemReturn) || 0)
	);
	$: totalSystemSales = totalSystemCashSales + (Number(systemCardSales) || 0);

	// Time format conversion for 12-hour format
	let startDateInput = '';
	let startTimeInput = '';
	let startHour = '12';
	let startMinute = '00';
	let startAmPm = 'AM';
	let startHourOpen = false;
	let startMinuteOpen = false;

	let endDateInput = '';
	let endTimeInput = '';
	let endHour = '12';
	let endMinute = '00';
	let endAmPm = 'AM';
	let endHourOpen = false;
	let endMinuteOpen = false;

	// Recharge card balance fields
	let openingBalance: number | '' = '';
	let closeBalance: number | '' = '';
	let sales: number | '' = '';

	// Recharge card edit state tracking
	let rechargeVerified: Record<string, boolean> = {}; // Track verification status
	let rechargeEditMode: Record<string, boolean> = {}; // Track edit mode for each field
	let rechargeEditedValues: Record<string, number> = {}; // Store edited values

	// Save recharge card edits to closing_details
	async function saveRechargeData() {
		triggerAutoSave();
	}

	// Auto-calculate sales using base values (already updated)
	$: sales = (
		(Number(closeBalance) || 0) -
		(Number(openingBalance) || 0)
	);

	// Differences fields
	let differenceInCashSales: number = 0;
	let differenceInCardSales: number = 0;

	// Auto-calculate difference in cash sales (total cash sales - (system cash sales - returns))
	$: differenceInCashSales = Math.round((totalCashSales - ((Number(systemCashSales) || 0) - (Number(systemReturn) || 0))) * 100) / 100;

	// Auto-calculate difference in card sales (bank total - system card sales)
	$: differenceInCardSales = Math.round((bankTotal - (Number(systemCardSales) || 0)) * 100) / 100;

	// Auto-calculate total difference
	$: totalDifference = Math.round((differenceInCashSales + differenceInCardSales) * 100) / 100;

	// Entry to Pass - Automatic adjustment entries calculation
	let entryToPassData: any = {
		transfers: [],
		adjustments: [],
		cashReceipt: {
			value: 0,
			adjustment: 0,
			total: 0
		},
		bankReceipt: {
			value: 0,
			adjustment: 0,
			total: 0
		}
	};

	// Calculate required entries based on POS Cash and POS Bank balances
	$: {
		const posCashValue = Math.abs(differenceInCashSales);
		const posCashType = differenceInCashSales >= 0 ? 'DR' : 'CR';
		const posBankValue = Math.abs(differenceInCardSales);
		const posBankType = differenceInCardSales >= 0 ? 'DR' : 'CR';

		entryToPassData = {
			transfers: [],
			adjustments: [],
			cashReceipt: {
				value: posCashValue,
				adjustment: 0,
				total: totalCashSales
			},
			bankReceipt: {
				value: posBankValue,
				adjustment: 0,
				total: bankTotal
			}
		};

		// Logic: Handle all four DR/CR combinations
		if (posCashType === 'DR' && posBankType === 'CR') {
			// Cash has surplus (DR), Bank has deficit (CR)
			// Transfer from Cash to Bank
			const transferAmount = Math.min(posCashValue, posBankValue);
			entryToPassData.transfers.push({
				account: 'POS Cash → POS Bank',
				debitAccount: 'POS Bank',
				debitAmount: transferAmount,
				creditAccount: 'POS Cash',
				creditAmount: transferAmount
			});

			// Check remaining balances
			const remainingCash = posCashValue - transferAmount;
			const remainingBank = posBankValue - transferAmount;

			if (remainingCash > 0) {
				entryToPassData.adjustments.push({
					account: 'POS Excess Adjustment',
					debitAccount: 'POS Excess',
					debitAmount: remainingCash,
					creditAccount: 'POS Cash',
					creditAmount: remainingCash
				});
				entryToPassData.cashReceipt.adjustment = remainingCash;
			}

			if (remainingBank > 0) {
				entryToPassData.adjustments.push({
					account: 'POS Short Adjustment',
					debitAccount: 'POS Bank',
					debitAmount: remainingBank,
					creditAccount: 'POS Short',
					creditAmount: remainingBank
				});
				entryToPassData.bankReceipt.adjustment = remainingBank;

				// Add cashier salary entry if short is >= 5
				if (remainingBank >= 5) {
					entryToPassData.adjustments.push({
						account: 'POS Short to Cashier Salary',
						debitAccount: 'Cashier Salary Account',
						debitAmount: remainingBank,
						creditAccount: 'POS Short',
						creditAmount: remainingBank
					});
				} else {
					// Add note if short is less than 5
					entryToPassData.adjustments.push({
						account: 'POS Short Note',
						note: '⚠️ Short amount is less than 5 - No need to post to Cashier Salary Account'
					});
				}
			}
		} else if (posCashType === 'CR' && posBankType === 'DR') {
			// Cash has deficit (CR), Bank has surplus (DR)
			// Transfer from Bank to Cash
			const transferAmount = Math.min(posCashValue, posBankValue);
			entryToPassData.transfers.push({
				account: 'POS Bank → POS Cash',
				debitAccount: 'POS Cash',
				debitAmount: transferAmount,
				creditAccount: 'POS Bank',
				creditAmount: transferAmount
			});

			// Check remaining balances
			const remainingCash = posCashValue - transferAmount;
			const remainingBank = posBankValue - transferAmount;

			if (remainingCash > 0) {
				entryToPassData.adjustments.push({
					account: 'POS Short Adjustment',
					debitAccount: 'POS Short',
					debitAmount: remainingCash,
					creditAccount: 'POS Cash',
					creditAmount: remainingCash
				});
				entryToPassData.cashReceipt.adjustment = remainingCash;

				// Add cashier salary entry if short is >= 5
				if (remainingCash >= 5) {
					entryToPassData.adjustments.push({
						account: 'POS Short to Cashier Salary',
						debitAccount: 'Cashier Salary Account',
						debitAmount: remainingCash,
						creditAccount: 'POS Short',
						creditAmount: remainingCash
					});
				} else {
					// Add note if short is less than 5
					entryToPassData.adjustments.push({
						account: 'POS Short Note',
						note: '⚠️ Short amount is less than 5 - No need to post to Cashier Salary Account'
					});
				}
			}

			if (remainingBank > 0) {
				entryToPassData.adjustments.push({
					account: 'POS Excess Adjustment',
					debitAccount: 'POS Bank',
					debitAmount: remainingBank,
					creditAccount: 'POS Excess',
					creditAmount: remainingBank
				});
				entryToPassData.bankReceipt.adjustment = remainingBank;
			}
		} else if (posCashType === 'DR' && posBankType === 'DR') {
			// Both have surplus (both DR)
			// Cash to POS Excess, Bank to POS Excess
			entryToPassData.adjustments.push({
				account: 'POS Cash Excess Adjustment',
				debitAccount: 'POS Excess',
				debitAmount: posCashValue,
				creditAccount: 'POS Cash',
				creditAmount: posCashValue
			});
			entryToPassData.adjustments.push({
				account: 'POS Bank Excess Adjustment',
				debitAccount: 'POS Excess',
				debitAmount: posBankValue,
				creditAccount: 'POS Bank',
				creditAmount: posBankValue
			});
			entryToPassData.cashReceipt.adjustment = posCashValue;
			entryToPassData.bankReceipt.adjustment = posBankValue;
		} else if (posCashType === 'CR' && posBankType === 'CR') {
			// Both have deficit (both CR)
			// POS Short from both Cash and Bank
			entryToPassData.adjustments.push({
				account: 'POS Cash Short Adjustment',
				debitAccount: 'POS Short',
				debitAmount: posCashValue,
				creditAccount: 'POS Cash',
				creditAmount: posCashValue
			});
			entryToPassData.adjustments.push({
				account: 'POS Bank Short Adjustment',
				debitAccount: 'POS Short',
				debitAmount: posBankValue,
				creditAccount: 'POS Bank',
				creditAmount: posBankValue
			});
			entryToPassData.cashReceipt.adjustment = posCashValue;
			entryToPassData.bankReceipt.adjustment = posBankValue;
		}
	}

	// Supervisor code
	let supervisorCode: string = '';
	let supervisorName: string = '';
	let supervisorCodeError: string = '';
	
	// Cashier confirmation code
	let cashierConfirmCode: string = '';
	let cashierName: string = '';
	let branchName: string = '';
	let cashierConfirmName: string = '';
	let cashierConfirmError: string = '';
	
	let closingSaved: boolean = false;
	let closingStarted: boolean = false;
	let hasCheckedForCompleted: boolean = false;
	let hasFetchedUrl: boolean = false;
	let hasInitializedCounts: boolean = false;

	// Voucher status check
	let showVoucherStatusModal: boolean = false;
	let showPrintModal: boolean = false;
	let voucherStatusResults: Array<{serial: string, amount: number, status: string, found: boolean, voucherData?: any}> = [];
	let isCheckingVoucherStatus: boolean = false;
	
	// Ensure branch name is set from prop if not already loaded
	$: if (!branchName || branchName === 'N/A') {
		branchName = branch?.name_en || branch?.name || 'N/A';
	}
	
	// Print modal computed data
	$: cashierName = (operation?.notes ? (typeof operation.notes === 'string' ? JSON.parse(operation.notes) : operation.notes)?.cashier_name : operationData?.cashier_name) || '';
	$: posNumber = selectedPosNumber;
	$: supervisorCheckCode = (operation?.notes ? (typeof operation.notes === 'string' ? JSON.parse(operation.notes) : operation.notes)?.supervisor_name : operationData?.supervisor_name) || '';
	$: supervisorCloseCode = supervisorName || '';
	$: amountIssued = Number(operation?.total_before) || 0;
	$: amountChecked = Number(operation?.total_after) || 0;
	$: closingCashTotal = closingTotal;
	$: totalBankSales = bankTotal;
	$: closingDenominationList = Object.keys(closingCounts).map(key => ({
		name: denomLabels[key] || key,
		count: closingCounts[key] || 0,
		value: denomValues[key] || 0
	}));
	$: rechargeCardsList = [];
	$: vouchersList = vouchers || [];
	$: adjustmentsList = [];
	$: chequesAmount = 0;
	$: transferAmount = 0;
	$: supervisorCheckDate = operation?.created_at ? new Date(operation.created_at).toLocaleDateString() : '';
	$: supervisorCloseDate = operation?.updated_at ? new Date(operation.updated_at).toLocaleDateString() : '';
	$: completedByDate = new Date().toLocaleDateString() || '';
	$: totalVoucherAmount = vouchersTotal || 0;

	// Print template variables
	$: statusCashAmount = Math.abs(differenceInCashSales);
	$: statusBankAmount = Math.abs(differenceInCardSales);
	$: transferDrCash = entryToPassData?.transfers?.find(t => t.debitAccount?.includes('Cash'))?.debitAmount || 0;
	$: transferCrBank = entryToPassData?.transfers?.find(t => t.creditAccount?.includes('Bank'))?.creditAmount || 0;
	$: adjustmentDrShort = entryToPassData?.adjustments?.find(a => a.debitAccount?.includes('Short'))?.debitAmount || 0;
	$: adjustmentCrCash = entryToPassData?.adjustments?.find(a => a.creditAccount?.includes('Cash'))?.creditAmount || 0;
	$: totalCashReceipt = entryToPassData?.cashReceipt?.total || 0;
	$: totalBankReceipt = entryToPassData?.bankReceipt?.total || 0;

	// Function to check voucher status
	async function checkVoucherStatus() {
		if (vouchers.length === 0) {
			alert($currentLocale === 'ar' ? 'لا توجد قسائم للتحقق منها' : 'No vouchers to check');
			return;
		}

		isCheckingVoucherStatus = true;
		voucherStatusResults = [];

		try {
			// Check each voucher against purchase_voucher_items table, using edited values if available
			for (let index = 0; index < vouchers.length; index++) {
				const voucher = vouchers[index];
				
				// Use edited values if they exist, otherwise use original
				const serialToCheck = voucherEditedValues[index]?.serial !== undefined 
					? voucherEditedValues[index].serial 
					: voucher.serial;
				const amountToCheck = voucherEditedValues[index]?.amount !== undefined 
					? voucherEditedValues[index].amount 
					: voucher.amount;
				
				const { data, error } = await supabase
					.from('purchase_voucher_items')
					.select('*')
					.eq('serial_number', parseInt(serialToCheck))
					.eq('value', parseFloat(amountToCheck))
					.maybeSingle();

				if (error) {
					console.error('Error checking voucher:', error);
					voucherStatusResults.push({
						serial: serialToCheck,
						amount: amountToCheck,
						status: 'Error',
						found: false
					});
				} else if (data) {
					voucherStatusResults.push({
						serial: serialToCheck,
						amount: amountToCheck,
						status: data.status || 'Unknown',
						found: true,
						voucherData: data
					});
				} else {
					voucherStatusResults.push({
						serial: serialToCheck,
						amount: amountToCheck,
						status: 'Not Found',
						found: false
					});
				}
			}

			showVoucherStatusModal = true;
		} catch (error) {
			console.error('Exception checking voucher status:', error);
			alert($currentLocale === 'ar' ? 'خطأ في التحقق من حالة القسائم' : 'Error checking voucher status');
		} finally {
			isCheckingVoucherStatus = false;
		}
	}

	// Function to start closing process
	async function startClosingProcess() {
		if (!operation?.id) {
			alert('No operation found to close');
			return;
		}

		try {
			console.log('🔄 Starting closing process for operation:', operation.id);

			// Get branch name
			const currentBranchName = branch?.name_en || branch?.name || 'N/A';
			console.log('🏢 Saving branch name:', currentBranchName);

			// Get current user info
			const { data: { user } } = await supabase.auth.getUser();
			
			// Update box_operations with completed_by info and branch name
			const { error: updateError } = await supabase
				.from('box_operations')
				.update({
					completed_by_user_id: user?.id,
					completed_by_name: completedByName,
					complete_details: JSON.stringify({
						branch_name: currentBranchName
					})
				})
				.eq('id', operation.id);

			if (updateError) {
				console.error('❌ Error updating operation:', updateError);
				alert('Failed to start closing process: ' + updateError.message);
				return;
			}

			console.log('✅ Closing process started with branch name');
			
			// Set branch name locally
			branchName = currentBranchName;
			
			// Show the cards
			closingStarted = true;
			
			// Reinitialize closing counts from completed data
			initializeClosingCounts();
			
		} catch (error) {
			console.error('❌ Exception loading completed operation:', error);
		}
	}

	// Check if all checkboxes are verified
	$: allCheckboxesVerified = (() => {
		// Check denominations (11 denominations)
		const denomKeys = ['d500', 'd200', 'd100', 'd50', 'd20', 'd10', 'd5', 'd2', 'd1', 'd05', 'd025', 'coins'];
		const allDenomsVerified = denomKeys.every(key => denomVerified[key] === true);
		
		// Check vouchers (all vouchers must be verified)
		const allVouchersVerified = vouchers.length === 0 || vouchers.every((_, index) => voucherVerified[index] === true);
		
		// Check bank fields (5 fields)
		const bankKeys = ['mada', 'visa', 'mastercard', 'googlepay', 'other'];
		const allBankVerified = bankKeys.every(key => bankVerified[key] === true);
		
		// Check system fields (3 fields)
		const systemKeys = ['cashSales', 'cardSales', 'return'];
		const allSystemVerified = systemKeys.every(key => systemVerified[key] === true);
		
		// Check recharge fields (2 balance fields + 4 date/time fields)
		const rechargeKeys = ['openingBalance', 'closeBalance', 'startDate', 'startTime', 'endDate', 'endTime'];
		const allRechargeVerified = rechargeKeys.every(key => rechargeVerified[key] === true);
		
		return allDenomsVerified && allVouchersVerified && allBankVerified && allSystemVerified && allRechargeVerified;
	})();

	// Complete box operation
	async function completeBox() {
		if (!operation?.id) {
			alert('No operation found');
			return;
		}

		if (!allCheckboxesVerified) {
			alert($currentLocale === 'ar' ? 'يجب التحقق من جميع الحقول أولاً' : 'All fields must be verified first');
			return;
		}

		try {
			const { error } = await supabase
				.from('box_operations')
				.update({ status: 'completed' })
				.eq('id', operation.id);

			if (error) {
				console.error('Error completing box:', error);
				alert($currentLocale === 'ar' ? 'خطأ في إكمال الصندوق' : 'Error completing box');
			} else {
				console.log('✅ Box completed successfully');
				alert($currentLocale === 'ar' ? 'تم إكمال الصندوق بنجاح' : 'Box completed successfully');
				// Refresh operation data
				if (operation) {
					operation.status = 'completed';
				}
			}
		} catch (error) {
			console.error('Exception completing box:', error);
			alert($currentLocale === 'ar' ? 'خطأ في إكمال الصندوق' : 'Error completing box');
		}
	}

	// Add to denomination function
	async function addToDenomination() {
		console.log('🔍 Operation data:', {
			id: operation?.id,
			denomination_record_id: operation?.denomination_record_id,
			branch_id: operation?.branch_id,
			branch_object: branch
		});

		if (!operation?.id || !operation?.denomination_record_id) {
			alert($currentLocale === 'ar' ? 'معلومات العملية غير مكتملة' : 'Operation information incomplete');
			return;
		}

		// Get branch_id from operation or from branch prop
		const branchId = operation?.branch_id || branch?.id;
		if (!branchId) {
			alert($currentLocale === 'ar' ? 'معرف الفرع مفقود' : 'Branch ID missing');
			return;
		}

		try {
			// Parse closing_details to get closing_counts
			const closingDetails = typeof operation.closing_details === 'string' 
				? JSON.parse(operation.closing_details) 
				: operation.closing_details;

			const closingCounts = closingDetails?.closing_counts;
			if (!closingCounts) {
				alert($currentLocale === 'ar' ? 'لا توجد بيانات فئات للإضافة' : 'No denomination data to add');
				return;
			}

			console.log('📊 Closing counts to add:', closingCounts);

			// Step 1: Get the advance_box record and zero it out
			const { data: advanceBoxRecord, error: fetchError } = await supabase
				.from('denomination_records')
				.select('*')
				.eq('id', operation.denomination_record_id)
				.single();

			if (fetchError) {
				console.error('Error fetching advance box record:', fetchError);
				alert($currentLocale === 'ar' ? 'خطأ في جلب سجل الصندوق' : 'Error fetching box record');
				return;
			}

			console.log('📦 Advance box record:', advanceBoxRecord);

			// Zero out the advance box record
			const zeroCounts = {
				d1: 0, d2: 0, d5: 0, d05: 0, d10: 0, d20: 0, d50: 0, 
				d025: 0, d100: 0, d200: 0, d500: 0, coins: 0, damage: 0
			};

			console.log('🔄 Zeroing out advance box with counts:', zeroCounts);

			const { error: zeroError } = await supabase
				.from('denomination_records')
				.update({ 
					counts: zeroCounts,
					grand_total: '0.00',
					updated_at: new Date().toISOString()
				})
				.eq('id', operation.denomination_record_id);

			if (zeroError) {
				console.error('❌ Error zeroing advance box:', zeroError);
				alert($currentLocale === 'ar' ? 'خطأ في تصفير الصندوق' : 'Error zeroing box');
				return;
			}

			console.log('✅ Advance box zeroed out successfully');

			// Step 2: Get the main record for the branch
			const { data: mainRecord, error: mainFetchError } = await supabase
				.from('denomination_records')
				.select('*')
				.eq('branch_id', branchId)
				.eq('record_type', 'main')
				.single();

			if (mainFetchError) {
				console.error('Error fetching main record:', mainFetchError);
				alert($currentLocale === 'ar' ? 'خطأ في جلب السجل الرئيسي' : 'Error fetching main record');
				return;
			}

			console.log('📋 Main record:', mainRecord);

			// Step 3: Parse existing counts and add closing counts
			const existingCounts = typeof mainRecord.counts === 'string' 
				? JSON.parse(mainRecord.counts) 
				: mainRecord.counts;

			const newCounts = {
				d1: (existingCounts.d1 || 0) + (closingCounts.d1 || 0),
				d2: (existingCounts.d2 || 0) + (closingCounts.d2 || 0),
				d5: (existingCounts.d5 || 0) + (closingCounts.d5 || 0),
				d05: (existingCounts.d05 || 0) + (closingCounts.d05 || 0),
				d10: (existingCounts.d10 || 0) + (closingCounts.d10 || 0),
				d20: (existingCounts.d20 || 0) + (closingCounts.d20 || 0),
				d50: (existingCounts.d50 || 0) + (closingCounts.d50 || 0),
				d025: (existingCounts.d025 || 0) + (closingCounts.d025 || 0),
				d100: (existingCounts.d100 || 0) + (closingCounts.d100 || 0),
				d200: (existingCounts.d200 || 0) + (closingCounts.d200 || 0),
				d500: (existingCounts.d500 || 0) + (closingCounts.d500 || 0),
				coins: (existingCounts.coins || 0) + (closingCounts.coins || 0),
				damage: existingCounts.damage || 0
			};

			// Calculate new grand total
			const newGrandTotal = 
				newCounts.d500 * 500 + 
				newCounts.d200 * 200 + 
				newCounts.d100 * 100 + 
				newCounts.d50 * 50 + 
				newCounts.d20 * 20 + 
				newCounts.d10 * 10 + 
				newCounts.d5 * 5 + 
				newCounts.d2 * 2 + 
				newCounts.d1 * 1 + 
				newCounts.d05 * 0.5 + 
				newCounts.d025 * 0.25 + 
				newCounts.coins;

			console.log('➕ New counts:', newCounts);
			console.log('💰 New grand total:', newGrandTotal);

			// Step 4: Update the main record
			const { data: updateResult, error: updateError } = await supabase
				.from('denomination_records')
				.update({ 
					counts: newCounts,
					grand_total: newGrandTotal.toFixed(2),
					updated_at: new Date().toISOString()
				})
				.eq('id', mainRecord.id)
				.select();

			if (updateError) {
				console.error('❌ Error updating main record:', updateError);
				alert($currentLocale === 'ar' ? 'خطأ في تحديث السجل الرئيسي' : 'Error updating main record');
				return;
			}

			console.log('✅ Main record updated:', updateResult);
			console.log('✅ Denominations added to main record successfully');
			denominationsAdded = true;
			alert($currentLocale === 'ar' ? 'تم إضافة الفئات إلى السجل الرئيسي بنجاح' : 'Denominations added to main record successfully');

		} catch (error) {
			console.error('Exception in addToDenomination:', error);
			alert($currentLocale === 'ar' ? 'خطأ في إضافة الفئات' : 'Error adding denominations');
		}
	}

	async function verifySupervisorCode() {
		supervisorCodeError = '';
		supervisorName = '';

		if (!supervisorCode) {
			return;
		}

		// Get cashier name from operation notes
		let cashierName = '';
		try {
			if (operation?.notes) {
				const notes = typeof operation.notes === 'string' 
					? JSON.parse(operation.notes) 
					: operation.notes;
				cashierName = notes.cashier_name || '';
			}
		} catch (e) {
			// Ignore parsing errors
		}

		try {
			const { data, error } = await supabase
				.from('users')
				.select('username')
				.eq('quick_access_code', supervisorCode)
				.single();

			if (error) throw error;

			if (data) {
				const verifiedName = data.username || '';
				
				// Don't allow supervisor to be same person as cashier
				if (verifiedName === cashierName) {
					supervisorName = '';
					supervisorCodeError = 'Supervisor must be different from cashier';
					return;
				}
				
				supervisorName = verifiedName;
				supervisorCodeError = '';
			} else {
				supervisorName = '';
				supervisorCodeError = 'Invalid supervisor code';
			}
		} catch (error) {
			console.error('Error verifying supervisor code:', error);
			supervisorName = '';
			supervisorCodeError = 'Invalid supervisor code';
		}
	}

	// Auto-verify supervisor code as user types
	$: if (supervisorCode) {
		verifySupervisorCode();
	} else {
		supervisorName = '';
		supervisorCodeError = '';
	}

	async function verifyCashierConfirmCode() {
		cashierConfirmError = '';
		cashierConfirmName = '';

		if (!cashierConfirmCode) {
			return;
		}

		// Get cashier name and code from operation notes
		let expectedCashierName = '';
		let expectedCashierCode = '';
		try {
			if (operation?.notes) {
				const notes = typeof operation.notes === 'string' 
					? JSON.parse(operation.notes) 
					: operation.notes;
				expectedCashierName = notes.cashier_name || '';
				expectedCashierCode = notes.cashier_access_code || '';
			}
		} catch (e) {
			console.error('Error parsing operation notes:', e);
		}

		try {
			const { data, error } = await supabase
				.from('users')
				.select('username, quick_access_code')
				.eq('quick_access_code', cashierConfirmCode)
				.single();

			if (error) throw error;

			if (data) {
				const verifiedName = data.username || '';
				const verifiedCode = data.quick_access_code || '';
				
				// Must match the exact cashier who started
				if (verifiedCode !== expectedCashierCode || verifiedName !== expectedCashierName) {
					cashierConfirmName = '';
					cashierConfirmError = $currentLocale === 'ar' ? 'يجب أن يكون الكاشير نفس من بدأ العملية' : 'Must be the same cashier who started the operation';
					return;
				}
				
				cashierConfirmName = verifiedName;
				cashierConfirmError = '';
			} else {
				cashierConfirmName = '';
				cashierConfirmError = $currentLocale === 'ar' ? 'كود الكاشير غير صحيح' : 'Invalid cashier code';
			}
		} catch (error) {
			console.error('Error verifying cashier code:', error);
			cashierConfirmName = '';
			cashierConfirmError = $currentLocale === 'ar' ? 'كود الكاشير غير صحيح' : 'Invalid cashier code';
		}
	}

	// Auto-verify cashier code as user types
	$: if (cashierConfirmCode) {
		verifyCashierConfirmCode();
	} else {
		cashierConfirmName = '';
		cashierConfirmError = '';
	}

	async function saveSupervisorCode() {
		if (!supervisorName) {
			return;
		}

		try {
			// Get supervisor user ID
			const { data: supervisorData, error: supervisorError } = await supabase
				.from('users')
				.select('id')
				.eq('quick_access_code', supervisorCode)
				.single();

			if (supervisorError) throw supervisorError;
			const supervisorUserId = supervisorData?.id;

			// Prepare closing details
			const closingData = {
				supervisor_name: supervisorName,
				supervisor_id: supervisorUserId,
				closing_start_date: new Date().toISOString().split('T')[0],
				closing_start_time: startHour && startMinute ? `${startHour}:${startMinute} ${startAmPm}` : null,
				closing_end_date: new Date().toISOString().split('T')[0],
				closing_end_time: endHour && endMinute ? `${endHour}:${endMinute} ${endAmPm}` : null,
				
				// Recharge cards
				recharge_opening_balance: openingBalance || 0,
				recharge_close_balance: closeBalance || 0,
				recharge_sales: sales || 0,
				recharge_transaction_start_date: startDateInput,
				recharge_transaction_start_time: startTimeInput || `${startHour}:${startMinute} ${startAmPm}`,
				recharge_transaction_end_date: endDateInput,
				recharge_transaction_end_time: endTimeInput || `${endHour}:${endMinute} ${endAmPm}`,
				
				// Bank reconciliation
				bank_mada: madaAmount || 0,
				bank_visa: visaAmount || 0,
				bank_mastercard: masterCardAmount || 0,
				bank_google_pay: googlePayAmount || 0,
				bank_other: otherAmount || 0,
				bank_total: bankTotal,
				
				// ERP details
				system_cash_sales: systemCashSales || 0,
				system_card_sales: systemCardSales || 0,
				system_return: systemReturn || 0,
				
				// Differences
				difference_cash_sales: differenceInCashSales,
				difference_card_sales: differenceInCardSales,
				total_difference: totalDifference,
				
				// Sales totals
				total_cash_sales: totalCashSales,
				vouchers_total: vouchersTotal,
				total_system_cash_sales: totalSystemCashSales,
				total_sales: totalSales,
				total_system_sales: totalSystemSales
			};

			// Update box operation with closing details
			// First, try updating without status to isolate the issue
			const updatePayload = {
				closing_details: closingData,
				supervisor_id: supervisorUserId,
				supervisor_verified_at: new Date().toISOString(),
				end_time: new Date().toISOString(),
				// Also update individual fields for easy querying
				difference_cash_sales: differenceInCashSales,
				difference_card_sales: differenceInCardSales,
				total_difference: totalDifference,
				recharge_opening_balance: openingBalance || 0,
				recharge_close_balance: closeBalance || 0,
				recharge_sales: sales || 0,
				bank_mada: madaAmount || 0,
				bank_visa: visaAmount || 0,
				bank_mastercard: masterCardAmount || 0,
				bank_google_pay: googlePayAmount || 0,
				bank_other: otherAmount || 0,
				bank_total: bankTotal,
				system_cash_sales: systemCashSales || 0,
				system_card_sales: systemCardSales || 0,
				system_return: systemReturn || 0
			};

			const { error: updateError } = await supabase
				.from('box_operations')
				.update(updatePayload)
				.eq('id', operation.id);

			if (updateError) {
				console.error('Update error:', updateError);
				throw updateError;
			}

			console.log('Closing box details saved successfully');

			// Copy all closing_details to complete_details for editing
			const completeDetailsPayload = {
				...closingData,
				closing_counts: closingCounts,
				vouchers: vouchers,
				// Initialize verification states
				denom_verified: {},
				voucher_verified: {},
				bank_verified: {},
				system_verified: {},
				recharge_verified: {},
				// Initialize edit tracking
				denom_edits: {},
				voucher_edits: {},
				bank_edits: {},
				system_edits: {},
				recharge_edits: {},
				date_time_edits: {}
			};

			await supabase
				.from('box_operations')
				.update({ complete_details: completeDetailsPayload })
				.eq('id', operation.id);

			console.log('✅ Copied closing_details to complete_details for editing');

			// Now try to update the status separately
			// Include updated_at in the update to ensure trigger fires
			const { error: statusError } = await supabase
				.from('box_operations')
				.update({ 
					status: 'pending_close',
					updated_at: new Date().toISOString()
				})
				.eq('id', operation.id);

			if (statusError) {
				console.error('Status update error:', statusError);
				console.error('Status error code:', statusError.code);
				console.error('Status error message:', statusError.message);
				// Don't throw - the details were saved, just status update failed
				// Try alternative: use raw SQL via RPC if available
			} else {
				console.log('Status updated to pending_close');
			}

			closingSaved = true;
			
			// Show success message
			alert('Box closing saved! Pending final close from POS Collection Manager');
		} catch (error) {
			console.error('Error saving closing box:', error);
			supervisorCodeError = 'Error saving closing box: ' + (error.message || 'Unknown error');
		}
	}

	const hours = Array.from({ length: 12 }, (_, i) => (i + 1).toString().padStart(2, '0'));
	const minutes = Array.from({ length: 60 }, (_, i) => i.toString().padStart(2, '0'));

	function updateStartTime() {
		startTimeInput = `${startHour}:${startMinute} ${startAmPm}`;
	}

	function updateEndTime() {
		endTimeInput = `${endHour}:${endMinute} ${endAmPm}`;
	}

	// Quick access code for completed by
	let completedByCode: string = '';
	let completedByName: string = '';
	let completedByCodeError: string = '';

	// Verify quick access code
	async function verifyCompletedByCode() {
		completedByCodeError = '';
		completedByName = '';

		if (!completedByCode) {
			return;
		}

		try {
			console.log('🔍 Verifying completed by code:', completedByCode);
			const { data, error } = await supabase
				.from('users')
				.select('username, quick_access_code')
				.eq('quick_access_code', completedByCode)
				.maybeSingle();

			if (error) {
				console.error('Error verifying code:', error);
				completedByCodeError = 'Error verifying code';
			} else if (data?.username) {
				completedByName = data.username;
				console.log('✅ Code verified for:', completedByName);
			} else {
				// No match found, silently wait for more input
				console.log('⏳ Code incomplete or not found');
			}
		} catch (error) {
			console.error('Exception verifying code:', error);
			completedByCodeError = 'Error verifying code';
		}
	}

	// Auto-verify completed by code as user types
	$: if (completedByCode) {
		verifyCompletedByCode();
	} else {
		completedByName = '';
		completedByCodeError = '';
	}

	// Modal for viewing POS image
	let showImageModal = false;
	let imageUrl = '';

	function openImageModal() {
		if (posBeforeUrl) {
			// Open image in a new browser window
			window.open(posBeforeUrl, 'POS_Closing_Image', 'width=1024,height=768,resizable=yes,scrollbars=yes');
		} else {
			alert($currentLocale === 'ar' ? 'لا توجد صورة متاحة' : 'No image available');
		}
	}

	function closeImageModal() {
		showImageModal = false;
		imageUrl = '';
	}

	// Check if closing image URL exists - validate from posBeforeUrl
	$: hasClosingImage = !!(posBeforeUrl && typeof posBeforeUrl === 'string' && posBeforeUrl.length > 0);

	// Debug log
	$: console.log('📸 Image URL check:', { url: posBeforeUrl, hasImage: hasClosingImage });
</script>

<div class="close-box-container">
	<div class="button-row">
		<button 
			class="view-closing-btn" 
			on:click={openImageModal}
			disabled={!hasClosingImage}
			title={hasClosingImage ? '' : ($currentLocale === 'ar' ? 'لا توجد صورة محفوظة' : 'No saved image')}
		>
			{$currentLocale === 'ar' ? 'عرض الإغلاق' : 'View Closing'}
		</button>
		<div class="completed-by-wrapper">
			<input 
				type="password" 
				class="completed-by-code-input"
				bind:value={completedByCode}
				disabled={closingStarted}
				placeholder={$currentLocale === 'ar' ? 'أدخل رمز الوصول السريع' : 'Enter your quick access code'}
			/>
			{#if completedByName}
				<div class="completed-by-name">
					{completedByName}
				</div>
			{/if}
			{#if completedByCodeError}
				<div class="completed-by-error">
					{completedByCodeError}
				</div>
			{/if}
		</div>
		<div style="display: flex; gap: 0.5rem;">
			<button 
				class="start-closing-btn" 
				disabled={!completedByName || closingStarted}
				on:click={startClosingProcess}
				title={!completedByName ? ($currentLocale === 'ar' ? 'تحقق من رمز الوصول السريع أولاً' : 'Verify quick access code first') : closingStarted ? ($currentLocale === 'ar' ? 'تم بدء الإغلاق' : 'Closing started') : ''}
			>
				{closingStarted ? ($currentLocale === 'ar' ? '✓ تم البدء' : '✓ Started') : ($currentLocale === 'ar' ? 'بدء الإغلاق' : 'Start Closing')}
			</button>
			<button 
				class="add-to-denomination-btn"
				disabled={!closingStarted || !allCheckboxesVerified || denominationsAdded}
				on:click={addToDenomination}
				title={!closingStarted ? ($currentLocale === 'ar' ? 'يجب بدء الإغلاق أولاً' : 'Must start closing first') : !allCheckboxesVerified ? ($currentLocale === 'ar' ? 'يجب التحقق من جميع الحقول أولاً' : 'All fields must be verified first') : denominationsAdded ? ($currentLocale === 'ar' ? 'تمت الإضافة' : 'Already added') : ''}
			>
				{denominationsAdded ? ($currentLocale === 'ar' ? '✓ تمت الإضافة' : '✓ Added') : ($currentLocale === 'ar' ? 'إضافة إلى الفئات' : 'Add to Denomination')}
			</button>
			<button 
				class="complete-btn"
				disabled={!closingStarted || !allCheckboxesVerified || !denominationsAdded || operation?.status === 'completed'}
				on:click={completeBox}
				title={!closingStarted ? ($currentLocale === 'ar' ? 'يجب بدء الإغلاق أولاً' : 'Must start closing first') : !allCheckboxesVerified ? ($currentLocale === 'ar' ? 'يجب التحقق من جميع الحقول أولاً' : 'All fields must be verified first') : !denominationsAdded ? ($currentLocale === 'ar' ? 'يجب إضافة الفئات أولاً' : 'Must add to denomination first') : operation?.status === 'completed' ? ($currentLocale === 'ar' ? 'تم الإكمال' : 'Completed') : ''}
			>
				{operation?.status === 'completed' ? ($currentLocale === 'ar' ? '✓ مكتمل' : '✓ Completed') : ($currentLocale === 'ar' ? 'إكمال' : 'Complete')}
			</button>
		</div>
	</div>

	<div class="top-info-row">
		<div class="info-group">
			<span class="info-label">{$currentLocale === 'ar' ? 'الكاشير (بدأ):' : 'Cashier (Started):'}</span>
			<span class="info-value">{operationData.cashier_name || 'N/A'}</span>
		</div>
		<div class="info-group">
			<span class="info-label">{$currentLocale === 'ar' ? 'المشرف (فحص):' : 'Supervisor (Checked):'}</span>
			<span class="info-value">{operationData.supervisor_name || 'N/A'}</span>
		</div>
		<div class="info-group">
			<span class="info-label">{$currentLocale === 'ar' ? 'المبلغ الصادر:' : 'Amount Issued:'}</span>
			<div class="info-value">
				<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
				<span>{(operation?.total_before || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
			</div>
		</div>
		<div class="info-group">
			<span class="info-label">{$currentLocale === 'ar' ? 'المبلغ المفحوص:' : 'Amount Checked:'}</span>
			<div class="info-value">
				<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
				<span>{(operation?.total_after || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
			</div>
		</div>
		<div class="info-group">
			<span class="info-label">{$currentLocale === 'ar' ? 'رقم نقطة البيع:' : 'POS Number:'}</span>
			<div class="pos-display-inline">POS {selectedPosNumber}</div>
		</div>
	</div>

	{#if closingStarted}
	<div class="two-cards-row">
		<div class="half-card split-card">
			<div class="split-section">
				<div class="card-header-text">{$currentLocale === 'ar' ? '1. تفاصيل الإغلاق المدخلة' : '1. Closing Details Entered'}</div>
				<div class="closing-cash-grid-2row">
					{#each Object.entries(denomLabels) as [key, label] (key)}
						<div class="denom-input-group">
							<div class="denom-label-with-checkbox">
								<label>
									{#if label !== 'Coins'}
										<span>{label}</span>
										<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
									{:else}
										{label}
									{/if}
								</label>
								<input
									type="checkbox"
									class="denom-verify-checkbox"
									bind:checked={denomVerified[key]}
									disabled={!closingStarted}
								/>
							</div>
							<div class="denom-input-wrapper">
								<input
									type="number"
									min="0"
									readonly={!denomEditMode[key]}
									class:denom-edited={denomEditedValues[key] !== undefined}
									value={denomEditedValues[key] !== undefined ? denomEditedValues[key] : (closingCounts[key] || '')}
									on:dblclick={() => {
										if (closingStarted) {
											denomEditMode[key] = true;
											denomEditMode = denomEditMode;
										}
									}}
									on:blur={(e) => {
										if (denomEditMode[key]) {
											const newValue = parseFloat(e.currentTarget.value) || 0;
											denomEditedValues[key] = newValue;
											denomEditedValues = denomEditedValues;
											closingCounts[key] = newValue; // Update base value
											closingCounts = closingCounts;
											denomEditMode[key] = false;
											denomEditMode = denomEditMode;
											saveDenomEdits();
										}
									}}
									on:keydown={(e) => {
										if (e.key === 'Enter' && denomEditMode[key]) {
											e.currentTarget.blur();
										}
									}}
								/>
								<div class="denom-values-display">
									{#if denomEditedValues[key] !== undefined && closingCounts[key]}
										<div class="denom-original-value">
											<span class="original-label">Original:</span>
											<span class="original-count">{closingCounts[key]}</span>
										</div>
									{/if}
									{#if (denomEditedValues[key] !== undefined ? denomEditedValues[key] : closingCounts[key]) > 0}
										<div class="denom-total">
											<img src={currencySymbolUrl} alt="SAR" class="currency-icon-tiny" />
											{((denomEditedValues[key] !== undefined ? denomEditedValues[key] : (closingCounts[key] || 0)) * denomValues[key]).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
										</div>
									{/if}
								</div>
							</div>
						</div>
					{/each}
				</div>
				<div class="closing-total">
					<span class="label">{$currentLocale === 'ar' ? 'إجمالي النقد الإغلاق:' : 'Closing Cash Total:'}</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{closingTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
				<div class="cash-sales">
					<span class="label">{$currentLocale === 'ar' ? 'المبيعات النقدية (حسب عد الإغلاق):' : 'Cash Sales (as per Closing Count):'}</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{cashSales.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
				<div class="total-cash-sales">
					<span class="label">{$currentLocale === 'ar' ? 'إجمالي المبيعات النقدية:' : 'Total Cash Sales:'}</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{totalCashSales.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
				<div class="total-bank-sales">
					<span class="label">{$currentLocale === 'ar' ? 'إجمالي المبيعات البنكية:' : 'Total Bank Sales:'}</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{bankTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
				<div class="total-sales">
					<span class="label">{$currentLocale === 'ar' ? 'إجمالي المبيعات:' : 'Total Sales:'}</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{totalSales.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
			</div>
			<div class="split-section">
				<div class="card-header-text">{$currentLocale === 'ar' ? '2. المبيعات عبر قسيمة الشراء' : '2. Sales through Purchase Voucher'}</div>
				
				<!-- Input row hidden for read-only view -->

				{#if vouchers.length > 0}
					<button 
						class="check-status-btn" 
						on:click={checkVoucherStatus}
						disabled={isCheckingVoucherStatus}
					>
						{#if isCheckingVoucherStatus}
							{$currentLocale === 'ar' ? 'جاري التحقق...' : 'Checking...'}
						{:else}
							{$currentLocale === 'ar' ? '✓ التحقق من الحالة' : '✓ Check Status'}
						{/if}
					</button>

					<div class="vouchers-table">
						<table>
							<thead>
								<tr>
									<th style="width: 40px;">✓</th>
									<th>{$currentLocale === 'ar' ? 'الرقم التسلسلي' : 'Serial'}</th>
									<th>{$currentLocale === 'ar' ? 'المبلغ' : 'Amount'}</th>
								</tr>
							</thead>
							<tbody>
								{#each vouchers as voucher, index (index)}
									<tr>
										<td style="width: 40px; text-align: center;">
											<input
												type="checkbox"
												class="voucher-verify-checkbox"
												bind:checked={voucherVerified[index]}
												on:change={() => saveVoucherData()}
												disabled={!closingStarted}
											/>
										</td>
										<td>
											<div class="voucher-cell-wrapper">
												<input
													type="text"
													class="voucher-editable-input"
													class:voucher-edited={voucherEditedValues[index]?.serial !== undefined}
													readonly={!voucherEditMode[index]?.serial}
													value={voucherEditedValues[index]?.serial !== undefined ? voucherEditedValues[index].serial : voucher.serial}
													on:dblclick={() => {
														if (closingStarted) {
															if (!voucherEditMode[index]) voucherEditMode[index] = { serial: false, amount: false };
															voucherEditMode[index].serial = true;
															voucherEditMode = voucherEditMode;
														}
													}}
													on:blur={(e) => {
														if (voucherEditMode[index]?.serial) {
															const newValue = e.currentTarget.value;
															if (!voucherEditedValues[index]) voucherEditedValues[index] = {};
															voucherEditedValues[index].serial = newValue;
															voucherEditedValues = voucherEditedValues;
																vouchers[index].serial = newValue; // Update base value
																vouchers = vouchers;
															voucherEditMode[index].serial = false;
															voucherEditMode = voucherEditMode;
															saveVoucherData();
														}
													}}
													on:keydown={(e) => {
														if (e.key === 'Enter' && voucherEditMode[index]?.serial) {
															e.currentTarget.blur();
														}
													}}
												/>
												{#if voucherEditedValues[index]?.serial !== undefined}
													<div class="voucher-original-value">
														<span class="original-label">Original:</span>
														<span class="original-value">{voucher.serial}</span>
													</div>
												{/if}
											</div>
										</td>
										<td>
											<div class="voucher-cell-wrapper">
												<div class="voucher-amount-display">
													<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
													<input
														type="number"
														class="voucher-editable-input voucher-amount-input"
														class:voucher-edited={voucherEditedValues[index]?.amount !== undefined}
														readonly={!voucherEditMode[index]?.amount}
														value={voucherEditedValues[index]?.amount !== undefined ? voucherEditedValues[index].amount : voucher.amount}
														on:dblclick={() => {
															if (closingStarted) {
																if (!voucherEditMode[index]) voucherEditMode[index] = { serial: false, amount: false };
																voucherEditMode[index].amount = true;
																voucherEditMode = voucherEditMode;
															}
														}}
														on:blur={(e) => {
															if (voucherEditMode[index]?.amount) {
																const newValue = parseFloat(e.currentTarget.value) || 0;
																if (!voucherEditedValues[index]) voucherEditedValues[index] = {};
																voucherEditedValues[index].amount = newValue;
																voucherEditedValues = voucherEditedValues;
																		vouchers[index].amount = newValue; // Update base value
																		vouchers = vouchers;
																voucherEditMode[index].amount = false;
																voucherEditMode = voucherEditMode;
																saveVoucherData();
															}
														}}
														on:keydown={(e) => {
															if (e.key === 'Enter' && voucherEditMode[index]?.amount) {
																e.currentTarget.blur();
															}
														}}
													/>
												</div>
												{#if voucherEditedValues[index]?.amount !== undefined}
													<div class="voucher-original-value">
														<span class="original-label">Original:</span>
														<span class="original-value">{voucher.amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
													</div>
												{/if}
											</div>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>

					<div class="vouchers-total">
						<span class="label">{$currentLocale === 'ar' ? 'إجمالي القسائم:' : 'Vouchers Total:'}</span>
						<div class="amount">
							<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
							<span>{vouchersTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
						</div>
					</div>
				{/if}
			</div>
			<div class="split-section">
				<div class="card-header-text">{$currentLocale === 'ar' ? '3. تسوية البنك' : '3. Bank Reconciliation'}</div>
				
				<div class="bank-fields-row">
					<!-- Mada -->
					<div class="bank-input-group">
						<div class="bank-field-header">
							<input
								type="checkbox"
								bind:checked={bankVerified['mada']}
								on:change={saveBankData}
								class="bank-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'مدى' : 'Mada'}</label>
						</div>
						<div class="bank-amount-display">
							<input
								type="number"
								value={bankEditedValues['mada'] !== undefined ? bankEditedValues['mada'] : madaAmount}
								readonly={!bankEditMode['mada']}
								min="0"
								step="0.01"
								class="bank-editable-input {bankEditedValues['mada'] !== undefined ? 'bank-edited' : ''}"
								on:dblclick={() => {
									bankEditMode['mada'] = true;
									bankEditMode = {...bankEditMode};
								}}
								on:blur={(e) => {
									const newValue = parseFloat(e.currentTarget.value) || 0;
									if (newValue !== (Number(madaAmount) || 0)) {
										bankEditedValues['mada'] = newValue;
							madaAmount = newValue; // Update base value
										saveBankData();
									}
									bankEditMode['mada'] = false;
									bankEditMode = {...bankEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && bankEditMode['mada']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if bankEditedValues['mada'] !== undefined}
								<div class="bank-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{(Number(madaAmount) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
								</div>
							{/if}
						</div>
					</div>

					<!-- Visa -->
					<div class="bank-input-group">
						<div class="bank-field-header">
							<input
								type="checkbox"
								bind:checked={bankVerified['visa']}
								on:change={saveBankData}
								class="bank-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'فيزا' : 'Visa'}</label>
						</div>
						<div class="bank-amount-display">
							<input
								type="number"
								value={bankEditedValues['visa'] !== undefined ? bankEditedValues['visa'] : visaAmount}
								readonly={!bankEditMode['visa']}
								min="0"
								step="0.01"
								class="bank-editable-input {bankEditedValues['visa'] !== undefined ? 'bank-edited' : ''}"
								on:dblclick={() => {
									bankEditMode['visa'] = true;
									bankEditMode = {...bankEditMode};
								}}
								on:blur={(e) => {
									const newValue = parseFloat(e.currentTarget.value) || 0;
									if (newValue !== (Number(visaAmount) || 0)) {
										bankEditedValues['visa'] = newValue;
							visaAmount = newValue; // Update base value
										saveBankData();
									}
									bankEditMode['visa'] = false;
									bankEditMode = {...bankEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && bankEditMode['visa']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if bankEditedValues['visa'] !== undefined}
								<div class="bank-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{(Number(visaAmount) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
								</div>
							{/if}
						</div>
					</div>

					<!-- MasterCard -->
					<div class="bank-input-group">
						<div class="bank-field-header">
							<input
								type="checkbox"
								bind:checked={bankVerified['mastercard']}
								on:change={saveBankData}
								class="bank-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'ماستر كارد' : 'MasterCard'}</label>
						</div>
						<div class="bank-amount-display">
							<input
								type="number"
								value={bankEditedValues['mastercard'] !== undefined ? bankEditedValues['mastercard'] : masterCardAmount}
								readonly={!bankEditMode['mastercard']}
								min="0"
								step="0.01"
								class="bank-editable-input {bankEditedValues['mastercard'] !== undefined ? 'bank-edited' : ''}"
								on:dblclick={() => {
									bankEditMode['mastercard'] = true;
									bankEditMode = {...bankEditMode};
								}}
								on:blur={(e) => {
									const newValue = parseFloat(e.currentTarget.value) || 0;
									if (newValue !== (Number(masterCardAmount) || 0)) {
										bankEditedValues['mastercard'] = newValue;
							masterCardAmount = newValue; // Update base value
										saveBankData();
									}
									bankEditMode['mastercard'] = false;
									bankEditMode = {...bankEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && bankEditMode['mastercard']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if bankEditedValues['mastercard'] !== undefined}
								<div class="bank-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{(Number(masterCardAmount) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
								</div>
							{/if}
						</div>
					</div>

					<!-- Google Pay -->
					<div class="bank-input-group">
						<div class="bank-field-header">
							<input
								type="checkbox"
								bind:checked={bankVerified['googlepay']}
								on:change={saveBankData}
								class="bank-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'جوجل باي' : 'Google Pay'}</label>
						</div>
						<div class="bank-amount-display">
							<input
								type="number"
								value={bankEditedValues['googlepay'] !== undefined ? bankEditedValues['googlepay'] : googlePayAmount}
								readonly={!bankEditMode['googlepay']}
								min="0"
								step="0.01"
								class="bank-editable-input {bankEditedValues['googlepay'] !== undefined ? 'bank-edited' : ''}"
								on:dblclick={() => {
									bankEditMode['googlepay'] = true;
									bankEditMode = {...bankEditMode};
								}}
								on:blur={(e) => {
									const newValue = parseFloat(e.currentTarget.value) || 0;
									if (newValue !== (Number(googlePayAmount) || 0)) {
										bankEditedValues['googlepay'] = newValue;
							googlePayAmount = newValue; // Update base value
										saveBankData();
									}
									bankEditMode['googlepay'] = false;
									bankEditMode = {...bankEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && bankEditMode['googlepay']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if bankEditedValues['googlepay'] !== undefined}
								<div class="bank-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{(Number(googlePayAmount) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
								</div>
							{/if}
						</div>
					</div>

					<!-- Other -->
					<div class="bank-input-group">
						<div class="bank-field-header">
							<input
								type="checkbox"
								bind:checked={bankVerified['other']}
								on:change={saveBankData}
								class="bank-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'أخرى' : 'Other'}</label>
						</div>
						<div class="bank-amount-display">
							<input
								type="number"
								value={bankEditedValues['other'] !== undefined ? bankEditedValues['other'] : otherAmount}
								readonly={!bankEditMode['other']}
								min="0"
								step="0.01"
								class="bank-editable-input {bankEditedValues['other'] !== undefined ? 'bank-edited' : ''}"
								on:dblclick={() => {
									bankEditMode['other'] = true;
									bankEditMode = {...bankEditMode};
								}}
								on:blur={(e) => {
									const newValue = parseFloat(e.currentTarget.value) || 0;
									if (newValue !== (Number(otherAmount) || 0)) {
										bankEditedValues['other'] = newValue;
							otherAmount = newValue; // Update base value
										saveBankData();
									}
									bankEditMode['other'] = false;
									bankEditMode = {...bankEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && bankEditMode['other']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if bankEditedValues['other'] !== undefined}
								<div class="bank-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{(Number(otherAmount) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
								</div>
							{/if}
						</div>
					</div>
				</div>

				<div class="bank-total">
					<span class="label">{$currentLocale === 'ar' ? 'إجمالي البنك:' : 'Bank Total:'}</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{bankTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
			</div>
			<div class="split-section erp-closing-section">
				<div class="card-header-text">{$currentLocale === 'ar' ? '4. تفاصيل إغلاق النظام' : '4. ERP Closing Details'}</div>
				
				<div class="system-sales-row">
					<!-- Cash Sales -->
					<div class="system-input-group">
						<div class="system-field-header">
							<input
								type="checkbox"
								bind:checked={systemVerified['cashSales']}
								on:change={saveSystemData}
								class="system-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'المبيعات النقدية' : 'Cash Sales'}</label>
						</div>
						<div class="system-amount-display">
							<input
								type="number"
								value={systemEditedValues['cashSales'] !== undefined ? systemEditedValues['cashSales'] : systemCashSales}
								readonly={!systemEditMode['cashSales']}
								min="0"
								step="0.01"
								class="system-editable-input {systemEditedValues['cashSales'] !== undefined ? 'system-edited' : ''}"
								on:dblclick={() => {
									systemEditMode['cashSales'] = true;
									systemEditMode = {...systemEditMode};
								}}
								on:blur={(e) => {
									const newValue = parseFloat(e.currentTarget.value) || 0;
									if (newValue !== (Number(systemCashSales) || 0)) {
										systemEditedValues['cashSales'] = newValue;
								systemCashSales = newValue; // Update base value
										saveSystemData();
									}
									systemEditMode['cashSales'] = false;
									systemEditMode = {...systemEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && systemEditMode['cashSales']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if systemEditedValues['cashSales'] !== undefined}
								<div class="system-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{(Number(systemCashSales) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
								</div>
							{/if}
						</div>
					</div>

					<!-- Card Sales -->
					<div class="system-input-group">
						<div class="system-field-header">
							<input
								type="checkbox"
								bind:checked={systemVerified['cardSales']}
								on:change={saveSystemData}
								class="system-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'مبيعات البطاقة' : 'Card Sales'}</label>
						</div>
						<div class="system-amount-display">
							<input
								type="number"
								value={systemEditedValues['cardSales'] !== undefined ? systemEditedValues['cardSales'] : systemCardSales}
								readonly={!systemEditMode['cardSales']}
								min="0"
								step="0.01"
								class="system-editable-input {systemEditedValues['cardSales'] !== undefined ? 'system-edited' : ''}"
								on:dblclick={() => {
									systemEditMode['cardSales'] = true;
									systemEditMode = {...systemEditMode};
								}}
								on:blur={(e) => {
									const newValue = parseFloat(e.currentTarget.value) || 0;
									if (newValue !== (Number(systemCardSales) || 0)) {
										systemEditedValues['cardSales'] = newValue;
								systemCardSales = newValue; // Update base value
										saveSystemData();
									}
									systemEditMode['cardSales'] = false;
									systemEditMode = {...systemEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && systemEditMode['cardSales']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if systemEditedValues['cardSales'] !== undefined}
								<div class="system-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{(Number(systemCardSales) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
								</div>
							{/if}
						</div>
					</div>

					<!-- Return -->
					<div class="system-input-group">
						<div class="system-field-header">
							<input
								type="checkbox"
								bind:checked={systemVerified['return']}
								on:change={saveSystemData}
								class="system-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'المرتجعات' : 'Return'}</label>
						</div>
						<div class="system-amount-display">
							<input
								type="number"
								value={systemEditedValues['return'] !== undefined ? systemEditedValues['return'] : systemReturn}
								readonly={!systemEditMode['return']}
								min="0"
								step="0.01"
								class="system-editable-input {systemEditedValues['return'] !== undefined ? 'system-edited' : ''}"
								on:dblclick={() => {
									systemEditMode['return'] = true;
									systemEditMode = {...systemEditMode};
								}}
								on:blur={(e) => {
									const newValue = parseFloat(e.currentTarget.value) || 0;
									if (newValue !== (Number(systemReturn) || 0)) {
										systemEditedValues['return'] = newValue;
								systemReturn = newValue; // Update base value
										saveSystemData();
									}
									systemEditMode['return'] = false;
									systemEditMode = {...systemEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && systemEditMode['return']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if systemEditedValues['return'] !== undefined}
								<div class="system-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{(Number(systemReturn) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
								</div>
							{/if}
						</div>
					</div>
				</div>

				<div class="system-total-1">
					<span class="label">{$currentLocale === 'ar' ? 'إجمالي المبيعات النقدية للنظام:' : 'Total ERP Cash Sales:'}</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{totalSystemCashSales.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>

				<div class="system-total-2">
					<span class="label">{$currentLocale === 'ar' ? 'إجمالي مبيعات النظام:' : 'Total ERP Sales:'}</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{totalSystemSales.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
			</div>
			<div class="split-section recharge-card-section-11">
				<div class="card-header-text">{$currentLocale === 'ar' ? '5. بطاقات الشحن' : '5. Recharge Cards'}</div>
				
				<div class="date-time-row">
					<!-- Start Date -->
					<div class="date-time-group">
						<div class="datetime-field-header">
							<input
								type="checkbox"
								bind:checked={rechargeVerified['startDate']}
								on:change={saveRechargeData}
								class="datetime-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'تاريخ البدء' : 'Start Date'}</label>
						</div>
						<div class="datetime-input-display">
							<input 
								type="date" 
								class="datetime-editable-input {rechargeEditedValues['startDate'] !== undefined ? 'datetime-edited' : ''}" 
								value={rechargeEditedValues['startDate'] !== undefined ? rechargeEditedValues['startDate'] : startDateInput}
								readonly={!rechargeEditMode['startDate']}
								on:dblclick={() => {
									rechargeEditMode['startDate'] = true;
									rechargeEditMode = {...rechargeEditMode};
								}}
								on:blur={(e) => {
									const newValue = e.currentTarget.value;
									if (newValue !== startDateInput) {
										rechargeEditedValues['startDate'] = newValue;
								startDateInput = newValue; // Update base value
										saveRechargeData();
									}
									rechargeEditMode['startDate'] = false;
									rechargeEditMode = {...rechargeEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && rechargeEditMode['startDate']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if rechargeEditedValues['startDate'] !== undefined}
								<div class="datetime-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{startDateInput || 'N/A'}</span>
								</div>
							{/if}
						</div>
					</div>

					<!-- Start Time -->
					<div class="date-time-group">
						<div class="datetime-field-header">
							<input
								type="checkbox"
								bind:checked={rechargeVerified['startTime']}
								on:change={saveRechargeData}
								class="datetime-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'وقت البدء' : 'Start Time'}</label>
						</div>
						<div class="datetime-input-display">
							<input 
								type="text" 
								class="datetime-editable-input {rechargeEditedValues['startTime'] !== undefined ? 'datetime-edited' : ''}" 
								value={rechargeEditedValues['startTime'] !== undefined ? rechargeEditedValues['startTime'] : `${startHour}:${startMinute} ${startAmPm}`}
								readonly={!rechargeEditMode['startTime']}
								placeholder="HH:MM AM/PM"
								on:dblclick={() => {
									rechargeEditMode['startTime'] = true;
									rechargeEditMode = {...rechargeEditMode};
								}}
								on:blur={(e) => {
									const newValue = e.currentTarget.value;
									if (newValue !== `${startHour}:${startMinute} ${startAmPm}`) {
										rechargeEditedValues['startTime'] = newValue;
								startTimeInput = newValue; // Update base value
										saveRechargeData();
									}
									rechargeEditMode['startTime'] = false;
									rechargeEditMode = {...rechargeEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && rechargeEditMode['startTime']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if rechargeEditedValues['startTime'] !== undefined}
								<div class="datetime-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{startHour}:{startMinute} {startAmPm}</span>
								</div>
							{/if}
						</div>
					</div>

					<!-- End Date -->
					<div class="date-time-group">
						<div class="datetime-field-header">
							<input
								type="checkbox"
								bind:checked={rechargeVerified['endDate']}
								on:change={saveRechargeData}
								class="datetime-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'تاريخ الانتهاء' : 'End Date'}</label>
						</div>
						<div class="datetime-input-display">
							<input 
								type="date" 
								class="datetime-editable-input {rechargeEditedValues['endDate'] !== undefined ? 'datetime-edited' : ''}" 
								value={rechargeEditedValues['endDate'] !== undefined ? rechargeEditedValues['endDate'] : endDateInput}
								readonly={!rechargeEditMode['endDate']}
								on:dblclick={() => {
									rechargeEditMode['endDate'] = true;
									rechargeEditMode = {...rechargeEditMode};
								}}
								on:blur={(e) => {
									const newValue = e.currentTarget.value;
									if (newValue !== endDateInput) {
										rechargeEditedValues['endDate'] = newValue;
								endDateInput = newValue; // Update base value
										saveRechargeData();
									}
									rechargeEditMode['endDate'] = false;
									rechargeEditMode = {...rechargeEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && rechargeEditMode['endDate']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if rechargeEditedValues['endDate'] !== undefined}
								<div class="datetime-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{endDateInput || 'N/A'}</span>
								</div>
							{/if}
						</div>
					</div>

					<!-- End Time -->
					<div class="date-time-group">
						<div class="datetime-field-header">
							<input
								type="checkbox"
								bind:checked={rechargeVerified['endTime']}
								on:change={saveRechargeData}
								class="datetime-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'وقت الانتهاء' : 'End Time'}</label>
						</div>
						<div class="datetime-input-display">
							<input 
								type="text" 
								class="datetime-editable-input {rechargeEditedValues['endTime'] !== undefined ? 'datetime-edited' : ''}" 
								value={rechargeEditedValues['endTime'] !== undefined ? rechargeEditedValues['endTime'] : `${endHour}:${endMinute} ${endAmPm}`}
								readonly={!rechargeEditMode['endTime']}
								placeholder="HH:MM AM/PM"
								on:dblclick={() => {
									rechargeEditMode['endTime'] = true;
									rechargeEditMode = {...rechargeEditMode};
								}}
								on:blur={(e) => {
									const newValue = e.currentTarget.value;
									if (newValue !== `${endHour}:${endMinute} ${endAmPm}`) {
										rechargeEditedValues['endTime'] = newValue;
								endTimeInput = newValue; // Update base value
										saveRechargeData();
									}
									rechargeEditMode['endTime'] = false;
									rechargeEditMode = {...rechargeEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && rechargeEditMode['endTime']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if rechargeEditedValues['endTime'] !== undefined}
								<div class="datetime-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{endHour}:{endMinute} {endAmPm}</span>
								</div>
							{/if}
						</div>
					</div>
				</div>
				
				<div class="balance-row">
					<!-- Opening Balance -->
					<div class="balance-group">
						<div class="recharge-field-header">
							<input
								type="checkbox"
								bind:checked={rechargeVerified['openingBalance']}
								on:change={saveRechargeData}
								class="recharge-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'الرصيد الافتتاحي' : 'Opening Balance'}</label>
						</div>
						<div class="recharge-amount-display">
							<input
								type="number"
								value={rechargeEditedValues['openingBalance'] !== undefined ? rechargeEditedValues['openingBalance'] : openingBalance}
								readonly={!rechargeEditMode['openingBalance']}
								placeholder="0.00"
								min="0"
								step="0.01"
								class="recharge-editable-input {rechargeEditedValues['openingBalance'] !== undefined ? 'recharge-edited' : ''}"
								on:dblclick={() => {
									rechargeEditMode['openingBalance'] = true;
									rechargeEditMode = {...rechargeEditMode};
								}}
								on:blur={(e) => {
									const newValue = parseFloat(e.currentTarget.value) || 0;
									if (newValue !== (Number(openingBalance) || 0)) {
										rechargeEditedValues['openingBalance'] = newValue;
								openingBalance = newValue; // Update base value
										saveRechargeData();
									}
									rechargeEditMode['openingBalance'] = false;
									rechargeEditMode = {...rechargeEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && rechargeEditMode['openingBalance']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if rechargeEditedValues['openingBalance'] !== undefined}
								<div class="recharge-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{(Number(openingBalance) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
								</div>
							{/if}
						</div>
					</div>

					<!-- Close Balance -->
					<div class="balance-group">
						<div class="recharge-field-header">
							<input
								type="checkbox"
								bind:checked={rechargeVerified['closeBalance']}
								on:change={saveRechargeData}
								class="recharge-verify-checkbox"
							/>
							<label>{$currentLocale === 'ar' ? 'رصيد الإغلاق' : 'Close Balance'}</label>
						</div>
						<div class="recharge-amount-display">
							<input
								type="number"
								value={rechargeEditedValues['closeBalance'] !== undefined ? rechargeEditedValues['closeBalance'] : closeBalance}
								readonly={!rechargeEditMode['closeBalance']}
								placeholder="0.00"
								min="0"
								step="0.01"
								class="recharge-editable-input {rechargeEditedValues['closeBalance'] !== undefined ? 'recharge-edited' : ''}"
								on:dblclick={() => {
									rechargeEditMode['closeBalance'] = true;
									rechargeEditMode = {...rechargeEditMode};
								}}
								on:blur={(e) => {
									const newValue = parseFloat(e.currentTarget.value) || 0;
									if (newValue !== (Number(closeBalance) || 0)) {
										rechargeEditedValues['closeBalance'] = newValue;
								closeBalance = newValue; // Update base value
										saveRechargeData();
									}
									rechargeEditMode['closeBalance'] = false;
									rechargeEditMode = {...rechargeEditMode};
								}}
								on:keydown={(e) => {
									if (e.key === 'Enter' && rechargeEditMode['closeBalance']) {
										e.currentTarget.blur();
									}
								}}
							/>
							{#if rechargeEditedValues['closeBalance'] !== undefined}
								<div class="recharge-original-value">
									<span class="original-label">Original:</span>
									<span class="original-value">{(Number(closeBalance) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
								</div>
							{/if}
						</div>
					</div>

					<!-- Sales (Read-only, calculated) -->
					<div class="balance-group">
						<label>{$currentLocale === 'ar' ? 'المبيعات' : 'Sales'}</label>
						<input
							type="number"
							value={sales}
							placeholder="0.00"
							disabled
							class="balance-input balance-input-disabled"
						/>
					</div>
				</div>
			</div>
			<div class="split-section comparison-signature-section">
				<div class="card-header-text">{$currentLocale === 'ar' ? '6. المقارنة والتوقيع الإلكتروني' : '6. Comparison & Electronic Signature'}</div>
				<div class="sub-cards-row">
					<div class="sub-card">
						<div class="sub-card-content">
							<div class="difference-row">
								<div class="difference-group">
									<label>{$currentLocale === 'ar' ? 'المبيعات النقدية' : 'Cash Sales'}</label>
									<input
										type="number"
										value={differenceInCashSales}
										disabled
										class="difference-input difference-input-disabled"
									/>
									<span class="difference-label" class:badge-short={differenceInCashSales < 0} class:badge-excess={differenceInCashSales > 0} class:badge-match={differenceInCashSales === 0}>
										{differenceInCashSales < 0 ? ($currentLocale === 'ar' ? 'نقص' : 'Short') : differenceInCashSales > 0 ? ($currentLocale === 'ar' ? 'زيادة' : 'Excess') : ($currentLocale === 'ar' ? 'متطابق' : 'Match')}
									</span>
								</div>
								<div class="difference-group">
									<label>{$currentLocale === 'ar' ? 'مبيعات البطاقة' : 'Card Sales'}</label>
									<input
										type="number"
										value={differenceInCardSales}
										disabled
										class="difference-input difference-input-disabled"
									/>
									<span class="difference-label" class:badge-short={differenceInCardSales < 0} class:badge-excess={differenceInCardSales > 0} class:badge-match={differenceInCardSales === 0}>
										{differenceInCardSales < 0 ? ($currentLocale === 'ar' ? 'نقص' : 'Short') : differenceInCardSales > 0 ? ($currentLocale === 'ar' ? 'زيادة' : 'Excess') : ($currentLocale === 'ar' ? 'متطابق' : 'Match')}
									</span>
								</div>
							</div>
							<div style="display: flex; flex-direction: column; gap: 0.15rem; margin-top: 0.3rem;">
								<input
									type="number"
									value={totalDifference}
									disabled
									class="difference-input difference-input-disabled"
								/>
								<span class="difference-label" class:badge-short={totalDifference < 0} class:badge-excess={totalDifference > 0} class:badge-match={totalDifference === 0}>
									{totalDifference < 0 ? ($currentLocale === 'ar' ? 'نقص' : 'Short') : totalDifference > 0 ? ($currentLocale === 'ar' ? 'زيادة' : 'Excess') : ($currentLocale === 'ar' ? 'متطابق' : 'Match')}
								</span>
							</div>
						</div>
					</div>
					<div class="sub-card">
						<div class="sub-card-header" style="font-size: 0.7rem; font-weight: 700; color: #15803d; letter-spacing: 1px; margin-bottom: 0.1rem; text-align: center; border-bottom: 1px solid #fed7aa; padding-bottom: 0.1rem;">
							{$currentLocale === 'ar' ? 'التوقيع الإلكتروني' : 'ELECTRONIC SIGNATURE'}
						</div>
						<div class="sub-card-content" style="gap: 0.1rem;">
							<div style="display: flex; align-items: center; gap: 0.3rem;">
								<div style="flex: 1;">
									<div style="font-size: 0.6rem; font-weight: 700; color: #166534; margin-bottom: 0.05rem;">
										{$currentLocale === 'ar' ? 'المشرف' : 'Supervisor'}
									</div>
									<input
										type="text"
										class="supervisor-code-input"
										value={supervisorName || ''}
										readonly
										placeholder={$currentLocale === 'ar' ? 'غير متوفر' : 'Not Available'}
										style="margin: 0;"
									/>
								</div>
								<div style="display: flex; flex-direction: column; align-items: center; justify-content: flex-end; min-height: 1.2rem;">
									<div style="font-size: 0.55rem; color: #15803d; font-weight: 600;">
										{$currentLocale === 'ar' ? '✓ تحقق' : '✓ Ok'}
									</div>
								</div>
							</div>
							
							<div style="display: flex; align-items: center; gap: 0.3rem;">
								<div style="flex: 1;">
									<div style="font-size: 0.6rem; font-weight: 700; color: #166534; margin-bottom: 0.05rem;">
										{$currentLocale === 'ar' ? 'الكاشير' : 'Cashier'}
									</div>
									<input
										type="text"
										class="supervisor-code-input"
										value={operationData.cashier_name || ''}
										readonly
										placeholder={$currentLocale === 'ar' ? 'غير متوفر' : 'Not Available'}
										style="margin: 0;"
									/>
								</div>
								<div style="display: flex; flex-direction: column; align-items: center; justify-content: flex-end; min-height: 1.5rem;">
									<div style="font-size: 0.55rem; color: #15803d; font-weight: 600;">
										{$currentLocale === 'ar' ? '✓ تحقق' : '✓ Ok'}
									</div>
								</div>
							</div>
							
							<button
								class="save-button"
								disabled={true}
								style="margin-top: 0.2rem;"
							>
								{$currentLocale === 'ar' ? '✓ تم الإغلاق' : '✓ Closed'}
							</button>
							<div style="font-size: 0.55rem; color: #15803d; font-weight: 600; text-align: center;">
								{$currentLocale === 'ar' ? 'في انتظار الإغلاق النهائي في نقطة البيع' : 'Pending final close in POS'}
							</div>
						</div>
					</div>
				</div>
				<div style="display: flex; justify-content: center; gap: 0.5rem; margin-top: 0.5rem;">
					<button class="save-button" on:click={() => showPrintModal = true} style="background: #3b82f6; border: 1px solid #1e40af;">
						🖨️ Print Box Details
					</button>
				</div>
			</div>
		</div>
		<div class="half-card split-card">
			<div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.5rem; padding: 0.5rem;">
				<div class="blank-card" style="background: #f0f9ff; border: 2px solid #0ea5e9; min-height: 80px; display: flex; flex-direction: column; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(6, 182, 212, 0.15); padding: 0.5rem;">
					<label style="font-size: 0.7rem; color: #0369a1; font-weight: 600; margin-bottom: 0.3rem; text-align: center;">Status POS Cash</label>
					<div style="display: flex; gap: 0.3rem; width: 100%; align-items: center;">
						<input type="number" value={Math.abs(differenceInCashSales)} readonly style="flex: 2; padding: 0.3rem; border: 1px solid #ccc; border-radius: 4px; text-align: center; font-size: 0.8rem; font-weight: bold;" />
						<div style="flex: 1; padding: 0.3rem; text-align: center; font-size: 0.75rem; font-weight: 600; color: #0369a1;">
							{differenceInCashSales >= 0 ? "DR" : "CR"}
						</div>
					</div>
				</div>
				<div class="blank-card" style="background: #f0f9ff; border: 2px solid #0ea5e9; min-height: 80px; display: flex; flex-direction: column; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(6, 182, 212, 0.15); padding: 0.5rem;">
					<label style="font-size: 0.7rem; color: #0369a1; font-weight: 600; margin-bottom: 0.3rem; text-align: center;">Status POS Bank</label>
					<div style="display: flex; gap: 0.3rem; width: 100%; align-items: center;">
						<input type="number" value={Math.abs(differenceInCardSales)} readonly style="flex: 2; padding: 0.3rem; border: 1px solid #ccc; border-radius: 4px; text-align: center; font-size: 0.8rem; font-weight: bold;" />
						<div style="flex: 1; padding: 0.3rem; text-align: center; font-size: 0.75rem; font-weight: 600; color: #0369a1;">
							{differenceInCardSales >= 0 ? "DR" : "CR"}
						</div>
					</div>
				</div>
			</div>
<label style="font-size: 0.7rem; color: #0369a1; font-weight: 600; margin-bottom: 0.5rem; text-align: center; width: 100%;">Entry to Pass</label>
				
{#if entryToPassData.transfers.length > 0}
				<div class="blank-card" style="background: #fff7ed; border: 2px solid #ea580c; min-height: auto; display: flex; flex-direction: column; align-items: flex-start; justify-content: flex-start; box-shadow: 0 2px 8px rgba(234, 88, 12, 0.15); padding: 0.5rem; width: 100%;">
					<div style="font-weight: 600; color: #ea580c; margin-bottom: 0.3rem; width: 100%;">📤 Transfers:</div>
					{#each entryToPassData.transfers as transfer}
						<div style="margin-bottom: 0.3rem; padding: 0.2rem; background: #ffedd5; border-radius: 3px; width: 100%; font-size: 0.65rem;">
							<div style="margin-bottom: 0.1rem;"><strong>Dr {transfer.debitAccount}:</strong> {transfer.debitAmount.toFixed(2)}</div>
							<div><strong>Cr {transfer.creditAccount}:</strong> {transfer.creditAmount.toFixed(2)}</div>
						</div>
					{/each}
				</div>
			{/if}

			{#if entryToPassData.adjustments.length > 0}
				<div class="blank-card" style="background: #fff7ed; border: 2px solid #ea580c; min-height: auto; display: flex; flex-direction: column; align-items: flex-start; justify-content: flex-start; box-shadow: 0 2px 8px rgba(234, 88, 12, 0.15); padding: 0.5rem; width: 100%;">
					<div style="font-weight: 600; color: #ea580c; margin-bottom: 0.3rem; width: 100%;">⚙️ Adjustments:</div>
					{#each entryToPassData.adjustments as adjustment}
						<div style="margin-bottom: 0.3rem; padding: 0.2rem; background: #ffedd5; border-radius: 3px; width: 100%; font-size: 0.65rem;">
							{#if adjustment.note}
								<div style="color: #dc2626; font-weight: 600; background: #fee2e2; padding: 0.3rem; border-radius: 3px; border-left: 3px solid #dc2626;">{adjustment.note}</div>
							{:else}
								<div style="margin-bottom: 0.1rem;"><strong>Dr {adjustment.debitAccount}:</strong> {adjustment.debitAmount.toFixed(2)}</div>
								<div><strong>Cr {adjustment.creditAccount}:</strong> {adjustment.creditAmount.toFixed(2)}</div>
							{/if}
						</div>
					{/each}
				</div>
			{/if}

			<div class="blank-card" style="background: #f0fdf4; border: 2px solid #22c55e; min-height: auto; display: flex; flex-direction: column; align-items: flex-start; justify-content: flex-start; box-shadow: 0 2px 8px rgba(34, 197, 94, 0.15); padding: 0.5rem; width: 100%;">
				<div style="font-weight: 600; color: #15803d; margin-bottom: 0.3rem; width: 100%; font-size: 0.65rem;">💵 Cash Receipt</div>
				{#if entryToPassData.cashReceipt.adjustment > 0}
					<div style="margin-bottom: 0.1rem; font-size: 0.65rem;"><strong>Adjustment:</strong> {entryToPassData.cashReceipt.adjustment.toFixed(2)}</div>
				{/if}
				<div style="font-weight: 600; color: #15803d; margin-top: 0.2rem; border-top: 2px solid #22c55e; padding-top: 0.2rem; width: 100%; font-size: 0.65rem;"><strong>Total Cash Receipt:</strong> {entryToPassData.cashReceipt.total.toFixed(2)}</div>
			</div>

			<div class="blank-card" style="background: #f0f9ff; border: 2px solid #0ea5e9; min-height: auto; display: flex; flex-direction: column; align-items: flex-start; justify-content: flex-start; box-shadow: 0 2px 8px rgba(6, 182, 212, 0.15); padding: 0.5rem; width: 100%;">
				<div style="font-weight: 600; color: #0369a1; margin-bottom: 0.3rem; width: 100%; font-size: 0.65rem;">🏦 Bank Receipt</div>
				<div style="font-size: 0.6rem; color: #0284c7; margin-bottom: 0.3rem; font-style: italic; font-weight: 600; width: 100%;">📌 Instruction: Do not post entry until bank statement is available for reconciliation</div>
				{#if entryToPassData.bankReceipt.adjustment > 0}
					<div style="margin-bottom: 0.1rem; font-size: 0.65rem;"><strong>Adjustment:</strong> {entryToPassData.bankReceipt.adjustment.toFixed(2)}</div>
				{/if}
				<div style="font-weight: 600; color: #0369a1; margin-top: 0.2rem; border-top: 2px solid #0ea5e9; padding-top: 0.2rem; width: 100%; font-size: 0.65rem;"><strong>Total Bank Receipt:</strong> {entryToPassData.bankReceipt.total.toFixed(2)}</div>
			</div>

		{#if entryToPassData.transfers.length === 0 && entryToPassData.adjustments.length === 0}
			<div style="font-size: 0.65rem; color: #6b7280; text-align: center; width: 100%;">Ready for posting</div>
		{/if}

		<!-- Net Short/Excess Card -->
		<div class="blank-card" style="background: #fef2f2; border: 2px solid #ef4444; min-height: auto; display: flex; flex-direction: column; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(239, 68, 68, 0.15); padding: 0.5rem; width: 100%;">
			{#if differenceInCashSales < 0 && differenceInCardSales < 0}
				<!-- Both CR (both short) -->
				<div style="font-weight: 600; color: #dc2626; font-size: 0.7rem;">📊 Net Position</div>
				<div style="font-size: 0.65rem; color: #991b1b; margin-top: 0.3rem;">
					<strong>Net Short:</strong> {(Math.abs(differenceInCashSales) + Math.abs(differenceInCardSales)).toFixed(2)}
				</div>
			{:else if differenceInCashSales > 0 && differenceInCardSales > 0}
				<!-- Both DR (both excess) -->
				<div style="font-weight: 600; color: #dc2626; font-size: 0.7rem;">📊 Net Position</div>
				<div style="font-size: 0.65rem; color: #991b1b; margin-top: 0.3rem;">
					<strong>Net Excess:</strong> {(differenceInCashSales + differenceInCardSales).toFixed(2)}
				</div>
			{:else if Math.abs(differenceInCashSales) > Math.abs(differenceInCardSales)}
				<!-- Mixed: Cash larger -->
				<div style="font-weight: 600; color: #dc2626; font-size: 0.7rem;">📊 Net Position</div>
				<div style="font-size: 0.65rem; color: #991b1b; margin-top: 0.3rem;">
					{#if differenceInCashSales > 0}
						<strong>Net Excess:</strong> {(Math.abs(differenceInCashSales) - Math.abs(differenceInCardSales)).toFixed(2)}
					{:else}
						<strong>Net Short:</strong> {(Math.abs(differenceInCashSales) - Math.abs(differenceInCardSales)).toFixed(2)}
					{/if}
				</div>
			{:else if Math.abs(differenceInCardSales) > Math.abs(differenceInCashSales)}
				<!-- Mixed: Bank larger -->
				<div style="font-weight: 600; color: #dc2626; font-size: 0.7rem;">📊 Net Position</div>
				<div style="font-size: 0.65rem; color: #991b1b; margin-top: 0.3rem;">
					{#if differenceInCardSales > 0}
						<strong>Net Excess:</strong> {(Math.abs(differenceInCardSales) - Math.abs(differenceInCashSales)).toFixed(2)}
					{:else}
						<strong>Net Short:</strong> {(Math.abs(differenceInCardSales) - Math.abs(differenceInCashSales)).toFixed(2)}
					{/if}
				</div>
			{:else}
				<div style="font-weight: 600; color: #15803d; font-size: 0.7rem;">✅ Balanced</div>
				<div style="font-size: 0.65rem; color: #15803d; margin-top: 0.3rem;">
					No net short or excess
				</div>
			{/if}
		</div>
	</div>
	</div>
	{/if}
</div>

<!-- Voucher Status Modal -->
{#if showVoucherStatusModal}
	<div class="modal-overlay" on:click={() => showVoucherStatusModal = false}>
		<div class="voucher-status-modal" on:click|stopPropagation>
			<div class="modal-header">
				<h3>{$currentLocale === 'ar' ? 'حالة القسائم' : 'Voucher Status'}</h3>
				<button class="modal-close-btn" on:click={() => showVoucherStatusModal = false}>✕</button>
			</div>
			<div class="modal-body">
				<table class="status-table">
					<thead>
						<tr>
							<th>{$currentLocale === 'ar' ? 'الرقم التسلسلي' : 'Serial'}</th>
							<th>{$currentLocale === 'ar' ? 'المبلغ' : 'Amount'}</th>
							<th>{$currentLocale === 'ar' ? 'الحالة' : 'Status'}</th>
							<th>{$currentLocale === 'ar' ? 'الإجراء' : 'Action'}</th>
						</tr>
					</thead>
					<tbody>
						{#each voucherStatusResults as result}
							<tr class:not-found={!result.found}>
								<td>{result.serial}</td>
								<td>
									<div class="amount-cell">
										<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
										<span>{result.amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
									</div>
								</td>
								<td>
									<span class="status-badge" class:status-stocked={result.status === 'stocked'}
										class:status-issued={result.status === 'issued'}
										class:status-not-found={!result.found}>
										{result.status}
									</span>
								</td>
								<td>
									{#if result.found && result.voucherData}
										{#if result.status === 'stocked'}
											<button 
												class="action-btn issue-btn"
												on:click={() => {
													const windowId = `issue-purchase-voucher-${Date.now()}`;
													openWindow({
														id: windowId,
														title: $currentLocale === 'ar' ? 'إصدار قسيمة الشراء' : 'Issue Purchase Voucher',
														component: IssuePurchaseVoucher,
														icon: '📝',
														size: { width: 1200, height: 700 },
														position: { x: 100, y: 100 },
														resizable: true,
														minimizable: true,
														maximizable: true,
														closable: true,
														props: { windowId, autoLoadSerial: result.serial, autoFilterValue: result.amount.toString() }
													});
													showVoucherStatusModal = false;
												}}
											>
												{$currentLocale === 'ar' ? 'إصدار' : 'Issue'}
											</button>
										{:else if result.status === 'issued'}
											<button 
												class="action-btn close-btn"
												on:click={() => {
													const windowId = `close-purchase-voucher-${Date.now()}`;
													openWindow({
														id: windowId,
														title: $currentLocale === 'ar' ? 'إغلاق قسيمة الشراء' : 'Close Purchase Voucher',
														component: ClosePurchaseVoucher,
														icon: '🔒',
														size: { width: 1400, height: 800 },
														position: { x: 100, y: 100 },
														resizable: true,
														minimizable: true,
														maximizable: true,
														closable: true,
														props: { windowId, autoFilterSerial: result.serial, autoFilterValue: result.amount.toString() }
													});
													showVoucherStatusModal = false;
												}}
											>
												{$currentLocale === 'ar' ? 'إغلاق' : 'Close'}
											</button>
										{:else}
											<span class="no-action">-</span>
										{/if}
									{:else}
										<span class="no-action">-</span>
									{/if}
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>
	</div>
{/if}

<!-- Print Modal -->
{#if showPrintModal}
	<div class="print-modal-overlay" on:click={() => showPrintModal = false}>
		<div class="print-modal" on:click|stopPropagation>
			<div class="print-modal-header">
				<h3>{$currentLocale === 'ar' ? 'طباعة تفاصيل الصندوق' : 'Print Box Details'}</h3>
				<button class="print-modal-close-btn" on:click={() => showPrintModal = false}>✕</button>
			</div>
			<div class="print-modal-body">
				<!-- A4 Print Container -->
				<div class="a4-print-container">
					<!-- Row 1: Cashier Info (Left) & Amount Info (Right) -->
					<div class="print-cards-row">
						<!-- Card 1 Left: Cashier Information -->
						<div class="print-card">
							<div class="print-card-header">👤 Cashier Info</div>
							<div class="print-card-content">
								<div class="print-info-row">
									<span class="print-label">Cashier Name:</span>
									<span class="print-value">{cashierName || 'N/A'}</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">POS Number:</span>
									<span class="print-value">{posNumber || 'N/A'}</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Supervisor Checked:</span>
									<span class="print-value">{supervisorCheckCode || 'N/A'}</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Supervisor Closed:</span>
									<span class="print-value">{supervisorCloseCode || 'N/A'}</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Completed By:</span>
									<span class="print-value">{completedByName || 'N/A'}</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Branch:</span>
									<span class="print-value">{branchName || 'N/A'}</span>
								</div>
							</div>
						</div>

						<!-- Card 1 Right: Amount Information -->
						<div class="print-card">
							<div class="print-card-header">💰 Amount Info</div>
							<div class="print-card-content">
								<div class="print-info-row">
									<span class="print-label">Amount Issued:</span>
									<span class="print-value">{(Number(amountIssued) || 0).toFixed(2)} SAR</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Amount Checked:</span>
									<span class="print-value">{(Number(amountChecked) || 0).toFixed(2)} SAR</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Closing Cash Total:</span>
									<span class="print-value">{(Number(closingCashTotal) || 0).toFixed(2)} SAR</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Total Cash Sales:</span>
									<span class="print-value">{(Number(totalCashSales) || 0).toFixed(2)} SAR</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Total Bank Sales:</span>
									<span class="print-value">{(Number(totalBankSales) || 0).toFixed(2)} SAR</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Total Sales:</span>
									<span class="print-value">{((Number(totalCashSales) || 0) + (Number(totalBankSales) || 0)).toFixed(2)} SAR</span>
								</div>
							</div>
						</div>
					</div>

					<!-- Row 2: Closing Denominations (Left) & Bank Reconciliation (Right) -->
					<div class="print-cards-row">
						<!-- Card 2 Left: Closing Denominations -->
						<div class="print-card">
							<div class="print-card-header">💵 Closing Denominations</div>
							<div class="print-card-content print-small-text">
								{#each closingDenominationList as denom, idx (idx)}
									{#if denom.count > 0}
										<div class="print-info-row">
											<span class="print-label">{denom.name}:</span>
											<span class="print-value">{denom.count} × {denom.value.toFixed(2)}</span>
										</div>
									{/if}
								{:else}
									<div class="print-info-row">
										<span class="print-label">No denominations recorded</span>
									</div>
								{/each}
								<div class="print-info-row" style="border-top: 1px solid #ccc; padding-top: 0.3rem; margin-top: 0.3rem;">
									<span class="print-label" style="font-weight: 700;">Total:</span>
									<span class="print-value" style="font-weight: 700;">{(Number(closingCashTotal) || 0).toFixed(2)} SAR</span>
								</div>
							</div>
						</div>

						<!-- Card 2 Right: Bank Reconciliation -->
						<div class="print-card">
							<div class="print-card-header">🏦 Bank Reconciliation</div>
							<div class="print-card-content print-small-text">
								<div class="print-info-row">
									<span class="print-label">Cheques Amount:</span>
									<span class="print-value">{(Number(chequesAmount) || 0).toFixed(2)} SAR</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Transfer Amount:</span>
									<span class="print-value">{(Number(transferAmount) || 0).toFixed(2)} SAR</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Total Bank:</span>
									<span class="print-value">{((Number(chequesAmount) || 0) + (Number(transferAmount) || 0)).toFixed(2)} SAR</span>
								</div>
							</div>
						</div>
					</div>

					<!-- Row 3: ERP Closing Details (Left) & Recharge Cards (Right) -->
					<div class="print-cards-row">
						<!-- Card 3 Left: ERP Closing Details -->
						<div class="print-card">
							<div class="print-card-header">📊 ERP Closing Details</div>
							<div class="print-card-content print-small-text">
								<div class="print-info-row">
									<span class="print-label">System Cash Sales:</span>
									<span class="print-value">{(Number(systemCashSales) || 0).toFixed(2)} SAR</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">System Card Sales:</span>
									<span class="print-value">{(Number(systemCardSales) || 0).toFixed(2)} SAR</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Difference (Cash):</span>
									<span class="print-value" class:short-value={differenceInCashSales < 0} class:excess-value={differenceInCashSales > 0}>
										{differenceInCashSales >= 0 ? '+' : ''}{differenceInCashSales.toFixed(2)} SAR
									</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Difference (Bank):</span>
									<span class="print-value" class:short-value={differenceInCardSales < 0} class:excess-value={differenceInCardSales > 0}>
										{differenceInCardSales >= 0 ? '+' : ''}{differenceInCardSales.toFixed(2)} SAR
									</span>
								</div>
							</div>
						</div>

						<!-- Card 3 Right: Recharge Cards -->
						<div class="print-card">
							<div class="print-card-header">🔋 Recharge Cards</div>
							<div class="print-card-content print-small-text">
								{#if rechargeCardsList && rechargeCardsList.length > 0}
									{#each rechargeCardsList as card, idx (idx)}
										<div class="print-info-row">
											<span class="print-label">{card.serial || `Card ${idx + 1}`}:</span>
											<span class="print-value">{(Number(card.amount) || 0).toFixed(2)} SAR</span>
										</div>
									{/each}
								{:else}
									<div class="print-info-row">
										<span class="print-label">No recharge cards recorded</span>
									</div>
								{/if}
							</div>
						</div>
					</div>

					<!-- Row 4: Sales Through Vouchers (Left) & Comparison & Signature (Right) -->
					<div class="print-cards-row">
						<!-- Card 4 Left: Sales Through Vouchers -->
						<div class="print-card">
							<div class="print-card-header">🎟️ Sales Through Vouchers</div>
							<div class="print-card-content print-small-text">
								{#if vouchersList && vouchersList.length > 0}
									{#each vouchersList as voucher, idx (idx)}
										<div class="print-info-row">
											<span class="print-label">{voucher.serial}:</span>
											<span class="print-value">{(Number(voucher.amount) || 0).toFixed(2)} SAR</span>
										</div>
									{/each}
									<div class="print-info-row" style="margin-top: 0.25rem; border-top: 1px solid #e5e7eb; padding-top: 0.25rem;">
										<span class="print-label" style="font-weight: 700;">Total Vouchers:</span>
										<span class="print-value" style="font-weight: 700;">{(Number(totalVoucherAmount) || 0).toFixed(2)} SAR</span>
									</div>
								{:else}
									<div class="print-info-row">
										<span class="print-label">No vouchers recorded</span>
									</div>
								{/if}
							</div>
						</div>

						<!-- Card 4 Right: Comparison & Electronic Signature -->
						<div class="print-card">
							<div class="print-card-header">✅ Comparison & Signature</div>
							<div class="print-card-content print-small-text">
								<div class="print-info-row">
									<span class="print-label">Supervisor Check Date:</span>
									<span class="print-value">{supervisorCheckDate || 'N/A'}</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Supervisor Close Date:</span>
									<span class="print-value">{supervisorCloseDate || 'N/A'}</span>
								</div>
								<div class="print-info-row">
									<span class="print-label">Completed By Date:</span>
									<span class="print-value">{completedByDate || 'N/A'}</span>
								</div>
								<div class="print-info-row">
									<span class="print-label" style="color: #1f2937;">Status:</span>
									<span class="print-value" style="color: #10b981; font-weight: 700;">✓ Signed</span>
								</div>
							</div>
						</div>
					</div>

					<!-- Row 5: Adjustment Entries (Left) & Accountant Signature (Right) -->
					<div class="print-cards-row">
						<!-- Card 5 Left: Adjustment Entries -->
						<div class="print-card">
							<div class="print-card-header">⚙️ Adjustment Entries</div>
							<div class="print-card-content print-small-text">
								{#if adjustmentsList && adjustmentsList.length > 0}
									{#each adjustmentsList as adj, idx (idx)}
										<div class="print-info-row">
											<span class="print-label">{adj.type || `Adjustment ${idx + 1}`}:</span>
											<span class="print-value">{(Number(adj.amount) || 0).toFixed(2)} SAR</span>
										</div>
										{#if adj.note}
											<div class="print-info-row print-note-row">
												<span class="print-label">Note:</span>
												<span class="print-value print-note-text">{adj.note}</span>
											</div>
										{/if}
									{/each}
								{:else}
									<div class="print-info-row">
										<span class="print-label">No adjustments recorded</span>
									</div>
								{/if}
							</div>
						</div>

						<!-- Card 5 Right: Accountant Signature -->
						<div class="print-card">
							<div class="print-card-header">👔 Accountant Verification</div>
							<div class="print-card-content">
								<div style="flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 1rem;">
									<div style="text-align: center;">
										<div class="print-signature-field">_____________________</div>
										<div class="print-label" style="margin-top: 0.25rem;">Accountant Signature</div>
									</div>
									<div style="text-align: center;">
										<div class="print-label">Date: _____________________</div>
									</div>
									<div style="text-align: center;">
										<div class="print-label">Name: _____________________</div>
									</div>
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>

			<div class="print-modal-footer">
				<button class="print-btn" on:click={() => {
					const printContent = document.getElementById('complete-box-print-content');
					if (printContent) {
						const printWindow = window.open('', 'PRINT', 'width=1200,height=800');
						const html = `
							<!DOCTYPE html>
							<html>
							<head>
								<meta charset="UTF-8">
								<title>Box Closing Details</title>
								<style>
									* { margin: 0; padding: 0; box-sizing: border-box; }
									html, body { 
										margin: 0; 
										padding: 1rem; 
										font-family: Arial, sans-serif;
										background: white;
										color: #000;
										font-size: 11pt;
									}
									.a4-print { 
										width: 210mm; 
										height: 297mm; 
										margin: 0 auto; 
										padding: 0.5rem;
										background: white;
									}
									.print-cards-row { 
										display: grid; 
										grid-template-columns: 1fr 1fr; 
										gap: 0.5rem; 
										margin-bottom: 0.5rem;
										page-break-inside: avoid;
									}
									.print-card { 
										border: 1px solid #3b82f6; 
										padding: 0.5rem; 
										page-break-inside: avoid;
										break-inside: avoid;
									}
									.print-card-header { 
										font-weight: 700; 
										color: #1e40af; 
										border-bottom: 1px solid #dbeafe; 
										padding-bottom: 0.3rem;
										font-size: 0.8rem;
										margin-bottom: 0.3rem;
									}
									.print-info-row { 
										display: flex; 
										justify-content: space-between; 
										padding: 0.15rem 0;
										border-bottom: 0.5px solid #e5e7eb;
										font-size: 0.75rem;
									}
									.print-label { font-weight: 600; min-width: 100px; }
									.print-value { text-align: right; flex: 1; }
									@page { margin: 0.5cm; size: A4; }
									@media print { 
										* { margin: 0 !important; padding: 0 !important; }
										body { padding: 0 !important; }
										.a4-print { width: 100%; height: 100%; margin: 0; padding: 0.5rem; }
									}
								</style>
							</head>
							<body>
								<div class="a4-print">
									${printContent.innerHTML}
								</div>
							</body>
							</html>
						`;
						printWindow.document.write(html);
						printWindow.document.close();
						setTimeout(() => {
							printWindow.print();
						}, 500);
					}
				}}>
					🖨️ Print
				</button>
				<button class="close-print-modal-btn" on:click={() => showPrintModal = false}>
					Close
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Hidden Print Content Container -->
<div id="complete-box-print-content" style="display: none;">
	<!-- A4 Print Container -->
	<div style="width: 210mm; padding: 0.5rem; font-family: Arial, sans-serif; font-size: 11pt; background: white;">
		<!-- Header -->
		<div style="text-align: center; margin-bottom: 0.5rem; border-bottom: 2px solid #1e40af; padding-bottom: 0.3rem;">
			<img src="/icons/logo.png" alt="PA Logo" style="height: 50px; margin-bottom: 0.3rem;" />
			<div style="font-weight: 700; font-size: 0.9rem;">🧾 BOX CLOSING REPORT</div>
			<div style="font-size: 0.65rem; color: #666;">Cashier: {cashierName || 'N/A'} | POS: {posNumber || 'N/A'} | {new Date().toLocaleDateString()}</div>
		</div>

		<!-- Row 1: Status Boxes (Cash & Bank) -->
		<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; margin-bottom: 0.5rem;">
			<div style="border: 2px solid #10b981; padding: 0.4rem; text-align: center; background: #ecfdf5;">
				<div style="font-size: 0.65rem; font-weight: 700; color: #065f46;">💵 Status POS Cash</div>
				<div style="font-size: 0.85rem; font-weight: 700; color: {differenceInCashSales >= 0 ? '#ef4444' : '#10b981'};">{Math.abs(differenceInCashSales).toFixed(2)} SAR</div>
				<div style="font-size: 0.6rem; color: {differenceInCashSales >= 0 ? '#ef4444' : '#10b981'};">{differenceInCashSales >= 0 ? '✗ DR' : '✓ CR'}</div>
			</div>
			<div style="border: 2px solid #3b82f6; padding: 0.4rem; text-align: center; background: #eff6ff;">
				<div style="font-size: 0.65rem; font-weight: 700; color: #1e40af;">💳 Status POS Bank</div>
				<div style="font-size: 0.85rem; font-weight: 700; color: {differenceInCardSales >= 0 ? '#ef4444' : '#10b981'};">{Math.abs(differenceInCardSales).toFixed(2)} SAR</div>
				<div style="font-size: 0.6rem; color: {differenceInCardSales >= 0 ? '#ef4444' : '#10b981'};">{differenceInCardSales >= 0 ? '✗ DR' : '✓ CR'}</div>
			</div>
		</div>

		<!-- Row 2: Transfers & Adjustments -->
		<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; margin-bottom: 0.5rem;">
			<div style="border: 1px solid #f97316; padding: 0.4rem; background: #fff7ed;">
				<div style="font-weight: 700; color: #c2410c; font-size: 0.7rem; border-bottom: 1px solid #fed7aa; padding-bottom: 0.2rem; margin-bottom: 0.2rem;">🔄 Transfers</div>
				<div style="font-size: 0.65rem;">
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span>Dr POS Cash:</span><span>{(Number(transferDrCash) || 0).toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span>Cr POS Bank:</span><span>{(Number(transferCrBank) || 0).toFixed(2)} SAR</span></div>
				</div>
			</div>
			<div style="border: 1px solid #ef4444; padding: 0.4rem; background: #fef2f2;">
				<div style="font-weight: 700; color: #991b1b; font-size: 0.7rem; border-bottom: 1px solid #fecaca; padding-bottom: 0.2rem; margin-bottom: 0.2rem;">⚠️ Adjustments</div>
				<div style="font-size: 0.65rem;">
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span>Dr POS Short:</span><span>{(Number(adjustmentDrShort) || 0).toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span>Cr POS Cash:</span><span>{(Number(adjustmentCrCash) || 0).toFixed(2)} SAR</span></div>
				</div>
			</div>
		</div>

		<!-- Row 3: Receipt Totals -->
		<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; margin-bottom: 0.5rem;">
			<div style="border: 2px solid #10b981; padding: 0.4rem; background: #f0fdf4; text-align: center;">
				<div style="font-size: 0.65rem; font-weight: 700; color: #15803d; margin-bottom: 0.2rem;">💰 Cash Receipt Total</div>
				<div style="font-size: 0.9rem; font-weight: 700; color: #10b981;">{(Number(totalCashReceipt) || 0).toFixed(2)} SAR</div>
			</div>
			<div style="border: 2px solid #3b82f6; padding: 0.4rem; background: #f0f9ff; text-align: center;">
				<div style="font-size: 0.65rem; font-weight: 700; color: #1e40af; margin-bottom: 0.2rem;">🏦 Bank Receipt Total</div>
				<div style="font-size: 0.9rem; font-weight: 700; color: #3b82f6;">{(Number(totalBankReceipt) || 0).toFixed(2)} SAR</div>
			</div>
		</div>

		<!-- Row 4: Cashier Info (Left) & Amount Summary (Right) -->
		<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; margin-bottom: 0.5rem;">
			<!-- Cashier Information -->
			<div style="border: 1px solid #3b82f6; padding: 0.4rem;">
				<div style="font-weight: 700; color: #1e40af; border-bottom: 1px solid #dbeafe; padding-bottom: 0.2rem; margin-bottom: 0.2rem; font-size: 0.7rem;">👤 Cashier Info</div>
				<div style="font-size: 0.65rem;">
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span style="font-weight: 600;">Supervisor Checked:</span><span>{supervisorCheckCode || 'N/A'}</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span style="font-weight: 600;">Supervisor Closed:</span><span>{supervisorCloseCode || 'N/A'}</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span style="font-weight: 600;">Cashier:</span><span>{cashierName || 'N/A'}</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span style="font-weight: 600;">Completed By:</span><span>{completedByName || 'N/A'}</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span style="font-weight: 600;">Branch:</span><span>{branchName || 'N/A'}</span></div>
				</div>
			</div>

			<!-- Amount Information -->
			<div style="border: 1px solid #3b82f6; padding: 0.4rem;">
				<div style="font-weight: 700; color: #1e40af; border-bottom: 1px solid #dbeafe; padding-bottom: 0.2rem; margin-bottom: 0.2rem; font-size: 0.7rem;">💰 Amount Summary</div>
				<div style="font-size: 0.65rem;">
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span style="font-weight: 600;">Issued:</span><span>{(Number(amountIssued) || 0).toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span style="font-weight: 600;">Checked:</span><span>{(Number(amountChecked) || 0).toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span style="font-weight: 600;">Cash Total:</span><span>{(Number(closingCashTotal) || 0).toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span style="font-weight: 600;">All Sales:</span><span>{((Number(totalCashSales) || 0) + (Number(totalBankSales) || 0)).toFixed(2)} SAR</span></div>
				</div>
			</div>
		</div>

		<!-- Row 5: Denominations (Left) & Bank Details (Right) -->
		<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; margin-bottom: 0.5rem;">
			<!-- Denominations Card -->
			<div style="border: 1px solid #3b82f6; padding: 0.4rem;">
				<div style="font-weight: 700; color: #1e40af; border-bottom: 1px solid #dbeafe; padding-bottom: 0.2rem; margin-bottom: 0.2rem; font-size: 0.7rem;">💵 Denominations</div>
				<div style="font-size: 0.65rem;">
					{#each closingDenominationList as denom, idx (idx)}
						{#if denom.count > 0}
							<div style="display: flex; justify-content: space-between; padding: 0.05rem 0; border-bottom: 0.5px solid #e5e7eb;"><span>{denom.name}:</span><span>{denom.count} × {denom.value.toFixed(2)}</span></div>
						{/if}
					{/each}
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0; border-top: 1px solid #ccc; margin-top: 0.15rem; font-weight: 700; font-size: 0.7rem;"><span>Total:</span><span>{(Number(closingCashTotal) || 0).toFixed(2)} SAR</span></div>
				</div>
			</div>

			<!-- Bank Details Card -->
			<div style="border: 1px solid #3b82f6; padding: 0.4rem;">
				<div style="font-weight: 700; color: #1e40af; border-bottom: 1px solid #dbeafe; padding-bottom: 0.2rem; margin-bottom: 0.2rem; font-size: 0.7rem;">🏦 Bank Details</div>
				<div style="font-size: 0.65rem;">
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0; border-bottom: 0.5px solid #e5e7eb;"><span>Mada:</span><span>{(Number(madaAmount) || 0).toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0; border-bottom: 0.5px solid #e5e7eb;"><span>Visa:</span><span>{(Number(visaAmount) || 0).toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0; border-bottom: 0.5px solid #e5e7eb;"><span>Mastercard:</span><span>{(Number(masterCardAmount) || 0).toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0; border-bottom: 0.5px solid #e5e7eb;"><span>Google Pay:</span><span>{(Number(googlePayAmount) || 0).toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0; border-bottom: 0.5px solid #e5e7eb;"><span>Other:</span><span>{(Number(otherAmount) || 0).toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0; border-top: 1px solid #ccc; margin-top: 0.15rem; font-weight: 700; font-size: 0.7rem;"><span>Total:</span><span>{((Number(madaAmount) || 0) + (Number(visaAmount) || 0) + (Number(masterCardAmount) || 0) + (Number(googlePayAmount) || 0) + (Number(otherAmount) || 0)).toFixed(2)} SAR</span></div>
				</div>
			</div>
		</div>

		<!-- Row 6: ERP Closing (Left) & Net Position (Right) -->
		<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; margin-bottom: 0.5rem;">
			<!-- ERP Closing Card -->
			<div style="border: 1px solid #3b82f6; padding: 0.4rem;">
				<div style="font-weight: 700; color: #1e40af; border-bottom: 1px solid #dbeafe; padding-bottom: 0.2rem; margin-bottom: 0.2rem; font-size: 0.7rem;">📊 ERP Closing</div>
				<div style="font-size: 0.65rem;">
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0; border-bottom: 0.5px solid #e5e7eb;"><span style="font-weight: 600;">System Cash:</span><span>{(Number(systemCashSales) || 0).toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0; border-bottom: 0.5px solid #e5e7eb;"><span style="font-weight: 600;">System Card:</span><span>{(Number(systemCardSales) || 0).toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0; border-bottom: 0.5px solid #e5e7eb;"><span style="font-weight: 600;">Diff (Cash):</span><span style="color: {differenceInCashSales < 0 ? '#dc2626' : '#059669'}; font-weight: 700;">{differenceInCashSales >= 0 ? '+' : ''}{differenceInCashSales.toFixed(2)} SAR</span></div>
					<div style="display: flex; justify-content: space-between; padding: 0.05rem 0;"><span style="font-weight: 600;">Diff (Bank):</span><span style="color: {differenceInCardSales < 0 ? '#dc2626' : '#059669'}; font-weight: 700;">{differenceInCardSales >= 0 ? '+' : ''}{differenceInCardSales.toFixed(2)} SAR</span></div>
				</div>
			</div>

			<!-- Net Position Card -->
			<div style="border: 2px solid #ef4444; padding: 0.4rem; background: #fef2f2; text-align: center;">
				<div style="font-weight: 700; color: #dc2626; border-bottom: 1px solid #fecaca; padding-bottom: 0.2rem; margin-bottom: 0.2rem; font-size: 0.7rem;">📊 Net Position</div>
				<div style="font-size: 0.65rem;">
					{#if differenceInCashSales < 0 && differenceInCardSales < 0}
						<div style="color: #991b1b; font-weight: 700;">🔴 NET SHORT</div>
						<div style="color: #991b1b; font-weight: 700; font-size: 0.8rem;">{(Math.abs(differenceInCashSales) + Math.abs(differenceInCardSales)).toFixed(2)} SAR</div>
					{:else if differenceInCashSales > 0 && differenceInCardSales > 0}
						<div style="color: #059669; font-weight: 700;">🟢 NET EXCESS</div>
						<div style="color: #059669; font-weight: 700; font-size: 0.8rem;">{(differenceInCashSales + differenceInCardSales).toFixed(2)} SAR</div>
					{:else if Math.abs(differenceInCashSales) > Math.abs(differenceInCardSales)}
						{#if differenceInCashSales > 0}
							<div style="color: #059669; font-weight: 700;">🟢 NET EXCESS</div>
							<div style="color: #059669; font-weight: 700; font-size: 0.8rem;">{(Math.abs(differenceInCashSales) - Math.abs(differenceInCardSales)).toFixed(2)} SAR</div>
						{:else}
							<div style="color: #991b1b; font-weight: 700;">🔴 NET SHORT</div>
							<div style="color: #991b1b; font-weight: 700; font-size: 0.8rem;">{(Math.abs(differenceInCashSales) - Math.abs(differenceInCardSales)).toFixed(2)} SAR</div>
						{/if}
					{:else if Math.abs(differenceInCardSales) > Math.abs(differenceInCashSales)}
						{#if differenceInCardSales > 0}
							<div style="color: #059669; font-weight: 700;">🟢 NET EXCESS</div>
							<div style="color: #059669; font-weight: 700; font-size: 0.8rem;">{(Math.abs(differenceInCardSales) - Math.abs(differenceInCashSales)).toFixed(2)} SAR</div>
						{:else}
							<div style="color: #991b1b; font-weight: 700;">🔴 NET SHORT</div>
							<div style="color: #991b1b; font-weight: 700; font-size: 0.8rem;">{(Math.abs(differenceInCardSales) - Math.abs(differenceInCashSales)).toFixed(2)} SAR</div>
						{/if}
					{:else}
						<div style="color: #15803d; font-weight: 700;">✅ BALANCED</div>
						<div style="color: #15803d; font-weight: 600; font-size: 0.65rem;">No Short/Excess</div>
					{/if}
				</div>
			</div>
		</div>

		<!-- Row 7: Summary Statistics -->
		<div style="border: 1px solid #3b82f6; padding: 0.4rem;">
			<div style="font-weight: 700; color: #1e40af; border-bottom: 1px solid #dbeafe; padding-bottom: 0.2rem; margin-bottom: 0.2rem; font-size: 0.7rem;">📈 Closing Summary</div>
			<div style="display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 0.3rem; font-size: 0.65rem;">
				<div style="border: 0.5px solid #dbeafe; padding: 0.15rem; text-align: center;"><div style="font-weight: 600;">Issued</div><div style="color: #1e40af; font-weight: 700; font-size: 0.7rem;">{(Number(amountIssued) || 0).toFixed(2)}</div></div>
				<div style="border: 0.5px solid #dbeafe; padding: 0.15rem; text-align: center;"><div style="font-weight: 600;">Checked</div><div style="color: #1e40af; font-weight: 700; font-size: 0.7rem;">{(Number(amountChecked) || 0).toFixed(2)}</div></div>
				<div style="border: 0.5px solid #dbeafe; padding: 0.15rem; text-align: center;"><div style="font-weight: 600;">Cash Total</div><div style="color: #059669; font-weight: 700; font-size: 0.7rem;">{(Number(closingCashTotal) || 0).toFixed(2)}</div></div>
				<div style="border: 0.5px solid #dbeafe; padding: 0.15rem; text-align: center;"><div style="font-weight: 600;">Total Sales</div><div style="color: #3b82f6; font-weight: 700; font-size: 0.7rem;">{((Number(totalCashSales) || 0) + (Number(totalBankSales) || 0)).toFixed(2)}</div></div>
			</div>
		</div>
	</div>
</div>

<style>
	.close-box-container {
		width: 100%;
		height: 100%;
		background: white;
		padding: 0.0625rem 0.25rem 0.25rem 0.25rem;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.top-info-row {
		display: grid;
		grid-template-columns: repeat(5, 1fr);
		gap: 0.5rem;
	}

	.info-group {
		display: flex;
		flex-direction: row;
		gap: 0.5rem;
		align-items: center;
		justify-content: center;
		padding: 0.375rem 0.75rem;
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border: 2px solid #86efac;
		border-radius: 0.75rem;
		box-shadow: 0 4px 6px -1px rgba(34, 197, 94, 0.1);
	}

	.info-label {
		font-size: 0.75rem;
		font-weight: 700;
		color: #ea580c;
		white-space: nowrap;
	}

	.info-value {
		font-size: 0.875rem;
		font-weight: 600;
		color: #166534;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.pos-display-inline {
		padding: 0.25rem 0.75rem;
		background: #dbeafe;
		color: #1e40af;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 700;
		display: inline-block;
	}

	.two-cards-row {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.5rem;
		flex: 1;
		min-height: 0;
	}

	.half-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		padding: 0.5rem;
		height: 100%;
		position: relative;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.split-card {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		padding: 0;
		overflow-y: auto;
	}

	.split-section {
		flex: 1;
		min-height: 200px;
		background: white;
		border: 2px solid #f97316;
		padding: 0.5rem;
		position: relative;
		border-radius: 0.5rem;
		display: flex;
		flex-direction: column;
	}

	.split-section:nth-child(1) {
		flex: 1;
		min-height: 200px;
	}

	.split-section:nth-child(2) {
		flex: 0.6;
		min-height: 140px;
	}

	.split-section:nth-child(3) {
		flex: 0.7;
		min-height: 130px;
	}

	.split-section:nth-child(4) {
		flex: 0.7;
		min-height: 130px;
	}

	/* Left column specific sizes (Cards 7 & 8) */
	.half-card:first-child .split-section:nth-child(1) {
		flex: 1.6;
		min-height: 450px;
	}

	.half-card:first-child .split-section:nth-child(2) {
		flex: 0.8;
		min-height: 240px;
	}

	.half-card:first-child .split-section:nth-child(3) {
		flex: 0.7;
		min-height: 175px;
	}

	.half-card:first-child .split-section:nth-child(4) {
		flex: 0.9;
		min-height: 207px;
	}

	.half-card:first-child .split-section:nth-child(5) {
		flex: 0.85;
		min-height: 179px;
	}

	.half-card:first-child .split-section:nth-child(6) {
		flex: 1.2;
		min-height: 264px;
	}

	/* Recharge Cards Card 11 Styling */
	.recharge-card-section-11 {
		flex: 1.1 !important;
		min-height: 210px !important;
		border: 3px solid #ea580c !important;
		padding: 0.5rem !important;
		margin-top: 0rem !important;
	}

	/* Comparison & Signature Section Styling */
	.comparison-signature-section {
		margin-top: 0rem !important;
	}

	/* ERP Closing Section Styling */
	.erp-closing-section {
		min-height: 240px !important;
	}

	.date-time-row {
		display: flex;
		gap: 0.25rem;
		flex: 1;
		align-items: flex-end;
	}

	.date-time-group {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
		min-width: 0;
		height: 100%;
	}

	.date-time-group label {
		font-size: 0.6rem;
		font-weight: 700;
		color: #1f2937;
		flex-shrink: 0;
	}

	.date-time-input {
		width: 100%;
		padding: 0.3rem 0.4rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #92400e;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		flex: 1;
		box-sizing: border-box;
	}

	.date-time-input:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.time-input-wrapper {
		display: flex;
		gap: 0.25rem;
		align-items: stretch;
	}

	.time-12h {
		flex: 1 !important;
	}

	.ampm-select {
		flex: 0.6;
		padding: 0.3rem 0.3rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		font-size: 0.6rem;
		font-weight: 600;
		color: #92400e;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		cursor: pointer;
	}

	.ampm-select:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.digital-time-picker {
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
		position: relative;
		flex: 1;
	}

	.time-display-btn {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		background: #fef3c7;
		padding: 0.3rem 0.4rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 700;
		color: #92400e;
		cursor: pointer;
		transition: all 0.2s;
		width: 100%;
		flex: 1;
		box-sizing: border-box;
		justify-content: center;
	}

	.time-display-btn:hover {
		background: #fed7aa;
		border-color: #f97316;
	}

	.time-value {
		font-family: 'Courier New', monospace;
		font-size: 0.8rem;
		letter-spacing: 0.05em;
	}

	.ampm-value {
		font-size: 0.6rem;
		margin-left: 0.2rem;
	}

	.picker-popup {
		position: absolute;
		top: 100%;
		left: 0;
		right: 0;
		margin-top: 0.3rem;
		background: white;
		border: 2px solid #f97316;
		border-radius: 0.5rem;
		padding: 0.5rem;
		z-index: 20;
		box-shadow: 0 8px 16px rgba(249, 115, 22, 0.3);
	}

	.picker-controls {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 0.5rem;
	}

	.picker-label {
		display: block;
		font-size: 0.6rem;
		font-weight: 700;
		color: #92400e;
		margin-bottom: 0.2rem;
		text-align: center;
	}

	.close-picker-btn {
		width: 100%;
		padding: 0.3rem 0.5rem;
		background: #f97316;
		border: none;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 700;
		color: white;
		cursor: pointer;
		transition: all 0.2s;
	}

	.close-picker-btn:hover {
		background: #ea580c;
	}

	.picker-row {
		display: flex;
		gap: 0.2rem;
		align-items: center;
		position: relative;
	}

	.picker-column {
		position: relative;
		flex: 1;
	}

	.picker-btn {
		width: 100%;
		padding: 0.3rem 0.25rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		background: white;
		font-size: 0.65rem;
		font-weight: 700;
		color: #92400e;
		cursor: pointer;
		transition: all 0.2s;
		font-family: 'Courier New', monospace;
	}

	.picker-btn:hover {
		background: #fef3c7;
		border-color: #f97316;
	}

	.picker-btn:active {
		transform: scale(0.95);
	}

	.colon {
		font-size: 0.7rem;
		font-weight: 700;
		color: #92400e;
		margin-top: 0.3rem;
	}

	.dropdown-popup {
		position: relative;
		background: white;
		border: 2px solid #fed7aa;
		border-radius: 0.375rem;
		max-height: 120px;
		overflow-y: auto;
		z-index: 10;
	}

	.hours-popup {
		width: 100%;
	}

	.minutes-popup {
		width: 100%;
	}

	.popup-option {
		padding: 0.25rem 0.3rem;
		font-size: 0.6rem;
		font-weight: 600;
		color: #92400e;
		cursor: pointer;
		text-align: center;
		transition: all 0.15s;
		border-bottom: 1px solid #fed7aa;
		font-family: 'Courier New', monospace;
	}

	.popup-option:last-child {
		border-bottom: none;
	}

	.popup-option:hover {
		background: #fef3c7;
	}

	.popup-option.selected {
		background: #f97316;
		color: white;
		font-weight: 700;
	}

	.ampm-select-popup {
		width: 100%;
		padding: 0.25rem 0.3rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		font-size: 0.6rem;
		font-weight: 600;
		color: #92400e;
		background: white;
		cursor: pointer;
	}

	.ampm-select-popup:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.balance-row {
		display: flex;
		gap: 0.25rem;
		flex: 1;
		align-items: flex-end;
	}

	.balance-group {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
		min-width: 0;
		height: 100%;
	}

	.balance-group label {
		font-size: 0.6rem;
		font-weight: 700;
		color: #1f2937;
		flex-shrink: 0;
	}

	.balance-input {
		width: 100%;
		padding: 0.3rem 0.4rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #92400e;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		flex: 1;
		box-sizing: border-box;
	}

	.balance-input:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.balance-input-disabled {
		background: #f3f4f6;
		color: #6b7280;
		border-color: #e5e7eb;
		cursor: not-allowed;
	}

	.balance-input-disabled:focus {
		outline: none;
		border-color: #e5e7eb;
		box-shadow: none;
	}

	.sub-cards-row {
		display: flex;
		gap: 0.5rem;
		flex: 1;
	}

	.sub-card {
		flex: 1;
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border: 2px solid #86efac;
		border-radius: 0.5rem;
		padding: 0.75rem;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.sub-card-header {
		font-size: 0.7rem;
		font-weight: 700;
		color: #166534;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.sub-card-content {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
		flex: 1;
	}

	.difference-row {
		display: flex;
		gap: 0.3rem;
		flex: 1;
	}

	.difference-group {
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
		flex: 1;
	}

	.difference-group label {
		font-size: 0.6rem;
		font-weight: 700;
		color: #166534;
	}

	.difference-input {
		width: 100%;
		padding: 0.25rem 0.3rem;
		border: 2px solid #86efac;
		border-radius: 0.25rem;
		font-size: 0.6rem;
		font-weight: 600;
		color: #166534;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		box-sizing: border-box;
	}

	.difference-input:focus {
		outline: none;
		border-color: #22c55e;
		box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.2);
	}

	.difference-input-disabled {
		background: #f3f4f6;
		color: #6b7280;
		border-color: #e5e7eb;
		cursor: not-allowed;
	}

	.difference-input-disabled:focus {
		outline: none;
		border-color: #e5e7eb;
		box-shadow: none;
	}

	.difference-label {
		font-size: 0.55rem;
		font-weight: 700;
		text-align: center;
		padding: 0.1rem 0.2rem;
		border-radius: 0.25rem;
	}

	.badge-short {
		color: #7f1d1d;
		background: #fee2e2;
	}

	.badge-excess {
		color: #92400e;
		background: #fef3c7;
	}

	.badge-match {
		color: #15803d;
		background: #dcfce7;
	}

	.supervisor-code-input {
		width: 100%;
		padding: 0.25rem 0.35rem;
		border: 2px solid #ea580c;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 600;
		color: #000;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		box-sizing: border-box;
	}

	.supervisor-code-input::placeholder {
		color: #9ca3af;
	}

	.supervisor-code-input:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.save-button {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 2px solid #ea580c;
		border-radius: 0.25rem;
		background: #ea580c;
		color: white;
		font-size: 0.7rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		box-sizing: border-box;
	}

	.save-button:hover {
		background: #d94800;
		border-color: #d94800;
	}

	.save-button:active {
		transform: scale(0.98);
	}

	.save-button:disabled {
		background: #cbd5e1;
		border-color: #cbd5e1;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.save-button:disabled:hover {
		background: #cbd5e1;
		border-color: #cbd5e1;
	}

	/* Right column specific sizes */
	.half-card:last-child .split-section:nth-child(1) {
		flex: 0.8;
		min-height: 150px;
	}

	.half-card:last-child .split-section:nth-child(2) {
		flex: 1.2;
		min-height: 220px;
	}

	.half-card:last-child .split-section:nth-child(3) {
		flex: 1.1;
		min-height: 200px;
	}

	.half-card:last-child .split-section:nth-child(4) {
		flex: 1.0;
		min-height: 180px;
	}

	.split-section:first-child {
		border-radius: 0.5rem 0.5rem 0 0;
	}

	.split-section:last-child {
		border-radius: 0 0 0.5rem 0.5rem;
	}

	.split-section:only-child {
		border-radius: 0.5rem;
	}

	.blank-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		position: relative;
		padding: 1rem;
	}

	.info-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		padding: 0.75rem;
		position: relative;
	}

	.card-number {
		position: absolute;
		top: 0.25rem;
		right: 0.25rem;
		background: #3b82f6;
		color: white;
		width: 1.25rem;
		height: 1.25rem;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.625rem;
		font-weight: 700;
		z-index: 1;
	}

	.card-header-text {
		font-size: 0.7rem;
		font-weight: 600;
		color: #1f2937;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		margin-bottom: 0.5rem;
	}

	.card-content-center {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		gap: 0.5rem;
		padding: 0.5rem;
	}

	.pos-label {
		font-size: 0.625rem;
		color: #6b7280;
		font-weight: 500;
	}

	.pos-display {
		padding: 0.375rem 0.75rem;
		background: #dbeafe;
		color: #1e40af;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 700;
	}

	.card-content {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.info-row {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.info-row .label {
		font-size: 0.625rem;
		color: #6b7280;
		font-weight: 500;
	}

	.info-row .value {
		font-size: 0.75rem;
		color: #1f2937;
		font-weight: 600;
	}

	.amount-value {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.75rem;
		color: #1f2937;
		font-weight: 600;
	}

	.currency-icon {
		width: 0.375rem;
		height: 0.375rem;
		object-fit: contain;
	}

	.closing-cash-grid-2row {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 0.4rem;
		margin-bottom: 1rem;
	}

	.denom-input-group {
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 0.3rem;
	}

	.denom-label-with-checkbox {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		flex-shrink: 0;
	}

	.denom-verify-checkbox {
		width: 1rem;
		height: 1rem;
		cursor: pointer;
		accent-color: #059669;
		flex-shrink: 0;
	}

	.denom-verify-checkbox:disabled {
		cursor: not-allowed;
		opacity: 0.5;
	}

	.denom-input-wrapper {
		flex: 1;
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 0.4rem;
		min-width: 0;
	}

	.denom-values-display {
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
		flex-shrink: 0;
	}

	.denom-original-value {
		display: flex;
		align-items: center;
		gap: 0.2rem;
		font-size: 0.5rem;
		padding: 0.15rem 0.3rem;
		background: #e0e7ff;
		border-radius: 0.25rem;
		white-space: nowrap;
	}

	.denom-original-value .original-label {
		font-weight: 600;
		color: #4338ca;
	}

	.denom-original-value .original-count {
		font-weight: 700;
		color: #3730a3;
	}

	.denom-total {
		display: flex;
		align-items: center;
		gap: 0.2rem;
		font-size: 0.55rem;
		font-weight: 600;
		color: #059669;
		white-space: nowrap;
		flex-shrink: 0;
	}

	.currency-icon-tiny {
		width: 0.65rem;
		height: 0.65rem;
		object-fit: contain;
	}

	.denom-input-group label {
		font-size: 0.6rem;
		font-weight: 700;
		color: #ea580c;
		display: flex;
		align-items: center;
		gap: 0.2rem;
		white-space: nowrap;
		flex-shrink: 0;
		min-width: 2.5rem;
		justify-content: flex-start;
	}

	.denom-input-wrapper input {
		flex: 0 0 auto;
		min-width: 0;
		width: 5rem;
		padding: 0.3rem 0.4rem;
		border: 2px solid #d1fae5;
		border-radius: 0.375rem;
		font-size: 0.65rem;
		background: white;
		font-weight: 600;
		color: #166534;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(34, 197, 94, 0.1);
		transition: all 0.2s;
	}

	.denom-input-wrapper input:focus {
		outline: none;
		border-color: #22c55e;
		box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.2), 0 4px 6px rgba(34, 197, 94, 0.15);
		transform: translateY(-1px);
	}

	.denom-input-wrapper input.denom-edited {
		background: #fef3c7;
		border-color: #fbbf24;
		color: #92400e;
		font-weight: 700;
	}

	.denom-input-wrapper input.denom-edited:focus {
		border-color: #f59e0b;
		box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.2), 0 4px 6px rgba(245, 158, 11, 0.15);
	}

	.currency-icon-small {
		width: 0.4rem;
		height: 0.4rem;
		object-fit: contain;
	}

	.closing-total {
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #1e40af;
		border: 2px solid #93c5fd;
		box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
	}

	.closing-total .label {
		font-size: 0.65rem;
	}

	.closing-total .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	.cash-sales {
		background: linear-gradient(135deg, #dcfce7 0%, #bbf7d0 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #166534;
		border: 2px solid #86efac;
		box-shadow: 0 4px 6px -1px rgba(34, 197, 94, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
		margin-top: 0.375rem;
	}

	.cash-sales .label {
		font-size: 0.65rem;
	}

	.cash-sales .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	.voucher-input-row {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 0.4rem;
	}

	.voucher-serial-input {
		flex: 1.5;
		padding: 0.2rem 0.3rem;
		border: 2px solid #fed7aa;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
	}

	.voucher-serial-input:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.voucher-amount-input {
		flex: 1;
		padding: 0.2rem 0.3rem;
		border: 2px solid #d1fae5;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #166534;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
	}

	.voucher-amount-input:focus {
		outline: none;
		border-color: #22c55e;
		box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.2);
	}

	.add-voucher-btn {
		width: 1.5rem;
		height: 1.5rem;
		background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
		border: none;
		border-radius: 0.25rem;
		color: white;
		font-size: 1rem;
		font-weight: 700;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 4px 6px rgba(34, 197, 94, 0.3);
		transition: all 0.2s;
	}

	.add-voucher-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 8px rgba(34, 197, 94, 0.4);
	}

	.add-voucher-btn:active {
		transform: translateY(0);
	}

	.vouchers-table {
		max-height: 150px;
		overflow-y: auto;
		margin-bottom: 0.5rem;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		flex: 1;
	}

	.vouchers-table table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.65rem;
	}

	.vouchers-table thead {
		background: #f9fafb;
		position: sticky;
		top: 0;
	}

	.vouchers-table th {
		padding: 0.25rem 0.35rem;
		text-align: left;
		font-weight: 700;
		color: #6b7280;
		border-bottom: 1px solid #e5e7eb;
	}

	.vouchers-table td {
		padding: 0.25rem 0.35rem;
		border-bottom: 1px solid #f3f4f6;
	}

	.vouchers-table tbody tr:hover {
		background: #f9fafb;
	}

	.voucher-verify-checkbox {
		width: 1rem;
		height: 1rem;
		cursor: pointer;
		accent-color: #059669;
	}

	.voucher-verify-checkbox:disabled {
		cursor: not-allowed;
		opacity: 0.5;
	}

	.voucher-cell-wrapper {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.voucher-editable-input {
		padding: 0.25rem 0.4rem;
		border: 2px solid #d1fae5;
		border-radius: 0.375rem;
		font-size: 0.65rem;
		background: white;
		font-weight: 600;
		color: #166534;
		width: 100%;
		box-sizing: border-box;
	}

	.voucher-editable-input:focus {
		outline: none;
		border-color: #22c55e;
		box-shadow: 0 0 0 2px rgba(34, 197, 94, 0.2);
		background: #f0fdf4;
	}

	.voucher-editable-input.voucher-edited {
		background: #fef3c7;
		border-color: #fbbf24;
		color: #92400e;
		font-weight: 700;
	}

	.voucher-editable-input.voucher-edited:focus {
		border-color: #f59e0b;
		box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.2);
	}

	.voucher-amount-display {
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.voucher-amount-input {
		flex: 1;
		min-width: 80px;
	}

	.voucher-original-value {
		display: flex;
		align-items: center;
		gap: 0.2rem;
		font-size: 0.5rem;
		padding: 0.15rem 0.3rem;
		background: #e0e7ff;
		border-radius: 0.25rem;
		white-space: nowrap;
	}

	.voucher-original-value .original-label {
		font-weight: 600;
		color: #4338ca;
	}

	.voucher-original-value .original-value {
		font-weight: 700;
		color: #3730a3;
	}

	/* Bank Edit Styles */
	.bank-field-header {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		margin-bottom: 0.3rem;
	}

	.bank-verify-checkbox {
		width: 0.8rem;
		height: 0.8rem;
		cursor: pointer;
		accent-color: #22c55e;
	}

	.bank-editable-input {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 2px solid #e5e7eb;
		border-radius: 0.375rem;
		font-size: 0.7rem;
		font-weight: 600;
		color: #166534;
		transition: all 0.2s;
		cursor: pointer;
	}

	.bank-editable-input[readonly] {
		background: #f9fafb;
		cursor: pointer;
	}

	.bank-editable-input:not([readonly]) {
		background: white;
		cursor: text;
	}

	.bank-editable-input:hover {
		border-color: #d1d5db;
		background: #f0fdf4;
	}

	.bank-editable-input.bank-edited {
		background: #fef3c7;
		border-color: #fbbf24;
		color: #92400e;
		font-weight: 700;
	}

	.bank-editable-input.bank-edited:focus {
		border-color: #f59e0b;
		box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.2);
	}

	.bank-amount-display {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.bank-original-value {
		display: flex;
		align-items: center;
		gap: 0.2rem;
		font-size: 0.5rem;
		padding: 0.15rem 0.3rem;
		background: #e0e7ff;
		border-radius: 0.25rem;
		white-space: nowrap;
	}

	.bank-original-value .original-label {
		font-weight: 600;
		color: #4338ca;
	}

	.bank-original-value .original-value {
		font-weight: 700;
		color: #3730a3;
	}

	/* System Sales Edit Styles */
	.system-field-header {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		margin-bottom: 0.3rem;
	}

	.system-verify-checkbox {
		width: 0.8rem;
		height: 0.8rem;
		cursor: pointer;
		accent-color: #22c55e;
	}

	.system-editable-input {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 2px solid #e5e7eb;
		border-radius: 0.375rem;
		font-size: 0.7rem;
		font-weight: 600;
		color: #166534;
		transition: all 0.2s;
		cursor: pointer;
	}

	.system-editable-input[readonly] {
		background: #f9fafb;
		cursor: pointer;
	}

	.system-editable-input:not([readonly]) {
		background: white;
		cursor: text;
	}

	.system-editable-input:hover {
		border-color: #d1d5db;
		background: #f0fdf4;
	}

	.system-editable-input.system-edited {
		background: #fef3c7;
		border-color: #fbbf24;
		color: #92400e;
		font-weight: 700;
	}

	.system-editable-input.system-edited:focus {
		border-color: #f59e0b;
		box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.2);
	}

	.system-amount-display {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.system-original-value {
		display: flex;
		align-items: center;
		gap: 0.2rem;
		font-size: 0.5rem;
		padding: 0.15rem 0.3rem;
		background: #e0e7ff;
		border-radius: 0.25rem;
		white-space: nowrap;
	}

	.system-original-value .original-label {
		font-weight: 600;
		color: #4338ca;
	}

	.system-original-value .original-value {
		font-weight: 700;
		color: #3730a3;
	}

	/* Recharge Card Edit Styles */
	.recharge-field-header {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		margin-bottom: 0.3rem;
	}

	.recharge-verify-checkbox {
		width: 0.8rem;
		height: 0.8rem;
		cursor: pointer;
		accent-color: #22c55e;
	}

	.recharge-editable-input {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 2px solid #e5e7eb;
		border-radius: 0.375rem;
		font-size: 0.7rem;
		font-weight: 600;
		color: #166534;
		transition: all 0.2s;
		cursor: pointer;
	}

	.recharge-editable-input[readonly] {
		background: #f9fafb;
		cursor: pointer;
	}

	.recharge-editable-input:not([readonly]) {
		background: white;
		cursor: text;
	}

	.recharge-editable-input:hover {
		border-color: #d1d5db;
		background: #f0fdf4;
	}

	.recharge-editable-input.recharge-edited {
		background: #fef3c7;
		border-color: #fbbf24;
		color: #92400e;
		font-weight: 700;
	}

	.recharge-editable-input.recharge-edited:focus {
		border-color: #f59e0b;
		box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.2);
	}

	.recharge-amount-display {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.recharge-original-value {
		display: flex;
		align-items: center;
		gap: 0.2rem;
		font-size: 0.5rem;
		padding: 0.15rem 0.3rem;
		background: #e0e7ff;
		border-radius: 0.25rem;
		white-space: nowrap;
	}

	.recharge-original-value .original-label {
		font-weight: 600;
		color: #4338ca;
	}

	.recharge-original-value .original-value {
		font-weight: 700;
		color: #3730a3;
	}

	/* DateTime Edit Styles */
	.datetime-field-header {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		margin-bottom: 0.3rem;
	}

	.datetime-verify-checkbox {
		width: 0.8rem;
		height: 0.8rem;
		cursor: pointer;
		accent-color: #22c55e;
	}

	.datetime-input-display {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.datetime-editable-input {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 2px solid #e5e7eb;
		border-radius: 0.375rem;
		font-size: 0.7rem;
		font-weight: 600;
		color: #166534;
		transition: all 0.2s;
		cursor: pointer;
	}

	.datetime-editable-input[readonly] {
		background: #f9fafb;
		cursor: pointer;
	}

	.datetime-editable-input:not([readonly]) {
		background: white;
		cursor: text;
	}

	.datetime-editable-input:hover {
		border-color: #d1d5db;
		background: #f0fdf4;
	}

	.datetime-editable-input.datetime-edited {
		background: #fef3c7;
		border-color: #fbbf24;
		color: #92400e;
		font-weight: 700;
	}

	.datetime-editable-input.datetime-edited:focus {
		border-color: #f59e0b;
		box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.2);
	}

	.datetime-original-value {
		display: flex;
		align-items: center;
		gap: 0.2rem;
		font-size: 0.5rem;
		padding: 0.15rem 0.3rem;
		background: #e0e7ff;
		border-radius: 0.25rem;
		white-space: nowrap;
	}

	.datetime-original-value .original-label {
		font-weight: 600;
		color: #4338ca;
	}

	.datetime-original-value .original-value {
		font-weight: 700;
		color: #3730a3;
	}

	.amount-cell {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-weight: 600;
		color: #166534;
	}

	.remove-btn {
		background: #fee2e2;
		border: none;
		color: #dc2626;
		width: 1.25rem;
		height: 1.25rem;
		border-radius: 0.25rem;
		font-size: 1rem;
		font-weight: 700;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}

	.remove-btn:hover {
		background: #fecaca;
		transform: scale(1.1);
	}

	.vouchers-total {
		background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
		padding: 0.35rem 0.5rem;
		border-radius: 0.375rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #92400e;
		border: 2px solid #fcd34d;
		box-shadow: 0 4px 6px -1px rgba(245, 158, 11, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
	}

	.vouchers-total .label {
		font-size: 0.7rem;
	}

	.vouchers-total .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.8rem;
	}

	.total-cash-sales {
		background: linear-gradient(135deg, #fed7aa 0%, #fdba74 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #9a3412;
		border: 2px solid #fb923c;
		box-shadow: 0 6px 8px -1px rgba(249, 115, 22, 0.3), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
		margin-top: 0.375rem;
	}

	.total-cash-sales .label {
		font-size: 0.65rem;
	}

	.total-cash-sales .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	.total-bank-sales {
		background: linear-gradient(135deg, #e0e7ff 0%, #c7d2fe 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #3730a3;
		border: 2px solid #a5b4fc;
		box-shadow: 0 6px 8px -1px rgba(79, 70, 229, 0.3), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
		margin-top: 0.375rem;
	}

	.total-bank-sales .label {
		font-size: 0.65rem;
	}

	.total-bank-sales .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	.total-sales {
		background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #065f46;
		border: 2px solid #6ee7b7;
		box-shadow: 0 6px 8px -1px rgba(16, 185, 129, 0.3), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
		margin-top: 0.375rem;
	}

	.total-sales .label {
		font-size: 0.65rem;
	}

	.total-sales .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	/* Bank Reconciliation Styles */
	.bank-fields-row {
		display: flex;
		gap: 0.35rem;
		margin-bottom: 0.75rem;
		flex-wrap: nowrap;
	}

	.bank-input-group {
		flex: 1;
		min-width: 0;
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
	}

	.bank-input-group label {
		font-size: 0.6rem;
		font-weight: 700;
		color: #1f2937;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.bank-input {
		width: 100%;
		padding: 0.25rem 0.3rem;
		border: 2px solid #bfdbfe;
		border-radius: 0.25rem;
		font-size: 0.6rem;
		font-weight: 600;
		color: #1e40af;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		min-width: 0;
	}

	.bank-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.bank-total {
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
		padding: 0.35rem 0.5rem;
		border-radius: 0.375rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #1e40af;
		border: 2px solid #93c5fd;
		box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
	}

	.bank-total .label {
		font-size: 0.7rem;
	}

	.bank-total .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.8rem;
	}

	/* System Sales Styles */
	.system-sales-row {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 0.75rem;
	}

	.system-input-group {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.system-input-group label {
		font-size: 0.65rem;
		font-weight: 700;
		color: #1f2937;
	}

	.system-input {
		width: 100%;
		padding: 0.25rem 0.3rem;
		border: 2px solid #e9d5ff;
		border-radius: 0.25rem;
		font-size: 0.6rem;
		font-weight: 600;
		color: #7c3aed;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		min-width: 0;
	}

	.system-input:focus {
		outline: none;
		border-color: #a855f7;
		box-shadow: 0 0 0 3px rgba(168, 85, 247, 0.1);
	}

	.system-total-1 {
		background: linear-gradient(135deg, #fce7f3 0%, #fbcfe8 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #be185d;
		border: 2px solid #f9a8d4;
		box-shadow: 0 4px 6px -1px rgba(219, 39, 119, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
		margin-top: 0.375rem;
	}

	.system-total-1 .label {
		font-size: 0.65rem;
	}

	.system-total-1 .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	.system-total-2 {
		background: linear-gradient(135deg, #f3e8ff 0%, #e9d5ff 100%);
		padding: 0.55rem;
		border-radius: 0.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-weight: 700;
		color: #7c3aed;
		border: 2px solid #c4b5fd;
		box-shadow: 0 4px 6px -1px rgba(124, 58, 237, 0.2), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
		margin-top: 0.375rem;
	}

	.system-total-2 .label {
		font-size: 0.65rem;
	}

	.system-total-2 .amount {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		font-size: 0.75rem;
	}

	/* Recharge Cards Styles */
	.recharge-cards-container {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		flex: 1;
	}

	.recharge-card-section {
		flex: 1;
		padding: 0.5rem;
		background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
		border: 2px solid #7dd3fc;
		border-radius: 0.5rem;
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
	}

	.recharge-card-section.closing-section {
		background: linear-gradient(135deg, #dcfce7 0%, #bbf7d0 100%);
		border-color: #86efac;
	}

	.recharge-card-title {
		font-size: 0.65rem;
		font-weight: 700;
		color: #0c4a6e;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.recharge-card-section.closing-section .recharge-card-title {
		color: #166534;
	}

	.recharge-input-row {
		display: flex;
		gap: 0.3rem;
		flex: 1;
	}

	.recharge-serial-input {
		flex: 1.5;
		padding: 0.3rem 0.4rem;
		border: 2px solid #7dd3fc;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #0c4a6e;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
	}

	.recharge-serial-input:focus {
		outline: none;
		border-color: #0ea5e9;
		box-shadow: 0 0 0 3px rgba(14, 165, 233, 0.2);
	}

	.recharge-amount-input {
		flex: 1;
		padding: 0.3rem 0.4rem;
		border: 2px solid #7dd3fc;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #0c4a6e;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
	}

	.recharge-amount-input:focus {
		outline: none;
		border-color: #0ea5e9;
		box-shadow: 0 0 0 3px rgba(14, 165, 233, 0.2);
	}

	.closing-recharge-status {
		display: flex;
		align-items: center;
		justify-content: center;
		flex: 1;
		padding: 0.5rem;
	}

	.status-label {
		font-size: 0.7rem;
		font-weight: 700;
		color: #166534;
		background: white;
		padding: 0.3rem 0.5rem;
		border-radius: 0.375rem;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.completed-by-wrapper {
		position: relative;
		display: flex;
		align-items: center;
		min-width: 160px;
		max-width: 280px;
	}

	.completed-by-code-input {
		width: 100%;
		padding: 0.3rem 0.4rem;
		height: 1.625rem;
		border: 2px solid #fed7aa;
		border-radius: 0.375rem;
		font-size: 0.65rem;
		font-weight: 600;
		color: #92400e;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
		min-width: 160px;
		max-width: 280px;
		box-sizing: border-box;
	}

	.completed-by-code-input:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.completed-by-name {
		position: absolute;
		top: -1.4rem;
		left: 0;
		font-size: 0.6rem;
		font-weight: 700;
		color: #059669;
		background: #dcfce7;
		padding: 0.2rem 0.4rem;
		border-radius: 0.25rem;
		white-space: nowrap;
		border: 1px solid #86efac;
	}

	.completed-by-error {
		position: absolute;
		top: -1.4rem;
		left: 0;
		font-size: 0.6rem;
		font-weight: 700;
		color: #dc2626;
		background: #fee2e2;
		padding: 0.2rem 0.4rem;
		border-radius: 0.25rem;
		white-space: nowrap;
		border: 1px solid #fecaca;
	}

	.completed-by-code-input::placeholder {
		color: #d97706;
		font-size: 0.65rem;
	}

	.start-closing-btn {
		padding: 0.3rem 0.75rem;
		height: 1.625rem;
		display: flex;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		border: 2px solid #047857;
		border-radius: 0.375rem;
		color: white;
		font-size: 0.7rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 4px 6px -1px rgba(16, 185, 129, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.5px;
		white-space: nowrap;
		box-sizing: border-box;
	}

	.start-closing-btn:hover {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-2px);
		box-shadow: 0 6px 12px -1px rgba(16, 185, 129, 0.4);
	}

	.start-closing-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 4px rgba(16, 185, 129, 0.3);
	}

	.start-closing-btn:disabled {
		background: linear-gradient(135deg, #d1d5db 0%, #9ca3af 100%);
		border-color: #9ca3af;
		cursor: not-allowed;
		opacity: 0.6;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.start-closing-btn:disabled:hover {
		transform: none;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.complete-btn {
		padding: 0.3rem 0.75rem;
		height: 1.625rem;
		display: flex;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		border: 2px solid #1d4ed8;
		border-radius: 0.375rem;
		color: white;
		font-size: 0.7rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.5px;
		white-space: nowrap;
		box-sizing: border-box;
	}

	.complete-btn:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
		transform: translateY(-2px);
		box-shadow: 0 6px 12px -1px rgba(59, 130, 246, 0.4);
	}

	.complete-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.3);
	}

	.complete-btn:disabled {
		background: linear-gradient(135deg, #d1d5db 0%, #9ca3af 100%);
		border-color: #9ca3af;
		cursor: not-allowed;
		opacity: 0.6;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.complete-btn:disabled:hover {
		transform: none;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.add-to-denomination-btn {
		padding: 0.3rem 0.75rem;
		height: 1.625rem;
		display: flex;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		border: 2px solid #b45309;
		border-radius: 0.375rem;
		color: white;
		font-size: 0.7rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 4px 6px -1px rgba(245, 158, 11, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.5px;
		white-space: nowrap;
		box-sizing: border-box;
	}

	.add-to-denomination-btn:hover {
		background: linear-gradient(135deg, #d97706 0%, #b45309 100%);
		transform: translateY(-2px);
		box-shadow: 0 6px 12px -1px rgba(245, 158, 11, 0.4);
	}

	.add-to-denomination-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 4px rgba(245, 158, 11, 0.3);
	}

	.add-to-denomination-btn:disabled {
		background: linear-gradient(135deg, #d1d5db 0%, #9ca3af 100%);
		border-color: #9ca3af;
		cursor: not-allowed;
		opacity: 0.6;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.add-to-denomination-btn:disabled:hover {
		transform: none;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.complete-btn:disabled {
		background: linear-gradient(135deg, #d1d5db 0%, #9ca3af 100%);
		border-color: #9ca3af;
		cursor: not-allowed;
		opacity: 0.6;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.complete-btn:disabled:hover {
		transform: none;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.button-row {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 0.5rem;
		align-items: flex-start;
	}

	.view-closing-btn {
		padding: 0.3rem 0.75rem;
		height: 1.625rem;
		display: flex;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		border: 2px solid #1d4ed8;
		border-radius: 0.375rem;
		color: white;
		font-size: 0.7rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.5px;
		white-space: nowrap;
		box-sizing: border-box;
	}

	.view-closing-btn:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
		transform: translateY(-2px);
		box-shadow: 0 6px 12px -1px rgba(59, 130, 246, 0.4);
	}

	.view-closing-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.3);
	}

	.view-closing-btn:disabled {
		background: linear-gradient(135deg, #d1d5db 0%, #9ca3af 100%);
		border-color: #9ca3af;
		cursor: not-allowed;
		opacity: 0.6;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.view-closing-btn:disabled:hover {
		transform: none;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	/* Modal Styles - Removed, now opens in separate window */

	/* Voucher Status Check Button */
	.check-status-btn {
		padding: 0.3rem 0.6rem;
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		border: 2px solid #065f46;
		border-radius: 0.375rem;
		color: white;
		font-size: 0.65rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 4px 6px -1px rgba(5, 150, 105, 0.3);
		margin-bottom: 0.5rem;
	}

	.check-status-btn:hover {
		background: linear-gradient(135deg, #047857 0%, #065f46 100%);
		transform: translateY(-1px);
		box-shadow: 0 6px 8px -2px rgba(5, 150, 105, 0.4);
	}

	.check-status-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 4px rgba(5, 150, 105, 0.3);
	}

	.check-status-btn:disabled {
		background: #d1d5db;
		border-color: #9ca3af;
		cursor: not-allowed;
		opacity: 0.6;
		box-shadow: none;
	}

	/* Voucher Status Modal */
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

	.voucher-status-modal {
		background: white;
		border-radius: 0.5rem;
		width: 90%;
		max-width: 600px;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem;
		border-bottom: 2px solid #f97316;
		background: linear-gradient(135deg, #fff7ed 0%, #ffedd5 100%);
	}

	.modal-header h3 {
		margin: 0;
		font-size: 1rem;
		font-weight: 700;
		color: #92400e;
	}

	.modal-close-btn {
		background: none;
		border: none;
		font-size: 1.5rem;
		color: #92400e;
		cursor: pointer;
		padding: 0;
		width: 2rem;
		height: 2rem;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 0.25rem;
		transition: all 0.2s;
	}

	.modal-close-btn:hover {
		background: rgba(249, 115, 22, 0.1);
		color: #f97316;
	}

	.modal-body {
		padding: 1rem;
		overflow-y: auto;
		flex: 1;
	}

	.status-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.75rem;
	}

	.status-table thead {
		background: #f97316;
		color: white;
	}

	.status-table th {
		padding: 0.5rem;
		text-align: left;
		font-weight: 700;
		border: 1px solid #ea580c;
	}

	.status-table td {
		padding: 0.5rem;
		border: 1px solid #fed7aa;
	}

	.status-table tbody tr:hover {
		background: #fff7ed;
	}

	.status-table tbody tr.not-found {
		background: #fee2e2;
	}

	.status-badge {
		display: inline-block;
		padding: 0.25rem 0.5rem;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 700;
		text-transform: uppercase;
	}

	.status-badge.status-stocked {
		background: #d1fae5;
		color: #065f46;
		border: 1px solid #10b981;
	}

	.status-badge.status-issued {
		background: #fef3c7;
		color: #92400e;
		border: 1px solid #f59e0b;
	}

	.status-badge.status-not-found {
		background: #fee2e2;
		color: #991b1b;
		border: 1px solid #ef4444;
	}

	.action-btn {
		padding: 0.375rem 0.75rem;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.75rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		text-transform: uppercase;
	}

	.action-btn.issue-btn {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
	}

	.action-btn.issue-btn:hover {
		box-shadow: 0 4px 8px rgba(16, 185, 129, 0.3);
		transform: translateY(-1px);
	}

	.action-btn.close-btn {
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		color: white;
	}

	.action-btn.close-btn:hover {
		box-shadow: 0 4px 8px rgba(245, 158, 11, 0.3);
		transform: translateY(-1px);
	}

	.no-action {
		color: #9ca3af;
		font-size: 0.75rem;
	}

	/* Print Modal Styles */
	.print-modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1001;
	}

	.print-modal {
		background: white;
		border-radius: 0.5rem;
		width: 95%;
		max-width: 1200px;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
	}

	.print-modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem;
		border-bottom: 2px solid #3b82f6;
		background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
	}

	.print-modal-header h3 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 700;
		color: #1e40af;
	}

	.print-modal-close-btn {
		background: none;
		border: none;
		font-size: 1.5rem;
		color: #1e40af;
		cursor: pointer;
		padding: 0;
		width: 2rem;
		height: 2rem;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 0.25rem;
		transition: all 0.2s;
	}

	.print-modal-close-btn:hover {
		background: rgba(59, 130, 246, 0.1);
		color: #3b82f6;
	}

	.print-modal-body {
		padding: 1.5rem;
		overflow-y: auto;
		flex: 1;
		background: #f9fafb;
	}

	.a4-print-container {
		background: white;
		padding: 2rem;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
		width: 100%;
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
	}

	.print-cards-row {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
	}

	.print-card {
		background: white;
		border: 2px solid #3b82f6;
		border-radius: 0.5rem;
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.1);
		page-break-inside: avoid;
		min-height: 200px;
	}

	.print-card-header {
		font-size: 0.9rem;
		font-weight: 700;
		color: #1e40af;
		border-bottom: 2px solid #dbeafe;
		padding-bottom: 0.5rem;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.print-card-content {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		flex: 1;
	}

	.print-info-row {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		gap: 0.5rem;
		font-size: 0.85rem;
		padding: 0.25rem 0;
		border-bottom: 1px solid #f3f4f6;
	}

	.print-info-row:last-child {
		border-bottom: none;
	}

	.print-label {
		font-weight: 600;
		color: #4b5563;
		min-width: 120px;
		flex-shrink: 0;
	}

	.print-value {
		color: #1f2937;
		font-weight: 500;
		text-align: right;
		flex: 1;
		word-break: break-word;
	}

	.print-small-text {
		font-size: 0.75rem;
	}

	.print-small-text .print-info-row {
		font-size: 0.75rem;
	}

	.print-small-text .print-label {
		min-width: 100px;
	}

	.short-value {
		color: #dc2626;
		font-weight: 700;
	}

	.excess-value {
		color: #059669;
		font-weight: 700;
	}

	.print-note-row {
		background: #fef3c7;
		padding: 0.5rem !important;
		border-radius: 0.25rem;
		border-bottom: none !important;
		margin-top: 0.25rem;
	}

	.print-note-text {
		font-size: 0.75rem;
		color: #92400e;
		font-style: italic;
	}

	.print-signature-field {
		height: 3rem;
		border-bottom: 2px solid #1f2937;
		width: 100%;
	}

	.print-modal-footer {
		display: flex;
		gap: 1rem;
		padding: 1rem;
		border-top: 2px solid #e5e7eb;
		background: #f9fafb;
		justify-content: flex-end;
	}

	.print-btn {
		padding: 0.5rem 1.5rem;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		border: 2px solid #1d4ed8;
		border-radius: 0.375rem;
		color: white;
		font-size: 0.9rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.print-btn:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
		transform: translateY(-2px);
		box-shadow: 0 6px 12px -1px rgba(59, 130, 246, 0.4);
	}

	.print-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.3);
	}

	.close-print-modal-btn {
		padding: 0.5rem 1.5rem;
		background: #ef4444;
		border: 2px solid #dc2626;
		border-radius: 0.375rem;
		color: white;
		font-size: 0.9rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 4px 6px -1px rgba(239, 68, 68, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.close-print-modal-btn:hover {
		background: #dc2626;
		transform: translateY(-2px);
		box-shadow: 0 6px 12px -1px rgba(239, 68, 68, 0.4);
	}

	.close-print-modal-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 4px rgba(239, 68, 68, 0.3);
	}

	/* Print Media Query for A4 Size */
	@media print {
		html, body {
			width: 100% !important;
			height: 100% !important;
			margin: 0 !important;
			padding: 0 !important;
		}

		.print-modal-overlay {
			position: static !important;
			background: white !important;
			display: block !important;
			width: 100% !important;
			height: 100% !important;
			padding: 0 !important;
			margin: 0 !important;
		}

		.print-modal {
			position: static !important;
			width: 100% !important;
			max-width: 100% !important;
			height: 100% !important;
			max-height: 100% !important;
			border: none !important;
			border-radius: 0 !important;
			box-shadow: none !important;
			margin: 0 !important;
			padding: 0 !important;
			display: block !important;
		}

		.print-modal-header,
		.print-modal-footer {
			display: none !important;
		}

		.print-modal-body {
			padding: 0.5rem !important;
			background: white !important;
			overflow: visible !important;
			position: static !important;
			width: 100% !important;
			height: 100% !important;
		}

		.a4-print-container {
			width: 100% !important;
			padding: 0.25rem !important;
			border: none !important;
			box-shadow: none !important;
			background: white !important;
			display: flex !important;
			flex-direction: column !important;
			gap: 0.75rem !important;
		}

		.print-cards-row {
			display: grid !important;
			grid-template-columns: repeat(2, 1fr) !important;
			gap: 0.75rem !important;
			page-break-inside: avoid !important;
			margin-bottom: 0.75rem !important;
		}

		.print-card {
			border: 1px solid #3b82f6 !important;
			background: white !important;
			page-break-inside: avoid !important;
			min-height: auto !important;
			padding: 0.5rem !important;
			font-size: 0.7rem !important;
			box-shadow: none !important;
		}

		.print-card-header {
			font-size: 0.75rem !important;
			font-weight: 700 !important;
			color: #1e40af !important;
			border-bottom: 1px solid #dbeafe !important;
			padding-bottom: 0.3rem !important;
			margin-bottom: 0.3rem !important;
		}

		.print-label {
			font-size: 0.65rem !important;
			min-width: 80px !important;
		}

		.print-value {
			font-size: 0.65rem !important;
		}

		.print-info-row {
			padding: 0.15rem 0 !important;
			border-bottom: 0.5px solid #e5e7eb !important;
			font-size: 0.65rem !important;
		}

		.print-card-content {
			gap: 0.2rem !important;
		}
	}
</style>


