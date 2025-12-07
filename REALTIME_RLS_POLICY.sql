-- ============================================================================
-- REALTIME SUBSCRIPTION RLS POLICIES
-- ============================================================================
-- Date: December 7, 2025
-- Purpose: Enable real-time subscriptions for authenticated users
-- Strategy: Add a new "realtime_subscription" policy for all 88 tables
-- Note: This policy is ADDED to existing policies (not replacing them)
-- ============================================================================

-- ============================================================================
-- PART 1: CREATE REALTIME SUBSCRIPTION POLICY FOR ALL 88 TABLES
-- ============================================================================
-- Pattern: For each table, create a policy that allows authenticated users
-- to subscribe to real-time changes without needing full data access
-- ============================================================================

-- Real-time subscription policies (allows subscriptions for authenticated users)
CREATE POLICY "realtime_subscription" ON app_functions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON approval_permissions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON biometric_connections FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON bogo_offer_rules FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON branches FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON coupon_campaigns FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON coupon_claims FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON coupon_eligible_customers FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON coupon_products FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON customer_access_code_history FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON customer_app_media FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON customer_recovery_requests FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON customers FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON deleted_bundle_offers FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON delivery_fee_tiers FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON delivery_service_settings FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON employee_fine_payments FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON employee_warning_history FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON employee_warnings FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON erp_connections FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON erp_daily_sales FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON expense_parent_categories FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON expense_requisitions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON expense_scheduler FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON expense_sub_categories FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON flyer_offer_products FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON flyer_offers FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON flyer_products FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON flyer_templates FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON hr_departments FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON hr_employee_contacts FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON hr_employee_documents FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON hr_employees FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON hr_fingerprint_transactions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON hr_levels FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON hr_position_assignments FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON hr_position_reporting_template FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON hr_positions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON hr_salary_components FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON hr_salary_wages FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON interface_permissions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON non_approved_payment_scheduler FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON notification_attachments FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON notification_queue FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON notification_read_states FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON notification_recipients FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON notifications FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON offer_bundles FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON offer_cart_tiers FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON offer_products FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON offer_usage_logs FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON offers FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON order_audit_logs FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON order_items FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON orders FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON product_categories FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON product_units FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON products FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON push_subscriptions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON quick_task_assignments FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON quick_task_comments FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON quick_task_completions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON quick_task_files FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON quick_task_user_preferences FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON quick_tasks FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON receiving_records FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON receiving_task_templates FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON receiving_tasks FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON recurring_assignment_schedules FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON recurring_schedule_check_log FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON requesters FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON role_permissions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON shelf_paper_templates FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON task_assignments FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON task_completions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON task_images FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON task_reminder_logs FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON tasks FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON tax_categories FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON user_audit_logs FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON user_device_sessions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON user_password_history FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON user_roles FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON user_sessions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON users FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON variation_audit_log FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON vendor_payment_schedule FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "realtime_subscription" ON vendors FOR SELECT USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- PART 2: VERIFICATION
-- ============================================================================

-- Verify the new realtime_subscription policy exists on a few sample tables
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  qual as condition
FROM pg_policies
WHERE policyname = 'realtime_subscription'
ORDER BY tablename
LIMIT 10;

-- Count total policies
SELECT COUNT(*) as total_realtime_policies FROM pg_policies WHERE policyname = 'realtime_subscription';

-- ============================================================================
-- IMPORTANT NOTES
-- ============================================================================
--
-- What was changed:
-- ✅ Added a new "realtime_subscription" policy for all 88 tables
-- ✅ This policy allows authenticated users (auth.uid() IS NOT NULL) to subscribe
-- ✅ The policy uses SELECT operation only (read permission for subscriptions)
-- ✅ Existing policies (anon_full_access, authenticated_full_access) are NOT removed
--
-- Why this fixes real-time subscriptions:
-- - Real-time channels require a READ policy even if data access is allowed
-- - The new policy grants SELECT permission specifically for subscriptions
-- - Works with existing full-access policies for backward compatibility
--
-- Testing:
-- 1. Check Supabase Realtime in SQL Editor
-- 2. Run: SELECT * FROM receiving_records LIMIT 1;  -- Should work
-- 3. Monitor console for CHANNEL_ERROR - should be gone
-- 4. Open ReceivingDataWindow - real-time should auto-subscribe
--
-- If issues persist:
-- - Check that Supabase Realtime is ENABLED in table settings
-- - Ensure RLS is ENABLED on the table
-- - Verify user is authenticated (not anon)
-- - Check browser console for errors
--
-- ============================================================================
