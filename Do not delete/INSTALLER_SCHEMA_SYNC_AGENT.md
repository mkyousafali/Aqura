# AI Agent: Installer Schema Sync

## Purpose
Keep the branch installer's bundled schema, storage buckets, and edge functions in sync with the live cloud Supabase database. Run this agent whenever you want to update the installer before distributing it to branches.

---

## When to Run
- After any migration is deployed to the cloud DB
- After new edge functions are added or updated
- After new storage buckets are created
- Before building a new installer release
- Periodically (e.g., monthly) as a health check

---

## Agent Task: Check & Update Installer

### Step 1 — Compare cloud DB with bundled schema

SSH to the cloud server and count objects. Then count what's in `bundled/aqura-schema.sql`. If any counts differ, the installer is outdated and must be updated.

**Run on cloud server (via SSH):**
```bash
ssh -o StrictHostKeyChecking=no -i "$env:USERPROFILE\.ssh\id_ed25519_nopass" root@8.213.42.21 "docker exec supabase-db psql -U supabase_admin -d postgres -t -A -c \"SELECT 'T:'||count(*) FROM information_schema.tables WHERE table_schema='public' UNION ALL SELECT 'F:'||count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' UNION ALL SELECT 'Trig:'||count(*) FROM information_schema.triggers WHERE trigger_schema='public' UNION ALL SELECT 'Idx:'||count(*) FROM pg_indexes WHERE schemaname='public' UNION ALL SELECT 'Bkt:'||count(*) FROM storage.buckets;\""
```

**Count objects in bundled schema file:**
```powershell
$f = "D:\Aqura\scripts\aqura-branch-setup\bundled\aqura-schema.sql"
wsl -d Ubuntu-22.04 -u root -- python3 -c "
import re
f = open('/mnt/d/Aqura/scripts/aqura-branch-setup/bundled/aqura-schema.sql', encoding='utf-8', errors='replace').read()
print('Tables:',    len(re.findall(r'(?im)^CREATE TABLE', f)))
print('Functions:', len(re.findall(r'(?im)^CREATE (?:OR REPLACE )?FUNCTION', f)))
print('Triggers:',  len(re.findall(r'(?im)^CREATE TRIGGER', f)))
print('Indexes:',   len(re.findall(r'(?im)^CREATE (?:UNIQUE )?INDEX', f)))
print('Buckets:',   len(re.findall(r'(?im)ON CONFLICT.*DO NOTHING', f)))
"
```

**Decision rule:**
- If ANY count from cloud > count in bundled file → **outdated, must update**
- If all counts match → installer is up to date, no rebuild needed

---

### Step 2 — Dump fresh schema from cloud server

Only run if Step 1 found differences.

```powershell
# 1. Dump public schema (structure only, no data)
ssh -o StrictHostKeyChecking=no -i "$env:USERPROFILE\.ssh\id_ed25519_nopass" root@8.213.42.21 `
  "docker exec supabase-db pg_dump -U supabase_admin -d postgres --schema-only --no-owner --no-acl -n public > /tmp/fresh_schema.sql && echo done"

# 2. Append storage bucket INSERT statements
$bucketSQL = @'
SELECT
  'INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types, avif_autodetection, created_at, updated_at) VALUES (' ||
  quote_literal(id) || ', ' || quote_literal(name) || ', ' ||
  public::text || ', ' || COALESCE(file_size_limit::text, 'NULL') || ', ' ||
  COALESCE(quote_literal(allowed_mime_types::text), 'NULL') || ', ' ||
  avif_autodetection::text || ', ' ||
  quote_literal(created_at::text) || ', ' || quote_literal(updated_at::text) ||
  ') ON CONFLICT (id) DO NOTHING;'
FROM storage.buckets ORDER BY name;
'@
$bucketSQL | Set-Content C:\Windows\Temp\bucket_q.sql -Encoding ASCII
scp -o StrictHostKeyChecking=no -i "$env:USERPROFILE\.ssh\id_ed25519_nopass" C:\Windows\Temp\bucket_q.sql root@8.213.42.21:/tmp/bucket_q.sql
ssh -o StrictHostKeyChecking=no -i "$env:USERPROFILE\.ssh\id_ed25519_nopass" root@8.213.42.21 `
  "echo '' >> /tmp/fresh_schema.sql && echo '-- ===== STORAGE BUCKETS =====' >> /tmp/fresh_schema.sql && cat /tmp/bucket_q.sql | docker exec -i supabase-db psql -U supabase_admin -d postgres -t -A >> /tmp/fresh_schema.sql && wc -l /tmp/fresh_schema.sql"

# 3. Download to bundled/ folder
scp -o StrictHostKeyChecking=no -i "$env:USERPROFILE\.ssh\id_ed25519_nopass" root@8.213.42.21:/tmp/fresh_schema.sql `
  "D:\Aqura\scripts\aqura-branch-setup\bundled\aqura-schema.sql"

# 4. Cleanup temp files on server
ssh -o StrictHostKeyChecking=no -i "$env:USERPROFILE\.ssh\id_ed25519_nopass" root@8.213.42.21 "rm -f /tmp/fresh_schema.sql /tmp/bucket_q.sql"
```

---

### Step 3 — Update edge functions

```powershell
# Re-zip all edge functions from source
Compress-Archive -Path "D:\Aqura\supabase\functions\*" `
  -DestinationPath "D:\Aqura\scripts\aqura-branch-setup\bundled\functions.zip" -Force

Write-Host "Functions zip: $([math]::Round((Get-Item 'D:\Aqura\scripts\aqura-branch-setup\bundled\functions.zip').Length/1KB,1)) KB"
```

---

### Step 4 — Update the migrations reference file

Copy the fresh schema to the migrations folder so source control tracks it:

```powershell
$date = Get-Date -Format "yyyyMMdd"
Copy-Item "D:\Aqura\scripts\aqura-branch-setup\bundled\aqura-schema.sql" `
  "D:\Aqura\supabase\migrations\${date}000000_current_schema.sql"
```

> **Note:** The old `20260515000000_current_schema.sql` can be deleted or kept. The newest date-prefixed file is the authoritative one.

---

### Step 5 — Rebuild the installer

```powershell
cd "D:\Aqura\scripts\aqura-branch-setup"
npm run build 2>&1 | Select-Object -Last 6
```

Verify the bundled files are included in the built output:
```powershell
Get-ChildItem "D:\Aqura\scripts\aqura-branch-setup\dist\win-unpacked\resources\bundled" |
  Select-Object Name, @{N='MB';E={[math]::Round($_.Length/1MB,2)}}
```

Expected output:
```
Name                MB
----                --
aqura-schema.sql    ~1.6+
functions.zip       ~0.1+
```

---

### Step 6 — Reset installer state for re-testing (optional)

If you want to test the full install flow again on this machine:

```powershell
# Reset to re-run from schema import step (step 7)
$state = Get-Content C:\AquraServer\installer-state.json | ConvertFrom-Json
$state.currentPhase = 6
$state.schemaImported = $false
$state | ConvertTo-Json -Depth 10 | Set-Content C:\AquraServer\installer-state.json
```

---

## Key Architecture Notes

### Installer bundled file locations
| File | Packaged path | Purpose |
|------|---------------|---------|
| `aqura-schema.sql` | `resources/bundled/aqura-schema.sql` | Full public schema + storage bucket INSERTs |
| `functions.zip` | `resources/bundled/functions.zip` | All Supabase edge functions |

### What the installer does with these files (Step 7 — import-schema)
1. Detects `aqura-schema.sql` via `api.fileExists()`
2. Copies it to `C:\Windows\Temp\aqura-schema.sql`
3. `docker cp` into supabase-db container
4. Runs `psql -f aqura-schema.sql` as `supabase_admin`
5. Detects `functions.zip`, unzips into `/opt/supabase/supabase/docker/volumes/functions/`
6. Restarts `supabase-edge-runtime` container
7. Verifies table + function count > 0 (throws if still 0)

### SSH credentials
- **Host:** `8.213.42.21`
- **User:** `root`
- **Key (no passphrase):** `%USERPROFILE%\.ssh\id_ed25519_nopass`
- **DB superuser:** `supabase_admin`
- **DB name:** `postgres`

### Critical rules
- **NEVER** run `buildSupabaseEnv()` and copy it as the full `.env` — it only has ~74 lines and destroys the 344-line config
- **ALWAYS** use `sed` to update individual keys in the existing `.env`
- **NEVER** use `wslpath` in the installer — use `C:\Windows\Temp\` as the transfer point
- The bundled schema is **schema-only** (no user data, no secrets)
- Storage bucket INSERTs use `ON CONFLICT (id) DO NOTHING` so they are safe to re-run

---

## Quick One-Liner Check (is the installer up to date?)

Run this from PowerShell. If it prints "UP TO DATE" the installer is good. If it prints "OUTDATED" run Steps 2–5 above.

```powershell
$cloud = ssh -o StrictHostKeyChecking=no -i "$env:USERPROFILE\.ssh\id_ed25519_nopass" root@8.213.42.21 "docker exec supabase-db psql -U supabase_admin -d postgres -t -A -c `"SELECT count(*) FROM information_schema.tables WHERE table_schema='public'`""
$local = (wsl -d Ubuntu-22.04 -u root -- bash -c "grep -c 'CREATE TABLE' /mnt/d/Aqura/scripts/aqura-branch-setup/bundled/aqura-schema.sql 2>/dev/null || echo 0")
if ([int]$cloud.Trim() -gt [int]$local.Trim()) { Write-Host "OUTDATED — Cloud: $($cloud.Trim()) tables, Bundled: $($local.Trim()) tables" -ForegroundColor Red }
else { Write-Host "UP TO DATE — $($cloud.Trim()) tables in both" -ForegroundColor Green }
```
