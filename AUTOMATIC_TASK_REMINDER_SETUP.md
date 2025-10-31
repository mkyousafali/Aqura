# Automatic Task Reminder System - Setup Guide

## 📋 Overview
This system automatically sends notifications to users when their tasks become overdue.

## 🚀 Quick Setup (5 minutes)

### Step 1: Enable pg_cron Extension
1. Open your Supabase Dashboard
2. Go to **Database** → **Extensions**
3. Search for `pg_cron`
4. Click **Enable** next to pg_cron

### Step 2: Run the SQL Migration
1. Go to **SQL Editor** in Supabase Dashboard
2. Click **New Query**
3. Copy the entire content from `migrations/setup-automatic-task-reminders.sql`
4. Paste it into the SQL editor
5. Click **Run** or press `Ctrl+Enter`

### Step 3: Verify Setup
Run this query to check if everything is working:
```sql
-- Check if cron job is scheduled
SELECT * FROM cron.job WHERE jobname = 'check-overdue-tasks-reminders';

-- View the function
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'check_overdue_tasks_and_send_reminders';

-- Check reminder logs table
SELECT * FROM pg_tables WHERE tablename = 'task_reminder_logs';
```

## ✅ What This Does

### Automatic Reminders (Every Hour)
- ⏰ Runs automatically every hour (at minute 0)
- 🔍 Checks all incomplete tasks that are past their deadline
- 📢 Sends ONE notification per overdue task (never duplicates)
- 📊 Logs every reminder sent in `task_reminder_logs` table

### Manual Testing
You can manually trigger the reminder check anytime:
```sql
SELECT * FROM check_overdue_tasks_and_send_reminders();
```

### View Statistics
Check how many reminders have been sent:
```sql
-- All users
SELECT * FROM get_reminder_statistics();

-- Specific user
SELECT * FROM get_reminder_statistics('user-uuid-here', 30);
```

### View Reminder History
```sql
-- Recent reminders
SELECT * FROM task_reminder_logs 
ORDER BY reminder_sent_at DESC 
LIMIT 20;

-- Reminders for a specific user
SELECT * FROM task_reminder_logs 
WHERE assigned_to_user_id = 'user-uuid-here'
ORDER BY reminder_sent_at DESC;

-- Count reminders by day
SELECT 
  DATE(reminder_sent_at) as date,
  COUNT(*) as reminders_sent,
  AVG(hours_overdue) as avg_hours_overdue
FROM task_reminder_logs
GROUP BY DATE(reminder_sent_at)
ORDER BY date DESC;
```

## 🎯 Features

### 1. Smart Reminder Logic
- ✅ Only sends reminder once per task
- ✅ Checks both regular tasks and quick tasks
- ✅ Calculates exact hours overdue
- ✅ Includes task details in notification

### 2. Notification Format
**Title:** ⚠️ Overdue Task Reminder

**Message:** Task "Task Name" is X hours overdue. Please complete it as soon as possible.

**Data includes:**
- Task assignment ID
- Task title
- Hours overdue
- Deadline
- Reminder type (automatic)

### 3. Database Logging
Every reminder is logged with:
- Task information
- User who received it
- Time sent
- Hours overdue
- Linked notification ID
- Status (sent/failed)

## 🔧 Troubleshooting

### Cron Job Not Running?
1. Verify pg_cron extension is enabled
2. Check cron job exists:
   ```sql
   SELECT * FROM cron.job;
   ```
3. Check cron logs:
   ```sql
   SELECT * FROM cron.job_run_details 
   WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'check-overdue-tasks-reminders')
   ORDER BY start_time DESC 
   LIMIT 10;
   ```

### No Reminders Being Sent?
1. Check if there are actually overdue tasks:
   ```sql
   SELECT COUNT(*) FROM task_assignments ta
   LEFT JOIN task_completions tc ON tc.task_assignment_id = ta.id
   WHERE tc.id IS NULL 
     AND COALESCE(ta.deadline_datetime, ta.deadline_date) < NOW();
   ```

2. Check if reminders were already sent:
   ```sql
   SELECT * FROM task_reminder_logs ORDER BY reminder_sent_at DESC LIMIT 5;
   ```

3. Manually run the function to see results:
   ```sql
   SELECT * FROM check_overdue_tasks_and_send_reminders();
   ```

### Modify Cron Schedule
To change when reminders are sent:
```sql
-- Remove existing schedule
SELECT cron.unschedule('check-overdue-tasks-reminders');

-- Every 30 minutes
SELECT cron.schedule('check-overdue-tasks-reminders', '*/30 * * * *', 
  $$SELECT check_overdue_tasks_and_send_reminders();$$);

-- Every 4 hours
SELECT cron.schedule('check-overdue-tasks-reminders', '0 */4 * * *', 
  $$SELECT check_overdue_tasks_and_send_reminders();$$);

-- Daily at 9 AM
SELECT cron.schedule('check-overdue-tasks-reminders', '0 9 * * *', 
  $$SELECT check_overdue_tasks_and_send_reminders();$$);
```

## 📊 Dashboard Integration

The frontend now includes:
- ✅ Manual reminder buttons (send to all or selected tasks)
- ✅ Reminder statistics modal
- ✅ Visual indicators for overdue tasks
- ✅ Selection checkboxes for bulk operations

## 🔐 Security

- ✅ Row Level Security (RLS) enabled
- ✅ Users can only see their own reminders
- ✅ Admins can see all reminders
- ✅ Function runs with SECURITY DEFINER
- ✅ Service role can insert reminders

## 📈 Performance

- Processes max 100 tasks per run (prevents timeout)
- Indexed queries for fast lookups
- Error handling prevents one failure from stopping others
- Logs all operations for debugging

## 🎉 Success!

Your automatic task reminder system is now active and will:
1. ⏰ Check every hour for overdue tasks
2. 📢 Send notifications automatically
3. 📊 Track all reminders
4. 🔔 Keep users informed about their overdue tasks

Users will receive notifications in their app notification center when tasks become overdue!
