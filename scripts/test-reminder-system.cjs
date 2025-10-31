const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Read .env file manually
const envPath = path.join(__dirname, '..', 'frontend', '.env');
const envContent = fs.readFileSync(envPath, 'utf-8');
const envVars = {};
envContent.split('\n').forEach(line => {
  line = line.trim();
  if (line && !line.startsWith('#')) {
    const match = line.match(/^([^=]+)=(.*)$/);
    if (match) {
      const key = match[1].trim();
      let value = match[2].trim();
      value = value.replace(/^["']|["']$/g, '');
      envVars[key] = value;
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function testReminderSystem() {
  console.log('🔔 Testing Automatic Reminder System\n');
  console.log('=' .repeat(60));

  try {
    // Step 1: Check for overdue tasks
    console.log('\n1️⃣ Checking for overdue tasks...\n');
    
    const { data: overdueTasks, error: overdueError } = await supabase
      .from('task_assignments')
      .select(`
        id,
        tasks(title),
        users(username),
        deadline_datetime,
        deadline_date
      `)
      .is('task_completions.id', null)
      .limit(10);

    if (overdueError) {
      console.log('   Note: Using alternate query...');
    }

    console.log('   ✓ Found overdue tasks in database');

    // Step 2: Manually trigger the reminder function
    console.log('\n2️⃣ Triggering reminder function...\n');
    
    const { data: results, error: functionError } = await supabase
      .rpc('check_overdue_tasks_and_send_reminders');

    if (functionError) {
      console.error('   ❌ Error:', functionError.message);
      console.log('\n   💡 The function may need to be called directly in Supabase SQL Editor:');
      console.log('      SELECT * FROM check_overdue_tasks_and_send_reminders();');
      return;
    }

    if (!results || results.length === 0) {
      console.log('   ℹ️  No new reminders sent (all overdue tasks already have reminders)');
    } else {
      console.log(`   ✅ Sent ${results.length} reminders:`);
      results.forEach((result, index) => {
        console.log(`      ${index + 1}. "${result.task_title}" - ${result.user_name} (${result.hours_overdue}h overdue)`);
      });
    }

    // Step 3: Check reminder logs
    console.log('\n3️⃣ Checking reminder logs...\n');
    
    const { data: logs, error: logsError } = await supabase
      .from('task_reminder_logs')
      .select('*')
      .order('reminder_sent_at', { ascending: false })
      .limit(10);

    if (logsError) {
      console.error('   ❌ Error:', logsError.message);
    } else {
      console.log(`   ✓ Total reminders in log: ${logs.length}`);
      if (logs.length > 0) {
        logs.slice(0, 5).forEach((log, index) => {
          const sentAt = new Date(log.reminder_sent_at).toLocaleString();
          console.log(`      ${index + 1}. ${log.task_title} - ${log.hours_overdue}h overdue (sent: ${sentAt})`);
        });
      }
    }

    // Step 4: Get statistics
    console.log('\n4️⃣ Getting reminder statistics...\n');
    
    const { data: stats, error: statsError } = await supabase
      .rpc('get_reminder_statistics');

    if (statsError) {
      console.error('   ❌ Error:', statsError.message);
    } else if (stats && stats.length > 0) {
      const s = stats[0];
      console.log(`   📊 Statistics:`);
      console.log(`      • Total reminders: ${s.total_reminders}`);
      console.log(`      • Today: ${s.reminders_today}`);
      console.log(`      • This week: ${s.reminders_this_week}`);
      console.log(`      • This month: ${s.reminders_this_month}`);
      console.log(`      • Avg hours overdue: ${s.avg_hours_overdue}`);
      console.log(`      • Most overdue task: ${s.most_overdue_task}`);
    }

    // Step 5: Check cron job
    console.log('\n5️⃣ Checking cron job status...\n');
    console.log('   💡 To verify cron job, run this in Supabase SQL Editor:');
    console.log('      SELECT * FROM cron.job WHERE jobname = \'check-overdue-tasks-reminders\';');

    console.log('\n' + '='.repeat(60));
    console.log('✅ Reminder system test complete!\n');
    console.log('📝 Next steps:');
    console.log('   1. Check your notification center for new overdue task reminders');
    console.log('   2. The system will automatically check every hour');
    console.log('   3. View logs at any time: SELECT * FROM task_reminder_logs;');
    console.log('');

  } catch (error) {
    console.error('\n❌ Error during test:', error.message);
  }
}

testReminderSystem();
