-- ============================================================================
-- DROP REALTIME_SUBSCRIPTION RLS POLICIES - BATCH 2 OF 4
-- ============================================================================
-- Tables 23-44 (flyer_offers through non_approved_payment_scheduler)
-- ============================================================================

DROP POLICY IF EXISTS "realtime_subscription" ON flyer_offers;
DROP POLICY IF EXISTS "realtime_subscription" ON flyer_products;
DROP POLICY IF EXISTS "realtime_subscription" ON flyer_templates;
DROP POLICY IF EXISTS "realtime_subscription" ON hr_departments;
DROP POLICY IF EXISTS "realtime_subscription" ON hr_employee_contacts;
DROP POLICY IF EXISTS "realtime_subscription" ON hr_employee_documents;
DROP POLICY IF EXISTS "realtime_subscription" ON hr_employees;
DROP POLICY IF EXISTS "realtime_subscription" ON hr_fingerprint_transactions;
DROP POLICY IF EXISTS "realtime_subscription" ON hr_levels;
DROP POLICY IF EXISTS "realtime_subscription" ON hr_position_assignments;
DROP POLICY IF EXISTS "realtime_subscription" ON hr_position_reporting_template;
DROP POLICY IF EXISTS "realtime_subscription" ON hr_positions;
DROP POLICY IF EXISTS "realtime_subscription" ON hr_salary_components;
DROP POLICY IF EXISTS "realtime_subscription" ON hr_salary_wages;
DROP POLICY IF EXISTS "realtime_subscription" ON interface_permissions;
DROP POLICY IF EXISTS "realtime_subscription" ON non_approved_payment_scheduler;
DROP POLICY IF EXISTS "realtime_subscription" ON notification_attachments;
DROP POLICY IF EXISTS "realtime_subscription" ON notification_queue;
DROP POLICY IF EXISTS "realtime_subscription" ON notification_read_states;
DROP POLICY IF EXISTS "realtime_subscription" ON notification_recipients;
DROP POLICY IF EXISTS "realtime_subscription" ON notifications;
DROP POLICY IF EXISTS "realtime_subscription" ON offer_bundles;

SELECT COUNT(*) as batch_2_dropped FROM pg_policies WHERE policyname = 'realtime_subscription' AND tablename IN ('flyer_offers', 'flyer_products', 'flyer_templates', 'hr_departments', 'hr_employee_contacts', 'hr_employee_documents', 'hr_employees', 'hr_fingerprint_transactions', 'hr_levels', 'hr_position_assignments', 'hr_position_reporting_template', 'hr_positions', 'hr_salary_components', 'hr_salary_wages', 'interface_permissions', 'non_approved_payment_scheduler', 'notification_attachments', 'notification_queue', 'notification_read_states', 'notification_recipients', 'notifications', 'offer_bundles');
