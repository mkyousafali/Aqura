<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import EmployeeAnalysisWindow from './EmployeeAnalysisWindow.svelte';
	import XLSX from 'xlsx-js-style';

	export let windowId: string;

	interface Employee {
		id: string;
		name_en: string;
		name_ar: string;
		current_branch_id: string;
		branch_name_en?: string;
		branch_name_ar?: string;
		employment_status: string;
		nationality_id?: string;
		nationality_name_en?: string;
	}

	let loading = false;
	let startDate = '';
	let endDate = '';
	let employees: Employee[] = [];
	let branches: any[] = [];
	let selectedBranch: any = '';
	let searchQuery = '';
	
	let analysisData: any[] = [];
	let datesInRange: string[] = [];
	let exporting = false;

	// Reactive filtering and sorting for the view
	$: filteredAnalysisData = analysisData
		.filter(row => {
			const matchesSearch = !searchQuery || 
				String(row.employeeId).toLowerCase().includes(searchQuery.toLowerCase()) || 
				row.employeeName.toLowerCase().includes(searchQuery.toLowerCase());
			
			const matchesBranch = !selectedBranch || String(row.currentBranchId) === String(selectedBranch);
			
			return matchesSearch && matchesBranch;
		})
		.sort((a, b) => {
			// Sort logic: Saudi Arabia first, then by nationality name, then by employee ID
			const aIsSaudi = a.nationality?.toLowerCase() === 'saudi arabia';
			const bIsSaudi = b.nationality?.toLowerCase() === 'saudi arabia';
			
			if (aIsSaudi && !bIsSaudi) return -1;
			if (!aIsSaudi && bIsSaudi) return 1;
			
			// If both are Saudi or both are non-Saudi, sort by nationality name
			const natCompare = (a.nationality || '').localeCompare(b.nationality || '');
			if (natCompare !== 0) return natCompare;
			
			// Finally sort by employee ID
			return String(a.employeeId).localeCompare(String(b.employeeId), undefined, { numeric: true });
		});

	// Cache for shifts and day offs to avoid repeated DB calls
	let employeeShifts: Map<string, any> = new Map();
	let employeeDayOffs: Map<string, any> = new Map();
	let employeeSpecialShiftsDateWise: Map<string, any[]> = new Map();
	let employeeSpecialShiftsWeekday: Map<string, any[]> = new Map();
	let employeeSpecificDayOffs: Map<string, any[]> = new Map();

	onMount(async () => {
		await loadInitialData();
		
		// Set default date range: 25th of previous month to yesterday
		const today = new Date();
		
		// Yesterday
		const yesterday = new Date(today);
		yesterday.setDate(today.getDate() - 1);
		endDate = yesterday.toISOString().split('T')[0];
		
		// 25th of previous month
		const prevMonth = new Date(today);
		prevMonth.setMonth(today.getMonth() - 1);
		prevMonth.setDate(25);
		startDate = prevMonth.toISOString().split('T')[0];

		// Automatic load if employees were found
		if (employees.length > 0) {
			await loadAnalysis();
		}
	});

	async function loadInitialData() {
		loading = true;
		try {
			// Load branches with location
			const { data: branchData } = await supabase.from('branches').select('id, name_en, name_ar, location_en, location_ar').order('name_en');
			branches = branchData || [];

			// Load employees with nationality
			const { data: empData } = await supabase
				.from('hr_employee_master')
				.select(`
					id,
					name_en,
					name_ar,
					current_branch_id,
					employment_status,
					nationality_id,
					nationalities (
						name_en
					)
				`)
				.eq('employment_status', 'Job (With Finger)');
			
			employees = (empData || []).map(e => ({
				...e,
				nationality_name_en: (e as any).nationalities?.name_en
			}));
		} catch (error) {
			console.error('Error loading initial data:', error);
		} finally {
			loading = false;
		}
	}

	async function loadAnalysis() {
		if (!startDate || !endDate) {
			alert('Please select date range');
			return;
		}

		loading = true;
		analysisData = [];
		datesInRange = [];

		// Generate date range
		const start = new Date(startDate);
		const end = new Date(endDate);
		for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
			datesInRange.push(new Date(d).toISOString().split('T')[0]);
		}

		try {
			// 1. Fetch all needed data for all employees in range
			// We'll need fingerprint transactions, shifts, day offs, etc.
			const empIds = employees
				.filter(e => {
					const matchesBranch = !selectedBranch || String(e.current_branch_id) === String(selectedBranch);
					const matchesSearch = !searchQuery || 
						String(e.id).toLowerCase().includes(searchQuery.toLowerCase()) || 
						e.name_en.toLowerCase().includes(searchQuery.toLowerCase()) || 
						(e.name_ar && e.name_ar.includes(searchQuery));
					return matchesBranch && matchesSearch;
				})
				.map(e => e.id);

			if (empIds.length === 0) {
				loading = false;
				return;
			}

			// Extend date range by 1 day before and after to capture carryover punches
			const extendedStartDate = new Date(startDate);
			extendedStartDate.setDate(extendedStartDate.getDate() - 1);
			const extStart = extendedStartDate.toISOString().split('T')[0];
			
			const extendedEndDate = new Date(endDate);
			extendedEndDate.setDate(extendedEndDate.getDate() + 1);
			const extEnd = extendedEndDate.toISOString().split('T')[0];

			// Pre-fetch everything in bulk
			const [
				{ data: transactions },
				{ data: shifts },
				{ data: dayOffWeekdays },
				{ data: specialShiftsDW },
				{ data: specialShiftsWD },
				{ data: specificDayOffs }
			] = await Promise.all([
				supabase.from('processed_fingerprint_transactions').select('*').in('center_id', empIds).gte('punch_date', extStart).lte('punch_date', extEnd),
				supabase.from('regular_shift').select('*').in('id', empIds),
				supabase.from('day_off_weekday').select('*').in('employee_id', empIds),
				supabase.from('special_shift_date_wise').select('*').in('employee_id', empIds),
				supabase.from('special_shift_weekday').select('*').in('employee_id', empIds),
				supabase.from('day_off').select('*, day_off_reasons(*)').in('employee_id', empIds)
			]);

			// Organize data maps for efficient lookup
			employeeShifts = new Map(shifts?.map(s => [String(s.id), s]));
			employeeDayOffs = new Map(dayOffWeekdays?.map(d => [String(d.employee_id), d]));
			
			employeeSpecialShiftsDateWise = new Map();
			specialShiftsDW?.forEach(s => {
				const list = employeeSpecialShiftsDateWise.get(String(s.employee_id)) || [];
				list.push(s);
				employeeSpecialShiftsDateWise.set(String(s.employee_id), list);
			});

			employeeSpecialShiftsWeekday = new Map();
			specialShiftsWD?.forEach(s => {
				const list = employeeSpecialShiftsWeekday.get(String(s.employee_id)) || [];
				list.push(s);
				employeeSpecialShiftsWeekday.set(String(s.employee_id), list);
			});

			employeeSpecificDayOffs = new Map();
			specificDayOffs?.forEach(d => {
				const list = employeeSpecificDayOffs.get(String(d.employee_id)) || [];
				list.push(d);
				employeeSpecificDayOffs.set(String(d.employee_id), list);
			});

			const txnsByEmp = new Map();
			transactions?.forEach(t => {
				const list = txnsByEmp.get(String(t.center_id)) || [];
				list.push(t);
				txnsByEmp.set(String(t.center_id), list);
			});

			// 2. Perform analysis for each employee
			const results = [];
			const filteredEmps = employees.filter(e => empIds.includes(e.id));

			for (const emp of filteredEmps) {
				const empTxns = txnsByEmp.get(String(emp.id)) || [];
				const analysis = analyzeEmployee(emp, empTxns);
				results.push(analysis);
			}

			analysisData = results;

		} catch (error) {
			console.error('Error during analysis:', error);
		} finally {
			loading = false;
		}
	}

	function openEmployeeAnalysis(empId: string) {
		const emp = employees.find((e) => String(e.id) === String(empId));
		if (!emp) return;

		const winId = `employee-analysis-${emp.id}-${Date.now()}`;
		openWindow({
			id: winId,
			title: `${$t('hr.processFingerprint.analyse')}: ${emp.id}`,
			component: EmployeeAnalysisWindow,
			props: {
				employee: emp,
				windowId: winId,
				initialStartDate: startDate,
				initialEndDate: endDate
			},
			icon: '🔍',
			size: { width: 1000, height: 700 },
			position: {
				x: 100 + Math.random() * 100,
				y: 100 + Math.random() * 100
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function timeToMinutes(timeStr: string): number {
		if (!timeStr) return 0;
		const parts = timeStr.split(':');
		return parseInt(parts[0]) * 60 + parseInt(parts[1]);
	}

	function getApplicableShift(empId: string, dateStr: string) {
		const sId = String(empId);
		const dateObj = new Date(dateStr);
		const dayNum = dateObj.getDay();

		// Date-wise special shift
		const dateWise = employeeSpecialShiftsDateWise.get(sId)?.find(s => s.shift_date === dateStr);
		if (dateWise) return dateWise;

		// Weekday special shift
		const weekdayShift = employeeSpecialShiftsWeekday.get(sId)?.find(s => s.weekday === dayNum);
		if (weekdayShift) return weekdayShift;

		// Regular shift
		return employeeShifts.get(sId);
	}

	function isOfficialDayOff(empId: string, dateStr: string): boolean {
		const dayOffWD = employeeDayOffs.get(String(empId));
		if (!dayOffWD) return false;
		const dayNum = new Date(dateStr).getDay();
		return dayNum === dayOffWD.weekday;
	}

	function getSpecificDayOff(empId: string, dateStr: string): any {
		return employeeSpecificDayOffs.get(String(empId))?.find(d => d.day_off_date === dateStr);
	}

	function calculateWorkedMinutesRaw(checkInTime: string, checkOutTime: string): number {
		const checkInMinutes = timeToMinutes(checkInTime);
		const checkOutMinutes = timeToMinutes(checkOutTime);
		let diffMinutes = checkOutMinutes - checkInMinutes;
		if (diffMinutes < 0) diffMinutes += 24 * 60;
		return diffMinutes;
	}

	function getTransactionStatus(punchTime: string, shift: any): string {
		if (!shift) return 'Other';

		const punchMinutes = timeToMinutes(punchTime);
		const shiftStartMinutes = timeToMinutes(shift.shift_start_time);
		const shiftEndMinutes = timeToMinutes(shift.shift_end_time);
		const startBufferMinutes = (shift.shift_start_buffer || 0) * 60;
		const endBufferMinutes = (shift.shift_end_buffer || 0) * 60;

		const checkInStart = shiftStartMinutes - startBufferMinutes;
		const checkInEnd = shiftStartMinutes + startBufferMinutes;
		const checkOutStart = shiftEndMinutes - endBufferMinutes;
		const checkOutEnd = shiftEndMinutes + endBufferMinutes;

		if (punchMinutes >= checkInStart && punchMinutes <= checkInEnd) return 'Check In';
		if (punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd) return 'Check Out';
		if (punchMinutes > checkInEnd && punchMinutes < checkOutStart) return 'In Progress';
		return 'Other';
	}

	function calculateLateArrivalMinutes(punchTime: string, shift: any): number {
		if (!shift) return 0;
		const punchMinutes = timeToMinutes(punchTime);
		const shiftStartMinutes = timeToMinutes(shift.shift_start_time);
		const shiftEndMinutes = timeToMinutes(shift.shift_end_time);
		const isOvernight = shiftEndMinutes < shiftStartMinutes;

		if (isOvernight) {
			// If they punch in during the evening (normal start)
			if (punchMinutes >= shiftStartMinutes) {
				return punchMinutes - shiftStartMinutes;
			}
			// If they punch in during the early morning (very late start)
			// Check if it's closer to start or end
			if (punchMinutes < shiftEndMinutes) {
				// This is actually morning, and it's after the shift start (which was last night)
				// We treat this as total lateness (24h wrap)
				return (24 * 60 - shiftStartMinutes) + punchMinutes;
			}
		}
		return punchMinutes > shiftStartMinutes ? punchMinutes - shiftStartMinutes : 0;
	}

	function getPreviousDateStr(dateStr: string): string {
		const d = new Date(dateStr);
		d.setDate(d.getDate() - 1);
		return d.toISOString().split('T')[0];
	}

	function getNextDateStr(dateStr: string): string {
		const d = new Date(dateStr);
		d.setDate(d.getDate() + 1);
		return d.toISOString().split('T')[0];
	}

	function analyzeEmployee(emp: Employee, txns: any[]) {
		const dayByDay: any = {};
		
		// Get regular shift for layout
		const regShift = employeeShifts.get(String(emp.id));
		let shiftInfo = '';
		let expectedMinutesPerDay = 0;
		if (regShift) {
			shiftInfo = `${formatTime12Hour(regShift.shift_start_time)} - ${formatTime12Hour(regShift.shift_end_time)}`;
			const sStart = timeToMinutes(regShift.shift_start_time);
			const sEnd = timeToMinutes(regShift.shift_end_time);
			expectedMinutesPerDay = sEnd - sStart;
			if (expectedMinutesPerDay < 0) expectedMinutesPerDay += 24 * 60;
		}

		// 1. Assign transactions to shift dates (carryover logic)
		const assignedTransactions = txns.map(txn => {
			const calendarDate = txn.punch_date;
			const punchTime = txn.punch_time;
			const punchMinutes = timeToMinutes(punchTime);
			
			let shiftDate = calendarDate;
			let status = 'Other';
			
			// Get the applicable shift for this calendar date
			const calendarShift = getApplicableShift(emp.id, calendarDate);
			
			// CRITICAL: Check if this is a morning punch that belongs to the PREVIOUS day's overnight shift
			// If punch time is before the current day's shift check-in window starts, it might be an early checkout from previous day
			const calendarShiftStartMinutes = calendarShift ? timeToMinutes(calendarShift.shift_start_time) : 24 * 60;
			const calendarShiftStartBuffer = calendarShift ? (calendarShift.shift_start_buffer || 0) * 60 : 0;
			const calendarCheckInStart = calendarShiftStartMinutes - calendarShiftStartBuffer;
			
			if (punchMinutes < calendarCheckInStart) {  // Before current day's shift check-in window
				const prevDateStr = getPreviousDateStr(calendarDate);
				const prevShift = getApplicableShift(emp.id, prevDateStr);
				
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
							shiftDate = prevDateStr;
							status = 'Check Out';
							return { ...txn, calendarDate, shiftDate, status };
						}
					}
				}
			}

			return { ...txn, shiftDate: calendarDate, calendarDate };
		});

		const txnsByShiftDate = new Map();
		assignedTransactions.forEach(t => {
			const shift = getApplicableShift(emp.id, t.shiftDate);
			const punchMinutes = timeToMinutes(t.punch_time);
			const shiftStartMinutes = timeToMinutes(shift?.shift_start_time || '00:00');
			const shiftEndMinutes = timeToMinutes(shift?.shift_end_time || '00:00');
			const isOvernightShift = shiftEndMinutes < shiftStartMinutes;

			let status = '';
			let finalShiftDate = t.shiftDate;

			if (!shift) {
				status = 'Other';
			} else {
				const startBufferMinutes = (shift.shift_start_buffer || 0) * 60;
				const endBufferMinutes = (shift.shift_end_buffer || 0) * 60;
				const checkInStart = shiftStartMinutes - startBufferMinutes;
				const checkInEnd = shiftStartMinutes + startBufferMinutes;
				const checkOutStart = shiftEndMinutes - endBufferMinutes;
				const checkOutEnd = shiftEndMinutes + endBufferMinutes;

				if (isOvernightShift) {
					// For overnight shifts (e.g., 4 PM - 12 AM with wrapping checkout window)
					// Check-in window: shift_start ± buffer (e.g., 4 PM ± 3h = 1 PM to 7 PM)
					if (punchMinutes >= checkInStart && punchMinutes <= checkInEnd) {
						// Evening check-in window (within shift start ± buffer)
						status = 'Check In';
						finalShiftDate = t.shiftDate;
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
							finalShiftDate = t.shiftDate; // FIXED: Keep on same calendar date
						}
						// Case 2: Evening punch (21:00 to 23:59) = checkout for this shift
						else if (punchMinutes >= adjustedCheckOutStart && punchMinutes < (24 * 60)) {
							status = 'Check Out';
							finalShiftDate = t.shiftDate;
						}
						// Case 3: In progress
						else if (punchMinutes > checkInEnd && punchMinutes < adjustedCheckOutStart) {
							status = 'In Progress';
							finalShiftDate = t.shiftDate;
						} else {
							status = 'Other';
							finalShiftDate = t.shiftDate;
						}
					}
					// Checkout window doesn't cross midnight (normal overnight case)
					else if (punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd) {
						status = 'Check Out';
						finalShiftDate = t.shiftDate;
					}
					else {
						status = 'Other';
						finalShiftDate = t.shiftDate;
					}
				} else {
					// Normal shift (e.g., 9 AM - 6 PM)
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

			const list = txnsByShiftDate.get(finalShiftDate) || [];
			list.push({ ...t, status, shiftDate: finalShiftDate });
			txnsByShiftDate.set(finalShiftDate, list);
		});

		for (const date of datesInRange) {
			const shift = getApplicableShift(emp.id, date);
			let allTransactions = txnsByShiftDate.get(date) || [];
			
			const isOff = isOfficialDayOff(emp.id, date);
			const specOff = getSpecificDayOff(emp.id, date);
			const isApprovedOff = specOff && specOff.approval_status === 'approved';
			const isPendingOff = specOff && (!specOff.approval_status || specOff.approval_status === 'pending');
			const isRejectedOff = specOff && specOff.approval_status === 'rejected';

			let workedMins = 0;
			let lateMins = 0;
			let underMins = 0;
			let isIncomplete = false;
			let status = '';

			if (isOff) {
				status = 'Official Day Off';
			} else if (isApprovedOff) {
				// Check deduction status for approved leaves
				if (specOff.is_deductible_on_salary) {
					status = 'Approved Leave (Deductible)';
				} else {
					status = 'Approved Leave (No Deduction)';
				}
			} else if (isPendingOff) {
				status = 'Pending Approval';
				// Don't count in any total for pending
			} else if (isRejectedOff && allTransactions.length === 0) {
				// Only show rejected status if employee didn't work that day
				// Check deduction status for rejected leaves
				if (specOff.is_deductible_on_salary) {
					status = 'Rejected-Deducted';
				} else {
					status = 'Rejected-Not Deducted';
				}
				// Don't count in any total for rejected
			} else if (allTransactions.length === 0) {
				status = 'Absent';
			} else {
				// DEDUPLICATION: Keep only the last punch per status type
				// BUT: If there are multiple punches of the same status and NO complementary punch exists,
				// keep all of them so they can be paired together (e.g., two Check Ins can become check-in/check-out)
				const allCheckIns = allTransactions.filter(t => t.status === 'Check In');
				const allCheckOuts = allTransactions.filter(t => t.status === 'Check Out');
				const allOthers = allTransactions.filter(t => t.status !== 'Check In' && t.status !== 'Check Out');
				
				let filteredTransactions: any[] = [];
				
				// If we have multiple Check Ins but NO Check Outs, keep all Check Ins (they can be paired together)
				if (allCheckIns.length >= 2 && allCheckOuts.length === 0) {
					filteredTransactions.push(...allCheckIns);
				} else if (allCheckIns.length > 0) {
					// Normal case: deduplicate check-ins, keep latest
					const checkInMap: { [key: string]: any } = {};
					allCheckIns.forEach(txn => {
						const key = `${txn.shiftDate}-${txn.calendarDate}`;
						if (!checkInMap[key] || new Date(txn.created_at) > new Date(checkInMap[key].created_at)) {
							checkInMap[key] = txn;
						}
					});
					filteredTransactions.push(...Object.values(checkInMap));
				}
				
				// If we have multiple Check Outs but NO Check Ins, keep all Check Outs (they can be paired together)
				if (allCheckOuts.length >= 2 && allCheckIns.length === 0) {
					filteredTransactions.push(...allCheckOuts);
				} else if (allCheckOuts.length > 0) {
					// Normal case: deduplicate check-outs, keep latest
					const checkOutMap: { [key: string]: any } = {};
					allCheckOuts.forEach(txn => {
						const key = `${txn.shiftDate}-${txn.calendarDate}`;
						if (!checkOutMap[key] || new Date(txn.created_at) > new Date(checkOutMap[key].created_at)) {
							checkOutMap[key] = txn;
						}
					});
					filteredTransactions.push(...Object.values(checkOutMap));
				}
				
				// Keep all "In Progress" and "Other" transactions
				filteredTransactions.push(...allOthers);

				// Sort by punch time
				filteredTransactions.sort((a, b) => {
					if (a.calendarDate !== b.calendarDate) return a.calendarDate.localeCompare(b.calendarDate);
					return a.punch_time.localeCompare(b.punch_time);
				});

				// Separate by status: Check In transactions, Check Out transactions, Other transactions
				const checkInTransactions = filteredTransactions.filter(t => t.status === 'Check In');
				const checkOutTransactions = filteredTransactions.filter(t => t.status === 'Check Out');
				const otherTransactions = filteredTransactions.filter(t => t.status !== 'Check In' && t.status !== 'Check Out');

				// Pair Check-In with Check-Out
				const pairs = [];
				
				// Special case: If we have multiple Check Ins but NO Check Outs, pair them together
				if (checkInTransactions.length >= 2 && checkOutTransactions.length === 0) {
					// Pair consecutive check-ins: first is check-in, second is check-out
					for (let i = 0; i < checkInTransactions.length - 1; i += 2) {
						pairs.push({ in: checkInTransactions[i], out: checkInTransactions[i + 1] });
					}
					// If odd number, last one is incomplete
					if (checkInTransactions.length % 2 === 1) {
						pairs.push({ in: checkInTransactions[checkInTransactions.length - 1], out: null });
					}
				}
				// Special case: If we have multiple Check Outs but NO Check Ins, pair them together
				else if (checkOutTransactions.length >= 2 && checkInTransactions.length === 0) {
					// Pair consecutive check-outs: first is check-in, second is check-out
					for (let i = 0; i < checkOutTransactions.length - 1; i += 2) {
						pairs.push({ in: checkOutTransactions[i], out: checkOutTransactions[i + 1] });
					}
					// If odd number, last one is incomplete
					if (checkOutTransactions.length % 2 === 1) {
						pairs.push({ in: null, out: checkOutTransactions[checkOutTransactions.length - 1] });
					}
				}
				// Normal case: pair Check Ins with Check Outs
				else {
					const pairCount = Math.min(checkInTransactions.length, checkOutTransactions.length);

					for (let i = 0; i < pairCount; i++) {
						pairs.push({ in: checkInTransactions[i], out: checkOutTransactions[i] });
					}

					// Leftover Check-Ins (missing checkout)
					for (let i = pairCount; i < checkInTransactions.length; i++) {
						pairs.push({ in: checkInTransactions[i], out: null });
					}

					// Leftover Check-Outs (missing checkin)
					for (let i = pairCount; i < checkOutTransactions.length; i++) {
						pairs.push({ in: null, out: checkOutTransactions[i] });
					}
				}

				// Add other transactions as incomplete pairs
				otherTransactions.forEach(t => {
					pairs.push({ in: null, out: t });
				});

				// Calculate totals from pairs
				let hasIncompletePair = false;
				let missingType = '';

				pairs.forEach((p, idx) => {
					if (p.in && p.out) {
						workedMins += calculateWorkedMinutesRaw(p.in.punch_time, p.out.punch_time);
						if (idx === 0 && shift) {
							lateMins = calculateLateArrivalMinutes(p.in.punch_time, shift);
						}
					} else {
						hasIncompletePair = true;
						if (p.in) {
							missingType = 'Check-Out Missing';
							if (idx === 0 && shift) lateMins = calculateLateArrivalMinutes(p.in.punch_time, shift);
						} else {
							missingType = 'Check-In Missing';
						}
					}
				});

				if (hasIncompletePair) {
					isIncomplete = true;
					status = missingType;
				} else {
					if (shift) {
						const sStart = timeToMinutes(shift.shift_start_time);
						const sEnd = timeToMinutes(shift.shift_end_time);
						let expected = sEnd - sStart;
						if (expected < 0) expected += 24 * 60;
						if (workedMins < expected) underMins = expected - workedMins;
					}
					status = 'Worked';
				}
			}

			dayByDay[date] = { workedMins, status, lateMins, underMins };
		}

		return {
			employeeId: emp.id,
			employeeName: $locale === 'ar' ? emp.name_ar || emp.name_en : emp.name_en,
			currentBranchId: emp.current_branch_id,
			nationality: emp.nationality_name_en,
			shiftInfo,
			dayByDay
		};
	}

	function formatMinutes(mins: number): string {
		const hours = Math.floor(mins / 60);
		const minutes = mins % 60;
		return `${hours}${$t('common.h')} ${minutes}${$t('common.m')}`;
	}

	function formatTime12Hour(timeString: string | null): string {
		if (!timeString) return '-';
		const [hoursStr, minutesStr] = timeString.split(':');
		let hour = parseInt(hoursStr);
		const minutes = minutesStr;
		const ampm = hour >= 12 ? $t('common.pm') : $t('common.am');
		hour = hour % 12 || 12;
		return `${String(hour).padStart(2, '0')}:${minutes} ${ampm}`;
	}

	function getStatusLabel(status: string) {
		switch (status) {
			case 'Worked': return $t('hr.processFingerprint.status_worked');
			case 'Official Day Off': return $t('hr.processFingerprint.status_official_day_off');
			case 'Approved Leave (Deductible)': return $t('hr.processFingerprint.status_approved_leave_deductible') || 'Approved Leave (Deductible)';
			case 'Approved Leave (No Deduction)': return $t('hr.processFingerprint.status_approved_leave_no_deduction') || 'Approved Leave (No Deduction)';
			case 'Pending Approval': return $t('hr.processFingerprint.status_pending_approval') || 'Pending Approval';
			case 'Rejected-Deducted': return $t('hr.processFingerprint.status_rejected_deducted') || 'Rejected-Deducted';
			case 'Rejected-Not Deducted': return $t('hr.processFingerprint.status_rejected_not_deducted') || 'Rejected-Not Deducted';
			case 'Rejected Leave': return $t('hr.processFingerprint.status_rejected_leave') || 'Rejected Leave';
			case 'Approved Leave': return $t('hr.processFingerprint.status_approved_leave');
			case 'Unapproved Day Off': return $t('hr.processFingerprint.status_unapproved_day_off');
		case 'Absent': return $t('hr.processFingerprint.status_absent');
			case 'Incomplete': return $t('hr.processFingerprint.status_incomplete');
			case 'Check-In Missing': return $t('hr.processFingerprint.checkin_missing');
			case 'Check-Out Missing': return $t('hr.processFingerprint.checkout_missing');
			default: return status;
		}
	}

	function getDayNameFull(dateStr: string): string {
		const d = new Date(dateStr);
		const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
		return $t(`common.days.${days[d.getDay()]}`);
	}

	function formatDateOnly(dateStr: string): string {
		const d = new Date(dateStr);
		return `${d.getDate()}/${d.getMonth() + 1}`;
	}

	function exportToExcel() {
		if (filteredAnalysisData.length === 0 || datesInRange.length === 0) return;
		exporting = true;
		try {
			const daysEn = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
			const daysAr = ['\u0627\u0644\u0623\u062d\u062f', '\u0627\u0644\u0627\u062b\u0646\u064a\u0646', '\u0627\u0644\u062b\u0644\u0627\u062b\u0627\u0621', '\u0627\u0644\u0623\u0631\u0628\u0639\u0627\u0621', '\u0627\u0644\u062e\u0645\u064a\u0633', '\u0627\u0644\u062c\u0645\u0639\u0629', '\u0627\u0644\u0633\u0628\u062a'];

			const statusMapAr: Record<string, string> = {
				'Worked': '\u0639\u0645\u0644',
				'Absent': '\u063a\u0627\u0626\u0628',
				'Official Day Off': '\u0625\u062c\u0627\u0632\u0629 \u0631\u0633\u0645\u064a\u0629',
				'Approved Leave (Deductible)': '\u0625\u062c\u0627\u0632\u0629 \u0645\u0639\u062a\u0645\u062f\u0629 (\u062e\u0635\u0645)',
				'Approved Leave (No Deduction)': '\u0625\u062c\u0627\u0632\u0629 \u0645\u0639\u062a\u0645\u062f\u0629 (\u0628\u062f\u0648\u0646 \u062e\u0635\u0645)',
				'Pending Approval': '\u0628\u0627\u0646\u062a\u0638\u0627\u0631 \u0627\u0644\u0645\u0648\u0627\u0641\u0642\u0629',
				'Rejected-Deducted': '\u0645\u0631\u0641\u0648\u0636-\u0645\u062e\u0635\u0648\u0645',
				'Rejected-Not Deducted': '\u0645\u0631\u0641\u0648\u0636-\u063a\u064a\u0631 \u0645\u062e\u0635\u0648\u0645',
				'Check-In Missing': '\u062f\u062e\u0648\u0644 \u0645\u0641\u0642\u0648\u062f',
				'Check-Out Missing': '\u062e\u0631\u0648\u062c \u0645\u0641\u0642\u0648\u062f',
				'Incomplete': '\u063a\u064a\u0631 \u0645\u0643\u062a\u0645\u0644'
			};

			function fmtMinsLang(mins: number, lang: 'en' | 'ar'): string {
				if (!mins || mins <= 0) return '-';
				const h = Math.floor(mins / 60);
				const m = mins % 60;
				return lang === 'ar' ? `${h} \u0633 ${m} \u062f` : `${h}h ${m}m`;
			}

			function getDayLang(dateStr: string, lang: 'en' | 'ar'): string {
				const d = new Date(dateStr);
				const arr = lang === 'ar' ? daysAr : daysEn;
				return arr[d.getDay()] ?? '';
			}

			function fmtDate(dateStr: string): string {
				const d = new Date(dateStr);
				const dd = String(d.getDate()).padStart(2, '0');
				const mm = String(d.getMonth() + 1).padStart(2, '0');
				return `${dd}-${mm}-${d.getFullYear()}`;
			}

			function getStatusLang(status: string, lang: 'en' | 'ar'): string {
				if (lang === 'ar') return statusMapAr[status] || status;
				return status;
			}

			// --- Styling ---
			const headerStyle = {
				fill: { fgColor: { rgb: '1F4E79' } },
				font: { bold: true, color: { rgb: 'FFFFFF' }, sz: 11, name: 'Calibri' },
				alignment: { horizontal: 'center', vertical: 'center', wrapText: true },
				border: { top: { style: 'thin', color: { rgb: '000000' } }, bottom: { style: 'thin', color: { rgb: '000000' } }, left: { style: 'thin', color: { rgb: '000000' } }, right: { style: 'thin', color: { rgb: '000000' } } }
			};
			const cellBorder = { top: { style: 'thin', color: { rgb: 'D0D0D0' } }, bottom: { style: 'thin', color: { rgb: 'D0D0D0' } }, left: { style: 'thin', color: { rgb: 'D0D0D0' } }, right: { style: 'thin', color: { rgb: 'D0D0D0' } } };
			const evenRow = { fill: { fgColor: { rgb: 'F2F7FB' } }, font: { sz: 10, name: 'Calibri' }, alignment: { horizontal: 'center', vertical: 'center' }, border: cellBorder };
			const oddRow = { fill: { fgColor: { rgb: 'FFFFFF' } }, font: { sz: 10, name: 'Calibri' }, alignment: { horizontal: 'center', vertical: 'center' }, border: cellBorder };
			const frozenColStyle = { fill: { fgColor: { rgb: 'E8F0FE' } }, font: { sz: 10, name: 'Calibri', bold: true }, alignment: { horizontal: 'center', vertical: 'center' }, border: cellBorder };
			const totalsStyle = { fill: { fgColor: { rgb: '1F4E79' } }, font: { bold: true, color: { rgb: 'FFFFFF' }, sz: 11, name: 'Calibri' }, alignment: { horizontal: 'center', vertical: 'center' }, border: { top: { style: 'medium', color: { rgb: '000000' } }, bottom: { style: 'medium', color: { rgb: '000000' } }, left: { style: 'thin', color: { rgb: '000000' } }, right: { style: 'thin', color: { rgb: '000000' } } } };

			function getStatusCellStyle(status: string, base: any) {
				const s = status;
				if (s === 'Worked') return { ...base, font: { ...base.font, color: { rgb: '0D7A3E' }, bold: true } };
				if (s === 'Absent') return { ...base, font: { ...base.font, color: { rgb: 'CC0000' }, bold: true } };
				if (s === 'Official Day Off') return { ...base, font: { ...base.font, color: { rgb: '0066CC' }, bold: true } };
				if (s.includes('Approved Leave')) return { ...base, font: { ...base.font, color: { rgb: '7B5EA7' }, bold: true } };
				if (s === 'Pending Approval') return { ...base, font: { ...base.font, color: { rgb: 'B8860B' }, bold: true } };
				if (s.includes('Rejected')) return { ...base, font: { ...base.font, color: { rgb: 'CC0000' }, bold: true } };
				if (s.includes('Missing')) return { ...base, font: { ...base.font, color: { rgb: 'E67E00' }, bold: true } };
				return base;
			}

			function lateCellStyle(val: string, base: any) {
				if (val && val !== '-' && val !== '') return { ...base, font: { ...base.font, color: { rgb: 'CC0000' } } };
				return base;
			}

			// --- Build sheet ---
			function buildSheet(lang: 'en' | 'ar') {
				const isAr = lang === 'ar';

				// Fixed columns: #, ID, Name
				// Then for each date: 3 sub-columns (Status, Late, Underworked) or just the worked/status cell
				// Simpler approach: one column per date showing status + worked time, then summary columns at end

				// Headers row 1: fixed cols + date labels (merged across 1 col each)
				const fixedHeaders = isAr ? ['#', '\u0631\u0642\u0645 \u0627\u0644\u0645\u0648\u0638\u0641', '\u0627\u0644\u0627\u0633\u0645'] : ['#', 'ID', 'Name'];
				const summaryHeaders = isAr
					? ['\u0623\u064a\u0627\u0645 \u0627\u0644\u0639\u0645\u0644', '\u063a\u064a\u0627\u0628', '\u0625\u062c\u0627\u0632\u0627\u062a', '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u062a\u0623\u062e\u064a\u0631', '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0646\u0642\u0635']
					: ['Work Days', 'Absent', 'Leaves', 'Total Late', 'Total Underworked'];

				const numCols = fixedHeaders.length + datesInRange.length + summaryHeaders.length;

				// Title row
				const titleText = isAr
					? `\u062a\u0642\u0631\u064a\u0631 \u062a\u062d\u0644\u064a\u0644 \u062c\u0645\u064a\u0639 \u0627\u0644\u0645\u0648\u0638\u0641\u064a\u0646 | ${startDate} \u0625\u0644\u0649 ${endDate}`
					: `All Employees Analysis | ${startDate} to ${endDate}`;
				const titleStyle = {
					fill: { fgColor: { rgb: '0B3D6B' } },
					font: { bold: true, color: { rgb: 'FFFFFF' }, sz: 14, name: 'Calibri' },
					alignment: { horizontal: 'center', vertical: 'center' },
					border: cellBorder
				};

				const aoa: any[][] = [];

				// Row 0: Title
				aoa.push([titleText, ...Array(numCols - 1).fill('')]);
				// Row 1: Spacer
				aoa.push(Array(numCols).fill(''));

				// Row 2: Headers
				const headerRow = [
					...fixedHeaders,
					...datesInRange.map(d => `${fmtDate(d)}\n${getDayLang(d, lang)}`),
					...summaryHeaders
				];
				aoa.push(headerRow);

				// Data rows
				for (let i = 0; i < filteredAnalysisData.length; i++) {
					const row = filteredAnalysisData[i];
					let workDays = 0, absentDays = 0, leaveDays = 0, totalLate = 0, totalUnder = 0;

					const dateCells: string[] = [];
					for (const date of datesInRange) {
						const day = row.dayByDay[date];
						if (!day) { dateCells.push('-'); continue; }

						const st = day.status;
						if (st === 'Worked') {
							workDays++;
							totalLate += day.lateMins || 0;
							totalUnder += day.underMins || 0;
							let cell = fmtMinsLang(day.workedMins, lang);
							if (day.lateMins > 0) cell += `\n${isAr ? '\u062a\u0623\u062e\u064a\u0631' : 'Late'}: ${fmtMinsLang(day.lateMins, lang)}`;
							if (day.underMins > 0) cell += `\n${isAr ? '\u0646\u0642\u0635' : 'Under'}: ${fmtMinsLang(day.underMins, lang)}`;
							dateCells.push(cell);
						} else if (st === 'Absent') {
							absentDays++;
							totalLate += day.lateMins || 0;
							let cell = getStatusLang(st, lang);
							if (day.lateMins > 0) cell += `\n${isAr ? '\u062a\u0623\u062e\u064a\u0631' : 'Late'}: ${fmtMinsLang(day.lateMins, lang)}`;
							dateCells.push(cell);
						} else if (st.includes('Leave') || st.includes('Approved') || st === 'Official Day Off') {
							leaveDays++;
							dateCells.push(getStatusLang(st, lang));
						} else {
							// Missing, Pending, Rejected, etc.
							totalLate += day.lateMins || 0;
							let cell = getStatusLang(st, lang);
							if (day.lateMins > 0) cell += `\n${isAr ? '\u062a\u0623\u062e\u064a\u0631' : 'Late'}: ${fmtMinsLang(day.lateMins, lang)}`;
							dateCells.push(cell);
						}
					}

					const dataRow = [
						i + 1,
						row.employeeId,
						row.employeeName,
						...dateCells,
						workDays,
						absentDays,
						leaveDays,
						fmtMinsLang(totalLate, lang),
						fmtMinsLang(totalUnder, lang)
					];
					aoa.push(dataRow);
				}

				const ws = XLSX.utils.aoa_to_sheet(aoa);

				// Merge title
				ws['!merges'] = [{ s: { r: 0, c: 0 }, e: { r: 0, c: numCols - 1 } }];

				// Column widths
				const colWidths: any[] = [
					{ wch: 5 },  // #
					{ wch: 12 }, // ID
					{ wch: 22 }, // Name
					...datesInRange.map(() => ({ wch: 16 })),
					{ wch: 12 }, { wch: 10 }, { wch: 10 }, { wch: 14 }, { wch: 16 }
				];
				ws['!cols'] = colWidths;

				// Row heights
				const rowHeights: any[] = [{ hpt: 30 }, { hpt: 8 }, { hpt: 32 }];
				for (let i = 0; i < filteredAnalysisData.length; i++) rowHeights.push({ hpt: 38 });
				ws['!rows'] = rowHeights;

				// Apply styles
				const totalRows = aoa.length;
				for (let R = 0; R < totalRows; R++) {
					for (let C = 0; C < numCols; C++) {
						const ref = XLSX.utils.encode_cell({ r: R, c: C });
						if (!ws[ref]) ws[ref] = { v: '', t: 's' };

						if (R === 0) {
							ws[ref].s = titleStyle;
						} else if (R === 1) {
							ws[ref].s = { fill: { fgColor: { rgb: 'FFFFFF' } } };
						} else if (R === 2) {
							ws[ref].s = headerStyle;
						} else {
							// Data row
							const dataIdx = R - 3;
							const base = dataIdx % 2 === 0 ? { ...evenRow } : { ...oddRow };

							if (C < 3) {
								// Fixed columns (# / ID / Name)
								ws[ref].s = { ...frozenColStyle, fill: base.fill };
							} else if (C >= fixedHeaders.length && C < fixedHeaders.length + datesInRange.length) {
								// Date columns — color by status
								const dateIdx = C - fixedHeaders.length;
								const date = datesInRange[dateIdx];
								const rowData = filteredAnalysisData[dataIdx >= 0 ? dataIdx : 0];
								// Need actual row index
								const actualRow = filteredAnalysisData[dataIdx >= 0 && dataIdx < filteredAnalysisData.length ? dataIdx : 0];
								if (dataIdx < filteredAnalysisData.length) {
									const empRow = filteredAnalysisData[R - 3];
									if (empRow && empRow.dayByDay[date]) {
										const st = empRow.dayByDay[date].status;
										ws[ref].s = getStatusCellStyle(st, { ...base, alignment: { ...base.alignment, wrapText: true } });
									} else {
										ws[ref].s = { ...base, alignment: { ...base.alignment, wrapText: true } };
									}
								} else {
									ws[ref].s = { ...base, alignment: { ...base.alignment, wrapText: true } };
								}
							} else if (C >= fixedHeaders.length + datesInRange.length) {
								// Summary columns
								const sumIdx = C - fixedHeaders.length - datesInRange.length;
								if (sumIdx === 3 || sumIdx === 4) {
									// Total Late / Total Underworked
									ws[ref].s = lateCellStyle(String(ws[ref].v || ''), base);
								} else if (sumIdx === 1) {
									// Absent count — red if > 0
									const v = Number(ws[ref].v) || 0;
									ws[ref].s = v > 0 ? { ...base, font: { ...base.font, color: { rgb: 'CC0000' }, bold: true } } : base;
								} else {
									ws[ref].s = base;
								}
							} else {
								ws[ref].s = base;
							}
						}
					}
				}

				return ws;
			}

			const wsEn = buildSheet('en');
			const wsAr = buildSheet('ar');

			const wb = XLSX.utils.book_new();
			XLSX.utils.book_append_sheet(wb, wsEn, 'All Employees EN');
			XLSX.utils.book_append_sheet(wb, wsAr, '\u062c\u0645\u064a\u0639 \u0627\u0644\u0645\u0648\u0638\u0641\u064a\u0646 AR');
			XLSX.writeFile(wb, `All_Employees_Analysis_${startDate}_to_${endDate}.xlsx`);
		} catch (err) {
			console.error('Export to Excel error:', err);
		} finally {
			exporting = false;
		}
	}

	function getStatusColor(status: string): string {
		switch (status) {
			case 'Worked': return 'text-emerald-600';
			case 'Incomplete': return 'text-red-500 font-bold';
			case 'Unapproved Day Off': return 'text-rose-700 font-bold';
		case 'Absent': return 'text-gray-700 font-bold';
			case 'Official Day Off': return 'text-blue-600';
			case 'Approved Leave': return 'text-indigo-600';
			case 'Approved Leave (Deductible)': return 'text-purple-600 font-semibold';
			case 'Approved Leave (No Deduction)': return 'text-indigo-500';
			case 'Pending Approval': return 'text-amber-600 font-semibold';
			case 'Rejected-Deducted': return 'text-red-700 font-bold';
			case 'Rejected-Not Deducted': return 'text-red-500 font-semibold';
			case 'Rejected Leave': return 'text-red-600 font-bold';
			default: return 'text-slate-400';
		}
	}
</script>

<div class="analyze-all-window flex flex-col h-full bg-slate-50">
	<!-- Header / Controls -->
	<div class="p-6 bg-white border-b border-slate-200 shadow-sm space-y-4">
		<div class="flex flex-wrap gap-4 items-end">
			<div class="flex-1 min-w-[200px]">
				<label for="branch-select" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.branch')}</label>
				<select id="branch-select" bind:value={selectedBranch} class="w-full px-3 py-2 border rounded-lg text-sm">
					<option value="">{$t('hr.allBranches')}</option>
					{#each branches as branch}
						<option value={branch.id}>
							{$locale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en} 
							{#if branch.location_en || branch.location_ar}
								({$locale === 'ar' ? (branch.location_ar || branch.location_en) : branch.location_en})
							{/if}
						</option>
					{/each}
				</select>
			</div>

			<div class="flex-1 min-w-[200px]">
				<label for="emp-search" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.shift.search_employee')}</label>
				<input id="emp-search" type="text" bind:value={searchQuery} placeholder="ID or Name..." class="w-full px-3 py-2 border rounded-lg text-sm" />
			</div>

			<div class="w-40">
				<label for="start-date" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.startDate')}</label>
				<input id="start-date" type="date" bind:value={startDate} class="w-full px-3 py-2 border rounded-lg text-sm" />
			</div>

			<div class="w-40">
				<label for="end-date" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.endDate')}</label>
				<input id="end-date" type="date" bind:value={endDate} class="w-full px-3 py-2 border rounded-lg text-sm" />
			</div>

			<button 
				on:click={loadAnalysis}
				disabled={loading}
				class="px-6 py-2 bg-emerald-600 text-white font-bold rounded-lg hover:bg-emerald-700 transition-colors disabled:bg-slate-300 h-[38px]"
			>
				{loading ? $t('hr.processFingerprint.processing') : $t('hr.processFingerprint.load_analysis')}
			</button>

			{#if filteredAnalysisData.length > 0}
				<button 
					on:click={exportToExcel}
					disabled={exporting}
					class="px-5 py-2 bg-blue-600 text-white font-bold rounded-lg hover:bg-blue-700 transition-colors disabled:bg-slate-300 h-[38px] flex items-center gap-2"
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
					{exporting ? $t('hr.processFingerprint.exporting') || 'Exporting...' : $t('hr.processFingerprint.export_excel') || 'Export Excel'}
				</button>
			{/if}

			<button 
				on:click={() => windowManager.closeWindow(windowId)}
				class="px-4 py-2 bg-slate-200 text-slate-700 font-bold rounded-lg hover:bg-slate-300 transition-colors h-[38px]"
			>
				{$t('common.close')}
			</button>
		</div>
	</div>

	<!-- Results Table -->
	<div class="flex-1 min-h-0 p-6 overflow-hidden">
		{#if analysisData.length > 0}
			<div class="h-full w-full bg-white rounded-xl shadow-lg border border-slate-200 overflow-auto custom-scrollbar">
				<table class="w-max min-w-full border-separate border-spacing-0 text-start text-sm table-fixed" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
					<thead class="sticky top-0 z-40 bg-slate-50">
						<tr>
							<th class="px-2 py-4 font-bold text-slate-700 border-b border-r w-[40px] sticky z-50 bg-slate-50 {$locale === 'ar' ? 'right-0' : 'left-0'}">
								<div class="flex justify-center italic text-[10px]">#</div>
							</th>
							<th class="px-4 py-4 font-bold text-slate-700 border-b border-r w-[100px] sticky z-50 bg-slate-50 {$locale === 'ar' ? 'right-[40px]' : 'left-[40px]'}">{$t('hr.employeeId')}</th>
							<th class="px-4 py-4 font-bold text-slate-700 border-b border-r w-[200px] sticky z-50 bg-slate-50 {$locale === 'ar' ? 'right-[140px]' : 'left-[140px]'}">{$t('hr.fullName')}</th>
							{#each datesInRange as date}
								<th class="px-3 py-2 font-bold text-slate-700 border-b border-r text-center w-[100px] whitespace-nowrap bg-slate-50">
									<div class="flex flex-col items-center">
										<span class="text-xs">{formatDateOnly(date)}</span>
										<span class="text-[9px] font-medium text-slate-500 capitalize">{getDayNameFull(date)}</span>
									</div>
								</th>
							{/each}
						</tr>
					</thead>
					<tbody class="divide-y divide-slate-200">
						{#each filteredAnalysisData as row}
							<tr class="transition-colors group even:bg-slate-100/80">
								<td class="px-2 py-3 border-r sticky z-20 bg-white group-even:bg-slate-100/80 group-hover:bg-emerald-100 flex justify-center items-center {$locale === 'ar' ? 'right-0' : 'left-0'}">
									<button 
										class="p-1 hover:bg-slate-200 rounded-full transition-colors text-blue-600"
										on:click={() => openEmployeeAnalysis(row.employeeId)}
										title={$t('hr.processFingerprint.analyse')}
									>
										<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
										</svg>
									</button>
								</td>
								<td class="px-4 py-3 font-mono font-medium text-slate-600 border-r sticky z-20 bg-white group-even:bg-slate-100/80 group-hover:bg-emerald-100 {$locale === 'ar' ? 'right-[40px]' : 'left-[40px]'}">
									{row.employeeId}
								</td>
								<td class="px-4 py-3 font-semibold text-slate-900 border-r sticky z-20 bg-white group-even:bg-slate-100/80 group-hover:bg-emerald-100 {$locale === 'ar' ? 'right-[140px]' : 'left-[140px]'}">
									<div class="flex flex-col">
										<span>{row.employeeName}</span>
										{#if row.shiftInfo}
											<span class="text-[9px] text-slate-500 font-normal">{row.shiftInfo}</span>
										{/if}
									</div>
								</td>
								{#each datesInRange as date}
									<td class="px-3 py-3 border-r text-center text-[10px] leading-tight w-[100px] group-hover:bg-emerald-100/50 transition-colors">
										<div class={getStatusColor(row.dayByDay[date].status)}>
											{#if row.dayByDay[date].status === 'Worked'}
												<div class="font-bold whitespace-nowrap {row.dayByDay[date].underMins > 0 ? 'text-red-700' : ''}">
													{formatMinutes(row.dayByDay[date].workedMins)}
												</div>
												{#if row.dayByDay[date].lateMins > 0}
													<div class="text-[8px] text-amber-700 font-bold">{$t('hr.processFingerprint.late_abbr')}: {formatMinutes(row.dayByDay[date].lateMins)}</div>
												{/if}
											{:else}
												<span class="whitespace-nowrap font-bold uppercase tracking-tight text-[8px]">{getStatusLabel(row.dayByDay[date].status)}</span>
											{#if row.dayByDay[date].lateMins > 0}
													<div class="text-[8px] text-amber-700 font-bold">{$t('hr.processFingerprint.late_abbr')}: {formatMinutes(row.dayByDay[date].lateMins)}</div>
												{/if}
											{/if}
										</div>
									</td>
								{/each}
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{:else if !loading}
			<div class="h-full flex flex-col items-center justify-center text-slate-400 space-y-4">
				<div class="text-6xl">📊</div>
				<p class="text-lg font-medium">{$t('hr.processFingerprint.select_range_to_begin')}</p>
			</div>
		{:else}
			<div class="h-full flex flex-col items-center justify-center space-y-4">
				<div class="w-12 h-12 border-4 border-emerald-600 border-t-transparent rounded-full animate-spin"></div>
				<p class="text-slate-500 font-medium">{$t('hr.processFingerprint.analyzing_all_moment')}</p>
			</div>
		{/if}
	</div>
</div>

<style>
	.analyze-all-window {
		user-select: none;
	}
	
	/* Custom scrollbar for better look in windows */
	::-webkit-scrollbar {
		width: 8px;
		height: 8px;
	}
	::-webkit-scrollbar-track {
		background: #f1f5f9;
	}
	::-webkit-scrollbar-thumb {
		background: #cbd5e1;
		border-radius: 4px;
	}
	::-webkit-scrollbar-thumb:hover {
		background: #94a3b8;
	}
	
	/* Ensure table can actually grow */
	table {
		min-width: 100%;
		border-collapse: separate;
	}
</style>