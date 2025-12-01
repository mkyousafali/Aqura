# EXACT 37 UNPROTECTED TABLES - DETAILED ACTION PLAN

**Generated:** December 1, 2025  
**Total Unprotected:** 37 tables (42% of database)

---

## 🔴 CRITICAL PRIORITY (2 Tables) - IMPLEMENT TODAY

### Financial Data (1 table - 1.98 MB)
1. **vendor_payment_schedule** (56 columns, 1984 kB)
   - Contains: Payment schedules, vendor financial data
   - Risk: Financial fraud, unauthorized payment approvals
   - **Action: IMMEDIATE**

### Customer Data (1 table - 112 KB)
2. **customer_app_media** (20 columns, 112 kB)
   - Contains: Customer uploaded media/content
   - Risk: Privacy violation, unauthorized access to customer files
   - **Action: IMMEDIATE**

**Total Critical Impact:** 2.09 MB of sensitive data exposed

---

## 🟡 HIGH PRIORITY (20 Tables) - IMPLEMENT THIS WEEK

### HR & Employee Data (11 tables - 1.26 MB)
3. **hr_employees** (7 columns, 136 kB) - Core employee records
4. **hr_fingerprint_transactions** (10 columns, 584 kB) - Attendance/biometric data
5. **hr_position_reporting_template** (9 columns, 136 kB) - Org structure
6. **hr_position_assignments** (9 columns, 112 kB) - Employee positions
7. **employee_warning_history** (11 columns, 112 kB) - Disciplinary records
8. **hr_positions** (7 columns, 64 kB) - Position definitions
9. **hr_employee_contacts** (7 columns, 40 kB) - Contact information
10. **hr_levels** (6 columns, 24 kB) - Organizational levels
11. **hr_departments** (5 columns, 24 kB) - Department structure
12. **hr_salary_components** (12 columns, 16 kB) - Salary breakdown
13. **hr_salary_wages** (7 columns, 16 kB) - Wage information

### Task Management (9 tables - 18.24 MB)
14. **receiving_tasks** (26 columns, 13 MB) - Receiving workflow tasks ⚠️ LARGEST
15. **receiving_records** (56 columns, 4368 kB) - Receiving transaction data
16. **quick_tasks** (17 columns, 192 kB) - Quick task system
17. **quick_task_assignments** (12 columns, 184 kB) - Task assignments
18. **quick_task_completions** (13 columns, 168 kB) - Task completion records
19. **receiving_task_templates** (13 columns, 112 kB) - Task templates
20. **quick_task_user_preferences** (9 columns, 80 kB) - User preferences
21. **quick_task_files** (10 columns, 64 kB) - Task attachments
22. **quick_task_comments** (6 columns, 32 kB) - Task comments

**Total High Priority Impact:** 19.5 MB of operational data exposed

---

## 🟢 MEDIUM PRIORITY (3 Tables) - IMPLEMENT WEEK 2

### Configuration Tables (3 tables - 1.13 MB)
23. **vendors** (34 columns, 944 kB) - Vendor master data
24. **branches** (26 columns, 112 kB) - Branch/location data
25. **app_functions** (8 columns, 80 kB) - System functions

**Total Medium Priority Impact:** 1.13 MB configuration data

---

## ⚪ LOW PRIORITY (12 Tables) - IMPLEMENT WEEK 3

### System & Audit Tables (12 tables - 16.12 MB)
26. **push_subscriptions** (14 columns, 8192 kB) - Push notification subscriptions
27. **user_audit_logs** (12 columns, 7384 kB) - User activity logs
28. **notification_queue** (19 columns, 6104 kB) - Notification queue
29. **user_sessions** (10 columns, 880 kB) - Session management
30. **notifications** (25 columns, 560 kB) - Notification records
31. **notification_recipients** (14 columns, 552 kB) - Notification targets
32. **users** (28 columns, 304 kB) - User accounts ⚠️ Should be HIGH but miscategorized
33. **role_permissions** (10 columns, 88 kB) - Permission definitions
34. **user_roles** (10 columns, 80 kB) - User role assignments
35. **recurring_assignment_schedules** (19 columns, 40 kB) - Recurring schedules
36. **notification_attachments** (8 columns, 32 kB) - Notification files
37. **user_password_history** (5 columns, 16 kB) - Password history

**Total Low Priority Impact:** 16.12 MB system data

⚠️ **NOTE:** `users`, `user_roles`, and `role_permissions` should be reclassified as HIGH PRIORITY!

---

## IMMEDIATE ACTION REQUIRED - TODAY

### Emergency Lockdown Script for 2 CRITICAL Tables

Run this in Supabase SQL Editor NOW:

```sql
-- ========================================
-- EMERGENCY LOCKDOWN - CRITICAL TABLES
-- ========================================

-- 1. VENDOR PAYMENT SCHEDULE (Financial Data)
ALTER TABLE vendor_payment_schedule ENABLE ROW LEVEL SECURITY;

CREATE POLICY "temp_lockdown_vendor_payment" ON vendor_payment_schedule
FOR ALL TO authenticated
USING (false);

COMMENT ON POLICY "temp_lockdown_vendor_payment" ON vendor_payment_schedule IS 
'TEMPORARY: Emergency lockdown until proper policies are implemented. Only service_role can access.';

-- 2. CUSTOMER APP MEDIA (Customer Data)
ALTER TABLE customer_app_media ENABLE ROW LEVEL SECURITY;

CREATE POLICY "temp_lockdown_customer_media" ON customer_app_media
FOR ALL TO authenticated
USING (false);

COMMENT ON POLICY "temp_lockdown_customer_media" ON customer_app_media IS 
'TEMPORARY: Emergency lockdown until proper policies are implemented. Only service_role can access.';

-- Verify RLS is enabled
SELECT 
    tablename, 
    rowsecurity as rls_enabled 
FROM pg_tables 
WHERE tablename IN ('vendor_payment_schedule', 'customer_app_media')
AND schemaname = 'public';
```

**Expected Result:** Both tables should show `rls_enabled = true`

**Test Your Apps:**
- ✅ Operations using `supabaseAdmin` should still work
- ✅ No user-facing features should break
- ⚠️ Direct user access to these tables should be blocked (intended)

---

## THIS WEEK: HIGH PRIORITY TABLES (20 Tables)

### Monday: User & Auth Tables (3 tables - RECLASSIFIED AS HIGH)

⚠️ **These were miscategorized as LOW but are actually CRITICAL:**

```sql
-- USER AUTHENTICATION TABLES (Monday Morning)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;

-- Temporary lockdown policies
CREATE POLICY "temp_lockdown_users" ON users FOR ALL TO authenticated USING (false);
CREATE POLICY "temp_lockdown_user_roles" ON user_roles FOR ALL TO authenticated USING (false);
CREATE POLICY "temp_lockdown_role_permissions" ON role_permissions FOR ALL TO authenticated USING (false);
```

### Monday: HR Tables (11 tables - 1.26 MB)

```sql
-- HR EMPLOYEE DATA (Monday Afternoon)
ALTER TABLE hr_employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_fingerprint_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_position_reporting_template ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_position_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_warning_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_employee_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_salary_components ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_salary_wages ENABLE ROW LEVEL SECURITY;

-- Batch create lockdown policies
DO $$
DECLARE
    tbl text;
    hr_tables text[] := ARRAY[
        'hr_employees', 'hr_fingerprint_transactions', 'hr_position_reporting_template',
        'hr_position_assignments', 'employee_warning_history', 'hr_positions',
        'hr_employee_contacts', 'hr_levels', 'hr_departments', 
        'hr_salary_components', 'hr_salary_wages'
    ];
BEGIN
    FOREACH tbl IN ARRAY hr_tables
    LOOP
        EXECUTE format('CREATE POLICY "temp_lockdown" ON %I FOR ALL TO authenticated USING (false)', tbl);
        RAISE NOTICE 'Locked down: %', tbl;
    END LOOP;
END $$;
```

### Tuesday-Wednesday: Task Management (9 tables - 18.24 MB)

```sql
-- TASK & RECEIVING TABLES (Tuesday-Wednesday)
ALTER TABLE receiving_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE receiving_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE receiving_task_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_comments ENABLE ROW LEVEL SECURITY;

-- Batch create lockdown policies
DO $$
DECLARE
    tbl text;
    task_tables text[] := ARRAY[
        'receiving_tasks', 'receiving_records', 'quick_tasks',
        'quick_task_assignments', 'quick_task_completions', 'receiving_task_templates',
        'quick_task_user_preferences', 'quick_task_files', 'quick_task_comments'
    ];
BEGIN
    FOREACH tbl IN ARRAY task_tables
    LOOP
        EXECUTE format('CREATE POLICY "temp_lockdown" ON %I FOR ALL TO authenticated USING (false)', tbl);
        RAISE NOTICE 'Locked down: %', tbl;
    END LOOP;
END $$;
```

---

## WEEK 2: MEDIUM PRIORITY (3 Tables)

```sql
-- CONFIGURATION TABLES
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_functions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "temp_lockdown" ON vendors FOR ALL TO authenticated USING (false);
CREATE POLICY "temp_lockdown" ON branches FOR ALL TO authenticated USING (false);
CREATE POLICY "temp_lockdown" ON app_functions FOR ALL TO authenticated USING (false);
```

---

## WEEK 3: LOW PRIORITY (9 Remaining Tables)

```sql
-- SYSTEM & NOTIFICATION TABLES
ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_assignment_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_password_history ENABLE ROW LEVEL SECURITY;

-- Batch lockdown
DO $$
DECLARE
    tbl text;
    system_tables text[] := ARRAY[
        'push_subscriptions', 'user_audit_logs', 'notification_queue',
        'user_sessions', 'notifications', 'notification_recipients',
        'recurring_assignment_schedules', 'notification_attachments', 'user_password_history'
    ];
BEGIN
    FOREACH tbl IN ARRAY system_tables
    LOOP
        EXECUTE format('CREATE POLICY "temp_lockdown" ON %I FOR ALL TO authenticated USING (false)', tbl);
        RAISE NOTICE 'Locked down: %', tbl;
    END LOOP;
END $$;
```

---

## PROPER POLICY DESIGN (After Emergency Lockdown)

### Example 1: vendor_payment_schedule

```sql
-- Remove temporary policy
DROP POLICY "temp_lockdown_vendor_payment" ON vendor_payment_schedule;

-- Policy 1: Branch managers can view schedules for their vendors
CREATE POLICY "branch_manager_view_vendor_payments" ON vendor_payment_schedule
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN vendors v ON v.branch_id = ur.branch_id
        WHERE ur.user_id = auth.uid()
        AND ur.role_name IN ('manager', 'admin')
        AND v.id = vendor_payment_schedule.vendor_id
    )
);

-- Policy 2: Finance team can approve payments
CREATE POLICY "finance_approve_payments" ON vendor_payment_schedule
FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM approval_permissions
        WHERE user_id = auth.uid()
        AND can_approve_vendor_payments = true
    )
);

-- Policy 3: Admins full access
CREATE POLICY "admin_full_access_vendor_payments" ON vendor_payment_schedule
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_id = auth.uid()
        AND role_name = 'admin'
    )
);
```

### Example 2: hr_employees

```sql
-- Remove temporary policy
DROP POLICY "temp_lockdown" ON hr_employees;

-- Policy 1: Employees can view their own record
CREATE POLICY "employees_view_own_record" ON hr_employees
FOR SELECT TO authenticated
USING (id::text = auth.uid()::text);

-- Policy 2: HR managers can view all employees
CREATE POLICY "hr_managers_view_all" ON hr_employees
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_id = auth.uid()
        AND role_name IN ('hr_manager', 'admin')
    )
);

-- Policy 3: Branch managers can view branch employees
CREATE POLICY "branch_managers_view_branch" ON hr_employees
FOR SELECT TO authenticated
USING (
    branch_id IN (
        SELECT branch_id FROM user_roles
        WHERE user_id = auth.uid()
        AND role_name = 'manager'
    )
);
```

### Example 3: quick_tasks

```sql
-- Remove temporary policy
DROP POLICY "temp_lockdown" ON quick_tasks;

-- Policy 1: View assigned tasks
CREATE POLICY "view_assigned_tasks" ON quick_tasks
FOR SELECT TO authenticated
USING (
    created_by = auth.uid()
    OR id IN (
        SELECT task_id FROM quick_task_assignments
        WHERE assigned_to = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_id = auth.uid()
        AND role_name IN ('admin', 'manager')
    )
);

-- Policy 2: Create tasks
CREATE POLICY "create_tasks" ON quick_tasks
FOR INSERT TO authenticated
WITH CHECK (created_by = auth.uid());

-- Policy 3: Update own tasks
CREATE POLICY "update_own_tasks" ON quick_tasks
FOR UPDATE TO authenticated
USING (created_by = auth.uid());
```

---

## VERIFICATION QUERIES

### Check RLS Status After Implementation

```sql
-- See which tables now have RLS
SELECT 
    tablename,
    rowsecurity as rls_enabled,
    COUNT(p.policyname) as policy_count
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename
WHERE t.schemaname = 'public'
AND t.tablename IN (
    'vendor_payment_schedule', 'customer_app_media',
    'users', 'user_roles', 'role_permissions',
    'hr_employees', 'hr_fingerprint_transactions', 'receiving_tasks',
    'quick_tasks', 'branches', 'vendors'
)
GROUP BY t.tablename, t.rowsecurity
ORDER BY t.tablename;
```

### Verify Policy Coverage

```sql
-- List all policies on protected tables
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

---

## SUCCESS METRICS

### End of Today
- [ ] 2 critical tables protected (vendor_payment_schedule, customer_app_media)
- [ ] Apps still functioning
- [ ] No security incidents

### End of Week 1
- [ ] 25 tables protected (2 critical + 23 high priority)
- [ ] 67% coverage (59/88 tables)
- [ ] Emergency lockdown complete

### End of Week 2
- [ ] 28 tables protected (add 3 medium)
- [ ] 72% coverage (62/88 tables)
- [ ] Begin proper policy design

### End of Week 3
- [ ] 37 tables protected (all remaining)
- [ ] 100% RLS coverage (88/88 tables)
- [ ] Proper policies implemented

---

## ROLLBACK PLAN

If any issues occur:

```sql
-- Disable RLS on specific table
ALTER TABLE [table_name] DISABLE ROW LEVEL SECURITY;

-- Or remove just the policy
DROP POLICY "temp_lockdown" ON [table_name];
```

---

## NEXT STEPS

1. **RIGHT NOW:** Run the emergency lockdown script for 2 critical tables
2. **Test:** Verify apps still work
3. **Monday:** Lock down user auth + HR tables (14 tables)
4. **Tuesday-Wednesday:** Lock down task management (9 tables)
5. **Next Week:** Implement proper policies

**Total Time Estimate:**
- Emergency lockdown: 30 minutes
- Week 1 lockdown: 4-6 hours
- Proper policies: 2-3 weeks

---

**Status:** 🔴 CRITICAL - BEGIN IMMEDIATELY  
**First Action:** Copy and run the emergency lockdown script above  
**Expected Impact:** Zero downtime, apps continue working via service_role
