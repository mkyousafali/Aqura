import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { createClient } from '@supabase/supabase-js';
import type { RequestHandler } from './$types';
import { cashierInBranch } from '$lib/server/cashierChangeBranch';
import { safeBoxSchemaUnavailable } from '$lib/server/safeBoxControl';

const actions = new Set([
  'printer_selection', 'test_print_attempt', 'test_print_success', 'test_print_failure',
  'opening_pos_counter', 'closing_pos_counter', 'recharge_card_operation',
  'other_reason', 'final_print_attempt', 'final_print_success', 'final_print_failure'
]);
const printerSetupActions = new Set(['printer_selection', 'test_print_attempt', 'test_print_success', 'test_print_failure']);
const statusByAction: Record<string, string> = {
  printer_selection: 'selected', test_print_attempt: 'attempted', test_print_success: 'success',
  test_print_failure: 'failure', opening_pos_counter: 'reason_selected',
  closing_pos_counter: 'reason_selected', recharge_card_operation: 'reason_selected',
  other_reason: 'reason_selected', final_print_attempt: 'attempted',
  final_print_success: 'success', final_print_failure: 'failure'
};

export const POST: RequestHandler = async ({ request }) => {
  try {
    const body = await request.json();
    const { userId, sessionToken, branchId, flowId, actionType, printerName, reason, customReason, errorMessage, posCounterId } = body;
    const validText = (value: unknown, max = 200) => typeof value === 'string' && value.length > 0 && value.length <= max;
    if (!validText(userId, 36) || !validText(sessionToken, 256) || !Number.isSafeInteger(Number(branchId)) || Number(branchId) <= 0 ||
        !validText(flowId, 36) || !actions.has(actionType) || !validText(printerName) ||
        (reason != null && !validText(reason)) || (customReason != null && !validText(customReason)) ||
        (errorMessage != null && !validText(errorMessage, 500))) {
      return json({ error: 'Invalid audit event' }, { status: 400 });
    }
    if (!env.VITE_SUPABASE_URL || !env.VITE_SUPABASE_SERVICE_KEY) throw new Error('Database unavailable');
    const db = createClient(env.VITE_SUPABASE_URL, env.VITE_SUPABASE_SERVICE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false }
    });
    const { data: session, error: sessionError } = await db.rpc('heartbeat_cashier_session', {
      p_user_id: userId,
      p_session_token: sessionToken
    });
    if (sessionError || session?.valid !== true) return json({ error: 'Cashier session expired' }, { status: 401 });
    const { data: user, error: userError } = await db.from('users').select('id,status,is_master_admin').eq('id', userId).single();
    if (userError || user?.status !== 'active') return json({ error: 'Cashier account inactive' }, { status: 401 });
    if (!await cashierInBranch(db, userId, Number(branchId))) return json({ error: 'Cashier branch mismatch.' }, { status: 403 });
    if (printerSetupActions.has(actionType) && user.is_master_admin !== true) {
      const { data: grant, error: grantError } = await db.from('aqura_safe_box_permissions').select('id')
        .eq('user_id', userId).eq('branch_id', branchId).eq('permission_type', 'printer').maybeSingle();
      if (grantError && !safeBoxSchemaUnavailable(grantError)) throw grantError;
      if (!grant) return json({ error: 'Printer settings access required.' }, { status: 403 });
    }
    const { data: branch, error: branchError } = await db.from('branches').select('id').eq('id', branchId).single();
    if (branchError || !branch) return json({ error: 'Invalid branch' }, { status: 400 });
    const printStatus = statusByAction[actionType];
    let posCounter: { counter_id: number; counter_name: string } | null = null;
    if (posCounterId != null) {
      if (!Number.isSafeInteger(Number(posCounterId)) || Number(posCounterId) <= 0)
        return json({ error: 'Invalid POS counter.' }, { status: 400 });
      const { data, error: counterError } = await db.from('erp_counters').select('counter_id,counter_name')
        .eq('branch_id', branchId).eq('counter_id', posCounterId).maybeSingle();
      if (counterError) throw counterError;
      if (!data) return json({ error: 'POS counter does not belong to this branch.' }, { status: 400 });
      posCounter = data;
    }
    const { error } = await db.from('aqura_pos_print_actions').insert({
      flow_id: flowId,
      user_id: user.id,
      branch_id: branch.id,
      action_type: actionType,
      reason: reason || null,
      custom_reason: customReason || null,
      printer_name: printerName,
      print_status: printStatus,
      error_message: errorMessage || null,
      pos_counter_id: posCounter?.counter_id || null,
      pos_counter_name: posCounter?.counter_name || null,
      pos_counter_number: posCounter?.counter_name?.match(/^POS[\s-]*(\d+)/i)?.[1] || null,
      printed_at: printStatus === 'success' ? new Date().toISOString() : null
    });
    if (error) throw error;
    return json({ success: true });
  } catch (error) {
    console.error('POS print audit failed:', error);
    return json({ error: 'Unable to record POS print action' }, { status: 500 });
  }
};
