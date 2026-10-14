import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

export const POST: RequestHandler = async ({ cookies, request, fetch }) => {
  try {
    const actor = await requireBreakUser(cookies, 'desktop');
    const body = await request.json().catch(() => ({}));
    const branchId = Number(body.branchId);
    if (!Number.isSafeInteger(branchId) || branchId <= 0) {
      return json({ success: false, error: 'A valid branch is required' }, { status: 400 });
    }

    const db = databaseClient();
    if (body.action === 'toggle') {
      if (!actor.isMasterAdmin) {
        return json({ success: false, error: 'Master admin access is required' }, { status: 403 });
      }
      if (!['sync', 'auto'].includes(body.setting) || typeof body.enabled !== 'boolean') {
        return json({ success: false, error: 'Invalid sync setting' }, { status: 400 });
      }

      const { data: connection, error: connectionError } = await db
        .from('erp_connections')
        .select('branch_id,vendor_sync_enabled')
        .eq('branch_id', branchId)
        .eq('is_active', true)
        .maybeSingle();
      if (connectionError) throw connectionError;
      if (!connection) return json({ success: false, error: 'Active ERP connection not found' }, { status: 404 });
      if (body.setting === 'auto' && body.enabled && !connection.vendor_sync_enabled) {
        return json({ success: false, error: 'Enable Sync before enabling Auto Sync' }, { status: 400 });
      }

      const updates = body.setting === 'sync'
        ? {
            vendor_sync_enabled: body.enabled,
            ...(body.enabled ? {} : { vendor_auto_sync_enabled: false })
          }
        : { vendor_auto_sync_enabled: body.enabled };
      const { error: updateError } = await db
        .from('erp_connections')
        .update(updates)
        .eq('branch_id', branchId)
        .eq('is_active', true);
      if (updateError) throw updateError;
      return json({ success: true, ...updates });
    }

    if (body.action === 'sync') {
      const { data: connection, error: connectionError } = await db
        .from('erp_connections')
        .select('vendor_sync_enabled')
        .eq('branch_id', branchId)
        .eq('is_active', true)
        .maybeSingle();
      if (connectionError) throw connectionError;
      if (!connection?.vendor_sync_enabled) {
        return json({ success: false, error: 'Vendor synchronization is disabled for this branch' }, { status: 400 });
      }

      const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY || env.VITE_SUPABASE_SERVICE_KEY;
      const supabaseUrl = env.VITE_SUPABASE_URL;
      if (!serviceKey || !supabaseUrl) throw new Error('Vendor sync service configuration is incomplete');
      const edgeResponse = await fetch(`${supabaseUrl}/functions/v1/sync-erp-vendors`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${serviceKey}`
        },
        body: JSON.stringify({ branchId, syncMode: 'manual' })
      });
      const result = await edgeResponse.json().catch(() => ({
        success: false,
        error: `Vendor sync returned HTTP ${edgeResponse.status}`
      }));
      return json(result, { status: edgeResponse.ok ? 200 : edgeResponse.status });
    }

    return json({ success: false, error: 'Unsupported action' }, { status: 400 });
  } catch (error) {
    return json({
      success: false,
      error: error instanceof Error ? error.message : 'Vendor synchronization failed'
    }, { status: 500 });
  }
};
