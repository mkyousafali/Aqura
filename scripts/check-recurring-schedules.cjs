#!/usr/bin/env node

/**
 * Script to check and notify recurring schedules
 * This script should be run daily (e.g., via cron job or scheduled task)
 * to send notifications 2 days before recurring expense occurrences
 * 
 * Usage:
 *   node scripts/check-recurring-schedules.cjs
 * 
 * Can be scheduled with:
 *   - GitHub Actions (scheduled workflow)
 *   - Vercel Cron
 *   - External cron service
 *   - System crontab: 0 6 * * * cd /path/to/Aqura && node scripts/check-recurring-schedules.cjs
 */

require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase client with service role key (required for admin operations)
const supabaseUrl = process.env.PUBLIC_SUPABASE_URL || process.env.VITE_SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.VITE_SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Error: Supabase URL or Service Role Key not found in environment variables');
  console.error('   Please ensure PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

/**
 * Main function to check and notify recurring schedules
 */
async function checkRecurringSchedules() {
  console.log('🔍 Checking recurring schedules...');
  console.log(`📅 Date: ${new Date().toISOString()}`);
  console.log(`🔗 Supabase URL: ${supabaseUrl}\n`);

  try {
    // Call the Supabase function
    const { data, error } = await supabase
      .rpc('check_and_notify_recurring_schedules_with_logging');

    if (error) {
      console.error('❌ Error calling function:', error);
      process.exit(1);
    }

    // Display results
    if (data && data.length > 0) {
      const result = data[0];
      console.log('✅ Function executed successfully!\n');
      console.log(`📊 Results:`);
      console.log(`   • Schedules checked: ${result.schedules_checked || 0}`);
      console.log(`   • Notifications sent: ${result.notifications_sent || 0}`);
      console.log(`   • Execution date: ${result.execution_date}`);
      console.log(`   • Message: ${result.message}\n`);

      if (result.notifications_sent > 0) {
        console.log(`✉️  ${result.notifications_sent} notification(s) sent to approvers for upcoming recurring expenses`);
      } else {
        console.log('ℹ️  No upcoming recurring schedules found (no notifications sent)');
      }
    } else {
      console.log('ℹ️  Function executed but returned no data');
    }

    // Get recent log entries
    console.log('\n📋 Recent execution history:');
    const { data: logs, error: logError } = await supabase
      .from('recurring_schedule_check_log')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(5);

    if (logError) {
      console.error('⚠️  Could not fetch execution history:', logError.message);
    } else if (logs && logs.length > 0) {
      logs.forEach((log, index) => {
        console.log(`   ${index + 1}. ${log.check_date}: ${log.schedules_checked} checked, ${log.notifications_sent} notified`);
      });
    }

  } catch (err) {
    console.error('❌ Unexpected error:', err);
    process.exit(1);
  }
}

// Run the check
checkRecurringSchedules()
  .then(() => {
    console.log('\n✅ Script completed successfully');
    process.exit(0);
  })
  .catch((err) => {
    console.error('\n❌ Script failed:', err);
    process.exit(1);
  });
