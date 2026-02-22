<script lang="ts">
	import { onMount } from 'svelte';
	import html2canvas from 'html2canvas';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import ReportIncident from '$lib/components/desktop-interface/master/hr/ReportIncident.svelte';

	export let windowId: string;
	export let operation: any;
	export let branch: any;

	let currencySymbolUrl = '/icons/saudi-currency.png';

	// Parse notes JSON to get names and POS number
	let operationData: any = {};
	let selectedPosNumber = 1;
	
	console.log('📦 CloseBox received operation:', operation);
	
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

	// Closing cash counts
	let closingCounts: Record<string, number> = {};
	Object.keys(denomValues).forEach(key => {
		closingCounts[key] = 0;
	});

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
				alert($currentLocale === 'ar' ? 'هذه القسيمة (نفس الرقم التسلسلي والمبلغ) موجودة بالفعل!' : 'This voucher (same serial and amount) already exists!');
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

	// Bank reconciliation payment methods (kept for backward compat in save)
	let madaAmount: number | '' = '';
	let visaAmount: number | '' = '';
	let masterCardAmount: number | '' = '';
	let googlePayAmount: number | '' = '';
	let otherAmount: number | '' = '';

	// Multiple reconciliations list
	let reconciliations: Array<{id?: number, reconciliation_number: string, mada: number, visa: number, mastercard: number, google_pay: number, other: number}> = [];
	let showReconPopup = false;
	let reconForm = { reconciliation_number: '', mada: '', visa: '', mastercard: '', google_pay: '', other: '' };
	let editingReconIndex: number | null = null;

	function openReconPopup(index?: number) {
		if (index !== undefined && index !== null) {
			editingReconIndex = index;
			const r = reconciliations[index];
			reconForm = { reconciliation_number: r.reconciliation_number, mada: r.mada, visa: r.visa, mastercard: r.mastercard, google_pay: r.google_pay, other: r.other };
		} else {
			editingReconIndex = null;
			reconForm = { reconciliation_number: '', mada: '', visa: '', mastercard: '', google_pay: '', other: '' };
		}
		showReconPopup = true;
	}

	function closeReconPopup() {
		showReconPopup = false;
		editingReconIndex = null;
	}

	function saveRecon() {
		const entry = {
			reconciliation_number: reconForm.reconciliation_number,
			mada: Number(reconForm.mada) || 0,
			visa: Number(reconForm.visa) || 0,
			mastercard: Number(reconForm.mastercard) || 0,
			google_pay: Number(reconForm.google_pay) || 0,
			other: Number(reconForm.other) || 0
		};
		if (editingReconIndex !== null) {
			reconciliations[editingReconIndex] = entry;
		} else {
			reconciliations = [...reconciliations, entry];
		}
		reconciliations = reconciliations; // trigger reactivity
		// Sync legacy amounts for backward compat (sum all)
		syncLegacyAmounts();
		closeReconPopup();
	}

	function removeRecon(index: number) {
		reconciliations = reconciliations.filter((_, i) => i !== index);
		syncLegacyAmounts();
	}

	function syncLegacyAmounts() {
		madaAmount = reconciliations.reduce((s, r) => s + (r.mada || 0), 0);
		visaAmount = reconciliations.reduce((s, r) => s + (r.visa || 0), 0);
		masterCardAmount = reconciliations.reduce((s, r) => s + (r.mastercard || 0), 0);
		googlePayAmount = reconciliations.reduce((s, r) => s + (r.google_pay || 0), 0);
		otherAmount = reconciliations.reduce((s, r) => s + (r.other || 0), 0);
	}

	function getReconTotal(r: any): number {
		return (r.mada || 0) + (r.visa || 0) + (r.mastercard || 0) + (r.google_pay || 0) + (r.other || 0);
	}

	// Calculate bank reconciliation total
	$: bankTotal = (Number(madaAmount) || 0) + (Number(visaAmount) || 0) + (Number(masterCardAmount) || 0) + (Number(googlePayAmount) || 0) + (Number(otherAmount) || 0);

	// Calculate total sales (total cash sales + total bank sales)
	$: totalSales = totalCashSales + bankTotal;

	// System sales
	let systemCashSales: number | '' = '';
	let systemCardSales: number | '' = '';
	let systemReturn: number | '' = '';

	// Calculate system sales totals
	$: totalSystemCashSales = (Number(systemCashSales) || 0) - (Number(systemReturn) || 0);
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

	// Auto-calculate sales
	$: sales = (Number(closeBalance) || 0) - (Number(openingBalance) || 0);

	// Differences fields
	let differenceInCashSales: number = 0;
	let differenceInCardSales: number = 0;

	// Auto-calculate difference in cash sales (total cash sales - (system cash sales - returns))
	$: differenceInCashSales = Math.round((totalCashSales - ((Number(systemCashSales) || 0) - (Number(systemReturn) || 0))) * 100) / 100;

	// Auto-calculate difference in card sales (bank total - system card sales)
	$: differenceInCardSales = Math.round((bankTotal - (Number(systemCardSales) || 0)) * 100) / 100;

	// Auto-calculate total difference
	$: totalDifference = Math.round((differenceInCashSales + differenceInCardSales) * 100) / 100;

	// Progressive disclosure checkbox states
	let checkbox1 = false; // Enter Closing Cash
	let checkbox2 = false; // Sales through Purchase Voucher
	let checkbox3 = false; // Recharge Cards
	let checkbox4 = false; // ERP Closing Details
	let checkbox5 = false; // Bank Reconciliation

	// ERP popup state
	let showErpPopup = false;
	let erpLabelChecked = false;

	function handleCheckbox3Change() {
		if (checkbox3) {
			showErpPopup = true;
		}
	}

	function closeErpPopup() {
		if (!erpLabelChecked) {
			checkbox3 = false;
		} else {
			// If ERP label is checked, enable ERP Closing Details (checkbox4)
			checkbox4 = true;
		}
		showErpPopup = false;
	}

	// Supervisor code
	let supervisorCode: string = '';
	let supervisorName: string = '';
	let supervisorCodeError: string = '';
	
	// Cashier confirmation code
	let cashierConfirmCode: string = '';
	let cashierConfirmName: string = '';
	let cashierConfirmError: string = '';
	
	let closingSaved: boolean = false;
	let showSuccessModal: boolean = false;
	let successMessage: string = '';

	// Checklist popup state for CL2
	let showCloseChecklistPopup = false;
	let closeChecklistData: any = null;
	let closeChecklistQuestions: any[] = [];
	let loadingCloseChecklist = false;
	let closeSelectedAnswers: Record<string, string> = {};
	let closeRemarksValues: Record<string, string> = {};
	let closeOtherValues: Record<string, string> = {};
	let closeCurrentQuestionIndex = 0;
	let closeChecklistCompleted = false;

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
				.maybeSingle();

			if (error) throw error;

			if (data) {
				const verifiedName = data.username || '';
				
				// Don't allow supervisor to be same person as cashier
				if (verifiedName === cashierName) {
					supervisorName = '';
					supervisorCodeError = $currentLocale === 'ar' ? 'يجب أن يكون المشرف مختلفًا عن الكاشير' : 'Supervisor must be different from cashier';
					return;
				}
				
				supervisorName = verifiedName;
				supervisorCodeError = '';
			} else {
				supervisorName = '';
				supervisorCodeError = $currentLocale === 'ar' ? 'كود المشرف غير صحيح' : 'Invalid supervisor code';
			}
		} catch (error) {
			console.error('Error verifying supervisor code:', error);
			supervisorName = '';
			supervisorCodeError = $currentLocale === 'ar' ? 'كود المشرف غير صحيح' : 'Invalid supervisor code';
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
				.maybeSingle();

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

	// Auto-show checklist popup when both codes are valid
	$: if (supervisorName && cashierConfirmName && !closeChecklistCompleted && !showCloseChecklistPopup) {
		loadCloseChecklist();
	}

	async function loadCloseChecklist() {
		loadingCloseChecklist = true;
		showCloseChecklistPopup = true;
		
		// Load CL2 checklist
		const { data: cl, error: clError } = await supabase
			.from('hr_checklists')
			.select('id, checklist_name_en, checklist_name_ar, question_ids')
			.eq('id', 'CL2')
			.single();
		
		if (clError || !cl) {
			console.error('CL2 checklist not found');
			// If CL2 not found, skip checklist
			closeChecklistCompleted = true;
			showCloseChecklistPopup = false;
			loadingCloseChecklist = false;
			return;
		}
		
		closeChecklistData = cl;
		
		if (!cl.question_ids || cl.question_ids.length === 0) {
			closeChecklistQuestions = [];
			loadingCloseChecklist = false;
			return;
		}
		
		// Fetch questions
		const { data: questions, error: qError } = await supabase
			.from('hr_checklist_questions')
			.select('*')
			.in('id', cl.question_ids);
		
		if (!qError) {
			closeChecklistQuestions = questions || [];
			closeSelectedAnswers = {};
			closeRemarksValues = {};
			closeOtherValues = {};
			closeCurrentQuestionIndex = 0;
		}
		loadingCloseChecklist = false;
	}

	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function openIncidentReport() {
		const windowId = generateWindowId('report-incident');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Report Incident #${instanceNumber}`,
			component: ReportIncident,
			icon: '📝',
			size: { width: 900, height: 700 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: {
				violation: null,
				employees: [],
				branches: [],
				preSelectedIncidentType: 'IN3',
				preSelectedBranch: branch
			}
		});
	}

	function getCloseQuestionAnswers(q: any): { key: string; en: string; ar: string; points: number }[] {
		const answers: { key: string; en: string; ar: string; points: number }[] = [];
		for (let i = 1; i <= 6; i++) {
			if (q[`answer_${i}_en`] || q[`answer_${i}_ar`]) {
				answers.push({
					key: `a${i}`,
					en: q[`answer_${i}_en`] || '',
					ar: q[`answer_${i}_ar`] || '',
					points: q[`answer_${i}_points`] || 0
				});
			}
		}
		return answers;
	}

	function closeCloseChecklistPopup() {
		showCloseChecklistPopup = false;
		// Reset codes since they cancelled
		supervisorCode = '';
		supervisorName = '';
		cashierConfirmCode = '';
		cashierConfirmName = '';
	}

	async function saveCloseChecklistAndContinue() {
		if (!closeChecklistData) return;

		// Build answers array with points
		const answersData: any[] = [];
		let totalPoints = 0;
		let maxPoints = 0;

		for (const q of closeChecklistQuestions) {
			// Calculate max possible points for this question
			let questionMaxPoints = 0;
			for (let i = 1; i <= 6; i++) {
				const pts = q[`answer_${i}_points`] || 0;
				if (pts > questionMaxPoints) questionMaxPoints = pts;
			}
			if (q.has_other && (q.other_points || 0) > questionMaxPoints) {
				questionMaxPoints = q.other_points || 0;
			}
			maxPoints += questionMaxPoints;

			const answerKey = closeSelectedAnswers[q.id];
			if (!answerKey) continue;

			let points = 0;
			let answerText = '';

			if (answerKey === 'other') {
				points = q.other_points || 0;
				answerText = 'Other';
			} else {
				const ansIdx = parseInt(answerKey.replace('a', ''));
				points = q[`answer_${ansIdx}_points`] || 0;
				answerText = q[`answer_${ansIdx}_en`] || q[`answer_${ansIdx}_ar`] || '';
			}

			totalPoints += points;

			answersData.push({
				question_id: q.id,
				answer_key: answerKey,
				answer_text: answerText,
				points: points,
				remarks: closeRemarksValues[q.id] || null,
				other_value: answerKey === 'other' ? (closeOtherValues[q.id] || null) : null
			});
		}

		// Lookup employee_id from hr_employee_master using cashier's user_id from operation
		let employeeId: string | null = null;
		let userId: string | null = null;
		
		try {
			// Get cashier user info from the codes we verified
			const { data: cashierData } = await supabase
				.from('users')
				.select('id')
				.eq('quick_access_code', cashierConfirmCode)
				.single();
			
			if (cashierData) {
				userId = cashierData.id;
				
				const { data: empData } = await supabase
					.from('hr_employee_master')
					.select('id')
					.eq('user_id', userId)
					.single();
				
				if (empData) {
					employeeId = empData.id;
				}
			}
		} catch (e) {
			console.error('Error looking up employee:', e);
		}

		// Save to hr_checklist_operations
		const { error } = await supabase
			.from('hr_checklist_operations')
			.insert({
				user_id: userId,
				employee_id: employeeId,
				box_number: operation?.box_number || null,
				box_operation_id: operation?.id || null,
				checklist_id: closeChecklistData.id,
				answers: answersData,
				total_points: totalPoints,
				max_points: maxPoints,
				branch_id: branch?.id || null,
				submission_type_en: 'POS',
				submission_type_ar: 'نقاط البيع'
			});

		if (error) {
			console.error('Error saving checklist operation:', error);
			alert('Error saving checklist: ' + error.message);
			return;
		}

		// Mark checklist as completed and close popup
		closeChecklistCompleted = true;
		showCloseChecklistPopup = false;
	}

	// Load saved closing details on component mount
	async function loadClosingDetails() {
		try {
			const { data, error } = await supabase
				.from('box_operations')
				.select('closing_details')
				.eq('id', operation.id)
				.single();

			if (error) {
				console.warn('No saved closing details found:', error);
				return;
			}

			const savedData = data?.closing_details;
			if (!savedData) {
				console.log('No closing details to restore');
				return;
			}

			console.log('📥 Restoring saved closing details:', savedData);

			// Restore closing counts
			if (savedData.closing_counts) {
				closingCounts = { ...savedData.closing_counts };
			}

			// Restore bank reconciliation
			if (savedData.bank_mada !== undefined) madaAmount = savedData.bank_mada;
			if (savedData.bank_visa !== undefined) visaAmount = savedData.bank_visa;
			if (savedData.bank_mastercard !== undefined) masterCardAmount = savedData.bank_mastercard;
			if (savedData.bank_google_pay !== undefined) googlePayAmount = savedData.bank_google_pay;
			if (savedData.bank_other !== undefined) otherAmount = savedData.bank_other;

			// Restore ERP details
			if (savedData.system_cash_sales !== undefined) systemCashSales = savedData.system_cash_sales;
			if (savedData.system_card_sales !== undefined) systemCardSales = savedData.system_card_sales;
			if (savedData.system_return !== undefined) systemReturn = savedData.system_return;

			// Restore recharge card details
			if (savedData.recharge_opening_balance !== undefined) openingBalance = savedData.recharge_opening_balance;
			if (savedData.recharge_close_balance !== undefined) closeBalance = savedData.recharge_close_balance;

			// Restore recharge card transaction times
			if (savedData.recharge_transaction_start_date) startDateInput = savedData.recharge_transaction_start_date;
			if (savedData.recharge_transaction_start_time) {
				// Parse time format "HH:MM AM/PM"
				const startTime = savedData.recharge_transaction_start_time;
				const startTimeParts = startTime.match(/(\d{1,2}):(\d{2})\s(AM|PM)/i);
				if (startTimeParts) {
					startHour = startTimeParts[1];
					startMinute = startTimeParts[2];
					startAmPm = startTimeParts[3].toUpperCase();
				}
			}

			if (savedData.recharge_transaction_end_date) endDateInput = savedData.recharge_transaction_end_date;
			if (savedData.recharge_transaction_end_time) {
				// Parse time format "HH:MM AM/PM"
				const endTime = savedData.recharge_transaction_end_time;
				const endTimeParts = endTime.match(/(\d{1,2}):(\d{2})\s(AM|PM)/i);
				if (endTimeParts) {
					endHour = endTimeParts[1];
					endMinute = endTimeParts[2];
					endAmPm = endTimeParts[3].toUpperCase();
				}
			}

			// Restore vouchers
			if (savedData.vouchers && Array.isArray(savedData.vouchers)) {
				vouchers = [...savedData.vouchers];
			}

			// Restore reconciliations: first try closing_details (pre-close), then bank_reconciliations table (post-close)
			if (savedData.reconciliations && Array.isArray(savedData.reconciliations) && savedData.reconciliations.length > 0) {
				reconciliations = [...savedData.reconciliations];
				syncLegacyAmounts();
			} else {
				const { data: reconData } = await supabase
					.from('bank_reconciliations')
					.select('*')
					.eq('operation_id', operation.id)
					.order('id');
				if (reconData && reconData.length > 0) {
					reconciliations = reconData.map((r: any) => ({
						id: r.id,
						reconciliation_number: r.reconciliation_number || '',
						mada: r.mada_amount || 0,
						visa: r.visa_amount || 0,
						mastercard: r.mastercard_amount || 0,
						google_pay: r.google_pay_amount || 0,
						other: r.other_amount || 0
					}));
					syncLegacyAmounts();
				}
			}

			console.log('✅ Closing details restored successfully');
		} catch (error) {
			console.error('❌ Error loading closing details:', error);
		}
	}

	// Load saved details when component mounts
	onMount(() => {
		loadClosingDetails();
	});

	// Real-time auto-save function
	let autoSaveTimeout: any;
	async function autoSaveClosingDetails() {
		// Debounce: wait 1 second after last change before saving
		clearTimeout(autoSaveTimeout);
		autoSaveTimeout = setTimeout(async () => {
			try {
				// Build closing data for auto-save
				const closingData = {
					closing_counts: closingCounts,
					closing_total: closingTotal,
					cash_sales: cashSales,
					total_cash_sales: totalCashSales,
					supervisor_name: supervisorName,
					
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
					
				// Recharge card transaction details
				recharge_opening_balance: openingBalance || 0,
				recharge_close_balance: closeBalance || 0,
				recharge_sales: sales || 0,
				recharge_transaction_start_date: startDateInput,
				recharge_transaction_start_time: startTimeInput || `${startHour}:${startMinute} ${startAmPm}`,
				recharge_transaction_end_date: endDateInput,
				recharge_transaction_end_time: endTimeInput || `${endHour}:${endMinute} ${endAmPm}`,
				
				// Purchase vouchers
				vouchers: vouchers,
				vouchers_total: vouchersTotal,
				
				// Bank reconciliation rows (for restore before final close)
				reconciliations: reconciliations,
				
				total_sales: totalSales,
				total_system_sales: totalSystemSales
			};

				console.log('💾 Auto-saving closing details...');
				const { error } = await supabase
					.from('box_operations')
					.update({ closing_details: closingData })
					.eq('id', operation.id);

				if (error) throw error;
				console.log('✅ Closing details auto-saved');
			} catch (error) {
				console.error('❌ Error auto-saving closing details:', error);
			}
		}, 1000);
	}

	// Reactive auto-save triggers - call autoSave when any data changes
	$: if (closingCounts) autoSaveClosingDetails();
	$: if (madaAmount !== undefined || visaAmount !== undefined || masterCardAmount !== undefined || googlePayAmount !== undefined || otherAmount !== undefined) autoSaveClosingDetails();
	$: if (systemCashSales !== undefined || systemCardSales !== undefined || systemReturn !== undefined) autoSaveClosingDetails();
	$: if (openingBalance !== undefined || closeBalance !== undefined) autoSaveClosingDetails();
	$: if (vouchers) autoSaveClosingDetails();
	$: if (reconciliations) autoSaveClosingDetails();
	$: if (startDateInput !== undefined || startHour !== undefined || startMinute !== undefined || startAmPm !== undefined) autoSaveClosingDetails();
	$: if (endDateInput !== undefined || endHour !== undefined || endMinute !== undefined || endAmPm !== undefined) autoSaveClosingDetails();

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

			console.log('🔒 Supervisor verified, updating box status to pending_close');

			// Build updated closing details with supervisor_name
			const updatedClosingDetails = {
				closing_counts: closingCounts,
				closing_total: closingTotal,
				cash_sales: cashSales,
				total_cash_sales: totalCashSales,
				supervisor_name: supervisorName,
				
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
				
				// Recharge card transaction details
				recharge_opening_balance: openingBalance || 0,
				recharge_close_balance: closeBalance || 0,
				recharge_sales: sales || 0,
				recharge_transaction_start_date: startDateInput,
				recharge_transaction_start_time: startTimeInput || `${startHour}:${startMinute} ${startAmPm}`,
				recharge_transaction_end_date: endDateInput,
				recharge_transaction_end_time: endTimeInput || `${endHour}:${endMinute} ${endAmPm}`,
				
				// Purchase vouchers
				vouchers: vouchers,
				vouchers_total: vouchersTotal,
				total_system_cash_sales: totalSystemCashSales,
				total_sales: totalSales,
				total_system_sales: totalSystemSales
			};

			// Update both closing_details and status to pending_close with supervisor info
			const { error: statusError } = await supabase
				.from('box_operations')
				.update({ 
					closing_details: updatedClosingDetails,
					status: 'pending_close',
					supervisor_id: supervisorUserId,
					supervisor_verified_at: new Date().toISOString(),
					end_time: new Date().toISOString(),
					updated_at: new Date().toISOString()
				})
				.eq('id', operation.id);

			if (statusError) {
				console.error('❌ Error updating status:', statusError);
				throw statusError;
			}

			console.log('✅ Status updated to pending_close');

			// Save individual reconciliations to bank_reconciliations table
			if (reconciliations.length > 0) {
				// First delete old reconciliations for this operation
				await supabase.from('bank_reconciliations').delete().eq('operation_id', operation.id);
				
				// Get cashier user ID
				let cashierUserId: string | null = null;
				if (cashierConfirmCode) {
					const { data: cashierData } = await supabase
						.from('users')
						.select('id')
						.eq('quick_access_code', cashierConfirmCode)
						.single();
					cashierUserId = cashierData?.id || null;
				}

				const reconRows = reconciliations.map(r => ({
					operation_id: operation.id,
					branch_id: branch?.id || null,
					pos_number: selectedPosNumber,
					supervisor_id: supervisorUserId || null,
					cashier_id: cashierUserId,
					reconciliation_number: r.reconciliation_number || '',
					mada_amount: r.mada || 0,
					visa_amount: r.visa || 0,
					mastercard_amount: r.mastercard || 0,
					google_pay_amount: r.google_pay || 0,
					other_amount: r.other || 0,
					total_amount: (r.mada || 0) + (r.visa || 0) + (r.mastercard || 0) + (r.google_pay || 0) + (r.other || 0)
				}));

				const { error: reconError } = await supabase
					.from('bank_reconciliations')
					.insert(reconRows);
				
				if (reconError) {
					console.error('❌ Error saving reconciliations:', reconError);
				} else {
					console.log('✅ Reconciliations saved:', reconRows.length);
				}
			}

			closingSaved = true;

			// Open print template
			openPrintTemplate();

			// Show success message
			successMessage = $currentLocale === 'ar' ? 'تم إرسال إغلاق الصندوق! في انتظار موافقة مدير تحصيل نقاط البيع' : 'Box closing submitted! Waiting for POS Collection Manager approval';
			showSuccessModal = true;
		} catch (error) {
			console.error('❌ Error saving supervisor code:', error);
			supervisorCodeError = ($currentLocale === 'ar' ? 'خطأ في تحديث حالة الصندوق: ' : 'Error updating box status: ') + (error.message || ($currentLocale === 'ar' ? 'خطأ غير معروف' : 'Unknown error'));
		}
	}

	// Print template state
	let showPrintTemplate = false;

	function openPrintTemplate() {
		showPrintTemplate = true;
	}

	function closePrintTemplate() {
		showPrintTemplate = false;
	}

	// A4 template state


	function handlePrint() {
		console.log('🖨️ Printing - Branch:', branch?.name, 'Supervisor:', supervisorName);
		const html = document.getElementById('print-template-content')?.innerHTML || '';
		
		// Create a minimal HTML document with aggressive print styles
		const printHtml = `
			<!DOCTYPE html>
			<html>
			<head>
				<meta charset="UTF-8">
				<title>Receipt</title>
				<style>
					* { margin: 0; padding: 0; border: 0; box-sizing: border-box; }
					html { margin: 0; padding: 0; }
					body { 
						margin: 0; 
						padding: 0; 
						width: 72.1mm; 
						font-family: 'Courier New', monospace;
						font-size: 10pt;
						font-weight: bold;
						overflow: visible;
					}
					
					.thermal-receipt { width: 72.1mm; margin: 0; padding: 0; overflow: visible; }
					.receipt-container { margin: 0; padding: 0; overflow: visible; }
					.receipt-divider { border-top: 1px dashed #000; margin: 0; padding: 0; }
					.receipt-row-ar { direction: rtl; text-align: right; margin: 0; padding: 0; font-size: 8pt; font-weight: bold; word-wrap: break-word; word-break: break-all; overflow: visible; width: 100%; }
					.receipt-row-en { text-align: left; margin: 0; padding: 0; font-size: 10pt; font-weight: bold; word-wrap: break-word; overflow: visible; width: 100%; }
					.receipt-label-ar { direction: rtl; text-align: right; margin: 0; padding: 0; font-size: 7pt; font-weight: bold; word-wrap: break-word; word-break: break-all; overflow: visible; width: 100%; }
					.receipt-label-en { text-align: left; margin: 0; padding: 0; font-size: 8pt; font-weight: bold; word-wrap: break-word; overflow: visible; width: 100%; }
					.receipt-label-bilingual { text-align: left; margin: 0; padding: 2px 0; font-size: 8pt; font-weight: bold; word-wrap: break-word; overflow: visible; width: 100%; }
					.receipt-total { font-size: 11pt; font-weight: bold; margin: 0; padding: 0; word-wrap: break-word; overflow: visible; }
					.receipt-logo { text-align: center; margin: 0; padding: 0; border-bottom: 1px solid #000; }
					.logo-image { max-width: 100%; height: auto; display: block; }
					.receipt-header { text-align: center; margin: 0; padding: 0; }
					.receipt-section { margin: 0; padding: 0; overflow: visible; }
					.receipt-footer { margin: 0; padding: 0; }
					.receipt-row-bilingual { margin: 0; padding: 0; overflow: visible; width: 100%; }
					
					@page {
						size: 72.1mm auto;
						margin: 0;
						padding: 0;
					}
					
					@media print {
						* { margin: 0 !important; padding: 0 !important; }
						html, body { width: 72.1mm; margin: 0; padding: 0; }
						body { page-break-after: avoid; }
					}
				</style>
			</head>
			<body>${html}</body>
			</html>
		`;
		
		const printWindow = window.open('', 'PRINT', 'width=100,height=600');
		printWindow.document.write(printHtml);
		printWindow.document.close();
		
		setTimeout(() => {
			printWindow.print();
			printWindow.close();
		}, 250);
	}

	const hours = Array.from({ length: 12 }, (_, i) => (i + 1).toString().padStart(2, '0'));
	const minutes = Array.from({ length: 60 }, (_, i) => i.toString().padStart(2, '0'));

	function updateStartTime() {
		startTimeInput = `${startHour}:${startMinute} ${startAmPm}`;
	}

	function updateEndTime() {
		endTimeInput = `${endHour}:${endMinute} ${endAmPm}`;
	}
</script>

<div class="close-box-container">
	<div class="top-info-row">
		<div class="info-group">
			<span class="info-label">{$currentLocale === 'ar' ? 'الكاشير (بدأ):' : 'Cashier (Started):'}</span>
			<span class="info-value">{operationData.cashier_name || 'N/A'}</span>
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
		<div class="info-group">
			<span class="info-label">{$currentLocale === 'ar' ? 'المشرف الفاحص:' : 'Checked Supervisor:'}</span>
			<span class="info-value">{operationData.supervisor_name || 'N/A'}</span>
		</div>
	</div>

	<div class="two-cards-row">
		<div class="half-card split-card">
			<div class="split-section">
				<div class="card-header-with-checkbox">
					<div class="card-header-text">{$currentLocale === 'ar' ? 'إدخال نقد الإغلاق' : 'Enter Closing Cash'}</div>
					<label class="checkbox-container">
						<span class="checkbox-number">1</span>
						<input type="checkbox" class="closing-checkbox" bind:checked={checkbox1} />
						<span class="checkmark"></span>
					</label>
				</div>
				<div class="closing-cash-grid-2row">
					{#each Object.entries(denomLabels) as [key, label] (key)}
						<div class="denom-input-group">
							<label>
								{#if label !== 'Coins'}
									<span>{label}</span>
									<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
								{:else}
									{$currentLocale === 'ar' ? 'عملات معدنية' : label}
								{/if}
							</label>
							<div class="denom-input-wrapper">
								<input
									type="number"
									min="0"
									value={closingCounts[key] || ''} on:input={(e) => { const val = e.currentTarget.value; closingCounts[key] = val === '' ? undefined : Number(val); }}
								/>
								{#if closingCounts[key] > 0}
									<div class="denom-total">
										<img src={currencySymbolUrl} alt="SAR" class="currency-icon-tiny" />
										{((closingCounts[key] || 0) * denomValues[key]).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
									</div>
								{/if}
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
			{#if checkbox1}
			<div class="split-section">
				<div class="card-header-with-checkbox">
					<div class="card-header-text">{$currentLocale === 'ar' ? 'المبيعات عبر قسيمة الشراء' : 'Sales through Purchase Voucher'}</div>
					<label class="checkbox-container">
						<span class="checkbox-number">2</span>
						<input type="checkbox" class="closing-checkbox" bind:checked={checkbox2} />
						<span class="checkmark"></span>
					</label>
				</div>
				
				<div class="voucher-input-row">
					<input
						type="text"
						bind:value={newVoucherSerial}
						placeholder={$currentLocale === 'ar' ? 'الرقم التسلسلي' : 'Serial Number'}
						class="voucher-serial-input"
					/>
					<input
						type="number"
						value={newVoucherAmount || ''}
						on:input={(e) => newVoucherAmount = e.currentTarget.value === '' ? undefined : Number(e.currentTarget.value)}
						placeholder={$currentLocale === 'ar' ? 'المبلغ' : 'Amount'}
						min="0"
						step="0.01"
						class="voucher-amount-input"
					/>
					<button class="add-voucher-btn" on:click={addVoucher}>
						<span>+</span>
					</button>
				</div>

				{#if vouchers.length > 0}
					<div class="vouchers-table">
						<table>
							<thead>
								<tr>
									<th>{$currentLocale === 'ar' ? 'الرقم التسلسلي' : 'Serial'}</th>
									<th>{$currentLocale === 'ar' ? 'المبلغ' : 'Amount'}</th>
									<th></th>
								</tr>
							</thead>
							<tbody>
								{#each vouchers as voucher, index (index)}
									<tr>
										<td>{voucher.serial}</td>
										<td>
											<div class="amount-cell">
												<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
												<span>{voucher.amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
											</div>
										</td>
										<td>
											<button class="remove-btn" on:click={() => removeVoucher(index)}>×</button>
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
			{/if}
		</div>
		<div class="half-card split-card">
			{#if checkbox2}
			<div class="split-section">
				<div class="card-header-with-checkbox">
					<div class="card-header-text">{$currentLocale === 'ar' ? 'تسوية البنك' : 'Bank Reconciliation'}</div>
					<button class="add-voucher-btn" on:click={() => openReconPopup()} style="width: 22px; height: 22px; font-size: 14px; padding: 0; line-height: 1;">
						<span>+</span>
					</button>
					<label class="checkbox-container">
						<span class="checkbox-number">5</span>
						<input type="checkbox" class="closing-checkbox" bind:checked={checkbox5} />
						<span class="checkmark"></span>
					</label>
				</div>

				<!-- Reconciliations list -->
				{#if reconciliations.length > 0}
					<div class="recon-cards-list">
						{#each reconciliations as recon, index (index)}
							<div class="recon-card">
								<div class="recon-card-header">
									<button
										style="background: none; border: none; color: #2563eb; cursor: pointer; text-decoration: underline; font-size: 13px; font-weight: 700; padding: 0;"
										on:click={() => openReconPopup(index)}
									>
										{recon.reconciliation_number || `#${index + 1}`}
									</button>
									<button class="remove-btn" on:click={() => removeRecon(index)}>×</button>
								</div>
								<div class="recon-card-body">
									<div class="bank-fields-row">
										<div class="bank-input-group">
											<label>{$currentLocale === 'ar' ? 'مدى' : 'Mada'}</label>
											<input type="number" value={recon.mada || 0} readonly class="bank-input" />
										</div>
										<div class="bank-input-group">
											<label>{$currentLocale === 'ar' ? 'فيزا' : 'Visa'}</label>
											<input type="number" value={recon.visa || 0} readonly class="bank-input" />
										</div>
										<div class="bank-input-group">
											<label>{$currentLocale === 'ar' ? 'ماستر كارد' : 'MC'}</label>
											<input type="number" value={recon.mastercard || 0} readonly class="bank-input" />
										</div>
										<div class="bank-input-group">
											<label>{$currentLocale === 'ar' ? 'جوجل باي' : 'GPay'}</label>
											<input type="number" value={recon.google_pay || 0} readonly class="bank-input" />
										</div>
										<div class="bank-input-group">
											<label>{$currentLocale === 'ar' ? 'أخرى' : 'Other'}</label>
											<input type="number" value={recon.other || 0} readonly class="bank-input" />
										</div>
										<div class="bank-input-group">
											<label style="color: #1e40af; font-weight: 800;">{$currentLocale === 'ar' ? 'المجموع' : 'Total'}</label>
											<input type="number" value={getReconTotal(recon)} readonly class="bank-input" style="color: #1e40af; font-weight: 800; border-color: #93c5fd; background: #eff6ff;" />
										</div>
									</div>
								</div>
							</div>
						{/each}
					</div>
				{/if}

				<!-- Overall totals by payment type -->
				<div class="recon-overall-totals">
					<div class="recon-overall-header">{$currentLocale === 'ar' ? 'إجمالي جميع التسويات' : 'All Reconciliations Total'}</div>
					<div class="bank-fields-row">
						<div class="bank-input-group">
							<label>{$currentLocale === 'ar' ? 'مدى' : 'Mada'}</label>
							<input type="number" value={Number(madaAmount) || 0} readonly class="bank-input" />
						</div>
						<div class="bank-input-group">
							<label>{$currentLocale === 'ar' ? 'فيزا' : 'Visa'}</label>
							<input type="number" value={Number(visaAmount) || 0} readonly class="bank-input" />
						</div>
						<div class="bank-input-group">
							<label>{$currentLocale === 'ar' ? 'ماستر كارد' : 'MasterCard'}</label>
							<input type="number" value={Number(masterCardAmount) || 0} readonly class="bank-input" />
						</div>
						<div class="bank-input-group">
							<label>{$currentLocale === 'ar' ? 'جوجل باي' : 'Google Pay'}</label>
							<input type="number" value={Number(googlePayAmount) || 0} readonly class="bank-input" />
						</div>
						<div class="bank-input-group">
							<label>{$currentLocale === 'ar' ? 'أخرى' : 'Other'}</label>
							<input type="number" value={Number(otherAmount) || 0} readonly class="bank-input" />
						</div>
					</div>
					<div class="bank-total" style="margin-top: 4px;">
						<span class="label">{$currentLocale === 'ar' ? 'إجمالي البنك:' : 'Bank Total:'}</span>
						<div class="amount">
							<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
							<span>{bankTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
						</div>
					</div>
				</div>
			</div>
			{/if}
			{#if checkbox4}
			<div class="split-section">
				<div class="card-header-with-checkbox">
					<div class="card-header-text">{$currentLocale === 'ar' ? 'تفاصيل إغلاق النظام' : 'ERP Closing Details'}</div>
					<label class="checkbox-container">
						<span class="checkbox-number">4</span>
						<input type="checkbox" class="closing-checkbox" bind:checked={checkbox4} />
						<span class="checkmark"></span>
					</label>
				</div>
				
				<div class="system-sales-row">
					<div class="system-input-group">
						<label>{$currentLocale === 'ar' ? 'المبيعات النقدية' : 'Cash Sales'}</label>
						<input
							type="number"
							bind:value={systemCashSales}

							min="0"
							step="0.01"
							class="system-input"
						/>
					</div>
					<div class="system-input-group">
						<label>{$currentLocale === 'ar' ? 'مبيعات البطاقة' : 'Card Sales'}</label>
						<input
							type="number"
							bind:value={systemCardSales}

							min="0"
							step="0.01"
							class="system-input"
						/>
					</div>
					<div class="system-input-group">
						<label>{$currentLocale === 'ar' ? 'المرتجعات' : 'Return'}</label>
						<input
							type="number"
							bind:value={systemReturn}

							min="0"
							step="0.01"
							class="system-input"
						/>
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
			{/if}
			{#if checkbox5}
			<div class="split-section recharge-card-section-11">
				<div class="card-header-with-checkbox">
					<div class="card-header-text">{$currentLocale === 'ar' ? 'بطاقات الشحن' : 'Recharge Cards'}</div>
					<label class="checkbox-container">
						<span class="checkbox-number">3</span>
						<input type="checkbox" class="closing-checkbox" bind:checked={checkbox3} on:change={handleCheckbox3Change} />
						<span class="checkmark"></span>
					</label>
				</div>
				
				<div class="recharge-time-fields">
					<div class="date-time-field-row">
						<div class="date-field-group">
							<label>{$currentLocale === 'ar' ? 'تاريخ البدء' : 'Start Date'}</label>
							<input type="date" class="date-input-field" bind:value={startDateInput} />
						</div>
						<div class="time-field-group">
							<label>{$currentLocale === 'ar' ? 'وقت البدء' : 'Start Time'}</label>
							<div class="time-input-controls">
								<input type="number" min="1" max="12" placeholder="HH" class="time-input-hm" bind:value={startHour} />
								<span class="time-separator">:</span>
								<input type="number" min="0" max="59" placeholder="MM" class="time-input-hm" bind:value={startMinute} />
								<select bind:value={startAmPm} class="time-input-ampm">
									<option>AM</option>
									<option>PM</option>
								</select>
							</div>
						</div>
					</div>
					
					<div class="date-time-field-row">
						<div class="date-field-group">
							<label>{$currentLocale === 'ar' ? 'تاريخ الانتهاء' : 'End Date'}</label>
							<input type="date" class="date-input-field" bind:value={endDateInput} />
						</div>
						<div class="time-field-group">
							<label>{$currentLocale === 'ar' ? 'وقت الانتهاء' : 'End Time'}</label>
							<div class="time-input-controls">
								<input type="number" min="1" max="12" placeholder="HH" class="time-input-hm" bind:value={endHour} />
								<span class="time-separator">:</span>
								<input type="number" min="0" max="59" placeholder="MM" class="time-input-hm" bind:value={endMinute} />
								<select bind:value={endAmPm} class="time-input-ampm">
									<option>AM</option>
									<option>PM</option>
								</select>
							</div>
						</div>
					</div>
				</div>
				
				<div class="balance-row">
					<div class="balance-group">
						<label>{$currentLocale === 'ar' ? 'الرصيد الافتتاحي' : 'Opening Balance'}</label>
						<input
							type="number"
							bind:value={openingBalance}
							placeholder="0.00"
							min="0"
							step="0.01"
							class="balance-input"
						/>
					</div>
					<div class="balance-group">
						<label>{$currentLocale === 'ar' ? 'رصيد الإغلاق' : 'Close Balance'}</label>
						<input
							type="number"
							bind:value={closeBalance}
							placeholder="0.00"
							min="0"
							step="0.01"
							class="balance-input"
						/>
					</div>
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
			{/if}
			<div class="split-section">
				
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
					{#if checkbox1 && checkbox2 && checkbox3 && checkbox4 && checkbox5}
					<div class="sub-card">
						<div class="sub-card-header" style="font-size: 0.7rem; font-weight: 700; color: #15803d; letter-spacing: 1px; margin-bottom: 0.1rem; text-align: center; border-bottom: 1px solid #fed7aa; padding-bottom: 0.1rem;">
							{$currentLocale === 'ar' ? 'التوقيع الإلكتروني' : 'ELECTRONIC SIGNATURE'}
						</div>
						<div class="sub-card-content" style="gap: 0.1rem;">
							<div style="display: flex; align-items: flex-start; gap: 0.3rem;">
								<div style="flex: 1; display: flex; flex-direction: column; gap: 0.05rem;">
									<input
										type="password"
										placeholder={$currentLocale === 'ar' ? 'كود المشرف' : 'Supervisor Code'}
										bind:value={supervisorCode}
										class="supervisor-code-input"
										style="margin: 0;"
									/>
									{#if supervisorCodeError}
										<div style="font-size: 0.55rem; color: #dc2626; font-weight: 600; text-align: center;">
											{supervisorCodeError}
										</div>
									{/if}
								</div>
								{#if supervisorName}
									<div style="font-size: 0.55rem; color: #15803d; font-weight: 600; padding-top: 0.15rem; white-space: nowrap;">
										✓ {supervisorName}
									</div>
								{/if}
							</div>
							
							<div style="display: flex; align-items: flex-start; gap: 0.3rem;">
								<div style="flex: 1; display: flex; flex-direction: column; gap: 0.05rem;">
									<input
										type="password"
										placeholder={$currentLocale === 'ar' ? 'كود الكاشير' : 'Cashier Code'}
										bind:value={cashierConfirmCode}
										class="supervisor-code-input"
									/>
									{#if cashierConfirmError}
										<div style="font-size: 0.55rem; color: #dc2626; font-weight: 600; text-align: center;">
											{cashierConfirmError}
										</div>
									{/if}
								</div>
								{#if cashierConfirmName}
									<div style="font-size: 0.55rem; color: #15803d; font-weight: 600; padding-top: 0.15rem; white-space: nowrap;">
										✓ {cashierConfirmName}
									</div>
								{/if}
							</div>
							
							<button
								on:click={saveSupervisorCode}
								class="save-button"
								disabled={!supervisorName || !cashierConfirmName || !closeChecklistCompleted || closingSaved}
								style="margin-top: 0.1rem;"
							>
								{closingSaved ? ($currentLocale === 'ar' ? '✓ تم الإغلاق' : '✓ Closed') : ($currentLocale === 'ar' ? 'إغلاق' : 'Close')}
							</button>
							{#if closingSaved}
								<div style="font-size: 0.55rem; color: #15803d; font-weight: 600; text-align: center;">
									{$currentLocale === 'ar' ? 'في انتظار الإغلاق النهائي في نقطة البيع' : 'Pending final close in POS'}
								</div>
								<button
									on:click={openPrintTemplate}
									class="reprint-button"
									style="margin-top: 0.25rem;"
								>
									🖨️ {$currentLocale === 'ar' ? 'إعادة طباعة' : 'Reprint'}
								</button>
							{/if}
						</div>
					</div>
					{/if}
				</div>
			</div>
		</div>
	</div>
</div>

{#if showPrintTemplate}
	<div class="print-modal-overlay" on:click={closePrintTemplate}>
		<div class="print-modal" on:click={(e) => e.stopPropagation()}>
			<div class="print-modal-header">
				<h3>{$currentLocale === 'ar' ? 'طباعة الإيصال' : 'Print Receipt'}</h3>
				<button class="close-modal-btn" on:click={closePrintTemplate}>✕</button>
			</div>
			
			<div class="print-modal-content">
				<div id="print-template-content" class="thermal-receipt">
					<!-- 80mm Thermal Receipt Template -->
					<div class="receipt-container">
						<!-- Logo Header -->
						<div class="receipt-logo">
							<img src="/icons/logo.png" alt="App Logo" class="logo-image" />
						</div>

						<!-- Header -->
						<div class="receipt-header">
							<div class="receipt-title-ar">تقفيل نقاط البيع</div>
							<div class="receipt-title-en">CLOSING RECEIPT</div>
							<hr class="receipt-divider" />
						</div>

						<!-- Branch Info -->
						<div class="receipt-section">
							<div class="receipt-row-stacked">
								<div class="receipt-label-bilingual">Branch - الفرع</div>
								<div class="branch-bilingual">
									<div style="text-align: left; font-weight: 600; font-size: 9pt; margin-bottom: 0.05rem;">{branch?.name_ar || branch?.name || operation?.branch_name || 'لا يوجد'}</div>
									<div style="text-align: left; font-weight: 600; font-size: 9pt; color: #6b7280;">{branch?.name_en || branch?.name || operation?.branch_name || 'N/A'}</div>
								</div>
							</div>
							<div class="receipt-row-stacked">
								<div class="receipt-label-bilingual">POS Number - رقم نقطة البيع</div>
								<div class="receipt-row-en">POS {selectedPosNumber}</div>
							</div>
							<div class="receipt-row-stacked">
								<div class="receipt-label-bilingual">Cashier - أمين الصندوق</div>
								<div class="receipt-row-en">{operationData.cashier_name || 'N/A'}</div>
							</div>
						</div>

						<hr class="receipt-divider" />

						<!-- Denominations -->
						<div class="receipt-section">
							<div class="section-title-ar">الفئات</div>
							<div class="section-title-en">DENOMINATIONS</div>
							{#each Object.entries(denomLabels) as [key, label] (key)}
								{#if closingCounts[key] > 0}
									<div class="receipt-row-stacked">
										<div class="receipt-row-en">{label}: {closingCounts[key]} x {(denomValues[key] || 0).toFixed(2)}</div>
									</div>
								{/if}
							{/each}
							<div class="receipt-row-stacked total-row">
							<div class="receipt-label-bilingual">Total Cash - إجمالي النقد</div>
							<div class="receipt-row-en receipt-total">{closingTotal.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
						</div>
					</div>

					<hr class="receipt-divider" />

					<!-- Cash Sales Summary -->
					<div class="receipt-section">
						<div class="section-title-ar">ملخص النقد</div>
						<div class="section-title-en">CASH SUMMARY</div>
						<div class="receipt-row-stacked">
							<div class="receipt-label-bilingual">Amount Issued - المبلغ المُصروف</div>
							<div class="receipt-row-en">{(operation?.total_before || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
						</div>
						<div class="receipt-row-stacked">
							<div class="receipt-label-bilingual">Amount Checked - المبلغ المُفتش</div>
							<div class="receipt-row-en">{(operation?.total_after || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
						</div>
						<div class="receipt-row-stacked">
							<div class="receipt-label-bilingual">Cash Sales - مبيعات نقدية</div>
						<div class="receipt-row-en">{cashSales.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
					</div>
				</div>

				<hr class="receipt-divider" />

				<!-- Purchase Vouchers -->
				{#if vouchersTotal > 0}
					<div class="receipt-section">
						<div class="section-title-ar">شيكات الشراء</div>
						<div class="section-title-en">PURCHASE VOUCHERS</div>
						{#each vouchers as voucher (voucher.serial)}
							<div class="receipt-row-stacked">
								<div class="receipt-row-en">{voucher.serial}: {voucher.amount.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
							</div>
						{/each}
						<div class="receipt-row-stacked total-row">
							<div class="receipt-row-en receipt-total">Total: {vouchersTotal.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
						</div>
					</div>

					<hr class="receipt-divider" />
				{/if}

				<!-- Recharge Cards -->
				<div class="receipt-section">
					<div class="section-title-ar">بطاقات الشحن</div>
					<div class="section-title-en">RECHARGE CARDS</div>
					{#if startDateInput}
						<div class="receipt-row-stacked">
							<div class="receipt-label-bilingual">Start Date - تاريخ البدء</div>
							<div class="receipt-row-en">{startDateInput}</div>
						</div>
					{/if}
					{#if startHour && startMinute && startAmPm}
						<div class="receipt-row-stacked">
							<div class="receipt-label-bilingual">Start Time - وقت البدء</div>
							<div class="receipt-row-en">{startHour}:{startMinute} {startAmPm}</div>
						</div>
					{/if}
					{#if endDateInput}
						<div class="receipt-row-stacked">
							<div class="receipt-label-bilingual">End Date - تاريخ الانتهاء</div>
							<div class="receipt-row-en">{endDateInput}</div>
						</div>
					{/if}
					{#if endHour && endMinute && endAmPm}
						<div class="receipt-row-stacked">
							<div class="receipt-label-bilingual">End Time - وقت الانتهاء</div>
							<div class="receipt-row-en">{endHour}:{endMinute} {endAmPm}</div>
						</div>
					{/if}
					<div class="receipt-row-stacked">
						<div class="receipt-label-bilingual">Opening Balance - الرصيد الافتتاحي</div>
						<div class="receipt-row-en">{(openingBalance || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
					</div>
					<div class="receipt-row-stacked">
						<div class="receipt-label-bilingual">Closing Balance - الرصيد الختامي</div>
						<div class="receipt-row-en">{(closeBalance || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
					</div>
					<div class="receipt-row-stacked">
						<div class="receipt-label-bilingual">Sales - المبيعات</div>
						<div class="receipt-row-en">{(sales || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
					</div>
				</div>

				<hr class="receipt-divider" />

			<!-- Bank Reconciliation -->
			<div class="receipt-section">
				<div class="section-title-ar">تسويات البنك</div>
				<div class="section-title-en">BANK RECONCILIATION</div>
				{#if madaAmount > 0}
								<div class="receipt-row-stacked">
									<div class="receipt-label-bilingual">Mada - مدى</div>
									<div class="receipt-row-en">{(madaAmount || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
								</div>
							{/if}
							{#if visaAmount > 0}
								<div class="receipt-row-stacked">
									<div class="receipt-label-bilingual">Visa - فيزا</div>
									<div class="receipt-row-en">{(visaAmount || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
								</div>
							{/if}
							{#if masterCardAmount > 0}
								<div class="receipt-row-stacked">
									<div class="receipt-label-bilingual">MasterCard - ماستركارد</div>
									<div class="receipt-row-en">{(masterCardAmount || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
								</div>
							{/if}
							{#if googlePayAmount > 0}
								<div class="receipt-row-stacked">
									<div class="receipt-label-bilingual">Google Pay - جوجل باي</div>
									<div class="receipt-row-en">{(googlePayAmount || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
								</div>
							{/if}
							{#if otherAmount > 0}
								<div class="receipt-row-stacked">
									<div class="receipt-label-bilingual">Other - أخرى</div>
									<div class="receipt-row-en">{(otherAmount || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
								</div>
							{/if}
							<div class="receipt-row-stacked total-row">
								<div class="receipt-label-bilingual">Total - المجموع</div>
								<div class="receipt-row-en receipt-total">{bankTotal.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
							</div>
						</div>

						<hr class="receipt-divider" />

						<!-- ERP Closing Details -->
						<div class="receipt-section">
							<div class="section-title-ar">نقاط البيع</div>
							<div class="section-title-en">ERP DETAILS</div>
							<div class="receipt-row-stacked">
								<div class="receipt-label-bilingual">ERP Cash Sales - مبيعات نقدية</div>
								<div class="receipt-row-en">{(systemCashSales || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
							</div>
							<div class="receipt-row-stacked">
								<div class="receipt-label-bilingual">ERP Card Sales - مبيعات بطاقات</div>
								<div class="receipt-row-en">{(systemCardSales || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
							</div>
							<div class="receipt-row-stacked">
								<div class="receipt-label-bilingual">Returns - المرتجعات</div>
								<div class="receipt-row-en">{(systemReturn || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
							</div>
							<div class="receipt-row-stacked total-row">
								<div class="receipt-label-bilingual">ERP Total - المجموع</div>
								<div class="receipt-row-en receipt-total">{totalSystemSales.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
							</div>
						</div>

						<hr class="receipt-divider" />

						<!-- Sales Summary -->
						<div class="receipt-section">
							<div class="section-title-ar">ملخص المبيعات</div>
							<div class="section-title-en">SALES SUMMARY</div>
							<div class="receipt-row-stacked">
								<div class="receipt-label-bilingual">Cash Sales (Total) - المبيعات النقدية (الإجمالي)</div>
								<div class="receipt-row-en">{totalCashSales.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
							</div>
							<div class="receipt-row-stacked">
								<div class="receipt-label-bilingual">Card Sales - مبيعات البطاقات</div>
								<div class="receipt-row-en">{bankTotal.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
							</div>
							<div class="receipt-row-stacked total-row">
								<div class="receipt-label-bilingual">Grand Total - الإجمالي الكلي</div>
								<div class="receipt-row-en receipt-total">{totalSales.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
							</div>
						</div>

						<hr class="receipt-divider" />

						<!-- Differences -->
						<div class="receipt-section">
							<div class="section-title-ar">التوفيق والفروقات</div>
							<div class="section-title-en">RECONCILIATION</div>
							<div class="receipt-row-stacked">
								<div class="receipt-label-bilingual">Cash Difference - فرق النقد</div>
								<div class="receipt-row-en">{differenceInCashSales.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
							</div>
							<div class="receipt-row-stacked">
								<div class="receipt-label-bilingual">Card Difference - فرق البطاقات</div>
								<div class="receipt-row-en">{differenceInCardSales.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
							</div>
							{#if totalDifference !== 0}
								<div class="receipt-row-stacked total-row">
									<div class="receipt-label-bilingual">Total Difference - إجمالي الفرق</div>
									<div class="receipt-row-en receipt-total {totalDifference < 0 ? 'negative' : 'positive'}">{totalDifference.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
								</div>
							{/if}
						</div>

						<hr class="receipt-divider" />

						<!-- Status -->
						<div class="receipt-section">
							<div class="section-title-ar">الحالة</div>
							<div class="section-title-en">STATUS</div>
							<div class="receipt-row-stacked">
								<div class="receipt-label-en">Checked By</div>
								<div class="receipt-row-en">{operationData.supervisor_name ? '✓ ' + operationData.supervisor_name : 'N/A'}</div>
							</div>
							<div class="receipt-row-stacked">
								<div class="receipt-label-bilingual">Closed By - المشرف المغلق</div>
								<div class="receipt-row-en">{supervisorName ? '✓ ' + supervisorName : 'Pending'}</div>
							</div>
							<div class="receipt-row-stacked">
								<div class="receipt-label-bilingual">Closing Status - حالة الإغلاق</div>
								<div class="receipt-row-en">{closingSaved ? '✓ Closed' : '⧖ Pending'}</div>
							</div>
						</div>

						<!-- Footer -->
						<div class="receipt-footer">
							<div class="footer-text-ar">شكراً لاستخدامك خدماتنا</div>
							<div class="footer-text-en">Thank You</div>
							<div class="receipt-date">{new Date().toLocaleString('en-US')}</div>
						</div>
					</div>
				</div>

				<div class="print-modal-actions">
					<button class="btn-print" on:click={handlePrint}>🖨️ {$currentLocale === 'ar' ? 'طباعة' : 'Print'}</button>
					<button class="btn-cancel" on:click={closePrintTemplate}>{$currentLocale === 'ar' ? 'إلغاء' : 'Cancel'}</button>
				</div>
			</div>
		</div>
	</div>
{/if}

{#if showErpPopup}
	<div class="erp-popup-overlay" on:click={closeErpPopup}>
		<div class="erp-popup-modal" on:click={(e) => e.stopPropagation()}>
			<div class="erp-popup-header">
				<h3>{$currentLocale === 'ar' ? 'يرجى إدخال القيمة إلى النظام' : 'Please Enter the Value to ERP'}</h3>
			</div>
			
			<div class="erp-popup-content">
				<label class="erp-checkbox-label">
					<input type="checkbox" bind:checked={erpLabelChecked} class="erp-checkbox-input" />
					<span class="erp-checkbox-text">
						{$currentLocale === 'ar' ? 'المبلغ المراد إدخاله' : 'Amount to Enter'}
					</span>
					<span class="erp-checkbox-value">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
						{(totalCashSales + (operation?.total_after || 0)).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
					</span>
				</label>
			</div>
			
			<div class="erp-popup-actions">
				<button class="btn-close-erp" on:click={closeErpPopup}>
					{$currentLocale === 'ar' ? 'إغلاق' : 'Close'}
				</button>
			</div>
		</div>
	</div>
{/if}

{#if showSuccessModal}
	<div class="success-modal-overlay" on:click={() => showSuccessModal = false}>
		<div class="success-modal" on:click={(e) => e.stopPropagation()}>
			<div class="success-icon">✓</div>
			<h3>{$currentLocale === 'ar' ? 'نجح' : 'Success'}</h3>
			<p class="success-text">{successMessage}</p>
			<button class="btn-ok" on:click={() => showSuccessModal = false}>
				{$currentLocale === 'ar' ? 'حسناً' : 'OK'}
			</button>
		</div>
	</div>
{/if}

{#if showCloseChecklistPopup}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="checklist-overlay" on:click={closeCloseChecklistPopup} on:keydown={(e) => { if (e.key === 'Escape') closeCloseChecklistPopup(); }} role="dialog" aria-modal="true">
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="checklist-popup" on:click|stopPropagation on:keydown|stopPropagation role="document">
			<div class="checklist-popup-header">
				<h3>{closeChecklistData ? `${closeChecklistData.id} - ${$currentLocale === 'ar' ? (closeChecklistData.checklist_name_ar || closeChecklistData.checklist_name_en) : (closeChecklistData.checklist_name_en || closeChecklistData.checklist_name_ar)}` : ($currentLocale === 'ar' ? 'قائمة التحقق' : 'Checklist')}</h3>
				<button class="close-btn" on:click={closeCloseChecklistPopup}>×</button>
			</div>
			<div class="checklist-popup-body">
				{#if loadingCloseChecklist}
					<div class="checklist-loading">
						<svg class="spinner" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none" opacity="0.25"></circle><path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" opacity="0.75"></path></svg>
					</div>
				{:else if closeChecklistQuestions.length === 0}
					<p class="no-checklists">{$currentLocale === 'ar' ? 'لا توجد أسئلة' : 'No questions in this checklist'}</p>
				{:else if closeCurrentQuestionIndex >= closeChecklistQuestions.length}
					<div class="checklist-complete">
						<div class="complete-icon">✓</div>
						<p class="complete-text">{$currentLocale === 'ar' ? 'تم إكمال القائمة!' : 'Checklist Complete!'}</p>
						<button class="complete-btn" on:click={saveCloseChecklistAndContinue}>
							{$currentLocale === 'ar' ? 'متابعة' : 'Continue'}
						</button>
					</div>
				{:else}
					{@const q = closeChecklistQuestions[closeCurrentQuestionIndex]}
					<div class="question-progress">
						<span>{$currentLocale === 'ar' ? 'السؤال' : 'Question'} {closeCurrentQuestionIndex + 1} / {closeChecklistQuestions.length}</span>
						<div class="progress-bar">
							<div class="progress-fill" style="width: {((closeCurrentQuestionIndex) / closeChecklistQuestions.length) * 100}%"></div>
						</div>
					</div>
					<div class="questions-list">
						<div class="question-card">
							<div class="question-header">
								<span class="question-number">{q.id}</span>
								<span class="question-text">{$currentLocale === 'ar' ? (q.question_ar || q.question_en) : (q.question_en || q.question_ar)}</span>
							</div>
							<div class="answers-list">
								{#each getCloseQuestionAnswers(q) as ans}
								<label class="answer-option" class:selected={closeSelectedAnswers[q.id] === ans.key}>
									<input
										type="radio"
										name={`close-q-${q.id}`}
										value={ans.key}
										checked={closeSelectedAnswers[q.id] === ans.key}
										on:change={() => { closeSelectedAnswers[q.id] = ans.key; }}
									/>
									<span class="answer-text">{$currentLocale === 'ar' ? (ans.ar || ans.en) : (ans.en || ans.ar)}</span>
									{#if ans.points !== 0}
										<span class="answer-points" class:negative={ans.points < 0}>{ans.points > 0 ? '+' : ''}{ans.points}</span>
									{/if}
								</label>
								{/each}
								{#if q.has_other}
									<label class="answer-option other-option" class:selected={closeSelectedAnswers[q.id] === 'other'}>
										<input
											type="radio"
											name={`close-q-${q.id}`}
											value="other"
											checked={closeSelectedAnswers[q.id] === 'other'}
											on:change={() => { closeSelectedAnswers[q.id] = 'other'; }}
										/>
										<span class="answer-text">{$currentLocale === 'ar' ? 'أخرى' : 'Other'}</span>
										{#if q.other_points !== 0}
											<span class="answer-points" class:negative={q.other_points < 0}>{q.other_points > 0 ? '+' : ''}{q.other_points}</span>
										{/if}
									</label>
									{#if closeSelectedAnswers[q.id] === 'other'}
										<div class="other-input-wrapper">
											<input
												type="text"
												class="other-input"
												placeholder={$currentLocale === 'ar' ? 'أدخل إجابتك...' : 'Enter your answer...'}
												bind:value={closeOtherValues[q.id]}
											/>
											<button class="next-btn" on:click={() => { if (closeCurrentQuestionIndex < closeChecklistQuestions.length) closeCurrentQuestionIndex++; }}>
												→
											</button>
										</div>
									{/if}
								{/if}
								{#if q.has_remarks}
									<div class="remarks-section">
										<textarea
											class="remarks-input"
											placeholder={$currentLocale === 'ar' ? 'ملاحظات...' : 'Remarks...'}
											bind:value={closeRemarksValues[q.id]}
										></textarea>
									</div>
								{/if}
							</div>
							<div class="nav-btn-wrapper">
								{#if closeCurrentQuestionIndex > 0}
									<button 
										class="back-question-btn" 
										on:click={() => { closeCurrentQuestionIndex--; }}
									>
										← {$currentLocale === 'ar' ? 'السابق' : 'Back'}
									</button>
								{/if}
								<button 
									class="next-question-btn" 
									disabled={!closeSelectedAnswers[q.id]}
									on:click={() => { if (closeCurrentQuestionIndex < closeChecklistQuestions.length) closeCurrentQuestionIndex++; }}
								>
									{$currentLocale === 'ar' ? 'التالي' : 'Next'} →
								</button>
								<button 
									class="incident-btn" 
									on:click={openIncidentReport}
								>
									⚠️ {$currentLocale === 'ar' ? 'الإبلاغ عن مشكلة' : 'Report a Problem'}
								</button>
							</div>
						</div>
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

{#if showReconPopup}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="erp-popup-overlay" on:click={closeReconPopup} on:keydown={(e) => { if (e.key === 'Escape') closeReconPopup(); }}>
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="erp-popup-modal" on:click|stopPropagation style="max-width: 420px;">
			<div class="erp-popup-header">
				<h3>{editingReconIndex !== null ? ($currentLocale === 'ar' ? 'تعديل التسوية' : 'Edit Reconciliation') : ($currentLocale === 'ar' ? 'إضافة تسوية' : 'Add Reconciliation')}</h3>
			</div>
			<div class="erp-popup-content" style="display: flex; flex-direction: column; gap: 10px;">
				<div class="bank-input-group">
					<label>{$currentLocale === 'ar' ? 'رقم التسوية' : 'Reconciliation #'}</label>
					<input type="text" bind:value={reconForm.reconciliation_number} class="bank-input" placeholder={$currentLocale === 'ar' ? 'أدخل رقم التسوية' : 'Enter reconciliation number'} />
				</div>
				<div class="bank-fields-row" style="flex-wrap: wrap;">
					<div class="bank-input-group">
						<label>{$currentLocale === 'ar' ? 'مدى' : 'Mada'}</label>
						<input type="text" inputmode="decimal" bind:value={reconForm.mada} class="bank-input" placeholder="0.00" />
					</div>
					<div class="bank-input-group">
						<label>{$currentLocale === 'ar' ? 'فيزا' : 'Visa'}</label>
						<input type="text" inputmode="decimal" bind:value={reconForm.visa} class="bank-input" placeholder="0.00" />
					</div>
					<div class="bank-input-group">
						<label>{$currentLocale === 'ar' ? 'ماستر كارد' : 'MasterCard'}</label>
						<input type="text" inputmode="decimal" bind:value={reconForm.mastercard} class="bank-input" placeholder="0.00" />
					</div>
					<div class="bank-input-group">
						<label>{$currentLocale === 'ar' ? 'جوجل باي' : 'Google Pay'}</label>
						<input type="text" inputmode="decimal" bind:value={reconForm.google_pay} class="bank-input" placeholder="0.00" />
					</div>
					<div class="bank-input-group">
						<label>{$currentLocale === 'ar' ? 'أخرى' : 'Other'}</label>
						<input type="text" inputmode="decimal" bind:value={reconForm.other} class="bank-input" placeholder="0.00" />
					</div>
				</div>
				<div class="bank-total" style="margin-top: 4px;">
					<span class="label">{$currentLocale === 'ar' ? 'المجموع:' : 'Total:'}</span>
					<div class="amount">
						<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
						<span>{((Number(reconForm.mada) || 0) + (Number(reconForm.visa) || 0) + (Number(reconForm.mastercard) || 0) + (Number(reconForm.google_pay) || 0) + (Number(reconForm.other) || 0)).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
					</div>
				</div>
			</div>
			<div class="erp-popup-actions" style="display: flex; gap: 8px; justify-content: flex-end; padding: 12px 16px;">
				<button class="btn-close-erp" on:click={saveRecon} style="background: #2563eb; color: white;">
					{$currentLocale === 'ar' ? 'حفظ' : 'Save'}
				</button>
				<button class="btn-close-erp" on:click={closeReconPopup}>
					{$currentLocale === 'ar' ? 'إلغاء' : 'Cancel'}
				</button>
			</div>
		</div>
	</div>
{/if}


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
		grid-auto-rows: auto;
		align-items: start;
	}

	.half-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		padding: 0.5rem;
		position: relative;
		display: flex;
		flex-direction: column;
	}

	.split-card {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		padding: 0;
	}

	.split-section {
		flex: none;
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
		flex: none;
		min-height: 200px;
	}

	.split-section:nth-child(2) {
		flex: none;
		min-height: 140px;
	}

	.split-section:nth-child(3) {
		flex: none;
		min-height: 130px;
	}

	.split-section:nth-child(4) {
		flex: none;
		min-height: 130px;
	}

	/* Left column specific sizes (Cards 7 & 8) */
	.half-card:first-child .split-section:nth-child(1) {
		flex: none;
		min-height: 500px;
	}

	.half-card:first-child .split-section:nth-child(2) {
		flex: none;
		min-height: 350px;
	}

	/* Recharge Cards Card 11 Styling */
	.recharge-card-section-11 {
		flex: 1.44 !important;
		min-height: 280px !important;
		border: 3px solid #ea580c !important;
		padding: 0.5rem !important;
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
		flex: 0.5;
		align-items: flex-end;
	}

	.balance-group {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
		min-width: 0;
		height: auto;
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
		flex: 0;
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

	.reprint-button {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 2px solid #0284c7;
		border-radius: 0.25rem;
		background: #0284c7;
		color: white;
		font-size: 0.7rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		box-sizing: border-box;
	}

	.reprint-button:hover {
		background: #0369a1;
		border-color: #0369a1;
	}

	.reprint-button:active {
		transform: scale(0.98);
	}

	.print-button {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 2px solid #0284c7;
		border-radius: 0.25rem;
		background: #0284c7;
		color: white;
		font-size: 0.7rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		box-sizing: border-box;
	}

	.print-button:hover {
		background: #0369a1;
		border-color: #0369a1;
	}

	.print-button:active {
		transform: scale(0.98);
	}

	.print-button:disabled {
		background: #cbd5e1;
		border-color: #cbd5e1;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.print-button:disabled:hover {
		background: #cbd5e1;
		border-color: #cbd5e1;
	}

	.save-image-button {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 2px solid #7c3aed;
		border-radius: 0.25rem;
		background: #7c3aed;
		color: white;
		font-size: 0.7rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		box-sizing: border-box;
	}

	.save-image-button:hover {
		background: #6d28d9;
		border-color: #6d28d9;
	}

	.save-image-button:active {
		transform: scale(0.98);
	}

	.save-image-button:disabled {
		background: #cbd5e1;
		border-color: #cbd5e1;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.save-image-button:disabled:hover {
		background: #cbd5e1;
		border-color: #cbd5e1;
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
		z-index: 1000;
	}

	.print-modal {
		background: white;
		border-radius: 0.75rem;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.3);
		max-width: 500px;
		width: 90%;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
	}

	.print-modal-header {
		padding: 1.5rem;
		border-bottom: 2px solid #e5e7eb;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.print-modal-header h3 {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 700;
		color: #1f2937;
	}

	.close-modal-btn {
		background: none;
		border: none;
		font-size: 1.5rem;
		cursor: pointer;
		color: #6b7280;
		transition: all 0.2s;
		width: 2rem;
		height: 2rem;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.close-modal-btn:hover {
		color: #1f2937;
		background: #f3f4f6;
		border-radius: 0.375rem;
	}

	.print-modal-content {
		flex: 1;
		overflow-y: auto;
		padding: 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	/* A4 Modal Styles */
	.a4-modal-overlay {
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

	/* Hide modal overlay when auto-saving */
	.a4-modal-overlay.auto-saving {
		background: transparent;
		pointer-events: none;
	}

	.a4-modal {
		background: white;
		border-radius: 0.75rem;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.3);
		width: 98%;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
	}

	.a4-modal-header {
		padding: 1.5rem;
		border-bottom: 2px solid #e5e7eb;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.a4-modal-header h3 {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 700;
		color: #1f2937;
	}

	.a4-modal-content {
		flex: 1;
		overflow-y: auto;
		padding: 1.5rem;
		background: #f5f5f5;
	}

	/* A4 Page Style */
	.a4-page {
		width: 100%;
		background: white;
		padding: 1.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.a4-top-info-row {
		display: flex;
		gap: 1rem;
		padding: 0.75rem;
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border: 2px solid #86efac;
		border-radius: 0.5rem;
		margin-bottom: 1rem;
		flex-wrap: wrap;
	}

	.a4-info-group {
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
		flex: 1;
		min-width: 150px;
	}

	.a4-info-label {
		font-size: 0.65rem;
		font-weight: 700;
		color: #ea580c;
	}

	.a4-info-value {
		font-size: 0.8rem;
		font-weight: 600;
		color: #166534;
	}

	.a4-two-columns {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
	}

	.a4-left-column,
	.a4-right-column {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.a4-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.375rem;
		padding: 0.75rem;
	}

	.a4-card-title {
		font-size: 0.75rem;
		font-weight: 700;
		color: #1f2937;
		margin: 0 0 0.5rem 0;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.a4-denom-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.25rem;
		margin-bottom: 0.5rem;
	}

	.a4-denom-row {
		display: flex;
		justify-content: space-between;
		font-size: 0.65rem;
		padding: 0.25rem 0.5rem;
		background: #f9fafb;
		border-radius: 0.25rem;
	}

	.a4-denom-label {
		font-weight: 600;
		color: #4b5563;
	}

	.a4-denom-value {
		color: #6b7280;
	}

	.a4-closing-total {
		display: flex;
		justify-content: space-between;
		padding: 0.5rem;
		background: #dbeafe;
		border: 1px solid #bfdbfe;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 600;
		color: #1e40af;
		margin-bottom: 0.25rem;
	}

	.a4-cash-sales {
		display: flex;
		justify-content: space-between;
		padding: 0.5rem;
		background: #dcfce7;
		border: 1px solid #86efac;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 600;
		color: #15803d;
	}

	.a4-vouchers-table {
		width: 100%;
		font-size: 0.65rem;
		margin-bottom: 0.5rem;
		border-collapse: collapse;
	}

	.a4-vouchers-table th,
	.a4-vouchers-table td {
		padding: 0.3rem;
		text-align: left;
		border-bottom: 1px solid #e5e7eb;
	}

	.a4-vouchers-table th {
		background: #f3f4f6;
		font-weight: 600;
	}

	.a4-vouchers-total {
		display: flex;
		justify-content: space-between;
		padding: 0.5rem;
		background: #fef3c7;
		border: 1px solid #fcd34d;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 600;
		color: #92400e;
		margin-bottom: 0.5rem;
	}

	.a4-total-cash-sales {
		display: flex;
		justify-content: space-between;
		padding: 0.5rem;
		background: #fed7aa;
		border: 1px solid #fb923c;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 600;
		color: #92400e;
	}

	.a4-summary-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.5rem;
	}

	.a4-summary-card {
		display: flex;
		justify-content: space-between;
		padding: 0.5rem;
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border: 1px solid #86efac;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 600;
	}

	.a4-summary-label {
		color: #166534;
	}

	.a4-summary-value {
		color: #15803d;
	}

	.a4-bank-grid,
	.a4-erp-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 0.3rem;
		margin-bottom: 0.5rem;
	}

	.a4-bank-item,
	.a4-erp-item {
		display: flex;
		justify-content: space-between;
		padding: 0.3rem 0.5rem;
		background: #f9fafb;
		border-radius: 0.25rem;
		font-size: 0.65rem;
	}

	.a4-bank-label,
	.a4-erp-label {
		font-weight: 600;
		color: #4b5563;
	}

	.a4-bank-total,
	.a4-erp-total {
		display: flex;
		justify-content: space-between;
		padding: 0.5rem;
		background: #dbeafe;
		border: 1px solid #bfdbfe;
		border-radius: 0.25rem;
		font-size: 0.7rem;
		font-weight: 600;
		color: #1e40af;
	}

	.a4-diff-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 0.3rem;
		margin-bottom: 0.5rem;
	}

	.a4-diff-item {
		display: flex;
		justify-content: space-between;
		padding: 0.3rem 0.5rem;
		background: #f9fafb;
		border-radius: 0.25rem;
		font-size: 0.65rem;
	}

	.a4-diff-label {
		font-weight: 600;
		color: #4b5563;
	}

	.a4-diff-negative {
		color: #dc2626;
		font-weight: 600;
	}

	.a4-diff-positive {
		color: #15803d;
		font-weight: 600;
	}

	.a4-status-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 0.3rem;
	}

	.a4-status-item {
		display: flex;
		justify-content: space-between;
		padding: 0.3rem 0.5rem;
		background: #f9fafb;
		border-radius: 0.25rem;
		font-size: 0.65rem;
		font-weight: 600;
	}

	.a4-modal-actions {
		display: flex;
		gap: 0.75rem;
		padding: 1rem 1.5rem;
		border-top: 2px solid #e5e7eb;
		background: white;
	}

	.btn-download {
		flex: 1;
		padding: 0.75rem 1.5rem;
		background: #10b981;
		color: white;
		border: 2px solid #10b981;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-download:hover {
		background: #059669;
		border-color: #059669;
	}

	.btn-download:active {
		transform: scale(0.98);
	}

	/* 80mm Thermal Receipt Styles */
	.thermal-receipt {
		font-family: 'Courier New', monospace;
		width: 80mm;
		background: white;
		padding: 0;
		margin: 0 auto;
	}

	.receipt-container {
		width: 100%;
		font-size: 10pt;
		line-height: 1.4;
	}

	.receipt-logo {
		text-align: center;
		padding: 0.05rem 0;
		margin-bottom: 0.05rem;
		border-bottom: 1px solid #000;
	}

	.logo-image {
		max-width: 10%;
		height: auto;
		max-height: 10px;
	}

	.receipt-header {
		text-align: center;
		padding-bottom: 0.5rem;
	}

	.receipt-title-ar {
		font-size: 12pt;
		font-weight: bold;
		direction: rtl;
		unicode-bidi: bidi-override;
		margin-bottom: 0.2rem;
	}

	.receipt-title-en {
		font-size: 11pt;
		font-weight: bold;
		margin-bottom: 0.3rem;
	}

	.receipt-divider {
		border: none;
		border-top: 1px dashed #000;
		margin: 0.3rem 0;
	}

	.receipt-section {
		padding: 0.3rem 0;
	}

	.section-title-ar {
		font-size: 10pt;
		font-weight: bold;
		direction: rtl;
		unicode-bidi: embed;
		text-align: right;
		margin-bottom: 0.2rem;
	}

	.section-title-en {
		font-size: 9pt;
		font-weight: bold;
		text-align: center;
		margin-bottom: 0.2rem;
	}

	.receipt-row-bilingual {
		display: flex;
		flex-direction: column;
		margin-bottom: 0.3rem;
		font-size: 9pt;
	}

	.receipt-row-stacked {
		display: flex;
		flex-direction: column;
		margin-bottom: 0.2rem;
		width: 100%;
	}

	.receipt-label-ar {
		direction: rtl;
		unicode-bidi: embed;
		text-align: right;
		font-weight: bold;
		font-size: 8pt;
		margin-bottom: 0.05rem;
		color: #1f2937;
	}

	.receipt-row-ar {
		direction: rtl;
		unicode-bidi: embed;
		text-align: right;
		margin-bottom: 0.15rem;
		font-weight: 600;
		font-size: 9pt;
	}

	.receipt-label-en {
		text-align: left;
		font-weight: bold;
		font-size: 8pt;
		margin-bottom: 0.05rem;
		color: #1f2937;
	}

	.receipt-row-en {
		text-align: left;
		font-weight: 600;
		font-size: 9pt;
		margin-bottom: 0.1rem;
	}

	.receipt-row-bilingual.total-row {
		border-top: 1px solid #000;
		border-bottom: 1px solid #000;
		padding: 0.2rem 0;
		margin: 0.2rem 0;
	}

	.receipt-row-bilingual .receipt-total {
		font-weight: bold;
		font-size: 10pt;
	}

	.receipt-row-ar.negative,
	.receipt-row-en.negative {
		color: #dc2626;
	}

	.receipt-row-ar.positive,
	.receipt-row-en.positive {
		color: #15803d;
	}

	.receipt-row {
		display: flex;
		justify-content: space-between;
		margin-bottom: 0.15rem;
		font-size: 9pt;
	}

	.label-ar {
		direction: rtl;
		unicode-bidi: bidi-override;
		text-align: right;
		flex: 1;
	}

	.label-en {
		flex: 1;
	}

	.value-en {
		text-align: right;
		flex: 1;
	}

	.receipt-row.total-row {
		border-top: 1px solid #000;
		border-bottom: 1px solid #000;
		padding: 0.2rem 0;
		font-weight: bold;
		margin: 0.2rem 0;
	}

	.receipt-row.total-row .value-en.total {
		font-weight: bold;
		font-size: 11pt;
	}

	.value-en.negative {
		color: #dc2626;
	}

	.value-en.positive {
		color: #15803d;
	}

	.receipt-footer {
		text-align: center;
		padding-top: 0.3rem;
		padding-bottom: 0.3rem;
	}

	.footer-text-ar {
		font-size: 10pt;
		direction: rtl;
		unicode-bidi: bidi-override;
		margin-bottom: 0.1rem;
	}

	.footer-text-en {
		font-size: 10pt;
		font-weight: bold;
		margin-bottom: 0.1rem;
	}

	.receipt-date {
		font-size: 8pt;
		color: #666;
		margin-top: 0.2rem;
	}

	.print-modal-actions {
		display: flex;
		gap: 0.75rem;
		padding-top: 1rem;
		border-top: 2px solid #e5e7eb;
	}

	.btn-print {
		flex: 1;
		padding: 0.75rem 1.5rem;
		background: #0284c7;
		color: white;
		border: 2px solid #0284c7;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-print:hover {
		background: #0369a1;
		border-color: #0369a1;
	}

	.btn-print:active {
		transform: scale(0.98);
	}

	.btn-cancel {
		flex: 1;
		padding: 0.75rem 1.5rem;
		background: white;
		color: #6b7280;
		border: 2px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-cancel:hover {
		background: #f9fafb;
		border-color: #9ca3af;
		color: #374151;
	}

	.btn-cancel:active {
		transform: scale(0.98);
	}

	@media print {
		.print-modal {
			display: none;
		}
		body {
			margin: 0;
			padding: 0;
		}
		.thermal-receipt {
			width: 80mm;
			margin: 0;
		}
	}

	/* Right column specific sizes */
	.half-card:last-child .split-section:nth-child(1) {
		flex: none;
		min-height: auto;
		max-height: 500px;
		overflow-y: auto;
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

	.denom-input-wrapper {
		flex: 1;
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 0.4rem;
		min-width: 0;
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

	/* Reconciliation cards */
	.recon-cards-list {
		display: flex;
		flex-direction: column;
		gap: 6px;
		margin-bottom: 8px;
		padding-right: 2px;
	}

	.recon-card {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		overflow: hidden;
	}

	.recon-card-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 4px 8px;
		background: #eef2ff;
		border-bottom: 1px solid #e2e8f0;
	}

	.recon-card-body {
		padding: 4px 8px;
	}

	.recon-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1px 0;
		font-size: 0.68rem;
	}

	.recon-row-total {
		border-top: 1px solid #cbd5e1;
		margin-top: 2px;
		padding-top: 3px;
		font-weight: 700;
		color: #1e40af;
	}

	.recon-label {
		color: #64748b;
		font-weight: 600;
	}

	.recon-value {
		font-family: 'SF Mono', 'Consolas', monospace;
		color: #334155;
		font-weight: 600;
	}

	.recon-row-total .recon-value {
		color: #1e40af;
	}

	.recon-overall-totals {
		background: #f0f9ff;
		border: 1px solid #bae6fd;
		border-radius: 8px;
		padding: 6px 8px;
		margin-bottom: 6px;
	}

	.recon-overall-header {
		font-size: 0.68rem;
		font-weight: 800;
		color: #0369a1;
		margin-bottom: 4px;
		text-align: center;
	}

	.recon-overall-totals .recon-row {
		font-size: 0.7rem;
	}

	.recon-overall-totals .recon-label {
		color: #0c4a6e;
	}

	.recon-overall-totals .recon-value {
		color: #0c4a6e;
		font-weight: 700;
	}

	.recon-overall-grid {
		display: flex;
		flex-wrap: wrap;
		gap: 6px;
		margin-bottom: 4px;
	}

	.recon-grid-item {
		flex: 1 1 calc(33.33% - 6px);
		min-width: 80px;
		display: flex;
		flex-direction: column;
		align-items: center;
		background: #e0f2fe;
		border-radius: 6px;
		padding: 4px 6px;
		gap: 1px;
	}

	.recon-grid-item .recon-label {
		font-size: 0.6rem;
		color: #0369a1;
	}

	.recon-grid-item .recon-value {
		font-size: 0.72rem;
		color: #0c4a6e;
		font-weight: 800;
		font-family: 'SF Mono', 'Consolas', monospace;
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

	.recharge-time-fields {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		padding: 0.5rem;
		background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
		border-radius: 0.5rem;
		border: 2px solid #fcd34d;
	}

	.date-time-field-row {
		display: flex;
		gap: 0.5rem;
		align-items: flex-end;
	}

	.date-field-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		flex: 1;
	}

	.date-field-group label {
		font-size: 0.75rem;
		font-weight: 700;
		color: #92400e;
		letter-spacing: 0.5px;
	}

	.date-input-field {
		padding: 0.4rem;
		border: 2px solid #fed7aa;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		color: #92400e;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
	}

	.date-input-field:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.time-field-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		flex: 1;
	}

	.time-field-group label {
		font-size: 0.75rem;
		font-weight: 700;
		color: #92400e;
		letter-spacing: 0.5px;
	}

	.time-input-controls {
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.time-input-hm {
		width: 70px;
		padding: 0.4rem;
		border: 2px solid #fed7aa;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		color: #92400e;
		text-align: center;
		background: white;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
	}

	.time-input-hm:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
	}

	.time-separator {
		font-size: 0.875rem;
		font-weight: 700;
		color: #92400e;
		padding: 0 0.1rem;
	}

	.time-input-ampm {
		padding: 0.4rem 0.5rem;
		border: 2px solid #fed7aa;
		border-radius: 0.375rem;
		font-size: 0.75rem;
		font-weight: 600;
		color: #92400e;
		background: white;
		cursor: pointer;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
		transition: all 0.2s;
	}

	.time-input-ampm:focus {
		outline: none;
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.2);
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

	.card-header-with-checkbox {
		display: flex;
		justify-content: space-between;
		align-items: center;
		width: 100%;
		margin-bottom: 0.5rem;
	}

	.checkbox-container {
		display: inline-flex;
		position: relative;
		cursor: pointer;
		user-select: none;
	}

	.checkbox-container input {
		position: absolute;
		opacity: 0;
		cursor: pointer;
		height: 0;
		width: 0;
	}

	.checkmark {
		height: 20px;
		width: 20px;
		background-color: white;
		border: 2px solid #f97316;
		border-radius: 4px;
		transition: all 0.2s;
		position: relative;
	}

	.checkbox-container:hover input ~ .checkmark {
		background-color: #fed7aa;
	}

	.checkbox-container input:checked ~ .checkmark {
		background-color: #22c55e;
		border-color: #22c55e;
	}

	.checkmark:after {
		content: "";
		position: absolute;
		display: none;
	}

	.checkbox-container input:checked ~ .checkmark:after {
		display: block;
	}

	.checkbox-container .checkmark:after {
		left: 5px;
		top: 1px;
		width: 5px;
		height: 10px;
		border: solid white;
		border-width: 0 3px 3px 0;
		transform: rotate(45deg);
	}

	.checkbox-number {
		font-size: 0.7rem;
		font-weight: 700;
		color: #f97316;
		margin-right: 0.5rem;
		padding: 0.1rem 0.4rem;
		background: #fed7aa;
		border-radius: 0.25rem;
		min-width: 1.2rem;
		text-align: center;
		display: inline-block;
	}

	/* ERP Popup Styles */
	.erp-popup-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.erp-popup-modal {
		background: white;
		border-radius: 1rem;
		padding: 1.5rem;
		min-width: 400px;
		max-width: 500px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.3);
	}

	.erp-popup-header {
		margin-bottom: 1.5rem;
		text-align: center;
	}

	.erp-popup-header h3 {
		font-size: 1.25rem;
		font-weight: 700;
		color: #f97316;
		margin: 0;
	}

	.erp-popup-content {
		margin-bottom: 1.5rem;
	}

	.erp-checkbox-label {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1rem;
		background: linear-gradient(135deg, #fef3c7 0%, #fed7aa 100%);
		border: 2px solid #f97316;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.erp-checkbox-label:hover {
		background: linear-gradient(135deg, #fed7aa 0%, #fdba74 100%);
		box-shadow: 0 4px 6px -1px rgba(249, 115, 22, 0.3);
	}

	.erp-checkbox-input {
		width: 24px;
		height: 24px;
		cursor: pointer;
		accent-color: #f97316;
	}

	.erp-checkbox-text {
		flex: 1;
		font-size: 0.95rem;
		font-weight: 600;
		color: #92400e;
	}

	.erp-checkbox-value {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 1rem;
		font-weight: 700;
		color: #ea580c;
		padding: 0.25rem 0.75rem;
		background: white;
		border-radius: 0.375rem;
	}

	.erp-popup-actions {
		display: flex;
		justify-content: center;
	}

	.btn-close-erp {
		padding: 0.75rem 2rem;
		background: #f97316;
		border: none;
		border-radius: 0.5rem;
		color: white;
		font-size: 0.95rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-close-erp:hover {
		background: #ea580c;
		transform: translateY(-1px);
		box-shadow: 0 4px 6px -1px rgba(249, 115, 22, 0.4);
	}

	.btn-close-erp:active {
		transform: translateY(0);
	}

	/* Success Modal Styles */
	.success-modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 10000;
	}

	.success-modal {
		background: white;
		padding: 2rem;
		border-radius: 1rem;
		max-width: 400px;
		width: 90%;
		box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
		text-align: center;
	}

	.success-icon {
		width: 64px;
		height: 64px;
		background: #22c55e;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 2.5rem;
		color: white;
		margin: 0 auto 1rem;
		font-weight: bold;
	}

	.success-modal h3 {
		font-size: 1.5rem;
		font-weight: 700;
		color: #166534;
		margin-bottom: 0.75rem;
	}

	.success-text {
		font-size: 1rem;
		color: #4b5563;
		margin-bottom: 1.5rem;
		line-height: 1.5;
	}

	.btn-ok {
		width: 100%;
		padding: 0.75rem 1.5rem;
		background: #22c55e;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-ok:hover {
		background: #16a34a;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(34, 197, 94, 0.3);
	}

	.btn-ok:active {
		transform: translateY(0);
	}

	/* Checklist popup styles */
	.checklist-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 10000;
	}

	.checklist-popup {
		background: white;
		border-radius: 1rem;
		width: 500px;
		max-height: 80vh;
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
		overflow: hidden;
	}

	.checklist-popup-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.5rem;
		background: linear-gradient(135deg, #7c3aed, #8b5cf6);
		color: white;
	}

	.checklist-popup-header h3 {
		margin: 0;
		font-size: 1rem;
		font-weight: 700;
	}

	.checklist-popup-header .close-btn {
		background: rgba(255, 255, 255, 0.2);
		border: none;
		color: white;
		font-size: 1.5rem;
		width: 2rem;
		height: 2rem;
		border-radius: 0.5rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.checklist-popup-body {
		padding: 1rem 1.5rem;
		max-height: 60vh;
		overflow-y: auto;
	}

	.checklist-loading {
		display: flex;
		justify-content: center;
		padding: 2rem;
	}

	.checklist-loading .spinner {
		width: 2rem;
		height: 2rem;
		color: #7c3aed;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.no-checklists {
		text-align: center;
		color: #94a3b8;
		padding: 2rem;
		font-size: 0.875rem;
	}

	.question-card {
		border: 2px solid #e2e8f0;
		border-radius: 0.75rem;
		padding: 1rem;
		background: #f8fafc;
	}

	.question-header {
		display: flex;
		align-items: flex-start;
		gap: 0.75rem;
		margin-bottom: 0.75rem;
	}

	.question-number {
		font-size: 0.75rem;
		font-weight: 800;
		color: #7c3aed;
		background: #ede9fe;
		padding: 0.25rem 0.5rem;
		border-radius: 0.375rem;
		white-space: nowrap;
	}

	.question-text {
		font-size: 0.9rem;
		font-weight: 600;
		color: #1e293b;
		line-height: 1.4;
	}

	.answers-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-left: 0.5rem;
	}

	.answer-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 0.75rem;
		border: 1px solid #e2e8f0;
		border-radius: 0.5rem;
		background: white;
		cursor: pointer;
		transition: all 0.2s;
	}

	.answer-option:hover {
		border-color: #7c3aed;
		background: #faf5ff;
	}

	.answer-option.selected {
		border-color: #7c3aed;
		background: #ede9fe;
	}

	.answer-option input[type="radio"] {
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		width: 1rem;
		height: 1rem;
		border: 2px solid #cbd5e1;
		border-radius: 0.25rem;
		background: white;
		cursor: pointer;
		position: relative;
	}

	.answer-option input[type="radio"]:checked {
		background: #7c3aed;
		border-color: #7c3aed;
	}

	.answer-option input[type="radio"]:checked::after {
		content: '✓';
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		color: white;
		font-size: 0.7rem;
		font-weight: bold;
	}

	.answer-text {
		flex: 1;
		font-size: 0.875rem;
		color: #334155;
	}

	.answer-points {
		font-size: 0.75rem;
		font-weight: 700;
		color: #059669;
		background: #d1fae5;
		padding: 0.125rem 0.375rem;
		border-radius: 0.25rem;
	}

	.answer-points.negative {
		color: #dc2626;
		background: #fee2e2;
	}

	.question-progress {
		margin-bottom: 1rem;
		text-align: center;
	}

	.question-progress span {
		font-size: 0.8rem;
		color: #64748b;
		font-weight: 600;
	}

	.progress-bar {
		height: 6px;
		background: #e2e8f0;
		border-radius: 3px;
		margin-top: 0.5rem;
		overflow: hidden;
	}

	.progress-fill {
		height: 100%;
		background: linear-gradient(90deg, #7c3aed, #8b5cf6);
		border-radius: 3px;
		transition: width 0.3s ease;
	}

	.checklist-complete {
		text-align: center;
		padding: 2rem;
	}

	.complete-icon {
		width: 4rem;
		height: 4rem;
		background: linear-gradient(135deg, #10b981, #059669);
		color: white;
		font-size: 2rem;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		margin: 0 auto 1rem;
	}

	.complete-text {
		font-size: 1.1rem;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 1rem;
	}

	.complete-btn {
		background: linear-gradient(135deg, #7c3aed, #8b5cf6);
		color: white;
		border: none;
		padding: 0.75rem 2rem;
		border-radius: 0.5rem;
		font-weight: 600;
		cursor: pointer;
		transition: transform 0.2s, box-shadow 0.2s;
	}

	.complete-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(124, 58, 237, 0.4);
	}

	.other-input-wrapper {
		display: flex;
		gap: 0.5rem;
		align-items: center;
		margin-top: 0.5rem;
	}

	.other-input {
		flex: 1;
		padding: 0.5rem 0.75rem;
		border: 1px solid #e2e8f0;
		border-radius: 0.5rem;
		font-size: 0.875rem;
	}

	.next-btn {
		background: #7c3aed;
		color: white;
		border: none;
		width: 2rem;
		height: 2rem;
		border-radius: 0.5rem;
		cursor: pointer;
		font-size: 1rem;
	}

	.nav-btn-wrapper {
		display: flex;
		justify-content: center;
		gap: 1rem;
		margin-top: 1rem;
		padding-top: 0.75rem;
		border-top: 1px solid #e2e8f0;
	}

	.back-question-btn {
		background: #6b7280;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 0.5rem;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
		transition: background 0.2s;
	}

	.back-question-btn:hover {
		background: #4b5563;
	}

	.next-question-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.75rem 2rem;
		border-radius: 0.5rem;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
		transition: background 0.2s, opacity 0.2s;
	}

	.next-question-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.next-question-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.incident-btn {
		background: #ef4444;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 0.5rem;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
		transition: background 0.2s;
	}

	.incident-btn:hover {
		background: #dc2626;
	}

	.remarks-section {
		margin-top: 0.5rem;
	}

	.remarks-input {
		width: 100%;
		padding: 0.5rem 0.75rem;
		border: 1px solid #e2e8f0;
		border-radius: 0.5rem;
		font-size: 0.875rem;
		resize: vertical;
		min-height: 3rem;
	}

	.questions-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}
</style>


