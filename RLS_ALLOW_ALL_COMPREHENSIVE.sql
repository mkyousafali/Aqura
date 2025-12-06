-- ============================================================================
-- NUCLEAR RESET: ALLOW ALL OPERATIONS ON ALL TABLES AND STORAGE
-- ============================================================================
-- Purpose: Drop all restrictive RLS policies and allow everyone access
-- Use case: Development/Testing - NOT for production
-- ============================================================================

-- ============================================================================
-- PART 1: DISABLE RLS ON ALL TABLES (Clean slate)
-- ============================================================================

ALTER TABLE app_functions DISABLE ROW LEVEL SECURITY;
ALTER TABLE approval_permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE biometric_connections DISABLE ROW LEVEL SECURITY;
ALTER TABLE bogo_offer_rules DISABLE ROW LEVEL SECURITY;
ALTER TABLE branches DISABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_campaigns DISABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_claims DISABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_eligible_customers DISABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_products DISABLE ROW LEVEL SECURITY;
ALTER TABLE customer_access_code_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE customer_app_media DISABLE ROW LEVEL SECURITY;
ALTER TABLE customer_recovery_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE customers DISABLE ROW LEVEL SECURITY;
ALTER TABLE deleted_bundle_offers DISABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_fee_tiers DISABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_service_settings DISABLE ROW LEVEL SECURITY;
ALTER TABLE employee_fine_payments DISABLE ROW LEVEL SECURITY;
ALTER TABLE employee_warning_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE employee_warnings DISABLE ROW LEVEL SECURITY;
ALTER TABLE erp_connections DISABLE ROW LEVEL SECURITY;
ALTER TABLE erp_daily_sales DISABLE ROW LEVEL SECURITY;
ALTER TABLE expense_parent_categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE expense_requisitions DISABLE ROW LEVEL SECURITY;
ALTER TABLE expense_scheduler DISABLE ROW LEVEL SECURITY;
ALTER TABLE expense_sub_categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE flyer_offer_products DISABLE ROW LEVEL SECURITY;
ALTER TABLE flyer_offers DISABLE ROW LEVEL SECURITY;
ALTER TABLE flyer_products DISABLE ROW LEVEL SECURITY;
ALTER TABLE flyer_templates DISABLE ROW LEVEL SECURITY;
ALTER TABLE hr_departments DISABLE ROW LEVEL SECURITY;
ALTER TABLE hr_employee_contacts DISABLE ROW LEVEL SECURITY;
ALTER TABLE hr_employee_documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE hr_employees DISABLE ROW LEVEL SECURITY;
ALTER TABLE hr_fingerprint_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE hr_levels DISABLE ROW LEVEL SECURITY;
ALTER TABLE hr_position_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE hr_position_reporting_template DISABLE ROW LEVEL SECURITY;
ALTER TABLE hr_positions DISABLE ROW LEVEL SECURITY;
ALTER TABLE hr_salary_components DISABLE ROW LEVEL SECURITY;
ALTER TABLE hr_salary_wages DISABLE ROW LEVEL SECURITY;
ALTER TABLE interface_permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE non_approved_payment_scheduler DISABLE ROW LEVEL SECURITY;
ALTER TABLE notification_attachments DISABLE ROW LEVEL SECURITY;
ALTER TABLE notification_queue DISABLE ROW LEVEL SECURITY;
ALTER TABLE notification_read_states DISABLE ROW LEVEL SECURITY;
ALTER TABLE notification_recipients DISABLE ROW LEVEL SECURITY;
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE offer_bundles DISABLE ROW LEVEL SECURITY;
ALTER TABLE offer_cart_tiers DISABLE ROW LEVEL SECURITY;
ALTER TABLE offer_products DISABLE ROW LEVEL SECURITY;
ALTER TABLE offer_usage_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE offers DISABLE ROW LEVEL SECURITY;
ALTER TABLE order_audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE order_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE product_categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE product_units DISABLE ROW LEVEL SECURITY;
ALTER TABLE products DISABLE ROW LEVEL SECURITY;
ALTER TABLE push_subscriptions DISABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_comments DISABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_completions DISABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_files DISABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_user_preferences DISABLE ROW LEVEL SECURITY;
ALTER TABLE quick_tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE receiving_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE receiving_task_templates DISABLE ROW LEVEL SECURITY;
ALTER TABLE receiving_tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_assignment_schedules DISABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_schedule_check_log DISABLE ROW LEVEL SECURITY;
ALTER TABLE requesters DISABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE shelf_paper_templates DISABLE ROW LEVEL SECURITY;
ALTER TABLE task_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE task_completions DISABLE ROW LEVEL SECURITY;
ALTER TABLE task_images DISABLE ROW LEVEL SECURITY;
ALTER TABLE task_reminder_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE tax_categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_device_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_password_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE variation_audit_log DISABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_payment_schedule DISABLE ROW LEVEL SECURITY;
ALTER TABLE vendors DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PART 2: RE-ENABLE RLS ON ALL TABLES
-- ============================================================================

ALTER TABLE app_functions ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE biometric_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE bogo_offer_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_eligible_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_access_code_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_app_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_recovery_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE deleted_bundle_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_fee_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_service_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_fine_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_warning_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_warnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE erp_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE erp_daily_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_parent_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_requisitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_scheduler ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_sub_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE flyer_offer_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE flyer_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE flyer_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE flyer_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_employee_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_employee_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_fingerprint_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_position_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_position_reporting_template ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_salary_components ENABLE ROW LEVEL SECURITY;
ALTER TABLE hr_salary_wages ENABLE ROW LEVEL SECURITY;
ALTER TABLE interface_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE non_approved_payment_scheduler ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_read_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_bundles ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_cart_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE receiving_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE receiving_task_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE receiving_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_assignment_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_schedule_check_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE requesters ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE shelf_paper_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_reminder_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE tax_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_device_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_password_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE variation_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_payment_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PART 3: CREATE "ALLOW ALL" POLICY FOR EVERY TABLE
-- ============================================================================

CREATE POLICY "allow_all_operations" ON app_functions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON approval_permissions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON biometric_connections FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON bogo_offer_rules FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON branches FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON coupon_campaigns FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON coupon_claims FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON coupon_eligible_customers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON coupon_products FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON customer_access_code_history FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON customer_app_media FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON customer_recovery_requests FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON customers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON deleted_bundle_offers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON delivery_fee_tiers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON delivery_service_settings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON employee_fine_payments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON employee_warning_history FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON employee_warnings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON erp_connections FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON erp_daily_sales FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON expense_parent_categories FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON expense_requisitions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON expense_scheduler FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON expense_sub_categories FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON flyer_offer_products FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON flyer_offers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON flyer_products FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON flyer_templates FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON hr_departments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON hr_employee_contacts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON hr_employee_documents FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON hr_employees FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON hr_fingerprint_transactions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON hr_levels FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON hr_position_assignments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON hr_position_reporting_template FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON hr_positions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON hr_salary_components FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON hr_salary_wages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON interface_permissions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON non_approved_payment_scheduler FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON notification_attachments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON notification_queue FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON notification_read_states FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON notification_recipients FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON notifications FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON offer_bundles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON offer_cart_tiers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON offer_products FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON offer_usage_logs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON offers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON order_audit_logs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON order_items FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON orders FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON product_categories FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON product_units FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON products FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON push_subscriptions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON quick_task_assignments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON quick_task_comments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON quick_task_completions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON quick_task_files FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON quick_task_user_preferences FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON quick_tasks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON receiving_records FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON receiving_task_templates FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON receiving_tasks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON recurring_assignment_schedules FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON recurring_schedule_check_log FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON requesters FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON role_permissions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON shelf_paper_templates FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON task_assignments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON task_completions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON task_images FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON task_reminder_logs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON tasks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON tax_categories FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON user_audit_logs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON user_device_sessions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON user_password_history FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON user_roles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON user_sessions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON variation_audit_log FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON vendor_payment_schedule FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_operations" ON vendors FOR ALL USING (true) WITH CHECK (true);

-- ============================================================================
-- PART 4: STORAGE BUCKET POLICIES
-- ============================================================================

-- Allow all access to storage.objects
DROP POLICY IF EXISTS "anon_storage_access" ON storage.objects;
DROP POLICY IF EXISTS "authenticated_storage_access" ON storage.objects;

CREATE POLICY "allow_all_storage" ON storage.objects 
  FOR ALL 
  USING (true) 
  WITH CHECK (true);

-- ============================================================================
-- PART 5: VERIFICATION
-- ============================================================================

SELECT 
  COUNT(*) as total_policies
FROM pg_policies
WHERE schemaname = 'public';

-- ============================================================================
-- DONE! 
-- ============================================================================
-- ✅ All 88 tables: RLS ENABLED with "ALLOW ALL" policy
-- ✅ Storage: RLS ENABLED with "ALLOW ALL" policy
-- ✅ Now test the INSERT again - should work!
-- ============================================================================
