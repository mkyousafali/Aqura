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

	async function loadEmployeeData() {
		try {
			// Load regular shift data
			const { data: shiftData } = await supabase
				.from('regular_shift')
				.select('*')
				.eq('id', employee.id)
				.single();
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
				.single();

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
		const punchDate = pair.checkInDate || pair.checkOutDate;
		console.log('punchDate:', punchDate);
		if (!punchDate) {
			console.log('No punchDate, returning early');
			return; // Don't open modal if there's no date
		}
		const applicableShift = getApplicableShift(punchDate);
		console.log('applicableShift:', applicableShift);

		// Default punch time based on shift
		let defaultTime = '';
		let defaultStatus = '';

		if (isMissingCheckIn && applicableShift) {
			// Default to shift start time for missing check-in
			defaultTime = applicableShift.shift_start_time;
			defaultStatus = 'Check In';
		} else if (!isMissingCheckIn && applicableShift) {
			// Default to shift end time for missing check-out
			defaultTime = applicableShift.shift_end_time;
			defaultStatus = 'Check Out';
		}

		modalData = {
			pair,
			isMissingCheckIn,
			punchDate,
			applicableShift
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
				syncResultMessage = 'Error fetching transactions: ' + fetchError.message;
				syncResultType = 'error';
				showSyncResultModal = true;
				return;
			}

			if (!allTransactions || allTransactions.length === 0) {
				syncResultMessage = 'No transactions found in this date range';
				syncResultType = 'info';
				showSyncResultModal = true;
				return;
			}
			
			// Filter to only transactions with null status that need updating
			const transactionsToUpdate = allTransactions.filter(txn => txn.status === null);
			
			if (transactionsToUpdate.length === 0) {
				syncResultMessage = 'ℹ️ No transactions with null status found in the date range';
				syncResultType = 'info';
				showSyncResultModal = true;
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
			syncResultMessage = `✅ Successfully updated ${updates.length} transaction(s) with calculated status`;
			syncResultType = 'success';
			showSyncResultModal = true;
			
			// Reload transactions to reflect the updates
			await loadTransactions();
		} catch (error) {
			console.error('Error updating transaction statuses:', error);
			syncResultMessage = 'Error updating statuses: ' + (error instanceof Error ? error.message : String(error));
			syncResultType = 'error';
			showSyncResultModal = true;
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
			
			let shiftDate = calendarDate;
			let status = 'Other';
			
			// Get the applicable shift for this calendar date
			const calendarShift = getApplicableShift(calendarDate);
			
			// ALWAYS recalculate status based on shift windows and buffers, NOT database status
			// Detect if shift is overnight (shift_end_time < shift_start_time in minutes)
			const isOvernightShift = calendarShift && 
				timeToMinutes(calendarShift.shift_end_time) < timeToMinutes(calendarShift.shift_start_time);
			
			// Calculate status using the shift's buffer windows
			if (calendarShift) {
				const punchMinutes = timeToMinutes(punchTime);
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
					// Check-in window: 8 PM - 3h to 8 PM + 3h = 5 PM to 11 PM (same calendar date)
					if (punchMinutes >= checkInStart && punchMinutes <= checkInEnd) {
						status = 'Check In';
						shiftDate = calendarDate;
						console.log(`  → CLASSIFIED AS CHECK IN (overnight)`);
					}
					// Checkout window for overnight: 8 AM - 3h to 8 AM + 3h = 5 AM to 11 AM
					// But since the shift spans two calendar days, 5 AM to 11 AM is on the NEXT calendar day
					// So we need to check: is this punch in the 5 AM to 11 AM range?
					else if (punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd) {
						status = 'Check Out';
						// Early morning punch (5 AM to 11 AM) = belongs to previous shift (started yesterday)
						shiftDate = getPreviousDate(calendarDate);
						console.log(`  → CLASSIFIED AS CHECK OUT (overnight, assigned to previous day)`);
					}
					// Midnight crossing: if checkOutStart is negative, it means the window includes early morning
					else if (checkOutStart < 0) {
						const adjustedCheckOutStart = checkOutStart + (24 * 60);
						const adjustedCheckOutEnd = checkOutEnd + (24 * 60);
						// Early morning (0:00 to late morning)
						if (punchMinutes >= 0 && punchMinutes <= adjustedCheckOutEnd) {
							status = 'Check Out';
							shiftDate = getPreviousDate(calendarDate);
							console.log(`  → CLASSIFIED AS CHECK OUT (early morning, assigned to previous day)`);
						}
						// In progress
						else if (punchMinutes > checkInEnd && punchMinutes < adjustedCheckOutStart) {
							status = 'In Progress';
							shiftDate = calendarDate;
							console.log(`  → CLASSIFIED AS IN PROGRESS`);
						} else {
							status = 'Other';
							shiftDate = calendarDate;
							console.log(`  → CLASSIFIED AS OTHER`);
						}
					} else {
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
		
		// Deduplicate: Keep only the last punch of each status type on same shift date
		const dedupedTransactions: any[] = [];
		const shiftDateStatusMap: { [key: string]: any } = {};

		filteredTransactions.forEach(txn => {
			const key = `${txn.shiftDate}-${txn.status}`;
			// Keep the latest punch for each status on each shift date
			if (!shiftDateStatusMap[key] || txn.created_at > shiftDateStatusMap[key].created_at) {
				shiftDateStatusMap[key] = txn;
			}
		});

		// Convert back to array
		Object.values(shiftDateStatusMap).forEach(txn => {
			dedupedTransactions.push(txn);
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
				consumedTransactions.add(checkInTxn.id);
			});
			
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
	<div class="sticky top-0 z-10 bg-white space-y-6 p-6">
		<!-- Employee Information Header -->
		<div class="bg-gradient-to-r from-blue-50 to-blue-100 border-l-4 border-blue-600 rounded-lg p-3">
			<div class="grid grid-cols-2 md:grid-cols-4 gap-2">
				<div class="bg-white rounded-lg p-3 shadow-sm border border-blue-100">
					<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.employeeId')}</div>
					<div class="text-base font-bold text-slate-900">{employee.id}</div>
				</div>

				<div class="bg-white rounded-lg p-3 shadow-sm border border-blue-100">
					<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.fullName')}</div>
					<div class="text-sm font-semibold text-slate-900">
						{$locale === 'ar' ? employee.name_ar || employee.name_en : employee.name_en}
					</div>
				</div>

				<div class="bg-white rounded-lg p-3 shadow-sm border border-blue-100">
					<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.branch')}</div>
					<div class="text-sm font-semibold text-slate-900">
						{$locale === 'ar' ? employee.branch_name_ar || employee.branch_name_en : employee.branch_name_en}
					</div>
				</div>

				<div class="bg-white rounded-lg p-3 shadow-sm border border-blue-100">
					<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.nationality')}</div>
					<div class="text-sm font-semibold text-slate-900">
						{$locale === 'ar' ? employee.nationality_name_ar || employee.nationality_name_en : employee.nationality_name_en}
					</div>
				</div>
			</div>
		</div>

		<!-- Regular Shift Section -->
		{#if !loading && regularShift}
			<div class="bg-gradient-to-r from-green-50 to-green-100 border-l-4 border-green-600 rounded-lg p-3">
				<div class="grid grid-cols-2 md:grid-cols-5 gap-2">
					<div class="bg-white rounded-lg p-3 shadow-sm border border-green-100">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.shift.shift_start')}</div>
						<div class="text-sm font-semibold text-slate-900">{formatTime12Hour(regularShift.shift_start_time) || '-'}</div>
					</div>

					<div class="bg-white rounded-lg p-3 shadow-sm border border-green-100">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.shift.start_buffer')}</div>
						<div class="text-sm font-semibold text-slate-900">{formatBufferMinutes(regularShift.shift_start_buffer)}</div>
					</div>

					<div class="bg-white rounded-lg p-3 shadow-sm border border-green-100">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.shift.shift_end')}</div>
						<div class="text-sm font-semibold text-slate-900">{formatTime12Hour(regularShift.shift_end_time) || '-'}</div>
					</div>

					<div class="bg-white rounded-lg p-3 shadow-sm border border-green-100">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.shift.end_buffer')}</div>
						<div class="text-sm font-semibold text-slate-900">{formatBufferMinutes(regularShift.shift_end_buffer)}</div>
					</div>

					<div class="bg-white rounded-lg p-3 shadow-sm border border-green-100">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.shift.total_working_hours')}</div>
						<div class="text-sm font-semibold text-slate-900">{regularShift.working_hours || '-'}</div>
					</div>
				</div>
			</div>
		{/if}

		<!-- Day Off Weekday Section -->
		{#if !loading && dayOffWeekday}
			<div class="bg-gradient-to-r from-orange-50 to-orange-100 border-l-4 border-orange-600 rounded-lg p-3">
				<div class="grid grid-cols-1 md:grid-cols-2 gap-2">
					<div class="bg-white rounded-lg p-3 shadow-sm border border-orange-100">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.shift.day_off')}</div>
						<div class="text-sm font-semibold text-slate-900">{dayOffWeekday.weekday !== undefined ? getDayName(dayOffWeekday.weekday) : '-'}</div>
					</div>
				</div>
			</div>
		{/if}

		<!-- Date Range Filter Section -->
		<div class="bg-gradient-to-r from-purple-50 to-purple-100 border-l-4 border-purple-600 rounded-lg p-4">
			<h3 class="text-sm font-bold text-slate-800 mb-3 uppercase tracking-wide">{$t('hr.processFingerprint.load_transactions_title')}</h3>
			<div class="grid grid-cols-1 md:grid-cols-4 gap-3">
				<div>
					<label class="block text-xs font-semibold text-slate-600 mb-2">{$t('hr.startDate')}</label>
					<input 
						type="date" 
						bind:value={startDate}
						class="w-full px-3 py-2 border border-purple-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
					/>
				</div>
				<div>
					<label class="block text-xs font-semibold text-slate-600 mb-2">{$t('hr.endDate')}</label>
					<input 
						type="date" 
						bind:value={endDate}
						class="w-full px-3 py-2 border border-purple-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
					/>
				</div>
				<div class="flex items-end">
					<button
						class="w-full px-4 py-2 bg-purple-600 text-white font-semibold rounded-lg hover:bg-purple-700 transition-colors disabled:bg-slate-400"
						on:click={loadTransactions}
						disabled={loadingTransactions}
					>
						{loadingTransactions ? $t('common.loading') : $t('hr.processFingerprint.load')}
					</button>
				</div>
				<div class="flex items-end">
					<button
						class="w-full px-4 py-2 bg-amber-600 text-white font-semibold rounded-lg hover:bg-amber-700 transition-colors disabled:bg-slate-400"
						on:click={updateTransactionStatuses}
						disabled={loadingTransactions}
						title="Update status for all transactions with null status in the date range"
					>
						{loadingTransactions ? $t('common.saving') : '🔄 Sync Status'}
					</button>
				</div>
			</div>
		</div>
	</div>

	<!-- Scrollable Content Section -->
	<div class="px-6 pb-6 space-y-6">

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
						{@const isUnapprovedLeave = !isApproved}
						<div class="border border-slate-300 rounded-lg overflow-hidden 
							{(isUnapprovedLeave && !isSpecific) ? 'bg-red-50' : 
							 (isSpecific && dayOff?.approval_status === 'approved') ? 'bg-green-50' : 
							 (isSpecific ? 'bg-orange-50' : 'bg-slate-50')}">
							<div class="px-4 py-2 font-bold flex items-center justify-between 
								{isOfficial ? 'bg-red-600' : 
								 (isSpecific && dayOff?.approval_status === 'approved') ? 'bg-green-500' : 
								 isSpecific ? 'bg-orange-400' : 
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
										<span class="px-3 py-1 bg-red-700 rounded-full text-sm font-semibold">{$t('hr.shift.unapproved_leave')}</span>
									{/if}
								</div>
							</div>
							<div class="px-4 py-6 text-center text-sm {isUnapprovedLeave ? 'text-red-600 font-semibold' : 'text-slate-500'}">
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
										<span class="px-3 py-1 {dayOff?.approval_status === 'approved' ? 'bg-green-600' : 'bg-red-700'} rounded-full text-sm font-semibold">
											{$t(dayOff?.approval_status === 'approved' ? 'hr.shift.approved_leave' : 'hr.shift.unapproved_leave')}
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
										<div class="text-right min-w-fit ml-4">
											<span class="font-mono text-xs text-slate-600">{pair.checkInTxn.id}</span>
										</div>
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
												{#if pair.lateEarlyTime?.late > 0}
													<span class="px-2 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800">
														{$t('hr.processFingerprint.overtime')} {Math.floor(pair.lateEarlyTime.late / 60)}{$t('common.h')} {pair.lateEarlyTime.late % 60}{$t('common.m')}
													</span>
												{/if}
												{#if pair.lateEarlyTime?.early > 0}
													<span class="px-2 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800">
														{$t('hr.processFingerprint.early')} {Math.floor(pair.lateEarlyTime.early / 60)}{$t('common.h')} {pair.lateEarlyTime.early % 60}{$t('common.m')}
													</span>
												{/if}
											</div>
											<div class="text-right min-w-fit ml-4">
												<span class="font-mono text-xs text-slate-600">{pair.checkOutTxn.id}</span>
											</div>
										</div>
										{#if pair.workedTime}
											{@const workedMinutes = parseInt(pair.workedTime.split(':')[0]) * 60 + parseInt(pair.workedTime.split(':')[1])}
											{@const assignedShift = getApplicableShift(pair.checkInDate)}
											{@const assignedMinutes = assignedShift ? (assignedShift.working_hours || 0) * 60 : 0}
											{@const isWorkedEnough = workedMinutes >= assignedMinutes}
											<div class="mt-3">
												<span class={`px-4 py-2 rounded-full text-sm font-bold ${isWorkedEnough ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
													{$t('hr.processFingerprint.worked')}: {pair.workedTime} {isWorkedEnough ? '✓' : '✗'}
												</span>
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
											{#if pair.lateEarlyTime?.late > 0}
												<span class="px-2 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800">
													{$t('hr.processFingerprint.overtime')} {Math.floor(pair.lateEarlyTime.late / 60)}{$t('common.h')} {pair.lateEarlyTime.late % 60}{$t('common.m')}
												</span>
											{/if}
											{#if pair.lateEarlyTime?.early > 0}
												<span class="px-2 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800">
													{$t('hr.processFingerprint.early')} {Math.floor(pair.lateEarlyTime.early / 60)}{$t('common.h')} {pair.lateEarlyTime.early % 60}{$t('common.m')}
												</span>
											{/if}
										</div>
										<div class="text-right min-w-fit ml-4">
											<span class="font-mono text-xs text-slate-600">{pair.checkOutTxn.id}</span>
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
		
		<!-- Summary Table -->
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
		{@const totalLateMinutes = completePairs.reduce((sum, p) => sum + (p.lateEarlyTime?.late || 0), 0)}
		{@const totalLateHours = Math.floor(totalLateMinutes / 60)}
		{@const totalLateMins = totalLateMinutes % 60}
		{@const totalEarlyMinutes = completePairs.reduce((sum, p) => sum + (p.lateEarlyTime?.early || 0), 0)}
		{@const totalEarlyHours = Math.floor(totalEarlyMinutes / 60)}
		{@const totalEarlyMins = totalEarlyMinutes % 60}
		
		<div class="mt-8 bg-white rounded-lg border border-slate-200 overflow-hidden">
			<div class="p-6">
				<h3 class="text-lg font-bold text-slate-900 mb-6">{$t('hr.processFingerprint.summary_for').replace('{startDate}', startDate).replace('{endDate}', endDate)}</h3>
				
				<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
					<!-- Complete Days -->
					<div class="bg-green-50 border border-green-200 rounded-lg p-4">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.processFingerprint.complete_days')}</div>
						<div class="text-3xl font-bold text-green-700">{completePairs.length}</div>
						<div class="text-xs text-slate-500 mt-2">{$t('hr.processFingerprint.checkin_checkout_recorded')}</div>
					</div>
					
					<!-- Incomplete Days -->
					<div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.processFingerprint.incomplete_days')}</div>
						<div class="text-3xl font-bold text-yellow-700">{incompletePairs.length}</div>
						<div class="text-xs text-slate-500 mt-2">{$t('hr.processFingerprint.missing_checkin_checkout')}</div>
					</div>
					
					<!-- Days Off -->
					<div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.processFingerprint.days_off')}</div>
						<div class="text-3xl font-bold text-blue-700">{officialDayOffs.length + specificDayOffs.length}</div>
						<div class="text-xs text-slate-500 mt-2">{$t('hr.processFingerprint.days_off_approved')}</div>
					</div>
					
					<!-- Unapproved Leaves -->
					<div class="bg-red-50 border border-red-200 rounded-lg p-4">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.processFingerprint.unapproved_leaves')}</div>
						<div class="text-3xl font-bold text-red-700">{unapprovedLeaves.length}</div>
						<div class="text-xs text-slate-500 mt-2">{$t('hr.processFingerprint.no_recorded_punches')}</div>
					</div>
				</div>
				
				<!-- Late/Early Time Row -->
				<div class="mt-4 grid grid-cols-1 md:grid-cols-2 gap-4">
					<!-- Total Late Time -->
					<div class="bg-red-50 border border-red-200 rounded-lg p-4">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.processFingerprint.total_late_time')}</div>
						<div class="text-3xl font-bold text-red-700">{totalLateHours}{$t('common.h')} {totalLateMins}{$t('common.m')}</div>
						<div class="text-xs text-slate-500 mt-2">{$t('hr.processFingerprint.overtime_across_days')}</div>
					</div>
					
					<!-- Total Early Time -->
					<div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">{$t('hr.processFingerprint.total_early_checkout')}</div>
						<div class="text-3xl font-bold text-blue-700">{totalEarlyHours}{$t('common.h')} {totalEarlyMins}{$t('common.m')}</div>
						<div class="text-xs text-slate-500 mt-2">{$t('hr.processFingerprint.undertime_across_days')}</div>
					</div>
				</div>
				
				<!-- Total Worked Hours -->
				<div class="mt-6 bg-gradient-to-r from-slate-50 to-slate-100 border border-slate-200 rounded-lg p-6">
					<div class="flex items-center justify-between">
						<div>
							<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-2">{$t('hr.processFingerprint.total_worked_hours')}</div>
							<div class="text-4xl font-bold text-slate-900">{totalWorkedHours}{$t('common.h')} {totalWorkedMins}{$t('common.m')}</div>
							<div class="text-sm text-slate-600 mt-3">{$t('hr.processFingerprint.across_complete_days').replace('{count}', completePairs.length.toString())}</div>
						</div>
						{#if regularShift}
							{@const expectedHours = regularShift.working_hours || 0}
							{@const expectedMinutes = expectedHours * 60}
							{@const difference = totalWorkedMinutes - (completePairs.length * expectedMinutes)}
							{@const diffHours = Math.floor(Math.abs(difference) / 60)}
							{@const diffMins = Math.abs(difference) % 60}
							<div class="text-right">
								<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-2">{$t('hr.processFingerprint.expected_vs_actual')}</div>
								<div class={`text-2xl font-bold ${difference >= 0 ? 'text-green-600' : 'text-red-600'}`}>
									{difference >= 0 ? '+' : '-'}{diffHours}{$t('common.h')} {diffMins}{$t('common.m')}
								</div>
								<div class="text-xs text-slate-600 mt-3">
									{$t('hr.processFingerprint.expected_total').replace('{count}', (completePairs.length * expectedHours).toString())}
								</div>
							</div>
						{/if}
					</div>
				</div>
			</div>
		</div>
	{:else if !loadingTransactions && (startDate || endDate)}
		<div class="text-center py-8 text-slate-500">
			<p>{$t('hr.processFingerprint.no_transactions_found')}</p>
		</div>
	{/if}
	</div>
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

				<!-- Punch Time Input -->
				<div>
					<label for="punch_time_input" style="display: block; font-size: 0.75rem; font-weight: 600; color: #4b5563; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.5rem;">{$t('hr.processFingerprint.punch_time') || 'Punch Time'}</label>
					<input 
						id="punch_time_input"
						type="time" 
						bind:value={editPunchTime}
						style="width: 100%; padding: 0.75rem; border: 1px solid #d1d5db; border-radius: 0.5rem; font-size: 0.875rem; box-sizing: border-box;"
						disabled={savingPunch}
					/>
					<div style="font-size: 0.75rem; color: #6b7280; margin-top: 0.25rem;">
						{$t('hr.processFingerprint.auto_filled') || 'Auto-filled based on shift'}: 
						{modalData.applicableShift ? formatTime12Hour(modalData.isMissingCheckIn ? modalData.applicableShift.shift_start_time : modalData.applicableShift.shift_end_time) : 'N/A'}
					</div>
				</div>

				<!-- Deduction % Input -->
				<div>
					<label for="deduction_percent_input" style="display: block; font-size: 0.75rem; font-weight: 600; color: #4b5563; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.5rem;">Deduction %</label>
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
						placeholder="Enter deduction percentage (0-100)"
					/>
					<div style="font-size: 0.75rem; color: #6b7280; margin-top: 0.25rem;">
						{#if editDeductionPercent && modalData.applicableShift}
							{@const shiftStart = timeToMinutes(modalData.applicableShift.shift_start_time)}
							{@const shiftEnd = timeToMinutes(modalData.applicableShift.shift_end_time)}
							{@const assignedMinutes = shiftEnd >= shiftStart ? (shiftEnd - shiftStart) : (shiftEnd - shiftStart + 24 * 60)}
							{@const deductionMinutes = Math.round((Number(editDeductionPercent) / 100) * assignedMinutes)}
							Deduction: {deductionMinutes} minutes ({(deductionMinutes / 60).toFixed(2)} hours)
						{:else}
							Enter percentage to calculate deduction
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
				<h2 style="font-size: 1.125rem; font-weight: bold;">⚠️ Permission Denied</h2>
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
					Please contact your administrator to request this permission.
				</p>
			</div>

			<!-- Popup Footer -->
			<div style="background-color: #f9fafb; padding: 1.5rem; border-radius: 0 0 0.5rem 0.5rem; display: flex; gap: 0.75rem; border-top: 1px solid #e5e7eb;">
				<button
					style="flex: 1; padding: 0.75rem 1rem; background-color: #2563eb; color: white; font-weight: 600; border-radius: 0.5rem; border: none; cursor: pointer;"
					on:click={() => showPermissionDeniedPopup = false}
				>
					OK
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
