# Button Access Control System - RLS Setup Guide

## Current Status

✅ **Branches Table RLS**: Already configured properly
- Service role: FULL ACCESS (read, write, delete)
- Anon key: READ & WRITE ACCESS

❌ **Button Tables RLS**: NEEDS SETUP
- button_main_sections
- button_sub_sections
- sidebar_buttons
- button_permissions

## Problem

The 401 Unauthorized errors in the browser console are because:
1. Button tables have NO RLS policies enabled
2. Frontend uses anon key which cannot access tables without RLS policies
3. Tables exist but are locked down by default

## Solution: Apply RLS Policies

### Step 1: Copy the SQL Migration

Open the file: `supabase/migrations/button_tables_rls.sql`

This file contains all the SQL statements needed to:
1. Enable RLS on all 4 button tables
2. Create SELECT policies for all users (authenticated and unauthenticated)
3. Create INSERT/UPDATE/DELETE policies for service role only

### Step 2: Execute in Supabase Console

1. Go to https://supabase.urbanaqura.com
2. Navigate to **SQL Editor** → **New Query**
3. Copy the entire contents of `supabase/migrations/button_tables_rls.sql`
4. Paste into the SQL editor
5. Click **Execute**

### Step 3: Verify Policies

Run this query in SQL Editor to verify:

```sql
SELECT * FROM pg_policies WHERE tablename LIKE 'button_%' OR tablename = 'sidebar_buttons';
```

Should return 8 policies:
- button_main_sections (2 policies: select_all, insert_service)
- button_sub_sections (2 policies)
- sidebar_buttons (2 policies)
- button_permissions (2 policies)

## RLS Policy Details

### button_main_sections
- **SELECT**: Allow all (true) - everyone can read
- **INSERT/UPDATE/DELETE**: Allow service_role only

### button_sub_sections
- **SELECT**: Allow all (true) - everyone can read
- **INSERT/UPDATE/DELETE**: Allow service_role only

### sidebar_buttons
- **SELECT**: Allow all (true) - everyone can read
- **INSERT/UPDATE/DELETE**: Allow service_role only

### button_permissions
- **SELECT**: Allow user_id = auth.uid() OR service_role
  - Users can only see their own permissions
  - Service role can see all
- **INSERT/UPDATE/DELETE**: Allow service_role only

## After RLS is Applied

1. Frontend 401 errors will be resolved
2. Button tables will be readable by all authenticated users
3. Only service role can modify button data (via scripts/populate-buttons.cjs)
4. Users can see their own button permissions

## Files Involved

- **Migration**: `supabase/migrations/button_tables_rls.sql` - SQL to apply RLS
- **Checker Script**: `scripts/check-branches-rls.cjs` - Verify RLS policies work
- **Applier Script**: `scripts/apply-button-rls.cjs` - Attempts automated setup (manual execution needed)

## Related Components

- **ButtonGenerator**: `frontend/src/lib/components/desktop-interface/settings/ButtonGenerator.svelte`
  - Shows missing buttons comparison
  - Adds missing buttons to database
  - Updates permissions table
  
- **ButtonAccessControl**: `frontend/src/lib/components/desktop-interface/settings/ButtonAccessControl.svelte`
  - Master Admin tool for managing user permissions
  
- **Sidebar**: `frontend/src/lib/components/desktop-interface/common/Sidebar.svelte`
  - Will filter buttons based on user permissions (to be implemented)
