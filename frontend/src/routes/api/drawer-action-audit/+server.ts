import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

type AuditRow = {
  id: string; at: string; branchId: number; userId: string; userNameEn: string; userNameAr: string;
  branchNameEn: string; branchNameAr: string; action: string; reason: string;
  requestId: string; requestNumber: string; printer: string; printStatus: string; posCounter: string; posNumber: string;
  amount: number | null; status: string; details: Record<string, unknown>;
};

const printLabels: Record<string, string> = {
  printer_selection: 'Printer Selection', test_print_attempt: 'Test Print Attempt',
  test_print_success: 'Test Print Success', test_print_failure: 'Test Print Failure',
  opening_pos_counter: 'Counter Opened', closing_pos_counter: 'Counter Closed',
  recharge_card_operation: 'Recharge Card Operation', other_reason: 'Counter Opened',
  final_print_attempt: 'Print Attempt', final_print_success: 'Print Success',
  final_print_failure: 'Print Failure',
  safe_box_opening: 'Safe Box Opening Print',
  pos_counter_opening: 'Counter Opened'
};
function cashierAction(item: any): string {
  if (['final_print_attempt', 'final_print_success', 'final_print_failure'].includes(item.action_type)) {
    if (item.reason === 'Closing a POS Counter') return 'Counter Closed';
    if (item.reason === 'Recharge Card Operation') return 'Recharge Card Operation';
    return 'Counter Opened';
  }
  return printLabels[item.action_type] || item.action_type;
}
const pageSize = 75;
const sourceLimit = 10000;

function text(value: unknown): string { return typeof value === 'string' ? value : ''; }
function number(value: unknown): number | null {
  const parsed = Number(value);
  return value == null || !Number.isFinite(parsed) ? null : parsed;
}
function validDate(value: string): boolean {
  if (!value) return true;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const ms = Date.parse(`${value}T00:00:00+03:00`);
  return Number.isFinite(ms) && new Date(ms + 3 * 60 * 60 * 1000).toISOString().slice(0, 10) === value;
}
function isSafePrint(item: any): boolean {
  return item.action_type === 'safe_box_opening' || item.source === 'Aqura Safe Box';
}

export const GET: RequestHandler = async ({ cookies, url }) => {
  let actor;
  try { actor = await requireBreakUser(cookies, 'desktop'); }
  catch { return json({ error: 'Desktop session required.' }, { status: 401 }); }
  try {
    const db = databaseClient();
    if (!actor.isMasterAdmin) {
      const { data: permission, error } = await db.from('button_permissions').select('button_code')
        .eq('user_id', actor.id).eq('button_code', 'DRAWER_ACTION_MONITOR').eq('is_enabled', true).maybeSingle();
      if (error) throw error;
      if (!permission) return json({ error: 'Drawer Action report access required.' }, { status: 403 });
    }
    const { data: ownEmployee, error: ownError } = await db.from('hr_employee_master')
      .select('current_branch_id').eq('user_id', actor.id).maybeSingle();
    if (ownError) throw ownError;
    const ownBranch = Number(ownEmployee?.current_branch_id || 0);
    if (!actor.isMasterAdmin && !ownBranch) return json({ error: 'No branch is assigned to this user.' }, { status: 403 });

    const mode = url.searchParams.get('mode');
    const branchValue = url.searchParams.get('branchId') || '';
    const branchFilter = Number(branchValue || 0);
    const branchId = actor.isMasterAdmin ? branchFilter : ownBranch;
    if (branchValue && (!/^\d+$/.test(branchValue) || !Number.isSafeInteger(branchFilter) || branchFilter <= 0 ||
      (!actor.isMasterAdmin && branchFilter !== ownBranch))) {
      return json({ error: 'Branch access denied.' }, { status: 403 });
    }
    const [{ data: branches, error: branchError }, { data: employees, error: employeeError }] = await Promise.all([
      db.from('branches').select('id,name_en,name_ar').order('id'),
      branchId ? db.from('hr_employee_master').select('user_id,name_en,name_ar,current_branch_id').eq('current_branch_id', branchId)
        : db.from('hr_employee_master').select('user_id,name_en,name_ar,current_branch_id')
    ]);
    if (branchError || employeeError) throw branchError || employeeError;
    const allowedBranches = actor.isMasterAdmin ? (branches || []) : (branches || []).filter(b => Number(b.id) === ownBranch);
    const allowedEmployees = (employees || []).filter(e => actor.isMasterAdmin || Number(e.current_branch_id) === ownBranch);
    if (mode === 'options') {
      return json({ branches: allowedBranches, users: allowedEmployees.map(e => ({ id: e.user_id,
        nameEn: e.name_en || '', nameAr: e.name_ar || '', branchId: Number(e.current_branch_id) })) },
        { headers: { 'Cache-Control': 'no-store' } });
    }

    const kind = url.searchParams.get('kind');
    if (kind !== 'safeBox' && kind !== 'cashier') return json({ error: 'Invalid report tab.' }, { status: 400 });
    const from = url.searchParams.get('from') || '';
    const to = url.searchParams.get('to') || '';
    if (!validDate(from) || !validDate(to) || (from && to && from > to)) return json({ error: 'Invalid date range.' }, { status: 400 });
    const userId = url.searchParams.get('userId') || '';
    if (userId && !/^[0-9a-f-]{36}$/i.test(userId)) return json({ error: 'Invalid user filter.' }, { status: 400 });
    const action = (url.searchParams.get('action') || '').slice(0, 100);
    const status = (url.searchParams.get('status') || '').slice(0, 100);
    const search = (url.searchParams.get('search') || '').trim().toLowerCase().slice(0, 120);
    const page = Number(url.searchParams.get('page') || 0);
    if (!Number.isSafeInteger(page) || page < 0) return json({ error: 'Invalid page.' }, { status: 400 });
    const fromBoundary = from ? new Date(`${from}T00:00:00+03:00`).toISOString() : '';
    const toBoundary = to ? new Date(Date.parse(`${to}T00:00:00+03:00`) + 86400000).toISOString() : '';

    async function allRows(table: string, columns: string): Promise<{ rows: any[]; truncated: boolean }> {
      const rows: any[] = [];
      for (let offset = 0; offset < sourceLimit; offset += 1000) {
        let query = db.from(table).select(columns).order('created_at', { ascending: false }).range(offset, offset + 999);
        if (branchId) query = query.eq('branch_id', branchId);
        if (table === 'aqura_pos_print_actions') {
          if (fromBoundary) query = query.gte('created_at', fromBoundary);
          if (toBoundary) query = query.lt('created_at', toBoundary);
          if (userId) query = query.eq('user_id', userId);
        }
        if (table === 'aqura_safe_box_operations' && userId) query = query.eq('user_id', userId);
        const { data, error } = await query;
        if (error) throw error;
        rows.push(...(data || []));
        if (!data || data.length < 1000) return { rows, truncated: false };
      }
      return { rows, truncated: true };
    }

    const [prints, operations, requests] = await Promise.all([
      allRows('aqura_pos_print_actions', 'id,flow_id,user_id,branch_id,action_type,reason,custom_reason,printer_name,print_status,error_message,printed_at,created_at,request_id,source,pos_counter_id,pos_counter_name,pos_counter_number'),
      kind === 'safeBox' ? allRows('aqura_safe_box_operations', 'id,user_id,branch_id,operation_type,denomination_counts,total_amount,balance_before,balance_after,printer_name,status,opened_at,completed_at,created_at,denomination_record_id,main_counts_before,main_counts_after,safe_box_counts_before,safe_box_counts_after,opening_print_status,opening_printed_at') : Promise.resolve({ rows: [], truncated: false }),
      kind === 'safeBox' ? allRows('aqura_change_requests', 'id,requested_by_user_id,requested_to_user_id,branch_id,denomination_counts,total_amount,status,requested_at,created_at,received_counts,received_total,received_at,withdrawal_counts,withdrawal_total,safe_box_printed_at,processed_at,cashier_confirmed_counts,cashier_confirmed_at,completed_at,safe_box_printer_name,cashier_printer_name,request_number') : Promise.resolve({ rows: [], truncated: false })
    ]);
    const operationAmountById = new Map(operations.rows.map(o => [o.id, number(o.total_amount)] as const));

    const requestRows = requests.rows;
    const requestIds = [...new Set([...prints.rows.map(p => p.request_id), ...requestRows.map(r => r.id)].filter(Boolean))];
    const requestNumberById = new Map<string, string>();
    const requestAmountById = new Map<string, number | null>();
    for (let start = 0; start < requestIds.length; start += 100) {
      const { data, error } = await db.from('aqura_change_requests').select('id,request_number,total_amount,withdrawal_total').in('id', requestIds.slice(start, start + 100));
      if (error) throw error;
      for (const item of data || []) {
        requestNumberById.set(item.id, item.request_number || item.id);
        requestAmountById.set(item.id, number(item.withdrawal_total ?? item.total_amount));
      }
    }

    const branchById = new Map((branches || []).map(b => [Number(b.id), b] as const));
    const employeeById = new Map((employees || []).map(e => [e.user_id, e] as const));
    const userIds = [...new Set([
      ...prints.rows.map(p => p.user_id), ...operations.rows.map(o => o.user_id),
      ...requestRows.flatMap(r => [r.requested_by_user_id, r.requested_to_user_id])
    ].filter(Boolean))];
    const usernameById = new Map<string, string>();
    for (let start = 0; start < userIds.length; start += 100) {
      const { data, error } = await db.from('users').select('id,username').in('id', userIds.slice(start, start + 100));
      if (error) throw error;
      for (const item of data || []) usernameById.set(item.id, item.username || item.id);
    }
    function common(id: string, at: string, rowBranch: number, rowUser: string): AuditRow {
      const b = branchById.get(Number(rowBranch));
      const e = employeeById.get(rowUser);
      const fallback = usernameById.get(rowUser) || rowUser;
      return { id, at, branchId: Number(rowBranch), userId: rowUser,
        userNameEn: e?.name_en || fallback, userNameAr: e?.name_ar || e?.name_en || fallback,
        branchNameEn: b?.name_en || `Branch ${rowBranch}`, branchNameAr: b?.name_ar || b?.name_en || `Branch ${rowBranch}`,
        action: '', reason: '', requestId: '', requestNumber: '', printer: '', printStatus: '', posCounter: '', posNumber: '',
        amount: null, status: '', details: {} };
    }

    const rows: AuditRow[] = [];
    const requestPrints = new Map<string, any[]>();
    const operationPrints = new Map<string, any[]>();
    for (const p of prints.rows) {
      if (p.request_id) {
        const linked = requestPrints.get(p.request_id) || [];
        linked.push(p);
        requestPrints.set(p.request_id, linked);
      } else if (isSafePrint(p) && p.flow_id) {
        const linked = operationPrints.get(p.flow_id) || [];
        linked.push(p);
        operationPrints.set(p.flow_id, linked);
      }
    }
    const auditEvent = (item: any) => ({ at: item.created_at, action: printLabels[item.action_type] || item.action_type,
      printStatus: item.print_status || '', reason: item.custom_reason || item.reason || '',
      printer: item.printer_name || '', error: item.error_message || '' });
    const cashierGroups: any[][] = [];
    if (kind === 'cashier') {
      const latestByFlow = new Map<string, any[]>();
      const cashierPrints = prints.rows.filter(p => !isSafePrint(p))
        .sort((a, b) => a.created_at.localeCompare(b.created_at) || a.id.localeCompare(b.id));
      for (const p of cashierPrints) {
        const key = `${p.branch_id}:${p.user_id}:${p.flow_id || p.request_id || p.id}`;
        const previous = latestByFlow.get(key);
        const previousLast = previous?.[previous.length - 1];
        const startsOperation = ['printer_selection', 'test_print_attempt', 'opening_pos_counter',
          'closing_pos_counter', 'recharge_card_operation', 'other_reason'].includes(p.action_type) ||
          (p.action_type === 'pos_counter_opening' && p.print_status === 'attempted');
        const previousFinished = previousLast?.print_status === 'success' || previousLast?.print_status === 'failure';
        const newAttempt = p.action_type === 'final_print_attempt' && previousFinished;
        if (!previous || startsOperation || newAttempt) {
          const group = [p];
          cashierGroups.push(group);
          latestByFlow.set(key, group);
        } else previous.push(p);
      }
    }
    const knownOperationIds = new Set(operations.rows.map(o => o.id));
    const knownRequestIds = new Set(requestRows.map(q => q.id));
    const orphanSafeGroups = new Map<string, any[]>();
    if (kind === 'safeBox') {
      for (const p of prints.rows.filter(isSafePrint)) {
        if ((p.request_id && knownRequestIds.has(p.request_id)) || (!p.request_id && knownOperationIds.has(p.flow_id))) continue;
        const key = `${p.branch_id}:${p.user_id}:${p.request_id || p.flow_id || p.id}`;
        const group = orphanSafeGroups.get(key) || [];
        group.push(p);
        orphanSafeGroups.set(key, group);
      }
      for (const group of orphanSafeGroups.values()) group.sort((a, b) => a.created_at.localeCompare(b.created_at));
    }
    const orphanGroups = [...orphanSafeGroups.values()];
    const reportPrints = kind === 'cashier' ? cashierGroups.map(group => group[group.length - 1]) :
      orphanGroups.map(group => group[group.length - 1]);
    const groupByLastId = new Map([...cashierGroups, ...orphanGroups].map(group => [group[group.length - 1].id, group] as const));
    for (const p of reportPrints) {
      if (isSafePrint(p) !== (kind === 'safeBox')) continue;
      const group = groupByLastId.get(p.id) || [p];
      const operation = group.find(item => ['opening_pos_counter', 'closing_pos_counter',
        'recharge_card_operation', 'other_reason'].includes(item.action_type));
      const r = common(`print:${p.id}`, p.created_at, p.branch_id, p.user_id);
      Object.assign(r, { action: isSafePrint(p) ? printLabels[p.action_type] || p.action_type : cashierAction(operation || p),
        reason: operation?.custom_reason || operation?.reason || p.custom_reason || p.reason || '',
        requestId: p.request_id || '', requestNumber: p.request_id ? requestNumberById.get(p.request_id) || p.request_id : '',
        printer: p.printer_name || '', printStatus: p.print_status || '', status: p.print_status || '',
        posCounter: [...group].reverse().find(item => item.pos_counter_name)?.pos_counter_name || '',
        posNumber: [...group].reverse().find(item => item.pos_counter_number)?.pos_counter_number || '',
        amount: p.request_id ? requestAmountById.get(p.request_id) ?? null : operationAmountById.get(p.flow_id) ?? null,
        details: { source: p.source, flowId: p.flow_id, errorMessage: p.error_message, posCounterId: p.pos_counter_id,
          printedAt: p.printed_at, customReason: p.custom_reason,
          auditEvents: group.map(auditEvent) } });
      rows.push(r);
    }
    if (kind === 'safeBox') {
      for (const o of operations.rows) {
        const linkedPrints = (operationPrints.get(o.id) || []).sort((a, b) => a.created_at.localeCompare(b.created_at));
        const latestPrint = linkedPrints[linkedPrints.length - 1];
        const r = common(`operation:${o.id}`, o.completed_at || o.created_at, o.branch_id, o.user_id);
        Object.assign(r, { action: o.status === 'Completed' ? 'Safe Box Withdrawal' :
          o.status === 'Open' ? 'Safe Box Opened' : 'Safe Box Opening',
          reason: 'Safe Box Management', printer: o.printer_name || '', printStatus: o.opening_print_status || latestPrint?.print_status || '',
          amount: number(o.total_amount), status: o.status || '', details: {
            operationId: o.id, denominationRecordId: o.denomination_record_id,
            withdrawalCounts: o.denomination_counts, mainCountsBefore: o.main_counts_before,
            mainCountsAfter: o.main_counts_after, safeBoxCountsBefore: o.safe_box_counts_before,
            safeBoxCountsAfter: o.safe_box_counts_after, safeBoxBalanceBefore: o.balance_before,
            safeBoxBalanceAfter: o.balance_after, openedAt: o.opened_at,
            openingPrintedAt: o.opening_printed_at, completedAt: o.completed_at,
            auditEvents: linkedPrints.map(auditEvent)
          } });
        rows.push(r);
      }
      for (const q of requestRows) {
        const linkedPrints = (requestPrints.get(q.id) || []).sort((a, b) => a.created_at.localeCompare(b.created_at));
        const safePrints = linkedPrints.filter(isSafePrint);
        const latestSafePrint = safePrints[safePrints.length - 1];
        const events = [
          ['sent', q.requested_at || q.created_at, 'Safe Box Request Sent', q.requested_by_user_id, q.total_amount, 'Pending'],
          ['received', q.received_at, 'Cash Received for Request', q.requested_to_user_id, q.received_total, 'Cash Received'],
          ['opening', q.safe_box_printed_at, 'Safe Box Request Opening', q.requested_to_user_id, null, 'Safe Box Printed'],
          ['processed', q.processed_at, 'Safe Box Request Withdrawal', q.requested_to_user_id, q.withdrawal_total, 'Ready for Cashier Confirmation'],
          ['confirmed', q.cashier_confirmed_at, 'Cashier Confirmed Request', q.requested_by_user_id, q.withdrawal_total, 'Cashier Confirmed'],
          ['completed', q.completed_at, 'Safe Box Request Completed', q.requested_by_user_id, q.withdrawal_total, 'Completed']
        ] as const;
        const recordedStages = events.filter(([, at]) => !!at);
        const latestStage = recordedStages[recordedStages.length - 1];
        if (!latestStage) continue;
        const r = common(`request:${q.id}`, latestStage[1] || q.created_at, q.branch_id,
          q.requested_to_user_id || q.requested_by_user_id);
        Object.assign(r, { action: 'Safe Box Request', reason: 'Request for Change', requestId: q.id,
          requestNumber: q.request_number || q.id, printer: q.safe_box_printer_name || latestSafePrint?.printer_name || '',
          printStatus: latestSafePrint?.print_status || (q.safe_box_printed_at ? 'success' : ''),
          amount: number(q.withdrawal_total ?? q.total_amount), status: q.status || latestStage[5], details: {
            requestedByUserId: q.requested_by_user_id, assignedToUserId: q.requested_to_user_id,
            currentRequestStatus: q.status, requestedCounts: q.denomination_counts,
            receivedCounts: q.received_counts, withdrawalCounts: q.withdrawal_counts,
            requestedAmount: q.total_amount, receivedAmount: q.received_total,
            withdrawalAmount: q.withdrawal_total, cashierConfirmedCounts: q.cashier_confirmed_counts,
            cashierPrinter: q.cashier_printer_name,
            auditEvents: [
              ...recordedStages.map(([, at, label, , , eventStatus]) => ({ at, action: label,
                printStatus: '', reason: 'Request for Change', printer: '', error: '', status: eventStatus })),
              ...linkedPrints.map(auditEvent)
            ].sort((a, b) => String(a.at).localeCompare(String(b.at)))
          } });
        rows.push(r);
      }
    }

    const filtered = rows.filter(row => {
      const day = row.at ? new Date(new Date(row.at).getTime() + 3 * 60 * 60 * 1000).toISOString().slice(0, 10) : '';
      if ((from && day < from) || (to && day > to)) return false;
      if (userId && row.userId !== userId && row.details.requestedByUserId !== userId &&
        row.details.assignedToUserId !== userId) return false;
      if (action && row.action !== action) return false;
      if (status && row.status !== status && row.printStatus !== status) return false;
      if (search && ![row.action, row.reason, row.requestNumber, row.printer, row.status,
        row.userNameEn, row.userNameAr, row.branchNameEn, row.branchNameAr, row.amount?.toString() || '']
        .some(value => value.toLowerCase().includes(search))) return false;
      return true;
    }).sort((a, b) => b.at.localeCompare(a.at) || b.id.localeCompare(a.id));
    const actions = [...new Set(rows.map(row => row.action))].sort();
    const statuses = [...new Set(rows.flatMap(row => [row.status, row.printStatus]).filter(Boolean))].sort();
    const reportUsers = [...new Map(rows.map(row => [`${row.userId}:${row.branchId}`, {
      id: row.userId, nameEn: row.userNameEn, nameAr: row.userNameAr, branchId: row.branchId
    }] as const)).values()];
    return json({ rows: filtered.slice(page * pageSize, (page + 1) * pageSize), total: filtered.length,
      page, pageSize, actions, statuses, reportUsers,
      truncated: prints.truncated || operations.truncated || requests.truncated },
      { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    console.error('Drawer action audit report failed:', error);
    return json({ error: error instanceof Error ? error.message : 'Could not load audit report.' }, { status: 500 });
  }
};
