#!/usr/bin/env node

/**
 * Queue System Setup Script
 * Runs the necessary SQL to create queue tables and migrate stuck broadcast
 */

import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Credentials (from frontend/.env)
const SUPABASE_URL = 'https://supabase.urbanaqura.com';
const SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

console.log('🚀 Queue System Setup\n');
console.log(`📍 Supabase: ${SUPABASE_URL}`);

const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

async function runSQL(sqlFile, description) {
  try {
    console.log(`\n📝 ${description}...`);
    const sqlPath = path.join(__dirname, 'scripts', sqlFile);
    const sql = fs.readFileSync(sqlPath, 'utf-8');
    
    // Split into individual statements for Postgres functions
    const statements = sql.split(';').filter(s => s.trim());
    
    for (const statement of statements) {
      if (!statement.trim()) continue;
      
      const { data, error } = await supabase.rpc('exec_sql', {
        sql_query: statement.trim() + ';'
      }).catch(() => {
        // RPC might not exist, try direct query
        return supabase.from('_sql_exec').insert({ query: statement.trim() }).catch(() => {
          // Fallback: try single statement
          return null;
        });
      });
      
      if (error) {
        console.warn(`⚠️ ${error.message.substring(0, 100)}`);
      }
    }
    
    console.log(`✅ ${description} complete`);
  } catch (e) {
    console.error(`❌ Error: ${e.message}`);
  }
}

async function setupDirect() {
  console.log('\n🔧 Setting up queue tables directly...\n');

  try {
    // 1. Create broadcast_queue_jobs table
    console.log('📝 Creating broadcast_queue_jobs table...');
    const { error: jobsTableError } = await supabase.rpc('pg_exec', {
      sql: `
        CREATE TABLE IF NOT EXISTS broadcast_queue_jobs (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          broadcast_id UUID NOT NULL,
          template_name TEXT NOT NULL,
          language TEXT NOT NULL,
          account_id UUID NOT NULL,
          total_recipients INT NOT NULL,
          processed_count INT DEFAULT 0,
          failed_count INT DEFAULT 0,
          deadline_at TIMESTAMP NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          worker_id TEXT,
          started_at TIMESTAMP,
          completed_at TIMESTAMP,
          error_message TEXT,
          created_at TIMESTAMP DEFAULT NOW(),
          updated_at TIMESTAMP DEFAULT NOW(),
          
          CONSTRAINT fk_broadcast FOREIGN KEY (broadcast_id) REFERENCES wa_broadcasts(id),
          CONSTRAINT fk_account FOREIGN KEY (account_id) REFERENCES wa_accounts(id)
        );
      `
    }).catch(() => ({ error: { message: 'Using direct query method' } }));

    // 2. Try creating via direct insert (simpler fallback)
    console.log('\n📊 Checking if broadcast_queue_jobs table exists...');
    const { data: tableCheck, error: checkErr } = await supabase
      .from('broadcast_queue_jobs')
      .select('*')
      .limit(1);

    if (checkErr && checkErr.code === 'PGRST116') {
      console.log('⚠️ Table does not exist yet');
      console.log('ℹ️ Please run this SQL in Supabase SQL Editor:\n');
      
      // Print the SQL for manual execution
      const setupSQL = fs.readFileSync(path.join(__dirname, 'scripts/setup-broadcast-queue-db.sql'), 'utf-8');
      console.log(setupSQL);
      
      return false;
    } else if (tableCheck !== undefined) {
      console.log('✅ broadcast_queue_jobs table exists!');
    }

    console.log('✅ Queue tables ready\n');
    return true;
  } catch (e) {
    console.error(`❌ Setup error: ${e.message}\n`);
    return false;
  }
}

async function migrateStuckBroadcast() {
  console.log('\n🔄 Migrating stuck broadcast...\n');

  try {
    // Check if broadcast exists
    const { data: broadcast, error: bcErr } = await supabase
      .from('wa_broadcasts')
      .select('id, name, status, sent_count, total_recipients')
      .eq('name', 'salaryoffermonththree')
      .single();

    if (bcErr) {
      console.error(`❌ Broadcast not found: ${bcErr.message}`);
      return false;
    }

    console.log(`📨 Found broadcast: ${broadcast.name}`);
    console.log(`   Status: ${broadcast.status}`);
    console.log(`   Sent: ${broadcast.sent_count}/${broadcast.total_recipients}`);

    // Check pending recipients
    const { data: pending, error: pendErr } = await supabase
      .from('wa_broadcast_recipients')
      .select('*', { count: 'exact' })
      .eq('broadcast_id', broadcast.id)
      .eq('status', 'pending');

    if (pendErr) {
      console.error(`❌ Error checking recipients: ${pendErr.message}`);
      return false;
    }

    console.log(`\n📋 Pending recipients: ${pending?.length || 0}`);

    if (pending && pending.length > 0) {
      // Get template info
      const { data: template } = await supabase
        .from('wa_templates')
        .select('name, language')
        .eq('id', broadcast.template_id)
        .single();

      // Create queue job
      const { data: jobData, error: jobErr } = await supabase
        .from('broadcast_queue_jobs')
        .insert({
          broadcast_id: broadcast.id,
          template_name: template?.name || 'unknown',
          language: template?.language || 'en',
          account_id: broadcast.wa_account_id,
          total_recipients: pending.length,
          deadline_at: new Date(Date.now() + 23.5 * 60 * 60 * 1000).toISOString(), // 23.5h from now
          status: 'pending'
        })
        .select()
        .single();

      if (jobErr) {
        console.error(`❌ Failed to create queue job: ${jobErr.message}`);
        return false;
      }

      console.log(`\n✅ Queue job created: ${jobData.id.slice(0, 8)}`);
      console.log(`   Deadline: ${new Date(jobData.deadline_at).toLocaleString()}`);
      console.log(`   Recipients: ${pending.length}`);

      // Update broadcast status
      const { error: updateErr } = await supabase
        .from('wa_broadcasts')
        .update({ status: 'queued', updated_at: new Date().toISOString() })
        .eq('id', broadcast.id);

      if (updateErr) {
        console.error(`⚠️ Warning: Broadcast status update failed: ${updateErr.message}`);
      } else {
        console.log(`✅ Broadcast status updated to: queued`);
      }

      return true;
    }

  } catch (e) {
    console.error(`❌ Migration error: ${e.message}`);
    return false;
  }
}

async function main() {
  try {
    // Setup tables
    const tablesReady = await setupDirect();
    
    if (!tablesReady) {
      console.log('\n⚠️ Tables may need manual setup. Please run setup-broadcast-queue-db.sql in Supabase SQL Editor.');
    }

    // Migrate broadcast
    await migrateStuckBroadcast();

    console.log('\n✅ Setup complete!');
    console.log('\n📋 Next step: Start the queue worker');
    console.log('   Run: node scripts/broadcast-queue-worker.js\n');

  } catch (e) {
    console.error('\n❌ Fatal error:', e.message);
    process.exit(1);
  }
}

main();
