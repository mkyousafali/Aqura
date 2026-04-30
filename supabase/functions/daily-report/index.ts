import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const body = await req.json().catch(() => ({}))
    let targetDate = body.date as string | undefined

    if (!targetDate) {
      const now = new Date()
      const saudiNow = new Date(now.getTime() + 3 * 60 * 60 * 1000)
      const yesterday = new Date(saudiNow)
      yesterday.setDate(yesterday.getDate() - 1)
      const pad = (n: number) => String(n).padStart(2, '0')
      targetDate = `${yesterday.getFullYear()}-${pad(yesterday.getMonth() + 1)}-${pad(yesterday.getDate())}`
    }

    const dayStart = `${targetDate}T00:00:00`
    const dayEnd   = `${targetDate}T23:59:59`

    const [
      salesResult,
      receivedBillsResult,
      paidBillsResult,
      paidExpensesResult,
      boxOpsResult,
      attendanceResult,
      incidentsResult,
    ] = await Promise.all([
      // 1. Sales
      supabase.from('erp_daily_sales')
        .select('net_amount, net_bills, return_amount, branch_id')
        .eq('sale_date', targetDate),

      // 2. Received bills
      supabase.from('receiving_records')
        .select('vendor_id, branch_id, bill_amount, bill_number')
        .gte('created_at', dayStart)
        .lte('created_at', dayEnd),

      // 3. Paid vendor bills — use updated_at (when payment was actually recorded)
      supabase.from('vendor_payment_schedule')
        .select('vendor_name, final_bill_amount, payment_method, branch_id, branch_name')
        .eq('is_paid', true)
        .gte('updated_at', dayStart)
        .lte('updated_at', dayEnd),

      // 4. All paid expenses — paid_date is a timestamp so use dayStart/dayEnd
      supabase.from('expense_scheduler')
        .select('vendor_name, amount, payment_method, expense_category_name_en, expense_category_name_ar, description, branch_id, branch_name')
        .eq('is_paid', true)
        .gte('paid_date', dayStart)
        .lte('paid_date', dayEnd),

      // 5. Cashier box operations — use complete_details JSONB for cashier name + direct numeric columns
      supabase.from('box_operations')
        .select('branch_id, user_id, box_number, complete_details, total_difference, bank_mada, bank_visa, bank_mastercard, bank_google_pay, bank_other, total_cash_sales, total_erp_sales')
        .eq('status', 'completed')
        .gte('start_time', dayStart)
        .lte('start_time', dayEnd),

      // 6. Attendance — include all relevant fields for late/missing punch/under-time detection
      supabase.from('hr_analysed_attendance_data')
        .select('employee_id, status, worked_minutes, late_minutes, under_minutes, check_in_time, check_out_time, branch_id, employee_name_en, employee_name_ar')
        .eq('shift_date', targetDate),

      // 8. Incidents
      supabase.from('incidents')
        .select('id, employee_id, branch_id, what_happened, report_type, resolution_status, created_at, incident_types(incident_type_en, incident_type_ar), warning_violation(name_en, name_ar)')
        .gte('created_at', dayStart)
        .lte('created_at', dayEnd)
        .order('created_at', { ascending: false }),
    ])

    // Call branch performance RPC for task data
    const taskPerfResult = await supabase.rpc('get_branch_performance_dashboard', {
      p_specific_date: targetDate
    })

    // ── Resolve vendor names ──────────────────────────────────────────
    const vendorNameMap: Record<string, string> = {}
    const receivedBills = receivedBillsResult.data || []
    if (receivedBills.length > 0) {
      const vendorIds = [...new Set(receivedBills.map((r: any) => r.vendor_id).filter(Boolean))]
      if (vendorIds.length > 0) {
        const { data: vendors } = await supabase
          .from('vendors')
          .select('erp_vendor_id, vendor_name')
          .in('erp_vendor_id', vendorIds)
        vendors?.forEach((v: any) => {
          if (v.erp_vendor_id) vendorNameMap[v.erp_vendor_id] = v.vendor_name
        })
      }
    }

    // ── Resolve employee names for incidents ─────────────────────────
    const employeeNameMap: Record<string, { en: string; ar: string }> = {}
    const incidents = incidentsResult.data || []
    if (incidents.length > 0) {
      const empIds = [...new Set(incidents.map((i: any) => i.employee_id).filter(Boolean))]
      if (empIds.length > 0) {
        const { data: emps } = await supabase
          .from('hr_employee_master')
          .select('id, employee_name_en, employee_name_ar')
          .in('id', empIds)
        emps?.forEach((e: any) => {
          employeeNameMap[e.id] = { en: e.employee_name_en || '', ar: e.employee_name_ar || e.employee_name_en || '' }
        })
      }
    }

    // ── Build set of active employees (Job With Finger only) for attendance filter ──
    const { data: activeEmps } = await supabase
      .from('hr_employee_master')
      .select('id')
      .eq('employment_status', 'Job (With Finger)')
    const activeEmpIds = new Set<string>((activeEmps || []).map((e: any) => String(e.id)))

    // ── Resolve branch names ──────────────────────────────────────────
    const allBranchIds = new Set<number>()
    ;[salesResult, receivedBillsResult, boxOpsResult, attendanceResult, incidentsResult].forEach(res => {
      res.data?.forEach((r: any) => { if (r.branch_id) allBranchIds.add(Number(r.branch_id)) })
    })
    ;(taskPerfResult.data?.branch_stats || []).forEach((b: any) => { if (b.branch_id) allBranchIds.add(Number(b.branch_id)) })

    const branchMap: Record<number, { en: string; ar: string }> = {}
    if (allBranchIds.size > 0) {
      const { data: branches } = await supabase
        .from('branches')
        .select('id, location_en, location_ar')
        .in('id', [...allBranchIds])
      branches?.forEach((b: any) => {
        branchMap[b.id] = { en: b.location_en || `Branch ${b.id}`, ar: b.location_ar || b.location_en || `فرع ${b.id}` }
      })
    }

    const bName = (id: any, lang = 'en') => branchMap[Number(id)]?.[lang as 'en' | 'ar'] || (lang === 'ar' ? `فرع ${id}` : `Branch ${id}`)

    // ── Section 1: Sales ─────────────────────────────────────────────
    const salesByBranch: Record<number, any> = {}
    ;(salesResult.data || []).forEach((s: any) => {
      const id = Number(s.branch_id)
      if (!salesByBranch[id]) salesByBranch[id] = { branch_id: id, branch_name_en: bName(id, 'en'), branch_name_ar: bName(id, 'ar'), net_amount: 0, net_bills: 0, return_amount: 0 }
      salesByBranch[id].net_amount    += s.net_amount    || 0
      salesByBranch[id].net_bills     += s.net_bills     || 0
      salesByBranch[id].return_amount += s.return_amount || 0
    })

    // ── Section 2: Received bills grouped by branch ───────────────────
    const receivedByBranch: Record<string, any> = {}
    receivedBills.forEach((b: any) => {
      const key = String(b.branch_id || 'unknown')
      if (!receivedByBranch[key]) receivedByBranch[key] = {
        branch_name_en: bName(b.branch_id, 'en'),
        branch_name_ar: bName(b.branch_id, 'ar'),
        subtotal: 0,
        count: 0,
        bills: [],
      }
      receivedByBranch[key].subtotal += b.bill_amount || 0
      receivedByBranch[key].count += 1
      receivedByBranch[key].bills.push({
        vendor_name: vendorNameMap[b.vendor_id] || b.vendor_id || 'Unknown',
        bill_amount: b.bill_amount || 0,
        bill_number: b.bill_number || '',
      })
    })
    const receivedBillsOut = Object.values(receivedByBranch)

    // ── Section 3: Paid bills ─────────────────────────────────────────
    const paidBillsOut = (paidBillsResult.data || []).map((b: any) => ({
      vendor_name:    b.vendor_name,
      amount:         b.final_bill_amount || 0,
      payment_method: b.payment_method || '',
      branch_name:    b.branch_name || bName(b.branch_id, 'en'),
    }))

    // ── Section 4: Paid expenses ─────────────────────────────────────
    const paidExpensesOut = (paidExpensesResult.data || []).map((e: any) => ({
      category_en:    e.expense_category_name_en || 'General',
      category_ar:    e.expense_category_name_ar || e.expense_category_name_en || 'عام',
      vendor_name:    e.vendor_name   || '',
      branch_name:    e.branch_name   || bName(e.branch_id, 'en'),
      amount:         e.amount        || 0,
      payment_method: e.payment_method || '',
      description:    e.description   || '',
    }))

    // ── Section 5: Cashier reports ──────
    const allBoxOps = boxOpsResult.data || []
    let cashierExcess = 0, cashierShort = 0
    const cashierReportsOut = allBoxOps
      .map((op: any) => {
        const cd = typeof op.complete_details === 'string'
          ? JSON.parse(op.complete_details || '{}')
          : (op.complete_details || {})
        const cashierName    = cd.cashier_name   || cd.completed_by_name || op.user_id || 'Unknown'
        const supervisorName = cd.supervisor_name || cd.completed_by_name || ''
        const diffCash = cd.difference_cash_sales ?? 0
        const diffCard = cd.difference_card_sales ?? 0
        const diffTotal = cd.total_difference ?? op.total_difference ?? 0
        if (diffTotal > 0) cashierExcess += diffTotal
        else if (diffTotal < 0) cashierShort += diffTotal
        return {
          branch_name_en:      bName(op.branch_id, 'en'),
          branch_name_ar:      bName(op.branch_id, 'ar'),
          box_number:          op.box_number         || 0,
          cashier_name:        cashierName,
          supervisor_name:     supervisorName,
          user_id:             op.user_id            || '',
          total_sales:         cd.total_sales        || op.total_erp_sales || 0,
          total_cash_sales:    cd.total_cash_sales   || op.total_cash_sales || 0,
          system_cash_sales:   cd.system_cash_sales  || 0,
          system_card_sales:   cd.system_card_sales  || 0,
          mada:                cd.bank_mada          || op.bank_mada || 0,
          visa:                cd.bank_visa          || op.bank_visa || 0,
          mastercard:          cd.bank_mastercard    || op.bank_mastercard || 0,
          google_pay:          cd.bank_google_pay    || op.bank_google_pay || 0,
          other:               cd.bank_other         || op.bank_other || 0,
          recharge_sales:      cd.recharge_sales     || 0,
          difference_cash:     diffCash,
          difference_card:     diffCard,
          difference_total:    diffTotal,
        }
      })
      // show only where total net difference is >= 5 or <= -5
      .filter((r: any) => Math.abs(r.difference_total) >= 5)

    // ── Section 6: Task performance from RPC ─────────────────────────
    const taskPerformanceOut = (taskPerfResult.data?.branch_stats || []).map((b: any) => ({
      branch_name_en:  b.branch_name_en  || b.branch_name || '',
      branch_name_ar:  b.branch_name_ar  || b.branch_name || '',
      completed:       b.completed_tasks ?? b.completed ?? 0,
      pending:         b.pending_tasks   ?? b.pending   ?? 0,
      overdue:         b.overdue_tasks   ?? b.overdue   ?? 0,
      total:           b.total_tasks     ?? b.total     ?? 0,
      completion_rate: b.completion_rate ?? 0,
    }))

    // ── Section 7: Attendance ─────────────────────────────────────────
    const attByBranch: Record<string, any> = {}
    // Filter to Job (With Finger) employees only — excludes resigned/terminated
    ;(attendanceResult.data || []).filter((a: any) => activeEmpIds.has(String(a.employee_id))).forEach((a: any) => {
      const key  = a.branch_id ? String(a.branch_id) : 'unassigned'
      const name = a.branch_id ? bName(a.branch_id, 'en') : 'Unassigned'
      if (!attByBranch[key]) attByBranch[key] = {
        branch_name_en: name,
        branch_name_ar: a.branch_id ? bName(a.branch_id, 'ar') : 'غير محدد',
        present: 0, absent: 0, late: 0, off: 0, total: 0,
        absent_names: [],
        late_names: [],          // late > 5 minutes
        missing_checkout: [],    // checked in but no check-out recorded
        under_time: [],          // under_minutes > 0 (didn't complete duty hours)
      }
      attByBranch[key].total++
      const s = (a.status || '').toLowerCase()
      if (s === 'absent') {
        attByBranch[key].absent++
        if (a.employee_name_en) attByBranch[key].absent_names.push(a.employee_name_en)
      } else if (s === 'late') {
        attByBranch[key].late++
        if ((a.late_minutes || 0) > 5 && a.employee_name_en) {
          attByBranch[key].late_names.push({ name: a.employee_name_en, late_minutes: a.late_minutes })
        }
      } else if (s === 'present') {
        attByBranch[key].present++
        // Also check late_minutes for present employees who arrived late
        if ((a.late_minutes || 0) > 5 && a.employee_name_en) {
          attByBranch[key].late_names.push({ name: a.employee_name_en, late_minutes: a.late_minutes })
        }
      } else {
        attByBranch[key].off++
      }
      // Missing checkout: has check_in but no check_out, and not absent
      if (s !== 'absent' && a.check_in_time && !a.check_out_time && a.employee_name_en) {
        attByBranch[key].missing_checkout.push(a.employee_name_en)
      }
      // Under duty time: under_minutes > 0, and not absent
      if (s !== 'absent' && (a.under_minutes || 0) > 0 && a.employee_name_en) {
        attByBranch[key].under_time.push({ name: a.employee_name_en, under_minutes: a.under_minutes })
      }
    })

    // ── Section 8: Incidents ──────────────────────────────────────────
    const incidentsOut = incidents.map((inc: any) => ({
      incident_type_en: (inc.incident_types as any)?.incident_type_en || '',
      incident_type_ar: (inc.incident_types as any)?.incident_type_ar || '',
      employee_name_en: employeeNameMap[inc.employee_id]?.en || '',
      employee_name_ar: employeeNameMap[inc.employee_id]?.ar || '',
      branch_name_en:   bName(inc.branch_id, 'en'),
      branch_name_ar:   bName(inc.branch_id, 'ar'),
      violation_en:     (inc.warning_violation as any)?.name_en || '',
      violation_ar:     (inc.warning_violation as any)?.name_ar || '',
      what_happened:    inc.what_happened     || '',
      resolution_status: inc.resolution_status || 'pending',
      report_type:      inc.report_type       || '',
    }))

    return new Response(JSON.stringify({
      date:            targetDate,
      sales:           Object.values(salesByBranch),
      receivedBills:   receivedBillsOut,
      paidBills:       paidBillsOut,
      paidExpenses:    paidExpensesOut,
      cashierReports:  cashierReportsOut,
      cashierSummary:  { totalExcess: cashierExcess, totalShort: cashierShort, totalBoxes: allBoxOps.length, flagged: cashierReportsOut.length },
      taskPerformance: taskPerformanceOut,
      attendance:      Object.values(attByBranch),
      incidents:       incidentsOut,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
