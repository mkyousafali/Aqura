# Recurring Schedule Notification System

## Overview
The system automatically sends approval notifications to designated approvers **2 days before** a recurring expense is scheduled to occur.

## How It Works

### 1. Recurring Schedule Creation
When users create a recurring expense schedule without an approved requisition:
- Schedule is saved to `non_approved_payment_scheduler` table
- Includes recurring type (daily, weekly, monthly, yearly, etc.)
- Includes recurring metadata (dates, frequencies, etc.)
- Approver is assigned to the schedule

### 2. Automated Notification Check
A scheduled job runs daily to check for upcoming recurring expenses:
- Calculates which schedules will occur in **2 days**
- Sends notification to the assigned approver
- Logs execution history

### 3. Notification Delivery
Approvers receive notifications via:
- In-app notification center
- Push notifications (if enabled)
- Email (if configured)

## Implementation

### Database Functions

#### `check_and_notify_recurring_schedules()`
Core function that:
- Queries all active recurring schedules
- Calculates next occurrence date based on recurring type
- Sends notifications for schedules occurring in 2 days
- Returns list of notifications sent

#### `check_and_notify_recurring_schedules_with_logging()`
Wrapper function that:
- Calls the core notification function
- Logs execution to `recurring_schedule_check_log` table
- Returns summary statistics

### Recurring Types Supported

1. **Daily**: Every day until specified end date
2. **Weekly**: Specific weekday until specified end date
3. **Monthly (Date)**: Start/middle/end of month until specified month
4. **Monthly (Day)**: Specific day of month until specified month
5. **Yearly**: Specific month/day until specified year
6. **Half-Yearly**: Specific month/day every 6 months
7. **Quarterly**: Specific month/day every 3 months
8. **Custom**: User-defined specific dates

### Notification Timing

- **Notification sent**: 2 days before occurrence
- **Example**: 
  - If expense occurs on October 30th
  - Notification sent on October 28th at 6:00 AM

## Setup Options

### Option 1: GitHub Actions (Recommended)
The repository includes a GitHub Actions workflow that runs daily:

**File**: `.github/workflows/check-recurring-schedules.yml`

**Setup**:
1. Add secrets to GitHub repository:
   - `PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
2. Workflow runs automatically at 6:00 AM UTC daily
3. Can be manually triggered from Actions tab

### Option 2: Manual Script Execution
Run the Node.js script manually or via external cron:

```bash
node scripts/check-recurring-schedules.cjs
```

**External Cron Services**:
- Vercel Cron
- AWS EventBridge
- Google Cloud Scheduler
- Heroku Scheduler

### Option 3: Supabase pg_cron (If Available)
If pg_cron extension is enabled:

```sql
SELECT cron.schedule(
    'check-recurring-schedules',
    '0 6 * * *',
    $$SELECT check_and_notify_recurring_schedules_with_logging();$$
);
```

## Monitoring

### Check Execution Logs
```sql
SELECT * FROM recurring_schedule_check_log
ORDER BY created_at DESC
LIMIT 10;
```

### Manual Test Run
```sql
SELECT * FROM check_and_notify_recurring_schedules_with_logging();
```

### View Sent Notifications
```sql
SELECT * FROM notifications
WHERE metadata->>'schedule_type' = 'recurring'
ORDER BY created_at DESC
LIMIT 20;
```

## Troubleshooting

### No Notifications Being Sent
1. Check if script/workflow is running:
   - GitHub Actions: Check workflow runs
   - Manual: Check execution logs
2. Verify schedules exist:
   ```sql
   SELECT * FROM expense_scheduler
   WHERE schedule_type = 'recurring'
   AND status = 'pending';
   ```
3. Check notification function:
   ```sql
   SELECT * FROM check_and_notify_recurring_schedules();
   ```

### Notifications Sent Multiple Times
- Each daily run should only send notifications once per schedule
- Check `recurring_schedule_check_log` for duplicate runs
- Ensure only one cron job is active

### Wrong Notification Timing
- Verify system timezone settings
- Check cron schedule timing
- Adjust GitHub Actions cron expression if needed

## Database Tables

### `expense_scheduler`
Stores all expense schedules including recurring ones:
- `schedule_type`: 'recurring' for recurring schedules
- `recurring_type`: Type of recurrence
- `recurring_metadata`: JSONB with recurrence details
- `approver_id`: User to notify

### `recurring_schedule_check_log`
Logs execution history:
- `check_date`: Date of check
- `schedules_checked`: Number of schedules processed
- `notifications_sent`: Number of notifications sent
- `created_at`: Timestamp of execution

### `notifications`
Stores all notifications sent:
- Includes metadata about schedule and occurrence date
- Used by notification system to display to users

## Future Enhancements

1. **Configurable notification timing**: Allow users to set custom advance notice (e.g., 1, 2, or 3 days)
2. **Multiple notifications**: Send reminder on multiple days before occurrence
3. **SMS notifications**: Add SMS delivery option
4. **Notification preferences**: Let users choose notification channels
5. **Escalation**: Auto-escalate if no action taken by occurrence date

## Related Files

- Migration: `supabase/migrations/073_create_recurring_schedule_notification_function.sql`
- Cron Setup: `supabase/migrations/074_setup_recurring_schedule_cron_job.sql`
- Script: `scripts/check-recurring-schedules.cjs`
- Workflow: `.github/workflows/check-recurring-schedules.yml`
- Component: `frontend/src/lib/components/admin/finance/RecurringExpenseScheduler.svelte`
