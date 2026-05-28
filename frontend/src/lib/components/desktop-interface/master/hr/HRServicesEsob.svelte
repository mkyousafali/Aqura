<script lang="ts">
	import { _ as t, locale } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	type TerminationMode = 'non_resignation' | 'resignation';
	type ContractType = 'definite' | 'indefinite';
	type PrintLanguage = 'en' | 'ar' | 'bilingual';

	const TERMINATION_REASONS = [
		// ── Employer-initiated ──────────────────────────────────────────────────────────────
		{ value: 'article_75',            en: 'Employer Termination with Notice (Art. 75)',             ar: 'إنهاء صاحب العمل للعقد مع إشعار (م. 75)',              factor: 'full',        definiteOnly: false },
		{ value: 'employer_unlawful',     en: 'Arbitrary / Unjust Termination by Employer (Art. 77)',   ar: 'إنهاء تعسفي من صاحب العمل (م. 77)',                    factor: 'full',        definiteOnly: false },
		{ value: 'article_80',            en: 'Dismissal for Cause – Misconduct (Art. 80)',             ar: 'الفصل بسبب المخالفة الجسيمة (م. 80)',                  factor: 'none',        definiteOnly: false },
		{ value: 'absconding',            en: 'Absconding / Abandonment of Work (Huroob)',              ar: 'الغياب غير المبرر / الهروب من العمل',                  factor: 'none',        definiteOnly: false },
		{ value: 'probation',             en: 'Termination during Probation Period',                    ar: 'إنهاء الخدمة خلال فترة التجربة',                       factor: 'none',        definiteOnly: false },
		{ value: 'medical_unfit',         en: 'Medical Termination / Permanent Incapacity',             ar: 'إنهاء الخدمة لعدم اللياقة الطبية / العجز الدائم',      factor: 'full',        definiteOnly: false },
		{ value: 'saudization',           en: 'Saudization / Replaced by Saudi National',               ar: 'السعودة / الاستعاضة بموظف سعودي',                      factor: 'full',        definiteOnly: false },
		{ value: 'expiry_contract_term',  en: 'End of Limited Contract Term',                           ar: 'انتهاء مدة العقد المحدد',                               factor: 'full',        definiteOnly: true  },
		// ── Employee-initiated ──────────────────────────────────────────────────────────────
		{ value: 'resignation',           en: 'Resignation (Employee)',                                  ar: 'استقالة (بمبادرة الموظف)',                              factor: 'resignation',  definiteOnly: false },
		{ value: 'article_81',            en: 'Resignation with Full Rights – Employer Fault (Art. 81)', ar: 'الاستقالة مع الحقوق كاملة – إخلال صاحب العمل (م. 81)', factor: 'full',        definiteOnly: false },
		{ value: 'female_marriage',       en: 'Female Resignation after Marriage (within 6 months)',    ar: 'استقالة الموظفة بعد الزواج (خلال 6 أشهر)',             factor: 'full',        definiteOnly: false },
		{ value: 'female_maternity',      en: 'Female Resignation after Childbirth (within 3 months)',  ar: 'استقالة الموظفة بعد الوضع (خلال 3 أشهر)',             factor: 'full',        definiteOnly: false },
		// ── Mutual / Agreed ──────────────────────────────────────────────────────────────────
		{ value: 'agreement_terminate',   en: 'Mutual Agreement to Terminate',                          ar: 'إنهاء العقد بالاتفاق المشترك',                         factor: 'full',        definiteOnly: false },
		// ── Natural / Unavoidable ────────────────────────────────────────────────────────────
		{ value: 'retirement_age',        en: 'Reaching Retirement Age',                                ar: 'بلوغ سن التقاعد',                                      factor: 'full',        definiteOnly: false },
		{ value: 'death_employee',        en: 'Death of Employee',                                      ar: 'وفاة الموظف',                                          factor: 'full',        definiteOnly: false },
		{ value: 'disability',            en: 'Total Disability (Work Injury)',                          ar: 'العجز الكلي الدائم (إصابة عمل)',                       factor: 'full',        definiteOnly: false },
		{ value: 'force_majeure',         en: 'Force Majeure',                                          ar: 'القوة القاهرة',                                        factor: 'full',        definiteOnly: false },
		// ── Business Reasons ────────────────────────────────────────────────────────────────
		{ value: 'final_closure',         en: 'Permanent / Final Closure of Business',                  ar: 'الإغلاق النهائي للمنشأة',                              factor: 'full',        definiteOnly: false },
		{ value: 'termination_activity',  en: 'Redundancy / Position Cancelled / End of Activity',      ar: 'إلغاء المنصب / إنهاء النشاط',                         factor: 'full',        definiteOnly: false },
		{ value: 'transfer_new_owner',    en: 'Transfer of Business to New Owner',                      ar: 'انتقال ملكية المنشأة لمالك جديد',                     factor: 'full',        definiteOnly: false },
		{ value: 'death_employer',        en: 'Death of Employer (Individual Business)',                 ar: 'وفاة صاحب العمل (مؤسسة فردية)',                       factor: 'full',        definiteOnly: false },
	] as const;

	type TerminationReason = typeof TERMINATION_REASONS[number]['value'];

	interface EmployeeRow {
		id: string;
		name_en: string | null;
		name_ar: string | null;
		id_number: string | null;
		nationality_name_en: string | null;
		nationality_name_ar: string | null;
		join_date: string | null;
		employment_status: string | null;
		employment_status_effective_date: string | null;
	}

	interface SalaryRow {
		employee_id: string;
		basic_salary: number | null;
		total_salary: number | null;
		other_allowance: number | null;
		accommodation_allowance: number | null;
		travel_allowance: number | null;
		food_allowance: number | null;
		gosi_deduction: number | null;
	}

	interface BaseRule {
		id: number;
		rule_name_en: string;
		rule_name_ar: string | null;
		years_from: number;
		years_to: number | null;
		months_per_year: number;
		is_active: boolean;
		sort_order: number;
	}

	interface ResignationRule {
		id: number;
		rule_name_en: string;
		rule_name_ar: string | null;
		years_from: number;
		years_to: number | null;
		factor: number;
		is_active: boolean;
		sort_order: number;
	}

	interface EsobRecord {
		id: number;
		employee_id: string;
		service_start_date: string;
		service_end_date: string;
		termination_mode: TerminationMode;
		contract_type: string | null;
		termination_reason: string | null;
		include_basic_salary: boolean;
		include_other_allowance: boolean;
		include_accommodation_allowance: boolean;
		include_travel_allowance: boolean;
		include_food_allowance: boolean;
		unused_leave_days: number;
		unused_ticket_count: number;
		ticket_amount: number;
		manual_additions: number;
		manual_deductions: number;
		notes: string | null;
		print_language: PrintLanguage;
		calc_service_years: number;
		calc_monthly_wage: number;
		calc_esob_amount: number;
		calc_leave_amount: number;
		calc_ticket_amount: number;
		calc_gross_amount: number;
		calc_net_amount: number;
		created_at: string;
		updated_at: string;
	}

	interface EsobDraft {
		recordId: number | null;
		employeeId: string;
		serviceStartDate: string;
		serviceEndDate: string;
		contractType: ContractType;
		terminationReason: TerminationReason | '';
		terminationMode: TerminationMode;
		includeBasicSalary: boolean;
		includeOtherAllowance: boolean;
		includeAccommodationAllowance: boolean;
		includeTravelAllowance: boolean;
		includeFoodAllowance: boolean;
		unusedLeaveDays: number;
		unusedTicketCount: number;
		ticketAmount: number;
		manualAdditions: number;
		manualDeductions: number;
		notes: string;
		printLanguage: PrintLanguage;
	}

	interface CalcResult {
		serviceYears: number;
		monthlyWage: number;
		esobAmount: number;
		leaveAmount: number;
		ticketAmount: number;
		grossAmount: number;
		netAmount: number;
	}

	interface BackgroundTemplate {
		id: string;
		name: string;
		name_ar: string | null;
		storage_path: string;
		bucket: string;
		category: string | null;
		is_active: boolean;
	}

	const ACTIVE_STATUS_DEFAULT = new Set(['Job (With Finger)', 'Remote Job', 'Vacation']);

	let isLoading = false;
	let isSaving = false;
	let errorMessage = '';
	let activeTab: 'calculation' | 'rules' = 'calculation';

	let employees: EmployeeRow[] = [];
	let salariesByEmployee: Record<string, SalaryRow> = {};
	let records: EsobRecord[] = [];
	let baseRules: BaseRule[] = [];
	let resignationRules: ResignationRule[] = [];
	let backgroundTemplates: BackgroundTemplate[] = [];

	let selectedTemplateId = '';
	let selectedTemplateUrl = '';
	let showTemplateUpload = false;
	let templateUploadName = '';
	let templateUploadFile: File | null = null;
	let isUploadingTemplate = false;
	let templateFileInput: HTMLInputElement;

	let search = '';
	let includeInactive = false;
	let selectedEmployeeId = '';

	let draft: EsobDraft = createEmptyDraft();
	let calcResult: CalcResult | null = null;

	let baseEditId: number | null = null;
	let baseRuleNameEn = '';
	let baseRuleNameAr = '';
	let baseYearsFrom: number | '' = 0;
	let baseYearsTo: number | '' = '';
	let baseMonthsPerYear: number | '' = 0.5;

	let resignationEditId: number | null = null;
	let resignationRuleNameEn = '';
	let resignationRuleNameAr = '';
	let resignationYearsFrom: number | '' = 0;
	let resignationYearsTo: number | '' = '';
	let resignationFactor: number | '' = 1;

	onMount(() => {
		void loadAll();
	});

	$: filteredEmployees = employees.filter((emp) => {
		if (!includeInactive && !ACTIVE_STATUS_DEFAULT.has(emp.employment_status ?? '')) {
			return false;
		}
		const q = search.trim().toLowerCase();
		if (!q) return true;
		const hay = `${emp.id} ${emp.name_en ?? ''} ${emp.name_ar ?? ''} ${emp.employment_status ?? ''}`.toLowerCase();
		return hay.includes(q);
	});

	$: selectedEmployee = employees.find((emp) => emp.id === selectedEmployeeId) ?? null;
	$: selectedSalary = selectedEmployeeId ? salariesByEmployee[selectedEmployeeId] ?? null : null;

	function createEmptyDraft(): EsobDraft {
		const today = formatDateYmd(new Date());
		return {
			recordId: null,
			employeeId: '',
			serviceStartDate: '',
			serviceEndDate: today,
			contractType: 'indefinite',
			terminationReason: '',
			terminationMode: 'non_resignation',
			includeBasicSalary: true,
			includeOtherAllowance: false,
			includeAccommodationAllowance: false,
			includeTravelAllowance: false,
			includeFoodAllowance: false,
			unusedLeaveDays: 0,
			unusedTicketCount: 0,
			ticketAmount: 0,
			manualAdditions: 0,
			manualDeductions: 0,
			notes: '',
			printLanguage: 'bilingual'
		};
	}

	function localizedText(en: string | null | undefined, ar: string | null | undefined, fallback = '—') {
		const isArabic = $locale === 'ar';
		const first = (isArabic ? ar : en) ?? '';
		const second = (isArabic ? en : ar) ?? '';
		return (first.trim() || second.trim() || fallback);
	}

	function formatDateYmd(date: Date) {
		const y = date.getFullYear();
		const m = `${date.getMonth() + 1}`.padStart(2, '0');
		const d = `${date.getDate()}`.padStart(2, '0');
		return `${y}-${m}-${d}`;
	}

	function toNumber(value: number | null | undefined) {
		return Number(value ?? 0);
	}

	function getReasonInfo(reason: TerminationReason | '') {
		return TERMINATION_REASONS.find((r) => r.value === reason) ?? null;
	}

	function getReasonLabel(reason: TerminationReason | '', lang: 'en' | 'ar' = 'en'): string {
		const info = getReasonInfo(reason);
		if (!info) return reason || '—';
		return lang === 'ar' ? info.ar : info.en;
	}

	function deriveTerminationMode(reason: TerminationReason | ''): TerminationMode {
		const info = getReasonInfo(reason);
		return info?.factor === 'resignation' ? 'resignation' : 'non_resignation';
	}

	// Map employment_status to a default termination reason
	const STATUS_TO_REASON: Record<string, TerminationReason> = {
		'Resigned': 'resignation',
		'Terminated': 'employer_unlawful',
		'Retired': 'retirement_age',
		'Deceased': 'death_employee',
		'Contract Ended': 'expiry_contract_term',
	};

	async function loadAll() {
		isLoading = true;
		errorMessage = '';
		try {
			await Promise.all([
				loadEmployeesAndSalaries(),
				loadRules(),
				loadRecords(),
				loadBackgroundTemplates()
			]);
		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'Failed to load ESOB module';
		} finally {
			isLoading = false;
		}
	}

	async function loadBackgroundTemplates() {
		const { data, error } = await supabase
			.from('background_templates')
			.select('id, name, name_ar, storage_path, bucket, category, is_active')
			.eq('is_active', true)
			.order('name', { ascending: true });
		if (error) throw error;
		backgroundTemplates = (data ?? []) as BackgroundTemplate[];
	}

	function onTemplateChange() {
		const tpl = backgroundTemplates.find((t) => t.id === selectedTemplateId);
		if (tpl) {
			const { data: urlData } = supabase.storage.from(tpl.bucket).getPublicUrl(tpl.storage_path);
			selectedTemplateUrl = urlData?.publicUrl ?? '';
		} else {
			selectedTemplateUrl = '';
		}
	}

	function onTemplateFileChange(e: Event) {
		const input = e.target as HTMLInputElement;
		templateUploadFile = input.files?.[0] ?? null;
		if (templateUploadFile && !templateUploadName) {
			templateUploadName = templateUploadFile.name.replace(/\.[^.]+$/, '');
		}
	}

	async function uploadTemplate() {
		if (!templateUploadFile || !templateUploadName.trim()) {
			errorMessage = 'Please provide a name and choose a file.';
			return;
		}
		if (templateUploadFile.size > 15 * 1024 * 1024) {
			errorMessage = 'File too large — maximum 15 MB.';
			return;
		}
		isUploadingTemplate = true;
		errorMessage = '';
		try {
			const ext = templateUploadFile.name.split('.').pop()?.toLowerCase() ?? 'png';
			const path = `esob/${Date.now()}_${templateUploadName.trim().replace(/\s+/g, '_')}.${ext}`;
			const { error: uploadError } = await supabase.storage
				.from('app-templates')
				.upload(path, templateUploadFile, { upsert: false });
			if (uploadError) throw uploadError;
			const { error: dbError } = await supabase.from('background_templates').insert({
				name: templateUploadName.trim(),
				storage_path: path,
				bucket: 'app-templates',
				mime_type: templateUploadFile.type,
				file_size: templateUploadFile.size,
				category: 'esob'
			});
			if (dbError) throw dbError;
			templateUploadName = '';
			templateUploadFile = null;
			if (templateFileInput) templateFileInput.value = '';
			showTemplateUpload = false;
			await loadBackgroundTemplates();
		} catch (err) {
			errorMessage = err instanceof Error ? err.message : 'Upload failed';
		} finally {
			isUploadingTemplate = false;
		}
	}

	async function loadEmployeesAndSalaries() {
		const { data: employeeData, error: employeeError } = await supabase
			.from('hr_employee_master')
			.select('id, name_en, name_ar, id_number, join_date, employment_status, employment_status_effective_date, nationalities(name_en, name_ar)')
			.order('id', { ascending: true })
			.limit(2000);
		if (employeeError) throw employeeError;

		employees = ((employeeData ?? []) as Array<any>).map((row) => ({
			id: row.id,
			name_en: row.name_en,
			name_ar: row.name_ar,
			id_number: row.id_number ?? null,
			nationality_name_en: row.nationalities?.name_en ?? null,
			nationality_name_ar: row.nationalities?.name_ar ?? null,
			join_date: row.join_date,
			employment_status: row.employment_status,
			employment_status_effective_date: row.employment_status_effective_date
		}));

		const employeeIds = employees.map((row) => row.id);
		if (employeeIds.length === 0) {
			salariesByEmployee = {};
			return;
		}

		const { data: salaryData, error: salaryError } = await supabase
			.from('hr_basic_salary')
			.select('employee_id, basic_salary, total_salary, other_allowance, accommodation_allowance, travel_allowance, food_allowance, gosi_deduction')
			.in('employee_id', employeeIds);
		if (salaryError) throw salaryError;

		const salaryMap: Record<string, SalaryRow> = {};
		for (const row of (salaryData ?? []) as SalaryRow[]) {
			salaryMap[row.employee_id] = row;
		}
		salariesByEmployee = salaryMap;
	}

	async function loadRules() {
		const [baseResult, resignationResult] = await Promise.all([
			supabase
				.from('hr_esob_base_rules')
				.select('id, rule_name_en, rule_name_ar, years_from, years_to, months_per_year, is_active, sort_order')
				.eq('is_active', true)
				.order('years_from', { ascending: true }),
			supabase
				.from('hr_esob_resignation_factors')
				.select('id, rule_name_en, rule_name_ar, years_from, years_to, factor, is_active, sort_order')
				.eq('is_active', true)
				.order('years_from', { ascending: true })
		]);

		if (baseResult.error) throw baseResult.error;
		if (resignationResult.error) throw resignationResult.error;

		baseRules = (baseResult.data ?? []) as BaseRule[];
		resignationRules = (resignationResult.data ?? []) as ResignationRule[];
	}

	async function loadRecords() {
		const { data, error } = await supabase
			.from('hr_employee_esob_records')
			.select('*')
			.order('updated_at', { ascending: false })
			.limit(300);
		if (error) throw error;
		records = (data ?? []) as EsobRecord[];
	}

	async function selectEmployee(employeeId: string) {
		selectedEmployeeId = employeeId;
		const employee = employees.find((row) => row.id === employeeId);
		if (!employee) return;

		draft = createEmptyDraft();
		draft.employeeId = employeeId;
		draft.serviceStartDate = employee.join_date ?? '';
		draft.serviceEndDate = employee.employment_status_effective_date ?? formatDateYmd(new Date());
		const autoReason = STATUS_TO_REASON[employee.employment_status ?? ''] ?? '';
		draft.terminationReason = autoReason;
		draft.terminationMode = deriveTerminationMode(autoReason);
		// Auto-set contract type: if reason is definite-only, switch to definite
		if (autoReason === 'expiry_contract_term') draft.contractType = 'definite';

		const remaining = await loadRemainingLeaveAndTickets(employeeId);
		draft.unusedLeaveDays = remaining.leave;
		draft.unusedTicketCount = remaining.tickets;

		calcResult = null;
	}

	async function loadRemainingLeaveAndTickets(employeeId: string) {
		try {
			const [assignmentResult, usageResult] = await Promise.all([
				supabase
					.from('hr_employee_settlement_applicability')
					.select('qualified_ticket_count, qualified_leave_days')
					.eq('employee_id', employeeId)
					.maybeSingle(),
				supabase.rpc('get_hr_employee_qualification_usage', { p_employee_ids: [employeeId] })
			]);

			if (assignmentResult.error) throw assignmentResult.error;
			if (usageResult.error) throw usageResult.error;

			const qualifiedTickets = Number(assignmentResult.data?.qualified_ticket_count ?? 0);
			const qualifiedLeave = Number(assignmentResult.data?.qualified_leave_days ?? 0);
			const usage = ((usageResult.data ?? []) as Array<{ employee_id: string; ticket_issued_count: number | null; leave_approved_days: number | null }>).find((row) => row.employee_id === employeeId);
			const usedTickets = Number(usage?.ticket_issued_count ?? 0);
			const usedLeave = Number(usage?.leave_approved_days ?? 0);

			return {
				tickets: Math.max(0, qualifiedTickets - usedTickets),
				leave: Math.max(0, qualifiedLeave - usedLeave)
			};
		} catch {
			return { tickets: 0, leave: 0 };
		}
	}

	function calculateServiceYears(startDate: string, endDate: string) {
		const start = new Date(startDate);
		const end = new Date(endDate);
		if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end < start) {
			return 0;
		}
		const dayMs = 1000 * 60 * 60 * 24;
		return (end.getTime() - start.getTime()) / dayMs / 365.25;
	}

	function calculateMonthlyWage() {
		if (!selectedSalary) return 0;
		let wage = 0;
		if (draft.includeBasicSalary) wage += toNumber(selectedSalary.basic_salary);
		if (draft.includeOtherAllowance) wage += toNumber(selectedSalary.other_allowance);
		if (draft.includeAccommodationAllowance) wage += toNumber(selectedSalary.accommodation_allowance);
		if (draft.includeTravelAllowance) wage += toNumber(selectedSalary.travel_allowance);
		if (draft.includeFoodAllowance) wage += toNumber(selectedSalary.food_allowance);
		return wage;
	}

	// Returns exact years/months/days breakdown (matches official HRSD method)
	function calculateServicePeriod(startDate: string, endDate: string): { years: number; months: number; days: number; decimalYears: number } {
		const start = new Date(startDate);
		const end = new Date(endDate);
		if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end < start) {
			return { years: 0, months: 0, days: 0, decimalYears: 0 };
		}
		// Saudi labor law counts both start and end dates as service days (inclusive)
		// Add 1 day to the end to include the termination date in the service period
		const endInclusive = new Date(end.getTime() + 24 * 60 * 60 * 1000);
		let years = endInclusive.getFullYear() - start.getFullYear();
		let months = endInclusive.getMonth() - start.getMonth();
		let days = endInclusive.getDate() - start.getDate();
		if (days < 0) {
			months--;
			days += new Date(endInclusive.getFullYear(), endInclusive.getMonth(), 0).getDate();
		}
		if (months < 0) { years--; months += 12; }
		const totalDays = (end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24) + 1;
		const decimalYears = totalDays / 365.25;
		return { years, months, days, decimalYears };
	}

	// Monthly ESOB rate for the tier where service currently sits
	function getTierMonthlyRate(atTotalMonths: number, monthlyWage: number): number {
		const atYears = atTotalMonths / 12;
		for (const rule of baseRules) {
			const from = Number(rule.years_from ?? 0);
			const to = rule.years_to == null ? Number.POSITIVE_INFINITY : Number(rule.years_to);
			if (atYears >= from && atYears < to) return (Number(rule.months_per_year) / 12) * monthlyWage;
		}
		if (baseRules.length > 0) return (Number(baseRules[baseRules.length - 1].months_per_year) / 12) * monthlyWage;
		return 0;
	}

	// Exact month+day calculation — matches official HRSD calculator
	function calculateBaseEsob(period: { years: number; months: number; days: number }, monthlyWage: number): number {
		const totalMonths = period.years * 12 + period.months;
		let total = 0;
		for (const rule of baseRules) {
			const ruleFromM = Math.round(Number(rule.years_from ?? 0) * 12);
			const ruleToM = rule.years_to == null ? totalMonths : Math.round(Number(rule.years_to) * 12);
			const spanStart = Math.max(0, ruleFromM);
			const spanEnd = Math.min(totalMonths, ruleToM);
			if (spanEnd <= spanStart) continue;
			total += (spanEnd - spanStart) * (Number(rule.months_per_year) / 12) * monthlyWage;
		}
		// Add remaining days at the rate of the tier where service ends
		if (period.days > 0) {
			total += period.days * (getTierMonthlyRate(totalMonths, monthlyWage) / 30);
		}
		return total;
	}

	function getResignationFactor(serviceYears: number) {
		for (const rule of resignationRules) {
			const from = Number(rule.years_from ?? 0);
			const to = rule.years_to == null ? Number.POSITIVE_INFINITY : Number(rule.years_to);
			if (serviceYears >= from && serviceYears < to) {
				return Number(rule.factor ?? 0);
			}
		}
		return 0;
	}

	function round2(value: number) {
		return Math.round((value + Number.EPSILON) * 100) / 100;
	}

	function recomputeFromEsob() {
		if (!calcResult) return;
		const esob = round2(Number(calcResult.esobAmount) || 0);
		const gross = round2(esob + calcResult.leaveAmount + calcResult.ticketAmount + Number(draft.manualAdditions || 0));
		const net = round2(gross - Number(draft.manualDeductions || 0));
		calcResult = { ...calcResult, esobAmount: esob, grossAmount: gross, netAmount: net };
	}

	function calculateDraft() {
		errorMessage = '';
		if (!draft.employeeId) {
			errorMessage = $t('hr.servicesWindow.esobSelectEmployeeError');
			return;
		}
		if (!draft.serviceStartDate || !draft.serviceEndDate) {
			errorMessage = $t('hr.servicesWindow.esobSelectDatesError');
			return;
		}
		if (!draft.terminationReason) {
			errorMessage = 'Please select a reason for termination.';
			return;
		}

		const reasonInfo = getReasonInfo(draft.terminationReason);
		const period = calculateServicePeriod(draft.serviceStartDate, draft.serviceEndDate);
		const serviceYears = period.decimalYears; // used for resignation factor threshold lookup
		const monthlyWage = calculateMonthlyWage();
		const baseEsob = calculateBaseEsob(period, monthlyWage);

		let esobFactor = 1;
		if (reasonInfo?.factor === 'none') {
			esobFactor = 0;
		} else if (reasonInfo?.factor === 'resignation') {
			esobFactor = getResignationFactor(serviceYears);
		}

		// Keep terminationMode in sync for backward compat
		draft.terminationMode = deriveTerminationMode(draft.terminationReason);

		const esobAmount = baseEsob * esobFactor;
		const leaveAmount = (monthlyWage / 30) * Number(draft.unusedLeaveDays || 0);
		const ticketAmount = Number(draft.ticketAmount || 0) * Number(draft.unusedTicketCount || 0);
		const grossAmount = esobAmount + leaveAmount + ticketAmount + Number(draft.manualAdditions || 0);
		const netAmount = grossAmount - Number(draft.manualDeductions || 0);

		calcResult = {
			serviceYears: round2(serviceYears),
			monthlyWage: round2(monthlyWage),
			esobAmount: round2(esobAmount),
			leaveAmount: round2(leaveAmount),
			ticketAmount: round2(ticketAmount),
			grossAmount: round2(grossAmount),
			netAmount: round2(netAmount)
		};
	}

	async function saveRecord() {
		if (!calcResult) {
			errorMessage = $t('hr.servicesWindow.esobCalculateFirst');
			return;
		}
		isSaving = true;
		errorMessage = '';
		try {
			const payload = {
				employee_id: draft.employeeId,
				service_start_date: draft.serviceStartDate,
				service_end_date: draft.serviceEndDate,
				contract_type: draft.contractType,
				termination_reason: draft.terminationReason || null,
				termination_mode: draft.terminationMode,
				include_basic_salary: draft.includeBasicSalary,
				include_other_allowance: draft.includeOtherAllowance,
				include_accommodation_allowance: draft.includeAccommodationAllowance,
				include_travel_allowance: draft.includeTravelAllowance,
				include_food_allowance: draft.includeFoodAllowance,
				unused_leave_days: Number(draft.unusedLeaveDays || 0),
				unused_ticket_count: Number(draft.unusedTicketCount || 0),
				ticket_amount: Number(draft.ticketAmount || 0),
				manual_additions: Number(draft.manualAdditions || 0),
				manual_deductions: Number(draft.manualDeductions || 0),
				notes: draft.notes || null,
				print_language: draft.printLanguage,
				calc_service_years: calcResult.serviceYears,
				calc_monthly_wage: calcResult.monthlyWage,
				calc_esob_amount: calcResult.esobAmount,
				calc_leave_amount: calcResult.leaveAmount,
				calc_ticket_amount: calcResult.ticketAmount,
				calc_gross_amount: calcResult.grossAmount,
				calc_net_amount: calcResult.netAmount
			};

			if (draft.recordId) {
				const { error } = await supabase
					.from('hr_employee_esob_records')
					.update(payload)
					.eq('id', draft.recordId);
				if (error) throw error;
			} else {
				const { data, error } = await supabase
					.from('hr_employee_esob_records')
					.insert(payload)
					.select('id')
					.single();
				if (error) throw error;
				draft.recordId = data?.id ?? null;
			}

			await loadRecords();
		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'Failed to save ESOB record';
		} finally {
			isSaving = false;
		}
	}

	function editRecord(record: EsobRecord) {
		selectedEmployeeId = record.employee_id;
		const storedReason = (record.termination_reason ?? '') as TerminationReason | '';
		draft = {
			recordId: record.id,
			employeeId: record.employee_id,
			serviceStartDate: record.service_start_date,
			serviceEndDate: record.service_end_date,
			contractType: (record.contract_type as ContractType) ?? 'indefinite',
			terminationReason: storedReason,
			terminationMode: storedReason ? deriveTerminationMode(storedReason) : record.termination_mode,
			includeBasicSalary: record.include_basic_salary,
			includeOtherAllowance: record.include_other_allowance,
			includeAccommodationAllowance: record.include_accommodation_allowance,
			includeTravelAllowance: record.include_travel_allowance,
			includeFoodAllowance: record.include_food_allowance,
			unusedLeaveDays: toNumber(record.unused_leave_days),
			unusedTicketCount: toNumber(record.unused_ticket_count),
			ticketAmount: toNumber(record.ticket_amount),
			manualAdditions: toNumber(record.manual_additions),
			manualDeductions: toNumber(record.manual_deductions),
			notes: record.notes ?? '',
			printLanguage: (record.print_language ?? 'bilingual') as PrintLanguage
		};
		calcResult = {
			serviceYears: toNumber(record.calc_service_years),
			monthlyWage: toNumber(record.calc_monthly_wage),
			esobAmount: toNumber(record.calc_esob_amount),
			leaveAmount: toNumber(record.calc_leave_amount),
			ticketAmount: toNumber(record.calc_ticket_amount),
			grossAmount: toNumber(record.calc_gross_amount),
			netAmount: toNumber(record.calc_net_amount)
		};
	}

	function formatCurrency(value: number) {
		return Number(value || 0).toFixed(2);
	}

	// Takes decimal years (e.g. 2.51) and returns a structured breakdown
	function decimalYearsToBreakdown(decimalYears: number): { years: number; months: number; days: number } {
		const totalDays = Math.round(Math.max(0, decimalYears) * 365.25);
		const years = Math.floor(totalDays / 365);
		const remainingAfterYears = totalDays - years * 365;
		const months = Math.floor(remainingAfterYears / 30);
		const days = remainingAfterYears - months * 30;
		return { years, months, days };
	}

	function formatYearText(value: number, lang: 'en' | 'ar' = 'en'): string {
		const { years, months, days } = decimalYearsToBreakdown(Number(value || 0));
		if (lang === 'ar') {
			const parts: string[] = [];
			if (years > 0) parts.push(`${years} سنة`);
			if (months > 0) parts.push(`${months} شهر`);
			parts.push(`${days} يوم`);
			return parts.join(' ');
		}
		const parts: string[] = [];
		if (years > 0) parts.push(`${years} year${years !== 1 ? 's' : ''}`);
		if (months > 0) parts.push(`${months} month${months !== 1 ? 's' : ''}`);
		parts.push(`${days} day${days !== 1 ? 's' : ''}`);
		return parts.join(' ');
	}

	// For UI display always use current locale
	function formatYearTextLocale(value: number): string {
		return formatYearText(value, ($locale === 'ar' ? 'ar' : 'en') as 'en' | 'ar');
	}

	async function printDraft() {
		if (!calcResult) {
			errorMessage = $t('hr.servicesWindow.esobCalculateFirst');
			return;
		}
		const employee = selectedEmployee;
		const dir = draft.printLanguage === 'ar' ? 'rtl' : 'ltr';
		const lang = draft.printLanguage === 'ar' ? 'ar' : 'en';
		const isBilingual = draft.printLanguage === 'bilingual';

		// Issued date/time
		const now = new Date();
		const pad = (n: number) => String(n).padStart(2, '0');
		const issuedDatetime = `${pad(now.getDate())}/${pad(now.getMonth() + 1)}/${now.getFullYear()}  ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;

		// Background template margins
		const sheetPaddingTop = selectedTemplateUrl ? '22%' : '24px';
		const sheetPaddingBottom = selectedTemplateUrl ? '3%' : '24px';

		// Fetch Saudi currency symbol
		let currencyImgTag = '<span style="font-weight:bold;">SAR</span>';
		try {
			const { data: iconData } = await supabase
				.from('app_icons')
				.select('storage_path')
				.eq('icon_key', 'saudi-currency')
				.eq('is_active', true)
				.single();
			if (iconData?.storage_path) {
				const { data: urlData } = supabase.storage.from('app-icons').getPublicUrl(iconData.storage_path);
				if (urlData?.publicUrl) {
					currencyImgTag = `<img src="${urlData.publicUrl}" alt="SAR" class="sar-icon" />`;
				}
			}
		} catch { /* currency icon is optional */ }

		const enBlock = `
			<h2>End of Service Benefits Statement</h2>
			<p><strong>Employee:</strong> ${employee?.name_en ?? employee?.id ?? '-'}</p>
			<p><strong>ID Number:</strong> ${employee?.id_number ?? '-'}</p>
			<p><strong>Service Period:</strong> ${draft.serviceStartDate} to ${draft.serviceEndDate}</p>
			<p><strong>Termination Type:</strong> ${getReasonLabel(draft.terminationReason, 'en')}</p>
			<table>
				<tr><td>Service Years</td><td>${formatYearText(calcResult.serviceYears, 'en')}</td></tr>
				<tr><td>Monthly Wage Used</td><td>${currencyImgTag} ${formatCurrency(calcResult.monthlyWage)}</td></tr>
				<tr><td>ESOB Amount</td><td>${currencyImgTag} ${formatCurrency(calcResult.esobAmount)}</td></tr>
				${Number(calcResult.leaveAmount) !== 0 ? `<tr><td>Unused Leave Payout</td><td>${currencyImgTag} ${formatCurrency(calcResult.leaveAmount)}</td></tr>` : ''}
				${Number(calcResult.ticketAmount) !== 0 ? `<tr><td>Unused Tickets Payout</td><td>${currencyImgTag} ${formatCurrency(calcResult.ticketAmount)}</td></tr>` : ''}
				${Number(draft.manualAdditions || 0) !== 0 ? `<tr><td>Manual Additions</td><td>${currencyImgTag} ${formatCurrency(Number(draft.manualAdditions || 0))}</td></tr>` : ''}
				${Number(draft.manualDeductions || 0) !== 0 ? `<tr><td>Manual Deductions</td><td>${currencyImgTag} ${formatCurrency(Number(draft.manualDeductions || 0))}</td></tr>` : ''}
				<tr><td><strong>Net Payable</strong></td><td><strong>${currencyImgTag} ${formatCurrency(calcResult.netAmount)}</strong></td></tr>
			</table>
		`;

		const arBlock = `
			<h2>بيان مستحقات نهاية الخدمة</h2>
			<p><strong>الموظف:</strong> ${employee?.name_ar ?? employee?.id ?? '-'}</p>
			<p><strong>رقم الهوية:</strong> ${employee?.id_number ?? '-'}</p>
			<p><strong>فترة الخدمة:</strong> ${draft.serviceStartDate} إلى ${draft.serviceEndDate}</p>
			<p><strong>نوع الانتهاء:</strong> ${getReasonLabel(draft.terminationReason, 'ar')}</p>
			<table>
				<tr><td>سنوات الخدمة</td><td>${formatYearText(calcResult.serviceYears, 'ar')}</td></tr>
				<tr><td>الأجر الشهري المستخدم</td><td><span dir="ltr">${currencyImgTag} ${formatCurrency(calcResult.monthlyWage)}</span></td></tr>
				<tr><td>مبلغ نهاية الخدمة</td><td><span dir="ltr">${currencyImgTag} ${formatCurrency(calcResult.esobAmount)}</span></td></tr>
				${Number(calcResult.leaveAmount) !== 0 ? `<tr><td>بدل الإجازة غير المستخدمة</td><td><span dir="ltr">${currencyImgTag} ${formatCurrency(calcResult.leaveAmount)}</span></td></tr>` : ''}
				${Number(calcResult.ticketAmount) !== 0 ? `<tr><td>بدل التذاكر غير المستخدمة</td><td><span dir="ltr">${currencyImgTag} ${formatCurrency(calcResult.ticketAmount)}</span></td></tr>` : ''}
				${Number(draft.manualAdditions || 0) !== 0 ? `<tr><td>إضافات يدوية</td><td><span dir="ltr">${currencyImgTag} ${formatCurrency(Number(draft.manualAdditions || 0))}</span></td></tr>` : ''}
				${Number(draft.manualDeductions || 0) !== 0 ? `<tr><td>استقطاعات يدوية</td><td><span dir="ltr">${currencyImgTag} ${formatCurrency(Number(draft.manualDeductions || 0))}</span></td></tr>` : ''}
				<tr><td><strong>الصافي المستحق</strong></td><td><strong><span dir="ltr">${currencyImgTag} ${formatCurrency(calcResult.netAmount)}</span></strong></td></tr>
			</table>
		`;

		const html = `
			<!doctype html>
			<html lang="${lang}" dir="${dir}">
			<head>
				<meta charset="utf-8" />
				<title>ESOB</title>
				<style>
					body { font-family: Arial, sans-serif; margin: 0; color: #111827; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
					.bg-template { position: fixed; top: 0; left: 0; width: 100%; height: 100%; object-fit: fill; z-index: -1; pointer-events: none; }
					.sheet { max-width: 900px; margin: 0 auto; position: relative; z-index: 1; }
					.doc-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 6px; }
					.issued-line { font-size: 12px; color: #6b7280; text-align: right; margin-bottom: 14px; }
					h1 { margin: 0; }
					h2 { margin: 10px 0; font-size: 20px; }
					table { width: 100%; border-collapse: collapse; margin-top: 10px; }
					td { border: 1px solid #d1d5db; padding: 8px 10px; }
					.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
					.sar-icon { height: 16px; vertical-align: middle; margin-right: 3px; }
					.signatures { margin-top: 60px; display: grid; grid-template-columns: repeat(2, 1fr); gap: 60px 50px; }
					.sig { border-top: 2px solid #111827; padding-top: 12px; }
					.sig-label { font-size: 13px; font-weight: 600; margin-bottom: 60px; }
					.sig-date { font-size: 12px; color: #374151; border-top: 1px solid #9ca3af; padding-top: 6px; margin-top: 4px; }
				</style>
			</head>
			<body>
				${selectedTemplateUrl ? `<img src="${selectedTemplateUrl}" class="bg-template" />` : ''}
				<div class="sheet" style="padding:${sheetPaddingTop} 24px ${sheetPaddingBottom};">
					<div class="doc-header">
						<h1>${isBilingual ? 'ESOB / نهاية الخدمة' : (draft.printLanguage === 'ar' ? 'نهاية الخدمة' : 'ESOB')}</h1>
					</div>
					<div class="issued-line">Issued / إصدار: ${issuedDatetime}</div>
					${isBilingual ? `<div class="grid"><div>${enBlock}</div><div dir="rtl">${arBlock}</div></div>` : (draft.printLanguage === 'ar' ? arBlock : enBlock)}
					<div class="signatures">
						<div class="sig">
							<div class="sig-label">Employee Signature / توقيع الموظف</div>
							<div class="sig-date">Date / التاريخ: ___________________________</div>
						</div>
						<div class="sig">
							<div class="sig-label">HR Prepared By / إعداد الموارد البشرية</div>
							<div class="sig-date">Date / التاريخ: ___________________________</div>
						</div>
						<div class="sig">
							<div class="sig-label">Finance Approval / اعتماد المالية</div>
							<div class="sig-date">Date / التاريخ: ___________________________</div>
						</div>
						<div class="sig">
							<div class="sig-label">Manager Signature / توقيع المدير</div>
							<div class="sig-date">Date / التاريخ: ___________________________</div>
						</div>
					</div>
				</div>
				<script>
					window.onload = () => {
						const imgs = Array.from(document.images);
						if (imgs.length === 0) { window.print(); return; }
						let remaining = imgs.length;
						const done = () => { if (--remaining === 0) window.print(); };
						imgs.forEach(img => { if (img.complete) done(); else { img.onload = done; img.onerror = done; } });
					};
				<\/script>
			</body>
			</html>
		`;

		const printWindow = window.open('', '_blank', 'width=1000,height=800');
		if (!printWindow) return;
		printWindow.document.open();
		printWindow.document.write(html);
		printWindow.document.close();
	}

	function resetBaseForm() {
		baseEditId = null;
		baseRuleNameEn = '';
		baseRuleNameAr = '';
		baseYearsFrom = 0;
		baseYearsTo = '';
		baseMonthsPerYear = 0.5;
	}

	function editBaseRule(rule: BaseRule) {
		baseEditId = rule.id;
		baseRuleNameEn = rule.rule_name_en;
		baseRuleNameAr = rule.rule_name_ar ?? '';
		baseYearsFrom = rule.years_from;
		baseYearsTo = rule.years_to ?? '';
		baseMonthsPerYear = rule.months_per_year;
	}

	async function saveBaseRule() {
		const payload = {
			rule_name_en: baseRuleNameEn.trim() || `Base Rule ${baseYearsFrom}`,
			rule_name_ar: baseRuleNameAr.trim() || null,
			years_from: Number(baseYearsFrom || 0),
			years_to: baseYearsTo === '' ? null : Number(baseYearsTo),
			months_per_year: Number(baseMonthsPerYear || 0),
			is_active: true,
			sort_order: Number(baseYearsFrom || 0)
		};
		if (payload.months_per_year <= 0) {
			errorMessage = $t('hr.servicesWindow.esobRuleValueError');
			return;
		}
		if (baseEditId) {
			const { error } = await supabase.from('hr_esob_base_rules').update(payload).eq('id', baseEditId);
			if (error) {
				errorMessage = error.message;
				return;
			}
		} else {
			const { error } = await supabase.from('hr_esob_base_rules').insert(payload);
			if (error) {
				errorMessage = error.message;
				return;
			}
		}
		resetBaseForm();
		await loadRules();
	}

	async function deleteBaseRule(id: number) {
		const { error } = await supabase.from('hr_esob_base_rules').delete().eq('id', id);
		if (error) {
			errorMessage = error.message;
			return;
		}
		await loadRules();
	}

	function resetResignationForm() {
		resignationEditId = null;
		resignationRuleNameEn = '';
		resignationRuleNameAr = '';
		resignationYearsFrom = 0;
		resignationYearsTo = '';
		resignationFactor = 1;
	}

	function editResignationRule(rule: ResignationRule) {
		resignationEditId = rule.id;
		resignationRuleNameEn = rule.rule_name_en;
		resignationRuleNameAr = rule.rule_name_ar ?? '';
		resignationYearsFrom = rule.years_from;
		resignationYearsTo = rule.years_to ?? '';
		resignationFactor = rule.factor;
	}

	async function saveResignationRule() {
		const payload = {
			rule_name_en: resignationRuleNameEn.trim() || `Resignation Rule ${resignationYearsFrom}`,
			rule_name_ar: resignationRuleNameAr.trim() || null,
			years_from: Number(resignationYearsFrom || 0),
			years_to: resignationYearsTo === '' ? null : Number(resignationYearsTo),
			factor: Number(resignationFactor || 0),
			is_active: true,
			sort_order: Number(resignationYearsFrom || 0)
		};
		if (payload.factor < 0 || payload.factor > 1) {
			errorMessage = $t('hr.servicesWindow.esobFactorRangeError');
			return;
		}
		if (resignationEditId) {
			const { error } = await supabase.from('hr_esob_resignation_factors').update(payload).eq('id', resignationEditId);
			if (error) {
				errorMessage = error.message;
				return;
			}
		} else {
			const { error } = await supabase.from('hr_esob_resignation_factors').insert(payload);
			if (error) {
				errorMessage = error.message;
				return;
			}
		}
		resetResignationForm();
		await loadRules();
	}

	async function deleteResignationRule(id: number) {
		const { error } = await supabase.from('hr_esob_resignation_factors').delete().eq('id', id);
		if (error) {
			errorMessage = error.message;
			return;
		}
		await loadRules();
	}
</script>

<div class="esob-panel">
	<div class="esob-header">
		<div>
			<div class="section-kicker">{$t('hr.servicesWindow.hrServices')}</div>
			<h3>{$t('hr.servicesWindow.esobTitle')}</h3>
		</div>
		<div class="toolbar">
			<button class="btn" on:click={loadAll} disabled={isLoading}>{$t('hr.servicesWindow.refresh')}</button>
			{#if activeTab === 'calculation'}
				<button class="btn primary" on:click={calculateDraft}>{$t('hr.servicesWindow.esobCalculate')}</button>
				<button class="btn primary" on:click={saveRecord} disabled={isSaving}>{isSaving ? $t('common.saving') : $t('hr.servicesWindow.esobSave')}</button>
				<button class="btn" on:click={printDraft}>{$t('hr.servicesWindow.esobPrint')}</button>
			{/if}
		</div>
	</div>

	<div class="tabs">
		<button class="tab-btn" class:active={activeTab === 'calculation'} on:click={() => activeTab = 'calculation'}>
			🧮 {$t('hr.servicesWindow.esobCalculate')}
		</button>
		<button class="tab-btn" class:active={activeTab === 'rules'} on:click={() => activeTab = 'rules'}>
			⚖️ {$t('hr.servicesWindow.esobBaseRules')}
		</button>
	</div>

	{#if errorMessage}
		<div class="error">{errorMessage}</div>
	{/if}

	{#if activeTab === 'calculation'}
	<div class="grid">
		<div class="card employee-card">
			<div class="card-title">{$t('hr.servicesWindow.esobEmployees')}</div>
			<div class="filters">
				<input class="input" type="text" placeholder={$t('hr.servicesWindow.searchByEmployeePlaceholder')} bind:value={search} />
				<label class="checkbox">
					<input type="checkbox" bind:checked={includeInactive} />
					<span>{$t('hr.servicesWindow.esobIncludeInactive')}</span>
				</label>
			</div>
			<div class="employee-list">
				{#if filteredEmployees.length === 0}
					<div class="empty">{$t('hr.servicesWindow.noEligibleEmployees')}</div>
				{:else}
					{#each filteredEmployees as employee}
						<button class="employee-row" class:selected={employee.id === selectedEmployeeId} on:click={() => selectEmployee(employee.id)}>
							<div class="row-main">{localizedText(employee.name_en, employee.name_ar, employee.id)}</div>
							<div class="row-sub">{employee.id} | {employee.employment_status ?? '-'}</div>
						</button>
					{/each}
				{/if}
			</div>
		</div>

		<div class="card form-card">
			<div class="card-title">{$t('hr.servicesWindow.esobCalculator')}</div>
			<div class="form-grid">
				<label>
					<span>{$t('hr.servicesWindow.employeeId')}</span>
					<input class="input" value={draft.employeeId} readonly />
				</label>
				<label>
					<span>{$t('hr.servicesWindow.startDate')}</span>
					<input class="input" type="date" bind:value={draft.serviceStartDate} />
				</label>
				<label>
					<span>{$t('hr.servicesWindow.endDate')}</span>
					<input class="input" type="date" bind:value={draft.serviceEndDate} />
				</label>
				<label>
					<span>{$t('hr.servicesWindow.esobContractType')}</span>
					<select class="input" bind:value={draft.contractType} on:change={() => {
						// If switching to indefinite, clear definite-only reason
						if (draft.contractType === 'indefinite' && getReasonInfo(draft.terminationReason)?.definiteOnly) {
							draft.terminationReason = '';
						}
					}}>
						<option value="indefinite">{$t('hr.servicesWindow.esobContractIndefinite')}</option>
						<option value="definite">{$t('hr.servicesWindow.esobContractDefinite')}</option>
					</select>
				</label>
				<label style="grid-column: 1 / -1;">
					<span>{$t('hr.servicesWindow.esobTerminationReason')}</span>
					<select class="input" bind:value={draft.terminationReason}>
						<option value="">— {$t('hr.servicesWindow.esobSelectReason')} —</option>
						{#each TERMINATION_REASONS.filter(r => !r.definiteOnly || draft.contractType === 'definite') as reason}
							<option value={reason.value}>{$locale === 'ar' ? reason.ar : reason.en}</option>
						{/each}
					</select>
				</label>
			</div>

			<div class="section-subtitle">{$t('hr.servicesWindow.esobSalaryComponents')}</div>
			<div class="checks">
				<label class="checkbox"><input type="checkbox" bind:checked={draft.includeBasicSalary} /><span>{$t('hr.servicesWindow.esobBasicSalary')}</span></label>
				<label class="checkbox"><input type="checkbox" bind:checked={draft.includeOtherAllowance} /><span>{$t('hr.servicesWindow.esobOtherAllowance')}</span></label>
				<label class="checkbox"><input type="checkbox" bind:checked={draft.includeAccommodationAllowance} /><span>{$t('hr.servicesWindow.esobAccommodationAllowance')}</span></label>
				<label class="checkbox"><input type="checkbox" bind:checked={draft.includeTravelAllowance} /><span>{$t('hr.servicesWindow.esobTravelAllowance')}</span></label>
				<label class="checkbox"><input type="checkbox" bind:checked={draft.includeFoodAllowance} /><span>{$t('hr.servicesWindow.esobFoodAllowance')}</span></label>
			</div>

			<div class="form-grid">
				<label>
					<span>{$t('hr.servicesWindow.esobUnusedLeaveDays')}</span>
					<input class="input" type="number" min="0" step="1" bind:value={draft.unusedLeaveDays} />
				</label>
				<label>
					<span>{$t('hr.servicesWindow.esobUnusedTicketCount')}</span>
					<input class="input" type="number" min="0" step="1" bind:value={draft.unusedTicketCount} />
				</label>
				<label>
					<span>{$t('hr.servicesWindow.esobTicketAmount')}</span>
					<input class="input" type="number" min="0" step="0.01" bind:value={draft.ticketAmount} />
				</label>
				<label>
					<span>{$t('hr.servicesWindow.esobManualAdditions')}</span>
					<input class="input" type="number" min="0" step="0.01" bind:value={draft.manualAdditions} />
				</label>
				<label>
					<span>{$t('hr.servicesWindow.esobManualDeductions')}</span>
					<input class="input" type="number" min="0" step="0.01" bind:value={draft.manualDeductions} />
				</label>
				<label>
					<span>{$t('hr.servicesWindow.esobPrintLanguage')}</span>
					<select class="input" bind:value={draft.printLanguage}>
						<option value="en">{$t('hr.servicesWindow.esobPrintEnglish')}</option>
						<option value="ar">{$t('hr.servicesWindow.esobPrintArabic')}</option>
						<option value="bilingual">{$t('hr.servicesWindow.esobPrintBilingual')}</option>
					</select>
				</label>
			</div>

			<label>
				<span>{$t('hr.servicesWindow.notes')}</span>
				<textarea class="input" rows="2" bind:value={draft.notes}></textarea>
			</label>

			<div class="template-section">
				<div class="section-subtitle">{$t('hr.servicesWindow.esobPrintTemplate')}</div>
				<div class="template-row">
					<select class="input" bind:value={selectedTemplateId} on:change={onTemplateChange}>
						<option value="">{$t('hr.servicesWindow.esobNoTemplate')}</option>
						{#each backgroundTemplates as tpl}
							<option value={tpl.id}>{tpl.name}</option>
						{/each}
					</select>
					<button class="btn" on:click={() => { showTemplateUpload = !showTemplateUpload; }}>
						{showTemplateUpload ? $t('hr.servicesWindow.esobCancelUpload') : $t('hr.servicesWindow.esobUpload')}
					</button>
				</div>
				{#if selectedTemplateUrl}
					<div class="template-preview">
						<img src={selectedTemplateUrl} alt="template preview" />
					</div>
				{/if}
				{#if showTemplateUpload}
					<div class="upload-form">
						<input class="input" type="text" placeholder={$t('hr.servicesWindow.esobTemplateName')} bind:value={templateUploadName} />
						<input class="input" type="file" accept="image/png,image/jpeg,image/webp" bind:this={templateFileInput} on:change={onTemplateFileChange} />
						<button class="btn primary" on:click={uploadTemplate} disabled={isUploadingTemplate}>
							{isUploadingTemplate ? $t('hr.servicesWindow.esobUploading') : $t('hr.servicesWindow.esobSaveTemplate')}
						</button>
					</div>
				{/if}
			</div>

			{#if calcResult}
				<div class="result-grid">
					<div>{$t('hr.servicesWindow.esobServiceYears')}: <strong>{formatYearTextLocale(calcResult.serviceYears)}</strong></div>
					<div>{$t('hr.servicesWindow.esobMonthlyWage')}: <strong>{formatCurrency(calcResult.monthlyWage)}</strong></div>
					<div class="esob-amount-cell">{$t('hr.servicesWindow.esobAmount')}: <input type="number" class="esob-override-input" bind:value={calcResult.esobAmount} on:input={recomputeFromEsob} step="0.01" min="0" /></div>
					<div>{$t('hr.servicesWindow.esobLeavePayout')}: <strong>{formatCurrency(calcResult.leaveAmount)}</strong></div>
					<div>{$t('hr.servicesWindow.esobTicketPayout')}: <strong>{formatCurrency(calcResult.ticketAmount)}</strong></div>
					<div>{$t('hr.servicesWindow.esobGross')}: <strong>{formatCurrency(calcResult.grossAmount)}</strong></div>
					<div class="net">{$t('hr.servicesWindow.esobNet')}: <strong>{formatCurrency(calcResult.netAmount)}</strong></div>
				</div>
			{/if}

			<div class="esob-disclaimer">
				<span class="disclaimer-icon">⚠️</span>
				<div class="disclaimer-text">
					<strong>{$t('hr.servicesWindow.esobDisclaimerTitle')}</strong>
					{$t('hr.servicesWindow.esobDisclaimerBody')}
					<a class="disclaimer-link" href="https://www.hrsd.gov.sa/en/ministry-services/services/end-service-benefit-calculator" target="_blank" rel="noopener noreferrer">
						🔗 {$t('hr.servicesWindow.esobDisclaimerBtn')}
					</a>
				</div>
			</div>
		</div>
	</div>

	<div class="card records-card">
		<div class="card-title">{$t('hr.servicesWindow.esobSavedRecords')}</div>
		{#if records.length === 0}
			<div class="empty">{$t('hr.servicesWindow.esobNoSavedRecords')}</div>
		{:else}
			<table class="table">
				<thead>
					<tr>
						<th>{$t('hr.servicesWindow.sn')}</th>
						<th>{$t('hr.servicesWindow.employeeId')}</th>
						<th>{$t('hr.servicesWindow.esobServiceYears')}</th>
						<th>{$t('hr.servicesWindow.esobNet')}</th>
						<th>{$t('hr.servicesWindow.date')}</th>
						<th></th>
					</tr>
				</thead>
				<tbody>
					{#each records as record, index}
						<tr>
							<td>{index + 1}</td>
							<td>{record.employee_id}</td>
							<td>{formatYearTextLocale(record.calc_service_years)}</td>
							<td>{formatCurrency(record.calc_net_amount)}</td>
							<td>{record.updated_at?.slice(0, 10)}</td>
							<td><button class="mini" on:click={() => editRecord(record)}>{$t('hr.servicesWindow.manage')}</button></td>
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	</div>
	{:else if activeTab === 'rules'}
	<div class="grid bottom-grid">
		<div class="card rules-card">
			<div class="card-title">{$t('hr.servicesWindow.esobBaseRules')}</div>
			<table class="table">
				<thead><tr><th>{$t('hr.servicesWindow.ruleName')}</th><th>{$t('hr.servicesWindow.from')}</th><th>{$t('hr.servicesWindow.to')}</th><th>{$t('hr.servicesWindow.esobMonthsPerYear')}</th><th></th></tr></thead>
				<tbody>
					{#each baseRules as rule}
						<tr>
							<td>{localizedText(rule.rule_name_en, rule.rule_name_ar)}</td>
							<td>{rule.years_from}</td>
							<td>{rule.years_to ?? '∞'}</td>
							<td>{rule.months_per_year}</td>
							<td><button class="mini" on:click={() => editBaseRule(rule)}>{$t('hr.servicesWindow.manage')}</button> <button class="mini danger" on:click={() => deleteBaseRule(rule.id)}>{$t('hr.servicesWindow.remove')}</button></td>
						</tr>
					{/each}
				</tbody>
			</table>
			<div class="rule-form">
				<input class="input" placeholder={$t('hr.servicesWindow.ruleNameEn')} bind:value={baseRuleNameEn} />
				<input class="input" placeholder={$t('hr.servicesWindow.ruleNameAr')} bind:value={baseRuleNameAr} />
				<input class="input" type="number" min="0" step="0.1" bind:value={baseYearsFrom} />
				<input class="input" type="number" min="0" step="0.1" bind:value={baseYearsTo} placeholder={$t('hr.servicesWindow.esobInfinite')} />
				<input class="input" type="number" min="0" step="0.01" bind:value={baseMonthsPerYear} />
				<button class="btn" on:click={saveBaseRule}>{baseEditId ? $t('hr.servicesWindow.esobUpdateRule') : $t('hr.servicesWindow.esobAddRule')}</button>
				<button class="btn" on:click={resetBaseForm}>{$t('hr.servicesWindow.reset')}</button>
			</div>
		</div>

		<div class="card rules-card">
			<div class="card-title">{$t('hr.servicesWindow.esobResignationRules')}</div>
			<table class="table">
				<thead><tr><th>{$t('hr.servicesWindow.ruleName')}</th><th>{$t('hr.servicesWindow.from')}</th><th>{$t('hr.servicesWindow.to')}</th><th>{$t('hr.servicesWindow.esobFactor')}</th><th></th></tr></thead>
				<tbody>
					{#each resignationRules as rule}
						<tr>
							<td>{localizedText(rule.rule_name_en, rule.rule_name_ar)}</td>
							<td>{rule.years_from}</td>
							<td>{rule.years_to ?? '∞'}</td>
							<td>{rule.factor}</td>
							<td><button class="mini" on:click={() => editResignationRule(rule)}>{$t('hr.servicesWindow.manage')}</button> <button class="mini danger" on:click={() => deleteResignationRule(rule.id)}>{$t('hr.servicesWindow.remove')}</button></td>
						</tr>
					{/each}
				</tbody>
			</table>
			<div class="rule-form">
				<input class="input" placeholder={$t('hr.servicesWindow.ruleNameEn')} bind:value={resignationRuleNameEn} />
				<input class="input" placeholder={$t('hr.servicesWindow.ruleNameAr')} bind:value={resignationRuleNameAr} />
				<input class="input" type="number" min="0" step="0.1" bind:value={resignationYearsFrom} />
				<input class="input" type="number" min="0" step="0.1" bind:value={resignationYearsTo} placeholder={$t('hr.servicesWindow.esobInfinite')} />
				<input class="input" type="number" min="0" max="1" step="0.01" bind:value={resignationFactor} />
				<button class="btn" on:click={saveResignationRule}>{resignationEditId ? $t('hr.servicesWindow.esobUpdateRule') : $t('hr.servicesWindow.esobAddRule')}</button>
				<button class="btn" on:click={resetResignationForm}>{$t('hr.servicesWindow.reset')}</button>
			</div>
		</div>
	</div>
	{/if}
</div>

<style>
	.esob-panel {
		display: grid;
		gap: 12px;
	}
	.esob-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 12px;
	}
	.section-kicker {
		font-size: 0.72rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: #94a3b8;
		margin-bottom: 4px;
	}
	h3 {
		margin: 0;
		font-size: 1.05rem;
		color: #1e293b;
	}
	.toolbar {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}
	.tabs {
		display: flex;
		gap: 6px;
		border-bottom: 2px solid rgba(148, 163, 184, 0.25);
		padding-bottom: 2px;
	}
	.tab-btn {
		padding: 7px 18px;
		border-radius: 10px 10px 0 0;
		border: 1px solid rgba(148, 163, 184, 0.25);
		border-bottom: none;
		background: rgba(241, 245, 249, 0.8);
		color: #64748b;
		font-size: 0.82rem;
		font-weight: 700;
		cursor: pointer;
		transition: background 0.15s;
	}
	.tab-btn.active {
		background: rgba(255, 255, 255, 0.97);
		color: #0f172a;
		border-color: rgba(148, 163, 184, 0.45);
		border-bottom: 2px solid #fff;
		margin-bottom: -2px;
	}
	.btn {
		padding: 8px 12px;
		border-radius: 10px;
		border: 1px solid rgba(148, 163, 184, 0.3);
		background: rgba(255, 255, 255, 0.88);
		color: #334155;
		font-size: 0.8rem;
		font-weight: 700;
		cursor: pointer;
	}
	.btn.primary {
		background: linear-gradient(135deg, #ec4899, #f97316);
		color: #fff;
		border: none;
	}
	.error {
		padding: 10px 12px;
		border-radius: 10px;
		border: 1px solid rgba(239, 68, 68, 0.3);
		background: rgba(254, 226, 226, 0.8);
		color: #b91c1c;
		font-size: 0.82rem;
	}
	.grid {
		display: grid;
		grid-template-columns: 320px minmax(0, 1fr);
		gap: 12px;
	}
	.bottom-grid {
		grid-template-columns: repeat(2, minmax(0, 1fr));
	}
	.card {
		padding: 12px;
		border-radius: 14px;
		border: 1px solid rgba(148, 163, 184, 0.22);
		background: rgba(255, 255, 255, 0.88);
		display: grid;
		gap: 10px;
	}
	.card-title {
		font-size: 0.88rem;
		font-weight: 800;
		color: #0f172a;
	}
	.filters {
		display: grid;
		gap: 8px;
	}
	.employee-list {
		max-height: 380px;
		overflow: auto;
		display: grid;
		gap: 6px;
	}
	.employee-row {
		text-align: left;
		padding: 8px 10px;
		border-radius: 10px;
		border: 1px solid rgba(148, 163, 184, 0.22);
		background: rgba(248, 250, 252, 0.9);
		cursor: pointer;
	}
	.employee-row.selected {
		border-color: rgba(14, 165, 233, 0.55);
		background: rgba(224, 242, 254, 0.9);
	}
	.row-main {
		font-size: 0.82rem;
		font-weight: 700;
		color: #0f172a;
	}
	.row-sub {
		font-size: 0.72rem;
		color: #64748b;
		margin-top: 2px;
	}
	.input {
		padding: 8px 10px;
		border-radius: 10px;
		border: 1px solid rgba(148, 163, 184, 0.3);
		background: #fff;
		font-size: 0.82rem;
		width: 100%;
		box-sizing: border-box;
	}
	.form-grid {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: 8px;
	}
	label {
		display: grid;
		gap: 4px;
		font-size: 0.72rem;
		font-weight: 700;
		color: #475569;
	}
	.section-subtitle {
		font-size: 0.78rem;
		font-weight: 800;
		color: #0f172a;
	}
	.checks {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 8px;
	}
	.checkbox {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 0.78rem;
		font-weight: 600;
		color: #334155;
	}
	.result-grid {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 8px;
		padding: 10px;
		border-radius: 10px;
		border: 1px solid rgba(236, 72, 153, 0.25);
		background: rgba(253, 242, 248, 0.65);
		font-size: 0.8rem;
	}
	.result-grid .net {
		grid-column: span 3;
		font-size: 0.9rem;
		color: #9d174d;
	}
	.esob-amount-cell {
		display: flex;
		align-items: center;
		gap: 6px;
		flex-wrap: wrap;
	}
	.esob-override-input {
		background: #1e293b;
		border: 1px solid #4ade80;
		border-radius: 4px;
		color: #f1f5f9;
		padding: 2px 6px;
		width: 100px;
		font-size: 0.85rem;
		font-weight: 700;
	}
	.esob-override-input:focus {
		outline: none;
		border-color: #86efac;
	}
	.esob-disclaimer {
		display: flex;
		align-items: flex-start;
		gap: 10px;
		margin-top: 16px;
		padding: 10px 14px;
		background: #7f1d1d;
		border: 1px solid #991b1b;
		border-radius: 8px;
	}
	.disclaimer-icon {
		font-size: 1.1rem;
		flex-shrink: 0;
		margin-top: 1px;
	}
	.disclaimer-text {
		font-size: 0.75rem;
		color: #fef2f2;
		line-height: 1.55;
	}
	.disclaimer-text strong {
		color: #fca5a5;
		display: block;
		margin-bottom: 2px;
	}
	.disclaimer-link {
		display: inline-block;
		margin-top: 8px;
		padding: 5px 14px;
		background: #1e40af;
		color: #fff;
		text-decoration: none;
		font-weight: 600;
		font-size: 0.75rem;
		border-radius: 6px;
		cursor: pointer;
		border: 1px solid #3b82f6;
	}
	.disclaimer-link:hover {
		background: #1d4ed8;
		border-color: #60a5fa;
	}
	.table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.78rem;
	}
	.table th,
	.table td {
		padding: 8px;
		border-bottom: 1px solid rgba(148, 163, 184, 0.18);
		text-align: left;
	}
	.table th {
		font-size: 0.68rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #64748b;
	}
	.rule-form {
		display: grid;
		grid-template-columns: 1.4fr 1.4fr repeat(3, minmax(0, 1fr)) auto auto;
		gap: 8px;
	}
	.mini {
		padding: 4px 8px;
		border-radius: 999px;
		border: 1px solid rgba(148, 163, 184, 0.35);
		background: #fff;
		font-size: 0.68rem;
		font-weight: 700;
		cursor: pointer;
	}
	.mini.danger {
		border-color: rgba(239, 68, 68, 0.35);
		color: #b91c1c;
	}
	.records-card {
		overflow: auto;
	}
	.template-section {
		display: grid;
		gap: 8px;
	}
	.template-row {
		display: flex;
		gap: 8px;
		align-items: center;
	}
	.template-row .input {
		flex: 1;
	}
	.template-preview {
		border-radius: 8px;
		overflow: hidden;
		border: 1px solid rgba(148, 163, 184, 0.3);
		max-height: 120px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f8fafc;
	}
	.template-preview img {
		max-height: 120px;
		width: 100%;
		object-fit: cover;
	}
	.upload-form {
		display: grid;
		gap: 6px;
	}
	.empty {
		padding: 10px;
		border-radius: 10px;
		border: 1px dashed rgba(148, 163, 184, 0.3);
		color: #64748b;
		font-size: 0.8rem;
	}

	@media (max-width: 1200px) {
		.grid {
			grid-template-columns: 1fr;
		}
		.bottom-grid {
			grid-template-columns: 1fr;
		}
		.form-grid {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
		.checks {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
		.rule-form {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
		.result-grid {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
		.result-grid .net {
			grid-column: span 2;
		}
	}

	@media (max-width: 700px) {
		.toolbar {
			width: 100%;
		}
		.toolbar .btn {
			flex: 1;
		}
		.form-grid,
		.checks,
		.result-grid,
		.rule-form {
			grid-template-columns: 1fr;
		}
		.result-grid .net {
			grid-column: span 1;
		}
	}
</style>
