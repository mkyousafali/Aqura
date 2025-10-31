const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Read .env file from frontend directory
const envPath = path.join(__dirname, '..', 'frontend', '.env');
const envContent = fs.readFileSync(envPath, 'utf-8');
const env = {};
envContent.split('\n').forEach(line => {
  line = line.trim();
  if (line && !line.startsWith('#')) {
    const match = line.match(/^([^=]+)=(.*)$/);
    if (match) {
      const key = match[1].trim();
      let value = match[2].trim();
      value = value.replace(/^["']|["']$/g, '');
      env[key] = value;
    }
  }
});

const supabaseUrl = env.VITE_SUPABASE_URL;
const supabaseServiceKey = env.VITE_SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function testOverdueReminders() {
  console.log('🔍 Testing Overdue Task Reminder System\n');
  console.log('='.repeat(80));

  // 1. Check for overdue tasks WITHOUT completion records
  console.log('\n1️⃣ Checking for overdue incomplete tasks...\n');
  
  try {
    const { data: overdueTasks, error: overdueError } = await supabase
      .from('task_assignments')
      .select(`
        id,
        assigned_to_user_id,
        deadline_datetime,
        deadline_date,
        tasks!inner(title),
        users!inner(username)
      `)
      .lt('deadline_datetime', new Date().toISOString())
      .limit(10);

    if (overdueError) {
      console.error('Error checking overdue tasks:', overdueError);
    } else if (overdueTasks && overdueTasks.length > 0) {
      console.log('Found', overdueTasks.length, 'overdue task assignments:\n');
      
      // Check each one for completion and reminder status
      for (const task of overdueTasks) {
        const deadline = task.deadline_datetime || task.deadline_date;
        const hoursOverdue = (Date.now() - new Date(deadline).getTime()) / (1000 * 60 * 60);
        
        // Check if has completion
        const { data: completion } = await supabase
          .from('task_completions')
          .select('id')
          .eq('assignment_id', task.id)
          .limit(1);
        
        // Check if reminder sent
        const { data: reminder } = await supabase
          .from('task_reminder_logs')
          .select('id')
          .eq('task_assignment_id', task.id)
          .limit(1);
        
        console.log(`• "${task.tasks.title}"`);
        console.log(`  User: ${task.users.username}`);
        console.log(`  Hours Overdue: ${Math.round(hoursOverdue * 10) / 10}`);
        console.log(`  Has Completion: ${completion && completion.length > 0}`);
        console.log(`  Reminder Sent: ${reminder && reminder.length > 0}`);
        console.log('');
      }
    } else {
      console.log('No overdue tasks found');
    }
  } catch (err) {
    console.error('Error:', err.message);
  }

  // 2. Check task_reminder_logs
  console.log('\n2️⃣ Checking reminder logs...\n');
  
  const { data: reminderLogs, error: logsError } = await supabase
    .from('task_reminder_logs')
    .select('*')
    .order('reminder_sent_at', { ascending: false })
    .limit(10);

  if (logsError) {
    console.error('Error checking reminder logs:', logsError);
  } else if (reminderLogs && reminderLogs.length > 0) {
    console.log(`Found ${reminderLogs.length} reminder logs:\n`);
    reminderLogs.forEach((log, i) => {
      console.log(`${i + 1}. ${log.task_title}`);
      console.log(`   Sent at: ${log.reminder_sent_at}`);
      console.log(`   Hours overdue: ${log.hours_overdue}`);
      console.log('');
    });
  } else {
    console.log('✅ No reminders sent yet (task_reminder_logs is empty)');
  }

  // 3. Check notifications
  console.log('\n3️⃣ Checking overdue task notifications...\n');
  
  const { data: notifications, error: notifError } = await supabase
    .from('notifications')
    .select('*')
    .eq('type', 'task_overdue')
    .order('created_at', { ascending: false })
    .limit(5);

  if (notifError) {
    console.error('Error checking notifications:', notifError);
  } else if (notifications && notifications.length > 0) {
    console.log(`Found ${notifications.length} overdue notifications:\n`);
    notifications.forEach((notif, i) => {
      console.log(`${i + 1}. ${notif.title}`);
      console.log(`   Message: ${notif.message}`);
      console.log(`   Created: ${notif.created_at}`);
      console.log(`   Read: ${notif.read}`);
      console.log('');
    });
  } else {
    console.log('✅ No overdue notifications found yet');
  }

  // 4. Test the function (dry run)
  console.log('\n4️⃣ Testing reminder function...\n');
  
  const { data: functionResult, error: funcError } = await supabase.rpc(
    'check_overdue_tasks_and_send_reminders'
  );

  if (funcError) {
    console.error('❌ Function error:', funcError);
  } else if (functionResult && functionResult.length > 0) {
    console.log(`✅ Function sent ${functionResult.length} reminders:\n`);
    functionResult.forEach((result, i) => {
      console.log(`${i + 1}. ${result.task_title} → ${result.user_name} (${result.hours_overdue}h overdue)`);
    });
  } else {
    console.log('⚠️  Function returned no results');
    console.log('   This means either:');
    console.log('   - No overdue incomplete tasks exist');
    console.log('   - All overdue tasks already have reminders sent');
  }

  console.log('\n' + '='.repeat(80));
  console.log('\n💡 Summary:');
  console.log('   - The function only sends ONE reminder per task');
  console.log('   - Once sent, it won\'t send again (tracked in task_reminder_logs)');
  console.log('   - To resend reminders, delete entries from task_reminder_logs table');
}

testOverdueReminders().catch(console.error);
