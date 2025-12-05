# DATA MIGRATION PLAN - Delete & Migrate from Old Supabase

**Date:** December 5, 2025
**Total Tables:** 28 tables
**Method:** UPSERT (Insert or Update if exists - preserves UUIDs)
**Strategy:** Delete current data, then migrate ALL data from old Supabase

---

## Tables to Migrate (28 total)

### OPERATIONAL DATA (Must Delete & Migrate)

#### HR & Biometric (4 tables)
1. **hr_fingerprint_transactions** - Employee punch records
   - DELETE: Yes
   - MIGRATE: Yes
   - Priority: Medium
   - Dependencies: hr_employees, users

2. **user_audit_logs** - User activity logs
   - DELETE: Yes
   - MIGRATE: Yes
   - Priority: Low
   - Dependencies: users

3. **user_device_sessions** - Device session tracking
   - DELETE: Yes
   - MIGRATE: Yes
   - Priority: Low
   - Dependencies: users

4. **user_sessions** - User login sessions
   - DELETE: Yes
   - MIGRATE: Yes
   - Priority: Low
   - Dependencies: users

#### Finance & Expenses (4 tables)
5. **expense_requisitions** - Expense requests
   - DELETE: Yes
   - MIGRATE: Yes
   - Priority: High
   - Dependencies: employees, branches

6. **expense_scheduler** - Scheduled expenses
   - DELETE: Yes
   - MIGRATE: Yes
   - Priority: High
   - Dependencies: expense_parent_categories, expense_sub_categories

7. **non_approved_payment_scheduler** - Pending payments
   - DELETE: Yes
   - MIGRATE: Yes
   - Priority: High
   - Dependencies: vendors, branches

8. **erp_daily_sales** - ERP sales data
   - DELETE: Yes
   - MIGRATE: Yes
   - Priority: Medium
   - Dependencies: None (standalone)

#### Receiving & Operations (6 tables)
9. **receiving_records** - Receiving transactions
   - DELETE: Yes
   - MIGRATE: Yes
   - Priority: Critical
   - Dependencies: vendors, branches, users

10. **receiving_tasks** - Receiving task assignments
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: High
    - Dependencies: receiving_records, users

11. **receiving_task_templates** - Task templates
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: Medium
    - Dependencies: None

12. **vendors** - Vendor information
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: High
    - Dependencies: branches

13. **vendor_payment_schedule** - Payment schedules
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: High
    - Dependencies: vendors

14. **requesters** - Request originators
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: Medium
    - Dependencies: None

#### Task Management (7 tables)
15. **tasks** - Main task records
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: Critical
    - Dependencies: users, branches

16. **task_assignments** - Task assignments
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: High
    - Dependencies: tasks, users

17. **task_completions** - Task completion records
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: High
    - Dependencies: tasks, users

18. **task_images** - Task attachments
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: Medium
    - Dependencies: tasks

19. **task_reminder_logs** - Reminder history
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: Low
    - Dependencies: tasks

20. **quick_tasks** - Quick task records
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: High
    - Dependencies: users, branches

21. **quick_task_assignments** - Quick task assignments
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: High
    - Dependencies: quick_tasks, users

#### Quick Tasks Details (3 tables)
22. **quick_task_comments** - Task comments
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: Medium
    - Dependencies: quick_tasks, users

23. **quick_task_completions** - Completion records
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: Medium
    - Dependencies: quick_tasks, users

24. **quick_task_files** - Task file attachments
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: Medium
    - Dependencies: quick_tasks

25. **quick_task_user_preferences** - User preferences
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: Low
    - Dependencies: users

#### Recurring Tasks & Audit (3 tables)
26. **recurring_assignment_schedules** - Recurring task schedules
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: Medium
    - Dependencies: users

27. **recurring_schedule_check_log** - Schedule check history
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: Low
    - Dependencies: recurring_assignment_schedules

28. **variation_audit_log** - Variation audit trail
    - DELETE: Yes
    - MIGRATE: Yes
    - Priority: Low
    - Dependencies: None

---

## Migration Order (Respecting Dependencies)

### Phase 1: Master Data (No dependencies)
1. requesters
2. receiving_task_templates
3. variation_audit_log
4. erp_daily_sales

### Phase 2: Vendor Data
5. vendors
6. vendor_payment_schedule

### Phase 3: User & Session Data
7. user_audit_logs
8. user_device_sessions
9. user_sessions

### Phase 4: HR & Biometric
10. hr_fingerprint_transactions

### Phase 5: Finance & Expenses
11. expense_scheduler
12. expense_requisitions
13. non_approved_payment_scheduler

### Phase 6: Receiving Operations
14. receiving_records
15. receiving_tasks

### Phase 7: Task Management (High Priority)
16. tasks
17. task_assignments
18. task_completions
19. task_images
20. task_reminder_logs

### Phase 8: Quick Tasks (High Priority)
21. quick_tasks
22. quick_task_assignments
23. quick_task_comments
24. quick_task_completions
25. quick_task_files
26. quick_task_user_preferences

### Phase 9: Recurring Tasks & Final
27. recurring_assignment_schedules
28. recurring_schedule_check_log

---

## SQL Migration Script Template (UPSERT)

For each table, use this pattern:

```sql
-- Step 1: Clear constraints temporarily (if needed)
ALTER TABLE [table_name] DISABLE TRIGGER ALL;

-- Step 2: UPSERT data from old Supabase
INSERT INTO [table_name] (column1, column2, column3, ...)
SELECT column1, column2, column3, ...
FROM [OLD_SUPABASE_REFERENCE].[table_name]
ON CONFLICT (id) DO UPDATE SET
  column1 = EXCLUDED.column1,
  column2 = EXCLUDED.column2,
  column3 = EXCLUDED.column3,
  -- ... all columns except id
  updated_at = NOW();

-- Step 3: Re-enable triggers
ALTER TABLE [table_name] ENABLE TRIGGER ALL;

-- Step 4: Verify
SELECT COUNT(*) as total_records FROM [table_name];
```

---

## Pre-Migration Checklist

- [ ] Backup old Supabase data (export as SQL)
- [ ] Backup new self-hosted Supabase (export as SQL)
- [ ] Verify both databases are accessible
- [ ] Confirm you have Service Role Keys for both
- [ ] Stop application (users offline during migration)
- [ ] Disable RLS temporarily (enable after all data migrated)
- [ ] Test migration on 1-2 tables first
- [ ] Verify data integrity (row counts match)

---

## Post-Migration Checklist

- [ ] Verify all 28 tables have data
- [ ] Check row counts match old Supabase
- [ ] Verify UUIDs are intact (no new IDs generated)
- [ ] Check foreign key relationships are valid
- [ ] Enable RLS policies on all tables
- [ ] Test with admin user account
- [ ] Test with regular user account
- [ ] Test with position-based user account
- [ ] Verify storage files migrated (if needed)
- [ ] Enable application for users

---

## Data Integrity Validation

After migration, run these checks:

```sql
-- Check 1: Verify row counts
SELECT COUNT(*) FROM receiving_records;  -- Should match old DB
SELECT COUNT(*) FROM tasks;               -- Should match old DB
SELECT COUNT(*) FROM quick_tasks;         -- Should match old DB

-- Check 2: Check for orphaned records (ForeignKey violations)
SELECT * FROM tasks WHERE assigned_to NOT IN (SELECT id FROM users);
SELECT * FROM receiving_records WHERE vendor_id NOT IN (SELECT id FROM vendors);

-- Check 3: Verify timestamps are preserved
SELECT MIN(created_at), MAX(created_at) FROM tasks;

-- Check 4: Check for NULL UUIDs (should be 0)
SELECT COUNT(*) FROM tasks WHERE id IS NULL;
```

---

## Rollback Plan (If Migration Fails)

If something goes wrong:

1. **Immediate:** Disable application
2. **Database:** Restore from backup SQL export
3. **Analyze:** Check error logs
4. **Fix:** Adjust migration scripts
5. **Retry:** Run migration again on clean database

---

## Notes

- ✅ UPSERT method preserves existing data + updates from old DB
- ✅ All UUIDs will remain the same (no ID conflicts)
- ✅ Foreign key relationships preserved automatically
- ✅ Timestamps (created_at, updated_at) preserved from old DB
- ✅ Can be done with zero downtime if UPSERT approach used (app can run during migration)
- ✅ RLS policies can be enabled after all data migrated

---

## Timeline Estimate

- Phase 1-2 (Master Data): 2-3 minutes
- Phase 3-5 (User/HR/Finance): 3-5 minutes
- Phase 6-9 (Tasks/Operations): 5-10 minutes
- **Total Expected Time:** 10-20 minutes (depending on data volume)

---

## Next Steps

1. **Confirm:** You're ready to proceed?
2. **Provide:** Old Supabase credentials (URL + Service Key)
3. **I'll create:** Complete migration Node.js scripts
4. **Execute:** Scripts in order
5. **Verify:** Data integrity
6. **Enable:** RLS policies

Ready to proceed? 🚀

