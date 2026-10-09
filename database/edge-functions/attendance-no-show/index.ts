import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const RIYADH_OFFSET = '+03:00'
const WHATSAPP_TEMPLATE = 'attendance_not_reported_ar'
const GRAPH_API_VERSION = 'v22.0'

type ShiftRow = {
  employee_id: string
  version_id: number
  slot_order: number
  date_from: string
  date_to?: string | null
  weekday?: number
  shift_start_time: string
  shift_end_time: string
  shift_start_buffer?: number
  is_shift_overlapping_next_day?: boolean
}

type ShiftSlot = ShiftRow & { source: 'date' | 'weekday' | 'regular'; shift_key: string; shift_name: string }

const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: { ...corsHeaders, 'Content-Type': 'application/json' },
})

function saudiParts(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Riyadh', year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23', weekday: 'short',
  }).formatToParts(now)
  const get = (type: string) => parts.find((p) => p.type === type)?.value || ''
  const weekdayMap: Record<string, number> = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 }
  return {
    date: `${get('year')}-${get('month')}-${get('day')}`,
    weekday: weekdayMap[get('weekday')],
  }
}

function atRiyadh(date: string, time: string) {
  return new Date(`${date}T${String(time).slice(0, 8)}${RIYADH_OFFSET}`)
}

function groupVersions(rows: ShiftRow[]) {
  const grouped = new Map<string, ShiftRow[]>()
  for (const row of rows || []) {
    const key = `${row.employee_id}:${row.version_id}`
    const list = grouped.get(key) || []
    list.push(row)
    grouped.set(key, list)
  }
  return grouped
}

function resolveShiftSlots(employeeId: string, today: string, weekday: number, dateRows: ShiftRow[], weekdayRows: ShiftRow[], regularRows: ShiftRow[]): ShiftSlot[] {
  const candidates: Array<{ source: ShiftSlot['source']; rows: ShiftRow[] }> = []
  for (const [key, rows] of groupVersions(dateRows)) {
    const first = rows[0]
    const appliesToday = rows.length > 1
      ? first.date_from <= today && (!first.date_to || first.date_to >= today)
      : first.date_from === today
    if (key.startsWith(`${employeeId}:`) && appliesToday) {
      candidates.push({ source: 'date', rows })
    }
  }
  if (candidates.length === 0) {
    for (const [key, rows] of groupVersions(weekdayRows)) {
      const first = rows[0]
      if (key.startsWith(`${employeeId}:`) && Number(first.weekday) === weekday) {
        candidates.push({ source: 'weekday', rows })
      }
    }
  }
  if (candidates.length === 0) {
    for (const [key, rows] of groupVersions(regularRows)) {
      const first = rows[0]
      if (key.startsWith(`${employeeId}:`) && first.date_from <= today && (!first.date_to || first.date_to >= today)) {
        candidates.push({ source: 'regular', rows })
      }
    }
  }
  const selected = candidates.sort((a, b) => b.rows[0].date_from.localeCompare(a.rows[0].date_from))[0]
  if (!selected) return []
  return selected.rows.sort((a, b) => a.slot_order - b.slot_order).map((row, index) => ({
    ...row,
    source: selected.source,
    shift_key: `${selected.source}:${row.version_id}:${row.slot_order}`,
    shift_name: `Shift ${index + 1}`,
  }))
}

function validCheckIn(attendanceRows: any[], slot: ShiftSlot) {
  const slotStart = String(slot.shift_start_time || '').slice(0, 5)
  return attendanceRows.some((row) =>
    String(row.shift_start_time || '').slice(0, 5) === slotStart &&
    Boolean(row.check_in_time)
  )
}

function formatDateAr(date: Date) {
  return new Intl.DateTimeFormat('ar-SA-u-ca-gregory', { timeZone: 'Asia/Riyadh', dateStyle: 'medium' }).format(date)
}

function formatDateEn(date: Date) {
  return new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Riyadh', dateStyle: 'long' }).format(date)
}

function formatTime(date: Date, locale: 'ar-SA' | 'en-US') {
  return new Intl.DateTimeFormat(locale, { timeZone: 'Asia/Riyadh', hour: '2-digit', minute: '2-digit' }).format(date)
}

function safeError(error: unknown) {
  return error instanceof Error ? error.message.slice(0, 500) : String(error).slice(0, 500)
}

async function refreshAttendancePipeline(supabaseUrl: string, serviceKey: string, today: string) {
  const headers = { Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' }
  const processResponse = await fetch(`${supabaseUrl}/functions/v1/process-fingerprints`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ skipAnalyze: true }),
  })
  const processResult = await processResponse.json().catch(() => ({}))
  if (!processResponse.ok || processResult.success === false) {
    throw new Error(`Final fingerprint processing failed (${processResponse.status}): ${processResult.error || 'unknown error'}`)
  }

  const analyzeResponse = await fetch(`${supabaseUrl}/functions/v1/analyze-attendance`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ dateFrom: today, dateTo: today, triggerType: 'attendance-no-show-final-check' }),
  })
  const analyzeResult = await analyzeResponse.json().catch(() => ({}))
  if (!analyzeResponse.ok || analyzeResult.success === false) {
    throw new Error(`Final attendance analysis failed (${analyzeResponse.status}): ${analyzeResult.error || 'unknown error'}`)
  }
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
  const bearer = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '') || ''
  if (!serviceKey || bearer !== serviceKey) return json({ error: 'Service authorization required' }, 401)

  const supabase = createClient(supabaseUrl, serviceKey)
  const requestBody = await req.json().catch(() => ({}))
  const manualForceResend = requestBody?.trigger === 'manual' && requestBody?.force_resend === true
  const alertType = manualForceResend
    ? `manual_not_reported_for_duty:${crypto.randomUUID()}`
    : 'not_reported_for_duty'
  const now = new Date()
  const { date: today, weekday } = saudiParts(now)
  const summary = { evaluated: 0, pending: 0, cancelled: 0, alerted: 0, deliveries: 0, errors: [] as string[] }
  let attendanceRefresh: Promise<void> | null = null

  try {
    const { data: monitored, error: monitoredError } = await supabase
      .from('attendance_monitoring_employees')
      .select('employee_id')
      .eq('is_enabled', true)
    if (monitoredError) throw monitoredError
    const employeeIds = (monitored || []).map((row: any) => String(row.employee_id))
    if (employeeIds.length === 0) return json({ success: true, today, ...summary })

    const [employeesResult, regularResult, weekdayResult, dateResult, attendanceResult, leaveResult, weeklyOffResult, holidayResult] = await Promise.all([
      supabase.from('hr_employee_master_with_status')
        .select('id,user_id,current_branch_id,name_en,name_ar,employment_status')
        .in('id', employeeIds),
      supabase.rpc('get_hr_regular_shifts', { p_employee_ids: employeeIds }),
      supabase.rpc('get_hr_weekday_shifts', { p_employee_ids: employeeIds }),
      supabase.rpc('get_hr_date_wise_shifts', { p_employee_ids: employeeIds }),
      supabase.from('hr_analysed_attendance_data')
        .select('employee_id,shift_date,shift_start_time,check_in_time,check_out_time,status')
        .in('employee_id', employeeIds).eq('shift_date', today),
      supabase.from('day_off').select('employee_id,day_off_date,approval_status')
        .in('employee_id', employeeIds).eq('day_off_date', today).eq('approval_status', 'approved'),
      supabase.from('day_off_weekday_versions')
        .select('employee_id,date_from,date_to,day_off_weekday_version_days(weekday)')
        .in('employee_id', employeeIds).lte('date_from', today),
      supabase.from('employee_official_holidays')
        .select('employee_id,official_holidays(holiday_date)')
        .in('employee_id', employeeIds),
    ])

    for (const result of [employeesResult, regularResult, weekdayResult, dateResult, attendanceResult, leaveResult, weeklyOffResult, holidayResult]) {
      if (result.error) throw result.error
    }

    const employees = employeesResult.data || []
    const attendanceByEmployee = new Map<string, any[]>()
    for (const row of attendanceResult.data || []) {
      const list = attendanceByEmployee.get(String(row.employee_id)) || []
      list.push(row)
      attendanceByEmployee.set(String(row.employee_id), list)
    }
    const approvedLeave = new Set((leaveResult.data || []).map((row: any) => String(row.employee_id)))
    const holiday = new Set((holidayResult.data || []).filter((row: any) => row.official_holidays?.holiday_date === today).map((row: any) => String(row.employee_id)))
    const weeklyOff = new Set<string>()
    for (const row of weeklyOffResult.data || []) {
      if ((!row.date_to || row.date_to >= today) && (row.day_off_weekday_version_days || []).some((day: any) => Number(day.weekday) === weekday)) {
        weeklyOff.add(String(row.employee_id))
      }
    }

    const { data: branches } = await supabase.from('branches').select('id,name_en,name_ar,location_en,location_ar')
    const branchMap = new Map((branches || []).map((branch: any) => [Number(branch.id), branch]))

    for (const employee of employees) {
      const employeeId = String(employee.id)
      const slots = resolveShiftSlots(employeeId, today, weekday, dateResult.data || [], weekdayResult.data || [], regularResult.data || [])
      for (const slot of slots) {
        summary.evaluated++
        const shiftStart = atRiyadh(today, slot.shift_start_time)
        let shiftEnd = atRiyadh(today, slot.shift_end_time)
        if (slot.is_shift_overlapping_next_day || shiftEnd <= shiftStart) shiftEnd = new Date(shiftEnd.getTime() + 24 * 60 * 60 * 1000)
        const candidateAt = new Date(shiftStart.getTime() + 10 * 60 * 1000)
        const eligibleAt = new Date(shiftStart.getTime() + 16 * 60 * 1000)
        if (now < candidateAt) continue
        if (manualForceResend && now < eligibleAt) continue

        const exclusion = employee.employment_status !== 'Job (With Finger)'
          ? 'cancelled_ineligible'
          : approvedLeave.has(employeeId)
            ? 'cancelled_leave'
            : weeklyOff.has(employeeId)
              ? 'cancelled_day_off'
              : holiday.has(employeeId)
                ? 'cancelled_holiday'
                : null
        const checkedIn = validCheckIn(attendanceByEmployee.get(employeeId) || [], slot)
        const cancelledStatus = checkedIn ? 'cancelled_checked_in' : exclusion

        const alertSeed = {
          employee_id: employeeId,
          branch_id: employee.current_branch_id,
          shift_date: today,
          shift_key: slot.shift_key,
          shift_name: slot.shift_name,
          shift_start_at: shiftStart.toISOString(),
          shift_end_at: shiftEnd.toISOString(),
          candidate_at: candidateAt.toISOString(),
          eligible_to_send_at: eligibleAt.toISOString(),
          last_checked_at: now.toISOString(),
          alert_type: alertType,
          updated_at: now.toISOString(),
        }

        const { data: existing } = await supabase.from('attendance_no_show_alerts')
          .select('*').eq('employee_id', employeeId).eq('shift_date', today).eq('shift_key', slot.shift_key).eq('alert_type', alertType).maybeSingle()

        if (existing && ['notification_created', 'completed', 'completed_with_failures', 'no_matching_recipients'].includes(existing.status)) continue

        if (cancelledStatus) {
          if (existing) {
            await supabase.from('attendance_no_show_alerts').update({
              ...alertSeed, status: cancelledStatus, cancel_reason: cancelledStatus,
            }).eq('id', existing.id)
            summary.cancelled++
          }
          continue
        }

        let alert = existing
        if (!alert) {
          const { data, error } = await supabase.from('attendance_no_show_alerts').insert({
            ...alertSeed, status: 'pending_wait',
          }).select('*').single()
          if (error && error.code !== '23505') throw error
          alert = data
          summary.pending++
        } else {
          const { data } = await supabase.from('attendance_no_show_alerts').update(alertSeed).eq('id', alert.id).select('*').single()
          alert = data || alert
        }
        if (!alert || now < eligibleAt) continue

        // Refresh the full pipeline once per invocation before any notification
        // can be created. If it fails, the invocation stops and nothing is sent.
        attendanceRefresh ||= refreshAttendancePipeline(supabaseUrl, serviceKey, today)
        await attendanceRefresh

        // Final, live verification immediately before delivery creation.
        const [{ data: liveEmployee }, { data: liveLeave }, { data: liveAttendance }] = await Promise.all([
          supabase.from('hr_employee_master_with_status').select('id,current_branch_id,name_en,name_ar,employment_status').eq('id', employeeId).maybeSingle(),
          supabase.from('day_off').select('id').eq('employee_id', employeeId).eq('day_off_date', today).eq('approval_status', 'approved').limit(1),
          supabase.from('hr_analysed_attendance_data').select('shift_start_time,check_in_time,check_out_time,status').eq('employee_id', employeeId).eq('shift_date', today),
        ])
        const hasLiveCheckIn = validCheckIn(liveAttendance || [], slot)
        if (!liveEmployee || liveEmployee.employment_status !== 'Job (With Finger)' || (liveLeave || []).length > 0 || hasLiveCheckIn) {
          const status = (liveLeave || []).length > 0 ? 'cancelled_leave' : hasLiveCheckIn ? 'cancelled_checked_in' : 'cancelled_ineligible'
          await supabase.from('attendance_no_show_alerts').update({ status, cancel_reason: status, last_checked_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq('id', alert.id)
          summary.cancelled++
          continue
        }

        const branchId = Number(liveEmployee.current_branch_id)
        const { data: recipients } = await supabase.from('attendance_notification_recipients')
          .select('id,user_id,delivery_mode,all_branches,attendance_notification_recipient_branches(branch_id)')
          .eq('is_enabled', true)
        const matched = (recipients || []).filter((recipient: any) => recipient.all_branches ||
          (recipient.attendance_notification_recipient_branches || []).some((mapping: any) => Number(mapping.branch_id) === branchId))

        if (matched.length === 0) {
          await supabase.from('attendance_no_show_alerts').update({ status: 'no_matching_recipients', last_checked_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq('id', alert.id)
          continue
        }

        for (const recipient of matched) {
          const { data: user } = await supabase.from('users').select('id,username,status').eq('id', recipient.user_id).maybeSingle()
          const { data: contact } = await supabase.from('hr_employee_master').select('name_en,name_ar,whatsapp_number,email').eq('user_id', recipient.user_id).maybeSingle()
          if (!user || user.status !== 'active' || !contact?.whatsapp_number || !contact?.email) continue
          const deliveryRows = [
            { alert_id: alert.id, recipient_user_id: user.id, channel: 'in_app', destination_snapshot: user.id },
            { alert_id: alert.id, recipient_user_id: user.id, channel: 'whatsapp', destination_snapshot: contact.whatsapp_number },
          ]
          if (recipient.delivery_mode === 'whatsapp_and_email') deliveryRows.push({ alert_id: alert.id, recipient_user_id: user.id, channel: 'email', destination_snapshot: contact.email })
          await supabase.from('attendance_no_show_deliveries').upsert(deliveryRows, { onConflict: 'alert_id,recipient_user_id,channel', ignoreDuplicates: true })
        }
        await supabase.from('attendance_no_show_alerts').update({
          branch_id: branchId, status: 'notification_created', notified_at: new Date().toISOString(), last_checked_at: new Date().toISOString(), updated_at: new Date().toISOString(),
        }).eq('id', alert.id)
        summary.alerted++
      }
    }

    // Deliver all due work, including retries left by previous invocations.
    const { data: dueDeliveries, error: deliveryError } = await supabase.from('attendance_no_show_deliveries')
      .select('*,attendance_no_show_alerts(*)')
      .in('status', ['pending', 'retry_wait'])
      .lt('attempt_count', 3)
      .or(`next_retry_at.is.null,next_retry_at.lte.${now.toISOString()}`)
      .limit(200)
    if (deliveryError) throw deliveryError

    for (const delivery of dueDeliveries || []) {
      const previousStatus = delivery.status
      const { data: claimed } = await supabase.from('attendance_no_show_deliveries').update({
        status: 'processing', attempt_count: delivery.attempt_count + 1, updated_at: new Date().toISOString(),
      }).eq('id', delivery.id).eq('status', previousStatus).select('id').maybeSingle()
      if (!claimed) continue

      try {
        const alert = delivery.attendance_no_show_alerts
        const [{ data: employee }, { data: recipient }, { data: branch }] = await Promise.all([
          supabase.from('hr_employee_master').select('name_en,name_ar').eq('id', alert.employee_id).single(),
          supabase.from('hr_employee_master').select('name_en,name_ar,whatsapp_number,email').eq('user_id', delivery.recipient_user_id).single(),
          supabase.from('branches').select('name_en,name_ar,location_en,location_ar').eq('id', alert.branch_id).single(),
        ])
        const shiftStart = new Date(alert.shift_start_at)
        const shiftEnd = new Date(alert.shift_end_at)
        const checkedAt = new Date(alert.last_checked_at)
        const minutesLate = Math.max(0, Math.floor((now.getTime() - shiftStart.getTime()) / 60_000))
        const employeeEn = employee?.name_en || employee?.name_ar || alert.employee_id
        const employeeAr = employee?.name_ar || employee?.name_en || alert.employee_id
        const branchEn = `${branch?.name_en || ''} - ${branch?.location_en || ''}`.replace(/^\s*-\s*|\s*-\s*$/g, '')
        const branchAr = `${branch?.name_ar || branch?.name_en || ''} - ${branch?.location_ar || branch?.location_en || ''}`.replace(/^\s*-\s*|\s*-\s*$/g, '')
        let providerId: string | null = null

        if (delivery.channel === 'in_app') {
          const { data: notification, error } = await supabase.from('notifications').insert({
            title: `${employeeEn} — Not Reported for Duty`,
            title_en: `${employeeEn} — Not Reported for Duty`,
            title_ar: `${employeeAr} — لم يحضر للعمل حتى الآن`,
            message: `${employeeEn} has not reported for the ${alert.shift_name}.`,
            message_en: `Employee: ${employeeEn}\nStatus: Not reported for duty until now\nBranch: ${branchEn}\nDate: ${formatDateEn(shiftStart)}\nAssigned shift: ${formatTime(shiftStart, 'en-US')} - ${formatTime(shiftEnd, 'en-US')} (${alert.shift_name})\nNotification time: ${formatTime(now, 'en-US')}\nLast checked: ${formatDateEn(checkedAt)} ${formatTime(checkedAt, 'en-US')}`,
            message_ar: `الموظف: ${employeeAr}\nالحالة: لم يحضر للعمل حتى الآن\nالفرع: ${branchAr}\nالتاريخ: ${formatDateAr(shiftStart)}\nالوردية المحددة: ${formatTime(shiftStart, 'ar-SA')} - ${formatTime(shiftEnd, 'ar-SA')} (${alert.shift_name})\nوقت التنبيه: ${formatTime(now, 'ar-SA')}\nآخر وقت تحقق: ${formatDateAr(checkedAt)} ${formatTime(checkedAt, 'ar-SA')}`,
            created_by: 'system', created_by_name: 'Attendance Monitor', created_by_role: 'System',
            target_type: 'specific_users', target_users: [delivery.recipient_user_id],
            type: 'warning', priority: 'high', total_recipients: 1,
            metadata: { attendance_no_show_alert_id: alert.id, employee_id: alert.employee_id, branch_id: alert.branch_id, shift_key: alert.shift_key },
          }).select('id').single()
          if (error) throw error
          providerId = notification.id
        } else if (delivery.channel === 'whatsapp') {
          const { data: account } = await supabase.from('wa_accounts').select('access_token,phone_number_id').eq('is_active', true).eq('is_default', true).maybeSingle()
          if (!account?.access_token || !account?.phone_number_id) throw new Error('WhatsApp account is not configured')
          const phone = String(recipient.whatsapp_number).replace(/[^0-9]/g, '')
          const response = await fetch(`https://graph.facebook.com/${GRAPH_API_VERSION}/${account.phone_number_id}/messages`, {
            method: 'POST', headers: { Authorization: `Bearer ${account.access_token}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({
              messaging_product: 'whatsapp', to: phone, type: 'template',
              template: { name: WHATSAPP_TEMPLATE, language: { code: 'ar' }, components: [{ type: 'body', parameters: [
                { type: 'text', text: employeeAr }, { type: 'text', text: branch?.name_ar || branch?.name_en || '' },
                { type: 'text', text: branch?.location_ar || branch?.location_en || '' }, { type: 'text', text: formatDateAr(shiftStart) },
                { type: 'text', text: formatTime(shiftStart, 'ar-SA') }, { type: 'text', text: formatTime(shiftEnd, 'ar-SA') },
                { type: 'text', text: formatTime(now, 'ar-SA') }, { type: 'text', text: String(minutesLate) },
              ] }] },
            }),
          })
          const result = await response.json()
          if (!response.ok) throw new Error(`WhatsApp delivery failed (${response.status})`)
          providerId = result.messages?.[0]?.id || null
          await supabase.from('whatsapp_message_log').insert({
            phone_number: recipient.whatsapp_number, message_type: 'attendance_no_show', template_name: WHATSAPP_TEMPLATE,
            template_language: 'ar', whatsapp_message_id: providerId, status: 'sent', customer_name: employeeEn,
          })
        } else {
          const { data: account } = await supabase.from('email_accounts').select('*').eq('is_active', true).eq('send_enabled', true).eq('default_for_transactional', true).maybeSingle()
          if (!account) throw new Error('Transactional email account is not configured')
          let queueId = delivery.provider_message_id
          if (!queueId) {
            const subject = `${employeeEn} — Not Reported for Duty | لم يحضر للعمل حتى الآن`
            const textBody = `Attendance Alert\n\nEmployee: ${employeeEn}\nStatus: Not reported for duty until now\nBranch: ${branchEn}\nDate: ${formatDateEn(shiftStart)}\nAssigned shift: ${formatTime(shiftStart, 'en-US')} - ${formatTime(shiftEnd, 'en-US')} (${alert.shift_name})\nNotification time: ${formatTime(now, 'en-US')}\nLast checked time and date: ${formatDateEn(checkedAt)} ${formatTime(checkedAt, 'en-US')}\n\nتنبيه الحضور\n\nالموظف: ${employeeAr}\nالحالة: لم يحضر للعمل حتى الآن\nالفرع: ${branchAr}\nالتاريخ: ${formatDateAr(shiftStart)}\nالوردية المحددة: ${formatTime(shiftStart, 'ar-SA')} - ${formatTime(shiftEnd, 'ar-SA')} (${alert.shift_name})\nوقت التنبيه: ${formatTime(now, 'ar-SA')}\nآخر وقت وتاريخ للتحقق: ${formatDateAr(checkedAt)} ${formatTime(checkedAt, 'ar-SA')}`
            const htmlBody = `<div dir="ltr"><h2>Attendance Alert</h2><p>${textBody.split('\n\nتنبيه الحضور')[0].replaceAll('\n', '<br>')}</p></div><hr><div dir="rtl"><h2>تنبيه الحضور</h2><p>${textBody.split('تنبيه الحضور\n\n')[1].replaceAll('\n', '<br>')}</p></div>`
            const { data: message, error: messageError } = await supabase.from('email_messages').insert({
              email_account_id: account.id, direction: 'outbound', status: 'queued', subject,
              from_name: account.from_name || account.account_name, from_address: account.email_address,
              html_body: htmlBody, text_body: textBody, body_preview: textBody.slice(0, 500),
              source_type: 'attendance_no_show', source_reference: alert.id, priority: 'high',
            }).select('id').single()
            if (messageError) throw messageError
            await supabase.from('email_message_recipients').insert({ email_message_id: message.id, recipient_type: 'to', display_name: recipient.name_en || recipient.name_ar, email_address: recipient.email })
            const { data: queued, error: queueError } = await supabase.from('email_queue').insert({
              queue_type: 'transactional', priority: 2, email_account_id: account.id, email_message_id: message.id,
              status: 'waiting', maximum_attempts: 3, idempotency_key: `attendance-no-show-${delivery.id}`,
            }).select('id').single()
            if (queueError) throw queueError
            queueId = queued.id
            await supabase.from('attendance_no_show_deliveries').update({ provider_message_id: queueId }).eq('id', delivery.id)
          }
          const response = await fetch(`${supabaseUrl}/functions/v1/email-send`, {
            method: 'POST', headers: { Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ queue_id: queueId }),
          })
          const result = await response.json()
          if (!response.ok || !result.success) throw new Error(result.error || `Email delivery failed (${response.status})`)
          providerId = queueId
        }

        await supabase.from('attendance_no_show_deliveries').update({
          status: 'sent', provider_message_id: providerId, sent_at: new Date().toISOString(), next_retry_at: null,
          last_error_code: null, last_error_message: null, updated_at: new Date().toISOString(),
        }).eq('id', delivery.id)
        summary.deliveries++
      } catch (error) {
        const attempt = delivery.attempt_count + 1
        await supabase.from('attendance_no_show_deliveries').update({
          status: attempt >= 3 ? 'permanent_failed' : 'retry_wait',
          next_retry_at: attempt >= 3 ? null : new Date(Date.now() + attempt * 60 * 1000).toISOString(),
          last_error_code: 'delivery_failed', last_error_message: safeError(error), updated_at: new Date().toISOString(),
        }).eq('id', delivery.id)
        summary.errors.push(`${delivery.channel}:${delivery.id}:${safeError(error)}`)
      }
    }

    const { data: openAlerts } = await supabase.from('attendance_no_show_alerts').select('id').eq('shift_date', today).eq('status', 'notification_created')
    for (const alert of openAlerts || []) {
      const { data: states } = await supabase.from('attendance_no_show_deliveries').select('status').eq('alert_id', alert.id)
      if ((states || []).every((row: any) => ['sent', 'permanent_failed', 'skipped'].includes(row.status))) {
        const failed = (states || []).some((row: any) => row.status === 'permanent_failed')
        await supabase.from('attendance_no_show_alerts').update({ status: failed ? 'completed_with_failures' : 'completed', updated_at: new Date().toISOString() }).eq('id', alert.id)
      }
    }

    return json({ success: true, today, ...summary })
  } catch (error) {
    console.error('[attendance-no-show]', error)
    return json({ success: false, error: safeError(error), today, ...summary }, 500)
  }
})
