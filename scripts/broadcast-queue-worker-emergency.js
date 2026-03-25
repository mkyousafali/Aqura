#!/usr/bin/env node

/**
 * Emergency Broadcast Queue Worker
 * Processes stuck broadcast (19,003 pending recipients) 
 * WITHOUT requiring new database tables
 * 
 * Usage: node scripts/broadcast-queue-worker-emergency.js
 */

import { createClient } from '@supabase/supabase-js';
import fetch from 'node-fetch';
import { v4 as uuidv4 } from 'uuid';

const SUPABASE_URL = 'https://supabase.urbanaqura.com';
const SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const GRAPH_API_VERSION = 'v22.0';
const WORKER_ID = `emergency-${uuidv4().slice(0, 8)}`;

const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

console.log(`\n🚨 Emergency Broadcast Queue Worker ${WORKER_ID}`);
console.log('================================================\n');

/**
 * Send WhatsApp message
 */
async function sendWhatsAppMessage(accessToken, phoneNumberId, phone, templateName, language) {
  try {
    const payload = {
      messaging_product: 'whatsapp',
      to: phone.replace(/^\+/, ''),
      type: 'template',
      template: {
        name: templateName,
        language: { code: language || 'en' }
      }
    };

    const resp = await fetch(
      `https://graph.facebook.com/${GRAPH_API_VERSION}/${phoneNumberId}/messages`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload),
        timeout: 10000
      }
    );

    const data = await resp.json();
    if (!resp.ok) {
      throw new Error(data.error?.message || `HTTP ${resp.status}`);
    }
    
    return { success: true, messageId: data.messages?.[0]?.id };
  } catch (e) {
    return { success: false, error: e.message };
  }
}

/**
 * Process stuck broadcast
 */
async function processStuckBroadcast() {
  try {
    // 1. Find the stuck broadcast
    console.log('📍 Finding stuck broadcast...');
    const { data: broadcast, error: bcErr } = await supabase
      .from('wa_broadcasts')
      .select('id, wa_account_id, template_id, name, sent_count, total_recipients')
      .eq('name', 'salaryoffermonththree')
      .eq('status', 'sending')
      .single();

    if (bcErr || !broadcast) {
      console.error('❌ Stuck broadcast not found or wrong status');
      return;
    }

    console.log(`✅ Found: ${broadcast.name}`);
    console.log(`   Sent: ${broadcast.sent_count}/${broadcast.total_recipients}`);

    // 2. Get account credentials & template info
    console.log('\n🔐 Loading credentials...');
    const [accountRes, templateRes] = await Promise.all([
      supabase
        .from('wa_accounts')
        .select('access_token, phone_number_id')
        .eq('id', broadcast.wa_account_id)
        .single(),
      supabase
        .from('wa_templates')
        .select('name, language')
        .eq('id', broadcast.template_id)
        .single()
    ]);

    if (!accountRes.data || !templateRes.data) {
      console.error('❌ Account or template not found');
      return;
    }

    const { access_token, phone_number_id } = accountRes.data;
    const { name: template_name, language } = templateRes.data;

    console.log(`✅ Template: ${template_name} (${language})`);

    // 3. Get pending recipients
    console.log('\n📋 Loading pending recipients...');
    const { data: allPending, error: pendErr, count } = await supabase
      .from('wa_broadcast_recipients')
      .select('id, phone_number', { count: 'exact' })
      .eq('broadcast_id', broadcast.id)
      .eq('status', 'pending');

    if (pendErr) throw pendErr;

    console.log(`✅ Pending: ${count || allPending?.length || 0}`);

    const pending = allPending || [];
    if (pending.length === 0) {
      console.log('✅ No pending recipients. Broadcast complete!');
      return;
    }

    // 4. Process in batches
    const BATCH_SIZE = 50;
    const MAX_CONCURRENT = 20;
    let totalSent = 0;
    let totalFailed = 0;
    const startTime = Date.now();
    const DEADLINE = new Date(Date.now() + 23.5 * 60 * 60 * 1000); // 23.5 hours

    console.log(`\n🚀 Processing ${pending.length} recipients`);
    console.log(`   Batch size: ${BATCH_SIZE}`);
    console.log(`   Deadline: ${DEADLINE.toLocaleString()}`);
    console.log(`   Worker ID: ${WORKER_ID}\n`);

    for (let batchIdx = 0; batchIdx < pending.length; batchIdx += BATCH_SIZE) {
      // Check deadline
      if (new Date() >= DEADLINE) {
        console.log('\n⏰ Deadline reached. Stopping.');
        break;
      }

      const batch = pending.slice(batchIdx, batchIdx + BATCH_SIZE);
      
      // Send with concurrency control
      const sendStart = Date.now();
      const results = [];
      
      for (let i = 0; i < batch.length; i += MAX_CONCURRENT) {
        const concurrent = batch.slice(i, i + MAX_CONCURRENT);
        const promises = concurrent.map(r =>
          sendWhatsAppMessage(access_token, phone_number_id, r.phone_number, template_name, language)
            .then(result => ({ recipientId: r.id, ...result }))
        );
        
        const concurrentResults = await Promise.allSettled(promises);
        results.push(...concurrentResults);
      }

      // Update DB
      const updates = [];
      for (const result of results) {
        if (result.status === 'fulfilled') {
          const { recipientId, success, messageId, error } = result.value;
          if (success) {
            totalSent++;
            updates.push({
              id: recipientId,
              updates: {
                status: 'sent',
                whatsapp_message_id: messageId,
                sent_at: new Date().toISOString()
              }
            });
          } else {
            totalFailed++;
            updates.push({
              id: recipientId,
              updates: {
                status: 'failed',
                error_details: error?.substring(0, 500)
              }
            });
          }
        }
      }

      // Batch DB updates (parallel)
      await Promise.all(updates.map(u =>
        supabase
          .from('wa_broadcast_recipients')
          .update(u.updates)
          .eq('id', u.id)
      ));

      const sendDuration = ((Date.now() - sendStart) / 1000).toFixed(1);
      const batchNum = Math.floor(batchIdx / BATCH_SIZE) + 1;
      const totalBatches = Math.ceil(pending.length / BATCH_SIZE);
      const rate = (batch.length / (Date.now() - sendStart) * 1000).toFixed(0);
      
      console.log(`  Batch ${batchNum}/${totalBatches}: +${totalSent} sent (${rate} msg/s, ${sendDuration}s)`);
    }

    // 5. Update broadcast status
    const totalTime = ((Date.now() - startTime) / 1000).toFixed(1);
    const successRate = ((totalSent / pending.length) * 100).toFixed(1);

    console.log(`\n✅ Processing complete!`);
    console.log(`   Sent: ${totalSent}/${pending.length} (${successRate}%)`);
    console.log(`   Failed: ${totalFailed}`);
    console.log(`   Duration: ${totalTime}s`);
    console.log(`   Rate: ${(totalSent / (totalTime)).toFixed(1)} msg/s`);

    // Update broadcast record
    const { error: updateErr } = await supabase
      .from('wa_broadcasts')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', broadcast.id);

    if (!updateErr) {
      console.log(`\n🎉 Broadcast marked as completed!`);
    }

    // Summary
    const { count: sentCount } = await supabase
      .from('wa_broadcast_recipients')
      .select('*', { count: 'exact', head: true })
      .eq('broadcast_id', broadcast.id)
      .eq('status', 'sent');

    const { count: deliveredCount } = await supabase
      .from('wa_broadcast_recipients')
      .select('*', { count: 'exact', head: true })
      .eq('broadcast_id', broadcast.id)
      .eq('status', 'delivered');

    console.log(`\n📊 Final Status:`);
    console.log(`   Sent: ${sentCount}`);
    console.log(`   Delivered: ${deliveredCount}`);
    console.log(`   Total Recipients: ${broadcast.total_recipients}`);

  } catch (e) {
    console.error('\n❌ Fatal error:', e.message);
    console.error(e.stack);
  }
}

// Run
processStuckBroadcast().catch(e => {
  console.error('Unhandled error:', e);
  process.exit(1);
});
