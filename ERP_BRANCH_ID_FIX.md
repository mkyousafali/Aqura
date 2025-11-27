# ERP Branch ID Fix - Implementation Guide

## Problem
The ERP sync service was syncing sales data from all branches without respecting the individual ERP branch IDs (1, 2, 3, 4, 5, etc.). This caused data to be mixed up between branches.

## Solution Overview
1. Add `erp_branch_id` column to `erp_connections` table
2. Update the sync app to collect ERP Branch ID during configuration
3. Filter SQL queries by ERP Branch ID when fetching sales data
4. Store data with correct Supabase branch_id while using ERP branch_id for filtering

## Step 1: Apply Database Migration

### Option A: Using Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Run this SQL:

```sql
-- Add erp_branch_id column to erp_connections table
ALTER TABLE erp_connections 
ADD COLUMN IF NOT EXISTS erp_branch_id INTEGER;

-- Add comment
COMMENT ON COLUMN erp_connections.erp_branch_id IS 'Branch ID from ERP system (1, 2, 3, etc.)';

-- Create index
CREATE INDEX IF NOT EXISTS idx_erp_connections_erp_branch_id 
ON erp_connections(erp_branch_id);

-- Verify the change
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'erp_connections'
ORDER BY ordinal_position;
```

4. Verify that `erp_branch_id` appears in the results

### Option B: Update Existing Records
If you already have ERP connections configured, update them with their ERP branch IDs:

```sql
-- Update existing connections with their ERP branch IDs
-- Replace the values as appropriate for your setup

UPDATE erp_connections 
SET erp_branch_id = 1 
WHERE branch_name = 'Main Branch';

UPDATE erp_connections 
SET erp_branch_id = 2 
WHERE branch_name = 'Branch 2';

-- Continue for all branches...
```

## Step 2: Update the Sync App

The following files have been updated:

### 1. **index.html**
- Added ERP Branch ID input field in the configuration form
- Added ERP Branch ID display in the sync status section

### 2. **renderer.js**
- Updated `getConfigFromForm()` to capture `erp_branch_id`
- Updated `validateConfig()` to require ERP Branch ID
- Updated `updateConfigDisplay()` to show ERP Branch ID

### 3. **main.js**
- Updated `save-config` handler to save `erp_branch_id` to database
- Updated `syncDateData()` function to:
  - Filter sales data by ERP Branch ID using `WHERE [BranchId] = @branchId`
  - Filter return data by ERP Branch ID
  - Store data with correct Supabase `branch_id`

## Step 3: Rebuild and Deploy

### Option A: Run from Source
```powershell
cd d:\Aqura\erp-sync-app
npm start
```

### Option B: Build Installer
```powershell
cd d:\Aqura\erp-sync-app
npm run build
```

The installer will be in `dist/` folder.

## Step 4: Reconfigure Each Branch

For each branch that has the sync app installed:

1. **Login** with your access code
2. **Stop the sync service** if running
3. Click **"Change Configuration"**
4. Fill in the configuration:
   - **Branch**: Select from dropdown (Supabase branch)
   - **ERP Branch ID**: Enter the ERP system's branch ID (1, 2, 3, etc.)
   - **Server IP**: Your SQL Server IP
   - **Database Name**: Your ERP database name
   - **Username/Password**: SQL Server credentials
5. Click **"Test Connection"** to verify
6. Click **"Save & Continue"**
7. Optionally run **"Sync Historical Data"** to import past sales
8. Click **"Start Sync"** to begin real-time syncing

## Verification

After configuration, verify that data is syncing correctly:

### Check Database
```sql
-- View recent syncs with branch information
SELECT 
    eds.sale_date,
    b.name_en as branch_name,
    ec.erp_branch_id,
    eds.total_bills,
    eds.net_amount,
    eds.last_sync_at
FROM erp_daily_sales eds
JOIN branches b ON b.id = eds.branch_id
LEFT JOIN erp_connections ec ON ec.branch_id = eds.branch_id
ORDER BY eds.sale_date DESC, b.name_en
LIMIT 20;
```

### Expected Results
- Each branch should have its own sales data
- `erp_branch_id` should match the branch's ERP system ID
- Sales amounts should correspond to individual branch sales only

## SQL Query Changes

### Before (Incorrect)
```sql
SELECT COUNT(*) AS TotalBills
FROM [dbo].[InvTransactionMaster]
WHERE [VoucherType] = 'SI'
AND CAST([TransactionDate] AS DATE) = @date
```
❌ **This fetches ALL branches' data**

### After (Correct)
```sql
SELECT COUNT(*) AS TotalBills
FROM [dbo].[InvTransactionMaster]
WHERE [VoucherType] = 'SI'
AND [BranchId] = @branchId  -- ✅ Filters by ERP branch
AND CAST([TransactionDate] AS DATE) = @date
```
✅ **This fetches only the specific branch's data**

## Troubleshooting

### Issue: "ERP Branch ID not configured" error
**Solution**: Make sure you entered the ERP Branch ID when configuring the app

### Issue: No data syncing after update
**Solution**: 
1. Verify the database migration was applied
2. Check that ERP Branch ID matches your ERP system
3. Test the SQL query directly in SQL Server Management Studio

### Issue: Getting data from wrong branch
**Solution**:
1. Check `erp_connections` table to verify `erp_branch_id` values
2. Verify your ERP system's `BranchId` column name (might be different)
3. Update the SQL queries in `main.js` if column name is different

## Important Notes

1. **Different IDs**: 
   - `branch_id` = Supabase UUID (used for storage)
   - `erp_branch_id` = ERP system integer (1, 2, 3... used for querying)

2. **Column Name**: The SQL queries assume your ERP uses `[BranchId]` column. If different, update the queries in `main.js`

3. **Historical Data**: After reconfiguring, run "Sync Historical Data" to properly sync past records with branch filtering

4. **Multiple Devices**: Each branch location should have the sync app configured with its specific ERP Branch ID

## Files Modified

- `erp-sync-app/index.html` - Added ERP Branch ID input
- `erp-sync-app/renderer.js` - Added ERP Branch ID handling
- `erp-sync-app/main.js` - Added branch filtering in SQL queries
- `supabase/migrations/add_erp_branch_id_to_connections.sql` - Database migration
- `add-erp-branch-id-column.sql` - Manual migration script

## Next Steps

1. ✅ Apply database migration (Step 1)
2. ✅ Update app files (already done)
3. 🔄 Rebuild the app (Step 3)
4. 🔄 Deploy to each branch (Step 4)
5. ✅ Verify data syncing correctly (Verification section)

---

**Last Updated**: November 27, 2025  
**Status**: Ready for deployment
