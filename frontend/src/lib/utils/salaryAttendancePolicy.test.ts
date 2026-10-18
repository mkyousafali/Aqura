import { describe, expect, it } from 'vitest';
import { buildSalaryAttendance } from './salaryAttendancePolicy';
import { calculateSalaryStatement } from './salaryStatementCalculation';

const dates = ['2026-10-05', '2026-10-06', '2026-10-07', '2026-10-08'];
const base = () => ({
  dates, eligibleDates: dates, rows: [] as any[], statusPeriods: [] as any[],
  currentStatus: 'Job (With Finger)', leaves: [] as any[], weeklyOffs: [] as any[], holidayDates: [] as string[]
});
const row = (date: string, status = 'Absent', worked = 0) => ({
  shift_date: date, status, worked_minutes: worked, late_minutes: 0, under_minutes: 0,
  shift_start_time: '07:00:00', shift_end_time: '19:00:00'
});

describe('new salary analysis attendance policy', () => {
  it('credits EMP46 remote days before his change to fingerprint employment', () => {
    const result = buildSalaryAttendance({ ...base(), rows: dates.map(date => row(date)), statusPeriods: [
      { status: 'Remote Job', effective_from: '2024-03-07', effective_to: '2026-10-06' },
      { status: 'Job (With Finger)', effective_from: '2026-10-07', effective_to: null }
    ] });
    expect(result.totalWorkedDays).toBe(2);
    expect(result.totalWorkedMinutes).toBe(0);
    expect(result.totalUnapprovedDaysOff).toBe(2);
    expect(result.dayByDay['2026-10-06'].status).toBe('Worked');
    expect(result.dayByDay['2026-10-07'].status).toBe('Absent');
  });

  it('retains earlier fingerprint deductions when the employee is now remote', () => {
    const result = buildSalaryAttendance({ ...base(), currentStatus: 'Remote Job',
      rows: [row(dates[0]), { ...row(dates[1], 'Check-Out Missing'), check_in_time: '07:20:00', late_minutes: 15 }],
      statusPeriods: [
        { status: 'Job (With Finger)', effective_from: '2020-01-01', effective_to: dates[1] },
        { status: 'Remote Job', effective_from: dates[2], effective_to: null }
      ]
    });
    expect(result.totalIncompleteDays).toBe(1);
    expect(result.totalUnapprovedDaysOff).toBe(1);
    expect(result.totalLateMinutes).toBe(15);
    expect(result.totalWorkedDays).toBe(2);
  });

  it.each(['approved', 'rejected'])('follows the current %s leave decision even when analysed status is stale', approval => {
    const result = buildSalaryAttendance({ ...base(), currentStatus: 'Remote Job',
      rows: [row(dates[0], 'Rejected-Deducted'), row(dates[1], 'Worked')],
      leaves: [
        { day_off_date: dates[0], approval_status: approval, is_deductible_on_salary: false },
        { day_off_date: dates[1], approval_status: approval, is_deductible_on_salary: true }
      ]
    });
    expect(result.totalUnapprovedDaysOff).toBe(1);
    expect(result.totalOfficialLeaveDays).toBe(1);
    const salary = calculateSalaryStatement({
      earnings: { basic: 3000, other: 0, accommodation: 0, travel: 0, food: 0 },
      eligibleCalendarDays: 30, fullPeriodEmployment: true,
      deductions: { unapprovedDays: result.totalUnapprovedDaysOff }
    });
    expect(salary.deductions.unapprovedLeave).toBe(100);
  });

  it('deducts pending leave for remote employees even if the old reason default was not deductible', () => {
    const result = buildSalaryAttendance({ ...base(), currentStatus: 'Remote Job', leaves: [
      { day_off_date: dates[0], approval_status: 'pending', is_deductible_on_salary: false }
    ] });
    expect(result.totalUnapprovedDaysOff).toBe(1);
    expect(result.totalWorkedDays).toBe(3);
  });

  it('keeps weekly rest days and official holidays paid inside a deductible leave request', () => {
    const result = buildSalaryAttendance({ ...base(),
      leaves: dates.map(date => ({ day_off_date: date, approval_status: 'approved', is_deductible_on_salary: true })),
      weeklyOffs: [{ date_from: '2026-10-01', date_to: null, day_off_weekday_version_days: [{ weekday: 2 }] }],
      holidayDates: [dates[3]]
    });
    expect(result.totalApprovedDaysOff).toBe(2);
    expect(result.totalUnapprovedDaysOff).toBe(2);
    expect(result.totalExpectedWorkDays).toBe(2);
  });

  it('does not charge or expect hours for EMP113 unscheduled and pre-employment days', () => {
    const result = buildSalaryAttendance({ ...base(), eligibleDates: dates.slice(1), rows: [
      row(dates[0], 'Not Joined'), row(dates[1], 'Not Scheduled'), row(dates[2], 'Worked', 720), row(dates[3])
    ] });
    expect(result.totalExpectedWorkDays).toBe(2);
    expect(result.totalExpectedMinutes).toBe(1440);
    expect(result.totalUnapprovedDaysOff).toBe(1);
    expect(result.dayByDay[dates[0]].status).toBe('Not Employed');
  });

  it('treats missing fingerprint analysis as absent but missing remote analysis as worked', () => {
    const finger = buildSalaryAttendance(base());
    const remote = buildSalaryAttendance({ ...base(), currentStatus: 'Remote Job' });
    expect(finger.totalUnapprovedDaysOff).toBe(4);
    expect(remote.totalUnapprovedDaysOff).toBe(0);
    expect(remote.totalWorkedDays).toBe(4);
    expect(remote.totalWorkedMinutes).toBe(0);
  });

  it('uses actual attendance when the employee works on a requested leave day', () => {
    const result = buildSalaryAttendance({ ...base(), rows: [row(dates[0], 'Worked', 720)], leaves: [
      { day_off_date: dates[0], approval_status: 'approved', is_deductible_on_salary: true }
    ] });
    expect(result.dayByDay[dates[0]].status).toBe('Worked');
    expect(result.totalUnapprovedDaysOff).toBe(3);
  });
});
