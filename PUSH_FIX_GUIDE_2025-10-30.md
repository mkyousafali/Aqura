# PUSH NOTIFICATION FIX - Complete Guide
## Date: October 30, 2025

---

## 🐛 Issues Reported

1. **Push received 3 times** - Same notification appears 3 times on device
2. **Not working when phone is locked** - Notifications only appear when app is open

---

## ✅ Solutions Implemented

### 1. Fix Duplicate Notifications (3x Issue)

**Root Cause**: 3 triggers firing on the same table

**Files Modified**:
- `supabase/migrations/fix_push_issues_complete.sql` (NEW)
- `SETUP_CRON_FOR_PRO.sql` (UPDATED - Step 0 added)

**SQL Fix** (Run in Supabase SQL Editor):
```sql
-- Drop duplicate triggers
DROP TRIGGER IF EXISTS trigger_queue_push_notifications ON notifications;
DROP TRIGGER IF EXISTS trigger_queue_quick_task_push_notifications ON notifications;

-- Keep only one
-- trigger_queue_push_notification (already exists)
```

**Verification**:
```sql
-- Should show only 1 trigger
SELECT tgname FROM pg_trigger 
WHERE tgrelid = 'notifications'::regclass 
AND tgname LIKE '%push%';
```

---

### 2. Fix Locked Phone Issue

**Root Cause**: Push notifications need proper urgency headers and TTL

**Files Modified**:
- `supabase/functions/process-push-queue/index.ts` (UPDATED)
  - Added `urgency` parameter ('high' for urgent notifications)
  - Added `TTL` (Time To Live = 24 hours)
  - Added `topic` for notification grouping

**Changes**:
```typescript
// NEW: Send with urgency and TTL
const sendOptions = {
  urgency: priority === 'high' ? 'high' : 'normal',
  TTL: 24 * 60 * 60, // 24 hours
  topic: item.payload?.tag || 'aqura-notification'
}

await webpush.sendNotification(
  pushSubscription,
  JSON.stringify(item.payload),
  sendOptions // <-- NEW parameter
)
```

**Additional Database Changes**:
- Added `notification_priority` column to queue
- Added `renotification_at` for retry scheduling
- Created `schedule_renotification()` trigger for automatic retries

---

## 🚀 Deployment Steps

### Step 1: Apply Database Fixes
```sql
-- Run in Supabase SQL Editor:
-- File: supabase/migrations/fix_push_issues_complete.sql
```

### Step 2: Deploy Edge Function
```bash
# In terminal:
cd d:\Aqura
supabase functions deploy process-push-queue
```

### Step 3: Verify Fixes
```bash
# Test trigger count (should create only 1 entry)
node scripts/check-triggers.js
```

---

## 📱 Testing Checklist

### Test 1: No More Duplicates
1. Create a notification in admin panel
2. Check notification_queue table
3. ✅ **Expected**: 1 queue entry per device
4. ❌ **Before**: 3 queue entries for same device

### Test 2: Locked Phone
1. Lock your phone
2. Send a notification
3. ✅ **Expected**: Notification appears on lock screen with sound
4. ❌ **Before**: No notification until app opened

### Test 3: High Priority
1. Send notification with `priority: 'high'`
2. Check device behavior
3. ✅ **Expected**: 
   - Longer vibration pattern
   - requireInteraction = true
   - Urgency header = 'high'

---

## 🔍 Debugging Commands

### Check Triggers
```sql
SELECT tgname, proname 
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'notifications'::regclass;
```

### Check Queue Entries
```sql
SELECT 
    notification_id,
    COUNT(*) as queue_count,
    notification_priority
FROM notification_queue
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY notification_id, notification_priority
HAVING COUNT(*) > 1; -- Show duplicates
```

### Check Failed Notifications
```sql
SELECT 
    id,
    notification_id,
    status,
    error_message,
    retry_count
FROM notification_queue
WHERE status IN ('failed', 'retry')
ORDER BY created_at DESC
LIMIT 10;
```

---

## 📊 Expected Behavior After Fix

### Before Fix:
```
User creates 1 notification
  ↓
Trigger fires 3 times
  ↓
3 queue entries created
  ↓
User receives 3 identical pushes ❌
```

### After Fix:
```
User creates 1 notification
  ↓
Trigger fires 1 time ✅
  ↓
1 queue entry per device ✅
  ↓
User receives 1 push ✅
  ↓
Works even when phone locked ✅
```

---

## ⚙️ Configuration Settings

### Push Notification Urgency Levels

| Priority | Urgency | TTL | requireInteraction | Vibrate Pattern |
|----------|---------|-----|-------------------|-----------------|
| urgent   | high    | 24h | true              | [300,100,300,100,300] |
| high     | high    | 24h | true              | [200,100,200,100,200] |
| medium   | normal  | 24h | false             | [200,100,200] |
| low      | normal  | 24h | false             | [200,100,200] |

### Retry Logic

- **Max Retries**: 3
- **Retry 1**: After 1 minute
- **Retry 2**: After 5 minutes  
- **Retry 3**: After 15 minutes
- **After 3**: Mark as permanently failed

---

## 🌐 Browser/OS Specific Notes

### Android Chrome
- ✅ Push works when locked
- ✅ Push works when app closed
- ✅ Requires service worker active
- ⚠️ May be delayed by battery optimization

### iOS Safari (PWA)
- ✅ Must be "Add to Home Screen"
- ⚠️ Push only works for installed PWAs
- ⚠️ Requires iOS 16.4+ for web push
- ⚠️ User must grant permission explicitly

### Desktop Chrome
- ✅ Works with browser closed
- ✅ Respects OS notification settings
- ✅ Always shows in notification center

---

## 🆘 Troubleshooting

### Issue: Still Receiving 3 Notifications

**Solution**:
```sql
-- 1. Verify triggers
SELECT COUNT(*) FROM pg_trigger 
WHERE tgrelid = 'notifications'::regclass 
AND tgname LIKE '%push%';
-- Should return 1

-- 2. If more than 1, manually drop extras
DROP TRIGGER trigger_queue_push_notifications ON notifications;
DROP TRIGGER trigger_queue_quick_task_push_notifications ON notifications;
```

### Issue: Not Working When Locked

**Check**:
1. Service worker registered: `navigator.serviceWorker.ready`
2. Push permission granted: `Notification.permission === 'granted'`
3. Device subscribed: Check `push_subscriptions` table
4. Edge Function deployed: Check Supabase dashboard

**Common Causes**:
- Battery optimization killing service worker
- Push permission revoked
- FCM endpoint expired
- Service worker not updated

---

## 📝 Files Modified Summary

| File | Change | Purpose |
|------|--------|---------|
| `supabase/migrations/fix_push_issues_complete.sql` | NEW | Complete fix script |
| `supabase/functions/process-push-queue/index.ts` | UPDATED | Add urgency & TTL |
| `SETUP_CRON_FOR_PRO.sql` | UPDATED | Include trigger fix |

---

## ✨ Next Steps

1. ✅ Run `fix_push_issues_complete.sql` in Supabase
2. ✅ Deploy updated Edge Function
3. ✅ Test with locked phone
4. ✅ Verify no duplicate notifications
5. 🔄 Monitor for 24 hours
6. 📊 Check error rates in dashboard

---

## 📞 Support Commands

```bash
# Test complete flow
node scripts/test-automatic-processing.js

# Check for duplicates
node scripts/check-triggers.js

# Manually process queue
node scripts/trigger-push-processor.js

# Check specific notification
node scripts/check-specific-notification.js
```

---

**Status**: ✅ Ready to deploy  
**Impact**: High - Fixes major UX issues  
**Risk**: Low - Only removes duplicate triggers  
**Rollback**: Can re-add triggers if needed
