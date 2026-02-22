// Supabase Edge Function: Analyze Attendance
// Runs automatically via pg_cron (4x/day) or manually via HTTP
// Analyzes all employees' attendance for a rolling 45-day window
// Upserts results into hr_analysed_attendance_data table

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ============ Timezone Helper ============
// Server runs in UTC but business operates in Saudi Arabia (UTC+3)
// Match browser behavior of EmployeeAnalysisWindow.svelte which uses local Saudi time

function getSaudiDateStr(date?: Date): string {
  const d = date || new Date();
  // Format in Saudi timezone to get the correct local date
  return d.toLocaleDateString('en-CA', { timeZone: 'Asia/Riyadh' }); // en-CA gives YYYY-MM-DD
}

function getWeekdayInSaudi(dateStr: string): number {
  // Parse YYYY-MM-DD and get weekday in Saudi timezone
  // Use noon UTC to avoid any date-boundary issues
  const d = new Date(dateStr + 'T12:00:00Z');
  return d.getDay();
}

// ============ Helper Functions ============

function timeToMinutes(timeStr: string): number {
  if (!timeStr) return 0;
  const parts = timeStr.split(':');
  return parseInt(parts[0]) * 60 + parseInt(parts[1]);
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

function calculateWorkedMinutesRaw(checkInTime: string, checkOutTime: string): number {
  const checkInMinutes = timeToMinutes(checkInTime);
  const checkOutMinutes = timeToMinutes(checkOutTime);
  let diffMinutes = checkOutMinutes - checkInMinutes;
  if (diffMinutes < 0) diffMinutes += 24 * 60;
  return diffMinutes;
}

function calculateLateArrivalMinutes(punchTime: string, shift: any): number {
  // Match EmployeeAnalysisWindow.svelte calculateEarlyLateForCheckIn logic
  if (!shift) return 0;
  const punchMinutes = timeToMinutes(punchTime);
  const shiftStartMinutes = timeToMinutes(shift.shift_start_time);
  const shiftEndMinutes = timeToMinutes(shift.shift_end_time);
  const isOvernight = shiftEndMinutes < shiftStartMinutes;

  if (isOvernight) {
    // For overnight shifts, check-in is only in the evening (>= shift_start)
    if (punchMinutes >= shiftStartMinutes) {
      // Late = how many minutes after shift start
      return punchMinutes - shiftStartMinutes;
    }
    // If punch is in the early morning (before shift_end), this is NOT a late check-in
    // (it's either a confused punch or early — treat as 0 late, matching EmployeeAnalysisWindow)
    return 0;
  }
  // Normal shift: late only if after shift start
  return punchMinutes > shiftStartMinutes ? punchMinutes - shiftStartMinutes : 0;
}

// ============ Main Analysis Logic ============

interface Employee {
  id: string;
  name_en: string;
  name_ar: string;
  current_branch_id: string;
  employment_status: string;
  nationality_id?: string;
  nationality_name_en?: string;
}

function getApplicableShift(
  empId: string,
  dateStr: string,
  employeeShifts: Map<string, any>,
  employeeSpecialShiftsDateWise: Map<string, any[]>,
  employeeSpecialShiftsWeekday: Map<string, any[]>
) {
  const sId = String(empId);
  const dayNum = getWeekdayInSaudi(dateStr);

  // Date-wise special shift (highest priority)
  const dateWise = employeeSpecialShiftsDateWise.get(sId)?.find(s => s.shift_date === dateStr);
  if (dateWise) return dateWise;

  // Weekday special shift
  const weekdayShift = employeeSpecialShiftsWeekday.get(sId)?.find(s => s.weekday === dayNum);
  if (weekdayShift) return weekdayShift;

  // Regular shift
  return employeeShifts.get(sId);
}

function isOfficialDayOff(empId: string, dateStr: string, employeeDayOffs: Map<string, any>): boolean {
  const dayOffWD = employeeDayOffs.get(String(empId));
  if (!dayOffWD) return false;
  const dayNum = getWeekdayInSaudi(dateStr);
  return dayNum === dayOffWD.weekday;
}

function getSpecificDayOff(empId: string, dateStr: string, employeeSpecificDayOffs: Map<string, any[]>): any {
  return employeeSpecificDayOffs.get(String(empId))?.find(d => d.day_off_date === dateStr);
}

function analyzeEmployeeDays(
  emp: Employee,
  datesInRange: string[],
  txnsByShiftDate: Map<string, any[]>,
  employeeShifts: Map<string, any>,
  employeeDayOffs: Map<string, any>,
  employeeSpecificDayOffs: Map<string, any[]>,
  employeeSpecialShiftsDateWise: Map<string, any[]>,
  employeeSpecialShiftsWeekday: Map<string, any[]>,
  employeeOfficialHolidays: Map<string, Set<string>>,
  employeeOvertime: Map<string, Map<string, number>>
): any[] {
  const results: any[] = [];
  const consumedTransactions = new Set<string>();

  // Process dates in order so cross-day fallback works correctly
  for (const date of datesInRange) {
    const shift = getApplicableShift(emp.id, date, employeeShifts, employeeSpecialShiftsDateWise, employeeSpecialShiftsWeekday);
    const isOff = isOfficialDayOff(emp.id, date, employeeDayOffs);
    const specOff = getSpecificDayOff(emp.id, date, employeeSpecificDayOffs);

    const isApprovedOff = specOff && specOff.approval_status === 'approved';
    const isPendingOff = specOff && (!specOff.approval_status || specOff.approval_status === 'pending');
    const isRejectedOff = specOff && specOff.approval_status === 'rejected';

    // Get transactions for this date, excluding already consumed ones
    const allTransactions = (txnsByShiftDate.get(date) || []).filter((t: any) => !consumedTransactions.has(t.id));

    let workedMins = 0;
    let lateMins = 0;
    let underMins = 0;
    let status = '';
    let checkInTime: string | null = null;
    let checkOutTime: string | null = null;

    if (allTransactions.length === 0) {
      // Day-off/leave status only when NO transactions (matches AnalyzeAllWindow.svelte)
      if (isOff) {
        status = 'Official Day Off';
      } else if (isApprovedOff) {
        status = specOff.is_deductible_on_salary ? 'Approved Leave (Deductible)' : 'Approved Leave (No Deduction)';
      } else if (isPendingOff) {
        status = 'Pending Approval';
      } else if (isRejectedOff) {
        status = specOff.is_deductible_on_salary ? 'Rejected-Deducted' : 'Rejected-Not Deducted';
      } else if (employeeOfficialHolidays.get(String(emp.id))?.has(date)) {
        status = 'Official Holiday';
      } else {
        status = 'Absent';
      }
    } else {
      // ---- DEDUPLICATION (matching EmployeeAnalysisWindow.svelte createPunchPairs) ----
      const allCheckIns = allTransactions.filter((t: any) => t.status === 'Check In');
      const allCheckOuts = allTransactions.filter((t: any) => t.status === 'Check Out');
      const allOthers = allTransactions.filter((t: any) => t.status !== 'Check In' && t.status !== 'Check Out');

      let dedupedTransactions: any[] = [];

      // If multiple Check Ins but NO Check Outs, keep all (for self-pairing)
      if (allCheckIns.length >= 2 && allCheckOuts.length === 0) {
        dedupedTransactions.push(...allCheckIns);
      } else if (allCheckIns.length > 0) {
        // Deduplicate check-ins by calendarDate, keep latest by created_at
        const checkInMap: { [key: string]: any } = {};
        allCheckIns.forEach((txn: any) => {
          const key = `${txn.calendarDate}`;
          if (!checkInMap[key] || new Date(txn.created_at) > new Date(checkInMap[key].created_at)) {
            checkInMap[key] = txn;
          }
        });
        dedupedTransactions.push(...Object.values(checkInMap));
      }

      // If multiple Check Outs but NO Check Ins, keep all (for self-pairing)
      if (allCheckOuts.length >= 2 && allCheckIns.length === 0) {
        dedupedTransactions.push(...allCheckOuts);
      } else if (allCheckOuts.length > 0) {
        // Deduplicate check-outs by calendarDate, keep latest by created_at
        const checkOutMap: { [key: string]: any } = {};
        allCheckOuts.forEach((txn: any) => {
          const key = `${txn.calendarDate}`;
          if (!checkOutMap[key] || new Date(txn.created_at) > new Date(checkOutMap[key].created_at)) {
            checkOutMap[key] = txn;
          }
        });
        dedupedTransactions.push(...Object.values(checkOutMap));
      }

      // Keep all "In Progress" and "Other" (dedup by id)
      const otherMap: { [key: string]: any } = {};
      allOthers.forEach((txn: any) => {
        if (!otherMap[txn.id]) otherMap[txn.id] = txn;
      });
      dedupedTransactions.push(...Object.values(otherMap));

      // Sort by calendar date then punch time
      dedupedTransactions.sort((a: any, b: any) => {
        if (a.calendarDate !== b.calendarDate) return a.calendarDate.localeCompare(b.calendarDate);
        return a.punch_time.localeCompare(b.punch_time);
      });

      // ---- PAIRING (matching EmployeeAnalysisWindow.svelte createPunchPairs) ----
      const checkInTransactions = dedupedTransactions.filter((t: any) => t.status === 'Check In');
      const checkOutTransactions = dedupedTransactions.filter((t: any) => t.status === 'Check Out');
      const otherTransactions = dedupedTransactions.filter((t: any) => t.status === 'In Progress' || t.status === 'Other');

      const isOvernightShift = shift && timeToMinutes(shift.shift_end_time) < timeToMinutes(shift.shift_start_time);

      // Sort check-outs: prioritize same-day over carryover
      checkOutTransactions.sort((a: any, b: any) => {
        const aSameDay = a.calendarDate === date ? 0 : 1;
        const bSameDay = b.calendarDate === date ? 0 : 1;
        return aSameDay - bSameDay;
      });

      const pairs: any[] = [];
      let checkOutIdx = 0;
      let otherIdx = 0;
      const localConsumed = new Set<string>();

      // Pair check-ins with check-outs (with fallback to Other/InProgress)
      checkInTransactions.forEach((checkInTxn: any) => {
        let checkOutTxn = null;

        // Priority 1: Use a Check Out transaction
        if (checkOutIdx < checkOutTransactions.length) {
          checkOutTxn = checkOutTransactions[checkOutIdx];
          checkOutIdx++;
          localConsumed.add(checkOutTxn.id);
        }
        // Priority 2: Use "In Progress" or "Other" as fallback checkout
        else if (otherIdx < otherTransactions.length) {
          checkOutTxn = otherTransactions[otherIdx];
          otherIdx++;
          localConsumed.add(checkOutTxn.id);
        }

        // Priority 3: Cross-day fallback for non-overnight shifts
        if (!checkOutTxn && !isOvernightShift && shift) {
          const nextDateStr = getNextDateStr(date);
          const nextDayTxns = txnsByShiftDate.get(nextDateStr);
          if (nextDayTxns && nextDayTxns.length > 0) {
            const nextDayShift = getApplicableShift(emp.id, nextDateStr, employeeShifts, employeeSpecialShiftsDateWise, employeeSpecialShiftsWeekday);
            if (nextDayShift) {
              const nextShiftStartMinutes = timeToMinutes(nextDayShift.shift_start_time);
              const nextShiftStartBuffer = (nextDayShift.shift_start_buffer || 0) * 60;
              const nextDayCheckInStart = nextShiftStartMinutes - nextShiftStartBuffer;

              for (const nextTxn of nextDayTxns) {
                if (consumedTransactions.has(nextTxn.id) || localConsumed.has(nextTxn.id)) continue;
                const nextPunchMinutes = timeToMinutes(nextTxn.punch_time);
                if (nextPunchMinutes < nextDayCheckInStart) {
                  checkOutTxn = nextTxn;
                  localConsumed.add(nextTxn.id);
                  break;
                }
              }
            }
          }
        }

        if (checkOutTxn) {
          pairs.push({ in: checkInTxn, out: checkOutTxn });
          localConsumed.add(checkInTxn.id);
        } else {
          pairs.push({ in: checkInTxn, out: null });
        }
      });

      // Self-pairing: unmatched Check Ins paired consecutively
      const unmatchedCheckIns = checkInTransactions.filter((t: any) => !localConsumed.has(t.id));
      if (unmatchedCheckIns.length >= 2) {
        // Remove incomplete pairs for these check-ins
        for (let i = pairs.length - 1; i >= 0; i--) {
          if (pairs[i].in && !pairs[i].out && unmatchedCheckIns.some((u: any) => u.id === pairs[i].in.id)) {
            pairs.splice(i, 1);
          }
        }
        // Sort by punch time
        unmatchedCheckIns.sort((a: any, b: any) => a.punch_time.localeCompare(b.punch_time));
        // Pair consecutively
        for (let i = 0; i < unmatchedCheckIns.length - 1; i += 2) {
          pairs.push({ in: unmatchedCheckIns[i], out: unmatchedCheckIns[i + 1] });
          localConsumed.add(unmatchedCheckIns[i].id);
          localConsumed.add(unmatchedCheckIns[i + 1].id);
        }
        // Odd leftover
        if (unmatchedCheckIns.length % 2 === 1) {
          const last = unmatchedCheckIns[unmatchedCheckIns.length - 1];
          pairs.push({ in: last, out: null });
          localConsumed.add(last.id);
        }
      }

      // Handle remaining unpaired Check Outs
      checkOutTransactions.forEach((t: any) => {
        if (!localConsumed.has(t.id)) {
          pairs.push({ in: null, out: t });
          localConsumed.add(t.id);
        }
      });

      // Handle remaining unpaired Others
      otherTransactions.forEach((t: any) => {
        if (!localConsumed.has(t.id)) {
          pairs.push({ in: null, out: t });
          localConsumed.add(t.id);
        }
      });

      // Mark all locally consumed transactions as globally consumed
      localConsumed.forEach(id => consumedTransactions.add(id));

      // ---- CALCULATE TOTALS ----
      let hasIncompletePair = false;
      let missingType = '';

      pairs.forEach((p: any, idx: number) => {
        if (p.in && p.out) {
          workedMins += calculateWorkedMinutesRaw(p.in.punch_time, p.out.punch_time);
          if (idx === 0 && shift) {
            lateMins = calculateLateArrivalMinutes(p.in.punch_time, shift);
          }
          if (!checkInTime) checkInTime = p.in.punch_time;
          checkOutTime = p.out.punch_time;
        } else {
          hasIncompletePair = true;
          if (p.in) {
            missingType = 'Check-Out Missing';
            if (idx === 0 && shift) lateMins = calculateLateArrivalMinutes(p.in.punch_time, shift);
            if (!checkInTime) checkInTime = p.in.punch_time;
          } else {
            missingType = 'Check-In Missing';
            if (p.out) checkOutTime = p.out.punch_time;
          }
        }
      });

      if (hasIncompletePair) {
        status = missingType;
      } else {
        if (shift) {
          // Use working_hours field (matches EmployeeAnalysisWindow.svelte)
          const expected = (shift.working_hours || 0) * 60;
          if (expected > 0 && workedMins < expected) underMins = expected - workedMins;
        }
        status = 'Worked';
      }
    }

    results.push({
      employee_id: emp.id,
      shift_date: date,
      status,
      worked_minutes: workedMins,
      late_minutes: lateMins,
      under_minutes: underMins,
      overtime_minutes: employeeOvertime.get(String(emp.id))?.get(date) || 0,
      shift_start_time: shift?.shift_start_time || null,
      shift_end_time: shift?.shift_end_time || null,
      check_in_time: checkInTime,
      check_out_time: checkOutTime,
      employee_name_en: emp.name_en,
      employee_name_ar: emp.name_ar,
      branch_id: emp.current_branch_id,
      nationality: emp.nationality_name_en || null,
      analyzed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
  }

  return results;
}

// ============ Main Handler ============

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse optional parameters (for manual trigger)
    let rollingDays = 45;
    let specificEmployeeId: string | null = null;

    if (req.method === 'POST') {
      try {
        const body = await req.json();
        if (body.rollingDays) rollingDays = body.rollingDays;
        if (body.employeeId) specificEmployeeId = body.employeeId;
      } catch (_) {
        // No body or invalid JSON - use defaults
      }
    }

    console.log(`📊 [Analyze Attendance] Starting analysis. Rolling window: ${rollingDays} days`);

    // ---- Calculate date range (Saudi timezone) ----
    const endDate = getSaudiDateStr(); // Today in Saudi Arabia
    const startDateObj = new Date(endDate + 'T12:00:00Z');
    startDateObj.setDate(startDateObj.getDate() - rollingDays);
    const startDate = startDateObj.toISOString().split('T')[0];

    // Generate dates in range
    const datesInRange: string[] = [];
    const endDateObj = new Date(endDate + 'T12:00:00Z');
    for (let d = new Date(startDateObj); d <= endDateObj; d.setDate(d.getDate() + 1)) {
      datesInRange.push(new Date(d).toISOString().split('T')[0]);
    }

    // ---- Load employees ----
    let empQuery = supabase
      .from('hr_employee_master')
      .select(`id, name_en, name_ar, current_branch_id, employment_status, nationality_id, nationalities (name_en)`)
      .eq('employment_status', 'Job (With Finger)');

    if (specificEmployeeId) {
      empQuery = empQuery.eq('id', specificEmployeeId);
    }

    const { data: empData, error: empError } = await empQuery;
    if (empError) throw empError;

    const employees: Employee[] = (empData || []).map((e: any) => ({
      ...e,
      nationality_name_en: e.nationalities?.name_en,
    }));

    if (employees.length === 0) {
      console.log('📊 [Analyze Attendance] No employees found');
      return new Response(JSON.stringify({ success: true, message: 'No employees', analyzed: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log(`📊 [Analyze Attendance] Found ${employees.length} employees, ${datesInRange.length} dates`);

    const empIds = employees.map(e => e.id);

    // ---- Extended date range for carryover punches ----
    const extStart = getPreviousDateStr(startDate);
    const extEnd = getNextDateStr(endDate);

    // ---- Bulk fetch all needed data ----
    const [
      { data: transactions },
      { data: shifts },
      { data: dayOffWeekdays },
      { data: specialShiftsDW },
      { data: specialShiftsWD },
      { data: specificDayOffs },
      { data: officialHolidaysData },
      { data: overtimeData },
    ] = await Promise.all([
      supabase.from('processed_fingerprint_transactions').select('*').in('center_id', empIds).gte('punch_date', extStart).lte('punch_date', extEnd),
      supabase.from('regular_shift').select('*').in('id', empIds),
      supabase.from('day_off_weekday').select('*').in('employee_id', empIds),
      supabase.from('special_shift_date_wise').select('*').in('employee_id', empIds),
      supabase.from('special_shift_weekday').select('*').in('employee_id', empIds),
      supabase.from('day_off').select('*, day_off_reasons(*)').in('employee_id', empIds),
      supabase.from('employee_official_holidays').select('employee_id, official_holidays(holiday_date)').in('employee_id', empIds),
      supabase.from('overtime_registrations').select('*').in('employee_id', empIds),
    ]);

    console.log(`📊 [Analyze Attendance] Fetched: ${transactions?.length || 0} transactions, ${shifts?.length || 0} shifts`);

    // ---- Build lookup maps ----
    const employeeShifts = new Map(shifts?.map((s: any) => [String(s.id), s]));
    const employeeDayOffs = new Map(dayOffWeekdays?.map((d: any) => [String(d.employee_id), d]));

    const employeeSpecialShiftsDateWise = new Map<string, any[]>();
    specialShiftsDW?.forEach((s: any) => {
      const list = employeeSpecialShiftsDateWise.get(String(s.employee_id)) || [];
      list.push(s);
      employeeSpecialShiftsDateWise.set(String(s.employee_id), list);
    });

    const employeeSpecialShiftsWeekday = new Map<string, any[]>();
    specialShiftsWD?.forEach((s: any) => {
      const list = employeeSpecialShiftsWeekday.get(String(s.employee_id)) || [];
      list.push(s);
      employeeSpecialShiftsWeekday.set(String(s.employee_id), list);
    });

    const employeeSpecificDayOffs = new Map<string, any[]>();
    specificDayOffs?.forEach((d: any) => {
      const list = employeeSpecificDayOffs.get(String(d.employee_id)) || [];
      list.push(d);
      employeeSpecificDayOffs.set(String(d.employee_id), list);
    });

    // Build official holidays lookup: employee_id -> Set of holiday dates
    const employeeOfficialHolidays = new Map<string, Set<string>>();
    officialHolidaysData?.forEach((row: any) => {
      const empId = String(row.employee_id);
      const holidayDate = row.official_holidays?.holiday_date;
      if (holidayDate) {
        if (!employeeOfficialHolidays.has(empId)) {
          employeeOfficialHolidays.set(empId, new Set());
        }
        employeeOfficialHolidays.get(empId)!.add(holidayDate);
      }
    });

    // Build overtime lookup: employee_id -> Map<date, overtime_minutes>
    const employeeOvertime = new Map<string, Map<string, number>>();
    overtimeData?.forEach((o: any) => {
      const empId = String(o.employee_id);
      if (!employeeOvertime.has(empId)) {
        employeeOvertime.set(empId, new Map());
      }
      employeeOvertime.get(empId)!.set(o.overtime_date, o.overtime_minutes || 0);
    });

    // Group transactions by employee
    const txnsByEmp = new Map<string, any[]>();
    transactions?.forEach((t: any) => {
      const list = txnsByEmp.get(String(t.center_id)) || [];
      list.push(t);
      txnsByEmp.set(String(t.center_id), list);
    });

    // ---- Analyze each employee ----
    const allResults: any[] = [];
    let totalAnalyzed = 0;

    for (const emp of employees) {
      const empTxns = txnsByEmp.get(String(emp.id)) || [];

      // ---- Step 1: Assign transactions to shift dates (carryover logic) ----
      const assignedTransactions = empTxns.map((txn: any) => {
        const calendarDate = txn.punch_date;
        const punchTime = txn.punch_time;
        const punchMinutes = timeToMinutes(punchTime);

        let shiftDate = calendarDate;

        const calendarShift = getApplicableShift(emp.id, calendarDate, employeeShifts, employeeSpecialShiftsDateWise, employeeSpecialShiftsWeekday);
        const calendarShiftStartMinutes = calendarShift ? timeToMinutes(calendarShift.shift_start_time) : 24 * 60;
        const calendarShiftStartBuffer = calendarShift ? (calendarShift.shift_start_buffer || 0) * 60 : 0;
        const calendarCheckInStart = calendarShiftStartMinutes - calendarShiftStartBuffer;

        // Check if morning punch belongs to previous day's overnight shift
        if (punchMinutes < calendarCheckInStart) {
          const prevDateStr = getPreviousDateStr(calendarDate);
          const prevShift = getApplicableShift(emp.id, prevDateStr, employeeShifts, employeeSpecialShiftsDateWise, employeeSpecialShiftsWeekday);

          if (prevShift) {
            const prevShiftEndMinutes = timeToMinutes(prevShift.shift_end_time);
            const prevShiftStartMinutes = timeToMinutes(prevShift.shift_start_time);
            const isOvernightPrevShift = prevShiftEndMinutes < prevShiftStartMinutes;

            if (isOvernightPrevShift) {
              const prevEndBufferMinutes = (prevShift.shift_end_buffer || 0) * 60;
              const prevCheckOutEnd = prevShiftEndMinutes + prevEndBufferMinutes;
              const adjustedCheckOutEnd = prevCheckOutEnd < 0 ? prevCheckOutEnd + (24 * 60) : prevCheckOutEnd;

              if (punchMinutes >= 0 && punchMinutes <= adjustedCheckOutEnd) {
                shiftDate = prevDateStr;
                return { ...txn, calendarDate, shiftDate, status: 'Check Out' };
              }
            }
          }
        }

        // IMPORTANT: Clear any existing DB status so Step 2 always recalculates
        // (matching EmployeeAnalysisWindow which always recalculates from shift windows)
        return { ...txn, shiftDate: calendarDate, calendarDate, status: null };
      });

      // ---- Step 2: Classify each transaction and group by shift date ----
      const txnsByShiftDate = new Map<string, any[]>();

      assignedTransactions.forEach((t: any) => {
        const shift = getApplicableShift(emp.id, t.shiftDate, employeeShifts, employeeSpecialShiftsDateWise, employeeSpecialShiftsWeekday);
        const punchMinutes = timeToMinutes(t.punch_time);
        const shiftStartMinutes = timeToMinutes(shift?.shift_start_time || '00:00');
        const shiftEndMinutes = timeToMinutes(shift?.shift_end_time || '00:00');
        const isOvernightShift = shiftEndMinutes < shiftStartMinutes;

        let status = '';
        let finalShiftDate = t.shiftDate;

        if (t.status) {
          // Already classified (carryover checkout)
          status = t.status;
        } else if (!shift) {
          status = 'Other';
        } else {
          const startBufferMinutes = (shift.shift_start_buffer || 0) * 60;
          const endBufferMinutes = (shift.shift_end_buffer || 0) * 60;
          const checkInStart = shiftStartMinutes - startBufferMinutes;
          const checkInEnd = shiftStartMinutes + startBufferMinutes;
          const checkOutStart = shiftEndMinutes - endBufferMinutes;
          const checkOutEnd = shiftEndMinutes + endBufferMinutes;

          if (isOvernightShift) {
            if (punchMinutes >= checkInStart && punchMinutes <= checkInEnd) {
              status = 'Check In';
            } else if (checkOutStart < 0) {
              const adjustedCheckOutStart = checkOutStart + (24 * 60);
              if (punchMinutes >= 0 && punchMinutes <= checkOutEnd) {
                status = 'Check Out';
              } else if (punchMinutes >= adjustedCheckOutStart && punchMinutes < (24 * 60)) {
                status = 'Check Out';
              } else if (punchMinutes > checkInEnd && punchMinutes < adjustedCheckOutStart) {
                status = 'In Progress';
              } else {
                status = 'Other';
              }
            } else if (punchMinutes >= checkOutStart && punchMinutes <= checkOutEnd) {
              status = 'Check Out';
            } else {
              status = 'Other';
            }
          } else {
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

      // ---- Step 3: Analyze each employee's dates (with cross-day awareness) ----
      const empResults = analyzeEmployeeDays(
        emp,
        datesInRange,
        txnsByShiftDate,
        employeeShifts,
        employeeDayOffs,
        employeeSpecificDayOffs,
        employeeSpecialShiftsDateWise,
        employeeSpecialShiftsWeekday,
        employeeOfficialHolidays,
        employeeOvertime
      );
      allResults.push(...empResults);
      totalAnalyzed += empResults.length;
    }

    console.log(`📊 [Analyze Attendance] Analyzed ${totalAnalyzed} employee-days. Upserting...`);

    // ---- Batch upsert results (in chunks of 500) ----
    const chunkSize = 500;
    let upsertedCount = 0;
    let errorCount = 0;

    for (let i = 0; i < allResults.length; i += chunkSize) {
      const chunk = allResults.slice(i, i + chunkSize);
      const { error: upsertError } = await supabase
        .from('hr_analysed_attendance_data')
        .upsert(chunk, { onConflict: 'employee_id,shift_date' });

      if (upsertError) {
        console.error(`📊 [Analyze Attendance] Upsert error for chunk ${i}:`, upsertError);
        errorCount += chunk.length;
      } else {
        upsertedCount += chunk.length;
      }
    }

    console.log(`📊 [Analyze Attendance] Complete! Upserted: ${upsertedCount}, Errors: ${errorCount}`);

    return new Response(
      JSON.stringify({
        success: true,
        analyzed: totalAnalyzed,
        upserted: upsertedCount,
        errors: errorCount,
        employees: employees.length,
        dateRange: { start: startDate, end: endDate },
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('❌ [Analyze Attendance] Error:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
