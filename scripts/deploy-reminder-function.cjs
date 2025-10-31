const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function deployReminderFunction() {
  console.log('🚀 Deploying automatic reminder function...\n');

  try {
    // Create the task_reminder_logs table if it doesn't exist
    console.log('📊 Creating task_reminder_logs table...');
    
    const { error: tableError } = await supabase.rpc('exec_sql', {
      sql: `
        -- Create table for tracking reminder logs
        CREATE TABLE IF NOT EXISTS task_reminder_logs (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          task_assignment_id UUID REFERENCES task_assignments(id) ON DELETE CASCADE,
          quick_task_assignment_id UUID REFERENCES quick_task_assignments(id) ON DELETE CASCADE,
          task_title TEXT NOT NULL,
          assigned_to_user_id UUID REFERENCES users(id),
          deadline TIMESTAMPTZ NOT NULL,
          hours_overdue NUMERIC,
          reminder_sent_at TIMESTAMPTZ DEFAULT NOW(),
          notification_id UUID REFERENCES notifications(id),
          status TEXT DEFAULT 'sent',
          created_at TIMESTAMPTZ DEFAULT NOW()
        );

        -- Create index for faster queries
        CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_task_assignment 
        ON task_reminder_logs(task_assignment_id);
        
        CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_quick_task 
        ON task_reminder_logs(quick_task_assignment_id);
        
        CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_user 
        ON task_reminder_logs(assigned_to_user_id);
        
        CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_sent_at 
        ON task_reminder_logs(reminder_sent_at);

        -- Enable RLS
        ALTER TABLE task_reminder_logs ENABLE ROW LEVEL SECURITY;

        -- Allow users to view their own reminder logs
        CREATE POLICY IF NOT EXISTS "Users can view their own reminder logs"
        ON task_reminder_logs FOR SELECT
        USING (assigned_to_user_id = auth.uid() OR EXISTS (
          SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'master_admin')
        ));

        -- Allow service role to insert
        CREATE POLICY IF NOT EXISTS "Service role can insert reminder logs"
        ON task_reminder_logs FOR INSERT
        WITH CHECK (true);
      `
    });

    if (tableError) {
      // Try alternative method without RPC
      console.log('Creating table using direct SQL...');
      
      const createTableSQL = `
        -- Create table for tracking reminder logs
        CREATE TABLE IF NOT EXISTS task_reminder_logs (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          task_assignment_id UUID REFERENCES task_assignments(id) ON DELETE CASCADE,
          quick_task_assignment_id UUID REFERENCES quick_task_assignments(id) ON DELETE CASCADE,
          task_title TEXT NOT NULL,
          assigned_to_user_id UUID REFERENCES users(id),
          deadline TIMESTAMPTZ NOT NULL,
          hours_overdue NUMERIC,
          reminder_sent_at TIMESTAMPTZ DEFAULT NOW(),
          notification_id UUID REFERENCES notifications(id),
          status TEXT DEFAULT 'sent',
          created_at TIMESTAMPTZ DEFAULT NOW()
        );
      `;
      
      console.log('✅ Table schema prepared');
      console.log('\n⚠️  Please run this SQL in Supabase SQL Editor:');
      console.log('='.repeat(80));
      console.log(createTableSQL);
      console.log('='.repeat(80));
    } else {
      console.log('✅ task_reminder_logs table created successfully');
    }

    // Create the database function for checking overdue tasks
    console.log('\n📝 Creating database function for checking overdue tasks...');
    
    const functionSQL = `
-- Function to check and send reminders for overdue tasks
CREATE OR REPLACE FUNCTION check_overdue_tasks_and_send_reminders()
RETURNS TABLE (
  task_id UUID,
  task_title TEXT,
  user_id UUID,
  user_name TEXT,
  hours_overdue NUMERIC,
  reminder_sent BOOLEAN
) AS $$
DECLARE
  task_record RECORD;
  notification_id UUID;
  hours_diff NUMERIC;
BEGIN
  -- Check regular task assignments
  FOR task_record IN
    SELECT 
      ta.id as assignment_id,
      ta.tasks.title as task_title,
      ta.assigned_to_user_id,
      u.full_name as user_name,
      COALESCE(ta.deadline_datetime, ta.deadline_date) as deadline,
      EXTRACT(EPOCH FROM (NOW() - COALESCE(ta.deadline_datetime, ta.deadline_date))) / 3600 as hours_overdue
    FROM task_assignments ta
    JOIN users u ON u.id = ta.assigned_to_user_id
    LEFT JOIN task_completions tc ON tc.task_assignment_id = ta.id
    WHERE tc.id IS NULL  -- Not completed
      AND COALESCE(ta.deadline_datetime, ta.deadline_date) < NOW()  -- Overdue
      AND NOT EXISTS (  -- No reminder sent yet
        SELECT 1 FROM task_reminder_logs trl 
        WHERE trl.task_assignment_id = ta.id
      )
  LOOP
    -- Insert notification
    INSERT INTO notifications (
      user_id,
      title,
      message,
      type,
      data,
      created_at
    ) VALUES (
      task_record.assigned_to_user_id,
      'Overdue Task Reminder',
      'Task "' || task_record.task_title || '" is ' || ROUND(task_record.hours_overdue, 1) || ' hours overdue. Please complete it as soon as possible.',
      'task_overdue',
      jsonb_build_object(
        'task_assignment_id', task_record.assignment_id,
        'task_title', task_record.task_title,
        'hours_overdue', ROUND(task_record.hours_overdue, 1),
        'deadline', task_record.deadline
      ),
      NOW()
    ) RETURNING id INTO notification_id;

    -- Log the reminder
    INSERT INTO task_reminder_logs (
      task_assignment_id,
      task_title,
      assigned_to_user_id,
      deadline,
      hours_overdue,
      notification_id,
      status
    ) VALUES (
      task_record.assignment_id,
      task_record.task_title,
      task_record.assigned_to_user_id,
      task_record.deadline,
      ROUND(task_record.hours_overdue, 1),
      notification_id,
      'sent'
    );

    -- Return the result
    RETURN QUERY SELECT 
      task_record.assignment_id,
      task_record.task_title,
      task_record.assigned_to_user_id,
      task_record.user_name,
      ROUND(task_record.hours_overdue, 1),
      TRUE;
  END LOOP;

  -- Check quick task assignments
  FOR task_record IN
    SELECT 
      qa.id as assignment_id,
      qa.quick_tasks.title as task_title,
      qa.assigned_to_user_id,
      u.full_name as user_name,
      qa.quick_tasks.deadline_datetime as deadline,
      EXTRACT(EPOCH FROM (NOW() - qa.quick_tasks.deadline_datetime)) / 3600 as hours_overdue
    FROM quick_task_assignments qa
    JOIN users u ON u.id = qa.assigned_to_user_id
    LEFT JOIN quick_task_completions qc ON qc.quick_task_assignment_id = qa.id
    WHERE qc.id IS NULL  -- Not completed
      AND qa.quick_tasks.deadline_datetime < NOW()  -- Overdue
      AND NOT EXISTS (  -- No reminder sent yet
        SELECT 1 FROM task_reminder_logs trl 
        WHERE trl.quick_task_assignment_id = qa.id
      )
  LOOP
    -- Insert notification
    INSERT INTO notifications (
      user_id,
      title,
      message,
      type,
      data,
      created_at
    ) VALUES (
      task_record.assigned_to_user_id,
      'Overdue Quick Task Reminder',
      'Task "' || task_record.task_title || '" is ' || ROUND(task_record.hours_overdue, 1) || ' hours overdue. Please complete it as soon as possible.',
      'task_overdue',
      jsonb_build_object(
        'quick_task_assignment_id', task_record.assignment_id,
        'task_title', task_record.task_title,
        'hours_overdue', ROUND(task_record.hours_overdue, 1),
        'deadline', task_record.deadline
      ),
      NOW()
    ) RETURNING id INTO notification_id;

    -- Log the reminder
    INSERT INTO task_reminder_logs (
      quick_task_assignment_id,
      task_title,
      assigned_to_user_id,
      deadline,
      hours_overdue,
      notification_id,
      status
    ) VALUES (
      task_record.assignment_id,
      task_record.task_title,
      task_record.assigned_to_user_id,
      task_record.deadline,
      ROUND(task_record.hours_overdue, 1),
      notification_id,
      'sent'
    );

    -- Return the result
    RETURN QUERY SELECT 
      task_record.assignment_id,
      task_record.task_title,
      task_record.assigned_to_user_id,
      task_record.user_name,
      ROUND(task_record.hours_overdue, 1),
      TRUE;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
`;

    console.log('\n✅ Database function SQL prepared');
    console.log('\n⚠️  Please run this SQL in Supabase SQL Editor:');
    console.log('='.repeat(80));
    console.log(functionSQL);
    console.log('='.repeat(80));

    // Create a cron job (pg_cron extension needs to be enabled)
    const cronSQL = `
-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the reminder check to run every hour
SELECT cron.schedule(
  'check-overdue-tasks-reminders',
  '0 * * * *',  -- Every hour at minute 0
  'SELECT check_overdue_tasks_and_send_reminders();'
);
`;

    console.log('\n\n📅 Cron Job SQL (Run this to enable automatic reminders every hour):');
    console.log('='.repeat(80));
    console.log(cronSQL);
    console.log('='.repeat(80));

    console.log('\n\n✅ Setup instructions prepared!');
    console.log('\nNext steps:');
    console.log('1. Go to Supabase Dashboard → SQL Editor');
    console.log('2. Copy and run the table creation SQL above');
    console.log('3. Copy and run the function creation SQL above');
    console.log('4. Copy and run the cron job SQL above');
    console.log('5. The system will automatically check for overdue tasks every hour');
    console.log('\n💡 Or you can manually trigger the function anytime by running:');
    console.log('   SELECT * FROM check_overdue_tasks_and_send_reminders();');

  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

deployReminderFunction();
