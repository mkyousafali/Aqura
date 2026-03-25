# 🚀 Quick Start: Deploy & Rescue Stuck Broadcast

## 5-Minute Checklist (Do This Right Now)

### ✅ Step 1: Deploy Speed Optimization
```bash
cd c:\Users\mkyou\Aqura

# Check changes
git diff supabase/functions/whatsapp-manage/index.ts

# Deploy
git add supabase/functions/whatsapp-manage/index.ts
git commit -m "🚀 Optimize broadcast speed: 15/100/35/3 (4-5x faster)"
git push
```

**What this does**:
- All new broadcasts now 4-5x faster
- Takes effect automatically
- Current broadcast still stuck (needs queue rescue)

---

### ✅ Step 2: Setup Queue (If Rescuing Stuck Broadcast)

#### 2a. Create Queue Tables (Supabase Console)
```bash
# Option 1: Via psql
psql -h your_supabase_host -U postgres -d postgres < scripts/setup-broadcast-queue-db.sql

# Option 2: Supabase Dashboard
# - Go to SQL Editor
# - Copy contents of: scripts/setup-broadcast-queue-db.sql
# - Run
```

#### 2b. Migrate Stuck Broadcast
```bash
psql -h your_supabase_host -U postgres -d postgres < scripts/migrate-stuck-broadcast.sql

# Or in Supabase Dashboard SQL Editor:
SELECT id, name, status FROM wa_broadcasts WHERE name = 'salaryoffermonththree';
```

**Expected Result**:
```
id: 12345-abc
name: salaryoffermonththree  
status: queued (changed from "sending")
```

---

### ✅ Step 3: Start Queue Worker

#### Terminal 1: Start the worker
```bash
cd c:\Users\mkyou\Aqura
node scripts/broadcast-queue-worker.js
```

**Expected Output**:
```
🚀 Broadcast Queue Worker worker-abc123 started
📋 Found 1 pending jobs at 2:34:56 PM
📨 Processing job 12345-ab - Template: slymthreetsix
  ✅ Batch 1: 50 sent (50 total)
  ✅ Batch 2: 50 sent (100 total)
  ✅ Batch 3: 50 sent (150 total)
...continues...
✅ Job 12345-ab completed | Sent: 19003, Failed: 0
```

#### Terminal 2: Monitor logs (optional)
```bash
tail -f broadcast-worker.log
```

---

## Expected Timeline

```
T+0 min:  Deploy speed fix (instant)
T+1 min:  Setup queue DB (1-2 minutes)
T+2 min:  Run migration SQL (1 minute)
T+3 min:  Start queue worker
T+6 min:  19,003 pending recipients processed ✅
T+10 min: All done! Broadcast now shows 21,500+ delivered
```

---

## How to Know It's Working

### In Terminal:
```
✅ "Batch N: X sent (N total)" - Messages going out
✅ "completed | Sent: 19003" - All done
```

### In Supabase:
```sql
SELECT status, sent_count, failed_count, completed_at 
FROM wa_broadcasts 
WHERE name = 'salaryoffermonththree';

-- Expected:
-- status: completed
-- sent_count: 21339  (original 2336 + queue 19003)
-- failed_count: 0
-- completed_at: 2026-03-25 14:42:00 (recent time)
```

### In UI (Aqura App):
```
Broadcast: salaryoffermonththree
Status: ✅ COMPLETED
Sent: 21,339 (99%)
Delivered: 1,823+
Failed: 0
Date: Today 25-03-2026
```

---

## If Something Goes Wrong

### Queue Worker Won't Start
```bash
# Check Node.js
node --version  # Should be v14+

# Check Supabase env vars
echo $SUPABASE_URL
echo $SUPABASE_SERVICE_ROLE_KEY

# Run with full debug
node scripts/broadcast-queue-worker.js --debug
```

### Queue Job Stuck
```sql
-- Check what's happening
SELECT * FROM broadcast_queue_jobs WHERE broadcast_id = '12345';

-- Check locks
SELECT * FROM broadcast_queue_worker_lock;

-- Force unlock if needed
DELETE FROM broadcast_queue_worker_lock WHERE job_id = '...';

-- Manually reset job
UPDATE broadcast_queue_jobs 
SET status = 'pending', worker_id = NULL 
WHERE id = '...';
```

### Still Seeing "SENDING"?
```sql
-- Verify migration ran
SELECT * FROM broadcast_queue_jobs;

-- Verify recipient status changed
SELECT status, COUNT(*) FROM wa_broadcast_recipients 
WHERE broadcast_id = '12345' GROUP BY status;
```

---

## Done ✅

Once complete:
- [ ] Deployment pushed
- [ ] Queue DB created
- [ ] Stuck broadcast migrated
- [ ] Queue worker processed 19,003
- [ ] Broadcast shows "COMPLETED"
- [ ] All recipients reached today

🎉 **Maximum speed without stuck!**
