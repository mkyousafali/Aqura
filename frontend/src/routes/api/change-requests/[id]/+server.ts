import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient } from '$lib/server/breakRegisterAuth';
import { checkedCounts } from '$lib/server/changeRequestCounts';
import { cashierInBranch } from '$lib/server/cashierChangeBranch';

export const POST: RequestHandler = async ({ request, params }) => {
  try {
    const body = await request.json();
    const { userId, sessionToken, branchId, action } = body;
    if (typeof userId !== 'string' || typeof sessionToken !== 'string' ||
        !Number.isSafeInteger(Number(branchId)) || Number(branchId) <= 0) {
      return json({ error: 'Invalid cashier session.' }, { status: 400 });
    }
    const db = databaseClient();
    const { data: session, error: authError } = await db.rpc('heartbeat_cashier_session', {
      p_user_id: userId, p_session_token: sessionToken
    });
    if (authError || session?.valid !== true) return json({ error: 'Cashier session expired.' }, { status: 401 });
    if (!await cashierInBranch(db, userId, Number(branchId))) return json({ error: 'Cashier branch mismatch.' }, { status: 403 });
    const { data: item, error } = await db.from('aqura_change_requests').select('*')
      .eq('id', params.id).eq('requested_by_user_id', userId).eq('branch_id', branchId).single();
    if (error || !item) return json({ error: 'Request not found for this cashier and branch.' }, { status: 404 });
    if (action === 'confirm') {
      if (item.status !== 'Ready for Cashier Confirmation') return json({ error: 'Request is not ready for confirmation.' }, { status: 409 });
      const { counts } = checkedCounts(body.counts);
      if (Object.keys(counts).some(key => counts[key] !== (item.withdrawal_counts?.[key] || 0))) {
        return json({ error: 'Confirmed denominations must match the cash given by Safe Box.' }, { status: 409 });
      }
      const { data, error: saveError } = await db.from('aqura_change_requests').update({
        cashier_confirmed_counts: counts, cashier_confirmed_at: new Date().toISOString(), status: 'Cashier Confirmed'
      }).eq('id', item.id).eq('status', 'Ready for Cashier Confirmation').select('id').maybeSingle();
      if (saveError) throw saveError;
      if (!data) return json({ error: 'Request changed. Reload it.' }, { status: 409 });
      return json({ status: 'Cashier Confirmed' });
    }
    if (action === 'print_event') {
      if (item.status !== 'Cashier Confirmed') return json({ error: 'Cashier confirmation is required before printing.' }, { status: 409 });
      if (!['attempted', 'success', 'failure'].includes(body.printStatus) ||
          typeof body.printerName !== 'string' || !body.printerName.trim() || body.printerName.length > 200) {
        return json({ error: 'Invalid print event.' }, { status: 400 });
      }
      let counter: { counter_id: number; counter_name: string } | null = null;
      if (body.posCounterId != null) {
        if (!Number.isSafeInteger(Number(body.posCounterId)) || Number(body.posCounterId) <= 0)
          return json({ error: 'Invalid POS counter.' }, { status: 400 });
        const { data, error: counterError } = await db.from('erp_counters').select('counter_id,counter_name')
          .eq('branch_id', branchId).eq('counter_id', body.posCounterId).maybeSingle();
        if (counterError) throw counterError;
        if (!data) return json({ error: 'POS counter does not belong to this branch.' }, { status: 400 });
        counter = data;
      }
      const { error: auditError } = await db.from('aqura_pos_print_actions').insert({
        flow_id: item.id, request_id: item.id, user_id: userId, branch_id: branchId,
        action_type: 'pos_counter_opening', source: 'Cashier Interface', reason: 'Opening a POS Counter',
        printer_name: body.printerName, print_status: body.printStatus,
        pos_counter_id: counter?.counter_id || null, pos_counter_name: counter?.counter_name || null,
        pos_counter_number: counter?.counter_name?.match(/^POS[\s-]*(\d+)/i)?.[1] || null,
        error_message: body.printStatus === 'failure' ? String(body.errorMessage || 'Print failed').slice(0, 500) : null,
        printed_at: body.printStatus === 'success' ? new Date().toISOString() : null
      });
      if (auditError) throw auditError;
      if (body.printStatus === 'success') {
        const { error: saveError } = await db.from('aqura_change_requests').update({
          status: 'Completed', completed_at: new Date().toISOString(), cashier_printer_name: body.printerName
        }).eq('id', item.id).eq('status', 'Cashier Confirmed');
        if (saveError) throw saveError;
      }
      return json({ status: body.printStatus === 'success' ? 'Completed' : item.status });
    }
    return json({ error: 'Unknown action.' }, { status: 400 });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Could not update request.' }, { status: 400 });
  }
};
