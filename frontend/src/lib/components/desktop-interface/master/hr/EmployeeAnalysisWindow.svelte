<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';

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

	onMount(async () => {
		try {
			// Load regular shift data
			const { data: shiftData } = await supabase
				.from('regular_shift')
				.select('*')
				.eq('id', employee.id)
				.single();
			regularShift = shiftData;

			// Load day off weekday data
			const { data: dayOffWData } = await supabase
				.from('day_off_weekday')
				.select('*')
				.eq('employee_id', employee.id);
			dayOffWeekday = dayOffWData && dayOffWData.length > 0 ? dayOffWData[0] : null;

			// Load day off dates
			const { data: dayOffDatesData } = await supabase
				.from('day_off')
				.select('*')
				.eq('employee_id', employee.id);
			dayOffDates = dayOffDatesData || [];

			// Load special shift date-wise
			const { data: specialDateData } = await supabase
				.from('special_shift_date_wise')
				.select('*')
				.eq('employee_id', employee.id);
			specialShiftDateWise = specialDateData || [];

			// Load special shift weekday
			const { data: specialWeekdayData } = await supabase
				.from('special_shift_weekday')
				.select('*')
				.eq('employee_id', employee.id);
			specialShiftWeekday = specialWeekdayData || [];

			// Get shift overlap flag from employee prop
			isShiftOverlappingNextDay = employee.is_shift_overlapping_next_day || false;
		} catch (error) {
			console.error('Error loading employee data:', error);
		} finally {
			loading = false;
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
		if (!bufferValue) return '0 min';
		// If buffer is in hours (decimal), convert to minutes
		const minutes = Math.round(bufferValue * 60);
		return `${minutes} min`;
	}

	function formatTime12Hour(timeString: string): string {
		if (!timeString) return '-';
		// Parse time string directly without Date object to avoid timezone conversion
		const [hoursStr, minutesStr] = timeString.split(':');
		let hour = parseInt(hoursStr);
		const minutes = minutesStr;
		const ampm = hour >= 12 ? 'PM' : 'AM';
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

	function getDayName(dayNum: number): string {
		const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
		return days[dayNum] || 'Unknown';
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
		const shiftEndMinutes = timeToMinutes(applicableShift.shift_end_time);
		
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
			
			// Extend end date by 1 day to capture overnight shift checkouts
			const extendedEndDate = new Date(endDate);
			extendedEndDate.setDate(extendedEndDate.getDate() + 1);
			const extendedEndDateStr = extendedEndDate.toISOString().split('T')[0];

			// Now query with extended date range
			const { data, error } = await supabase
				.from('processed_fingerprint_transactions')
				.select('*')
				.eq('center_id', employee.id)
				.gte('punch_date', startDate)
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
		}
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
		
		// Create pairs for each shift date
		Object.keys(groupedByShiftDate).sort().forEach(shiftDate => {
			const shiftTransactions = groupedByShiftDate[shiftDate];
			
			// Sort transactions within each shift by calendar date (chronologically)
			// This ensures check-in (earlier calendar date) comes before check-out (later calendar date)
			shiftTransactions.sort((a, b) => {
				const aDate = new Date(`${a.calendarDate.split('-').reverse().join('-')}`);
				const bDate = new Date(`${b.calendarDate.split('-').reverse().join('-')}`);
				return aDate.getTime() - bDate.getTime();
			});
			
			let i = 0;
			
			while (i < shiftTransactions.length) {
				const txn = shiftTransactions[i];
				
					if (txn.status === 'Check In') {
					// Look for corresponding checkout in the same shift
					let checkOutTxn = null;
					let checkOutCalendarDate = null;
					
					if (i + 1 < shiftTransactions.length) {
						const nextTxn = shiftTransactions[i + 1];
						if (nextTxn.status === 'Check Out') {
							checkOutTxn = nextTxn;
							checkOutCalendarDate = nextTxn.calendarDate;
						}
					}
					
					const pair = {
						checkInTxn: txn,
						checkInDate: shiftDate,
						checkInEarlyLateTime: calculateEarlyLateForCheckIn(txn.punch_time, getApplicableShift(shiftDate)),
						checkOutTxn: checkOutTxn,
						checkOutDate: shiftDate,
						checkOutCalendarDate: checkOutCalendarDate,
						workedTime: checkOutTxn ? calculateWorkedTime(txn.punch_time, checkOutTxn.punch_time) : null,
						lateEarlyTime: checkOutTxn ? calculateLateTime(checkOutTxn.punch_time, getApplicableShift(shiftDate)) : { late: 0, early: 0 },
						checkOutMissing: !checkOutTxn
					};
					
					pairs.push(pair);
					i += checkOutTxn ? 2 : 1;
				} else {
					// Standalone checkout (check-in was before the query range)
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
					<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">Employee ID</div>
					<div class="text-base font-bold text-slate-900">{employee.id}</div>
				</div>

				<div class="bg-white rounded-lg p-3 shadow-sm border border-blue-100">
					<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">Full Name</div>
					<div class="text-sm font-semibold text-slate-900">
						{$locale === 'ar' ? employee.name_ar || employee.name_en : employee.name_en}
					</div>
				</div>

				<div class="bg-white rounded-lg p-3 shadow-sm border border-blue-100">
					<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">Branch</div>
					<div class="text-sm font-semibold text-slate-900">
						{$locale === 'ar' ? employee.branch_name_ar || employee.branch_name_en : employee.branch_name_en}
					</div>
				</div>

				<div class="bg-white rounded-lg p-3 shadow-sm border border-blue-100">
					<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">Nationality</div>
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
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">Shift Start</div>
						<div class="text-sm font-semibold text-slate-900">{formatTime12Hour(regularShift.shift_start_time) || '-'}</div>
					</div>

					<div class="bg-white rounded-lg p-3 shadow-sm border border-green-100">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">Start Buffer</div>
						<div class="text-sm font-semibold text-slate-900">{formatBufferMinutes(regularShift.shift_start_buffer)}</div>
					</div>

					<div class="bg-white rounded-lg p-3 shadow-sm border border-green-100">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">Shift End</div>
						<div class="text-sm font-semibold text-slate-900">{formatTime12Hour(regularShift.shift_end_time) || '-'}</div>
					</div>

					<div class="bg-white rounded-lg p-3 shadow-sm border border-green-100">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">End Buffer</div>
						<div class="text-sm font-semibold text-slate-900">{formatBufferMinutes(regularShift.shift_end_buffer)}</div>
					</div>

					<div class="bg-white rounded-lg p-3 shadow-sm border border-green-100">
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">Working Hours</div>
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
						<div class="text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1">Day Off</div>
						<div class="text-sm font-semibold text-slate-900">{dayOffWeekday.weekday !== undefined ? getDayName(dayOffWeekday.weekday) : '-'}</div>
					</div>
				</div>
			</div>
		{/if}

		<!-- Date Range Filter Section -->
		<div class="bg-gradient-to-r from-purple-50 to-purple-100 border-l-4 border-purple-600 rounded-lg p-4">
			<h3 class="text-sm font-bold text-slate-800 mb-3 uppercase tracking-wide">Load Fingerprint Transactions</h3>
			<div class="grid grid-cols-1 md:grid-cols-3 gap-3">
				<div>
					<label class="block text-xs font-semibold text-slate-600 mb-2">Start Date</label>
					<input 
						type="date" 
						bind:value={startDate}
						class="w-full px-3 py-2 border border-purple-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
					/>
				</div>
				<div>
					<label class="block text-xs font-semibold text-slate-600 mb-2">End Date</label>
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
						{loadingTransactions ? 'Loading...' : 'Load'}
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
				{#each punchPairs as pair, idx (pair.checkInTxn?.id || pair.checkOutTxn?.id)}
					{#if pair.checkInTxn}
						<!-- Paired Check-In/Check-Out (always show under check-in date) -->
						<div class="border border-slate-300 rounded-lg overflow-hidden">
							<div class="bg-blue-600 text-white px-4 py-2 font-bold flex items-center justify-between">
								<span>{pair.checkInDate}</span>
								<div class="flex gap-2">
									{#if isOfficialDayOff(pair.checkInDate)}
										<span class="px-3 py-1 bg-red-500 rounded-full text-sm font-semibold">Official Day Off</span>
									{/if}
									{#if isSpecificDayOff(pair.checkInDate)}
										<span class="px-3 py-1 bg-orange-500 rounded-full text-sm font-semibold">Day Off</span>
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
												Check In
											</span>
											{#if pair.checkInMissing}
												<span class="px-3 py-1 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800">
													Check-In Missing
												</span>
											{/if}										{#if pair.checkInEarlyLateTime?.late > 0}
											<span class="px-2 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800">
												Late {Math.floor(pair.checkInEarlyLateTime.late / 60)}h {pair.checkInEarlyLateTime.late % 60}m
											</span>
										{/if}
										{#if pair.checkInEarlyLateTime?.early > 0}
											<span class="px-2 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800">
												Early {Math.floor(pair.checkInEarlyLateTime.early / 60)}h {pair.checkInEarlyLateTime.early % 60}m
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
														<div class="text-xs text-gray-500 mt-1">from {pair.checkOutCalendarDate}</div>
													{/if}
												</div>
											</div>
											<div class="flex items-center gap-2">
												<span class="px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800">
													Check Out
												</span>
												{#if pair.checkOutMissing}
													<span class="px-3 py-1 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800">
														Check-Out Missing
													</span>
												{/if}
												{#if pair.lateEarlyTime?.late > 0}
													<span class="px-2 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800">
														Overtime {Math.floor(pair.lateEarlyTime.late / 60)}h {pair.lateEarlyTime.late % 60}m
													</span>
												{/if}
												{#if pair.lateEarlyTime?.early > 0}
													<span class="px-2 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800">
														Early {Math.floor(pair.lateEarlyTime.early / 60)}h {pair.lateEarlyTime.early % 60}m
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
													Worked: {pair.workedTime} {isWorkedEnough ? '✓' : '✗'}
												</span>
											</div>
										{/if}
									</div>
								{/if}
							</div>
						</div>
					{:else}
						<!-- Standalone Check-Out (Carryover from previous day) -->
						<div class="border border-slate-300 rounded-lg overflow-hidden">
							<div class="bg-blue-600 text-white px-4 py-2 font-bold flex items-center justify-between">
								<span>{pair.checkOutDate}</span>
								<div class="flex gap-2">
									{#if isOfficialDayOff(pair.checkOutDate)}
										<span class="px-3 py-1 bg-red-500 rounded-full text-sm font-semibold">Official Day Off</span>
									{/if}
									{#if isSpecificDayOff(pair.checkOutDate)}
										<span class="px-3 py-1 bg-orange-500 rounded-full text-sm font-semibold">Day Off</span>
									{/if}
								</div>
							</div>
							
							<div class="divide-y divide-slate-200">
								<div class="px-4 py-3 hover:bg-slate-50">
									<div class="flex items-center justify-between mb-2">
										<div class="flex items-center gap-3 flex-1">
											<div>
												<div class="font-mono text-sm font-semibold text-slate-900">{formatTime12Hour(pair.checkOutTxn.punch_time) || '-'}</div>
												{#if pair.checkOutCalendarDate && pair.checkOutCalendarDate !== pair.checkOutDate}
													<div class="text-xs text-gray-500 mt-1">from {pair.checkOutCalendarDate}</div>
												{/if}
											</div>
										</div>
										<div class="flex items-center gap-2">
											<span class="px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800">
												Check Out
											</span>
											{#if pair.checkInMissing}
												<span class="px-3 py-1 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800">
													Check-In Missing
												</span>
											{/if}
											{#if pair.lateEarlyTime?.late > 0}
												<span class="px-2 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800">
												Overtime {Math.floor(pair.lateEarlyTime.late / 60)}h {pair.lateEarlyTime.late % 60}m
												</span>
											{/if}
											{#if pair.lateEarlyTime?.early > 0}
												<span class="px-2 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800">
													Early {Math.floor(pair.lateEarlyTime.early / 60)}h {pair.lateEarlyTime.early % 60}m
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
				Total Punch Pairs: {punchPairs.length}
			</div>
		</div>
	{:else if !loadingTransactions && (startDate || endDate)}
		<div class="text-center py-8 text-slate-500">
			<p>No transactions found for the selected date range</p>
		</div>
	{/if}
	</div>
</div>

<style>
	.employee-analysis-window {
		background: white;
	}
</style>
