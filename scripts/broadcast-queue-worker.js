#!/usr/bin/env node

/**
 * Broadcast Queue Worker
 * Processes pending broadcast jobs from queue
 * 
 * Run with: node scripts/broadcast-queue-worker.js
 * Or in background: nohup node scripts/broadcast-queue-worker.js > broadcast-worker.log 2>&1 &
 */

import { createClient } from '@supabase/supabase-js';
import fetch from 'node-fetch';
import { v4 as uuidv4 } from 'uuid';

const GRAPH_API_VERSION = 'v22.0';
const WORKER_ID = `worker-${uuidv4().split('-')[0]}`;
const POLL_INTERVAL_MS = 5000; // Check for jobs every 5 seconds
const BATCH_SIZE = 50; // Process 50 recipients per batch
const MAX_CONCURRENT_SENDS = 20; // 20 parallel API calls
const LOCK_EXPIRY_MS = 5 * 60 * 1000; // 5 minute lock timeout

// Initialize Supabase
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

console.log(`🚀 Broadcast Queue Worker ${WORKER_ID} started`);

/**
 * Acquire lock for a job (prevent duplicate processing)
 */
async function acquireLock(jobId) {
  try {
    const { data, error } = await supabase
      .from('broadcast_queue_worker_lock')
      .insert({
        job_id: jobId,
        worker_id: WORKER_ID,
        expires_at: new Date(Date.now() + LOCK_EXPIRY_MS).toISOString()
      })
      .select()
      .single();
    
    if (error) {
      if (error.code === '23505') return null; // Already locked
      throw error;
    }
    return data;
  } catch (e) {
    console.error(`⚠️ Lock acquisition error for job ${jobId}:`, e.message);
    return null;
  }
}

/**
 * Release lock for a job
 */
async function releaseLock(jobId) {
  try {
    await supabase
      .from('broadcast_queue_worker_lock')
      .delete()
      .eq('job_id', jobId);
  } catch (e) {
    console.error(`⚠️ Lock release error for job ${jobId}:`, e.message);
  }
}

/**
 * Poll for pending jobs
 */
async function getPendingJobs() {
  try {
    const { data, error } = await supabase
      .from('broadcast_queue_jobs')
      .select('*')
      .in('status', ['pending', 'processing'])
      .lt('deadline_at', new Date().toISOString()) // Only jobs not yet expired
      .order('deadline_at', { ascending: true })
      .limit(5); // Process up to 5 jobs in parallel
    
    if (error) throw error;
    return data || [];
  } catch (e) {
    console.error('❌ Error fetching pending jobs:', e.message);
    return [];
  }
}

/**
 * Audit log helper
 */
async function auditLog(jobId, eventType, message, recipientsCount = null) {
  try {
    await supabase
      .from('broadcast_queue_audit')
      .insert({
        job_id: jobId,
        event_type: eventType,
        message,
        recipients_count: recipientsCount
      });
  } catch (e) {
    console.error(`⚠️ Audit log error:`, e.message);
  }
}

/**
 * Send WhatsApp message
 */
async function sendWhatsAppMessage(accessToken, phoneNumberId, phone, templateName, language, components) {
  try {
    const payload = {
      messaging_product: 'whatsapp',
      to: phone.replace(/^\+/, ''),
      type: 'template',
      template: {
        name: templateName,
        language: { code: language || 'en' },
        ...(components ? { components } : {})
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
      const errMsg = data.error?.message || `HTTP ${resp.status}`;
      throw new Error(errMsg);
    }
    
    return { success: true, messageId: data.messages?.[0]?.id };
  } catch (e) {
    return { success: false, error: e.message };
  }
}

/**
 * Process a broadcast job
 */
async function processJob(job) {
  const { id: jobId, broadcast_id, template_name, language, account_id } = job;
  
  console.log(`📨 Processing job ${jobId.slice(0, 8)} - Template: ${template_name}`);
  
  // Acquire lock
  const lock = await acquireLock(jobId);
  if (!lock) {
    console.log(`⏭️ Job ${jobId.slice(0, 8)} already being processed by another worker`);
    return;
  }

  try {
    // Mark as processing
    await supabase
      .from('broadcast_queue_jobs')
      .update({
        status: 'processing',
        worker_id: WORKER_ID,
        started_at: new Date().toISOString()
      })
      .eq('id', jobId);

    // Get account credentials
    const { data: account, error: accountErr } = await supabase
      .from('wa_accounts')
      .select('access_token, phone_number_id')
      .eq('id', account_id)
      .single();
    
    if (accountErr || !account) {
      throw new Error('Account not found');
    }

    const { access_token, phone_number_id } = account;
    
    // Load pending recipients in batches
    let totalProcessed = 0;
    let totalFailed = 0;
    let pageNum = 0;

    while (true) {
      const { data: recipients, error: recipErr } = await supabase
        .from('wa_broadcast_recipients')
        .select('id, phone_number')
        .eq('broadcast_id', broadcast_id)
        .eq('status', 'pending')
        .range(pageNum * BATCH_SIZE, (pageNum + 1) * BATCH_SIZE - 1);
      
      if (recipErr) throw recipErr;
      if (!recipients || recipients.length === 0) break;

      // Send batch with concurrency control
      const sendPromises = recipients.map(r =>
        sendWhatsAppMessage(access_token, phone_number_id, r.phone_number, template_name, language)
          .then(result => ({ recipientId: r.id, ...result }))
      );

      const results = await Promise.allSettled(sendPromises);

      // Update DB with results
      const updates = [];
      for (const [idx, result] of results.entries()) {
        const recipientId = recipients[idx].id;
        if (result.status === 'fulfilled') {
          const { success, messageId, error } = result.value;
          if (success) {
            totalProcessed++;
            updates.push({
              id: recipientId,
              status: 'sent',
              whatsapp_message_id: messageId,
              sent_at: new Date().toISOString()
            });
          } else {
            totalFailed++;
            updates.push({
              id: recipientId,
              status: 'failed',
              error_details: error?.substring(0, 500)
            });
          }
        } else {
          totalFailed++;
          updates.push({
            id: recipientId,
            status: 'failed',
            error_details: result.reason?.message?.substring(0, 500)
          });
        }
      }

      // Bulk update recipients
      for (const update of updates) {
        await supabase
          .from('wa_broadcast_recipients')
          .update({
            status: update.status,
            ...(update.whatsapp_message_id && { whatsapp_message_id: update.whatsapp_message_id }),
            ...(update.sent_at && { sent_at: update.sent_at }),
            ...(update.error_details && { error_details: update.error_details })
          })
          .eq('id', update.id);
      }

      // Update job progress  
      await supabase
        .from('broadcast_queue_jobs')
        .update({
          processed_count: totalProcessed,
          failed_count: totalFailed,
          updated_at: new Date().toISOString()
        })
        .eq('id', jobId);

      console.log(`  ✅ Batch ${pageNum + 1}: ${recipients.length} sent (${totalProcessed} total)`);
      pageNum++;

      // Check deadline
      if (new Date() > new Date(job.deadline_at)) {
        console.warn(`⏰ Deadline reached for job ${jobId.slice(0, 8)}`);
        break;
      }
    }

    // Mark as completed
    await supabase
      .from('broadcast_queue_jobs')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString()
      })
      .eq('id', jobId);

    // Update broadcast record
    await supabase
      .from('wa_broadcasts')
      .update({
        status: 'completed',
        updated_at: new Date().toISOString()
      })
      .eq('id', broadcast_id);

    console.log(`✅ Job ${jobId.slice(0, 8)} completed | Sent: ${totalProcessed}, Failed: ${totalFailed}`);
    await auditLog(jobId, 'completed', `Processed ${totalProcessed} recipients, ${totalFailed} failed`, totalProcessed);

  } catch (e) {
    console.error(`❌ Job ${jobId.slice(0, 8)} error:`, e.message);
    
    await supabase
      .from('broadcast_queue_jobs')
      .update({
        status: 'failed',
        error_message: e.message.substring(0, 500)
      })
      .eq('id', jobId);

    await auditLog(jobId, 'error', e.message);
  } finally {
    await releaseLock(jobId);
  }
}

/**
 * Main loop
 */
async function main() {
  while (true) {
    try {
      const jobs = await getPendingJobs();
      
      if (jobs.length > 0) {
        console.log(`\n📋 Found ${jobs.length} pending jobs at ${new Date().toLocaleTimeString()}`);
        
        // Process jobs in parallel
        await Promise.all(jobs.map(job => processJob(job)));
      }
      
      // Wait before next poll
      await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
    } catch (e) {
      console.error('Fatal error in main loop:', e.message);
      await new Promise(r => setTimeout(r, 10000)); // Wait 10s before retry
    }
  }
}

// Start worker
main().catch(e => {
  console.error('❌ Worker crashed:', e);
  process.exit(1);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n⏹️ Worker shutting down...');
  process.exit(0);
});
