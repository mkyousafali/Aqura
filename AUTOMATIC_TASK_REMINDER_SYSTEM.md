# Automatic Task Reminder System

## Overview
This system automatically sends reminders to users when their tasks become overdue, and provides manual controls to send reminders from the admin interface.

## Features

### 1. Automatic Overdue Reminders
- **Runs periodically** (recommended: every hour via cron)
- **Checks all incomplete tasks** with deadlines
- **Sends notification once** when task becomes overdue
- **Tracks sent reminders** to avoid duplicates

### 2. Manual Reminder Controls (Incomplete Tasks Window)
- **Select All / Deselect All** buttons
- **Send to Selected** - Send reminders to specifically selected tasks
- **Send to All Overdue** - Send reminders to all currently overdue tasks
- **Real-time feedback** - Shows number of reminders sent/failed

### 3. Dashboard Counter
- **Auto Reminder Counter** - Displays in the Incomplete Tasks window header
- Shows total number of automatic reminders sent from the system

## Setup Instructions

### Step 1: Deploy the Edge Function

```bash
# Navigate to your project directory
cd d:\Aqura

# Deploy the function to Supabase
npx supabase functions deploy send-overdue-reminders
```

### Step 2: Set up Cron Job (Supabase Dashboard)

1. Go to your Supabase Dashboard
2. Navigate to **Database** → **Extensions**
3. Enable the `pg_cron` extension
4. Go to **SQL Editor** and run:

```sql
-- Schedule the function to run every hour
SELECT cron.schedule(
  'send-overdue-reminders',
  '0 * * * *', -- Every hour at minute 0
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-overdue-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_ANON_KEY'
    ),
    body := '{}'::jsonb
  ) as request_id;
  $$
);
```

**Replace:**
- `YOUR_PROJECT_REF` with your Supabase project reference
- `YOUR_ANON_KEY` with your Supabase anon key

### Step 3: Verify Setup

1. **Test the function manually:**
```bash
curl -X POST 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-overdue-reminders' \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

2. **Check the logs:**
```bash
npx supabase functions logs send-overdue-reminders
```

3. **Verify in Supabase Dashboard:**
   - Go to **Database** → **Table: notifications**
   - Filter by `type = 'task_overdue_reminder'`
   - Check the `data` column for `auto_sent: true`

## How It Works

### Automatic Reminder Flow

1. **Cron triggers** the Edge Function every hour
2. **Function queries** all incomplete task assignments where:
   - `completed_at` is NULL
   - `deadline_datetime < now()`
3. **For each overdue task:**
   - Checks if reminder already sent (prevents duplicates)
   - Calculates hours overdue
   - Creates notification with type `task_overdue_reminder`
   - Marks as `auto_sent: true` in data field
4. **Returns summary** of reminders sent/skipped

### Manual Reminder Flow

1. **User opens** "Total Incomplete Tasks" window
2. **Sees:**
   - Auto reminder counter in header
   - Selection checkboxes for each task
   - "Send to Selected" and "Send to All Overdue" buttons
3. **Selects tasks** or chooses "Send to All Overdue"
4. **Confirms** the action
5. **System sends** notifications with type `task_reminder`
6. **Shows results** modal with success/failure counts

## Database Schema

### Notifications Table
```sql
CREATE TABLE notifications (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES users(id),
  type text NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  data jsonb,
  read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Index for faster queries
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_auto_sent ON notifications((data->>'auto_sent'));
```

### Notification Types
- `task_overdue_reminder` - Automatic reminders (sent once when overdue)
- `task_reminder` - Manual reminders (sent by admin)

### Notification Data Structure
```json
{
  "task_id": "uuid",
  "assignment_id": "uuid",
  "task_type": "regular" | "quick",
  "deadline": "ISO8601 timestamp",
  "hours_overdue": 5,
  "branch_name": "Branch Name",
  "auto_sent": true  // Only for automatic reminders
}
```

## Cron Schedule Options

```sql
-- Every hour at minute 0
'0 * * * *'

-- Every 30 minutes
'*/30 * * * *'

-- Every 2 hours
'0 */2 * * *'

-- Daily at 9 AM
'0 9 * * *'

-- Monday to Friday at 9 AM and 5 PM
'0 9,17 * * 1-5'
```

## Monitoring

### View Cron Jobs
```sql
SELECT * FROM cron.job;
```

### View Cron Job Runs
```sql
SELECT * FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'send-overdue-reminders')
ORDER BY start_time DESC
LIMIT 10;
```

### Count Auto Reminders Sent
```sql
SELECT COUNT(*) 
FROM notifications 
WHERE type = 'task_overdue_reminder';
```

### View Recent Reminders
```sql
SELECT 
  n.*,
  u.username as recipient_name
FROM notifications n
JOIN users u ON n.user_id = u.id
WHERE n.type IN ('task_overdue_reminder', 'task_reminder')
ORDER BY n.created_at DESC
LIMIT 50;
```

## Troubleshooting

### No reminders being sent?
1. Check if cron job is running:
   ```sql
   SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 5;
   ```
2. Check function logs:
   ```bash
   npx supabase functions logs send-overdue-reminders --tail
   ```
3. Verify overdue tasks exist:
   ```sql
   SELECT COUNT(*) FROM task_assignments
   WHERE completed_at IS NULL
   AND deadline_datetime < NOW();
   ```

### Duplicate reminders?
- Check the function logic - it should skip tasks that already have reminders
- Verify the query in the function filters correctly

### Wrong number in counter?
- Counter shows ALL auto reminders ever sent
- To reset: `DELETE FROM notifications WHERE type = 'task_overdue_reminder';`

## Security Notes

- Edge Function uses **Service Role Key** (has full database access)
- Cron job should use **Anon Key** or **Service Role Key**
- Notifications are only visible to the assigned user (implement RLS)

## Future Enhancements

- [ ] Configurable reminder frequency (1 hour, 6 hours, daily)
- [ ] Multiple reminder escalations
- [ ] Email notifications in addition to in-app
- [ ] SMS reminders for critical tasks
- [ ] Reminder preferences per user
- [ ] Snooze reminder functionality
