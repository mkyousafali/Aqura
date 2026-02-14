// Supabase Edge Function: Auto Sync ERP Products
// Purpose: Syncs products from ONE ERP branch connection per invocation.
//          Reads erp_connections, calls the branch's tunnel /sync endpoint,
//          and upserts results into erp_synced_products via RPC.
//
// Usage:
//   POST with {"branch_id": 5}  → sync specific branch
//   POST with {}                → sync the NEXT branch due for sync (round-robin)
//
// pg_cron: one job per branch, staggered (e.g. :00, :15, :30, :45)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const BRIDGE_API_SECRET = 'aqura-erp-bridge-2026';
const BATCH_SIZE = 200;
const FETCH_TIMEOUT_MS = 180000; // 3 minutes max for bridge fetch

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    let params: any = {};
    if (req.method === 'POST') {
      try { params = await req.json(); } catch (_) {}
    }

    // ── Get the target branch connection ──
    let conn: any = null;

    if (params.branch_id) {
      // Specific branch requested
      const { data, error } = await supabase
        .from('erp_connections')
        .select('id, branch_id, branch_name, tunnel_url, erp_branch_id, is_active')
        .eq('branch_id', params.branch_id)
        .eq('is_active', true)
        .not('tunnel_url', 'is', null)
        .neq('tunnel_url', '')
        .single();

      if (error || !data) {
        return new Response(
          JSON.stringify({ success: false, error: `Branch ${params.branch_id} not found or inactive` }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      conn = data;
    } else {
      // No branch specified → pick the one with the oldest synced_at
      const { data: connections, error: connError } = await supabase
        .from('erp_connections')
        .select('id, branch_id, branch_name, tunnel_url, erp_branch_id, is_active')
        .eq('is_active', true)
        .not('tunnel_url', 'is', null)
        .neq('tunnel_url', '');

      if (connError || !connections || connections.length === 0) {
        return new Response(
          JSON.stringify({ success: true, message: 'No active ERP connections with tunnel URLs found' }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Check sync logs for the most recent sync per branch
      const { data: recentLogs } = await supabase
        .from('erp_sync_logs')
        .select('details, created_at')
        .eq('sync_type', 'auto')
        .order('created_at', { ascending: false })
        .limit(50);

      // Build a map of branch_id → last sync time
      const lastSyncMap = new Map<number, string>();
      if (recentLogs) {
        for (const log of recentLogs) {
          if (log.details && Array.isArray(log.details)) {
            for (const detail of log.details) {
              if (detail.branch_id && detail.success && !lastSyncMap.has(detail.branch_id)) {
                lastSyncMap.set(detail.branch_id, log.created_at);
              }
            }
          }
        }
      }

      // Pick the connection that was synced longest ago (or never synced)
      let oldestTime = new Date().toISOString();
      conn = connections[0];
      for (const c of connections) {
        const lastSync = lastSyncMap.get(c.branch_id);
        if (!lastSync) {
          conn = c;
          break;
        }
        if (lastSync < oldestTime) {
          oldestTime = lastSync;
          conn = c;
        }
      }
    }

    // ── Sync the branch ──
    const baseUrl = conn.tunnel_url.replace(/\/+$/, '');
    console.log(`[auto-sync-erp] Syncing branch: ${conn.branch_name} (ID: ${conn.branch_id}, URL: ${baseUrl})`);

    // Step 1: Fetch products from bridge
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

    let syncResp: Response;
    try {
      syncResp = await fetch(`${baseUrl}/sync`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-secret': BRIDGE_API_SECRET,
        },
        body: JSON.stringify({
          erpBranchId: conn.erp_branch_id,
          appBranchId: conn.branch_id,
        }),
        signal: controller.signal,
      });
    } catch (fetchErr: any) {
      clearTimeout(timeout);
      const errorMsg = fetchErr.name === 'AbortError'
        ? `Bridge timeout after ${FETCH_TIMEOUT_MS / 1000}s`
        : `Bridge unreachable: ${fetchErr.message}`;

      console.error(`[auto-sync-erp] ${conn.branch_name}: ${errorMsg}`);

      try {
        await supabase.from('erp_sync_logs').insert({
          sync_type: 'auto',
          branches_total: 1,
          branches_success: 0,
          branches_failed: 1,
          products_fetched: 0,
          duration_ms: Date.now() - startTime,
          details: [{ branch_name: conn.branch_name, branch_id: conn.branch_id, success: false, error: errorMsg }],
          triggered_by: params.branch_id ? `manual-branch-${params.branch_id}` : 'pg_cron',
        });
      } catch (_) {}

      return new Response(
        JSON.stringify({ success: false, branch: conn.branch_name, error: errorMsg }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    clearTimeout(timeout);

    if (!syncResp.ok) {
      throw new Error(`Bridge returned HTTP ${syncResp.status}`);
    }

    const syncData = await syncResp.json();

    if (!syncData.success || !syncData.products) {
      throw new Error(syncData.error || 'Bridge returned no products');
    }

    const products = syncData.products;
    console.log(`[auto-sync-erp] ${conn.branch_name}: Fetched ${products.length} products, upserting in batches of ${BATCH_SIZE}...`);

    // Step 2: Upsert into Supabase in batches
    let totalInserted = 0;
    let totalUpdated = 0;
    let batchErrors = 0;

    for (let i = 0; i < products.length; i += BATCH_SIZE) {
      const batch = products.slice(i, i + BATCH_SIZE);
      const batchNum = Math.floor(i / BATCH_SIZE) + 1;

      const { data: rpcResult, error: rpcError } = await supabase
        .rpc('upsert_erp_products_with_expiry', { p_products: batch });

      if (rpcError) {
        console.error(`[auto-sync-erp] RPC error batch ${batchNum}: ${rpcError.message}`);
        batchErrors++;
        continue;
      }

      if (rpcResult) {
        totalInserted += rpcResult.inserted || 0;
        totalUpdated += rpcResult.updated || 0;
      }
    }

    const duration = Date.now() - startTime;

    console.log(`[auto-sync-erp] ${conn.branch_name}: DONE! Fetched: ${products.length}, Inserted: ${totalInserted}, Updated: ${totalUpdated}, Errors: ${batchErrors}, Duration: ${duration}ms`);

    // Step 3: Log success
    const result = {
      branch_name: conn.branch_name,
      branch_id: conn.branch_id,
      success: true,
      products_fetched: products.length,
      inserted: totalInserted,
      updated: totalUpdated,
      batch_errors: batchErrors,
      duration_ms: duration,
    };

    try {
      await supabase.from('erp_sync_logs').insert({
        sync_type: 'auto',
        branches_total: 1,
        branches_success: 1,
        branches_failed: 0,
        products_fetched: products.length,
        products_inserted: totalInserted,
        products_updated: totalUpdated,
        duration_ms: duration,
        details: [result],
        triggered_by: params.branch_id ? `manual-branch-${params.branch_id}` : 'pg_cron',
      });
    } catch (_) {}

    return new Response(
      JSON.stringify({ success: true, ...result }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('[auto-sync-erp] Fatal error:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
