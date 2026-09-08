<script lang="ts">
	import { _ as t, locale } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import * as HRServicesEsobModule from './HRServicesEsob.svelte';
	const HRServicesEsob: any = (HRServicesEsobModule as any).default ?? HRServicesEsobModule;

	type ServiceKey = 'settlementRules' | 'travelTickets' | 'leaveSalary' | 'esob' | 'qualificationManagement';

	interface Service {
		key: ServiceKey;
		labelKey: string;
		icon: string;
		accent: string;
		bg: string;
		glow: string;
	}

	const services: Service[] = [
		{
			key: 'settlementRules',
			labelKey: 'hr.servicesWindow.serviceSettlementRules',
			icon: '📋',
			accent: '#f97316',
			bg: 'rgba(249,115,22,0.08)',
			glow: 'rgba(249,115,22,0.25)'
		},
		{
			key: 'travelTickets',
			labelKey: 'hr.servicesWindow.serviceTravelTickets',
			icon: '✈️',
			accent: '#22c55e',
			bg: 'rgba(34,197,94,0.08)',
			glow: 'rgba(34,197,94,0.25)'
		},
		{
			key: 'leaveSalary',
			labelKey: 'hr.servicesWindow.serviceAnnualLeave',
			icon: '💰',
			accent: '#a78bfa',
			bg: 'rgba(167,139,250,0.08)',
			glow: 'rgba(167,139,250,0.25)'
		},
		{
			key: 'esob',
			labelKey: 'hr.servicesWindow.serviceEsob',
			icon: '🏅',
			accent: '#f472b6',
			bg: 'rgba(244,114,182,0.08)',
			glow: 'rgba(244,114,182,0.25)'
		},
		{
			key: 'qualificationManagement',
			labelKey: 'hr.servicesWindow.serviceApplicability',
			icon: '✅',
			accent: '#0ea5e9',
			bg: 'rgba(14,165,233,0.08)',
			glow: 'rgba(14,165,233,0.25)'
		}
	];

	let selected: ServiceKey | null = null;

	type SettlementRuleType = 'ticket' | 'leave_salary';
	interface SettlementRule {
		id: number;
		rule_type: SettlementRuleType;
		rule_name_en: string;
		rule_name_ar: string;
		qualification_cycle_years: number;
		qualification_cycle_value?: number;
		qualification_cycle_unit?: 'year' | 'month';
		ticket_count: number | null;
		entitled_days: number | null;
		is_active: boolean;
	}

	interface EmployeeMasterRow {
		id: string;
		name_en: string | null;
		name_ar: string | null;
		nationality_id: string | null;
		nationality_name_en: string | null;
		nationality_name_ar: string | null;
		sponsorship_status: boolean | null;
		join_date: string | null;
		employment_status: string | null;
	}

	interface NationalityRow {
		id: string;
		name_en: string | null;
		name_ar: string | null;
	}

	interface ApplicabilityRpcRow {
		applicability_id: number | null;
		employee_id: string;
		employee_name_en: string | null;
		employee_name_ar: string | null;
		nationality_id: string | null;
		nationality_name_en: string | null;
		nationality_name_ar: string | null;
		sponsorship_status: boolean | null;
		join_date: string | null;
		employment_status: string | null;
		ticket_rule_id: number | null;
		ticket_rule_enabled: boolean;
		ticket_rule_name_en: string | null;
		ticket_rule_name_ar: string | null;
		qualified_ticket_count: number | null;
		ticket_periods_count: number;
		leave_salary_rule_id: number | null;
		leave_salary_rule_enabled: boolean;
		leave_rule_name_en: string | null;
		leave_rule_name_ar: string | null;
		qualified_leave_days: number | null;
		leave_periods_count: number;
		total_count: number;
	}

	interface EmployeeApplicabilityAssignment {
		id: number | null;
		employee_id: string;
		ticket_rule_id: number | null;
		ticket_rule_enabled: boolean;
		ticket_rule_name_en: string | null;
		ticket_rule_name_ar: string | null;
		qualified_ticket_count: number | null;
		ticket_periods_count: number;
		leave_salary_rule_id: number | null;
		leave_salary_rule_enabled: boolean;
		leave_rule_name_en: string | null;
		leave_rule_name_ar: string | null;
		qualified_leave_days: number | null;
		leave_periods_count: number;
	}

	interface RulePeriodDraft {
		rule_id: number | null;
		duration_years: number;
		duration_months: number;
		is_infinite: boolean;
	}

	interface RulePeriodRow {
		id: number;
		sequence_no: number;
		rule_id: number;
		rule_name_en: string | null;
		rule_name_ar: string | null;
		duration_years: number;
		duration_months: number;
		effective_from: string;
		effective_to: string | null;
		is_infinite: boolean;
	}

	interface QualificationUsageRpcRow {
		employee_id: string;
		ticket_issued_count: number | null;
		leave_approved_days: number | null;
		leave_paid_days: number | null;
	}

	interface TicketIssuanceRow {
		id: number;
		employee_id: string;
		issuance_date: string;
		ticket_count: number;
		ticket_amount: number;
		is_paid: boolean;
		created_at: string;
	}

	interface LeaveApprovalRow {
		id: number;
		employee_id: string;
		leave_date: string;
		is_paid: boolean;
		created_at: string;
	}

	// day_off records shown in the Manage popup
	interface DayOffLeaveRow {
		id: string;
		employee_id: string;
		day_off_date: string;
		is_paid: boolean;
		is_manual_hr_entry: boolean;
		approval_status: string | null;
	}

	interface IssuedTicketTableRow extends TicketIssuanceRow {
		employee_name_en: string | null;
		employee_name_ar: string | null;
	}

	interface IssuedLeaveTableRow extends LeaveApprovalRow {
		employee_name_en: string | null;
		employee_name_ar: string | null;
	}

	let settlementRules: SettlementRule[] = [];
	let applicabilityEmployees: EmployeeMasterRow[] = [];
	let applicabilityAssignments: EmployeeApplicabilityAssignment[] = [];
	let nationalityOptions: NationalityRow[] = [];
	let isLoadingApplicability = false;
	let isLoadingMoreApplicability = false;
	let applicabilityError = '';
	let isSavingApplicability = false;
	let applicabilityOffset = 0;
	let applicabilityLimit = 60;
	let applicabilityTotalCount = 0;
	let hasMoreApplicability = false;
	let searchName = '';
	let selectedNationalityId = '';
	let ticketStatusFilter: 'all' | 'enabled' | 'disabled' = 'all';
	let leaveStatusFilter: 'all' | 'enabled' | 'disabled' = 'all';
	let applicabilityTableWrapEl: HTMLDivElement | null = null;
	let showRuleScheduleModal = false;
	let scheduleEmployeeId: string | null = null;
	let scheduleRuleType: SettlementRuleType | null = null;
	let schedulePeriods: RulePeriodDraft[] = [];
	let scheduleEmployee: EmployeeMasterRow | null = null;
	let schedulePreviewRows: Array<{ effective_from: string; effective_to: string | null }> = [];
	let ticketUsageByEmployee: Record<string, number> = {};
	let leaveUsageByEmployee: Record<string, number> = {};  // approved (from day_off DRS052)
	let leavePaidByEmployee: Record<string, number> = {};   // paid subset (is_paid = true)

	let showTicketManageModal = false;
	let manageTicketEmployeeId: string | null = null;
	let manageTicketRecords: TicketIssuanceRow[] = [];
	let ticketIssueCount: number | '' = 1;
	let ticketIssueDate = formatDateYmd(new Date());
	let ticketIssueAmount: number | '' = '';
	let ticketIssuePaid = false;

	let showLeaveManageModal = false;
	let manageLeaveEmployeeId: string | null = null;
	let manageLeaveRecords: DayOffLeaveRow[] = [];
	let leaveManageLoading = false;
	let leaveManageSaving = false;
	let leaveEntryMode: 'single' | 'range' = 'single';
	let leaveSingleDate = formatDateYmd(new Date());
	let leaveRangeStart = formatDateYmd(new Date());
	let leaveRangeEnd = formatDateYmd(new Date());
	let leaveDefaultPaid = false;
	let leaveConflictDates: string[] = [];

	let isLoadingRules = false;
	let rulesError = '';
	let isSavingRule = false;
	let isLoadingTicketIssued = false;
	let isLoadingLeaveIssued = false;
	let ticketIssuedTableRows: IssuedTicketTableRow[] = [];
	let leaveIssuedTableRows: IssuedLeaveTableRow[] = [];
	let filteredTicketIssuedRows: IssuedTicketTableRow[] = [];
	let filteredLeaveIssuedRows: IssuedLeaveTableRow[] = [];
	let ticketIssuedSearch = '';
	let ticketIssuedPaymentFilter: 'all' | 'paid' | 'not_paid' = 'all';
	let ticketIssuedDateFrom = '';
	let ticketIssuedDateTo = '';
	let leaveIssuedSearch = '';
	let leaveIssuedPaymentFilter: 'all' | 'paid' | 'not_paid' = 'all';
	let leaveIssuedDateFrom = '';
	let leaveIssuedDateTo = '';
	let activeRuleForm: SettlementRuleType | null = null;
	let formRuleNameEn = '';
	let formRuleNameAr = '';
	let formCycleYears: number | '' = 1;
	let formTicketCount: number | '' = 1;
	let formEntitledDays: number | '' = 21;

	onMount(() => {
		void Promise.all([loadSettlementRules(), loadNationalityOptions(), loadApplicabilityData(true)]);
	});

	$: scheduleEmployee = scheduleEmployeeId ? applicabilityEmployees.find((row) => row.id === scheduleEmployeeId) ?? null : null;
	$: schedulePreviewRows = getPeriodPreviewRows(scheduleEmployee?.join_date ?? null, schedulePeriods);
	$: filteredTicketIssuedRows = ticketIssuedTableRows.filter((row) => {
		const query = ticketIssuedSearch.trim().toLowerCase();
		const text = `${row.employee_id} ${row.employee_name_en ?? ''} ${row.employee_name_ar ?? ''} ${row.issuance_date}`.toLowerCase();
		const matchesSearch = query === '' || text.includes(query);
		const matchesPayment = ticketIssuedPaymentFilter === 'all'
			|| (ticketIssuedPaymentFilter === 'paid' && row.is_paid)
			|| (ticketIssuedPaymentFilter === 'not_paid' && !row.is_paid);
		const matchesFrom = ticketIssuedDateFrom === '' || row.issuance_date >= ticketIssuedDateFrom;
		const matchesTo = ticketIssuedDateTo === '' || row.issuance_date <= ticketIssuedDateTo;
		return matchesSearch && matchesPayment && matchesFrom && matchesTo;
	});
	$: filteredLeaveIssuedRows = leaveIssuedTableRows.filter((row) => {
		const query = leaveIssuedSearch.trim().toLowerCase();
		const text = `${row.employee_id} ${row.employee_name_en ?? ''} ${row.employee_name_ar ?? ''} ${row.leave_date}`.toLowerCase();
		const matchesSearch = query === '' || text.includes(query);
		const matchesPayment = leaveIssuedPaymentFilter === 'all'
			|| (leaveIssuedPaymentFilter === 'paid' && row.is_paid)
			|| (leaveIssuedPaymentFilter === 'not_paid' && !row.is_paid);
		const matchesFrom = leaveIssuedDateFrom === '' || row.leave_date >= leaveIssuedDateFrom;
		const matchesTo = leaveIssuedDateTo === '' || row.leave_date <= leaveIssuedDateTo;
		return matchesSearch && matchesPayment && matchesFrom && matchesTo;
	});

	async function loadSettlementRules() {
		isLoadingRules = true;
		rulesError = '';

		try {
			const { data, error } = await supabase
				.from('settlement_rules')
				.select('*')
				.order('created_at', { ascending: true });

			if (error) {
				throw error;
			}

			settlementRules = (data ?? []) as SettlementRule[];
		} catch (error) {
			rulesError = error instanceof Error ? error.message : 'Failed to load settlement rules';
		} finally {
			isLoadingRules = false;
		}
	}

	function handleServiceSelect(serviceKey: ServiceKey) {
		selected = selected === serviceKey ? null : serviceKey;
		activeRuleForm = null;
		closeRuleScheduleModal();

		if (selected === 'travelTickets') {
			void loadIssuedTicketsTable();
		}
		if (selected === 'leaveSalary') {
			void loadIssuedLeaveTable();
		}
	}

	async function loadIssuedTicketsTable() {
		isLoadingTicketIssued = true;
		rulesError = '';
		try {
			const { data, error } = await supabase
				.from('hr_employee_ticket_issuances')
				.select('id, employee_id, issuance_date, ticket_count, ticket_amount, is_paid, created_at')
				.order('issuance_date', { ascending: false })
				.order('id', { ascending: false })
				.limit(500);
			if (error) throw error;

			const rows = (data ?? []) as TicketIssuanceRow[];
			const employeeIds = Array.from(new Set(rows.map((row) => row.employee_id).filter(Boolean)));
			let employeeNameMap: Record<string, { name_en: string | null; name_ar: string | null }> = {};

			if (employeeIds.length > 0) {
				const { data: empData, error: empError } = await supabase
					.from('hr_employee_master')
					.select('id, name_en, name_ar')
					.in('id', employeeIds);
				if (empError) throw empError;

				employeeNameMap = ((empData ?? []) as Array<{ id: string; name_en: string | null; name_ar: string | null }>).reduce((acc, row) => {
					acc[row.id] = { name_en: row.name_en, name_ar: row.name_ar };
					return acc;
				}, {} as Record<string, { name_en: string | null; name_ar: string | null }>);
			}

			ticketIssuedTableRows = rows.filter(r => r.employee_id !== 'EMP51').map((row) => ({
				...row,
				employee_name_en: employeeNameMap[row.employee_id]?.name_en ?? null,
				employee_name_ar: employeeNameMap[row.employee_id]?.name_ar ?? null
			}));
		} catch (error) {
			rulesError = error instanceof Error ? error.message : 'Failed to load issued tickets';
		} finally {
			isLoadingTicketIssued = false;
		}
	}

	async function loadIssuedLeaveTable() {
		isLoadingLeaveIssued = true;
		rulesError = '';
		try {
			const { data, error } = await supabase
				.from('hr_employee_leave_approvals')
				.select('id, employee_id, leave_date, is_paid, created_at')
				.order('leave_date', { ascending: false })
				.order('id', { ascending: false })
				.limit(1000);
			if (error) throw error;

			const rows = (data ?? []) as LeaveApprovalRow[];
			const employeeIds = Array.from(new Set(rows.map((row) => row.employee_id).filter(Boolean)));
			let employeeNameMap: Record<string, { name_en: string | null; name_ar: string | null }> = {};

			if (employeeIds.length > 0) {
				const { data: empData, error: empError } = await supabase
					.from('hr_employee_master')
					.select('id, name_en, name_ar')
					.in('id', employeeIds);
				if (empError) throw empError;

				employeeNameMap = ((empData ?? []) as Array<{ id: string; name_en: string | null; name_ar: string | null }>).reduce((acc, row) => {
					acc[row.id] = { name_en: row.name_en, name_ar: row.name_ar };
					return acc;
				}, {} as Record<string, { name_en: string | null; name_ar: string | null }>);
			}

			leaveIssuedTableRows = rows.filter(r => r.employee_id !== 'EMP51').map((row) => ({
				...row,
				employee_name_en: employeeNameMap[row.employee_id]?.name_en ?? null,
				employee_name_ar: employeeNameMap[row.employee_id]?.name_ar ?? null
			}));
		} catch (error) {
			rulesError = error instanceof Error ? error.message : 'Failed to load approved leave days';
		} finally {
			isLoadingLeaveIssued = false;
		}
	}

	function resetTicketIssuedFilters() {
		ticketIssuedSearch = '';
		ticketIssuedPaymentFilter = 'all';
		ticketIssuedDateFrom = '';
		ticketIssuedDateTo = '';
	}

	function resetLeaveIssuedFilters() {
		leaveIssuedSearch = '';
		leaveIssuedPaymentFilter = 'all';
		leaveIssuedDateFrom = '';
		leaveIssuedDateTo = '';
	}

	function mapStatusFilter(value: 'all' | 'enabled' | 'disabled') {
		if (value === 'all') return null;
		return value === 'enabled';
	}

	async function loadNationalityOptions() {
		try {
			const { data, error } = await supabase.rpc('get_applicability_nationalities');
			if (error) throw error;
			nationalityOptions = ((data ?? []) as NationalityRow[]).filter((row) => !!row.id);
		} catch (error) {
			applicabilityError = error instanceof Error ? error.message : 'Failed to load nationalities';
		}
	}

	async function loadApplicabilityData(reset = false) {
		if (isLoadingApplicability || isLoadingMoreApplicability) return;

		if (reset) {
			isLoadingApplicability = true;
			applicabilityOffset = 0;
			applicabilityTotalCount = 0;
			hasMoreApplicability = false;
			applicabilityError = '';
		} else {
			if (!hasMoreApplicability) return;
			isLoadingMoreApplicability = true;
		}

		try {
			const offset = reset ? 0 : applicabilityOffset;
			const { data, error } = await supabase.rpc('get_hr_employee_applicability', {
				p_limit: applicabilityLimit,
				p_offset: offset,
				p_name_search: searchName.trim() || null,
				p_nationality_id: selectedNationalityId || null,
				p_ticket_enabled: mapStatusFilter(ticketStatusFilter),
				p_leave_enabled: mapStatusFilter(leaveStatusFilter)
			});

			if (error) throw error;

			const rows = ((data ?? []) as ApplicabilityRpcRow[]).filter(r => r.employee_id !== 'EMP51');
			const employees = rows.map((row) => ({
				id: row.employee_id,
				name_en: row.employee_name_en,
				name_ar: row.employee_name_ar,
				nationality_id: row.nationality_id,
				nationality_name_en: row.nationality_name_en,
				nationality_name_ar: row.nationality_name_ar,
				sponsorship_status: row.sponsorship_status,
				join_date: row.join_date,
				employment_status: row.employment_status
			}));

			const assignments = rows.map((row) => ({
				id: row.applicability_id,
				employee_id: row.employee_id,
				ticket_rule_id: row.ticket_rule_id,
				ticket_rule_enabled: row.ticket_rule_enabled,
				ticket_rule_name_en: row.ticket_rule_name_en,
				ticket_rule_name_ar: row.ticket_rule_name_ar,
				qualified_ticket_count: row.qualified_ticket_count,
				ticket_periods_count: row.ticket_periods_count ?? 0,
				leave_salary_rule_id: row.leave_salary_rule_id,
				leave_salary_rule_enabled: row.leave_salary_rule_enabled,
				leave_rule_name_en: row.leave_rule_name_en,
				leave_rule_name_ar: row.leave_rule_name_ar,
				qualified_leave_days: row.qualified_leave_days,
				leave_periods_count: row.leave_periods_count ?? 0
			}));

			if (reset) {
				applicabilityEmployees = employees;
				applicabilityAssignments = assignments;
				ticketUsageByEmployee = {};
				leaveUsageByEmployee = {};
			} else {
				applicabilityEmployees = [...applicabilityEmployees, ...employees];
				applicabilityAssignments = [...applicabilityAssignments, ...assignments];
			}

			await loadQualificationUsageForEmployees(employees.map((row) => row.id));

			const fetchedCount = rows.length;
			applicabilityTotalCount = fetchedCount > 0 ? Number(rows[0].total_count ?? 0) : (reset ? 0 : applicabilityTotalCount);
			applicabilityOffset = offset + fetchedCount;
			hasMoreApplicability = applicabilityOffset < applicabilityTotalCount;
		} catch (error) {
			applicabilityError = error instanceof Error ? error.message : 'Failed to load applicability management data';
		} finally {
			isLoadingApplicability = false;
			isLoadingMoreApplicability = false;
		}
	}

	async function loadQualificationUsageForEmployees(employeeIds: string[]) {
		if (employeeIds.length === 0) return;

		const { data, error } = await supabase.rpc('get_hr_employee_qualification_usage', {
			p_employee_ids: employeeIds
		});

		if (error) throw error;

		const rows = (data ?? []) as QualificationUsageRpcRow[];
		const nextTicketUsage = { ...ticketUsageByEmployee };
		const nextLeaveUsage = { ...leaveUsageByEmployee };
		const nextLeavePaid = { ...leavePaidByEmployee };
		for (const row of rows) {
			nextTicketUsage[row.employee_id] = Number(row.ticket_issued_count ?? 0);
			nextLeaveUsage[row.employee_id] = Number(row.leave_approved_days ?? 0);
			nextLeavePaid[row.employee_id] = Number(row.leave_paid_days ?? 0);
		}

		ticketUsageByEmployee = nextTicketUsage;
		leaveUsageByEmployee = nextLeaveUsage;
		leavePaidByEmployee = nextLeavePaid;
	}

	function applyApplicabilityFilters() {
		void loadApplicabilityData(true);
	}

	function clearApplicabilityFilters() {
		searchName = '';
		selectedNationalityId = '';
		ticketStatusFilter = 'all';
		leaveStatusFilter = 'all';
		void loadApplicabilityData(true);
	}

	function handleApplicabilityScroll(event: Event) {
		const target = event.currentTarget as HTMLDivElement;
		const remaining = target.scrollHeight - target.scrollTop - target.clientHeight;
		if (remaining < 160) {
			void loadApplicabilityData(false);
		}
	}

	function formatDateYmd(date: Date) {
		const y = date.getFullYear();
		const m = `${date.getMonth() + 1}`.padStart(2, '0');
		const d = `${date.getDate()}`.padStart(2, '0');
		return `${y}-${m}-${d}`;
	}

	function addMonths(date: Date, months: number) {
		const copy = new Date(date);
		copy.setMonth(copy.getMonth() + months);
		return copy;
	}

	function getPeriodPreviewRows(joinDate: string | null, periods: RulePeriodDraft[]) {
		const rows: Array<{ effective_from: string; effective_to: string | null }> = [];
		const base = joinDate ? new Date(joinDate) : new Date();
		if (Number.isNaN(base.getTime())) return rows;

		let currentStart = new Date(base);
		for (const period of periods) {
			if (!period.rule_id) {
				rows.push({ effective_from: formatDateYmd(currentStart), effective_to: null });
				continue;
			}

			if (period.is_infinite) {
				rows.push({ effective_from: formatDateYmd(currentStart), effective_to: null });
				break;
			}

			const months = (period.duration_years * 12) + period.duration_months;
			const end = addMonths(currentStart, months);
			end.setDate(end.getDate() - 1);
			rows.push({ effective_from: formatDateYmd(currentStart), effective_to: formatDateYmd(end) });

			const nextStart = new Date(end);
			nextStart.setDate(nextStart.getDate() + 1);
			currentStart = nextStart;
		}

		return rows;
	}

	function createDefaultPeriod(ruleType: SettlementRuleType): RulePeriodDraft {
		return {
			rule_id: getRulesByType(ruleType)[0]?.id ?? null,
			duration_years: 1,
			duration_months: 0,
			is_infinite: false
		};
	}

	async function openRuleScheduleModal(employeeId: string, ruleType: SettlementRuleType) {
		scheduleEmployeeId = employeeId;
		scheduleRuleType = ruleType;
		schedulePeriods = [createDefaultPeriod(ruleType)];
		showRuleScheduleModal = true;

		try {
			const { data, error } = await supabase.rpc('get_hr_employee_rule_periods', {
				p_employee_id: employeeId,
				p_rule_type: ruleType
			});
			if (error) throw error;

			const periods = (data ?? []) as RulePeriodRow[];
			if (periods.length > 0) {
				schedulePeriods = periods.map((period) => ({
					rule_id: period.rule_id,
					duration_years: period.duration_years ?? 0,
					duration_months: period.duration_months ?? 0,
					is_infinite: period.is_infinite
				}));
			}
		} catch (error) {
			applicabilityError = error instanceof Error ? error.message : 'Failed to load rule schedule';
		}
	}

	function closeRuleScheduleModal() {
		showRuleScheduleModal = false;
		scheduleEmployeeId = null;
		scheduleRuleType = null;
		schedulePeriods = [];
	}

	function addSchedulePeriod() {
		if (!scheduleRuleType) return;
		if (schedulePeriods[schedulePeriods.length - 1]?.is_infinite) return;
		schedulePeriods = [...schedulePeriods, createDefaultPeriod(scheduleRuleType)];
	}

	function removeSchedulePeriod(index: number) {
		schedulePeriods = schedulePeriods.filter((_, idx) => idx !== index);
		if (schedulePeriods.length === 0 && scheduleRuleType) {
			schedulePeriods = [createDefaultPeriod(scheduleRuleType)];
		}
	}

	function updateSchedulePeriod(index: number, patch: Partial<RulePeriodDraft>) {
		schedulePeriods = schedulePeriods.map((period, idx) => {
			if (idx !== index) return period;
			const next = { ...period, ...patch };
			if (next.is_infinite) {
				next.duration_years = 0;
				next.duration_months = 0;
			}
			return next;
		});
	}

	async function saveRuleSchedule() {
		if (!scheduleEmployeeId || !scheduleRuleType) return;
		isSavingApplicability = true;
		applicabilityError = '';

		try {
			for (const period of schedulePeriods) {
				if (!period.rule_id) {
					throw new Error('Please select a rule for each period.');
				}
				if (!period.is_infinite && period.duration_years === 0 && period.duration_months === 0) {
					throw new Error('Each non-infinite period must have duration.');
				}
			}

			const payload = schedulePeriods.map((period) => ({
				rule_id: period.rule_id,
				duration_years: period.duration_years,
				duration_months: period.duration_months,
				is_infinite: period.is_infinite
			}));

			const { error } = await supabase.rpc('save_hr_employee_rule_periods', {
				p_employee_id: scheduleEmployeeId,
				p_rule_type: scheduleRuleType,
				p_periods: payload
			});
			if (error) throw error;

			closeRuleScheduleModal();
			await loadApplicabilityData(true);
		} catch (error) {
			applicabilityError = error instanceof Error ? error.message : 'Failed to save rule schedule';
		} finally {
			isSavingApplicability = false;
		}
	}

	function openRuleForm(type: SettlementRuleType) {
		activeRuleForm = type;
		formRuleNameEn = '';
		formRuleNameAr = '';
		formCycleYears = 1;
		formTicketCount = 1;
		formEntitledDays = 21;
	}

	function closeRuleForm() {
		activeRuleForm = null;
	}

	function getRulesByType(type: SettlementRuleType) {
		return settlementRules.filter((rule) => rule.rule_type === type && rule.is_active);
	}

	function getAssignmentForEmployee(employeeId: string) {
		return applicabilityAssignments.find((row) => row.employee_id === employeeId) ?? null;
	}

	function localizedText(en: string | null | undefined, ar: string | null | undefined, fallback = '—') {
		const isArabic = $locale === 'ar';
		const primary = (isArabic ? ar : en) ?? '';
		const secondary = (isArabic ? en : ar) ?? '';
		const value = primary.trim() || secondary.trim();
		return value || fallback;
	}

	function localizedDir() {
		return $locale === 'ar' ? 'rtl' : 'ltr';
	}

	function getTicketRemaining(employeeId: string, qualified: number | null | undefined) {
		const total = Number(qualified ?? 0);
		const used = Number(ticketUsageByEmployee[employeeId] ?? 0);
		return Math.max(0, total - used);
	}

	function getLeaveRemaining(employeeId: string, qualified: number | null | undefined) {
		const total = Number(qualified ?? 0);
		const paid = Number(leavePaidByEmployee[employeeId] ?? 0);
		return Math.max(0, total - paid);
	}

	function formatCycleLabel(rule: SettlementRule) {
		const cycleValue = rule.qualification_cycle_value ?? rule.qualification_cycle_years ?? 1;
		const cycleUnit = rule.qualification_cycle_unit ?? 'year';
		if ($locale === 'ar') {
			const unitLabel = cycleUnit === 'month' ? 'شهر' : 'سنة';
			return `كل ${cycleValue} ${unitLabel}`;
		}
		const unitLabel = cycleUnit === 'month' ? (cycleValue === 1 ? 'month' : 'months') : (cycleValue === 1 ? 'year' : 'years');
		return `Every ${cycleValue} ${unitLabel}`;
	}

	function formatJoiningDuration(joinDate: string | null) {
		if (!joinDate) return '—';
		const start = new Date(joinDate);
		const end = new Date();
		if (Number.isNaN(start.getTime())) return '—';
		if (start > end) return $locale === 'ar' ? '0 يوم' : '0 days';

		let years = end.getFullYear() - start.getFullYear();
		let months = end.getMonth() - start.getMonth();
		let days = end.getDate() - start.getDate();

		if (days < 0) {
			const previousMonthLastDay = new Date(end.getFullYear(), end.getMonth(), 0).getDate();
			days += previousMonthLastDay;
			months -= 1;
		}

		if (months < 0) {
			months += 12;
			years -= 1;
		}

		const parts: string[] = [];
		if ($locale === 'ar') {
			if (years > 0) parts.push(`${years} سنة`);
			if (months > 0) parts.push(`${months} شهر`);
			parts.push(`${days} يوم`);
		} else {
			if (years > 0) parts.push(`${years} year${years !== 1 ? 's' : ''}`);
			if (months > 0) parts.push(`${months} month${months !== 1 ? 's' : ''}`);
			parts.push(`${days} day${days !== 1 ? 's' : ''}`);
		}
		return parts.join(', ');
	}

	function hasMissingJoinDate(joinDate: string | null) {
		if (!joinDate) return true;
		return Number.isNaN(new Date(joinDate).getTime());
	}

	async function disableRuleForEmployee(employeeId: string, ruleType: SettlementRuleType) {
		isSavingApplicability = true;
		applicabilityError = '';
		try {
			const { error } = await supabase.rpc('save_hr_employee_rule_periods', {
				p_employee_id: employeeId,
				p_rule_type: ruleType,
				p_periods: []
			});
			if (error) throw error;

			await loadApplicabilityData(true);
		} catch (error) {
			applicabilityError = error instanceof Error ? error.message : 'Failed to disable rule';
		} finally {
			isSavingApplicability = false;
		}
	}

	async function saveRule() {
		if (!activeRuleForm) return;
		isSavingRule = true;
		rulesError = '';

		const rule_name_en = formRuleNameEn.trim();
		const rule_name_ar = formRuleNameAr.trim();
		const qualification_cycle_years = Number(formCycleYears) || 1;
		const basePayload = {
			rule_type: activeRuleForm,
			rule_name_en: rule_name_en,
			rule_name_ar: rule_name_ar,
			qualification_cycle_years,
			qualification_cycle_value: qualification_cycle_years,
			qualification_cycle_unit: 'year',
			is_active: true
		};

		const payload =
			activeRuleForm === 'ticket'
				? { ...basePayload, ticket_count: Number(formTicketCount) || 1, entitled_days: null }
				: { ...basePayload, ticket_count: null, entitled_days: Number(formEntitledDays) || 21 };

		try {
			const { error } = await supabase.from('settlement_rules').insert(payload);
			if (error) throw error;
			closeRuleForm();
			await loadSettlementRules();
		} catch (error) {
			rulesError = error instanceof Error ? error.message : 'Failed to save settlement rule';
		} finally {
			isSavingRule = false;
		}
	}

	async function deleteRule(id: number) {
		try {
			const { error } = await supabase.from('settlement_rules').delete().eq('id', id);
			if (error) throw error;
			await loadSettlementRules();
		} catch (error) {
			rulesError = error instanceof Error ? error.message : 'Failed to delete settlement rule';
		}
	}

	function getManageEmployee(employeeId: string | null) {
		if (!employeeId) return null;
		return applicabilityEmployees.find((row) => row.id === employeeId) ?? null;
	}

	function getManageAssignment(employeeId: string | null) {
		if (!employeeId) return null;
		return getAssignmentForEmployee(employeeId);
	}

	async function openTicketManageModal(employeeId: string) {
		showTicketManageModal = true;
		manageTicketEmployeeId = employeeId;
		ticketIssueCount = 1;
		ticketIssueDate = formatDateYmd(new Date());
		ticketIssueAmount = '';
		ticketIssuePaid = false;
		await loadTicketManageRecords(employeeId);
	}

	function closeTicketManageModal() {
		showTicketManageModal = false;
		manageTicketEmployeeId = null;
		manageTicketRecords = [];
	}

	async function loadTicketManageRecords(employeeId: string) {
		const { data, error } = await supabase
			.from('hr_employee_ticket_issuances')
			.select('id, employee_id, issuance_date, ticket_count, ticket_amount, is_paid, created_at')
			.eq('employee_id', employeeId)
			.order('issuance_date', { ascending: false })
			.order('id', { ascending: false });

		if (error) throw error;
		manageTicketRecords = (data ?? []) as TicketIssuanceRow[];
	}

	async function saveTicketIssue() {
		if (!manageTicketEmployeeId) return;
		const count = Number(ticketIssueCount) || 0;
		const amount = Number(ticketIssueAmount) || 0;

		if (count <= 0) {
			applicabilityError = 'Issued ticket count must be greater than zero.';
			return;
		}

		if (!ticketIssueDate) {
			applicabilityError = 'Issue date is required.';
			return;
		}

		if (amount < 0) {
			applicabilityError = 'Ticket amount cannot be negative.';
			return;
		}

		isSavingApplicability = true;
		applicabilityError = '';

		try {
			const { error } = await supabase.from('hr_employee_ticket_issuances').insert({
				employee_id: manageTicketEmployeeId,
				issuance_date: ticketIssueDate,
				ticket_count: count,
				ticket_amount: amount,
				is_paid: ticketIssuePaid
			});
			if (error) throw error;

			await loadTicketManageRecords(manageTicketEmployeeId);
			await loadQualificationUsageForEmployees([manageTicketEmployeeId]);
			ticketIssueCount = 1;
			ticketIssueAmount = '';
			ticketIssuePaid = false;
		} catch (error) {
			applicabilityError = error instanceof Error ? error.message : 'Failed to save ticket issuance';
		} finally {
			isSavingApplicability = false;
		}
	}

	async function toggleTicketPayment(record: TicketIssuanceRow) {
		isSavingApplicability = true;
		applicabilityError = '';
		try {
			const { error } = await supabase
				.from('hr_employee_ticket_issuances')
				.update({ is_paid: !record.is_paid })
				.eq('id', record.id);
			if (error) throw error;

			if (manageTicketEmployeeId) {
				await loadTicketManageRecords(manageTicketEmployeeId);
			}
		} catch (error) {
			applicabilityError = error instanceof Error ? error.message : 'Failed to update ticket payment status';
		} finally {
			isSavingApplicability = false;
		}
	}

	async function openLeaveManageModal(employeeId: string) {
		showLeaveManageModal = true;
		manageLeaveEmployeeId = employeeId;
		leaveSingleDate = formatDateYmd(new Date());
		leaveDefaultPaid = false;
		await loadLeaveManageRecords(employeeId);
	}

	function closeLeaveManageModal() {
		showLeaveManageModal = false;
		manageLeaveEmployeeId = null;
		manageLeaveRecords = [];
	}

	async function loadLeaveManageRecords(employeeId: string) {
		leaveManageLoading = true;
		try {
			const { data, error } = await supabase
				.from('day_off')
				.select('id, employee_id, day_off_date, is_paid, is_manual_hr_entry, approval_status')
				.eq('employee_id', employeeId)
				.eq('day_off_reason_id', 'DRS052')
				.eq('approval_status', 'approved')
				.order('day_off_date', { ascending: false });
			if (error) throw error;
			manageLeaveRecords = (data ?? []) as DayOffLeaveRow[];
		} finally {
			leaveManageLoading = false;
		}
	}

	async function saveLeaveApprovalDays() {
		if (!manageLeaveEmployeeId) return;
		applicabilityError = '';
		leaveConflictDates = [];

		// Build list of dates
		let datesToAdd: string[] = [];
		if (leaveEntryMode === 'single') {
			if (!leaveSingleDate) {
				applicabilityError = 'Leave date is required.';
				return;
			}
			datesToAdd = [leaveSingleDate];
		} else {
			if (!leaveRangeStart || !leaveRangeEnd) {
				applicabilityError = 'Start and end dates are required.';
				return;
			}
			const start = new Date(leaveRangeStart);
			const end = new Date(leaveRangeEnd);
			if (isNaN(start.getTime()) || isNaN(end.getTime()) || end < start) {
				applicabilityError = 'End date must be on or after start date.';
				return;
			}
			const cursor = new Date(start);
			while (cursor <= end) {
				datesToAdd.push(formatDateYmd(cursor));
				cursor.setDate(cursor.getDate() + 1);
			}
			if (datesToAdd.length > 90) {
				applicabilityError = 'Date range cannot exceed 90 days.';
				return;
			}
		}

		leaveManageSaving = true;
		try {
			// Conflict check — any existing record for this employee on these dates
			const { data: existing, error: checkErr } = await supabase
				.from('day_off')
				.select('day_off_date')
				.eq('employee_id', manageLeaveEmployeeId)
				.in('day_off_date', datesToAdd);

			if (checkErr) throw checkErr;

			if (existing && existing.length > 0) {
				leaveConflictDates = existing.map((r: any) => r.day_off_date as string).sort();
				applicabilityError = `Conflict: ${leaveConflictDates.length} date(s) already exist for this employee: ${leaveConflictDates.join(', ')}`;
				return;
			}

			// Insert one record per date
			const payload = datesToAdd.map((date) => ({
				id: `${manageLeaveEmployeeId}_${date}_HR`,
				employee_id: manageLeaveEmployeeId,
				day_off_date: date,
				day_off_reason_id: 'DRS052',
				approval_status: 'approved',
				is_paid: leaveDefaultPaid,
				is_manual_hr_entry: true
			}));

			const { error } = await supabase
				.from('day_off')
				.insert(payload);
			if (error) throw error;

			await loadLeaveManageRecords(manageLeaveEmployeeId);
			await loadQualificationUsageForEmployees([manageLeaveEmployeeId]);
			// Reset form
			leaveSingleDate = formatDateYmd(new Date());
			leaveRangeStart = formatDateYmd(new Date());
			leaveRangeEnd = formatDateYmd(new Date());
			leaveDefaultPaid = false;
			leaveConflictDates = [];
		} catch (error) {
			applicabilityError = error instanceof Error ? error.message : 'Failed to save leave date.';
		} finally {
			leaveManageSaving = false;
		}
	}

	async function toggleLeavePayment(record: DayOffLeaveRow) {
		leaveManageSaving = true;
		applicabilityError = '';
		try {
			const { error } = await supabase
				.from('day_off')
				.update({ is_paid: !record.is_paid })
				.eq('id', record.id);
			if (error) throw error;

			if (manageLeaveEmployeeId) {
				await loadLeaveManageRecords(manageLeaveEmployeeId);
				await loadQualificationUsageForEmployees([manageLeaveEmployeeId]);
			}
		} catch (error) {
			applicabilityError = error instanceof Error ? error.message : 'Failed to update paid status.';
		} finally {
			leaveManageSaving = false;
		}
	}
</script>

<div class="services-window">
	<!-- Service Cards Grid -->
	<div class="services-grid">
		{#each services as svc}
			<button
				class="service-card"
				class:active={selected === svc.key}
				style="--accent:{svc.accent};--bg:{svc.bg};--glow:{svc.glow}"
				on:click={() => handleServiceSelect(svc.key)}
			>
				<span class="card-icon">{svc.icon}</span>
				<span class="card-label">{$t(svc.labelKey)}</span>
				<span class="card-indicator"></span>
			</button>
		{/each}
	</div>

	<!-- Content Area -->
	{#if selected === 'settlementRules'}
		<div class="settlement-panel">
			{#if rulesError}
				<div class="rules-error">{rulesError}</div>
			{/if}

			{#if activeRuleForm}
				<div class="rule-form-card" class:ticket-form={activeRuleForm === 'ticket'} class:leave-form={activeRuleForm === 'leave_salary'}>
					<div class="rule-form-header">
						<div>
							<div class="rule-form-kicker">{activeRuleForm === 'ticket' ? $t('hr.servicesWindow.ticketRules') : $t('hr.servicesWindow.leaveSalaryRules')}</div>
							<h3>{activeRuleForm === 'ticket' ? $t('hr.servicesWindow.addTravelTicketRule') : $t('hr.servicesWindow.addAnnualLeaveRule')}</h3>
						</div>
						<button class="btn-close-form" on:click={closeRuleForm}>✕</button>
					</div>

					<div class="form-fields">
						<div class="field-group">
							<label class="field-label" for="f-name-en">{$t('hr.servicesWindow.ruleNameEn')}</label>
							<input id="f-name-en" class="field-input" type="text" placeholder={activeRuleForm === 'ticket' ? $t('hr.servicesWindow.serviceTravelTickets') : $t('hr.servicesWindow.serviceAnnualLeave')} bind:value={formRuleNameEn} />
						</div>
						<div class="field-group">
							<label class="field-label" for="f-name-ar">{$t('hr.servicesWindow.ruleNameAr')}</label>
							<input id="f-name-ar" class="field-input" type="text" dir="rtl" placeholder={activeRuleForm === 'ticket' ? 'قاعدة تذاكر السفر' : 'إدارة الإجازة السنوية'} bind:value={formRuleNameAr} />
						</div>
						<div class="field-group">
							<label class="field-label" for="f-cycle">{$t('hr.servicesWindow.qualificationCycleYears')}</label>
							<input id="f-cycle" class="field-input field-number" type="number" min="1" max="99" bind:value={formCycleYears} />
						</div>
						{#if activeRuleForm === 'ticket'}
							<div class="field-group">
								<label class="field-label" for="f-tickets">{$t('hr.servicesWindow.numberOfTickets')}</label>
								<input id="f-tickets" class="field-input field-number" type="number" min="1" max="99" bind:value={formTicketCount} />
							</div>
						{:else}
							<div class="field-group">
								<label class="field-label" for="f-days">{$t('hr.servicesWindow.entitledDays')}</label>
								<input id="f-days" class="field-input field-number" type="number" min="1" max="365" bind:value={formEntitledDays} />
							</div>
						{/if}
					</div>

					<div class="form-footer">
						<button class="btn-cancel" on:click={closeRuleForm}>{$t('common.cancel')}</button>
						<button class="btn-save" on:click={saveRule} disabled={isSavingRule}>{isSavingRule ? $t('common.saving') : $t('hr.servicesWindow.saveRule')}</button>
					</div>
				</div>
			{/if}

			<div class="settlement-sections">
				<section class="settlement-section ticket-section">
					<div class="section-header">
						<div>
							<div class="section-kicker">{$t('hr.servicesWindow.serviceSettlementRules')}</div>
							<h3>{$t('hr.servicesWindow.travelTicketManagementRules')}</h3>
						</div>
						<button class="section-add-btn ticket" on:click={() => openRuleForm('ticket')}>{$t('hr.servicesWindow.addNew')}</button>
					</div>

					{#if isLoadingRules}
						<div class="settlement-empty">{$t('hr.servicesWindow.loadingTravelTicketRules')}</div>
					{:else if getRulesByType('ticket').length === 0}
						<div class="settlement-empty">{$t('hr.servicesWindow.noTravelTicketRules')}</div>
					{:else}
						<table class="settlement-table">
							<thead>
								<tr>
									<th>{$t('hr.servicesWindow.ruleName')}</th>
									<th>{$t('hr.servicesWindow.cycle')}</th>
									<th>{$t('hr.servicesWindow.tickets')}</th>
									<th></th>
								</tr>
							</thead>
							<tbody>
								{#each getRulesByType('ticket') as rule}
									<tr>
										<td class="td-name">
											<div class="name-en" dir={localizedDir()}>{localizedText(rule.rule_name_en, rule.rule_name_ar)}</div>
										</td>
										<td>{formatCycleLabel(rule)}</td>
										<td>{rule.ticket_count}</td>
										<td class="table-actions">
											<button class="btn-delete" on:click={() => deleteRule(rule.id)} title="Delete">🗑️</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					{/if}
				</section>

				<section class="settlement-section leave-section">
					<div class="section-header">
						<div>
							<div class="section-kicker">{$t('hr.servicesWindow.serviceSettlementRules')}</div>
							<h3>{$t('hr.servicesWindow.annualLeaveManagementRules')}</h3>
						</div>
						<button class="section-add-btn leave" on:click={() => openRuleForm('leave_salary')}>{$t('hr.servicesWindow.addNew')}</button>
					</div>

					{#if isLoadingRules}
						<div class="settlement-empty">{$t('hr.servicesWindow.loadingAnnualLeaveRules')}</div>
					{:else if getRulesByType('leave_salary').length === 0}
						<div class="settlement-empty">{$t('hr.servicesWindow.noAnnualLeaveRules')}</div>
					{:else}
						<table class="settlement-table">
							<thead>
								<tr>
									<th>{$t('hr.servicesWindow.ruleName')}</th>
									<th>{$t('hr.servicesWindow.cycle')}</th>
									<th>{$t('hr.servicesWindow.days')}</th>
									<th></th>
								</tr>
							</thead>
							<tbody>
								{#each getRulesByType('leave_salary') as rule}
									<tr>
										<td class="td-name">
											<div class="name-en" dir={localizedDir()}>{localizedText(rule.rule_name_en, rule.rule_name_ar)}</div>
										</td>
										<td>{formatCycleLabel(rule)}</td>
										<td>{rule.entitled_days}</td>
										<td class="table-actions">
											<button class="btn-delete" on:click={() => deleteRule(rule.id)} title="Delete">🗑️</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					{/if}
				</section>
			</div>
		</div>

	{:else if selected === 'qualificationManagement'}
		<div class="applicability-panel">
			<div class="applicability-header">
				<div>
					<div class="section-kicker">{$t('hr.servicesWindow.hrServices')}</div>
					<h3>{$t('hr.servicesWindow.applicabilityManagement')}</h3>
				</div>
				<div class="result-count">{applicabilityEmployees.length} / {applicabilityTotalCount}</div>
			</div>

			<div class="applicability-filters">
				<input
					class="filter-input"
					type="text"
					placeholder={$t('hr.servicesWindow.searchEmployeePlaceholder')}
					bind:value={searchName}
					on:keydown={(event) => {
						if (event.key === 'Enter') applyApplicabilityFilters();
					}}
				/>
				<select class="filter-select" bind:value={selectedNationalityId}>
					<option value="">{$t('hr.servicesWindow.allNationalities')}</option>
					{#each nationalityOptions as nationality}
						<option value={nationality.id}>{localizedText(nationality.name_en, nationality.name_ar, nationality.id)}</option>
					{/each}
				</select>
				<select class="filter-select" bind:value={ticketStatusFilter}>
					<option value="all">{$t('hr.servicesWindow.ticketAll')}</option>
					<option value="enabled">{$t('hr.servicesWindow.ticketEnabled')}</option>
					<option value="disabled">{$t('hr.servicesWindow.ticketDisabled')}</option>
				</select>
				<select class="filter-select" bind:value={leaveStatusFilter}>
					<option value="all">{$t('hr.servicesWindow.leaveAll')}</option>
					<option value="enabled">{$t('hr.servicesWindow.leaveEnabled')}</option>
					<option value="disabled">{$t('hr.servicesWindow.leaveDisabled')}</option>
				</select>
				<div class="filter-actions">
					<button class="btn-apply-filter" on:click={applyApplicabilityFilters}>{$t('hr.servicesWindow.apply')}</button>
					<button class="btn-clear-filter" on:click={clearApplicabilityFilters}>{$t('hr.servicesWindow.reset')}</button>
				</div>
			</div>

			{#if applicabilityError}
				<div class="rules-error">{applicabilityError}</div>
			{/if}

			{#if isLoadingApplicability}
				<div class="applicability-empty">{$t('hr.servicesWindow.loadingEligibleEmployees')}</div>
			{:else if applicabilityEmployees.length === 0}
				<div class="applicability-empty">{$t('hr.servicesWindow.noEligibleEmployees')}</div>
			{:else}
				<div class="applicability-table-wrap" bind:this={applicabilityTableWrapEl} on:scroll={handleApplicabilityScroll}>
					<table class="applicability-table">
						<thead>
							<tr>
								<th>{$t('hr.servicesWindow.sn')}</th>
								<th>{$t('hr.servicesWindow.employeeId')}</th>
								<th>{$t('hr.servicesWindow.employeeName')}</th>
								<th>{$t('hr.servicesWindow.nationality')}</th>
								<th>{$t('hr.servicesWindow.sponsorshipStatus')}</th>
								<th>{$t('hr.servicesWindow.joiningDuration')}</th>
								<th>{$t('hr.servicesWindow.ticketRule')}</th>
								<th>{$t('hr.servicesWindow.qualifiedTickets')}</th>
								<th>{$t('hr.servicesWindow.annualLeaveRule')}</th>
								<th>{$t('hr.servicesWindow.qualifiedLeaveDays')}</th>
							</tr>
						</thead>
						<tbody>
							{#each applicabilityEmployees as employee, index}
								{@const assignment = getAssignmentForEmployee(employee.id)}
								{@const ticketRemaining = getTicketRemaining(employee.id, assignment?.qualified_ticket_count)}
								{@const leaveRemaining = getLeaveRemaining(employee.id, assignment?.qualified_leave_days)}
								<tr class:missing-join-date={hasMissingJoinDate(employee.join_date)}>
									<td class="mono-cell">{index + 1}</td>
									<td class="mono-cell">{employee.id}</td>
									<td class="td-name">
										<span class="name-en" dir={localizedDir()}>{localizedText(employee.name_en, employee.name_ar)}</span>
									</td>
									<td class="td-name">
										<span class="name-en" dir={localizedDir()}>{localizedText(employee.nationality_name_en, employee.nationality_name_ar)}</span>
									</td>
									<td>{employee.sponsorship_status === true ? $t('hr.servicesWindow.yes') : $t('hr.servicesWindow.no')}</td>
									<td>{formatJoiningDuration(employee.join_date)}</td>
									<td>
										<div class="toggle-cell">
											<div class="toggle-actions-inline">
												<button
													class="toggle-btn"
													class:enabled={assignment?.ticket_rule_enabled}
													on:click={() => openRuleScheduleModal(employee.id, 'ticket')}
												>
													{assignment?.ticket_rule_enabled ? $t('hr.servicesWindow.manageRules') : $t('hr.servicesWindow.enableRules')}
												</button>
												{#if assignment?.ticket_rule_enabled}
													<button class="btn-inline-disable" on:click={() => disableRuleForEmployee(employee.id, 'ticket')}>{$t('hr.servicesWindow.disable')}</button>
												{/if}
											</div>
											{#if assignment?.ticket_rule_enabled}
												<div class="applied-rule">
													<div dir={localizedDir()}>{localizedText(assignment?.ticket_rule_name_en, assignment?.ticket_rule_name_ar)}</div>
													<div class="rule-meta">{$t('hr.servicesWindow.periods')}: {assignment?.ticket_periods_count ?? 0}</div>
												</div>
											{/if}
										</div>
									</td>
									<td>
										{#if assignment?.ticket_rule_enabled}
											<div class="qualified-manage-cell">
												<div class="qualified-number">{ticketRemaining}</div>
												<div class="qualified-meta">{$t('hr.servicesWindow.qualified')}: {assignment?.qualified_ticket_count ?? 0} | {$t('hr.servicesWindow.issued')}: {ticketUsageByEmployee[employee.id] ?? 0}</div>
												{#if (assignment?.qualified_ticket_count ?? 0) > 0 || (ticketUsageByEmployee[employee.id] ?? 0) > 0}
													<button class="btn-manage-qualified" on:click={() => openTicketManageModal(employee.id)}>{$t('hr.servicesWindow.manage')}</button>
												{/if}
											</div>
										{:else}
											—
										{/if}
									</td>
									<td>
										<div class="toggle-cell">
											<div class="toggle-actions-inline">
												<button
													class="toggle-btn leave-toggle"
													class:enabled={assignment?.leave_salary_rule_enabled}
													on:click={() => openRuleScheduleModal(employee.id, 'leave_salary')}
												>
													{assignment?.leave_salary_rule_enabled ? $t('hr.servicesWindow.manageRules') : $t('hr.servicesWindow.enableRules')}
												</button>
												{#if assignment?.leave_salary_rule_enabled}
													<button class="btn-inline-disable" on:click={() => disableRuleForEmployee(employee.id, 'leave_salary')}>{$t('hr.servicesWindow.disable')}</button>
												{/if}
											</div>
											{#if assignment?.leave_salary_rule_enabled}
												<div class="applied-rule">
													<div dir={localizedDir()}>{localizedText(assignment?.leave_rule_name_en, assignment?.leave_rule_name_ar)}</div>
													<div class="rule-meta">{$t('hr.servicesWindow.periods')}: {assignment?.leave_periods_count ?? 0}</div>
												</div>
											{/if}
										</div>
									</td>
									<td>
										{#if assignment?.leave_salary_rule_enabled}
											{@const leaveRemaining = getLeaveRemaining(employee.id, assignment?.qualified_leave_days)}
											{@const leaveApproved = leaveUsageByEmployee[employee.id] ?? 0}
											{@const leavePaid = leavePaidByEmployee[employee.id] ?? 0}
											<div class="qualified-manage-cell">
												<div class="qualified-number">{leaveRemaining}</div>
												<div class="qualified-meta">
													{$t('hr.servicesWindow.qualified')}: {assignment?.qualified_leave_days ?? 0}
													&nbsp;|&nbsp;
													{$t('hr.servicesWindow.leaveApprovedCount')}: {leaveApproved}
													&nbsp;|&nbsp;
													{$t('hr.servicesWindow.leavePaidCount')}: {leavePaid}
												</div>
												<button class="btn-manage-qualified" on:click={() => openLeaveManageModal(employee.id)}>{$t('hr.servicesWindow.manage')}</button>
											</div>
										{:else}
											—
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
					{#if isLoadingMoreApplicability}
						<div class="applicability-loading-more">{$t('hr.servicesWindow.loadingMore')}</div>
					{:else if hasMoreApplicability}
						<div class="applicability-loading-more">{$t('hr.servicesWindow.scrollToLoadMore')}</div>
					{/if}
				</div>
			{/if}
		</div>

		{#if showRuleScheduleModal && scheduleRuleType}
			<div
				class="picker-backdrop"
				role="button"
				tabindex="0"
				aria-label={$t('hr.servicesWindow.close')}
				on:click={closeRuleScheduleModal}
				on:keydown={(event) => {
					if (event.key === 'Enter' || event.key === ' ' || event.key === 'Escape') {
						closeRuleScheduleModal();
					}
				}}
			>
				<div class="picker-modal" role="dialog" aria-modal="true" tabindex="-1" on:click|stopPropagation on:keydown|stopPropagation>
					<h4>{scheduleRuleType === 'ticket' ? $t('hr.servicesWindow.travelTicketRulePeriods') : $t('hr.servicesWindow.annualLeaveRulePeriods')}</h4>
					<div class="picker-list">
						{#if scheduleEmployee}
							<div class="picker-employee-meta">
								<div><strong>{$t('hr.servicesWindow.employee')}:</strong> <span dir={localizedDir()}>{localizedText(scheduleEmployee.name_en, scheduleEmployee.name_ar, scheduleEmployee.id)}</span></div>
								<div><strong>{$t('hr.servicesWindow.joiningDate')}:</strong> {scheduleEmployee.join_date || 'N/A'}</div>
							</div>
						{/if}
						{#each schedulePeriods as period, index}
							<div class="schedule-row">
								<div class="schedule-row-top">
									<div class="schedule-seq">{$t('hr.servicesWindow.ruleName')} #{index + 1}</div>
									{#if schedulePeriods.length > 1}
										<button class="btn-remove-period" on:click={() => removeSchedulePeriod(index)}>{$t('hr.servicesWindow.remove')}</button>
									{/if}
								</div>
								<div class="schedule-grid">
									<select
										class="filter-select"
										value={period.rule_id ?? ''}
										on:change={(event) => updateSchedulePeriod(index, { rule_id: Number((event.currentTarget as HTMLSelectElement).value) || null })}
									>
										<option value="">{$t('hr.servicesWindow.selectRule')}</option>
										{#each getRulesByType(scheduleRuleType) as rule}
											<option value={rule.id}>{localizedText(rule.rule_name_en, rule.rule_name_ar)}</option>
										{/each}
									</select>

									<label class="schedule-inline-field">
										<input
											type="checkbox"
											checked={period.is_infinite}
											on:change={(event) => updateSchedulePeriod(index, { is_infinite: (event.currentTarget as HTMLInputElement).checked })}
										/>
										<span>{$t('hr.servicesWindow.infinitePeriod')}</span>
									</label>

									<label class="schedule-number-field">
										<span>{$t('hr.servicesWindow.years')}</span>
										<input
											class="field-input field-number"
											type="number"
											min="0"
											disabled={period.is_infinite}
											value={period.duration_years}
											on:input={(event) => updateSchedulePeriod(index, { duration_years: Number((event.currentTarget as HTMLInputElement).value) || 0 })}
											aria-label="Duration years"
										/>
									</label>
									<label class="schedule-number-field">
										<span>{$t('hr.servicesWindow.months')}</span>
										<input
											class="field-input field-number"
											type="number"
											min="0"
											max="11"
											disabled={period.is_infinite}
											value={period.duration_months}
											on:input={(event) => updateSchedulePeriod(index, { duration_months: Number((event.currentTarget as HTMLInputElement).value) || 0 })}
											aria-label="Duration months"
										/>
									</label>
								</div>
								<div class="schedule-preview">
									{$t('hr.servicesWindow.from')}: {schedulePreviewRows[index]?.effective_from || '—'}
									{#if schedulePreviewRows[index]?.effective_to}
										| {$t('hr.servicesWindow.to')}: {schedulePreviewRows[index]?.effective_to}
									{:else}
										| {$t('hr.servicesWindow.to')}: {$t('hr.servicesWindow.infinitePeriod')}
									{/if}
								</div>
							</div>
						{/each}
						<button class="btn-add-period" on:click={addSchedulePeriod} disabled={schedulePeriods[schedulePeriods.length - 1]?.is_infinite}>
							{$t('hr.servicesWindow.addNextRulePeriod')}
						</button>
					</div>
					<div class="picker-footer">
						<button class="btn-cancel" on:click={closeRuleScheduleModal}>{$t('common.cancel')}</button>
						<button class="btn-save" disabled={isSavingApplicability} on:click={saveRuleSchedule}>
							{isSavingApplicability ? $t('common.saving') : $t('hr.servicesWindow.savePeriodRules')}
						</button>
					</div>
				</div>
			</div>
		{/if}

		{#if showTicketManageModal}
			<div class="picker-backdrop" role="button" tabindex="0" aria-label={$t('hr.servicesWindow.close')} on:click={closeTicketManageModal} on:keydown={(event) => {
				if (event.key === 'Enter' || event.key === ' ' || event.key === 'Escape') {
					closeTicketManageModal();
				}
			}}>
				<div class="picker-modal" role="dialog" aria-modal="true" tabindex="-1" on:click|stopPropagation on:keydown|stopPropagation>
					<h4>{$t('hr.servicesWindow.manageQualifiedTickets')}</h4>
					<div class="picker-list">
						<div class="picker-employee-meta">
							<div><strong>{$t('hr.servicesWindow.employee')}:</strong> <span dir={localizedDir()}>{localizedText(getManageEmployee(manageTicketEmployeeId)?.name_en, getManageEmployee(manageTicketEmployeeId)?.name_ar, getManageEmployee(manageTicketEmployeeId)?.id || 'N/A')}</span></div>
							<div><strong>{$t('hr.servicesWindow.remainingTickets')}:</strong> {manageTicketEmployeeId ? getTicketRemaining(manageTicketEmployeeId, getManageAssignment(manageTicketEmployeeId)?.qualified_ticket_count) : 0}</div>
						</div>

						<div class="schedule-row">
							<div class="schedule-seq">{$t('hr.servicesWindow.addTicketIssuance')}</div>
							<div class="manage-form-grid">
								<label class="field-group">
									<span class="field-label">{$t('hr.servicesWindow.numberOfTickets')}</span>
									<input class="field-input field-number" type="number" min="1" bind:value={ticketIssueCount} />
								</label>
								<label class="field-group">
									<span class="field-label">{$t('hr.servicesWindow.issueDate')}</span>
									<input class="field-input" type="date" bind:value={ticketIssueDate} />
								</label>
								<label class="field-group">
									<span class="field-label">{$t('hr.servicesWindow.ticketAmount')}</span>
									<input class="field-input field-number" type="number" min="0" step="0.01" bind:value={ticketIssueAmount} />
								</label>
								<label class="schedule-inline-field">
									<input type="checkbox" bind:checked={ticketIssuePaid} />
									<span>{$t('hr.servicesWindow.markedAsPaid')}</span>
								</label>
							</div>
							<button class="btn-save-inline" disabled={isSavingApplicability} on:click={saveTicketIssue}>{isSavingApplicability ? $t('common.saving') : $t('hr.servicesWindow.saveIssuance')}</button>
						</div>

						<div class="manage-list-card">
							<div class="schedule-seq">{$t('hr.servicesWindow.issuedTickets')}</div>
							{#if manageTicketRecords.length === 0}
								<div class="manage-empty">{$t('hr.servicesWindow.noTicketIssuanceRecords')}</div>
							{:else}
								<table class="manage-table">
									<thead>
										<tr>
											<th>{$t('hr.servicesWindow.date')}</th>
											<th>{$t('hr.servicesWindow.count')}</th>
											<th>{$t('hr.servicesWindow.amount')}</th>
											<th>{$t('hr.servicesWindow.payment')}</th>
										</tr>
									</thead>
									<tbody>
										{#each manageTicketRecords as rec}
											<tr>
												<td>{rec.issuance_date}</td>
												<td>{rec.ticket_count}</td>
												<td>{Number(rec.ticket_amount ?? 0).toFixed(2)}</td>
												<td><button class="btn-payment-toggle" on:click={() => toggleTicketPayment(rec)}>{rec.is_paid ? $t('hr.servicesWindow.paid') : $t('hr.servicesWindow.notPaid')}</button></td>
											</tr>
										{/each}
									</tbody>
								</table>
							{/if}
						</div>
					</div>
					<div class="picker-footer">
						<button class="btn-cancel" on:click={closeTicketManageModal}>{$t('hr.servicesWindow.close')}</button>
					</div>
				</div>
			</div>
		{/if}

		{#if showLeaveManageModal}
			{@const mgmtEmp = getManageEmployee(manageLeaveEmployeeId)}
			{@const mgmtAssign = getManageAssignment(manageLeaveEmployeeId)}
			{@const mgmtRemaining = manageLeaveEmployeeId ? getLeaveRemaining(manageLeaveEmployeeId, mgmtAssign?.qualified_leave_days) : 0}
			{@const mgmtApproved = leaveUsageByEmployee[manageLeaveEmployeeId ?? ''] ?? 0}
			{@const mgmtPaid = leavePaidByEmployee[manageLeaveEmployeeId ?? ''] ?? 0}
			<div class="picker-backdrop" role="button" tabindex="0" aria-label={$t('hr.servicesWindow.close')} on:click={closeLeaveManageModal} on:keydown={(event) => {
				if (event.key === 'Enter' || event.key === ' ' || event.key === 'Escape') closeLeaveManageModal();
			}}>
				<div class="picker-modal leave-manage-modal" role="dialog" aria-modal="true" tabindex="-1" on:click|stopPropagation on:keydown|stopPropagation>
					<div class="leave-modal-header">
						<div>
							<h4>{$t('hr.servicesWindow.manageQualifiedLeaveDays')}</h4>
							<div class="picker-employee-meta" style="margin-top:4px;">
								<span dir={localizedDir()} style="font-weight:600;">{localizedText(mgmtEmp?.name_en, mgmtEmp?.name_ar, mgmtEmp?.id ?? 'N/A')}</span>
								&nbsp;&mdash;&nbsp;{mgmtEmp?.id ?? ''}
							</div>
						</div>
						<div class="leave-balance-pills">
							<div class="balance-pill pill-qualified">
								<span class="pill-label">{$t('hr.servicesWindow.qualified')}</span>
								<span class="pill-value">{mgmtAssign?.qualified_leave_days ?? 0}</span>
							</div>
							<div class="balance-pill pill-approved">
								<span class="pill-label">{$t('hr.servicesWindow.leaveApprovedCount')}</span>
								<span class="pill-value">{mgmtApproved}</span>
							</div>
							<div class="balance-pill pill-paid">
								<span class="pill-label">{$t('hr.servicesWindow.leavePaidCount')}</span>
								<span class="pill-value">{mgmtPaid}</span>
							</div>
							<div class="balance-pill pill-remaining">
								<span class="pill-label">{$t('hr.servicesWindow.remainingLeaveDays')}</span>
								<span class="pill-value">{mgmtRemaining}</span>
							</div>
						</div>
					</div>

					<div class="picker-list">
						<!-- Manual entry form -->
						<div class="schedule-row">
							<div class="schedule-seq">{$t('hr.servicesWindow.addManualLeaveDate')}</div>

							<!-- Mode toggle -->
							<div class="leave-mode-toggle">
								<button
									class="mode-btn"
									class:active={leaveEntryMode === 'single'}
									on:click={() => { leaveEntryMode = 'single'; applicabilityError = ''; leaveConflictDates = []; }}
								>{$t('hr.servicesWindow.leaveModeSingle')}</button>
								<button
									class="mode-btn"
									class:active={leaveEntryMode === 'range'}
									on:click={() => { leaveEntryMode = 'range'; applicabilityError = ''; leaveConflictDates = []; }}
								>{$t('hr.servicesWindow.leaveModeRange')}</button>
							</div>

							<div class="manage-form-grid">
								{#if leaveEntryMode === 'single'}
									<label class="field-group">
										<span class="field-label">{$t('hr.servicesWindow.leaveDate')}</span>
										<input class="field-input" type="date" bind:value={leaveSingleDate} />
									</label>
								{:else}
									<label class="field-group">
										<span class="field-label">{$t('hr.servicesWindow.leaveDateFrom')}</span>
										<input class="field-input" type="date" bind:value={leaveRangeStart} />
									</label>
									<label class="field-group">
										<span class="field-label">{$t('hr.servicesWindow.leaveDateTo')}</span>
										<input class="field-input" type="date" bind:value={leaveRangeEnd} />
									</label>
									{#if leaveRangeStart && leaveRangeEnd && leaveRangeEnd >= leaveRangeStart}
										{@const rangeMs = new Date(leaveRangeEnd).getTime() - new Date(leaveRangeStart).getTime()}
										{@const rangeCount = Math.floor(rangeMs / 86400000) + 1}
										<div class="range-preview">
											{rangeCount} {$t('hr.servicesWindow.leaveDaysWillBeAdded')}
										</div>
									{/if}
								{/if}
								<label class="schedule-inline-field">
									<input type="checkbox" bind:checked={leaveDefaultPaid} />
									<span>{$t('hr.servicesWindow.markAsPaid')}</span>
								</label>
							</div>

							{#if applicabilityError}
								<div class="rules-error leave-conflict-error">
									{applicabilityError}
									{#if leaveConflictDates.length > 0}
										<ul class="conflict-date-list">
											{#each leaveConflictDates as cd}
												<li>{cd}</li>
											{/each}
										</ul>
									{/if}
								</div>
							{/if}

							<button class="btn-save-inline" disabled={leaveManageSaving} on:click={saveLeaveApprovalDays}>
								{leaveManageSaving ? $t('common.saving') : $t('hr.servicesWindow.addLeaveDate')}
							</button>
						</div>

						<!-- Leave records table -->
						<div class="manage-list-card">
							<div class="schedule-seq">{$t('hr.servicesWindow.approvedLeaveDates')}</div>
							{#if leaveManageLoading}
								<div class="manage-empty">{$t('hr.servicesWindow.loadingLeaveRecords')}</div>
							{:else if manageLeaveRecords.length === 0}
								<div class="manage-empty">{$t('hr.servicesWindow.noLeaveApprovalRecords')}</div>
							{:else}
								<table class="manage-table leave-table">
									<thead>
										<tr>
											<th>#</th>
											<th>{$t('hr.servicesWindow.date')}</th>
											<th>{$t('hr.servicesWindow.leaveSource')}</th>
											<th>{$t('hr.servicesWindow.leavePaidStatus')}</th>
										</tr>
									</thead>
									<tbody>
										{#each manageLeaveRecords as rec, idx}
											<tr class:paid-row={rec.is_paid}>
												<td class="mono-cell">{idx + 1}</td>
												<td class="mono-cell">{rec.day_off_date}</td>
												<td>
													{#if rec.is_manual_hr_entry}
														<span class="source-badge badge-manual">{$t('hr.servicesWindow.leaveSourceManual')}</span>
													{:else}
														<span class="source-badge badge-approved">{$t('hr.servicesWindow.leaveSourceApproved')}</span>
													{/if}
												</td>
												<td>
													<label class="paid-checkbox-label">
														<input
															type="checkbox"
															checked={rec.is_paid}
															disabled={leaveManageSaving}
															on:change={() => toggleLeavePayment(rec)}
														/>
														<span>{rec.is_paid ? $t('hr.servicesWindow.paid') : $t('hr.servicesWindow.notPaid')}</span>
													</label>
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							{/if}
						</div>
					</div>

					<div class="picker-footer">
						<button class="btn-cancel" on:click={closeLeaveManageModal}>{$t('hr.servicesWindow.close')}</button>
					</div>
				</div>
			</div>
		{/if}

	{:else if selected === 'travelTickets'}
		<div class="applicability-panel">
			<div class="applicability-header">
				<div>
					<div class="section-kicker">{$t('hr.servicesWindow.hrServices')}</div>
					<h3>{$t('hr.servicesWindow.travelTicketManagement')}</h3>
				</div>
				<button class="btn-apply-filter" on:click={loadIssuedTicketsTable} disabled={isLoadingTicketIssued}>{isLoadingTicketIssued ? $t('hr.servicesWindow.refreshing') : $t('hr.servicesWindow.refresh')}</button>
			</div>

			<div class="applicability-filters">
				<input class="filter-input" type="text" placeholder={$t('hr.servicesWindow.searchByEmployeePlaceholder')} bind:value={ticketIssuedSearch} />
				<select class="filter-select" bind:value={ticketIssuedPaymentFilter}>
					<option value="all">{$t('hr.servicesWindow.paymentAll')}</option>
					<option value="paid">{$t('hr.servicesWindow.paymentPaid')}</option>
					<option value="not_paid">{$t('hr.servicesWindow.paymentNotPaid')}</option>
				</select>
				<input class="filter-input" type="date" bind:value={ticketIssuedDateFrom} />
				<input class="filter-input" type="date" bind:value={ticketIssuedDateTo} />
				<div class="filter-actions">
					<button class="btn-clear-filter" on:click={resetTicketIssuedFilters}>{$t('hr.servicesWindow.reset')}</button>
				</div>
			</div>

			{#if rulesError}
				<div class="rules-error">{rulesError}</div>
			{/if}

			{#if isLoadingTicketIssued}
				<div class="applicability-empty">{$t('hr.servicesWindow.loadingIssuedTickets')}</div>
			{:else if ticketIssuedTableRows.length === 0}
				<div class="applicability-empty">{$t('hr.servicesWindow.noIssuedTickets')}</div>
			{:else if filteredTicketIssuedRows.length === 0}
				<div class="applicability-empty">{$t('hr.servicesWindow.noIssuedTicketsMatchFilters')}</div>
			{:else}
				<div class="issued-table-wrap">
					<table class="issued-table">
						<thead>
							<tr>
								<th>{$t('hr.servicesWindow.sn')}</th>
								<th>{$t('hr.servicesWindow.employeeId')}</th>
								<th>{$t('hr.servicesWindow.employeeName')}</th>
								<th>{$t('hr.servicesWindow.issueDate')}</th>
								<th>{$t('hr.servicesWindow.tickets')}</th>
								<th>{$t('hr.servicesWindow.amount')}</th>
								<th>{$t('hr.servicesWindow.payment')}</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredTicketIssuedRows as row, index}
								<tr>
									<td class="mono-cell">{index + 1}</td>
									<td class="mono-cell">{row.employee_id}</td>
									<td class="td-name">
										<span class="name-en" dir={localizedDir()}>{localizedText(row.employee_name_en, row.employee_name_ar)}</span>
									</td>
									<td>{row.issuance_date}</td>
									<td>{row.ticket_count}</td>
									<td>{Number(row.ticket_amount ?? 0).toFixed(2)}</td>
									<td>{row.is_paid ? $t('hr.servicesWindow.paid') : $t('hr.servicesWindow.notPaid')}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>

	{:else if selected === 'leaveSalary'}
		<div class="applicability-panel">
			<div class="applicability-header">
				<div>
					<div class="section-kicker">{$t('hr.servicesWindow.hrServices')}</div>
					<h3>{$t('hr.servicesWindow.annualLeaveManagement')}</h3>
				</div>
				<button class="btn-apply-filter" on:click={loadIssuedLeaveTable} disabled={isLoadingLeaveIssued}>{isLoadingLeaveIssued ? $t('hr.servicesWindow.refreshing') : $t('hr.servicesWindow.refresh')}</button>
			</div>

			<div class="applicability-filters">
				<input class="filter-input" type="text" placeholder={$t('hr.servicesWindow.searchByEmployeePlaceholder')} bind:value={leaveIssuedSearch} />
				<select class="filter-select" bind:value={leaveIssuedPaymentFilter}>
					<option value="all">{$t('hr.servicesWindow.paymentAll')}</option>
					<option value="paid">{$t('hr.servicesWindow.paymentPaid')}</option>
					<option value="not_paid">{$t('hr.servicesWindow.paymentNotPaid')}</option>
				</select>
				<input class="filter-input" type="date" bind:value={leaveIssuedDateFrom} />
				<input class="filter-input" type="date" bind:value={leaveIssuedDateTo} />
				<div class="filter-actions">
					<button class="btn-clear-filter" on:click={resetLeaveIssuedFilters}>{$t('hr.servicesWindow.reset')}</button>
				</div>
			</div>

			{#if rulesError}
				<div class="rules-error">{rulesError}</div>
			{/if}

			{#if isLoadingLeaveIssued}
				<div class="applicability-empty">{$t('hr.servicesWindow.loadingApprovedLeaveDays')}</div>
			{:else if leaveIssuedTableRows.length === 0}
				<div class="applicability-empty">{$t('hr.servicesWindow.noApprovedLeaveDays')}</div>
			{:else if filteredLeaveIssuedRows.length === 0}
				<div class="applicability-empty">{$t('hr.servicesWindow.noApprovedLeaveMatchFilters')}</div>
			{:else}
				<div class="issued-table-wrap">
					<table class="issued-table">
						<thead>
							<tr>
								<th>{$t('hr.servicesWindow.sn')}</th>
								<th>{$t('hr.servicesWindow.employeeId')}</th>
								<th>{$t('hr.servicesWindow.employeeName')}</th>
								<th>{$t('hr.servicesWindow.leaveDate')}</th>
								<th>{$t('hr.servicesWindow.payment')}</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredLeaveIssuedRows as row, index}
								<tr>
									<td class="mono-cell">{index + 1}</td>
									<td class="mono-cell">{row.employee_id}</td>
									<td class="td-name">
										<span class="name-en" dir={localizedDir()}>{localizedText(row.employee_name_en, row.employee_name_ar)}</span>
									</td>
									<td>{row.leave_date}</td>
									<td>{row.is_paid ? $t('hr.servicesWindow.paid') : $t('hr.servicesWindow.notPaid')}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>

	{:else if selected === 'esob'}
		<div class="applicability-panel">
			<HRServicesEsob />
		</div>

	{:else if selected}
		{@const svc = services.find(s => s.key === selected)}
		<div class="content-area" style="--accent:{svc?.accent};--bg:{svc?.bg};--glow:{svc?.glow}">
			<div class="content-inner">
				<div class="content-icon">{svc?.icon}</div>
				<h2 class="content-title">{svc ? $t(svc.labelKey) : ''}</h2>
				<p class="coming-soon">{$t('common.comingSoon')}</p>
				<div class="coming-soon-decoration">
					<span class="dot"></span>
					<span class="dot"></span>
					<span class="dot"></span>
				</div>
			</div>
		</div>
	{:else}
		<div class="empty-state">
			<div class="empty-icon">🛠️</div>
			<p class="empty-text">{$t('hr.selectServicePrompt')}</p>
		</div>
	{/if}
</div>

<style>
	.services-window {
		display: flex;
		height: 100%;
		flex-direction: column;
		background: linear-gradient(145deg, #f8faff 0%, #f0f4ff 50%, #fdf4ff 100%);
		font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
		overflow: hidden;
	}

	/* ── Grid ── */
	.services-grid {
		display: grid;
		grid-template-columns: repeat(5, 1fr);
		gap: 16px;
		padding: 24px 28px 18px;
		flex-shrink: 0;
	}
	@media (max-width: 780px) {
		.services-grid {
			grid-template-columns: repeat(3, 1fr);
		}
	}
	@media (max-width: 500px) {
		.services-grid {
			grid-template-columns: repeat(2, 1fr);
		}
	}

	/* ── Card ── */
	.service-card {
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 10px;
		padding: 22px 16px 18px;
		border-radius: 18px;
		border: 1.5px solid rgba(148,163,184,0.18);
		background: rgba(255,255,255,0.7);
		backdrop-filter: blur(12px);
		cursor: pointer;
		transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease, background 0.18s ease;
		box-shadow: 0 2px 10px rgba(0,0,0,0.05);
		overflow: hidden;
	}
	.service-card::before {
		content: '';
		position: absolute;
		inset: 0;
		border-radius: inherit;
		background: var(--bg);
		opacity: 0;
		transition: opacity 0.18s ease;
	}
	.service-card:hover {
		transform: translateY(-3px);
		box-shadow: 0 8px 24px var(--glow), 0 2px 6px rgba(0,0,0,0.06);
		border-color: var(--accent);
	}
	.service-card:hover::before {
		opacity: 1;
	}
	.service-card:active {
		transform: translateY(-1px);
		box-shadow: 0 4px 14px var(--glow);
	}
	.service-card.active {
		border-color: var(--accent);
		background: var(--bg);
		box-shadow: 0 0 0 3px var(--glow), 0 6px 20px rgba(0,0,0,0.07);
		transform: translateY(-2px);
	}
	.service-card.active::before {
		opacity: 1;
	}
	.card-icon {
		position: relative;
		font-size: 2rem;
		line-height: 1;
		filter: drop-shadow(0 2px 4px rgba(0,0,0,0.12));
		transition: transform 0.18s ease;
	}
	.service-card:hover .card-icon,
	.service-card.active .card-icon {
		transform: scale(1.12);
	}
	.card-label {
		position: relative;
		font-size: 0.82rem;
		font-weight: 600;
		color: #1e293b;
		text-align: center;
		line-height: 1.3;
		transition: color 0.18s ease;
	}
	.service-card.active .card-label {
		color: var(--accent);
	}
	.card-indicator {
		position: absolute;
		bottom: 0;
		left: 50%;
		transform: translateX(-50%) scaleX(0);
		width: 40px;
		height: 3px;
		border-radius: 3px 3px 0 0;
		background: var(--accent);
		transition: transform 0.2s ease;
	}
	.service-card.active .card-indicator {
		transform: translateX(-50%) scaleX(1);
	}

	/* ── Settlement Rules Panel ── */
	.settlement-panel {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 14px;
		margin: 0 28px 24px;
		padding: 16px;
		border-radius: 20px;
		border: 1.5px solid rgba(249,115,22,0.2);
		background: rgba(255,255,255,0.75);
		backdrop-filter: blur(16px);
		box-shadow: 0 4px 24px rgba(249,115,22,0.08), 0 0 0 2px rgba(249,115,22,0.1);
		overflow: auto;
	}
	.rules-error {
		padding: 10px 12px;
		border-radius: 12px;
		background: rgba(254, 226, 226, 0.85);
		border: 1px solid rgba(239, 68, 68, 0.2);
		color: #b91c1c;
		font-size: 0.85rem;
	}
	.rule-form-card {
		padding: 14px;
		border-radius: 18px;
		background: rgba(248,250,255,0.96);
		border: 1px solid rgba(148,163,184,0.18);
		box-shadow: 0 10px 24px rgba(15,23,42,0.04);
		animation: slideDown 0.18s ease;
	}
	.rule-form-card.ticket-form { border-left: 4px solid #22c55e; }
	.rule-form-card.leave-form { border-left: 4px solid #a78bfa; }
	.rule-form-header {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		gap: 12px;
		margin-bottom: 12px;
	}
	.rule-form-kicker {
		font-size: 0.72rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: #f97316;
		margin-bottom: 4px;
	}
	.rule-form-header h3 {
		margin: 0;
		font-size: 1rem;
		color: #1e293b;
	}
	.btn-close-form {
		border: none;
		background: rgba(255,255,255,0.8);
		color: #64748b;
		width: 32px;
		height: 32px;
		border-radius: 10px;
		cursor: pointer;
	}
	.form-fields {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: 12px;
	}
	.field-group { display: flex; flex-direction: column; gap: 4px; }
	.field-label {
		font-size: 0.72rem;
		font-weight: 700;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}
	.field-input {
		padding: 8px 12px;
		border-radius: 10px;
		border: 1.5px solid rgba(148,163,184,0.3);
		background: rgba(255,255,255,0.95);
		font-size: 0.88rem;
		color: #1e293b;
		outline: none;
		width: 100%;
		box-sizing: border-box;
		transition: border-color 0.15s ease, box-shadow 0.15s ease;
	}
	.field-input:focus {
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249,115,22,0.12);
	}
	.form-footer {
		display: flex;
		justify-content: flex-end;
		gap: 10px;
		margin-top: 12px;
	}
	.btn-cancel {
		padding: 8px 18px;
		border-radius: 10px;
		border: 1.5px solid rgba(148,163,184,0.3);
		background: rgba(255,255,255,0.8);
		font-size: 0.85rem;
		font-weight: 600;
		color: #64748b;
		cursor: pointer;
	}
	.btn-save {
		padding: 8px 22px;
		border-radius: 10px;
		border: none;
		background: linear-gradient(135deg, #f97316, #fb923c);
		color: #fff;
		font-size: 0.85rem;
		font-weight: 700;
		cursor: pointer;
		box-shadow: 0 3px 10px rgba(249,115,22,0.3);
	}
	.btn-save:disabled {
		opacity: 0.7;
		cursor: not-allowed;
	}
	.settlement-sections {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: 14px;
	}
	.settlement-section {
		padding: 14px;
		border-radius: 18px;
		background: rgba(255,255,255,0.8);
		border: 1px solid rgba(148,163,184,0.15);
		overflow: hidden;
	}
	.ticket-section { box-shadow: 0 8px 24px rgba(34,197,94,0.06); }
	.leave-section { box-shadow: 0 8px 24px rgba(167,139,250,0.06); }
	.section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		margin-bottom: 12px;
	}
	.section-kicker {
		font-size: 0.72rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: #94a3b8;
		margin-bottom: 4px;
	}
	.section-header h3 {
		margin: 0;
		font-size: 1rem;
		color: #1e293b;
	}
	.section-add-btn {
		border: none;
		border-radius: 999px;
		padding: 9px 14px;
		font-size: 0.82rem;
		font-weight: 700;
		cursor: pointer;
		color: #fff;
		box-shadow: 0 6px 14px rgba(0,0,0,0.08);
	}
	.section-add-btn.ticket { background: linear-gradient(135deg, #22c55e, #16a34a); }
	.section-add-btn.leave { background: linear-gradient(135deg, #a78bfa, #8b5cf6); }
	.settlement-empty {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 140px;
		padding: 20px;
		border-radius: 14px;
		border: 1px dashed rgba(148,163,184,0.25);
		color: #94a3b8;
		font-size: 0.88rem;
		background: rgba(248,250,252,0.8);
	}
	.settlement-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.84rem;
	}
	.settlement-table thead {
		position: sticky;
		top: 0;
		background: rgba(255,255,255,0.96);
		backdrop-filter: blur(8px);
		z-index: 1;
	}
	.settlement-table th {
		padding: 9px 12px;
		text-align: left;
		font-size: 0.72rem;
		font-weight: 700;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		border-bottom: 1px solid rgba(148,163,184,0.16);
	}
	.settlement-table td {
		padding: 10px 12px;
		border-bottom: 1px solid rgba(148,163,184,0.1);
		vertical-align: middle;
		color: #1e293b;
	}
	.settlement-table tr:hover td { background: rgba(249,115,22,0.03); }
	.table-actions { text-align: right; width: 48px; }
	.name-en { font-weight: 700; color: #1e293b; }
	.btn-delete {
		background: none;
		border: none;
		cursor: pointer;
		font-size: 1rem;
		opacity: 0.45;
		padding: 4px 6px;
		border-radius: 6px;
	}
	.btn-delete:hover { opacity: 1; background: rgba(239,68,68,0.08); }

	/* ── Applicability Management ── */
	.applicability-panel {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 12px;
		margin: 0 28px 24px;
		padding: 16px;
		border-radius: 20px;
		border: 1.5px solid rgba(14,165,233,0.2);
		background: rgba(255,255,255,0.75);
		backdrop-filter: blur(16px);
		box-shadow: 0 4px 24px rgba(14,165,233,0.08), 0 0 0 2px rgba(14,165,233,0.08);
		overflow: auto;
	}
	.applicability-header h3 {
		margin: 0;
		font-size: 1.05rem;
		color: #1e293b;
	}
	.applicability-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
	}
	.result-count {
		padding: 6px 10px;
		border-radius: 999px;
		border: 1px solid rgba(14,165,233,0.25);
		background: rgba(14,165,233,0.08);
		font-size: 0.74rem;
		font-weight: 700;
		color: #0369a1;
	}
	.applicability-filters {
		display: grid;
		grid-template-columns: minmax(240px, 2fr) repeat(3, minmax(150px, 1fr)) auto;
		gap: 10px;
	}
	.filter-input,
	.filter-select {
		padding: 8px 10px;
		border-radius: 10px;
		border: 1.5px solid rgba(148,163,184,0.28);
		background: rgba(255,255,255,0.95);
		font-size: 0.82rem;
		color: #1e293b;
		outline: none;
	}
	.filter-input:focus,
	.filter-select:focus {
		border-color: #0ea5e9;
		box-shadow: 0 0 0 3px rgba(14,165,233,0.12);
	}
	.filter-actions {
		display: flex;
		gap: 8px;
	}
	.btn-apply-filter,
	.btn-clear-filter {
		padding: 8px 12px;
		border-radius: 10px;
		font-size: 0.78rem;
		font-weight: 700;
		cursor: pointer;
	}
	.btn-apply-filter {
		border: none;
		background: linear-gradient(135deg, #0ea5e9, #38bdf8);
		color: #fff;
	}
	.btn-clear-filter {
		border: 1.5px solid rgba(148,163,184,0.32);
		background: rgba(248,250,252,0.85);
		color: #475569;
	}
	.applicability-empty {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 180px;
		padding: 20px;
		border-radius: 14px;
		border: 1px dashed rgba(148,163,184,0.25);
		color: #94a3b8;
		font-size: 0.9rem;
		background: rgba(248,250,252,0.8);
	}
	.applicability-table-wrap {
		overflow: auto;
		border-radius: 14px;
		border: 1px solid rgba(148,163,184,0.14);
		background: rgba(255,255,255,0.9);
	}
	.applicability-table {
		width: 100%;
		min-width: 1360px;
		border-collapse: collapse;
		font-size: 0.84rem;
	}
	.applicability-loading-more {
		padding: 10px 12px;
		text-align: center;
		font-size: 0.78rem;
		color: #64748b;
		border-top: 1px solid rgba(148,163,184,0.12);
		background: rgba(248,250,252,0.65);
	}
	.applicability-table th {
		position: sticky;
		top: 0;
		background: rgba(254,226,226,0.92);
		padding: 10px 12px;
		text-align: left;
		font-size: 0.72rem;
		font-weight: 700;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		border-bottom: 1px solid rgba(148,163,184,0.18);
		border-right: 1px solid rgba(148,163,184,0.28);
		z-index: 1;
	}
	.applicability-table th:last-child {
		border-right: none;
	}
	.applicability-table td {
		padding: 11px 12px;
		border-bottom: 1px solid rgba(148,163,184,0.1);
		border-right: 1px solid rgba(148,163,184,0.22);
		vertical-align: middle;
		color: #1e293b;
	}
	.applicability-table td:last-child {
		border-right: none;
	}
	.applicability-table tbody tr:nth-child(odd) td {
		background: rgba(255,237,213,0.52);
	}
	.applicability-table tbody tr:nth-child(even) td {
		background: rgba(243,232,255,0.52);
	}
	.applicability-table tr:hover td {
		background: rgba(219,234,254,0.72) !important;
	}
	.applicability-table tr.missing-join-date td {
		background: #b91c1c !important;
		color: #ffffff !important;
	}
	.applicability-table tr.missing-join-date:hover td {
		background: #991b1b !important;
		color: #ffffff !important;
	}
	.applicability-table tr.missing-join-date td .name-en,
	.applicability-table tr.missing-join-date td .rule-meta,
	.applicability-table tr.missing-join-date td .qualified-meta,
	.applicability-table tr.missing-join-date td .qualified-number {
		color: #ffffff !important;
	}
	.applicability-table-wrap::-webkit-scrollbar {
		height: 10px;
		width: 10px;
	}
	.applicability-table-wrap::-webkit-scrollbar-thumb {
		background: rgba(147,197,253,0.8);
		border-radius: 999px;
	}
	.applicability-table-wrap::-webkit-scrollbar-track {
		background: rgba(226,232,240,0.55);
	}
	.mono-cell {
		font-family: 'Consolas', 'Courier New', monospace;
		font-size: 0.78rem;
		color: #334155;
	}
	.toggle-cell {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.toggle-actions-inline {
		display: flex;
		align-items: center;
		gap: 8px;
		flex-wrap: wrap;
	}
	.toggle-btn {
		align-self: flex-start;
		padding: 6px 10px;
		border-radius: 999px;
		border: 1px solid rgba(148,163,184,0.3);
		background: rgba(241,245,249,0.8);
		font-size: 0.74rem;
		font-weight: 700;
		color: #64748b;
		cursor: pointer;
	}
	.toggle-btn.enabled {
		background: rgba(34,197,94,0.16);
		border-color: rgba(34,197,94,0.45);
		color: #15803d;
	}
	.btn-inline-disable {
		align-self: flex-start;
		padding: 4px 10px;
		border-radius: 999px;
		border: 1px solid rgba(239,68,68,0.28);
		background: rgba(254,226,226,0.55);
		color: #b91c1c;
		font-size: 0.7rem;
		font-weight: 700;
		cursor: pointer;
	}
	.leave-toggle.enabled {
		background: rgba(167,139,250,0.16);
		border-color: rgba(167,139,250,0.45);
		color: #6d28d9;
	}
	.applied-rule {
		font-size: 0.75rem;
		line-height: 1.3;
		color: #334155;
	}
	.rule-meta {
		font-size: 0.68rem;
		color: #64748b;
	}
	.qualified-manage-cell {
		display: grid;
		gap: 4px;
	}
	.qualified-number {
		font-weight: 800;
		color: #0f172a;
		font-size: 0.9rem;
	}
	.qualified-meta {
		font-size: 0.68rem;
		color: #64748b;
	}
	.btn-manage-qualified {
		justify-self: flex-start;
		padding: 4px 10px;
		border-radius: 999px;
		border: 1px solid rgba(14, 165, 233, 0.3);
		background: rgba(224, 242, 254, 0.8);
		color: #0369a1;
		font-size: 0.7rem;
		font-weight: 700;
		cursor: pointer;
	}

	@media (max-width: 1200px) {
		.applicability-filters {
			grid-template-columns: repeat(2, minmax(180px, 1fr));
		}
		.filter-actions {
			grid-column: 1 / -1;
		}
	}

	/* Rule picker modal */
	.picker-backdrop {
		position: fixed;
		inset: 0;
		background: rgba(15,23,42,0.45);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 50;
		padding: 16px;
	}
	.picker-modal {
		width: min(860px, calc(100vw - 32px));
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		background: rgba(255,255,255,0.96);
		border: 1px solid rgba(148,163,184,0.2);
		border-radius: 18px;
		box-shadow: 0 24px 40px rgba(15,23,42,0.25);
		overflow: hidden;
	}
	/* Wider leave manage modal */
	.leave-manage-modal {
		width: min(1100px, calc(100vw - 32px));
	}
	/* Leave modal header: title + balance pills */
	.leave-modal-header {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		gap: 12px;
		padding: 14px 18px;
		border-bottom: 1px solid rgba(148,163,184,0.14);
		flex-wrap: wrap;
	}
	.leave-modal-header h4 { margin: 0; font-size: 1rem; }
	.leave-balance-pills {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}
	.balance-pill {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 6px 14px;
		border-radius: 12px;
		min-width: 72px;
		font-size: 0.7rem;
	}
	.balance-pill .pill-label { opacity: 0.7; font-weight: 500; }
	.balance-pill .pill-value { font-size: 1.15rem; font-weight: 700; line-height: 1.2; }
	.pill-qualified  { background: rgba(14,165,233,0.12);  color: #0369a1; }
	.pill-approved   { background: rgba(168,85,247,0.12);  color: #7e22ce; }
	.pill-paid       { background: rgba(34,197,94,0.12);   color: #15803d; }
	.pill-remaining  { background: rgba(234,179,8,0.14);   color: #92400e; }
	/* Leave table */
	.leave-table th, .leave-table td { padding: 8px 12px; }
	.paid-row { background: rgba(34,197,94,0.06); }
	.source-badge {
		display: inline-block;
		padding: 2px 8px;
		border-radius: 999px;
		font-size: 0.7rem;
		font-weight: 600;
	}
	.badge-approved { background: rgba(14,165,233,0.14); color: #0369a1; }
	.badge-manual   { background: rgba(234,179,8,0.16);  color: #92400e; }
	.paid-checkbox-label {
		display: flex;
		align-items: center;
		gap: 6px;
		cursor: pointer;
		font-size: 0.82rem;
	}
	.paid-checkbox-label input { cursor: pointer; width: 15px; height: 15px; }
	/* Mode toggle */
	.leave-mode-toggle {
		display: flex;
		gap: 0;
		margin-bottom: 10px;
		border: 1px solid rgba(148,163,184,0.2);
		border-radius: 8px;
		overflow: hidden;
		width: fit-content;
	}
	.mode-btn {
		padding: 5px 16px;
		font-size: 0.8rem;
		font-weight: 500;
		background: transparent;
		border: none;
		color: #94a3b8;
		cursor: pointer;
		transition: background 0.15s, color 0.15s;
	}
	.mode-btn.active {
		background: rgba(14,165,233,0.15);
		color: #0ea5e9;
		font-weight: 600;
	}
	/* Range preview */
	.range-preview {
		font-size: 0.78rem;
		color: #0ea5e9;
		background: rgba(14,165,233,0.08);
		padding: 4px 10px;
		border-radius: 6px;
		align-self: center;
	}
	/* Conflict error */
	.leave-conflict-error {
		margin: 8px 0 4px;
		font-size: 0.82rem;
	}
	.conflict-date-list {
		margin: 6px 0 0 16px;
		padding: 0;
		font-family: monospace;
		font-size: 0.8rem;
		list-style: disc;
	}
	.picker-modal h4 {
		margin: 0;
		padding: 14px 16px;
		font-size: 1rem;
		border-bottom: 1px solid rgba(148,163,184,0.14);
	}
	.picker-list {
		overflow: auto;
		padding: 10px 12px;
		display: grid;
		gap: 8px;
	}
	.picker-employee-meta {
		padding: 8px 10px;
		border-radius: 10px;
		border: 1px dashed rgba(14,165,233,0.35);
		background: rgba(14,165,233,0.06);
		font-size: 0.78rem;
		color: #0f172a;
		display: grid;
		gap: 3px;
	}
	.schedule-row {
		padding: 10px;
		border: 1px solid rgba(148,163,184,0.2);
		border-radius: 12px;
		background: rgba(248,250,252,0.8);
		display: grid;
		gap: 8px;
	}
	.schedule-row-top {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}
	.schedule-seq {
		font-size: 0.75rem;
		font-weight: 700;
		color: #334155;
	}
	.btn-remove-period {
		border: none;
		background: rgba(239,68,68,0.1);
		color: #b91c1c;
		font-size: 0.72rem;
		font-weight: 700;
		padding: 5px 10px;
		border-radius: 8px;
		cursor: pointer;
	}
	.schedule-grid {
		display: grid;
		grid-template-columns: minmax(0, 1fr) auto 90px 90px;
		gap: 8px;
		align-items: center;
	}
	.schedule-inline-field {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 0.74rem;
		color: #334155;
		white-space: normal;
		line-height: 1.2;
		padding: 0 2px;
	}
	.schedule-inline-field span {
		word-break: break-word;
	}
	.schedule-number-field {
		display: grid;
		gap: 4px;
		font-size: 0.68rem;
		font-weight: 700;
		color: #475569;
		text-transform: uppercase;
		letter-spacing: 0.03em;
	}
	.schedule-number-field .field-input {
		padding: 7px 10px;
	}
	.schedule-grid :global(select),
	.schedule-grid :global(input) {
		min-width: 0;
	}
	.schedule-preview {
		font-size: 0.74rem;
		color: #475569;
	}
	.manage-form-grid {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: 8px;
		align-items: end;
	}
	.btn-save-inline {
		margin-top: 8px;
		align-self: flex-start;
		padding: 7px 12px;
		border-radius: 10px;
		border: 1px solid rgba(14,165,233,0.35);
		background: rgba(14,165,233,0.12);
		color: #075985;
		font-size: 0.76rem;
		font-weight: 700;
		cursor: pointer;
	}
	.btn-save-inline:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
	.manage-list-card {
		padding: 10px;
		border-radius: 12px;
		border: 1px solid rgba(148,163,184,0.16);
		background: rgba(255,255,255,0.88);
		display: grid;
		gap: 8px;
	}
	.manage-empty {
		font-size: 0.76rem;
		color: #64748b;
	}
	.manage-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.76rem;
	}
	.manage-table th,
	.manage-table td {
		padding: 7px 8px;
		border-bottom: 1px solid rgba(148,163,184,0.16);
		text-align: left;
	}
	.manage-table th {
		font-size: 0.66rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: #64748b;
	}
	.btn-payment-toggle {
		padding: 4px 10px;
		border-radius: 999px;
		border: 1px solid rgba(100,116,139,0.3);
		background: rgba(241,245,249,0.8);
		color: #334155;
		font-size: 0.68rem;
		font-weight: 700;
		cursor: pointer;
	}
	.issued-table-wrap {
		overflow: auto;
		border-radius: 14px;
		border: 1px solid rgba(148,163,184,0.14);
		background: rgba(255,255,255,0.9);
	}
	.issued-table {
		width: 100%;
		min-width: 980px;
		border-collapse: collapse;
		font-size: 0.84rem;
	}
	.issued-table th {
		position: sticky;
		top: 0;
		background: rgba(224, 242, 254, 0.92);
		padding: 10px 12px;
		text-align: left;
		font-size: 0.72rem;
		font-weight: 700;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		border-bottom: 1px solid rgba(148,163,184,0.18);
		border-right: 1px solid rgba(148,163,184,0.28);
		z-index: 1;
	}
	.issued-table th:last-child,
	.issued-table td:last-child {
		border-right: none;
	}
	.issued-table td {
		padding: 11px 12px;
		border-bottom: 1px solid rgba(148,163,184,0.1);
		border-right: 1px solid rgba(148,163,184,0.22);
		vertical-align: middle;
		color: #1e293b;
	}
	.issued-table tbody tr:nth-child(odd) td {
		background: rgba(240,249,255,0.55);
	}
	.issued-table tbody tr:nth-child(even) td {
		background: rgba(236,253,245,0.5);
	}
	.issued-table tr:hover td {
		background: rgba(219,234,254,0.75) !important;
	}
	.btn-add-period {
		justify-self: flex-start;
		padding: 7px 12px;
		border-radius: 10px;
		border: 1px solid rgba(14,165,233,0.35);
		background: rgba(224,242,254,0.75);
		color: #0369a1;
		font-size: 0.76rem;
		font-weight: 700;
		cursor: pointer;
	}
	.btn-add-period:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
	.picker-footer {
		display: flex;
		justify-content: flex-end;
		gap: 10px;
		padding: 12px 16px;
		border-top: 1px solid rgba(148,163,184,0.14);
	}

	@media (max-width: 900px) {
		.picker-modal {
			width: calc(100vw - 20px);
			max-height: 86vh;
		}
		.manage-form-grid {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
		.schedule-grid {
			grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
		}
		.schedule-grid .field-input.field-number {
			width: 100%;
		}
	}

	@media (max-width: 620px) {
		.manage-form-grid {
			grid-template-columns: 1fr;
		}
		.schedule-grid {
			grid-template-columns: 1fr;
		}
		.picker-footer {
			justify-content: stretch;
		}
		.picker-footer .btn-cancel,
		.picker-footer .btn-save {
			flex: 1;
		}
	}

	/* ── Content Area ── */
	.content-area {
		flex: 1;
		margin: 0 28px 24px;
		border-radius: 20px;
		border: 1.5px solid rgba(148,163,184,0.18);
		background: rgba(255,255,255,0.68);
		backdrop-filter: blur(16px);
		box-shadow: 0 4px 24px rgba(0,0,0,0.06), 0 0 0 2px var(--glow);
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
		position: relative;
		transition: box-shadow 0.3s ease;
	}
	.content-area::before {
		content: '';
		position: absolute;
		inset: 0;
		background: var(--bg);
		border-radius: inherit;
		pointer-events: none;
	}
	.content-inner {
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
		padding: 32px;
		text-align: center;
	}
	.content-icon {
		font-size: 3.5rem;
		line-height: 1;
		filter: drop-shadow(0 4px 8px rgba(0,0,0,0.12));
	}
	.content-title {
		margin: 0;
		font-size: 1.4rem;
		font-weight: 700;
		color: #1e293b;
	}
	.coming-soon {
		margin: 0;
		font-size: 1rem;
		font-weight: 500;
		color: var(--accent);
		letter-spacing: 0.5px;
		padding: 6px 18px;
		border-radius: 30px;
		background: var(--bg);
		border: 1.5px solid var(--glow);
	}
	.coming-soon-decoration {
		display: flex;
		gap: 8px;
		margin-top: 4px;
	}
	.dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: var(--accent);
		opacity: 0.35;
		animation: pulse-dot 1.4s ease-in-out infinite;
	}
	.dot:nth-child(2) { animation-delay: 0.2s; }
	.dot:nth-child(3) { animation-delay: 0.4s; }
	@keyframes pulse-dot {
		0%, 100% { opacity: 0.25; transform: scale(0.9); }
		50%        { opacity: 0.8;  transform: scale(1.15); }
	}

	/* ── Empty State ── */
	.empty-state {
		flex: 1;
		margin: 0 28px 24px;
		border-radius: 20px;
		border: 1.5px dashed rgba(148,163,184,0.3);
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 14px;
		background: rgba(255,255,255,0.4);
	}
	.empty-icon {
		font-size: 3rem;
		opacity: 0.3;
	}
	.empty-text {
		margin: 0;
		font-size: 0.9rem;
		color: #94a3b8;
		font-weight: 500;
	}
</style>
