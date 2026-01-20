<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { onMount, onDestroy, tick } from 'svelte';

	export let employee: any;
	export let windowId: string;
	export let initialStartDate: string = '';
	export let initialEndDate: string = '';

	interface Employee {
		id: string;
		name_en: string;
		name_ar: string;
		current_branch_id: string;
		branch_name_en?: string;
		branch_name_ar?: string;
		nationality_id: string;
		nationality_name_en?: string;
		nationality_name_ar?: string;
		employment_status: string;
		sponsorship_status?: string;
	}

	let regularShift: any = null;
	let dayOffWeekday: any = null;
	let dayOffDates: any[] = [];
	let specialShiftDateWise: any[] = [];
	let specialShiftWeekday: any[] = [];
	let isShiftOverlappingNextDay = false;
	let loading = true;
	let startDate = initialStartDate || new Date().toISOString().split('T')[0];
	let endDate = initialEndDate || new Date().toISOString().split('T')[0];
	let transactionData: any[] = [];
	let loadingTransactions = false;
	let punchPairs: any[] = []; // Store paired check-ins and check-outs with metadata
	let realtimeChannel: any = null;
	let showAddPunchModal = false;
	let modalData: any = null;
	let editPunchTime = '';
	let editPunchStatus = '';
	let editDeductionPercent: number | string = '';
	let savingPunch = false;
	let userCanAddPunches = false;
	let permissionDeniedMessage = '';
	let showPermissionDeniedPopup = false;
	let showSyncResultModal = false;
	let syncResultMessage = '';
	let syncResultType: 'success' | 'error' | 'info' = 'info';

	// 12-hour format state for punch time
	let punchHour12 = '12';
	let punchMinute = '00';
	let punchPeriod: 'AM' | 'PM' = 'AM';

	// Convert 12-hour to 24-hour format and update editPunchTime
	function updatePunchTime24h() {
		let h = parseInt(punchHour12);
		if (punchPeriod === 'PM' && h < 12) h += 12;
		if (punchPeriod === 'AM' && h === 12) h = 0;
		editPunchTime = `${String(h).padStart(2, '0')}:${punchMinute}`;
	}

	// Convert 24-hour time to 12-hour format state
	function syncPunchTimeTo12h() {
		if (!editPunchTime) return;
		const [hours, minutes] = editPunchTime.split(':').map(Number);
		punchPeriod = hours >= 12 ? 'PM' : 'AM';
		let h = hours % 12;
		if (h === 0) h = 12;
		punchHour12 = String(h).padStart(2, '0');
		punchMinute = String(minutes).padStart(2, '0');
	}

	// Reactive: sync when editPunchTime changes externally
	$: if (editPunchTime && showAddPunchModal) {
		syncPunchTimeTo12h();
	}

	async function loadEmployeeData() {
		try {
			// Load regular shift data
			const { data: shiftData } = await supabase
				.from('regular_shift')
				.select('*')
				.eq('id', employee.id)
				.maybeSingle();
			regularShift = shiftData;

			// Get shift overlap flag from the shift data
			if (shiftData?.is_shift_overlapping_next_day) {
				isShiftOverlappingNextDay = true;
			}

			// Load day off weekday data
			const { data: dayOffWData } = await supabase
				.from('day_off_weekday')
				.select('*')
				.eq('employee_id', employee.id);
			dayOffWeekday = dayOffWData && dayOffWData.length > 0 ? dayOffWData[0] : null;

			// Load day off dates
			const { data: dayOffDatesData } = await supabase
				.from('day_off')
				.select('*, day_off_reasons(*)')
				.eq('employee_id', employee.id);
			dayOffDates = dayOffDatesData || [];

			// Load special shift date-wise
			const { data: specialDateData } = await supabase
				.from('special_shift_date_wise')
				.select('*')
				.eq('employee_id', employee.id);
			specialShiftDateWise = specialDateData || [];

			// Check for shift overlap in special date-wise shifts
			if (specialDateData?.some(s => s.is_shift_overlapping_next_day)) {
				isShiftOverlappingNextDay = true;
			}

			// Load special shift weekday
			const { data: specialWeekdayData } = await supabase
				.from('special_shift_weekday')
				.select('*')
				.eq('employee_id', employee.id);
			specialShiftWeekday = specialWeekdayData || [];

			// Check for shift overlap in special weekday shifts
			if (specialWeekdayData?.some(s => s.is_shift_overlapping_next_day)) {
				isShiftOverlappingNextDay = true;
			}
		} catch (error) {
			console.error('Error loading employee data:', error);
		}
	}

	function setupRealtime() {
		if (realtimeChannel) {
			supabase.removeChannel(realtimeChannel);
		}

		realtimeChannel = supabase
			.channel('employee_analysis_changes')
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'regular_shift',
					filter: `id=eq.${employee.id}`
				},
				() => loadEmployeeData()
			)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'day_off_weekday',
					filter: `employee_id=eq.${employee.id}`
				},
				() => loadEmployeeData()
			)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'day_off',
					filter: `employee_id=eq.${employee.id}`
				},
				() => loadEmployeeData()
			)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'special_shift_date_wise',
					filter: `employee_id=eq.${employee.id}`
				},
				() => loadEmployeeData()
			)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'special_shift_weekday',
					filter: `employee_id=eq.${employee.id}`
				},
				() => loadEmployeeData()
			)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'processed_fingerprint_transactions',
					filter: `center_id=eq.${employee.id}`
				},
				() => loadTransactions()
			)
			.subscribe();
	}

	onMount(async () => {
		loading = true;
		await loadEmployeeData();
		await checkUserPunchPermissions();
		
		// If initial dates were provided, load transactions automatically and then sync
		if (initialStartDate && initialEndDate) {
			await loadTransactions();
			// Auto-sync after auto-load completes
			await updateTransactionStatuses();
		}
		
		loading = false;
		setupRealtime();
	});

	async function checkUserPunchPermissions() {
		try {
			const userId = $currentUser?.id;
			if (!userId) {
				userCanAddPunches = false;
				return;
			}

			const { data, error } = await supabase
				.from('approval_permissions')
				.select('can_add_missing_punches')
				.eq('user_id', userId)
				.maybeSingle();

			if (error) {
				console.warn('Error checking punch permissions:', error);
				userCanAddPunches = false;
				return;
			}

			userCanAddPunches = data?.can_add_missing_punches || false;
			console.log('✅ User can add missing punches:', userCanAddPunches);
		} catch (err) {
			console.error('Error checking permissions:', err);
			userCanAddPunches = false;
		}
	}

	onDestroy(() => {
		if (realtimeChannel) {
			supabase.removeChannel(realtimeChannel);
		}
	});

	function closeWindow() {
		windowManager.closeWindow(windowId);
	}

	function generatePunchId(): string {
		// Generate a unique ID for the punch
		const timestamp = Date.now().toString(36);
		const random = Math.random().toString(36).substring(2, 9);
		return `PF${timestamp}${random}`.toUpperCase();
	}

	function openAddPunchModal(pair: any, isMissingCheckIn: boolean) {
		console.log('openAddPunchModal called', { pair, isMissingCheckIn });
		
		// Check if user has permission to add missing punches
		if (!userCanAddPunches) {
			permissionDeniedMessage = "You don't have permission to add a punch.";
			showPermissionDeniedPopup = true;
			return;
		}
		
		// Determine the date for the punch - use whichever date is available
		let punchDate = pair.checkInDate || pair.checkOutDate;
		console.log('punchDate:', punchDate);
		if (!punchDate) {
			console.log('No punchDate, returning early');
			return; // Don't open modal if there's no date
		}
		
		// For missing checkout on overnight shifts, the checkout occurs on the NEXT day
		// Check if this is a missing checkout AND the shift is overnight
		const applicableShift = getApplicableShift(punchDate);
		if (!isMissingCheckIn && applicableShift) {
			const shiftEndMinutes = timeToMinutes(applicableShift.shift_end_time);
			const shiftStartMinutes = timeToMinutes(applicableShift.shift_start_time);
			const isOvernightShift = shiftEndMinutes < shiftStartMinutes;
			
			// For overnight shifts, checkout happens on the next calendar day
			if (isOvernightShift) {
				punchDate = getNextDate(punchDate);
				console.log('Overnight shift checkout - adjusted punchDate to:', punchDate);
			}
		}
		
		console.log('Final punchDate:', punchDate);
		const finalApplicableShift = getApplicableShift(punchDate);
		console.log('finalApplicableShift:', finalApplicableShift);
		console.log('regularShift:', regularShift);
		console.log('specialShiftDateWise:', specialShiftDateWise);
		console.log('specialShiftWeekday:', specialShiftWeekday);

		// Default punch time based on shift
		let defaultTime = '';
		let defaultStatus = '';

		if (isMissingCheckIn && finalApplicableShift) {
			// Default to shift start time for missing check-in
			defaultTime = finalApplicableShift.shift_start_time;
			defaultStatus = 'Check In';
		} else if (!isMissingCheckIn && finalApplicableShift) {
			// Default to shift end time for missing check-out
			defaultTime = finalApplicableShift.shift_end_time;
			defaultStatus = 'Check Out';
		}

		modalData = {
			pair,
			isMissingCheckIn,
			punchDate,
			applicableShift: finalApplicableShift
		};

		editPunchTime = defaultTime;
		editPunchStatus = defaultStatus;
		editDeductionPercent = '';
		console.log('Setting showAddPunchModal to true', { modalData, editPunchTime, editPunchStatus });
		showAddPunchModal = true;
		console.log('showAddPunchModal is now:', showAddPunchModal);
	}

	function closeAddPunchModal() {
		showAddPunchModal = false;
		modalData = null;
		editPunchTime = '';
		editPunchStatus = '';
		editDeductionPercent = '';
	}

	function calculateAdjustedPunchTime(baseTime: string, deductionPercent: number, isMissingCheckIn: boolean, shiftStart: string, shiftEnd: string): string {
		if (!deductionPercent || deductionPercent <= 0) return baseTime;

		const shiftStartMinutes = timeToMinutes(shiftStart);
		const shiftEndMinutes = timeToMinutes(shiftEnd);
		
		// Calculate assigned working hours in minutes
		let assignedMinutes = shiftEndMinutes - shiftStartMinutes;
		if (assignedMinutes < 0) assignedMinutes += 24 * 60; // Handle overnight shifts
		
		// Calculate deduction in minutes
		const deductionMinutes = Math.round((deductionPercent / 100) * assignedMinutes);
		
		// Get base punch time in minutes
		const basePunchMinutes = timeToMinutes(baseTime);
		
		let adjustedMinutes = basePunchMinutes;
		
		if (isMissingCheckIn) {
			// Check-in case: add the deduction as late (move check-in forward)
			adjustedMinutes += deductionMinutes;
		} else {
			// Check-out case: subtract the deduction as early leave (move check-out backward)
			adjustedMinutes -= deductionMinutes;
		}
		
		// Handle day wrapping
		if (adjustedMinutes < 0) adjustedMinutes += 24 * 60;
		if (adjustedMinutes >= 24 * 60) adjustedMinutes -= 24 * 60;
		
		// Convert back to HH:MM format
		const hours = Math.floor(adjustedMinutes / 60);
		const minutes = Math.round(adjustedMinutes % 60);
		return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
	}

	async function updateTransactionStatuses() {
		// Don't start sync if already loading
		if (loadingTransactions) {
			console.log('Load in progress, waiting...');
			// Wait for loading to complete
			while (loadingTransactions) {
				await new Promise(resolve => setTimeout(resolve, 100));
			}
		}
		
		// Update status for all transactions with null status in the loaded date range
		loadingTransactions = true;
		try {
			const extendedStartDate = new Date(startDate);
			extendedStartDate.setDate(extendedStartDate.getDate() - 1);
			const extendedStartDateStr = extendedStartDate.toISOString().split('T')[0];
			
			const extendedEndDate = new Date(endDate);
			extendedEndDate.setDate(extendedEndDate.getDate() + 1);
			const extendedEndDateStr = extendedEndDate.toISOString().split('T')[0];

			// Fetch ALL transactions in the date range (not just null status) so we can see pairing context
			const { data: allTransactions, error: fetchError } = await supabase
				.from('processed_fingerprint_transactions')
				.select('*')
				.eq('center_id', employee.id)
				.gte('punch_date', extendedStartDateStr)
				.lte('punch_date', extendedEndDateStr);

			if (fetchError) {
				console.error('Error fetching transactions:', fetchError);
				return;
			}

			if (!allTransactions || allTransactions.length === 0) {
				console.log('No transactions found in this date range');
				return;
			}
			
			// Filter to only transactions with null status that need updating
			const transactionsToUpdate = allTransactions.filter(txn => txn.status === null);
			
			if (transactionsToUpdate.length === 0) {
				console.log('No transactions with null status to update');
				return;
			}

			console.log(`Updating status for ${transactionsToUpdate.length} transactions (out of ${allTransactions.length} total)`);

			// Step 1: Classify only the null-status transactions by shift windows
			const classifiedTransactions = transactionsToUpdate.map(txn => {
				const calendarDate = formatDateddmmyyyy(txn.punch_date);
				const punchTime = txn.punch_time;
				const applicableShift = getApplicableShift(calendarDate);
				
				let status = 'Other';
				
				if (applicableShift) {
					const punchMinutes = timeToMinutes(punchTime);
					const shiftStartMinutes = timeToMinutes(applicableShift.shift_start_time);
					const shiftEndMinutes = timeToMinutes(applicableShift.shift_end_time);
					const startBufferMinutes = (applicableShift.shift_start_buffer || 0) * 60;
					const endBufferMinutes = (applicableShift.shift_end_buffer || 0) * 60;
					
					const checkInStart = shiftStartMinutes - startBufferMinutes;
					const checkInEnd = shiftStartMinutes + startBufferMinutes;
					const checkOutStart = shiftEndMinutes - endBufferMinutes;
					const checkOutEnd = shiftEndMinutes + endBufferMinutes;
					
					const isOvernightShift = shiftEndMinutes < shiftStartMinutes;
					
					if (isOvernightShift) {
						if (punchMinutes >= checkInStart && punchMinutes <= checkInEnd) {
							status = 'Check In';
						} else if (punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd) {
							status = 'Check Out';
						} else if (checkOutStart < 0) {
							const adjustedCheckOutStart = checkOutStart + (24 * 60);
							const adjustedCheckOutEnd = checkOutEnd + (24 * 60);
							if (punchMinutes >= 0 && punchMinutes <= adjustedCheckOutEnd) {
								status = 'Check Out';
							} else if (punchMinutes > checkInEnd && punchMinutes < adjustedCheckOutStart) {
								status = 'In Progress';
							} else {
								status = 'Other';
							}
						} else {
							status = 'Other';
						}
					} else {
						if (punchMinutes >= checkInStart && punchMinutes <= checkInEnd) {
							status = 'Check In';
						} else if (punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd) {
							status = 'Check Out';
						} else if (punchMinutes > checkInEnd && punchMinutes < checkOutStart) {
							status = 'In Progress';
						} else {
							status = 'Other';
						}
					}
				}
				
				return {
					...txn,
					calendarDate,
					initialStatus: status
				};
			});

			// Step 2: Group ALL transactions (including already-classified ones) by shift date for pairing context
			const groupedByShiftDate: { [key: string]: any[] } = {};
			
			// First add all classified transactions
			classifiedTransactions.forEach(txn => {
				if (!groupedByShiftDate[txn.calendarDate]) {
					groupedByShiftDate[txn.calendarDate] = [];
				}
				groupedByShiftDate[txn.calendarDate].push(txn);
			});
			
			// Then add all other transactions that already have status (for pairing context)
			allTransactions.forEach(txn => {
				if (txn.status !== null) { // Skip the ones we're updating
					const calendarDate = formatDateddmmyyyy(txn.punch_date);
					if (!groupedByShiftDate[calendarDate]) {
						groupedByShiftDate[calendarDate] = [];
					}
					groupedByShiftDate[calendarDate].push({
						...txn,
						calendarDate,
						initialStatus: txn.status // Use existing status
					});
				}
			});

			// Step 3: Apply pairing logic to reclassify "Other" punches
			Object.keys(groupedByShiftDate).forEach(shiftDate => {
				const shiftTransactions = groupedByShiftDate[shiftDate];
				const checkIns = shiftTransactions.filter(t => t.initialStatus === 'Check In');
				const checkOuts = shiftTransactions.filter(t => t.initialStatus === 'Check Out');
				// Only consider "Others" that we're updating (not already-classified ones)
				const others = classifiedTransactions.filter(t => t.calendarDate === shiftDate && (t.initialStatus === 'Other' || t.initialStatus === 'In Progress'));
				
				console.log(`[Pairing] ${shiftDate}: ${checkIns.length} Check Ins, ${checkOuts.length} Check Outs, ${others.length} Others to classify`);

				// Reclassify "Other" punches as check-outs if they're paired with check-ins
				let otherIdx = 0;
				checkIns.forEach((checkIn, idx) => {
					console.log(`[Pairing] Processing Check In ${idx}: needs checkout?`, idx >= checkOuts.length);
					if (idx < checkOuts.length) {
						// Already has a Check Out, no need to use Other
						console.log(`[Pairing]   → Already has Check Out at index ${idx}`);
						return;
					}
					// Use the next Other as Check Out
					if (otherIdx < others.length) {
						console.log(`[Pairing]   → Assigning Other ${others[otherIdx].id} as Check Out`);
						others[otherIdx].initialStatus = 'Check Out';
						console.log(`[Pairing]   → Reclassified ${others[otherIdx].id} from "Other" to "Check Out"`);
						otherIdx++;
					}
				});
			});

			// Step 4: Prepare updates with final classified status
			const updates = classifiedTransactions.map(txn => ({
				id: txn.id,
				status: txn.initialStatus
			}));
			
			console.log('[Final Updates]', updates.map(u => `${u.id}: ${u.status}`).join(', '));

			// Batch update the database
			for (const update of updates) {
				const { error: updateError } = await supabase
					.from('processed_fingerprint_transactions')
					.update({ status: update.status })
					.eq('id', update.id);

				if (updateError) {
					console.error('Error updating transaction:', updateError);
				}
			}

			console.log(`Successfully updated ${updates.length} transactions`);
			
			// Reload transactions to reflect the updates
			await loadTransactions();
		} catch (error) {
			console.error('Error updating transaction statuses:', error);
		} finally {
			loadingTransactions = false;
		}
	}

	async function savePunch() {
		if (!editPunchTime || !editPunchStatus || !modalData) return;

		savingPunch = true;
		try {
			// Prepare the data for insertion
			const newPunch = {
				id: generatePunchId(),
				center_id: employee.id,
				employee_id: employee.id,
				branch_id: employee.current_branch_id,
				punch_date: modalData.punchDate.split('-').reverse().join('-'), // Convert DD-MM-YYYY to YYYY-MM-DD
				punch_time: editPunchTime,
				status: editPunchStatus,
				processed_at: new Date().toISOString(),
				created_at: new Date().toISOString(),
				updated_at: new Date().toISOString()
			};

			// Insert into database
			const { error } = await supabase
				.from('processed_fingerprint_transactions')
				.insert([newPunch]);

			if (error) {
				console.error('Error saving punch:', error);
				alert($t('common.error') || 'Error' + ': ' + error.message);
			} else {
				// Close modal and reload transactions
				closeAddPunchModal();
				await loadTransactions();
			}
		} catch (error) {
			console.error('Error saving punch:', error);
			alert($t('common.error') || 'Error' + ': ' + (error as Error).message);
		} finally {
			savingPunch = false;
		}
	}

	function groupTransactionsByDate(transactions: any[]) {
		const grouped: { [date: string]: any[] } = {};
		
		// Create all dates in range
		const start = new Date(startDate);
		const end = new Date(endDate);
		
		// Initialize all dates with empty arrays
		for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
			const dateStr = formatDateddmmyyyy(d.toISOString().split('T')[0]);
			grouped[dateStr] = [];
		}
		
		// Add transactions to their respective dates
		transactions.forEach(txn => {
			const date = formatDateddmmyyyy(txn.punch_date);
			if (!grouped[date]) {
				grouped[date] = [];
			}
			grouped[date].push(txn);
		});
		
		return grouped;
	}

	function formatDateddmmyyyy(dateString: string): string {
		if (!dateString) return '-';
		const date = new Date(dateString);
		const day = String(date.getDate()).padStart(2, '0');
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const year = date.getFullYear();
		return `${day}-${month}-${year}`;
	}

	function formatBufferMinutes(bufferValue: number): string {
		if (!bufferValue) return `0 ${$t('common.min')}`;
		// If buffer is in hours (decimal), convert to minutes
		const minutes = Math.round(bufferValue * 60);
		return `${minutes} ${$t('common.min')}`;
	}

	function formatTime12Hour(timeString: string): string {
		if (!timeString) return '-';
		// Parse time string directly without Date object to avoid timezone conversion
		const [hoursStr, minutesStr] = timeString.split(':');
		let hour = parseInt(hoursStr);
		const minutes = minutesStr;
		const ampm = hour >= 12 ? $t('common.pm') : $t('common.am');
		hour = hour % 12 || 12;
		return `${String(hour).padStart(2, '0')}:${minutes} ${ampm}`;
	}

	function getDayNameFromDate(dateStr: string): number {
		// dateStr is in format DD-MM-YYYY
		if (!dateStr) return 0;
		const parts = dateStr.split('-');
		if (parts.length !== 3) return 0;
		const [day, month, year] = parts;
		const date = new Date(`${year}-${month}-${day}`);
		return date.getDay(); // 0 = Sunday, 1 = Monday, etc.
	}

	function isOfficialDayOff(dateStr: string): boolean {
		if (!dayOffWeekday) return false;
		const dateWeekday = getDayNameFromDate(dateStr);
		return dateWeekday === dayOffWeekday.weekday;
	}

	function isSpecificDayOff(dateStr: string): boolean {
		// Check if this specific date is marked as day off
		// dateStr is in format DD-MM-YYYY
		const [day, month, year] = dateStr.split('-');
		const dateFormatted = `${year}-${month}-${day}`; // Convert to YYYY-MM-DD
		return dayOffDates.some(d => d.day_off_date === dateFormatted);
	}

	function getSpecificDayOff(dateStr: string): any {
		// dateStr is in format DD-MM-YYYY
		const [day, month, year] = dateStr.split('-');
		const dateFormatted = `${year}-${month}-${day}`; // Convert to YYYY-MM-DD
		return dayOffDates.find(d => d.day_off_date === dateFormatted);
	}

	function getDayName(dayNum: number): string {
		const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
		const dayKey = days[dayNum];
		return dayKey ? $t(`common.days.${dayKey}`) : $t('common.unknown');
	}

	function getApplicableShift(dateStr: string) {
		// dateStr is in DD-MM-YYYY format
		if (!dateStr) return null;
		// Extract the weekday
		const dayNum = getDayNameFromDate(dateStr);

		// First priority: Check special_shift_date_wise (overwrites for specific date)
		const dateWiseShift = specialShiftDateWise.find((shift) => {
			// Convert dateStr from DD-MM-YYYY to YYYY-MM-DD for comparison
			const [day, month, year] = dateStr.split('-');
			const formattedDate = `${year}-${month}-${day}`;
			return shift.shift_date === formattedDate;
		});
		if (dateWiseShift) {
			return dateWiseShift;
		}

		// Second priority: Check special_shift_weekday
		const weekdayShift = specialShiftWeekday.find((shift) => shift.weekday === dayNum);
		if (weekdayShift) {
			return weekdayShift;
		}

		// Third priority: Fall back to regular shift
		return regularShift;
	}

	function timeToMinutes(timeStr: string): number {
		// Convert HH:MM:SS or HH:MM to minutes since midnight
		const parts = timeStr.split(':');
		const hours = parseInt(parts[0]);
		const minutes = parseInt(parts[1]);
		return hours * 60 + minutes;
	}

	function getTransactionStatus(punchTime: string, applicableShift: any): string {
		if (!applicableShift) return 'Unknown';

		const punchMinutes = timeToMinutes(punchTime);
		const shiftStartMinutes = timeToMinutes(applicableShift.shift_start_time);
		const shiftEndMinutes = timeToMinutes(applicableShift.shift_end_time);
		const startBufferMinutes = (applicableShift.shift_start_buffer || 0) * 60;
		const endBufferMinutes = (applicableShift.shift_end_buffer || 0) * 60;

		// Check-in window: shift_start ± buffer
		const checkInStart = shiftStartMinutes - startBufferMinutes;
		const checkInEnd = shiftStartMinutes + startBufferMinutes;

		// Check-out window: shift_end ± buffer
		const checkOutStart = shiftEndMinutes - endBufferMinutes;
		const checkOutEnd = shiftEndMinutes + endBufferMinutes;

		// Determine status based on which window punch falls into
		if (punchMinutes >= checkInStart && punchMinutes <= checkInEnd) {
			return 'Check In';
		} else if (punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd) {
			return 'Check Out';
		}

		// If within shift time but outside buffers
		if (punchMinutes > checkInEnd && punchMinutes < checkOutStart) {
			return 'In Progress';
		}

		return 'Other';
	}

	function isCarryoverCheckOut(dateStr: string, punchTime: string, applicableShift: any): boolean {
		// Check if this punch is a check-out from the previous day
		// This happens when shift overlaps next day and punch time is early morning (before shift start)
		if (!isShiftOverlappingNextDay || !applicableShift) return false;

		const punchMinutes = timeToMinutes(punchTime);
		const shiftStartMinutes = timeToMinutes(applicableShift.shift_start_time);
		const shiftEndMinutes = timeToMinutes(applicableShift.shift_end_time);
		const endBufferMinutes = (applicableShift.shift_end_buffer || 0) * 60;

		// If shift end is after midnight (e.g., 23:00 next day = 23 * 60)
		// and punch time is small (early morning, before normal shift start)
		// then this is a carryover from previous day
		if (shiftEndMinutes > shiftStartMinutes) {
			// Normal shift (doesn't cross midnight)
			return false;
		}

		// Shift crosses midnight - check if punch is in the early morning window (checkout window)
		const checkOutStart = shiftEndMinutes - endBufferMinutes;
		const checkOutEnd = shiftEndMinutes + endBufferMinutes;

		return punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd;
	}

	function getPreviousDate(dateStr: string): string {
		// Convert DD-MM-YYYY to previous date in same format
		const [day, month, year] = dateStr.split('-');
		const date = new Date(`${year}-${month}-${day}`);
		date.setDate(date.getDate() - 1);
		const d = String(date.getDate()).padStart(2, '0');
		const m = String(date.getMonth() + 1).padStart(2, '0');
		const y = date.getFullYear();
		return `${d}-${m}-${y}`;
	}

	function getNextDate(dateStr: string): string {
		// Convert DD-MM-YYYY to next date in same format
		const [day, month, year] = dateStr.split('-');
		const date = new Date(`${year}-${month}-${day}`);
		date.setDate(date.getDate() + 1);
		const d = String(date.getDate()).padStart(2, '0');
		const m = String(date.getMonth() + 1).padStart(2, '0');
		const y = date.getFullYear();
		return `${d}-${m}-${y}`;
	}

	function calculateLateTime(punchTime: string, applicableShift: any): { late: number; early: number } {
		// Returns object with late and early minutes
		// Late = minutes after shift_end_time (not counting buffer)
		// Early = minutes before shift_end_time
		if (!applicableShift) return { late: 0, early: 0 };

		const punchMinutes = timeToMinutes(punchTime);
		const shiftStartMinutes = timeToMinutes(applicableShift.shift_start_time);
		const shiftEndMinutes = timeToMinutes(applicableShift.shift_end_time);
		
		// Check if this is an overnight shift (end time < start time)
		const isOvernightShift = shiftEndMinutes < shiftStartMinutes;
		
		if (isOvernightShift) {
			// For overnight shifts, checkout can be either:
			// 1. In the early morning hours (0:00 to shift_end_time) - normal checkout
			// 2. In the evening hours (shift_start_time onwards) - should not happen for checkout
			
			if (punchMinutes <= shiftEndMinutes) {
				// This is a morning checkout (after midnight)
				// Calculate early/late based on shift end time
				if (punchMinutes > shiftEndMinutes) {
					return { late: punchMinutes - shiftEndMinutes, early: 0 };
				} else {
					return { late: 0, early: shiftEndMinutes - punchMinutes };
				}
			} else if (punchMinutes >= shiftStartMinutes) {
				// This is an evening punch (should be check-in, not check-out)
				// But if it's being treated as checkout, it's very late
				// Add 24 hours to shift end for comparison
				const adjustedShiftEnd = shiftEndMinutes + (24 * 60);
				return { late: punchMinutes - adjustedShiftEnd, early: 0 };
			}
		}
		
		// Normal shift (doesn't cross midnight)
		if (punchMinutes > shiftEndMinutes) {
			// Checkout is late (after shift end time)
			return { late: punchMinutes - shiftEndMinutes, early: 0 };
		} else if (punchMinutes < shiftEndMinutes) {
			// Checkout is early (before shift end time)
			return { late: 0, early: shiftEndMinutes - punchMinutes };
		}
		
		return { late: 0, early: 0 };
	}

	function calculateEarlyLateForCheckIn(punchTime: string, applicableShift: any): { late: number; early: number } {
		// For check-in: early = minutes before shift start, late = minutes after shift start
		// Based on actual shift start time, not the buffer
		if (!applicableShift) return { late: 0, early: 0 };

		const punchMinutes = timeToMinutes(punchTime);
		const shiftStartMinutes = timeToMinutes(applicableShift.shift_start_time);
		const shiftEndMinutes = timeToMinutes(applicableShift.shift_end_time);
		
		// Check if this is an overnight shift (end time < start time)
		const isOvernightShift = shiftEndMinutes < shiftStartMinutes;
		
		if (isOvernightShift) {
			// For overnight shifts, check-in is only in the evening (between shift_start and midnight)
			if (punchMinutes >= shiftStartMinutes) {
				// Evening check-in
				if (punchMinutes < shiftStartMinutes) {
					// Early - shouldn't happen since we're >= shiftStart
					return { late: 0, early: shiftStartMinutes - punchMinutes };
				} else {
					// Late - after shift start time
					return { late: punchMinutes - shiftStartMinutes, early: 0 };
				}
			} else if (punchMinutes < shiftStartMinutes && punchMinutes < shiftEndMinutes) {
				// This is a morning punch (shouldn't be check-in)
				// Could be previous day's checkout or very early morning check-in
				// Treat as very early (add 24 hours for comparison)
				const adjustedShiftStart = shiftStartMinutes - (24 * 60);
				return { late: 0, early: adjustedShiftStart - punchMinutes };
			}
		}
		
		// Normal shift (doesn't cross midnight)
		if (punchMinutes < shiftStartMinutes) {
			// Check-in is early (before shift start)
			return { late: 0, early: shiftStartMinutes - punchMinutes };
		} else if (punchMinutes > shiftStartMinutes) {
			// Check-in is late (after shift start)
			return { late: punchMinutes - shiftStartMinutes, early: 0 };
		}
		
		return { late: 0, early: 0 };
	}

	function calculateWorkedTime(checkInTime: string, checkOutTime: string): string {
		// Returns formatted worked time HH:MM
		const checkInMinutes = timeToMinutes(checkInTime);
		const checkOutMinutes = timeToMinutes(checkOutTime);

		let diffMinutes = checkOutMinutes - checkInMinutes;

		// Handle overnight shift (checkout is next day)
		if (diffMinutes < 0) {
			diffMinutes += 24 * 60; // Add 24 hours
		}

		const hours = Math.floor(diffMinutes / 60);
		const minutes = diffMinutes % 60;

		return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
	}

	async function loadTransactions() {
		loadingTransactions = true;
		try {
			console.log('Loading transactions for employee:', employee.id, 'Date range:', startDate, 'to', endDate);
			
			// Extend date range by 1 day before and after to capture carryover punches
			const extendedStartDate = new Date(startDate);
			extendedStartDate.setDate(extendedStartDate.getDate() - 1);
			const extendedStartDateStr = extendedStartDate.toISOString().split('T')[0];
			
			const extendedEndDate = new Date(endDate);
			extendedEndDate.setDate(extendedEndDate.getDate() + 1);
			const extendedEndDateStr = extendedEndDate.toISOString().split('T')[0];

			console.log('Extended date range for query:', extendedStartDateStr, 'to', extendedEndDateStr);

			// Query with extended date range
			const { data, error } = await supabase
				.from('processed_fingerprint_transactions')
				.select('*')
				.eq('center_id', employee.id)
				.gte('punch_date', extendedStartDateStr)
				.lte('punch_date', extendedEndDateStr)
				.order('punch_date', { ascending: false });

			console.log('Transaction query result:', { data, error });

			if (error) {
				console.error('Error loading transactions:', error);
				transactionData = [];
			} else {
				transactionData = data || [];
				console.log('Transactions loaded:', transactionData.length);
			}
		} catch (error) {
			console.error('Error loading transactions:', error);
			transactionData = [];
		} finally {
			loadingTransactions = false;
			// Process punch pairs after loading transactions
			punchPairs = createPunchPairs(transactionData);
			// Fill in missing dates in the range
			punchPairs = fillMissingDatesInRange(punchPairs);
			// Sort by date descending (latest first)
			punchPairs = sortPunchPairsNewestFirst(punchPairs);
		}
	}

	function fillMissingDatesInRange(pairs: any[]): any[] {
		const start = new Date(startDate);
		const end = new Date(endDate);
		const allDatePairs: any[] = [];
		const existingDates = new Set<string>();

		// Filter pairs to only include those within the original date range
		const filteredPairs = pairs.filter(pair => {
			const dateToCheck = pair.checkInDate || pair.checkOutDate;
			if (!dateToCheck) return false;
			
			const dateParts = dateToCheck.split('-');
			const pairDate = new Date(`${dateParts[2]}-${dateParts[1]}-${dateParts[0]}`);
			return pairDate >= start && pairDate <= end;
		});

		// Track which shift dates have pairs
		filteredPairs.forEach(pair => {
			if (pair.checkInDate) {
				existingDates.add(pair.checkInDate);
			}
			if (pair.checkOutDate && !pair.checkInDate) {
				existingDates.add(pair.checkOutDate);
			}
		});

		// Create empty pairs for all missing dates in the range
		for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
			const dateStr = formatDateddmmyyyy(d.toISOString().split('T')[0]);
			
			if (!existingDates.has(dateStr)) {
				// Create empty pair for this date
				allDatePairs.push({
					checkInTxn: null,
					checkInDate: dateStr,
					checkInEarlyLateTime: { late: 0, early: 0 },
					checkOutTxn: null,
					checkOutDate: dateStr,
					checkOutCalendarDate: null,
					workedTime: null,
					lateEarlyTime: { late: 0, early: 0 },
					checkInMissing: true,
					checkOutMissing: true,
					isEmptyDate: true
				});
			}
		}

		// Combine filtered pairs with empty date pairs
		const allPairs = [...filteredPairs, ...allDatePairs];
		
		// Sort by date (convert DD-MM-YYYY to comparable format)
		allPairs.sort((a, b) => {
			const aDate = a.checkInDate || a.checkOutDate;
			const bDate = b.checkInDate || b.checkOutDate;
			
			const aParts = aDate.split('-');
			const bParts = bDate.split('-');
			
			const aDateObj = new Date(`${aParts[2]}-${aParts[1]}-${aParts[0]}`);
			const bDateObj = new Date(`${bParts[2]}-${bParts[1]}-${bParts[0]}`);
			
			return aDateObj.getTime() - bDateObj.getTime();
		});

		return allPairs;
	}

	function sortPunchPairsNewestFirst(pairs: any[]): any[] {
		// Sort by date descending (newest/latest first)
		return pairs.sort((a, b) => {
			const aDate = a.checkInDate || a.checkOutDate;
			const bDate = b.checkInDate || b.checkOutDate;
			
			const aParts = aDate.split('-');
			const bParts = bDate.split('-');
			
			const aDateObj = new Date(`${aParts[2]}-${aParts[1]}-${aParts[0]}`);
			const bDateObj = new Date(`${bParts[2]}-${bParts[1]}-${bParts[0]}`);
			
			// Return in descending order (latest first): b - a instead of a - b
			return bDateObj.getTime() - aDateObj.getTime();
		});
	}

	function createPunchPairs(transactions: any[]): any[] {
		const pairs: any[] = [];
		
		// Debug logging
		console.log('createPunchPairs called with', transactions.length, 'transactions');
		console.log('isShiftOverlappingNextDay:', isShiftOverlappingNextDay);
		
		// First, assign each transaction to its correct shift date
		const assignedTransactions = transactions.map(txn => {
			const calendarDate = formatDateddmmyyyy(txn.punch_date);
			const punchTime = txn.punch_time;
			const punchMinutes = timeToMinutes(punchTime);
			
			let shiftDate = calendarDate;
			let status = 'Other';
			
			// Get the applicable shift for this calendar date
			const calendarShift = getApplicableShift(calendarDate);
			
			// CRITICAL: Check if this is a morning punch that belongs to the PREVIOUS day's overnight shift
			// If punch time is before the current day's shift check-in window starts, it might be an early checkout from previous day
			const calendarShiftStartMinutes = calendarShift ? timeToMinutes(calendarShift.shift_start_time) : 24 * 60;
			const calendarShiftStartBuffer = calendarShift ? (calendarShift.shift_start_buffer || 0) * 60 : 0;
			const calendarCheckInStart = calendarShiftStartMinutes - calendarShiftStartBuffer;
			
			if (punchMinutes < calendarCheckInStart) {  // Before current day's shift check-in window
				const prevDate = getPreviousDate(calendarDate);
				const prevShift = getApplicableShift(prevDate);
				
				if (prevShift) {
					const prevShiftEndMinutes = timeToMinutes(prevShift.shift_end_time);
					const prevShiftStartMinutes = timeToMinutes(prevShift.shift_start_time);
					const isOvernightPrevShift = prevShiftEndMinutes < prevShiftStartMinutes;
					
					// If previous shift is overnight (ends after it starts in time, meaning crosses midnight)
					if (isOvernightPrevShift) {
						const prevEndBufferMinutes = (prevShift.shift_end_buffer || 0) * 60;
						const prevCheckOutStart = prevShiftEndMinutes - prevEndBufferMinutes;
						const prevCheckOutEnd = prevShiftEndMinutes + prevEndBufferMinutes;
						
						// Adjust for negative (midnight crossing)
						const adjustedCheckOutEnd = prevCheckOutEnd < 0 ? prevCheckOutEnd + (24 * 60) : prevCheckOutEnd;
						
						// Check if this punch is in the previous shift's checkout window
						if (punchMinutes >= 0 && punchMinutes <= adjustedCheckOutEnd) {
							// This is an early morning checkout for the PREVIOUS day's shift
							shiftDate = prevDate;
							status = 'Check Out';
							console.log(`Punch ${txn.id} at ${punchTime} on ${calendarDate}: Reclassified as Check Out for ${prevDate} (early morning carryover)`);
							return { ...txn, calendarDate, shiftDate, status };
						}
					}
				}
			}
			
			// ALWAYS recalculate status based on shift windows and buffers, NOT database status
			// Detect if shift is overnight (shift_end_time < shift_start_time in minutes)
			const isOvernightShift = calendarShift && 
				timeToMinutes(calendarShift.shift_end_time) < timeToMinutes(calendarShift.shift_start_time);
			
			// Calculate status using the shift's buffer windows
			if (calendarShift) {
				const shiftStartMinutes = timeToMinutes(calendarShift.shift_start_time);
				const shiftEndMinutes = timeToMinutes(calendarShift.shift_end_time);
				const startBufferMinutes = (calendarShift.shift_start_buffer || 0) * 60;
				const endBufferMinutes = (calendarShift.shift_end_buffer || 0) * 60;
				
				const checkInStart = shiftStartMinutes - startBufferMinutes;
				const checkInEnd = shiftStartMinutes + startBufferMinutes;
				const checkOutStart = shiftEndMinutes - endBufferMinutes;
				const checkOutEnd = shiftEndMinutes + endBufferMinutes;
				
				console.log(`Punch ${txn.id} on ${calendarDate} at ${punchTime}:`, {
					punchMinutes,
					shiftStart: `${calendarShift.shift_start_time} (${shiftStartMinutes}m)`,
					shiftEnd: `${calendarShift.shift_end_time} (${shiftEndMinutes}m)`,
					startBuffer: `${startBufferMinutes}m`,
					endBuffer: `${endBufferMinutes}m`,
					checkInWindow: `${checkInStart}-${checkInEnd}`,
					checkOutWindow: `${checkOutStart}-${checkOutEnd}`,
					isOvernight: isOvernightShift
				});
				
				// For overnight shifts, the checkout window crosses midnight
				if (isOvernightShift) {
					// Check-in window: shift_start ± buffer (e.g., 4 PM ± 3h = 1 PM to 7 PM)
					if (punchMinutes >= checkInStart && punchMinutes <= checkInEnd) {
						status = 'Check In';
						shiftDate = calendarDate;
						console.log(`  → CLASSIFIED AS CHECK IN (overnight)`);
					}
					// For overnight shifts ending at/near midnight:
					// If shift_end is 00:00 (midnight) with 3h buffer:
					//   checkOutStart = 0 - 180 = -180 (21:00 previous day)
					//   checkOutEnd = 0 + 180 = 180 (03:00 next day)
					// Both evening (21:00-23:59) and early morning (00:00-03:00) are valid checkout times on THIS calendar date
					else if (checkOutStart < 0) {
						// Shift ends at or near midnight - checkout window wraps around
						const adjustedCheckOutStart = checkOutStart + (24 * 60); // Convert negative to evening time
						
						// Case 1: Early morning punch (00:00 to 03:00) = checkout for this shift
						if (punchMinutes >= 0 && punchMinutes <= checkOutEnd) {
							status = 'Check Out';
							shiftDate = calendarDate; // FIXED: Keep on same calendar date, not previous
							console.log(`  → CLASSIFIED AS CHECK OUT (early morning, same date)`);
						}
						// Case 2: Evening punch (21:00 to 23:59) = checkout for this shift
						else if (punchMinutes >= adjustedCheckOutStart && punchMinutes < (24 * 60)) {
							status = 'Check Out';
							shiftDate = calendarDate;
							console.log(`  → CLASSIFIED AS CHECK OUT (evening, same date)`);
						}
						// Case 3: In progress
						else if (punchMinutes > checkInEnd && punchMinutes < adjustedCheckOutStart) {
							status = 'In Progress';
							shiftDate = calendarDate;
							console.log(`  → CLASSIFIED AS IN PROGRESS`);
						} else {
							status = 'Other';
							shiftDate = calendarDate;
							console.log(`  → CLASSIFIED AS OTHER`);
						}
					}
					// Checkout window doesn't cross midnight (normal overnight case)
					else if (punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd) {
						status = 'Check Out';
						shiftDate = calendarDate;
						console.log(`  → CLASSIFIED AS CHECK OUT (overnight, normal window)`);
					}
					else {
						status = 'Other';
						shiftDate = calendarDate;
						console.log(`  → CLASSIFIED AS OTHER`);
					}
				} else {
					// Normal shift (doesn't cross midnight)
					if (punchMinutes >= checkInStart && punchMinutes <= checkInEnd) {
						status = 'Check In';
						shiftDate = calendarDate;
						console.log(`  → CLASSIFIED AS CHECK IN`);
					} else if (punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd) {
						status = 'Check Out';
						shiftDate = calendarDate;
						console.log(`  → CLASSIFIED AS CHECK OUT`);
					} else if (punchMinutes > checkInEnd && punchMinutes < checkOutStart) {
						status = 'In Progress';
						shiftDate = calendarDate;
						console.log(`  → CLASSIFIED AS IN PROGRESS`);
					} else {
						status = 'Other';
						shiftDate = calendarDate;
						console.log(`  → CLASSIFIED AS OTHER`);
					}
				}
			}
			
			return {
				...txn,
				calendarDate,
				shiftDate,
				status
			};
		});
		
		// Filter to only include shift dates within the user's date range
		const startDateObj = new Date(startDate);
		const endDateObj = new Date(endDate);
		
		const filteredTransactions = assignedTransactions.filter(txn => {
			const shiftDateParts = txn.shiftDate.split('-');
			const txnDate = new Date(`${shiftDateParts[2]}-${shiftDateParts[1]}-${shiftDateParts[0]}`);
			const isInRange = txnDate >= startDateObj && txnDate <= endDateObj;
			if (!isInRange) {
				console.log(`Filtering out ${txn.shiftDate} (outside range ${startDate} to ${endDate})`);
			}
			return isInRange;
		});
		
		// Deduplicate: Keep only the last punch of each status type on same shift date AND calendar date
		// BUT: If there are multiple punches of the same status and NO complementary punch exists,
		// keep all of them so they can be paired together (e.g., two Check Ins can become check-in/check-out)
		const dedupedTransactions: any[] = [];
		
		// First, group by shift date to analyze each day's punches
		const groupedForDedup: { [shiftDate: string]: any[] } = {};
		filteredTransactions.forEach(txn => {
			if (!groupedForDedup[txn.shiftDate]) {
				groupedForDedup[txn.shiftDate] = [];
			}
			groupedForDedup[txn.shiftDate].push(txn);
		});
		
		// Process each shift date
		Object.keys(groupedForDedup).forEach(shiftDate => {
			const dayTransactions = groupedForDedup[shiftDate];
			const checkIns = dayTransactions.filter(t => t.status === 'Check In');
			const checkOuts = dayTransactions.filter(t => t.status === 'Check Out');
			const others = dayTransactions.filter(t => t.status !== 'Check In' && t.status !== 'Check Out');
			
			// If we have multiple Check Ins but NO Check Outs, keep all Check Ins (they can be paired together)
			if (checkIns.length >= 2 && checkOuts.length === 0) {
				// Keep all check-ins for pairing
				checkIns.forEach(txn => dedupedTransactions.push(txn));
			} else if (checkIns.length > 0) {
				// Normal case: deduplicate check-ins by calendar date, keep latest
				const checkInMap: { [key: string]: any } = {};
				checkIns.forEach(txn => {
					const key = `${txn.calendarDate}`;
					if (!checkInMap[key] || txn.created_at > checkInMap[key].created_at) {
						checkInMap[key] = txn;
					}
				});
				Object.values(checkInMap).forEach(txn => dedupedTransactions.push(txn));
			}
			
			// If we have multiple Check Outs but NO Check Ins, keep all Check Outs (they can be paired together)
			if (checkOuts.length >= 2 && checkIns.length === 0) {
				// Keep all check-outs for pairing
				checkOuts.forEach(txn => dedupedTransactions.push(txn));
			} else if (checkOuts.length > 0) {
				// Normal case: deduplicate check-outs by calendar date, keep latest
				const checkOutMap: { [key: string]: any } = {};
				checkOuts.forEach(txn => {
					const key = `${txn.calendarDate}`;
					if (!checkOutMap[key] || txn.created_at > checkOutMap[key].created_at) {
						checkOutMap[key] = txn;
					}
				});
				Object.values(checkOutMap).forEach(txn => dedupedTransactions.push(txn));
			}
			
			// Keep all "In Progress" and "Other" transactions (deduplicate by id)
			const otherMap: { [key: string]: any } = {};
			others.forEach(txn => {
				if (!otherMap[txn.id]) {
					otherMap[txn.id] = txn;
				}
			});
			Object.values(otherMap).forEach(txn => dedupedTransactions.push(txn));
		});
		
		// Group deduplicated transactions by shift date
		const groupedByShiftDate: { [key: string]: any[] } = {};
		dedupedTransactions.forEach(txn => {
			if (!groupedByShiftDate[txn.shiftDate]) {
				groupedByShiftDate[txn.shiftDate] = [];
			}
			groupedByShiftDate[txn.shiftDate].push(txn);
		});
		
		console.log('Assigned transactions by shift date:', Object.keys(groupedByShiftDate));
		Object.keys(groupedByShiftDate).forEach(sd => {
			console.log(`  ${sd}: ${groupedByShiftDate[sd].map(t => `${t.status}@${formatTime12Hour(t.punch_time)}`).join(', ')}`);
		});
		
		// Track consumed transactions to avoid double pairing
		const consumedTransactions = new Set<string>();
		
		// Create pairs for each shift date
		Object.keys(groupedByShiftDate).sort().forEach(shiftDate => {
			const shiftTransactions = groupedByShiftDate[shiftDate].filter(t => !consumedTransactions.has(t.id));
			
			// Get applicable shift for this shift date
			const applicableShiftForDate = getApplicableShift(shiftDate);
			const isOvernightShift = applicableShiftForDate && 
				timeToMinutes(applicableShiftForDate.shift_end_time) < timeToMinutes(applicableShiftForDate.shift_start_time);
			
			// Sort transactions within each shift by: calendar date first, then by punch time
			// This ensures check-in (earlier calendar date or earlier time) comes before check-out
			shiftTransactions.sort((a, b) => {
				const aDate = new Date(`${a.calendarDate.split('-').reverse().join('-')}`);
				const bDate = new Date(`${b.calendarDate.split('-').reverse().join('-')}`);
				const dateComparison = aDate.getTime() - bDate.getTime();
				
				// If same calendar date, sort by punch time
				if (dateComparison === 0) {
					const aPunchMinutes = timeToMinutes(a.punch_time);
					const bPunchMinutes = timeToMinutes(b.punch_time);
					return aPunchMinutes - bPunchMinutes;
				}
				
				return dateComparison;
			});
			
			// Separate transactions by their computed status
			const checkInTransactions = shiftTransactions.filter(t => t.status === 'Check In');
			const checkOutTransactions = shiftTransactions.filter(t => t.status === 'Check Out');
			const otherTransactions = shiftTransactions.filter(t => t.status === 'In Progress' || t.status === 'Other');
			
			// IMPORTANT: Sort check-outs to prioritize same-day checkouts over carryover checkouts
			// For example: if shift is 31-12 and we have checkouts at:
			//   - 31-12 at 00:06:31 (same day recording)
			//   - 01-01 at 00:00:30 (carryover to next day)
			// We should use 31-12 at 00:06:31 as the primary checkout
			checkOutTransactions.sort((a, b) => {
				const aSameDay = a.calendarDate === shiftDate ? 0 : 1;
				const bSameDay = b.calendarDate === shiftDate ? 0 : 1;
				// Same-day checkouts (0) come before carryover checkouts (1)
				return aSameDay - bSameDay;
			});
			
			// Pair check-ins with check-outs
			let checkOutIdx = 0;
			let otherIdx = 0;
			
			checkInTransactions.forEach(checkInTxn => {
				// Try to find a matching check-out transaction
				let checkOutTxn = null;
				let checkOutCalendarDate = null;
				
				// First priority: Use a Check Out status transaction if available
				if (checkOutIdx < checkOutTransactions.length) {
					checkOutTxn = checkOutTransactions[checkOutIdx];
					checkOutCalendarDate = checkOutTxn.calendarDate;
					checkOutIdx++;
					consumedTransactions.add(checkOutTxn.id);
				}
				// Second priority: Use "In Progress" or "Other" as fallback
				else if (otherIdx < otherTransactions.length) {
					checkOutTxn = otherTransactions[otherIdx];
					checkOutCalendarDate = checkOutTxn.calendarDate;
					otherIdx++;
					consumedTransactions.add(checkOutTxn.id);
				}
				
				// For non-overlapping shifts, if still no checkout found, search for carryover checkout on next shift date
				if (!checkOutTxn && !isOvernightShift) {
					const applicableShift = getApplicableShift(shiftDate);
					if (applicableShift) {
						const nextShiftDate = getNextDate(shiftDate);
						const nextShiftTransactions = groupedByShiftDate[nextShiftDate];
						
						if (nextShiftTransactions && nextShiftTransactions.length > 0) {
							const nextDayShift = getApplicableShift(nextShiftDate);
							if (nextDayShift) {
								const nextShiftStartMinutes = timeToMinutes(nextDayShift.shift_start_time);
								const nextShiftStartBuffer = (nextDayShift.shift_start_buffer || 0) * 60;
								const nextDayCheckInStart = nextShiftStartMinutes - nextShiftStartBuffer; // Earliest punch that would be check-in
								
								// Look for any punch before the next day's check-in window
								for (const nextTxn of nextShiftTransactions) {
									if (consumedTransactions.has(nextTxn.id)) continue;
									
									const nextPunchMinutes = timeToMinutes(nextTxn.punch_time);
									
									// If this punch is BEFORE the next day's check-in window, it belongs to current day as checkout
									if (nextPunchMinutes < nextDayCheckInStart) {
										checkOutTxn = nextTxn;
										checkOutCalendarDate = nextTxn.calendarDate;
										// Mark this transaction as consumed
										consumedTransactions.add(nextTxn.id);
										break; // Use the first such punch found
									}
								}
							}
						}
					}
				}
				
				const checkOutApplicableShift = checkOutTxn ? getApplicableShift(shiftDate) : null;
				
				const pair = {
					checkInTxn: checkInTxn,
					checkInDate: shiftDate,
					checkInEarlyLateTime: calculateEarlyLateForCheckIn(checkInTxn.punch_time, getApplicableShift(shiftDate)),
					checkOutTxn: checkOutTxn,
					checkOutDate: shiftDate,
					checkOutCalendarDate: checkOutCalendarDate,
					workedTime: checkOutTxn ? calculateWorkedTime(checkInTxn.punch_time, checkOutTxn.punch_time) : null,
					lateEarlyTime: checkOutTxn ? calculateLateTime(checkOutTxn.punch_time, checkOutApplicableShift) : { late: 0, early: 0 },
					checkOutMissing: !checkOutTxn
				};
				
				pairs.push(pair);
				// ONLY mark as consumed if it has a matched checkout
				if (checkOutTxn) {
					consumedTransactions.add(checkInTxn.id);
				}
			});
			
			// ADDITIONAL LOGIC: If we have multiple unmatched "Check In" classified punches on the same shift date,
			// pair them together (first is check-in, second is check-out) because they likely represent a complete shift
			const unmatchedCheckIns = checkInTransactions.filter(t => !consumedTransactions.has(t.id));
			
			if (unmatchedCheckIns.length >= 2) {
				// Sort unmatched check-ins by punch time to ensure proper pairing order
				unmatchedCheckIns.sort((a, b) => {
					const aPunchMinutes = timeToMinutes(a.punch_time);
					const bPunchMinutes = timeToMinutes(b.punch_time);
					return aPunchMinutes - bPunchMinutes;
				});
				
				// Remove the already-paired pairs and create new correct ones
				// Remove old incomplete pairs first
				let pairsToRemove = [];
				unmatchedCheckIns.forEach(txn => {
					const idx = pairs.findIndex(p => p.checkInTxn && p.checkInTxn.id === txn.id && p.checkOutMissing);
					if (idx >= 0) {
						pairsToRemove.push(idx);
					}
				});
				// Remove in reverse order to avoid index shifting
				pairsToRemove.sort((a, b) => b - a).forEach(idx => {
					pairs.splice(idx, 1);
				});
				
				// Pair consecutive unmatched check-ins
				for (let i = 0; i < unmatchedCheckIns.length - 1; i += 2) {
					const checkInTxn = unmatchedCheckIns[i];
					const checkOutTxn = unmatchedCheckIns[i + 1];
					
					const pair = {
						checkInTxn: checkInTxn,
						checkInDate: shiftDate,
						checkInEarlyLateTime: calculateEarlyLateForCheckIn(checkInTxn.punch_time, getApplicableShift(shiftDate)),
						checkOutTxn: checkOutTxn,
						checkOutDate: shiftDate,
						checkOutCalendarDate: checkOutTxn.calendarDate,
						workedTime: calculateWorkedTime(checkInTxn.punch_time, checkOutTxn.punch_time),
						lateEarlyTime: calculateLateTime(checkOutTxn.punch_time, getApplicableShift(shiftDate)),
						checkOutMissing: false
					};
					
					pairs.push(pair);
					consumedTransactions.add(checkInTxn.id);
					consumedTransactions.add(checkOutTxn.id);
				}
				
				// If there's an odd unmatched check-in left, re-add it as incomplete
				if (unmatchedCheckIns.length % 2 === 1) {
					const lastCheckIn = unmatchedCheckIns[unmatchedCheckIns.length - 1];
					const pair = {
						checkInTxn: lastCheckIn,
						checkInDate: shiftDate,
						checkInEarlyLateTime: calculateEarlyLateForCheckIn(lastCheckIn.punch_time, getApplicableShift(shiftDate)),
						checkOutTxn: null,
						checkOutDate: shiftDate,
						checkOutCalendarDate: null,
						workedTime: null,
						lateEarlyTime: { late: 0, early: 0 },
						checkOutMissing: true
					};
					pairs.push(pair);
					consumedTransactions.add(lastCheckIn.id);
				}
			}
			
			// Handle remaining check-outs that weren't paired with check-ins
			checkOutTransactions.forEach(checkOutTxn => {
				if (!consumedTransactions.has(checkOutTxn.id)) {
					const pair = {
						checkInTxn: null,
						checkInDate: null,
						checkOutTxn: checkOutTxn,
						checkOutDate: shiftDate,
						checkOutCalendarDate: checkOutTxn.calendarDate,
						workedTime: null,
						lateEarlyTime: calculateLateTime(checkOutTxn.punch_time, getApplicableShift(shiftDate)),
						checkInMissing: true
					};
					
					pairs.push(pair);
					consumedTransactions.add(checkOutTxn.id);
				}
			});
			
			// Handle remaining "Other" transactions that weren't paired
			otherTransactions.forEach(otherTxn => {
				if (!consumedTransactions.has(otherTxn.id)) {
					const pair = {
						checkInTxn: null,
						checkInDate: null,
						checkOutTxn: otherTxn,
						checkOutDate: shiftDate,
						checkOutCalendarDate: otherTxn.calendarDate,
						workedTime: null,
						lateEarlyTime: calculateLateTime(otherTxn.punch_time, getApplicableShift(shiftDate)),
						checkInMissing: true
					};
					
					pairs.push(pair);
					consumedTransactions.add(otherTxn.id);
				}
			});
		});
		
		console.log('Created pairs:', pairs.length);
		pairs.forEach((p, idx) => {
			const checkInStr = p.checkInTxn ? `${formatTime12Hour(p.checkInTxn.punch_time)}@${p.checkInDate}` : 'none';
			const checkOutStr = p.checkOutTxn ? `${formatTime12Hour(p.checkOutTxn.punch_time)}@${p.checkOutCalendarDate}` : 'none';
			console.log(`  Pair ${idx}: IN=${checkInStr}, OUT=${checkOutStr}, Worked=${p.workedTime}`);
		});
		
		return pairs;
	}

</script>

<div class="employee-analysis-window bg-white h-full overflow-y-auto">
	<!-- Sticky Header Section -->
	<div class="sticky top-0 z-20 bg-white/95 backdrop-blur-md border-b border-slate-200 shadow-sm px-4 py-1">
		<div class="flex flex-wrap items-center justify-between gap-2">
			
			<!-- Employee Section -->
			<div class="flex items-center gap-2">
				<div class="w-8 h-8 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white text-xs font-bold shadow-sm ring-2 ring-white">
					{employee.id.toString().slice(-2)}
				</div>
				<div class="flex flex-col">
					<div class="flex items-center gap-2">
						<h2 class="text-xs font-bold text-slate-900 leading-none">
							{$locale === 'ar' ? employee.name_ar || employee.name_en : employee.name_en}
						</h2>
						<span class="text-[9px] font-bold text-slate-500">#{employee.id}</span>
					</div>
					<div class="flex items-center gap-1.5">
						<span class="text-[10px] font-semibold text-blue-600 bg-blue-50 px-1 rounded">{$locale === 'ar' ? employee.branch_name_ar || employee.branch_name_en : employee.branch_name_en}</span>
						<span class="text-[10px] text-slate-400 font-medium">{$locale === 'ar' ? employee.nationality_name_ar || employee.nationality_name_en : employee.nationality_name_en}</span>
					</div>
				</div>
			</div>

			<!-- Shift Group -->
			{#if !loading && (regularShift || dayOffWeekday)}
				<div class="flex items-center bg-white border border-slate-200 rounded-lg overflow-hidden shadow-sm divide-x divide-slate-100">
					{#if regularShift}
						<div class="flex gap-4 px-3 py-1">
							<div class="flex flex-col">
								<span class="text-[8px] font-bold text-slate-400 ml-0.5">{$locale === 'ar' ? 'الجدول' : 'SCHEDULE'}</span>
								<div class="flex items-center gap-1 leading-none h-3">
									<span class="text-[11px] font-bold text-slate-700">{formatTime12Hour(regularShift.shift_start_time)} - {formatTime12Hour(regularShift.shift_end_time)}</span>
								</div>
							</div>
							<div class="flex flex-col">
								<span class="text-[8px] font-bold text-slate-400 ml-0.5">{$locale === 'ar' ? 'العازل' : 'BUFFER'}</span>
								<span class="text-[10px] font-semibold text-slate-600 leading-none h-3">{formatBufferMinutes(regularShift.shift_start_buffer)}/{formatBufferMinutes(regularShift.shift_end_buffer)}</span>
							</div>
							<div class="flex flex-col items-center">
								<span class="text-[8px] font-bold text-indigo-500 ml-0.5">{$t('common.hrs')}</span>
								<span class="text-[11px] font-black text-indigo-700 leading-none h-3">{regularShift.working_hours}{$t('common.h')}</span>
							</div>
						</div>
					{/if}
					
					{#if dayOffWeekday}
						<div class="bg-orange-50/50 px-3 py-1 flex flex-col items-center">
							<span class="text-[8px] font-bold text-orange-500 ml-0.5">{$t('hr.shift.day_off')}</span>
							<span class="text-[11px] font-bold text-orange-700 leading-none h-3">{dayOffWeekday.weekday !== undefined ? getDayName(dayOffWeekday.weekday) : '-'}</span>
						</div>
					{/if}
				</div>
			{/if}

			<!-- Actions -->
			<div class="flex items-center gap-2">
				<div class="flex items-center px-2 py-1 bg-slate-50 border border-slate-200 rounded-lg shadow-inner h-8">
					<input type="date" bind:value={startDate} class="text-[10px] font-bold border-none bg-transparent focus:ring-0 p-0 text-slate-700 w-24 uppercase" />
					<span class="mx-1 text-slate-300">-</span>
					<input type="date" bind:value={endDate} class="text-[10px] font-bold border-none bg-transparent focus:ring-0 p-0 text-slate-700 w-24 uppercase" />
				</div>
				<button 
					on:click={loadTransactions} 
					disabled={loadingTransactions}
					class="bg-slate-900 hover:bg-blue-600 text-[10px] text-white font-black px-3 h-8 rounded-lg transition-all shadow-sm active:scale-95 disabled:opacity-50"
				>
					{loadingTransactions ? '...' : $t('hr.processFingerprint.load')}
				</button>
				<button 
					on:click={updateTransactionStatuses} 
					disabled={loadingTransactions}
					class="w-8 h-8 bg-white border border-slate-200 rounded-lg text-slate-500 hover:text-indigo-600 hover:border-indigo-200 transition-all shadow-sm group"
					title={$t('hr.processFingerprint.sync_status')}
				>
					<span class="block group-hover:rotate-180 transition-transform duration-500 text-xs">🔄</span>
				</button>
			</div>
		</div>
	</div>

	<!-- Scrollable Content Section -->
	<div class="px-6 pb-2 space-y-6">

	<!-- Transactions Table -->
	{#if punchPairs.length > 0}
		<div class="bg-white rounded-lg border border-slate-200 overflow-hidden">
			<div class="space-y-4 p-4">
				{#each punchPairs as pair, idx (pair.checkInTxn?.id || pair.checkOutTxn?.id || pair.checkInDate || pair.checkOutDate)}
					{#if pair.isEmptyDate}
						<!-- Empty Date Card (No Transactions) -->
						{@const isOfficial = isOfficialDayOff(pair.checkInDate)}
						{@const isSpecific = isSpecificDayOff(pair.checkInDate)}
						{@const dayOff = isSpecific ? getSpecificDayOff(pair.checkInDate) : null}
						{@const isApproved = isOfficial || (isSpecific && dayOff?.approval_status === 'approved')}
						{@const isPending = isSpecific && (!dayOff?.approval_status || dayOff?.approval_status === 'pending')}
						{@const isRejected = isSpecific && dayOff?.approval_status === 'rejected'}
						{@const isUnapprovedLeave = !isApproved && !isPending && !isRejected}
						<div class="border border-slate-300 rounded-lg overflow-hidden 
							{(isUnapprovedLeave && !isSpecific) ? 'bg-red-50' : 
							 (isSpecific && dayOff?.approval_status === 'approved') ? 'bg-green-50' : 
							 (isPending ? 'bg-amber-50' :
							 (isRejected ? 'bg-rose-50' : 'bg-slate-50'))}}">
							<div class="px-4 py-2 font-bold flex items-center justify-between 
								{isOfficial ? 'bg-red-600' : 
								 (isSpecific && dayOff?.approval_status === 'approved') ? 'bg-green-500' : 
								 isPending ? 'bg-amber-500' :
								 isRejected ? 'bg-rose-600' :
								 isUnapprovedLeave ? 'bg-red-500' : 'bg-slate-400'} text-white">
								<span>{pair.checkInDate}</span>
								<div class="flex gap-2">
									{#if isOfficial}
										<span class="px-3 py-1 bg-red-600 rounded-full text-sm font-semibold">{$t('hr.shift.official_day_off')}</span>
									{/if}
									{#if isSpecific}
										<div class="flex items-center gap-2">
											<span class="px-3 py-1 {dayOff?.approval_status === 'approved' ? 'bg-green-600' : 'bg-red-700'} rounded-full text-sm font-semibold">
												{$t(dayOff?.approval_status === 'approved' ? 'hr.shift.approved_leave' : 'hr.shift.unapproved_leave')}
												{#if dayOff?.day_off_reasons}
													: {$locale === 'ar' ? (dayOff.day_off_reasons.reason_ar || dayOff.day_off_reasons.reason_en) : (dayOff.day_off_reasons.reason_en || dayOff.day_off_reasons.reason_ar)}
												{/if}
											</span>
											{#if dayOff?.document_url}
												<button 
													class="px-2 py-1 bg-white text-orange-600 rounded-full text-xs font-bold hover:bg-orange-50 transition"
													on:click={() => window.open(dayOff.document_url, '_blank')}
													title="View Document"
												>
													📄 {$t('common.view') || 'View'}
												</button>
											{/if}
											{#if dayOff?.description}
												<button 
													class="px-2 py-1 bg-white text-blue-600 rounded-full text-xs font-bold hover:bg-blue-50 transition"
													title={dayOff.description}
												>
													📝 {$t('common.note') || 'Note'}
												</button>
											{/if}
										</div>
									{/if}
									{#if !isOfficial && !isSpecific && isUnapprovedLeave}
										<span class="px-3 py-1 bg-gray-700 rounded-full text-sm font-semibold">{$t('hr.processFingerprint.status_absent')}</span>
									{/if}
								</div>
							</div>
							<div class="px-4 py-6 text-center text-sm {isUnapprovedLeave ? 'text-gray-600 font-semibold' : 'text-slate-500'}">
								{#if isUnapprovedLeave}
									{$t('hr.processFingerprint.no_checkin_checkout_recorded')}
								{:else}
									{$t('hr.processFingerprint.no_transactions_recorded')}
								{/if}
							</div>
							{#if isSpecific && dayOff?.description}
								<div class="px-4 py-3 bg-blue-50 border-t border-blue-200">
									<div class="text-xs font-semibold text-blue-700 mb-1">📝 {$t('common.description') || 'Description'}:</div>
									<div class="text-sm text-blue-900">{dayOff.description}</div>
								</div>
							{/if}
						</div>
					{:else if pair.checkInTxn}
						<!-- Paired Check-In/Check-Out (always show under check-in date) -->
						{@const isOfficial = isOfficialDayOff(pair.checkInDate)}
						{@const isSpecific = isSpecificDayOff(pair.checkInDate)}
						{@const dayOff = isSpecific ? getSpecificDayOff(pair.checkInDate) : null}
						<div class="border border-slate-300 rounded-lg overflow-hidden">
							<div class="{isOfficial ? 'bg-red-600' : (isSpecific && dayOff?.approval_status === 'approved') ? 'bg-green-500' : isSpecific ? 'bg-orange-400' : 'bg-blue-600'} text-white px-4 py-2 font-bold flex items-center justify-between">
								<span>{pair.checkInDate}</span>
								<div class="flex gap-2">
									{#if isOfficial}
										<span class="px-3 py-1 bg-red-500 rounded-full text-sm font-semibold">{$t('hr.shift.official_day_off')}</span>
									{/if}
									{#if isSpecific}
										<span class="px-3 py-1 {dayOff?.approval_status === 'approved' ? (dayOff?.is_deductible_on_salary ? 'bg-purple-600' : 'bg-green-600') : dayOff?.approval_status === 'pending' ? 'bg-amber-600' : dayOff?.approval_status === 'rejected' ? 'bg-red-700' : 'bg-red-700'} rounded-full text-sm font-semibold">
											{#if dayOff?.approval_status === 'approved'}
												{$t(dayOff?.is_deductible_on_salary ? 'hr.processFingerprint.status_approved_leave_deductible' : 'hr.processFingerprint.status_approved_leave_no_deduction')}
											{:else if dayOff?.approval_status === 'pending'}
												{$t('hr.processFingerprint.status_pending_approval')}
											{:else if dayOff?.approval_status === 'rejected'}
												{$t(dayOff?.is_deductible_on_salary ? 'hr.processFingerprint.status_rejected_deducted' : 'hr.processFingerprint.status_rejected_not_deducted')}
											{:else}
												{$t('hr.shift.unapproved_leave')}
											{/if}
											{#if dayOff?.day_off_reasons}
												: {$locale === 'ar' ? (dayOff.day_off_reasons.reason_ar || dayOff.day_off_reasons.reason_en) : (dayOff.day_off_reasons.reason_en || dayOff.day_off_reasons.reason_ar)}
											{/if}
										</span>
									{/if}
								</div>
							</div>
							
							<div class="divide-y divide-slate-200">
								<!-- Check-In Row -->
								<div class="px-4 py-3 hover:bg-slate-50">
									<div class="flex items-center justify-between">
										<div class="flex items-center gap-3 flex-1">
											<div>
												<div class="font-mono text-sm font-semibold text-slate-900">{formatTime12Hour(pair.checkInTxn.punch_time) || '-'}</div>
											</div>
										</div>
										<div class="flex items-center gap-2">
											<span class="px-3 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800">
												{$t('hr.checkIn')}
											</span>
											{#if pair.checkInMissing}
												<span class="px-3 py-1 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800">
													{$t('hr.processFingerprint.checkin_missing')}
												</span>
											{/if}										{#if pair.checkInEarlyLateTime?.late > 0}
											<span class="px-2 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800">
												{$t('hr.processFingerprint.late')} {Math.floor(pair.checkInEarlyLateTime.late / 60)}{$t('common.h')} {pair.checkInEarlyLateTime.late % 60}{$t('common.m')}
											</span>
										{/if}
										{#if pair.checkInEarlyLateTime?.early > 0}
											<span class="px-2 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800">
												{$t('hr.processFingerprint.early')} {Math.floor(pair.checkInEarlyLateTime.early / 60)}{$t('common.h')} {pair.checkInEarlyLateTime.early % 60}{$t('common.m')}
											</span>
										{/if}										</div>
									</div>
								</div>
								
								<!-- Check-Out Row -->
								{#if pair.checkOutTxn}
									<div class="px-4 py-3 hover:bg-slate-50">
										<div class="flex items-center justify-between mb-2">
											<div class="flex items-center gap-3 flex-1">
												<div>
													<div class="font-mono text-sm font-semibold text-slate-900">{formatTime12Hour(pair.checkOutTxn.punch_time) || '-'}</div>
													{#if pair.checkOutCalendarDate && pair.checkOutCalendarDate !== pair.checkInDate}
														<div class="text-xs text-gray-500 mt-1">{$t('hr.processFingerprint.from_label')} {pair.checkOutCalendarDate}</div>
													{/if}
												</div>
											</div>
											<div class="flex items-center gap-2">
												<span class="px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800">
													{$t('hr.checkOut')}
												</span>
												{#if pair.checkOutMissing}
													<span class="px-3 py-1 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800">
														{$t('hr.processFingerprint.checkout_missing')}
													</span>
												{/if}
												{#if pair.lateEarlyTime?.early > 0}
													<span class="px-2 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800">
														{$t('hr.processFingerprint.early')} {Math.floor(pair.lateEarlyTime.early / 60)}{$t('common.h')} {pair.lateEarlyTime.early % 60}{$t('common.m')}
													</span>
												{/if}
											</div>
										</div>
										{#if pair.workedTime}
											{@const workedMinutes = parseInt(pair.workedTime.split(':')[0]) * 60 + parseInt(pair.workedTime.split(':')[1])}
											{@const assignedShift = getApplicableShift(pair.checkInDate)}
											{@const assignedMinutes = assignedShift ? (assignedShift.working_hours || 0) * 60 : 0}
											{@const isWorkedEnough = workedMinutes >= assignedMinutes}
											{@const underworkedMinutes = assignedMinutes - workedMinutes}
											{@const underworkedH = Math.floor(underworkedMinutes / 60)}
											{@const underworkedM = underworkedMinutes % 60}
											<div class="mt-3 flex items-center gap-3">
												<span class={`px-4 py-2 rounded-full text-sm font-bold ${isWorkedEnough ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
													{$t('hr.processFingerprint.worked')}: {pair.workedTime} {isWorkedEnough ? '✓' : '✗'}
												</span>
												{#if underworkedMinutes > 0}
													<span class="px-3 py-1 rounded-full text-xs font-semibold bg-orange-100 text-orange-800">
														{$t('hr.processFingerprint.underworked')}: {underworkedH}{$t('common.h')} {underworkedM}{$t('common.m')}
													</span>
												{/if}
											</div>
										{/if}
									</div>
								{:else if pair.checkInTxn}
									<!-- Check-Out Missing -->
									<div class="px-4 py-3 bg-yellow-50 border-t border-yellow-100">
										<div class="flex items-center justify-between">
											<div class="flex items-center gap-3">
												<div class="text-sm font-semibold text-yellow-800">{$t('hr.processFingerprint.no_checkout_recorded')}</div>
											</div>
											<div class="flex items-center gap-2">
												<span class="px-3 py-1 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800">
													{$t('hr.processFingerprint.checkout_missing')}
												</span>
												<button
													class="px-3 py-1 rounded-full text-xs font-semibold bg-blue-600 text-white hover:bg-blue-700 transition"
													on:click={() => openAddPunchModal(pair, false)}
													disabled={savingPunch}
												>
													➕ {$t('actions.add') || 'Add'}
												</button>
											</div>
										</div>
									</div>
								{/if}
							</div>
						</div>
					{:else}
						<!-- Standalone Check-Out (Carryover from previous day) -->
						{@const isOfficial = isOfficialDayOff(pair.checkOutDate)}
						{@const isSpecific = isSpecificDayOff(pair.checkOutDate)}
						{@const dayOff = isSpecific ? getSpecificDayOff(pair.checkOutDate) : null}
						<div class="border border-slate-300 rounded-lg overflow-hidden">
							<div class="{isOfficial ? 'bg-red-600' : (isSpecific && dayOff?.approval_status === 'approved') ? 'bg-green-500' : isSpecific ? 'bg-orange-400' : 'bg-blue-600'} text-white px-4 py-2 font-bold flex items-center justify-between">
								<span>{pair.checkOutDate}</span>
								<div class="flex gap-2">
									{#if isOfficial}
										<span class="px-3 py-1 bg-red-500 rounded-full text-sm font-semibold">{$t('hr.shift.official_day_off')}</span>
									{/if}
									{#if isSpecific}
										<div class="flex items-center gap-2">
											<span class="px-3 py-1 {dayOff?.approval_status === 'approved' ? 'bg-green-600' : 'bg-red-700'} rounded-full text-sm font-semibold">
												{$t(dayOff?.approval_status === 'approved' ? 'hr.shift.approved_leave' : 'hr.shift.unapproved_leave')}
												{#if dayOff?.day_off_reasons}
													: {$locale === 'ar' ? (dayOff.day_off_reasons.reason_ar || dayOff.day_off_reasons.reason_en) : (dayOff.day_off_reasons.reason_en || dayOff.day_off_reasons.reason_ar)}
												{/if}
											</span>
											{#if dayOff?.document_url}
												<button 
													class="px-2 py-1 bg-white text-orange-600 rounded-full text-xs font-bold hover:bg-orange-50 transition"
													on:click={() => window.open(dayOff.document_url, '_blank')}
													title="View Document"
												>
													📄 {$t('common.view') || 'View'}
												</button>
											{/if}
										</div>
									{/if}
								</div>
							</div>
							
							<div class="divide-y divide-slate-200">
								{#if pair.checkInMissing}
									<!-- Check-In Missing -->
									<div class="px-4 py-3 bg-yellow-50 border-b border-yellow-100">
										<div class="flex items-center justify-between">
											<div class="flex items-center gap-3">
												<div class="text-sm font-semibold text-yellow-800">{$t('hr.processFingerprint.no_checkin_recorded')}</div>
											</div>
											<div class="flex items-center gap-2">
												<span class="px-3 py-1 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800">
													{$t('hr.processFingerprint.checkin_missing')}
												</span>
												<button
													class="px-3 py-1 rounded-full text-xs font-semibold bg-blue-600 text-white hover:bg-blue-700 transition"
													on:click={() => openAddPunchModal(pair, true)}
													disabled={savingPunch}
												>
													➕ {$t('actions.add') || 'Add'}
												</button>
											</div>
										</div>
									</div>
								{/if}
								<div class="px-4 py-3 hover:bg-slate-50">
									<div class="flex items-center justify-between mb-2">
										<div class="flex items-center gap-3 flex-1">
											<div>
												<div class="font-mono text-sm font-semibold text-slate-900">{formatTime12Hour(pair.checkOutTxn.punch_time) || '-'}</div>
												{#if pair.checkOutCalendarDate && pair.checkOutCalendarDate !== pair.checkOutDate}
													<div class="text-xs text-gray-500 mt-1">{$t('hr.processFingerprint.from_label')} {pair.checkOutCalendarDate}</div>
												{/if}
											</div>
										</div>
										<div class="flex items-center gap-2">
											<span class="px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800">
												{$t('hr.checkOut')}
											</span>
											{#if pair.lateEarlyTime?.early > 0}
												<span class="px-2 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800">
													{$t('hr.processFingerprint.early')} {Math.floor(pair.lateEarlyTime.early / 60)}{$t('common.h')} {pair.lateEarlyTime.early % 60}{$t('common.m')}
												</span>
											{/if}
										</div>
									</div>
								</div>
							</div>
						</div>
					{/if}
				{/each}
			</div>
			
			<!-- Footer -->
			<div class="px-4 py-3 bg-slate-50 text-xs text-slate-600 font-semibold border-t border-slate-200">
				{$t('hr.processFingerprint.total_punch_pairs')}: {punchPairs.length}
			</div>
		</div>
	{:else if !loadingTransactions && (startDate || endDate)}
		<div class="text-center py-8 text-slate-500">
			<p>{$t('hr.processFingerprint.no_transactions_found')}</p>
		</div>
	{/if}
	</div>

	<!-- Sticky Bottom Summary Section -->
	{#if punchPairs.length > 0}
		{@const completePairs = punchPairs.filter(p => p.checkInTxn && p.checkOutTxn)}
		{@const incompletePairs = punchPairs.filter(p => (p.checkInMissing || p.checkOutMissing) && !p.isEmptyDate)}
		{@const emptyDates = punchPairs.filter(p => p.isEmptyDate)}
		{@const officialDayOffs = emptyDates.filter(d => isOfficialDayOff(d.checkInDate))}
		{@const specificDayOffs = emptyDates.filter(d => isSpecificDayOff(d.checkInDate))}
		{@const unapprovedLeaves = emptyDates.filter(d => !isOfficialDayOff(d.checkInDate) && !isSpecificDayOff(d.checkInDate))}
		{@const totalWorkedMinutes = completePairs.reduce((sum, p) => {
			if (!p.workedTime) return sum;
			const [hours, mins] = p.workedTime.split(':').map(Number);
			return sum + (hours * 60) + mins;
		}, 0)}
		{@const totalWorkedHours = Math.floor(totalWorkedMinutes / 60)}
		{@const totalWorkedMins = totalWorkedMinutes % 60}
		{@const totalLateMinutes = completePairs.reduce((sum, p) => sum + (p.checkInEarlyLateTime?.late || 0), 0)}
		{@const totalLateHours = Math.floor(totalLateMinutes / 60)}
		{@const totalLateMins = totalLateMinutes % 60}
		{@const totalEarlyMinutes = completePairs.reduce((sum, p) => sum + (p.lateEarlyTime?.early || 0), 0)}
		{@const totalEarlyHours = Math.floor(totalEarlyMinutes / 60)}
		{@const totalEarlyMins = totalEarlyMinutes % 60}

		<div class="sticky bottom-0 z-20 bg-white/95 backdrop-blur-md border-t border-slate-200 px-6 py-2 shadow-[0_-4px_10px_rgba(0,0,0,0.05)]">
			<div class="flex items-center justify-between mb-2 px-1">
				<h3 class="text-[10px] font-black text-slate-500 uppercase tracking-tighter">{$t('hr.processFingerprint.summary_for').replace('{startDate}', startDate).replace('{endDate}', endDate)}</h3>
				<div class="flex items-center gap-1.5 bg-white px-2 py-0.5 rounded border border-slate-200 shadow-sm">
					<span class="text-[9px] font-bold text-slate-400 uppercase">{$t('hr.processFingerprint.total_days')}</span>
					<span class="text-[10px] font-black text-slate-900 leading-none">{punchPairs.length}</span>
				</div>
			</div>
			
			<div class="grid grid-cols-4 gap-2">
				<!-- Mini Stats Row -->
				{#each [
					{ label: $t('hr.processFingerprint.complete_days'), val: completePairs.length, color: 'bg-green-500' },
					{ label: $t('hr.processFingerprint.incomplete_days'), val: incompletePairs.length, color: 'bg-yellow-500' },
					{ label: $t('hr.processFingerprint.days_off'), val: officialDayOffs.length + specificDayOffs.length, color: 'bg-blue-500' },
					{ label: $t('hr.processFingerprint.unapproved_leaves'), val: unapprovedLeaves.length, color: 'bg-red-500' }
				] as item}
					<div class="bg-white border border-slate-200 rounded p-1.5 flex flex-col items-center">
						<div class="flex items-center gap-1 mb-0.5">
							<span class="w-1.5 h-1.5 rounded-full {item.color}"></span>
							<span class="text-[8px] font-bold text-slate-400 uppercase leading-none truncate w-16">{item.label}</span>
						</div>
						<span class="text-sm font-black text-slate-900 leading-none">{item.val}</span>
					</div>
				{/each}
			</div>
			
			<!-- Analytics Strip -->
			<div class="mt-2 flex items-center gap-2">
				<div class="flex-1 bg-indigo-600 rounded p-1.5 flex items-center justify-between px-3">
					<span class="text-[9px] font-bold text-indigo-100 uppercase">{$t('hr.processFingerprint.worked')}</span>
					<span class="text-sm font-black text-white leading-none">{totalWorkedHours}{$t('common.h')} {totalWorkedMins}{$t('common.m')}</span>
				</div>

				<div class="flex-1 bg-white border border-slate-200 rounded p-1.5 flex items-center justify-between px-3">
					<span class="text-[9px] font-bold text-slate-400 uppercase">{$t('hr.processFingerprint.late')}/{$t('hr.processFingerprint.early')}</span>
					<div class="flex gap-2">
						<span class="text-[10px] font-black text-red-600">{$locale === 'ar' ? 'تأخير' : 'L'}: {totalLateHours}{$t('common.h')} {totalLateMins}{$t('common.m')}</span>
						<span class="text-[10px] font-black text-orange-600">{$locale === 'ar' ? 'مبكر' : 'E'}: {totalEarlyHours}{$t('common.h')} {totalEarlyMins}{$t('common.m')}</span>
					</div>
				</div>

				{#if regularShift}
					{@const expectedHours = regularShift.working_hours || 0}
					{@const expectedMinutes = expectedHours * 60}
					{@const difference = totalWorkedMinutes - (completePairs.length * expectedMinutes)}
					{@const diffHours = Math.floor(Math.abs(difference) / 60)}
					{@const diffMins = Math.abs(difference) % 60}
					<div class="flex-1 bg-white border border-slate-200 rounded p-1.5 flex items-center justify-between px-3">
						<span class="text-[9px] font-bold text-slate-400 uppercase">{$locale === 'ar' ? 'الفرق' : 'Variance'}</span>
						<span class={`text-[10px] font-black ${difference >= 0 ? 'text-green-600' : 'text-red-600'}`}>
							{difference >= 0 ? '+' : '-'}{diffHours}{$t('common.h')} {diffMins}{$t('common.m')}
						</span>
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>

<!-- Add Punch Modal - Positioned at document root -->
{#if showAddPunchModal && modalData}
	<div style="position: fixed; inset: 0; background-color: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; z-index: 9999;">
		<div style="background-color: white; border-radius: 0.5rem; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1); max-width: 28rem; width: 100%; margin: 1rem;">
			<!-- Modal Header -->
			<div style="background: linear-gradient(to right, #2563eb, #1d4ed8); color: white; padding: 1.5rem; border-radius: 0.5rem 0.5rem 0 0; display: flex; align-items: center; justify-content: space-between;">
				<h2 style="font-size: 1.125rem; font-weight: bold;">
					{modalData.isMissingCheckIn ? $t('hr.checkIn') : $t('hr.checkOut')} - {$t('actions.add') || 'Add'}
				</h2>
				<button 
					on:click={closeAddPunchModal}
					style="background: transparent; border: none; color: white; cursor: pointer; padding: 0.25rem; border-radius: 9999px; font-size: 1.25rem;"
					disabled={savingPunch}
				>
					✕
				</button>
			</div>

			<!-- Modal Body -->
			<div style="padding: 1.5rem; display: flex; flex-direction: column; gap: 1rem;">
				<!-- Date Display -->
				<div>
					<div style="font-size: 0.75rem; font-weight: 600; color: #4b5563; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.5rem;">{$t('common.date') || 'Date'}</div>
					<div style="padding: 0.5rem 1rem; background-color: #f3f4f6; border-radius: 0.5rem; font-size: 0.875rem; font-weight: 600; color: #111827;">
						{modalData.punchDate}
					</div>
				</div>

				<!-- Punch Time Input - 12 Hour Format -->
				<div>
					<div style="display: block; font-size: 0.75rem; font-weight: 600; color: #4b5563; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.5rem;">{$t('hr.processFingerprint.punch_time') || 'Punch Time'}</div>
					<div style="display: flex; gap: 0.5rem; align-items: center;">
						<!-- Hour -->
						<select 
							bind:value={punchHour12}
							on:change={updatePunchTime24h}
							disabled={savingPunch}
							style="flex: 1; padding: 0.75rem; border: 1px solid #d1d5db; border-radius: 0.5rem; font-size: 0.875rem; background: white; cursor: pointer;"
						>
							{#each ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'] as hour}
								<option value={hour}>{hour}</option>
							{/each}
						</select>
						<span style="font-weight: bold; color: #374151;">:</span>
						<!-- Minute -->
						<select 
							bind:value={punchMinute}
							on:change={updatePunchTime24h}
							disabled={savingPunch}
							style="flex: 1; padding: 0.75rem; border: 1px solid #d1d5db; border-radius: 0.5rem; font-size: 0.875rem; background: white; cursor: pointer;"
						>
							{#each ['00', '05', '10', '15', '20', '25', '30', '35', '40', '45', '50', '55'] as minute}
								<option value={minute}>{minute}</option>
							{/each}
						</select>
						<!-- AM/PM -->
						<select 
							bind:value={punchPeriod}
							on:change={updatePunchTime24h}
							disabled={savingPunch}
							style="flex: 1; padding: 0.75rem; border: 1px solid #d1d5db; border-radius: 0.5rem; font-size: 0.875rem; background: white; cursor: pointer; font-weight: 600;"
						>
							<option value="AM">{$t('common.am') || 'AM'}</option>
							<option value="PM">{$t('common.pm') || 'PM'}</option>
						</select>
					</div>
					<div style="font-size: 0.75rem; color: #6b7280; margin-top: 0.25rem;">
						{#if modalData.applicableShift}
							{$t('hr.shift.addPunchModal.auto_filled_based_on_shift') || 'Auto-filled based on shift'}: 
							{formatTime12Hour(modalData.isMissingCheckIn ? modalData.applicableShift.shift_start_time : modalData.applicableShift.shift_end_time)}
						{:else}
							<span style="color: #dc2626;">⚠️ {$t('hr.shift.no_shift_configured') || 'No shift configured for this employee'}</span>
						{/if}
					</div>
				</div>

				<!-- Deduction % Input -->
				<div>
					<label for="deduction_percent_input" style="display: block; font-size: 0.75rem; font-weight: 600; color: #4b5563; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.5rem;">{$t('hr.shift.addPunchModal.deduction_percent') || 'Deduction %'}</label>
					<input 
						id="deduction_percent_input"
						type="number" 
						min="0"
						max="100"
						step="0.1"
						bind:value={editDeductionPercent}
						on:input={() => {
							if (editDeductionPercent && modalData.applicableShift && editPunchTime) {
								editPunchTime = calculateAdjustedPunchTime(
									editPunchTime,
									Number(editDeductionPercent),
									modalData.isMissingCheckIn,
									modalData.applicableShift.shift_start_time,
									modalData.applicableShift.shift_end_time
								);
							}
						}}
						style="width: 100%; padding: 0.75rem; border: 1px solid #d1d5db; border-radius: 0.5rem; font-size: 0.875rem; box-sizing: border-box;"
						disabled={savingPunch}
						placeholder={$t('hr.shift.addPunchModal.deduction_placeholder') || 'Enter deduction percentage (0-100)'}
					/>
					<div style="font-size: 0.75rem; color: #6b7280; margin-top: 0.25rem;">
						{#if editDeductionPercent && modalData.applicableShift}
							{@const shiftStart = timeToMinutes(modalData.applicableShift.shift_start_time)}
							{@const shiftEnd = timeToMinutes(modalData.applicableShift.shift_end_time)}
							{@const assignedMinutes = shiftEnd >= shiftStart ? (shiftEnd - shiftStart) : (shiftEnd - shiftStart + 24 * 60)}
							{@const deductionMinutes = Math.round((Number(editDeductionPercent) / 100) * assignedMinutes)}
							{$t('hr.shift.addPunchModal.deduction_minutes', { minutes: deductionMinutes, hours: (deductionMinutes / 60).toFixed(2) }) || `Deduction: ${deductionMinutes} minutes (${(deductionMinutes / 60).toFixed(2)} hours)`}
						{:else}
							{$t('hr.shift.addPunchModal.enter_percentage') || 'Enter percentage to calculate deduction'}
						{/if}
					</div>
				</div>

				<!-- Status Display -->
				<div>
					<div style="font-size: 0.75rem; font-weight: 600; color: #4b5563; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.5rem;">{$t('common.status') || 'Status'}</div>
					<div style="padding: 0.5rem 1rem; background-color: #f3f4f6; border-radius: 0.5rem; font-size: 0.875rem; font-weight: 600; color: #111827;">
						{editPunchStatus}
					</div>
				</div>

				<!-- Shift Information -->
				{#if modalData.applicableShift}
					<div style="background-color: #eff6ff; border: 1px solid #bfdbfe; border-radius: 0.5rem; padding: 0.75rem;">
						<div style="font-size: 0.75rem; font-weight: 600; color: #1e40af; margin-bottom: 0.5rem;">{$t('hr.shift.shift_details') || 'Shift Details'}</div>
						<div style="font-size: 0.75rem; color: #1e3a8a; display: flex; flex-direction: column; gap: 0.25rem;">
							<div>{$t('hr.shift.shift_start') || 'Start'}: {formatTime12Hour(modalData.applicableShift.shift_start_time)}</div>
							<div>{$t('hr.shift.shift_end') || 'End'}: {formatTime12Hour(modalData.applicableShift.shift_end_time)}</div>
							<div>{$t('hr.shift.total_working_hours') || 'Working Hours'}: {modalData.applicableShift.working_hours || 'N/A'}</div>
						</div>
					</div>
				{/if}
			</div>

			<!-- Modal Footer -->
			<div style="background-color: #f9fafb; padding: 1.5rem; border-radius: 0 0 0.5rem 0.5rem; display: flex; gap: 0.75rem; border-top: 1px solid #e5e7eb;">
				<button
					style="flex: 1; padding: 0.75rem 1rem; background-color: #d1d5db; color: #374151; font-weight: 600; border-radius: 0.5rem; border: none; cursor: pointer;"
					on:click={closeAddPunchModal}
					disabled={savingPunch}
				>
					{$t('common.cancel') || 'Cancel'}
				</button>
				<button
					style="flex: 1; padding: 0.75rem 1rem; background-color: #2563eb; color: white; font-weight: 600; border-radius: 0.5rem; border: none; cursor: pointer;"
					on:click={savePunch}
					disabled={savingPunch || !editPunchTime}
				>
					{savingPunch ? $t('common.saving') || 'Saving...' : $t('common.save') || 'Save'}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Permission Denied Popup -->
{#if showPermissionDeniedPopup}
	<div style="position: fixed; inset: 0; background-color: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; z-index: 10000;">
		<div style="background-color: white; border-radius: 0.5rem; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1); max-width: 24rem; width: 100%; margin: 1rem;">
			<!-- Popup Header -->
			<div style="background: linear-gradient(to right, #ef4444, #dc2626); color: white; padding: 1.5rem; border-radius: 0.5rem 0.5rem 0 0; display: flex; align-items: center; justify-content: space-between;">
				<h2 style="font-size: 1.125rem; font-weight: bold;">⚠️ {$t('hr.shift.permissions.permission_denied_title') || 'Permission Denied'}</h2>
				<button 
					on:click={() => showPermissionDeniedPopup = false}
					style="background: transparent; border: none; color: white; cursor: pointer; padding: 0.25rem; border-radius: 9999px; font-size: 1.25rem;"
				>
					✕
				</button>
			</div>

			<!-- Popup Body -->
			<div style="padding: 1.5rem; display: flex; flex-direction: column; gap: 1rem;">
				<p style="font-size: 0.875rem; color: #374151; margin: 0;">
					{permissionDeniedMessage}
				</p>
				<p style="font-size: 0.75rem; color: #6b7280; margin: 0;">
					{$t('hr.shift.permissions.contact_admin') || 'Please contact your administrator to request this permission.'}
				</p>
			</div>

			<!-- Popup Footer -->
			<div style="background-color: #f9fafb; padding: 1.5rem; border-radius: 0 0 0.5rem 0.5rem; display: flex; gap: 0.75rem; border-top: 1px solid #e5e7eb;">
				<button
					style="flex: 1; padding: 0.75rem 1rem; background-color: #2563eb; color: white; font-weight: 600; border-radius: 0.5rem; border: none; cursor: pointer;"
					on:click={() => showPermissionDeniedPopup = false}
				>
					{$t('common.ok') || 'OK'}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Sync Result Modal -->
{#if showSyncResultModal}
	<div style="position: fixed; inset: 0; background-color: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; z-index: 10000;">
		<div style="background-color: white; border-radius: 0.5rem; box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1); max-width: 28rem; width: 100%; margin: 1rem;">
			<!-- Modal Header -->
			<div style="
				background: linear-gradient(to right, 
					{syncResultType === 'success' ? '#10b981, #059669' : syncResultType === 'error' ? '#ef4444, #dc2626' : '#3b82f6, #2563eb'}
				); 
				color: white; 
				padding: 1.5rem; 
				border-radius: 0.5rem 0.5rem 0 0; 
				display: flex; 
				align-items: center; 
				justify-content: space-between;
			">
				<h2 style="font-size: 1.125rem; font-weight: bold;">
					{syncResultType === 'success' ? '✅ Success' : syncResultType === 'error' ? '❌ Error' : 'ℹ️ Information'}
				</h2>
				<button 
					on:click={() => showSyncResultModal = false}
					style="background: transparent; border: none; color: white; cursor: pointer; padding: 0.25rem; border-radius: 9999px; font-size: 1.25rem;"
				>
					✕
				</button>
			</div>

			<!-- Modal Body -->
			<div style="padding: 1.5rem; display: flex; flex-direction: column; gap: 1rem;">
				<p style="font-size: 0.875rem; color: #374151; margin: 0; line-height: 1.5;">
					{syncResultMessage}
				</p>
			</div>

			<!-- Modal Footer -->
			<div style="background-color: #f9fafb; padding: 1.5rem; border-radius: 0 0 0.5rem 0.5rem; display: flex; gap: 0.75rem; border-top: 1px solid #e5e7eb;">
				<button
					style="flex: 1; padding: 0.75rem 1rem; background-color: {syncResultType === 'success' ? '#10b981' : syncResultType === 'error' ? '#ef4444' : '#3b82f6'}; color: white; font-weight: 600; border-radius: 0.5rem; border: none; cursor: pointer;"
					on:click={() => showSyncResultModal = false}
				>
					OK
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.employee-analysis-window {
		background: white;
	}
</style>
