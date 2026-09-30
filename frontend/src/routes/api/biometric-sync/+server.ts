import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

async function requireDesktopUser(cookies: Parameters<typeof requireBreakUser>[0]) {
  return requireBreakUser(cookies, 'desktop');
}

export const GET: RequestHandler = async ({ cookies, url }) => {
  try {
    const db = databaseClient();
    if (url.searchParams.get('view') === 'logs') {
      await requireDesktopUser(cookies);
      const { data, error } = await db.from('biometric_sync_logs').select('*').order('created_at', { ascending: false }).limit(50);
      if (error) throw error;
      return json({ success: true, logs: data || [] }, { headers: { 'Cache-Control': 'no-store' } });
    }
    const { data, error } = await db.rpc('get_biometric_sync_branch_status');
    if (error) throw error;
    return json({ success: true, branches: data || [] }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    return json({ success: false, error: error instanceof Error ? error.message : 'Biometric sync access denied' }, { status: 403 });
  }
};

export const POST: RequestHandler = async ({ cookies, request, fetch }) => {
  try {
    const actor = await requireDesktopUser(cookies);
    const body = await request.json();
    const db = databaseClient();
    if (body.action === 'toggle') {
      const branchId = Number(body.branchId);
      if (!Number.isSafeInteger(branchId) || branchId <= 0 || typeof body.enabled !== 'boolean') return json({ success: false, error: 'Invalid request' }, { status: 400 });
      const { data: statuses, error: statusError } = await db.rpc('get_biometric_sync_branch_status');
      if (statusError) throw statusError;
      const status = (statuses || []).find((row: any) => Number(row.branch_id) === branchId);
      if (!status) return json({ success: false, error: 'Branch not found' }, { status: 404 });
      if (body.enabled && !status.ready) return json({ success: false, error: 'Configuration is incomplete', missing: status.missing_requirements || [] }, { status: 400 });
      const { error } = await db.from('branches').update({
        biometric_edge_sync_enabled: body.enabled,
        biometric_edge_sync_enabled_at: body.enabled ? new Date().toISOString() : null,
        biometric_edge_sync_enabled_by: body.enabled ? actor.id : null
      }).eq('id', branchId);
      if (error) throw error;
      return json({ success: true, enabled: body.enabled });
    }
    if (body.action === 'sync') {
      const branchId = body.branchId == null ? null : Number(body.branchId);
      if (branchId != null && (!Number.isSafeInteger(branchId) || branchId <= 0)) return json({ success: false, error: 'Invalid branch' }, { status: 400 });
      const syncType = ['punches','employees','both'].includes(body.syncType) ? body.syncType : 'punches';
      const endpoint = `${env.VITE_SUPABASE_URL}/functions/v1/biometric-sync`;
      const edgeResponse = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${env.VITE_SUPABASE_SERVICE_KEY}` },
        body: JSON.stringify({ branchId, syncType, dryRun: body.dryRun === true, triggerType: 'manual', windowDays: 3 })
      });
      const result = await edgeResponse.json().catch(() => ({ success: false, error: `Edge Function returned HTTP ${edgeResponse.status}` }));
      return json(result, { status: edgeResponse.ok || edgeResponse.status === 207 ? 200 : edgeResponse.status });
    }
    return json({ success: false, error: 'Unsupported action' }, { status: 400 });
  } catch (error) {
    return json({ success: false, error: error instanceof Error ? error.message : 'Biometric sync access denied' }, { status: 403 });
  }
};
