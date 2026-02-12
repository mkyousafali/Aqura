# Edge Function Creation & Deployment Guide

> **AI Agent Guide** — Walk the user through each step, one at a time.
> Server: Self-hosted Supabase at `8.213.42.21` (SSH as `root`)

---

## Server Architecture

| Component | Details |
|---|---|
| **Server IP** | `8.213.42.21` |
| **SSH User** | `root` |
| **Docker Compose Path** | `/opt/supabase/supabase/docker/docker-compose.yml` |
| **Functions Volume** | `/opt/supabase/supabase/docker/volumes/functions/` |
| **Edge Functions Container** | `supabase-edge-functions` |
| **Kong Gateway Container** | `supabase-kong` (port 8000) |
| **Kong Config** | `/opt/supabase/supabase/docker/volumes/api/kong.yml` |
| **Kong Routing** | **Wildcard route** `/functions/v1/*` → `http://functions:9000/` (auto-routes all functions) |
| **Database Container** | `supabase-db` (user: `supabase_admin`) |
| **Internal Function URL** | `http://supabase-kong:8000/functions/v1/<function-name>` |
| **External Function URL** | `https://supabase.urbanaqura.com/functions/v1/<function-name>` |
| **Service Role Key** | **DO NOT hardcode!** Run command below on server to retrieve it |

### How to get the Service Role Key (run on server via SSH)

```bash
grep SERVICE_ROLE_KEY /opt/supabase/supabase/docker/.env | cut -d '=' -f2
```

> **NEVER** commit the service role key to git. Always retrieve it from the server when needed.

---

## Step 1: Create the Function Code Locally

Create the function file in the workspace:

```
d:\Aqura\supabase\functions\<function-name>\index.ts
```

### Template

```typescript
// Supabase Edge Function: <Function Name>
// Purpose: <description>

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get Supabase client with service role (full access)
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // --- Your logic here ---

    // Parse request body (for POST)
    let params: any = {};
    if (req.method === 'POST') {
      try {
        params = await req.json();
      } catch (_) {
        // No body or invalid JSON
      }
    }

    // Example: query a table
    const { data, error } = await supabase
      .from('your_table')
      .select('*');

    if (error) throw error;

    // Return success response
    return new Response(
      JSON.stringify({ success: true, data }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

### Key Notes

- **Import**: Always use `https://esm.sh/@supabase/supabase-js@2.39.3` (ESM URL, not npm)
- **Runtime**: Deno (not Node.js) — no `require()`, use `import`
- **Environment Variables**: `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are auto-injected
- **Timezone**: Server runs UTC. For Saudi Arabia dates, use:
  ```typescript
  function getSaudiDateStr(): string {
    return new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Riyadh' });
  }
  ```

---

## Step 2: SSH into the Server

```bash
ssh root@8.213.42.21
```

Password will be prompted.

---

## Step 3: Create the Function Directory on Server

```bash
mkdir -p /opt/supabase/supabase/docker/volumes/functions/<function-name>/
```

---

## Step 4: Create the Function File on Server

```bash
cd /opt/supabase/supabase/docker/volumes/functions/<function-name>/
nano index.ts
```

Then:
1. In VS Code, select all code in `index.ts` (Ctrl+A)
2. Copy (Ctrl+C)
3. In the SSH terminal, right-click to paste
4. Press **Ctrl+O** to save
5. Press **Enter** to confirm filename
6. Press **Ctrl+X** to exit nano

### Verify

```bash
wc -l index.ts
```

Should match the line count from VS Code.

---

## Step 5: Register the Function in Docker Compose

The Edge Functions container needs to know about the new function.

```bash
cd /opt/supabase/supabase/docker/
nano docker-compose.yml
```

Find the `edge-functions` or `functions` service section. Look for a `SUPABASE_FUNCTIONS_*` environment variable or volume mapping. The functions volume is typically already mounted at:

```yaml
volumes:
  - ./volumes/functions:/home/deno/functions
```

If the volume is already mounted (it should be), **no changes to docker-compose.yml are needed** — the container auto-discovers functions by folder name.

---

## Step 6: Kong Gateway — No Action Needed!

> **IMPORTANT DISCOVERY**: Kong uses a **wildcard route** that auto-routes ALL functions.
> The route `/functions/v1/*` forwards to `http://functions:9000/`, so **no per-function Kong registration is needed**.
> Simply creating the function folder in the volumes directory (Step 3-4) and restarting the edge-functions container (Step 7) is sufficient.

The Kong config is at `/opt/supabase/supabase/docker/volumes/api/kong.yml` — you should NOT need to edit it.

You can verify the wildcard route exists:

```bash
grep -A5 'functions' /opt/supabase/supabase/docker/volumes/api/kong.yml
```

Look for:
```yaml
paths:
  - /functions/v1/
```

This wildcard catches all `/functions/v1/<anything>` and forwards to the edge-functions container.

---

## Step 7: Restart the Containers

```bash
cd /opt/supabase/supabase/docker/
docker restart supabase-edge-functions
docker restart supabase-kong
```

### Verify the container is running

```bash
docker ps | grep -E "edge-functions|kong"
```

Both should show `Up` status.

---

## Step 8: Test the Function

### Test from the server (internal)

```bash
# First, get the key into a variable:
SERVICE_KEY=$(grep SERVICE_ROLE_KEY /opt/supabase/supabase/docker/.env | cut -d '=' -f2)

curl -X POST http://localhost:8000/functions/v1/<function-name> \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Test from external (browser/frontend)

```bash
curl -X POST https://supabase.urbanaqura.com/functions/v1/<function-name> \
  -H "Authorization: Bearer <USER_ACCESS_TOKEN_OR_SERVICE_ROLE_KEY>" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Check logs if it fails

```bash
docker logs supabase-edge-functions --tail 50
docker logs supabase-kong --tail 50
```

---

## Step 9: Call from Frontend (SvelteKit)

```typescript
// Using user's auth token (respects RLS)
const { data: { session } } = await supabase.auth.getSession();
const token = session?.access_token;

const res = await fetch('https://supabase.urbanaqura.com/functions/v1/<function-name>', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({ /* your params */ })
});

const result = await res.json();
```

---

## Step 10: Set Up pg_cron (Optional — Scheduled Execution)

If the function needs to run automatically on a schedule:

### Connect to the database

```bash
docker exec -it supabase-db psql -U supabase_admin -d postgres
```

### Enable extensions (first time only)

```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;
```

### Create a cron job

```sql
SELECT cron.schedule(
  '<job-name>',
  '<cron-expression>',
  $$
  SELECT net.http_post(
    url := 'http://supabase-kong:8000/functions/v1/<function-name>',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer <SERVICE_ROLE_KEY>'  -- get key: grep SERVICE_ROLE_KEY /opt/supabase/supabase/docker/.env | cut -d '=' -f2
    ),
    body := '{"key": "value"}'::jsonb
  );
  $$
);
```

### Cron Expression Reference

| Expression | Meaning |
|---|---|
| `0 3 * * *` | Every day at 3:00 AM UTC (6:00 AM Saudi) |
| `30 5 * * *` | Every day at 5:30 AM UTC (8:30 AM Saudi) |
| `0 10 * * *` | Every day at 10:00 AM UTC (1:00 PM Saudi) |
| `*/15 * * * *` | Every 15 minutes |
| `0 0 * * 0` | Every Sunday at midnight UTC |

> **Saudi Arabia = UTC + 3 hours**. Subtract 3 from Saudi time to get UTC for cron.

### Manage cron jobs

```sql
-- List all jobs
SELECT * FROM cron.job;

-- Delete a job
SELECT cron.unschedule(<job_id>);

-- Check recent execution history
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 20;
```

### Exit psql

```
\q
```

---

## Updating an Existing Function

When you need to update an already-deployed function:

1. **Edit locally** in VS Code: `d:\Aqura\supabase\functions\<function-name>\index.ts`
2. **SSH into server**: `ssh root@8.213.42.21`
3. **Navigate**: `cd /opt/supabase/supabase/docker/volumes/functions/<function-name>/`
4. **Clear & open**: `> index.ts && nano index.ts`
5. **Paste** the new code from VS Code
6. **Save & exit**: Ctrl+O, Enter, Ctrl+X
7. **Verify**: `wc -l index.ts`
8. **Restart**: `cd /opt/supabase/supabase/docker/ && docker restart supabase-edge-functions`
9. **Test**: Run the curl command from Step 8

> **No need to restart Kong** when only updating function code (only restart Kong when adding new functions or changing routes).

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `502 Bad Gateway` | `docker restart supabase-edge-functions` then check `docker logs supabase-edge-functions --tail 50` |
| `404 Not Found` | Function folder missing — check `ls /opt/supabase/supabase/docker/volumes/functions/` and restart edge-functions container |
| `401 Unauthorized` | Wrong or missing Authorization header — use service role key |
| `Function not found` | Directory name must match function name in URL; check `ls /opt/supabase/supabase/docker/volumes/functions/` |
| Syntax error in function | Check `docker logs supabase-edge-functions --tail 100` for TypeScript/Deno errors |
| pg_cron not firing | Verify with `SELECT * FROM cron.job;` and check `cron.job_run_details` |
| pg_cron 401 error | Use internal URL `http://supabase-kong:8000/...` (not localhost, not external URL) |
| Timezone wrong | Use `getSaudiDateStr()` helper — server runs in UTC, Saudi = UTC+3 |

---

## Existing Edge Functions

| Function | Path | Purpose | pg_cron |
|---|---|---|---|
| `analyze-attendance` | `/functions/v1/analyze-attendance` | Automated attendance analysis | 6x/day (jobs 5-10) |
| `process-fingerprints` | `/functions/v1/process-fingerprints` | ETL: raw device punches → processed_fingerprint_transactions | Hourly at :00 (job 11) |
| `send-push-notification` | `/functions/v1/send-push-notification` | Push notifications to users | — |

### pg_cron Schedule Reference

| Job ID | Name | Schedule (UTC) | Saudi Time | Function | Body |
|---|---|---|---|---|---|
| 5 | `analyze-attendance-6am` | `0 3 * * *` | 6:00 AM daily | analyze-attendance | `{"rollingDays": 45}` |
| 6 | `analyze-attendance-830am` | `30 5 * * *` | 8:30 AM daily | analyze-attendance | `{"rollingDays": 45}` |
| 7 | `analyze-attendance-1pm` | `0 10 * * *` | 1:00 PM daily | analyze-attendance | `{"rollingDays": 45}` |
| 8 | `analyze-attendance-6pm` | `0 15 * * *` | 6:00 PM daily | analyze-attendance | `{"rollingDays": 45}` |
| 9 | `analyze-attendance-830pm` | `30 17 * * *` | 8:30 PM daily | analyze-attendance | `{"rollingDays": 45}` |
| 10 | `analyze-attendance-1230am` | `30 21 * * *` | 12:30 AM daily | analyze-attendance | `{"rollingDays": 45}` |
| 11 | `process-fingerprints-hourly` | `0 * * * *` | Every hour at :00 | process-fingerprints | `{}` |

---

## File Locations Summary

```
LOCAL (VS Code):
d:\Aqura\supabase\functions\<function-name>\index.ts

SERVER (SSH):
/opt/supabase/supabase/docker/volumes/functions/<function-name>/index.ts
/opt/supabase/supabase/docker/volumes/api/kong.yml
/opt/supabase/supabase/docker/docker-compose.yml
```
