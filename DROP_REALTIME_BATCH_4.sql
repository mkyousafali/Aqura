-- ============================================================================
-- DROP REALTIME_SUBSCRIPTION RLS POLICIES - BATCH 4 OF 4
-- ============================================================================
-- Tables 67-88 (recurring_schedule_check_log through vendors)
-- ============================================================================

DROP POLICY IF EXISTS "realtime_subscription" ON recurring_schedule_check_log;
DROP POLICY IF EXISTS "realtime_subscription" ON requesters;
DROP POLICY IF EXISTS "realtime_subscription" ON role_permissions;
DROP POLICY IF EXISTS "realtime_subscription" ON shelf_paper_templates;
DROP POLICY IF EXISTS "realtime_subscription" ON task_assignments;
DROP POLICY IF EXISTS "realtime_subscription" ON task_completions;
DROP POLICY IF EXISTS "realtime_subscription" ON task_images;
DROP POLICY IF EXISTS "realtime_subscription" ON task_reminder_logs;
DROP POLICY IF EXISTS "realtime_subscription" ON tasks;
DROP POLICY IF EXISTS "realtime_subscription" ON tax_categories;
DROP POLICY IF EXISTS "realtime_subscription" ON user_audit_logs;
DROP POLICY IF EXISTS "realtime_subscription" ON user_device_sessions;
DROP POLICY IF EXISTS "realtime_subscription" ON user_password_history;
DROP POLICY IF EXISTS "realtime_subscription" ON user_roles;
DROP POLICY IF EXISTS "realtime_subscription" ON user_sessions;
DROP POLICY IF EXISTS "realtime_subscription" ON users;
DROP POLICY IF EXISTS "realtime_subscription" ON variation_audit_log;
DROP POLICY IF EXISTS "realtime_subscription" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "realtime_subscription" ON vendors;
DROP POLICY IF EXISTS "realtime_subscription" ON expense_parent_categories;
DROP POLICY IF EXISTS "realtime_subscription" ON expense_requisitions;
DROP POLICY IF EXISTS "realtime_subscription" ON expense_scheduler;

SELECT COUNT(*) as batch_4_dropped FROM pg_policies WHERE policyname = 'realtime_subscription' AND tablename IN ('recurring_schedule_check_log', 'requesters', 'role_permissions', 'shelf_paper_templates', 'task_assignments', 'task_completions', 'task_images', 'task_reminder_logs', 'tasks', 'tax_categories', 'user_audit_logs', 'user_device_sessions', 'user_password_history', 'user_roles', 'user_sessions', 'users', 'variation_audit_log', 'vendor_payment_schedule', 'vendors', 'expense_parent_categories', 'expense_requisitions', 'expense_scheduler');
