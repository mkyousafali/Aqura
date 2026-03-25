# WhatsApp Broadcast Timeout Issues - Analysis & Fixes

## Current State
The broadcast system is stuck with status "SENDING" with no progress. The screenshot shows "195 failed" and metrics stalling.

## Root Causes Identified

### 1. **Database Load Inefficiency**
**Location**: [`supabase/functions/whatsapp-manage/index.ts:841-859`](supabase/functions/whatsapp-manage/index.ts#L841-L859)

**Issue**: Loading 5,000 recipients at a time from DB can timeout if:
- Table has millions of pending records
- Database is under load
- Network latency to Supabase is high

**Current Code**:
```typescript
while (true) {
  const { data: dbRecipients, error: dbErr } = await supabase
    .from("wa_broadcast_recipients")
    .select("id, phone_number")
    .eq("broadcast_id", broadcast_id)
    .eq("status", "pending")
    .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
  
  if (dbErr) throw new Error("Failed to load recipients: " + dbErr.message);
  const batch = (dbRecipients || []).map((r: any) => ({ id: r.id, phone: r.phone_number }));
  recipients.push(...batch);
  if (batch.length < PAGE_SIZE) break;
  page++;
}
```

**Fix**: Add timeout wrapper & early exit if we've already spent time loading:
- Set 10s max time for recipient loading
- If timeout, start with whatever we've loaded
- Remaining recipients will be picked up in auto-continue

### 2. **Auto-Continue Self-Invocation Failure**
**Location**: [`supabase/functions/whatsapp-manage/index.ts:173`](supabase/functions/whatsapp-manage/index.ts#L173)

**Issue**: 10s timeout on edge function invocation is too short and doesn't retry on failure:
```typescript
signal: AbortSignal.timeout(10000), // 10s timeout
```

**Problem**: If the function response takes >10s, the entire auto-continue chain breaks silently and broadcast gets stuck.

**Fix**: 
- Increase timeout to 30s
- Add exponential backoff retry (up to 5 attempts)
- Log failures to debug

### 3. **Ecosystem Error Deferral Loop**
**Location**: [`supabase/functions/whatsapp-manage/index.ts:1125-1130`](supabase/functions/whatsapp-manage/index.ts#L1125-L1130)

**Issue**: Ecosystem-failed messages are marked as "pending" indefinitely:
```typescript
if (isEcosystem) {
  batchEcosystemFails++;
  ecosystemFailCount++;
  consecutiveEcosystemFails++;
  if (recipient?.id) {
    batchEcosystem.push({
      id: recipient.id,
      error_details: errMsg.substring(0, 1000),
    });
  }
}
```

**Problem**: These recipients get re-attempted immediately and may fail again, causing infinite defer loop.

**Fix**:
- Add a retry counter to error_details
- After 3 defer cycles, mark as permanently failed
- Create separate status "ecosystem_deferred_final" after retry limit

### 4. **Speed Throttle Consuming 60s Window**
**Location**: [`supabase/functions/whatsapp-manage/index.ts:1207-1230`](supabase/functions/whatsapp-manage/index.ts#L1207-L1230)

**Issue**: Multiple throttle pauses can add up quickly:
- Ecosystem critical pause: up to 30s
- Ecosystem throttle pause: 5s
- Rate limit pause: 5s
- Light ecosystem pause: 2s

**Example**: If you hit ecosystem errors on first 3 batches with 5s pauses each, that's 15s of the 60s already consumed before real progress.

**Fix**: 
- Cap total throttle pause time to 20s maximum (not per pause)
- After 20s of pausing, move to auto-continue
- Log pause time consumption to understand the issue

### 5. **Broadcast Status Stuck on "SENDING"**
**Location**: Broadcast completion logic not triggered if auto-continue fails

**Issue**: If auto-continue invocation fails silently, broadcast never updates from "sending" to "completed" or "failed".

**Fix**:
- Add client-side stall detection to mark stuck broadcasts
- Check if sent_count hasn't changed for 5 minutes
- Provide UI button to manually mark as failed
- Add server-side auto-expire: if "sending" >24hrs, auto-mark "failed"

## Recommended Changes Priority

### 🔴 Critical (Implement First)
1. **Fix recipient DB loading timeout** - Add 10s max load time
2. **Fix auto-continue invocation** - Increase timeout to 30s + retries
3. **Add stall detection backend** - Mark stuck broadcasts after 15 min

### 🟡 Medium Priority
1. Fix ecosystem error deferral loop - add retry counter
2. Cap throttle pauses to 20s maximum
3. Add manual retry button for stuck broadcasts

### 🟢 Low Priority
1. Better logging/metrics for debugging
2. Add broadcast timeout configuration option
3. New "ecosystem_deferred_final" status type

## Implementation Order
1. Fix the recipient loading timeout (quick win)
2. Fix auto-continue timeout (critical for reliability)
3. Add backend stall detection (prevents future hangs)
4. Fix ecosystem deferral loop (prevents infinite waits)

## Testing After Fix
1. Send broadcast to 50k recipients
2. Monitor logs for auto-continue invocations
3. Verify no broadcasts get stuck >5 minutes
4. Check ecosystem errors are handled gracefully
