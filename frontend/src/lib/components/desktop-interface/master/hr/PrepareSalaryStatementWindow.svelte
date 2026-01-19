<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import EmployeeAnalysisWindow from './EmployeeAnalysisWindow.svelte';

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
	let editableWorkedDays: { [key: string]: string } = {};
	let basicSalaries: { [key: string]: number } = {};
	let paymentModes: { [key: string]: string } = {};
	let otherAllowances: { [key: string]: number } = {};
	let otherAllowancePaymentModes: { [key: string]: string } = {};
	let accommodationAllowances: { [key: string]: number } = {};
	let accommodationPaymentModes: { [key: string]: string } = {};
	let travelAllowances: { [key: string]: number } = {};
	let travelPaymentModes: { [key: string]: string } = {};
	let gosiDeductions: { [key: string]: number } = {};
	let foodAllowances: { [key: string]: number } = {};
	let foodPaymentModes: { [key: string]: string } = {};

	// Reactive filtering and sorting for the view
	$: filteredAnalysisData = analysisData
		.filter(row => {
			const matchesSearch = !searchQuery || 
				String(row.employeeId).toLowerCase().includes(searchQuery.toLowerCase()) || 
				row.employeeName.toLowerCase().includes(searchQuery.toLowerCase());
			
			const matchesBranch = !selectedBranch || String(row.currentBranchId) === String(selectedBranch);
			
			const isNotExcluded = row.employeeId !== 'EMP51';
			
			return matchesSearch && matchesBranch && isNotExcluded;
		})
		.sort((a, b) => {
			// 1. Sort by nationality first (Saudi Arabia first)
			const aIsSaudi = a.nationality?.toLowerCase() === 'saudi arabia';
			const bIsSaudi = b.nationality?.toLowerCase() === 'saudi arabia';
			
			if (aIsSaudi && !bIsSaudi) return -1;
			if (!aIsSaudi && bIsSaudi) return 1;
			
			// If both are Saudi or both are non-Saudi, sort by nationality name
			const natCompare = (a.nationality || '').localeCompare(b.nationality || '');
			if (natCompare !== 0) return natCompare;

			// 2. Within same nationality, sort by employment status
			const statusOrder: { [key: string]: number } = {
				'Job (With Finger)': 1,
				'Job (No Finger)': 2,
				'Remote Job': 3
			};
			const statusOrderA = statusOrder[a.employmentStatus] || 99;
			const statusOrderB = statusOrder[b.employmentStatus] || 99;
			if (statusOrderA !== statusOrderB) return statusOrderA - statusOrderB;
			
			// 3. Finally sort by employee ID
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
				.in('employment_status', ['Job (With Finger)', 'Job (No Finger)', 'Remote Job']);
			
			employees = (empData || []).map(e => ({
				...e,
				nationality_name_en: (e as any).nationalities?.name_en
			}));

			// Load basic salaries
			const { data: salaryData } = await supabase
				.from('hr_basic_salary')
				.select('employee_id, basic_salary, payment_mode, other_allowance, other_allowance_payment_mode, accommodation_allowance, accommodation_payment_mode, travel_allowance, travel_payment_mode, gosi_deduction, food_allowance, food_payment_mode');
			
			if (salaryData) {
				salaryData.forEach(item => {
					basicSalaries[item.employee_id] = item.basic_salary || 0;
					paymentModes[item.employee_id] = item.payment_mode || 'Bank';
					otherAllowances[item.employee_id] = item.other_allowance || 0;
					otherAllowancePaymentModes[item.employee_id] = item.other_allowance_payment_mode || 'Bank';
					accommodationAllowances[item.employee_id] = item.accommodation_allowance || 0;
					accommodationPaymentModes[item.employee_id] = item.accommodation_payment_mode || 'Bank';
					travelAllowances[item.employee_id] = item.travel_allowance || 0;
					travelPaymentModes[item.employee_id] = item.travel_payment_mode || 'Bank';
					gosiDeductions[item.employee_id] = item.gosi_deduction || 0;

					foodAllowances[item.employee_id] = item.food_allowance || 0;
					foodPaymentModes[item.employee_id] = item.food_payment_mode || 'Bank';
				});
			}
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
		
		let totalWorkedMinutes = 0;
		let totalUnderWorkedMinutes = 0;
		let totalLateMinutes = 0;
		let totalIncompleteDays = 0;
		let totalUnapprovedDaysOff = 0;
		let totalOfficialLeaveDays = 0;
		let totalApprovedDaysOff = 0;
		let totalCompleteDays = 0;

		// Get regular shift for layout
		const regShift = employeeShifts.get(String(emp.id));
		let shiftInfo = '';
		if (regShift) {
			shiftInfo = `${formatTime12Hour(regShift.shift_start_time)} - ${formatTime12Hour(regShift.shift_end_time)}`;
		}

		// 1. Assign transactions to shift dates (carryover logic)
		const assignedTransactions = txns.map(txn => {
			const calendarDate = txn.punch_date;
			const punchTime = txn.punch_time;
			const punchMinutes = timeToMinutes(punchTime);
			
			const prevDateStr = getPreviousDateStr(calendarDate);
			const prevShift = getApplicableShift(emp.id, prevDateStr);
			
			if (prevShift) {
				const isOverlap = prevShift.is_shift_overlapping_next_day || 
								 timeToMinutes(prevShift.shift_end_time) < timeToMinutes(prevShift.shift_start_time);
				
				if (isOverlap) {
					const shiftEndMinutes = timeToMinutes(prevShift.shift_end_time);
					const endBufferMinutes = (prevShift.shift_end_buffer || 0) * 60;
					const checkOutEnd = shiftEndMinutes + endBufferMinutes;
					
					if (punchMinutes >= 0 && punchMinutes <= checkOutEnd) {
						return { ...txn, shiftDate: prevDateStr, calendarDate };
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
					// For overnight shifts (e.g., 8 PM - 8 AM)
					if (punchMinutes >= checkInStart && punchMinutes <= checkInEnd) {
						// Evening check-in window (within shift start ± buffer)
						status = 'Check In';
						finalShiftDate = t.shiftDate;
				} else if (punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd) {
					// Morning check-out window (5 AM to 11 AM for 8 AM end time)
					status = 'Check Out';
					// Early morning checkouts belong to the PREVIOUS shift (started yesterday)
					finalShiftDate = getPreviousDateStr(t.shiftDate);
				} else if (checkOutStart < 0) {
					// Midnight crossing: if checkOutStart is negative, it means the window includes early morning
					const adjustedCheckOutStart = checkOutStart + (24 * 60);
					const adjustedCheckOutEnd = checkOutEnd + (24 * 60);
					// Early morning (0:00 to late morning)
					if (punchMinutes >= 0 && punchMinutes <= adjustedCheckOutEnd) {
						status = 'Check Out';
						finalShiftDate = getPreviousDateStr(t.shiftDate);
					}
					// In progress
					else if (punchMinutes > checkInEnd && punchMinutes < adjustedCheckOutStart) {
						status = 'In Progress';
						finalShiftDate = t.shiftDate;
					} else {
						status = 'Other';
						finalShiftDate = t.shiftDate;
					}
				} else {
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

			let workedMins = 0;
			let lateMins = 0;
			let underMins = 0;
			let isIncomplete = false;
			let status = '';

			if (isOff) {
				status = 'Official Day Off';
				totalApprovedDaysOff++;
			} else if (isApprovedOff) {
				status = 'Approved Leave';
				totalOfficialLeaveDays++;
			} else if (allTransactions.length === 0) {
				status = 'Unapproved Day Off';
				totalUnapprovedDaysOff++;
			} else {
				// DEDUPLICATION: Keep only the last punch per status type
				const shiftDateStatusMap: { [key: string]: any } = {};
				allTransactions.forEach(txn => {
					const key = `${txn.shiftDate}-${txn.status}`;
					if (!shiftDateStatusMap[key] || new Date(txn.created_at) > new Date(shiftDateStatusMap[key].created_at)) {
						shiftDateStatusMap[key] = txn;
					}
				});
				const filteredTransactions = Object.values(shiftDateStatusMap);

				// Sort by punch time
				filteredTransactions.sort((a, b) => {
					if (a.calendarDate !== b.calendarDate) return a.calendarDate.localeCompare(b.calendarDate);
					return a.punch_time.localeCompare(b.punch_time);
				});

				// Separate by status: Check In transactions, Check Out transactions, Other transactions
				const checkInTransactions = filteredTransactions.filter(t => t.status === 'Check In');
				const checkOutTransactions = filteredTransactions.filter(t => t.status === 'Check Out');
				const otherTransactions = filteredTransactions.filter(t => t.status !== 'Check In' && t.status !== 'Check Out');

				// Pair Check-In with Check-Out: min(checkIns.length, checkOuts.length) pairs
				const pairs = [];
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
					totalIncompleteDays++;
					status = missingType;
				} else {
					if (shift) {
						const sStart = timeToMinutes(shift.shift_start_time);
						const sEnd = timeToMinutes(shift.shift_end_time);
						let expected = sEnd - sStart;
						if (expected < 0) expected += 24 * 60;
						if (workedMins < expected) underMins = expected - workedMins;
						totalCompleteDays++;
					}
					status = 'Worked';
				}

				totalWorkedMinutes += workedMins;
				totalLateMinutes += lateMins;
				totalUnderWorkedMinutes += underMins;
			}

			dayByDay[date] = { workedMins, status, lateMins, underMins };
		}

		let actualWorkedDaysCount = 0;
		Object.values(dayByDay).forEach(d => {
			if (d.workedMins > 0) actualWorkedDaysCount++;
		});

		const totalExpectedWorkDays = datesInRange.length - totalApprovedDaysOff;

		return {
			employeeId: emp.id,
			employeeName: $locale === 'ar' ? emp.name_ar || emp.name_en : emp.name_en,
			currentBranchId: emp.current_branch_id,
			nationality: emp.nationality_name_en,
			employmentStatus: emp.employment_status,
			shiftInfo,
			dayByDay,
			totalWorkedMinutes,
			totalUnderWorkedMinutes,
			totalLateMinutes,
			totalIncompleteDays,
			totalUnapprovedDaysOff,
			totalOfficialLeaveDays,
			totalApprovedDaysOff,
			totalExpectedWorkDays,
			totalWorkedDays: actualWorkedDaysCount
		};
	}

	function formatMinutes(mins: number): string {
		const h = Math.floor(mins / 60);
		const m = mins % 60;
		return `${h}h ${m}m`;
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
			case 'Approved Leave': return $t('hr.processFingerprint.status_approved_leave');
			case 'Unapproved Day Off': return $t('hr.processFingerprint.status_unapproved_day_off');
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

	function getStatusColor(status: string): string {
		switch (status) {
			case 'Worked': return 'text-emerald-600';
			case 'Incomplete': return 'text-red-500 font-bold';
			case 'Unapproved Day Off': return 'text-rose-700 font-bold';
			case 'Official Day Off': return 'text-blue-600';
			case 'Approved Leave': return 'text-indigo-600';
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
					<thead class="bg-slate-50">
						<tr>
							<th class="px-2 py-4 font-bold text-slate-700 border-b border-r w-[40px] sticky z-50 bg-slate-50 {$locale === 'ar' ? 'right-0' : 'left-0'}">
								<div class="flex justify-center italic text-[10px]">#</div>
							</th>
							<th class="px-4 py-4 font-bold text-slate-700 border-b border-r w-[100px] sticky z-50 bg-slate-50 {$locale === 'ar' ? 'right-[40px]' : 'left-[40px]'}">{$t('hr.employeeId')}</th>
							<th class="px-4 py-4 font-bold text-slate-700 border-b border-r w-[200px] sticky z-50 bg-slate-50 {$locale === 'ar' ? 'right-[140px]' : 'left-[140px]'}">{$t('hr.fullName')}</th>
							{#each datesInRange as date}
								<th class="hidden px-3 py-2 font-bold text-slate-700 border-b border-r text-center w-[100px] whitespace-nowrap bg-slate-50">
									<div class="flex flex-col items-center">
										<span class="text-xs">{formatDateOnly(date)}</span>
										<span class="text-[9px] font-medium text-slate-500 capitalize">{getDayNameFull(date)}</span>
									</div>
								</th>
							{/each}
							<th class="hidden px-4 py-4 font-bold text-indigo-700 border-b border-r bg-indigo-50/50 text-center w-[150px] whitespace-nowrap">{$t('hr.processFingerprint.total_worked_hours_minutes')}</th>
							<th class="px-4 py-4 font-bold text-emerald-700 border-b border-r bg-emerald-50/50 text-center w-[150px] whitespace-nowrap">Total Worked Hours</th>
							<th class="px-4 py-4 font-bold text-teal-700 border-b border-r bg-teal-50/50 text-center w-[150px] whitespace-nowrap">Total Expected Hours</th>
							<th class="px-4 py-4 font-bold text-red-700 border-b border-r bg-red-50/50 text-center w-[150px] whitespace-nowrap">{$t('hr.processFingerprint.total_under_worked_hours_minutes')}</th>
							<th class="px-4 py-4 font-bold text-amber-700 border-b border-r bg-amber-50/50 text-center w-[150px] whitespace-nowrap">{$t('hr.processFingerprint.total_late_hours_minutes')}</th>
							<th class="hidden px-4 py-4 font-bold text-rose-700 border-b border-r text-center w-[120px] whitespace-nowrap">{$t('hr.processFingerprint.total_incomplete_days')}</th>
							<th class="px-4 py-4 font-bold text-rose-800 border-b border-r text-center w-[120px] whitespace-nowrap">{$t('hr.processFingerprint.total_unapproved_days_off')}</th>
							<th class="px-4 py-4 font-bold text-blue-700 border-b border-r text-center w-[120px] whitespace-nowrap">{$t('hr.processFingerprint.total_official_leave_days')}</th>
							<th class="px-4 py-4 font-bold text-emerald-700 border-b border-r text-center w-[120px] whitespace-nowrap">{$t('hr.processFingerprint.total_approved_days_off')}</th>
							<th class="px-4 py-4 font-bold text-indigo-800 border-b text-center w-[120px] whitespace-nowrap bg-indigo-50 z-50 shadow-[-2px_0_4px_rgba(0,0,0,0.05)] border-l">{$t('hr.processFingerprint.total_expected_work_days')}</th>
							<th class="px-4 py-4 font-bold text-slate-900 border-b text-center w-[120px] whitespace-nowrap bg-slate-100 z-50 shadow-[-2px_0_4px_rgba(0,0,0,0.05)] border-l">{$t('hr.processFingerprint.total_worked_days_header')}</th>
							<th class="px-4 py-4 font-bold text-green-800 border-b border-r bg-green-50/50 text-center w-[150px] whitespace-nowrap">Basic Salary</th>
							<th class="px-4 py-4 font-bold text-amber-800 border-b border-r bg-amber-50/50 text-center w-[150px] whitespace-nowrap">Other Allowance</th>
							<th class="px-4 py-4 font-bold text-cyan-800 border-b border-r bg-cyan-50/50 text-center w-[150px] whitespace-nowrap">Accommodation</th>
							<th class="px-4 py-4 font-bold text-blue-800 border-b border-r bg-blue-50/50 text-center w-[150px] whitespace-nowrap">Travel</th>
							<th class="px-4 py-4 font-bold text-orange-800 border-b border-r bg-orange-50/50 text-center w-[150px] whitespace-nowrap">Food Allowance</th>
							<th class="px-4 py-4 font-bold text-red-800 border-b border-r bg-red-50/50 text-center w-[150px] whitespace-nowrap">GOSI Deduction</th>
						<th class="px-4 py-4 font-bold text-purple-700 border-b border-r bg-purple-50/50 text-center w-[150px] whitespace-nowrap">Late Deductions</th>
						<th class="px-4 py-4 font-bold text-indigo-700 border-b border-r bg-indigo-50/50 text-center w-[150px] whitespace-nowrap">Under Worked Deductions</th>
						<th class="px-4 py-4 font-bold text-pink-700 border-b border-r bg-pink-50/50 text-center w-[150px] whitespace-nowrap">POS Shortage Deduction</th>
						<th class="px-4 py-4 font-bold text-rose-700 border-b border-r bg-rose-50/50 text-center w-[150px] whitespace-nowrap">Salary Advance Deductions</th>
						<th class="px-4 py-4 font-bold text-fuchsia-700 border-b border-r bg-fuchsia-50/50 text-center w-[150px] whitespace-nowrap">Loan Deductions</th>
						<th class="px-4 py-4 font-bold text-orange-700 border-b border-r bg-orange-50/50 text-center w-[150px] whitespace-nowrap">Penalties/Fine Deductions</th>
						<th class="px-4 py-4 font-bold text-sky-700 border-b border-r bg-sky-50/50 text-center w-[150px] whitespace-nowrap">Unapproved Leave Deductions</th>
						<th class="px-4 py-4 font-bold text-gray-700 border-b border-r bg-gray-50/50 text-center w-[150px] whitespace-nowrap">Other Deductions</th>
						<th class="px-4 py-4 font-bold text-yellow-800 border-b border-r bg-yellow-50/50 text-center w-[150px] whitespace-nowrap">Net Salary</th>
						<th class="px-4 py-4 font-bold text-blue-800 border-b border-r bg-blue-50/50 text-center w-[150px] whitespace-nowrap">Net Bank</th>
						<th class="px-4 py-4 font-bold text-red-800 border-b border-r bg-red-50/50 text-center w-[150px] whitespace-nowrap">Net Cash</th></tr>
					</thead>
					<tbody class="divide-y divide-slate-200">
						{#each filteredAnalysisData as row}
							<tr class="transition-colors group {row.employmentStatus === 'Job (No Finger)' ? 'bg-red-50/60 even:bg-red-100/60' : row.employmentStatus === 'Remote Job' ? 'bg-orange-50/60 even:bg-orange-100/60' : 'even:bg-slate-100/80'}">
								<td class="px-2 py-3 border-r sticky z-20 bg-white group-even:bg-slate-100/80 group-hover:bg-emerald-100 flex justify-center items-center {row.employmentStatus === 'Job (No Finger)' ? 'bg-red-50/60 group-even:bg-red-100/60' : row.employmentStatus === 'Remote Job' ? 'bg-orange-50/60 group-even:bg-orange-100/60' : ''} {$locale === 'ar' ? 'right-0' : 'left-0'}">
									{#if row.employmentStatus === 'Job (With Finger)'}
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
									{/if}
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
									<td class="hidden px-3 py-3 border-r text-center text-[10px] leading-tight w-[100px] group-hover:bg-emerald-100/50 transition-colors">
										<div class={getStatusColor(row.dayByDay[date].status)}>
											{#if row.dayByDay[date].status === 'Worked'}
												<div class="font-bold whitespace-nowrap {row.dayByDay[date].underMins > 0 ? 'text-red-700' : ''}">
													{formatMinutes(row.dayByDay[date].workedMins)}
												</div>
												{#if row.dayByDay[date].lateMins > 0}
													<div class="text-[8px] text-amber-700 font-bold">L: {row.dayByDay[date].lateMins}m</div>
												{/if}
											{:else}
												<span class="whitespace-nowrap font-bold uppercase tracking-tight text-[8px]">{getStatusLabel(row.dayByDay[date].status)}</span>
											{#if row.dayByDay[date].lateMins > 0}
													<div class="text-[8px] text-amber-700 font-bold">L: {row.dayByDay[date].lateMins}m</div>
												{/if}
											{/if}
										</div>
									</td>
								{/each}
								<td class="hidden px-4 py-3 border-r text-center font-bold text-indigo-700 bg-indigo-50/20 w-[150px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors">
									{formatMinutes(row.totalWorkedMinutes)}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-emerald-700 bg-emerald-50/20 w-[150px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors">
									{(row.totalWorkedMinutes / 60).toFixed(2)} hrs
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-teal-700 bg-teal-50/20 w-[150px] whitespace-nowrap group-hover:bg-teal-100/50 transition-colors">
									{#if employeeShifts.get(String(row.employeeId))}
										{(() => {
											const shift = employeeShifts.get(String(row.employeeId));
											const startMins = timeToMinutes(shift.shift_start_time);
											const endMins = timeToMinutes(shift.shift_end_time);
											let shiftMins = endMins - startMins;
											if (shiftMins < 0) shiftMins += 24 * 60;
											const expectedHours = (shiftMins / 60) * row.totalExpectedWorkDays;
											return expectedHours.toFixed(2);
										})()}
										hrs
									{:else}
										-
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-red-700 bg-red-50/20 w-[150px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors">
									{formatMinutes(row.totalUnderWorkedMinutes)}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-amber-700 bg-amber-50/20 w-[150px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors">
									{formatMinutes(row.totalLateMinutes)}
								</td>
								<td class="hidden px-4 py-3 border-r text-center font-bold text-rose-700 w-[120px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors">{row.totalIncompleteDays}</td>
								<td class="px-4 py-3 border-r text-center font-bold text-rose-900 w-[120px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors">{row.totalUnapprovedDaysOff}</td>
								<td class="px-4 py-3 border-r text-center font-bold text-blue-800 w-[120px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors">{row.totalApprovedDaysOff}</td>
								<td class="px-4 py-3 border-r text-center font-bold text-emerald-800 w-[120px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors">{row.totalOfficialLeaveDays}</td>
								<td class="px-4 py-3 text-center font-bold text-indigo-900 bg-indigo-50 z-20 w-[120px] whitespace-nowrap shadow-[-2px_0_4px_rgba(0,0,0,0.1)] border-l group-hover:bg-emerald-100 transition-colors text-xs">
									{row.totalExpectedWorkDays}
								</td>
								<td class="px-4 py-3 text-center font-black text-slate-950 bg-slate-200 z-20 w-[120px] whitespace-nowrap shadow-[-2px_0_4px_rgba(0,0,0,0.1)] border-l group-hover:bg-emerald-200 transition-colors text-xs">
									{#if row.employmentStatus === 'Job (No Finger)' || row.employmentStatus === 'Remote Job'}
										<input 
											type="number" 
											bind:value={editableWorkedDays[row.employeeId]}
											placeholder={row.totalWorkedDays}
											class="w-full px-2 py-1 text-center border border-slate-300 rounded bg-white text-slate-950 font-bold"
										/>
									{:else}
										{row.totalWorkedDays}
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-green-800 bg-green-50/20 w-[150px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors">
									{#if basicSalaries[row.employeeId]}
										<div class="flex flex-col items-center">
											<span class="font-bold text-slate-800">{basicSalaries[row.employeeId].toLocaleString()}</span>
											<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 mt-1">{paymentModes[row.employeeId] === 'Bank' ? 'Bank' : 'Cash'}</span>
										</div>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-amber-800 bg-amber-50/20 w-[150px] whitespace-nowrap group-hover:bg-amber-100/50 transition-colors">
									{#if otherAllowances[row.employeeId] && otherAllowances[row.employeeId] > 0}
										<div class="flex flex-col items-center">
											<span class="font-bold text-slate-800">{otherAllowances[row.employeeId].toLocaleString()}</span>
											<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 mt-1">{otherAllowancePaymentModes[row.employeeId] === 'Bank' ? 'Bank' : 'Cash'}</span>
										</div>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-cyan-800 bg-cyan-50/20 w-[150px] whitespace-nowrap group-hover:bg-cyan-100/50 transition-colors">
									{#if accommodationAllowances[row.employeeId] && accommodationAllowances[row.employeeId] > 0}
										<div class="flex flex-col items-center">
											<span class="font-bold text-slate-800">{accommodationAllowances[row.employeeId].toLocaleString()}</span>
											<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 mt-1">{accommodationPaymentModes[row.employeeId] === 'Bank' ? 'Bank' : 'Cash'}</span>
										</div>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-blue-800 bg-blue-50/20 w-[150px] whitespace-nowrap group-hover:bg-blue-100/50 transition-colors">
									{#if travelAllowances[row.employeeId] && travelAllowances[row.employeeId] > 0}
										<div class="flex flex-col items-center">
											<span class="font-bold text-slate-800">{travelAllowances[row.employeeId].toLocaleString()}</span>
											<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 mt-1">{travelPaymentModes[row.employeeId] === 'Bank' ? 'Bank' : 'Cash'}</span>
										</div>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-orange-800 bg-orange-50/20 w-[150px] whitespace-nowrap group-hover:bg-orange-100/50 transition-colors">
									{#if foodAllowances[row.employeeId] && foodAllowances[row.employeeId] > 0}
										<div class="flex flex-col items-center">
											<span class="font-bold text-slate-800">{foodAllowances[row.employeeId].toLocaleString()}</span>
											<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 mt-1">{foodPaymentModes[row.employeeId] === 'Bank' ? 'Bank' : 'Cash'}</span>
										</div>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-red-800 bg-red-50/20 w-[150px] whitespace-nowrap group-hover:bg-red-100/50 transition-colors">
									{#if gosiDeductions[row.employeeId] && gosiDeductions[row.employeeId] > 0}
										<span class="font-bold text-slate-800">{gosiDeductions[row.employeeId].toLocaleString()}</span>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-purple-700 bg-purple-50/20 w-[150px] whitespace-nowrap group-hover:bg-purple-100/50 transition-colors">
									{#if employeeShifts.get(String(row.employeeId))}
										{(() => {
											const shift = employeeShifts.get(String(row.employeeId));
											const basicSal = basicSalaries[row.employeeId] || 0;
											const otherAllow = otherAllowances[row.employeeId] || 0;
											const accommAllow = accommodationAllowances[row.employeeId] || 0;
											const travelAllow = travelAllowances[row.employeeId] || 0;
											const foodAllow = foodAllowances[row.employeeId] || 0;
											const gosiDed = gosiDeductions[row.employeeId] || 0;
											
											const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow - gosiDed;
											
											const startMins = timeToMinutes(shift.shift_start_time);
											const endMins = timeToMinutes(shift.shift_end_time);
											let shiftMins = endMins - startMins;
											if (shiftMins < 0) shiftMins += 24 * 60;
											const totalExpectedHours = (shiftMins / 60) * row.totalExpectedWorkDays;
											
											const hourlyRate = totalExpectedHours > 0 ? totalSalary / totalExpectedHours : 0;
											const lateHours = row.totalLateMinutes / 60;
											const lateDeduction = lateHours * hourlyRate;
											
											return lateDeduction.toFixed(2);
										})()}
									{:else}
										-
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-indigo-700 bg-indigo-50/20 w-[150px] whitespace-nowrap group-hover:bg-indigo-100/50 transition-colors">
									{#if employeeShifts.get(String(row.employeeId))}
										{(() => {
											const shift = employeeShifts.get(String(row.employeeId));
											const basicSal = basicSalaries[row.employeeId] || 0;
											const otherAllow = otherAllowances[row.employeeId] || 0;
											const accommAllow = accommodationAllowances[row.employeeId] || 0;
											const travelAllow = travelAllowances[row.employeeId] || 0;
											const foodAllow = foodAllowances[row.employeeId] || 0;
											const gosiDed = gosiDeductions[row.employeeId] || 0;
											
											const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow - gosiDed;
											
											const startMins = timeToMinutes(shift.shift_start_time);
											const endMins = timeToMinutes(shift.shift_end_time);
											let shiftMins = endMins - startMins;
											if (shiftMins < 0) shiftMins += 24 * 60;
											const totalExpectedHours = (shiftMins / 60) * row.totalExpectedWorkDays;
											
											const hourlyRate = totalExpectedHours > 0 ? totalSalary / totalExpectedHours : 0;
											const underWorkedHours = row.totalUnderWorkedMinutes / 60;
											const underWorkedDeduction = underWorkedHours * hourlyRate;
											
											return underWorkedDeduction.toFixed(2);
										})()}
									{:else}
										-
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-pink-700 bg-pink-50/20 w-[150px] whitespace-nowrap group-hover:bg-pink-100/50 transition-colors">
									-
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-rose-700 bg-rose-50/20 w-[150px] whitespace-nowrap group-hover:bg-rose-100/50 transition-colors">
									-
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-fuchsia-700 bg-fuchsia-50/20 w-[150px] whitespace-nowrap group-hover:bg-fuchsia-100/50 transition-colors">
									-
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-orange-700 bg-orange-50/20 w-[150px] whitespace-nowrap group-hover:bg-orange-100/50 transition-colors">
									-
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-sky-700 bg-sky-50/20 w-[150px] whitespace-nowrap group-hover:bg-sky-100/50 transition-colors">
									{#if employeeShifts.get(String(row.employeeId))}
										{(() => {
											const shift = employeeShifts.get(String(row.employeeId));
											const basicSal = basicSalaries[row.employeeId] || 0;
											const otherAllow = otherAllowances[row.employeeId] || 0;
											const accommAllow = accommodationAllowances[row.employeeId] || 0;
											const travelAllow = travelAllowances[row.employeeId] || 0;
											const foodAllow = foodAllowances[row.employeeId] || 0;
											const gosiDed = gosiDeductions[row.employeeId] || 0;
											
											const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow - gosiDed;
											
											const startMins = timeToMinutes(shift.shift_start_time);
											const endMins = timeToMinutes(shift.shift_end_time);
											let shiftMins = endMins - startMins;
											if (shiftMins < 0) shiftMins += 24 * 60;
											const totalExpectedHours = (shiftMins / 60) * row.totalExpectedWorkDays;
											
											const hourlyRate = totalExpectedHours > 0 ? totalSalary / totalExpectedHours : 0;
											const shiftHoursPerDay = shiftMins / 60;
											const unapprovedLeaveDays = row.totalUnapprovedDaysOff || 0;
											const unapprovedLeaveDeduction = unapprovedLeaveDays * shiftHoursPerDay * hourlyRate;
											
											return unapprovedLeaveDeduction.toFixed(2);
										})()}
									{:else}
										-
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-gray-700 bg-gray-50/20 w-[150px] whitespace-nowrap group-hover:bg-gray-100/50 transition-colors">
									-
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-yellow-800 bg-yellow-50/20 w-[150px] whitespace-nowrap group-hover:bg-yellow-100/50 transition-colors">
									{(() => {
										const basicSal = basicSalaries[row.employeeId] || 0;
										const otherAllow = otherAllowances[row.employeeId] || 0;
										const accommAllow = accommodationAllowances[row.employeeId] || 0;
										const travelAllow = travelAllowances[row.employeeId] || 0;
										const foodAllow = foodAllowances[row.employeeId] || 0;
										const gosiDed = gosiDeductions[row.employeeId] || 0;
										
										// Calculate per-day salary
										const totalAllowances = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
										const perDaySalary = row.totalExpectedWorkDays > 0 ? totalAllowances / row.totalExpectedWorkDays : 0;
										
										// Calculate salary for worked days
										const workedDays = editableWorkedDays[row.employeeId] !== undefined && editableWorkedDays[row.employeeId] !== '' ? parseFloat(editableWorkedDays[row.employeeId]) : row.totalWorkedDays;
										const grossWorkedSalary = perDaySalary * workedDays;
										
										let lateDeduction = 0;
										let underWorkedDeduction = 0;
										let unapprovedLeaveDeduction = 0;
										
										// Only calculate deductions if shift exists
										if (employeeShifts.get(String(row.employeeId))) {
											const shift = employeeShifts.get(String(row.employeeId));
											const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow - gosiDed;
											const startMins = timeToMinutes(shift.shift_start_time);
											const endMins = timeToMinutes(shift.shift_end_time);
											let shiftMins = endMins - startMins;
											if (shiftMins < 0) shiftMins += 24 * 60;
											const totalExpectedHours = (shiftMins / 60) * row.totalExpectedWorkDays;
											const hourlyRate = totalExpectedHours > 0 ? totalSalary / totalExpectedHours : 0;
											const shiftHoursPerDay = shiftMins / 60;
											
											if (row.totalLateMinutes > 0) {
												const lateHours = row.totalLateMinutes / 60;
												lateDeduction = lateHours * hourlyRate;
											}
											
											if (row.totalUnderWorkedMinutes > 0) {
												const underWorkedHours = row.totalUnderWorkedMinutes / 60;
												underWorkedDeduction = underWorkedHours * hourlyRate;
											}
											
											if (row.totalUnapprovedDaysOff > 0) {
												unapprovedLeaveDeduction = row.totalUnapprovedDaysOff * shiftHoursPerDay * hourlyRate;
											}
										}
										
										// Placeholder deductions (currently 0 since columns show "-")
										const salaryAdvanceDed = 0;
										const loanDed = 0;
										const penaltiesDed = 0;
										const otherDed = 0;
										
										// Calculate net salary
										const netSalary = grossWorkedSalary - (gosiDed + lateDeduction + underWorkedDeduction + salaryAdvanceDed + loanDed + penaltiesDed + unapprovedLeaveDeduction + otherDed);
										
										return netSalary.toFixed(2);
									})()}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-blue-800 bg-blue-50/20 w-[150px] whitespace-nowrap group-hover:bg-blue-100/50 transition-colors">
									{(() => {
										const basicSal = basicSalaries[row.employeeId] || 0;
										const otherAllow = otherAllowances[row.employeeId] || 0;
										const accommAllow = accommodationAllowances[row.employeeId] || 0;
										const travelAllow = travelAllowances[row.employeeId] || 0;
										const foodAllow = foodAllowances[row.employeeId] || 0;
										const gosiDed = gosiDeductions[row.employeeId] || 0;
										
										// Calculate per-day salary
										const totalAllowances = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
										const perDaySalary = row.totalExpectedWorkDays > 0 ? totalAllowances / row.totalExpectedWorkDays : 0;
										
										// Calculate salary for worked days
										const workedDays = editableWorkedDays[row.employeeId] !== undefined && editableWorkedDays[row.employeeId] !== '' ? parseFloat(editableWorkedDays[row.employeeId]) : row.totalWorkedDays;
										const grossWorkedSalary = perDaySalary * workedDays;
										
										let lateDeduction = 0;
										let underWorkedDeduction = 0;
										let unapprovedLeaveDeduction = 0;
										
										// Only calculate deductions if shift exists
										if (employeeShifts.get(String(row.employeeId))) {
											const shift = employeeShifts.get(String(row.employeeId));
											const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow - gosiDed;
											const startMins = timeToMinutes(shift.shift_start_time);
											const endMins = timeToMinutes(shift.shift_end_time);
											let shiftMins = endMins - startMins;
											if (shiftMins < 0) shiftMins += 24 * 60;
											const totalExpectedHours = (shiftMins / 60) * row.totalExpectedWorkDays;
											const hourlyRate = totalExpectedHours > 0 ? totalSalary / totalExpectedHours : 0;
											const shiftHoursPerDay = shiftMins / 60;
											
											if (row.totalLateMinutes > 0) {
												const lateHours = row.totalLateMinutes / 60;
												lateDeduction = lateHours * hourlyRate;
											}
											
											if (row.totalUnderWorkedMinutes > 0) {
												const underWorkedHours = row.totalUnderWorkedMinutes / 60;
												underWorkedDeduction = underWorkedHours * hourlyRate;
											}
											
											if (row.totalUnapprovedDaysOff > 0) {
												unapprovedLeaveDeduction = row.totalUnapprovedDaysOff * shiftHoursPerDay * hourlyRate;
											}
										}
										
										// Placeholder deductions (currently 0 since columns show "-")
										const salaryAdvanceDed = 0;
										const loanDed = 0;
										const penaltiesDed = 0;
										const otherDed = 0;
										
										// Calculate net salary
										const netSalary = grossWorkedSalary - (gosiDed + lateDeduction + underWorkedDeduction + salaryAdvanceDed + loanDed + penaltiesDed + unapprovedLeaveDeduction + otherDed);
										
										// Calculate bank and cash portions based on payment modes
										const basicPayMode = paymentModes[row.employeeId] || 'Bank';
										const otherPayMode = otherAllowancePaymentModes[row.employeeId] || 'Bank';
										const accommPayMode = accommodationPaymentModes[row.employeeId] || 'Bank';
										const travelPayMode = travelPaymentModes[row.employeeId] || 'Bank';
										const foodPayMode = foodPaymentModes[row.employeeId] || 'Bank';
										
										// Calculate total allowances for bank and cash
										let bankAllowances = 0;
										let cashAllowances = 0;
										
										if (basicPayMode === 'Bank') bankAllowances += basicSal; else cashAllowances += basicSal;
										if (otherPayMode === 'Bank') bankAllowances += otherAllow; else cashAllowances += otherAllow;
										if (accommPayMode === 'Bank') bankAllowances += accommAllow; else cashAllowances += accommAllow;
										if (travelPayMode === 'Bank') bankAllowances += travelAllow; else cashAllowances += travelAllow;
										if (foodPayMode === 'Bank') bankAllowances += foodAllow; else cashAllowances += foodAllow;
										
										// Calculate ratios
										const bankRatio = totalAllowances > 0 ? bankAllowances / totalAllowances : 0;
										
										// Apply ratios to net salary
										const netBank = netSalary * bankRatio;
										
										return netBank.toFixed(2);
									})()}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-red-800 bg-red-50/20 w-[150px] whitespace-nowrap group-hover:bg-red-100/50 transition-colors">
									{(() => {
										const basicSal = basicSalaries[row.employeeId] || 0;
										const otherAllow = otherAllowances[row.employeeId] || 0;
										const accommAllow = accommodationAllowances[row.employeeId] || 0;
										const travelAllow = travelAllowances[row.employeeId] || 0;
										const foodAllow = foodAllowances[row.employeeId] || 0;
										const gosiDed = gosiDeductions[row.employeeId] || 0;
										
										// Calculate per-day salary
										const totalAllowances = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
										const perDaySalary = row.totalExpectedWorkDays > 0 ? totalAllowances / row.totalExpectedWorkDays : 0;
										
										// Calculate salary for worked days
										const workedDays = editableWorkedDays[row.employeeId] !== undefined && editableWorkedDays[row.employeeId] !== '' ? parseFloat(editableWorkedDays[row.employeeId]) : row.totalWorkedDays;
										const grossWorkedSalary = perDaySalary * workedDays;
										
										let lateDeduction = 0;
										let underWorkedDeduction = 0;
										let unapprovedLeaveDeduction = 0;
										
										// Only calculate deductions if shift exists
										if (employeeShifts.get(String(row.employeeId))) {
											const shift = employeeShifts.get(String(row.employeeId));
											const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow - gosiDed;
											const startMins = timeToMinutes(shift.shift_start_time);
											const endMins = timeToMinutes(shift.shift_end_time);
											let shiftMins = endMins - startMins;
											if (shiftMins < 0) shiftMins += 24 * 60;
											const totalExpectedHours = (shiftMins / 60) * row.totalExpectedWorkDays;
											const hourlyRate = totalExpectedHours > 0 ? totalSalary / totalExpectedHours : 0;
											const shiftHoursPerDay = shiftMins / 60;
											
											if (row.totalLateMinutes > 0) {
												const lateHours = row.totalLateMinutes / 60;
												lateDeduction = lateHours * hourlyRate;
											}
											
											if (row.totalUnderWorkedMinutes > 0) {
												const underWorkedHours = row.totalUnderWorkedMinutes / 60;
												underWorkedDeduction = underWorkedHours * hourlyRate;
											}
											
											if (row.totalUnapprovedDaysOff > 0) {
												unapprovedLeaveDeduction = row.totalUnapprovedDaysOff * shiftHoursPerDay * hourlyRate;
											}
										}
										
										// Placeholder deductions (currently 0 since columns show "-")
										const salaryAdvanceDed = 0;
										const loanDed = 0;
										const penaltiesDed = 0;
										const otherDed = 0;
										
										// Calculate net salary
										const netSalary = grossWorkedSalary - (gosiDed + lateDeduction + underWorkedDeduction + salaryAdvanceDed + loanDed + penaltiesDed + unapprovedLeaveDeduction + otherDed);
										
										// Calculate bank and cash portions based on payment modes
										const basicPayMode = paymentModes[row.employeeId] || 'Bank';
										const otherPayMode = otherAllowancePaymentModes[row.employeeId] || 'Bank';
										const accommPayMode = accommodationPaymentModes[row.employeeId] || 'Bank';
										const travelPayMode = travelPaymentModes[row.employeeId] || 'Bank';
										const foodPayMode = foodPaymentModes[row.employeeId] || 'Bank';
										
										// Calculate total allowances for bank and cash
										let bankAllowances = 0;
										let cashAllowances = 0;
										
										if (basicPayMode === 'Bank') bankAllowances += basicSal; else cashAllowances += basicSal;
										if (otherPayMode === 'Bank') bankAllowances += otherAllow; else cashAllowances += otherAllow;
										if (accommPayMode === 'Bank') bankAllowances += accommAllow; else cashAllowances += accommAllow;
										if (travelPayMode === 'Bank') bankAllowances += travelAllow; else cashAllowances += travelAllow;
										if (foodPayMode === 'Bank') bankAllowances += foodAllow; else cashAllowances += foodAllow;
										
										// Calculate ratios
										const cashRatio = totalAllowances > 0 ? cashAllowances / totalAllowances : 0;
										
										// Apply ratios to net salary
										const netCash = netSalary * cashRatio;
										
										return netCash.toFixed(2);
									})()}
								</td>
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