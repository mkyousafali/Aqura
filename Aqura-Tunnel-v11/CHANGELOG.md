# Aqura-Tunnel v11 Changelog

## Version 11 - November 28, 2025

### 🔧 Critical Bug Fix: Biometric Historical Sync

**Issue Fixed:**
- Historical sync was reporting success (7,092 transactions) but no data was inserted into Supabase
- Root cause: Sync code used `upsert` with `onConflict: 'employee_id,date,time'` but no unique constraint existed
- PostgreSQL silently rejected all inserts due to missing constraint (error code 42P10)

**Solution:**
- Changed from `upsert()` to direct `insert()` for both historical and ongoing sync
- Added error logging to detect batch insert failures
- Updated both `syncBiometricTransactions()` and `sync-bio-historical-data` handler

### Changes from v10:

#### main.js
- **Line ~835**: Changed ongoing transaction sync from upsert to insert
  ```javascript
  // Before (v10):
  .upsert(batch, { onConflict: 'employee_id,date,time', ignoreDuplicates: true })
  
  // After (v11):
  .insert(batch)
  ```

- **Line ~955**: Changed historical sync from upsert to insert
  ```javascript
  // Before (v10):
  .upsert(batch, { onConflict: 'employee_id,date,time', ignoreDuplicates: true })
  
  // After (v11):
  .insert(batch)
  ```

- Added error message logging for batch failures

### Database Schema Requirement:

The `hr_fingerprint_transactions` table must have these columns:
- `employee_id` (varchar)
- `name` (varchar) 
- `date` (date)
- `time` (time)
- `status` (varchar) - "Check In" or "Check Out"
- `device_id` (varchar)
- `location` (text)
- `branch_id` (bigint)
- `created_at` (timestamp)

### Testing:

After installing v11:
1. Click "👤 Sync Biometric History" to re-sync historical data
2. All 7,000+ transactions should now insert successfully
3. Verify data appears in Supabase `hr_fingerprint_transactions` table
4. Ongoing sync will work automatically (5-minute punch / 30-minute employees)

### Notes:

- This fix resolves the silent failure issue
- Direct insert will work as long as branch doesn't re-sync same date range twice
- Future enhancement: Add unique constraint to table and switch back to upsert for deduplication

---

**Upgrade from v10:** Replace all files, no database changes needed (columns already fixed)
