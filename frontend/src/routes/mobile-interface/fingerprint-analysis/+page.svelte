<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { page } from '$app/stores';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { initI18n, currentLocale, localeData, switchLocale } from '$lib/i18n';
	import { _ as t } from '$lib/i18n';

	let userData: any = null;
	let employeeId: string = ''; // Store the actual employee ID from hr_employee_master
	let regularShift: any = null;
	let dayOffWeekday: any = null;
	let dayOffDates: any[] = [];
	let specialShiftDateWise: any[] = [];
	let specialShiftWeekday: any[] = [];
	let isShiftOverlappingNextDay = false;
	let loading = true;
	let loadingTransactions = false;
	let startDate = getDefaultStartDate();
	let endDate = getDefaultEndDate();
	let transactionData: any[] = [];
	let punchPairs: any[] = [];
	let realtimeChannel: any = null;

	function getDefaultStartDate(): string {
		// Get 25th of previous month
		const today = new Date();
		const year = today.getMonth() === 0 ? today.getFullYear() - 1 : today.getFullYear();
		const month = today.getMonth() === 0 ? 11 : today.getMonth() - 1;
		const startDateObj = new Date(year, month, 25);
		return startDateObj.toISOString().split('T')[0];
	}

	function getDefaultEndDate(): string {
		// Get yesterday (day before current date)
		const today = new Date();
		const yesterday = new Date(today);
		yesterday.setDate(yesterday.getDate() - 1);
		return yesterday.toISOString().split('T')[0];
	}

	onMount(async () => {
		// Get logged-in user's data
		if ($currentUser) {
			userData = $currentUser;
			console.log('📱 Mobile Fingerprint Analysis - User UUID:', userData.id);
			
			// Fetch the actual employee ID from hr_employee_master
			await fetchEmployeeId();
			
			if (employeeId) {
				// Load employee data
				await loadEmployeeData();
				
				// Setup realtime subscriptions
				setupRealtime();
				
				// Load initial transactions for today
				await loadTransactions();
			}
		}
		
		loading = false;
	});

	async function fetchEmployeeId() {
		try {
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select('id')
				.eq('user_id', userData.id)
				.single();
			
			if (error) {
				console.error('Error fetching employee ID:', error);
				return;
			}
			
			if (data) {
				employeeId = data.id;
				console.log('✅ Employee ID fetched:', employeeId);
			}
		} catch (error) {
			console.error('Error fetching employee ID:', error);
		}
	}

	onDestroy(() => {
		if (realtimeChannel) {
			supabase.removeChannel(realtimeChannel);
		}
	});

	async function loadEmployeeData() {
		try {
			// Load regular shift data using the actual employee ID
			const { data: shiftData } = await supabase
				.from('regular_shift')
				.select('*')
				.eq('id', employeeId)
				.single();
			regularShift = shiftData;

			if (shiftData?.is_shift_overlapping_next_day) {
				isShiftOverlappingNextDay = true;
			}

			// Load day off weekday data
			const { data: dayOffWData } = await supabase
				.from('day_off_weekday')
				.select('*')
				.eq('employee_id', employeeId);
			dayOffWeekday = dayOffWData && dayOffWData.length > 0 ? dayOffWData[0] : null;

			// Load day off dates
			const { data: dayOffDatesData } = await supabase
				.from('day_off')
				.select('*, day_off_reasons(*)')
				.eq('employee_id', employeeId);
			dayOffDates = dayOffDatesData || [];

			// Load special shift date-wise
			const { data: specialDateData } = await supabase
				.from('special_shift_date_wise')
				.select('*')
				.eq('employee_id', employeeId);
			specialShiftDateWise = specialDateData || [];

			if (specialDateData?.some(s => s.is_shift_overlapping_next_day)) {
				isShiftOverlappingNextDay = true;
			}

			// Load special shift weekday
			const { data: specialWeekdayData } = await supabase
				.from('special_shift_weekday')
				.select('*')
				.eq('employee_id', employeeId);
			specialShiftWeekday = specialWeekdayData || [];

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
			.channel('mobile_fingerprint_analysis_changes')
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'regular_shift',
					filter: `id=eq.${employeeId}`
				},
				() => loadEmployeeData()
			)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'processed_fingerprint_transactions',
					filter: `center_id=eq.${employeeId}`
				},
				() => loadTransactions()
			)
			.subscribe();
	}

	async function loadTransactions() {
		loadingTransactions = true;
		try {
			const extendedStartDate = new Date(startDate);
			extendedStartDate.setDate(extendedStartDate.getDate() - 1);
			const extendedStartDateStr = extendedStartDate.toISOString().split('T')[0];

			const extendedEndDate = new Date(endDate);
			extendedEndDate.setDate(extendedEndDate.getDate() + 1);
			const extendedEndDateStr = extendedEndDate.toISOString().split('T')[0];

			const { data, error } = await supabase
				.from('processed_fingerprint_transactions')
				.select('*')
				.eq('center_id', employeeId)
				.gte('punch_date', extendedStartDateStr)
				.lte('punch_date', extendedEndDateStr)
				.order('punch_date', { ascending: false });

			if (error) {
				console.error('Error loading transactions:', error);
				transactionData = [];
			} else {
				transactionData = data || [];
				punchPairs = createPunchPairs(transactionData);
				punchPairs = fillMissingDatesInRange(punchPairs);
			}
		} catch (error) {
			console.error('Error loading transactions:', error);
			transactionData = [];
		} finally {
			loadingTransactions = false;
		}
	}

	function formatDateddmmyyyy(dateString: string): string {
		if (!dateString) return '-';
		const date = new Date(dateString);
		const day = String(date.getDate()).padStart(2, '0');
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const year = date.getFullYear();
		return `${day}-${month}-${year}`;
	}

	function formatTime12Hour(timeString: string): string {
		if (!timeString) return '-';
		const [hoursStr, minutesStr] = timeString.split(':');
		let hour = parseInt(hoursStr);
		const minutes = minutesStr;
		const ampm = hour >= 12 ? $t('common.pm') : $t('common.am');
		hour = hour % 12 || 12;
		return `${String(hour).padStart(2, '0')}:${minutes} ${ampm}`;
	}

	function timeToMinutes(timeStr: string): number {
		const parts = timeStr.split(':');
		const hours = parseInt(parts[0]);
		const minutes = parseInt(parts[1]);
		return hours * 60 + minutes;
	}

	function getDayNameFromDate(dateStr: string): number {
		const [day, month, year] = dateStr.split('-');
		const date = new Date(`${year}-${month}-${day}`);
		return date.getDay();
	}

	function getApplicableShift(dateStr: string) {
		const dayNum = getDayNameFromDate(dateStr);

		const dateWiseShift = specialShiftDateWise.find((shift) => {
			const [day, month, year] = dateStr.split('-');
			const formattedDate = `${year}-${month}-${day}`;
			return shift.shift_date === formattedDate;
		});
		if (dateWiseShift) {
			return dateWiseShift;
		}

		const weekdayShift = specialShiftWeekday.find((shift) => shift.weekday === dayNum);
		if (weekdayShift) {
			return weekdayShift;
		}

		return regularShift;
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

	function calculateEarlyLateForCheckIn(punchTime: string, applicableShift: any): { late: number; early: number } {
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
		const inMinutes = timeToMinutes(checkInTime);
		const outMinutes = timeToMinutes(checkOutTime);
		const diff = outMinutes - inMinutes;

		if (diff < 0) {
			// Overnight shift
			const overallDiff = (24 * 60) - inMinutes + outMinutes;
			const hours = Math.floor(overallDiff / 60);
			const minutes = overallDiff % 60;
			return `${hours}h ${minutes}m`;
		}

		const hours = Math.floor(diff / 60);
		const minutes = diff % 60;
		return `${hours}h ${minutes}m`;
	}

	function calculateWorkedMinutes(checkInTime: string, checkOutTime: string): number {
		const inMinutes = timeToMinutes(checkInTime);
		const outMinutes = timeToMinutes(checkOutTime);
		let diff = outMinutes - inMinutes;
		if (diff < 0) diff += (24 * 60);
		return diff;
	}

	function isOfficialDayOff(dateStr: string): boolean {
		if (!dayOffWeekday) return false;
		const dateWeekday = getDayNameFromDate(dateStr);
		return dateWeekday === dayOffWeekday.weekday;
	}

	function isSpecificDayOff(dateStr: string): boolean {
		const [day, month, year] = dateStr.split('-');
		const dateFormatted = `${year}-${month}-${day}`;
		return dayOffDates.some(d => d.day_off_date === dateFormatted);
	}

	function getSpecificDayOff(dateStr: string): any {
		const [day, month, year] = dateStr.split('-');
		const dateFormatted = `${year}-${month}-${day}`;
		return dayOffDates.find(d => d.day_off_date === dateFormatted);
	}

	function formatMinutesToHm(totalMinutes: number): string {
		const hours = Math.floor(totalMinutes / 60);
		const minutes = totalMinutes % 60;
		if (hours > 0) {
			return `${hours}h ${minutes}m`;
		}
		return `${minutes}m`;
	}

	function calculateLateTime(punchTime: string, applicableShift: any, punchCalendarDate?: string, shiftDate?: string): { late: number; early: number } {
		if (!applicableShift) return { late: 0, early: 0 };

		let punchMinutes = timeToMinutes(punchTime);
		const shiftStartMinutes = timeToMinutes(applicableShift.shift_start_time);
		const shiftEndMinutes = timeToMinutes(applicableShift.shift_end_time);

		// If punch is on a different calendar date than the shift date, it's potentially next day
		if (punchCalendarDate && shiftDate && punchCalendarDate !== shiftDate) {
			// Basic next-day detection: if calendar date is after shift date
			const [pDay, pMonth, pYear] = punchCalendarDate.split('-').map(Number);
			const [sDay, sMonth, sYear] = shiftDate.split('-').map(Number);
			const pDate = new Date(pYear, pMonth - 1, pDay);
			const sDate = new Date(sYear, sMonth - 1, sDay);

			if (pDate > sDate) {
				punchMinutes += (24 * 60);
			}
		}
		
		// Check if this is an overnight shift (end time < start time)
		const isOvernightShift = shiftEndMinutes < shiftStartMinutes;
		
		if (isOvernightShift) {
			// For overnight shifts, checkout is in the early morning (0 to ~4 AM)
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
			// Checkout is late (after shift end time) - this is overtime
			return { late: punchMinutes - shiftEndMinutes, early: 0 };
		} else if (punchMinutes < shiftEndMinutes) {
			// Checkout is early (before shift end time)
			return { late: 0, early: shiftEndMinutes - punchMinutes };
		}
		
		return { late: 0, early: 0 };
	}

	function getPreviousDate(dateStr: string): string {
		const [day, month, year] = dateStr.split('-');
		const date = new Date(`${year}-${month}-${day}`);
		date.setDate(date.getDate() - 1);
		const d = String(date.getDate()).padStart(2, '0');
		const m = String(date.getMonth() + 1).padStart(2, '0');
		const y = date.getFullYear();
		return `${d}-${m}-${y}`;
	}

	function getNextDate(dateStr: string): string {
		const [day, month, year] = dateStr.split('-');
		const date = new Date(`${year}-${month}-${day}`);
		date.setDate(date.getDate() + 1);
		const d = String(date.getDate()).padStart(2, '0');
		const m = String(date.getMonth() + 1).padStart(2, '0');
		const y = date.getFullYear();
		return `${d}-${m}-${y}`;
	}

	function createPunchPairs(transactions: any[]): any[] {
		const pairs: any[] = [];

		const assignedTransactions = transactions.map(txn => {
			const calendarDate = formatDateddmmyyyy(txn.punch_date);
			const punchTime = txn.punch_time;
			let shiftDate = calendarDate;
			let status = 'Other';

			const calendarShift = getApplicableShift(calendarDate);
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

				if (punchMinutes >= checkInStart && punchMinutes <= checkInEnd) {
					status = 'Check In';
					shiftDate = calendarDate;
				} else if (isOvernightShift && checkOutStart < 0) {
					const adjustedCheckOutStart = checkOutStart + (24 * 60);

					if (punchMinutes >= 0 && punchMinutes <= checkOutEnd) {
						status = 'Check Out';
						shiftDate = getPreviousDate(calendarDate);
					} else if (punchMinutes >= adjustedCheckOutStart && punchMinutes < (24 * 60)) {
						status = 'Check Out';
						shiftDate = calendarDate;
					} else if (punchMinutes > checkInEnd && punchMinutes < adjustedCheckOutStart) {
						status = 'In Progress';
						shiftDate = calendarDate;
					} else {
						status = 'Other';
						shiftDate = calendarDate;
					}
				} else if (punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd) {
					status = 'Check Out';
					shiftDate = getPreviousDate(calendarDate);
				} else if (punchMinutes > checkInEnd && punchMinutes < checkOutStart) {
					status = 'In Progress';
					shiftDate = calendarDate;
				} else {
					status = 'Other';
					shiftDate = calendarDate;
				}
			} else {
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

		const startDateObj = new Date(startDate);
		const endDateObj = new Date(endDate);

		const filteredTransactions = assignedTransactions.filter(txn => {
			const shiftDateParts = txn.shiftDate.split('-');
			const txnDate = new Date(`${shiftDateParts[2]}-${shiftDateParts[1]}-${shiftDateParts[0]}`);
			return txnDate >= startDateObj && txnDate <= endDateObj;
		});

		const groupedByShiftDate: { [key: string]: any[] } = {};
		filteredTransactions.forEach(txn => {
			if (!groupedByShiftDate[txn.shiftDate]) {
				groupedByShiftDate[txn.shiftDate] = [];
			}
			groupedByShiftDate[txn.shiftDate].push(txn);
		});

		const consumedTransactions = new Set<string>();

		Object.keys(groupedByShiftDate).sort().forEach(shiftDate => {
			const shiftTransactions = groupedByShiftDate[shiftDate].filter(t => !consumedTransactions.has(t.id));

			const applicableShiftForDate = getApplicableShift(shiftDate);

			shiftTransactions.sort((a, b) => {
				const aDate = new Date(`${a.calendarDate.split('-').reverse().join('-')}`);
				const bDate = new Date(`${b.calendarDate.split('-').reverse().join('-')}`);
				const dateComparison = aDate.getTime() - bDate.getTime();

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
					let checkOutTxn = null;
					let checkOutCalendarDate = null;
					let nextIdx = i + 1;

					if (nextIdx < shiftTransactions.length) {
						const nextTxn = shiftTransactions[nextIdx];
						if (nextTxn.status === 'Check Out') {
							checkOutTxn = nextTxn;
							checkOutCalendarDate = nextTxn.calendarDate;
						} else if ((nextTxn.status === 'In Progress' || nextTxn.status === 'Other') && nextTxn.shiftDate === shiftDate) {
							checkOutTxn = nextTxn;
							checkOutCalendarDate = nextTxn.calendarDate;
						}
					}

					if (!checkOutTxn && !isShiftOverlappingNextDay) {
						const applicableShift = getApplicableShift(shiftDate);
						if (applicableShift) {
							const nextShiftDate = getNextDate(shiftDate);
							const nextShiftTransactions = groupedByShiftDate[nextShiftDate];

							if (nextShiftTransactions && nextShiftTransactions.length > 0) {
								const nextDayShift = getApplicableShift(nextShiftDate);
								if (nextDayShift) {
									const nextShiftStartMinutes = timeToMinutes(nextDayShift.shift_start_time);
									const nextShiftStartBuffer = (nextDayShift.shift_start_buffer || 0) * 60;
									const nextDayCheckInStart = nextShiftStartMinutes - nextShiftStartBuffer;

									for (const nextTxn of nextShiftTransactions) {
										if (consumedTransactions.has(nextTxn.id)) continue;

										const nextPunchMinutes = timeToMinutes(nextTxn.punch_time);

										if (nextPunchMinutes < nextDayCheckInStart) {
											checkOutTxn = nextTxn;
											checkOutCalendarDate = nextTxn.calendarDate;
											consumedTransactions.add(nextTxn.id);
											break;
										}
									}
								}
							}
						}
					}

					if (checkOutTxn && !consumedTransactions.has(txn.id)) {
						consumedTransactions.add(txn.id);
					}

					const checkOutApplicableShift = checkOutTxn ? getApplicableShift(shiftDate) : null;
					const workedMinutes = checkOutTxn ? calculateWorkedMinutes(txn.punch_time, checkOutTxn.punch_time) : 0;
					const expectedMinutes = (checkOutApplicableShift?.working_hours || 0) * 60;

					const pair = {
						checkInTxn: txn,
						checkInDate: shiftDate,
						checkInEarlyLateTime: calculateEarlyLateForCheckIn(txn.punch_time, getApplicableShift(shiftDate)),
						checkOutTxn: checkOutTxn,
						checkOutDate: shiftDate,
						checkOutCalendarDate: checkOutCalendarDate,
						workedTime: checkOutTxn ? calculateWorkedTime(txn.punch_time, checkOutTxn.punch_time) : null,
						isUnderHours: checkOutTxn && workedMinutes < expectedMinutes,
						lateEarlyTime: checkOutTxn ? calculateLateTime(checkOutTxn.punch_time, checkOutApplicableShift, checkOutCalendarDate, shiftDate) : { late: 0, early: 0 },
						checkOutMissing: !checkOutTxn,
						checkInMissing: false
					};

					pairs.push(pair);
					i += checkOutTxn ? 2 : 1;
				} else {
					if (!consumedTransactions.has(txn.id)) {
						const pair = {
							checkInTxn: null,
							checkInDate: null,
							checkOutTxn: txn,
							checkOutDate: shiftDate,
							checkOutCalendarDate: txn.calendarDate,
							workedTime: null,
							lateEarlyTime: calculateLateTime(txn.punch_time, getApplicableShift(shiftDate), txn.calendarDate, shiftDate),
							checkInMissing: true
						};

						pairs.push(pair);
						consumedTransactions.add(txn.id);
					}
					i += 1;
				}
			}
		});

		return pairs;
	}

	function fillMissingDatesInRange(pairs: any[]): any[] {
		const start = new Date(startDate);
		const end = new Date(endDate);
		const allDatePairs: any[] = [];
		const existingDates = new Set<string>();

		const filteredPairs = pairs.filter(pair => {
			const dateToCheck = pair.checkInDate || pair.checkOutDate;
			if (!dateToCheck) return false;

			const dateParts = dateToCheck.split('-');
			const pairDate = new Date(`${dateParts[2]}-${dateParts[1]}-${dateParts[0]}`);
			return pairDate >= start && pairDate <= end;
		});

		filteredPairs.forEach(pair => {
			if (pair.checkInDate) {
				existingDates.add(pair.checkInDate);
			}
			if (pair.checkOutDate && !pair.checkInDate) {
				existingDates.add(pair.checkOutDate);
			}
		});

		for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
			const dateStr = formatDateddmmyyyy(d.toISOString().split('T')[0]);

			if (!existingDates.has(dateStr)) {
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

		const allPairs = [...filteredPairs, ...allDatePairs];

		allPairs.sort((a, b) => {
			const aDate = a.checkInDate || a.checkOutDate;
			const bDate = b.checkInDate || b.checkOutDate;

			const aParts = aDate.split('-');
			const bParts = bDate.split('-');

			const aDateObj = new Date(`${aParts[2]}-${aParts[1]}-${aParts[0]}`);
			const bDateObj = new Date(`${bParts[2]}-${bParts[1]}-${bParts[0]}`);

			return bDateObj.getTime() - aDateObj.getTime();
		});

		return allPairs;
	}
</script>

<div class="fingerprint-analysis-page">

	<!-- Shift Info Card -->
	{#if regularShift}
		<div class="glass-card shift-summary">
			<div class="card-glow"></div>
			<div class="card-content">
				<div class="shift-title">
					<div class="pulse-indicator"></div>
					{$t('hr.shift.regularShift')}
				</div>
				<div class="shift-grid">
					<div class="shift-item">
						<span class="shift-label">{$t('hr.shift.shift_start')}</span>
						<span class="shift-value in">{formatTime12Hour(regularShift.shift_start_time)}</span>
					</div>
					<div class="shift-item">
						<span class="shift-label">{$t('hr.shift.shift_end')}</span>
						<span class="shift-value out">{formatTime12Hour(regularShift.shift_end_time)}</span>
					</div>
					<div class="shift-item span-2">
						<span class="shift-label">{$t('hr.shift.total_working_hours')}</span>
						<span class="shift-value total">{regularShift.working_hours} {$t('common.hours')}</span>
					</div>
				</div>
			</div>
		</div>
	{/if}

	<!-- Date Range Filter -->
	<div class="modern-filter">
		<div class="filter-inputs">
			<div class="filter-group">
				<label>{$t('hr.startDate')}</label>
				<input type="date" bind:value={startDate} />
			</div>
			<div class="filter-divider"></div>
			<div class="filter-group">
				<label>{$t('hr.endDate')}</label>
				<input type="date" bind:value={endDate} />
			</div>
		</div>
		<button on:click={loadTransactions} disabled={loadingTransactions} class="futuristic-btn">
			{#if loadingTransactions}
				<div class="loading-ring"><div></div><div></div><div></div><div></div></div>
				<span>{$t('common.loading')}</span>
			{:else}
				<span class="btn-text">{$t('hr.processFingerprint.load')}</span>
				<div class="btn-glow"></div>
			{/if}
		</button>
	</div>

	<!-- Transactions List -->
	<div class="timeline-container">
		{#if punchPairs.length > 0}
			{#each punchPairs as pair (pair.checkInTxn?.id || pair.checkOutTxn?.id || pair.checkInDate || pair.checkOutDate)}
				{@const shiftDate = pair.checkInDate || pair.checkOutDate}
				{@const isOfficial = isOfficialDayOff(shiftDate)}
				{@const isSpecific = isSpecificDayOff(shiftDate)}
				{@const dayOff = isSpecific ? getSpecificDayOff(shiftDate) : null}
				{@const isUnapprovedLeave = pair.isEmptyDate && !isOfficial && !isSpecific}

				<div class="timeline-card" class:is-day-off={isOfficial || (isSpecific && dayOff?.approval_status === 'approved')} class:is-unapproved={isUnapprovedLeave}>
					<div class="timeline-header">
						<div class="header-left">
							<div class="date-badge">{shiftDate}</div>
							{#if isOfficial}
								<span class="status-pill official">{$t('hr.shift.official_day_off')}</span>
							{:else if isSpecific}
								<span class="status-pill" class:approved={dayOff?.approval_status === 'approved'} class:unapproved={dayOff?.approval_status !== 'approved'}>
									{$t(dayOff?.approval_status === 'approved' ? 'hr.shift.approved_leave' : 'hr.shift.unapproved_leave')}
								</span>
							{:else if isUnapprovedLeave}
								<span class="status-pill unapproved">{$t('hr.shift.unapproved_leave')}</span>
							{/if}
						</div>
						{#if pair.workedTime}
							<div class="work-duration" class:under-hours={pair.isUnderHours}>
								<div class="status-indicator">
									{#if pair.isUnderHours}
										<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="indicator-svg"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
									{:else}
										<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="indicator-svg"><polyline points="20 6 9 17 4 12"></polyline></svg>
									{/if}
								</div>
								<span class="time-text">{pair.workedTime}</span>
							</div>
						{/if}
					</div>

					<div class="punch-slots">
						{#if pair.checkInTxn}
							<div class="slot-item check-in">
								<div class="slot-icon">
									<svg viewBox="0 0 24 24" fill="none"><path d="M15 3H19C20.1046 3 21 3.89543 21 5V19C21 20.1046 20.1046 21 19 21H15" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M10 17L15 12L10 7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M15 12H3" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
								</div>
								<div class="slot-data">
									<span class="slot-status">{$t('hr.processFingerprint.checkIn')}</span>
									<span class="slot-time">{formatTime12Hour(pair.checkInTxn.punch_time)}</span>
								</div>
								<div class="slot-badges-row">
									{#if pair.checkInEarlyLateTime}
										{#if pair.checkInEarlyLateTime.late > 0}
											<div class="slot-badge late">-{pair.checkInEarlyLateTime.late}m</div>
										{:else if pair.checkInEarlyLateTime.early > 0}
											<div class="slot-badge early">+{pair.checkInEarlyLateTime.early}m</div>
										{/if}
									{/if}
								</div>
							</div>
						{:else if !pair.isEmptyDate && !pair.checkInTxn && pair.checkOutTxn}
							<div class="slot-item check-in missing">
								<div class="slot-icon">
									<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 3H19C20.1046 3 21 3.89543 21 5V19C21 20.1046 20.1046 21 19 21H15" stroke-linecap="round"/><path d="M10 17L15 12L10 7" stroke-linecap="round" stroke-linejoin="round"/><path d="M15 12H3" stroke-linecap="round" stroke-linejoin="round"/></svg>
								</div>
								<div class="slot-data">
									<span class="slot-status">{$t('hr.processFingerprint.checkIn')}</span>
									<span class="slot-time missing">{$t('hr.processFingerprint.checkin_missing')}</span>
								</div>
							</div>
						{/if}

						{#if pair.checkOutTxn}
							<div class="slot-item check-out">
								<div class="slot-icon">
									<svg viewBox="0 0 24 24" fill="none"><path d="M9 3H5C3.89543 3 3 3.89543 3 5V19C3 20.1046 3.89543 21 5 21H9" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M14 17L9 12L14 7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M9 12H21" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
								</div>
								<div class="slot-data">
									<span class="slot-status space-between">
										{$t('hr.processFingerprint.checkOut')}
										{#if pair.checkOutCalendarDate && pair.checkOutCalendarDate !== shiftDate}
											<span class="next-day-label">({pair.checkOutCalendarDate})</span>
										{/if}
									</span>
									<span class="slot-time">{formatTime12Hour(pair.checkOutTxn.punch_time)}</span>
								</div>
								<div class="slot-badges-row">
									{#if pair.lateEarlyTime}
										{#if pair.lateEarlyTime.early > 0}
											<div class="slot-badge warning">-{pair.lateEarlyTime.early}m</div>
										{:else if pair.lateEarlyTime.late > 0}
											<div class="slot-badge early">+{formatMinutesToHm(pair.lateEarlyTime.late)}</div>
										{/if}
									{/if}
								</div>
							</div>
						{:else if (pair.checkInTxn || !pair.isEmptyDate) && !pair.checkOutTxn}
							<div class="slot-item check-out missing">
								<div class="slot-icon">
									<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 3H5C3.89543 3 3 3.89543 3 5V19C3 20.1046 3.89543 21 5 21H9" stroke-linecap="round"/><path d="M14 17L9 12L14 7" stroke-linecap="round" stroke-linejoin="round"/><path d="M9 12H21" stroke-linecap="round" stroke-linejoin="round"/></svg>
								</div>
								<div class="slot-data">
									<span class="slot-status">{$t('hr.processFingerprint.checkOut')}</span>
									<span class="slot-time missing">{$t('hr.processFingerprint.checkout_missing')}</span>
								</div>
							</div>
						{/if}

						{#if pair.isEmptyDate}
							<div class="empty-slot">
								{#if isOfficial}
									<div class="empty-icon official">🏝️</div>
								{:else if isSpecific}
									<div class="empty-icon approved">🏖️</div>
								{:else}
									<div class="empty-icon missing">❓</div>
								{/if}
								<p>
									{#if isUnapprovedLeave}
										{$t('hr.processFingerprint.no_checkin_checkout_recorded')}
									{:else}
										{$t('hr.processFingerprint.no_transactions_recorded')}
									{/if}
								</p>
							</div>
						{/if}
					</div>
				</div>
			{/each}
		{:else if !loadingTransactions}
			<div class="no-results">
				<div class="no-results-icon">
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M21 21L15 15M17 10C17 13.866 13.866 17 10 17C6.13401 17 3 13.866 3 10C3 6.13401 6.13401 3 10 3C13.866 3 17 6.13401 17 10Z" stroke-linecap="round" stroke-linejoin="round"/></svg>
				</div>
				<p>{$t('hr.processFingerprint.no_transactions_found')}</p>
			</div>
		{/if}
	</div>
</div>

<style>
	:root {
		--futuristic-green: #10B981;
		--futuristic-orange: #F97316;
		--futuristic-white: #FFFFFF;
		--futuristic-bg: #F8FAFC;
		--futuristic-border: #E2E8F0;
		--futuristic-text: #1E293B;
		--futuristic-text-light: #64748B;
		--glass-bg: rgba(255, 255, 255, 0.8);
	}

	.fingerprint-analysis-page {
		padding: 1.25rem;
		background: var(--futuristic-bg);
		min-height: 100vh;
		font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
	}

	/* Futuristic Shift Card */
	.glass-card {
		background: var(--futuristic-white);
		border-radius: 1.5rem;
		padding: 1.5rem;
		position: relative;
		overflow: hidden;
		box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.05);
		border: 1px solid var(--futuristic-border);
		margin-bottom: 1.5rem;
	}

	.card-glow {
		position: absolute;
		top: -50%;
		left: -50%;
		width: 200%;
		height: 200%;
		background: radial-gradient(circle at center, rgba(16, 185, 129, 0.05) 0%, transparent 70%);
		pointer-events: none;
	}

	.shift-title {
		font-size: 0.75rem;
		font-weight: 700;
		color: var(--futuristic-text-light);
		text-transform: uppercase;
		letter-spacing: 0.1em;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 1.25rem;
	}

	.pulse-indicator {
		width: 8px;
		height: 8px;
		background: var(--futuristic-green);
		border-radius: 50%;
		box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.4);
		animation: pulse 2s infinite;
	}

	@keyframes pulse {
		0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); }
		70% { transform: scale(1); box-shadow: 0 0 0 10px rgba(16, 185, 129, 0); }
		100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
	}

	.shift-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1.25rem;
	}

	.shift-item {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.shift-item.span-2 { grid-column: span 2; }

	.shift-label {
		font-size: 0.7rem;
		color: var(--futuristic-text-light);
		font-weight: 500;
	}

	.shift-value {
		font-size: 1.125rem;
		font-weight: 800;
		color: var(--futuristic-text);
	}

	.shift-value.in { color: var(--futuristic-green); }
	.shift-value.out { color: var(--futuristic-orange); }
	.shift-value.total { font-size: 1.25rem; }

	/* Modern Filter */
	.modern-filter {
		background: var(--futuristic-white);
		border-radius: 1.25rem;
		padding: 1rem;
		margin-bottom: 1.5rem;
		border: 1px solid var(--futuristic-border);
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
	}

	.filter-inputs {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		margin-bottom: 1rem;
	}

	.filter-group {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.filter-divider {
		width: 1px;
		height: 24px;
		background: var(--futuristic-border);
	}

	.filter-group label {
		font-size: 0.65rem;
		font-weight: 600;
		color: var(--futuristic-text-light);
		text-transform: uppercase;
	}

	.filter-group input {
		border: none;
		background: transparent;
		font-size: 0.9rem;
		font-weight: 600;
		color: var(--futuristic-text);
		padding: 0;
		width: 100%;
		outline: none;
	}

	.futuristic-btn {
		width: 100%;
		background: var(--futuristic-orange);
		color: white;
		border: none;
		border-radius: 1rem;
		padding: 1rem;
		font-weight: 700;
		position: relative;
		overflow: hidden;
		transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.futuristic-btn:active { transform: scale(0.98); }

	.btn-glow {
		position: absolute;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
		transform: translateX(-100%);
		transition: transform 0.6s ease;
	}

	.futuristic-btn:hover .btn-glow { transform: translateX(100%); }

	/* Timeline List */
	.timeline-container {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.timeline-card {
		background: var(--futuristic-white);
		border-radius: 1.25rem;
		border: 1px solid var(--futuristic-border);
		overflow: hidden;
		transition: transform 0.2s ease;
	}

	.timeline-header {
		padding: 1rem 1.25rem;
		background: white;
		border-bottom: 1px solid var(--futuristic-bg);
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.header-left {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.status-pill {
		font-size: 0.65rem;
		font-weight: 800;
		padding: 0.2rem 0.6rem;
		border-radius: 2rem;
		text-transform: uppercase;
		letter-spacing: 0.02em;
	}

	.status-pill.official { background: #FEE2E2; color: #DC2626; border: 1px solid #FECACA; }
	.status-pill.approved { background: #D1FAE5; color: #059669; border: 1px solid #A7F3D0; }
	.status-pill.unapproved { background: #FEF3C7; color: #D97706; border: 1px solid #FDE68A; }

	.date-badge {
		font-size: 0.875rem;
		font-weight: 700;
		color: var(--futuristic-text);
		background: var(--futuristic-bg);
		padding: 0.375rem 0.75rem;
		border-radius: 0.75rem;
	}

	.timeline-card.is-day-off {
		border-left: 4px solid #10B981;
	}

	.timeline-card.is-unapproved {
		border-left: 4px solid #F97316;
	}

	.work-duration {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.8125rem;
		font-weight: 800;
		color: var(--futuristic-green);
		background: rgba(16, 185, 129, 0.08);
		padding: 0.35rem 0.75rem;
		border-radius: 2rem;
		transition: all 0.3s ease;
	}

	.work-duration.under-hours {
		color: #EF4444;
		background: rgba(239, 68, 68, 0.08);
	}

	.status-indicator {
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.indicator-svg {
		width: 14px;
		height: 14px;
	}

	.time-text {
		letter-spacing: -0.01em;
	}

	.clock-icon { width: 14px; height: 14px; }

	.punch-slots {
		padding: 0.75rem 1.25rem 1.25rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.slot-item {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem;
		border-radius: 1rem;
		background: var(--futuristic-bg);
	}

	.slot-icon {
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 0.75rem;
	}

	.check-in .slot-icon { background: rgba(16, 185, 129, 0.1); color: var(--futuristic-green); }
	.check-out .slot-icon { background: rgba(249, 115, 22, 0.1); color: var(--futuristic-orange); }

	.slot-icon svg { width: 18px; height: 18px; }

	.slot-data {
		flex: 1;
		display: flex;
		flex-direction: column;
	}

	.slot-status {
		font-size: 0.65rem;
		font-weight: 600;
		color: var(--futuristic-text-light);
		text-transform: uppercase;
	}

	.slot-time {
		font-size: 0.9375rem;
		font-weight: 700;
		color: var(--futuristic-text);
	}

	.slot-time.missing {
		color: #EF4444;
		font-size: 0.8rem;
		font-style: italic;
	}

	.slot-status.space-between {
		display: flex;
		justify-content: space-between;
		align-items: center;
		width: 100%;
	}

	.next-day-label {
		font-size: 0.6rem;
		color: var(--futuristic-orange);
		background: rgba(249, 115, 22, 0.05);
		padding: 0.1rem 0.3rem;
		border-radius: 0.25rem;
	}

	.slot-badges-row {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		align-items: flex-end;
	}

	.slot-badge {
		padding: 0.25rem 0.5rem;
		border-radius: 0.5rem;
		font-size: 0.75rem;
		font-weight: 700;
	}

	.slot-badge.late { background: #FEE2E2; color: #DC2626; }
	.slot-badge.early { background: #D1FAE5; color: #10B981; }
	.slot-badge.warning { background: #FFEDD5; color: #EA580C; }

	.empty-slot {
		padding: 1.5rem;
		text-align: center;
		color: var(--futuristic-text-light);
		font-size: 0.8125rem;
		font-weight: 500;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.75rem;
	}

	.empty-icon {
		font-size: 1.5rem;
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		background: var(--futuristic-bg);
	}

	.empty-icon.official { background: #FEE2E2; }
	.empty-icon.approved { background: #D1FAE5; }
	.empty-icon.missing { background: #FEF3C7; }

	.empty-ring {
		width: 24px;
		height: 24px;
		border: 2px dashed var(--futuristic-border);
		border-radius: 50%;
	}

	.no-results {
		padding: 4rem 2rem;
		text-align: center;
		color: var(--futuristic-text-light);
	}

	.no-results-icon {
		width: 48px;
		height: 48px;
		margin: 0 auto 1rem;
		color: var(--futuristic-border);
	}

	.loading-ring {
		display: inline-block;
		position: relative;
		width: 20px;
		height: 20px;
		margin-right: 0.75rem;
	}
	.loading-ring div {
		box-sizing: border-box;
		display: block;
		position: absolute;
		width: 16px;
		height: 16px;
		margin: 2px;
		border: 2px solid #fff;
		border-radius: 50%;
		animation: loading-ring 1.2s cubic-bezier(0.5, 0, 0.5, 1) infinite;
		border-color: #fff transparent transparent transparent;
	}
	.loading-ring div:nth-child(1) { animation-delay: -0.45s; }
	.loading-ring div:nth-child(2) { animation-delay: -0.3s; }
	.loading-ring div:nth-child(3) { animation-delay: -0.15s; }
	@keyframes loading-ring {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	@media (max-width: 640px) {
		.fingerprint-analysis-page { padding: 1rem; }
		.shift-value { font-size: 1rem; }
	}
</style>
