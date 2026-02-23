<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase, getEdgeFunctionUrl } from '$lib/utils/supabase';
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
	let refreshing = false;
	let lastUpdated: string = '';

	// Multi-shift data for all employees
	let multiShiftRegularAll: any[] = [];
	let multiShiftDateWiseAll: any[] = [];
	let multiShiftWeekdayAll: any[] = [];

	/** Get total multi-shift working minutes for a given employee on a given date */
	function getMultiShiftMinsForEmpDate(empId: string, dateStr: string): number {
		const dayNum = new Date(dateStr + 'T12:00:00').getDay();
		let totalHours = 0;
		const eid = String(empId);
		// Date-wise multi-shifts
		for (const ms of multiShiftDateWiseAll) {
			if (String(ms.employee_id) === eid && dateStr >= ms.date_from && dateStr <= ms.date_to) {
				totalHours += ms.working_hours || 0;
			}
		}
		// Weekday multi-shifts
		for (const ms of multiShiftWeekdayAll) {
			if (String(ms.employee_id) === eid && ms.weekday === dayNum) {
				totalHours += ms.working_hours || 0;
			}
		}
		// Regular multi-shifts
		for (const ms of multiShiftRegularAll) {
			if (String(ms.employee_id) === eid) {
				totalHours += ms.working_hours || 0;
			}
		}
		return totalHours * 60;
	}

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
			const { data: branchData } = await supabase.from('branches').select('id, name_en, name_ar, location_en, location_ar').eq('is_active', true).order('name_en');
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
			// Query pre-computed analysis data from the Edge Function table
			const { data: rows, error } = await supabase
				.from('hr_analysed_attendance_data')
				.select('*')
				.gte('shift_date', startDate)
				.lte('shift_date', endDate);

			if (error) throw error;

			if (!rows || rows.length === 0) {
				lastUpdated = '';
				loading = false;
				return;
			}

			// Find the most recent analyzed_at timestamp
			const maxAnalyzedAt = rows.reduce((max: string, r: any) => {
				if (!r.analyzed_at) return max;
				return r.analyzed_at > max ? r.analyzed_at : max;
			}, '');
			if (maxAnalyzedAt) {
				const d = new Date(maxAnalyzedAt);
				const parts = new Intl.DateTimeFormat('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric', timeZone: 'Asia/Riyadh' }).formatToParts(d);
				const dd = parts.find(p => p.type === 'day')?.value ?? '';
				const mm = parts.find(p => p.type === 'month')?.value ?? '';
				const yyyy = parts.find(p => p.type === 'year')?.value ?? '';
				lastUpdated = `${dd}-${mm}-${yyyy} ` + d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', hour12: true, timeZone: 'Asia/Riyadh' });
			} else {
				lastUpdated = '';
			}

			// Group by employee and build the same structure as before
			const empMap = new Map<string, any>();

			for (const row of rows) {
				const empId = String(row.employee_id);

				if (!empMap.has(empId)) {
					empMap.set(empId, {
						employeeId: empId,
						employeeName: $locale === 'ar' 
							? (row.employee_name_ar || row.employee_name_en) 
							: row.employee_name_en,
						currentBranchId: row.branch_id,
						nationality: row.nationality,
						shiftInfo: row.shift_start_time && row.shift_end_time
							? `${formatTime12Hour(row.shift_start_time)} - ${formatTime12Hour(row.shift_end_time)}`
							: '',
						dayByDay: {} as Record<string, any>
					});
				}

				const emp = empMap.get(empId)!;
				// shift_date from Supabase DATE column comes as "YYYY-MM-DD"
				const dateStr = typeof row.shift_date === 'string'
					? row.shift_date.split('T')[0]
					: new Date(row.shift_date).toISOString().split('T')[0];

				// Map legacy Edge Function status strings to AnalyzeAllWindow status strings
				let status = row.status;
				if (status === 'Complete') status = 'Worked';
				else if (status === 'Missing Checkout') status = 'Check-Out Missing';
				else if (status === 'Missing Checkin') status = 'Check-In Missing';
				else if (status === 'Pending Leave') status = 'Pending Approval';
				else if (status === 'Approved Leave') status = 'Approved Leave (No Deduction)';
				else if (status === 'Rejected Leave') status = 'Rejected-Not Deducted';

				emp.dayByDay[dateStr] = {
					workedMins: row.worked_minutes || 0,
					status,
					lateMins: row.late_minutes || 0,
					underMins: row.under_minutes || 0,
					overtimeMins: row.overtime_minutes || 0
				};
			}

			// Fill missing dates with 'Absent' default
			for (const [, empData] of empMap) {
				for (const date of datesInRange) {
					if (!empData.dayByDay[date]) {
						empData.dayByDay[date] = { workedMins: 0, status: 'Absent', lateMins: 0, underMins: 0, overtimeMins: 0 };
					}
				}
			}

			// Load multi-shift data and adjust underworked for multi-shift employees
			const [msRegRes, msDateRes, msWeekRes] = await Promise.all([
				supabase.from('multi_shift_regular').select('employee_id, working_hours'),
				supabase.from('multi_shift_date_wise').select('employee_id, date_from, date_to, working_hours'),
				supabase.from('multi_shift_weekday').select('employee_id, weekday, working_hours')
			]);
			multiShiftRegularAll = msRegRes.data || [];
			multiShiftDateWiseAll = msDateRes.data || [];
			multiShiftWeekdayAll = msWeekRes.data || [];

			// Adjust underworked minutes for employees with multi-shifts
			for (const [empId, empData] of empMap) {
				for (const date of datesInRange) {
					const multiMins = getMultiShiftMinsForEmpDate(empId, date);
					if (multiMins > 0 && empData.dayByDay[date]) {
						empData.dayByDay[date].underMins = Math.max(0, (empData.dayByDay[date].underMins || 0) + multiMins);
					}
				}
			}

			analysisData = Array.from(empMap.values());

		} catch (error) {
			console.error('Error loading analysis:', error);
		} finally {
			loading = false;
		}
	}

	async function refreshFromServer() {
		if (!startDate || !endDate) {
			alert('Please select date range first');
			return;
		}
		refreshing = true;
		try {
			// Calculate rolling days from startDate to today
			const today = new Date();
			const start = new Date(startDate);
			const diffMs = today.getTime() - start.getTime();
			const rollingDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

			const { data: { session } } = await supabase.auth.getSession();
			const token = session?.access_token;

			const res = await fetch(getEdgeFunctionUrl('analyze-attendance'), {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					'Authorization': `Bearer ${token}`
				},
				body: JSON.stringify({ rollingDays })
			});

			const result = await res.json();

			if (result.success) {
				alert(`Analysis refreshed!\n${result.upserted} records updated, ${result.errors} errors.`);
				// Reload the data from the table
				await loadAnalysis();
			} else {
				alert(`Refresh failed: ${result.error || 'Unknown error'}`);
			}
		} catch (err: any) {
			console.error('Error refreshing analysis:', err);
			alert(`Error: ${err.message}`);
		} finally {
			refreshing = false;
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
			case 'Official Holiday': return $t('hr.shiftAndDayOff.officialHolidays') || 'Official Holiday';
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
				'Official Holiday': '\u0639\u0637\u0644\u0629 \u0631\u0633\u0645\u064a\u0629',
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
				if (s === 'Official Holiday') return { ...base, font: { ...base.font, color: { rgb: '4338CA' }, bold: true } };
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
					? ['\u0623\u064a\u0627\u0645 \u0627\u0644\u0639\u0645\u0644', '\u063a\u064a\u0627\u0628', '\u0625\u062c\u0627\u0632\u0627\u062a', '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u062a\u0623\u062e\u064a\u0631', '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0646\u0642\u0635', '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0648\u0642\u062a \u0627\u0644\u0625\u0636\u0627\u0641\u064a']
					: ['Work Days', 'Absent', 'Leaves', 'Total Late', 'Total Underworked', 'Total Overtime'];

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
					let workDays = 0, absentDays = 0, leaveDays = 0, totalLate = 0, totalUnder = 0, totalOvertime = 0;

					const dateCells: string[] = [];
					for (const date of datesInRange) {
						const day = row.dayByDay[date];
						if (!day) { dateCells.push('-'); continue; }

						const st = day.status;
						if (st === 'Worked') {
							workDays++;
							totalLate += day.lateMins || 0;
							totalUnder += day.underMins || 0;
							totalOvertime += day.overtimeMins || 0;
							let cell = fmtMinsLang(day.workedMins, lang);
							if (day.lateMins > 0) cell += `\n${isAr ? '\u062a\u0623\u062e\u064a\u0631' : 'Late'}: ${fmtMinsLang(day.lateMins, lang)}`;
							if (day.underMins > 0) cell += `\n${isAr ? '\u0646\u0642\u0635' : 'Under'}: ${fmtMinsLang(day.underMins, lang)}`;
							if (day.overtimeMins > 0) cell += `\n${isAr ? '\u0625\u0636\u0627\u0641\u064a' : 'OT'}: ${fmtMinsLang(day.overtimeMins, lang)}`;
							dateCells.push(cell);
						} else if (st === 'Absent') {
							absentDays++;
							totalLate += day.lateMins || 0;
							let cell = getStatusLang(st, lang);
							if (day.lateMins > 0) cell += `\n${isAr ? '\u062a\u0623\u062e\u064a\u0631' : 'Late'}: ${fmtMinsLang(day.lateMins, lang)}`;
							dateCells.push(cell);
						} else if (st.includes('Leave') || st.includes('Approved') || st === 'Official Day Off' || st === 'Official Holiday') {
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
						fmtMinsLang(totalUnder, lang),
						fmtMinsLang(totalOvertime, lang)
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
					{ wch: 12 }, { wch: 10 }, { wch: 10 }, { wch: 14 }, { wch: 16 }, { wch: 16 }
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
								} else if (sumIdx === 5) {
									// Total Overtime — amber if > 0
									const v = String(ws[ref].v || '');
									ws[ref].s = (v && v !== '-' && v !== '') ? { ...base, font: { ...base.font, color: { rgb: 'D97706' }, bold: true } } : base;
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
			case 'Official Holiday': return 'text-indigo-600 font-semibold';
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

			<button 
				on:click={refreshFromServer}
				disabled={refreshing || loading}
				class="px-5 py-2 bg-amber-500 text-white font-bold rounded-lg hover:bg-amber-600 transition-colors disabled:bg-slate-300 h-[38px] flex items-center gap-2"
				title="Re-run Edge Function to refresh analysis data from server"
			>
				<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 {refreshing ? 'animate-spin' : ''}" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
				{refreshing ? 'Refreshing...' : 'Refresh Data'}
			</button>

			{#if lastUpdated}
				<div class="flex items-center gap-1.5 px-3 py-1.5 bg-slate-100 border border-slate-200 rounded-lg h-[38px] text-xs text-slate-600" title="Last analysis run time">
					<svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
					<span class="font-semibold text-slate-500">Updated:</span>
					<span class="font-bold text-slate-700">{lastUpdated}</span>
				</div>
			{/if}

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
												{#if row.dayByDay[date].overtimeMins > 0}
													<div class="text-[8px] text-amber-600 font-bold">⏱️ {formatMinutes(row.dayByDay[date].overtimeMins)}</div>
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