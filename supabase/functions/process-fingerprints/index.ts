// Edge Function: process-fingerprints
// Copies raw fingerprint transactions from hr_fingerprint_transactions → processed_fingerprint_transactions
// Runs hourly via pg_cron. Only processes unprocessed records (processed = false).
// Replicates the logic from ProcessFingerprint.svelte but runs server-side.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Optional: process only a specific employee
    let specificEmployeeId: string | null = null;
    try {
      const body = await req.json();
      if (body.employeeId) specificEmployeeId = body.employeeId;
    } catch { /* no body = process all */ }

    console.log(`🔄 [Process Fingerprints] Starting...${specificEmployeeId ? ` Employee: ${specificEmployeeId}` : ' All employees'}`);

    // ─── Step 1: Get employees with fingerprint device mappings ───
    let empQuery = supabase
      .from('hr_employee_master')
      .select('id, employee_id_mapping')
      .not('employee_id_mapping', 'is', null);

    if (specificEmployeeId) {
      empQuery = empQuery.eq('id', specificEmployeeId);
    }

    const { data: employees, error: empError } = await empQuery;
    if (empError) throw new Error(`Failed to load employees: ${empError.message}`);
    if (!employees || employees.length === 0) {
      console.log('⚠️ No employees with fingerprint mappings found');
      return new Response(
        JSON.stringify({ success: true, message: 'No employees with mappings', processed: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`👥 Found ${employees.length} employees with mappings`);

    // ─── Step 2: Build reverse map (device_employee_id → hr_employee_master.id) ───
    const deviceToMasterId = new Map<string, string>();
    const allDeviceIds: string[] = [];

    for (const emp of employees) {
      let mapping = emp.employee_id_mapping;

      // Parse if stringified
      if (typeof mapping === 'string') {
        try { mapping = JSON.parse(mapping); } catch { continue; }
      }

      if (!mapping || typeof mapping !== 'object') continue;

      // mapping is like {"1": "UABUD116", "2": "ASAHD12", "3": "UARDS5"}
      // Values are device employee IDs
      const deviceIds: string[] = Array.isArray(mapping)
        ? mapping.map((item: any) => item.employee_id || item.id || String(item)).filter(Boolean)
        : Object.values(mapping).map((v: any) => {
            if (typeof v === 'object' && v !== null && 'employee_id' in v) return v.employee_id;
            return String(v);
          }).filter(Boolean);

      for (const devId of deviceIds) {
        deviceToMasterId.set(devId, emp.id);
        allDeviceIds.push(devId);
      }
    }

    if (allDeviceIds.length === 0) {
      console.log('⚠️ No device IDs extracted from mappings');
      return new Response(
        JSON.stringify({ success: true, message: 'No device IDs found', processed: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`🔗 Mapped ${allDeviceIds.length} device IDs across ${employees.length} employees`);

    // ─── Step 3: Fetch unprocessed fingerprint transactions ───
    // Process in batches of device IDs (Supabase .in() has limits)
    const DEVICE_BATCH_SIZE = 50;
    let allTransactions: any[] = [];

    for (let i = 0; i < allDeviceIds.length; i += DEVICE_BATCH_SIZE) {
      const batch = allDeviceIds.slice(i, i + DEVICE_BATCH_SIZE);

      const { data: transactions, error: txnError } = await supabase
        .from('hr_fingerprint_transactions')
        .select('id, employee_id, branch_id, date, time, status')
        .in('employee_id', batch)
        .eq('processed', false);

      if (txnError) {
        console.error(`Batch ${Math.floor(i / DEVICE_BATCH_SIZE) + 1} error:`, txnError.message);
        continue;
      }

      if (transactions && transactions.length > 0) {
        allTransactions = allTransactions.concat(transactions);
      }
    }

    if (allTransactions.length === 0) {
      console.log('✅ No unprocessed transactions found');
      return new Response(
        JSON.stringify({ success: true, message: 'No new transactions to process', processed: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`📋 Found ${allTransactions.length} unprocessed transactions`);

    // ─── Step 4: Build processed records with deterministic IDs ───
    const recordsToInsert: any[] = [];
    const sourceIds: string[] = []; // to mark as processed

    for (const txn of allTransactions) {
      const masterId = deviceToMasterId.get(txn.employee_id);
      if (!masterId) {
        console.warn(`⚠️ No master mapping for device ID: ${txn.employee_id}`);
        continue;
      }

      // Generate deterministic ID: PF-{deviceEmpId}-{YYYYMMDD}-{HHMMSS}
      const cleanDate = String(txn.date).replace(/-/g, '');
      const cleanTime = String(txn.time).replace(/:/g, '');
      const detId = `PF-${txn.employee_id}-${cleanDate}-${cleanTime}`;

      recordsToInsert.push({
        id: detId,
        center_id: masterId,
        employee_id: txn.employee_id,
        branch_id: String(txn.branch_id),
        punch_date: txn.date,
        punch_time: txn.time,
        status: null  // Status calculated later by analyze-attendance Edge Function
      });

      sourceIds.push(txn.id);
    }

    console.log(`🔧 Prepared ${recordsToInsert.length} records for upsert`);

    // ─── Step 5: Upsert into processed_fingerprint_transactions ───
    const UPSERT_BATCH_SIZE = 500;
    let totalUpserted = 0;
    let upsertErrors = 0;

    for (let i = 0; i < recordsToInsert.length; i += UPSERT_BATCH_SIZE) {
      const batch = recordsToInsert.slice(i, i + UPSERT_BATCH_SIZE);

      const { data: upsertedData, error: upsertError } = await supabase
        .from('processed_fingerprint_transactions')
        .upsert(batch, { onConflict: 'id', ignoreDuplicates: true })
        .select('id');

      if (upsertError) {
        console.error(`Upsert batch ${Math.floor(i / UPSERT_BATCH_SIZE) + 1} error:`, upsertError.message);
        upsertErrors++;
        continue;
      }

      totalUpserted += upsertedData?.length || 0;
    }

    console.log(`✅ Upserted ${totalUpserted} records (${upsertErrors} batch errors)`);

    // ─── Step 6: Mark source records as processed ───
    const MARK_BATCH_SIZE = 500;
    let totalMarked = 0;

    for (let i = 0; i < sourceIds.length; i += MARK_BATCH_SIZE) {
      const batch = sourceIds.slice(i, i + MARK_BATCH_SIZE);

      const { error: markError } = await supabase
        .from('hr_fingerprint_transactions')
        .update({ processed: true })
        .in('id', batch);

      if (markError) {
        console.warn(`Mark batch ${Math.floor(i / MARK_BATCH_SIZE) + 1} error:`, markError.message);
      } else {
        totalMarked += batch.length;
      }
    }

    console.log(`📌 Marked ${totalMarked}/${sourceIds.length} source records as processed`);

    const result = {
      success: true,
      processed: totalUpserted,
      marked: totalMarked,
      total_raw: allTransactions.length,
      errors: upsertErrors,
      employees: employees.length
    };

    console.log(`🏁 [Process Fingerprints] Done:`, JSON.stringify(result));

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (err: any) {
    console.error('❌ [Process Fingerprints] Fatal error:', err.message);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
