-- ============================================
-- POLICY: anon_insert ON access_code_otp
-- ============================================
CREATE POLICY anon_insert ON public.access_code_otp FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: service_role_all ON access_code_otp
-- ============================================
CREATE POLICY service_role_all ON public.access_code_otp FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to ai_chat_guide ON ai_chat_guide
-- ============================================
CREATE POLICY "Allow all access to ai_chat_guide" ON public.ai_chat_guide FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Anyone can view app icons ON app_icons
-- ============================================
CREATE POLICY "Anyone can view app icons" ON public.app_icons FOR SELECT USING (true);

-- ============================================
-- POLICY: Authenticated users can delete app icons ON app_icons
-- ============================================
CREATE POLICY "Authenticated users can delete app icons" ON public.app_icons FOR DELETE TO authenticated USING (true);

-- ============================================
-- POLICY: Authenticated users can insert app icons ON app_icons
-- ============================================
CREATE POLICY "Authenticated users can insert app icons" ON public.app_icons FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Authenticated users can update app icons ON app_icons
-- ============================================
CREATE POLICY "Authenticated users can update app icons" ON public.app_icons FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to approval_permissions ON approval_permissions
-- ============================================
CREATE POLICY "Allow all access to approval_permissions" ON public.approval_permissions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all to view approval permissions ON approval_permissions
-- ============================================
CREATE POLICY "Allow all to view approval permissions" ON public.approval_permissions FOR SELECT USING (true);

-- ============================================
-- POLICY: Allow anon insert approval_permissions ON approval_permissions
-- ============================================
CREATE POLICY "Allow anon insert approval_permissions" ON public.approval_permissions FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON approval_permissions
-- ============================================
CREATE POLICY allow_all_operations ON public.approval_permissions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON approval_permissions
-- ============================================
CREATE POLICY allow_delete ON public.approval_permissions FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON approval_permissions
-- ============================================
CREATE POLICY allow_insert ON public.approval_permissions FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON approval_permissions
-- ============================================
CREATE POLICY allow_select ON public.approval_permissions FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON approval_permissions
-- ============================================
CREATE POLICY allow_update ON public.approval_permissions FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON approval_permissions
-- ============================================
CREATE POLICY anon_full_access ON public.approval_permissions FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON approval_permissions
-- ============================================
CREATE POLICY authenticated_full_access ON public.approval_permissions FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to approver_branch_access ON approver_branch_access
-- ============================================
CREATE POLICY "Allow all access to approver_branch_access" ON public.approver_branch_access FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to approver_visibility_config ON approver_visibility_config
-- ============================================
CREATE POLICY "Allow all access to approver_visibility_config" ON public.approver_visibility_config FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to asset_main_categories ON asset_main_categories
-- ============================================
CREATE POLICY "Allow all access to asset_main_categories" ON public.asset_main_categories FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to asset_sub_categories ON asset_sub_categories
-- ============================================
CREATE POLICY "Allow all access to asset_sub_categories" ON public.asset_sub_categories FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to assets ON assets
-- ============================================
CREATE POLICY "Allow all access to assets" ON public.assets FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_all_background_templates ON background_templates
-- ============================================
CREATE POLICY anon_all_background_templates ON public.background_templates FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: auth_all_background_templates ON background_templates
-- ============================================
CREATE POLICY auth_all_background_templates ON public.background_templates FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to bank_reconciliations ON bank_reconciliations
-- ============================================
CREATE POLICY "Allow all access to bank_reconciliations" ON public.bank_reconciliations FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert biometric_connections ON biometric_connections
-- ============================================
CREATE POLICY "Allow anon insert biometric_connections" ON public.biometric_connections FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Enable delete for authenticated users ON biometric_connections
-- ============================================
CREATE POLICY "Enable delete for authenticated users" ON public.biometric_connections FOR DELETE USING ((role() = 'authenticated'::text));

-- ============================================
-- POLICY: Enable insert for authenticated users ON biometric_connections
-- ============================================
CREATE POLICY "Enable insert for authenticated users" ON public.biometric_connections FOR INSERT WITH CHECK ((role() = 'authenticated'::text));

-- ============================================
-- POLICY: Enable read for authenticated users ON biometric_connections
-- ============================================
CREATE POLICY "Enable read for authenticated users" ON public.biometric_connections FOR SELECT USING ((role() = 'authenticated'::text));

-- ============================================
-- POLICY: Enable update for authenticated users ON biometric_connections
-- ============================================
CREATE POLICY "Enable update for authenticated users" ON public.biometric_connections FOR UPDATE USING ((role() = 'authenticated'::text));

-- ============================================
-- POLICY: allow_all_operations ON biometric_connections
-- ============================================
CREATE POLICY allow_all_operations ON public.biometric_connections FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON biometric_connections
-- ============================================
CREATE POLICY allow_delete ON public.biometric_connections FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON biometric_connections
-- ============================================
CREATE POLICY allow_insert ON public.biometric_connections FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON biometric_connections
-- ============================================
CREATE POLICY allow_select ON public.biometric_connections FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON biometric_connections
-- ============================================
CREATE POLICY allow_update ON public.biometric_connections FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON biometric_connections
-- ============================================
CREATE POLICY anon_full_access ON public.biometric_connections FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON biometric_connections
-- ============================================
CREATE POLICY authenticated_full_access ON public.biometric_connections FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert bogo_offer_rules ON bogo_offer_rules
-- ============================================
CREATE POLICY "Allow anon insert bogo_offer_rules" ON public.bogo_offer_rules FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow read access to bogo_offer_rules ON bogo_offer_rules
-- ============================================
CREATE POLICY "Allow read access to bogo_offer_rules" ON public.bogo_offer_rules FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Allow service role full access to bogo_offer_rules ON bogo_offer_rules
-- ============================================
CREATE POLICY "Allow service role full access to bogo_offer_rules" ON public.bogo_offer_rules FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON bogo_offer_rules
-- ============================================
CREATE POLICY allow_all_operations ON public.bogo_offer_rules FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON bogo_offer_rules
-- ============================================
CREATE POLICY allow_delete ON public.bogo_offer_rules FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON bogo_offer_rules
-- ============================================
CREATE POLICY allow_insert ON public.bogo_offer_rules FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_public_read_bogo ON bogo_offer_rules
-- ============================================
CREATE POLICY allow_public_read_bogo ON public.bogo_offer_rules FOR SELECT TO authenticated, anon USING (true);

-- ============================================
-- POLICY: allow_select ON bogo_offer_rules
-- ============================================
CREATE POLICY allow_select ON public.bogo_offer_rules FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON bogo_offer_rules
-- ============================================
CREATE POLICY allow_update ON public.bogo_offer_rules FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON bogo_offer_rules
-- ============================================
CREATE POLICY anon_full_access ON public.bogo_offer_rules FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON bogo_offer_rules
-- ============================================
CREATE POLICY authenticated_full_access ON public.bogo_offer_rules FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to box_edit_requests ON box_edit_requests
-- ============================================
CREATE POLICY "Allow all access to box_edit_requests" ON public.box_edit_requests FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: box_operations_delete ON box_operations
-- ============================================
CREATE POLICY box_operations_delete ON public.box_operations FOR DELETE USING (true);

-- ============================================
-- POLICY: box_operations_insert ON box_operations
-- ============================================
CREATE POLICY box_operations_insert ON public.box_operations FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: box_operations_select ON box_operations
-- ============================================
CREATE POLICY box_operations_select ON public.box_operations FOR SELECT USING (true);

-- ============================================
-- POLICY: box_operations_update ON box_operations
-- ============================================
CREATE POLICY box_operations_update ON public.box_operations FOR UPDATE USING (true);

-- ============================================
-- POLICY: Allow all access to branch_default_delivery_receivers ON branch_default_delivery_receivers
-- ============================================
CREATE POLICY "Allow all access to branch_default_delivery_receivers" ON public.branch_default_delivery_receivers FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to branch_default_positions ON branch_default_positions
-- ============================================
CREATE POLICY "Allow all access to branch_default_positions" ON public.branch_default_positions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: branch_sync_config_modify ON branch_sync_config
-- ============================================
CREATE POLICY branch_sync_config_modify ON public.branch_sync_config FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: branch_sync_config_select ON branch_sync_config
-- ============================================
CREATE POLICY branch_sync_config_select ON public.branch_sync_config FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: allow_delete ON branches
-- ============================================
CREATE POLICY allow_delete ON public.branches FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON branches
-- ============================================
CREATE POLICY allow_insert ON public.branches FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON branches
-- ============================================
CREATE POLICY allow_select ON public.branches FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON branches
-- ============================================
CREATE POLICY allow_update ON public.branches FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: rls_delete ON branches
-- ============================================
CREATE POLICY rls_delete ON public.branches FOR DELETE USING (true);

-- ============================================
-- POLICY: rls_insert ON branches
-- ============================================
CREATE POLICY rls_insert ON public.branches FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: rls_select ON branches
-- ============================================
CREATE POLICY rls_select ON public.branches FOR SELECT USING (true);

-- ============================================
-- POLICY: rls_update ON branches
-- ============================================
CREATE POLICY rls_update ON public.branches FOR UPDATE WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to break_reasons ON break_reasons
-- ============================================
CREATE POLICY "Allow all access to break_reasons" ON public.break_reasons FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to break_register ON break_register
-- ============================================
CREATE POLICY "Allow all access to break_register" ON public.break_register FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to break_register_permissions ON break_register_permissions
-- ============================================
CREATE POLICY "Allow all access to break_register_permissions" ON public.break_register_permissions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON button_main_sections
-- ============================================
CREATE POLICY allow_delete ON public.button_main_sections FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON button_main_sections
-- ============================================
CREATE POLICY allow_insert ON public.button_main_sections FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON button_main_sections
-- ============================================
CREATE POLICY allow_select ON public.button_main_sections FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON button_main_sections
-- ============================================
CREATE POLICY allow_update ON public.button_main_sections FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON button_permissions
-- ============================================
CREATE POLICY allow_delete ON public.button_permissions FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON button_permissions
-- ============================================
CREATE POLICY allow_insert ON public.button_permissions FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON button_permissions
-- ============================================
CREATE POLICY allow_select ON public.button_permissions FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON button_permissions
-- ============================================
CREATE POLICY allow_update ON public.button_permissions FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON button_sub_sections
-- ============================================
CREATE POLICY allow_delete ON public.button_sub_sections FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON button_sub_sections
-- ============================================
CREATE POLICY allow_insert ON public.button_sub_sections FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON button_sub_sections
-- ============================================
CREATE POLICY allow_select ON public.button_sub_sections FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON button_sub_sections
-- ============================================
CREATE POLICY allow_update ON public.button_sub_sections FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: cashier_bindings_select ON cashier_device_bindings
-- ============================================
CREATE POLICY cashier_bindings_select ON public.cashier_device_bindings FOR SELECT USING (true);

-- ============================================
-- POLICY: Allow anon insert coupon_campaigns ON coupon_campaigns
-- ============================================
CREATE POLICY "Allow anon insert coupon_campaigns" ON public.coupon_campaigns FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON coupon_campaigns
-- ============================================
CREATE POLICY allow_all_operations ON public.coupon_campaigns FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON coupon_campaigns
-- ============================================
CREATE POLICY allow_delete ON public.coupon_campaigns FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON coupon_campaigns
-- ============================================
CREATE POLICY allow_insert ON public.coupon_campaigns FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON coupon_campaigns
-- ============================================
CREATE POLICY allow_select ON public.coupon_campaigns FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON coupon_campaigns
-- ============================================
CREATE POLICY allow_update ON public.coupon_campaigns FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON coupon_campaigns
-- ============================================
CREATE POLICY anon_full_access ON public.coupon_campaigns FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON coupon_campaigns
-- ============================================
CREATE POLICY authenticated_full_access ON public.coupon_campaigns FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: authenticated_view_active_campaigns ON coupon_campaigns
-- ============================================
CREATE POLICY authenticated_view_active_campaigns ON public.coupon_campaigns FOR SELECT TO authenticated USING (((is_active = true) AND (deleted_at IS NULL)));

-- ============================================
-- POLICY: Allow anon insert coupon_claims ON coupon_claims
-- ============================================
CREATE POLICY "Allow anon insert coupon_claims" ON public.coupon_claims FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON coupon_claims
-- ============================================
CREATE POLICY allow_all_operations ON public.coupon_claims FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON coupon_claims
-- ============================================
CREATE POLICY allow_delete ON public.coupon_claims FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON coupon_claims
-- ============================================
CREATE POLICY allow_insert ON public.coupon_claims FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON coupon_claims
-- ============================================
CREATE POLICY allow_select ON public.coupon_claims FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON coupon_claims
-- ============================================
CREATE POLICY allow_update ON public.coupon_claims FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON coupon_claims
-- ============================================
CREATE POLICY anon_full_access ON public.coupon_claims FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_create_claims ON coupon_claims
-- ============================================
CREATE POLICY authenticated_create_claims ON public.coupon_claims FOR INSERT TO authenticated WITH CHECK ((claimed_by_user = uid()));

-- ============================================
-- POLICY: authenticated_full_access ON coupon_claims
-- ============================================
CREATE POLICY authenticated_full_access ON public.coupon_claims FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert coupon_eligible_customers ON coupon_eligible_customers
-- ============================================
CREATE POLICY "Allow anon insert coupon_eligible_customers" ON public.coupon_eligible_customers FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON coupon_eligible_customers
-- ============================================
CREATE POLICY allow_all_operations ON public.coupon_eligible_customers FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON coupon_eligible_customers
-- ============================================
CREATE POLICY allow_delete ON public.coupon_eligible_customers FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON coupon_eligible_customers
-- ============================================
CREATE POLICY allow_insert ON public.coupon_eligible_customers FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON coupon_eligible_customers
-- ============================================
CREATE POLICY allow_select ON public.coupon_eligible_customers FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON coupon_eligible_customers
-- ============================================
CREATE POLICY allow_update ON public.coupon_eligible_customers FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON coupon_eligible_customers
-- ============================================
CREATE POLICY anon_full_access ON public.coupon_eligible_customers FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_check_eligibility ON coupon_eligible_customers
-- ============================================
CREATE POLICY authenticated_check_eligibility ON public.coupon_eligible_customers FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: authenticated_full_access ON coupon_eligible_customers
-- ============================================
CREATE POLICY authenticated_full_access ON public.coupon_eligible_customers FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert coupon_products ON coupon_products
-- ============================================
CREATE POLICY "Allow anon insert coupon_products" ON public.coupon_products FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON coupon_products
-- ============================================
CREATE POLICY allow_all_operations ON public.coupon_products FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON coupon_products
-- ============================================
CREATE POLICY allow_delete ON public.coupon_products FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON coupon_products
-- ============================================
CREATE POLICY allow_insert ON public.coupon_products FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON coupon_products
-- ============================================
CREATE POLICY allow_select ON public.coupon_products FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON coupon_products
-- ============================================
CREATE POLICY allow_update ON public.coupon_products FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON coupon_products
-- ============================================
CREATE POLICY anon_full_access ON public.coupon_products FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON coupon_products
-- ============================================
CREATE POLICY authenticated_full_access ON public.coupon_products FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: authenticated_view_active_products ON coupon_products
-- ============================================
CREATE POLICY authenticated_view_active_products ON public.coupon_products FOR SELECT TO authenticated USING (((is_active = true) AND (deleted_at IS NULL)));

-- ============================================
-- POLICY: Allow anon insert customer_access_code_history ON customer_access_code_history
-- ============================================
CREATE POLICY "Allow anon insert customer_access_code_history" ON public.customer_access_code_history FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON customer_access_code_history
-- ============================================
CREATE POLICY allow_all_operations ON public.customer_access_code_history FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON customer_access_code_history
-- ============================================
CREATE POLICY allow_delete ON public.customer_access_code_history FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON customer_access_code_history
-- ============================================
CREATE POLICY allow_insert ON public.customer_access_code_history FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON customer_access_code_history
-- ============================================
CREATE POLICY allow_select ON public.customer_access_code_history FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON customer_access_code_history
-- ============================================
CREATE POLICY allow_update ON public.customer_access_code_history FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON customer_access_code_history
-- ============================================
CREATE POLICY anon_full_access ON public.customer_access_code_history FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON customer_access_code_history
-- ============================================
CREATE POLICY authenticated_full_access ON public.customer_access_code_history FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: customer_access_code_history_insert_policy ON customer_access_code_history
-- ============================================
CREATE POLICY customer_access_code_history_insert_policy ON public.customer_access_code_history FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: customer_access_code_history_select_policy ON customer_access_code_history
-- ============================================
CREATE POLICY customer_access_code_history_select_policy ON public.customer_access_code_history FOR SELECT USING (true);

-- ============================================
-- POLICY: realtime_access_code_history_select ON customer_access_code_history
-- ============================================
CREATE POLICY realtime_access_code_history_select ON public.customer_access_code_history FOR SELECT TO authenticated, anon USING (true);

-- ============================================
-- POLICY: Allow anon insert customer_app_media ON customer_app_media
-- ============================================
CREATE POLICY "Allow anon insert customer_app_media" ON public.customer_app_media FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON customer_app_media
-- ============================================
CREATE POLICY allow_all_operations ON public.customer_app_media FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON customer_app_media
-- ============================================
CREATE POLICY allow_delete ON public.customer_app_media FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON customer_app_media
-- ============================================
CREATE POLICY allow_insert ON public.customer_app_media FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON customer_app_media
-- ============================================
CREATE POLICY allow_select ON public.customer_app_media FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON customer_app_media
-- ============================================
CREATE POLICY allow_update ON public.customer_app_media FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON customer_app_media
-- ============================================
CREATE POLICY anon_full_access ON public.customer_app_media FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON customer_app_media
-- ============================================
CREATE POLICY authenticated_full_access ON public.customer_app_media FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to customer_product_requests ON customer_product_requests
-- ============================================
CREATE POLICY "Allow all access to customer_product_requests" ON public.customer_product_requests FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert customer_recovery_requests ON customer_recovery_requests
-- ============================================
CREATE POLICY "Allow anon insert customer_recovery_requests" ON public.customer_recovery_requests FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON customer_recovery_requests
-- ============================================
CREATE POLICY allow_all_operations ON public.customer_recovery_requests FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON customer_recovery_requests
-- ============================================
CREATE POLICY allow_delete ON public.customer_recovery_requests FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON customer_recovery_requests
-- ============================================
CREATE POLICY allow_insert ON public.customer_recovery_requests FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON customer_recovery_requests
-- ============================================
CREATE POLICY allow_select ON public.customer_recovery_requests FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON customer_recovery_requests
-- ============================================
CREATE POLICY allow_update ON public.customer_recovery_requests FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON customer_recovery_requests
-- ============================================
CREATE POLICY anon_full_access ON public.customer_recovery_requests FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON customer_recovery_requests
-- ============================================
CREATE POLICY authenticated_full_access ON public.customer_recovery_requests FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: customer_recovery_requests_delete_policy ON customer_recovery_requests
-- ============================================
CREATE POLICY customer_recovery_requests_delete_policy ON public.customer_recovery_requests FOR DELETE USING (true);

-- ============================================
-- POLICY: customer_recovery_requests_insert_policy ON customer_recovery_requests
-- ============================================
CREATE POLICY customer_recovery_requests_insert_policy ON public.customer_recovery_requests FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: customer_recovery_requests_select_policy ON customer_recovery_requests
-- ============================================
CREATE POLICY customer_recovery_requests_select_policy ON public.customer_recovery_requests FOR SELECT USING (true);

-- ============================================
-- POLICY: customer_recovery_requests_update_policy ON customer_recovery_requests
-- ============================================
CREATE POLICY customer_recovery_requests_update_policy ON public.customer_recovery_requests FOR UPDATE USING (true);

-- ============================================
-- POLICY: Allow anon insert customers ON customers
-- ============================================
CREATE POLICY "Allow anon insert customers" ON public.customers FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON customers
-- ============================================
CREATE POLICY allow_all_operations ON public.customers FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON customers
-- ============================================
CREATE POLICY allow_delete ON public.customers FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON customers
-- ============================================
CREATE POLICY allow_insert ON public.customers FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON customers
-- ============================================
CREATE POLICY allow_select ON public.customers FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON customers
-- ============================================
CREATE POLICY allow_update ON public.customers FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON customers
-- ============================================
CREATE POLICY anon_full_access ON public.customers FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON customers
-- ============================================
CREATE POLICY authenticated_full_access ON public.customers FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: customers_delete_policy ON customers
-- ============================================
CREATE POLICY customers_delete_policy ON public.customers FOR DELETE USING (true);

-- ============================================
-- POLICY: customers_insert_policy ON customers
-- ============================================
CREATE POLICY customers_insert_policy ON public.customers FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: customers_select_policy ON customers
-- ============================================
CREATE POLICY customers_select_policy ON public.customers FOR SELECT USING (true);

-- ============================================
-- POLICY: customers_update_policy ON customers
-- ============================================
CREATE POLICY customers_update_policy ON public.customers FOR UPDATE USING (true);

-- ============================================
-- POLICY: realtime_customers_select ON customers
-- ============================================
CREATE POLICY realtime_customers_select ON public.customers FOR SELECT TO authenticated, anon USING (true);

-- ============================================
-- POLICY: Allow anon full access to daily_temp_schedules ON daily_temp_schedules
-- ============================================
CREATE POLICY "Allow anon full access to daily_temp_schedules" ON public.daily_temp_schedules FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users full access to daily_temp_schedules ON daily_temp_schedules
-- ============================================
CREATE POLICY "Allow authenticated users full access to daily_temp_schedules" ON public.daily_temp_schedules FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all operations on day_off ON day_off
-- ============================================
CREATE POLICY "Allow all operations on day_off" ON public.day_off FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to day_off_reasons ON day_off_reasons
-- ============================================
CREATE POLICY "Allow all access to day_off_reasons" ON public.day_off_reasons FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all operations on day_off_weekday ON day_off_weekday
-- ============================================
CREATE POLICY "Allow all operations on day_off_weekday" ON public.day_off_weekday FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to default_incident_users ON default_incident_users
-- ============================================
CREATE POLICY "Allow all access to default_incident_users" ON public.default_incident_users FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert deleted_bundle_offers ON deleted_bundle_offers
-- ============================================
CREATE POLICY "Allow anon insert deleted_bundle_offers" ON public.deleted_bundle_offers FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to archive offers ON deleted_bundle_offers
-- ============================================
CREATE POLICY "Allow authenticated users to archive offers" ON public.deleted_bundle_offers FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to view deleted offers ON deleted_bundle_offers
-- ============================================
CREATE POLICY "Allow authenticated users to view deleted offers" ON public.deleted_bundle_offers FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: allow_all_operations ON deleted_bundle_offers
-- ============================================
CREATE POLICY allow_all_operations ON public.deleted_bundle_offers FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON deleted_bundle_offers
-- ============================================
CREATE POLICY allow_delete ON public.deleted_bundle_offers FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON deleted_bundle_offers
-- ============================================
CREATE POLICY allow_insert ON public.deleted_bundle_offers FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON deleted_bundle_offers
-- ============================================
CREATE POLICY allow_select ON public.deleted_bundle_offers FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON deleted_bundle_offers
-- ============================================
CREATE POLICY allow_update ON public.deleted_bundle_offers FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON deleted_bundle_offers
-- ============================================
CREATE POLICY anon_full_access ON public.deleted_bundle_offers FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON deleted_bundle_offers
-- ============================================
CREATE POLICY authenticated_full_access ON public.deleted_bundle_offers FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert delivery_fee_tiers ON delivery_fee_tiers
-- ============================================
CREATE POLICY "Allow anon insert delivery_fee_tiers" ON public.delivery_fee_tiers FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON delivery_fee_tiers
-- ============================================
CREATE POLICY allow_all_operations ON public.delivery_fee_tiers FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON delivery_fee_tiers
-- ============================================
CREATE POLICY allow_delete ON public.delivery_fee_tiers FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON delivery_fee_tiers
-- ============================================
CREATE POLICY allow_insert ON public.delivery_fee_tiers FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON delivery_fee_tiers
-- ============================================
CREATE POLICY allow_select ON public.delivery_fee_tiers FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON delivery_fee_tiers
-- ============================================
CREATE POLICY allow_update ON public.delivery_fee_tiers FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON delivery_fee_tiers
-- ============================================
CREATE POLICY anon_full_access ON public.delivery_fee_tiers FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON delivery_fee_tiers
-- ============================================
CREATE POLICY authenticated_full_access ON public.delivery_fee_tiers FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: delivery_tiers_select_all ON delivery_fee_tiers
-- ============================================
CREATE POLICY delivery_tiers_select_all ON public.delivery_fee_tiers FOR SELECT USING (true);

-- ============================================
-- POLICY: Allow anon insert delivery_service_settings ON delivery_service_settings
-- ============================================
CREATE POLICY "Allow anon insert delivery_service_settings" ON public.delivery_service_settings FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON delivery_service_settings
-- ============================================
CREATE POLICY allow_all_operations ON public.delivery_service_settings FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON delivery_service_settings
-- ============================================
CREATE POLICY allow_delete ON public.delivery_service_settings FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON delivery_service_settings
-- ============================================
CREATE POLICY allow_insert ON public.delivery_service_settings FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON delivery_service_settings
-- ============================================
CREATE POLICY allow_select ON public.delivery_service_settings FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON delivery_service_settings
-- ============================================
CREATE POLICY allow_update ON public.delivery_service_settings FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON delivery_service_settings
-- ============================================
CREATE POLICY anon_full_access ON public.delivery_service_settings FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON delivery_service_settings
-- ============================================
CREATE POLICY authenticated_full_access ON public.delivery_service_settings FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: delivery_settings_allow_read ON delivery_service_settings
-- ============================================
CREATE POLICY delivery_settings_allow_read ON public.delivery_service_settings FOR SELECT USING (true);

-- ============================================
-- POLICY: denomination_audit_log_insert ON denomination_audit_log
-- ============================================
CREATE POLICY denomination_audit_log_insert ON public.denomination_audit_log FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: denomination_audit_log_select ON denomination_audit_log
-- ============================================
CREATE POLICY denomination_audit_log_select ON public.denomination_audit_log FOR SELECT USING (true);

-- ============================================
-- POLICY: Allow anon full access to denomination_permissions ON denomination_permissions
-- ============================================
CREATE POLICY "Allow anon full access to denomination_permissions" ON public.denomination_permissions FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated full access to denomination_permissions ON denomination_permissions
-- ============================================
CREATE POLICY "Allow authenticated full access to denomination_permissions" ON public.denomination_permissions FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: denomination_records_delete ON denomination_records
-- ============================================
CREATE POLICY denomination_records_delete ON public.denomination_records FOR DELETE USING (true);

-- ============================================
-- POLICY: denomination_records_insert ON denomination_records
-- ============================================
CREATE POLICY denomination_records_insert ON public.denomination_records FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: denomination_records_select ON denomination_records
-- ============================================
CREATE POLICY denomination_records_select ON public.denomination_records FOR SELECT USING (true);

-- ============================================
-- POLICY: denomination_records_update ON denomination_records
-- ============================================
CREATE POLICY denomination_records_update ON public.denomination_records FOR UPDATE USING (true);

-- ============================================
-- POLICY: Allow all access to denomination_transactions ON denomination_transactions
-- ============================================
CREATE POLICY "Allow all access to denomination_transactions" ON public.denomination_transactions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: denomination_types_delete ON denomination_types
-- ============================================
CREATE POLICY denomination_types_delete ON public.denomination_types FOR DELETE USING (true);

-- ============================================
-- POLICY: denomination_types_insert ON denomination_types
-- ============================================
CREATE POLICY denomination_types_insert ON public.denomination_types FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: denomination_types_select ON denomination_types
-- ============================================
CREATE POLICY denomination_types_select ON public.denomination_types FOR SELECT USING (true);

-- ============================================
-- POLICY: denomination_types_update ON denomination_types
-- ============================================
CREATE POLICY denomination_types_update ON public.denomination_types FOR UPDATE USING (true);

-- ============================================
-- POLICY: Allow all access to desktop_themes ON desktop_themes
-- ============================================
CREATE POLICY "Allow all access to desktop_themes" ON public.desktop_themes FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: email_secrets_no_client_access ON email_account_secrets
-- ============================================
CREATE POLICY email_secrets_no_client_access ON public.email_account_secrets FOR ALL TO authenticated, anon USING (false);

-- ============================================
-- POLICY: email_accounts_read ON email_accounts
-- ============================================
CREATE POLICY email_accounts_read ON public.email_accounts FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_ai_results_read ON email_ai_results
-- ============================================
CREATE POLICY email_ai_results_read ON public.email_ai_results FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_ai_settings_read ON email_ai_settings
-- ============================================
CREATE POLICY email_ai_settings_read ON public.email_ai_settings FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_attachments_read ON email_attachments
-- ============================================
CREATE POLICY email_attachments_read ON public.email_attachments FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_campaign_recipients_read ON email_campaign_recipients
-- ============================================
CREATE POLICY email_campaign_recipients_read ON public.email_campaign_recipients FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_campaigns_read ON email_campaigns
-- ============================================
CREATE POLICY email_campaigns_read ON public.email_campaigns FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_delivery_events_read ON email_delivery_events
-- ============================================
CREATE POLICY email_delivery_events_read ON public.email_delivery_events FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_folders_read ON email_folders
-- ============================================
CREATE POLICY email_folders_read ON public.email_folders FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_group_members_read ON email_group_members
-- ============================================
CREATE POLICY email_group_members_read ON public.email_group_members FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_groups_read ON email_groups
-- ============================================
CREATE POLICY email_groups_read ON public.email_groups FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_logs_read ON email_logs
-- ============================================
CREATE POLICY email_logs_read ON public.email_logs FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_recipients_read ON email_message_recipients
-- ============================================
CREATE POLICY email_recipients_read ON public.email_message_recipients FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_messages_read ON email_messages
-- ============================================
CREATE POLICY email_messages_read ON public.email_messages FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_presets_read ON email_provider_presets
-- ============================================
CREATE POLICY email_presets_read ON public.email_provider_presets FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_queue_read ON email_queue
-- ============================================
CREATE POLICY email_queue_read ON public.email_queue FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_send_attempts_read ON email_send_attempts
-- ============================================
CREATE POLICY email_send_attempts_read ON public.email_send_attempts FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_settings_read ON email_settings
-- ============================================
CREATE POLICY email_settings_read ON public.email_settings FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_signatures_read ON email_signatures
-- ============================================
CREATE POLICY email_signatures_read ON public.email_signatures FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_suppressions_read ON email_suppressions
-- ============================================
CREATE POLICY email_suppressions_read ON public.email_suppressions FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_sync_runs_read ON email_sync_runs
-- ============================================
CREATE POLICY email_sync_runs_read ON public.email_sync_runs FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_template_versions_read ON email_template_versions
-- ============================================
CREATE POLICY email_template_versions_read ON public.email_template_versions FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_templates_read ON email_templates
-- ============================================
CREATE POLICY email_templates_read ON public.email_templates FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_threads_read ON email_threads
-- ============================================
CREATE POLICY email_threads_read ON public.email_threads FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: email_usage_counters_read ON email_usage_counters
-- ============================================
CREATE POLICY email_usage_counters_read ON public.email_usage_counters FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Allow all access to employee_checklist_assignments ON employee_checklist_assignments
-- ============================================
CREATE POLICY "Allow all access to employee_checklist_assignments" ON public.employee_checklist_assignments FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Admins can manage all fine payments ON employee_fine_payments
-- ============================================
CREATE POLICY "Admins can manage all fine payments" ON public.employee_fine_payments FOR ALL USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = uid()) AND (u.user_type = 'global'::user_type_enum)))));

-- ============================================
-- POLICY: Allow anon insert employee_fine_payments ON employee_fine_payments
-- ============================================
CREATE POLICY "Allow anon insert employee_fine_payments" ON public.employee_fine_payments FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON employee_fine_payments
-- ============================================
CREATE POLICY allow_all_operations ON public.employee_fine_payments FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON employee_fine_payments
-- ============================================
CREATE POLICY allow_delete ON public.employee_fine_payments FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON employee_fine_payments
-- ============================================
CREATE POLICY allow_insert ON public.employee_fine_payments FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON employee_fine_payments
-- ============================================
CREATE POLICY allow_select ON public.employee_fine_payments FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON employee_fine_payments
-- ============================================
CREATE POLICY allow_update ON public.employee_fine_payments FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON employee_fine_payments
-- ============================================
CREATE POLICY anon_full_access ON public.employee_fine_payments FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON employee_fine_payments
-- ============================================
CREATE POLICY authenticated_full_access ON public.employee_fine_payments FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all operations on employee_official_holidays ON employee_official_holidays
-- ============================================
CREATE POLICY "Allow all operations on employee_official_holidays" ON public.employee_official_holidays FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert erp_connections ON erp_connections
-- ============================================
CREATE POLICY "Allow anon insert erp_connections" ON public.erp_connections FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to create ERP connections ON erp_connections
-- ============================================
CREATE POLICY "Allow authenticated users to create ERP connections" ON public.erp_connections FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to delete ERP connections ON erp_connections
-- ============================================
CREATE POLICY "Allow authenticated users to delete ERP connections" ON public.erp_connections FOR DELETE TO authenticated USING (true);

-- ============================================
-- POLICY: Allow authenticated users to read ERP connections ON erp_connections
-- ============================================
CREATE POLICY "Allow authenticated users to read ERP connections" ON public.erp_connections FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Allow authenticated users to update ERP connections ON erp_connections
-- ============================================
CREATE POLICY "Allow authenticated users to update ERP connections" ON public.erp_connections FOR UPDATE TO authenticated USING (true);

-- ============================================
-- POLICY: allow_all_operations ON erp_connections
-- ============================================
CREATE POLICY allow_all_operations ON public.erp_connections FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON erp_connections
-- ============================================
CREATE POLICY allow_delete ON public.erp_connections FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON erp_connections
-- ============================================
CREATE POLICY allow_insert ON public.erp_connections FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON erp_connections
-- ============================================
CREATE POLICY allow_select ON public.erp_connections FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON erp_connections
-- ============================================
CREATE POLICY allow_update ON public.erp_connections FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON erp_connections
-- ============================================
CREATE POLICY anon_full_access ON public.erp_connections FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON erp_connections
-- ============================================
CREATE POLICY authenticated_full_access ON public.erp_connections FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert erp_daily_sales ON erp_daily_sales
-- ============================================
CREATE POLICY "Allow anon insert erp_daily_sales" ON public.erp_daily_sales FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to read sales data ON erp_daily_sales
-- ============================================
CREATE POLICY "Allow authenticated users to read sales data" ON public.erp_daily_sales FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Allow service role to manage sales data ON erp_daily_sales
-- ============================================
CREATE POLICY "Allow service role to manage sales data" ON public.erp_daily_sales FOR ALL TO service_role USING (true);

-- ============================================
-- POLICY: allow_all_operations ON erp_daily_sales
-- ============================================
CREATE POLICY allow_all_operations ON public.erp_daily_sales FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON erp_daily_sales
-- ============================================
CREATE POLICY allow_delete ON public.erp_daily_sales FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON erp_daily_sales
-- ============================================
CREATE POLICY allow_insert ON public.erp_daily_sales FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON erp_daily_sales
-- ============================================
CREATE POLICY allow_select ON public.erp_daily_sales FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON erp_daily_sales
-- ============================================
CREATE POLICY allow_update ON public.erp_daily_sales FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON erp_daily_sales
-- ============================================
CREATE POLICY anon_full_access ON public.erp_daily_sales FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON erp_daily_sales
-- ============================================
CREATE POLICY authenticated_full_access ON public.erp_daily_sales FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Service role full access on erp_sync_logs ON erp_sync_logs
-- ============================================
CREATE POLICY "Service role full access on erp_sync_logs" ON public.erp_sync_logs FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to erp_synced_products ON erp_synced_products
-- ============================================
CREATE POLICY "Allow all access to erp_synced_products" ON public.erp_synced_products FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow admin users to delete parent categories ON expense_parent_categories
-- ============================================
CREATE POLICY "Allow admin users to delete parent categories" ON public.expense_parent_categories FOR DELETE TO authenticated USING (true);

-- ============================================
-- POLICY: Allow admin users to insert parent categories ON expense_parent_categories
-- ============================================
CREATE POLICY "Allow admin users to insert parent categories" ON public.expense_parent_categories FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Allow admin users to update parent categories ON expense_parent_categories
-- ============================================
CREATE POLICY "Allow admin users to update parent categories" ON public.expense_parent_categories FOR UPDATE TO authenticated USING (true);

-- ============================================
-- POLICY: Allow anon insert expense_parent_categories ON expense_parent_categories
-- ============================================
CREATE POLICY "Allow anon insert expense_parent_categories" ON public.expense_parent_categories FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to read parent categories ON expense_parent_categories
-- ============================================
CREATE POLICY "Allow authenticated users to read parent categories" ON public.expense_parent_categories FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: allow_all_operations ON expense_parent_categories
-- ============================================
CREATE POLICY allow_all_operations ON public.expense_parent_categories FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON expense_parent_categories
-- ============================================
CREATE POLICY allow_delete ON public.expense_parent_categories FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON expense_parent_categories
-- ============================================
CREATE POLICY allow_insert ON public.expense_parent_categories FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON expense_parent_categories
-- ============================================
CREATE POLICY allow_select ON public.expense_parent_categories FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON expense_parent_categories
-- ============================================
CREATE POLICY allow_update ON public.expense_parent_categories FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON expense_parent_categories
-- ============================================
CREATE POLICY anon_full_access ON public.expense_parent_categories FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON expense_parent_categories
-- ============================================
CREATE POLICY authenticated_full_access ON public.expense_parent_categories FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert expense_requisitions ON expense_requisitions
-- ============================================
CREATE POLICY "Allow anon insert expense_requisitions" ON public.expense_requisitions FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to create expense requisitions ON expense_requisitions
-- ============================================
CREATE POLICY "Allow authenticated users to create expense requisitions" ON public.expense_requisitions FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to delete requisitions ON expense_requisitions
-- ============================================
CREATE POLICY "Allow authenticated users to delete requisitions" ON public.expense_requisitions FOR DELETE TO authenticated USING (true);

-- ============================================
-- POLICY: Allow authenticated users to insert requisitions ON expense_requisitions
-- ============================================
CREATE POLICY "Allow authenticated users to insert requisitions" ON public.expense_requisitions FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to read expense requisitions ON expense_requisitions
-- ============================================
CREATE POLICY "Allow authenticated users to read expense requisitions" ON public.expense_requisitions FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Allow authenticated users to read requisitions ON expense_requisitions
-- ============================================
CREATE POLICY "Allow authenticated users to read requisitions" ON public.expense_requisitions FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Allow authenticated users to update expense requisitions ON expense_requisitions
-- ============================================
CREATE POLICY "Allow authenticated users to update expense requisitions" ON public.expense_requisitions FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to update requisitions ON expense_requisitions
-- ============================================
CREATE POLICY "Allow authenticated users to update requisitions" ON public.expense_requisitions FOR UPDATE TO authenticated USING (true);

-- ============================================
-- POLICY: Service role has full access to expense requisitions ON expense_requisitions
-- ============================================
CREATE POLICY "Service role has full access to expense requisitions" ON public.expense_requisitions FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON expense_requisitions
-- ============================================
CREATE POLICY allow_all_operations ON public.expense_requisitions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON expense_requisitions
-- ============================================
CREATE POLICY allow_delete ON public.expense_requisitions FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON expense_requisitions
-- ============================================
CREATE POLICY allow_insert ON public.expense_requisitions FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON expense_requisitions
-- ============================================
CREATE POLICY allow_select ON public.expense_requisitions FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON expense_requisitions
-- ============================================
CREATE POLICY allow_update ON public.expense_requisitions FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON expense_requisitions
-- ============================================
CREATE POLICY anon_full_access ON public.expense_requisitions FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON expense_requisitions
-- ============================================
CREATE POLICY authenticated_full_access ON public.expense_requisitions FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert expense_scheduler ON expense_scheduler
-- ============================================
CREATE POLICY "Allow anon insert expense_scheduler" ON public.expense_scheduler FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to create expense scheduler ON expense_scheduler
-- ============================================
CREATE POLICY "Allow authenticated users to create expense scheduler" ON public.expense_scheduler FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to read expense scheduler ON expense_scheduler
-- ============================================
CREATE POLICY "Allow authenticated users to read expense scheduler" ON public.expense_scheduler FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Allow authenticated users to update expense scheduler ON expense_scheduler
-- ============================================
CREATE POLICY "Allow authenticated users to update expense scheduler" ON public.expense_scheduler FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Service role has full access to expense scheduler ON expense_scheduler
-- ============================================
CREATE POLICY "Service role has full access to expense scheduler" ON public.expense_scheduler FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON expense_scheduler
-- ============================================
CREATE POLICY allow_all_operations ON public.expense_scheduler FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON expense_scheduler
-- ============================================
CREATE POLICY allow_delete ON public.expense_scheduler FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON expense_scheduler
-- ============================================
CREATE POLICY allow_insert ON public.expense_scheduler FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON expense_scheduler
-- ============================================
CREATE POLICY allow_select ON public.expense_scheduler FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON expense_scheduler
-- ============================================
CREATE POLICY allow_update ON public.expense_scheduler FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON expense_scheduler
-- ============================================
CREATE POLICY anon_full_access ON public.expense_scheduler FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON expense_scheduler
-- ============================================
CREATE POLICY authenticated_full_access ON public.expense_scheduler FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow admin users to delete sub categories ON expense_sub_categories
-- ============================================
CREATE POLICY "Allow admin users to delete sub categories" ON public.expense_sub_categories FOR DELETE TO authenticated USING (true);

-- ============================================
-- POLICY: Allow admin users to insert sub categories ON expense_sub_categories
-- ============================================
CREATE POLICY "Allow admin users to insert sub categories" ON public.expense_sub_categories FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Allow admin users to update sub categories ON expense_sub_categories
-- ============================================
CREATE POLICY "Allow admin users to update sub categories" ON public.expense_sub_categories FOR UPDATE TO authenticated USING (true);

-- ============================================
-- POLICY: Allow anon insert expense_sub_categories ON expense_sub_categories
-- ============================================
CREATE POLICY "Allow anon insert expense_sub_categories" ON public.expense_sub_categories FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to read sub categories ON expense_sub_categories
-- ============================================
CREATE POLICY "Allow authenticated users to read sub categories" ON public.expense_sub_categories FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: allow_all_operations ON expense_sub_categories
-- ============================================
CREATE POLICY allow_all_operations ON public.expense_sub_categories FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON expense_sub_categories
-- ============================================
CREATE POLICY allow_delete ON public.expense_sub_categories FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON expense_sub_categories
-- ============================================
CREATE POLICY allow_insert ON public.expense_sub_categories FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON expense_sub_categories
-- ============================================
CREATE POLICY allow_select ON public.expense_sub_categories FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON expense_sub_categories
-- ============================================
CREATE POLICY allow_update ON public.expense_sub_categories FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON expense_sub_categories
-- ============================================
CREATE POLICY anon_full_access ON public.expense_sub_categories FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON expense_sub_categories
-- ============================================
CREATE POLICY authenticated_full_access ON public.expense_sub_categories FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert flyer_offer_products ON flyer_offer_products
-- ============================================
CREATE POLICY "Allow anon insert flyer_offer_products" ON public.flyer_offer_products FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON flyer_offer_products
-- ============================================
CREATE POLICY allow_all_operations ON public.flyer_offer_products FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON flyer_offer_products
-- ============================================
CREATE POLICY allow_delete ON public.flyer_offer_products FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON flyer_offer_products
-- ============================================
CREATE POLICY allow_insert ON public.flyer_offer_products FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON flyer_offer_products
-- ============================================
CREATE POLICY allow_select ON public.flyer_offer_products FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON flyer_offer_products
-- ============================================
CREATE POLICY allow_update ON public.flyer_offer_products FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON flyer_offer_products
-- ============================================
CREATE POLICY anon_full_access ON public.flyer_offer_products FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON flyer_offer_products
-- ============================================
CREATE POLICY authenticated_full_access ON public.flyer_offer_products FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: flyer_offer_products_delete_policy ON flyer_offer_products
-- ============================================
CREATE POLICY flyer_offer_products_delete_policy ON public.flyer_offer_products FOR DELETE TO authenticated USING (true);

-- ============================================
-- POLICY: flyer_offer_products_insert_policy ON flyer_offer_products
-- ============================================
CREATE POLICY flyer_offer_products_insert_policy ON public.flyer_offer_products FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: flyer_offer_products_select_policy ON flyer_offer_products
-- ============================================
CREATE POLICY flyer_offer_products_select_policy ON public.flyer_offer_products FOR SELECT USING (true);

-- ============================================
-- POLICY: flyer_offer_products_update_policy ON flyer_offer_products
-- ============================================
CREATE POLICY flyer_offer_products_update_policy ON public.flyer_offer_products FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert flyer_offers ON flyer_offers
-- ============================================
CREATE POLICY "Allow anon insert flyer_offers" ON public.flyer_offers FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON flyer_offers
-- ============================================
CREATE POLICY allow_all_operations ON public.flyer_offers FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON flyer_offers
-- ============================================
CREATE POLICY allow_delete ON public.flyer_offers FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON flyer_offers
-- ============================================
CREATE POLICY allow_insert ON public.flyer_offers FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON flyer_offers
-- ============================================
CREATE POLICY allow_select ON public.flyer_offers FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON flyer_offers
-- ============================================
CREATE POLICY allow_update ON public.flyer_offers FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON flyer_offers
-- ============================================
CREATE POLICY anon_full_access ON public.flyer_offers FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON flyer_offers
-- ============================================
CREATE POLICY authenticated_full_access ON public.flyer_offers FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: flyer_offers_delete_policy ON flyer_offers
-- ============================================
CREATE POLICY flyer_offers_delete_policy ON public.flyer_offers FOR DELETE TO authenticated USING (true);

-- ============================================
-- POLICY: flyer_offers_insert_policy ON flyer_offers
-- ============================================
CREATE POLICY flyer_offers_insert_policy ON public.flyer_offers FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: flyer_offers_select_all_policy ON flyer_offers
-- ============================================
CREATE POLICY flyer_offers_select_all_policy ON public.flyer_offers FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: flyer_offers_select_policy ON flyer_offers
-- ============================================
CREATE POLICY flyer_offers_select_policy ON public.flyer_offers FOR SELECT USING ((is_active = true));

-- ============================================
-- POLICY: flyer_offers_update_policy ON flyer_offers
-- ============================================
CREATE POLICY flyer_offers_update_policy ON public.flyer_offers FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert flyer_templates ON flyer_templates
-- ============================================
CREATE POLICY "Allow anon insert flyer_templates" ON public.flyer_templates FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Users can view active flyer templates ON flyer_templates
-- ============================================
CREATE POLICY "Users can view active flyer templates" ON public.flyer_templates FOR SELECT TO authenticated USING (((is_active = true) AND (deleted_at IS NULL)));

-- ============================================
-- POLICY: allow_all_operations ON flyer_templates
-- ============================================
CREATE POLICY allow_all_operations ON public.flyer_templates FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON flyer_templates
-- ============================================
CREATE POLICY allow_delete ON public.flyer_templates FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON flyer_templates
-- ============================================
CREATE POLICY allow_insert ON public.flyer_templates FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON flyer_templates
-- ============================================
CREATE POLICY allow_select ON public.flyer_templates FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON flyer_templates
-- ============================================
CREATE POLICY allow_update ON public.flyer_templates FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON flyer_templates
-- ============================================
CREATE POLICY anon_full_access ON public.flyer_templates FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON flyer_templates
-- ============================================
CREATE POLICY authenticated_full_access ON public.flyer_templates FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Authenticated users can insert frontend_builds ON frontend_builds
-- ============================================
CREATE POLICY "Authenticated users can insert frontend_builds" ON public.frontend_builds FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Authenticated users can read frontend_builds ON frontend_builds
-- ============================================
CREATE POLICY "Authenticated users can read frontend_builds" ON public.frontend_builds FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Service role full access to frontend_builds ON frontend_builds
-- ============================================
CREATE POLICY "Service role full access to frontend_builds" ON public.frontend_builds FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon all gift_wheel_coupons ON gift_wheel_coupons
-- ============================================
CREATE POLICY "Allow anon all gift_wheel_coupons" ON public.gift_wheel_coupons FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated all gift_wheel_coupons ON gift_wheel_coupons
-- ============================================
CREATE POLICY "Allow authenticated all gift_wheel_coupons" ON public.gift_wheel_coupons FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon all gift_wheel_rewards ON gift_wheel_rewards
-- ============================================
CREATE POLICY "Allow anon all gift_wheel_rewards" ON public.gift_wheel_rewards FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated all gift_wheel_rewards ON gift_wheel_rewards
-- ============================================
CREATE POLICY "Allow authenticated all gift_wheel_rewards" ON public.gift_wheel_rewards FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon all gift_wheel_settings ON gift_wheel_settings
-- ============================================
CREATE POLICY "Allow anon all gift_wheel_settings" ON public.gift_wheel_settings FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated all gift_wheel_settings ON gift_wheel_settings
-- ============================================
CREATE POLICY "Allow authenticated all gift_wheel_settings" ON public.gift_wheel_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon all gift_wheel_spins ON gift_wheel_spins
-- ============================================
CREATE POLICY "Allow anon all gift_wheel_spins" ON public.gift_wheel_spins FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated all gift_wheel_spins ON gift_wheel_spins
-- ============================================
CREATE POLICY "Allow authenticated all gift_wheel_spins" ON public.gift_wheel_spins FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: helper_apps_delete ON helper_apps
-- ============================================
CREATE POLICY helper_apps_delete ON public.helper_apps FOR DELETE TO authenticated, anon USING (true);

-- ============================================
-- POLICY: helper_apps_insert ON helper_apps
-- ============================================
CREATE POLICY helper_apps_insert ON public.helper_apps FOR INSERT TO authenticated, anon WITH CHECK (true);

-- ============================================
-- POLICY: helper_apps_select ON helper_apps
-- ============================================
CREATE POLICY helper_apps_select ON public.helper_apps FOR SELECT TO authenticated, anon USING (true);

-- ============================================
-- POLICY: helper_apps_update ON helper_apps
-- ============================================
CREATE POLICY helper_apps_update ON public.helper_apps FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to hr_analysed_attendance_data ON hr_analysed_attendance_data
-- ============================================
CREATE POLICY "Allow all access to hr_analysed_attendance_data" ON public.hr_analysed_attendance_data FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to hr_basic_salary ON hr_basic_salary
-- ============================================
CREATE POLICY "Allow all access to hr_basic_salary" ON public.hr_basic_salary FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to hr_checklist_operations ON hr_checklist_operations
-- ============================================
CREATE POLICY "Allow all access to hr_checklist_operations" ON public.hr_checklist_operations FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to hr_checklist_questions ON hr_checklist_questions
-- ============================================
CREATE POLICY "Allow all access to hr_checklist_questions" ON public.hr_checklist_questions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to hr_checklists ON hr_checklists
-- ============================================
CREATE POLICY "Allow all access to hr_checklists" ON public.hr_checklists FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert hr_departments ON hr_departments
-- ============================================
CREATE POLICY "Allow anon insert hr_departments" ON public.hr_departments FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON hr_departments
-- ============================================
CREATE POLICY allow_all_operations ON public.hr_departments FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON hr_departments
-- ============================================
CREATE POLICY allow_delete ON public.hr_departments FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON hr_departments
-- ============================================
CREATE POLICY allow_insert ON public.hr_departments FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON hr_departments
-- ============================================
CREATE POLICY allow_select ON public.hr_departments FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON hr_departments
-- ============================================
CREATE POLICY allow_update ON public.hr_departments FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON hr_departments
-- ============================================
CREATE POLICY anon_full_access ON public.hr_departments FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON hr_departments
-- ============================================
CREATE POLICY authenticated_full_access ON public.hr_departments FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon all hr_employee_applicability_rule_periods ON hr_employee_applicability_rule_periods
-- ============================================
CREATE POLICY "Allow anon all hr_employee_applicability_rule_periods" ON public.hr_employee_applicability_rule_periods FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: authenticated_full_access_hr_employee_applicability_rule_period ON hr_employee_applicability_rule_periods
-- ============================================
CREATE POLICY authenticated_full_access_hr_employee_applicability_rule_period ON public.hr_employee_applicability_rule_periods FOR ALL USING ((uid() IS NOT NULL)) WITH CHECK ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to hr_employee_esob_records ON hr_employee_esob_records
-- ============================================
CREATE POLICY "Allow all access to hr_employee_esob_records" ON public.hr_employee_esob_records FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon all hr_employee_leave_approvals ON hr_employee_leave_approvals
-- ============================================
CREATE POLICY "Allow anon all hr_employee_leave_approvals" ON public.hr_employee_leave_approvals FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: authenticated_full_access_hr_employee_leave_approvals ON hr_employee_leave_approvals
-- ============================================
CREATE POLICY authenticated_full_access_hr_employee_leave_approvals ON public.hr_employee_leave_approvals FOR ALL USING ((uid() IS NOT NULL)) WITH CHECK ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to hr_employee_master ON hr_employee_master
-- ============================================
CREATE POLICY "Allow all access to hr_employee_master" ON public.hr_employee_master FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all users to view hr_employee_master table ON hr_employee_master
-- ============================================
CREATE POLICY "Allow all users to view hr_employee_master table" ON public.hr_employee_master FOR SELECT USING (true);

-- ============================================
-- POLICY: Allow anon insert hr_employee_master ON hr_employee_master
-- ============================================
CREATE POLICY "Allow anon insert hr_employee_master" ON public.hr_employee_master FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow service role full access to hr_employee_master ON hr_employee_master
-- ============================================
CREATE POLICY "Allow service role full access to hr_employee_master" ON public.hr_employee_master FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON hr_employee_master
-- ============================================
CREATE POLICY anon_full_access ON public.hr_employee_master FOR SELECT USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON hr_employee_master
-- ============================================
CREATE POLICY authenticated_full_access ON public.hr_employee_master FOR SELECT USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon all hr_employee_settlement_applicability ON hr_employee_settlement_applicability
-- ============================================
CREATE POLICY "Allow anon all hr_employee_settlement_applicability" ON public.hr_employee_settlement_applicability FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: authenticated_full_access_hr_employee_settlement_applicability ON hr_employee_settlement_applicability
-- ============================================
CREATE POLICY authenticated_full_access_hr_employee_settlement_applicability ON public.hr_employee_settlement_applicability FOR ALL USING ((uid() IS NOT NULL)) WITH CHECK ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon all hr_employee_ticket_issuances ON hr_employee_ticket_issuances
-- ============================================
CREATE POLICY "Allow anon all hr_employee_ticket_issuances" ON public.hr_employee_ticket_issuances FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: authenticated_full_access_hr_employee_ticket_issuances ON hr_employee_ticket_issuances
-- ============================================
CREATE POLICY authenticated_full_access_hr_employee_ticket_issuances ON public.hr_employee_ticket_issuances FOR ALL USING ((uid() IS NOT NULL)) WITH CHECK ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert hr_employees ON hr_employees
-- ============================================
CREATE POLICY "Allow anon insert hr_employees" ON public.hr_employees FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON hr_employees
-- ============================================
CREATE POLICY allow_all_operations ON public.hr_employees FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON hr_employees
-- ============================================
CREATE POLICY allow_delete ON public.hr_employees FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON hr_employees
-- ============================================
CREATE POLICY allow_insert ON public.hr_employees FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON hr_employees
-- ============================================
CREATE POLICY allow_select ON public.hr_employees FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON hr_employees
-- ============================================
CREATE POLICY allow_update ON public.hr_employees FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON hr_employees
-- ============================================
CREATE POLICY anon_full_access ON public.hr_employees FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON hr_employees
-- ============================================
CREATE POLICY authenticated_full_access ON public.hr_employees FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to hr_esob_base_rules ON hr_esob_base_rules
-- ============================================
CREATE POLICY "Allow all access to hr_esob_base_rules" ON public.hr_esob_base_rules FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to hr_esob_resignation_factors ON hr_esob_resignation_factors
-- ============================================
CREATE POLICY "Allow all access to hr_esob_resignation_factors" ON public.hr_esob_resignation_factors FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert hr_fingerprint_transactions ON hr_fingerprint_transactions
-- ============================================
CREATE POLICY "Allow anon insert hr_fingerprint_transactions" ON public.hr_fingerprint_transactions FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON hr_fingerprint_transactions
-- ============================================
CREATE POLICY allow_all_operations ON public.hr_fingerprint_transactions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON hr_fingerprint_transactions
-- ============================================
CREATE POLICY allow_delete ON public.hr_fingerprint_transactions FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON hr_fingerprint_transactions
-- ============================================
CREATE POLICY allow_insert ON public.hr_fingerprint_transactions FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON hr_fingerprint_transactions
-- ============================================
CREATE POLICY allow_select ON public.hr_fingerprint_transactions FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON hr_fingerprint_transactions
-- ============================================
CREATE POLICY allow_update ON public.hr_fingerprint_transactions FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON hr_fingerprint_transactions
-- ============================================
CREATE POLICY anon_full_access ON public.hr_fingerprint_transactions FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON hr_fingerprint_transactions
-- ============================================
CREATE POLICY authenticated_full_access ON public.hr_fingerprint_transactions FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to hr_insurance_companies ON hr_insurance_companies
-- ============================================
CREATE POLICY "Allow all access to hr_insurance_companies" ON public.hr_insurance_companies FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert hr_levels ON hr_levels
-- ============================================
CREATE POLICY "Allow anon insert hr_levels" ON public.hr_levels FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON hr_levels
-- ============================================
CREATE POLICY allow_all_operations ON public.hr_levels FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON hr_levels
-- ============================================
CREATE POLICY allow_delete ON public.hr_levels FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON hr_levels
-- ============================================
CREATE POLICY allow_insert ON public.hr_levels FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON hr_levels
-- ============================================
CREATE POLICY allow_select ON public.hr_levels FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON hr_levels
-- ============================================
CREATE POLICY allow_update ON public.hr_levels FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON hr_levels
-- ============================================
CREATE POLICY anon_full_access ON public.hr_levels FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON hr_levels
-- ============================================
CREATE POLICY authenticated_full_access ON public.hr_levels FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert hr_position_assignments ON hr_position_assignments
-- ============================================
CREATE POLICY "Allow anon insert hr_position_assignments" ON public.hr_position_assignments FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON hr_position_assignments
-- ============================================
CREATE POLICY allow_all_operations ON public.hr_position_assignments FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON hr_position_assignments
-- ============================================
CREATE POLICY allow_delete ON public.hr_position_assignments FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON hr_position_assignments
-- ============================================
CREATE POLICY allow_insert ON public.hr_position_assignments FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON hr_position_assignments
-- ============================================
CREATE POLICY allow_select ON public.hr_position_assignments FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON hr_position_assignments
-- ============================================
CREATE POLICY allow_update ON public.hr_position_assignments FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON hr_position_assignments
-- ============================================
CREATE POLICY anon_full_access ON public.hr_position_assignments FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON hr_position_assignments
-- ============================================
CREATE POLICY authenticated_full_access ON public.hr_position_assignments FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert hr_position_reporting_template ON hr_position_reporting_template
-- ============================================
CREATE POLICY "Allow anon insert hr_position_reporting_template" ON public.hr_position_reporting_template FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON hr_position_reporting_template
-- ============================================
CREATE POLICY allow_all_operations ON public.hr_position_reporting_template FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON hr_position_reporting_template
-- ============================================
CREATE POLICY allow_delete ON public.hr_position_reporting_template FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON hr_position_reporting_template
-- ============================================
CREATE POLICY allow_insert ON public.hr_position_reporting_template FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON hr_position_reporting_template
-- ============================================
CREATE POLICY allow_select ON public.hr_position_reporting_template FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON hr_position_reporting_template
-- ============================================
CREATE POLICY allow_update ON public.hr_position_reporting_template FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON hr_position_reporting_template
-- ============================================
CREATE POLICY anon_full_access ON public.hr_position_reporting_template FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON hr_position_reporting_template
-- ============================================
CREATE POLICY authenticated_full_access ON public.hr_position_reporting_template FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert hr_positions ON hr_positions
-- ============================================
CREATE POLICY "Allow anon insert hr_positions" ON public.hr_positions FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON hr_positions
-- ============================================
CREATE POLICY allow_all_operations ON public.hr_positions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON hr_positions
-- ============================================
CREATE POLICY allow_delete ON public.hr_positions FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON hr_positions
-- ============================================
CREATE POLICY allow_insert ON public.hr_positions FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON hr_positions
-- ============================================
CREATE POLICY allow_select ON public.hr_positions FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON hr_positions
-- ============================================
CREATE POLICY allow_update ON public.hr_positions FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON hr_positions
-- ============================================
CREATE POLICY anon_full_access ON public.hr_positions FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON hr_positions
-- ============================================
CREATE POLICY authenticated_full_access ON public.hr_positions FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: hr_salary_notes_delete ON hr_salary_notes
-- ============================================
CREATE POLICY hr_salary_notes_delete ON public.hr_salary_notes FOR DELETE TO authenticated USING (true);

-- ============================================
-- POLICY: hr_salary_notes_insert ON hr_salary_notes
-- ============================================
CREATE POLICY hr_salary_notes_insert ON public.hr_salary_notes FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: hr_salary_notes_select ON hr_salary_notes
-- ============================================
CREATE POLICY hr_salary_notes_select ON public.hr_salary_notes FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Allow all access to incident_actions ON incident_actions
-- ============================================
CREATE POLICY "Allow all access to incident_actions" ON public.incident_actions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to incident_types ON incident_types
-- ============================================
CREATE POLICY "Allow all access to incident_types" ON public.incident_types FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to incidents ON incidents
-- ============================================
CREATE POLICY "Allow all access to incidents" ON public.incidents FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert interface_permissions ON interface_permissions
-- ============================================
CREATE POLICY "Allow anon insert interface_permissions" ON public.interface_permissions FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON interface_permissions
-- ============================================
CREATE POLICY allow_all_operations ON public.interface_permissions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON interface_permissions
-- ============================================
CREATE POLICY allow_delete ON public.interface_permissions FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON interface_permissions
-- ============================================
CREATE POLICY allow_insert ON public.interface_permissions FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON interface_permissions
-- ============================================
CREATE POLICY allow_select ON public.interface_permissions FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON interface_permissions
-- ============================================
CREATE POLICY allow_update ON public.interface_permissions FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON interface_permissions
-- ============================================
CREATE POLICY anon_full_access ON public.interface_permissions FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON interface_permissions
-- ============================================
CREATE POLICY authenticated_full_access ON public.interface_permissions FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: interface_permissions_delete_policy ON interface_permissions
-- ============================================
CREATE POLICY interface_permissions_delete_policy ON public.interface_permissions FOR DELETE USING (true);

-- ============================================
-- POLICY: interface_permissions_insert_policy ON interface_permissions
-- ============================================
CREATE POLICY interface_permissions_insert_policy ON public.interface_permissions FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: interface_permissions_select_policy ON interface_permissions
-- ============================================
CREATE POLICY interface_permissions_select_policy ON public.interface_permissions FOR SELECT USING (true);

-- ============================================
-- POLICY: interface_permissions_update_policy ON interface_permissions
-- ============================================
CREATE POLICY interface_permissions_update_policy ON public.interface_permissions FOR UPDATE USING (true);

-- ============================================
-- POLICY: Allow all access to lease_rent_lease_parties ON lease_rent_lease_parties
-- ============================================
CREATE POLICY "Allow all access to lease_rent_lease_parties" ON public.lease_rent_lease_parties FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_payment_entries ON lease_rent_payment_entries
-- ============================================
CREATE POLICY allow_all_payment_entries ON public.lease_rent_payment_entries FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to lease_rent_payments ON lease_rent_payments
-- ============================================
CREATE POLICY "Allow all access to lease_rent_payments" ON public.lease_rent_payments FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to lease_rent_properties ON lease_rent_properties
-- ============================================
CREATE POLICY "Allow all access to lease_rent_properties" ON public.lease_rent_properties FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to lease_rent_property_spaces ON lease_rent_property_spaces
-- ============================================
CREATE POLICY "Allow all access to lease_rent_property_spaces" ON public.lease_rent_property_spaces FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to lease_rent_rent_parties ON lease_rent_rent_parties
-- ============================================
CREATE POLICY "Allow all access to lease_rent_rent_parties" ON public.lease_rent_rent_parties FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_lease_rent_special_changes ON lease_rent_special_changes
-- ============================================
CREATE POLICY allow_all_lease_rent_special_changes ON public.lease_rent_special_changes FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: loyalty_customer_bills_anon ON loyalty_customer_bills
-- ============================================
CREATE POLICY loyalty_customer_bills_anon ON public.loyalty_customer_bills FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: loyalty_customer_bills_authenticated ON loyalty_customer_bills
-- ============================================
CREATE POLICY loyalty_customer_bills_authenticated ON public.loyalty_customer_bills FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: loyalty_redemptions_anon ON loyalty_redemptions
-- ============================================
CREATE POLICY loyalty_redemptions_anon ON public.loyalty_redemptions FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: loyalty_redemptions_authenticated ON loyalty_redemptions
-- ============================================
CREATE POLICY loyalty_redemptions_authenticated ON public.loyalty_redemptions FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: loyalty_tiers_authenticated ON loyalty_tiers
-- ============================================
CREATE POLICY loyalty_tiers_authenticated ON public.loyalty_tiers FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: loyalty_tiers_public_read ON loyalty_tiers
-- ============================================
CREATE POLICY loyalty_tiers_public_read ON public.loyalty_tiers FOR SELECT USING (true);

-- ============================================
-- POLICY: Allow all access to mobile_themes ON mobile_themes
-- ============================================
CREATE POLICY "Allow all access to mobile_themes" ON public.mobile_themes FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to multi_shift_date_wise ON multi_shift_date_wise
-- ============================================
CREATE POLICY "Allow all access to multi_shift_date_wise" ON public.multi_shift_date_wise FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to multi_shift_regular ON multi_shift_regular
-- ============================================
CREATE POLICY "Allow all access to multi_shift_regular" ON public.multi_shift_regular FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to multi_shift_weekday ON multi_shift_weekday
-- ============================================
CREATE POLICY "Allow all access to multi_shift_weekday" ON public.multi_shift_weekday FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to nationalities ON nationalities
-- ============================================
CREATE POLICY "Allow all access to nationalities" ON public.nationalities FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to near_expiry_reports ON near_expiry_reports
-- ============================================
CREATE POLICY "Allow all access to near_expiry_reports" ON public.near_expiry_reports FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert non_approved_payment_scheduler ON non_approved_payment_scheduler
-- ============================================
CREATE POLICY "Allow anon insert non_approved_payment_scheduler" ON public.non_approved_payment_scheduler FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to create non approved scheduler ON non_approved_payment_scheduler
-- ============================================
CREATE POLICY "Allow authenticated users to create non approved scheduler" ON public.non_approved_payment_scheduler FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to read non approved scheduler ON non_approved_payment_scheduler
-- ============================================
CREATE POLICY "Allow authenticated users to read non approved scheduler" ON public.non_approved_payment_scheduler FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Allow authenticated users to update non approved scheduler ON non_approved_payment_scheduler
-- ============================================
CREATE POLICY "Allow authenticated users to update non approved scheduler" ON public.non_approved_payment_scheduler FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Service role has full access to non approved scheduler ON non_approved_payment_scheduler
-- ============================================
CREATE POLICY "Service role has full access to non approved scheduler" ON public.non_approved_payment_scheduler FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON non_approved_payment_scheduler
-- ============================================
CREATE POLICY allow_all_operations ON public.non_approved_payment_scheduler FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON non_approved_payment_scheduler
-- ============================================
CREATE POLICY allow_delete ON public.non_approved_payment_scheduler FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON non_approved_payment_scheduler
-- ============================================
CREATE POLICY allow_insert ON public.non_approved_payment_scheduler FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON non_approved_payment_scheduler
-- ============================================
CREATE POLICY allow_select ON public.non_approved_payment_scheduler FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON non_approved_payment_scheduler
-- ============================================
CREATE POLICY allow_update ON public.non_approved_payment_scheduler FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON non_approved_payment_scheduler
-- ============================================
CREATE POLICY anon_full_access ON public.non_approved_payment_scheduler FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON non_approved_payment_scheduler
-- ============================================
CREATE POLICY authenticated_full_access ON public.non_approved_payment_scheduler FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert notification_attachments ON notification_attachments
-- ============================================
CREATE POLICY "Allow anon insert notification_attachments" ON public.notification_attachments FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON notification_attachments
-- ============================================
CREATE POLICY allow_all_operations ON public.notification_attachments FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON notification_attachments
-- ============================================
CREATE POLICY allow_delete ON public.notification_attachments FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON notification_attachments
-- ============================================
CREATE POLICY allow_insert ON public.notification_attachments FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON notification_attachments
-- ============================================
CREATE POLICY allow_select ON public.notification_attachments FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON notification_attachments
-- ============================================
CREATE POLICY allow_update ON public.notification_attachments FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON notification_attachments
-- ============================================
CREATE POLICY anon_full_access ON public.notification_attachments FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON notification_attachments
-- ============================================
CREATE POLICY authenticated_full_access ON public.notification_attachments FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert notification_read_states ON notification_read_states
-- ============================================
CREATE POLICY "Allow anon insert notification_read_states" ON public.notification_read_states FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Users can insert own read states ON notification_read_states
-- ============================================
CREATE POLICY "Users can insert own read states" ON public.notification_read_states FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Users can update own read states ON notification_read_states
-- ============================================
CREATE POLICY "Users can update own read states" ON public.notification_read_states FOR UPDATE USING (true);

-- ============================================
-- POLICY: Users can view own read states ON notification_read_states
-- ============================================
CREATE POLICY "Users can view own read states" ON public.notification_read_states FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_all_operations ON notification_read_states
-- ============================================
CREATE POLICY allow_all_operations ON public.notification_read_states FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON notification_read_states
-- ============================================
CREATE POLICY allow_delete ON public.notification_read_states FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON notification_read_states
-- ============================================
CREATE POLICY allow_insert ON public.notification_read_states FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON notification_read_states
-- ============================================
CREATE POLICY allow_select ON public.notification_read_states FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON notification_read_states
-- ============================================
CREATE POLICY allow_update ON public.notification_read_states FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON notification_read_states
-- ============================================
CREATE POLICY anon_full_access ON public.notification_read_states FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON notification_read_states
-- ============================================
CREATE POLICY authenticated_full_access ON public.notification_read_states FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert notification_recipients ON notification_recipients
-- ============================================
CREATE POLICY "Allow anon insert notification_recipients" ON public.notification_recipients FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON notification_recipients
-- ============================================
CREATE POLICY allow_all_operations ON public.notification_recipients FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON notification_recipients
-- ============================================
CREATE POLICY allow_delete ON public.notification_recipients FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON notification_recipients
-- ============================================
CREATE POLICY allow_insert ON public.notification_recipients FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON notification_recipients
-- ============================================
CREATE POLICY allow_select ON public.notification_recipients FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON notification_recipients
-- ============================================
CREATE POLICY allow_update ON public.notification_recipients FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON notification_recipients
-- ============================================
CREATE POLICY anon_full_access ON public.notification_recipients FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON notification_recipients
-- ============================================
CREATE POLICY authenticated_full_access ON public.notification_recipients FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert notifications ON notifications
-- ============================================
CREATE POLICY "Allow anon insert notifications" ON public.notifications FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Emergency: Allow all inserts for notifications ON notifications
-- ============================================
CREATE POLICY "Emergency: Allow all inserts for notifications" ON public.notifications FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON notifications
-- ============================================
CREATE POLICY allow_all_operations ON public.notifications FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON notifications
-- ============================================
CREATE POLICY allow_delete ON public.notifications FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON notifications
-- ============================================
CREATE POLICY allow_insert ON public.notifications FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON notifications
-- ============================================
CREATE POLICY allow_select ON public.notifications FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON notifications
-- ============================================
CREATE POLICY allow_update ON public.notifications FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON notifications
-- ============================================
CREATE POLICY anon_full_access ON public.notifications FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON notifications
-- ============================================
CREATE POLICY authenticated_full_access ON public.notifications FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert offer_bundles ON offer_bundles
-- ============================================
CREATE POLICY "Allow anon insert offer_bundles" ON public.offer_bundles FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON offer_bundles
-- ============================================
CREATE POLICY allow_all_operations ON public.offer_bundles FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON offer_bundles
-- ============================================
CREATE POLICY allow_delete ON public.offer_bundles FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON offer_bundles
-- ============================================
CREATE POLICY allow_insert ON public.offer_bundles FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_public_read_bundles ON offer_bundles
-- ============================================
CREATE POLICY allow_public_read_bundles ON public.offer_bundles FOR SELECT TO authenticated, anon USING (true);

-- ============================================
-- POLICY: allow_select ON offer_bundles
-- ============================================
CREATE POLICY allow_select ON public.offer_bundles FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON offer_bundles
-- ============================================
CREATE POLICY allow_update ON public.offer_bundles FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON offer_bundles
-- ============================================
CREATE POLICY anon_full_access ON public.offer_bundles FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON offer_bundles
-- ============================================
CREATE POLICY authenticated_full_access ON public.offer_bundles FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert offer_cart_tiers ON offer_cart_tiers
-- ============================================
CREATE POLICY "Allow anon insert offer_cart_tiers" ON public.offer_cart_tiers FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: admin_all_offer_cart_tiers ON offer_cart_tiers
-- ============================================
CREATE POLICY admin_all_offer_cart_tiers ON public.offer_cart_tiers FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON offer_cart_tiers
-- ============================================
CREATE POLICY allow_all_operations ON public.offer_cart_tiers FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON offer_cart_tiers
-- ============================================
CREATE POLICY allow_delete ON public.offer_cart_tiers FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON offer_cart_tiers
-- ============================================
CREATE POLICY allow_insert ON public.offer_cart_tiers FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON offer_cart_tiers
-- ============================================
CREATE POLICY allow_select ON public.offer_cart_tiers FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON offer_cart_tiers
-- ============================================
CREATE POLICY allow_update ON public.offer_cart_tiers FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON offer_cart_tiers
-- ============================================
CREATE POLICY anon_full_access ON public.offer_cart_tiers FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON offer_cart_tiers
-- ============================================
CREATE POLICY authenticated_full_access ON public.offer_cart_tiers FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to offer_names ON offer_names
-- ============================================
CREATE POLICY "Allow all access to offer_names" ON public.offer_names FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert offer_products ON offer_products
-- ============================================
CREATE POLICY "Allow anon insert offer_products" ON public.offer_products FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Authenticated users can manage offer products ON offer_products
-- ============================================
CREATE POLICY "Authenticated users can manage offer products" ON public.offer_products FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Public can view active offer products ON offer_products
-- ============================================
CREATE POLICY "Public can view active offer products" ON public.offer_products FOR SELECT USING ((offer_id IN ( SELECT offers.id
   FROM offers
  WHERE ((offers.is_active = true) AND (offers.start_date <= now()) AND (offers.end_date >= now())))));

-- ============================================
-- POLICY: Users can delete offer products ON offer_products
-- ============================================
CREATE POLICY "Users can delete offer products" ON public.offer_products FOR DELETE USING (true);

-- ============================================
-- POLICY: Users can insert offer products ON offer_products
-- ============================================
CREATE POLICY "Users can insert offer products" ON public.offer_products FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Users can update offer products ON offer_products
-- ============================================
CREATE POLICY "Users can update offer products" ON public.offer_products FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Users can view offer products ON offer_products
-- ============================================
CREATE POLICY "Users can view offer products" ON public.offer_products FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_all_operations ON offer_products
-- ============================================
CREATE POLICY allow_all_operations ON public.offer_products FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON offer_products
-- ============================================
CREATE POLICY allow_delete ON public.offer_products FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON offer_products
-- ============================================
CREATE POLICY allow_insert ON public.offer_products FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON offer_products
-- ============================================
CREATE POLICY allow_select ON public.offer_products FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON offer_products
-- ============================================
CREATE POLICY allow_update ON public.offer_products FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON offer_products
-- ============================================
CREATE POLICY anon_full_access ON public.offer_products FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON offer_products
-- ============================================
CREATE POLICY authenticated_full_access ON public.offer_products FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert offer_usage_logs ON offer_usage_logs
-- ============================================
CREATE POLICY "Allow anon insert offer_usage_logs" ON public.offer_usage_logs FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON offer_usage_logs
-- ============================================
CREATE POLICY allow_all_operations ON public.offer_usage_logs FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON offer_usage_logs
-- ============================================
CREATE POLICY allow_delete ON public.offer_usage_logs FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON offer_usage_logs
-- ============================================
CREATE POLICY allow_insert ON public.offer_usage_logs FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON offer_usage_logs
-- ============================================
CREATE POLICY allow_select ON public.offer_usage_logs FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON offer_usage_logs
-- ============================================
CREATE POLICY allow_update ON public.offer_usage_logs FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON offer_usage_logs
-- ============================================
CREATE POLICY anon_full_access ON public.offer_usage_logs FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON offer_usage_logs
-- ============================================
CREATE POLICY authenticated_full_access ON public.offer_usage_logs FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: allow_delete_offers ON offers
-- ============================================
CREATE POLICY allow_delete_offers ON public.offers FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert_offers ON offers
-- ============================================
CREATE POLICY allow_insert_offers ON public.offers FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select_offers ON offers
-- ============================================
CREATE POLICY allow_select_offers ON public.offers FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update_offers ON offers
-- ============================================
CREATE POLICY allow_update_offers ON public.offers FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all operations on official_holidays ON official_holidays
-- ============================================
CREATE POLICY "Allow all operations on official_holidays" ON public.official_holidays FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert order_audit_logs ON order_audit_logs
-- ============================================
CREATE POLICY "Allow anon insert order_audit_logs" ON public.order_audit_logs FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON order_audit_logs
-- ============================================
CREATE POLICY allow_all_operations ON public.order_audit_logs FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON order_audit_logs
-- ============================================
CREATE POLICY allow_delete ON public.order_audit_logs FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON order_audit_logs
-- ============================================
CREATE POLICY allow_insert ON public.order_audit_logs FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON order_audit_logs
-- ============================================
CREATE POLICY allow_select ON public.order_audit_logs FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON order_audit_logs
-- ============================================
CREATE POLICY allow_update ON public.order_audit_logs FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON order_audit_logs
-- ============================================
CREATE POLICY anon_full_access ON public.order_audit_logs FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON order_audit_logs
-- ============================================
CREATE POLICY authenticated_full_access ON public.order_audit_logs FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: management_view_all_audit_logs ON order_audit_logs
-- ============================================
CREATE POLICY management_view_all_audit_logs ON public.order_audit_logs FOR SELECT USING (has_order_management_access(uid()));

-- ============================================
-- POLICY: system_insert_audit_logs ON order_audit_logs
-- ============================================
CREATE POLICY system_insert_audit_logs ON public.order_audit_logs FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: users_view_order_audit_logs ON order_audit_logs
-- ============================================
CREATE POLICY users_view_order_audit_logs ON public.order_audit_logs FOR SELECT USING ((order_id IN ( SELECT orders.id
   FROM orders
  WHERE ((orders.customer_id = uid()) OR (orders.picker_id = uid()) OR (orders.delivery_person_id = uid()) OR has_order_management_access(uid()) OR is_delivery_staff(uid())))));

-- ============================================
-- POLICY: Allow anon insert order_items ON order_items
-- ============================================
CREATE POLICY "Allow anon insert order_items" ON public.order_items FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON order_items
-- ============================================
CREATE POLICY allow_all_operations ON public.order_items FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON order_items
-- ============================================
CREATE POLICY allow_delete ON public.order_items FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON order_items
-- ============================================
CREATE POLICY allow_insert ON public.order_items FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_insert_order_items ON order_items
-- ============================================
CREATE POLICY allow_insert_order_items ON public.order_items FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON order_items
-- ============================================
CREATE POLICY allow_select ON public.order_items FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON order_items
-- ============================================
CREATE POLICY allow_update ON public.order_items FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON order_items
-- ============================================
CREATE POLICY anon_full_access ON public.order_items FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON order_items
-- ============================================
CREATE POLICY authenticated_full_access ON public.order_items FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: management_delete_order_items ON order_items
-- ============================================
CREATE POLICY management_delete_order_items ON public.order_items FOR DELETE USING (has_order_management_access(uid()));

-- ============================================
-- POLICY: management_update_order_items ON order_items
-- ============================================
CREATE POLICY management_update_order_items ON public.order_items FOR UPDATE USING (has_order_management_access(uid()));

-- ============================================
-- POLICY: system_insert_order_items ON order_items
-- ============================================
CREATE POLICY system_insert_order_items ON public.order_items FOR INSERT WITH CHECK ((order_id IN ( SELECT orders.id
   FROM orders
  WHERE ((orders.customer_id = uid()) OR has_order_management_access(uid())))));

-- ============================================
-- POLICY: users_view_order_items ON order_items
-- ============================================
CREATE POLICY users_view_order_items ON public.order_items FOR SELECT USING ((order_id IN ( SELECT orders.id
   FROM orders
  WHERE ((orders.customer_id = uid()) OR (orders.picker_id = uid()) OR (orders.delivery_person_id = uid()) OR has_order_management_access(uid()) OR is_delivery_staff(uid())))));

-- ============================================
-- POLICY: Allow anon insert orders ON orders
-- ============================================
CREATE POLICY "Allow anon insert orders" ON public.orders FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON orders
-- ============================================
CREATE POLICY allow_all_operations ON public.orders FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON orders
-- ============================================
CREATE POLICY allow_delete ON public.orders FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON orders
-- ============================================
CREATE POLICY allow_insert ON public.orders FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON orders
-- ============================================
CREATE POLICY allow_select ON public.orders FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON orders
-- ============================================
CREATE POLICY allow_update ON public.orders FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON orders
-- ============================================
CREATE POLICY anon_full_access ON public.orders FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON orders
-- ============================================
CREATE POLICY authenticated_full_access ON public.orders FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: customers_create_orders ON orders
-- ============================================
CREATE POLICY customers_create_orders ON public.orders FOR INSERT WITH CHECK ((uid() = customer_id));

-- ============================================
-- POLICY: customers_view_own_orders ON orders
-- ============================================
CREATE POLICY customers_view_own_orders ON public.orders FOR SELECT USING (((uid() = customer_id) OR has_order_management_access(uid()) OR is_delivery_staff(uid())));

-- ============================================
-- POLICY: delivery_update_assigned_orders ON orders
-- ============================================
CREATE POLICY delivery_update_assigned_orders ON public.orders FOR UPDATE USING (((delivery_person_id = uid()) OR is_delivery_staff(uid()))) WITH CHECK ((((delivery_person_id = uid()) OR is_delivery_staff(uid())) AND ((order_status)::text = ANY (ARRAY[('out_for_delivery'::character varying)::text, ('delivered'::character varying)::text]))));

-- ============================================
-- POLICY: delivery_view_assigned_orders ON orders
-- ============================================
CREATE POLICY delivery_view_assigned_orders ON public.orders FOR SELECT USING (((delivery_person_id = uid()) OR is_delivery_staff(uid()) OR has_order_management_access(uid())));

-- ============================================
-- POLICY: management_update_orders ON orders
-- ============================================
CREATE POLICY management_update_orders ON public.orders FOR UPDATE USING (has_order_management_access(uid()));

-- ============================================
-- POLICY: management_view_all_orders ON orders
-- ============================================
CREATE POLICY management_view_all_orders ON public.orders FOR SELECT USING ((has_order_management_access(uid()) OR (picker_id = uid()) OR (delivery_person_id = uid())));

-- ============================================
-- POLICY: pickers_update_assigned_orders ON orders
-- ============================================
CREATE POLICY pickers_update_assigned_orders ON public.orders FOR UPDATE USING ((picker_id = uid())) WITH CHECK (((picker_id = uid()) AND ((order_status)::text = ANY (ARRAY[('in_picking'::character varying)::text, ('ready'::character varying)::text]))));

-- ============================================
-- POLICY: pickers_view_assigned_orders ON orders
-- ============================================
CREATE POLICY pickers_view_assigned_orders ON public.orders FOR SELECT USING (((picker_id = uid()) OR has_order_management_access(uid())));

-- ============================================
-- POLICY: overtime_registrations_all ON overtime_registrations
-- ============================================
CREATE POLICY overtime_registrations_all ON public.overtime_registrations FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to pos_deduction_transfer_edits ON pos_deduction_transfer_edits
-- ============================================
CREATE POLICY "Allow all access to pos_deduction_transfer_edits" ON public.pos_deduction_transfer_edits FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to pos_deduction_transfers ON pos_deduction_transfers
-- ============================================
CREATE POLICY "Allow all access to pos_deduction_transfers" ON public.pos_deduction_transfers FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert privilege_cards_branch ON privilege_cards_branch
-- ============================================
CREATE POLICY "Allow anon insert privilege_cards_branch" ON public.privilege_cards_branch FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to create privilege_cards_branch ON privilege_cards_branch
-- ============================================
CREATE POLICY "Allow authenticated users to create privilege_cards_branch" ON public.privilege_cards_branch FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to read privilege_cards_branch ON privilege_cards_branch
-- ============================================
CREATE POLICY "Allow authenticated users to read privilege_cards_branch" ON public.privilege_cards_branch FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Allow authenticated users to update privilege_cards_branch ON privilege_cards_branch
-- ============================================
CREATE POLICY "Allow authenticated users to update privilege_cards_branch" ON public.privilege_cards_branch FOR UPDATE TO authenticated USING (true);

-- ============================================
-- POLICY: Service role has full access to privilege_cards_branch ON privilege_cards_branch
-- ============================================
CREATE POLICY "Service role has full access to privilege_cards_branch" ON public.privilege_cards_branch FOR ALL TO service_role USING (true);

-- ============================================
-- POLICY: allow_all_operations ON privilege_cards_branch
-- ============================================
CREATE POLICY allow_all_operations ON public.privilege_cards_branch FOR ALL USING (true);

-- ============================================
-- POLICY: allow_delete ON privilege_cards_branch
-- ============================================
CREATE POLICY allow_delete ON public.privilege_cards_branch FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON privilege_cards_branch
-- ============================================
CREATE POLICY allow_insert ON public.privilege_cards_branch FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON privilege_cards_branch
-- ============================================
CREATE POLICY allow_select ON public.privilege_cards_branch FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON privilege_cards_branch
-- ============================================
CREATE POLICY allow_update ON public.privilege_cards_branch FOR UPDATE USING (true);

-- ============================================
-- POLICY: anon_full_access ON privilege_cards_branch
-- ============================================
CREATE POLICY anon_full_access ON public.privilege_cards_branch FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON privilege_cards_branch
-- ============================================
CREATE POLICY authenticated_full_access ON public.privilege_cards_branch FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert privilege_cards_master ON privilege_cards_master
-- ============================================
CREATE POLICY "Allow anon insert privilege_cards_master" ON public.privilege_cards_master FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to create privilege_cards_master ON privilege_cards_master
-- ============================================
CREATE POLICY "Allow authenticated users to create privilege_cards_master" ON public.privilege_cards_master FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to read privilege_cards_master ON privilege_cards_master
-- ============================================
CREATE POLICY "Allow authenticated users to read privilege_cards_master" ON public.privilege_cards_master FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Allow authenticated users to update privilege_cards_master ON privilege_cards_master
-- ============================================
CREATE POLICY "Allow authenticated users to update privilege_cards_master" ON public.privilege_cards_master FOR UPDATE TO authenticated USING (true);

-- ============================================
-- POLICY: Service role has full access to privilege_cards_master ON privilege_cards_master
-- ============================================
CREATE POLICY "Service role has full access to privilege_cards_master" ON public.privilege_cards_master FOR ALL TO service_role USING (true);

-- ============================================
-- POLICY: allow_all_operations ON privilege_cards_master
-- ============================================
CREATE POLICY allow_all_operations ON public.privilege_cards_master FOR ALL USING (true);

-- ============================================
-- POLICY: allow_delete ON privilege_cards_master
-- ============================================
CREATE POLICY allow_delete ON public.privilege_cards_master FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON privilege_cards_master
-- ============================================
CREATE POLICY allow_insert ON public.privilege_cards_master FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON privilege_cards_master
-- ============================================
CREATE POLICY allow_select ON public.privilege_cards_master FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON privilege_cards_master
-- ============================================
CREATE POLICY allow_update ON public.privilege_cards_master FOR UPDATE USING (true);

-- ============================================
-- POLICY: anon_full_access ON privilege_cards_master
-- ============================================
CREATE POLICY anon_full_access ON public.privilege_cards_master FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON privilege_cards_master
-- ============================================
CREATE POLICY authenticated_full_access ON public.privilege_cards_master FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to processed_fingerprint_transactions ON processed_fingerprint_transactions
-- ============================================
CREATE POLICY "Allow all access to processed_fingerprint_transactions" ON public.processed_fingerprint_transactions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to product_categories ON product_categories
-- ============================================
CREATE POLICY "Allow all access to product_categories" ON public.product_categories FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to product_request_bt ON product_request_bt
-- ============================================
CREATE POLICY "Allow all access to product_request_bt" ON public.product_request_bt FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to product_request_po ON product_request_po
-- ============================================
CREATE POLICY "Allow all access to product_request_po" ON public.product_request_po FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to product_request_st ON product_request_st
-- ============================================
CREATE POLICY "Allow all access to product_request_st" ON public.product_request_st FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to product_units ON product_units
-- ============================================
CREATE POLICY "Allow all access to product_units" ON public.product_units FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete_all ON products
-- ============================================
CREATE POLICY allow_delete_all ON public.products FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert_all ON products
-- ============================================
CREATE POLICY allow_insert_all ON public.products FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select_all ON products
-- ============================================
CREATE POLICY allow_select_all ON public.products FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update_all ON products
-- ============================================
CREATE POLICY allow_update_all ON public.products FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: pv_issue_types_authenticated_all ON purchase_voucher_issue_types
-- ============================================
CREATE POLICY pv_issue_types_authenticated_all ON public.purchase_voucher_issue_types FOR ALL USING (true);

-- ============================================
-- POLICY: pv_issue_types_service_role_all ON purchase_voucher_issue_types
-- ============================================
CREATE POLICY pv_issue_types_service_role_all ON public.purchase_voucher_issue_types FOR ALL USING (true);

-- ============================================
-- POLICY: pvi_authenticated_all ON purchase_voucher_items
-- ============================================
CREATE POLICY pvi_authenticated_all ON public.purchase_voucher_items FOR ALL USING (true);

-- ============================================
-- POLICY: pvi_service_role_all ON purchase_voucher_items
-- ============================================
CREATE POLICY pvi_service_role_all ON public.purchase_voucher_items FOR ALL USING (true);

-- ============================================
-- POLICY: pv_authenticated_all ON purchase_vouchers
-- ============================================
CREATE POLICY pv_authenticated_all ON public.purchase_vouchers FOR ALL USING (true);

-- ============================================
-- POLICY: pv_service_role_all ON purchase_vouchers
-- ============================================
CREATE POLICY pv_service_role_all ON public.purchase_vouchers FOR ALL USING (true);

-- ============================================
-- POLICY: Allow all access to push_subscriptions ON push_subscriptions
-- ============================================
CREATE POLICY "Allow all access to push_subscriptions" ON public.push_subscriptions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert quick_task_assignments ON quick_task_assignments
-- ============================================
CREATE POLICY "Allow anon insert quick_task_assignments" ON public.quick_task_assignments FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow service role full access to quick_task_assignments ON quick_task_assignments
-- ============================================
CREATE POLICY "Allow service role full access to quick_task_assignments" ON public.quick_task_assignments FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON quick_task_assignments
-- ============================================
CREATE POLICY allow_all_operations ON public.quick_task_assignments FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON quick_task_assignments
-- ============================================
CREATE POLICY allow_delete ON public.quick_task_assignments FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON quick_task_assignments
-- ============================================
CREATE POLICY allow_insert ON public.quick_task_assignments FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON quick_task_assignments
-- ============================================
CREATE POLICY allow_select ON public.quick_task_assignments FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON quick_task_assignments
-- ============================================
CREATE POLICY allow_update ON public.quick_task_assignments FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON quick_task_assignments
-- ============================================
CREATE POLICY anon_full_access ON public.quick_task_assignments FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON quick_task_assignments
-- ============================================
CREATE POLICY authenticated_full_access ON public.quick_task_assignments FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert quick_task_comments ON quick_task_comments
-- ============================================
CREATE POLICY "Allow anon insert quick_task_comments" ON public.quick_task_comments FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON quick_task_comments
-- ============================================
CREATE POLICY allow_all_operations ON public.quick_task_comments FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON quick_task_comments
-- ============================================
CREATE POLICY allow_delete ON public.quick_task_comments FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON quick_task_comments
-- ============================================
CREATE POLICY allow_insert ON public.quick_task_comments FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON quick_task_comments
-- ============================================
CREATE POLICY allow_select ON public.quick_task_comments FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON quick_task_comments
-- ============================================
CREATE POLICY allow_update ON public.quick_task_comments FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON quick_task_comments
-- ============================================
CREATE POLICY anon_full_access ON public.quick_task_comments FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON quick_task_comments
-- ============================================
CREATE POLICY authenticated_full_access ON public.quick_task_comments FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert quick_task_completions ON quick_task_completions
-- ============================================
CREATE POLICY "Allow anon insert quick_task_completions" ON public.quick_task_completions FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow service role full access to quick_task_completions ON quick_task_completions
-- ============================================
CREATE POLICY "Allow service role full access to quick_task_completions" ON public.quick_task_completions FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Managers can verify completions ON quick_task_completions
-- ============================================
CREATE POLICY "Managers can verify completions" ON public.quick_task_completions FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = uid()) AND (users.user_type = 'global'::user_type_enum)))));

-- ============================================
-- POLICY: Managers can view all completions ON quick_task_completions
-- ============================================
CREATE POLICY "Managers can view all completions" ON public.quick_task_completions FOR SELECT USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = uid()) AND (users.user_type = 'global'::user_type_enum)))));

-- ============================================
-- POLICY: Users can insert their own completions ON quick_task_completions
-- ============================================
CREATE POLICY "Users can insert their own completions" ON public.quick_task_completions FOR INSERT WITH CHECK ((completed_by_user_id = uid()));

-- ============================================
-- POLICY: Users can update their own completions ON quick_task_completions
-- ============================================
CREATE POLICY "Users can update their own completions" ON public.quick_task_completions FOR UPDATE USING ((completed_by_user_id = uid()));

-- ============================================
-- POLICY: Users can view their own completions ON quick_task_completions
-- ============================================
CREATE POLICY "Users can view their own completions" ON public.quick_task_completions FOR SELECT USING ((completed_by_user_id = uid()));

-- ============================================
-- POLICY: allow_all_operations ON quick_task_completions
-- ============================================
CREATE POLICY allow_all_operations ON public.quick_task_completions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON quick_task_completions
-- ============================================
CREATE POLICY allow_delete ON public.quick_task_completions FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON quick_task_completions
-- ============================================
CREATE POLICY allow_insert ON public.quick_task_completions FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON quick_task_completions
-- ============================================
CREATE POLICY allow_select ON public.quick_task_completions FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON quick_task_completions
-- ============================================
CREATE POLICY allow_update ON public.quick_task_completions FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON quick_task_completions
-- ============================================
CREATE POLICY anon_full_access ON public.quick_task_completions FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON quick_task_completions
-- ============================================
CREATE POLICY authenticated_full_access ON public.quick_task_completions FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert quick_task_files ON quick_task_files
-- ============================================
CREATE POLICY "Allow anon insert quick_task_files" ON public.quick_task_files FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON quick_task_files
-- ============================================
CREATE POLICY allow_all_operations ON public.quick_task_files FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON quick_task_files
-- ============================================
CREATE POLICY allow_delete ON public.quick_task_files FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON quick_task_files
-- ============================================
CREATE POLICY allow_insert ON public.quick_task_files FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON quick_task_files
-- ============================================
CREATE POLICY allow_select ON public.quick_task_files FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON quick_task_files
-- ============================================
CREATE POLICY allow_update ON public.quick_task_files FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON quick_task_files
-- ============================================
CREATE POLICY anon_full_access ON public.quick_task_files FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON quick_task_files
-- ============================================
CREATE POLICY authenticated_full_access ON public.quick_task_files FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert quick_task_user_preferences ON quick_task_user_preferences
-- ============================================
CREATE POLICY "Allow anon insert quick_task_user_preferences" ON public.quick_task_user_preferences FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Users can delete their own preferences ON quick_task_user_preferences
-- ============================================
CREATE POLICY "Users can delete their own preferences" ON public.quick_task_user_preferences FOR DELETE USING ((uid() = user_id));

-- ============================================
-- POLICY: Users can insert their own preferences ON quick_task_user_preferences
-- ============================================
CREATE POLICY "Users can insert their own preferences" ON public.quick_task_user_preferences FOR INSERT WITH CHECK ((uid() = user_id));

-- ============================================
-- POLICY: Users can update their own preferences ON quick_task_user_preferences
-- ============================================
CREATE POLICY "Users can update their own preferences" ON public.quick_task_user_preferences FOR UPDATE USING ((uid() = user_id)) WITH CHECK ((uid() = user_id));

-- ============================================
-- POLICY: Users can view their own preferences ON quick_task_user_preferences
-- ============================================
CREATE POLICY "Users can view their own preferences" ON public.quick_task_user_preferences FOR SELECT USING ((uid() = user_id));

-- ============================================
-- POLICY: allow_all_operations ON quick_task_user_preferences
-- ============================================
CREATE POLICY allow_all_operations ON public.quick_task_user_preferences FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON quick_task_user_preferences
-- ============================================
CREATE POLICY allow_delete ON public.quick_task_user_preferences FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON quick_task_user_preferences
-- ============================================
CREATE POLICY allow_insert ON public.quick_task_user_preferences FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON quick_task_user_preferences
-- ============================================
CREATE POLICY allow_select ON public.quick_task_user_preferences FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON quick_task_user_preferences
-- ============================================
CREATE POLICY allow_update ON public.quick_task_user_preferences FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON quick_task_user_preferences
-- ============================================
CREATE POLICY anon_full_access ON public.quick_task_user_preferences FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON quick_task_user_preferences
-- ============================================
CREATE POLICY authenticated_full_access ON public.quick_task_user_preferences FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert quick_tasks ON quick_tasks
-- ============================================
CREATE POLICY "Allow anon insert quick_tasks" ON public.quick_tasks FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow service role full access to quick_tasks ON quick_tasks
-- ============================================
CREATE POLICY "Allow service role full access to quick_tasks" ON public.quick_tasks FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON quick_tasks
-- ============================================
CREATE POLICY allow_all_operations ON public.quick_tasks FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON quick_tasks
-- ============================================
CREATE POLICY allow_delete ON public.quick_tasks FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON quick_tasks
-- ============================================
CREATE POLICY allow_insert ON public.quick_tasks FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON quick_tasks
-- ============================================
CREATE POLICY allow_select ON public.quick_tasks FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON quick_tasks
-- ============================================
CREATE POLICY allow_update ON public.quick_tasks FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON quick_tasks
-- ============================================
CREATE POLICY anon_full_access ON public.quick_tasks FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON quick_tasks
-- ============================================
CREATE POLICY authenticated_full_access ON public.quick_tasks FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: allow_delete ON receiving_records
-- ============================================
CREATE POLICY allow_delete ON public.receiving_records FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON receiving_records
-- ============================================
CREATE POLICY allow_insert ON public.receiving_records FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON receiving_records
-- ============================================
CREATE POLICY allow_select ON public.receiving_records FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON receiving_records
-- ============================================
CREATE POLICY allow_update ON public.receiving_records FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: rls_delete ON receiving_records
-- ============================================
CREATE POLICY rls_delete ON public.receiving_records FOR DELETE USING (true);

-- ============================================
-- POLICY: rls_insert ON receiving_records
-- ============================================
CREATE POLICY rls_insert ON public.receiving_records FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: rls_select ON receiving_records
-- ============================================
CREATE POLICY rls_select ON public.receiving_records FOR SELECT USING (true);

-- ============================================
-- POLICY: rls_update ON receiving_records
-- ============================================
CREATE POLICY rls_update ON public.receiving_records FOR UPDATE WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert receiving_task_templates ON receiving_task_templates
-- ============================================
CREATE POLICY "Allow anon insert receiving_task_templates" ON public.receiving_task_templates FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON receiving_task_templates
-- ============================================
CREATE POLICY allow_all_operations ON public.receiving_task_templates FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON receiving_task_templates
-- ============================================
CREATE POLICY allow_delete ON public.receiving_task_templates FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON receiving_task_templates
-- ============================================
CREATE POLICY allow_insert ON public.receiving_task_templates FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON receiving_task_templates
-- ============================================
CREATE POLICY allow_select ON public.receiving_task_templates FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON receiving_task_templates
-- ============================================
CREATE POLICY allow_update ON public.receiving_task_templates FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON receiving_task_templates
-- ============================================
CREATE POLICY anon_full_access ON public.receiving_task_templates FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON receiving_task_templates
-- ============================================
CREATE POLICY authenticated_full_access ON public.receiving_task_templates FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert receiving_tasks ON receiving_tasks
-- ============================================
CREATE POLICY "Allow anon insert receiving_tasks" ON public.receiving_tasks FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON receiving_tasks
-- ============================================
CREATE POLICY allow_all_operations ON public.receiving_tasks FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON receiving_tasks
-- ============================================
CREATE POLICY allow_delete ON public.receiving_tasks FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON receiving_tasks
-- ============================================
CREATE POLICY allow_insert ON public.receiving_tasks FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON receiving_tasks
-- ============================================
CREATE POLICY allow_select ON public.receiving_tasks FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON receiving_tasks
-- ============================================
CREATE POLICY allow_update ON public.receiving_tasks FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON receiving_tasks
-- ============================================
CREATE POLICY anon_full_access ON public.receiving_tasks FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON receiving_tasks
-- ============================================
CREATE POLICY authenticated_full_access ON public.receiving_tasks FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to receiving_user_defaults ON receiving_user_defaults
-- ============================================
CREATE POLICY "Allow all access to receiving_user_defaults" ON public.receiving_user_defaults FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert recurring_assignment_schedules ON recurring_assignment_schedules
-- ============================================
CREATE POLICY "Allow anon insert recurring_assignment_schedules" ON public.recurring_assignment_schedules FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON recurring_assignment_schedules
-- ============================================
CREATE POLICY allow_all_operations ON public.recurring_assignment_schedules FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON recurring_assignment_schedules
-- ============================================
CREATE POLICY allow_delete ON public.recurring_assignment_schedules FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON recurring_assignment_schedules
-- ============================================
CREATE POLICY allow_insert ON public.recurring_assignment_schedules FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON recurring_assignment_schedules
-- ============================================
CREATE POLICY allow_select ON public.recurring_assignment_schedules FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON recurring_assignment_schedules
-- ============================================
CREATE POLICY allow_update ON public.recurring_assignment_schedules FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON recurring_assignment_schedules
-- ============================================
CREATE POLICY anon_full_access ON public.recurring_assignment_schedules FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON recurring_assignment_schedules
-- ============================================
CREATE POLICY authenticated_full_access ON public.recurring_assignment_schedules FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert recurring_schedule_check_log ON recurring_schedule_check_log
-- ============================================
CREATE POLICY "Allow anon insert recurring_schedule_check_log" ON public.recurring_schedule_check_log FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Only global users can view check logs ON recurring_schedule_check_log
-- ============================================
CREATE POLICY "Only global users can view check logs" ON public.recurring_schedule_check_log FOR SELECT USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = uid()) AND (users.user_type = 'global'::user_type_enum)))));

-- ============================================
-- POLICY: allow_all_operations ON recurring_schedule_check_log
-- ============================================
CREATE POLICY allow_all_operations ON public.recurring_schedule_check_log FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON recurring_schedule_check_log
-- ============================================
CREATE POLICY allow_delete ON public.recurring_schedule_check_log FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON recurring_schedule_check_log
-- ============================================
CREATE POLICY allow_insert ON public.recurring_schedule_check_log FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON recurring_schedule_check_log
-- ============================================
CREATE POLICY allow_select ON public.recurring_schedule_check_log FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON recurring_schedule_check_log
-- ============================================
CREATE POLICY allow_update ON public.recurring_schedule_check_log FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON recurring_schedule_check_log
-- ============================================
CREATE POLICY anon_full_access ON public.recurring_schedule_check_log FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON recurring_schedule_check_log
-- ============================================
CREATE POLICY authenticated_full_access ON public.recurring_schedule_check_log FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to regular_shift ON regular_shift
-- ============================================
CREATE POLICY "Allow all access to regular_shift" ON public.regular_shift FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert requesters ON requesters
-- ============================================
CREATE POLICY "Allow anon insert requesters" ON public.requesters FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Users can insert requesters ON requesters
-- ============================================
CREATE POLICY "Users can insert requesters" ON public.requesters FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Users can update requesters ON requesters
-- ============================================
CREATE POLICY "Users can update requesters" ON public.requesters FOR UPDATE USING (true);

-- ============================================
-- POLICY: Users can view all requesters ON requesters
-- ============================================
CREATE POLICY "Users can view all requesters" ON public.requesters FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_all_operations ON requesters
-- ============================================
CREATE POLICY allow_all_operations ON public.requesters FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON requesters
-- ============================================
CREATE POLICY allow_delete ON public.requesters FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON requesters
-- ============================================
CREATE POLICY allow_insert ON public.requesters FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON requesters
-- ============================================
CREATE POLICY allow_select ON public.requesters FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON requesters
-- ============================================
CREATE POLICY allow_update ON public.requesters FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON requesters
-- ============================================
CREATE POLICY anon_full_access ON public.requesters FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON requesters
-- ============================================
CREATE POLICY authenticated_full_access ON public.requesters FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon read ON security_code_scroll_texts
-- ============================================
CREATE POLICY "Allow anon read" ON public.security_code_scroll_texts FOR SELECT TO anon USING (true);

-- ============================================
-- POLICY: Allow authenticated delete ON security_code_scroll_texts
-- ============================================
CREATE POLICY "Allow authenticated delete" ON public.security_code_scroll_texts FOR DELETE TO authenticated USING (true);

-- ============================================
-- POLICY: Allow authenticated insert ON security_code_scroll_texts
-- ============================================
CREATE POLICY "Allow authenticated insert" ON public.security_code_scroll_texts FOR INSERT TO authenticated WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated read ON security_code_scroll_texts
-- ============================================
CREATE POLICY "Allow authenticated read" ON public.security_code_scroll_texts FOR SELECT TO authenticated USING (true);

-- ============================================
-- POLICY: Allow authenticated update ON security_code_scroll_texts
-- ============================================
CREATE POLICY "Allow authenticated update" ON public.security_code_scroll_texts FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon all settlement_rules ON settlement_rules
-- ============================================
CREATE POLICY "Allow anon all settlement_rules" ON public.settlement_rules FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: authenticated_full_access ON settlement_rules
-- ============================================
CREATE POLICY authenticated_full_access ON public.settlement_rules FOR ALL USING ((uid() IS NOT NULL)) WITH CHECK ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to shelf_paper_fonts ON shelf_paper_fonts
-- ============================================
CREATE POLICY "Allow all access to shelf_paper_fonts" ON public.shelf_paper_fonts FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert shelf_paper_templates ON shelf_paper_templates
-- ============================================
CREATE POLICY "Allow anon insert shelf_paper_templates" ON public.shelf_paper_templates FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Users can create templates ON shelf_paper_templates
-- ============================================
CREATE POLICY "Users can create templates" ON public.shelf_paper_templates FOR INSERT WITH CHECK ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Users can delete own templates ON shelf_paper_templates
-- ============================================
CREATE POLICY "Users can delete own templates" ON public.shelf_paper_templates FOR DELETE USING ((created_by = uid()));

-- ============================================
-- POLICY: Users can update own templates ON shelf_paper_templates
-- ============================================
CREATE POLICY "Users can update own templates" ON public.shelf_paper_templates FOR UPDATE USING ((created_by = uid()));

-- ============================================
-- POLICY: Users can view active templates ON shelf_paper_templates
-- ============================================
CREATE POLICY "Users can view active templates" ON public.shelf_paper_templates FOR SELECT USING ((is_active = true));

-- ============================================
-- POLICY: allow_all_operations ON shelf_paper_templates
-- ============================================
CREATE POLICY allow_all_operations ON public.shelf_paper_templates FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON shelf_paper_templates
-- ============================================
CREATE POLICY allow_delete ON public.shelf_paper_templates FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON shelf_paper_templates
-- ============================================
CREATE POLICY allow_insert ON public.shelf_paper_templates FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON shelf_paper_templates
-- ============================================
CREATE POLICY allow_select ON public.shelf_paper_templates FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON shelf_paper_templates
-- ============================================
CREATE POLICY allow_update ON public.shelf_paper_templates FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON shelf_paper_templates
-- ============================================
CREATE POLICY anon_full_access ON public.shelf_paper_templates FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON shelf_paper_templates
-- ============================================
CREATE POLICY authenticated_full_access ON public.shelf_paper_templates FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Anyone can read sidebar_animations ON sidebar_animations
-- ============================================
CREATE POLICY "Anyone can read sidebar_animations" ON public.sidebar_animations FOR SELECT USING (true);

-- ============================================
-- POLICY: Service role can manage sidebar_animations ON sidebar_animations
-- ============================================
CREATE POLICY "Service role can manage sidebar_animations" ON public.sidebar_animations FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON sidebar_buttons
-- ============================================
CREATE POLICY allow_delete ON public.sidebar_buttons FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON sidebar_buttons
-- ============================================
CREATE POLICY allow_insert ON public.sidebar_buttons FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON sidebar_buttons
-- ============================================
CREATE POLICY allow_select ON public.sidebar_buttons FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON sidebar_buttons
-- ============================================
CREATE POLICY allow_update ON public.sidebar_buttons FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Enable all access for social_links ON social_links
-- ============================================
CREATE POLICY "Enable all access for social_links" ON public.social_links FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all operations on special_shift_date_wise ON special_shift_date_wise
-- ============================================
CREATE POLICY "Allow all operations on special_shift_date_wise" ON public.special_shift_date_wise FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: special_shift_weekday_policy ON special_shift_weekday
-- ============================================
CREATE POLICY special_shift_weekday_policy ON public.special_shift_weekday FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_all_surprise_box_plays ON surprise_box_plays
-- ============================================
CREATE POLICY anon_all_surprise_box_plays ON public.surprise_box_plays FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: auth_all_surprise_box_plays ON surprise_box_plays
-- ============================================
CREATE POLICY auth_all_surprise_box_plays ON public.surprise_box_plays FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_all_surprise_box_rewards ON surprise_box_rewards
-- ============================================
CREATE POLICY anon_all_surprise_box_rewards ON public.surprise_box_rewards FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: auth_all_surprise_box_rewards ON surprise_box_rewards
-- ============================================
CREATE POLICY auth_all_surprise_box_rewards ON public.surprise_box_rewards FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_all_surprise_box_settings ON surprise_box_settings
-- ============================================
CREATE POLICY anon_all_surprise_box_settings ON public.surprise_box_settings FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: auth_all_surprise_box_settings ON surprise_box_settings
-- ============================================
CREATE POLICY auth_all_surprise_box_settings ON public.surprise_box_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_all_surprise_box_vouchers ON surprise_box_vouchers
-- ============================================
CREATE POLICY anon_all_surprise_box_vouchers ON public.surprise_box_vouchers FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: auth_all_surprise_box_vouchers ON surprise_box_vouchers
-- ============================================
CREATE POLICY auth_all_surprise_box_vouchers ON public.surprise_box_vouchers FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Enable all access to system_api_keys ON system_api_keys
-- ============================================
CREATE POLICY "Enable all access to system_api_keys" ON public.system_api_keys FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert task_assignments ON task_assignments
-- ============================================
CREATE POLICY "Allow anon insert task_assignments" ON public.task_assignments FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow service role full access to task_assignments ON task_assignments
-- ============================================
CREATE POLICY "Allow service role full access to task_assignments" ON public.task_assignments FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Emergency: Allow all inserts for task_assignments ON task_assignments
-- ============================================
CREATE POLICY "Emergency: Allow all inserts for task_assignments" ON public.task_assignments FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Simple create task assignments policy ON task_assignments
-- ============================================
CREATE POLICY "Simple create task assignments policy" ON public.task_assignments FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Simple update task assignments policy ON task_assignments
-- ============================================
CREATE POLICY "Simple update task assignments policy" ON public.task_assignments FOR UPDATE USING (true);

-- ============================================
-- POLICY: Simple view task assignments policy ON task_assignments
-- ============================================
CREATE POLICY "Simple view task assignments policy" ON public.task_assignments FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_all_operations ON task_assignments
-- ============================================
CREATE POLICY allow_all_operations ON public.task_assignments FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON task_assignments
-- ============================================
CREATE POLICY allow_delete ON public.task_assignments FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON task_assignments
-- ============================================
CREATE POLICY allow_insert ON public.task_assignments FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON task_assignments
-- ============================================
CREATE POLICY allow_select ON public.task_assignments FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON task_assignments
-- ============================================
CREATE POLICY allow_update ON public.task_assignments FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON task_assignments
-- ============================================
CREATE POLICY anon_full_access ON public.task_assignments FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON task_assignments
-- ============================================
CREATE POLICY authenticated_full_access ON public.task_assignments FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert task_completions ON task_completions
-- ============================================
CREATE POLICY "Allow anon insert task_completions" ON public.task_completions FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow service role full access to task_completions ON task_completions
-- ============================================
CREATE POLICY "Allow service role full access to task_completions" ON public.task_completions FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Simple create task completions policy ON task_completions
-- ============================================
CREATE POLICY "Simple create task completions policy" ON public.task_completions FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Simple update task completions policy ON task_completions
-- ============================================
CREATE POLICY "Simple update task completions policy" ON public.task_completions FOR UPDATE USING (true);

-- ============================================
-- POLICY: Simple view task completions policy ON task_completions
-- ============================================
CREATE POLICY "Simple view task completions policy" ON public.task_completions FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_all_operations ON task_completions
-- ============================================
CREATE POLICY allow_all_operations ON public.task_completions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON task_completions
-- ============================================
CREATE POLICY allow_delete ON public.task_completions FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON task_completions
-- ============================================
CREATE POLICY allow_insert ON public.task_completions FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON task_completions
-- ============================================
CREATE POLICY allow_select ON public.task_completions FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON task_completions
-- ============================================
CREATE POLICY allow_update ON public.task_completions FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON task_completions
-- ============================================
CREATE POLICY anon_full_access ON public.task_completions FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON task_completions
-- ============================================
CREATE POLICY authenticated_full_access ON public.task_completions FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert task_images ON task_images
-- ============================================
CREATE POLICY "Allow anon insert task_images" ON public.task_images FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Simple create task images policy ON task_images
-- ============================================
CREATE POLICY "Simple create task images policy" ON public.task_images FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Simple delete task images policy ON task_images
-- ============================================
CREATE POLICY "Simple delete task images policy" ON public.task_images FOR DELETE USING (true);

-- ============================================
-- POLICY: Simple update task images policy ON task_images
-- ============================================
CREATE POLICY "Simple update task images policy" ON public.task_images FOR UPDATE USING (true);

-- ============================================
-- POLICY: Simple view task images policy ON task_images
-- ============================================
CREATE POLICY "Simple view task images policy" ON public.task_images FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_all_operations ON task_images
-- ============================================
CREATE POLICY allow_all_operations ON public.task_images FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON task_images
-- ============================================
CREATE POLICY allow_delete ON public.task_images FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON task_images
-- ============================================
CREATE POLICY allow_insert ON public.task_images FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON task_images
-- ============================================
CREATE POLICY allow_select ON public.task_images FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON task_images
-- ============================================
CREATE POLICY allow_update ON public.task_images FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON task_images
-- ============================================
CREATE POLICY anon_full_access ON public.task_images FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON task_images
-- ============================================
CREATE POLICY authenticated_full_access ON public.task_images FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert task_reminder_logs ON task_reminder_logs
-- ============================================
CREATE POLICY "Allow anon insert task_reminder_logs" ON public.task_reminder_logs FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Authenticated users can view all reminder logs ON task_reminder_logs
-- ============================================
CREATE POLICY "Authenticated users can view all reminder logs" ON public.task_reminder_logs FOR SELECT USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Service role can insert reminder logs ON task_reminder_logs
-- ============================================
CREATE POLICY "Service role can insert reminder logs" ON public.task_reminder_logs FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Users can view their own reminder logs ON task_reminder_logs
-- ============================================
CREATE POLICY "Users can view their own reminder logs" ON public.task_reminder_logs FOR SELECT USING ((assigned_to_user_id = uid()));

-- ============================================
-- POLICY: allow_all_operations ON task_reminder_logs
-- ============================================
CREATE POLICY allow_all_operations ON public.task_reminder_logs FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON task_reminder_logs
-- ============================================
CREATE POLICY allow_delete ON public.task_reminder_logs FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON task_reminder_logs
-- ============================================
CREATE POLICY allow_insert ON public.task_reminder_logs FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON task_reminder_logs
-- ============================================
CREATE POLICY allow_select ON public.task_reminder_logs FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON task_reminder_logs
-- ============================================
CREATE POLICY allow_update ON public.task_reminder_logs FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON task_reminder_logs
-- ============================================
CREATE POLICY anon_full_access ON public.task_reminder_logs FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON task_reminder_logs
-- ============================================
CREATE POLICY authenticated_full_access ON public.task_reminder_logs FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert tasks ON tasks
-- ============================================
CREATE POLICY "Allow anon insert tasks" ON public.tasks FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow service role full access to tasks ON tasks
-- ============================================
CREATE POLICY "Allow service role full access to tasks" ON public.tasks FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Emergency: Allow all inserts for tasks ON tasks
-- ============================================
CREATE POLICY "Emergency: Allow all inserts for tasks" ON public.tasks FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Simple create tasks policy ON tasks
-- ============================================
CREATE POLICY "Simple create tasks policy" ON public.tasks FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Simple update tasks policy ON tasks
-- ============================================
CREATE POLICY "Simple update tasks policy" ON public.tasks FOR UPDATE USING (true);

-- ============================================
-- POLICY: Simple view tasks policy ON tasks
-- ============================================
CREATE POLICY "Simple view tasks policy" ON public.tasks FOR SELECT USING ((deleted_at IS NULL));

-- ============================================
-- POLICY: allow_all_operations ON tasks
-- ============================================
CREATE POLICY allow_all_operations ON public.tasks FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON tasks
-- ============================================
CREATE POLICY allow_delete ON public.tasks FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON tasks
-- ============================================
CREATE POLICY allow_insert ON public.tasks FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON tasks
-- ============================================
CREATE POLICY allow_select ON public.tasks FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON tasks
-- ============================================
CREATE POLICY allow_update ON public.tasks FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON tasks
-- ============================================
CREATE POLICY anon_full_access ON public.tasks FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON tasks
-- ============================================
CREATE POLICY authenticated_full_access ON public.tasks FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert user_audit_logs ON user_audit_logs
-- ============================================
CREATE POLICY "Allow anon insert user_audit_logs" ON public.user_audit_logs FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON user_audit_logs
-- ============================================
CREATE POLICY allow_all_operations ON public.user_audit_logs FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON user_audit_logs
-- ============================================
CREATE POLICY allow_delete ON public.user_audit_logs FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON user_audit_logs
-- ============================================
CREATE POLICY allow_insert ON public.user_audit_logs FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON user_audit_logs
-- ============================================
CREATE POLICY allow_select ON public.user_audit_logs FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON user_audit_logs
-- ============================================
CREATE POLICY allow_update ON public.user_audit_logs FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON user_audit_logs
-- ============================================
CREATE POLICY anon_full_access ON public.user_audit_logs FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON user_audit_logs
-- ============================================
CREATE POLICY authenticated_full_access ON public.user_audit_logs FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Admins can view all device sessions ON user_device_sessions
-- ============================================
CREATE POLICY "Admins can view all device sessions" ON public.user_device_sessions FOR SELECT USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = uid()) AND (users.user_type = 'global'::user_type_enum)))));

-- ============================================
-- POLICY: Allow anon insert user_device_sessions ON user_device_sessions
-- ============================================
CREATE POLICY "Allow anon insert user_device_sessions" ON public.user_device_sessions FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Users can manage their own device sessions ON user_device_sessions
-- ============================================
CREATE POLICY "Users can manage their own device sessions" ON public.user_device_sessions FOR ALL USING ((user_id = uid()));

-- ============================================
-- POLICY: allow_all_operations ON user_device_sessions
-- ============================================
CREATE POLICY allow_all_operations ON public.user_device_sessions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON user_device_sessions
-- ============================================
CREATE POLICY allow_delete ON public.user_device_sessions FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON user_device_sessions
-- ============================================
CREATE POLICY allow_insert ON public.user_device_sessions FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON user_device_sessions
-- ============================================
CREATE POLICY allow_select ON public.user_device_sessions FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON user_device_sessions
-- ============================================
CREATE POLICY allow_update ON public.user_device_sessions FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON user_device_sessions
-- ============================================
CREATE POLICY anon_full_access ON public.user_device_sessions FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON user_device_sessions
-- ============================================
CREATE POLICY authenticated_full_access ON public.user_device_sessions FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: allow_all_operations ON user_erp_credentials
-- ============================================
CREATE POLICY allow_all_operations ON public.user_erp_credentials FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to user_favorite_buttons ON user_favorite_buttons
-- ============================================
CREATE POLICY "Allow all access to user_favorite_buttons" ON public.user_favorite_buttons FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to user_mobile_theme_assignments ON user_mobile_theme_assignments
-- ============================================
CREATE POLICY "Allow all access to user_mobile_theme_assignments" ON public.user_mobile_theme_assignments FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert user_password_history ON user_password_history
-- ============================================
CREATE POLICY "Allow anon insert user_password_history" ON public.user_password_history FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON user_password_history
-- ============================================
CREATE POLICY allow_all_operations ON public.user_password_history FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON user_password_history
-- ============================================
CREATE POLICY allow_delete ON public.user_password_history FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON user_password_history
-- ============================================
CREATE POLICY allow_insert ON public.user_password_history FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON user_password_history
-- ============================================
CREATE POLICY allow_select ON public.user_password_history FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON user_password_history
-- ============================================
CREATE POLICY allow_update ON public.user_password_history FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON user_password_history
-- ============================================
CREATE POLICY anon_full_access ON public.user_password_history FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON user_password_history
-- ============================================
CREATE POLICY authenticated_full_access ON public.user_password_history FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert user_sessions ON user_sessions
-- ============================================
CREATE POLICY "Allow anon insert user_sessions" ON public.user_sessions FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON user_sessions
-- ============================================
CREATE POLICY allow_all_operations ON public.user_sessions FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON user_sessions
-- ============================================
CREATE POLICY allow_delete ON public.user_sessions FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON user_sessions
-- ============================================
CREATE POLICY allow_insert ON public.user_sessions FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON user_sessions
-- ============================================
CREATE POLICY allow_select ON public.user_sessions FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON user_sessions
-- ============================================
CREATE POLICY allow_update ON public.user_sessions FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON user_sessions
-- ============================================
CREATE POLICY anon_full_access ON public.user_sessions FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON user_sessions
-- ============================================
CREATE POLICY authenticated_full_access ON public.user_sessions FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow all access to user_theme_assignments ON user_theme_assignments
-- ============================================
CREATE POLICY "Allow all access to user_theme_assignments" ON public.user_theme_assignments FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to user_voice_preferences ON user_voice_preferences
-- ============================================
CREATE POLICY "Allow all access to user_voice_preferences" ON public.user_voice_preferences FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all operations for authenticated users ON user_voice_preferences
-- ============================================
CREATE POLICY "Allow all operations for authenticated users" ON public.user_voice_preferences FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all users to view users table ON users
-- ============================================
CREATE POLICY "Allow all users to view users table" ON public.users FOR SELECT USING (true);

-- ============================================
-- POLICY: Allow anon insert users ON users
-- ============================================
CREATE POLICY "Allow anon insert users" ON public.users FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: Allow service role full access to users ON users
-- ============================================
CREATE POLICY "Allow service role full access to users" ON public.users FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON users
-- ============================================
CREATE POLICY allow_all_operations ON public.users FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON users
-- ============================================
CREATE POLICY allow_delete ON public.users FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON users
-- ============================================
CREATE POLICY allow_insert ON public.users FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON users
-- ============================================
CREATE POLICY allow_select ON public.users FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON users
-- ============================================
CREATE POLICY allow_update ON public.users FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON users
-- ============================================
CREATE POLICY anon_full_access ON public.users FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON users
-- ============================================
CREATE POLICY authenticated_full_access ON public.users FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: Allow anon insert variation_audit_log ON variation_audit_log
-- ============================================
CREATE POLICY "Allow anon insert variation_audit_log" ON public.variation_audit_log FOR INSERT TO anon WITH CHECK (true);

-- ============================================
-- POLICY: System can insert variation audit logs ON variation_audit_log
-- ============================================
CREATE POLICY "System can insert variation audit logs" ON public.variation_audit_log FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Users can view variation audit logs ON variation_audit_log
-- ============================================
CREATE POLICY "Users can view variation audit logs" ON public.variation_audit_log FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_all_operations ON variation_audit_log
-- ============================================
CREATE POLICY allow_all_operations ON public.variation_audit_log FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON variation_audit_log
-- ============================================
CREATE POLICY allow_delete ON public.variation_audit_log FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON variation_audit_log
-- ============================================
CREATE POLICY allow_insert ON public.variation_audit_log FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON variation_audit_log
-- ============================================
CREATE POLICY allow_select ON public.variation_audit_log FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON variation_audit_log
-- ============================================
CREATE POLICY allow_update ON public.variation_audit_log FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON variation_audit_log
-- ============================================
CREATE POLICY anon_full_access ON public.variation_audit_log FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON variation_audit_log
-- ============================================
CREATE POLICY authenticated_full_access ON public.variation_audit_log FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: vendor_payment_schedule_delete ON vendor_payment_schedule
-- ============================================
CREATE POLICY vendor_payment_schedule_delete ON public.vendor_payment_schedule FOR DELETE USING (true);

-- ============================================
-- POLICY: vendor_payment_schedule_insert ON vendor_payment_schedule
-- ============================================
CREATE POLICY vendor_payment_schedule_insert ON public.vendor_payment_schedule FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: vendor_payment_schedule_select ON vendor_payment_schedule
-- ============================================
CREATE POLICY vendor_payment_schedule_select ON public.vendor_payment_schedule FOR SELECT USING (true);

-- ============================================
-- POLICY: vendor_payment_schedule_update ON vendor_payment_schedule
-- ============================================
CREATE POLICY vendor_payment_schedule_update ON public.vendor_payment_schedule FOR UPDATE USING (true);

-- ============================================
-- POLICY: allow_delete ON vendors
-- ============================================
CREATE POLICY allow_delete ON public.vendors FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON vendors
-- ============================================
CREATE POLICY allow_insert ON public.vendors FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON vendors
-- ============================================
CREATE POLICY allow_select ON public.vendors FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON vendors
-- ============================================
CREATE POLICY allow_update ON public.vendors FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: rls_delete ON vendors
-- ============================================
CREATE POLICY rls_delete ON public.vendors FOR DELETE USING (true);

-- ============================================
-- POLICY: rls_insert ON vendors
-- ============================================
CREATE POLICY rls_insert ON public.vendors FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: rls_select ON vendors
-- ============================================
CREATE POLICY rls_select ON public.vendors FOR SELECT USING (true);

-- ============================================
-- POLICY: rls_update ON vendors
-- ============================================
CREATE POLICY rls_update ON public.vendors FOR UPDATE WITH CHECK (true);

-- ============================================
-- POLICY: Allow anon insert view_offer ON view_offer
-- ============================================
CREATE POLICY "Allow anon insert view_offer" ON public.view_offer FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to create view_offer ON view_offer
-- ============================================
CREATE POLICY "Allow authenticated users to create view_offer" ON public.view_offer FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated users to read view_offer ON view_offer
-- ============================================
CREATE POLICY "Allow authenticated users to read view_offer" ON public.view_offer FOR SELECT USING (true);

-- ============================================
-- POLICY: Allow authenticated users to update view_offer ON view_offer
-- ============================================
CREATE POLICY "Allow authenticated users to update view_offer" ON public.view_offer FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Enable all access for view_offer ON view_offer
-- ============================================
CREATE POLICY "Enable all access for view_offer" ON public.view_offer FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Service role has full access to view_offer ON view_offer
-- ============================================
CREATE POLICY "Service role has full access to view_offer" ON public.view_offer FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_operations ON view_offer
-- ============================================
CREATE POLICY allow_all_operations ON public.view_offer FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_delete ON view_offer
-- ============================================
CREATE POLICY allow_delete ON public.view_offer FOR DELETE USING (true);

-- ============================================
-- POLICY: allow_insert ON view_offer
-- ============================================
CREATE POLICY allow_insert ON public.view_offer FOR INSERT WITH CHECK (true);

-- ============================================
-- POLICY: allow_select ON view_offer
-- ============================================
CREATE POLICY allow_select ON public.view_offer FOR SELECT USING (true);

-- ============================================
-- POLICY: allow_update ON view_offer
-- ============================================
CREATE POLICY allow_update ON public.view_offer FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: anon_full_access ON view_offer
-- ============================================
CREATE POLICY anon_full_access ON public.view_offer FOR ALL USING (((jwt() ->> 'role'::text) = 'anon'::text));

-- ============================================
-- POLICY: authenticated_full_access ON view_offer
-- ============================================
CREATE POLICY authenticated_full_access ON public.view_offer FOR ALL USING ((uid() IS NOT NULL));

-- ============================================
-- POLICY: vip_campaign_settings_delete ON vip_campaign_settings
-- ============================================
CREATE POLICY vip_campaign_settings_delete ON public.vip_campaign_settings FOR DELETE TO authenticated, anon USING (true);

-- ============================================
-- POLICY: vip_campaign_settings_insert ON vip_campaign_settings
-- ============================================
CREATE POLICY vip_campaign_settings_insert ON public.vip_campaign_settings FOR INSERT TO authenticated, anon WITH CHECK (true);

-- ============================================
-- POLICY: vip_campaign_settings_select ON vip_campaign_settings
-- ============================================
CREATE POLICY vip_campaign_settings_select ON public.vip_campaign_settings FOR SELECT TO authenticated, anon USING (true);

-- ============================================
-- POLICY: vip_campaign_settings_update ON vip_campaign_settings
-- ============================================
CREATE POLICY vip_campaign_settings_update ON public.vip_campaign_settings FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: vip_redemptions_delete ON vip_redemptions
-- ============================================
CREATE POLICY vip_redemptions_delete ON public.vip_redemptions FOR DELETE TO authenticated, anon USING (true);

-- ============================================
-- POLICY: vip_redemptions_insert ON vip_redemptions
-- ============================================
CREATE POLICY vip_redemptions_insert ON public.vip_redemptions FOR INSERT TO authenticated, anon WITH CHECK (true);

-- ============================================
-- POLICY: vip_redemptions_select ON vip_redemptions
-- ============================================
CREATE POLICY vip_redemptions_select ON public.vip_redemptions FOR SELECT TO authenticated, anon USING (true);

-- ============================================
-- POLICY: vip_redemptions_update ON vip_redemptions
-- ============================================
CREATE POLICY vip_redemptions_update ON public.vip_redemptions FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to wa_accounts ON wa_accounts
-- ============================================
CREATE POLICY "Allow all access to wa_accounts" ON public.wa_accounts FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Service role full access on wa_ai_bot_config ON wa_ai_bot_config
-- ============================================
CREATE POLICY "Service role full access on wa_ai_bot_config" ON public.wa_ai_bot_config FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Service role full access on wa_auto_reply_triggers ON wa_auto_reply_triggers
-- ============================================
CREATE POLICY "Service role full access on wa_auto_reply_triggers" ON public.wa_auto_reply_triggers FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_wa_auto_reply ON wa_auto_reply_triggers
-- ============================================
CREATE POLICY allow_all_wa_auto_reply ON public.wa_auto_reply_triggers FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_wa_bot_flows ON wa_bot_flows
-- ============================================
CREATE POLICY allow_all_wa_bot_flows ON public.wa_bot_flows FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to wa_broadcast_recipients ON wa_broadcast_recipients
-- ============================================
CREATE POLICY "Allow all access to wa_broadcast_recipients" ON public.wa_broadcast_recipients FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to wa_broadcasts ON wa_broadcasts
-- ============================================
CREATE POLICY "Allow all access to wa_broadcasts" ON public.wa_broadcasts FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated full access on wa_catalog_orders ON wa_catalog_orders
-- ============================================
CREATE POLICY "Allow authenticated full access on wa_catalog_orders" ON public.wa_catalog_orders FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated full access on wa_catalog_products ON wa_catalog_products
-- ============================================
CREATE POLICY "Allow authenticated full access on wa_catalog_products" ON public.wa_catalog_products FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow authenticated full access on wa_catalogs ON wa_catalogs
-- ============================================
CREATE POLICY "Allow authenticated full access on wa_catalogs" ON public.wa_catalogs FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Service role full access on wa_contact_group_members ON wa_contact_group_members
-- ============================================
CREATE POLICY "Service role full access on wa_contact_group_members" ON public.wa_contact_group_members FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Service role full access on wa_contact_groups ON wa_contact_groups
-- ============================================
CREATE POLICY "Service role full access on wa_contact_groups" ON public.wa_contact_groups FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to wa_conversations ON wa_conversations
-- ============================================
CREATE POLICY "Allow all access to wa_conversations" ON public.wa_conversations FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Service role full access on wa_messages ON wa_messages
-- ============================================
CREATE POLICY "Service role full access on wa_messages" ON public.wa_messages FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: realtime_wa_messages_select ON wa_messages
-- ============================================
CREATE POLICY realtime_wa_messages_select ON public.wa_messages FOR SELECT TO authenticated, anon USING (true);

-- ============================================
-- POLICY: Service role full access on wa_settings ON wa_settings
-- ============================================
CREATE POLICY "Service role full access on wa_settings" ON public.wa_settings FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: allow_all_wa_settings ON wa_settings
-- ============================================
CREATE POLICY allow_all_wa_settings ON public.wa_settings FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to wa_templates ON wa_templates
-- ============================================
CREATE POLICY "Allow all access to wa_templates" ON public.wa_templates FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to warning_main_category ON warning_main_category
-- ============================================
CREATE POLICY "Allow all access to warning_main_category" ON public.warning_main_category FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to warning_sub_category ON warning_sub_category
-- ============================================
CREATE POLICY "Allow all access to warning_sub_category" ON public.warning_sub_category FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Allow all access to warning_violation ON warning_violation
-- ============================================
CREATE POLICY "Allow all access to warning_violation" ON public.warning_violation FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- POLICY: Service role full access on whatsapp_message_log ON whatsapp_message_log
-- ============================================
CREATE POLICY "Service role full access on whatsapp_message_log" ON public.whatsapp_message_log FOR ALL USING (true) WITH CHECK (true);

