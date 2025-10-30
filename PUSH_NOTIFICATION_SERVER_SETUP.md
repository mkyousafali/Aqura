# Server-Side Push Notification Setup

## Overview
Push notifications are now processed **server-side** using Supabase Edge Functions and pg_cron. This ensures notifications are delivered even when:
- ✅ Phone is locked
- ✅ App is closed
- ✅ User is logged out
- ✅ Device is offline (delivered when back online)

## Architecture

```
Notification Created
    ↓
Database Trigger → queue_push_notification()
    ↓
notification_queue table (pending entries)
    ↓
pg_cron (every 30 seconds)
    ↓
Edge Function: process-push-queue
    ↓
Web Push Protocol (VAPID)
    ↓
Browser/OS Push Service
    ↓
Service Worker receives push
    ↓
Notification shows on device!
```

## Components

### 1. Database Migration
**File:** `supabase/migrations/fix_queue_push_notification_function.sql`
- Creates `queue_push_notification()` function
- Sets up database triggers
- Populates `notification_queue` table

### 2. Edge Function
**File:** `supabase/functions/process-push-queue/index.ts`
- Processes pending queue entries
- Sends Web Push notifications using VAPID
- Handles retries (3 attempts with exponential backoff)
- Updates delivery status

### 3. Cron Job Setup
**File:** `supabase/migrations/setup_push_notification_cron.sql`
- Enables pg_cron extension
- Creates cron job to run every minute
- Calls Edge Function automatically

### 4. Client Changes
**File:** `frontend/src/lib/utils/pushNotificationProcessor.ts`
- Client-side processing **DISABLED**
- Server now handles all push processing
- Client only registers subscriptions

## Deployment Steps

### 1. Apply Database Migrations
```bash
cd d:\Aqura
supabase db push
```

### 2. Deploy Edge Function
```bash
supabase functions deploy process-push-queue
```

### 3. Set Environment Variables
In Supabase Dashboard → Project Settings → Edge Functions:
```
VAPID_PRIVATE_KEY=hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8
```

### 4. Enable pg_cron
In Supabase Dashboard → Database → Extensions:
- Enable `pg_cron`
- Enable `http` (for calling Edge Functions)

### 5. Configure Cron Job
The migration will auto-create the cron job, but you can verify:
```sql
SELECT * FROM cron.job;
```

## Testing

### Test Push Notification Flow
```bash
# 1. Create a test notification in the app
# 2. Check queue was created:
SELECT * FROM notification_queue WHERE status = 'pending';

# 3. Trigger Edge Function manually:
curl -X POST https://vmypotfsyrvuublyddyt.supabase.co/functions/v1/process-push-queue \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"

# 4. Verify notification was sent:
SELECT * FROM notification_queue WHERE status = 'sent';
```

### Monitor Cron Jobs
```sql
-- View cron job history
SELECT * FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'process-push-notifications-minute')
ORDER BY start_time DESC 
LIMIT 10;
```

## Configuration

### Retry Logic
- **Attempt 1:** Immediate
- **Attempt 2:** After 1 minute
- **Attempt 3:** After 5 minutes
- **After 3 failures:** Marked as permanently failed

### Cron Schedule
- **Frequency:** Every 1 minute (can be increased to 30 seconds if needed)
- **Batch Size:** 50 notifications per run
- **Timeout:** 10 seconds per batch

### VAPID Keys
- **Public Key:** Already configured in client
- **Private Key:** Stored in Edge Function environment variables
- **Email:** support@aqura.com (update in Edge Function if needed)

## Troubleshooting

### Notifications Not Arriving on Locked Phone

**Check 1: Verify Edge Function is Running**
```bash
supabase functions logs process-push-queue --tail
```

**Check 2: Verify Cron Job is Active**
```sql
SELECT * FROM cron.job WHERE jobname LIKE 'process-push%';
```

**Check 3: Check Queue Status**
```sql
SELECT status, COUNT(*) 
FROM notification_queue 
GROUP BY status;
```

### Common Issues

**Issue:** "Function not found"
- **Solution:** Deploy Edge Function: `supabase functions deploy process-push-queue`

**Issue:** "pg_cron not enabled"
- **Solution:** Enable in Supabase Dashboard → Database → Extensions

**Issue:** "Unauthorized"
- **Solution:** Check VAPID_PRIVATE_KEY is set in Edge Function env vars

**Issue:** "Notifications still processed client-side"
- **Solution:** Clear browser cache and reload app

## Performance

- **Latency:** < 1 minute from notification creation to delivery
- **Throughput:** 50 notifications per minute (3000/hour)
- **Reliability:** 3 automatic retries with exponential backoff
- **Scalability:** Increase batch size or cron frequency as needed

## Migration from Client-Side

The old client-side processor is now disabled. To re-enable for testing:
1. Edit `pushNotificationProcessor.ts`
2. Remove the `return;` statement in `start()` method
3. Uncomment the legacy code

**NOT RECOMMENDED:** Server-side processing is more reliable and works when devices are locked.

## Next Steps

1. ✅ Apply migrations
2. ✅ Deploy Edge Function  
3. ✅ Enable pg_cron
4. ✅ Test with locked phone
5. ⏭️ Monitor logs for first 24 hours
6. ⏭️ Adjust cron frequency if needed
7. ⏭️ Set up alerting for failed notifications

## Support

For issues or questions:
- Check Edge Function logs: `supabase functions logs process-push-queue`
- Check cron job history: See SQL query above
- Check notification_queue table for stuck entries
