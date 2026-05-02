<script lang="ts">
	import { windowManager } from '$lib/stores/windowManager';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { onMount, onDestroy } from 'svelte';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import EmployeeAnalysisWindow from './EmployeeAnalysisWindow.svelte';
	import EmployeeSalaryNotesPopup from './EmployeeSalaryNotesPopup.svelte';

	export let windowId: string;

	// Notes popup state
	let showNotesPopup = false;
	let notesEmployeeId = '';
	let notesEmployeeName = '';

	function openNotesPopup(row: any) {
		notesEmployeeId = row.employeeId;
		notesEmployeeName = row.employeeName || row.employeeId;
		showNotesPopup = true;
	}

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
	let foodDeductionActives: { [key: string]: boolean } = {};
	let posShortageDeductions: { [key: string]: number } = {};
	let posDeductionsList: { [key: string]: any[] } = {}; // Store detailed POS deductions per employee
	let expandedPosDropdown: { [key: string]: boolean } = {}; // Track which employee's dropdown is open

	// Column visibility panel
	let showColumnPanel = false;
	let colVis = {
		status: true, workedHours: true, expectedHours: true, underWorkedHours: true,
		lateHours: true, incompleteDays: true, incompleteDeductions: true,
		unapprovedDaysOff: true, officialLeave: true, approvedDaysOff: true,
		expectedWorkDays: true, workedDays: true, basicSalary: true,
		otherAllowance: true, accommodation: true, travel: true,
		foodAllowance: true, foodDeduction: true, gosiDeduction: true, lateDeductions: true,
		underWorkedDeductions: true, posShortage: true, salaryAdvance: true,
		loanDeductions: true, penaltiesDeductions: true, unapprovedLeaveDeductions: true,
                otherDeductions: true, grossEarnings: true, totalDeductions: true, netSalary: true, netBank: true, netCash: true,
		idNumber: true, whatsappNumber: true,
	};
	function toggleAllColumns(visible: boolean) {
		(Object.keys(colVis) as Array<keyof typeof colVis>).forEach(k => colVis[k] = visible);
		colVis = colVis;
	}

	// Employee edit modal state
	let showEmpEditModal = false;
	let empEditRow: any = null;
	let empEdit = {
		basicSalary: 0,
		basicPaymentMode: 'Bank',
		otherAllowance: 0,
		otherAllowancePaymentMode: 'Bank',
		accommodation: 0,
		accommodationPaymentMode: 'Bank',
		travel: 0,
		travelPaymentMode: 'Bank',
		food: 0,
		foodPaymentMode: 'Bank',
		gosiDeduction: 0,
		posShortage: 0,
		salaryAdvance: 0,
		loanDeductions: 0,
		penalties: 0,
		otherDeductions: 0,
		lateMinutes: 0,
		underWorkedMinutes: 0,
		lateDeduction: 0,
		underWorkedDeduction: 0,
		unapprovedLeaveDeduction: 0,
		incompleteDayDeduction: 0,
		foodDeductionActive: false,
	};

	function openEmpEdit(row: any) {
		empEditRow = row;
		empEdit = {
			basicSalary: basicSalaries[row.employeeId] || 0,
			basicPaymentMode: paymentModes[row.employeeId] || 'Bank',
			otherAllowance: otherAllowances[row.employeeId] || 0,
			otherAllowancePaymentMode: otherAllowancePaymentModes[row.employeeId] || 'Bank',
			accommodation: accommodationAllowances[row.employeeId] || 0,
			accommodationPaymentMode: accommodationPaymentModes[row.employeeId] || 'Bank',
			travel: travelAllowances[row.employeeId] || 0,
			travelPaymentMode: travelPaymentModes[row.employeeId] || 'Bank',
			food: foodAllowances[row.employeeId] || 0,
			foodPaymentMode: foodPaymentModes[row.employeeId] || 'Bank',
			gosiDeduction: gosiDeductions[row.employeeId] || 0,
			posShortage: posShortageDeductions[row.employeeId] || 0,
			salaryAdvance: empEditOverrides[row.employeeId]?.salaryAdvance || 0,
			loanDeductions: empEditOverrides[row.employeeId]?.loanDeductions || 0,
			penalties: empEditOverrides[row.employeeId]?.penalties || 0,
			otherDeductions: empEditOverrides[row.employeeId]?.otherDeductions || 0,
			lateMinutes: lateMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalLateMinutes) ?? 0,
			underWorkedMinutes: underWorkedMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalUnderWorkedMinutes) ?? 0,
			lateDeduction: (() => {
				if (lateDeductionOverrides[row.employeeId] !== undefined) return lateDeductionOverrides[row.employeeId];
				const totSal = (basicSalaries[row.employeeId]||0)+(otherAllowances[row.employeeId]||0)+(accommodationAllowances[row.employeeId]||0)+(travelAllowances[row.employeeId]||0)+(foodAllowances[row.employeeId]||0);
				const hr = totSal / 240;
				const effL = lateMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalLateMinutes) ?? 0;
				return effL > 0 ? parseFloat(((effL / 60) * hr).toFixed(2)) : 0;
			})(),
			underWorkedDeduction: (() => {
				if (underWorkedDeductionOverrides[row.employeeId] !== undefined) return underWorkedDeductionOverrides[row.employeeId];
				const totSal = (basicSalaries[row.employeeId]||0)+(otherAllowances[row.employeeId]||0)+(accommodationAllowances[row.employeeId]||0)+(travelAllowances[row.employeeId]||0)+(foodAllowances[row.employeeId]||0);
				const hr = totSal / 240;
				const effU = underWorkedMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalUnderWorkedMinutes) ?? 0;
				return effU > 0 ? parseFloat(((effU / 60) * hr).toFixed(2)) : 0;
			})(),
			unapprovedLeaveDeduction: (() => {
				if (unapprovedLeaveDeductionOverrides[row.employeeId] !== undefined) return unapprovedLeaveDeductionOverrides[row.employeeId];
				if (!((row.employmentStatus === 'Remote Job' ? 0 : row.totalUnapprovedDaysOff) > 0)) return 0;
				const totSal = (basicSalaries[row.employeeId]||0)+(otherAllowances[row.employeeId]||0)+(accommodationAllowances[row.employeeId]||0)+(travelAllowances[row.employeeId]||0)+(foodAllowances[row.employeeId]||0);
				const hr = totSal / 240;
				return parseFloat(((row.employmentStatus === 'Remote Job' ? 0 : row.totalUnapprovedDaysOff) * 8 * hr).toFixed(2));
			})(),
			incompleteDayDeduction: (() => {
				if (incompleteDayDeductionOverrides[row.employeeId] !== undefined) return incompleteDayDeductionOverrides[row.employeeId];
				if (!((row.employmentStatus === 'Remote Job' ? 0 : row.totalIncompleteDays) > 0)) return 0;
				const totSal = (basicSalaries[row.employeeId]||0)+(otherAllowances[row.employeeId]||0)+(accommodationAllowances[row.employeeId]||0)+(travelAllowances[row.employeeId]||0)+(foodAllowances[row.employeeId]||0);
				const hr = totSal / 240;
				return parseFloat(((row.employmentStatus === 'Remote Job' ? 0 : row.totalIncompleteDays) * 8 * hr).toFixed(2));
			})(),
			foodDeductionActive: foodDeductionActives[row.employeeId] ?? false,
		};
		showEmpEditModal = true;
	}

	// Store for manual deductions not in DB
	let empEditOverrides: { [key: string]: { salaryAdvance: number; loanDeductions: number; penalties: number; otherDeductions: number } } = {};
	let lateMinutesOverrides: { [key: string]: number } = {};
	let underWorkedMinutesOverrides: { [key: string]: number } = {};
	let lateDeductionOverrides: { [key: string]: number } = {};
	let underWorkedDeductionOverrides: { [key: string]: number } = {};
	let unapprovedLeaveDeductionOverrides: { [key: string]: number } = {};
	let incompleteDayDeductionOverrides: { [key: string]: number } = {};

	function applyEmpEdit() {
		if (!empEditRow) return;
		const id = empEditRow.employeeId;
		basicSalaries[id] = Number(empEdit.basicSalary) || 0;
		paymentModes[id] = empEdit.basicPaymentMode;
		otherAllowances[id] = Number(empEdit.otherAllowance) || 0;
		otherAllowancePaymentModes[id] = empEdit.otherAllowancePaymentMode;
		accommodationAllowances[id] = Number(empEdit.accommodation) || 0;
		accommodationPaymentModes[id] = empEdit.accommodationPaymentMode;
		travelAllowances[id] = Number(empEdit.travel) || 0;
		travelPaymentModes[id] = empEdit.travelPaymentMode;
		foodAllowances[id] = Number(empEdit.food) || 0;
		foodPaymentModes[id] = empEdit.foodPaymentMode;
		gosiDeductions[id] = Number(empEdit.gosiDeduction) || 0;
		posShortageDeductions[id] = Number(empEdit.posShortage) || 0;
		empEditOverrides[id] = {
			salaryAdvance: Number(empEdit.salaryAdvance) || 0,
			loanDeductions: Number(empEdit.loanDeductions) || 0,
			penalties: Number(empEdit.penalties) || 0,
			otherDeductions: Number(empEdit.otherDeductions) || 0,
		};
		lateMinutesOverrides[id] = Number(empEdit.lateMinutes) || 0;
		underWorkedMinutesOverrides[id] = Number(empEdit.underWorkedMinutes) || 0;
		lateDeductionOverrides[id] = Number(empEdit.lateDeduction) || 0;
		underWorkedDeductionOverrides[id] = Number(empEdit.underWorkedDeduction) || 0;
		unapprovedLeaveDeductionOverrides[id] = Number(empEdit.unapprovedLeaveDeduction) || 0;
		incompleteDayDeductionOverrides[id] = Number(empEdit.incompleteDayDeduction) || 0;
		foodDeductionActives[id] = empEdit.foodDeductionActive ?? false;
		// trigger reactivity
		basicSalaries = basicSalaries;
		paymentModes = paymentModes;
		otherAllowances = otherAllowances;
		otherAllowancePaymentModes = otherAllowancePaymentModes;
		accommodationAllowances = accommodationAllowances;
		accommodationPaymentModes = accommodationPaymentModes;
		travelAllowances = travelAllowances;
		travelPaymentModes = travelPaymentModes;
		foodAllowances = foodAllowances;
		foodPaymentModes = foodPaymentModes;
		gosiDeductions = gosiDeductions;
		posShortageDeductions = posShortageDeductions;
		empEditOverrides = empEditOverrides;
		lateMinutesOverrides = lateMinutesOverrides;
		underWorkedMinutesOverrides = underWorkedMinutesOverrides;
		lateDeductionOverrides = lateDeductionOverrides;
		underWorkedDeductionOverrides = underWorkedDeductionOverrides;
		unapprovedLeaveDeductionOverrides = unapprovedLeaveDeductionOverrides;
		incompleteDayDeductionOverrides = incompleteDayDeductionOverrides;
		showEmpEditModal = false;
	}

	// Reactive filtering and sorting for the view
	$: filteredAnalysisData = analysisData
		.filter(row => {
			const matchesSearch = !searchQuery || 
				String(row.employeeId).toLowerCase().includes(searchQuery.toLowerCase()) || 
				row.employeeName.toLowerCase().includes(searchQuery.toLowerCase()) ||
				(row.idNumber && String(row.idNumber).toLowerCase().includes(searchQuery.toLowerCase()));
			
			const matchesBranch = !selectedBranch || String(row.currentBranchId) === String(selectedBranch);
			
			const isNotExcluded = row.employeeId !== 'EMP51';
			
			return matchesSearch && matchesBranch && isNotExcluded;
		})
		.sort((a, b) => {
			// 1. Sort by employment status first
			const statusOrder: { [key: string]: number } = {
				'Job (With Finger)': 1,
				'Remote Job': 2
			};
			const statusOrderA = statusOrder[a.employmentStatus] || 99;
			const statusOrderB = statusOrder[b.employmentStatus] || 99;
			if (statusOrderA !== statusOrderB) return statusOrderA - statusOrderB;

			// 2. Within same status, sort by nationality (Saudi Arabia first)
			const aIsSaudi = a.nationality?.toLowerCase() === 'saudi arabia';
			const bIsSaudi = b.nationality?.toLowerCase() === 'saudi arabia';
			if (aIsSaudi && !bIsSaudi) return -1;
			if (!aIsSaudi && bIsSaudi) return 1;

			// If both are Saudi or both are non-Saudi, sort by nationality name
			const natCompare = (a.nationality || '').localeCompare(b.nationality || '');
			if (natCompare !== 0) return natCompare;

			// 3. Finally sort by employee ID
			return String(a.employeeId).localeCompare(String(b.employeeId), undefined, { numeric: true });
		});

	// Compute per-row salary numbers (mirrors table cell formulas)
	function computeRowSalary(row: any) {
		const basicSal = basicSalaries[row.employeeId] || 0;
		const otherAllow = otherAllowances[row.employeeId] || 0;
		const accommAllow = accommodationAllowances[row.employeeId] || 0;
		const travelAllow = travelAllowances[row.employeeId] || 0;
		const foodAllow = foodAllowances[row.employeeId] || 0;
		const gosiDed = gosiDeductions[row.employeeId] || 0;

		const totalAllowances = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
		let grossWorkedSalary = totalAllowances;
		if (row.employmentStatus === 'Remote Job') {
			const wdRaw = editableWorkedDays[row.employeeId];
			const wd = (wdRaw !== undefined && wdRaw !== '') ? parseFloat(wdRaw) : (row.totalExpectedWorkDays || 0);
			const expWd = row.totalExpectedWorkDays || 0;
			if (expWd > 0) grossWorkedSalary = totalAllowances * (wd / expWd);
		}

		const hourlyRate = totalAllowances / 240;
		const shiftHoursPerDay = 8;

		// Remote Job has no fingerprint data - zero out attendance-derived deductions (mirrors cell logic)
		const _isRemote = row.employmentStatus === 'Remote Job';
		const lateOvr = lateDeductionOverrides[row.employeeId];
		const underOvr = underWorkedDeductionOverrides[row.employeeId];
		const unapOvr = unapprovedLeaveDeductionOverrides[row.employeeId];
		const incompOvr = incompleteDayDeductionOverrides[row.employeeId];
		const effLate = _isRemote ? 0 : (lateMinutesOverrides[row.employeeId] ?? row.totalLateMinutes ?? 0);
		const effUnder = _isRemote ? 0 : (underWorkedMinutesOverrides[row.employeeId] ?? row.totalUnderWorkedMinutes ?? 0);
		const effIncompDays = _isRemote ? 0 : (row.totalIncompleteDays || 0);
		const effUnapDays = _isRemote ? 0 : (row.totalUnapprovedDaysOff || 0);

		let lateDeduction = 0;
		let underWorkedDeduction = 0;
		let unapprovedLeaveDeduction = 0;
		let incompleteDayDeduction = 0;

		if (lateOvr !== undefined) lateDeduction = _isRemote ? 0 : lateOvr;
		else if (effLate > 0) lateDeduction = (effLate / 60) * hourlyRate;

		if (underOvr !== undefined) underWorkedDeduction = _isRemote ? 0 : underOvr;
		else if (effUnder > 0) underWorkedDeduction = (effUnder / 60) * hourlyRate;

		if (incompOvr !== undefined) incompleteDayDeduction = _isRemote ? 0 : incompOvr;
		else if (effIncompDays > 0) incompleteDayDeduction = effIncompDays * shiftHoursPerDay * hourlyRate;

		if (unapOvr !== undefined) unapprovedLeaveDeduction = _isRemote ? 0 : unapOvr;
		else if (effUnapDays > 0) unapprovedLeaveDeduction = effUnapDays * shiftHoursPerDay * hourlyRate;

		const salaryAdvanceDed = empEditOverrides[row.employeeId]?.salaryAdvance || 0;
		const loanDed = empEditOverrides[row.employeeId]?.loanDeductions || 0;
		const penaltiesDed = empEditOverrides[row.employeeId]?.penalties || 0;
		const otherDed = empEditOverrides[row.employeeId]?.otherDeductions || 0;
		const posShortageDed = posShortageDeductions[row.employeeId] || 0;
		const foodDeductionDed = (foodDeductionActives[row.employeeId] ?? false) ? foodAllow : 0;

		const totalDeductions = gosiDed + lateDeduction + underWorkedDeduction + unapprovedLeaveDeduction
			+ salaryAdvanceDed + loanDed + penaltiesDed + incompleteDayDeduction + posShortageDed + otherDed + foodDeductionDed;

		const netSalary = grossWorkedSalary - totalDeductions;

		const basicPayMode = paymentModes[row.employeeId] || 'Bank';
		const otherPayMode = otherAllowancePaymentModes[row.employeeId] || 'Bank';
		const accommPayMode = accommodationPaymentModes[row.employeeId] || 'Bank';
		const travelPayMode = travelPaymentModes[row.employeeId] || 'Bank';
		const foodPayMode = foodPaymentModes[row.employeeId] || 'Bank';
		const isFoodDed = foodDeductionActives[row.employeeId] ?? false;
		// When food deduction toggle is ON, food is fully deducted — exclude it from distribution entirely
		const distFoodAllow = isFoodDed ? 0 : foodAllow;
		let bankAllow = 0;
		if (basicPayMode === 'Bank') bankAllow += basicSal;
		if (otherPayMode === 'Bank') bankAllow += otherAllow;
		if (accommPayMode === 'Bank') bankAllow += accommAllow;
		if (travelPayMode === 'Bank') bankAllow += travelAllow;
		if (foodPayMode === 'Bank') bankAllow += distFoodAllow;
		const distTotal = basicSal + otherAllow + accommAllow + travelAllow + distFoodAllow;
		const bankRatio = distTotal > 0 ? bankAllow / distTotal : 0;
		const netBank = netSalary * bankRatio;
		const netCash = netSalary - netBank;

		return { gross: grossWorkedSalary, totalDeductions, netSalary, netBank, netCash };
	}

	// Compute totals over current filtered rows. Reads module state directly.
	function computeSalaryTotals() {
		const rows = filteredAnalysisData || [];
		const t = {
			totalEmployees: rows.length,
			countFingerJob: 0, countRemoteJob: 0,
			workedMinutes: 0, expectedMinutes: 0, underWorkedMinutes: 0, lateMinutes: 0,
			incompleteDays: 0, incompleteDeductions: 0, unapprovedDaysOff: 0,
			officialLeaveDays: 0, approvedDaysOff: 0, expectedWorkDays: 0, workedDays: 0,
			basicSalary: 0, otherAllowance: 0, accommodation: 0, travel: 0, foodAllowance: 0,
			foodDeduction: 0, gosiDeduction: 0, lateDeductions: 0, underWorkedDeductions: 0,
			posShortage: 0, salaryAdvance: 0, loanDeductions: 0, penalties: 0,
			unapprovedLeaveDeductions: 0, otherDeductions: 0,
			totalGross: 0, totalDed: 0, totalNet: 0, totalBank: 0, totalCash: 0
		};
		const branchMap = new Map<string, { name: string; count: number; net: number; bank: number; cash: number }>();
		for (const r of rows) {
			if (r.employmentStatus === 'Remote Job') t.countRemoteJob++;
			else if (r.employmentStatus === 'Job (With Finger)') t.countFingerJob++;
			const basicSal = basicSalaries[r.employeeId] || 0;
			const otherAllow = otherAllowances[r.employeeId] || 0;
			const accommAllow = accommodationAllowances[r.employeeId] || 0;
			const travelAllow = travelAllowances[r.employeeId] || 0;
			const foodAllow = foodAllowances[r.employeeId] || 0;
			const gosiDed = gosiDeductions[r.employeeId] || 0;
			const totalAllowances = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
			const hourlyRate = totalAllowances / 240;
			const shiftHoursPerDay = 8;
			t.basicSalary += basicSal; t.otherAllowance += otherAllow; t.accommodation += accommAllow;
			t.travel += travelAllow; t.foodAllowance += foodAllow; t.gosiDeduction += gosiDed;
			// Remote Job: zero out attendance counts (no fingerprint data)
			const isRemote = r.employmentStatus === 'Remote Job';
			t.workedMinutes += r.totalWorkedMinutes || 0;
			t.expectedMinutes += r.totalExpectedMinutes || 0;
			t.underWorkedMinutes += isRemote ? 0 : ((underWorkedMinutesOverrides[r.employeeId] ?? r.totalUnderWorkedMinutes) || 0);
			t.lateMinutes += isRemote ? 0 : ((lateMinutesOverrides[r.employeeId] ?? r.totalLateMinutes) || 0);
			t.incompleteDays += isRemote ? 0 : (r.totalIncompleteDays || 0);
			t.unapprovedDaysOff += isRemote ? 0 : (r.totalUnapprovedDaysOff || 0);
			t.officialLeaveDays += r.totalOfficialLeaveDays || 0;
			t.approvedDaysOff += r.totalApprovedDaysOff || 0;
			t.expectedWorkDays += r.totalExpectedWorkDays || 0;
			// Worked Days: mirror input cell fallback chain
			const wdRaw = editableWorkedDays[r.employeeId];
			let wd: number;
			if (wdRaw !== undefined && wdRaw !== '') wd = parseFloat(wdRaw);
			else if (isRemote) wd = r.totalExpectedWorkDays || 0;
			else wd = r.totalWorkedDays || 0;
			t.workedDays += isNaN(wd) ? 0 : wd;
			const lateOvr = lateDeductionOverrides[r.employeeId];
			const underOvr = underWorkedDeductionOverrides[r.employeeId];
			const unapOvr = unapprovedLeaveDeductionOverrides[r.employeeId];
			const incompOvr = incompleteDayDeductionOverrides[r.employeeId];
			const effLate = lateMinutesOverrides[r.employeeId] ?? r.totalLateMinutes ?? 0;
			const effUnder = underWorkedMinutesOverrides[r.employeeId] ?? r.totalUnderWorkedMinutes ?? 0;
			let lateDed = 0;
			if (lateOvr !== undefined) lateDed = lateOvr;
			else if (effLate > 0) lateDed = (effLate / 60) * hourlyRate;
			let underDed = 0;
			if (underOvr !== undefined) underDed = underOvr;
			else if (effUnder > 0) underDed = (effUnder / 60) * hourlyRate;
			// Mirror cell: only deduct if employee has a shift configured
			const _hasShift = !!employeeShifts.get(String(r.employeeId));
			let incompDed = 0;
			if (incompOvr !== undefined) incompDed = incompOvr;
			else if (_hasShift && (r.totalIncompleteDays || 0) > 0) incompDed = (r.totalIncompleteDays || 0) * shiftHoursPerDay * hourlyRate;
			let unapDed = 0;
			if (unapOvr !== undefined) unapDed = unapOvr;
			else if ((r.totalUnapprovedDaysOff || 0) > 0) unapDed = (r.totalUnapprovedDaysOff || 0) * shiftHoursPerDay * hourlyRate;
			if (r.employmentStatus === 'Remote Job') { lateDed = 0; underDed = 0; incompDed = 0; unapDed = 0; }
			t.lateDeductions += lateDed;
			t.underWorkedDeductions += underDed;
			t.incompleteDeductions += incompDed;
			t.unapprovedLeaveDeductions += unapDed;
			t.posShortage += posShortageDeductions[r.employeeId] || 0;
			t.salaryAdvance += empEditOverrides[r.employeeId]?.salaryAdvance || 0;
			t.loanDeductions += empEditOverrides[r.employeeId]?.loanDeductions || 0;
			t.penalties += empEditOverrides[r.employeeId]?.penalties || 0;
			t.otherDeductions += empEditOverrides[r.employeeId]?.otherDeductions || 0;
			t.foodDeduction += (foodDeductionActives[r.employeeId] ?? false) ? foodAllow : 0;
			const s = computeRowSalary(r);
			t.totalGross += s.gross;
			t.totalDed += s.totalDeductions;
			t.totalNet += s.netSalary;
			t.totalBank += s.netBank;
			t.totalCash += s.netCash;
			const bId = String(r.currentBranchId || '');
			const branchObj = branches.find((b: any) => String(b.id) === bId);
			const bName = branchObj ? ($locale === 'ar' ? (branchObj.name_ar || branchObj.name_en) : branchObj.name_en) : 'Unassigned';
			const cur = branchMap.get(bId) || { name: bName, count: 0, net: 0, bank: 0, cash: 0 };
			cur.count += 1; cur.net += s.netSalary; cur.bank += s.netBank; cur.cash += s.netCash;
			branchMap.set(bId, cur);
		}
		const branchBreakdown = Array.from(branchMap.values()).sort((a, b) => b.net - a.net);
		return { ...t, branchBreakdown };
	}

	// Reactive totals - re-runs whenever any referenced map mutates (we reassign maps after every edit).
	$: salaryTotals = (
		filteredAnalysisData,
		basicSalaries, otherAllowances, accommodationAllowances, travelAllowances, foodAllowances,
		gosiDeductions, paymentModes, otherAllowancePaymentModes, accommodationPaymentModes,
		travelPaymentModes, foodPaymentModes, foodDeductionActives,
		editableWorkedDays, lateMinutesOverrides, underWorkedMinutesOverrides,
		lateDeductionOverrides, underWorkedDeductionOverrides, unapprovedLeaveDeductionOverrides,
		incompleteDayDeductionOverrides, posShortageDeductions, empEditOverrides, branches,
		computeSalaryTotals()
	);

	// Cache for shifts and day offs to avoid repeated DB calls
	let employeeShifts: Map<string, any> = new Map();
	let employeeDayOffs: Map<string, any> = new Map();
	let employeeSpecialShiftsDateWise: Map<string, any[]> = new Map();
	let employeeSpecialShiftsWeekday: Map<string, any[]> = new Map();
	let employeeSpecificDayOffs: Map<string, any[]> = new Map();
	// ====================================================================
	// SAVED STATEMENTS â€” Save / Load / Update via RPC
	// ====================================================================
	let currentSavedStatementId: string | null = null;
	let isLoadedFromSaved = false;
	let isModified = false;
	let originalLoadedSnapshotJson = '';

	let showSaveModal = false;
	let showLoadModal = false;
	let saveStatementName = '';
	let saveBusy = false;
	let saveError = '';
	let saveNotice = '';
	let loadList: any[] = [];
	let loadListLoading = false;

// ====================================================================
// MUDAD EXPORTER
// ====================================================================
let showMudadModal = false;
let mudadTemplateFile: File | null = null;
let mudadProcessing = false;
let mudadError = '';
let mudadSuccess = '';
let mudadFileInputEl: HTMLInputElement;

function normalizeLegalId(value: any): string {
if (value === null || value === undefined) return '';
return String(value).trim().replace(/\s+/g, '');
}

/** Build a map from normalized Legal Id -> mudad values for all current filteredAnalysisData rows */
function buildMudadRowMap(): Map<string, { otherAllowances: number; leaveOfAbsence: number; otherDeductions: number }> {
	const map = new Map<string, { otherAllowances: number; leaveOfAbsence: number; otherDeductions: number }>();
	for (const row of filteredAnalysisData) {
		const legalId = normalizeLegalId(row.idNumber);
		if (!legalId) continue;
		const empId = row.employeeId;
		const hourlyRate = (
			(basicSalaries[empId] || 0) +
			(otherAllowances[empId] || 0) +
			(accommodationAllowances[empId] || 0) +
			(travelAllowances[empId] || 0) +
			(foodAllowances[empId] || 0)
		) / 240;
		const shiftHPD = 8;
		const isRemote = row.employmentStatus === 'Remote Job';

		// Other Allowances — bank-paid only
		const otherAllow = otherAllowances[empId] || 0;
		const otherPayMode = (otherAllowancePaymentModes[empId] || 'Bank').toLowerCase();
		const otherAllowBank = otherPayMode !== 'cash' ? otherAllow : 0;

		const foodAllow = foodAllowances[empId] || 0;
		const foodDeductionActive = foodDeductionActives[empId] ?? false;
		const foodPayMode = (foodPaymentModes[empId] || 'Bank').toLowerCase();
		const foodAllowBank = (!foodDeductionActive && foodPayMode !== 'cash') ? foodAllow : 0;

		const otherAllowancesAmount = otherAllowBank + foodAllowBank;

		// Leave of Absence = incomplete + late + under worked deductions
		let incompleteDed = 0;
		const incompOvr = incompleteDayDeductionOverrides[empId];
		if (incompOvr !== undefined) incompleteDed = isRemote ? 0 : incompOvr;
		else if (!isRemote && (row.totalIncompleteDays || 0) > 0)
			incompleteDed = (row.totalIncompleteDays || 0) * shiftHPD * hourlyRate;

		let lateDed = 0;
		const lateOvr = lateDeductionOverrides[empId];
		const effLate = isRemote ? 0 : (lateMinutesOverrides[empId] ?? row.totalLateMinutes ?? 0);
		if (lateOvr !== undefined) lateDed = isRemote ? 0 : lateOvr;
		else if (effLate > 0) lateDed = (effLate / 60) * hourlyRate;

		let underDed = 0;
		const underOvr = underWorkedDeductionOverrides[empId];
		const effUnder = isRemote ? 0 : (underWorkedMinutesOverrides[empId] ?? row.totalUnderWorkedMinutes ?? 0);
		if (underOvr !== undefined) underDed = isRemote ? 0 : underOvr;
		else if (effUnder > 0) underDed = (effUnder / 60) * hourlyRate;

		const leaveOfAbsenceAmount = incompleteDed + lateDed + underDed;

		// Other Deductions = POS + advance + loan + penalties + other
		const otherDeductionsAmount =
			(posShortageDeductions[empId] || 0) +
			(empEditOverrides[empId]?.salaryAdvance || 0) +
			(empEditOverrides[empId]?.loanDeductions || 0) +
			(empEditOverrides[empId]?.penalties || 0) +
			(empEditOverrides[empId]?.otherDeductions || 0);

		map.set(legalId, {
			otherAllowances: otherAllowancesAmount,
			leaveOfAbsence: leaveOfAbsenceAmount,
			otherDeductions: otherDeductionsAmount
		});
	}
	return map;
}

/** Convert Excel column letters to 1-based column number: A=1, Z=26, AA=27 */
	function mudadColToNum(ref: string): number {
		const letters = ref.match(/^([A-Z]+)/)?.[1] || '';
		let n = 0;
		for (const ch of letters) n = n * 26 + ch.charCodeAt(0) - 64;
		return n;
	}

	/** Parse xl/sharedStrings.xml into an array of plain strings */
	async function parseMudadSharedStrings(zip: any): Promise<string[]> {
		const file = zip.file('xl/sharedStrings.xml');
		if (!file) return [];
		const xml: string = await file.async('string');
		const parser = new DOMParser();
		const doc = parser.parseFromString(xml, 'application/xml');
		const sis = doc.getElementsByTagName('si');
		const result: string[] = [];
		for (let i = 0; i < sis.length; i++) {
			const tEls = sis[i].getElementsByTagName('t');
			let text = '';
			for (let j = 0; j < tEls.length; j++) text += tEls[j].textContent || '';
			result.push(text);
		}
		return result;
	}

	/**
	 * Replaces <v> content inside specific cells by their cell ref (e.g. "I5").
	 * Only modifies the targeted cells — all other XML is left byte-for-byte identical.
	 */
	function updateMudadCells(xml: string, updates: Map<string, number>): string {
		let result = xml;
		for (const [cellRef, newValue] of updates) {
			// Build patterns that match this exact cell ref attribute
			// Handles both full <c r="REF" ...>...</c> and self-closing <c r="REF" .../>
			const rAttr = 'r="' + cellRef + '"';
			// Find the cell opening tag, inner content and closing tag
			// We use indexOf for safety instead of complex regexes
			let pos = 0;
			while (true) {
				const cellStart = result.indexOf('<c ', pos);
				if (cellStart === -1) break;
				// Find end of opening tag
				const tagEnd = result.indexOf('>', cellStart);
				if (tagEnd === -1) break;
				const openTag = result.substring(cellStart, tagEnd + 1);
				// Check if this is our target cell
				if (!openTag.includes(rAttr)) {
					pos = tagEnd + 1;
					continue;
				}
				if (openTag.endsWith('/>')) {
					// Self-closing: <c r="REF" s="3"/>  →  <c r="REF" s="3"><v>VALUE</v></c>
					const cleanOpen = openTag.slice(0, -2)
						.replace(/ t="[^"]*"/g, '')
						.replace(/ t='[^']*'/g, '');
					result = result.substring(0, cellStart) + cleanOpen + '><v>' + newValue + '</v></c>' + result.substring(tagEnd + 1);
					pos = cellStart + 1;
				} else {
					// Full element: find </c>
					const closeTag = result.indexOf('</c>', tagEnd + 1);
					if (closeTag === -1) { pos = tagEnd + 1; continue; }
					const cleanOpen = openTag
						.replace(/ t="[^"]*"/g, '')
						.replace(/ t='[^']*'/g, '');
					result = result.substring(0, cellStart) + cleanOpen + '<v>' + newValue + '</v></c>' + result.substring(closeTag + 4);
					pos = cellStart + 1;
				}
				break; // cell ref is unique per sheet row
			}
		}
		return result;
	}

	/** Find header row, match Legal Ids, return updated sheet XML and match count */
	function processMudadSheetXml(
		xml: string,
		sharedStrings: string[],
		mudadMap: Map<string, { otherAllowances: number; leaveOfAbsence: number; otherDeductions: number }>
	): { result: string; matchCount: number } {
		const HEADERS = ['Legal Id', 'Other Allowances (Amount)', 'Leave of Absence (Amount)', 'Other Deductions (Amount)'];
		const parser = new DOMParser();
		const doc = parser.parseFromString(xml, 'application/xml');
		const rows = Array.from(doc.getElementsByTagName('row'));

		let headerRowNum = -1;
		let legalIdCol = 0, otherAllowCol = 0, leaveAbsenceCol = 0, otherDedCol = 0;
		for (const row of rows) {
			if (headerRowNum !== -1) break;
			const colMap: Record<string, number> = {};
			for (const cell of Array.from(row.getElementsByTagName('c'))) {
				if (cell.getAttribute('t') !== 's') continue;
				const vEl = cell.querySelector('v');
				if (!vEl?.textContent) continue;
				const idx = parseInt(vEl.textContent);
				if (isNaN(idx)) continue;
				const str = sharedStrings[idx]?.trim();
				if (str) colMap[str] = mudadColToNum(cell.getAttribute('r') || '');
			}
			if (HEADERS.every(h => colMap[h])) {
				headerRowNum    = parseInt(row.getAttribute('r') || '0');
				legalIdCol      = colMap['Legal Id'];
				otherAllowCol   = colMap['Other Allowances (Amount)'];
				leaveAbsenceCol = colMap['Leave of Absence (Amount)'];
				otherDedCol     = colMap['Other Deductions (Amount)'];
			}
		}
		if (headerRowNum === -1) return { result: xml, matchCount: 0 };

		const updates = new Map<string, number>();
		for (const row of rows) {
			const rowNum = parseInt(row.getAttribute('r') || '0');
			if (rowNum <= headerRowNum) continue;
			let legalId = '';
			for (const cell of Array.from(row.getElementsByTagName('c'))) {
				if (mudadColToNum(cell.getAttribute('r') || '') !== legalIdCol) continue;
				const vEl = cell.querySelector('v');
				if (!vEl) break;
				const rawVal = cell.getAttribute('t') === 's'
					? sharedStrings[parseInt(vEl.textContent || '0')]
					: vEl.textContent;
				legalId = normalizeLegalId(rawVal);
				break;
			}
			if (!legalId) continue;
			const vals = mudadMap.get(legalId);
			if (!vals) continue;
			for (const cell of Array.from(row.getElementsByTagName('c'))) {
				const ref = cell.getAttribute('r') || '';
				const col = mudadColToNum(ref);
				if (col === otherAllowCol)       updates.set(ref, parseFloat(vals.otherAllowances.toFixed(2)));
				else if (col === leaveAbsenceCol) updates.set(ref, parseFloat(vals.leaveOfAbsence.toFixed(2)));
				else if (col === otherDedCol)     updates.set(ref, parseFloat(vals.otherDeductions.toFixed(2)));
			}
		}
		if (updates.size === 0) return { result: xml, matchCount: 0 };
		return { result: updateMudadCells(xml, updates), matchCount: Math.round(updates.size / 3) };
	}

	function handleMudadTemplateImport(file: File) {
		mudadError = '';
		mudadSuccess = '';
		if (!file) return;
		if (!file.name.match(/\.xlsx?$/i)) {
			mudadError = 'Please upload a valid Excel file (.xlsx or .xls).';
			mudadTemplateFile = null;
			return;
		}
		mudadTemplateFile = file;
		mudadSuccess = `Template ready: ${file.name}`;
	}

	async function exportMudadExcel() {
		if (!mudadTemplateFile) { mudadError = 'Please upload a Mudad template file first.'; return; }
		if (!filteredAnalysisData.length) { mudadError = 'No salary data loaded. Load a salary statement first.'; return; }
		mudadProcessing = true; mudadError = ''; mudadSuccess = '';
		try {
			// JSZip opens the XLSX as a raw ZIP — ALL parts (tables, drawings, autofilter) are fully preserved
			const JSZipMod: any = await import('jszip');
			const JSZip = JSZipMod.default ?? JSZipMod;
			const arrayBuffer = await mudadTemplateFile!.arrayBuffer();
			const zip = await JSZip.loadAsync(arrayBuffer);

			const sharedStrings = await parseMudadSharedStrings(zip);
			const mudadMap = buildMudadRowMap();

			let totalMatched = 0;
			const sheetPaths = Object.keys((zip as any).files).filter((f: string) =>
				/^xl\/worksheets\/sheet\d+\.xml$/i.test(f)
			);
			for (const sheetPath of sheetPaths) {
				const xml: string = await (zip as any).file(sheetPath)!.async('string');
				const { result, matchCount } = processMudadSheetXml(xml, sharedStrings, mudadMap);
				if (matchCount > 0) { (zip as any).file(sheetPath, result); totalMatched += matchCount; }
			}

			const blob: Blob = await (zip as any).generateAsync({
				type: 'blob',
				mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
				compression: 'DEFLATE',
				compressionOptions: { level: 6 }
			});
			const url = URL.createObjectURL(blob);
			const a = document.createElement('a');
			const today = new Date();
			const stamp = String(today.getFullYear()) + String(today.getMonth() + 1).padStart(2, '0') + String(today.getDate()).padStart(2, '0');
			a.href = url; a.download = 'Mudad_' + stamp + '.xlsx';
			document.body.appendChild(a); a.click();
			setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 1500);
			mudadSuccess = totalMatched > 0
				? 'Done — ' + totalMatched + ' employee(s) matched and exported.'
				: 'Warning: No employees were matched. Check that Legal Id values in the template match the salary data.';
		} catch (err: any) {
			console.error('Mudad export error:', err);
			mudadError = 'Export failed: ' + (err?.message || 'Unknown error');
		} finally {
			mudadProcessing = false;
		}
	}

	let loadingStatementId: string | null = null;

	function buildStatementSnapshot() {
		return {
			version: 1,
			savedAt: new Date().toISOString(),
			filters: { startDate, endDate, selectedBranch, searchQuery },
			datesInRange,
			analysisData,
			editableWorkedDays,
			basicSalaries,
			paymentModes,
			otherAllowances,
			otherAllowancePaymentModes,
			accommodationAllowances,
			accommodationPaymentModes,
			travelAllowances,
			travelPaymentModes,
			gosiDeductions,
			foodAllowances,
			foodPaymentModes,
			foodDeductionActives,
			posShortageDeductions,
			posDeductionsList,
			empEditOverrides,
			lateMinutesOverrides,
			underWorkedMinutesOverrides,
			lateDeductionOverrides,
			underWorkedDeductionOverrides,
			unapprovedLeaveDeductionOverrides,
			incompleteDayDeductionOverrides,
			colVis,
			employeeShifts: Array.from(employeeShifts.entries()),
		};
	}

	function restoreStatementSnapshot(snap: any) {
		if (!snap) return;
		if (snap.filters) {
			startDate = snap.filters.startDate || '';
			endDate = snap.filters.endDate || '';
			selectedBranch = snap.filters.selectedBranch ?? '';
			searchQuery = snap.filters.searchQuery || '';
		}
		datesInRange = Array.isArray(snap.datesInRange) ? snap.datesInRange : [];
		analysisData = Array.isArray(snap.analysisData) ? snap.analysisData : [];
		editableWorkedDays = snap.editableWorkedDays || {};
		basicSalaries = snap.basicSalaries || {};
		paymentModes = snap.paymentModes || {};
		otherAllowances = snap.otherAllowances || {};
		otherAllowancePaymentModes = snap.otherAllowancePaymentModes || {};
		accommodationAllowances = snap.accommodationAllowances || {};
		accommodationPaymentModes = snap.accommodationPaymentModes || {};
		travelAllowances = snap.travelAllowances || {};
		travelPaymentModes = snap.travelPaymentModes || {};
		gosiDeductions = snap.gosiDeductions || {};
		foodAllowances = snap.foodAllowances || {};
		foodPaymentModes = snap.foodPaymentModes || {};
		foodDeductionActives = snap.foodDeductionActives || {};
		posShortageDeductions = snap.posShortageDeductions || {};
		posDeductionsList = snap.posDeductionsList || {};
		empEditOverrides = snap.empEditOverrides || {};
		lateMinutesOverrides = snap.lateMinutesOverrides || {};
		underWorkedMinutesOverrides = snap.underWorkedMinutesOverrides || {};
		lateDeductionOverrides = snap.lateDeductionOverrides || {};
		underWorkedDeductionOverrides = snap.underWorkedDeductionOverrides || {};
		unapprovedLeaveDeductionOverrides = snap.unapprovedLeaveDeductionOverrides || {};
		incompleteDayDeductionOverrides = snap.incompleteDayDeductionOverrides || {};
		if (snap.colVis) colVis = { ...colVis, ...snap.colVis };
		if (Array.isArray(snap.employeeShifts)) {
			employeeShifts = new Map(snap.employeeShifts);
		} else {
			employeeShifts = new Map();
		}
	}

	function openSaveModal() {
		if (!analysisData || analysisData.length === 0) return;
		saveError = '';
		if (!saveStatementName) saveStatementName = `Salary ${startDate} to ${endDate}`;
		showSaveModal = true;
	}

	async function confirmSave() {
		saveError = '';
		if (!saveStatementName || !saveStatementName.trim()) { saveError = $t('hr.salaryStatement.statementNameRequiredError'); return; }
		if (!startDate || !endDate) { saveError = $t('hr.salaryStatement.dateRangeRequired'); return; }
		if (saveBusy) return;
		saveBusy = true;
		try {
			const snap = buildStatementSnapshot();
			const { data, error } = await supabase.rpc('create_salary_statement', {
				p_statement_name: saveStatementName.trim(),
				p_start_date: startDate,
				p_end_date: endDate,
				p_data_json: snap,
			});
			if (error) throw error;
			if (!data?.success) throw new Error(data?.error || 'Save failed');
			currentSavedStatementId = data.id;
			isLoadedFromSaved = true;
			isModified = false;
			originalLoadedSnapshotJson = JSON.stringify(buildStatementSnapshot());
			showSaveModal = false;
			saveNotice = $t('hr.salaryStatement.savedSuccessfully');
			setTimeout(() => { saveNotice = ''; }, 3000);
		} catch (e: any) {
			saveError = e?.message || String(e);
		} finally {
			saveBusy = false;
		}
	}

	async function openLoadModal() {
		showLoadModal = true;
		loadListLoading = true;
		loadList = [];
		saveError = '';
		try {
			const { data, error } = await supabase.rpc('list_salary_statements');
			if (error) throw error;
			if (!data?.success) throw new Error(data?.error || 'List failed');
			loadList = data.items || [];
		} catch (e: any) {
			saveError = e?.message || String(e);
		} finally {
			loadListLoading = false;
		}
	}

	async function selectAndLoadStatement(id: string) {
		if (loadingStatementId) return;
		loadingStatementId = id;
		saveError = '';
		try {
			const { data, error } = await supabase.rpc('get_salary_statement_by_id', { p_id: id });
			if (error) throw error;
			if (!data?.success) throw new Error(data?.error || 'Load failed');
			const item = data.item;
			restoreStatementSnapshot(item.data_json);
			currentSavedStatementId = item.id;
			saveStatementName = item.statement_name;
			isLoadedFromSaved = true;
			isModified = false;
			setTimeout(() => {
				originalLoadedSnapshotJson = JSON.stringify(buildStatementSnapshot());
			}, 60);
			showLoadModal = false;
			saveNotice = $t('hr.salaryStatement.loadedNamed').replace('{name}', item.statement_name);
			setTimeout(() => { saveNotice = ''; }, 3000);
		} catch (e: any) {
			saveError = e?.message || String(e);
		} finally {
			loadingStatementId = null;
		}
	}

	async function confirmUpdate() {
		if (!currentSavedStatementId || saveBusy) return;
		saveBusy = true;
		saveError = '';
		try {
			const snap = buildStatementSnapshot();
			const { data, error } = await supabase.rpc('update_salary_statement', {
				p_id: currentSavedStatementId,
				p_statement_name: (saveStatementName?.trim() || `Salary ${startDate} to ${endDate}`),
				p_start_date: startDate,
				p_end_date: endDate,
				p_data_json: snap,
			});
			if (error) throw error;
			if (!data?.success) throw new Error(data?.error || 'Update failed');
			isModified = false;
			originalLoadedSnapshotJson = JSON.stringify(snap);
			saveNotice = $t('hr.salaryStatement.updatedSuccessfully');
			setTimeout(() => { saveNotice = ''; }, 3000);
		} catch (e: any) {
			saveError = e?.message || String(e);
		} finally {
			saveBusy = false;
		}
	}

	function resetSavedStatementContext() {
		currentSavedStatementId = null;
		isLoadedFromSaved = false;
		isModified = false;
		originalLoadedSnapshotJson = '';
		saveStatementName = '';
	}

	// Lightweight change-detection (debounced) for loaded statements
	let _modCheckTimer: any = null;
	function _scheduleModCheck() {
		if (!isLoadedFromSaved || !originalLoadedSnapshotJson) { isModified = false; return; }
		if (_modCheckTimer) clearTimeout(_modCheckTimer);
		_modCheckTimer = setTimeout(() => {
			try {
				const cur = JSON.stringify(buildStatementSnapshot());
				isModified = cur !== originalLoadedSnapshotJson;
			} catch { /* ignore */ }
		}, 300);
	}
	$: void [
		basicSalaries, paymentModes, otherAllowances, otherAllowancePaymentModes,
		accommodationAllowances, accommodationPaymentModes, travelAllowances, travelPaymentModes,
		gosiDeductions, foodAllowances, foodPaymentModes, foodDeductionActives,
		posShortageDeductions, posDeductionsList, empEditOverrides,
		lateMinutesOverrides, underWorkedMinutesOverrides, lateDeductionOverrides,
		underWorkedDeductionOverrides, unapprovedLeaveDeductionOverrides,
		incompleteDayDeductionOverrides, editableWorkedDays, colVis, analysisData,
		startDate, endDate
	], _scheduleModCheck();


	// Realtime subscriptions
	let subscriptions: any[] = [];
	let reloadTimeout: any = null;
	let pollingInterval: any = null;
	let isRealtimeReload = false;

	let tableEl: HTMLTableElement | null = null;

	async function handleExportExcel() {
		try {
			if (!tableEl) {
				alert('No table to export.');
				return;
			}
			// Dynamic import - keeps initial bundle smaller
			const XLSX: any = await import('xlsx');
			// Clone so we can strip <input> and form controls (export their values as plain text)
			const clone = tableEl.cloneNode(true) as HTMLTableElement;
			// Replace inputs/selects with their values
			clone.querySelectorAll('input, select, textarea').forEach((el: any) => {
				const text = document.createTextNode(el.value ?? '');
				el.parentNode?.replaceChild(text, el);
			});
			// Remove elements explicitly hidden (so we don't export hidden columns)
			clone.querySelectorAll('.hidden').forEach((el) => el.parentNode?.removeChild(el));
			const ws = XLSX.utils.table_to_sheet(clone, { raw: false });

			// Convert numeric-looking string cells into real numbers so SUM formulas work,
			// then append a TOTAL row with SUM formulas for each numeric column so edits
			// in Excel automatically update the totals.
			try {
				const range = XLSX.utils.decode_range(ws['!ref']);
				const headerRow = range.s.r;
				const firstDataRow = headerRow + 1;
				const lastDataRow = range.e.r;
				const numericByCol: { [c: number]: boolean } = {};

				// Pass 1: detect numeric columns and convert numeric strings -> real numbers
				for (let c = range.s.c; c <= range.e.c; c++) {
					let hasNumeric = false;
					let hasNonNumeric = false;
					for (let r = firstDataRow; r <= lastDataRow; r++) {
						const addr = XLSX.utils.encode_cell({ r, c });
						const cell = ws[addr];
						if (!cell) continue;
						const raw = cell.v;
						if (raw === null || raw === undefined || raw === '') continue;
						if (typeof raw === 'number') { hasNumeric = true; continue; }
						const s = String(raw).trim().replace(/,/g, '');
						if (s === '' || s === '-') continue;
						const n = Number(s);
						if (Number.isFinite(n)) {
							cell.v = n;
							cell.t = 'n';
							delete cell.w;
							hasNumeric = true;
						} else {
							hasNonNumeric = true;
						}
					}
					numericByCol[c] = hasNumeric && !hasNonNumeric;
				}

				// Pass 2: append TOTAL row with SUM formulas for numeric columns
				if (lastDataRow >= firstDataRow) {
					const totalRow = lastDataRow + 1;
					let labelPlaced = false;
					for (let c = range.s.c; c <= range.e.c; c++) {
						const addr = XLSX.utils.encode_cell({ r: totalRow, c });
						if (numericByCol[c]) {
							const firstAddr = XLSX.utils.encode_cell({ r: firstDataRow, c });
							const lastAddr = XLSX.utils.encode_cell({ r: lastDataRow, c });
							ws[addr] = { t: 'n', f: `SUM(${firstAddr}:${lastAddr})` };
						} else if (!labelPlaced) {
							ws[addr] = { t: 's', v: 'TOTAL' };
							labelPlaced = true;
						}
					}
					range.e.r = totalRow;
					ws['!ref'] = XLSX.utils.encode_range(range);
				}
			} catch (totalErr) {
				console.warn('Could not append totals row with formulas:', totalErr);
			}

			const wb = XLSX.utils.book_new();
			XLSX.utils.book_append_sheet(wb, ws, 'Salary Statement');
			const today = new Date();
			const stamp = `${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}_${String(today.getHours()).padStart(2, '0')}${String(today.getMinutes()).padStart(2, '0')}`;
			XLSX.writeFile(wb, `Salary_Statement_${stamp}.xlsx`);
		} catch (err) {
			console.error('Export to Excel failed:', err);
			alert('Failed to export to Excel. See console for details.');
		}
	}

	async function handleRefresh() {
		if (loading || analysisData.length === 0) return;
		
		console.log('🔄 Manual refresh triggered');
		loading = true;
		
		try {
			// Clear ALL caches completely - shifts, day offs, salaries, everything
			employeeShifts = new Map();
			employeeDayOffs = new Map();
			employeeSpecialShiftsDateWise = new Map();
			employeeSpecialShiftsWeekday = new Map();
			employeeSpecificDayOffs = new Map();
			posShortageDeductions = {};
			posDeductionsList = {};
			
			// Clear salary data
			basicSalaries = {};
			paymentModes = {};
			otherAllowances = {};
			otherAllowancePaymentModes = {};
			accommodationAllowances = {};
			accommodationPaymentModes = {};
			travelAllowances = {};
			travelPaymentModes = {};
			gosiDeductions = {};
			foodAllowances = {};
			foodPaymentModes = {};
			editableWorkedDays = {};
			
			// Clear analysis data
			analysisData = [];
			datesInRange = [];
			
			// Reload initial data (to get fresh salary data)
			await loadInitialData();
			
			// Reload analysis with fresh data
			await loadAnalysis();
			console.log('✅ Data refreshed successfully');
		} catch (error) {
			console.error('❌ Error refreshing data:', error);
			alert('Error refreshing data. Please try again.');
		} finally {
			loading = false;
		}
	}

	function debouncedReload() {
		// Clear existing timeout to prevent multiple calls
		if (reloadTimeout) {
			clearTimeout(reloadTimeout);
		}
		
		// Set timeout and reload in background without blocking UI
		reloadTimeout = setTimeout(() => {
			if (startDate && endDate && analysisData.length > 0) {
				console.log('🔄 Background update starting...');
				
				// Flag that this is a realtime reload
				isRealtimeReload = true;
				
				// Reload in background asynchronously without blocking UI
				setTimeout(async () => {
					try {
						// Clear only the data that changes (shifts, day offs, pos deductions)
						employeeShifts = new Map();
						employeeDayOffs = new Map();
						employeeSpecialShiftsDateWise = new Map();
						employeeSpecialShiftsWeekday = new Map();
						employeeSpecificDayOffs = new Map();
						posShortageDeductions = {};
						posDeductionsList = {};
						
						// Reload analysis with fresh data
						await loadAnalysis();
						console.log('✅ Background update complete');
						isRealtimeReload = false;
					} catch (error) {
						console.error('❌ Background update error:', error);
						isRealtimeReload = false;
					}
				}, 100);
			}
		}, 1000);
	}

	onMount(async () => {
		await loadInitialData();
		// Realtime subscriptions disabled - causes too many reloads
		// await setupRealtimeSubscriptions();
		
		// Polling disabled - causes table to reload constantly
		// pollingInterval setup removed
		
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

	onDestroy(() => {
		// Cleanup timeout
		if (reloadTimeout) {
			clearTimeout(reloadTimeout);
		}
		
		// Cleanup polling interval (if enabled)
		if (pollingInterval) {
			clearInterval(pollingInterval);
		}
		
		// Cleanup all realtime subscriptions (if enabled)
		subscriptions.forEach(sub => {
			if (sub) {
				try {
					supabase.removeChannel(sub);
				} catch (e) {
					// ignore
				}
			}
		});
		subscriptions = [];
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
					id_number,
					whatsapp_number,
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
				.select('employee_id, basic_salary, payment_mode, other_allowance, other_allowance_payment_mode, accommodation_allowance, accommodation_payment_mode, travel_allowance, travel_payment_mode, gosi_deduction, food_allowance, food_payment_mode, food_deduction_active');
			
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
					foodDeductionActives[item.employee_id] = item.food_deduction_active ?? false;
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
			// Build filtered employee list (same branch/search filter as before)
			const filteredEmps = employees.filter(e => {
				const matchesBranch = !selectedBranch || String(e.current_branch_id) === String(selectedBranch);
				const matchesSearch = !searchQuery ||
					String(e.id).toLowerCase().includes(searchQuery.toLowerCase()) ||
					e.name_en.toLowerCase().includes(searchQuery.toLowerCase()) ||
					(e.name_ar && e.name_ar.includes(searchQuery)) ||
					(e.id_number && String(e.id_number).toLowerCase().includes(searchQuery.toLowerCase()));
				return matchesBranch && matchesSearch;
			});

			if (filteredEmps.length === 0) {
				loading = false;
				return;
			}

			const empIds = filteredEmps.map(e => e.id);

			// Fetch pre-computed attendance data + POS deductions in parallel
			// (same approach as AnalyzeAllWindow — reads from hr_analysed_attendance_data)
			const [{ data: rows, error }, { data: posDeductions }] = await Promise.all([
				supabase
					.from('hr_analysed_attendance_data')
					.select('*')
					.in('employee_id', empIds)
					.gte('shift_date', startDate)
					.lte('shift_date', endDate),
				supabase
					.from('pos_deduction_transfers')
					.select('*')
					.in('id', empIds)
					.eq('status', 'Proposed')
					.gte('date_closed_box', startDate)
					.lte('date_closed_box', endDate)
			]);

			if (error) throw error;

			// Process POS shortage deductions
			posShortageDeductions = {};
			posDeductionsList = {};
			posDeductions?.forEach(deduction => {
				const empId = String(deduction.id);
				if (!posDeductionsList[empId]) posDeductionsList[empId] = [];
				posDeductionsList[empId].push(deduction);
				if (!posShortageDeductions[empId]) posShortageDeductions[empId] = 0;
				posShortageDeductions[empId] += deduction.short_amount || 0;
			});

			// Group attendance rows by employee
			const rowsByEmp = new Map<string, any[]>();
			for (const row of (rows || [])) {
				const empId = String(row.employee_id);
				if (!rowsByEmp.has(empId)) rowsByEmp.set(empId, []);
				rowsByEmp.get(empId)!.push(row);
			}

			// Build employeeShifts map from attendance data (used by salary hourly-rate calculations)
			employeeShifts = new Map();
			for (const [empId, empRows] of rowsByEmp) {
				const shiftRow = empRows.find(r => r.shift_start_time && r.shift_end_time);
				if (shiftRow) {
					employeeShifts.set(empId, {
						id: empId,
						shift_start_time: shiftRow.shift_start_time,
						shift_end_time: shiftRow.shift_end_time
					});
				}
			}

			// Aggregate per-employee totals from pre-computed rows
			const results: any[] = [];
			for (const emp of filteredEmps) {
				const empId = String(emp.id);
				const empRows = rowsByEmp.get(empId) || [];

				let totalWorkedMinutes = 0;
				let totalLateMinutes = 0;
				let totalUnderWorkedMinutes = 0;
				let totalIncompleteDays = 0;
				let totalApprovedDaysOff = 0;   // Official weekly day offs (e.g. Friday)
				let totalOfficialLeaveDays = 0; // Specific approved leaves
				let totalUnapprovedDaysOff = 0;
				let totalWorkedDays = 0;
				const dayByDay: Record<string, any> = {};

				for (const row of empRows) {
					const dateStr = typeof row.shift_date === 'string'
						? row.shift_date.split('T')[0]
						: new Date(row.shift_date).toISOString().split('T')[0];

					const status = row.status || 'Absent';
					const workedMins = row.worked_minutes || 0;
					const lateMins = row.late_minutes || 0;
					const underMins = row.under_minutes || 0;

					dayByDay[dateStr] = { workedMins, status, lateMins, underMins };

					if (status === 'Official Day Off' || status === 'Official Holiday') {
						totalApprovedDaysOff++;
					} else if (status === 'Approved Leave (No Deduction)') {
						totalOfficialLeaveDays++;
					} else if (status === 'Absent' || status === 'Pending Approval' || status === 'Approved Leave (Deductible)' || status === 'Rejected-Deducted' || status === 'Rejected-Not Deducted') {
						totalUnapprovedDaysOff++;
					} else if (status === 'Check-Out Missing' || status === 'Check-In Missing') {
						totalIncompleteDays++;
					}

					totalWorkedMinutes += workedMins;
					totalLateMinutes += lateMins;
					totalUnderWorkedMinutes += underMins;
					if (workedMins > 0) totalWorkedDays++;
				}

				// Fill missing dates with Absent
				for (const date of datesInRange) {
					if (!dayByDay[date]) {
						dayByDay[date] = { workedMins: 0, status: 'Absent', lateMins: 0, underMins: 0 };
						totalUnapprovedDaysOff++;
					}
				}

				const totalExpectedWorkDays = datesInRange.length - totalApprovedDaysOff;
				const shiftRow = empRows.find(r => r.shift_start_time && r.shift_end_time);
				const shiftInfo = shiftRow
					? `${shiftRow.shift_start_time} - ${shiftRow.shift_end_time}`
					: '';

				results.push({
					employeeId: emp.id,
					employeeName: $locale === 'ar' ? emp.name_ar || emp.name_en : emp.name_en,
					currentBranchId: emp.current_branch_id,
					nationality: emp.nationality_name_en,
					employmentStatus: emp.employment_status,
					idNumber: emp.id_number ?? null,
					whatsappNumber: emp.whatsapp_number ?? null,
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
					totalWorkedDays
				});
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

	async function setupRealtimeSubscriptions() {
		try {
			// Subscribe to processed_fingerprint_transactions changes
			const fxnSub = supabase
				.channel('processed_fingerprint_transactions_changes')
				.on('postgres_changes', {
					event: '*',
					schema: 'public',
					table: 'processed_fingerprint_transactions'
				}, (payload) => {
					console.log('📡 Fingerprint transactions changed:', payload);
					debouncedReload();
				})
				.on('subscribe', (status) => {
					if (status === 'SUBSCRIBED') {
						console.log('✅ Subscribed to processed_fingerprint_transactions');
					}
				})
				.subscribe();
			subscriptions.push(fxnSub);

			// Subscribe to regular_shift changes
			const shiftSub = supabase
				.channel('regular_shift_changes')
				.on('postgres_changes', {
					event: '*',
					schema: 'public',
					table: 'regular_shift'
				}, (payload) => {
					console.log('📡 Shifts changed:', payload);
					debouncedReload();
				})
				.on('subscribe', (status) => {
					if (status === 'SUBSCRIBED') {
						console.log('✅ Subscribed to regular_shift');
					}
				})
				.subscribe();
			subscriptions.push(shiftSub);

			// Subscribe to day_off_weekday changes
			const dayOffWeekdaySub = supabase
				.channel('day_off_weekday_changes')
				.on('postgres_changes', {
					event: '*',
					schema: 'public',
					table: 'day_off_weekday'
				}, (payload) => {
					console.log('📡 Day off weekday changed:', payload);
					debouncedReload();
				})
				.on('subscribe', (status) => {
					if (status === 'SUBSCRIBED') {
						console.log('✅ Subscribed to day_off_weekday');
					}
				})
				.subscribe();
			subscriptions.push(dayOffWeekdaySub);

			// Subscribe to special_shift_date_wise changes
			const specialShiftDWSub = supabase
				.channel('special_shift_date_wise_changes')
				.on('postgres_changes', {
					event: '*',
					schema: 'public',
					table: 'special_shift_date_wise'
				}, (payload) => {
					console.log('📡 Special shift date-wise changed:', payload);
					debouncedReload();
				})
				.on('subscribe', (status) => {
					if (status === 'SUBSCRIBED') {
						console.log('✅ Subscribed to special_shift_date_wise');
					}
				})
				.subscribe();
			subscriptions.push(specialShiftDWSub);

			// Subscribe to special_shift_weekday changes
			const specialShiftWDSub = supabase
				.channel('special_shift_weekday_changes')
				.on('postgres_changes', {
					event: '*',
					schema: 'public',
					table: 'special_shift_weekday'
				}, (payload) => {
					console.log('📡 Special shift weekday changed:', payload);
					debouncedReload();
				})
				.on('subscribe', (status) => {
					if (status === 'SUBSCRIBED') {
						console.log('✅ Subscribed to special_shift_weekday');
					}
				})
				.subscribe();
			subscriptions.push(specialShiftWDSub);

			// Subscribe to day_off changes
			const dayOffSub = supabase
				.channel('day_off_changes')
				.on('postgres_changes', {
					event: '*',
					schema: 'public',
					table: 'day_off'
				}, (payload) => {
					console.log('📡 Day off changed:', payload);
					debouncedReload();
				})
				.on('subscribe', (status) => {
					if (status === 'SUBSCRIBED') {
						console.log('✅ Subscribed to day_off');
					}
				})
				.subscribe();
			subscriptions.push(dayOffSub);

			// Subscribe to pos_deduction_transfers changes
			const posSub = supabase
				.channel('pos_deduction_transfers_changes')
				.on('postgres_changes', {
					event: '*',
					schema: 'public',
					table: 'pos_deduction_transfers'
				}, (payload) => {
					console.log('📡 POS deductions changed:', payload);
					debouncedReload();
				})
				.on('subscribe', (status) => {
					if (status === 'SUBSCRIBED') {
						console.log('✅ Subscribed to pos_deduction_transfers');
					}
				})
				.subscribe();
			subscriptions.push(posSub);

			console.log('✅ All realtime subscriptions initialized');
		} catch (error) {
			console.error('Error setting up realtime subscriptions:', error);
		}
	}

	async function togglePosDeductionForgiveness(deductionId: string, boxNumber: number, dateClosedBox: string, currentStatus: string) {
		try {
			const newStatus = currentStatus === 'Proposed' ? 'Forgiven' : 'Proposed';
			
			const { error } = await supabase
				.from('pos_deduction_transfers')
				.update({ status: newStatus })
				.eq('id', deductionId)
				.eq('box_number', boxNumber)
				.eq('date_closed_box', dateClosedBox);
			
			if (error) {
				console.error('Error updating POS deduction status:', error);
				alert('Failed to update status');
				return;
			}

			// Update local state
			const deductions = posDeductionsList[deductionId] || [];
			const deduction = deductions.find(d => d.box_number === boxNumber && d.date_closed_box === dateClosedBox);
			if (deduction) {
				deduction.status = newStatus;
				// Recalculate totals if changing to Forgiven
				if (newStatus === 'Forgiven') {
					posShortageDeductions[deductionId] -= deduction.short_amount || 0;
				} else {
					posShortageDeductions[deductionId] += deduction.short_amount || 0;
				}
				posDeductionsList = posDeductionsList; // Trigger reactivity
				posShortageDeductions = posShortageDeductions; // Trigger reactivity
			}
		} catch (error) {
			console.error('Error toggling POS deduction forgiveness:', error);
			alert('An error occurred');
		}
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
		(Object.values(dayByDay) as { workedMins: number; status: string; lateMins: number; underMins: number }[]).forEach(d => {
			if (d.workedMins > 0) actualWorkedDaysCount++;
		});

		const totalExpectedWorkDays = datesInRange.length - totalApprovedDaysOff;

		return {
			employeeId: emp.id,
			employeeName: $locale === 'ar' ? emp.name_ar || emp.name_en : emp.name_en,
			currentBranchId: emp.current_branch_id,
			nationality: emp.nationality_name_en,
			employmentStatus: emp.employment_status,
			idNumber: emp.id_number ?? null,
			whatsappNumber: emp.whatsapp_number ?? null,
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

function sanitizeWhatsappNumber(raw: string | null | undefined, defaultCountryCode = '966'): string | null {
if (!raw) return null;
let n = String(raw).replace(/[\s\-().+]/g, '');
if (n.startsWith('00')) n = n.slice(2);
if (n.startsWith('0')) n = defaultCountryCode + n.slice(1);
if (!/^\d{7,15}$/.test(n)) return null;
return n;
}

	function calculateTotalHoursInPeriod(shiftMins: number): number {
		// Calculate total hours from 25th of start month to 24th of end month
		if (!startDate || !endDate) return 0;
		
		try {
			const [startYear, startMonth, startDay] = startDate.split('-').map(Number);
			const [endYear, endMonth, endDay] = endDate.split('-').map(Number);
			
			// Start from 25th of start month
			const periodStart = new Date(startYear, startMonth - 1, 25);
			// End at 24th of end month
			const periodEnd = new Date(endYear, endMonth - 1, 24);
			
			// Calculate days between
			const timeDiff = periodEnd.getTime() - periodStart.getTime();
			const daysDiff = Math.ceil(timeDiff / (1000 * 60 * 60 * 24)) + 1; // +1 to include both start and end dates
			
			const shiftHoursPerDay = shiftMins / 60;
			return daysDiff * shiftHoursPerDay;
		} catch (e) {
			return 0;
		}
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
				<input id="emp-search" type="text" bind:value={searchQuery} placeholder="{$t('hr.salaryStatement.searchPlaceholder')}" class="w-full px-3 py-2 border rounded-lg text-sm" />
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
				on:click={handleRefresh}
				disabled={loading || analysisData.length === 0}
				class="px-6 py-2 bg-blue-600 text-white font-bold rounded-lg hover:bg-blue-700 transition-colors disabled:bg-slate-300 h-[38px] flex items-center gap-2"
				title="{$t('hr.salaryStatement.refreshTooltip')}"
			>
				<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
				</svg>
				Refresh
			</button>

			<button
				on:click={handleExportExcel}
				disabled={loading || analysisData.length === 0}
				class="px-6 py-2 bg-emerald-600 text-white font-bold rounded-lg hover:bg-emerald-700 transition-colors disabled:bg-slate-300 h-[38px] flex items-center gap-2"
				title="Export the table as shown to Excel"
			>
				<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3M3 17V7a2 2 0 012-2h6l2 2h6a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z" />
				</svg>
				Export Excel
			</button>

			
<button
on:click={() => { showMudadModal = true; mudadError = ''; mudadSuccess = ''; mudadTemplateFile = null; }}
disabled={loading || analysisData.length === 0}
class="px-6 py-2 bg-orange-600 text-white font-bold rounded-lg hover:bg-orange-700 transition-colors disabled:bg-slate-300 h-[38px] flex items-center gap-2"
title="Export salary data to Mudad Excel template"
>
<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
</svg>
Mudad Exporter
</button>
<!-- Column selector button -->
			<div class="relative">
				<button
					on:click={() => showColumnPanel = !showColumnPanel}
					class="px-4 py-2 bg-violet-600 text-white font-bold rounded-lg hover:bg-violet-700 transition-colors h-[38px] flex items-center gap-2"
					title="{$t('hr.salaryStatement.columnsTooltip')}"
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
					</svg>
					{$t('hr.salaryStatement.columns')}
				</button>
				{#if showColumnPanel}
					<!-- svelte-ignore a11y-click-events-have-key-events -->
					<!-- svelte-ignore a11y-no-static-element-interactions -->
					<div class="fixed inset-0 z-[9998]" on:click={() => showColumnPanel = false}></div>
					<div class="absolute top-full right-0 mt-1 bg-white border border-slate-200 rounded-xl shadow-2xl z-[9999] w-[270px] max-h-[520px] flex flex-col">
						<div class="px-4 py-3 bg-violet-600 text-white font-bold text-sm rounded-t-xl flex items-center justify-between shrink-0">
							<span>{$t('hr.salaryStatement.columnVisibility')}</span>
							<button on:click={() => showColumnPanel = false} class="text-white/80 hover:text-white text-lg leading-none">✕</button>
						</div>
						<div class="px-3 py-2 border-b border-slate-100 flex gap-2 shrink-0">
							<button on:click={() => toggleAllColumns(true)} class="text-xs px-3 py-1 bg-emerald-100 text-emerald-700 rounded-lg hover:bg-emerald-200 font-semibold">{$t('hr.salaryStatement.showAll')}</button>
							<button on:click={() => toggleAllColumns(false)} class="text-xs px-3 py-1 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 font-semibold">{$t('hr.salaryStatement.hideAll')}</button>
						</div>
						<div class="p-2 space-y-0.5 overflow-y-auto">
							{#each [
								['status', $t('hr.salaryStatement.status')],
				['idNumber', $t('hr.salaryStatement.idNumber')],
				['whatsappNumber', $t('hr.salaryStatement.whatsappNumber')],
								['workedHours', $t('hr.salaryStatement.totalWorkedHours')],
								['expectedHours', $t('hr.salaryStatement.totalExpectedHours')],
								['underWorkedHours', $t('hr.salaryStatement.totalUnderWorkedHours')],
								['lateHours', $t('hr.salaryStatement.totalLateHours')],
								['incompleteDays', $t('hr.salaryStatement.totalIncompleteDays')],
								['incompleteDeductions', $t('hr.salaryStatement.incompleteDeductions')],
								['unapprovedDaysOff', $t('hr.salaryStatement.unapprovedDaysOff')],
								['officialLeave', $t('hr.salaryStatement.officialLeaveDays')],
								['approvedDaysOff', $t('hr.salaryStatement.approvedDaysOff')],
								['expectedWorkDays', $t('hr.salaryStatement.expectedWorkDays')],
								['workedDays', $t('hr.salaryStatement.workedDays')],
								['basicSalary', $t('hr.salaryStatement.basicSalary')],
								['otherAllowance', $t('hr.salaryStatement.otherAllowance')],
								['accommodation', $t('hr.salaryStatement.accommodation')],
								['travel', $t('hr.salaryStatement.travel')],
								['foodAllowance', $t('hr.salaryStatement.foodAllowance')],
								['foodDeduction', $t('hr.salaryStatement.foodAllowanceDeduction')],
								['gosiDeduction', $t('hr.salaryStatement.gosiDeduction')],
								['lateDeductions', $t('hr.salaryStatement.lateDeductions')],
								['underWorkedDeductions', $t('hr.salaryStatement.underWorkedDeductions')],
								['posShortage', $t('hr.salaryStatement.posShortageDeduction')],
								['salaryAdvance', $t('hr.salaryStatement.salaryAdvanceDeductions')],
								['loanDeductions', $t('hr.salaryStatement.loanDeductions')],
								['penaltiesDeductions', $t('hr.salaryStatement.penaltiesDeductions')],
								['unapprovedLeaveDeductions', $t('hr.salaryStatement.unapprovedLeaveDeductions')],
								['otherDeductions', $t('hr.salaryStatement.otherDeductions')],
								['grossEarnings', $t('hr.salaryStatement.grossEarnings')],
								['totalDeductions', $t('hr.salaryStatement.totalDeductions')],
								['netSalary', $t('hr.salaryStatement.netSalary')],
								['netBank', $t('hr.salaryStatement.netBank')],
								['netCash', $t('hr.salaryStatement.netCash')],
							] as [key, label]}
								<label class="flex items-center gap-2.5 px-2 py-1.5 rounded-lg hover:bg-slate-50 cursor-pointer select-none">
									<input
										type="checkbox"
										checked={(colVis as any)[key]}
										on:change={(e) => { (colVis as any)[key] = (e.target as HTMLInputElement).checked; colVis = colVis; }}
										class="w-4 h-4 accent-violet-600 cursor-pointer"
									/>
									<span class="text-sm text-slate-700">{label}</span>
								</label>
							{/each}
						</div>
					</div>
				{/if}
			</div>

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
			<div class="h-full w-full bg-white rounded-xl shadow-lg border border-slate-200 flex flex-col overflow-hidden">
			<div class="flex-1 min-h-0 overflow-auto custom-scrollbar">
				<table bind:this={tableEl} class="w-max min-w-full border-separate border-spacing-0 text-start text-sm table-fixed" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
					<thead class="bg-slate-50">
						<tr>
							<th class="px-2 py-4 font-bold text-slate-700 border-b border-r w-[40px] sticky top-0 z-50 bg-slate-50 {$locale === 'ar' ? 'right-0' : 'left-0'}">
								<div class="flex justify-center italic text-[10px]">#</div>
							</th>
							<th class="px-4 py-4 font-bold text-slate-700 border-b border-r w-[100px] sticky top-0 z-50 bg-slate-50 {$locale === 'ar' ? 'right-[40px]' : 'left-[40px]'}">{$t('hr.employeeId')}</th>
							<th class="px-4 py-4 font-bold text-slate-700 border-b border-r w-[200px] sticky top-0 z-50 bg-slate-50 {$locale === 'ar' ? 'right-[140px]' : 'left-[140px]'}">{$t('hr.fullName')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-slate-700 border-b border-r bg-slate-50 text-center w-[130px] whitespace-nowrap {colVis.idNumber ? '' : 'hidden'}">{$t('hr.salaryStatement.idNumber')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-green-700 border-b border-r bg-green-50 text-center w-[160px] whitespace-nowrap {colVis.whatsappNumber ? '' : 'hidden'}">{$t('hr.salaryStatement.whatsappNumber')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-slate-700 border-b border-r bg-slate-50 text-center w-[130px] whitespace-nowrap {colVis.status ? '' : 'hidden'}">{$t('hr.salaryStatement.status')}</th>
							{#each datesInRange as date}
								<th class="sticky top-0 z-30 hidden px-3 py-2 font-bold text-slate-700 border-b border-r text-center w-[100px] whitespace-nowrap bg-slate-50">
									<div class="flex flex-col items-center">
										<span class="text-xs">{formatDateOnly(date)}</span>
										<span class="text-[9px] font-medium text-slate-500 capitalize">{getDayNameFull(date)}</span>
									</div>
								</th>
							{/each}
							<th class="sticky top-0 z-30 hidden px-4 py-4 font-bold text-indigo-700 border-b border-r bg-indigo-50 text-center w-[150px] whitespace-nowrap">{$t('hr.processFingerprint.total_worked_hours_minutes')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-emerald-700 border-b border-r bg-emerald-50 text-center w-[150px] whitespace-nowrap {colVis.workedHours ? '' : 'hidden'}">{$t('hr.salaryStatement.totalWorkedHours')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-teal-700 border-b border-r bg-teal-50 text-center w-[150px] whitespace-nowrap {colVis.expectedHours ? '' : 'hidden'}">{$t('hr.salaryStatement.totalExpectedHours')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-red-700 border-b border-r bg-red-50 text-center w-[150px] whitespace-nowrap {colVis.underWorkedHours ? '' : 'hidden'}">{$t('hr.processFingerprint.total_under_worked_hours_minutes')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-amber-700 border-b border-r bg-amber-50 text-center w-[150px] whitespace-nowrap {colVis.lateHours ? '' : 'hidden'}">{$t('hr.processFingerprint.total_late_hours_minutes')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-rose-700 border-b border-r bg-rose-50 text-center w-[120px] whitespace-nowrap {colVis.incompleteDays ? '' : 'hidden'}">{$t('hr.salaryStatement.totalIncompleteDays')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-pink-700 border-b border-r bg-pink-50 text-center w-[150px] whitespace-nowrap {colVis.incompleteDeductions ? '' : 'hidden'}">{$t('hr.salaryStatement.incompleteDeductions')}</th>
							<th class="sticky top-0 z-30 hidden px-4 py-4 font-bold text-rose-700 border-b border-r bg-rose-50 text-center w-[120px] whitespace-nowrap">{$t('hr.processFingerprint.total_incomplete_days')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-rose-800 border-b border-r bg-rose-50 text-center w-[120px] whitespace-nowrap {colVis.unapprovedDaysOff ? '' : 'hidden'}">{$t('hr.processFingerprint.total_unapproved_days_off')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-blue-700 border-b border-r bg-blue-50 text-center w-[120px] whitespace-nowrap {colVis.officialLeave ? '' : 'hidden'}">{$t('hr.processFingerprint.total_official_leave_days')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-emerald-700 border-b border-r bg-emerald-50 text-center w-[120px] whitespace-nowrap {colVis.approvedDaysOff ? '' : 'hidden'}">{$t('hr.processFingerprint.total_approved_days_off')}</th>
							<th class="px-4 py-4 font-bold text-indigo-800 border-b text-center w-[120px] whitespace-nowrap bg-indigo-50 sticky top-0 z-30 shadow-[-2px_0_4px_rgba(0,0,0,0.05)] border-l {colVis.expectedWorkDays ? '' : 'hidden'}">{$t('hr.processFingerprint.total_expected_work_days')}</th>
							<th class="px-4 py-4 font-bold text-slate-900 border-b text-center w-[120px] whitespace-nowrap bg-slate-100 sticky top-0 z-30 shadow-[-2px_0_4px_rgba(0,0,0,0.05)] border-l {colVis.workedDays ? '' : 'hidden'}">{$t('hr.processFingerprint.total_worked_days_header')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-green-800 border-b border-r bg-green-50 text-center w-[150px] whitespace-nowrap {colVis.basicSalary ? '' : 'hidden'}">{$t('hr.salaryStatement.basicSalary')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-amber-800 border-b border-r bg-amber-50 text-center w-[150px] whitespace-nowrap {colVis.otherAllowance ? '' : 'hidden'}">{$t('hr.salaryStatement.otherAllowance')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-cyan-800 border-b border-r bg-cyan-50 text-center w-[150px] whitespace-nowrap {colVis.accommodation ? '' : 'hidden'}">{$t('hr.salaryStatement.accommodation')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-blue-800 border-b border-r bg-blue-50 text-center w-[150px] whitespace-nowrap {colVis.travel ? '' : 'hidden'}">{$t('hr.salaryStatement.travel')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-orange-800 border-b border-r bg-orange-50 text-center w-[150px] whitespace-nowrap {colVis.foodAllowance ? '' : 'hidden'}">{$t('hr.salaryStatement.foodAllowance')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-red-600 border-b border-r bg-red-50 text-center w-[150px] whitespace-nowrap {colVis.foodDeduction ? '' : 'hidden'}">{$t('hr.salaryStatement.foodAllowanceDeduction')}</th>
							<th class="sticky top-0 z-30 px-4 py-4 font-bold text-red-800 border-b border-r bg-red-50 text-center w-[150px] whitespace-nowrap {colVis.gosiDeduction ? '' : 'hidden'}">{$t('hr.salaryStatement.gosiDeduction')}</th>
						<th class="sticky top-0 z-30 px-4 py-4 font-bold text-purple-700 border-b border-r bg-purple-50 text-center w-[150px] whitespace-nowrap {colVis.lateDeductions ? '' : 'hidden'}">{$t('hr.salaryStatement.lateDeductions')}</th>
						<th class="sticky top-0 z-30 px-4 py-4 font-bold text-indigo-700 border-b border-r bg-indigo-50 text-center w-[150px] whitespace-nowrap {colVis.underWorkedDeductions ? '' : 'hidden'}">{$t('hr.salaryStatement.underWorkedDeductions')}</th>
						<th class="sticky top-0 z-30 px-4 py-4 font-bold text-pink-700 border-b border-r bg-pink-50 text-center w-[150px] whitespace-nowrap {colVis.posShortage ? '' : 'hidden'}">{$t('hr.salaryStatement.posShortageDeduction')}</th>
						<th class="sticky top-0 z-30 px-4 py-4 font-bold text-rose-700 border-b border-r bg-rose-50 text-center w-[150px] whitespace-nowrap {colVis.salaryAdvance ? '' : 'hidden'}">{$t('hr.salaryStatement.salaryAdvanceDeductions')}</th>
						<th class="sticky top-0 z-30 px-4 py-4 font-bold text-fuchsia-700 border-b border-r bg-fuchsia-50 text-center w-[150px] whitespace-nowrap {colVis.loanDeductions ? '' : 'hidden'}">{$t('hr.salaryStatement.loanDeductions')}</th>
						<th class="sticky top-0 z-30 px-4 py-4 font-bold text-orange-700 border-b border-r bg-orange-50 text-center w-[150px] whitespace-nowrap {colVis.penaltiesDeductions ? '' : 'hidden'}">{$t('hr.salaryStatement.penaltiesDeductions')}</th>
						<th class="sticky top-0 z-30 px-4 py-4 font-bold text-sky-700 border-b border-r bg-sky-50 text-center w-[150px] whitespace-nowrap {colVis.unapprovedLeaveDeductions ? '' : 'hidden'}">{$t('hr.salaryStatement.unapprovedLeaveDeductions')}</th>
						<th class="sticky top-0 z-30 px-4 py-4 font-bold text-gray-700 border-b border-r bg-gray-50 text-center w-[150px] whitespace-nowrap {colVis.otherDeductions ? '' : 'hidden'}">{$t('hr.salaryStatement.otherDeductions')}</th>
						<th class="sticky top-0 z-40 px-4 py-4 font-bold text-emerald-800 border-b border-l bg-emerald-50 text-center w-[150px] whitespace-nowrap shadow-[-2px_0_4px_rgba(0,0,0,0.05)] {$locale === 'ar' ? 'left-[600px]' : 'right-[600px]'} {colVis.grossEarnings ? '' : 'hidden'}">{$t('hr.salaryStatement.grossEarnings')}</th>
						<th class="sticky top-0 z-40 px-4 py-4 font-bold text-rose-800 border-b border-l bg-rose-50 text-center w-[150px] whitespace-nowrap shadow-[-2px_0_4px_rgba(0,0,0,0.05)] {$locale === 'ar' ? 'left-[450px]' : 'right-[450px]'} {colVis.totalDeductions ? '' : 'hidden'}">{$t('hr.salaryStatement.totalDeductions')}</th>
						<th class="sticky top-0 z-40 px-4 py-4 font-bold text-yellow-800 border-b border-l bg-yellow-50 text-center w-[150px] whitespace-nowrap shadow-[-2px_0_4px_rgba(0,0,0,0.05)] {$locale === 'ar' ? 'left-[300px]' : 'right-[300px]'} {colVis.netSalary ? '' : 'hidden'}">{$t('hr.salaryStatement.netSalary')}</th>
						<th class="sticky top-0 z-40 px-4 py-4 font-bold text-blue-800 border-b border-r bg-blue-50 text-center w-[150px] whitespace-nowrap {$locale === 'ar' ? 'left-[150px]' : 'right-[150px]'} {colVis.netBank ? '' : 'hidden'}">{$t('hr.salaryStatement.netBank')}</th>
						<th class="sticky top-0 z-40 px-4 py-4 font-bold text-red-800 border-b border-r bg-red-50 text-center w-[150px] whitespace-nowrap {$locale === 'ar' ? 'left-0' : 'right-0'} {colVis.netCash ? '' : 'hidden'}">{$t('hr.salaryStatement.netCash')}</th></tr>
					</thead>
					<tbody class="divide-y divide-slate-200">
						{#each filteredAnalysisData as row, rowIdx}
							<tr class="transition-colors group {row.employmentStatus === 'Remote Job' ? 'bg-orange-50 even:bg-orange-100' : 'even:bg-slate-100'}">
								<td class="px-2 py-3 border-r sticky z-20 group-hover:bg-emerald-100 flex flex-col justify-center items-center gap-0.5 {$locale === 'ar' ? 'right-0' : 'left-0'} {row.employmentStatus === 'Remote Job' ? (rowIdx % 2 === 1 ? 'bg-orange-100' : 'bg-orange-50') : (rowIdx % 2 === 1 ? 'bg-slate-100' : 'bg-white')}">
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
									<button
										class="p-1 hover:bg-violet-100 rounded-full transition-colors text-violet-500"
										on:click={() => openEmpEdit(row)}
										title="{$t('hr.salaryStatement.editEmployeeValuesTooltip')}"
									>
										<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
										</svg>
									</button>
								</td>
								<!-- Notes button alongside employee ID -->
								<td class="px-4 py-3 font-mono font-medium text-slate-600 border-r sticky z-20 group-hover:bg-emerald-100 {$locale === 'ar' ? 'right-[40px]' : 'left-[40px]'} {row.employmentStatus === 'Remote Job' ? (rowIdx % 2 === 1 ? 'bg-orange-100' : 'bg-orange-50') : (rowIdx % 2 === 1 ? 'bg-slate-100' : 'bg-white')}">
									<div class="flex items-center gap-1">
										<span>{row.employeeId}</span>
										<button
											type="button"
											class="p-0.5 hover:bg-amber-100 rounded-full transition-colors text-amber-400 hover:text-amber-600 flex-shrink-0"
											on:click={() => openNotesPopup(row)}
											title={$t('hr.salaryNotes.openNotes')}
										>
											<svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
											</svg>
										</button>
									</div>
								</td>
								<td class="px-4 py-3 font-semibold text-slate-900 border-r sticky z-20 group-hover:bg-emerald-100 {$locale === 'ar' ? 'right-[140px]' : 'left-[140px]'} {row.employmentStatus === 'Remote Job' ? (rowIdx % 2 === 1 ? 'bg-orange-100' : 'bg-orange-50') : (rowIdx % 2 === 1 ? 'bg-slate-100' : 'bg-white')}">
									<div class="flex flex-col">
										<span>{row.employeeName}</span>
										{#if row.shiftInfo}
											<span class="text-[9px] text-slate-500 font-normal">{row.shiftInfo}</span>
										{/if}
									</div>
								</td>
								<td class="px-4 py-3 border-r text-center text-sm font-mono text-slate-700 w-[130px] whitespace-nowrap {colVis.idNumber ? '' : 'hidden'}">
									{row.idNumber || '—'}
								</td>
								<td class="px-4 py-3 border-r text-center w-[160px] {colVis.whatsappNumber ? '' : 'hidden'}">
									{#if row.whatsappNumber}
										<div class="flex items-center justify-center gap-2">
											<span dir="ltr" class="text-sm font-mono text-slate-700">{row.whatsappNumber}</span>
											{#if sanitizeWhatsappNumber(row.whatsappNumber)}
											<button
												type="button"
												class="flex-shrink-0 hover:scale-110 transition-transform"
												aria-label={$t('hr.salaryStatement.openWhatsapp')}
												title={$t('hr.salaryStatement.openWhatsapp')}
												on:click|stopPropagation={() => window.open(`https://wa.me/${sanitizeWhatsappNumber(row.whatsappNumber)}`, '_blank', 'noopener,noreferrer')}
											>
												<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><circle cx="12" cy="12" r="12" fill="#25D366"/><path fill="#ffffff" d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>
											</button>
											{/if}
										</div>
									{:else}
										<span class="text-slate-400">—</span>
									{/if}
								</td>
								<td class="px-3 py-3 border-r text-center w-[130px] {colVis.status ? '' : 'hidden'}">
									{#if row.employmentStatus === 'Job (With Finger)'}
										<span class="inline-block px-2 py-0.5 rounded text-[10px] font-semibold bg-green-100 text-green-800 whitespace-nowrap">{$t('hr.salaryStatement.withFinger')}</span>
									{:else if row.employmentStatus === 'Remote Job'}
										<span class="inline-block px-2 py-0.5 rounded text-[10px] font-semibold bg-blue-100 text-blue-800 whitespace-nowrap">{$t('hr.salaryStatement.remote')}</span>
									{:else}
										<span class="inline-block px-2 py-0.5 rounded text-[10px] font-semibold bg-slate-100 text-slate-600 whitespace-nowrap">{row.employmentStatus || '-'}</span>
									{/if}
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
								<td class="px-4 py-3 border-r text-center font-bold text-emerald-700 bg-emerald-50/20 w-[150px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors {colVis.workedHours ? '' : 'hidden'}">
									{(row.totalWorkedMinutes / 60).toFixed(2)} hrs
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-teal-700 bg-teal-50/20 w-[150px] whitespace-nowrap group-hover:bg-teal-100/50 transition-colors {colVis.expectedHours ? '' : 'hidden'}">
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
								<td class="px-4 py-3 border-r text-center font-bold text-red-700 bg-red-50/20 w-[150px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors {colVis.underWorkedHours ? '' : 'hidden'}">
									{formatMinutes(underWorkedMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalUnderWorkedMinutes))}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-amber-700 bg-amber-50/20 w-[150px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors {colVis.lateHours ? '' : 'hidden'}">
									{formatMinutes(lateMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalLateMinutes))}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-rose-700 bg-rose-50/20 w-[120px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors {colVis.incompleteDays ? '' : 'hidden'}">{(row.employmentStatus === 'Remote Job' ? 0 : row.totalIncompleteDays)}</td>
								<td class="px-4 py-3 border-r text-center font-bold text-pink-700 bg-pink-50/20 w-[150px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors {colVis.incompleteDeductions ? '' : 'hidden'}">
									{#if employeeShifts.get(String(row.employeeId)) && (row.employmentStatus === 'Remote Job' ? 0 : row.totalIncompleteDays) > 0}
										{(() => {
											const basicSal = basicSalaries[row.employeeId] || 0;
											const otherAllow = otherAllowances[row.employeeId] || 0;
											const accommAllow = accommodationAllowances[row.employeeId] || 0;
											const travelAllow = travelAllowances[row.employeeId] || 0;
											const foodAllow = foodAllowances[row.employeeId] || 0;
											const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
											const hourlyRate = totalSalary / 240;
											const incompleteDeduction = (row.employmentStatus === 'Remote Job' ? 0 : row.totalIncompleteDays) * 8 * hourlyRate;
											return incompleteDeduction.toFixed(2);
										})()}
									{:else}
										-
									{/if}
								</td>
								<td class="hidden px-4 py-3 border-r text-center font-bold text-rose-700 w-[120px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors">{(row.employmentStatus === 'Remote Job' ? 0 : row.totalIncompleteDays)}</td>
								<td class="px-4 py-3 border-r text-center font-bold text-rose-900 w-[120px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors {colVis.unapprovedDaysOff ? '' : 'hidden'}">{(row.employmentStatus === 'Remote Job' ? 0 : row.totalUnapprovedDaysOff)}</td>
								<td class="px-4 py-3 border-r text-center font-bold text-blue-800 w-[120px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors {colVis.officialLeave ? '' : 'hidden'}">{row.totalOfficialLeaveDays}</td>
								<td class="px-4 py-3 border-r text-center font-bold text-emerald-800 w-[120px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors {colVis.approvedDaysOff ? '' : 'hidden'}">{row.totalApprovedDaysOff}</td>
								<td class="px-4 py-3 text-center font-bold text-indigo-900 bg-indigo-50 z-20 w-[120px] whitespace-nowrap shadow-[-2px_0_4px_rgba(0,0,0,0.1)] border-l group-hover:bg-emerald-100 transition-colors text-xs {colVis.expectedWorkDays ? '' : 'hidden'}">
									{row.totalExpectedWorkDays}
								</td>
								<td class="px-4 py-3 text-center font-black text-slate-950 bg-slate-200 z-20 w-[120px] whitespace-nowrap shadow-[-2px_0_4px_rgba(0,0,0,0.1)] border-l group-hover:bg-emerald-200 transition-colors text-xs {colVis.workedDays ? '' : 'hidden'}">
									{#if row.employmentStatus === 'Remote Job'}
										<input 
											type="number" 
											value={editableWorkedDays[row.employeeId] !== undefined && editableWorkedDays[row.employeeId] !== '' ? editableWorkedDays[row.employeeId] : (row.totalWorkedDays || row.totalExpectedWorkDays || 0)}
											on:input={(e) => { editableWorkedDays[row.employeeId] = (e.currentTarget as HTMLInputElement).value; editableWorkedDays = { ...editableWorkedDays }; }}
											class="w-full px-2 py-1 text-center border border-slate-300 rounded bg-white text-slate-950 font-bold"
										/>
									{:else}
										{row.totalWorkedDays}
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-green-800 bg-green-50/20 w-[150px] whitespace-nowrap group-hover:bg-emerald-100/50 transition-colors {colVis.basicSalary ? '' : 'hidden'}">
									{#if basicSalaries[row.employeeId]}
										<div class="flex flex-col items-center">
											<span class="font-bold text-slate-800">{basicSalaries[row.employeeId].toLocaleString()}</span>
											<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 mt-1">{paymentModes[row.employeeId] === 'Bank' ? $t('hr.salaryStatement.bank') : $t('hr.salaryStatement.cash')}</span>
										</div>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-amber-800 bg-amber-50/20 w-[150px] whitespace-nowrap group-hover:bg-amber-100/50 transition-colors {colVis.otherAllowance ? '' : 'hidden'}">
									{#if otherAllowances[row.employeeId] && otherAllowances[row.employeeId] > 0}
										<div class="flex flex-col items-center">
											<span class="font-bold text-slate-800">{otherAllowances[row.employeeId].toLocaleString()}</span>
											<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 mt-1">{otherAllowancePaymentModes[row.employeeId] === 'Bank' ? $t('hr.salaryStatement.bank') : $t('hr.salaryStatement.cash')}</span>
										</div>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-cyan-800 bg-cyan-50/20 w-[150px] whitespace-nowrap group-hover:bg-cyan-100/50 transition-colors {colVis.accommodation ? '' : 'hidden'}">
									{#if accommodationAllowances[row.employeeId] && accommodationAllowances[row.employeeId] > 0}
										<div class="flex flex-col items-center">
											<span class="font-bold text-slate-800">{accommodationAllowances[row.employeeId].toLocaleString()}</span>
											<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 mt-1">{accommodationPaymentModes[row.employeeId] === 'Bank' ? $t('hr.salaryStatement.bank') : $t('hr.salaryStatement.cash')}</span>
										</div>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-blue-800 bg-blue-50/20 w-[150px] whitespace-nowrap group-hover:bg-blue-100/50 transition-colors {colVis.travel ? '' : 'hidden'}">
							{#if travelAllowances[row.employeeId] && travelAllowances[row.employeeId] > 0}
										<div class="flex flex-col items-center">
											<span class="font-bold text-slate-800">{travelAllowances[row.employeeId].toLocaleString()}</span>
											<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 mt-1">{travelPaymentModes[row.employeeId] === 'Bank' ? $t('hr.salaryStatement.bank') : $t('hr.salaryStatement.cash')}</span>
										</div>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-orange-800 bg-orange-50/20 w-[150px] whitespace-nowrap group-hover:bg-orange-100/50 transition-colors {colVis.foodAllowance ? '' : 'hidden'}">
									{#if foodAllowances[row.employeeId] && foodAllowances[row.employeeId] > 0}
										<div class="flex flex-col items-center">
											<span class="font-bold text-slate-800">{foodAllowances[row.employeeId].toLocaleString()}</span>
											<span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 mt-1">{foodPaymentModes[row.employeeId] === 'Bank' ? $t('hr.salaryStatement.bank') : $t('hr.salaryStatement.cash')}</span>
										</div>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-red-600 bg-red-50/20 w-[150px] whitespace-nowrap group-hover:bg-red-100/50 transition-colors {colVis.foodDeduction ? '' : 'hidden'}">
									{#if foodDeductionActives[row.employeeId]}
										<div class="flex flex-col items-center">
											<span class="font-bold text-red-700">-{(foodAllowances[row.employeeId] || 0).toLocaleString()}</span>
											<span class="text-[10px] px-1.5 py-0.5 rounded bg-red-100 text-red-600 mt-1">{$t('hr.salaryStatement.deducted')}</span>
										</div>
									{:else}
										<span class="text-[10px] px-1.5 py-0.5 rounded bg-emerald-100 text-emerald-600">{$t('hr.salaryStatement.included')}</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-red-800 bg-red-50/20 w-[150px] whitespace-nowrap group-hover:bg-red-100/50 transition-colors {colVis.gosiDeduction ? '' : 'hidden'}">
							{#if gosiDeductions[row.employeeId] && gosiDeductions[row.employeeId] > 0}
										<span class="font-bold text-slate-800">{gosiDeductions[row.employeeId].toLocaleString()}</span>
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-purple-700 bg-purple-50/20 w-[150px] whitespace-nowrap group-hover:bg-purple-100/50 transition-colors {colVis.lateDeductions ? '' : 'hidden'}">
										{(() => {
											const basicSal = basicSalaries[row.employeeId] || 0;
											const otherAllow = otherAllowances[row.employeeId] || 0;
											const accommAllow = accommodationAllowances[row.employeeId] || 0;
											const travelAllow = travelAllowances[row.employeeId] || 0;
											const foodAllow = foodAllowances[row.employeeId] || 0;
											const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
											const hourlyRate = totalSalary / 240;
											const lateMinutes = lateMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalLateMinutes) ?? 0;
											return (lateMinutes / 60 * hourlyRate).toFixed(2);
										})()}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-indigo-700 bg-indigo-50/20 w-[150px] whitespace-nowrap group-hover:bg-indigo-100/50 transition-colors {colVis.underWorkedDeductions ? '' : 'hidden'}">
										{(() => {
											const basicSal = basicSalaries[row.employeeId] || 0;
											const otherAllow = otherAllowances[row.employeeId] || 0;
											const accommAllow = accommodationAllowances[row.employeeId] || 0;
											const travelAllow = travelAllowances[row.employeeId] || 0;
											const foodAllow = foodAllowances[row.employeeId] || 0;
											const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
											const hourlyRate = totalSalary / 240;
											const uwMinutes = underWorkedMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalUnderWorkedMinutes) ?? 0;
											return (uwMinutes / 60 * hourlyRate).toFixed(2);
										})()}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-pink-700 bg-pink-50/20 w-[150px] whitespace-nowrap group-hover:bg-pink-100/50 transition-colors relative {colVis.posShortage ? '' : 'hidden'}">
									{#if posShortageDeductions[row.employeeId] && posShortageDeductions[row.employeeId] > 0}
										<button 
											class="font-bold text-slate-800 cursor-pointer hover:bg-pink-200/50 px-2 py-1 rounded transition-colors"
											on:click={() => expandedPosDropdown[row.employeeId] = !expandedPosDropdown[row.employeeId]}
											title="{$t('hr.salaryStatement.clickToForgive')}"
										>
											{posShortageDeductions[row.employeeId].toLocaleString()}
										</button>
										
										{#if expandedPosDropdown[row.employeeId]}
											<div class="absolute top-full left-0 right-0 mt-1 bg-white border border-pink-300 rounded shadow-lg z-50 max-h-64 overflow-y-auto">
												<div class="px-3 py-2 bg-pink-100 text-pink-800 font-semibold text-xs border-b border-pink-300 sticky top-0">
													Click to Forgive
												</div>
												{#each posDeductionsList[row.employeeId] || [] as deduction}
													<div class="px-3 py-2 border-b border-pink-100 text-left text-sm hover:bg-pink-50/30 flex items-center gap-2">
														<input 
															type="checkbox" 
															checked={deduction.status === 'Forgiven'}
															on:change={() => togglePosDeductionForgiveness(deduction.id, deduction.box_number, deduction.date_closed_box, deduction.status)}
															class="w-4 h-4 cursor-pointer"
														/>
														<div class="flex-1 text-xs">
															<div class="font-semibold text-slate-700">Box #{deduction.box_number}</div>
															<div class="text-slate-600">{deduction.short_amount.toLocaleString()} - {deduction.status}</div>
														</div>
													</div>
												{/each}
											</div>
										{/if}
									{:else}
										<span class="text-slate-400">-</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-rose-700 bg-rose-50/20 w-[150px] whitespace-nowrap group-hover:bg-rose-100/50 transition-colors {colVis.salaryAdvance ? '' : 'hidden'}">
									{(empEditOverrides[row.employeeId]?.salaryAdvance || 0) > 0 ? (empEditOverrides[row.employeeId].salaryAdvance).toLocaleString() : '-'}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-fuchsia-700 bg-fuchsia-50/20 w-[150px] whitespace-nowrap group-hover:bg-fuchsia-100/50 transition-colors {colVis.loanDeductions ? '' : 'hidden'}">
									{(empEditOverrides[row.employeeId]?.loanDeductions || 0) > 0 ? (empEditOverrides[row.employeeId].loanDeductions).toLocaleString() : '-'}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-orange-700 bg-orange-50/20 w-[150px] whitespace-nowrap group-hover:bg-orange-100/50 transition-colors {colVis.penaltiesDeductions ? '' : 'hidden'}">
									{(empEditOverrides[row.employeeId]?.penalties || 0) > 0 ? (empEditOverrides[row.employeeId].penalties).toLocaleString() : '-'}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-sky-700 bg-sky-50/20 w-[150px] whitespace-nowrap group-hover:bg-sky-100/50 transition-colors {colVis.unapprovedLeaveDeductions ? '' : 'hidden'}">
										{(() => {
											const basicSal = basicSalaries[row.employeeId] || 0;
											const otherAllow = otherAllowances[row.employeeId] || 0;
											const accommAllow = accommodationAllowances[row.employeeId] || 0;
											const travelAllow = travelAllowances[row.employeeId] || 0;
											const foodAllow = foodAllowances[row.employeeId] || 0;
											const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
											const hourlyRate = totalSalary / 240;
											const unapprovedDays = (row.employmentStatus === 'Remote Job' ? 0 : row.totalUnapprovedDaysOff) || 0;
											return (unapprovedDays * 8 * hourlyRate).toFixed(2);
										})()}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-gray-700 bg-gray-50/20 w-[150px] whitespace-nowrap group-hover:bg-gray-100/50 transition-colors {colVis.otherDeductions ? '' : 'hidden'}">
									{(empEditOverrides[row.employeeId]?.otherDeductions || 0) > 0 ? (empEditOverrides[row.employeeId].otherDeductions).toLocaleString() : '-'}
								</td>
								<td class="px-4 py-3 border-l text-center font-bold text-emerald-800 bg-emerald-50 w-[150px] whitespace-nowrap group-hover:bg-emerald-100 transition-colors sticky z-20 shadow-[-2px_0_4px_rgba(0,0,0,0.05)] {$locale === 'ar' ? 'left-[600px]' : 'right-[600px]'} {colVis.grossEarnings ? '' : 'hidden'}">{computeRowSalary(row).gross.toFixed(2)}</td>
								<td class="px-4 py-3 border-l text-center font-bold text-rose-800 bg-rose-50 w-[150px] whitespace-nowrap group-hover:bg-rose-100 transition-colors sticky z-20 shadow-[-2px_0_4px_rgba(0,0,0,0.05)] {$locale === 'ar' ? 'left-[450px]' : 'right-[450px]'} {colVis.totalDeductions ? '' : 'hidden'}">{computeRowSalary(row).totalDeductions.toFixed(2)}</td>
								<td class="px-4 py-3 border-l text-center font-bold text-yellow-800 bg-yellow-50 w-[150px] whitespace-nowrap group-hover:bg-yellow-100 transition-colors sticky z-20 shadow-[-2px_0_4px_rgba(0,0,0,0.05)] {$locale === 'ar' ? 'left-[300px]' : 'right-[300px]'} {colVis.netSalary ? '' : 'hidden'}">
									{(() => {
										const basicSal = basicSalaries[row.employeeId] || 0;
										const otherAllow = otherAllowances[row.employeeId] || 0;
										const accommAllow = accommodationAllowances[row.employeeId] || 0;
										const travelAllow = travelAllowances[row.employeeId] || 0;
										const foodAllow = foodAllowances[row.employeeId] || 0;
										const gosiDed = gosiDeductions[row.employeeId] || 0;
										
										// Total Earnings = full allowances (unapproved absences deducted explicitly below)
										const totalAllowances = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
										// Remote Job: prorate gross salary by edited worked days / expected work days
										let grossWorkedSalary = totalAllowances;
										if (row.employmentStatus === 'Remote Job') {
											const _wdRaw = editableWorkedDays[row.employeeId];
											const _wd = (_wdRaw !== undefined && _wdRaw !== '') ? parseFloat(_wdRaw) : (row.totalExpectedWorkDays || 0);
											const _expWd = row.totalExpectedWorkDays || 0;
											if (_expWd > 0) grossWorkedSalary = totalAllowances * (_wd / _expWd);
										}
										
										let lateDeduction = 0;
										let underWorkedDeduction = 0;
										let unapprovedLeaveDeduction = 0;
										let incompleteDayDeduction = 0;
										
										// Calculate deductions using fixed rate: Monthly Wage / 30 days / 8 hours
										const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
										const hourlyRate = totalSalary / 240;
										const shiftHoursPerDay = 8;
										
										// Use saved overrides if set, otherwise compute from rate
										const _lateDedOvr = lateDeductionOverrides[row.employeeId];
										const _underDedOvr = underWorkedDeductionOverrides[row.employeeId];
										const _unapDedOvr = unapprovedLeaveDeductionOverrides[row.employeeId];
										const _incompDedOvr = incompleteDayDeductionOverrides[row.employeeId];
										const effLate = lateMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalLateMinutes) ?? 0;
										const effUnder = underWorkedMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalUnderWorkedMinutes) ?? 0;
										if (_lateDedOvr !== undefined) { lateDeduction = _lateDedOvr; }
										else if (effLate > 0) { lateDeduction = (effLate / 60) * hourlyRate; }
										if (_underDedOvr !== undefined) { underWorkedDeduction = _underDedOvr; }
										else if (effUnder > 0) { underWorkedDeduction = (effUnder / 60) * hourlyRate; }
										if (_incompDedOvr !== undefined) { incompleteDayDeduction = _incompDedOvr; }
										else if ((row.employmentStatus === 'Remote Job' ? 0 : row.totalIncompleteDays) > 0) { incompleteDayDeduction = (row.employmentStatus === 'Remote Job' ? 0 : row.totalIncompleteDays) * shiftHoursPerDay * hourlyRate; }
										if (_unapDedOvr !== undefined) { unapprovedLeaveDeduction = _unapDedOvr; }
										else if ((row.employmentStatus === 'Remote Job' ? 0 : row.totalUnapprovedDaysOff) > 0) { unapprovedLeaveDeduction = (row.employmentStatus === 'Remote Job' ? 0 : row.totalUnapprovedDaysOff) * shiftHoursPerDay * hourlyRate; }
										const salaryAdvanceDed = empEditOverrides[row.employeeId]?.salaryAdvance || 0;
										const loanDed = empEditOverrides[row.employeeId]?.loanDeductions || 0;
										const penaltiesDed = empEditOverrides[row.employeeId]?.penalties || 0;
										const otherDed = empEditOverrides[row.employeeId]?.otherDeductions || 0;
										const posShortageDed = posShortageDeductions[row.employeeId] || 0;
										
										// Calculate net salary
										const foodDeductionDed = (foodDeductionActives[row.employeeId] ?? false) ? foodAllow : 0;
										const netSalary = grossWorkedSalary - (gosiDed + lateDeduction + underWorkedDeduction + unapprovedLeaveDeduction + salaryAdvanceDed + loanDed + penaltiesDed + incompleteDayDeduction + posShortageDed + otherDed + foodDeductionDed);
										
										return netSalary.toFixed(2);
									})()}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-blue-800 bg-blue-50 w-[150px] whitespace-nowrap group-hover:bg-blue-100 transition-colors sticky z-20 {$locale === 'ar' ? 'left-[150px]' : 'right-[150px]'} {colVis.netBank ? '' : 'hidden'}">
									{(() => {
										const basicSal = basicSalaries[row.employeeId] || 0;
										const otherAllow = otherAllowances[row.employeeId] || 0;
										const accommAllow = accommodationAllowances[row.employeeId] || 0;
										const travelAllow = travelAllowances[row.employeeId] || 0;
										const foodAllow = foodAllowances[row.employeeId] || 0;
										const gosiDed = gosiDeductions[row.employeeId] || 0;
										
										// Total Earnings = full allowances (unapproved absences deducted explicitly below)
										const totalAllowances = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
										// Remote Job: prorate gross salary by edited worked days / expected work days
										let grossWorkedSalary = totalAllowances;
										if (row.employmentStatus === 'Remote Job') {
											const _wdRaw = editableWorkedDays[row.employeeId];
											const _wd = (_wdRaw !== undefined && _wdRaw !== '') ? parseFloat(_wdRaw) : (row.totalExpectedWorkDays || 0);
											const _expWd = row.totalExpectedWorkDays || 0;
											if (_expWd > 0) grossWorkedSalary = totalAllowances * (_wd / _expWd);
										}
										
										let lateDeduction = 0;
										let underWorkedDeduction = 0;
										let unapprovedLeaveDeduction = 0;
										let incompleteDayDeduction = 0;
										
										// Calculate deductions using fixed rate: Monthly Wage / 30 days / 8 hours
										const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
										const hourlyRate = totalSalary / 240;
										const shiftHoursPerDay = 8;
										
										// Use saved overrides if set, otherwise compute from rate
										const _lateDedOvr = lateDeductionOverrides[row.employeeId];
										const _underDedOvr = underWorkedDeductionOverrides[row.employeeId];
										const _unapDedOvr = unapprovedLeaveDeductionOverrides[row.employeeId];
										const _incompDedOvr = incompleteDayDeductionOverrides[row.employeeId];
										const effLate = lateMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalLateMinutes) ?? 0;
										const effUnder = underWorkedMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalUnderWorkedMinutes) ?? 0;
										if (_lateDedOvr !== undefined) { lateDeduction = _lateDedOvr; }
										else if (effLate > 0) { lateDeduction = (effLate / 60) * hourlyRate; }
										if (_underDedOvr !== undefined) { underWorkedDeduction = _underDedOvr; }
										else if (effUnder > 0) { underWorkedDeduction = (effUnder / 60) * hourlyRate; }
										if (_incompDedOvr !== undefined) { incompleteDayDeduction = _incompDedOvr; }
										else if ((row.employmentStatus === 'Remote Job' ? 0 : row.totalIncompleteDays) > 0) { incompleteDayDeduction = (row.employmentStatus === 'Remote Job' ? 0 : row.totalIncompleteDays) * shiftHoursPerDay * hourlyRate; }
										if (_unapDedOvr !== undefined) { unapprovedLeaveDeduction = _unapDedOvr; }
										else if ((row.employmentStatus === 'Remote Job' ? 0 : row.totalUnapprovedDaysOff) > 0) { unapprovedLeaveDeduction = (row.employmentStatus === 'Remote Job' ? 0 : row.totalUnapprovedDaysOff) * shiftHoursPerDay * hourlyRate; }
										const salaryAdvanceDed = empEditOverrides[row.employeeId]?.salaryAdvance || 0;
										const loanDed = empEditOverrides[row.employeeId]?.loanDeductions || 0;
										const penaltiesDed = empEditOverrides[row.employeeId]?.penalties || 0;
										const otherDed = empEditOverrides[row.employeeId]?.otherDeductions || 0;
										const posShortageDed = posShortageDeductions[row.employeeId] || 0;
										
										const foodDeductionDed = (foodDeductionActives[row.employeeId] ?? false) ? foodAllow : 0;
										// Calculate net salary
										const netSalary = grossWorkedSalary - (gosiDed + lateDeduction + underWorkedDeduction + unapprovedLeaveDeduction + salaryAdvanceDed + loanDed + penaltiesDed + incompleteDayDeduction + posShortageDed + otherDed + foodDeductionDed);

										// Distribute net salary across Bank/Cash based on each allowance's payment mode
										const basicPayMode = paymentModes[row.employeeId] || 'Bank';
										const otherPayMode = otherAllowancePaymentModes[row.employeeId] || 'Bank';
										const accommPayMode = accommodationPaymentModes[row.employeeId] || 'Bank';
										const travelPayMode = travelPaymentModes[row.employeeId] || 'Bank';
										const foodPayMode = foodPaymentModes[row.employeeId] || 'Bank';
										const isFoodDedActive = foodDeductionActives[row.employeeId] ?? false;
										const distFood = isFoodDedActive ? 0 : foodAllow;
										let bankAllowances = 0;
										if (basicPayMode === 'Bank') bankAllowances += basicSal;
										if (otherPayMode === 'Bank') bankAllowances += otherAllow;
										if (accommPayMode === 'Bank') bankAllowances += accommAllow;
										if (travelPayMode === 'Bank') bankAllowances += travelAllow;
										if (foodPayMode === 'Bank') bankAllowances += distFood;
										const distTotal = basicSal + otherAllow + accommAllow + travelAllow + distFood;
										const bankRatio = distTotal > 0 ? bankAllowances / distTotal : 0;
										const netBank = Math.max(0, netSalary * bankRatio);
										
										return netBank.toFixed(2);
									})()}
								</td>
								<td class="px-4 py-3 border-r text-center font-bold text-red-800 bg-red-50 w-[150px] whitespace-nowrap group-hover:bg-red-100 transition-colors sticky z-20 {$locale === 'ar' ? 'left-0' : 'right-0'} {colVis.netCash ? '' : 'hidden'}">
									{(() => {
										const basicSal = basicSalaries[row.employeeId] || 0;
										const otherAllow = otherAllowances[row.employeeId] || 0;
										const accommAllow = accommodationAllowances[row.employeeId] || 0;
										const travelAllow = travelAllowances[row.employeeId] || 0;
										const foodAllow = foodAllowances[row.employeeId] || 0;
										const gosiDed = gosiDeductions[row.employeeId] || 0;
										
										// Total Earnings = full allowances (unapproved absences deducted explicitly below)
										const totalAllowances = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
										// Remote Job: prorate gross salary by edited worked days / expected work days
										let grossWorkedSalary = totalAllowances;
										if (row.employmentStatus === 'Remote Job') {
											const _wdRaw = editableWorkedDays[row.employeeId];
											const _wd = (_wdRaw !== undefined && _wdRaw !== '') ? parseFloat(_wdRaw) : (row.totalExpectedWorkDays || 0);
											const _expWd = row.totalExpectedWorkDays || 0;
											if (_expWd > 0) grossWorkedSalary = totalAllowances * (_wd / _expWd);
										}
										
										let lateDeduction = 0;
										let underWorkedDeduction = 0;
										let unapprovedLeaveDeduction = 0;
										let incompleteDayDeduction = 0;
										
										// Calculate deductions using fixed rate: Monthly Wage / 30 days / 8 hours
										const totalSalary = basicSal + otherAllow + accommAllow + travelAllow + foodAllow;
										const hourlyRate = totalSalary / 240;
										const shiftHoursPerDay = 8;
										
										// Use saved overrides if set, otherwise compute from rate
										const _lateDedOvr = lateDeductionOverrides[row.employeeId];
										const _underDedOvr = underWorkedDeductionOverrides[row.employeeId];
										const _unapDedOvr = unapprovedLeaveDeductionOverrides[row.employeeId];
										const _incompDedOvr = incompleteDayDeductionOverrides[row.employeeId];
										const effLate = lateMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalLateMinutes) ?? 0;
										const effUnder = underWorkedMinutesOverrides[row.employeeId] ?? (row.employmentStatus === 'Remote Job' ? 0 : row.totalUnderWorkedMinutes) ?? 0;
										if (_lateDedOvr !== undefined) { lateDeduction = _lateDedOvr; }
										else if (effLate > 0) { lateDeduction = (effLate / 60) * hourlyRate; }
										if (_underDedOvr !== undefined) { underWorkedDeduction = _underDedOvr; }
										else if (effUnder > 0) { underWorkedDeduction = (effUnder / 60) * hourlyRate; }
										if (_incompDedOvr !== undefined) { incompleteDayDeduction = _incompDedOvr; }
										else if ((row.employmentStatus === 'Remote Job' ? 0 : row.totalIncompleteDays) > 0) { incompleteDayDeduction = (row.employmentStatus === 'Remote Job' ? 0 : row.totalIncompleteDays) * shiftHoursPerDay * hourlyRate; }
										if (_unapDedOvr !== undefined) { unapprovedLeaveDeduction = _unapDedOvr; }
										else if ((row.employmentStatus === 'Remote Job' ? 0 : row.totalUnapprovedDaysOff) > 0) { unapprovedLeaveDeduction = (row.employmentStatus === 'Remote Job' ? 0 : row.totalUnapprovedDaysOff) * shiftHoursPerDay * hourlyRate; }
										const salaryAdvanceDed = empEditOverrides[row.employeeId]?.salaryAdvance || 0;
										const loanDed = empEditOverrides[row.employeeId]?.loanDeductions || 0;
										const penaltiesDed = empEditOverrides[row.employeeId]?.penalties || 0;
										const otherDed = empEditOverrides[row.employeeId]?.otherDeductions || 0;
										const posShortageDed = posShortageDeductions[row.employeeId] || 0;
										const foodDeductionDed = (foodDeductionActives[row.employeeId] ?? false) ? foodAllow : 0;
										
										// Calculate net salary
										const netSalary = grossWorkedSalary - (gosiDed + lateDeduction + underWorkedDeduction + unapprovedLeaveDeduction + salaryAdvanceDed + loanDed + penaltiesDed + incompleteDayDeduction + posShortageDed + otherDed + foodDeductionDed);

										// Distribute net salary across Bank/Cash based on each allowance's payment mode
										const basicPayMode = paymentModes[row.employeeId] || 'Bank';
										const otherPayMode = otherAllowancePaymentModes[row.employeeId] || 'Bank';
										const accommPayMode = accommodationPaymentModes[row.employeeId] || 'Bank';
										const travelPayMode = travelPaymentModes[row.employeeId] || 'Bank';
										const foodPayMode = foodPaymentModes[row.employeeId] || 'Bank';
										const isFoodDedActive = foodDeductionActives[row.employeeId] ?? false;
										const distFood = isFoodDedActive ? 0 : foodAllow;
										let bankAllowances = 0;
										if (basicPayMode === 'Bank') bankAllowances += basicSal;
										if (otherPayMode === 'Bank') bankAllowances += otherAllow;
										if (accommPayMode === 'Bank') bankAllowances += accommAllow;
										if (travelPayMode === 'Bank') bankAllowances += travelAllow;
										if (foodPayMode === 'Bank') bankAllowances += distFood;
										const distTotal = basicSal + otherAllow + accommAllow + travelAllow + distFood;
										const bankRatio = distTotal > 0 ? bankAllowances / distTotal : 0;
										const netBankPortion = Math.max(0, netSalary * bankRatio);
										const netCash = Math.max(0, netSalary - netBankPortion);
										
										return netCash.toFixed(2);
									})()}
								</td>
							</tr>
						{/each}
					</tbody>
					<!-- Excel-style column totals (sticky bottom) -->
				</table>
			</div>
			<!-- Compact summary bar (column totals are now in the table tfoot) -->
			<div class="border-t-2 border-slate-300 bg-gradient-to-r from-slate-100 to-slate-50 px-4 py-1.5 shrink-0 shadow-[0_-4px_8px_rgba(0,0,0,0.08)]">
				<div class="flex flex-wrap items-center gap-3 text-[11px]">
					<!-- Save / Load / Update controls -->
					<div class="ml-auto flex items-center gap-2 order-last">
						{#if saveNotice}
							<span class="px-2 py-0.5 bg-emerald-100 border border-emerald-300 rounded text-emerald-800 text-[11px] font-bold">{saveNotice}</span>
						{/if}
						{#if isLoadedFromSaved && currentSavedStatementId}
							<span class="px-2 py-0.5 bg-indigo-50 border border-indigo-300 rounded text-indigo-800 text-[10px] font-semibold" title="{$t('hr.salaryStatement.loadedSavedTooltip')}">{$t('hr.salaryStatement.savedBadge')}</span>
						{/if}
						{#if isLoadedFromSaved && isModified}
							<button type="button" on:click={confirmUpdate} disabled={saveBusy}
								class="px-3 py-1 rounded bg-amber-600 hover:bg-amber-700 disabled:opacity-50 disabled:cursor-not-allowed text-white text-[11px] font-bold shadow-sm">
								{#if saveBusy}{$t('hr.salaryStatement.updating')}{:else}<span class="inline-flex items-center gap-1"><svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 20 20" fill="currentColor"><path d="M3 4a2 2 0 012-2h8.586A2 2 0 0115 2.586L17.414 5A2 2 0 0118 6.414V16a2 2 0 01-2 2H5a2 2 0 01-2-2V4zm9-1H5a1 1 0 00-1 1v3h7V3zm0 4H4v9a1 1 0 001 1h11a1 1 0 001-1V6.414L13.586 3H13v3a1 1 0 01-1 1z"/></svg>Update</span>{/if}
							</button>
						{:else}
							<button type="button" on:click={openSaveModal}
								disabled={saveBusy || !analysisData?.length || isLoadedFromSaved}
								title={isLoadedFromSaved ? $t('hr.salaryStatement.saveDisabledLoadedTooltip') : $t('hr.salaryStatement.saveTooltip')}
								class="px-3 py-1 rounded bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed text-white text-[11px] font-bold shadow-sm">
								<span class="inline-flex items-center gap-1"><svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 20 20" fill="currentColor"><path d="M3 4a2 2 0 012-2h8.586A2 2 0 0115 2.586L17.414 5A2 2 0 0118 6.414V16a2 2 0 01-2 2H5a2 2 0 01-2-2V4zm9-1H5a1 1 0 00-1 1v3h7V3zm0 4H4v9a1 1 0 001 1h11a1 1 0 001-1V6.414L13.586 3H13v3a1 1 0 01-1 1z"/></svg>Save</span>
							</button>
						{/if}
						<button type="button" on:click={openLoadModal} disabled={saveBusy}
							class="px-3 py-1 rounded bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white text-[11px] font-bold shadow-sm">
							<span class="inline-flex items-center gap-1"><svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 20 20" fill="currentColor"><path d="M2 6a2 2 0 012-2h4l2 2h6a2 2 0 012 2v6a2 2 0 01-2 2H4a2 2 0 01-2-2V6z"/></svg>Load</span>
						</button>
						{#if isLoadedFromSaved}
							<button type="button" on:click={resetSavedStatementContext}
								title="{$t('hr.salaryStatement.detachTooltip')}"
								class="px-2 py-1 rounded bg-slate-200 hover:bg-slate-300 text-slate-700 text-[11px] font-semibold">
								✕
							</button>
						{/if}
					</div>
					<span class="font-bold text-slate-700">{$t('hr.salaryStatement.employees')}: <span class="text-slate-900">{salaryTotals.totalEmployees}</span></span>
					<span class="text-slate-300">|</span>
					<span class="font-bold text-emerald-700">{$t('hr.salaryStatement.finger')}: <span class="text-emerald-900">{salaryTotals.countFingerJob}</span></span>
					<span class="font-bold text-orange-700">{$t('hr.salaryStatement.remoteShort')}: <span class="text-orange-900">{salaryTotals.countRemoteJob}</span></span>
					<span class="text-slate-300">|</span>
					<span class="font-bold text-blue-700">{$t('hr.salaryStatement.gross')}: <span class="text-blue-900">{salaryTotals.totalGross.toFixed(2)}</span></span>
					<span class="font-bold text-red-700">{$t('hr.salaryStatement.ded')}: <span class="text-red-900">{salaryTotals.totalDed.toFixed(2)}</span></span>
					<span class="px-2 py-0.5 bg-yellow-100 border border-yellow-400 rounded font-black text-yellow-900">{$t('hr.salaryStatement.net')}: {salaryTotals.totalNet.toFixed(2)}</span>
					<span class="px-2 py-0.5 bg-blue-100 border border-blue-300 rounded font-black text-blue-900">{$t('hr.salaryStatement.bank')}: {salaryTotals.totalBank.toFixed(2)}</span>
					<span class="px-2 py-0.5 bg-green-100 border border-green-300 rounded font-black text-green-900">{$t('hr.salaryStatement.cash')}: {salaryTotals.totalCash.toFixed(2)}</span>
				</div>
			</div>
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


<!-- Mudad Exporter Modal -->
{#if showMudadModal}
<!-- svelte-ignore a11y-click-events-have-key-events -->
<!-- svelte-ignore a11y-no-static-element-interactions -->
<div class="fixed inset-0 z-[100] flex items-center justify-center bg-black/50" on:click|self={() => (showMudadModal = false)}>
<div class="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 border-2 border-orange-400">
<div class="flex items-center justify-between mb-4">
<div class="flex items-center gap-2">
<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-orange-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
</svg>
<h3 class="text-lg font-bold text-slate-900">Mudad Exporter</h3>
</div>
<button type="button" class="text-slate-400 hover:text-slate-700 text-xl leading-none" on:click={() => (showMudadModal = false)}>×</button>
</div>
<p class="text-sm text-slate-600 mb-4">
Upload your Mudad Excel template. The system will match employees by <strong>Legal Id</strong> and fill in:
<strong>Other Allowances (Amount)</strong>, <strong>Leave of Absence (Amount)</strong>, and <strong>Other Deductions (Amount)</strong>.
</p>
<div class="mb-4">
<label for="mudad-template-input" class="block text-xs font-bold text-slate-700 mb-1 uppercase">Import Mudad Template (.xlsx)</label>
<input
type="file"
accept=".xlsx,.xls"
id="mudad-template-input" bind:this={mudadFileInputEl}
on:change={(e) => { const f = (e.target as HTMLInputElement).files?.[0]; if (f) handleMudadTemplateImport(f); }}
class="block w-full text-sm text-slate-700 border border-slate-300 rounded-lg cursor-pointer bg-slate-50 file:mr-3 file:py-1.5 file:px-3 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-orange-100 file:text-orange-700 hover:file:bg-orange-200"
/>
</div>
{#if mudadError}
<div class="mb-3 px-3 py-2 bg-red-50 border border-red-300 rounded-lg text-red-700 text-sm font-medium">{mudadError}</div>
{/if}
{#if mudadSuccess}
<div class="mb-3 px-3 py-2 bg-green-50 border border-green-300 rounded-lg text-green-700 text-sm font-medium">{mudadSuccess}</div>
{/if}
<div class="flex justify-end gap-2 mt-2">
<button
type="button"
on:click={() => (showMudadModal = false)}
disabled={mudadProcessing}
class="px-4 py-2 rounded-lg bg-slate-200 hover:bg-slate-300 text-slate-700 text-sm font-semibold"
>Cancel</button>
<button
type="button"
on:click={exportMudadExcel}
disabled={mudadProcessing || !mudadTemplateFile}
class="px-5 py-2 rounded-lg bg-orange-600 hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed text-white text-sm font-bold shadow"
>
{#if mudadProcessing}
<span class="flex items-center gap-2">
<span class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
Processing...
</span>
{:else}
Export Filled Excel
{/if}
</button>
</div>
</div>
</div>
{/if}
<!-- Save Salary Statement Modal -->
{#if showSaveModal}
	<div class="fixed inset-0 z-[100] flex items-center justify-center bg-black/50" on:click|self={() => (showSaveModal = false)}>
		<div class="bg-white rounded-lg shadow-2xl w-full max-w-md p-5 border-2 border-emerald-500" role="dialog">
			<div class="flex items-center justify-between mb-4">
				<h3 class="text-lg font-bold text-slate-900">{$t('hr.salaryStatement.saveModalTitle')}</h3>
				<button type="button" class="text-slate-400 hover:text-slate-700 text-xl leading-none" on:click={() => (showSaveModal = false)}>Ã—</button>
			</div>
			<div class="space-y-3">
				<div>
					<label class="block text-xs font-bold text-slate-700 mb-1">{$t('hr.salaryStatement.statementNameRequired')}</label>
					<input type="text" bind:value={saveStatementName}
						class="w-full px-3 py-2 border border-slate-300 rounded text-sm focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
						placeholder="{$t('hr.salaryStatement.statementNamePlaceholder')}" />
				</div>
				<div class="grid grid-cols-2 gap-3">
					<div>
						<label class="block text-xs font-bold text-slate-700 mb-1">{$t('hr.salaryStatement.startDate')}</label>
						<input type="date" bind:value={startDate} disabled
							class="w-full px-3 py-2 border border-slate-300 rounded text-sm bg-slate-50 text-slate-700" />
					</div>
					<div>
						<label class="block text-xs font-bold text-slate-700 mb-1">{$t('hr.salaryStatement.endDate')}</label>
						<input type="date" bind:value={endDate} disabled
							class="w-full px-3 py-2 border border-slate-300 rounded text-sm bg-slate-50 text-slate-700" />
					</div>
				</div>
				{#if saveError}
					<div class="px-3 py-2 bg-red-50 border border-red-300 rounded text-red-700 text-xs">{saveError}</div>
				{/if}
			</div>
			<div class="mt-5 flex justify-end gap-2">
				<button type="button" on:click={() => (showSaveModal = false)} disabled={saveBusy}
					class="px-4 py-2 rounded bg-slate-200 hover:bg-slate-300 text-slate-700 text-sm font-semibold">Cancel</button>
				<button type="button" on:click={confirmSave} disabled={saveBusy}
					class="px-4 py-2 rounded bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white text-sm font-bold shadow">
					{saveBusy ? $t('hr.salaryStatement.saving') : $t('hr.salaryStatement.save')}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Load Salary Statement Modal -->
{#if showLoadModal}
	<div class="fixed inset-0 z-[100] flex items-center justify-center bg-black/50" on:click|self={() => (showLoadModal = false)}>
		<div class="bg-white rounded-lg shadow-2xl w-full max-w-3xl max-h-[80vh] flex flex-col p-5 border-2 border-blue-500" role="dialog">
			<div class="flex items-center justify-between mb-4">
				<h3 class="text-lg font-bold text-slate-900">{$t('hr.salaryStatement.loadModalTitle')}</h3>
				<button type="button" class="text-slate-400 hover:text-slate-700 text-xl leading-none" on:click={() => (showLoadModal = false)}>Ã—</button>
			</div>
			<div class="flex-1 overflow-auto">
				{#if loadListLoading}
					<div class="flex items-center justify-center py-12 text-slate-500">
						<div class="w-6 h-6 border-2 border-blue-600 border-t-transparent rounded-full animate-spin mr-2"></div>
						Loading saved statements...
					</div>
				{:else if loadList.length === 0}
					<div class="text-center py-12 text-slate-400">
						<div class="text-4xl mb-2">ðŸ“­</div>
						<p>{$t('hr.salaryStatement.noSavedStatements')}</p>
					</div>
				{:else}
					<table class="w-full text-sm">
						<thead class="bg-slate-100 sticky top-0">
							<tr>
								<th class="px-3 py-2 text-left text-xs font-bold text-slate-700">{$t('hr.salaryStatement.name')}</th>
								<th class="px-3 py-2 text-left text-xs font-bold text-slate-700">{$t('hr.salaryStatement.start')}</th>
								<th class="px-3 py-2 text-left text-xs font-bold text-slate-700">{$t('hr.salaryStatement.end')}</th>
								<th class="px-3 py-2 text-left text-xs font-bold text-slate-700">{$t('hr.salaryStatement.updated')}</th>
								<th class="px-3 py-2"></th>
							</tr>
						</thead>
						<tbody>
							{#each loadList as it (it.id)}
								<tr class="border-b border-slate-100 hover:bg-blue-50">
									<td class="px-3 py-2 font-semibold text-slate-900">{it.statement_name}</td>
									<td class="px-3 py-2 text-slate-700">{it.start_date}</td>
									<td class="px-3 py-2 text-slate-700">{it.end_date}</td>
									<td class="px-3 py-2 text-slate-500 text-xs">{new Date(it.updated_at).toLocaleString()}</td>
									<td class="px-3 py-2 text-right">
										<button type="button" on:click={() => selectAndLoadStatement(it.id)}
											disabled={loadingStatementId !== null}
											class="px-3 py-1 rounded bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white text-xs font-bold">
											{loadingStatementId === it.id ? $t('hr.salaryStatement.loading') : $t('hr.salaryStatement.load')}
										</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				{/if}
				{#if saveError}
					<div class="mt-3 px-3 py-2 bg-red-50 border border-red-300 rounded text-red-700 text-xs">{saveError}</div>
				{/if}
			</div>
			<div class="mt-4 flex justify-end">
				<button type="button" on:click={() => (showLoadModal = false)}
					class="px-4 py-2 rounded bg-slate-200 hover:bg-slate-300 text-slate-700 text-sm font-semibold">{$t('hr.salaryStatement.close')}</button>
			</div>
		</div>
	</div>
{/if}
<!-- Employee Edit Modal -->
<!-- Salary Notes Popup -->
<EmployeeSalaryNotesPopup
	bind:show={showNotesPopup}
	employeeId={notesEmployeeId}
	employeeName={notesEmployeeName}
	on:close={() => { showNotesPopup = false; }}
/>

{#if showEmpEditModal && empEditRow}
	{@const _basicSal = Number(empEdit.basicSalary) || 0}
	{@const _otherAllow = Number(empEdit.otherAllowance) || 0}
	{@const _accomm = Number(empEdit.accommodation) || 0}
	{@const _travel = Number(empEdit.travel) || 0}
	{@const _food = Number(empEdit.food) || 0}
	{@const _gosi = Number(empEdit.gosiDeduction) || 0}
	{@const _posShort = Number(empEdit.posShortage) || 0}
	{@const _salAdv = Number(empEdit.salaryAdvance) || 0}
	{@const _loan = Number(empEdit.loanDeductions) || 0}
	{@const _pen = Number(empEdit.penalties) || 0}
	{@const _otherDed = Number(empEdit.otherDeductions) || 0}
	{@const _totalAllow = _basicSal + _otherAllow + _accomm + _travel + _food}
	{@const _workedDays = editableWorkedDays[empEditRow.employeeId] !== undefined && editableWorkedDays[empEditRow.employeeId] !== '' ? parseFloat(editableWorkedDays[empEditRow.employeeId]) : empEditRow.totalWorkedDays}
	{@const _wdRawPop = editableWorkedDays[empEditRow.employeeId]}
	{@const _wdPop = (_wdRawPop !== undefined && _wdRawPop !== '') ? parseFloat(_wdRawPop) : (empEditRow.totalExpectedWorkDays || 0)}
	{@const _expWdPop = empEditRow.totalExpectedWorkDays || 0}
	{@const _gross = empEditRow.employmentStatus === 'Remote Job' && _expWdPop > 0 ? _totalAllow * (_wdPop / _expWdPop) : _totalAllow}
	{@const _shift = employeeShifts.get(String(empEditRow.employeeId))}
	{@const _shiftMins = _shift ? (() => { const s = timeToMinutes(_shift.shift_start_time); const e = timeToMinutes(_shift.shift_end_time); let m = e - s; if (m < 0) m += 1440; return m; })() : 0}
	{@const _totalExpH = _shift ? calculateTotalHoursInPeriod(_shiftMins) : 0}
	{@const _totalSalForRate = _basicSal + _otherAllow + _accomm + _travel + _food}
	{@const _hourlyRate = _totalSalForRate / 240}
	{@const _shiftHPD = _shiftMins / 60}
	{@const _lateDed = Number(empEdit.lateDeduction) || 0}
	{@const _underDed = Number(empEdit.underWorkedDeduction) || 0}
	{@const _unapDed = Number(empEdit.unapprovedLeaveDeduction) || 0}
	{@const _incompleteDed = Number(empEdit.incompleteDayDeduction) || 0}
	{@const _foodDed = (empEdit.foodDeductionActive ?? false) ? _food : 0}
	{@const _netSal = _gross - (_gosi + _lateDed + _underDed + _unapDed + _salAdv + _loan + _pen + _posShort + _otherDed + _incompleteDed + _foodDed)}
	{@const _distFood = (empEdit.foodDeductionActive ?? false) ? 0 : _food}
	{@const _bankAllow = (_basicSal * (empEdit.basicPaymentMode === 'Cash' ? 0 : 1)) + (_otherAllow * (empEdit.otherAllowancePaymentMode === 'Cash' ? 0 : 1)) + (_accomm * (empEdit.accommodationPaymentMode === 'Cash' ? 0 : 1)) + (_travel * (empEdit.travelPaymentMode === 'Cash' ? 0 : 1)) + (_distFood * (empEdit.foodPaymentMode === 'Cash' ? 0 : 1))}
	{@const _distTotal = _basicSal + _otherAllow + _accomm + _travel + _distFood}
	{@const _bankRatio = _distTotal > 0 ? _bankAllow / _distTotal : 0}
	{@const _netBank = _netSal * _bankRatio}
	{@const _netCash = _netSal - _netBank}
	{@const _perMinuteRate = _hourlyRate / 60}
	{@const _perDayRate = 8 * _hourlyRate}
	<div role="dialog" aria-modal="true" tabindex="-1" class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/50 backdrop-blur-sm" on:click|self={() => showEmpEditModal = false} on:keydown={(e) => e.key === 'Escape' && (showEmpEditModal = false)}>
		<div class="bg-white rounded-2xl shadow-2xl w-full max-w-7xl mx-4 overflow-hidden flex flex-col max-h-[90vh]">
			<!-- Header -->
			<div class="flex items-center justify-between px-6 py-2 bg-orange-50 border-b-2 border-orange-400 flex-shrink-0">
				<div>
					<p class="text-[10px] font-semibold text-orange-500 uppercase tracking-wider">{$t('hr.salaryStatement.editEmployeeValues')}</p>
					<p class="font-bold text-base text-green-800">{empEditRow.employeeName}</p>
					<p class="text-[10px] text-green-600">{empEditRow.employeeId}</p>
					<span class="inline-block mt-0.5 px-2 py-0.5 rounded-full text-[10px] font-semibold {empEditRow.employmentStatus === 'Resigned' || empEditRow.employmentStatus === 'Terminated' || empEditRow.employmentStatus === 'Run Away' ? 'bg-red-100 text-red-700' : empEditRow.employmentStatus === 'Remote Job' ? 'bg-orange-100 text-orange-700' : empEditRow.employmentStatus === 'Vacation' ? 'bg-blue-100 text-blue-700' : 'bg-green-100 text-green-700'}">{empEditRow.employmentStatus ?? '-'}</span>
				</div>
				<button class="p-2 hover:bg-orange-100 rounded-full transition-colors text-orange-500" aria-label="Close" on:click={() => showEmpEditModal = false}>
					<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
					</svg>
				</button>
			</div>

			<!-- Fields -->
			<div class="px-6 py-5 space-y-5 overflow-y-auto flex-1">

				<!-- Attendance Summary (read-only) -->
				<div>
					<p class="text-xs font-bold text-green-700 uppercase tracking-widest mb-2">{$t('hr.salaryStatement.attendanceSummary')}</p>
					<div class="grid grid-cols-9 gap-1.5">
						<div class="bg-emerald-50 rounded px-2 py-1 text-center border border-emerald-100">
							<p class="text-[9px] text-emerald-700 font-semibold leading-tight">{$t('hr.salaryStatement.workedHours')}</p>
							<p class="text-xs font-bold text-emerald-800 leading-tight">{empEditRow.employmentStatus === 'Remote Job' ? (empEditRow.totalExpectedWorkDays * 8) + 'h 0m' : Math.floor(empEditRow.totalWorkedMinutes/60) + 'h ' + (empEditRow.totalWorkedMinutes%60) + 'm'}</p>
						</div>
						<div class="bg-teal-50 rounded px-2 py-1 text-center border border-teal-100">
							<p class="text-[9px] text-teal-700 font-semibold leading-tight">{$t('hr.salaryStatement.expectedHours')}</p>
							<p class="text-xs font-bold text-teal-800 leading-tight">{_totalExpH > 0 ? Math.floor(_totalExpH) + 'h ' + Math.round((_totalExpH % 1) * 60) + 'm' : '-'}</p>
						</div>
						<div class="bg-red-50 rounded px-2 py-1 text-center border border-red-200">
							<p class="text-[9px] text-red-700 font-semibold leading-tight">{$t('hr.salaryStatement.underWorked')}</p>
							<p class="text-xs font-bold text-red-800 leading-tight">{empEditRow.employmentStatus === 'Remote Job' ? '0h 0m' : Math.floor(empEdit.underWorkedMinutes/60) + 'h ' + (empEdit.underWorkedMinutes%60) + 'm'}</p>
						</div>
						<div class="bg-amber-50 rounded px-2 py-1 text-center border border-amber-200">
							<p class="text-[9px] text-amber-700 font-semibold leading-tight">{$t('hr.salaryStatement.late')}</p>
							<p class="text-xs font-bold text-amber-800 leading-tight">{empEditRow.employmentStatus === 'Remote Job' ? '0h 0m' : Math.floor(empEdit.lateMinutes/60) + 'h ' + (empEdit.lateMinutes%60) + 'm'}</p>
						</div>
						<div class="bg-rose-50 rounded px-2 py-1 text-center border border-rose-100">
							<p class="text-[9px] text-rose-700 font-semibold leading-tight">{$t('hr.salaryStatement.incompleteDays')}</p>
							<p class="text-xs font-bold text-rose-800 leading-tight">{empEditRow.employmentStatus === 'Remote Job' ? 0 : empEditRow.totalIncompleteDays}</p>
						</div>
						<div class="bg-orange-50 rounded px-2 py-1 text-center border border-orange-200">
							<p class="text-[9px] text-orange-700 font-semibold leading-tight">{$t('hr.salaryStatement.unapprovedLeaves')}</p>
							<p class="text-xs font-bold text-orange-800 leading-tight">{empEditRow.employmentStatus === 'Remote Job' ? 0 : empEditRow.totalUnapprovedDaysOff}</p>
						</div>
						<div class="bg-blue-50 rounded px-2 py-1 text-center border border-blue-100">
							<p class="text-[9px] text-blue-700 font-semibold leading-tight">{$t('hr.salaryStatement.officialLeave')}</p>
							<p class="text-xs font-bold text-blue-800 leading-tight">{empEditRow.totalOfficialLeaveDays}</p>
						</div>
						<div class="bg-indigo-50 rounded px-2 py-1 text-center border border-indigo-100">
							<p class="text-[9px] text-indigo-700 font-semibold leading-tight">{$t('hr.salaryStatement.approvedLeaves')}</p>
							<p class="text-xs font-bold text-indigo-800 leading-tight">{empEditRow.totalApprovedDaysOff}</p>
						</div>
						<div class="bg-slate-50 rounded px-2 py-1 text-center border border-slate-200">
							<p class="text-[9px] text-slate-600 font-semibold leading-tight">{$t('hr.salaryStatement.expectedDays')}</p>
							<p class="text-xs font-bold text-slate-800 leading-tight">{empEditRow.totalExpectedWorkDays}</p>
						</div>
					</div>
				</div>

				<!-- Allowances -->
				<div>
					<p class="text-xs font-bold text-green-700 uppercase tracking-widest mb-3">{$t('hr.salaryStatement.allowances')}</p>
					<div class="grid grid-cols-5 gap-3">
						<div>
							<label for="ee-basic" class="block text-xs font-semibold text-slate-500 mb-1">{$t('hr.salaryStatement.basicSalary')}</label>
							<input id="ee-basic" type="number" min="0" bind:value={empEdit.basicSalary} class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-violet-400" />
						</div>
						<div>
							<label for="ee-basic-mode" class="block text-xs font-semibold text-slate-500 mb-1">{$t('hr.salaryStatement.basicMode')}</label>
							<select id="ee-basic-mode" bind:value={empEdit.basicPaymentMode} class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-violet-400">
								<option>Bank</option><option>Cash</option>
							</select>
						</div>
						<div>
							<label for="ee-other" class="block text-xs font-semibold text-slate-500 mb-1">{$t('hr.salaryStatement.otherAllowance')}</label>
							<input id="ee-other" type="number" min="0" bind:value={empEdit.otherAllowance} class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-violet-400" />
						</div>
						<div>
							<label for="ee-other-mode" class="block text-xs font-semibold text-slate-500 mb-1">{$t('hr.salaryStatement.otherMode')}</label>
							<select id="ee-other-mode" bind:value={empEdit.otherAllowancePaymentMode} class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-violet-400">
								<option>Bank</option><option>Cash</option>
							</select>
						</div>
						<div>
							<label for="ee-accomm" class="block text-xs font-semibold text-slate-500 mb-1">{$t('hr.salaryStatement.accommodation')}</label>
							<input id="ee-accomm" type="number" min="0" bind:value={empEdit.accommodation} class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-violet-400" />
						</div>
						<div>
							<label for="ee-accomm-mode" class="block text-xs font-semibold text-slate-500 mb-1">{$t('hr.salaryStatement.accommodationMode')}</label>
							<select id="ee-accomm-mode" bind:value={empEdit.accommodationPaymentMode} class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-violet-400">
								<option>Bank</option><option>Cash</option>
							</select>
						</div>
						<div>
							<label for="ee-travel" class="block text-xs font-semibold text-slate-500 mb-1">{$t('hr.salaryStatement.travelAllowance')}</label>
							<input id="ee-travel" type="number" min="0" bind:value={empEdit.travel} class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-violet-400" />
						</div>
						<div>
							<label for="ee-travel-mode" class="block text-xs font-semibold text-slate-500 mb-1">{$t('hr.salaryStatement.travelMode')}</label>
							<select id="ee-travel-mode" bind:value={empEdit.travelPaymentMode} class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-violet-400">
								<option>Bank</option><option>Cash</option>
							</select>
						</div>
						<div>
							<label for="ee-food" class="block text-xs font-semibold text-slate-500 mb-1">{$t('hr.salaryStatement.foodAllowance')}</label>
							<input id="ee-food" type="number" min="0" bind:value={empEdit.food} class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-violet-400" />
						</div>
						<div>
							<label for="ee-food-mode" class="block text-xs font-semibold text-slate-500 mb-1">{$t('hr.salaryStatement.foodMode')}</label>
							<select id="ee-food-mode" bind:value={empEdit.foodPaymentMode} class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-violet-400">
								<option>Bank</option><option>Cash</option>
							</select>
						</div>
					</div>
				</div>

				<!-- Deductions -->
				<div class="border-t border-slate-100 pt-4">
					<p class="text-xs font-bold text-green-700 uppercase tracking-widest mb-3">{$t('hr.salaryStatement.deductions')}</p>

					<!-- Group 1: Financial / Manual Deductions -->
					<p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2 flex items-center gap-1.5">
						<span class="inline-block w-2 h-2 rounded-full bg-slate-300"></span>{$t('hr.salaryStatement.financialDeductions')}
					</p>
					<div class="grid grid-cols-3 gap-3 mb-4">
						<div class="bg-slate-50 rounded-lg p-2.5 border border-slate-100">
							<label for="ee-gosi" class="block text-[10px] font-bold text-slate-500 uppercase tracking-wide mb-1">{$t('hr.salaryStatement.gosi')}</label>
							<input id="ee-gosi" type="number" min="0" bind:value={empEdit.gosiDeduction} class="w-full px-2.5 py-1.5 border border-slate-200 rounded-md text-sm font-semibold text-slate-800 bg-white focus:outline-none focus:ring-2 focus:ring-violet-400" />
						</div>
						<div class="bg-orange-50 rounded-lg p-2.5 border border-orange-100">
							<label for="ee-pos" class="block text-[10px] font-bold text-orange-600 uppercase tracking-wide mb-1">{$t('hr.salaryStatement.posShortageLabel')}</label>
							<input id="ee-pos" type="number" min="0" bind:value={empEdit.posShortage} class="w-full px-2.5 py-1.5 border border-orange-200 rounded-md text-sm font-semibold text-orange-800 bg-white focus:outline-none focus:ring-2 focus:ring-orange-400" />
						</div>
						<div class="bg-rose-50 rounded-lg p-2.5 border border-rose-100">
							<label for="ee-sal-adv" class="block text-[10px] font-bold text-rose-600 uppercase tracking-wide mb-1">{$t('hr.salaryStatement.salaryAdvanceLabel')}</label>
							<input id="ee-sal-adv" type="number" min="0" bind:value={empEdit.salaryAdvance} class="w-full px-2.5 py-1.5 border border-rose-200 rounded-md text-sm font-semibold text-rose-800 bg-white focus:outline-none focus:ring-2 focus:ring-rose-400" />
						</div>
						<div class="bg-fuchsia-50 rounded-lg p-2.5 border border-fuchsia-100">
							<label for="ee-loan" class="block text-[10px] font-bold text-fuchsia-600 uppercase tracking-wide mb-1">{$t('hr.salaryStatement.loanDeductionsLabel')}</label>
							<input id="ee-loan" type="number" min="0" bind:value={empEdit.loanDeductions} class="w-full px-2.5 py-1.5 border border-fuchsia-200 rounded-md text-sm font-semibold text-fuchsia-800 bg-white focus:outline-none focus:ring-2 focus:ring-fuchsia-400" />
						</div>
						<div class="bg-amber-50 rounded-lg p-2.5 border border-amber-100">
							<label for="ee-pen" class="block text-[10px] font-bold text-amber-600 uppercase tracking-wide mb-1">{$t('hr.salaryStatement.penaltiesLabel')}</label>
							<input id="ee-pen" type="number" min="0" bind:value={empEdit.penalties} class="w-full px-2.5 py-1.5 border border-amber-200 rounded-md text-sm font-semibold text-amber-800 bg-white focus:outline-none focus:ring-2 focus:ring-amber-400" />
						</div>
						<div class="bg-gray-50 rounded-lg p-2.5 border border-gray-100">
							<label for="ee-other-ded" class="block text-[10px] font-bold text-gray-500 uppercase tracking-wide mb-1">{$t('hr.salaryStatement.otherDeductionsLabel')}</label>
							<input id="ee-other-ded" type="number" min="0" bind:value={empEdit.otherDeductions} class="w-full px-2.5 py-1.5 border border-gray-200 rounded-md text-sm font-semibold text-gray-700 bg-white focus:outline-none focus:ring-2 focus:ring-gray-400" />
						</div>
					</div>

					<!-- Rate Info Card: Attendance Deduction Calculation Rates -->
					<div class="bg-teal-50 border border-teal-200 rounded-lg px-3 py-2 mb-2 flex items-center gap-3 flex-wrap">
						<span class="text-[9px] font-bold text-teal-600 uppercase tracking-widest whitespace-nowrap">{$t('hr.salaryStatement.attendanceDeductionRates')}:</span>
						<span class="flex items-center gap-1 text-[9px]"><span class="w-1.5 h-1.5 rounded-full bg-purple-400 inline-block"></span><span class="text-purple-600 font-semibold">{$t('hr.salaryStatement.lateDeductionsLabel')}:</span> <span class="font-bold text-purple-800">{_perMinuteRate.toFixed(4)}</span> <span class="text-purple-400">{$t('hr.salaryStatement.perMinute')}</span></span>
						<span class="flex items-center gap-1 text-[9px]"><span class="w-1.5 h-1.5 rounded-full bg-indigo-400 inline-block"></span><span class="text-indigo-600 font-semibold">{$t('hr.salaryStatement.underWorkedDeductionsLabel')}:</span> <span class="font-bold text-indigo-800">{_perMinuteRate.toFixed(4)}</span> <span class="text-indigo-400">{$t('hr.salaryStatement.perMinute')}</span></span>
						<span class="flex items-center gap-1 text-[9px]"><span class="w-1.5 h-1.5 rounded-full bg-pink-400 inline-block"></span><span class="text-pink-600 font-semibold">{$t('hr.salaryStatement.incompleteDayDeductions')}:</span> <span class="font-bold text-pink-800">{_perDayRate.toFixed(2)}</span> <span class="text-pink-400">{$t('hr.salaryStatement.perDay')}</span></span>
						<span class="flex items-center gap-1 text-[9px]"><span class="w-1.5 h-1.5 rounded-full bg-sky-400 inline-block"></span><span class="text-sky-600 font-semibold">{$t('hr.salaryStatement.unapprovedLeaveDeductionsLabel')}:</span> <span class="font-bold text-sky-800">{_perDayRate.toFixed(2)}</span> <span class="text-sky-400">{$t('hr.salaryStatement.perDay')}</span></span>
						<span class="text-[9px] text-teal-400 ml-auto whitespace-nowrap">{_totalSalForRate.toFixed(2)} ÷ 240h = {_hourlyRate.toFixed(4)} {$t('hr.salaryStatement.perHour')}</span>
					</div>

					<!-- Group 2: Attendance-Based Deductions (auto-computed, overridable) -->
					<p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2 flex items-center gap-1.5">
						<span class="inline-block w-2 h-2 rounded-full bg-violet-400"></span>{$t('hr.salaryStatement.attendanceBasedDeductions')}
						<span class="normal-case font-normal text-slate-300 ml-1">— {$t('hr.salaryStatement.autoComputedEditable')}</span>
					</p>
					<div class="grid grid-cols-4 gap-3">
						<div class="bg-purple-50 rounded-lg p-2.5 border border-purple-100">
							<label for="ee-late-ded" class="block text-[10px] font-bold text-purple-600 uppercase tracking-wide mb-1">{$t('hr.salaryStatement.lateDeductionsLabel')}</label>
							<input id="ee-late-ded" type="number" min="0" bind:value={empEdit.lateDeduction} class="w-full px-2.5 py-1.5 border border-purple-200 rounded-md text-sm font-semibold text-purple-800 bg-white focus:outline-none focus:ring-2 focus:ring-purple-400" />
						</div>
						<div class="bg-indigo-50 rounded-lg p-2.5 border border-indigo-100">
							<label for="ee-under-ded" class="block text-[10px] font-bold text-indigo-600 uppercase tracking-wide mb-1">{$t('hr.salaryStatement.underWorkedDeductionsLabel')}</label>
							<input id="ee-under-ded" type="number" min="0" bind:value={empEdit.underWorkedDeduction} class="w-full px-2.5 py-1.5 border border-indigo-200 rounded-md text-sm font-semibold text-indigo-800 bg-white focus:outline-none focus:ring-2 focus:ring-indigo-400" />
						</div>
						<div class="bg-sky-50 rounded-lg p-2.5 border border-sky-100">
							<label for="ee-unap-ded" class="block text-[10px] font-bold text-sky-600 uppercase tracking-wide mb-1">{$t('hr.salaryStatement.unapprovedLeaveDeductionsLabel')}</label>
							<input id="ee-unap-ded" type="number" min="0" bind:value={empEdit.unapprovedLeaveDeduction} class="w-full px-2.5 py-1.5 border border-sky-200 rounded-md text-sm font-semibold text-sky-800 bg-white focus:outline-none focus:ring-2 focus:ring-sky-400" />
						</div>
						<div class="bg-pink-50 rounded-lg p-2.5 border border-pink-100">
							<label for="ee-incomp-ded" class="block text-[10px] font-bold text-pink-600 uppercase tracking-wide mb-1">{$t('hr.salaryStatement.incompleteDayDeductions')}</label>
							<input id="ee-incomp-ded" type="number" min="0" bind:value={empEdit.incompleteDayDeduction} class="w-full px-2.5 py-1.5 border border-pink-200 rounded-md text-sm font-semibold text-pink-800 bg-white focus:outline-none focus:ring-2 focus:ring-pink-400" />
						</div>
						<div class="bg-red-50 rounded-lg p-2.5 border border-red-200 col-span-1">
							<p class="text-[10px] font-bold text-red-600 uppercase tracking-wide mb-1">{$t('hr.salaryStatement.foodAllowanceDeduction')}</p>
							<div class="flex items-center gap-2 mt-1">
								<button
									type="button"
									aria-label="{$t('hr.salaryStatement.toggleFoodAllowanceDeduction')}"
									class="relative inline-flex h-5 w-9 items-center rounded-full transition-colors focus:outline-none {empEdit.foodDeductionActive ? 'bg-red-500' : 'bg-slate-300'}"
									on:click={() => { empEdit.foodDeductionActive = !empEdit.foodDeductionActive; empEdit = empEdit; }}
								>
									<span class="inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform {empEdit.foodDeductionActive ? 'translate-x-4' : 'translate-x-0.5'}"></span>
								</button>
								<span class="text-xs font-semibold {empEdit.foodDeductionActive ? 'text-red-700' : 'text-slate-400'}">
									{empEdit.foodDeductionActive ? '-' + _food.toFixed(2) : $t('hr.salaryStatement.inactive')}
								</span>
							</div>
						</div>
					</div>
				</div>

				<!-- Auto-calculated totals -->
				<div class="border-t border-slate-100 pt-4">
					<p class="text-xs font-bold text-green-700 uppercase tracking-widest mb-3">{$t('hr.salaryStatement.calculatedTotals')}</p>
					<div class="grid grid-cols-3 gap-3">
						<div class="bg-yellow-50 rounded-xl px-4 py-3 text-center border border-yellow-200">
							<p class="text-xs text-yellow-700 font-semibold mb-1">{$t('hr.salaryStatement.netSalary')}</p>
							<p class="text-lg font-bold text-yellow-800">{_netSal.toFixed(2)}</p>
						</div>
						<div class="bg-blue-50 rounded-xl px-4 py-3 text-center border border-blue-200">
							<p class="text-xs text-blue-700 font-semibold mb-1">{$t('hr.salaryStatement.netBank')}</p>
							<p class="text-lg font-bold text-blue-800">{_netBank.toFixed(2)}</p>
						</div>
						<div class="bg-red-50 rounded-xl px-4 py-3 text-center border border-red-200">
							<p class="text-xs text-red-700 font-semibold mb-1">{$t('hr.salaryStatement.netCash')}</p>
							<p class="text-lg font-bold text-red-800">{_netCash.toFixed(2)}</p>
						</div>
					</div>
				</div>
			</div>

			<!-- Footer -->
			<div class="flex justify-end gap-3 px-6 py-4 border-t border-slate-100 bg-slate-50 flex-shrink-0">
				<button class="px-4 py-2 text-sm rounded-lg bg-slate-200 hover:bg-slate-300 text-slate-700 transition-colors" on:click={() => showEmpEditModal = false}>{$t('hr.salaryStatement.cancel')}</button>
				<button class="px-6 py-2 text-sm rounded-lg bg-violet-600 hover:bg-violet-700 text-white font-semibold transition-colors" on:click={applyEmpEdit}>{$t('hr.salaryStatement.apply')}</button>
			</div>
		</div>
	</div>
{/if}

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
