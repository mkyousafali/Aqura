# 🗄️ Push Notification Removal - SQL Commands

**IMPORTANT:** Execute in this EXACT order to handle dependencies properly

---

## ⚠️ PRE-EXECUTION VERIFICATION

Run these BEFORE executing the deletion commands:

```sql
-- Check database for push-related objects
SELECT routine_name FROM information_schema.routines 
WHERE routine_name LIKE '%push%' OR routine_name LIKE '%queue%'
ORDER BY routine_name;

-- Count push subscriptions (0 is OK to delete)
SELECT COUNT(*) as push_subscription_count FROM push_subscriptions;

-- Count notification queue items (0 is OK to delete)
SELECT COUNT(*) as notification_queue_count FROM notification_queue;

-- Verify notifications table exists and has data
SELECT COUNT(*) as notification_count FROM notifications;
SELECT COUNT(*) as recipient_count FROM notification_recipients;
```

---

## 🧹 PHASE 1: DROP TRIGGERS (Safe First)

Execute these before dropping functions:

```sql
-- Drop triggers that call push functions
DROP TRIGGER IF EXISTS queue_push_notification_trigger ON notifications;
DROP TRIGGER IF EXISTS trigger_requeue_failed_notifications ON notification_queue;
DROP TRIGGER IF EXISTS trigger_queue_push_notifications ON notifications;
```

---

## 🗑️ PHASE 2: DROP DATABASE FUNCTIONS

Execute in this order (functions may depend on each other):

```sql
-- Drop processors first (may call other functions)
DROP FUNCTION IF EXISTS process_push_notification_queue();

-- Drop helpers second
DROP FUNCTION IF EXISTS cleanup_old_push_subscriptions();
DROP FUNCTION IF EXISTS cleanup_orphaned_notifications();
DROP FUNCTION IF EXISTS schedule_renotification();
DROP FUNCTION IF EXISTS update_push_subscriptions_updated_at();

-- Drop main functions last
DROP FUNCTION IF EXISTS trigger_queue_push_notifications();
DROP FUNCTION IF EXISTS queue_push_notification_trigger();
DROP FUNCTION IF EXISTS queue_push_notification(uuid);
DROP FUNCTION IF EXISTS register_push_subscription(
    uuid,        -- user_id
    text,        -- device_id
    text,        -- endpoint
    text,        -- p256dh
    text,        -- auth
    text,        -- device_type
    text,        -- browser_name
    text         -- user_agent
);

-- Verify all push functions are gone
SELECT routine_name FROM information_schema.routines 
WHERE routine_name LIKE '%push%' OR routine_name LIKE '%queue%';
-- Should return empty result ✓
```

---

## 🗄️ PHASE 3: REMOVE RLS POLICIES

Execute BEFORE dropping tables (optional - will be dropped with table):

```sql
-- Remove policies from notification_queue
DROP POLICY IF EXISTS "anon_full_access" ON notification_queue;
DROP POLICY IF EXISTS "authenticated_full_access" ON notification_queue;
DROP POLICY IF EXISTS "realtime_subscription" ON notification_queue;
DROP POLICY IF EXISTS "user_can_view_own_queue" ON notification_queue;
DROP POLICY IF EXISTS "user_can_manage_own_queue" ON notification_queue;

-- Remove policies from push_subscriptions
DROP POLICY IF EXISTS "anon_full_access" ON push_subscriptions;
DROP POLICY IF EXISTS "authenticated_full_access" ON push_subscriptions;
DROP POLICY IF EXISTS "realtime_subscription" ON push_subscriptions;
DROP POLICY IF EXISTS "user_can_view_own_subscriptions" ON push_subscriptions;
DROP POLICY IF EXISTS "user_can_manage_own_subscriptions" ON push_subscriptions;
```

---

## 💾 PHASE 4: BACKUP TABLE STRUCTURE (Optional)

If you want to keep a record of table structure:

```sql
-- Export notification_queue structure to CSV (copy output)
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'notification_queue'
ORDER BY ordinal_position;

-- Export push_subscriptions structure to CSV (copy output)
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'push_subscriptions'
ORDER BY ordinal_position;
```

---

## 🔥 PHASE 5: DROP TABLES (Point of No Return)

⚠️ **CRITICAL:** This permanently deletes data  
✅ **SAFE:** Only drops push-related tables, not notification data

```sql
-- Step 1: Backup table record (optional)
-- SELECT COUNT(*) FROM notification_queue;
-- SELECT COUNT(*) FROM push_subscriptions;

-- Step 2: Drop tables in correct order (notification_queue references push_subscriptions)
DROP TABLE IF EXISTS notification_queue CASCADE;

-- Step 3: Drop push subscriptions
DROP TABLE IF EXISTS push_subscriptions CASCADE;

-- Step 4: Verify tables are gone
SELECT table_name FROM information_schema.tables
WHERE table_name IN ('notification_queue', 'push_subscriptions');
-- Should return empty result ✓
```

---

## ✅ VERIFICATION PHASE 6: CONFIRM EVERYTHING STILL WORKS

```sql
-- Verify notification system still works
SELECT COUNT(*) as notification_count FROM notifications;

-- Verify recipients tracking still works
SELECT COUNT(*) as recipient_count FROM notification_recipients;

-- Verify read states still work
SELECT COUNT(*) as read_state_count FROM notification_read_states;

-- Verify attachments still work
SELECT COUNT(*) as attachment_count FROM notification_attachments;

-- Verify task reminders still work
SELECT COUNT(*) as reminder_count FROM task_reminder_logs;

-- Check for orphaned records (shouldn't be any)
SELECT COUNT(*) as orphaned_recipients 
FROM notification_recipients 
WHERE notification_id NOT IN (SELECT id FROM notifications);

-- Verify key functions still exist
SELECT routine_name FROM information_schema.routines 
WHERE routine_name LIKE '%notification%'
  AND routine_name NOT LIKE '%push%'
ORDER BY routine_name;
-- Should show: create_notification_simple, create_notification_recipients, etc.
```

---

## 🎯 COMPLETE REMOVAL SCRIPT (All at Once)

⚠️ **Only use after individual steps verified!**

```sql
-- Complete removal in correct order
-- Phase 1: Triggers
DROP TRIGGER IF EXISTS queue_push_notification_trigger ON notifications;
DROP TRIGGER IF EXISTS trigger_requeue_failed_notifications ON notification_queue;
DROP TRIGGER IF EXISTS trigger_queue_push_notifications ON notifications;

-- Phase 2: Functions
DROP FUNCTION IF EXISTS process_push_notification_queue();
DROP FUNCTION IF EXISTS cleanup_old_push_subscriptions();
DROP FUNCTION IF EXISTS cleanup_orphaned_notifications();
DROP FUNCTION IF EXISTS schedule_renotification();
DROP FUNCTION IF EXISTS update_push_subscriptions_updated_at();
DROP FUNCTION IF EXISTS trigger_queue_push_notifications();
DROP FUNCTION IF EXISTS queue_push_notification_trigger();
DROP FUNCTION IF EXISTS queue_push_notification(uuid);
DROP FUNCTION IF EXISTS register_push_subscription(uuid, text, text, text, text, text, text, text);

-- Phase 3: Tables (CASCADE removes associated policies)
DROP TABLE IF EXISTS notification_queue CASCADE;
DROP TABLE IF EXISTS push_subscriptions CASCADE;

-- Phase 4: Final verification
SELECT 'Verification' as step;
SELECT COUNT(*) as remaining_push_objects FROM information_schema.routines 
WHERE routine_name LIKE '%push%';
-- Should return 0 ✓
```

---

## 🔍 TROUBLESHOOTING

### If DROP fails with "cannot drop because other objects depend on it"

```sql
-- Find what's blocking the drop
SELECT constraint_name, table_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name IN ('notification_queue', 'push_subscriptions');

-- Find foreign keys
SELECT constraint_name, table_name, column_name, referenced_table_name
FROM information_schema.key_column_usage
WHERE table_name IN ('notification_queue', 'push_subscriptions');

-- Force drop with CASCADE
DROP TABLE notification_queue CASCADE;
DROP TABLE push_subscriptions CASCADE;
```

### If function DROP fails

```sql
-- List all variations of the function
SELECT routine_name, routine_type, data_type
FROM information_schema.routines
WHERE routine_name = 'queue_push_notification';

-- Try dropping each variation
DROP FUNCTION IF EXISTS queue_push_notification() CASCADE;
DROP FUNCTION IF EXISTS queue_push_notification(uuid) CASCADE;
```

### Verify no push references remain

```sql
-- Search for any remaining push-related objects
SELECT 'Functions' as object_type, routine_name as name
FROM information_schema.routines
WHERE routine_name LIKE '%push%' OR routine_name LIKE '%subscription%'

UNION ALL

SELECT 'Tables' as object_type, table_name as name
FROM information_schema.tables
WHERE table_name LIKE '%push%' OR table_name LIKE '%subscription%';

-- Should return empty result ✓
```

---

## 📊 DATA SIZE RECOVERY

After successful removal, reclaim storage:

```sql
-- VACUUM removes dead rows and reclaims space
VACUUM ANALYZE;

-- Check current database size
SELECT 
  schemaname,
  SUM(pg_total_relation_size(schemaname||'.'||tablename))::bigint as size_bytes
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
GROUP BY schemaname
ORDER BY size_bytes DESC;

-- Specific table sizes (before and after)
SELECT 
  tablename,
  pg_size_pretty(pg_total_relation_size(tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(tablename) DESC;
```

---

## 🚀 EXECUTION CHECKLIST

### Before Execution:
- [ ] Database backup created
- [ ] Git feature branch created
- [ ] All frontend code removed
- [ ] App tested in development
- [ ] No push imports remain

### Phase 1 (Triggers):
- [ ] DROP TRIGGER queue_push_notification_trigger
- [ ] DROP TRIGGER trigger_requeue_failed_notifications
- [ ] DROP TRIGGER trigger_queue_push_notifications

### Phase 2 (Functions):
- [ ] All 9 functions dropped successfully
- [ ] No errors during execution
- [ ] Verified with information_schema query

### Phase 3 (Tables):
- [ ] notification_queue dropped
- [ ] push_subscriptions dropped
- [ ] Cascade removed all policies
- [ ] ~14.3 MB storage recovered

### Phase 4 (Verification):
- [ ] No push objects remain
- [ ] Notifications table intact
- [ ] Recipients table intact
- [ ] Read states table intact
- [ ] Attachments table intact
- [ ] Task reminders intact

### After Execution:
- [ ] Git commit created
- [ ] Feature branch merged
- [ ] Deployment tested
- [ ] Production verified

---

## ✅ SUCCESS CRITERIA

After removal, verify:

```
✅ No push-related functions exist
✅ No push-related tables exist
✅ notification_queue table gone
✅ push_subscriptions table gone
✅ notifications table still works
✅ App boots without errors
✅ Notification Center displays notifications
✅ Sound system works
✅ Toast notifications work
✅ Database reports no errors
```

---

**Last Updated:** December 8, 2025  
**SQL Version:** PostgreSQL 12+  
**Supabase Compatible:** Yes ✅
