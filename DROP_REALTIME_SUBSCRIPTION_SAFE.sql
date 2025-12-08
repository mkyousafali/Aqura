-- ============================================================================
-- DROP REALTIME_SUBSCRIPTION RLS POLICIES - ALL 88 TABLES
-- ============================================================================
-- Execute this entire script in Supabase SQL Editor
-- If deadlock occurs, kill idle connections and retry
-- ============================================================================

DROP POLICY IF EXISTS "realtime_subscription" ON app_functions;
DROP POLICY IF EXISTS "realtime_subscription" ON approval_permissions;
DROP POLICY IF EXISTS "realtime_subscription" ON biometric_connections;
DROP POLICY IF EXISTS "realtime_subscription" ON bogo_offer_rules;
DROP POLICY IF EXISTS "realtime_subscription" ON branches;
DROP POLICY IF EXISTS "realtime_subscription" ON coupon_campaigns;
DROP POLICY IF EXISTS "realtime_subscription" ON coupon_claims;
DROP POLICY IF EXISTS "realtime_subscription" ON coupon_eligible_customers;
DROP POLICY IF EXISTS "realtime_subscription" ON coupon_products;
DROP POLICY IF EXISTS "realtime_subscription" ON customer_access_code_history;
DROP POLICY IF EXISTS "realtime_subscription" ON customer_app_media;
DROP POLICY IF EXISTS "realtime_subscription" ON customer_recovery_requests;
DROP POLICY IF EXISTS "realtime_subscription" ON customers;
DROP POLICY IF EXISTS "realtime_subscription" ON deleted_bundle_offers;
DROP POLICY IF EXISTS "realtime_subscription" ON delivery_fee_tiers;
DROP POLICY IF EXISTS "realtime_subscription" ON delivery_service_settings;
DROP POLICY IF EXISTS "realtime_subscription" ON employee_fine_payments;
DROP POLICY IF EXISTS "realtime_subscription" ON employee_warning_history;
DROP POLICY IF EXISTS "realtime_subscription" ON employee_warnings;
DROP POLICY IF EXISTS "realtime_subscription" ON erp_connections;
DROP POLICY IF EXISTS "realtime_subscription" ON erp_daily_sales;
DROP POLICY IF EXISTS "realtime_subscription" ON expense_parent_categories;
DROP POLICY IF EXISTS "realtime_subscription" ON expense_requisitions;
DROP POLICY IF EXISTS "realtime_subscription" ON expense_scheduler;
DROP POLICY IF EXISTS "realtime_subscription" ON expense_sub_categories;
DROP POLICY IF EXISTS "realtime_subscription" ON flyer_offer_products;
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
DROP POLICY IF EXISTS "realtime_subscription" ON offer_cart_tiers;
DROP POLICY IF EXISTS "realtime_subscription" ON offer_products;
DROP POLICY IF EXISTS "realtime_subscription" ON offer_usage_logs;
DROP POLICY IF EXISTS "realtime_subscription" ON offers;
DROP POLICY IF EXISTS "realtime_subscription" ON order_audit_logs;
DROP POLICY IF EXISTS "realtime_subscription" ON order_items;
DROP POLICY IF EXISTS "realtime_subscription" ON orders;
DROP POLICY IF EXISTS "realtime_subscription" ON product_categories;
DROP POLICY IF EXISTS "realtime_subscription" ON product_units;
DROP POLICY IF EXISTS "realtime_subscription" ON products;
DROP POLICY IF EXISTS "realtime_subscription" ON push_subscriptions;
DROP POLICY IF EXISTS "realtime_subscription" ON quick_task_assignments;
DROP POLICY IF EXISTS "realtime_subscription" ON quick_task_comments;
DROP POLICY IF EXISTS "realtime_subscription" ON quick_task_completions;
DROP POLICY IF EXISTS "realtime_subscription" ON quick_task_files;
DROP POLICY IF EXISTS "realtime_subscription" ON quick_task_user_preferences;
DROP POLICY IF EXISTS "realtime_subscription" ON quick_tasks;
DROP POLICY IF EXISTS "realtime_subscription" ON receiving_records;
DROP POLICY IF EXISTS "realtime_subscription" ON receiving_task_templates;
DROP POLICY IF EXISTS "realtime_subscription" ON receiving_tasks;
DROP POLICY IF EXISTS "realtime_subscription" ON recurring_assignment_schedules;
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

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check remaining realtime_subscription policies (should return 0 rows)
SELECT 
  schemaname,
  tablename,
  policyname
FROM pg_policies
WHERE policyname = 'realtime_subscription'
ORDER BY tablename;

-- Count total remaining policies (should return 0)
SELECT COUNT(*) as total_remaining FROM pg_policies WHERE policyname = 'realtime_subscription';
