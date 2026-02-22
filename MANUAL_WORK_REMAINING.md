# Manual Work Remaining

## Step 1 — Test Branch Sync
Run sync from **Storage Manager > Branch Sync** and verify:
- Schema pass shows all statements deploying (multi-pass, 0 failures ideal)
- Discovery shows `cloud=179, branch=~170, syncable=~163`
- Data import completes for all tables

## Step 2 — Commit & Push All Changes
Uncommitted files since last push:
- `frontend/src/lib/components/desktop-interface/settings/StorageManager.svelte`
- `frontend/src/routes/api/branch-proxy/+server.ts`
- `supabase/migrations/20260222_export_schema_ddl.sql`
- `supabase/migrations/20260222_expand_sync_tables.sql`

## Step 3 — Version Bump & Deploy
Follow `AI_VERSION_PUSH_AND_DEPLOY_GUIDE.md`:
- Bump version in all 4 interfaces
- Build frontend (`NODE_OPTIONS="--max-old-space-size=8192"`)
- Upload ZIP to Supabase Storage
- Register in `frontend_builds` table
- Update `VersionChangelog.svelte`
- Push to Git

## Step 4 — Build Branch Frontend ZIP
Run `Build-Frontend.ps1` to create `aqura-frontend-build.zip` for branch deployments with the new sync code.

## Step 5 — Push Frontend to Active Branches
Run `Update-AquraBranch.ps1 -All` to push the new frontend build to any active branch VMs.

## Step 6 — Verify Branch Sync End-to-End
After pushing, open a branch at `http://<branch-ip>:3001`, go to Storage Manager, and run sync. Confirm:
- All ~163 tables sync successfully
- Schema (functions, triggers, policies) deployed without errors
- Data matches cloud
