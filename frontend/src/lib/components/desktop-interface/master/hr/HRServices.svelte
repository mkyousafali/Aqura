<script lang="ts">
	import { _ as t } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	type ServiceKey = 'settlementRules' | 'travelTickets' | 'leaveSalary' | 'esob' | 'qualificationManagement';

	interface Service {
		key: ServiceKey;
		label: string;
		icon: string;
		accent: string;
		bg: string;
		glow: string;
	}

	const services: Service[] = [
		{
			key: 'settlementRules',
			label: 'Settlement Rules',
			icon: '📋',
			accent: '#f97316',
			bg: 'rgba(249,115,22,0.08)',
			glow: 'rgba(249,115,22,0.25)'
		},
		{
			key: 'travelTickets',
			label: 'Travel Ticket Management',
			icon: '✈️',
			accent: '#22c55e',
			bg: 'rgba(34,197,94,0.08)',
			glow: 'rgba(34,197,94,0.25)'
		},
		{
			key: 'leaveSalary',
			label: 'Annual Leave Management',
			icon: '💰',
			accent: '#a78bfa',
			bg: 'rgba(167,139,250,0.08)',
			glow: 'rgba(167,139,250,0.25)'
		},
		{
			key: 'esob',
			label: 'ESOB',
			icon: '🏅',
			accent: '#f472b6',
			bg: 'rgba(244,114,182,0.08)',
			glow: 'rgba(244,114,182,0.25)'
		},
		{
			key: 'qualificationManagement',
			label: 'Applicability Management',
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

	let isLoadingRules = false;
	let rulesError = '';
	let isSavingRule = false;
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

			const rows = (data ?? []) as ApplicabilityRpcRow[];
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
			} else {
				applicabilityEmployees = [...applicabilityEmployees, ...employees];
				applicabilityAssignments = [...applicabilityAssignments, ...assignments];
			}

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

	function formatCycleLabel(rule: SettlementRule) {
		const cycleValue = rule.qualification_cycle_value ?? rule.qualification_cycle_years ?? 1;
		const cycleUnit = rule.qualification_cycle_unit ?? 'year';
		const unitLabel = cycleUnit === 'month' ? (cycleValue === 1 ? 'month' : 'months') : (cycleValue === 1 ? 'year' : 'years');
		return `Every ${cycleValue} ${unitLabel}`;
	}

	function formatJoiningDuration(joinDate: string | null) {
		if (!joinDate) return '—';
		const start = new Date(joinDate);
		const end = new Date();
		if (Number.isNaN(start.getTime())) return '—';
		if (start > end) return '0 days';

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
		if (years > 0) parts.push(`${years} year${years !== 1 ? 's' : ''}`);
		if (months > 0) parts.push(`${months} month${months !== 1 ? 's' : ''}`);
		parts.push(`${days} day${days !== 1 ? 's' : ''}`);
		return parts.join(', ');
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
</script>

<div class="services-window">
	<!-- Service Cards Grid -->
	<div class="services-grid">
		{#each services as svc}
			<button
				class="service-card"
				class:active={selected === svc.key}
				style="--accent:{svc.accent};--bg:{svc.bg};--glow:{svc.glow}"
				on:click={() => { selected = selected === svc.key ? null : svc.key; activeRuleForm = null; closeRuleScheduleModal(); }}
			>
				<span class="card-icon">{svc.icon}</span>
				<span class="card-label">{svc.label}</span>
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
							<div class="rule-form-kicker">{activeRuleForm === 'ticket' ? 'Ticket Rules' : 'Leave Salary Rules'}</div>
							<h3>{activeRuleForm === 'ticket' ? 'Add Travel Ticket Management Rule' : 'Add Annual Leave Management Rule'}</h3>
						</div>
						<button class="btn-close-form" on:click={closeRuleForm}>✕</button>
					</div>

					<div class="form-fields">
						<div class="field-group">
							<label class="field-label" for="f-name-en">Rule Name (EN)</label>
							<input id="f-name-en" class="field-input" type="text" placeholder={activeRuleForm === 'ticket' ? 'Travel Tickets Rule' : 'Annual Leave Management Rule'} bind:value={formRuleNameEn} />
						</div>
						<div class="field-group">
							<label class="field-label" for="f-name-ar">Rule Name (AR)</label>
							<input id="f-name-ar" class="field-input" type="text" dir="rtl" placeholder={activeRuleForm === 'ticket' ? 'قاعدة تذاكر السفر' : 'إدارة الإجازة السنوية'} bind:value={formRuleNameAr} />
						</div>
						<div class="field-group">
							<label class="field-label" for="f-cycle">Qualification Cycle (years)</label>
							<input id="f-cycle" class="field-input field-number" type="number" min="1" max="99" bind:value={formCycleYears} />
						</div>
						{#if activeRuleForm === 'ticket'}
							<div class="field-group">
								<label class="field-label" for="f-tickets">Number of Tickets</label>
								<input id="f-tickets" class="field-input field-number" type="number" min="1" max="99" bind:value={formTicketCount} />
							</div>
						{:else}
							<div class="field-group">
								<label class="field-label" for="f-days">Entitled Days</label>
								<input id="f-days" class="field-input field-number" type="number" min="1" max="365" bind:value={formEntitledDays} />
							</div>
						{/if}
					</div>

					<div class="form-footer">
						<button class="btn-cancel" on:click={closeRuleForm}>Cancel</button>
						<button class="btn-save" on:click={saveRule} disabled={isSavingRule}>{isSavingRule ? 'Saving...' : 'Save Rule'}</button>
					</div>
				</div>
			{/if}

			<div class="settlement-sections">
				<section class="settlement-section ticket-section">
					<div class="section-header">
						<div>
							<div class="section-kicker">Settlement Rules</div>
							<h3>Travel Ticket Management Rules</h3>
						</div>
						<button class="section-add-btn ticket" on:click={() => openRuleForm('ticket')}>+ Add New</button>
					</div>

					{#if isLoadingRules}
						<div class="settlement-empty">Loading travel ticket management rules...</div>
					{:else if getRulesByType('ticket').length === 0}
						<div class="settlement-empty">No travel ticket management rules yet.</div>
					{:else}
						<table class="settlement-table">
							<thead>
								<tr>
									<th>Rule Name (EN / AR)</th>
									<th>Cycle</th>
									<th>Tickets</th>
									<th></th>
								</tr>
							</thead>
							<tbody>
								{#each getRulesByType('ticket') as rule}
									<tr>
										<td class="td-name">
											<div class="name-stack">
												<span class="name-en">{rule.rule_name_en}</span>
												<span class="name-ar">{rule.rule_name_ar}</span>
											</div>
										</td>
										<td>{formatCycleLabel(rule)}</td>
										<td>{rule.ticket_count} ticket{rule.ticket_count !== 1 ? 's' : ''}</td>
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
							<div class="section-kicker">Settlement Rules</div>
							<h3>Annual Leave Management Rules</h3>
						</div>
						<button class="section-add-btn leave" on:click={() => openRuleForm('leave_salary')}>+ Add New</button>
					</div>

					{#if isLoadingRules}
						<div class="settlement-empty">Loading annual leave management rules...</div>
					{:else if getRulesByType('leave_salary').length === 0}
						<div class="settlement-empty">No annual leave management rules yet.</div>
					{:else}
						<table class="settlement-table">
							<thead>
								<tr>
									<th>Rule Name (EN / AR)</th>
									<th>Cycle</th>
									<th>Days</th>
									<th></th>
								</tr>
							</thead>
							<tbody>
								{#each getRulesByType('leave_salary') as rule}
									<tr>
										<td class="td-name">
											<div class="name-stack">
												<span class="name-en">{rule.rule_name_en}</span>
												<span class="name-ar">{rule.rule_name_ar}</span>
											</div>
										</td>
										<td>{formatCycleLabel(rule)}</td>
										<td>{rule.entitled_days} day{rule.entitled_days !== 1 ? 's' : ''}</td>
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
					<div class="section-kicker">HR Services</div>
					<h3>Applicability Management</h3>
				</div>
				<div class="result-count">{applicabilityEmployees.length} / {applicabilityTotalCount}</div>
			</div>

			<div class="applicability-filters">
				<input
					class="filter-input"
					type="text"
					placeholder="Search by employee id, English name, or Arabic name"
					bind:value={searchName}
					on:keydown={(event) => {
						if (event.key === 'Enter') applyApplicabilityFilters();
					}}
				/>
				<select class="filter-select" bind:value={selectedNationalityId}>
					<option value="">All Nationalities</option>
					{#each nationalityOptions as nationality}
						<option value={nationality.id}>{nationality.name_en || nationality.id}{nationality.name_ar ? ` / ${nationality.name_ar}` : ''}</option>
					{/each}
				</select>
				<select class="filter-select" bind:value={ticketStatusFilter}>
					<option value="all">Ticket: All</option>
					<option value="enabled">Ticket: Enabled</option>
					<option value="disabled">Ticket: Disabled</option>
				</select>
				<select class="filter-select" bind:value={leaveStatusFilter}>
					<option value="all">Leave: All</option>
					<option value="enabled">Leave: Enabled</option>
					<option value="disabled">Leave: Disabled</option>
				</select>
				<div class="filter-actions">
					<button class="btn-apply-filter" on:click={applyApplicabilityFilters}>Apply</button>
					<button class="btn-clear-filter" on:click={clearApplicabilityFilters}>Reset</button>
				</div>
			</div>

			{#if applicabilityError}
				<div class="rules-error">{applicabilityError}</div>
			{/if}

			{#if isLoadingApplicability}
				<div class="applicability-empty">Loading eligible employees...</div>
			{:else if applicabilityEmployees.length === 0}
				<div class="applicability-empty">No eligible employees matched your filters.</div>
			{:else}
				<div class="applicability-table-wrap" bind:this={applicabilityTableWrapEl} on:scroll={handleApplicabilityScroll}>
					<table class="applicability-table">
						<thead>
							<tr>
								<th>S/N</th>
								<th>Employee ID</th>
								<th>Employee Name</th>
								<th>Nationality</th>
								<th>Sponsorship Status</th>
								<th>Joining Duration</th>
								<th>Ticket Rule</th>
								<th>Qualified Number of Tickets</th>
								<th>Annual Leave Rule</th>
								<th>Qualified Number of Annual Leave Days</th>
							</tr>
						</thead>
						<tbody>
							{#each applicabilityEmployees as employee, index}
								{@const assignment = getAssignmentForEmployee(employee.id)}
								<tr>
									<td class="mono-cell">{index + 1}</td>
									<td class="mono-cell">{employee.id}</td>
									<td class="td-name">
										<div class="name-stack">
											<span class="name-en">{employee.name_en || '—'}</span>
											<span class="name-ar">{employee.name_ar || '—'}</span>
										</div>
									</td>
									<td class="td-name">
										<div class="name-stack">
											<span class="name-en">{employee.nationality_name_en || '—'}</span>
											<span class="name-ar">{employee.nationality_name_ar || '—'}</span>
										</div>
									</td>
									<td>{employee.sponsorship_status === true ? 'Yes' : 'No'}</td>
									<td>{formatJoiningDuration(employee.join_date)}</td>
									<td>
										<div class="toggle-cell">
											<button
												class="toggle-btn"
												class:enabled={assignment?.ticket_rule_enabled}
												on:click={() => openRuleScheduleModal(employee.id, 'ticket')}
											>
												{assignment?.ticket_rule_enabled ? 'Manage Rules' : 'Enable Rules'}
											</button>
											{#if assignment?.ticket_rule_enabled}
												<button class="btn-inline-disable" on:click={() => disableRuleForEmployee(employee.id, 'ticket')}>Disable</button>
											{/if}
											{#if assignment?.ticket_rule_enabled}
												<div class="applied-rule">
													<div>{assignment?.ticket_rule_name_en || '—'}</div>
													<div class="rule-ar">{assignment?.ticket_rule_name_ar || '—'}</div>
													<div class="rule-meta">Periods: {assignment?.ticket_periods_count ?? 0}</div>
												</div>
											{/if}
										</div>
									</td>
									<td>{assignment?.ticket_rule_enabled ? (assignment?.qualified_ticket_count ?? 0) : '—'}</td>
									<td>
										<div class="toggle-cell">
											<button
												class="toggle-btn leave-toggle"
												class:enabled={assignment?.leave_salary_rule_enabled}
												on:click={() => openRuleScheduleModal(employee.id, 'leave_salary')}
											>
												{assignment?.leave_salary_rule_enabled ? 'Manage Rules' : 'Enable Rules'}
											</button>
											{#if assignment?.leave_salary_rule_enabled}
												<button class="btn-inline-disable" on:click={() => disableRuleForEmployee(employee.id, 'leave_salary')}>Disable</button>
											{/if}
											{#if assignment?.leave_salary_rule_enabled}
												<div class="applied-rule">
													<div>{assignment?.leave_rule_name_en || '—'}</div>
													<div class="rule-ar">{assignment?.leave_rule_name_ar || '—'}</div>
													<div class="rule-meta">Periods: {assignment?.leave_periods_count ?? 0}</div>
												</div>
											{/if}
										</div>
									</td>
									<td>{assignment?.leave_salary_rule_enabled ? (assignment?.qualified_leave_days ?? 0) : '—'}</td>
								</tr>
							{/each}
						</tbody>
					</table>
					{#if isLoadingMoreApplicability}
						<div class="applicability-loading-more">Loading more...</div>
					{:else if hasMoreApplicability}
						<div class="applicability-loading-more">Scroll to load more</div>
					{/if}
				</div>
			{/if}
		</div>

		{#if showRuleScheduleModal && scheduleRuleType}
			<div
				class="picker-backdrop"
				role="button"
				tabindex="0"
				aria-label="Close rule schedule"
				on:click={closeRuleScheduleModal}
				on:keydown={(event) => {
					if (event.key === 'Enter' || event.key === ' ' || event.key === 'Escape') {
						closeRuleScheduleModal();
					}
				}}
			>
				<div class="picker-modal" role="dialog" aria-modal="true" tabindex="-1" on:click|stopPropagation on:keydown|stopPropagation>
					<h4>{scheduleRuleType === 'ticket' ? 'Travel Ticket' : 'Annual Leave'} Rule Periods</h4>
					<div class="picker-list">
						{#if scheduleEmployee}
							<div class="picker-employee-meta">
								<div><strong>Employee:</strong> {scheduleEmployee.name_en || scheduleEmployee.id}</div>
								<div><strong>Joining Date:</strong> {scheduleEmployee.join_date || 'N/A'}</div>
							</div>
						{/if}
						{#each schedulePeriods as period, index}
							<div class="schedule-row">
								<div class="schedule-row-top">
									<div class="schedule-seq">Rule #{index + 1}</div>
									{#if schedulePeriods.length > 1}
										<button class="btn-remove-period" on:click={() => removeSchedulePeriod(index)}>Remove</button>
									{/if}
								</div>
								<div class="schedule-grid">
									<select
										class="filter-select"
										value={period.rule_id ?? ''}
										on:change={(event) => updateSchedulePeriod(index, { rule_id: Number((event.currentTarget as HTMLSelectElement).value) || null })}
									>
										<option value="">Select Rule</option>
										{#each getRulesByType(scheduleRuleType) as rule}
											<option value={rule.id}>{rule.rule_name_en} / {rule.rule_name_ar}</option>
										{/each}
									</select>

									<label class="schedule-inline-field">
										<input
											type="checkbox"
											checked={period.is_infinite}
											on:change={(event) => updateSchedulePeriod(index, { is_infinite: (event.currentTarget as HTMLInputElement).checked })}
										/>
										<span>Infinite period</span>
									</label>

									<label class="schedule-number-field">
										<span>Years</span>
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
										<span>Months</span>
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
									From: {schedulePreviewRows[index]?.effective_from || '—'}
									{#if schedulePreviewRows[index]?.effective_to}
										| To: {schedulePreviewRows[index]?.effective_to}
									{:else}
										| To: Infinite
									{/if}
								</div>
							</div>
						{/each}
						<button class="btn-add-period" on:click={addSchedulePeriod} disabled={schedulePeriods[schedulePeriods.length - 1]?.is_infinite}>
							+ Add Next Rule Period
						</button>
					</div>
					<div class="picker-footer">
						<button class="btn-cancel" on:click={closeRuleScheduleModal}>Cancel</button>
						<button class="btn-save" disabled={isSavingApplicability} on:click={saveRuleSchedule}>
							{isSavingApplicability ? 'Saving...' : 'Save Period Rules'}
						</button>
					</div>
				</div>
			</div>
		{/if}

	{:else if selected}
		{@const svc = services.find(s => s.key === selected)}
		<div class="content-area" style="--accent:{svc?.accent};--bg:{svc?.bg};--glow:{svc?.glow}">
			<div class="content-inner">
				<div class="content-icon">{svc?.icon}</div>
				<h2 class="content-title">{svc?.label}</h2>
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
	.name-stack {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}
	.name-en { font-weight: 700; color: #1e293b; }
	.name-ar { font-size: 0.78rem; color: #64748b; direction: rtl; }
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
	.rule-ar {
		direction: rtl;
		color: #64748b;
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
		.schedule-grid {
			grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
		}
		.schedule-grid .field-input.field-number {
			width: 100%;
		}
	}

	@media (max-width: 620px) {
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
