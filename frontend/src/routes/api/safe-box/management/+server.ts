import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient } from '$lib/server/breakRegisterAuth';
import { safeBoxAccess } from '$lib/server/safeBoxControl';

const values: Record<string, number> = {
  d500: 50000, d200: 20000, d100: 10000, d50: 5000, d20: 2000, d10: 1000,
  d5: 500, d2: 200, d1: 100, d05: 50, d025: 25, coins: 100, damage: 100
};

export const POST: RequestHandler = async ({ cookies, request }) => {
  try {
    const access = await safeBoxAccess(cookies);
    if (!access.canManagement) return json({ error: 'Safe Box Management access denied.' }, { status: 403 });
    const body = await request.json();
    const db = databaseClient();
    if (body.action === 'open_attempt') {
      const printerName = body.printerName;
      if (typeof printerName !== 'string' || !printerName.trim() || printerName.length > 200) {
        return json({ error: 'Select a configured Safe Box printer.' }, { status: 400 });
      }
      let operationId = body.operationId;
      if (operationId) {
        if (typeof operationId !== 'string' || !/^[0-9a-f-]{36}$/i.test(operationId)) return json({ error: 'Invalid operation.' }, { status: 400 });
        const { data: existing } = await db.from('aqura_safe_box_operations').select('id,status')
          .eq('id', operationId).eq('user_id', access.userId).eq('branch_id', access.branchId).maybeSingle();
        if (!existing || !['Opening', 'Print Failed'].includes(existing.status)) return json({ error: 'Operation cannot retry opening.' }, { status: 409 });
        const { error } = await db.from('aqura_safe_box_operations').update({ status: 'Opening', printer_name: printerName }).eq('id', operationId);
        if (error) throw error;
      } else {
        const { data, error } = await db.from('aqura_safe_box_operations').insert({
          user_id: access.userId, branch_id: access.branchId, printer_name: printerName, status: 'Opening'
        }).select('id').single();
        if (error) throw error;
        operationId = data.id;
      }
      const { error: auditError } = await db.from('aqura_pos_print_actions').insert({
        flow_id: operationId, user_id: access.userId, branch_id: access.branchId,
        action_type: 'safe_box_opening', source: 'Aqura Safe Box', reason: 'Safe Box Management',
        printer_name: printerName, print_status: 'attempted'
      });
      if (auditError) throw auditError;
      return json({ operationId });
    }
    if (body.action === 'print_result') {
      const operationId = body.operationId;
      if (typeof operationId !== 'string' || !/^[0-9a-f-]{36}$/i.test(operationId) ||
        !['success', 'failure'].includes(body.printStatus)) return json({ error: 'Invalid print result.' }, { status: 400 });
      const { data: operation } = await db.from('aqura_safe_box_operations').select('id,status,printer_name')
        .eq('id', operationId).eq('user_id', access.userId).eq('branch_id', access.branchId).maybeSingle();
      if (!operation || operation.status !== 'Opening') return json({ error: 'Opening print is not active.' }, { status: 409 });
      const { error: auditError } = await db.from('aqura_pos_print_actions').insert({
        flow_id: operationId, user_id: access.userId, branch_id: access.branchId,
        action_type: 'safe_box_opening', source: 'Aqura Safe Box', reason: 'Safe Box Management',
        printer_name: operation.printer_name, print_status: body.printStatus,
        error_message: body.printStatus === 'failure' ? String(body.errorMessage || 'Print failed').slice(0, 500) : null,
        printed_at: body.printStatus === 'success' ? new Date().toISOString() : null
      });
      if (auditError) throw auditError;
      const { error } = await db.from('aqura_safe_box_operations').update({
        status: body.printStatus === 'success' ? 'Open' : 'Print Failed',
        opened_at: body.printStatus === 'success' ? new Date().toISOString() : null,
        opening_print_status: body.printStatus,
        opening_printed_at: body.printStatus === 'success' ? new Date().toISOString() : null
      }).eq('id', operationId).eq('status', 'Opening');
      if (error) throw error;
      return json({ status: body.printStatus });
    }
    if (body.action === 'complete') {
      const { operationId, counts } = body;
      if (typeof operationId !== 'string' || !/^[0-9a-f-]{36}$/i.test(operationId) ||
        body.operationType !== undefined || !counts || typeof counts !== 'object' || Array.isArray(counts)) {
        return json({ error: 'Invalid Safe Box operation.' }, { status: 400 });
      }
      const keys = Object.keys(counts);
      if (!keys.length || keys.some(key => !(key in values) || !Number.isSafeInteger(counts[key]) || counts[key] < 0 || counts[key] > 100000) ||
        !keys.some(key => counts[key] > 0)) return json({ error: 'Enter valid denomination quantities.' }, { status: 400 });
      const { data, error } = await db.rpc('aqura_complete_safe_box_management', {
        p_operation_id: operationId, p_user_id: access.userId, p_operation_type: 'Withdraw', p_counts: counts
      });
      if (error) return json({ error: error.message }, { status: 409 });
      return json(data);
    }
    return json({ error: 'Unknown action.' }, { status: 400 });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Safe Box operation failed.' }, { status: 403 });
  }
};
