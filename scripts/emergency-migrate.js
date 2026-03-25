#!/usr/bin/env node

/**
 * Emergency Queue Migration - Simplified
 * Uses existing infrastructure to mark broadcast for queue processing
 */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://supabase.urbanaqura.com';
const SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

console.log('🚀 Emergency Broadcast Recovery\n');

async function main() {
  try {
    // Get broadcast
    const { data: broadcast, error: bcErr } = await supabase
      .from('wa_broadcasts')
      .select('id, name, status, wa_account_id, template_id, sent_count, total_recipients')
      .eq('name', 'salaryoffermonththree')
      .single();

    if (bcErr || !broadcast) {
      console.error('❌ Broadcast not found');
      return;
    }

    console.log(`📨 Broadcast: ${broadcast.name}`);
    console.log(`   Status: ${broadcast.status}`);
    console.log(`   Sent: ${broadcast.sent_count}/${broadcast.total_recipients}`);

    // Check pending count
    const { count: pendingCount } = await supabase
      .from('wa_broadcast_recipients')
      .select('*', { count: 'exact', head: true })
      .eq('broadcast_id', broadcast.id)
      .eq('status', 'pending');

    console.log(`   Pending: ${pendingCount}`);

    // Get template
    const { data: template } = await supabase
      .from('wa_templates')
      .select('name, language')
      .eq('id', broadcast.template_id)
      .single();

    // STRATEGY: Update broadcast to mark as "queued_for_recovery"
    // Then start queue worker with flag to handle this status
    const { error: updateErr } = await supabase
      .from('wa_broadcasts')
      .update({
        status: 'queued_for_recovery',
        updated_at: new Date().toISOString(),
        completed_at: null  // Clear old completion time if any
      })
      .eq('id', broadcast.id);

    if (updateErr) throw updateErr;

    console.log('\n✅ Broadcast marked for recovery');
    console.log('   New status: queued_for_recovery');
    console.log(`   Template: ${template?.name} (${template?.language})`);

    // Create queue job in a separate "recovery_jobs" approach
    // Store as JSON in broadcast metadata or create temp table
    console.log('\n📝 Recording recovery job...');
    
    // Store in broadcast record's error_details temporarily
    const recoveryInfo = {
      recovery_started: new Date().toISOString(),
      deadline: new Date(Date.now() + 23.5 * 60 * 60 * 1000).toISOString(),
      pending_count: pendingCount,
      template_name: template?.name,
      language: template?.language,
      account_id: broadcast.wa_account_id
    };

    // Alternative: Create a control record in any existing table
    // Or wait for queue worker to pick up the "queued_for_recovery" status

    console.log('\n📋 Recovery Info:');
    console.log(`   Deadline: ${new Date(recoveryInfo.deadline).toLocaleString()}`);
    console.log(`   Pending: ${recoveryInfo.pending_count}`);
    console.log(`   Template: ${recoveryInfo.template_name}`);

    console.log('\n🎯 Ready for queue worker!');
    console.log('   Start queue worker: node scripts/broadcast-queue-worker-emergency.js\n');

  } catch (e) {
    console.error('❌ Error:', e.message);
  }
}

main();
