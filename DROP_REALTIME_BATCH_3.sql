-- ============================================================================
-- DROP REALTIME_SUBSCRIPTION RLS POLICIES - BATCH 3 OF 4
-- ============================================================================
-- Tables 45-66 (offer_cart_tiers through recurring_assignment_schedules)
-- ============================================================================

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

SELECT COUNT(*) as batch_3_dropped FROM pg_policies WHERE policyname = 'realtime_subscription' AND tablename IN ('offer_cart_tiers', 'offer_products', 'offer_usage_logs', 'offers', 'order_audit_logs', 'order_items', 'orders', 'product_categories', 'product_units', 'products', 'push_subscriptions', 'quick_task_assignments', 'quick_task_comments', 'quick_task_completions', 'quick_task_files', 'quick_task_user_preferences', 'quick_tasks', 'receiving_records', 'receiving_task_templates', 'receiving_tasks', 'recurring_assignment_schedules');
