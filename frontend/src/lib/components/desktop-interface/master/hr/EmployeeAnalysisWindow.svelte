<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { onMount, onDestroy } from 'svelte';

	export let employee: any;
	export let windowId: string;

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
	let startDate = new Date().toISOString().split('T')[0];
	let endDate = new Date().toISOString().split('T')[0];
	let transactionData: any[] = [];
	let loadingTransactions = false;
	let punchPairs: any[] = []; // Store paired check-ins and check-outs with metadata
	let realtimeChannel: any = null;

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
		loading = false;
		setupRealtime();
	});

	onDestroy(() => {
		if (realtimeChannel) {
			supabase.removeChannel(realtimeChannel);
		}
	});

	function closeWindow() {
		windowManager.closeWindow(windowId);
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
		const [day, month, year] = dateStr.split('-');
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
			
			// Detect if shift is overnight (shift_end_time < shift_start_time in minutes)
			const isOvernightShift = calendarShift && 
				timeToMinutes(calendarShift.shift_end_time) < timeToMinutes(calendarShift.shift_start_time);
			
			if ((isShiftOverlappingNextDay || isOvernightShift) && calendarShift) {
				const punchMinutes = timeToMinutes(punchTime);
				const shiftStartMinutes = timeToMinutes(calendarShift.shift_start_time);
				const shiftEndMinutes = timeToMinutes(calendarShift.shift_end_time);
				const startBufferMinutes = (calendarShift.shift_start_buffer || 0) * 60;
				const endBufferMinutes = (calendarShift.shift_end_buffer || 0) * 60;
				
				const checkInStart = shiftStartMinutes - startBufferMinutes;
				const checkInEnd = shiftStartMinutes + startBufferMinutes;
				const checkOutStart = shiftEndMinutes - endBufferMinutes;
				const checkOutEnd = shiftEndMinutes + endBufferMinutes;
				
				// Determine if this is check-in or checkout based on calendar date's shift
				if (punchMinutes >= checkInStart && punchMinutes <= checkInEnd) {
					status = 'Check In';
					shiftDate = calendarDate;
				} else if (isOvernightShift && checkOutStart < 0) {
					// For overnight shifts where checkout buffer crosses midnight
					// Check-out can be:
					// 1. Early morning (0 to checkOutEnd) - on next calendar day, but belongs to previous day's shift
					// 2. Late evening (checkOutStart + 24*60 onwards) - on same calendar day
					const adjustedCheckOutStart = checkOutStart + (24 * 60);
					
					// Early morning checkout (0:00 to 4:00 AM)
					if (punchMinutes >= 0 && punchMinutes <= checkOutEnd) {
						status = 'Check Out';
						// This punch is on the next calendar day, but belongs to previous day's shift
						shiftDate = getPreviousDate(calendarDate);
						const assignedShift = getApplicableShift(shiftDate);
						console.log(`Assigned early morning checkout on ${calendarDate} to shift date ${shiftDate}. Shift: ${calendarShift.shift_start_time}-${calendarShift.shift_end_time}`);
					}
					// Late evening checkout (10:00 PM to 11:59 PM)
					else if (punchMinutes >= adjustedCheckOutStart && punchMinutes < (24 * 60)) {
						status = 'Check Out';
						// This punch is on the same calendar day as check-in
						shiftDate = calendarDate;
						const assignedShift = getApplicableShift(shiftDate);
						console.log(`Assigned late evening checkout on ${calendarDate}. Shift: ${calendarShift.shift_start_time}-${calendarShift.shift_end_time}`);
					}
					else if (punchMinutes > checkInEnd && punchMinutes < adjustedCheckOutStart) {
						status = 'In Progress';
						shiftDate = calendarDate;
					} else {
						status = 'Other';
						shiftDate = calendarDate;
					}
				} else if (punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd) {
					status = 'Check Out';
					// Assign to previous day's shift
					shiftDate = getPreviousDate(calendarDate);
					// Verify that the assigned shift date also expects this as a checkout
					const assignedShift = getApplicableShift(shiftDate);
					console.log(`Assigned checkout from ${calendarDate} to ${shiftDate}. Calendar shift: ${calendarShift.shift_start_time}-${calendarShift.shift_end_time}, Assigned shift: ${assignedShift?.shift_start_time}-${assignedShift?.shift_end_time}`);
				} else if (punchMinutes > checkInEnd && punchMinutes < checkOutStart) {
					status = 'In Progress';
					shiftDate = calendarDate;
				} else {
					status = 'Other';
					shiftDate = calendarDate;
				}
			} else {
				// No overnight shift, use default logic
				status = getTransactionStatus(punchTime, calendarShift);
				shiftDate = calendarDate;
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
		
		// Group filtered transactions by shift date
		const groupedByShiftDate: { [key: string]: any[] } = {};
		filteredTransactions.forEach(txn => {
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
			
			let i = 0;
			
			while (i < shiftTransactions.length) {
				const txn = shiftTransactions[i];
				
				if (txn.status === 'Check In') {
					// Look for corresponding checkout in the same shift
					let checkOutTxn = null;
					let checkOutCalendarDate = null;
					let nextIdx = i + 1;
					
					// First, try to find a proper "Check Out" status punch
					if (nextIdx < shiftTransactions.length) {
						const nextTxn = shiftTransactions[nextIdx];
						if (nextTxn.status === 'Check Out') {
							checkOutTxn = nextTxn;
							checkOutCalendarDate = nextTxn.calendarDate;
						}
						// If no proper checkout found, use "In Progress" or "Other" punch as fallback checkout
						// BUT only if it's on the same shift date (same calendar date for non-overnight shifts)
						else if ((nextTxn.status === 'In Progress' || nextTxn.status === 'Other') && nextTxn.shiftDate === shiftDate) {
							checkOutTxn = nextTxn;
							checkOutCalendarDate = nextTxn.calendarDate;
						}
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
					
					// Mark check-in as consumed
					if (checkOutTxn && !consumedTransactions.has(txn.id)) {
						consumedTransactions.add(txn.id);
					}
					
					// For checkout late/early calculation, use the shift applicable to the checkout's shift date
					// (which may differ from check-in date in carryover scenarios)
					const checkOutApplicableShift = checkOutTxn ? getApplicableShift(shiftDate) : null;
					
					const pair = {
						checkInTxn: txn,
						checkInDate: shiftDate,
						checkInEarlyLateTime: calculateEarlyLateForCheckIn(txn.punch_time, getApplicableShift(shiftDate)),
						checkOutTxn: checkOutTxn,
						checkOutDate: shiftDate,
						checkOutCalendarDate: checkOutCalendarDate,
						workedTime: checkOutTxn ? calculateWorkedTime(txn.punch_time, checkOutTxn.punch_time) : null,
						lateEarlyTime: checkOutTxn ? calculateLateTime(checkOutTxn.punch_time, checkOutApplicableShift) : { late: 0, early: 0 },
						checkOutMissing: !checkOutTxn
					};
					
					pairs.push(pair);
					i += checkOutTxn ? 2 : 1;
				} else {
					// Standalone checkout (check-in was before the query range or is missing)
					// Only show if not already consumed as a carryover
					if (!consumedTransactions.has(txn.id)) {
						const pair = {
							checkInTxn: null,
							checkInDate: null,
							checkOutTxn: txn,
							checkOutDate: shiftDate,
							checkOutCalendarDate: txn.calendarDate,
							workedTime: null,
							lateEarlyTime: calculateLateTime(txn.punch_time, getApplicableShift(shiftDate)),
							checkInMissing: true
						};
						
						pairs.push(pair);
						consumedTransactions.add(txn.id);
					}
					i += 1;
				}
			}
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
			<div class="grid grid-cols-1 md:grid-cols-3 gap-3">
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

<style>
	.employee-analysis-window {
		background: white;
	}
</style>
