import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient } from '$lib/server/breakRegisterAuth';
import { safeBoxAccess } from '$lib/server/safeBoxControl';
import { checkedCounts } from '$lib/server/changeRequestCounts';

export const POST: RequestHandler = async ({ cookies, params, request }) => {
  try {
    const access = await safeBoxAccess(cookies);
    if (!access.canRequests) return json({ error: 'Safe Box request access denied.' }, { status: 403 });
    const userId = access.userId;
    const db = databaseClient();
    const { data: item, error } = await db.from('aqura_change_requests').select('*')
      .eq('id', params.id).eq('requested_to_user_id', userId).eq('branch_id', access.branchId).single();
    if (error || !item) return json({ error: 'Assigned request not found.' }, { status: 404 });
    const { data: employee } = await db.from('hr_employee_master').select('current_branch_id')
      .eq('user_id', userId).maybeSingle();
    if (employee?.current_branch_id !== Number(item.branch_id)) return json({ error: 'Request belongs to another branch.' }, { status: 403 });
    const body = await request.json();
    if (body.action === 'received') {
      if (item.status !== 'Pending') return json({ error: 'Request is no longer pending.' }, { status: 409 });
      const { counts, total } = checkedCounts(body.counts);
      const { data, error: saveError } = await db.from('aqura_change_requests').update({
        received_counts: counts, received_total: total, received_at: new Date().toISOString(), status: 'Cash Received'
      }).eq('id', item.id).eq('status', 'Pending').select('id').maybeSingle();
      if (saveError) throw saveError;
      if (!data) return json({ error: 'Request changed. Reload it.' }, { status: 409 });
      return json({ status: 'Cash Received' });
    }
    if (body.action === 'print_event') {
      if (item.status !== 'Cash Received' && item.status !== 'Safe Box Printed') {
        return json({ error: 'Cash received must be saved before printing.' }, { status: 409 });
      }
      if (!['attempted', 'success', 'failure'].includes(body.printStatus) ||
          typeof body.printerName !== 'string' || !body.printerName.trim() || body.printerName.length > 200) {
        return json({ error: 'Invalid print event.' }, { status: 400 });
      }
      const { error: auditError } = await db.from('aqura_pos_print_actions').insert({
        flow_id: item.id, request_id: item.id, user_id: userId, branch_id: item.branch_id,
        action_type: 'safe_box_opening', source: 'Aqura Safe Box', reason: 'Safe Box Opening / Change Request',
        printer_name: body.printerName, print_status: body.printStatus,
        error_message: body.printStatus === 'failure' ? String(body.errorMessage || 'Print failed').slice(0, 500) : null,
        printed_at: body.printStatus === 'success' ? new Date().toISOString() : null
      });
      if (auditError) throw auditError;
      if (body.printStatus === 'success') {
        const { error: saveError } = await db.from('aqura_change_requests').update({
          status: 'Safe Box Printed', safe_box_printed_at: new Date().toISOString(), safe_box_printer_name: body.printerName
        }).eq('id', item.id).eq('status', 'Cash Received');
        if (saveError) throw saveError;
      }
      return json({ status: body.printStatus });
    }
    if (body.action === 'withdraw') {
      const { counts, total } = checkedCounts(body.counts);
      if (Math.round(total * 100) !== Math.round(Number(item.total_amount) * 100)) {
        return json({ error: `Cash taken must exactly match the requested ${Number(item.total_amount).toFixed(2)} SAR.` }, { status: 400 });
      }
      const { data, error: rpcError } = await db.rpc('aqura_finalize_safe_box_request', {
        p_request_id: item.id, p_user_id: userId, p_withdrawal_counts: counts,
        p_printer_name: item.safe_box_printer_name || ''
      });
      if (rpcError) return json({ error: rpcError.message }, { status: 409 });
      return json(data);
    }
    return json({ error: 'Unknown action.' }, { status: 400 });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Could not process request.';
    return json({ error: message }, { status: message.includes('session') ? 401 : 400 });
  }
};
