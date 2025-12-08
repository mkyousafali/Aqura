-- ============================================================================
-- DROP REALTIME_SUBSCRIPTION RLS POLICIES - BATCH 1 OF 4
-- ============================================================================
-- Tables 1-22 (app_functions through flyer_templates)
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
DROP POLICY IF EXISTS "realtime_subscription" ON flyer_offer_products;

SELECT COUNT(*) as batch_1_dropped FROM pg_policies WHERE policyname = 'realtime_subscription' AND tablename IN ('app_functions', 'approval_permissions', 'biometric_connections', 'bogo_offer_rules', 'branches', 'coupon_campaigns', 'coupon_claims', 'coupon_eligible_customers', 'coupon_products', 'customer_access_code_history', 'customer_app_media', 'customer_recovery_requests', 'customers', 'deleted_bundle_offers', 'delivery_fee_tiers', 'delivery_service_settings', 'employee_fine_payments', 'employee_warning_history', 'employee_warnings', 'erp_connections', 'erp_daily_sales', 'flyer_offer_products');
