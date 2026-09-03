<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';
	import { t } from '$lib/i18n';
	import { iconUrlMap } from '$lib/stores/iconStore';
	import { getEmployeeDisplayName } from '$lib/utils/employeeDisplayName';
	import { addMoney, money, multiplyMoney, subtractMoney } from '$lib/utils/money';
	import { windowManager } from '$lib/stores/windowManager';

	export let windowId: string;
	export let box: any;
	export let branch: any;
	export let user: any;

	$: currencySymbolUrl = $iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png';

	// Portal action: moves a node to document.body so the denomination dropdown panel/backdrop
	// isn't clipped by this window's own scroll container.
	function portal(node: HTMLElement) {
		document.body.appendChild(node);
		return {
			destroy() {
				if (node.parentNode) node.parentNode.removeChild(node);
			}
		};
	}

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

	let realCounts: Record<string, number> = {};
	Object.keys(denomValues).forEach(key => {
		realCounts[key] = undefined;
	});

	// Denomination count input — dropdown + stepper buttons instead of free typing, same pattern
	// as CloseBox.svelte's closing cash entry, so a stray keystroke can't silently produce a wrong count.
	const DENOM_COUNT_DEFAULT_MAX = 100;
	function denomCountOptions(currentValue: number | undefined): number[] {
		const max = Math.max(DENOM_COUNT_DEFAULT_MAX, currentValue || 0);
		return Array.from({ length: max + 1 }, (_, i) => i);
	}

	const DENOM_PAGE_SIZE = 20;
	function denomPageCount(key: string): number {
		return Math.ceil(denomCountOptions(realCounts[key]).length / DENOM_PAGE_SIZE);
	}
	function denomPageOptions(key: string, page: number): number[] {
		return denomCountOptions(realCounts[key]).slice(page * DENOM_PAGE_SIZE, page * DENOM_PAGE_SIZE + DENOM_PAGE_SIZE);
	}

	function commitRealCountChange() {
		realCounts = { ...realCounts };
		changeCounter++;
		saveDenominationCounts();
	}

	function incrementDenomCount(key: string) {
		if (isCountReadonly) return;
		realCounts[key] = (Number(realCounts[key]) || 0) + 1;
		commitRealCountChange();
	}
	function decrementDenomCount(key: string) {
		if (isCountReadonly) return;
		const current = Number(realCounts[key]) || 0;
		realCounts[key] = current > 0 ? current - 1 : 0;
		commitRealCountChange();
	}
	function clearDenomCount(key: string) {
		if (isCountReadonly) return;
		realCounts[key] = 0;
		commitRealCountChange();
	}

	// Custom dropdown panel (replaces the native <select>) — portaled to <body> and positioned from
	// the trigger's live bounding rect so it can never get clipped, and closes on scroll/resize.
	let openDenomDropdown: string | null = null;
	let denomTriggerEls: Record<string, HTMLButtonElement> = {};
	let denomDropdownPos = { top: 0, left: 0 };
	let denomDropdownPage = 0;

	function closeDenomDropdown() {
		openDenomDropdown = null;
		window.removeEventListener('scroll', closeDenomDropdown, true);
		window.removeEventListener('resize', closeDenomDropdown, true);
	}

	function toggleDenomDropdown(key: string) {
		if (isCountReadonly) return;
		window.removeEventListener('scroll', closeDenomDropdown, true);
		window.removeEventListener('resize', closeDenomDropdown, true);
		if (openDenomDropdown === key) {
			openDenomDropdown = null;
			return;
		}
		const el = denomTriggerEls[key];
		if (el) {
			const rect = el.getBoundingClientRect();
			const panelHalfWidth = 104; // half of the panel's 13rem width
			const centerX = Math.min(Math.max(rect.left + rect.width / 2, panelHalfWidth + 8), window.innerWidth - panelHalfWidth - 8);
			denomDropdownPos = { top: rect.bottom + 6, left: centerX };
		}
		denomDropdownPage = Math.floor((Number(realCounts[key]) || 0) / DENOM_PAGE_SIZE);
		openDenomDropdown = key;
		window.addEventListener('scroll', closeDenomDropdown, true);
		window.addEventListener('resize', closeDenomDropdown, true);
	}

	function selectDenomValue(key: string, n: number) {
		if (isCountReadonly) return;
		realCounts[key] = n;
		commitRealCountChange();
		closeDenomDropdown();
	}

	let matchStatus: 'match' | 'mismatch' | null = null;
	let displayTotal: number = 0;
	let cashierAccessCode = '';
	let cashierName = '';
	let cashierCodeValid = false;
	let supervisorAccessCode = '';
	let supervisorName = '';

	// Access codes are always exactly 6 digits, entered as individual boxes (like an OTP field)
	// instead of a free-text password box — same digit-box pattern as ChangeAccessCode.svelte,
	// keeping cashierAccessCode/supervisorAccessCode as the source of truth everything else here
	// (verify/lookup/validate/hasChangesAfterValidation) already reads.
	let cashierCodeDigits: string[] = ['', '', '', '', '', ''];
	let supervisorCodeDigits: string[] = ['', '', '', '', '', ''];

	function handleAccessCodeDigitInput(e: Event, index: number, digits: string[], field: 'cashier' | 'supervisor') {
		const input = e.target as HTMLInputElement;
		const value = input.value.replace(/[^0-9]/g, '');
		digits[index] = value.slice(-1);

		if (value && index < 5) {
			const next = document.getElementById(`${field}-code-${index + 1}`) as HTMLInputElement;
			if (next) next.focus();
		}

		if (field === 'cashier') {
			cashierCodeDigits = [...digits];
			cashierAccessCode = cashierCodeDigits.join('');
			if (cashierAccessCode.length === 6) verifyCashierAccessCode();
			else { cashierCodeValid = false; cashierName = ''; }
		} else {
			supervisorCodeDigits = [...digits];
			supervisorAccessCode = supervisorCodeDigits.join('');
			if (supervisorAccessCode.length === 6) lookupSupervisorAccessCode();
			else { supervisorName = ''; supervisorUserId = null; }
		}
		changeCounter++;
	}

	function handleAccessCodeDigitKeydown(e: KeyboardEvent, index: number, digits: string[], field: 'cashier' | 'supervisor') {
		if (e.key === 'Backspace' && !digits[index] && index > 0) {
			const prev = document.getElementById(`${field}-code-${index - 1}`) as HTMLInputElement;
			if (prev) prev.focus();
			digits[index - 1] = '';
			if (field === 'cashier') {
				cashierCodeDigits = [...digits];
				cashierAccessCode = cashierCodeDigits.join('');
				cashierCodeValid = false;
				cashierName = '';
			} else {
				supervisorCodeDigits = [...digits];
				supervisorAccessCode = supervisorCodeDigits.join('');
				supervisorName = '';
				supervisorUserId = null;
			}
			changeCounter++;
		}
	}

	function handleAccessCodeDigitPaste(e: ClipboardEvent, digits: string[], field: 'cashier' | 'supervisor') {
		e.preventDefault();
		const text = (e.clipboardData?.getData('text') || '').replace(/[^0-9]/g, '').slice(0, 6);
		for (let i = 0; i < 6; i++) digits[i] = text[i] || '';

		if (field === 'cashier') {
			cashierCodeDigits = [...digits];
			cashierAccessCode = cashierCodeDigits.join('');
			if (cashierAccessCode.length === 6) verifyCashierAccessCode();
		} else {
			supervisorCodeDigits = [...digits];
			supervisorAccessCode = supervisorCodeDigits.join('');
			if (supervisorAccessCode.length === 6) lookupSupervisorAccessCode();
		}
		changeCounter++;

		const focusIdx = Math.min(text.length, 5);
		const el = document.getElementById(`${field}-code-${focusIdx}`) as HTMLInputElement;
		if (el) el.focus();
	}
	let supervisorUserId: string | null = null; // tracked so we can catch the cashier using their own code as the "supervisor" one too
	let selectedPosNumber: number | null = null;
	let isValidated = false;
	let errorMessage = '';
	let isStarting = false;
	
	// ERP Counter Details state
	let erpCounterDetails: any = null;
	let erpBranchId: number | null = null;
	let loadingCounterDetails = false;
	let counterDetailsError = '';
	let counterDetailsWarning = '';
	
	// Recharge card fields
	let rechargeStartDate: string = '';
	let rechargeStartHour = '12';
	let rechargeStartMinute = '00';
	let rechargeStartAmPm = 'AM';
	let rechargeOpeningBalance: number = 0;
	
	// Track original values after validation to detect changes
	let originalCashierCode = '';
	let originalSupervisorCode = '';
	let originalRealCounts: Record<string, number> = {};
	let hasChangesDetected = false;
	let changeCounter = 0;

	function hasChangesAfterValidation(): boolean {
		if (!isValidated) return false;
		
		// Check if access codes changed
		if (cashierAccessCode !== originalCashierCode || supervisorAccessCode !== originalSupervisorCode) {
			return true;
		}
		
		// Check if any real counts changed
		for (const key of Object.keys(denomValues)) {
			const currentCount = Number(realCounts[key]) || 0;
			const originalCount = originalRealCounts[key] || 0;
			if (currentCount !== originalCount) {
				return true;
			}
		}
		
		return false;
	}

	// Reactive statement to track changes - use changeCounter as dependency
	$: if (changeCounter >= 0) {
		hasChangesDetected = hasChangesAfterValidation();
		// Reset validation state if changes are detected
		if (hasChangesDetected) {
			isValidated = false;
			errorMessage = '';
		}
	}

	function calculateRealTotal(): number {
		let total = 0;
		for (const key of Object.keys(denomValues)) {
			const count = Number(realCounts[key]) || 0;
			const denomValue = denomValues[key] || 0;
			total = addMoney(total, multiplyMoney(denomValue, count));
		}
		console.log('Calculated total:', total, 'from counts:', realCounts);
		return total;
	}

	// Explicitly track realCounts changes
	$: if (realCounts) {
		displayTotal = calculateRealTotal();
	}

	$: if (box && displayTotal !== undefined) {
		const boxTotal = Number(box.total) || 0;
		// Use Math.abs for floating point comparison tolerance (0.01 = 1 cent)
		matchStatus = Math.abs(displayTotal - boxTotal) < 0.01 ? 'match' : 'mismatch';
	}

	// Compare ERP's opening cash (entered when the counter was opened) against the
	// cashier's entered denomination total — UI-only, not saved anywhere.
	let openingCashMatchStatus: 'match' | 'mismatch' | null = null;
	$: if (erpCounterDetails && displayTotal !== undefined) {
		const openingCash = Number(erpCounterDetails.OpenCashPhysical) || 0;
		openingCashMatchStatus = Math.abs(displayTotal - openingCash) < 0.01 ? 'match' : 'mismatch';
	} else {
		openingCashMatchStatus = null;
	}

	$: isCountReadonly = false;

	function checkDenominationMatch(denomKey: string): 'match' | 'mismatch' | null {
		if (!isValidated || !box) return null;
		
		const realCount = realCounts[denomKey] || 0;
		let expectedCount = 0;
		
		try {
			const boxCounts = typeof box.counts === 'string' ? JSON.parse(box.counts) : box.counts;
			expectedCount = boxCounts[denomKey] || 0;
		} catch (e) {
			console.error('Error parsing box counts:', e);
		}

		return realCount === expectedCount ? 'match' : 'mismatch';
	}

	// Format OpenTime (stored as 1900-01-01 + time) with TransactionDate in 12-hour format
	function formatOpenDateTime(transactionDate: string, openTime: string): string {
		try {
			if (!transactionDate || !openTime) return '-';
			
			// Extract time from openTime (e.g., "1900-01-01T20:19:05.530Z" -> "20:19:05")
			const timeMatch = openTime.match(/T(\d{2}):(\d{2}):(\d{2})/);
			if (!timeMatch) return '-';
			
			let hours = parseInt(timeMatch[1]);
			const minutes = timeMatch[2];
			const seconds = timeMatch[3];
			const ampm = hours >= 12 ? 'PM' : 'AM';
			
			// Convert to 12-hour format
			if (hours > 12) {
				hours = hours - 12;
			} else if (hours === 0) {
				hours = 12;
			}
			
			const timeStr = `${hours}:${minutes}:${seconds} ${ampm}`;
			
			// Extract date from transactionDate (e.g., "2026-09-02T00:00:00.000Z" -> "2026-09-02")
			const dateMatch = transactionDate.match(/(\d{4}-\d{2}-\d{2})/);
			if (!dateMatch) return '-';
			
			const dateStr = dateMatch[1]; // "2026-09-02"
			
			// Combine: "2026-09-02 8:19:05 PM"
			return `${dateStr} ${timeStr}`;
		} catch (e) {
			return '-';
		}
	}

	async function verifyCashierAccessCode() {
		if (!cashierAccessCode) {
			cashierCodeValid = false;
			cashierName = '';
			return;
		}

		try {
			// Use RPC for bcrypt hash verification
			const { data: verifyResult, error } = await supabase.rpc('verify_quick_access_code', {
				p_code: cashierAccessCode
			});

			if (error) throw error;

			if (verifyResult && verifyResult.success && verifyResult.user) {
				// Ensure the verified code belongs to the logged-in user
				if (verifyResult.user.id === user.id) {
					cashierCodeValid = true;
					cashierName = await getEmployeeDisplayName(verifyResult.user.id, $currentLocale, verifyResult.user.username || '');
				} else {
					cashierCodeValid = false;
					cashierName = '';
					errorMessage = $currentLocale === 'ar' ? 'رمز الدخول لا يتطابق مع المستخدم المسجل' : 'Access code does not match logged user';
				}
			} else {
				cashierCodeValid = false;
				cashierName = '';
				errorMessage = $currentLocale === 'ar' ? 'رمز الدخول لا يتطابق مع المستخدم المسجل' : 'Access code does not match logged user';
			}
		} catch (error) {
			console.error('Error verifying cashier access code:', error);
			cashierCodeValid = false;
			cashierName = '';
		}
	}

	async function lookupSupervisorAccessCode() {
		if (!supervisorAccessCode) {
			supervisorName = '';
			supervisorUserId = null;
			return;
		}

		try {
			// Use RPC for bcrypt hash verification
			const { data: verifyResult, error } = await supabase.rpc('verify_quick_access_code', {
				p_code: supervisorAccessCode
			});

			if (error) throw error;

			if (verifyResult && verifyResult.success && verifyResult.user) {
				// Reject the cashier's own code as the supervisor code — the whole point of this
				// second sign-off is an independent second person confirming the counted cash,
				// so the same person can't approve their own count.
				if (verifyResult.user.id === user.id) {
					supervisorName = '';
					supervisorUserId = null;
					errorMessage = $currentLocale === 'ar'
						? 'يجب أن يكون رمز المشرف مختلفًا عن رمز الموظف'
						: 'Supervisor code must belong to a different person than the cashier';
					return;
				}
				supervisorName = await getEmployeeDisplayName(verifyResult.user.id, $currentLocale, verifyResult.user.username || '');
				supervisorUserId = verifyResult.user.id;
			} else {
				supervisorName = '';
				supervisorUserId = null;
				errorMessage = $currentLocale === 'ar' ? 'الرجاء إدخال رمز الدخول الصحيح' : 'Please enter correct access code';
			}
		} catch (error) {
			console.error('Error looking up supervisor:', error);
			supervisorName = '';
			supervisorUserId = null;
			errorMessage = $currentLocale === 'ar' ? 'الرجاء إدخال رمز الدخول الصحيح' : 'Please enter correct access code';
		}
	}

	async function validateAccessCodes() {
		errorMessage = '';
		await verifyCashierAccessCode();
		await lookupSupervisorAccessCode();

		if (!cashierCodeValid) {
			errorMessage = $currentLocale === 'ar' ? 'رمز الوصول الخاص بالموظف غير صحيح' : 'Cashier access code is incorrect';
			return;
		}

		if (!supervisorName) {
			// lookupSupervisorAccessCode already set a more specific message when the code
			// belongs to the cashier themselves — don't clobber it with the generic one.
			if (!errorMessage) {
				errorMessage = $currentLocale === 'ar' ? 'رمز الوصول الخاص بالمشرف غير صحيح' : 'Supervisor access code is incorrect';
			}
			return;
		}

		// Belt-and-suspenders: lookupSupervisorAccessCode already blocks this, but guard here too
		// in case validateAccessCodes is ever invoked without going through it first.
		if (supervisorUserId && supervisorUserId === user.id) {
			supervisorName = '';
			errorMessage = $currentLocale === 'ar'
				? 'يجب أن يكون رمز المشرف مختلفًا عن رمز الموظف'
				: 'Supervisor code must belong to a different person than the cashier';
			return;
		}

		// Validation passed - allow start even if denominations don't match
		isValidated = true;
		errorMessage = '';
		
		// Store the validated values to detect changes later
		originalCashierCode = cashierAccessCode;
		originalSupervisorCode = supervisorAccessCode;
		originalRealCounts = {};
		for (const key of Object.keys(realCounts)) {
			originalRealCounts[key] = Number(realCounts[key]) || 0;
		}
		
		// Reset the change counter so button shows as validated
		changeCounter = 0;
	}

	async function fetchCounterDetails() {
		loadingCounterDetails = true;
		counterDetailsError = '';
		
		try {
			// Get user's ERP credentials from user_erp_credentials table
			const { data: credData, error: credError } = await supabase
				.from('user_erp_credentials')
				.select('erp_username, erp_user_id, erp_password, erp_branch_id, aqura_branch_id')
				.eq('user_id', user.id)
				.eq('aqura_branch_id', branch.id)
				.single();
			
			if (credError || !credData) {
				throw new Error($currentLocale === 'ar' 
					? 'لم يتم العثور على بيانات اعتماد ERP' 
					: 'ERP credentials not found');
			}
			
			const { erp_username, erp_user_id, erp_branch_id, aqura_branch_id } = credData;
			const erpUser = erp_username || erp_user_id;
			
			if (!erpUser || !erp_branch_id) {
				throw new Error($currentLocale === 'ar' 
					? 'بيانات اعتماد ERP غير كاملة' 
					: 'ERP credentials incomplete');
			}
			
			// Map aqura_branch_id to tunnel URL
			const tunnelUrlMap: Record<number, string> = {
				1: 'https://erp-branch1.urbanaqura.com',
				2: 'https://erp-branch2.urbanaqura.com',
				3: 'https://erp-branch3.urbanaqura.com'
			};
			
			let tunnelUrl = tunnelUrlMap[aqura_branch_id];
			
			// For local branch (branch 4), we can't use tunnel - would need different handling
			if (!tunnelUrl) {
				throw new Error($currentLocale === 'ar' 
					? 'لا يمكن الاتصال بـ ERP لهذا الفرع' 
					: 'Cannot connect to ERP for this branch');
			}
			
			// Query ERP for current open shifts opened BY THIS USER
			const erpUserId = parseInt(erp_user_id, 10);
			if (!erpUserId) {
				throw new Error($currentLocale === 'ar' 
					? 'معرّف مستخدم ERP غير صالح' 
					: 'Invalid ERP user ID');
			}
			
			const sql = `
				SELECT TOP 10
					cs.CounterID,
					cs.CounterShiftID,
					cs.ShiftName,
					cs.TransactionDate,
					cs.OpenTime,
					cs.OpenCloseStatus,
					cs.OpenCashPhysical,
					cs.OpeningCashBySystem,
					c.CounterName
				FROM CounterShift cs
				LEFT JOIN Counter c ON cs.CounterID = c.CounterID AND cs.BranchID = c.BranchID
				WHERE cs.BranchID = ${erp_branch_id}
				  AND cs.OpenCloseStatus = 'O'
				  AND cs.OpenUserID = ${erpUserId}
				ORDER BY cs.TransactionDate DESC, cs.OpenTime DESC
			`;
			
			console.log('ERP Query:', sql);
			console.log('Tunnel URL:', tunnelUrl);
			console.log('Branch ID:', erp_branch_id);
			
			const response = await fetch(`${tunnelUrl}/query`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					'x-api-secret': 'aqura-erp-bridge-2026'
				},
				body: JSON.stringify({ sql })
			});
			
			console.log('Response status:', response.status);
			
			if (!response.ok) {
				const errorText = await response.text();
				console.log('Error response:', errorText);
				throw new Error(`ERP query failed: ${response.status} - ${errorText}`);
			}
			
			const result = await response.json();
			console.log('ERP Result:', result);
			
			// ERP returns results in recordset array
			const records = result.recordset || result || [];
			
			// Filter to only include actual POS counters (POS-1, POS-2, etc.), not "MAIN OFFICE", "ACCOUNTS", etc.
			// Note: Results are already filtered by user's OpenUserID in SQL, but we filter by name for safety
			const posRecords = records.filter((r: any) => r.CounterName && r.CounterName.startsWith('POS-'));
			
			if (posRecords && posRecords[0]) {
				erpCounterDetails = posRecords[0];
				erpBranchId = erp_branch_id;
				// Extract POS number from CounterName (e.g., "POS-2" → 2)
				const posNumberMatch = erpCounterDetails.CounterName.match(/\d+/);
				selectedPosNumber = posNumberMatch ? parseInt(posNumberMatch[0], 10) : erpCounterDetails.CounterID;
				counterDetailsError = '';
				
				// Check if user has multiple open POS counters (should only happen if they opened multiple)
				if (posRecords.length > 1) {
					counterDetailsWarning = $currentLocale === 'ar'
						? `⚠️ تحذير: لديك ${posRecords.length} نقاط بيع مفتوحة. أغلق الأخرى للمتابعة.`
						: `⚠️ Warning: You have ${posRecords.length} open POS counters. Close the others to proceed.`;
				} else {
					counterDetailsWarning = '';
				}
			} else if (records.length > 0) {
				// User has open counters but none are POS (shouldn't happen in normal operation)
				counterDetailsError = $currentLocale === 'ar'
					? 'لا توجد نقطة بيع مفتوحة (قد تكون لديك عداد إداري فقط)'
					: 'No POS counter open (you may only have administrative counters)';
				counterDetailsWarning = '';
				erpCounterDetails = null;
			} else {
				counterDetailsError = $currentLocale === 'ar'
					? 'لا توجد نقطة بيع مفتوحة للمستخدم الحالي'
					: 'No open POS counter found for you';
				counterDetailsWarning = '';
				erpCounterDetails = null;
			}
		} catch (error) {
			console.error('Error fetching counter details:', error);
			counterDetailsError = error instanceof Error 
				? error.message 
				: ($currentLocale === 'ar' ? 'حدث خطأ في جلب التفاصيل' : 'Error fetching counter details');
			erpCounterDetails = null;
		} finally {
			loadingCounterDetails = false;
		}
	}

	let saveTimeout: NodeJS.Timeout;
	let draftOperationId: string | null = null;

	// ERP counter/shift columns to attach to a box_operations row, derived from the
	// counter details fetched via "Get My Counter Details" (null fields if not fetched yet).
	function buildErpColumns() {
		// OpenTime comes back as "1900-01-01T20:19:05.530Z" (dummy date, real time) —
		// the erp_shift_start_time column is `time`, so extract just the HH:MM:SS(.sss) part.
		let shiftStartTime: string | null = null;
		if (erpCounterDetails?.OpenTime) {
			const match = String(erpCounterDetails.OpenTime).match(/T(\d{2}:\d{2}:\d{2}(?:\.\d+)?)/);
			shiftStartTime = match ? match[1] : null;
		}
		return {
			erp_counter_id: erpCounterDetails?.CounterID ?? null,
			erp_counter_shift_id: erpCounterDetails?.CounterShiftID ?? null,
			erp_counter_name: erpCounterDetails?.CounterName ?? null,
			erp_shift_name: erpCounterDetails?.ShiftName ?? null,
			erp_shift_start_date: erpCounterDetails?.TransactionDate ?? null,
			erp_shift_start_time: shiftStartTime,
			erp_opening_cash_physical: erpCounterDetails?.OpenCashPhysical ?? null,
			erp_opening_cash_system: erpCounterDetails?.OpeningCashBySystem ?? null,
			erp_branch_id: erpBranchId
		};
	}
	
	async function saveDenominationCounts() {
		clearTimeout(saveTimeout);
		
		// Debounce saves - wait 1 second after last change before saving
		saveTimeout = setTimeout(async () => {
			try {
				const countsToSave: Record<string, number> = {};
				for (const key of Object.keys(realCounts)) {
					countsToSave[key] = Number(realCounts[key]) || 0;
				}
				
				// Build closing details with recharge card info
				const closingData = {
					counts_after: countsToSave,
					total_after: displayTotal,
					difference: subtractMoney(displayTotal, box.total),
					is_matched: Math.abs(displayTotal - Number(box.total)) < 0.01,
					// Recharge card details
					recharge_transaction_start_date: rechargeStartDate,
					recharge_transaction_start_time: `${rechargeStartHour}:${rechargeStartMinute} ${rechargeStartAmPm}`,
					recharge_opening_balance: money(rechargeOpeningBalance)
				};
				
				let error;
				
				// If we already have a draft ID, update it
				if (draftOperationId) {
					const result = await supabase
						.from('box_operations')
						.update({ closing_details: closingData, ...buildErpColumns() })
						.eq('id', draftOperationId);
					error = result.error;
				} else {
					// Otherwise create a new draft record
					const result = await supabase
						.from('box_operations')
						.insert([{
							box_number: box.number,
							branch_id: branch.id,
							user_id: user.id,
							denomination_record_id: box.id,
							counts_before: box.counts,
							counts_after: countsToSave,
							total_before: box.total,
							total_after: displayTotal,
							difference: subtractMoney(displayTotal, box.total),
							is_matched: Math.abs(displayTotal - Number(box.total)) < 0.01,
							status: 'draft',
							start_time: new Date().toISOString(),
							closing_details: closingData,
							...buildErpColumns()
						}])
						.select('id');
					
					if (result.data && result.data[0]) {
						draftOperationId = result.data[0].id;
					}
					error = result.error;
				}
				
				if (error) console.error('Error saving closing details:', error);
			} catch (error) {
				console.error('Error saving closing details:', error);
			}
		}, 1000);
	}

	async function loadDenominationCounts() {
		try {
			// First, load counts from denomination_records
			const { data: denomData, error: denomError } = await supabase
				.from('denomination_records')
				.select('counts')
				.eq('id', box.id)
				.maybeSingle();
			
			if (denomData && denomData.counts) {
				const boxCounts = typeof denomData.counts === 'string' ? JSON.parse(denomData.counts) : denomData.counts;
				for (const key of Object.keys(realCounts)) {
					realCounts[key] = boxCounts[key] || 0;
				}
				realCounts = { ...realCounts };
			}
		} catch (error) {
			console.log('Error loading denomination counts:', error);
		}
	}

	async function loadSavedCounts() {
		try {
			const { data, error } = await supabase
				.from('box_operations')
				.select('id, counts_after')
				.eq('denomination_record_id', box.id)
				.eq('user_id', user.id)
				.eq('status', 'draft')
				.maybeSingle();
			
			if (data && data.counts_after) {
				draftOperationId = data.id;
				const savedCounts = typeof data.counts_after === 'string' ? JSON.parse(data.counts_after) : data.counts_after;
				for (const key of Object.keys(realCounts)) {
					realCounts[key] = savedCounts[key] || 0;
				}
				realCounts = { ...realCounts };
			}
		} catch (error) {
			console.log('No saved counts found, starting fresh');
		}
	}

	// Load saved counts on component mount
	import { onMount } from 'svelte';
	onMount(async () => {
		// First load denomination counts from denomination_records
		await loadDenominationCounts();
		
		// Then check if there's a saved draft in box_operations (will override if exists)
		await loadSavedCounts();
		
		// Set current date and time for recharge card section
		const now = new Date();
		
		// Set date in YYYY-MM-DD format
		const year = now.getFullYear();
		const month = String(now.getMonth() + 1).padStart(2, '0');
		const day = String(now.getDate()).padStart(2, '0');
		rechargeStartDate = `${year}-${month}-${day}`;
		
		// Set time in 12-hour format
		let hours = now.getHours();
		const minutes = now.getMinutes();
		
		if (hours === 0) {
			rechargeStartHour = '12';
			rechargeStartAmPm = 'AM';
		} else if (hours < 12) {
			rechargeStartHour = String(hours);
			rechargeStartAmPm = 'AM';
		} else if (hours === 12) {
			rechargeStartHour = '12';
			rechargeStartAmPm = 'PM';
		} else {
			rechargeStartHour = String(hours - 12);
			rechargeStartAmPm = 'PM';
		}
		
		rechargeStartMinute = String(minutes).padStart(2, '0');
	});

	async function startOperation() {
		if (!isValidated || !selectedPosNumber || isStarting) return;

		isStarting = true;

		try {
			const countsAfter: Record<string, number> = {};
			Object.keys(denomValues).forEach(key => {
				countsAfter[key] = realCounts[key] || 0;
			});

			const realTotal = calculateRealTotal();
			const difference = subtractMoney(realTotal, box.total);
			const isMatched = Math.abs(difference) < 0.01;

			// Build closing details with recharge card info
			const closingDetails = {
				counts_after: countsAfter,
				total_after: realTotal,
				difference: difference,
				is_matched: isMatched,
				// Recharge card details
				recharge_transaction_start_date: rechargeStartDate,
				recharge_transaction_start_time: `${rechargeStartHour}:${rechargeStartMinute} ${rechargeStartAmPm}`,
				recharge_opening_balance: money(rechargeOpeningBalance)
			};

			const { error } = await supabase
				.from('box_operations')
				.insert({
					box_number: box.number,
					branch_id: branch.id,
					user_id: user.id,
					denomination_record_id: box.id,
					counts_before: box.counts,
					counts_after: countsAfter,
					total_before: box.total,
					total_after: realTotal,
					difference: difference,
					is_matched: isMatched,
					status: 'in_use',
					start_time: new Date().toISOString(),
					closing_details: closingDetails,
					...buildErpColumns(),
					notes: JSON.stringify({
						cashier_name: cashierName,
						cashier_access_code: cashierAccessCode,
						supervisor_name: supervisorName,
						pos_number: selectedPosNumber
					})
				});

			if (error) throw error;

			// Delete draft record now that operation is complete
			if (draftOperationId) {
				await supabase
					.from('box_operations')
					.delete()
					.eq('id', draftOperationId);
			}

			windowManager.closeWindow(windowId);
		} catch (error) {
			console.error('Error starting operation:', error);
			errorMessage = $currentLocale === 'ar' ? 'حدث خطأ أثناء بدء العملية' : 'Error starting operation';
			isStarting = false;
		}
	}
</script>

<div class="counter-check-container">
	<div class="pos-number-section">
		<div class="access-code-group">
			<label>{t('pos.posNumber') || 'POS Number'}</label>
			<div class="pos-number-display">
				{#if selectedPosNumber}
					<span class="pos-value">POS {selectedPosNumber}</span>
					<span class="pos-hint">({$currentLocale === 'ar' ? 'من ERP' : 'Auto-populated from ERP'})</span>
				{:else}
					<span class="pos-placeholder">{$currentLocale === 'ar' ? 'انقر على "احصل على تفاصيل العداد"' : 'Click "Get My Counter Details" first'}</span>
				{/if}
			</div>
		</div>
	</div>

	<div class="main-content-grid">
		<!-- LEFT COLUMN: Denominations -->
		<div class="left-column">
			<div class="split-card">
				<div class="split-section">
					<div class="card-header-text">{t('pos.enterRealCount') || 'ENTER REAL COUNT'}</div>
					<div class="real-count-inputs">
						{#each Object.entries(denomLabels) as [key, label] (key)}
							<div class="denom-input-group">
								<div class="denom-header-row">
									<label>
										{#if label !== 'Coins'}
											<span>{label}</span>
											<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
										{:else}
											{$currentLocale === 'ar' ? 'عملات معدنية' : label}
										{/if}
									</label>
									<div class="denom-total-wrap">
										{#if realCounts[key] > 0}
											<div class="denom-total">
												<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
												{((realCounts[key] || 0) * denomValues[key]).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
											</div>
										{/if}
										{#if realCounts[key] > 0 && box && isValidated}
											{#if checkDenominationMatch(key) === 'match'}
												<span class="status-icon match">✓</span>
											{:else if checkDenominationMatch(key) === 'mismatch'}
												<span class="status-icon mismatch">✗</span>
											{/if}
										{/if}
									</div>
								</div>
								<div class="denom-input-wrapper">
									<div class="denom-stepper">
										<button type="button" class="stepper-btn minus" disabled={isCountReadonly} on:click={() => decrementDenomCount(key)} aria-label="Decrease">−</button>
										{#if key === 'coins'}
											<!-- Coins is an odd-value tally (not a fixed-denomination note count), so it
											     stays a typed field instead of the dropdown, but keeps the same +/− stepper. -->
											<input
												type="number"
												min="0"
												class="denom-select coins-input"
												readonly={isCountReadonly}
												value={realCounts[key] || ''}
												on:input={(e) => {
													if (isCountReadonly) return;
													const val = e.currentTarget.value;
													realCounts[key] = val === '' ? undefined : Number(val);
													commitRealCountChange();
												}}
											/>
										{:else}
											<div class="denom-dropdown-wrap">
												<button
													type="button"
													class="denom-select denom-dropdown-trigger"
													class:open={openDenomDropdown === key}
													bind:this={denomTriggerEls[key]}
													disabled={isCountReadonly}
													on:click={() => toggleDenomDropdown(key)}
													aria-haspopup="listbox"
													aria-expanded={openDenomDropdown === key}
												>
													<span>{realCounts[key] || 0}</span>
													<span class="dropdown-caret">▾</span>
												</button>
												{#if openDenomDropdown === key}
													<div class="denom-dropdown-backdrop" use:portal on:click={closeDenomDropdown}></div>
													<div
														class="denom-dropdown-panel"
														role="listbox"
														use:portal
														style="top:{denomDropdownPos.top}px; left:{denomDropdownPos.left}px;"
													>
														<div class="denom-dropdown-grid">
															{#each denomPageOptions(key, denomDropdownPage) as n}
																<button
																	type="button"
																	class="denom-dropdown-option"
																	class:selected={n === (realCounts[key] || 0)}
																	role="option"
																	aria-selected={n === (realCounts[key] || 0)}
																	on:click={() => selectDenomValue(key, n)}
																>{n}</button>
															{/each}
														</div>
														{#if denomPageCount(key) > 1}
															<div class="denom-dropdown-nav">
																<button
																	type="button"
																	class="denom-nav-btn"
																	disabled={denomDropdownPage === 0}
																	on:click={() => (denomDropdownPage = Math.max(0, denomDropdownPage - 1))}
																>◀ {$currentLocale === 'ar' ? 'رجوع' : 'Back'}</button>
																<span class="denom-nav-page">{denomDropdownPage + 1} / {denomPageCount(key)}</span>
																<button
																	type="button"
																	class="denom-nav-btn"
																	disabled={denomDropdownPage >= denomPageCount(key) - 1}
																	on:click={() => (denomDropdownPage = Math.min(denomPageCount(key) - 1, denomDropdownPage + 1))}
																>{$currentLocale === 'ar' ? 'التالي' : 'Next'} ▶</button>
															</div>
														{/if}
													</div>
												{/if}
											</div>
										{/if}
										<button type="button" class="stepper-btn plus" disabled={isCountReadonly} on:click={() => incrementDenomCount(key)} aria-label="Increase">+</button>
										{#if realCounts[key] > 0}
											<button type="button" class="stepper-btn clear" disabled={isCountReadonly} on:click={() => clearDenomCount(key)} aria-label="Clear">{$currentLocale === 'ar' ? 'مسح' : 'Clear'}</button>
										{/if}
									</div>
								</div>
							</div>
						{/each}
					</div>
				</div>
			</div>
		</div>

		<!-- RIGHT COLUMN: Stacked cards (POS Total → ERP Counter → Recharge & Access) -->
		<div class="right-column">
			<div class="right-column-grid">
				<!-- 1: Totals Card (POS Total) -->
				<div class="right-section-card center-card">
					<div class="split-card">
						<div class="split-section">
							<div class="card-header-text">{t('pos.totals') || 'POS TOTAL'}</div>
							<div class="total-match-status">
								<div class="status-row">
									<span class="label">{t('pos.realTotal') || 'Real Total'}:</span>
									<div class="amount">
										<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
										<span>{displayTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
									</div>
								</div>
								<div class="status-row">
									<span class="label">{t('pos.box') || 'Box'} {t('common.total') || 'Total'}:</span>
									<div class="amount">
										<img src={currencySymbolUrl} alt="SAR" class="currency-icon" />
										<span>{box.total.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
									</div>
								</div>
								{#if matchStatus === 'match'}
									<div class="match-indicator match">
										<span class="icon">✓</span>
										<span class="text">{t('pos.matched') || 'MATCHED'}</span>
									</div>
								{:else if matchStatus === 'mismatch'}
									<div class="match-indicator mismatch">
										<span class="icon">✗</span>
										<span class="text">{t('pos.notMatched') || 'NOT MATCHED'}</span>
										<div class="difference">
											{t('pos.difference') || 'Difference'}: 
											<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
											<span style="color: {displayTotal - box.total > 0 ? '#16a34a' : '#dc2626'};">
												{(displayTotal - box.total) > 0 ? '+' : ''}{(displayTotal - box.total).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
											</span>
										</div>
									</div>
								{/if}
							</div>
						</div>
					</div>
				</div>

				<!-- 2: ERP Counter Details Card -->
				<div class="right-section-card">
					<div class="split-card">
						<div class="split-section">
							<div class="card-header-text">{$currentLocale === 'ar' ? 'تفاصيل العداد' : 'ERP COUNTER'}</div>
							
							{#if erpCounterDetails}
								<div class="counter-details-display">
									<div class="detail-row">
										<span class="detail-label">{$currentLocale === 'ar' ? 'اسم:' : 'Name:'}</span>
										<span class="detail-value">{erpCounterDetails.CounterName || '-'}</span>
									</div>
									<div class="detail-row">
										<span class="detail-label">{$currentLocale === 'ar' ? 'الورديه:' : 'Shift:'}</span>
										<span class="detail-value">{erpCounterDetails.CounterShiftID}</span>
									</div>
									<div class="detail-row">
										<span class="detail-label">{$currentLocale === 'ar' ? 'الوقت:' : 'Time:'}</span>
										<span class="detail-value">{formatOpenDateTime(erpCounterDetails.TransactionDate, erpCounterDetails.OpenTime)}</span>
									</div>
									<div class="detail-row">
										<span class="detail-label">{$currentLocale === 'ar' ? 'النقدية الافتتاحية:' : 'Opening Cash:'}</span>
										<span class="detail-value">{Number(erpCounterDetails.OpenCashPhysical ?? 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
									</div>
								</div>
								{#if openingCashMatchStatus === 'match'}
									<div class="match-indicator match">
										<span class="icon">✓</span>
										<span class="text">{$currentLocale === 'ar' ? 'مطابق للنقدية الافتتاحية' : 'MATCHES OPENING CASH'}</span>
									</div>
								{:else if openingCashMatchStatus === 'mismatch'}
									<div class="match-indicator mismatch">
										<span class="icon">✗</span>
										<span class="text">{$currentLocale === 'ar' ? 'غير مطابق للنقدية الافتتاحية' : 'DOES NOT MATCH OPENING CASH'}</span>
										<div class="difference">
											{t('pos.difference') || 'Difference'}: 
											<img src={currencySymbolUrl} alt="SAR" class="currency-icon-small" />
											<span style="color: {displayTotal - Number(erpCounterDetails.OpenCashPhysical ?? 0) > 0 ? '#16a34a' : '#dc2626'};">
												{(displayTotal - Number(erpCounterDetails.OpenCashPhysical ?? 0)) > 0 ? '+' : ''}{(displayTotal - Number(erpCounterDetails.OpenCashPhysical ?? 0)).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
											</span>
										</div>
									</div>
								{/if}
								{#if counterDetailsWarning}
									<div class="counter-warning">
										<span class="warning-text">{counterDetailsWarning}</span>
									</div>
								{/if}
							{:else if counterDetailsError}
								<div class="counter-error">
									<span class="error-text">{counterDetailsError}</span>
								</div>
							{:else}
								<div class="counter-empty">
									<span class="empty-text">{$currentLocale === 'ar' ? 'اضغط الزر' : 'Click button'}</span>
								</div>
							{/if}
							
							<button 
								class="btn-get-details" 
								on:click={fetchCounterDetails}
								disabled={loadingCounterDetails}
							>
								{loadingCounterDetails 
									? ($currentLocale === 'ar' ? 'جاري...' : 'Loading...')
									: ($currentLocale === 'ar' ? 'احصل على' : 'Get Details')}
							</button>
						</div>
					</div>
				</div>

				<!-- 3: Recharge & Access Codes Card -->
				{#if erpCounterDetails}
				<div class="right-section-card">
					<div class="split-card">
						<div class="split-section">
							<div class="card-header-text">{$currentLocale === 'ar' ? 'الشحن والوصول' : 'RECHARGE & ACCESS'}</div>
							
							<!-- Recharge Grid -->
							<div class="recharge-grid">
								<div class="input-group">
									<label>{$currentLocale === 'ar' ? 'التاريخ' : 'Date'}</label>
									<input
										type="date"
										bind:value={rechargeStartDate}
										on:change={() => saveDenominationCounts()}
										class="recharge-input"
									/>
								</div>
								<div class="input-group">
									<label>{$currentLocale === 'ar' ? 'الوقت' : 'Time'}</label>
									<div class="time-inputs">
										<input
											type="number"
											min="1"
											max="12"
											bind:value={rechargeStartHour}
											on:change={() => saveDenominationCounts()}
											placeholder="HH"
											class="time-input"
										/>
										<span class="time-separator">:</span>
										<input
											type="number"
											min="0"
											max="59"
											bind:value={rechargeStartMinute}
											on:change={() => saveDenominationCounts()}
											placeholder="MM"
											class="time-input"
										/>
										<select bind:value={rechargeStartAmPm} on:change={() => saveDenominationCounts()} class="time-select">
											<option value="AM">AM</option>
											<option value="PM">PM</option>
										</select>
									</div>
								</div>
								<div class="input-group">
									<label>{$currentLocale === 'ar' ? 'الرصيد' : 'Balance'}</label>
									<input
										type="number"
										min="0"
										step="0.01"
										bind:value={rechargeOpeningBalance}
										on:input={() => saveDenominationCounts()}
										placeholder="0.00"
										class="recharge-input"
									/>
								</div>
							</div>

							<!-- Access Codes -->
							<div class="access-codes-grid">
								<div class="access-code-row">
									<div class="access-code-group">
										<label>{t('pos.cashierAccessCode') || 'Cashier'}</label>
										<div class="digit-row">
											{#each cashierCodeDigits as digit, i}
												<input
													id="cashier-code-{i}"
													type="text"
													inputmode="numeric"
													pattern="[0-9]*"
													maxlength="1"
													class="digit-box"
													bind:value={cashierCodeDigits[i]}
													on:input={(e) => handleAccessCodeDigitInput(e, i, cashierCodeDigits, 'cashier')}
													on:keydown={(e) => handleAccessCodeDigitKeydown(e, i, cashierCodeDigits, 'cashier')}
													on:paste={(e) => handleAccessCodeDigitPaste(e, cashierCodeDigits, 'cashier')}
												/>
											{/each}
										</div>
									</div>
									{#if cashierCodeValid && cashierName}
										<div class="verified-name-display-inline">✓ {cashierName}</div>
									{/if}
								</div>

								<div class="access-code-row">
									<div class="access-code-group">
										<label>{t('pos.supervisorAccessCode') || 'Supervisor'}</label>
										<div class="digit-row">
											{#each supervisorCodeDigits as digit, i}
												<input
													id="supervisor-code-{i}"
													type="text"
													inputmode="numeric"
													pattern="[0-9]*"
													maxlength="1"
													class="digit-box"
													bind:value={supervisorCodeDigits[i]}
													on:input={(e) => handleAccessCodeDigitInput(e, i, supervisorCodeDigits, 'supervisor')}
													on:keydown={(e) => handleAccessCodeDigitKeydown(e, i, supervisorCodeDigits, 'supervisor')}
													on:paste={(e) => handleAccessCodeDigitPaste(e, supervisorCodeDigits, 'supervisor')}
												/>
											{/each}
										</div>
									</div>
									{#if supervisorName}
										<div class="verified-name-display-inline">✓ {supervisorName}</div>
									{/if}
								</div>
							</div>
						</div>
					</div>
				</div>
				{/if}
			</div>
		</div>
	</div>

	<div class="modal-footer">
		<button class="btn-validate" on:click={validateAccessCodes} disabled={!erpCounterDetails || (isValidated && !hasChangesDetected)}>
			{isValidated && !hasChangesDetected ? ($currentLocale === 'ar' ? '✓ تم التحقق' : '✓ Validated') : ($currentLocale === 'ar' ? 'التحقق' : 'Validate')}
		</button>
		<button class="btn-primary" on:click={startOperation} disabled={isStarting || !isValidated}>
			{isStarting ? (t('common.starting') || 'Starting...') : (t('common.start') || 'Start')}
		</button>
	</div>
</div>

{#if errorMessage}
	<div class="error-overlay">
		<div class="error-popup">
			<div class="error-header">
				<span class="error-icon">⚠️</span>
				<h3>Error</h3>
			</div>
			<p class="error-text">{errorMessage}</p>
			<button class="btn-close-error" on:click={() => errorMessage = ''}>Close</button>
		</div>
	</div>
{/if}

<style>
	.counter-check-container {
		width: 100%;
		height: 100%;
		background: white;
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		overflow-y: auto;
	}

	.pos-number-section {
		margin-bottom: 0.5rem;
	}

	.access-code-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.access-code-group label {
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.pos-number-select {
		padding: 0.5rem;
		border: 2px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
	}

	.pos-number-display {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		padding: 0.75rem;
		background-color: #f3f4f6;
		border: 2px solid #e5e7eb;
		border-radius: 0.375rem;
		font-size: 0.875rem;
	}

	.pos-value {
		font-weight: 600;
		color: #1f2937;
	}

	.pos-hint {
		font-size: 0.75rem;
		color: #6b7280;
		font-style: italic;
	}

	.pos-placeholder {
		color: #9ca3af;
		font-style: italic;
	}

	.two-cards-row {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
		margin-bottom: 0.5rem;
	}

	.main-content-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
		margin-bottom: 0.5rem;
		align-items: start;
	}

	.left-column {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.right-column {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.right-column-grid {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.right-section-card {
		display: flex;
		flex-direction: column;
	}

	.right-section-card.center-card {
		/* Emphasize the center card */
		box-shadow: 0 0 0 2px #15803d20;
	}

	.split-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
	}

	.split-section {
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.card-header-text {
		font-size: 0.75rem;
		font-weight: 700;
		color: #15803d;
		margin-bottom: 0.5rem;
		letter-spacing: 1px;
	}

	.section {
		background: white;
		border-radius: 0.5rem;
	}

	.section h3 {
		font-size: 0.75rem;
		font-weight: 700;
		color: #15803d;
		margin-bottom: 0.75rem;
		letter-spacing: 1px;
	}

	.real-count-inputs {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.5rem;
	}

	@media (max-width: 640px) {
		.real-count-inputs {
			grid-template-columns: 1fr;
		}

		.denom-select {
			width: 6rem;
		}

		.stepper-btn {
			width: 3.2rem;
		}
	}

	.denom-input-group {
		display: flex;
		flex-direction: column;
		align-items: stretch;
		gap: 0.3rem;
		border: 2px solid #e5e7eb;
		border-radius: 0.5rem;
		padding: 0.4rem 0.5rem;
		background: #fafafa;
	}

	.denom-header-row {
		display: flex;
		flex-direction: row;
		align-items: center;
		justify-content: space-between;
		gap: 0.4rem;
	}

	.denom-total-wrap {
		display: flex;
		align-items: center;
		gap: 0.35rem;
	}

	.denom-total {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.85rem;
		font-weight: 800;
		color: #059669;
		white-space: nowrap;
		flex-shrink: 0;
	}

	.denom-input-wrapper {
		flex: 1;
		display: flex;
		flex-direction: row;
		flex-wrap: nowrap;
		align-items: center;
		gap: 0.4rem;
		min-width: 0;
	}

	.denom-stepper {
		flex: 0 0 auto;
		display: flex;
		align-items: stretch;
		gap: 0.15rem;
		width: 100%;
	}

	.stepper-btn {
		flex-shrink: 0;
		width: 2.9rem;
		height: 2.75rem;
		box-sizing: border-box;
		display: flex;
		align-items: center;
		justify-content: center;
		border: 2px solid #d1fae5;
		border-radius: 0.375rem;
		background: white;
		color: #166534;
		font-size: 1.2rem;
		font-weight: 800;
		line-height: 1;
		cursor: pointer;
		transition: all 0.15s;
	}

	.stepper-btn:active {
		transform: scale(0.92);
	}

	.stepper-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.stepper-btn.minus {
		background: #dc2626;
		border-color: #dc2626;
		color: white;
	}

	.stepper-btn.minus:hover {
		background: #b91c1c;
		border-color: #b91c1c;
	}

	.stepper-btn.plus {
		background: #16a34a;
		border-color: #16a34a;
		color: white;
	}

	.stepper-btn.plus:hover {
		background: #15803d;
		border-color: #15803d;
	}

	.stepper-btn.clear {
		width: auto;
		padding: 0 0.8rem;
		font-size: 0.85rem;
		font-weight: 800;
		background: #eab308;
		border-color: #eab308;
		color: #422006;
	}

	.stepper-btn.clear:hover {
		background: #ca8a04;
		border-color: #ca8a04;
	}

	.denom-select {
		flex: 1 1 auto;
		width: 5.2rem;
		height: 2.75rem;
		box-sizing: border-box;
		min-width: 0;
		padding: 0.3rem 0.4rem;
		border: 2px solid #d1fae5;
		border-radius: 0.375rem;
		font-size: 1rem;
		background: white;
		font-weight: 700;
		color: #166534;
		box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(34, 197, 94, 0.1);
		transition: all 0.2s;
		text-align: center;
	}

	.denom-select:focus {
		outline: none;
		border-color: #22c55e;
		box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.2), 0 4px 6px rgba(34, 197, 94, 0.15);
	}

	.denom-select:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.denom-dropdown-wrap {
		position: relative;
		flex: 1;
		min-width: 0;
	}

	.denom-dropdown-trigger {
		display: flex;
		align-items: center;
		justify-content: space-between;
		width: 100%;
		cursor: pointer;
	}

	.denom-dropdown-trigger:focus,
	.denom-dropdown-trigger.open {
		outline: none;
		border-color: #22c55e;
		box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.2), 0 4px 6px rgba(34, 197, 94, 0.15);
	}

	.dropdown-caret {
		font-size: 0.75rem;
		margin-left: 0.2rem;
		color: #4b9d6e;
		transition: transform 0.15s;
	}

	.denom-dropdown-trigger.open .dropdown-caret {
		transform: rotate(180deg);
	}

	.denom-dropdown-backdrop {
		position: fixed;
		inset: 0;
		z-index: 999998;
		background: transparent;
	}

	.denom-dropdown-panel {
		position: fixed;
		transform: translateX(-50%);
		z-index: 999999;
		width: 13rem;
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
		padding: 0.5rem;
		background: white;
		border: 2px solid #bbf7d0;
		border-radius: 0.75rem;
		box-shadow: 0 12px 28px rgba(0, 0, 0, 0.18);
	}

	.denom-dropdown-grid {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 0.3rem;
	}

	.denom-dropdown-nav {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.3rem;
		padding-top: 0.35rem;
		border-top: 1px solid #e5e7eb;
	}

	.denom-nav-btn {
		flex: 1;
		min-height: 2.2rem;
		border: 1px solid #bbf7d0;
		border-radius: 0.5rem;
		background: #f0fdf4;
		color: #166534;
		font-size: 0.8rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.12s;
	}

	.denom-nav-btn:hover:not(:disabled) {
		background: #dcfce7;
		border-color: #22c55e;
	}

	.denom-nav-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.denom-nav-page {
		flex-shrink: 0;
		font-size: 0.75rem;
		font-weight: 700;
		color: #64748b;
		white-space: nowrap;
	}

	.denom-dropdown-option {
		min-height: 2.6rem;
		display: flex;
		align-items: center;
		justify-content: center;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		background: #f8fafc;
		color: #166534;
		font-size: 0.95rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.12s;
	}

	.denom-dropdown-option:hover {
		background: #dcfce7;
		border-color: #22c55e;
	}

	.denom-dropdown-option:active {
		transform: scale(0.94);
	}

	.denom-dropdown-option.selected {
		background: #16a34a;
		border-color: #16a34a;
		color: white;
	}

	input.coins-input::-webkit-outer-spin-button,
	input.coins-input::-webkit-inner-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}

	input.coins-input {
		-moz-appearance: textfield;
		appearance: textfield;
	}

	.input-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.input-group label {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.75rem;
		font-weight: 700;
		color: #ea580c;
	}

	.currency-icon {
		width: 14px;
		height: 14px;
		object-fit: contain;
	}

	.status-icon {
		font-size: 1rem;
		font-weight: bold;
	}

	.status-icon.match {
		color: #16a34a;
	}

	.status-icon.mismatch {
		color: #dc2626;
	}

	.total-match-status {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.status-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.5rem;
		font-size: 0.875rem;
	}

	.status-row .label {
		font-weight: 600;
		color: #4b5563;
	}

	.status-row .amount {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-weight: 700;
		color: #1f2937;
	}

	.match-indicator {
		margin-top: 0.75rem;
		padding: 0.75rem;
		border-radius: 0.5rem;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-weight: 700;
	}

	.match-indicator.match {
		background: #dcfce7;
		color: #16a34a;
		border: 2px solid #86efac;
	}

	.match-indicator.mismatch {
		background: #fee2e2;
		color: #dc2626;
		border: 2px solid #fca5a5;
		flex-direction: column;
		align-items: flex-start;
	}

	.match-indicator .icon {
		font-size: 1.25rem;
	}

	.match-indicator .text {
		font-size: 0.875rem;
	}

	.difference {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.75rem;
		margin-top: 0.25rem;
	}

	.currency-icon-small {
		width: 12px;
		height: 12px;
	}

	.access-codes-section {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.5rem;
		padding: 0.75rem;
		background: linear-gradient(135deg, #fff7ed 0%, #ffedd5 100%);
		border-radius: 0.5rem;
		margin-top: 0.125rem;
		border: 2px solid #fed7aa;
		box-shadow: 0 4px 6px -1px rgba(249, 115, 22, 0.1), inset 0 2px 4px 0 rgba(255, 255, 255, 0.6);
	}

	.signature-header {
		grid-column: 1 / -1;
		font-size: 0.75rem;
		font-weight: 700;
		color: #15803d;
		letter-spacing: 1px;
		padding-bottom: 0.5rem;
		margin-bottom: 0.15rem;
		border-bottom: 1px solid #fed7aa;
	}

	.access-code-group {
		display: flex;
		flex-direction: column;
		/* Without this, the column's default stretch makes both the label and .digit-row (which is
		   forced direction:ltr so its own digits stay in typed order) fill the full width — the
		   label's text then sits at the RTL-natural right edge while the ltr-packed boxes sit at
		   the left, so they land nowhere near each other. Centering both, rather than pinning to a
		   side, keeps the box row directly under the label regardless of RTL/LTR. */
		align-items: center;
		gap: 0.15rem;
	}

	.access-code-group label {
		font-size: 0.75rem;
		font-weight: 700;
		color: #374151;
		letter-spacing: 0.5px;
		margin: 0;
	}

	.access-code-group input {
		width: 100%;
		padding: 0.3rem 0.4rem;
		border: 2px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
	}

	/* Cashier/Supervisor access codes are always exactly 6 digits — a row of individual boxes
	   (OTP-style, matching ChangeAccessCode.svelte's pattern) instead of one free-text field. The
	   extra specificity (input.digit-box) is needed to win over the generic .access-code-group
	   input rule above for width/padding/font-size. */
	.digit-row {
		display: flex;
		gap: 0.4rem;
		/* Keep digit order fixed left-to-right even in Arabic (RTL) — otherwise a plain flex row
		   visually reverses the boxes, so the first digit typed ends up on the right and the code
		   reads back to front. */
		direction: ltr;
	}

	.access-code-group input.digit-box {
		width: 2.4rem;
		height: 2.7rem;
		padding: 0;
		text-align: center;
		font-size: 1.15rem;
		font-weight: 700;
		border: 2px solid #fed7aa;
		border-radius: 0.5rem;
		color: #92400e;
		background: white;
		transition: all 0.2s;
	}

	.access-code-group input.digit-box:focus {
		outline: none;
		border-color: #ea580c;
		box-shadow: 0 0 0 3px rgba(234, 88, 12, 0.15);
	}

	.access-code-row {
		display: flex;
		align-items: flex-start;
		gap: 0.5rem;
		margin-bottom: 0.3rem;
	}

	.access-code-row .access-code-group {
		flex: 1;
	}

	.verified-name-display {
		margin-top: 0.25rem;
		padding: 0.25rem 0.5rem;
		background: #dcfce7;
		border: 1px solid #86efac;
		border-radius: 0.375rem;
		font-size: 0.75rem;
		color: #16a34a;
		font-weight: 600;
		text-align: center;
	}

	.verified-name-display-inline {
		font-size: 0.7rem;
		color: #16a34a;
		font-weight: 600;
		white-space: nowrap;
		padding-top: 0.3rem;
		padding-right: 0.25rem;
	}

	.pos-number-select {
		padding: 0.3rem 0.4rem;
		border: 2px solid #22c55e;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		color: #166534;
		background: white;
	}

	.modal-footer {
		display: flex;
		gap: 0.5rem;
		justify-content: flex-end;
		padding-top: 0.75rem;
		border-top: 1px solid #e5e7eb;
	}

	.counter-details-display {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-bottom: 0.75rem;
		padding: 0.75rem;
		background: #f9fafb;
		border-radius: 0.375rem;
		border: 1px solid #e5e7eb;
	}

	.detail-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.8rem;
	}

	.detail-label {
		font-weight: 600;
		color: #4b5563;
		flex-shrink: 0;
	}

	.detail-value {
		color: #1f2937;
		word-break: break-word;
		text-align: right;
	}

	.counter-error,
	.counter-empty {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.75rem;
		margin-bottom: 0.75rem;
		border-radius: 0.375rem;
		border: 1px solid #e5e7eb;
		min-height: 60px;
	}

	.counter-error {
		background: #fee2e2;
		border-color: #fca5a5;
	}

	.error-text {
		color: #dc2626;
		font-size: 0.8rem;
		font-weight: 500;
		text-align: center;
	}

	.counter-warning {
		background: #fef3c7;
		border: 1px solid #fcd34d;
		border-radius: 0.375rem;
		padding: 0.75rem;
		margin-top: 0.5rem;
	}

	.warning-text {
		color: #b45309;
		font-size: 0.8rem;
		font-weight: 500;
		text-align: center;
		display: block;
	}

	.counter-empty {
		background: #f0f9ff;
		border-color: #7dd3fc;
	}

	.empty-text {
		color: #0284c7;
		font-size: 0.8rem;
		text-align: center;
	}

	.btn-get-details {
		padding: 0.5rem 1rem;
		background: #2563eb;
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-weight: 600;
		cursor: pointer;
		font-size: 0.875rem;
		transition: background 0.2s ease;
	}

	.btn-get-details:hover:not(:disabled) {
		background: #1d4ed8;
	}

	.btn-get-details:disabled {
		background: #d1d5db;
		cursor: not-allowed;
	}

	.btn-validate,
	.btn-primary {
		padding: 0.5rem 1.5rem;
		border-radius: 0.375rem;
		font-weight: 600;
		cursor: pointer;
		border: none;
		font-size: 0.875rem;
	}

	.btn-validate {
		background: #10b981;
		color: white;
	}

	.btn-validate:disabled {
		background: #d1d5db;
		cursor: not-allowed;
	}

	.btn-primary {
		background: #3b82f6;
		color: white;
	}

	.btn-primary:disabled {
		background: #d1d5db;
		cursor: not-allowed;
	}

	.error-overlay {
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

	.error-popup {
		background: white;
		padding: 1.5rem;
		border-radius: 0.5rem;
		max-width: 400px;
		box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
	}

	.error-header {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}

	.error-icon {
		font-size: 1.5rem;
	}

	.error-text {
		margin-bottom: 1rem;
		color: #4b5563;
	}

	.btn-close-error {
		width: 100%;
		padding: 0.5rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-weight: 600;
		cursor: pointer;
	}

	.recharge-section {
		padding: 0.75rem;
		background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
		border-radius: 0.5rem;
		border: 2px solid #7dd3fc;
		margin-top: 0.5rem;
	}

	.section-header {
		font-size: 0.75rem;
		font-weight: 700;
		color: #15803d;
		letter-spacing: 1px;
		padding-bottom: 0.5rem;
		margin-bottom: 0.5rem;
		border-bottom: 1px solid #7dd3fc;
	}

	.recharge-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 0.5rem;
		margin-bottom: 1rem;
		padding-bottom: 1rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.access-codes-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
	}

	.recharge-input {
		width: 100%;
		padding: 0.3rem 0.4rem;
		border: 2px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
	}

	.time-inputs {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		width: 100%;
	}

	.time-input {
		width: 80px;
		padding: 0.3rem 0.4rem;
		border: 2px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		text-align: center;
		font-weight: 600;
	}

	.time-select {
		flex: 1;
		padding: 0.3rem 0.4rem;
		border: 2px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		background: white;
		cursor: pointer;
	}

	.time-separator {
		font-weight: bold;
		color: #4b5563;
		font-size: 0.875rem;
	}</style>
