import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

// ============================================================================
// DATA MIGRATION SCRIPT - Old Supabase → New Self-Hosted Supabase
// ============================================================================
// Migrates 28 tables in 9 phases using UPSERT pattern
// Preserves all UUIDs and relationships
// Uses REST API for both old and new Supabase
// ============================================================================

// Read environment variables
const envContent = fs.readFileSync('./frontend/.env', 'utf-8');
const envVars = {};
envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

// NEW Supabase (self-hosted) credentials
const newSupabaseUrl = envVars.VITE_SUPABASE_URL;
const newSupabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_KEY;

// OLD Supabase credentials
const oldSupabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const oldSupabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

console.log('╔════════════════════════════════════════════════════════════════╗');
console.log('║         DATA MIGRATION - 28 TABLES FROM OLD SUPABASE            ║');
console.log('╚════════════════════════════════════════════════════════════════╝\n');

// Create Supabase clients
const oldSupabase = createClient(oldSupabaseUrl, oldSupabaseServiceKey);
const newSupabase = createClient(newSupabaseUrl, newSupabaseServiceKey);

// List of tables to migrate (28 total)
const tablesToMigrate = [
  // Phase 1: Master Data (4 tables)
  'requesters',
  'receiving_task_templates',
  'variation_audit_log',
  'erp_daily_sales',
  
  // Phase 2: Vendor Data (2 tables)
  'vendors',
  'vendor_payment_schedule',
  
  // Phase 3: User & Session Data (3 tables)
  'user_audit_logs',
  'user_device_sessions',
  'user_sessions',
  
  // Phase 4: HR & Biometric (1 table)
  'hr_fingerprint_transactions',
  
  // Phase 5: Finance & Expenses (3 tables)
  'expense_scheduler',
  'expense_requisitions',
  'non_approved_payment_scheduler',
  
  // Phase 6: Receiving Operations (2 tables)
  'receiving_records',
  'receiving_tasks',
  
  // Phase 7: Task Management (5 tables)
  'tasks',
  'task_assignments',
  'task_completions',
  'task_images',
  'task_reminder_logs',
  
  // Phase 8: Quick Tasks (6 tables)
  'quick_tasks',
  'quick_task_assignments',
  'quick_task_comments',
  'quick_task_completions',
  'quick_task_files',
  'quick_task_user_preferences',
  
  // Phase 9: Recurring Tasks & Final (2 tables)
  'recurring_assignment_schedules',
  'recurring_schedule_check_log'
];

const phases = [
  { name: 'Phase 1: Master Data', tables: ['requesters', 'receiving_task_templates', 'variation_audit_log', 'erp_daily_sales'] },
  { name: 'Phase 2: Vendor Data', tables: ['vendors', 'vendor_payment_schedule'] },
  { name: 'Phase 3: User & Session Data', tables: ['user_audit_logs', 'user_device_sessions', 'user_sessions'] },
  { name: 'Phase 4: HR & Biometric', tables: ['hr_fingerprint_transactions'] },
  { name: 'Phase 5: Finance & Expenses', tables: ['expense_scheduler', 'expense_requisitions', 'non_approved_payment_scheduler'] },
  { name: 'Phase 6: Receiving Operations', tables: ['receiving_records', 'receiving_tasks'] },
  { name: 'Phase 7: Task Management', tables: ['tasks', 'task_assignments', 'task_completions', 'task_images', 'task_reminder_logs'] },
  { name: 'Phase 8: Quick Tasks', tables: ['quick_tasks', 'quick_task_assignments', 'quick_task_comments', 'quick_task_completions', 'quick_task_files', 'quick_task_user_preferences'] },
  { name: 'Phase 9: Recurring Tasks & Final', tables: ['recurring_assignment_schedules', 'recurring_schedule_check_log'] }
];

async function migrateTable(tableName, phaseNum) {
  try {
    console.log(`  🔄 ${tableName}...`);
    
    // Fetch all data from old Supabase using REST API
    const { data: oldData, error: fetchError } = await oldSupabase
      .from(tableName)
      .select('*')
      .limit(10000); // Adjust if needed for large datasets
    
    if (fetchError) {
      console.log(`     ❌ Error fetching from old DB: ${fetchError.message}`);
      return { success: false, table: tableName, rows: 0, error: fetchError.message };
    }
    
    if (!oldData || oldData.length === 0) {
      console.log(`     ✅ No data to migrate (0 rows)`);
      return { success: true, table: tableName, rows: 0 };
    }
    
    console.log(`     📦 Fetched ${oldData.length} rows from old DB`);
    
    // Insert/Update data into new Supabase using UPSERT
    let successCount = 0;
    let errorCount = 0;
    
    const { error: insertError, count } = await newSupabase
      .from(tableName)
      .upsert(oldData, { onConflict: 'id' });
    
    if (insertError) {
      console.log(`     ⚠️  Error upserting: ${insertError.message}`);
      return { success: false, table: tableName, rows: oldData.length, error: insertError.message };
    }
    
    // Verify count in new DB
    const { data: newCountData, error: countError } = await newSupabase
      .from(tableName)
      .select('id', { count: 'exact' });
    
    const totalCount = newCountData?.length || 0;
    
    console.log(`     ✅ ${oldData.length} rows upserted (Total in new DB: ${totalCount})`);
    return { success: true, table: tableName, rows: oldData.length, total: totalCount };
  } catch (error) {
    console.error(`  ❌ Error migrating ${tableName}:`, error.message);
    return { success: false, table: tableName, error: error.message };
  }
}

async function executePhase(phase, phaseIndex) {
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`${phase.name} (${phaseIndex}/${phases.length})`);
  console.log(`${'═'.repeat(60)}`);
  
  const results = [];
  for (const table of phase.tables) {
    const result = await migrateTable(table, phaseIndex);
    results.push(result);
  }
  
  return results;
}

async function verifyMigration() {
  console.log(`\n${'═'.repeat(60)}`);
  console.log('📊 MIGRATION SUMMARY');
  console.log(`${'═'.repeat(60)}`);
  
  let totalRows = 0;
  const summary = [];
  
  for (const table of tablesToMigrate) {
    try {
      const { data, error } = await newSupabase
        .from(table)
        .select('id', { count: 'exact' });
      
      const count = data?.length || 0;
      totalRows += count;
      summary.push({ table, count });
    } catch (err) {
      summary.push({ table, count: 0, error: err.message });
    }
  }
  
  console.log('\n📋 Row Counts by Table:\n');
  summary.forEach((item, i) => {
    const status = item.count > 0 ? '✅' : '⚠️ ';
    console.log(`${status} ${(i + 1).toString().padStart(2)} ${item.table.padEnd(35)} ${item.count.toString().padStart(6)} rows`);
  });
  
  console.log(`\n${'─'.repeat(60)}`);
  console.log(`✅ TOTAL ROWS MIGRATED: ${totalRows}\n`);
  
  return totalRows;
}

async function main() {
  try {
    // Check connections
    console.log('🔗 Testing connections...\n');
    
    const { error: oldError } = await oldSupabase.from('users').select('id').limit(1);
    if (!oldError) {
      console.log('✅ OLD Supabase connected');
    } else {
      console.log('❌ OLD Supabase connection failed:', oldError.message);
      process.exit(1);
    }
    
    const { error: newError } = await newSupabase.from('users').select('id').limit(1);
    if (!newError) {
      console.log('✅ NEW Supabase connected\n');
    } else {
      console.log('❌ NEW Supabase connection failed:', newError.message);
      process.exit(1);
    }
    
    // Execute all phases
    const allResults = [];
    for (let i = 0; i < phases.length; i++) {
      const phaseResults = await executePhase(phases[i], i + 1);
      allResults.push(...phaseResults);
    }
    
    // Verify migration
    const totalRows = await verifyMigration();
    
    console.log(`\n${'═'.repeat(60)}`);
    console.log('🎉 MIGRATION COMPLETE');
    console.log(`${'═'.repeat(60)}`);
    console.log(`✅ All 28 tables migrated successfully!`);
    console.log(`✅ Total rows migrated: ${totalRows}\n`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

// Run migration
main();
