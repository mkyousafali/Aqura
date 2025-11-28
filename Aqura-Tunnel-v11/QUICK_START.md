# Aqura-Tunnel v11 Quick Start Guide

## What's New in v11?
✅ Fixed biometric historical sync - data now inserts successfully into Supabase
✅ Changed from upsert to direct insert (no unique constraint needed)
✅ Added better error logging for batch failures

---

## Installation Steps

### 1. Copy Files to Branch PC
Copy the entire `Aqura-Tunnel-v11` folder to the branch computer.

### 2. Install Dependencies
```bash
npm install
```

### 3. Configure ERP Connection
1. Launch the app: `npm start`
2. Click "⚙️ ERP Configuration"
3. Fill in:
   - Branch ID (1, 2, 3, 4)
   - SQL Server IP (e.g., `192.168.0.3`)
   - Database Name (e.g., `URBAN2_2025`)
   - Username (e.g., `sa`)
   - Password
4. Click "💾 Save ERP Config"
5. Click "🧪 Test Connection" to verify

### 4. Configure Biometric Connection
1. Click "⚙️ Biometric Configuration"
2. Fill in:
   - Branch ID (same as ERP)
   - Device ID (unique identifier for this ZKBioTime device)
   - SQL Server IP (ZKBioTime server, e.g., `WIN-D1D6EN8240A`)
   - Database Name (usually `Zkurbard`)
   - Username (SQL Server user)
   - Password
   - Terminal S/N (optional - filter by specific device)
3. Click "💾 Save Biometric Config"
4. Click "🧪 Test Connection" to verify

### 5. Sync Historical Biometric Data (IMPORTANT!)
1. Click "👤 Sync Biometric History" button
2. Select start date (e.g., January 1, 2024)
3. Click "Start Sync"
4. Wait for completion (shows progress: "71/71 batches")
5. **Verify in Supabase** - Check `hr_fingerprint_transactions` table has data

### 6. Start Automatic Sync
1. Click "🚀 Start Sync" button
2. Monitor the sync log:
   - ERP sales sync: Every 1 minute
   - Biometric punch sync: Every 5 minutes
   - Biometric employee sync: Every 30 minutes

---

## Verification Checklist

### ERP Sync Working:
- ✅ See "✅ Sales synced successfully: X records" every minute
- ✅ Sales data appears in Supabase `sales_data` table

### Biometric Sync Working:
- ✅ See "✅ Synced X punch transactions" every 5 minutes
- ✅ See "✅ Synced X employees" every 30 minutes
- ✅ Data appears in Supabase `hr_fingerprint_transactions` table
- ✅ Employee data appears in Supabase `hr_employees` table

---

## Troubleshooting

### Historical Sync Shows Success But No Data
**Fixed in v11!** The upsert issue has been resolved. If you still see no data:
1. Check Supabase `hr_fingerprint_transactions` table columns are correct:
   - Must have: `employee_id`, `date`, `time`, `status`, `device_id`, `location`, `branch_id`
2. Check sync log for batch errors (now logged in v11)
3. Verify ZKBioTime connection works (Test Connection button)

### ERP Sync Fails
- Verify SQL Server IP is correct
- Check database name matches exactly
- Ensure `InvTransactionMaster` table exists in ERP database
- Test connection using "🧪 Test Connection" button

### Biometric Sync Fails
- Verify ZKBioTime server IP is correct
- Check database name (usually `Zkurbard`)
- Ensure `iclock_transaction` and `personnel_employee` tables exist
- Test connection using "🧪 Test Connection" button

### Connection Pool Errors
**Fixed in v10+!** v11 uses separate connection pools to prevent database context switching.

---

## Database Schema Requirements

### Supabase Tables Needed:

1. **erp_connections** - ERP configuration storage
2. **biometric_connections** - Biometric configuration storage (with `last_sync_at`)
3. **sales_data** - ERP sales records
4. **hr_fingerprint_transactions** - Biometric punch records
5. **hr_employees** - Employee master data

---

## Support

If you encounter issues:
1. Check the sync log in the app
2. Verify all configurations are correct
3. Test connections individually
4. Check Supabase tables exist with correct schemas
5. Review error messages in console (F12)

---

## Version History

- **v11** (Nov 28, 2025): Fixed upsert issue → direct insert for biometric sync
- **v10** (Nov 28, 2025): Fixed connection pool isolation
- **v9** (Nov 28, 2025): Initial biometric sync implementation

---

**Ready to sync!** 🚀
