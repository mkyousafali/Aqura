import type { StatusPeriod } from './salaryStatementCalculation';

export const SALARY_ATTENDANCE_POLICY_VERSION = 1;

export function employmentStatusOnDate(date: string, periods: StatusPeriod[], currentStatus: string): string {
  const covering = periods.filter(p => (!p.effective_from || p.effective_from <= date) && (!p.effective_to || p.effective_to >= date));
  covering.sort((a, b) => (b.effective_from || '').localeCompare(a.effective_from || ''));
  return covering[0]?.status || currentStatus;
}

// Used only when constructing a new analysis, never when restoring a snapshot.
export function buildSalaryAttendance(args: {
  dates: string[];
  eligibleDates: string[];
  rows: any[];
  statusPeriods: StatusPeriod[];
  currentStatus: string;
  leaves: any[];
  weeklyOffs: any[];
  holidayDates: string[];
}) {
  const eligible = new Set(args.eligibleDates);
  const rows = new Map(args.rows.map(row => [String(row.shift_date).split('T')[0], row]));
  const leaves = new Map(args.leaves.map(row => [row.day_off_date, row]));
  const holidays = new Set(args.holidayDates);
  const fallbackShift = args.rows.find(row => row.shift_start_time && row.shift_end_time);
  const dayByDay: Record<string, any> = {};
  let totalWorkedMinutes = 0;
  let totalLateMinutes = 0;
  let totalUnderWorkedMinutes = 0;
  let totalIncompleteDays = 0;
  let totalApprovedDaysOff = 0;
  let totalOfficialLeaveDays = 0;
  let totalUnapprovedDaysOff = 0;
  let totalWorkedDays = 0;
  let totalExpectedWorkDays = 0;
  let totalExpectedMinutes = 0;

  for (const date of args.dates) {
    if (!eligible.has(date)) {
      dayByDay[date] = { workedMins: 0, status: 'Not Employed', lateMins: 0, underMins: 0 };
      continue;
    }
    const row = rows.get(date);
    const employmentStatus = employmentStatusOnDate(date, args.statusPeriods, args.currentStatus);
    const isRemote = employmentStatus === 'Remote Job';
    const weekday = new Date(date + 'T12:00:00Z').getUTCDay();
    const weeklyOff = args.weeklyOffs.some(version =>
      (!version.date_from || version.date_from <= date) && (!version.date_to || version.date_to >= date) &&
      (version.day_off_weekday_version_days || []).some((day: any) => day.weekday === weekday)
    );
    const hasPunches = Boolean(row && (row.worked_minutes > 0 || row.check_in_time || row.check_out_time));
    let status = row?.status || (isRemote ? 'Worked' : 'Absent');
    let workedMins = Number(row?.worked_minutes) || 0;
    let lateMins = Number(row?.late_minutes) || 0;
    let underMins = Number(row?.under_minutes) || 0;

    if (!hasPunches) {
      const leave = leaves.get(date);
      // Regular paid rest days and holidays remain paid even inside a leave request.
      if (weeklyOff || status === 'Official Day Off') status = 'Official Day Off';
      else if (holidays.has(date) || status === 'Official Holiday') status = 'Official Holiday';
      else if (leave) {
        if (leave.approval_status === 'approved') {
          status = leave.is_deductible_on_salary ? 'Approved Leave (Deductible)' : 'Approved Leave (No Deduction)';
        } else if (leave.approval_status === 'rejected') {
          status = leave.is_deductible_on_salary ? 'Rejected-Deducted' : 'Rejected-Not Deducted';
        } else {
          status = 'Pending Approval';
        }
      } else if (isRemote && ['Absent', 'Not Scheduled', 'Worked'].includes(status)) {
        status = 'Worked';
      }
      // Remote presence is credited as a day, without inventing fingerprint hours.
      if (isRemote) { workedMins = 0; lateMins = 0; underMins = 0; }
    }

    dayByDay[date] = { workedMins, status, lateMins, underMins, employmentStatus };
    if (status === 'Official Day Off' || status === 'Official Holiday') totalApprovedDaysOff++;
    else if (status === 'Approved Leave (No Deduction)' || status === 'Rejected-Not Deducted') totalOfficialLeaveDays++;
    else if (['Absent', 'Pending Approval', 'Approved Leave (Deductible)', 'Rejected-Deducted'].includes(status)) totalUnapprovedDaysOff++;
    else if (status === 'Check-In Missing' || status === 'Check-Out Missing') totalIncompleteDays++;

    if (!['Official Day Off', 'Official Holiday', 'Not Scheduled', 'Not Joined', 'Not Employed'].includes(status)) {
      totalExpectedWorkDays++;
      const shift = row?.shift_start_time && row?.shift_end_time ? row : fallbackShift;
      if (shift) {
        const minutes = (time: string) => Number(time.split(':')[0]) * 60 + Number(time.split(':')[1]);
        totalExpectedMinutes += (minutes(shift.shift_end_time) - minutes(shift.shift_start_time) + 1440) % 1440;
      }
    }
    totalWorkedMinutes += workedMins;
    totalLateMinutes += lateMins;
    totalUnderWorkedMinutes += underMins;
    if (workedMins > 0 || (isRemote && status === 'Worked')) totalWorkedDays++;
  }

  return { dayByDay, totalWorkedMinutes, totalLateMinutes, totalUnderWorkedMinutes,
    totalIncompleteDays, totalApprovedDaysOff, totalOfficialLeaveDays, totalUnapprovedDaysOff,
    totalWorkedDays, totalExpectedWorkDays, totalExpectedMinutes };
}
