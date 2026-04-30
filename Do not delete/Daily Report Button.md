# Daily Report — Full Implementation Plan

---

## What Are We Building?

We're adding a **"Daily Report"** button to the AI chat window. When a manager clicks it, the system pulls yesterday's full operational data — sales, vendor bills, expenses, cashier summaries, tasks, and attendance — and sends it to Gemini AI, which comes back with a smart analysis and recommendations, all displayed right in the chat.

The heavy data fetching happens in a **Supabase Edge Function** (server-side), not in the browser. The frontend just calls one endpoint, gets back structured data, and passes it to the AI.

---

## Part 1 — Supabase Edge Function

### What It Does
Runs on Supabase's servers. Queries all 7 report sections from the database using the **service role key** (full access, no RLS restrictions), and returns clean JSON to the frontend.

### File Location
```
supabase/functions/daily-report/index.ts
```

### How to Call It (from frontend)
```
POST https://<your-project>.supabase.co/functions/v1/daily-report
Body: { "date": "2025-01-15" }   ← optional, defaults to yesterday (Saudi TZ)
Headers: Authorization: Bearer <user's JWT token>
```

### What It Returns
```json
{
  "date": "2025-01-15",
  "dateDisplay": "Tuesday, January 15, 2025",
  "sales": [ { "branch_id": 1, "branch_name": "Riyadh", "net_amount": 15000, "net_bills": 120, "return_amount": 300 } ],
  "receivedBills": [ { "vendor_name": "Al Watania", "branch_name": "Riyadh", "bill_amount": 5000, "bill_number": "INV-001" } ],
  "paidBills": [ { "vendor_name": "Al Jazeera", "amount": 3000, "payment_method": "Bank Transfer" } ],
  "paidExpenses": [ { "category": "Utilities", "vendor_name": "SEC", "branch_name": "Jeddah", "amount": 1200, "payment_method": "Bank Transfer" } ],
  "cashierReports": [ { "branch_name": "Riyadh", "cashier_index": 1, "total_sales": 8000, "cash": 4000, "mada": 2500, "visa": 1500, "mastercard": 0, "google_pay": 0, "other": 0, "difference": 50 } ],
  "taskPerformance": [ { "branch_name": "Riyadh", "completed": 5, "pending": 2, "overdue": 1 } ],
  "attendance": [ { "branch_name": "Riyadh", "present": 18, "absent": 2, "late": 3, "total": 23 } ]
}
```

### Edge Function Code

```typescript
// supabase/functions/daily-report/index.ts

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
    // Use service role key — full DB access, no RLS
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Get date from request body, or default to yesterday in Saudi TZ
    const body = await req.json().catch(() => ({}))
    let targetDate = body.date as string | undefined

    if (!targetDate) {
      const now = new Date()
      // Saudi Arabia = UTC+3
      const saudiNow = new Date(now.getTime() + 3 * 60 * 60 * 1000)
      const yesterday = new Date(saudiNow)
      yesterday.setDate(yesterday.getDate() - 1)
      const pad = (n: number) => String(n).padStart(2, '0')
      targetDate = `${yesterday.getFullYear()}-${pad(yesterday.getMonth() + 1)}-${pad(yesterday.getDate())}`
    }

    const dayStart = `${targetDate}T00:00:00`
    const dayEnd   = `${targetDate}T23:59:59`

    // ── Fetch all sections in parallel ────────────────────────────────
    const [
      salesResult,
      receivedBillsResult,
      paidBillsResult,
      paidExpVpsResult,
      paidExpensesResult,
      boxOpsResult,
      taskResult,
      quickTaskResult,
      attendanceResult,
    ] = await Promise.all([
      // 1. Sales
      supabase.from('erp_daily_sales')
        .select('net_amount, net_bills, return_amount, branch_id')
        .eq('sale_date', targetDate),

      // 2. Received bills (vendor invoices logged yesterday)
      supabase.from('receiving_records')
        .select('vendor_id, branch_id, bill_amount, bill_number')
        .gte('created_at', dayStart)
        .lte('created_at', dayEnd),

      // 3a. Paid bills from vendor_payment_schedule
      supabase.from('vendor_payment_schedule')
        .select('vendor_name, final_bill_amount, payment_method, branch_id')
        .eq('is_paid', true)
        .gte('paid_date', targetDate)
        .lte('paid_date', targetDate),

      // 3b. Vendor-linked paid bills from expense_scheduler
      supabase.from('expense_scheduler')
        .select('vendor_name, amount, payment_method, branch_id')
        .eq('is_paid', true)
        .gte('paid_date', targetDate)
        .lte('paid_date', targetDate)
        .not('vendor_id', 'is', null),

      // 4. All paid expenses
      supabase.from('expense_scheduler')
        .select('vendor_name, amount, payment_method, expense_category_name_en, expense_category_name_ar, description, branch_id, branch_name')
        .eq('is_paid', true)
        .gte('paid_date', targetDate)
        .lte('paid_date', targetDate),

      // 5. Cashier box operations
      supabase.from('box_operations')
        .select('closing_details, branch_id')
        .eq('status', 'completed')
        .gte('start_time', dayStart)
        .lte('start_time', dayEnd),

      // 6a. Regular tasks due yesterday
      supabase.from('task_assignments')
        .select('status, assigned_to_branch_id')
        .eq('deadline_date', targetDate),

      // 6b. Quick tasks due yesterday
      supabase.from('quick_task_assignments')
        .select('status')
        .eq('deadline_date', targetDate),

      // 7. Attendance
      supabase.from('hr_analysed_attendance_data')
        .select('status, worked_minutes, late_minutes, branch_id')
        .eq('shift_date', targetDate),
    ])

    // ── Resolve vendor names for receiving_records ────────────────────
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

    // ── Resolve branch names ──────────────────────────────────────────
    const allBranchIds = new Set<number>()
    ;[salesResult, receivedBillsResult, boxOpsResult, attendanceResult].forEach(res => {
      res.data?.forEach((r: any) => { if (r.branch_id) allBranchIds.add(Number(r.branch_id)) })
    })
    taskResult.data?.forEach((t: any) => { if (t.assigned_to_branch_id) allBranchIds.add(Number(t.assigned_to_branch_id)) })

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

    // ── Build response ────────────────────────────────────────────────

    // Section 1: Sales
    const salesByBranch: Record<number, any> = {}
    ;(salesResult.data || []).forEach((s: any) => {
      const id = Number(s.branch_id)
      if (!salesByBranch[id]) salesByBranch[id] = { branch_id: id, branch_name_en: bName(id, 'en'), branch_name_ar: bName(id, 'ar'), net_amount: 0, net_bills: 0, return_amount: 0 }
      salesByBranch[id].net_amount    += s.net_amount    || 0
      salesByBranch[id].net_bills     += s.net_bills     || 0
      salesByBranch[id].return_amount += s.return_amount || 0
    })

    // Section 2: Received bills
    const receivedBillsOut = receivedBills.map((b: any) => ({
      vendor_name : vendorNameMap[b.vendor_id] || b.vendor_id || 'Unknown',
      branch_name_en: bName(b.branch_id, 'en'),
      branch_name_ar: bName(b.branch_id, 'ar'),
      bill_amount : b.bill_amount  || 0,
      bill_number : b.bill_number  || '',
    }))

    // Section 3: Paid bills (combined)
    const paidBillsOut = [
      ...(paidBillsResult.data  || []).map((b: any) => ({ vendor_name: b.vendor_name, amount: b.final_bill_amount || 0, payment_method: b.payment_method || '' })),
      ...(paidExpVpsResult.data || []).map((e: any) => ({ vendor_name: e.vendor_name,  amount: e.amount           || 0, payment_method: e.payment_method || '' })),
    ]

    // Section 4: Paid expenses
    const paidExpensesOut = (paidExpensesResult.data || []).map((e: any) => ({
      category_en : e.expense_category_name_en || 'General',
      category_ar : e.expense_category_name_ar || e.expense_category_name_en || 'عام',
      vendor_name : e.vendor_name   || '',
      branch_name : e.branch_name   || bName(e.branch_id, 'en'),
      amount      : e.amount        || 0,
      payment_method: e.payment_method || '',
      description : e.description   || '',
    }))

    // Section 5: Cashier reports
    const cashierReportsOut = (boxOpsResult.data || []).map((op: any, i: number) => {
      const cd = typeof op.closing_details === 'string' ? JSON.parse(op.closing_details || '{}') : (op.closing_details || {})
      return {
        cashier_index : i + 1,
        branch_name_en: bName(op.branch_id, 'en'),
        branch_name_ar: bName(op.branch_id, 'ar'),
        total_sales   : cd.total_sales       || 0,
        cash          : cd.total_cash_sales  || 0,
        mada          : cd.bank_mada         || 0,
        visa          : cd.bank_visa         || 0,
        mastercard    : cd.bank_mastercard   || 0,
        google_pay    : cd.bank_google_pay   || 0,
        other         : cd.bank_other        || 0,
        difference    : cd.total_difference  || 0,
      }
    })

    // Section 6: Task performance by branch
    const taskByBranch: Record<string, any> = {}
    const allTasks = [
      ...(taskResult.data      || []).map((t: any) => ({ status: t.status, branchId: t.assigned_to_branch_id })),
      ...(quickTaskResult.data || []).map((t: any) => ({ status: t.status, branchId: null })),
    ]
    allTasks.forEach(t => {
      const key  = t.branchId ? String(t.branchId) : 'unassigned'
      const name = t.branchId ? bName(t.branchId, 'en') : 'Unassigned'
      if (!taskByBranch[key]) taskByBranch[key] = { branch_name_en: name, branch_name_ar: t.branchId ? bName(t.branchId, 'ar') : 'غير محدد', completed: 0, pending: 0, overdue: 0 }
      if      (t.status === 'completed') taskByBranch[key].completed++
      else if (t.status === 'overdue')   taskByBranch[key].overdue++
      else                               taskByBranch[key].pending++
    })

    // Section 7: Attendance by branch
    const attByBranch: Record<string, any> = {}
    ;(attendanceResult.data || []).forEach((a: any) => {
      const key  = a.branch_id ? String(a.branch_id) : 'unassigned'
      const name = a.branch_id ? bName(a.branch_id, 'en') : 'Unassigned'
      if (!attByBranch[key]) attByBranch[key] = { branch_name_en: name, branch_name_ar: a.branch_id ? bName(a.branch_id, 'ar') : 'غير محدد', present: 0, absent: 0, late: 0, total: 0 }
      attByBranch[key].total++
      if      (a.status === 'Present') attByBranch[key].present++
      else if (a.status === 'Absent')  attByBranch[key].absent++
      else if (a.status === 'Late')    attByBranch[key].late++
    })

    // ── Final response ────────────────────────────────────────────────
    return new Response(JSON.stringify({
      date        : targetDate,
      sales       : Object.values(salesByBranch),
      receivedBills: receivedBillsOut,
      paidBills   : paidBillsOut,
      paidExpenses: paidExpensesOut,
      cashierReports: cashierReportsOut,
      taskPerformance: Object.values(taskByBranch),
      attendance  : Object.values(attByBranch),
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
```

### Deploy Command
```bash
supabase functions deploy daily-report
```

---

## Part 2 — Frontend Changes

### File to Modify
```
frontend/src/lib/components/desktop-interface/common/ChatWindow.svelte
```

---

### Button Position

The chat window has a **quick-actions bar** just below the header and above the messages area. It currently has one button — "Sales Report". The new "Daily Report" button goes **immediately to the right of it** (or to the left in Arabic RTL layout).

```
┌─────────────────────────────────────────┐
│  🤖 Aqura          [🔊] [🗑️] [✕]       │  ← Header (draggable)
├─────────────────────────────────────────┤
│  [📊 Sales Report]  [📋 Daily Report]   │  ← Quick-actions bar  ← HERE
├─────────────────────────────────────────┤
│                                         │
│   chat messages ...                     │
│                                         │
├─────────────────────────────────────────┤
│  [ type your message... ]  [🎤] [➤]    │  ← Input area
└─────────────────────────────────────────┘
```

---

### New State Variables
Add these two variables alongside the existing `hasSalesPermission` and `salesLoading`:

```ts
// No new variable needed — reuses hasSalesPermission
let dailyLoading = false;
```

---

### Permission Check
Inside the existing `onMount` permission block, add one line for master admin and one line for regular users:

```ts
// No changes needed here — Daily Report shares the existing hasSalesPermission flag.
// Anyone who already has SALES_REPORT permission can also use Daily Report.
// Master admin already sets hasSalesPermission = true, which covers both buttons.
```

---

### Button HTML
Add this button right after the existing Sales Report button inside the `.quick-actions` div:

```html
<button
    class="quick-action-btn"
    on:click={handleDailyReport}
    disabled={!hasSalesPermission || dailyLoading}
    title={hasSalesPermission
        ? (isArabic ? 'التقرير اليومي الكامل' : 'Full Daily Report')
        : (isArabic ? 'ليس لديك صلاحية' : 'No permission')}
>
    <span class="quick-action-icon">📋</span>
    <span class="quick-action-label">{isArabic ? 'التقرير اليومي' : 'Daily Report'}</span>
    {#if !hasSalesPermission}
        <span class="lock-icon">🔒</span>
    {/if}
</button>
```

---

### handleDailyReport() Function
Add this function after `handleSalesReport()`. It calls the edge function, formats the response into a readable text block, and sends it to Gemini for analysis:

```ts
async function handleDailyReport() {
    if (dailyLoading) return;
    if (closingCountdown) cancelCountdown();
    resetInactivityTimer();

    messages = [...messages, { role: 'user', content: isArabic ? '📋 التقرير اليومي' : '📋 Daily Report' }];
    await scrollToBottom();

    dailyLoading = true;
    isLoading = true;

    try {
        // Call the edge function
        const { data: sessionData } = await supabase.auth.getSession();
        const token = sessionData.session?.access_token;

        const res = await fetch(
            `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/daily-report`,
            {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`,
                },
                body: JSON.stringify({}), // uses yesterday by default
            }
        );

        if (!res.ok) throw new Error(`Edge function error: ${res.status}`);
        const report = await res.json();
        if (report.error) throw new Error(report.error);

        // ── Format the data into readable text ─────────────────────────
        const fmt = (n: number) => n.toLocaleString('en-US', { maximumFractionDigits: 0 });
        const cur = isArabic ? 'ر.س' : 'SAR';
        const na  = isArabic ? 'لا توجد بيانات' : 'No data available';
        const L   = (ar: string, en: string) => isArabic ? ar : en;
        const lines: string[] = [];

        lines.push(L(`📅 تقرير يوم ${report.date}`, `📅 Daily Report — ${report.date}`));
        lines.push('═'.repeat(40));

        // 1. Sales
        lines.push('');
        lines.push(L('💰 المبيعات حسب الفرع', '💰 Sales by Branch'));
        lines.push('─'.repeat(30));
        if (report.sales?.length) {
            let tAmt = 0, tBills = 0, tRet = 0;
            report.sales.forEach((s: any) => {
                const name = L(s.branch_name_ar, s.branch_name_en);
                lines.push(L(
                    `🏪 ${name}: ${fmt(s.net_amount)} ${cur} | الفواتير: ${s.net_bills} | المرتجعات: ${fmt(s.return_amount)} ${cur}`,
                    `🏪 ${name}: ${fmt(s.net_amount)} ${cur} | Bills: ${s.net_bills} | Returns: ${fmt(s.return_amount)} ${cur}`
                ));
                tAmt += s.net_amount; tBills += s.net_bills; tRet += s.return_amount;
            });
            lines.push(L(
                `📊 الإجمالي: ${fmt(tAmt)} ${cur} | الفواتير: ${tBills} | المرتجعات: ${fmt(tRet)} ${cur}`,
                `📊 Total: ${fmt(tAmt)} ${cur} | Bills: ${tBills} | Returns: ${fmt(tRet)} ${cur}`
            ));
        } else { lines.push(na); }

        // 2. Received Bills
        lines.push('');
        lines.push(L('📥 الفواتير المستلمة من الموردين', '📥 Vendor Bills Received'));
        lines.push('─'.repeat(30));
        if (report.receivedBills?.length) {
            let total = 0;
            report.receivedBills.forEach((b: any) => {
                total += b.bill_amount;
                const branch = L(b.branch_name_ar, b.branch_name_en);
                lines.push(`• ${b.vendor_name} (${branch}): ${fmt(b.bill_amount)} ${cur}${b.bill_number ? ` — #${b.bill_number}` : ''}`);
            });
            lines.push(L(`الإجمالي: ${fmt(total)} ${cur} (${report.receivedBills.length} فاتورة)`, `Total: ${fmt(total)} ${cur} (${report.receivedBills.length} bills)`));
        } else { lines.push(na); }

        // 3. Paid Bills
        lines.push('');
        lines.push(L('✅ الفواتير المدفوعة', '✅ Bills Paid'));
        lines.push('─'.repeat(30));
        if (report.paidBills?.length) {
            let total = 0;
            report.paidBills.forEach((b: any) => {
                total += b.amount;
                lines.push(`• ${b.vendor_name}: ${fmt(b.amount)} ${cur}${b.payment_method ? ` (${b.payment_method})` : ''}`);
            });
            lines.push(L(`إجمالي المدفوع: ${fmt(total)} ${cur}`, `Total Paid: ${fmt(total)} ${cur}`));
        } else { lines.push(na); }

        // 4. Paid Expenses
        lines.push('');
        lines.push(L('💸 المصروفات المدفوعة', '💸 Paid Expenses'));
        lines.push('─'.repeat(30));
        if (report.paidExpenses?.length) {
            let total = 0;
            report.paidExpenses.forEach((e: any) => {
                total += e.amount;
                const cat = L(e.category_ar, e.category_en);
                lines.push(`• ${cat}${e.vendor_name ? ` — ${e.vendor_name}` : ''} (${e.branch_name}): ${fmt(e.amount)} ${cur}${e.payment_method ? ` | ${e.payment_method}` : ''}`);
            });
            lines.push(L(`إجمالي المصروفات: ${fmt(total)} ${cur}`, `Total Expenses: ${fmt(total)} ${cur}`));
        } else { lines.push(na); }

        // 5. Cashier Reports
        lines.push('');
        lines.push(L('🖥️ تقارير الكاشيرات', '🖥️ Cashier Reports'));
        lines.push('─'.repeat(30));
        if (report.cashierReports?.length) {
            let totalExcess = 0, totalShort = 0;
            report.cashierReports.forEach((c: any) => {
                const branch = L(c.branch_name_ar, c.branch_name_en);
                const diff = c.difference;
                if (diff > 0) totalExcess += diff; else totalShort += diff;
                const diffLabel = diff > 0
                    ? L(`زيادة +${fmt(diff)}`, `Excess +${fmt(diff)}`)
                    : diff < 0 ? L(`نقص ${fmt(diff)}`, `Short ${fmt(diff)}`) : L('متوازن', 'Balanced');
                lines.push(L(
                    `كاشير ${c.cashier_index} (${branch}): مبيعات ${fmt(c.total_sales)} | نقدي ${fmt(c.cash)} | مدى ${fmt(c.mada)} | فيزا ${fmt(c.visa)} | ماستر ${fmt(c.mastercard)} | ${diffLabel} ${cur}`,
                    `Cashier ${c.cashier_index} (${branch}): Sales ${fmt(c.total_sales)} | Cash ${fmt(c.cash)} | Mada ${fmt(c.mada)} | Visa ${fmt(c.visa)} | MC ${fmt(c.mastercard)} | GPay ${fmt(c.google_pay)} | ${diffLabel} ${cur}`
                ));
            });
            lines.push(L(
                `إجمالي الزيادات: ${fmt(totalExcess)} ${cur} | إجمالي النقص: ${fmt(Math.abs(totalShort))} ${cur}`,
                `Total Excess: ${fmt(totalExcess)} ${cur} | Total Short: ${fmt(Math.abs(totalShort))} ${cur}`
            ));
        } else { lines.push(na); }

        // 6. Branch Task Performance
        lines.push('');
        lines.push(L('📋 أداء المهام حسب الفرع', '📋 Branch Task Performance'));
        lines.push('─'.repeat(30));
        if (report.taskPerformance?.length) {
            report.taskPerformance.forEach((t: any) => {
                const branch = L(t.branch_name_ar, t.branch_name_en);
                lines.push(L(
                    `${branch}: مكتمل ${t.completed} | معلق ${t.pending} | متأخر ${t.overdue}`,
                    `${branch}: Completed ${t.completed} | Pending ${t.pending} | Overdue ${t.overdue}`
                ));
            });
        } else { lines.push(na); }

        // 7. Attendance
        lines.push('');
        lines.push(L('👥 ملخص الحضور', '👥 Attendance Summary'));
        lines.push('─'.repeat(30));
        if (report.attendance?.length) {
            report.attendance.forEach((a: any) => {
                const branch = L(a.branch_name_ar, a.branch_name_en);
                lines.push(L(
                    `${branch}: حاضر ${a.present} | غائب ${a.absent} | متأخر ${a.late} | الإجمالي ${a.total}`,
                    `${branch}: Present ${a.present} | Absent ${a.absent} | Late ${a.late} | Total ${a.total}`
                ));
            });
        } else { lines.push(na); }

        // ── Send to Gemini for analysis + suggestions + education ────────
        const dataContext = lines.join('\n');
        const prompt = L(
            `فيما يلي تقرير يوم أمس الكامل:\n\n${dataContext}\n\nبناءً على هذه البيانات، قدّم ردًا منظمًا يتضمن الأقسام التالية:\n\n📊 **التحليل** — حلّل الأرقام وأبرز أي انحرافات أو نقاط مهمة لكل قسم.\n\n⚠️ **المخاوف والتنبيهات** — اذكر أي مشاكل تحتاج اهتمامًا فوريًا (نقص في الكاشير، غياب موظفين، مهام متأخرة، إلخ).\n\n💡 **الاقتراحات** — قدّم اقتراحات عملية لتحسين الأداء بناءً على البيانات.\n\n📚 **التوجيه والتعليم** — أضف ملاحظات تعليمية أو إرشادات للفريق حول أفضل الممارسات المتعلقة بما ظهر في التقرير.\n\n✅ **التعليمات** — اذكر خطوات واضحة وقابلة للتنفيذ يجب على الإدارة اتخاذها اليوم.`,
            `Below is yesterday's complete daily report:\n\n${dataContext}\n\nBased on this data, provide a structured response with the following sections:\n\n📊 **Analysis** — Analyse the numbers and highlight any deviations or key points for each section.\n\n⚠️ **Concerns & Alerts** — Call out any issues needing immediate attention (cashier shorts, staff absences, overdue tasks, etc.).\n\n💡 **Suggestions** — Provide practical suggestions to improve performance based on the data.\n\n📚 **Guidance & Education** — Add educational notes or guidance for the team on best practices related to what appeared in the report.\n\n✅ **Instructions** — List clear, actionable steps management should take today.`
        );

        const reply = await sendChatMessage([{ role: 'user', content: prompt }], $currentLocale);
        messages = [...messages, { role: 'assistant', content: reply }];
        speakText(reply);

    } catch (err: any) {
        messages = [...messages, {
            role: 'assistant',
            content: isArabic
                ? `عذرًا، حدث خطأ: ${err.message}`
                : `Sorry, an error occurred: ${err.message}`
        }];
    }

    dailyLoading = false;
    isLoading = true;
    resetInactivityTimer();
    await scrollToBottom();
}
```

---

## Part 3 — Permissions Setup (Admin Panel)

**No new permission required.** The Daily Report button reuses the existing **`SALES_REPORT`** button permission. Any user who already has access to the Sales Report button will automatically see the Daily Report button enabled. No changes needed in the `sidebar_buttons` table or Button Permissions manager.

---

## Database Tables Used

| Table | What We Fetch |
|-------|--------------|
| `erp_daily_sales` | Net sales, bill count, returns — per branch |
| `receiving_records` | Vendor bills received (bill amount, bill number) |
| `vendors` | Vendor names (looked up via `erp_vendor_id`) |
| `vendor_payment_schedule` | Vendor bills that were paid yesterday |
| `expense_scheduler` | All expenses paid yesterday (vendor + non-vendor) |
| `box_operations` | Cashier session summaries (sales, cash, card, excess/short) |
| `task_assignments` | Regular tasks with yesterday's deadline |
| `quick_task_assignments` | Quick tasks with yesterday's deadline |
| `hr_analysed_attendance_data` | Yesterday's attendance status per employee |
| `incidents` | Incidents reported yesterday (type, employee, branch, status) |
| `incident_types` | Incident type names (EN + AR) |
| `warning_violation` | Violation names linked to incidents (EN + AR) |
| `hr_employee_master` | Employee names for incident lookup |
| `branches` | Branch names (EN + AR) |
| `button_permissions` | Checked on login to enable/disable the button |

---

## Section 8 — Incident Summary

### Data Source
- **Table**: `incidents`
- **Joined tables**: `incident_types` (for type name EN/AR), `warning_violation` (for violation name EN/AR)
- **Employee names**: resolved from `hr_employee_master` via `employee_id`
- **Filter**: `created_at` in yesterday's range

### Fields to Fetch
```
id, incident_type_id, employee_id, branch_id, violation_id,
what_happened, report_type, resolution_status, created_at,
incident_types(incident_type_en, incident_type_ar),
warning_violation(name_en, name_ar)
```

### Edge Function Query (add to `Promise.all`)
```ts
// 8. Incidents reported yesterday
supabase.from('incidents')
  .select('id, employee_id, branch_id, what_happened, report_type, resolution_status, created_at, incident_types(incident_type_en, incident_type_ar), warning_violation(name_en, name_ar)')
  .gte('created_at', dayStart)
  .lte('created_at', dayEnd)
  .order('created_at', { ascending: false }),
```

After fetching, resolve employee names from `hr_employee_master` via unique `employee_id` values (same pattern as vendor name lookup).

### Edge Function Response Field
```json
"incidents": [
  {
    "incident_type_en": "Theft",
    "incident_type_ar": "سرقة",
    "employee_name_en": "Ahmed Ali",
    "employee_name_ar": "أحمد علي",
    "branch_name_en": "Riyadh",
    "branch_name_ar": "الرياض",
    "violation_en": "Policy Breach",
    "violation_ar": "مخالفة السياسة",
    "what_happened": "Employee was caught...",
    "resolution_status": "pending",
    "report_type": "violation"
  }
]
```

### Frontend Formatting (add after Attendance section)
```ts
// 8. Incidents
lines.push('');
lines.push(L('🚨 الحوادث المُبلَّغ عنها', '🚨 Reported Incidents'));
lines.push('─'.repeat(30));
if (report.incidents?.length) {
    report.incidents.forEach((inc: any, i: number) => {
        const type    = L(inc.incident_type_ar, inc.incident_type_en) || '?';
        const emp     = L(inc.employee_name_ar, inc.employee_name_en) || '-';
        const branch  = L(inc.branch_name_ar,   inc.branch_name_en)   || '-';
        const status  = inc.resolution_status || 'pending';
        const violation = inc.violation_en ? ` | ${L(inc.violation_ar, inc.violation_en)}` : '';
        lines.push(`${i + 1}. [${type}] ${emp} — ${branch}${violation} | ${L('الحالة', 'Status')}: ${status}`);
        if (inc.what_happened) lines.push(`   ${inc.what_happened}`);
    });
    lines.push(L(`الإجمالي: ${report.incidents.length} حادثة`, `Total: ${report.incidents.length} incident(s)`));
} else { lines.push(L('لا توجد حوادث مُبلَّغ عنها أمس', 'No incidents reported yesterday')); }
```

---

## Section 9 — AI Analysis, Suggestions, Education & Instructions

This is not a data section — it is the **entire AI response**. After sections 1–7 are assembled into plain text and sent to Gemini, the AI is explicitly instructed to return a structured reply with five named sub-sections:

| Sub-section | What It Contains |
|-------------|-----------------|
| 📊 **Analysis** | Reads through the numbers, spots trends, deviations, and notable figures |
| ⚠️ **Concerns & Alerts** | Flags urgent issues — cashier shorts, high absences, overdue tasks, unpaid bills |
| 💡 **Suggestions** | Practical ideas to improve what the data reveals |
| 📚 **Guidance & Education** | Best-practice tips and teaching points for the team based on what appeared |
| ✅ **Instructions** | Clear step-by-step actions management should take today |

The AI prompt (inside `handleDailyReport`) explicitly names these five sub-sections in both Arabic and English so Gemini always structures its response the same way regardless of language.

---

## Checklist Before Going Live

- [ ] Edge function deployed: `supabase functions deploy daily-report`
- [ ] No new permission needed — reuses existing `SALES_REPORT` permission
- [ ] Frontend: add `dailyLoading` variable (no new permission variable needed)
- [ ] Daily Report button added to quick-actions bar (second position, after Sales Report)
- [ ] `handleDailyReport()` function added after `handleSalesReport()`
- [ ] Incidents section added (section 8) — query `incidents` table + resolve employee names from `hr_employee_master`
- [ ] AI prompt includes all 5 sub-sections: Analysis, Concerns, Suggestions, Education, Instructions
- [ ] Tested with no data (all sections show "No data available" gracefully)
- [ ] Tested in Arabic (RTL) and English (LTR)
- [ ] TTS reads the AI response when voice is enabled
