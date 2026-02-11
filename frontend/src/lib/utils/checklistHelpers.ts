/**
 * Checklist Helper Functions
 * Handles timezone-aware checklist scheduling and filtering
 */

import { supabase } from './supabase';

// Saudi Arabia timezone (UTC+3, no DST)
export const SA_TIMEZONE = 'Asia/Riyadh';

/**
 * Get current time in Saudi Arabia timezone
 */
export function getSaudiArabiaTime(): Date {
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: SA_TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });

  const parts = formatter.formatToParts(new Date());
  return new Date(new Date().toLocaleString('en-US', { timeZone: SA_TIMEZONE }));
}

/**
 * Get current day of week in Saudi Arabia timezone
 * Returns day name: "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
 */
export function getSaudiDayOfWeek(): string {
  const date = getSaudiArabiaTime();
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  return days[date.getDay()];
}

/**
 * Check if employee has a day off on a specific day
 * Checks both recurring weekly day offs and specific date day offs
 */
export async function isEmployeeDayOff(employeeId: string, checkDate?: Date): boolean {
  const date = checkDate || getSaudiArabiaTime();
  const dayOfWeekNumber = date.getDay(); // 0-6 (0=Sunday, 1=Monday, etc.)
  const dateString = date.toISOString().split('T')[0];

  try {
    // Check for weekly recurring day off (one row per employee-weekday that's a day off)
    const { data: weekdayOff, error: weekError } = await supabase
      .from('day_off_weekday')
      .select('*')
      .eq('employee_id', employeeId)
      .eq('weekday', dayOfWeekNumber)
      .maybeSingle();

    if (!weekError && weekdayOff) {
      // If a row exists for this employee on this weekday, they have the day off
      return true;
    }

    // Check for specific date day off (approved)
    const { data: specificOffs, error: dateError } = await supabase
      .from('day_off')
      .select('*')
      .eq('employee_id', employeeId)
      .eq('day_off_date', dateString)
      .eq('approval_status', 'approved');

    if (!dateError && specificOffs && specificOffs.length > 0) {
      return true;
    }

    return false;
  } catch (err) {
    console.error('Error checking day off:', err);
    return false;
  }
}

/**
 * Get today's checklists excluding day offs
 */
export async function getTodaysChecklistsWithDayOff(userId: string, employeeId: string) {
  try {
    const checklists = await getTodaysChecklists(userId);
    
    // Check if employee has day off today
    const hasOffToday = await isEmployeeDayOff(employeeId);
    
    if (hasOffToday) {
      console.log('📅 Employee has day off today - no checklists shown');
      return [];
    }

    return checklists;
  } catch (err) {
    console.error('Error getting checklists:', err);
    return [];
  }
}

/**
 * Get today's checklists for a user (Saudi Arabia timezone)
 * Filters daily and weekly checklists based on SA timezone
 */
export async function getTodaysChecklists(userId: string) {
  try {
    const { data: assignments, error } = await supabase
      .from('employee_checklist_assignments')
      .select(`
        *,
        hr_checklists:checklist_id (
          id,
          checklist_name_en,
          checklist_name_ar
        )
      `)
      .eq('assigned_to_user_id', userId)
      .is('deleted_at', null)
      .eq('is_active', true);

    if (error) throw error;

    // Filter for today based on Saudi Arabia timezone
    const saToday = getSaudiDayOfWeek();
    return (assignments || []).filter(a => {
      // Daily checklists always show
      if (a.frequency_type === 'daily') {
        return true;
      }
      // Weekly checklists show on matching day
      if (a.frequency_type === 'weekly' && a.day_of_week === saToday) {
        return true;
      }
      return false;
    });
  } catch (err: any) {
    console.error('Error getting checklists:', err);
    throw err;
  }
}

/**
 * Get all assigned checklists for a user (no time filtering)
 */
export async function getAllAssignedChecklists(userId: string) {
  try {
    const { data: assignments, error } = await supabase
      .from('employee_checklist_assignments')
      .select(`
        *,
        hr_checklists:checklist_id (
          id,
          checklist_name_en,
          checklist_name_ar
        ),
        employee:employee_id (
          id,
          name_en,
          name_ar,
          user_id
        )
      `)
      .eq('assigned_to_user_id', userId)
      .is('deleted_at', null);

    if (error) throw error;
    return assignments || [];
  } catch (err: any) {
    console.error('Error getting assigned checklists:', err);
    throw err;
  }
}

/**
 * Get checklists for an employee (for EmployeeAnalysisWindow)
 * Shows which checklists are assigned to an employee
 */
export async function getEmployeeChecklists(employeeId: string) {
  try {
    const { data: assignments, error } = await supabase
      .from('employee_checklist_assignments')
      .select(`
        *,
        hr_checklists:checklist_id (
          id,
          checklist_name_en,
          checklist_name_ar
        ),
        assigned_user:assigned_to_user_id (
          id,
          username,
          hr_employees (
            id,
            name_en,
            name_ar
          )
        )
      `)
      .eq('employee_id', employeeId)
      .is('deleted_at', null)
      .order('created_at', { ascending: false });

    if (error) throw error;
    return assignments || [];
  } catch (err: any) {
    console.error('Error getting employee checklists:', err);
    throw err;
  }
}

/**
 * Check if a checklist should run today for an employee
 * Considers: frequency, day of week, and day off status
 */
export async function shouldRunToday(assignment: any, employeeId?: string): Promise<boolean> {
  const saToday = getSaudiDayOfWeek();

  // Check frequency and day
  let matchesSchedule = false;
  if (assignment.frequency_type === 'daily') {
    matchesSchedule = true;
  } else if (assignment.frequency_type === 'weekly' && assignment.day_of_week === saToday) {
    matchesSchedule = true;
  }

  if (!matchesSchedule) {
    return false;
  }

  // Check if employee has day off (if employeeId provided)
  if (employeeId) {
    const hasOffToday = await isEmployeeDayOff(employeeId);
    if (hasOffToday) {
      return false;
    }
  }

  return true;
}

/**
 * Format checklist assignment info for display
 */
export function formatChecklistInfo(assignment: any, locale: string = 'en') {
  const checklist = assignment.hr_checklists;
  const name = locale === 'ar' ? checklist.checklist_name_ar : checklist.checklist_name_en;
  const frequency = assignment.frequency_type === 'daily' 
    ? '📅 Daily' 
    : `📅 Weekly - ${assignment.day_of_week}`;
  
  return {
    name,
    frequency,
    assignedTo: assignment.assigned_to_user_id,
    isActive: assignment.is_active
  };
}

/**
 * Get employee's shift start time for a given date
 * Priority: special_shift_date_wise → special_shift_weekday → regular_shift
 */
export async function getShiftStartTime(
  employeeId: string, 
  checkDate?: Date
): Promise<string | null> {
  const date = checkDate || getSaudiArabiaTime();
  const dateString = date.toISOString().split('T')[0]; // YYYY-MM-DD
  const dayOfWeek = date.getDay(); // 0-6 (0=Sunday)

  try {
    // Priority 1: Check specific date override
    const { data: dateWise, error: dateError } = await supabase
      .from('special_shift_date_wise')
      .select('shift_start_time')
      .eq('employee_id', employeeId)
      .eq('shift_date', dateString)
      .maybeSingle();

    if (!dateError && dateWise) {
      return dateWise.shift_start_time;
    }

    // Priority 2: Check weekly special shift
    const { data: weekdayShift, error: weekError } = await supabase
      .from('special_shift_weekday')
      .select('shift_start_time')
      .eq('employee_id', employeeId)
      .eq('weekday', dayOfWeek)
      .maybeSingle();

    if (!weekError && weekdayShift) {
      return weekdayShift.shift_start_time;
    }

    // Priority 3: Get regular shift
    const { data: regularShift, error: regError } = await supabase
      .from('regular_shift')
      .select('shift_start_time')
      .eq('id', employeeId)
      .maybeSingle();

    if (!regError && regularShift) {
      return regularShift.shift_start_time;
    }

    return null;
  } catch (err) {
    console.error('Error getting shift start time:', err);
    return null;
  }
}

/**
 * Check if current time is after shift start time
 * Returns false if no shift assigned (requires shift for checklist access)
 */
export async function isAfterShiftStart(employeeId: string): Promise<boolean> {
  try {
    const shiftStartTime = await getShiftStartTime(employeeId);
    if (!shiftStartTime) {
      console.warn('No shift assigned for employee - denying access');
      return false; // Deny access if no shift configured
    }

    const now = getSaudiArabiaTime();
    const currentMinutes = now.getHours() * 60 + now.getMinutes();
    const [hours, minutes] = shiftStartTime.split(':').map(Number);
    const shiftMinutes = hours * 60 + minutes;

    return currentMinutes >= shiftMinutes;
  } catch (err) {
    console.error('Error checking shift start time:', err);
    return false; // Deny on error
  }
}
