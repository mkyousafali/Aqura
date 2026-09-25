// Supabase Edge Function: Analyze Breaks
// Converts raw break_register transactions into one canonical reporting projection.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

type Slot = {
  employee_id: string
  version_id: number
  date_from: string
  date_to: string | null
  weekday?: number
  slot_order?: number
  shift_start_time: string
  shift_end_time: string
  shift_end_buffer?: number | null
  is_shift_overlapping_next_day?: boolean | null
}

type Schedules = { regular: Slot[]; weekday: Slot[]; dateWise: Slot[] }

const ANALYSIS_VERSION = 1
const PAGE_SIZE = 1000

function saudiDate(date = new Date()): string {
  return date.toLocaleDateString('en-CA', { timeZone: 'Asia/Riyadh' })
}

function addDays(date: string, days: number): string {
  const value = new Date(`${date}T12:00:00Z`)
  value.setUTCDate(value.getUTCDate() + days)
  return value.toISOString().slice(0, 10)
}

function weekday(date: string): number {
  return new Date(`${date}T12:00:00Z`).getUTCDay()
}

function mins(time: string): number {
  const [hour, minute] = time.split(':').map(Number)
  return hour * 60 + minute
}

function localParts(timestamp: string): { date: string; minute: number } {
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Riyadh', year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  })
  const parts = Object.fromEntries(formatter.formatToParts(new Date(timestamp)).map(p => [p.type, p.value]))
  return { date: `${parts.year}-${parts.month}-${parts.day}`, minute: Number(parts.hour) * 60 + Number(parts.minute) }
}

function effective(slot: Slot, date: string): boolean {
  return slot.date_from <= date && (!slot.date_to || slot.date_to >= date)
}

function latestVersion(slots: Slot[]): Slot[] {
  if (!slots.length) return []
  const latest = slots.reduce((best, slot) =>
    slot.date_from > best.date_from || (slot.date_from === best.date_from && slot.version_id > best.version_id) ? slot : best)
  return slots.filter(slot => slot.version_id === latest.version_id)
    .sort((a, b) => Number(a.slot_order || 0) - Number(b.slot_order || 0))
}

function slotsForDate(employeeId: string, date: string, schedules: Schedules): { source: string; slots: Slot[] } {
  const matches = (slot: Slot) => String(slot.employee_id) === employeeId && effective(slot, date)
  const dateWise = latestVersion(schedules.dateWise.filter(matches))
  if (dateWise.length) return { source: 'date_wise', slots: dateWise }
  const weekdaySlots = latestVersion(schedules.weekday.filter(slot => matches(slot) && Number(slot.weekday) === weekday(date)))
  if (weekdaySlots.length) return { source: 'weekday', slots: weekdaySlots }
  return { source: 'regular', slots: latestVersion(schedules.regular.filter(matches)) }
}

function isOvernight(slot: Slot): boolean {
  return slot.is_shift_overlapping_next_day === true || mins(slot.shift_end_time) < mins(slot.shift_start_time)
}

function assignShift(employeeId: string, timestamp: string, schedules: Schedules) {
  const local = localParts(timestamp)
  const previousDate = addDays(local.date, -1)
  const previous = slotsForDate(employeeId, previousDate, schedules)
  const carryover = previous.slots.find(slot => isOvernight(slot)
    && local.minute <= mins(slot.shift_end_time) + (Number(slot.shift_end_buffer) || 0) * 60)
  if (carryover) return { date: previousDate, source: previous.source, slot: carryover }

  const current = slotsForDate(employeeId, local.date, schedules)
  const slot = current.slots.find(candidate => {
    const start = mins(candidate.shift_start_time)
    const end = mins(candidate.shift_end_time) + (Number(candidate.shift_end_buffer) || 0) * 60
    return isOvernight(candidate) ? local.minute >= start : local.minute >= start && local.minute <= end
  }) || current.slots[0] || null
  return { date: local.date, source: slot ? current.source : 'unmatched', slot }
}

async function fetchAll(queryFactory: (from: number, to: number) => Promise<any>): Promise<any[]> {
  const result: any[] = []
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await queryFactory(from, from + PAGE_SIZE - 1)
    if (error) throw error
    result.push(...(data || []))
    if (!data || data.length < PAGE_SIZE) return result
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!supabaseUrl || !serviceKey) throw new Error('Missing Supabase configuration')
    const supabase = createClient(supabaseUrl, serviceKey)

    let body: any = {}
    if (req.method === 'POST') try { body = await req.json() } catch { body = {} }
    const fullBackfill = body.fullBackfill === true
    const rollingDays = Math.min(Math.max(Number(body.rollingDays) || 3, 1), 3660)
    const employeeId = typeof body.employeeId === 'string' && body.employeeId ? body.employeeId : null
    const breakId = typeof body.breakId === 'string' && body.breakId ? body.breakId : null
    const endDate = typeof body.dateTo === 'string' ? body.dateTo : saudiDate()
    const startDate = fullBackfill ? null : (typeof body.dateFrom === 'string' ? body.dateFrom : addDays(endDate, -(rollingDays - 1)))

    let breakQuery = supabase.from('break_register').select('*').order('start_time')
    if (breakId) breakQuery = breakQuery.eq('id', breakId)
    else {
      if (employeeId) breakQuery = breakQuery.eq('employee_id', employeeId)
      if (startDate) breakQuery = breakQuery.gte('start_time', `${addDays(startDate, -1)}T00:00:00+03:00`)
      breakQuery = breakQuery.lt('start_time', `${addDays(endDate, 2)}T00:00:00+03:00`)
    }
    const breaks = await fetchAll((from, to) => breakQuery.range(from, to))
    if (!breaks.length) return new Response(JSON.stringify({ success: true, analyzed: 0, upserted: 0 }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

    const employeeIds = [...new Set(breaks.map(row => String(row.employee_id)))]
    const loadSlots = async (versionTable: string, slotTable: string): Promise<Slot[]> => {
      const versions: any[] = []
      for (let i = 0; i < employeeIds.length; i += 100) {
        let query = supabase.from(versionTable).select('*').in('employee_id', employeeIds.slice(i, i + 100))
        if (startDate) query = query.lte('date_from', addDays(endDate, 1)).or(`date_to.is.null,date_to.gte.${addDays(startDate, -1)}`)
        const { data, error } = await query
        if (error) throw error
        versions.push(...(data || []))
      }
      const slots: Slot[] = []
      for (let i = 0; i < versions.length; i += 100) {
        const batch = versions.slice(i, i + 100)
        const { data, error } = await supabase.from(slotTable).select('*').in('version_id', batch.map(v => v.id))
        if (error) throw error
        const byId = new Map(batch.map(v => [v.id, v]))
        for (const slot of data || []) {
          const version = byId.get(slot.version_id)
          if (version) slots.push({ ...version, ...slot })
        }
      }
      return slots
    }

    const [regular, weekdaySlots, dateWise, weeklyOffs, specificOffs, holidays] = await Promise.all([
      loadSlots('hr_regular_shift_versions', 'hr_regular_shift_slots'),
      loadSlots('hr_special_shift_weekday_versions', 'hr_special_shift_weekday_slots'),
      loadSlots('hr_special_shift_date_wise_versions', 'hr_special_shift_date_wise_slots'),
      supabase.from('day_off_weekday').select('employee_id,weekday').in('employee_id', employeeIds),
      supabase.from('day_off').select('employee_id,day_off_date,approval_status').in('employee_id', employeeIds).eq('approval_status', 'approved'),
      supabase.from('employee_official_holidays').select('employee_id,official_holidays(holiday_date)').in('employee_id', employeeIds),
    ])
    for (const result of [weeklyOffs, specificOffs, holidays]) if (result.error) throw result.error
    const schedules: Schedules = { regular, weekday: weekdaySlots, dateWise }
    const weeklyOffSet = new Set((weeklyOffs.data || []).map((r: any) => `${r.employee_id}__${r.weekday}`))
    const specificOffSet = new Set((specificOffs.data || []).map((r: any) => `${r.employee_id}__${r.day_off_date}`))
    const holidaySet = new Set((holidays.data || [])
      .filter((r: any) => r.official_holidays?.holiday_date)
      .map((r: any) => `${r.employee_id}__${r.official_holidays.holiday_date}`))

    const rows = breaks.map(raw => {
      const assigned = assignShift(String(raw.employee_id), raw.start_time, schedules)
      const key = `${raw.employee_id}__${assigned.date}`
      let exception: string | null = null
      if (specificOffSet.has(key)) exception = 'approved_day_off'
      else if (holidaySet.has(key)) exception = 'official_holiday'
      else if (weeklyOffSet.has(`${raw.employee_id}__${weekday(assigned.date)}`)) exception = 'weekly_day_off'
      else if (!assigned.slot) exception = 'no_matching_shift'
      const slot = assigned.slot
      return {
        break_id: raw.id, user_id: raw.user_id, employee_id: raw.employee_id,
        employee_name_en: raw.employee_name_en, employee_name_ar: raw.employee_name_ar,
        branch_id: raw.branch_id, reason_id: raw.reason_id, reason_note: raw.reason_note,
        start_time: raw.start_time, end_time: raw.end_time, duration_seconds: raw.duration_seconds,
        status: raw.status, shift_date: assigned.date, shift_source: assigned.source,
        shift_version_id: slot?.version_id || null, shift_slot_order: slot?.slot_order || null,
        shift_start_time: slot?.shift_start_time || null, shift_end_time: slot?.shift_end_time || null,
        shift_end_buffer: slot?.shift_end_buffer || null, is_overnight: slot ? isOvernight(slot) : false,
        is_scheduled: Boolean(slot) && exception === null, schedule_exception: exception,
        analysis_version: ANALYSIS_VERSION, analyzed_at: new Date().toISOString(), updated_at: new Date().toISOString(),
      }
    }).filter(row => fullBackfill || breakId || (row.shift_date >= (startDate as string) && row.shift_date <= endDate))

    let upserted = 0
    for (let i = 0; i < rows.length; i += 500) {
      const chunk = rows.slice(i, i + 500)
      const { error } = await supabase.from('hr_analysed_break_data').upsert(chunk, { onConflict: 'break_id' })
      if (error) throw error
      upserted += chunk.length
    }
    return new Response(JSON.stringify({ success: true, analyzed: rows.length, upserted, dateRange: { start: startDate, end: endDate }, fullBackfill }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('[Analyze Breaks]', error)
    return new Response(JSON.stringify({ success: false, error: error instanceof Error ? error.message : String(error) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
