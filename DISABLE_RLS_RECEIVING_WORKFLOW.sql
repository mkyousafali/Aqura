-- Disable RLS on all tables related to receiving workflow
-- This ensures the entire receiving process works without RLS permission issues

-- Primary receiving tables
ALTER TABLE receiving_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE receiving_tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE receiving_items DISABLE ROW LEVEL SECURITY;

-- Related tables referenced by receiving
ALTER TABLE vendor_payment_schedule DISABLE ROW LEVEL SECURITY;
ALTER TABLE vendors DISABLE ROW LEVEL SECURITY;
ALTER TABLE branches DISABLE ROW LEVEL SECURITY;
ALTER TABLE employees DISABLE ROW LEVEL SECURITY;

-- Task and approval related tables
ALTER TABLE tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE approvals DISABLE ROW LEVEL SECURITY;
ALTER TABLE approval_workflows DISABLE ROW LEVEL SECURITY;

-- Verify all RLS status
SELECT 
  tablename,
  rowsecurity as "RLS Enabled"
FROM pg_tables 
WHERE tablename IN (
  'receiving_records', 'receiving_tasks', 'receiving_items',
  'vendor_payment_schedule', 'vendors', 'branches', 'employees',
  'tasks', 'approvals', 'approval_workflows'
)
ORDER BY tablename;
