# How to Delete Data from Notifications Table

This guide explains how to safely delete all data from the notifications table and its related tables in the Aqura database.

## Overview

The notifications table has several dependent tables with foreign key constraints that must be handled in the correct order:

1. `notification_recipients`
2. `notification_read_states`
3. `notification_attachments`
4. `task_reminder_logs`
5. `notifications` (main table)

## Automated Script Method

### Prerequisites

- Node.js installed
- `@supabase/supabase-js` package installed
- Valid Supabase service role key in `frontend/.env`

### Steps

1. **Use the provided script** (`delete-notifications.js`)

```bash
node delete-notifications.js
```

The script will automatically:
- Count existing notifications
- Delete all related records in dependent tables
- Delete all notifications
- Verify the deletion

### Script Features

- ✅ Handles foreign key constraints automatically
- ✅ Deletes records in the correct order
- ✅ Provides detailed progress updates
- ✅ Verifies deletion completion
- ✅ Shows count of deleted records

## Manual SQL Method

If you prefer to delete data directly using SQL, execute the following commands in order:

```sql
-- Step 1: Delete notification recipients
DELETE FROM notification_recipients;

-- Step 2: Delete notification read states
DELETE FROM notification_read_states;

-- Step 3: Delete notification attachments
DELETE FROM notification_attachments;

-- Step 4: Delete task reminder logs
DELETE FROM task_reminder_logs;

-- Step 5: Finally delete all notifications
DELETE FROM notifications;
```

⚠️ **Important**: Execute these commands in the exact order shown to avoid foreign key constraint violations.

## Using Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Copy and paste the SQL commands above
4. Click **Run** to execute

## Verification

After deletion, verify the tables are empty:

```sql
SELECT COUNT(*) FROM notifications;
SELECT COUNT(*) FROM notification_recipients;
SELECT COUNT(*) FROM notification_read_states;
SELECT COUNT(*) FROM notification_attachments;
SELECT COUNT(*) FROM task_reminder_logs;
```

All counts should return `0`.

## Safety Considerations

⚠️ **WARNING**: This operation is irreversible. All notification data will be permanently deleted.

### Before Deletion

- Ensure you have a backup if needed
- Confirm this is the intended action
- Verify you're working in the correct environment

### Alternative: Delete Specific Notifications

To delete only specific notifications instead of all:

```javascript
// Delete notifications older than a specific date
const { error } = await supabase
  .from('notifications')
  .delete()
  .lt('created_at', '2025-01-01');

// Delete notifications of a specific type
const { error } = await supabase
  .from('notifications')
  .delete()
  .eq('type', 'specific_type');
```

## Troubleshooting

### Foreign Key Constraint Error

If you encounter: `violates foreign key constraint`

**Solution**: Ensure you're deleting dependent tables first before the main notifications table.

### Permission Denied Error

If you encounter: `permission denied`

**Solution**: Ensure you're using the service role key, not the anon key.

### Script Not Found Error

If you encounter: `Cannot find module '@supabase/supabase-js'`

**Solution**: Install the required package:

```bash
npm install @supabase/supabase-js
```

## Script Code Reference

The deletion script (`delete-notifications.js`) performs the following operations:

```javascript
// 1. Count notifications
const { count } = await supabase
  .from('notifications')
  .select('*', { count: 'exact', head: true });

// 2. Delete in correct order
await supabase.from('notification_recipients').delete().neq('id', '00000000-0000-0000-0000-000000000000');
await supabase.from('notification_read_states').delete().neq('id', '00000000-0000-0000-0000-000000000000');
await supabase.from('notification_attachments').delete().neq('id', '00000000-0000-0000-0000-000000000000');
await supabase.from('task_reminder_logs').delete().neq('id', '00000000-0000-0000-0000-000000000000');
await supabase.from('notifications').delete().neq('id', '00000000-0000-0000-0000-000000000000');

// 3. Verify deletion
const { count: newCount } = await supabase
  .from('notifications')
  .select('*', { count: 'exact', head: true });
```

## Related Tables Schema

### notifications
- Primary table storing notification records
- Referenced by multiple child tables

### notification_recipients
- Stores which users should receive each notification
- FK: `notification_id` → `notifications.id`

### notification_read_states
- Tracks read/unread status for users
- FK: `notification_id` → `notifications.id`

### notification_attachments
- Stores attached files/media
- FK: `notification_id` → `notifications.id`

### task_reminder_logs
- Logs for task reminders sent via notifications
- FK: `notification_id` → `notifications.id`

## Best Practices

1. **Always backup** before mass deletions
2. **Test in development** environment first
3. **Use the script** for automated, safe deletion
4. **Verify results** after deletion
5. **Document the action** for audit purposes

---

**Last Updated**: November 30, 2025  
**Script Location**: `delete-notifications.js`  
**Database**: Aqura Supabase Instance
