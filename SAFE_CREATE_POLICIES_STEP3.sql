-- STEP 3: CREATE UNIVERSAL POLICIES ON ALL TABLES
-- Run this AFTER Step 2 completes

-- Create policies for each table
CREATE POLICY "allow_select" ON app_functions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON app_functions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON app_functions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON app_functions FOR DELETE USING (true);

CREATE POLICY "allow_select" ON approval_permissions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON approval_permissions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON approval_permissions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON approval_permissions FOR DELETE USING (true);

CREATE POLICY "allow_select" ON biometric_connections FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON biometric_connections FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON biometric_connections FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON biometric_connections FOR DELETE USING (true);

CREATE POLICY "allow_select" ON bogo_offer_rules FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON bogo_offer_rules FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON bogo_offer_rules FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON bogo_offer_rules FOR DELETE USING (true);

CREATE POLICY "allow_select" ON branches FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON branches FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON branches FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON branches FOR DELETE USING (true);

CREATE POLICY "allow_select" ON coupon_campaigns FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON coupon_campaigns FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON coupon_campaigns FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON coupon_campaigns FOR DELETE USING (true);

CREATE POLICY "allow_select" ON coupon_claims FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON coupon_claims FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON coupon_claims FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON coupon_claims FOR DELETE USING (true);

CREATE POLICY "allow_select" ON coupon_eligible_customers FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON coupon_eligible_customers FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON coupon_eligible_customers FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON coupon_eligible_customers FOR DELETE USING (true);

CREATE POLICY "allow_select" ON coupon_products FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON coupon_products FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON coupon_products FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON coupon_products FOR DELETE USING (true);

CREATE POLICY "allow_select" ON customer_access_code_history FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON customer_access_code_history FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON customer_access_code_history FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON customer_access_code_history FOR DELETE USING (true);

CREATE POLICY "allow_select" ON customer_app_media FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON customer_app_media FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON customer_app_media FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON customer_app_media FOR DELETE USING (true);

CREATE POLICY "allow_select" ON customer_recovery_requests FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON customer_recovery_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON customer_recovery_requests FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON customer_recovery_requests FOR DELETE USING (true);

CREATE POLICY "allow_select" ON customers FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON customers FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON customers FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON customers FOR DELETE USING (true);

CREATE POLICY "allow_select" ON deleted_bundle_offers FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON deleted_bundle_offers FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON deleted_bundle_offers FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON deleted_bundle_offers FOR DELETE USING (true);

CREATE POLICY "allow_select" ON delivery_fee_tiers FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON delivery_fee_tiers FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON delivery_fee_tiers FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON delivery_fee_tiers FOR DELETE USING (true);

CREATE POLICY "allow_select" ON delivery_service_settings FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON delivery_service_settings FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON delivery_service_settings FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON delivery_service_settings FOR DELETE USING (true);

CREATE POLICY "allow_select" ON employee_fine_payments FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON employee_fine_payments FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON employee_fine_payments FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON employee_fine_payments FOR DELETE USING (true);

CREATE POLICY "allow_select" ON employee_warning_history FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON employee_warning_history FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON employee_warning_history FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON employee_warning_history FOR DELETE USING (true);

CREATE POLICY "allow_select" ON employee_warnings FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON employee_warnings FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON employee_warnings FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON employee_warnings FOR DELETE USING (true);

CREATE POLICY "allow_select" ON erp_connections FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON erp_connections FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON erp_connections FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON erp_connections FOR DELETE USING (true);

CREATE POLICY "allow_select" ON erp_daily_sales FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON erp_daily_sales FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON erp_daily_sales FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON erp_daily_sales FOR DELETE USING (true);

CREATE POLICY "allow_select" ON expense_parent_categories FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON expense_parent_categories FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON expense_parent_categories FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON expense_parent_categories FOR DELETE USING (true);

CREATE POLICY "allow_select" ON expense_requisitions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON expense_requisitions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON expense_requisitions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON expense_requisitions FOR DELETE USING (true);

CREATE POLICY "allow_select" ON expense_scheduler FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON expense_scheduler FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON expense_scheduler FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON expense_scheduler FOR DELETE USING (true);

CREATE POLICY "allow_select" ON expense_sub_categories FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON expense_sub_categories FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON expense_sub_categories FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON expense_sub_categories FOR DELETE USING (true);

CREATE POLICY "allow_select" ON flyer_offer_products FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON flyer_offer_products FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON flyer_offer_products FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON flyer_offer_products FOR DELETE USING (true);

CREATE POLICY "allow_select" ON flyer_offers FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON flyer_offers FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON flyer_offers FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON flyer_offers FOR DELETE USING (true);

CREATE POLICY "allow_select" ON flyer_products FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON flyer_products FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON flyer_products FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON flyer_products FOR DELETE USING (true);

CREATE POLICY "allow_select" ON flyer_templates FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON flyer_templates FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON flyer_templates FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON flyer_templates FOR DELETE USING (true);

CREATE POLICY "allow_select" ON hr_departments FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON hr_departments FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON hr_departments FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON hr_departments FOR DELETE USING (true);

CREATE POLICY "allow_select" ON hr_employee_contacts FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON hr_employee_contacts FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON hr_employee_contacts FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON hr_employee_contacts FOR DELETE USING (true);

CREATE POLICY "allow_select" ON hr_employee_documents FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON hr_employee_documents FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON hr_employee_documents FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON hr_employee_documents FOR DELETE USING (true);

CREATE POLICY "allow_select" ON hr_employees FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON hr_employees FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON hr_employees FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON hr_employees FOR DELETE USING (true);

CREATE POLICY "allow_select" ON hr_fingerprint_transactions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON hr_fingerprint_transactions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON hr_fingerprint_transactions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON hr_fingerprint_transactions FOR DELETE USING (true);

CREATE POLICY "allow_select" ON hr_levels FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON hr_levels FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON hr_levels FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON hr_levels FOR DELETE USING (true);

CREATE POLICY "allow_select" ON hr_position_assignments FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON hr_position_assignments FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON hr_position_assignments FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON hr_position_assignments FOR DELETE USING (true);

CREATE POLICY "allow_select" ON hr_position_reporting_template FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON hr_position_reporting_template FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON hr_position_reporting_template FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON hr_position_reporting_template FOR DELETE USING (true);

CREATE POLICY "allow_select" ON hr_positions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON hr_positions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON hr_positions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON hr_positions FOR DELETE USING (true);

CREATE POLICY "allow_select" ON hr_salary_components FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON hr_salary_components FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON hr_salary_components FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON hr_salary_components FOR DELETE USING (true);

CREATE POLICY "allow_select" ON hr_salary_wages FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON hr_salary_wages FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON hr_salary_wages FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON hr_salary_wages FOR DELETE USING (true);

CREATE POLICY "allow_select" ON interface_permissions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON interface_permissions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON interface_permissions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON interface_permissions FOR DELETE USING (true);

CREATE POLICY "allow_select" ON non_approved_payment_scheduler FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON non_approved_payment_scheduler FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON non_approved_payment_scheduler FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON non_approved_payment_scheduler FOR DELETE USING (true);

CREATE POLICY "allow_select" ON notification_attachments FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON notification_attachments FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON notification_attachments FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON notification_attachments FOR DELETE USING (true);

CREATE POLICY "allow_select" ON notification_queue FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON notification_queue FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON notification_queue FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON notification_queue FOR DELETE USING (true);

CREATE POLICY "allow_select" ON notification_read_states FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON notification_read_states FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON notification_read_states FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON notification_read_states FOR DELETE USING (true);

CREATE POLICY "allow_select" ON notification_recipients FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON notification_recipients FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON notification_recipients FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON notification_recipients FOR DELETE USING (true);

CREATE POLICY "allow_select" ON notifications FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON notifications FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON notifications FOR DELETE USING (true);

CREATE POLICY "allow_select" ON offer_bundles FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON offer_bundles FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON offer_bundles FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON offer_bundles FOR DELETE USING (true);

CREATE POLICY "allow_select" ON offer_cart_tiers FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON offer_cart_tiers FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON offer_cart_tiers FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON offer_cart_tiers FOR DELETE USING (true);

CREATE POLICY "allow_select" ON offer_products FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON offer_products FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON offer_products FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON offer_products FOR DELETE USING (true);

CREATE POLICY "allow_select" ON offer_usage_logs FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON offer_usage_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON offer_usage_logs FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON offer_usage_logs FOR DELETE USING (true);

CREATE POLICY "allow_select" ON offers FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON offers FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON offers FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON offers FOR DELETE USING (true);

CREATE POLICY "allow_select" ON order_audit_logs FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON order_audit_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON order_audit_logs FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON order_audit_logs FOR DELETE USING (true);

CREATE POLICY "allow_select" ON order_items FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON order_items FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON order_items FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON order_items FOR DELETE USING (true);

CREATE POLICY "allow_select" ON orders FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON orders FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON orders FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON orders FOR DELETE USING (true);

CREATE POLICY "allow_select" ON product_categories FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON product_categories FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON product_categories FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON product_categories FOR DELETE USING (true);

CREATE POLICY "allow_select" ON product_units FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON product_units FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON product_units FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON product_units FOR DELETE USING (true);

CREATE POLICY "allow_select" ON products FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON products FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON products FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON products FOR DELETE USING (true);

CREATE POLICY "allow_select" ON push_subscriptions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON push_subscriptions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON push_subscriptions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON push_subscriptions FOR DELETE USING (true);

CREATE POLICY "allow_select" ON quick_task_assignments FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON quick_task_assignments FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON quick_task_assignments FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON quick_task_assignments FOR DELETE USING (true);

CREATE POLICY "allow_select" ON quick_task_comments FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON quick_task_comments FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON quick_task_comments FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON quick_task_comments FOR DELETE USING (true);

CREATE POLICY "allow_select" ON quick_task_completions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON quick_task_completions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON quick_task_completions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON quick_task_completions FOR DELETE USING (true);

CREATE POLICY "allow_select" ON quick_task_files FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON quick_task_files FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON quick_task_files FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON quick_task_files FOR DELETE USING (true);

CREATE POLICY "allow_select" ON quick_task_user_preferences FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON quick_task_user_preferences FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON quick_task_user_preferences FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON quick_task_user_preferences FOR DELETE USING (true);

CREATE POLICY "allow_select" ON quick_tasks FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON quick_tasks FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON quick_tasks FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON quick_tasks FOR DELETE USING (true);

CREATE POLICY "allow_select" ON receiving_records FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON receiving_records FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON receiving_records FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON receiving_records FOR DELETE USING (true);

CREATE POLICY "allow_select" ON receiving_task_templates FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON receiving_task_templates FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON receiving_task_templates FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON receiving_task_templates FOR DELETE USING (true);

CREATE POLICY "allow_select" ON receiving_tasks FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON receiving_tasks FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON receiving_tasks FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON receiving_tasks FOR DELETE USING (true);

CREATE POLICY "allow_select" ON recurring_assignment_schedules FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON recurring_assignment_schedules FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON recurring_assignment_schedules FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON recurring_assignment_schedules FOR DELETE USING (true);

CREATE POLICY "allow_select" ON recurring_schedule_check_log FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON recurring_schedule_check_log FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON recurring_schedule_check_log FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON recurring_schedule_check_log FOR DELETE USING (true);

CREATE POLICY "allow_select" ON requesters FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON requesters FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON requesters FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON requesters FOR DELETE USING (true);

CREATE POLICY "allow_select" ON role_permissions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON role_permissions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON role_permissions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON role_permissions FOR DELETE USING (true);

CREATE POLICY "allow_select" ON shelf_paper_templates FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON shelf_paper_templates FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON shelf_paper_templates FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON shelf_paper_templates FOR DELETE USING (true);

CREATE POLICY "allow_select" ON task_assignments FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON task_assignments FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON task_assignments FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON task_assignments FOR DELETE USING (true);

CREATE POLICY "allow_select" ON task_completions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON task_completions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON task_completions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON task_completions FOR DELETE USING (true);

CREATE POLICY "allow_select" ON task_images FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON task_images FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON task_images FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON task_images FOR DELETE USING (true);

CREATE POLICY "allow_select" ON task_reminder_logs FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON task_reminder_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON task_reminder_logs FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON task_reminder_logs FOR DELETE USING (true);

CREATE POLICY "allow_select" ON tasks FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON tasks FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON tasks FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON tasks FOR DELETE USING (true);

CREATE POLICY "allow_select" ON tax_categories FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON tax_categories FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON tax_categories FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON tax_categories FOR DELETE USING (true);

CREATE POLICY "allow_select" ON user_audit_logs FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON user_audit_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON user_audit_logs FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON user_audit_logs FOR DELETE USING (true);

CREATE POLICY "allow_select" ON user_device_sessions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON user_device_sessions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON user_device_sessions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON user_device_sessions FOR DELETE USING (true);

CREATE POLICY "allow_select" ON user_password_history FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON user_password_history FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON user_password_history FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON user_password_history FOR DELETE USING (true);

CREATE POLICY "allow_select" ON user_roles FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON user_roles FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON user_roles FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON user_roles FOR DELETE USING (true);

CREATE POLICY "allow_select" ON user_sessions FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON user_sessions FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON user_sessions FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON user_sessions FOR DELETE USING (true);

CREATE POLICY "allow_select" ON users FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON users FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON users FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON users FOR DELETE USING (true);

CREATE POLICY "allow_select" ON variation_audit_log FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON variation_audit_log FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON variation_audit_log FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON variation_audit_log FOR DELETE USING (true);

CREATE POLICY "allow_select" ON vendor_payment_schedule FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON vendor_payment_schedule FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON vendor_payment_schedule FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON vendor_payment_schedule FOR DELETE USING (true);

CREATE POLICY "allow_select" ON vendors FOR SELECT USING (true);
CREATE POLICY "allow_insert" ON vendors FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update" ON vendors FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "allow_delete" ON vendors FOR DELETE USING (true);

-- Verify
SELECT 
  COUNT(DISTINCT t.tablename) as total_tables,
  SUM(CASE WHEN t.rowsecurity THEN 1 ELSE 0 END) as rls_enabled,
  COUNT(DISTINCT p.tablename) as tables_with_policies
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename
WHERE t.schemaname = 'public';
