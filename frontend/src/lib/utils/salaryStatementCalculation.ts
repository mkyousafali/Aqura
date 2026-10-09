export const SALARY_STATEMENT_CALCULATION_VERSION = 2;
export const SALARY_DIVISOR_DAYS = 30;
export const SALARY_DIVISOR_HOURS = 240;

export const EMPLOYED_STATUSES = new Set(['Job (With Finger)', 'Remote Job', 'Vacation']);

export interface StatusPeriod {
	status: string;
	effective_from?: string | null;
	effective_to?: string | null;
}

export interface EmploymentEligibility {
	eligibleDates: string[];
	eligibleCalendarDays: number;
	fullPeriodEmployment: boolean;
	prorationFactor: number;
}

export interface SalaryEarnings {
	basic: number;
	other: number;
	accommodation: number;
	travel: number;
	food: number;
}

export interface SalaryDeductionsInput {
	gosi?: number;
	lateMinutes?: number;
	underWorkedMinutes?: number;
	incompleteDays?: number;
	unapprovedDays?: number;
	lateOverride?: number;
	underWorkedOverride?: number;
	incompleteOverride?: number;
	unapprovedOverride?: number;
	posShortage?: number;
	salaryAdvance?: number;
	loan?: number;
	penalties?: number;
	other?: number;
	foodDeductionActive?: boolean;
}

export interface SalaryCalculationInput {
	earnings: SalaryEarnings;
	paymentModes?: Partial<Record<keyof SalaryEarnings, string>>;
	eligibleCalendarDays: number;
	fullPeriodEmployment: boolean;
	deductions?: SalaryDeductionsInput;
}

function ymdToDayNumber(value: string): number {
	const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
	if (!match) throw new Error(`Invalid date: ${value}`);
	return Math.floor(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])) / 86400000);
}

function dayNumberToYmd(value: number): string {
	return new Date(value * 86400000).toISOString().slice(0, 10);
}

export function enumerateDates(start: string, end: string): string[] {
	const first = ymdToDayNumber(start);
	const last = ymdToDayNumber(end);
	if (last < first) return [];
	const dates: string[] = [];
	for (let day = first; day <= last; day++) dates.push(dayNumberToYmd(day));
	return dates;
}

export function isPayrollPeriod(start: string, end: string): boolean {
	const dates = enumerateDates(start, end);
	if (!dates.length || start.slice(8) !== '25' || end.slice(8) !== '24') return false;
	const [sy, sm] = start.split('-').map(Number);
	const expectedEndMonth = sm === 12 ? 1 : sm + 1;
	const expectedEndYear = sm === 12 ? sy + 1 : sy;
	const [ey, em] = end.split('-').map(Number);
	return ey === expectedEndYear && em === expectedEndMonth;
}

export function getEmploymentEligibility(args: {
	periodStart: string;
	periodEnd: string;
	joinDate?: string | null;
	statusPeriods?: StatusPeriod[];
	currentStatus?: string | null;
	currentStatusEffectiveDate?: string | null;
}): EmploymentEligibility {
	const periodDates = enumerateDates(args.periodStart, args.periodEnd);
	const periods = args.statusPeriods || [];
	const hasUsableHistory = periods.some(period => period.effective_from || period.effective_to);
	const eligibleDates = periodDates.filter(date => {
		if (args.joinDate && date < args.joinDate) return false;
		if (hasUsableHistory) {
			return periods.some(period =>
				EMPLOYED_STATUSES.has(period.status) &&
				(!period.effective_from || period.effective_from <= date) &&
				(!period.effective_to || period.effective_to >= date)
			);
		}
		if (args.currentStatus === 'Resigned' && args.currentStatusEffectiveDate && date >= args.currentStatusEffectiveDate) return false;
		return EMPLOYED_STATUSES.has(args.currentStatus || '') || args.currentStatus === 'Resigned';
	});
	const fullPeriodEmployment = periodDates.length > 0 && eligibleDates.length === periodDates.length;
	return {
		eligibleDates,
		eligibleCalendarDays: eligibleDates.length,
		fullPeriodEmployment,
		prorationFactor: fullPeriodEmployment ? 1 : Math.min(eligibleDates.length / SALARY_DIVISOR_DAYS, 1)
	};
}

const amount = (value: unknown) => Number(value) || 0;
const money = (value: number) => Math.round((value + Number.EPSILON) * 100) / 100;

export function calculateSalaryStatement(input: SalaryCalculationInput) {
	const factor = input.fullPeriodEmployment ? 1 : Math.min(Math.max(input.eligibleCalendarDays, 0) / SALARY_DIVISOR_DAYS, 1);
	const monthly = {
		basic: amount(input.earnings.basic),
		other: amount(input.earnings.other),
		accommodation: amount(input.earnings.accommodation),
		travel: amount(input.earnings.travel),
		food: amount(input.earnings.food)
	};
	const prorated = {
		basic: monthly.basic * factor,
		other: monthly.other * factor,
		accommodation: monthly.accommodation * factor,
		travel: monthly.travel * factor,
		food: monthly.food * factor
	};
	const monthlyGross = Object.values(monthly).reduce((sum, value) => sum + value, 0);
	const gross = Math.min(monthlyGross, Object.values(prorated).reduce((sum, value) => sum + value, 0));
	const hourlyRate = monthlyGross / SALARY_DIVISOR_HOURS;
	const d = input.deductions || {};
	const deductions = {
		gosi: amount(d.gosi),
		late: d.lateOverride !== undefined ? amount(d.lateOverride) : amount(d.lateMinutes) / 60 * hourlyRate,
		underWorked: d.underWorkedOverride !== undefined ? amount(d.underWorkedOverride) : amount(d.underWorkedMinutes) / 60 * hourlyRate,
		incomplete: d.incompleteOverride !== undefined ? amount(d.incompleteOverride) : amount(d.incompleteDays) * 8 * hourlyRate,
		unapprovedLeave: d.unapprovedOverride !== undefined ? amount(d.unapprovedOverride) : amount(d.unapprovedDays) * 8 * hourlyRate,
		posShortage: amount(d.posShortage),
		salaryAdvance: amount(d.salaryAdvance),
		loan: amount(d.loan),
		penalties: amount(d.penalties),
		other: amount(d.other),
		food: d.foodDeductionActive ? prorated.food : 0
	};
	const totalDeductions = Object.values(deductions).reduce((sum, value) => sum + value, 0);
	const netSalary = gross - totalDeductions;
	const modes = input.paymentModes || {};
	let grossBank = 0;
	let grossCash = 0;
	for (const key of Object.keys(prorated) as Array<keyof SalaryEarnings>) {
		if (key === 'food' && d.foodDeductionActive) continue;
		if ((modes[key] || 'Bank').toLowerCase() === 'cash') grossCash += prorated[key];
		else grossBank += prorated[key];
	}
	const nonFoodDeductions = totalDeductions - deductions.food;
	const fromBank = Math.min(nonFoodDeductions, grossBank);
	const netBank = Math.max(0, grossBank - fromBank);
	const netCash = Math.max(0, grossCash - (nonFoodDeductions - fromBank));
	return {
		calculationVersion: SALARY_STATEMENT_CALCULATION_VERSION,
		eligibleCalendarDays: Math.max(0, input.eligibleCalendarDays),
		fullPeriodEmployment: input.fullPeriodEmployment,
		prorationFactor: factor,
		monthlyEarnings: monthly,
		proratedEarnings: Object.fromEntries(Object.entries(prorated).map(([key, value]) => [key, money(value)])) as unknown as SalaryEarnings,
		monthlyGross: money(monthlyGross),
		gross: money(gross),
		hourlyRate,
		deductions: Object.fromEntries(Object.entries(deductions).map(([key, value]) => [key, money(value)])) as typeof deductions,
		totalDeductions: money(totalDeductions),
		netSalary: money(netSalary),
		netBank: money(netBank),
		netCash: money(netCash)
	};
}
