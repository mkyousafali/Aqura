# System Expiry Dates RPC Function - Deployment Guide

## Overview
The `get_system_expiry_dates` RPC function fetches system expiry dates from the `erp_synced_products` table in Supabase, avoiding long URL issues by processing the query server-side.

## Function Details
- **Function Name:** `get_system_expiry_dates`
- **Parameters:**
  - `barcode_list` (text[]) - Array of product barcodes
  - `branch_id_param` (integer) - Branch ID to filter by
- **Returns:** Table with columns:
  - `barcode` (text) - Product barcode
  - `expiry_date_formatted` (text) - Formatted expiry date (DD-MM-YYYY) or '—' if not found

## Deployment Steps

### Option 1: Using Supabase Dashboard
1. Go to Supabase dashboard → SQL Editor
2. Create a new query
3. Copy the SQL from `supabase/migrations/create_get_system_expiry_dates_rpc.sql`
4. Execute the query

### Option 2: Using Server SSH (from Windows with SSH key)
```powershell
scp supabase/migrations/create_get_system_expiry_dates_rpc.sql root@8.213.42.21:/tmp/
ssh root@8.213.42.21 "docker cp /tmp/create_get_system_expiry_dates_rpc.sql supabase-db:/tmp/ && docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/create_get_system_expiry_dates_rpc.sql"
```

### Option 3: Manual Execution on Server
```bash
# SSH into server
ssh root@8.213.42.21

# Copy SQL file to container
docker cp /path/to/migration/file supabase-db:/tmp/migration.sql

# Execute in PostgreSQL
docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/migration.sql
```

## Usage in NearExpiryManager Component
The component calls the RPC function after importing data:
```typescript
const { data: expiryResults, error } = await supabase.rpc('get_system_expiry_dates', {
    barcode_list: barcodes,
    branch_id_param: selectedBranchId
});
```

## Benefits
✅ Avoids long URL issues with large barcode arrays
✅ Server-side processing reduces frontend data transfer
✅ Formatted dates returned directly (DD-MM-YYYY)
✅ Branch-specific filtering built into function
✅ Null safety with '—' placeholder for missing data
