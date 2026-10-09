import { describe, expect, it } from 'vitest';
import { calculateSalaryStatement, getEmploymentEligibility, isPayrollPeriod } from './salaryStatementCalculation';

const monthly = { basic: 2400, other: 300, accommodation: 150, travel: 90, food: 60 };
const status = (from: string, to: string | null, value = 'Job (With Finger)') => ({ status: value, effective_from: from, effective_to: to });

describe('salary statement employment eligibility', () => {
	it.each([
		['2025-01-25', '2025-02-24', 31],
		['2025-02-25', '2025-03-24', 28],
		['2024-02-25', '2024-03-24', 29],
		['2025-04-25', '2025-05-24', 30]
	])('recognizes the 25th-24th period %s to %s', (start, end, days) => {
		expect(isPayrollPeriod(start, end)).toBe(true);
		const result = getEmploymentEligibility({ periodStart: start, periodEnd: end, joinDate: start, currentStatus: 'Job (With Finger)' });
		expect(result.eligibleCalendarDays).toBe(days);
		expect(result.fullPeriodEmployment).toBe(true);
		expect(result.prorationFactor).toBe(1);
	});

	it('counts joining and resignation boundaries without counting inactive dates', () => {
		const result = getEmploymentEligibility({
			periodStart: '2025-04-25', periodEnd: '2025-05-24', joinDate: '2025-05-01',
			statusPeriods: [status('2025-05-01', '2025-05-09'), status('2025-05-10', null, 'Resigned')]
		});
		expect(result.eligibleDates).toEqual(['2025-05-01','2025-05-02','2025-05-03','2025-05-04','2025-05-05','2025-05-06','2025-05-07','2025-05-08','2025-05-09']);
	});

	it('unions rejoining intervals and excludes the resignation gap', () => {
		const result = getEmploymentEligibility({
			periodStart: '2025-04-25', periodEnd: '2025-05-24', joinDate: '2025-04-25',
			statusPeriods: [status('2025-04-25', '2025-04-30'), status('2025-05-01', '2025-05-09', 'Resigned'), status('2025-05-10', null, 'Remote Job')]
		});
		expect(result.eligibleCalendarDays).toBe(21);
		expect(result.eligibleDates).not.toContain('2025-05-05');
	});

	it('keeps job, remote and vacation transitions continuously eligible', () => {
		const result = getEmploymentEligibility({
			periodStart: '2025-04-25', periodEnd: '2025-05-24', joinDate: '2025-04-25',
			statusPeriods: [status('2025-04-25', '2025-05-02'), status('2025-05-03', '2025-05-10', 'Remote Job'), status('2025-05-11', null, 'Vacation')]
		});
		expect(result.fullPeriodEmployment).toBe(true);
	});
});

describe('salary statement calculation', () => {
	it('pays a full salary for full employment in a 28-day period', () => {
		expect(calculateSalaryStatement({ earnings: monthly, eligibleCalendarDays: 28, fullPeriodEmployment: true }).gross).toBe(3000);
	});

	it.each([[1, 100], [27, 2700], [29, 2900], [30, 3000], [31, 3000]])('uses the fixed divisor and cap for %i eligible days', (days, expected) => {
		expect(calculateSalaryStatement({ earnings: monthly, eligibleCalendarDays: days, fullPeriodEmployment: false }).gross).toBe(expected);
	});

	it('keeps excluded employment days out of absence deductions', () => {
		const result = calculateSalaryStatement({ earnings: monthly, eligibleCalendarDays: 15, fullPeriodEmployment: false, deductions: { unapprovedDays: 0 } });
		expect(result.gross).toBe(1500);
		expect(result.deductions.unapprovedLeave).toBe(0);
	});

	it('deducts a genuine eligible absence exactly once', () => {
		const result = calculateSalaryStatement({ earnings: monthly, eligibleCalendarDays: 15, fullPeriodEmployment: false, deductions: { unapprovedDays: 1 } });
		expect(result.gross).toBe(1500);
		expect(result.deductions.unapprovedLeave).toBe(100);
		expect(result.netSalary).toBe(1400);
	});

	it('uses the same gross calculation regardless of fingerprint or remote attendance', () => {
		const a = calculateSalaryStatement({ earnings: monthly, eligibleCalendarDays: 12, fullPeriodEmployment: false });
		const b = calculateSalaryStatement({ earnings: monthly, eligibleCalendarDays: 12, fullPeriodEmployment: false });
		expect(a).toEqual(b);
	});

	it('prorates earning components and keeps bank/cash distribution consistent', () => {
		const result = calculateSalaryStatement({
			earnings: monthly, eligibleCalendarDays: 15, fullPeriodEmployment: false,
			paymentModes: { basic: 'Bank', other: 'Cash', accommodation: 'Bank', travel: 'Cash', food: 'Bank' },
			deductions: { gosi: 50 }
		});
		expect(result.proratedEarnings).toEqual({ basic: 1200, other: 150, accommodation: 75, travel: 45, food: 30 });
		expect(result.netSalary).toBe(1450);
		expect(result.netBank + result.netCash).toBe(result.netSalary);
	});

	it('prorates a food deduction with the food earning', () => {
		const result = calculateSalaryStatement({ earnings: monthly, eligibleCalendarDays: 15, fullPeriodEmployment: false, deductions: { foodDeductionActive: true } });
		expect(result.deductions.food).toBe(30);
	});
});
