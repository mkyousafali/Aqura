-- INDEX: access_code_otp_pkey ON access_code_otp
CREATE UNIQUE INDEX access_code_otp_pkey ON public.access_code_otp USING btree (id);

-- INDEX: idx_access_code_otp_expires ON access_code_otp
CREATE INDEX idx_access_code_otp_expires ON public.access_code_otp USING btree (expires_at);

-- INDEX: idx_access_code_otp_user ON access_code_otp
CREATE INDEX idx_access_code_otp_user ON public.access_code_otp USING btree (user_id);

-- INDEX: ai_chat_guide_pkey ON ai_chat_guide
CREATE UNIQUE INDEX ai_chat_guide_pkey ON public.ai_chat_guide USING btree (id);

-- INDEX: app_icons_icon_key_key ON app_icons
CREATE UNIQUE INDEX app_icons_icon_key_key ON public.app_icons USING btree (icon_key);

-- INDEX: app_icons_pkey ON app_icons
CREATE UNIQUE INDEX app_icons_pkey ON public.app_icons USING btree (id);

-- INDEX: idx_app_icons_category ON app_icons
CREATE INDEX idx_app_icons_category ON public.app_icons USING btree (category);

-- INDEX: idx_app_icons_key ON app_icons
CREATE INDEX idx_app_icons_key ON public.app_icons USING btree (icon_key);

-- INDEX: approval_permissions_pkey ON approval_permissions
CREATE UNIQUE INDEX approval_permissions_pkey ON public.approval_permissions USING btree (id);

-- INDEX: approval_permissions_user_id_key ON approval_permissions
CREATE UNIQUE INDEX approval_permissions_user_id_key ON public.approval_permissions USING btree (user_id);

-- INDEX: idx_approval_permissions_add_missing_punches ON approval_permissions
CREATE INDEX idx_approval_permissions_add_missing_punches ON public.approval_permissions USING btree (can_add_missing_punches) WHERE ((can_add_missing_punches = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_customer_incidents ON approval_permissions
CREATE INDEX idx_approval_permissions_customer_incidents ON public.approval_permissions USING btree (can_receive_customer_incidents) WHERE ((can_receive_customer_incidents = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_employee_incidents ON approval_permissions
CREATE INDEX idx_approval_permissions_employee_incidents ON public.approval_permissions USING btree (can_receive_employee_incidents) WHERE ((can_receive_employee_incidents = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_finance_incidents ON approval_permissions
CREATE INDEX idx_approval_permissions_finance_incidents ON public.approval_permissions USING btree (can_receive_finance_incidents) WHERE ((can_receive_finance_incidents = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_government_incidents ON approval_permissions
CREATE INDEX idx_approval_permissions_government_incidents ON public.approval_permissions USING btree (can_receive_government_incidents) WHERE ((can_receive_government_incidents = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_is_active ON approval_permissions
CREATE INDEX idx_approval_permissions_is_active ON public.approval_permissions USING btree (is_active) WHERE (is_active = true);

-- INDEX: idx_approval_permissions_leave_requests ON approval_permissions
CREATE INDEX idx_approval_permissions_leave_requests ON public.approval_permissions USING btree (can_approve_leave_requests) WHERE ((can_approve_leave_requests = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_maintenance_incidents ON approval_permissions
CREATE INDEX idx_approval_permissions_maintenance_incidents ON public.approval_permissions USING btree (can_receive_maintenance_incidents) WHERE ((can_receive_maintenance_incidents = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_multiple_bill ON approval_permissions
CREATE INDEX idx_approval_permissions_multiple_bill ON public.approval_permissions USING btree (can_approve_multiple_bill) WHERE ((can_approve_multiple_bill = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_other_incidents ON approval_permissions
CREATE INDEX idx_approval_permissions_other_incidents ON public.approval_permissions USING btree (can_receive_other_incidents) WHERE ((can_receive_other_incidents = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_pos_incidents ON approval_permissions
CREATE INDEX idx_approval_permissions_pos_incidents ON public.approval_permissions USING btree (can_receive_pos_incidents) WHERE ((can_receive_pos_incidents = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_purchase_vouchers ON approval_permissions
CREATE INDEX idx_approval_permissions_purchase_vouchers ON public.approval_permissions USING btree (can_approve_purchase_vouchers) WHERE ((can_approve_purchase_vouchers = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_recurring_bill ON approval_permissions
CREATE INDEX idx_approval_permissions_recurring_bill ON public.approval_permissions USING btree (can_approve_recurring_bill) WHERE ((can_approve_recurring_bill = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_requisitions ON approval_permissions
CREATE INDEX idx_approval_permissions_requisitions ON public.approval_permissions USING btree (can_approve_requisitions) WHERE ((can_approve_requisitions = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_single_bill ON approval_permissions
CREATE INDEX idx_approval_permissions_single_bill ON public.approval_permissions USING btree (can_approve_single_bill) WHERE ((can_approve_single_bill = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_user_id ON approval_permissions
CREATE INDEX idx_approval_permissions_user_id ON public.approval_permissions USING btree (user_id);

-- INDEX: idx_approval_permissions_vehicle_incidents ON approval_permissions
CREATE INDEX idx_approval_permissions_vehicle_incidents ON public.approval_permissions USING btree (can_receive_vehicle_incidents) WHERE ((can_receive_vehicle_incidents = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_vendor_incidents ON approval_permissions
CREATE INDEX idx_approval_permissions_vendor_incidents ON public.approval_permissions USING btree (can_receive_vendor_incidents) WHERE ((can_receive_vendor_incidents = true) AND (is_active = true));

-- INDEX: idx_approval_permissions_vendor_payments ON approval_permissions
CREATE INDEX idx_approval_permissions_vendor_payments ON public.approval_permissions USING btree (can_approve_vendor_payments) WHERE ((can_approve_vendor_payments = true) AND (is_active = true));

-- INDEX: approver_branch_access_pkey ON approver_branch_access
CREATE UNIQUE INDEX approver_branch_access_pkey ON public.approver_branch_access USING btree (id);

-- INDEX: approver_branch_access_user_id_branch_id_key ON approver_branch_access
CREATE UNIQUE INDEX approver_branch_access_user_id_branch_id_key ON public.approver_branch_access USING btree (user_id, branch_id);

-- INDEX: idx_approver_branch_access_active ON approver_branch_access
CREATE INDEX idx_approver_branch_access_active ON public.approver_branch_access USING btree (is_active) WHERE (is_active = true);

-- INDEX: idx_approver_branch_access_branch_id ON approver_branch_access
CREATE INDEX idx_approver_branch_access_branch_id ON public.approver_branch_access USING btree (branch_id);

-- INDEX: idx_approver_branch_access_user_branch ON approver_branch_access
CREATE INDEX idx_approver_branch_access_user_branch ON public.approver_branch_access USING btree (user_id, branch_id);

-- INDEX: idx_approver_branch_access_user_id ON approver_branch_access
CREATE INDEX idx_approver_branch_access_user_id ON public.approver_branch_access USING btree (user_id);

-- INDEX: approver_visibility_config_pkey ON approver_visibility_config
CREATE UNIQUE INDEX approver_visibility_config_pkey ON public.approver_visibility_config USING btree (id);

-- INDEX: approver_visibility_config_user_id_key ON approver_visibility_config
CREATE UNIQUE INDEX approver_visibility_config_user_id_key ON public.approver_visibility_config USING btree (user_id);

-- INDEX: idx_approver_visibility_active ON approver_visibility_config
CREATE INDEX idx_approver_visibility_active ON public.approver_visibility_config USING btree (is_active) WHERE (is_active = true);

-- INDEX: idx_approver_visibility_type ON approver_visibility_config
CREATE INDEX idx_approver_visibility_type ON public.approver_visibility_config USING btree (visibility_type);

-- INDEX: idx_approver_visibility_user_id ON approver_visibility_config
CREATE INDEX idx_approver_visibility_user_id ON public.approver_visibility_config USING btree (user_id);

-- INDEX: asset_main_categories_group_code_key ON asset_main_categories
CREATE UNIQUE INDEX asset_main_categories_group_code_key ON public.asset_main_categories USING btree (group_code);

-- INDEX: asset_main_categories_name_en_key ON asset_main_categories
CREATE UNIQUE INDEX asset_main_categories_name_en_key ON public.asset_main_categories USING btree (name_en);

-- INDEX: asset_main_categories_pkey ON asset_main_categories
CREATE UNIQUE INDEX asset_main_categories_pkey ON public.asset_main_categories USING btree (id);

-- INDEX: idx_asset_main_categories_group_code ON asset_main_categories
CREATE INDEX idx_asset_main_categories_group_code ON public.asset_main_categories USING btree (group_code);

-- INDEX: idx_asset_main_categories_name_en ON asset_main_categories
CREATE INDEX idx_asset_main_categories_name_en ON public.asset_main_categories USING btree (name_en);

-- INDEX: asset_items_group_code_name_en_key ON asset_sub_categories
CREATE UNIQUE INDEX asset_items_group_code_name_en_key ON public.asset_sub_categories USING btree (group_code, name_en);

-- INDEX: asset_items_pkey ON asset_sub_categories
CREATE UNIQUE INDEX asset_items_pkey ON public.asset_sub_categories USING btree (id);

-- INDEX: idx_asset_sub_categories_category_id ON asset_sub_categories
CREATE INDEX idx_asset_sub_categories_category_id ON public.asset_sub_categories USING btree (category_id);

-- INDEX: idx_asset_sub_categories_group_code ON asset_sub_categories
CREATE INDEX idx_asset_sub_categories_group_code ON public.asset_sub_categories USING btree (group_code);

-- INDEX: assets_asset_id_key ON assets
CREATE UNIQUE INDEX assets_asset_id_key ON public.assets USING btree (asset_id);

-- INDEX: assets_pkey ON assets
CREATE UNIQUE INDEX assets_pkey ON public.assets USING btree (id);

-- INDEX: idx_assets_asset_id ON assets
CREATE INDEX idx_assets_asset_id ON public.assets USING btree (asset_id);

-- INDEX: idx_assets_branch_id ON assets
CREATE INDEX idx_assets_branch_id ON public.assets USING btree (branch_id);

-- INDEX: idx_assets_sub_category_id ON assets
CREATE INDEX idx_assets_sub_category_id ON public.assets USING btree (sub_category_id);

-- INDEX: background_templates_pkey ON background_templates
CREATE UNIQUE INDEX background_templates_pkey ON public.background_templates USING btree (id);

-- INDEX: bank_reconciliations_pkey ON bank_reconciliations
CREATE UNIQUE INDEX bank_reconciliations_pkey ON public.bank_reconciliations USING btree (id);

-- INDEX: idx_bank_reconciliations_branch_id ON bank_reconciliations
CREATE INDEX idx_bank_reconciliations_branch_id ON public.bank_reconciliations USING btree (branch_id);

-- INDEX: idx_bank_reconciliations_created_at ON bank_reconciliations
CREATE INDEX idx_bank_reconciliations_created_at ON public.bank_reconciliations USING btree (created_at);

-- INDEX: idx_bank_reconciliations_operation_id ON bank_reconciliations
CREATE INDEX idx_bank_reconciliations_operation_id ON public.bank_reconciliations USING btree (operation_id);

-- INDEX: biometric_connections_pkey ON biometric_connections
CREATE UNIQUE INDEX biometric_connections_pkey ON public.biometric_connections USING btree (id);

-- INDEX: idx_biometric_connections_active ON biometric_connections
CREATE INDEX idx_biometric_connections_active ON public.biometric_connections USING btree (is_active);

-- INDEX: idx_biometric_connections_branch ON biometric_connections
CREATE INDEX idx_biometric_connections_branch ON public.biometric_connections USING btree (branch_id);

-- INDEX: idx_biometric_connections_device ON biometric_connections
CREATE INDEX idx_biometric_connections_device ON public.biometric_connections USING btree (device_id);

-- INDEX: idx_biometric_connections_terminal ON biometric_connections
CREATE INDEX idx_biometric_connections_terminal ON public.biometric_connections USING btree (terminal_sn);

-- INDEX: unique_branch_device ON biometric_connections
CREATE UNIQUE INDEX unique_branch_device ON public.biometric_connections USING btree (branch_id, device_id);

-- INDEX: bogo_offer_rules_pkey ON bogo_offer_rules
CREATE UNIQUE INDEX bogo_offer_rules_pkey ON public.bogo_offer_rules USING btree (id);

-- INDEX: idx_bogo_offer_rules_buy_product ON bogo_offer_rules
CREATE INDEX idx_bogo_offer_rules_buy_product ON public.bogo_offer_rules USING btree (buy_product_id);

-- INDEX: idx_bogo_offer_rules_buy_product_id ON bogo_offer_rules
CREATE INDEX idx_bogo_offer_rules_buy_product_id ON public.bogo_offer_rules USING btree (buy_product_id);

-- INDEX: idx_bogo_offer_rules_get_product ON bogo_offer_rules
CREATE INDEX idx_bogo_offer_rules_get_product ON public.bogo_offer_rules USING btree (get_product_id);

-- INDEX: idx_bogo_offer_rules_get_product_id ON bogo_offer_rules
CREATE INDEX idx_bogo_offer_rules_get_product_id ON public.bogo_offer_rules USING btree (get_product_id);

-- INDEX: idx_bogo_offer_rules_offer_id ON bogo_offer_rules
CREATE INDEX idx_bogo_offer_rules_offer_id ON public.bogo_offer_rules USING btree (offer_id);

-- INDEX: box_edit_requests_pkey ON box_edit_requests
CREATE UNIQUE INDEX box_edit_requests_pkey ON public.box_edit_requests USING btree (id);

-- INDEX: idx_box_edit_requests_approver ON box_edit_requests
CREATE INDEX idx_box_edit_requests_approver ON public.box_edit_requests USING btree (assigned_approver_id, status);

-- INDEX: idx_box_edit_requests_box ON box_edit_requests
CREATE INDEX idx_box_edit_requests_box ON public.box_edit_requests USING btree (box_operation_id);

-- INDEX: idx_box_edit_requests_requester ON box_edit_requests
CREATE INDEX idx_box_edit_requests_requester ON public.box_edit_requests USING btree (requested_by, status);

-- INDEX: box_operations_pkey ON box_operations
CREATE UNIQUE INDEX box_operations_pkey ON public.box_operations USING btree (id);

-- INDEX: idx_box_operations_active ON box_operations
CREATE INDEX idx_box_operations_active ON public.box_operations USING btree (branch_id, status) WHERE ((status)::text = 'in_use'::text);

-- INDEX: idx_box_operations_box ON box_operations
CREATE INDEX idx_box_operations_box ON public.box_operations USING btree (box_number);

-- INDEX: idx_box_operations_branch ON box_operations
CREATE INDEX idx_box_operations_branch ON public.box_operations USING btree (branch_id);

-- INDEX: idx_box_operations_denomination ON box_operations
CREATE INDEX idx_box_operations_denomination ON public.box_operations USING btree (denomination_record_id);

-- INDEX: idx_box_operations_pos_before_url ON box_operations
CREATE INDEX idx_box_operations_pos_before_url ON public.box_operations USING btree (pos_before_url);

-- INDEX: idx_box_operations_start_time ON box_operations
CREATE INDEX idx_box_operations_start_time ON public.box_operations USING btree (start_time DESC);

-- INDEX: idx_box_operations_status ON box_operations
CREATE INDEX idx_box_operations_status ON public.box_operations USING btree (status);

-- INDEX: idx_box_operations_user ON box_operations
CREATE INDEX idx_box_operations_user ON public.box_operations USING btree (user_id);

-- INDEX: branch_default_delivery_receivers_branch_id_user_id_key ON branch_default_delivery_receivers
CREATE UNIQUE INDEX branch_default_delivery_receivers_branch_id_user_id_key ON public.branch_default_delivery_receivers USING btree (branch_id, user_id);

-- INDEX: branch_default_delivery_receivers_pkey ON branch_default_delivery_receivers
CREATE UNIQUE INDEX branch_default_delivery_receivers_pkey ON public.branch_default_delivery_receivers USING btree (id);

-- INDEX: idx_branch_delivery_receivers_branch ON branch_default_delivery_receivers
CREATE INDEX idx_branch_delivery_receivers_branch ON public.branch_default_delivery_receivers USING btree (branch_id) WHERE (is_active = true);

-- INDEX: idx_branch_delivery_receivers_user ON branch_default_delivery_receivers
CREATE INDEX idx_branch_delivery_receivers_user ON public.branch_default_delivery_receivers USING btree (user_id) WHERE (is_active = true);

-- INDEX: branch_default_positions_branch_id_key ON branch_default_positions
CREATE UNIQUE INDEX branch_default_positions_branch_id_key ON public.branch_default_positions USING btree (branch_id);

-- INDEX: branch_default_positions_pkey ON branch_default_positions
CREATE UNIQUE INDEX branch_default_positions_pkey ON public.branch_default_positions USING btree (id);

-- INDEX: idx_branch_default_positions_branch_id ON branch_default_positions
CREATE INDEX idx_branch_default_positions_branch_id ON public.branch_default_positions USING btree (branch_id);

-- INDEX: branch_sync_config_branch_id_key ON branch_sync_config
CREATE UNIQUE INDEX branch_sync_config_branch_id_key ON public.branch_sync_config USING btree (branch_id);

-- INDEX: branch_sync_config_pkey ON branch_sync_config
CREATE UNIQUE INDEX branch_sync_config_pkey ON public.branch_sync_config USING btree (id);

-- INDEX: branches_pkey ON branches
CREATE UNIQUE INDEX branches_pkey ON public.branches USING btree (id);

-- INDEX: idx_branches_active ON branches
CREATE INDEX idx_branches_active ON public.branches USING btree (is_active);

-- INDEX: idx_branches_main ON branches
CREATE INDEX idx_branches_main ON public.branches USING btree (is_main_branch);

-- INDEX: idx_branches_name_ar ON branches
CREATE INDEX idx_branches_name_ar ON public.branches USING btree (name_ar);

-- INDEX: idx_branches_name_en ON branches
CREATE INDEX idx_branches_name_en ON public.branches USING btree (name_en);

-- INDEX: idx_branches_vat_number ON branches
CREATE INDEX idx_branches_vat_number ON public.branches USING btree (vat_number) WHERE (vat_number IS NOT NULL);

-- INDEX: break_reasons_name_en_unique ON break_reasons
CREATE UNIQUE INDEX break_reasons_name_en_unique ON public.break_reasons USING btree (name_en);

-- INDEX: break_reasons_pkey ON break_reasons
CREATE UNIQUE INDEX break_reasons_pkey ON public.break_reasons USING btree (id);

-- INDEX: break_register_pkey ON break_register
CREATE UNIQUE INDEX break_register_pkey ON public.break_register USING btree (id);

-- INDEX: idx_break_register_employee ON break_register
CREATE INDEX idx_break_register_employee ON public.break_register USING btree (employee_id);

-- INDEX: idx_break_register_start ON break_register
CREATE INDEX idx_break_register_start ON public.break_register USING btree (start_time DESC);

-- INDEX: idx_break_register_user_status ON break_register
CREATE INDEX idx_break_register_user_status ON public.break_register USING btree (user_id, status);

-- INDEX: break_register_permissions_pkey ON break_register_permissions
CREATE UNIQUE INDEX break_register_permissions_pkey ON public.break_register_permissions USING btree (id);

-- INDEX: break_register_permissions_user_id_key ON break_register_permissions
CREATE UNIQUE INDEX break_register_permissions_user_id_key ON public.break_register_permissions USING btree (user_id);

-- INDEX: break_security_seed_pkey ON break_security_seed
CREATE UNIQUE INDEX break_security_seed_pkey ON public.break_security_seed USING btree (id);

-- INDEX: button_main_sections_pkey ON button_main_sections
CREATE UNIQUE INDEX button_main_sections_pkey ON public.button_main_sections USING btree (id);

-- INDEX: button_main_sections_section_code_key ON button_main_sections
CREATE UNIQUE INDEX button_main_sections_section_code_key ON public.button_main_sections USING btree (section_code);

-- INDEX: idx_button_main_sections_active ON button_main_sections
CREATE INDEX idx_button_main_sections_active ON public.button_main_sections USING btree (is_active);

-- INDEX: button_permissions_pkey ON button_permissions
CREATE UNIQUE INDEX button_permissions_pkey ON public.button_permissions USING btree (id);

-- INDEX: button_permissions_user_id_button_id_key ON button_permissions
CREATE UNIQUE INDEX button_permissions_user_id_button_id_key ON public.button_permissions USING btree (user_id, button_id);

-- INDEX: idx_button_permissions_button ON button_permissions
CREATE INDEX idx_button_permissions_button ON public.button_permissions USING btree (button_id);

-- INDEX: idx_button_permissions_user ON button_permissions
CREATE INDEX idx_button_permissions_user ON public.button_permissions USING btree (user_id);

-- INDEX: button_sub_sections_main_section_id_subsection_code_key ON button_sub_sections
CREATE UNIQUE INDEX button_sub_sections_main_section_id_subsection_code_key ON public.button_sub_sections USING btree (main_section_id, subsection_code);

-- INDEX: button_sub_sections_pkey ON button_sub_sections
CREATE UNIQUE INDEX button_sub_sections_pkey ON public.button_sub_sections USING btree (id);

-- INDEX: idx_button_sub_sections_active ON button_sub_sections
CREATE INDEX idx_button_sub_sections_active ON public.button_sub_sections USING btree (is_active);

-- INDEX: idx_button_sub_sections_main ON button_sub_sections
CREATE INDEX idx_button_sub_sections_main ON public.button_sub_sections USING btree (main_section_id);

-- INDEX: cashier_device_bindings_pkey ON cashier_device_bindings
CREATE UNIQUE INDEX cashier_device_bindings_pkey ON public.cashier_device_bindings USING btree (user_id);

-- INDEX: idx_cashier_device_bindings_device ON cashier_device_bindings
CREATE INDEX idx_cashier_device_bindings_device ON public.cashier_device_bindings USING btree (device_id);

-- INDEX: coupon_campaigns_campaign_code_key ON coupon_campaigns
CREATE UNIQUE INDEX coupon_campaigns_campaign_code_key ON public.coupon_campaigns USING btree (campaign_code);

-- INDEX: coupon_campaigns_pkey ON coupon_campaigns
CREATE UNIQUE INDEX coupon_campaigns_pkey ON public.coupon_campaigns USING btree (id);

-- INDEX: idx_campaigns_active ON coupon_campaigns
CREATE INDEX idx_campaigns_active ON public.coupon_campaigns USING btree (is_active) WHERE (deleted_at IS NULL);

-- INDEX: idx_campaigns_code ON coupon_campaigns
CREATE INDEX idx_campaigns_code ON public.coupon_campaigns USING btree (campaign_code);

-- INDEX: idx_campaigns_validity ON coupon_campaigns
CREATE INDEX idx_campaigns_validity ON public.coupon_campaigns USING btree (validity_start_date, validity_end_date);

-- INDEX: coupon_claims_pkey ON coupon_claims
CREATE UNIQUE INDEX coupon_claims_pkey ON public.coupon_claims USING btree (id);

-- INDEX: idx_coupon_claims_branch ON coupon_claims
CREATE INDEX idx_coupon_claims_branch ON public.coupon_claims USING btree (branch_id);

-- INDEX: idx_coupon_claims_campaign ON coupon_claims
CREATE INDEX idx_coupon_claims_campaign ON public.coupon_claims USING btree (campaign_id);

-- INDEX: idx_coupon_claims_customer_campaign ON coupon_claims
CREATE INDEX idx_coupon_claims_customer_campaign ON public.coupon_claims USING btree (campaign_id, customer_mobile);

-- INDEX: idx_coupon_claims_date ON coupon_claims
CREATE INDEX idx_coupon_claims_date ON public.coupon_claims USING btree (claimed_at);

-- INDEX: idx_coupon_claims_mobile ON coupon_claims
CREATE INDEX idx_coupon_claims_mobile ON public.coupon_claims USING btree (customer_mobile);

-- INDEX: idx_coupon_claims_product ON coupon_claims
CREATE INDEX idx_coupon_claims_product ON public.coupon_claims USING btree (product_id);

-- INDEX: coupon_eligible_customers_pkey ON coupon_eligible_customers
CREATE UNIQUE INDEX coupon_eligible_customers_pkey ON public.coupon_eligible_customers USING btree (id);

-- INDEX: idx_eligible_customers_campaign ON coupon_eligible_customers
CREATE INDEX idx_eligible_customers_campaign ON public.coupon_eligible_customers USING btree (campaign_id);

-- INDEX: idx_eligible_customers_mobile ON coupon_eligible_customers
CREATE INDEX idx_eligible_customers_mobile ON public.coupon_eligible_customers USING btree (mobile_number);

-- INDEX: unique_customer_campaign ON coupon_eligible_customers
CREATE UNIQUE INDEX unique_customer_campaign ON public.coupon_eligible_customers USING btree (campaign_id, mobile_number);

-- INDEX: coupon_products_campaign_barcode_unique ON coupon_products
CREATE UNIQUE INDEX coupon_products_campaign_barcode_unique ON public.coupon_products USING btree (campaign_id, special_barcode);

-- INDEX: coupon_products_pkey ON coupon_products
CREATE UNIQUE INDEX coupon_products_pkey ON public.coupon_products USING btree (id);

-- INDEX: idx_coupon_products_barcode ON coupon_products
CREATE INDEX idx_coupon_products_barcode ON public.coupon_products USING btree (special_barcode);

-- INDEX: idx_coupon_products_campaign ON coupon_products
CREATE INDEX idx_coupon_products_campaign ON public.coupon_products USING btree (campaign_id);

-- INDEX: idx_coupon_products_stock ON coupon_products
CREATE INDEX idx_coupon_products_stock ON public.coupon_products USING btree (stock_remaining) WHERE (is_active = true);

-- INDEX: customer_access_code_history_pkey ON customer_access_code_history
CREATE UNIQUE INDEX customer_access_code_history_pkey ON public.customer_access_code_history USING btree (id);

-- INDEX: idx_customer_access_code_history_created_at ON customer_access_code_history
CREATE INDEX idx_customer_access_code_history_created_at ON public.customer_access_code_history USING btree (created_at);

-- INDEX: idx_customer_access_code_history_customer_id ON customer_access_code_history
CREATE INDEX idx_customer_access_code_history_customer_id ON public.customer_access_code_history USING btree (customer_id);

-- INDEX: idx_customer_access_code_history_generated_by ON customer_access_code_history
CREATE INDEX idx_customer_access_code_history_generated_by ON public.customer_access_code_history USING btree (generated_by);

-- INDEX: customer_app_media_pkey ON customer_app_media
CREATE UNIQUE INDEX customer_app_media_pkey ON public.customer_app_media USING btree (id);

-- INDEX: idx_customer_app_media_active ON customer_app_media
CREATE INDEX idx_customer_app_media_active ON public.customer_app_media USING btree (is_active) WHERE (is_active = true);

-- INDEX: idx_customer_app_media_display_order ON customer_app_media
CREATE INDEX idx_customer_app_media_display_order ON public.customer_app_media USING btree (display_order);

-- INDEX: idx_customer_app_media_expiry ON customer_app_media
CREATE INDEX idx_customer_app_media_expiry ON public.customer_app_media USING btree (expiry_date) WHERE (expiry_date IS NOT NULL);

-- INDEX: idx_customer_app_media_type ON customer_app_media
CREATE INDEX idx_customer_app_media_type ON public.customer_app_media USING btree (media_type);

-- INDEX: unique_slot_per_type ON customer_app_media
CREATE UNIQUE INDEX unique_slot_per_type ON public.customer_app_media USING btree (media_type, slot_number);

-- INDEX: customer_product_requests_pkey ON customer_product_requests
CREATE UNIQUE INDEX customer_product_requests_pkey ON public.customer_product_requests USING btree (id);

-- INDEX: idx_customer_product_requests_branch ON customer_product_requests
CREATE INDEX idx_customer_product_requests_branch ON public.customer_product_requests USING btree (branch_id);

-- INDEX: idx_customer_product_requests_requester ON customer_product_requests
CREATE INDEX idx_customer_product_requests_requester ON public.customer_product_requests USING btree (requester_user_id);

-- INDEX: idx_customer_product_requests_status ON customer_product_requests
CREATE INDEX idx_customer_product_requests_status ON public.customer_product_requests USING btree (status);

-- INDEX: idx_customer_product_requests_target ON customer_product_requests
CREATE INDEX idx_customer_product_requests_target ON public.customer_product_requests USING btree (target_user_id);

-- INDEX: customer_recovery_requests_pkey ON customer_recovery_requests
CREATE UNIQUE INDEX customer_recovery_requests_pkey ON public.customer_recovery_requests USING btree (id);

-- INDEX: idx_customer_recovery_requests_created_at ON customer_recovery_requests
CREATE INDEX idx_customer_recovery_requests_created_at ON public.customer_recovery_requests USING btree (created_at);

-- INDEX: idx_customer_recovery_requests_customer_id ON customer_recovery_requests
CREATE INDEX idx_customer_recovery_requests_customer_id ON public.customer_recovery_requests USING btree (customer_id);

-- INDEX: idx_customer_recovery_requests_processed_by ON customer_recovery_requests
CREATE INDEX idx_customer_recovery_requests_processed_by ON public.customer_recovery_requests USING btree (processed_by);

-- INDEX: idx_customer_recovery_requests_request_type ON customer_recovery_requests
CREATE INDEX idx_customer_recovery_requests_request_type ON public.customer_recovery_requests USING btree (request_type);

-- INDEX: idx_customer_recovery_requests_verification_status ON customer_recovery_requests
CREATE INDEX idx_customer_recovery_requests_verification_status ON public.customer_recovery_requests USING btree (verification_status);

-- INDEX: idx_customer_recovery_requests_whatsapp ON customer_recovery_requests
CREATE INDEX idx_customer_recovery_requests_whatsapp ON public.customer_recovery_requests USING btree (whatsapp_number);

-- INDEX: customers_access_code_key ON customers
CREATE UNIQUE INDEX customers_access_code_key ON public.customers USING btree (access_code);

-- INDEX: customers_pkey ON customers
CREATE UNIQUE INDEX customers_pkey ON public.customers USING btree (id);

-- INDEX: customers_whatsapp_number_unique ON customers
CREATE UNIQUE INDEX customers_whatsapp_number_unique ON public.customers USING btree (whatsapp_number);

-- INDEX: idx_customers_access_code ON customers
CREATE INDEX idx_customers_access_code ON public.customers USING btree (access_code) WHERE (access_code IS NOT NULL);

-- INDEX: idx_customers_approved_by ON customers
CREATE INDEX idx_customers_approved_by ON public.customers USING btree (approved_by);

-- INDEX: idx_customers_is_deleted ON customers
CREATE INDEX idx_customers_is_deleted ON public.customers USING btree (is_deleted) WHERE (is_deleted = true);

-- INDEX: idx_customers_registration_status ON customers
CREATE INDEX idx_customers_registration_status ON public.customers USING btree (registration_status);

-- INDEX: idx_customers_whatsapp ON customers
CREATE INDEX idx_customers_whatsapp ON public.customers USING btree (whatsapp_number) WHERE (whatsapp_number IS NOT NULL);

-- INDEX: daily_temp_schedules_pkey ON daily_temp_schedules
CREATE UNIQUE INDEX daily_temp_schedules_pkey ON public.daily_temp_schedules USING btree (id);

-- INDEX: idx_daily_temp_schedules_branch_id ON daily_temp_schedules
CREATE INDEX idx_daily_temp_schedules_branch_id ON public.daily_temp_schedules USING btree (branch_id);

-- INDEX: idx_daily_temp_schedules_created_at ON daily_temp_schedules
CREATE INDEX idx_daily_temp_schedules_created_at ON public.daily_temp_schedules USING btree (created_at DESC);

-- INDEX: idx_daily_temp_schedules_payment_mode ON daily_temp_schedules
CREATE INDEX idx_daily_temp_schedules_payment_mode ON public.daily_temp_schedules USING btree (payment_mode);

-- INDEX: idx_daily_temp_schedules_schedule_date ON daily_temp_schedules
CREATE INDEX idx_daily_temp_schedules_schedule_date ON public.daily_temp_schedules USING btree (schedule_date DESC);

-- INDEX: day_off_pkey ON day_off
CREATE UNIQUE INDEX day_off_pkey ON public.day_off USING btree (id);

-- INDEX: idx_day_off_approval_requested_by ON day_off
CREATE INDEX idx_day_off_approval_requested_by ON public.day_off USING btree (approval_requested_by);

-- INDEX: idx_day_off_approval_status ON day_off
CREATE INDEX idx_day_off_approval_status ON public.day_off USING btree (approval_status);

-- INDEX: idx_day_off_date ON day_off
CREATE INDEX idx_day_off_date ON public.day_off USING btree (day_off_date);

-- INDEX: idx_day_off_description ON day_off
CREATE INDEX idx_day_off_description ON public.day_off USING btree (description);

-- INDEX: idx_day_off_employee_id ON day_off
CREATE INDEX idx_day_off_employee_id ON public.day_off USING btree (employee_id);

-- INDEX: idx_day_off_reason_id ON day_off
CREATE INDEX idx_day_off_reason_id ON public.day_off USING btree (day_off_reason_id);

-- INDEX: unique_employee_day_off ON day_off
CREATE UNIQUE INDEX unique_employee_day_off ON public.day_off USING btree (employee_id, day_off_date);

-- INDEX: day_off_reasons_pkey ON day_off_reasons
CREATE UNIQUE INDEX day_off_reasons_pkey ON public.day_off_reasons USING btree (id);

-- INDEX: day_off_reasons_reason_en_reason_ar_key ON day_off_reasons
CREATE UNIQUE INDEX day_off_reasons_reason_en_reason_ar_key ON public.day_off_reasons USING btree (reason_en, reason_ar);

-- INDEX: idx_day_off_reasons_deductible ON day_off_reasons
CREATE INDEX idx_day_off_reasons_deductible ON public.day_off_reasons USING btree (is_deductible);

-- INDEX: idx_day_off_reasons_document_mandatory ON day_off_reasons
CREATE INDEX idx_day_off_reasons_document_mandatory ON public.day_off_reasons USING btree (is_document_mandatory);

-- INDEX: day_off_weekday_pkey ON day_off_weekday
CREATE UNIQUE INDEX day_off_weekday_pkey ON public.day_off_weekday USING btree (id);

-- INDEX: idx_day_off_weekday_employee_id ON day_off_weekday
CREATE INDEX idx_day_off_weekday_employee_id ON public.day_off_weekday USING btree (employee_id);

-- INDEX: idx_day_off_weekday_weekday ON day_off_weekday
CREATE INDEX idx_day_off_weekday_weekday ON public.day_off_weekday USING btree (weekday);

-- INDEX: unique_employee_weekday_dayoff ON day_off_weekday
CREATE UNIQUE INDEX unique_employee_weekday_dayoff ON public.day_off_weekday USING btree (employee_id, weekday);

-- INDEX: default_incident_users_pkey ON default_incident_users
CREATE UNIQUE INDEX default_incident_users_pkey ON public.default_incident_users USING btree (id);

-- INDEX: default_incident_users_user_id_incident_type_id_key ON default_incident_users
CREATE UNIQUE INDEX default_incident_users_user_id_incident_type_id_key ON public.default_incident_users USING btree (user_id, incident_type_id);

-- INDEX: idx_default_incident_users_type ON default_incident_users
CREATE INDEX idx_default_incident_users_type ON public.default_incident_users USING btree (incident_type_id);

-- INDEX: idx_default_incident_users_user ON default_incident_users
CREATE INDEX idx_default_incident_users_user ON public.default_incident_users USING btree (user_id);

-- INDEX: deleted_bundle_offers_original_offer_id_key ON deleted_bundle_offers
CREATE UNIQUE INDEX deleted_bundle_offers_original_offer_id_key ON public.deleted_bundle_offers USING btree (original_offer_id);

-- INDEX: deleted_bundle_offers_pkey ON deleted_bundle_offers
CREATE UNIQUE INDEX deleted_bundle_offers_pkey ON public.deleted_bundle_offers USING btree (id);

-- INDEX: idx_deleted_bundle_offers_deleted_at ON deleted_bundle_offers
CREATE INDEX idx_deleted_bundle_offers_deleted_at ON public.deleted_bundle_offers USING btree (deleted_at DESC);

-- INDEX: idx_deleted_bundle_offers_deleted_by ON deleted_bundle_offers
CREATE INDEX idx_deleted_bundle_offers_deleted_by ON public.deleted_bundle_offers USING btree (deleted_by);

-- INDEX: idx_deleted_bundle_offers_original_id ON deleted_bundle_offers
CREATE INDEX idx_deleted_bundle_offers_original_id ON public.deleted_bundle_offers USING btree (original_offer_id);

-- INDEX: delivery_fee_tiers_pkey ON delivery_fee_tiers
CREATE UNIQUE INDEX delivery_fee_tiers_pkey ON public.delivery_fee_tiers USING btree (id);

-- INDEX: idx_delivery_tiers_active ON delivery_fee_tiers
CREATE INDEX idx_delivery_tiers_active ON public.delivery_fee_tiers USING btree (is_active);

-- INDEX: idx_delivery_tiers_branch_order ON delivery_fee_tiers
CREATE INDEX idx_delivery_tiers_branch_order ON public.delivery_fee_tiers USING btree (branch_id, tier_order);

-- INDEX: idx_delivery_tiers_branch_order_amount ON delivery_fee_tiers
CREATE INDEX idx_delivery_tiers_branch_order_amount ON public.delivery_fee_tiers USING btree (branch_id, min_order_amount, max_order_amount) WHERE (is_active = true);

-- INDEX: idx_delivery_tiers_order ON delivery_fee_tiers
CREATE INDEX idx_delivery_tiers_order ON public.delivery_fee_tiers USING btree (tier_order);

-- INDEX: idx_delivery_tiers_order_amount ON delivery_fee_tiers
CREATE INDEX idx_delivery_tiers_order_amount ON public.delivery_fee_tiers USING btree (min_order_amount, max_order_amount);

-- INDEX: ux_delivery_tiers_scope_order ON delivery_fee_tiers
CREATE UNIQUE INDEX ux_delivery_tiers_scope_order ON public.delivery_fee_tiers USING btree (COALESCE(branch_id, ('-1'::integer)::bigint), tier_order);

-- INDEX: delivery_service_settings_pkey ON delivery_service_settings
CREATE UNIQUE INDEX delivery_service_settings_pkey ON public.delivery_service_settings USING btree (id);

-- INDEX: denomination_audit_log_pkey ON denomination_audit_log
CREATE UNIQUE INDEX denomination_audit_log_pkey ON public.denomination_audit_log USING btree (id);

-- INDEX: idx_denomination_audit_action ON denomination_audit_log
CREATE INDEX idx_denomination_audit_action ON public.denomination_audit_log USING btree (action);

-- INDEX: idx_denomination_audit_branch ON denomination_audit_log
CREATE INDEX idx_denomination_audit_branch ON public.denomination_audit_log USING btree (branch_id);

-- INDEX: idx_denomination_audit_created ON denomination_audit_log
CREATE INDEX idx_denomination_audit_created ON public.denomination_audit_log USING btree (created_at DESC);

-- INDEX: idx_denomination_audit_record ON denomination_audit_log
CREATE INDEX idx_denomination_audit_record ON public.denomination_audit_log USING btree (record_id);

-- INDEX: idx_denomination_audit_user ON denomination_audit_log
CREATE INDEX idx_denomination_audit_user ON public.denomination_audit_log USING btree (user_id);

-- INDEX: denomination_permissions_pkey ON denomination_permissions
CREATE UNIQUE INDEX denomination_permissions_pkey ON public.denomination_permissions USING btree (user_id);

-- INDEX: denomination_records_pkey ON denomination_records
CREATE UNIQUE INDEX denomination_records_pkey ON public.denomination_records USING btree (id);

-- INDEX: idx_denomination_records_branch ON denomination_records
CREATE INDEX idx_denomination_records_branch ON public.denomination_records USING btree (branch_id);

-- INDEX: idx_denomination_records_branch_created ON denomination_records
CREATE INDEX idx_denomination_records_branch_created ON public.denomination_records USING btree (branch_id, created_at DESC);

-- INDEX: idx_denomination_records_branch_type ON denomination_records
CREATE INDEX idx_denomination_records_branch_type ON public.denomination_records USING btree (branch_id, record_type);

-- INDEX: idx_denomination_records_created_at ON denomination_records
CREATE INDEX idx_denomination_records_created_at ON public.denomination_records USING btree (created_at);

-- INDEX: idx_denomination_records_history ON denomination_records
CREATE INDEX idx_denomination_records_history ON public.denomination_records USING btree (branch_id, record_type, created_at DESC);

-- INDEX: idx_denomination_records_petty_cash_operation ON denomination_records
CREATE INDEX idx_denomination_records_petty_cash_operation ON public.denomination_records USING gin (petty_cash_operation);

-- INDEX: idx_denomination_records_type ON denomination_records
CREATE INDEX idx_denomination_records_type ON public.denomination_records USING btree (record_type);

-- INDEX: idx_denomination_records_user ON denomination_records
CREATE INDEX idx_denomination_records_user ON public.denomination_records USING btree (user_id);

-- INDEX: denomination_transactions_pkey ON denomination_transactions
CREATE UNIQUE INDEX denomination_transactions_pkey ON public.denomination_transactions USING btree (id);

-- INDEX: idx_denomination_transactions_branch_id ON denomination_transactions
CREATE INDEX idx_denomination_transactions_branch_id ON public.denomination_transactions USING btree (branch_id);

-- INDEX: idx_denomination_transactions_branch_section ON denomination_transactions
CREATE INDEX idx_denomination_transactions_branch_section ON public.denomination_transactions USING btree (branch_id, section);

-- INDEX: idx_denomination_transactions_created_at ON denomination_transactions
CREATE INDEX idx_denomination_transactions_created_at ON public.denomination_transactions USING btree (created_at DESC);

-- INDEX: idx_denomination_transactions_section ON denomination_transactions
CREATE INDEX idx_denomination_transactions_section ON public.denomination_transactions USING btree (section);

-- INDEX: idx_denomination_transactions_type ON denomination_transactions
CREATE INDEX idx_denomination_transactions_type ON public.denomination_transactions USING btree (transaction_type);

-- INDEX: denomination_types_code_key ON denomination_types
CREATE UNIQUE INDEX denomination_types_code_key ON public.denomination_types USING btree (code);

-- INDEX: denomination_types_pkey ON denomination_types
CREATE UNIQUE INDEX denomination_types_pkey ON public.denomination_types USING btree (id);

-- INDEX: idx_denomination_types_active ON denomination_types
CREATE INDEX idx_denomination_types_active ON public.denomination_types USING btree (is_active, sort_order);

-- INDEX: denomination_user_preferences_pkey ON denomination_user_preferences
CREATE UNIQUE INDEX denomination_user_preferences_pkey ON public.denomination_user_preferences USING btree (id);

-- INDEX: denomination_user_preferences_user_id_key ON denomination_user_preferences
CREATE UNIQUE INDEX denomination_user_preferences_user_id_key ON public.denomination_user_preferences USING btree (user_id);

-- INDEX: idx_denomination_user_preferences_user_id ON denomination_user_preferences
CREATE INDEX idx_denomination_user_preferences_user_id ON public.denomination_user_preferences USING btree (user_id);

-- INDEX: desktop_themes_pkey ON desktop_themes
CREATE UNIQUE INDEX desktop_themes_pkey ON public.desktop_themes USING btree (id);

-- INDEX: idx_desktop_themes_is_default ON desktop_themes
CREATE INDEX idx_desktop_themes_is_default ON public.desktop_themes USING btree (is_default);

-- INDEX: edge_function_trigger_log_pkey ON edge_function_trigger_log
CREATE UNIQUE INDEX edge_function_trigger_log_pkey ON public.edge_function_trigger_log USING btree (function_name);

-- INDEX: edge_functions_cache_pkey ON edge_functions_cache
CREATE UNIQUE INDEX edge_functions_cache_pkey ON public.edge_functions_cache USING btree (func_name);

-- INDEX: email_account_secrets_pkey ON email_account_secrets
CREATE UNIQUE INDEX email_account_secrets_pkey ON public.email_account_secrets USING btree (id);

-- INDEX: email_accounts_pkey ON email_accounts
CREATE UNIQUE INDEX email_accounts_pkey ON public.email_accounts USING btree (id);

-- INDEX: idx_email_accounts_active ON email_accounts
CREATE INDEX idx_email_accounts_active ON public.email_accounts USING btree (is_active) WHERE (is_active = true);

-- INDEX: idx_email_accounts_default_manual ON email_accounts
CREATE INDEX idx_email_accounts_default_manual ON public.email_accounts USING btree (default_for_manual) WHERE (default_for_manual = true);

-- INDEX: idx_email_accounts_default_transactional ON email_accounts
CREATE INDEX idx_email_accounts_default_transactional ON public.email_accounts USING btree (default_for_transactional) WHERE (default_for_transactional = true);

-- INDEX: email_ai_results_pkey ON email_ai_results
CREATE UNIQUE INDEX email_ai_results_pkey ON public.email_ai_results USING btree (id);

-- INDEX: email_ai_settings_feature_name_key ON email_ai_settings
CREATE UNIQUE INDEX email_ai_settings_feature_name_key ON public.email_ai_settings USING btree (feature_name);

-- INDEX: email_ai_settings_pkey ON email_ai_settings
CREATE UNIQUE INDEX email_ai_settings_pkey ON public.email_ai_settings USING btree (id);

-- INDEX: email_attachments_pkey ON email_attachments
CREATE UNIQUE INDEX email_attachments_pkey ON public.email_attachments USING btree (id);

-- INDEX: idx_email_attachments_message ON email_attachments
CREATE INDEX idx_email_attachments_message ON public.email_attachments USING btree (email_message_id);

-- INDEX: email_campaign_recipients_email_campaign_id_email_address_key ON email_campaign_recipients
CREATE UNIQUE INDEX email_campaign_recipients_email_campaign_id_email_address_key ON public.email_campaign_recipients USING btree (email_campaign_id, email_address);

-- INDEX: email_campaign_recipients_pkey ON email_campaign_recipients
CREATE UNIQUE INDEX email_campaign_recipients_pkey ON public.email_campaign_recipients USING btree (id);

-- INDEX: idx_email_campaign_recipients_campaign ON email_campaign_recipients
CREATE INDEX idx_email_campaign_recipients_campaign ON public.email_campaign_recipients USING btree (email_campaign_id, status);

-- INDEX: email_campaigns_pkey ON email_campaigns
CREATE UNIQUE INDEX email_campaigns_pkey ON public.email_campaigns USING btree (id);

-- INDEX: idx_email_campaigns_status ON email_campaigns
CREATE INDEX idx_email_campaigns_status ON public.email_campaigns USING btree (status);

-- INDEX: email_delivery_events_pkey ON email_delivery_events
CREATE UNIQUE INDEX email_delivery_events_pkey ON public.email_delivery_events USING btree (id);

-- INDEX: email_folders_pkey ON email_folders
CREATE UNIQUE INDEX email_folders_pkey ON public.email_folders USING btree (id);

-- INDEX: idx_email_folders_account ON email_folders
CREATE INDEX idx_email_folders_account ON public.email_folders USING btree (email_account_id);

-- INDEX: idx_email_folders_type ON email_folders
CREATE INDEX idx_email_folders_type ON public.email_folders USING btree (email_account_id, folder_type);

-- INDEX: email_group_members_email_group_id_email_address_key ON email_group_members
CREATE UNIQUE INDEX email_group_members_email_group_id_email_address_key ON public.email_group_members USING btree (email_group_id, email_address);

-- INDEX: email_group_members_pkey ON email_group_members
CREATE UNIQUE INDEX email_group_members_pkey ON public.email_group_members USING btree (id);

-- INDEX: email_groups_pkey ON email_groups
CREATE UNIQUE INDEX email_groups_pkey ON public.email_groups USING btree (id);

-- INDEX: email_logs_pkey ON email_logs
CREATE UNIQUE INDEX email_logs_pkey ON public.email_logs USING btree (id);

-- INDEX: idx_email_logs_account ON email_logs
CREATE INDEX idx_email_logs_account ON public.email_logs USING btree (email_account_id, created_at DESC);

-- INDEX: idx_email_logs_type ON email_logs
CREATE INDEX idx_email_logs_type ON public.email_logs USING btree (event_type, created_at DESC);

-- INDEX: idx_email_logs_user ON email_logs
CREATE INDEX idx_email_logs_user ON public.email_logs USING btree (user_id, created_at DESC);

-- INDEX: email_message_recipients_pkey ON email_message_recipients
CREATE UNIQUE INDEX email_message_recipients_pkey ON public.email_message_recipients USING btree (id);

-- INDEX: idx_email_recipients_address ON email_message_recipients
CREATE INDEX idx_email_recipients_address ON public.email_message_recipients USING btree (email_address);

-- INDEX: idx_email_recipients_message ON email_message_recipients
CREATE INDEX idx_email_recipients_message ON public.email_message_recipients USING btree (email_message_id);

-- INDEX: email_messages_pkey ON email_messages
CREATE UNIQUE INDEX email_messages_pkey ON public.email_messages USING btree (id);

-- INDEX: idx_email_messages_account_folder ON email_messages
CREATE INDEX idx_email_messages_account_folder ON public.email_messages USING btree (email_account_id, folder_id);

-- INDEX: idx_email_messages_direction ON email_messages
CREATE INDEX idx_email_messages_direction ON public.email_messages USING btree (direction);

-- INDEX: idx_email_messages_is_read ON email_messages
CREATE INDEX idx_email_messages_is_read ON public.email_messages USING btree (email_account_id, is_read) WHERE (is_read = false);

-- INDEX: idx_email_messages_is_starred ON email_messages
CREATE INDEX idx_email_messages_is_starred ON public.email_messages USING btree (email_account_id, is_starred) WHERE (is_starred = true);

-- INDEX: idx_email_messages_message_id_header ON email_messages
CREATE INDEX idx_email_messages_message_id_header ON public.email_messages USING btree (message_id_header);

-- INDEX: idx_email_messages_received_at ON email_messages
CREATE INDEX idx_email_messages_received_at ON public.email_messages USING btree (received_at DESC);

-- INDEX: idx_email_messages_sent_at ON email_messages
CREATE INDEX idx_email_messages_sent_at ON public.email_messages USING btree (sent_at DESC);

-- INDEX: idx_email_messages_source ON email_messages
CREATE INDEX idx_email_messages_source ON public.email_messages USING btree (source_type);

-- INDEX: idx_email_messages_status ON email_messages
CREATE INDEX idx_email_messages_status ON public.email_messages USING btree (status);

-- INDEX: idx_email_messages_thread ON email_messages
CREATE INDEX idx_email_messages_thread ON public.email_messages USING btree (thread_id);

-- INDEX: idx_email_messages_unique_incoming ON email_messages
CREATE INDEX idx_email_messages_unique_incoming ON public.email_messages USING btree (email_account_id, folder_id, uid_validity, remote_uid) WHERE (remote_uid IS NOT NULL);

-- INDEX: email_provider_presets_pkey ON email_provider_presets
CREATE UNIQUE INDEX email_provider_presets_pkey ON public.email_provider_presets USING btree (id);

-- INDEX: email_provider_presets_provider_code_key ON email_provider_presets
CREATE UNIQUE INDEX email_provider_presets_provider_code_key ON public.email_provider_presets USING btree (provider_code);

-- INDEX: email_queue_idempotency_key_key ON email_queue
CREATE UNIQUE INDEX email_queue_idempotency_key_key ON public.email_queue USING btree (idempotency_key);

-- INDEX: email_queue_pkey ON email_queue
CREATE UNIQUE INDEX email_queue_pkey ON public.email_queue USING btree (id);

-- INDEX: idx_email_queue_account ON email_queue
CREATE INDEX idx_email_queue_account ON public.email_queue USING btree (email_account_id, status);

-- INDEX: idx_email_queue_campaign ON email_queue
CREATE INDEX idx_email_queue_campaign ON public.email_queue USING btree (email_campaign_id) WHERE (email_campaign_id IS NOT NULL);

-- INDEX: idx_email_queue_retry ON email_queue
CREATE INDEX idx_email_queue_retry ON public.email_queue USING btree (next_retry_at) WHERE ((status)::text = 'temporary_failed'::text);

-- INDEX: idx_email_queue_scheduled ON email_queue
CREATE INDEX idx_email_queue_scheduled ON public.email_queue USING btree (scheduled_at) WHERE (((status)::text = 'waiting'::text) AND (scheduled_at IS NOT NULL));

-- INDEX: idx_email_queue_status ON email_queue
CREATE INDEX idx_email_queue_status ON public.email_queue USING btree (status, available_at);

-- INDEX: email_send_attempts_pkey ON email_send_attempts
CREATE UNIQUE INDEX email_send_attempts_pkey ON public.email_send_attempts USING btree (id);

-- INDEX: email_settings_pkey ON email_settings
CREATE UNIQUE INDEX email_settings_pkey ON public.email_settings USING btree (id);

-- INDEX: email_settings_setting_key_key ON email_settings
CREATE UNIQUE INDEX email_settings_setting_key_key ON public.email_settings USING btree (setting_key);

-- INDEX: email_signatures_pkey ON email_signatures
CREATE UNIQUE INDEX email_signatures_pkey ON public.email_signatures USING btree (id);

-- INDEX: email_suppressions_pkey ON email_suppressions
CREATE UNIQUE INDEX email_suppressions_pkey ON public.email_suppressions USING btree (id);

-- INDEX: idx_email_suppressions_address ON email_suppressions
CREATE INDEX idx_email_suppressions_address ON public.email_suppressions USING btree (email_address, is_active);

-- INDEX: idx_email_suppressions_type ON email_suppressions
CREATE INDEX idx_email_suppressions_type ON public.email_suppressions USING btree (suppression_type, is_active);

-- INDEX: email_sync_runs_pkey ON email_sync_runs
CREATE UNIQUE INDEX email_sync_runs_pkey ON public.email_sync_runs USING btree (id);

-- INDEX: idx_email_sync_runs_account ON email_sync_runs
CREATE INDEX idx_email_sync_runs_account ON public.email_sync_runs USING btree (email_account_id, started_at DESC);

-- INDEX: email_template_versions_pkey ON email_template_versions
CREATE UNIQUE INDEX email_template_versions_pkey ON public.email_template_versions USING btree (id);

-- INDEX: email_templates_pkey ON email_templates
CREATE UNIQUE INDEX email_templates_pkey ON public.email_templates USING btree (id);

-- INDEX: email_templates_template_code_key ON email_templates
CREATE UNIQUE INDEX email_templates_template_code_key ON public.email_templates USING btree (template_code);

-- INDEX: email_threads_pkey ON email_threads
CREATE UNIQUE INDEX email_threads_pkey ON public.email_threads USING btree (id);

-- INDEX: email_unsubscribe_tokens_pkey ON email_unsubscribe_tokens
CREATE UNIQUE INDEX email_unsubscribe_tokens_pkey ON public.email_unsubscribe_tokens USING btree (id);

-- INDEX: email_unsubscribe_tokens_token_hash_key ON email_unsubscribe_tokens
CREATE UNIQUE INDEX email_unsubscribe_tokens_token_hash_key ON public.email_unsubscribe_tokens USING btree (token_hash);

-- INDEX: email_usage_counters_email_account_id_period_type_period_st_key ON email_usage_counters
CREATE UNIQUE INDEX email_usage_counters_email_account_id_period_type_period_st_key ON public.email_usage_counters USING btree (email_account_id, period_type, period_start);

-- INDEX: email_usage_counters_pkey ON email_usage_counters
CREATE UNIQUE INDEX email_usage_counters_pkey ON public.email_usage_counters USING btree (id);

-- INDEX: idx_email_usage_counters_lookup ON email_usage_counters
CREATE INDEX idx_email_usage_counters_lookup ON public.email_usage_counters USING btree (email_account_id, period_type, period_start);

-- INDEX: employee_checklist_assignments_pkey ON employee_checklist_assignments
CREATE UNIQUE INDEX employee_checklist_assignments_pkey ON public.employee_checklist_assignments USING btree (id);

-- INDEX: idx_employee_checklist_assignments_assigned_to_user_id ON employee_checklist_assignments
CREATE INDEX idx_employee_checklist_assignments_assigned_to_user_id ON public.employee_checklist_assignments USING btree (assigned_to_user_id);

-- INDEX: idx_employee_checklist_assignments_branch_id ON employee_checklist_assignments
CREATE INDEX idx_employee_checklist_assignments_branch_id ON public.employee_checklist_assignments USING btree (branch_id);

-- INDEX: idx_employee_checklist_assignments_checklist_id ON employee_checklist_assignments
CREATE INDEX idx_employee_checklist_assignments_checklist_id ON public.employee_checklist_assignments USING btree (checklist_id);

-- INDEX: idx_employee_checklist_assignments_deleted_at ON employee_checklist_assignments
CREATE INDEX idx_employee_checklist_assignments_deleted_at ON public.employee_checklist_assignments USING btree (deleted_at);

-- INDEX: idx_employee_checklist_assignments_employee_id ON employee_checklist_assignments
CREATE INDEX idx_employee_checklist_assignments_employee_id ON public.employee_checklist_assignments USING btree (employee_id);

-- INDEX: employee_fine_payments_pkey ON employee_fine_payments
CREATE UNIQUE INDEX employee_fine_payments_pkey ON public.employee_fine_payments USING btree (id);

-- INDEX: idx_fine_payments_payment_date ON employee_fine_payments
CREATE INDEX idx_fine_payments_payment_date ON public.employee_fine_payments USING btree (payment_date);

-- INDEX: idx_fine_payments_processed_by ON employee_fine_payments
CREATE INDEX idx_fine_payments_processed_by ON public.employee_fine_payments USING btree (processed_by);

-- INDEX: idx_fine_payments_warning_id ON employee_fine_payments
CREATE INDEX idx_fine_payments_warning_id ON public.employee_fine_payments USING btree (warning_id);

-- INDEX: employee_official_holidays_pkey ON employee_official_holidays
CREATE UNIQUE INDEX employee_official_holidays_pkey ON public.employee_official_holidays USING btree (id);

-- INDEX: idx_eoh_employee_id ON employee_official_holidays
CREATE INDEX idx_eoh_employee_id ON public.employee_official_holidays USING btree (employee_id);

-- INDEX: idx_eoh_holiday_id ON employee_official_holidays
CREATE INDEX idx_eoh_holiday_id ON public.employee_official_holidays USING btree (official_holiday_id);

-- INDEX: unique_employee_official_holiday ON employee_official_holidays
CREATE UNIQUE INDEX unique_employee_official_holiday ON public.employee_official_holidays USING btree (employee_id, official_holiday_id);

-- INDEX: erp_connections_branch_id_key ON erp_connections
CREATE UNIQUE INDEX erp_connections_branch_id_key ON public.erp_connections USING btree (branch_id);

-- INDEX: erp_connections_pkey ON erp_connections
CREATE UNIQUE INDEX erp_connections_pkey ON public.erp_connections USING btree (id);

-- INDEX: idx_erp_connections_branch_id ON erp_connections
CREATE INDEX idx_erp_connections_branch_id ON public.erp_connections USING btree (branch_id);

-- INDEX: idx_erp_connections_device_id ON erp_connections
CREATE INDEX idx_erp_connections_device_id ON public.erp_connections USING btree (device_id);

-- INDEX: idx_erp_connections_erp_branch_id ON erp_connections
CREATE INDEX idx_erp_connections_erp_branch_id ON public.erp_connections USING btree (erp_branch_id);

-- INDEX: idx_erp_connections_is_active ON erp_connections
CREATE INDEX idx_erp_connections_is_active ON public.erp_connections USING btree (is_active);

-- INDEX: erp_daily_sales_branch_id_sale_date_key ON erp_daily_sales
CREATE UNIQUE INDEX erp_daily_sales_branch_id_sale_date_key ON public.erp_daily_sales USING btree (branch_id, sale_date);

-- INDEX: erp_daily_sales_pkey ON erp_daily_sales
CREATE UNIQUE INDEX erp_daily_sales_pkey ON public.erp_daily_sales USING btree (id);

-- INDEX: idx_erp_daily_sales_branch_date ON erp_daily_sales
CREATE INDEX idx_erp_daily_sales_branch_date ON public.erp_daily_sales USING btree (branch_id, sale_date);

-- INDEX: idx_erp_daily_sales_branch_id ON erp_daily_sales
CREATE INDEX idx_erp_daily_sales_branch_id ON public.erp_daily_sales USING btree (branch_id);

-- INDEX: idx_erp_daily_sales_sale_date ON erp_daily_sales
CREATE INDEX idx_erp_daily_sales_sale_date ON public.erp_daily_sales USING btree (sale_date);

-- INDEX: erp_sync_logs_pkey ON erp_sync_logs
CREATE UNIQUE INDEX erp_sync_logs_pkey ON public.erp_sync_logs USING btree (id);

-- INDEX: idx_erp_sync_logs_created_at ON erp_sync_logs
CREATE INDEX idx_erp_sync_logs_created_at ON public.erp_sync_logs USING btree (created_at DESC);

-- INDEX: erp_synced_products_barcode_key ON erp_synced_products
CREATE UNIQUE INDEX erp_synced_products_barcode_key ON public.erp_synced_products USING btree (barcode);

-- INDEX: erp_synced_products_pkey ON erp_synced_products
CREATE UNIQUE INDEX erp_synced_products_pkey ON public.erp_synced_products USING btree (id);

-- INDEX: idx_erp_synced_products_barcode ON erp_synced_products
CREATE INDEX idx_erp_synced_products_barcode ON public.erp_synced_products USING btree (barcode);

-- INDEX: idx_erp_synced_products_expiry_dates ON erp_synced_products
CREATE INDEX idx_erp_synced_products_expiry_dates ON public.erp_synced_products USING gin (expiry_dates);

-- INDEX: idx_erp_synced_products_expiry_hidden ON erp_synced_products
CREATE INDEX idx_erp_synced_products_expiry_hidden ON public.erp_synced_products USING btree (expiry_hidden) WHERE (expiry_hidden = true);

-- INDEX: idx_erp_synced_products_in_process ON erp_synced_products
CREATE INDEX idx_erp_synced_products_in_process ON public.erp_synced_products USING gin (in_process);

-- INDEX: idx_erp_synced_products_managed_by ON erp_synced_products
CREATE INDEX idx_erp_synced_products_managed_by ON public.erp_synced_products USING gin (managed_by);

-- INDEX: idx_erp_synced_products_parent_barcode ON erp_synced_products
CREATE INDEX idx_erp_synced_products_parent_barcode ON public.erp_synced_products USING btree (parent_barcode);

-- INDEX: idx_erp_synced_products_product_name_en ON erp_synced_products
CREATE INDEX idx_erp_synced_products_product_name_en ON public.erp_synced_products USING btree (product_name_en);

-- INDEX: expense_parent_categories_pkey ON expense_parent_categories
CREATE UNIQUE INDEX expense_parent_categories_pkey ON public.expense_parent_categories USING btree (id);

-- INDEX: idx_expense_parent_categories_is_active ON expense_parent_categories
CREATE INDEX idx_expense_parent_categories_is_active ON public.expense_parent_categories USING btree (is_active);

-- INDEX: expense_requisitions_pkey ON expense_requisitions
CREATE UNIQUE INDEX expense_requisitions_pkey ON public.expense_requisitions USING btree (id);

-- INDEX: expense_requisitions_requisition_number_key ON expense_requisitions
CREATE UNIQUE INDEX expense_requisitions_requisition_number_key ON public.expense_requisitions USING btree (requisition_number);

-- INDEX: idx_expense_requisitions_due_date ON expense_requisitions
CREATE INDEX idx_expense_requisitions_due_date ON public.expense_requisitions USING btree (due_date);

-- INDEX: idx_expense_requisitions_is_active ON expense_requisitions
CREATE INDEX idx_expense_requisitions_is_active ON public.expense_requisitions USING btree (is_active) WHERE (is_active = true);

-- INDEX: idx_expense_requisitions_remaining_balance ON expense_requisitions
CREATE INDEX idx_expense_requisitions_remaining_balance ON public.expense_requisitions USING btree (remaining_balance);

-- INDEX: idx_expense_requisitions_requester_ref ON expense_requisitions
CREATE INDEX idx_expense_requisitions_requester_ref ON public.expense_requisitions USING btree (requester_ref_id);

-- INDEX: idx_expense_requisitions_status_active ON expense_requisitions
CREATE INDEX idx_expense_requisitions_status_active ON public.expense_requisitions USING btree (status, is_active);

-- INDEX: idx_requisitions_branch ON expense_requisitions
CREATE INDEX idx_requisitions_branch ON public.expense_requisitions USING btree (branch_id);

-- INDEX: idx_requisitions_created_at ON expense_requisitions
CREATE INDEX idx_requisitions_created_at ON public.expense_requisitions USING btree (created_at DESC);

-- INDEX: idx_requisitions_number ON expense_requisitions
CREATE INDEX idx_requisitions_number ON public.expense_requisitions USING btree (requisition_number);

-- INDEX: idx_requisitions_status ON expense_requisitions
CREATE INDEX idx_requisitions_status ON public.expense_requisitions USING btree (status);

-- INDEX: expense_scheduler_pkey ON expense_scheduler
CREATE UNIQUE INDEX expense_scheduler_pkey ON public.expense_scheduler USING btree (id);

-- INDEX: idx_expense_scheduler_approver_id ON expense_scheduler
CREATE INDEX idx_expense_scheduler_approver_id ON public.expense_scheduler USING btree (approver_id) WHERE (approver_id IS NOT NULL);

-- INDEX: idx_expense_scheduler_branch_id ON expense_scheduler
CREATE INDEX idx_expense_scheduler_branch_id ON public.expense_scheduler USING btree (branch_id);

-- INDEX: idx_expense_scheduler_category_id ON expense_scheduler
CREATE INDEX idx_expense_scheduler_category_id ON public.expense_scheduler USING btree (expense_category_id);

-- INDEX: idx_expense_scheduler_co_user_id ON expense_scheduler
CREATE INDEX idx_expense_scheduler_co_user_id ON public.expense_scheduler USING btree (co_user_id);

-- INDEX: idx_expense_scheduler_created_at ON expense_scheduler
CREATE INDEX idx_expense_scheduler_created_at ON public.expense_scheduler USING btree (created_at DESC);

-- INDEX: idx_expense_scheduler_created_by ON expense_scheduler
CREATE INDEX idx_expense_scheduler_created_by ON public.expense_scheduler USING btree (created_by);

-- INDEX: idx_expense_scheduler_credit_period ON expense_scheduler
CREATE INDEX idx_expense_scheduler_credit_period ON public.expense_scheduler USING btree (credit_period);

-- INDEX: idx_expense_scheduler_due_date ON expense_scheduler
CREATE INDEX idx_expense_scheduler_due_date ON public.expense_scheduler USING btree (due_date);

-- INDEX: idx_expense_scheduler_due_date_paid ON expense_scheduler
CREATE INDEX idx_expense_scheduler_due_date_paid ON public.expense_scheduler USING btree (due_date, is_paid);

-- INDEX: idx_expense_scheduler_is_paid ON expense_scheduler
CREATE INDEX idx_expense_scheduler_is_paid ON public.expense_scheduler USING btree (is_paid);

-- INDEX: idx_expense_scheduler_payment_reference ON expense_scheduler
CREATE INDEX idx_expense_scheduler_payment_reference ON public.expense_scheduler USING btree (payment_reference) WHERE (payment_reference IS NOT NULL);

-- INDEX: idx_expense_scheduler_recurring_type ON expense_scheduler
CREATE INDEX idx_expense_scheduler_recurring_type ON public.expense_scheduler USING btree (recurring_type) WHERE (recurring_type IS NOT NULL);

-- INDEX: idx_expense_scheduler_requisition_id ON expense_scheduler
CREATE INDEX idx_expense_scheduler_requisition_id ON public.expense_scheduler USING btree (requisition_id);

-- INDEX: idx_expense_scheduler_schedule_type ON expense_scheduler
CREATE INDEX idx_expense_scheduler_schedule_type ON public.expense_scheduler USING btree (schedule_type);

-- INDEX: idx_expense_scheduler_status ON expense_scheduler
CREATE INDEX idx_expense_scheduler_status ON public.expense_scheduler USING btree (status);

-- INDEX: expense_sub_categories_pkey ON expense_sub_categories
CREATE UNIQUE INDEX expense_sub_categories_pkey ON public.expense_sub_categories USING btree (id);

-- INDEX: idx_expense_sub_categories_is_active ON expense_sub_categories
CREATE INDEX idx_expense_sub_categories_is_active ON public.expense_sub_categories USING btree (is_active);

-- INDEX: idx_expense_sub_categories_parent ON expense_sub_categories
CREATE INDEX idx_expense_sub_categories_parent ON public.expense_sub_categories USING btree (parent_category_id);

-- INDEX: flyer_offer_products_offer_id_product_barcode_key ON flyer_offer_products
CREATE UNIQUE INDEX flyer_offer_products_offer_id_product_barcode_key ON public.flyer_offer_products USING btree (offer_id, product_barcode);

-- INDEX: flyer_offer_products_pkey ON flyer_offer_products
CREATE UNIQUE INDEX flyer_offer_products_pkey ON public.flyer_offer_products USING btree (id);

-- INDEX: idx_flyer_offer_products_barcode ON flyer_offer_products
CREATE INDEX idx_flyer_offer_products_barcode ON public.flyer_offer_products USING btree (product_barcode);

-- INDEX: idx_flyer_offer_products_offer_id ON flyer_offer_products
CREATE INDEX idx_flyer_offer_products_offer_id ON public.flyer_offer_products USING btree (offer_id);

-- INDEX: idx_flyer_offer_products_page ON flyer_offer_products
CREATE INDEX idx_flyer_offer_products_page ON public.flyer_offer_products USING btree (offer_id, page_number, page_order);

-- INDEX: flyer_offers_pkey ON flyer_offers
CREATE UNIQUE INDEX flyer_offers_pkey ON public.flyer_offers USING btree (id);

-- INDEX: flyer_offers_template_id_key ON flyer_offers
CREATE UNIQUE INDEX flyer_offers_template_id_key ON public.flyer_offers USING btree (template_id);

-- INDEX: idx_flyer_offers_dates ON flyer_offers
CREATE INDEX idx_flyer_offers_dates ON public.flyer_offers USING btree (start_date, end_date);

-- INDEX: idx_flyer_offers_is_active ON flyer_offers
CREATE INDEX idx_flyer_offers_is_active ON public.flyer_offers USING btree (is_active);

-- INDEX: idx_flyer_offers_offer_name ON flyer_offers
CREATE INDEX idx_flyer_offers_offer_name ON public.flyer_offers USING btree (offer_name);

-- INDEX: idx_flyer_offers_offer_name_id ON flyer_offers
CREATE INDEX idx_flyer_offers_offer_name_id ON public.flyer_offers USING btree (offer_name_id);

-- INDEX: idx_flyer_offers_template_id ON flyer_offers
CREATE INDEX idx_flyer_offers_template_id ON public.flyer_offers USING btree (template_id);

-- INDEX: flyer_templates_name_unique ON flyer_templates
CREATE UNIQUE INDEX flyer_templates_name_unique ON public.flyer_templates USING btree (name);

-- INDEX: flyer_templates_pkey ON flyer_templates
CREATE UNIQUE INDEX flyer_templates_pkey ON public.flyer_templates USING btree (id);

-- INDEX: idx_flyer_templates_category ON flyer_templates
CREATE INDEX idx_flyer_templates_category ON public.flyer_templates USING btree (category) WHERE (deleted_at IS NULL);

-- INDEX: idx_flyer_templates_created_at ON flyer_templates
CREATE INDEX idx_flyer_templates_created_at ON public.flyer_templates USING btree (created_at DESC);

-- INDEX: idx_flyer_templates_created_by ON flyer_templates
CREATE INDEX idx_flyer_templates_created_by ON public.flyer_templates USING btree (created_by);

-- INDEX: idx_flyer_templates_is_active ON flyer_templates
CREATE INDEX idx_flyer_templates_is_active ON public.flyer_templates USING btree (is_active) WHERE (deleted_at IS NULL);

-- INDEX: idx_flyer_templates_is_default ON flyer_templates
CREATE INDEX idx_flyer_templates_is_default ON public.flyer_templates USING btree (is_default) WHERE ((is_default = true) AND (deleted_at IS NULL));

-- INDEX: idx_flyer_templates_tags ON flyer_templates
CREATE INDEX idx_flyer_templates_tags ON public.flyer_templates USING gin (tags);

-- INDEX: frontend_builds_pkey ON frontend_builds
CREATE UNIQUE INDEX frontend_builds_pkey ON public.frontend_builds USING btree (id);

-- INDEX: gift_wheel_coupons_code_key ON gift_wheel_coupons
CREATE UNIQUE INDEX gift_wheel_coupons_code_key ON public.gift_wheel_coupons USING btree (code);

-- INDEX: gift_wheel_coupons_pkey ON gift_wheel_coupons
CREATE UNIQUE INDEX gift_wheel_coupons_pkey ON public.gift_wheel_coupons USING btree (id);

-- INDEX: idx_gift_wheel_coupons_code ON gift_wheel_coupons
CREATE INDEX idx_gift_wheel_coupons_code ON public.gift_wheel_coupons USING btree (code);

-- INDEX: idx_gift_wheel_coupons_status ON gift_wheel_coupons
CREATE INDEX idx_gift_wheel_coupons_status ON public.gift_wheel_coupons USING btree (status);

-- INDEX: gift_wheel_rewards_pkey ON gift_wheel_rewards
CREATE UNIQUE INDEX gift_wheel_rewards_pkey ON public.gift_wheel_rewards USING btree (id);

-- INDEX: gift_wheel_settings_pkey ON gift_wheel_settings
CREATE UNIQUE INDEX gift_wheel_settings_pkey ON public.gift_wheel_settings USING btree (id);

-- INDEX: gift_wheel_spins_pkey ON gift_wheel_spins
CREATE UNIQUE INDEX gift_wheel_spins_pkey ON public.gift_wheel_spins USING btree (id);

-- INDEX: idx_gift_wheel_spins_bill_number ON gift_wheel_spins
CREATE INDEX idx_gift_wheel_spins_bill_number ON public.gift_wheel_spins USING btree (bill_number);

-- INDEX: idx_gift_wheel_spins_created_at ON gift_wheel_spins
CREATE INDEX idx_gift_wheel_spins_created_at ON public.gift_wheel_spins USING btree (created_at);

-- INDEX: helper_apps_pkey ON helper_apps
CREATE UNIQUE INDEX helper_apps_pkey ON public.helper_apps USING btree (id);

-- INDEX: hr_analysed_attendance_data_pkey ON hr_analysed_attendance_data
CREATE UNIQUE INDEX hr_analysed_attendance_data_pkey ON public.hr_analysed_attendance_data USING btree (id);

-- INDEX: idx_analysed_att_branch ON hr_analysed_attendance_data
CREATE INDEX idx_analysed_att_branch ON public.hr_analysed_attendance_data USING btree (branch_id);

-- INDEX: idx_analysed_att_date ON hr_analysed_attendance_data
CREATE INDEX idx_analysed_att_date ON public.hr_analysed_attendance_data USING btree (shift_date);

-- INDEX: idx_analysed_att_emp_date ON hr_analysed_attendance_data
CREATE INDEX idx_analysed_att_emp_date ON public.hr_analysed_attendance_data USING btree (employee_id, shift_date);

-- INDEX: idx_analysed_att_employee_id ON hr_analysed_attendance_data
CREATE INDEX idx_analysed_att_employee_id ON public.hr_analysed_attendance_data USING btree (employee_id);

-- INDEX: idx_analysed_att_status ON hr_analysed_attendance_data
CREATE INDEX idx_analysed_att_status ON public.hr_analysed_attendance_data USING btree (status);

-- INDEX: unique_employee_shift_date ON hr_analysed_attendance_data
CREATE UNIQUE INDEX unique_employee_shift_date ON public.hr_analysed_attendance_data USING btree (employee_id, shift_date);

-- INDEX: hr_basic_salary_pkey ON hr_basic_salary
CREATE UNIQUE INDEX hr_basic_salary_pkey ON public.hr_basic_salary USING btree (employee_id);

-- INDEX: idx_hr_basic_salary_employee_id ON hr_basic_salary
CREATE INDEX idx_hr_basic_salary_employee_id ON public.hr_basic_salary USING btree (employee_id);

-- INDEX: hr_checklist_operations_pkey ON hr_checklist_operations
CREATE UNIQUE INDEX hr_checklist_operations_pkey ON public.hr_checklist_operations USING btree (id);

-- INDEX: idx_checklist_operations_submission_type_en ON hr_checklist_operations
CREATE INDEX idx_checklist_operations_submission_type_en ON public.hr_checklist_operations USING btree (submission_type_en);

-- INDEX: idx_hr_checklist_operations_box ON hr_checklist_operations
CREATE INDEX idx_hr_checklist_operations_box ON public.hr_checklist_operations USING btree (box_operation_id);

-- INDEX: idx_hr_checklist_operations_box_number ON hr_checklist_operations
CREATE INDEX idx_hr_checklist_operations_box_number ON public.hr_checklist_operations USING btree (box_number);

-- INDEX: idx_hr_checklist_operations_branch ON hr_checklist_operations
CREATE INDEX idx_hr_checklist_operations_branch ON public.hr_checklist_operations USING btree (branch_id);

-- INDEX: idx_hr_checklist_operations_checklist ON hr_checklist_operations
CREATE INDEX idx_hr_checklist_operations_checklist ON public.hr_checklist_operations USING btree (checklist_id);

-- INDEX: idx_hr_checklist_operations_created ON hr_checklist_operations
CREATE INDEX idx_hr_checklist_operations_created ON public.hr_checklist_operations USING btree (created_at DESC);

-- INDEX: idx_hr_checklist_operations_date ON hr_checklist_operations
CREATE INDEX idx_hr_checklist_operations_date ON public.hr_checklist_operations USING btree (operation_date DESC);

-- INDEX: idx_hr_checklist_operations_employee ON hr_checklist_operations
CREATE INDEX idx_hr_checklist_operations_employee ON public.hr_checklist_operations USING btree (employee_id);

-- INDEX: idx_hr_checklist_operations_user ON hr_checklist_operations
CREATE INDEX idx_hr_checklist_operations_user ON public.hr_checklist_operations USING btree (user_id);

-- INDEX: hr_checklist_questions_pkey ON hr_checklist_questions
CREATE UNIQUE INDEX hr_checklist_questions_pkey ON public.hr_checklist_questions USING btree (id);

-- INDEX: idx_hr_checklist_questions_created ON hr_checklist_questions
CREATE INDEX idx_hr_checklist_questions_created ON public.hr_checklist_questions USING btree (created_at DESC);

-- INDEX: hr_checklists_pkey ON hr_checklists
CREATE UNIQUE INDEX hr_checklists_pkey ON public.hr_checklists USING btree (id);

-- INDEX: idx_hr_checklists_created ON hr_checklists
CREATE INDEX idx_hr_checklists_created ON public.hr_checklists USING btree (created_at DESC);

-- INDEX: hr_departments_pkey ON hr_departments
CREATE UNIQUE INDEX hr_departments_pkey ON public.hr_departments USING btree (id);

-- INDEX: hr_employee_applicability_rule_periods_effective_idx ON hr_employee_applicability_rule_periods
CREATE INDEX hr_employee_applicability_rule_periods_effective_idx ON public.hr_employee_applicability_rule_periods USING btree (employee_id, rule_type, effective_from, effective_to);

-- INDEX: hr_employee_applicability_rule_periods_employee_type_idx ON hr_employee_applicability_rule_periods
CREATE INDEX hr_employee_applicability_rule_periods_employee_type_idx ON public.hr_employee_applicability_rule_periods USING btree (employee_id, rule_type);

-- INDEX: hr_employee_applicability_rule_periods_pkey ON hr_employee_applicability_rule_periods
CREATE UNIQUE INDEX hr_employee_applicability_rule_periods_pkey ON public.hr_employee_applicability_rule_periods USING btree (id);

-- INDEX: hr_employee_applicability_rule_periods_unique_seq ON hr_employee_applicability_rule_periods
CREATE UNIQUE INDEX hr_employee_applicability_rule_periods_unique_seq ON public.hr_employee_applicability_rule_periods USING btree (employee_id, rule_type, sequence_no);

-- INDEX: hr_employee_esob_records_pkey ON hr_employee_esob_records
CREATE UNIQUE INDEX hr_employee_esob_records_pkey ON public.hr_employee_esob_records USING btree (id);

-- INDEX: idx_hr_employee_esob_records_employee_id ON hr_employee_esob_records
CREATE INDEX idx_hr_employee_esob_records_employee_id ON public.hr_employee_esob_records USING btree (employee_id);

-- INDEX: idx_hr_employee_esob_records_updated_at ON hr_employee_esob_records
CREATE INDEX idx_hr_employee_esob_records_updated_at ON public.hr_employee_esob_records USING btree (updated_at DESC);

-- INDEX: hr_employee_leave_approvals_employee_date_idx ON hr_employee_leave_approvals
CREATE INDEX hr_employee_leave_approvals_employee_date_idx ON public.hr_employee_leave_approvals USING btree (employee_id, leave_date);

-- INDEX: hr_employee_leave_approvals_employee_date_key ON hr_employee_leave_approvals
CREATE UNIQUE INDEX hr_employee_leave_approvals_employee_date_key ON public.hr_employee_leave_approvals USING btree (employee_id, leave_date);

-- INDEX: hr_employee_leave_approvals_pkey ON hr_employee_leave_approvals
CREATE UNIQUE INDEX hr_employee_leave_approvals_pkey ON public.hr_employee_leave_approvals USING btree (id);

-- INDEX: hr_employee_master_pkey ON hr_employee_master
CREATE UNIQUE INDEX hr_employee_master_pkey ON public.hr_employee_master USING btree (id);

-- INDEX: hr_employee_master_user_id_key ON hr_employee_master
CREATE UNIQUE INDEX hr_employee_master_user_id_key ON public.hr_employee_master USING btree (user_id);

-- INDEX: idx_employment_status ON hr_employee_master
CREATE INDEX idx_employment_status ON public.hr_employee_master USING btree (employment_status);

-- INDEX: idx_employment_status_effective_date ON hr_employee_master
CREATE INDEX idx_employment_status_effective_date ON public.hr_employee_master USING btree (employment_status_effective_date);

-- INDEX: idx_hr_employee_driving_licence_expiry ON hr_employee_master
CREATE INDEX idx_hr_employee_driving_licence_expiry ON public.hr_employee_master USING btree (driving_licence_expiry_date);

-- INDEX: idx_hr_employee_health_card_expiry ON hr_employee_master
CREATE INDEX idx_hr_employee_health_card_expiry ON public.hr_employee_master USING btree (health_card_expiry_date);

-- INDEX: idx_hr_employee_id_expiry ON hr_employee_master
CREATE INDEX idx_hr_employee_id_expiry ON public.hr_employee_master USING btree (id_expiry_date);

-- INDEX: idx_hr_employee_master_bank_name ON hr_employee_master
CREATE INDEX idx_hr_employee_master_bank_name ON public.hr_employee_master USING btree (bank_name);

-- INDEX: idx_hr_employee_master_branch_id ON hr_employee_master
CREATE INDEX idx_hr_employee_master_branch_id ON public.hr_employee_master USING btree (current_branch_id);

-- INDEX: idx_hr_employee_master_date_of_birth ON hr_employee_master
CREATE INDEX idx_hr_employee_master_date_of_birth ON public.hr_employee_master USING btree (date_of_birth);

-- INDEX: idx_hr_employee_master_driving_licence_expiry_date ON hr_employee_master
CREATE INDEX idx_hr_employee_master_driving_licence_expiry_date ON public.hr_employee_master USING btree (driving_licence_expiry_date);

-- INDEX: idx_hr_employee_master_employee_mapping ON hr_employee_master
CREATE INDEX idx_hr_employee_master_employee_mapping ON public.hr_employee_master USING gin (employee_id_mapping);

-- INDEX: idx_hr_employee_master_erp_mapping ON hr_employee_master
CREATE INDEX idx_hr_employee_master_erp_mapping ON public.hr_employee_master USING gin (erp_employee_id_mapping);

-- INDEX: idx_hr_employee_master_health_card_expiry_date ON hr_employee_master
CREATE INDEX idx_hr_employee_master_health_card_expiry_date ON public.hr_employee_master USING btree (health_card_expiry_date);

-- INDEX: idx_hr_employee_master_health_educational_renewal_date ON hr_employee_master
CREATE INDEX idx_hr_employee_master_health_educational_renewal_date ON public.hr_employee_master USING btree (health_educational_renewal_date);

-- INDEX: idx_hr_employee_master_id_expiry_date ON hr_employee_master
CREATE INDEX idx_hr_employee_master_id_expiry_date ON public.hr_employee_master USING btree (id_expiry_date);

-- INDEX: idx_hr_employee_master_insurance_company_id ON hr_employee_master
CREATE INDEX idx_hr_employee_master_insurance_company_id ON public.hr_employee_master USING btree (insurance_company_id);

-- INDEX: idx_hr_employee_master_insurance_expiry_date ON hr_employee_master
CREATE INDEX idx_hr_employee_master_insurance_expiry_date ON public.hr_employee_master USING btree (insurance_expiry_date);

-- INDEX: idx_hr_employee_master_join_date ON hr_employee_master
CREATE INDEX idx_hr_employee_master_join_date ON public.hr_employee_master USING btree (join_date);

-- INDEX: idx_hr_employee_master_nationality_id ON hr_employee_master
CREATE INDEX idx_hr_employee_master_nationality_id ON public.hr_employee_master USING btree (nationality_id);

-- INDEX: idx_hr_employee_master_permitted_early_leave_hours ON hr_employee_master
CREATE INDEX idx_hr_employee_master_permitted_early_leave_hours ON public.hr_employee_master USING btree (permitted_early_leave_hours);

-- INDEX: idx_hr_employee_master_position_id ON hr_employee_master
CREATE INDEX idx_hr_employee_master_position_id ON public.hr_employee_master USING btree (current_position_id);

-- INDEX: idx_hr_employee_master_probation_period_expiry_date ON hr_employee_master
CREATE INDEX idx_hr_employee_master_probation_period_expiry_date ON public.hr_employee_master USING btree (probation_period_expiry_date);

-- INDEX: idx_hr_employee_master_user_id ON hr_employee_master
CREATE INDEX idx_hr_employee_master_user_id ON public.hr_employee_master USING btree (user_id);

-- INDEX: idx_hr_employee_master_work_permit_expiry_date ON hr_employee_master
CREATE INDEX idx_hr_employee_master_work_permit_expiry_date ON public.hr_employee_master USING btree (work_permit_expiry_date);

-- INDEX: hr_employee_settlement_applicability_employee_id_key ON hr_employee_settlement_applicability
CREATE UNIQUE INDEX hr_employee_settlement_applicability_employee_id_key ON public.hr_employee_settlement_applicability USING btree (employee_id);

-- INDEX: hr_employee_settlement_applicability_leave_rule_idx ON hr_employee_settlement_applicability
CREATE INDEX hr_employee_settlement_applicability_leave_rule_idx ON public.hr_employee_settlement_applicability USING btree (leave_salary_rule_id);

-- INDEX: hr_employee_settlement_applicability_pkey ON hr_employee_settlement_applicability
CREATE UNIQUE INDEX hr_employee_settlement_applicability_pkey ON public.hr_employee_settlement_applicability USING btree (id);

-- INDEX: hr_employee_settlement_applicability_ticket_rule_idx ON hr_employee_settlement_applicability
CREATE INDEX hr_employee_settlement_applicability_ticket_rule_idx ON public.hr_employee_settlement_applicability USING btree (ticket_rule_id);

-- INDEX: hr_employee_ticket_issuances_employee_date_idx ON hr_employee_ticket_issuances
CREATE INDEX hr_employee_ticket_issuances_employee_date_idx ON public.hr_employee_ticket_issuances USING btree (employee_id, issuance_date);

-- INDEX: hr_employee_ticket_issuances_pkey ON hr_employee_ticket_issuances
CREATE UNIQUE INDEX hr_employee_ticket_issuances_pkey ON public.hr_employee_ticket_issuances USING btree (id);

-- INDEX: hr_employees_employee_id_branch_id_unique ON hr_employees
CREATE UNIQUE INDEX hr_employees_employee_id_branch_id_unique ON public.hr_employees USING btree (employee_id, branch_id);

-- INDEX: hr_employees_pkey ON hr_employees
CREATE UNIQUE INDEX hr_employees_pkey ON public.hr_employees USING btree (id);

-- INDEX: idx_hr_employees_branch_id ON hr_employees
CREATE INDEX idx_hr_employees_branch_id ON public.hr_employees USING btree (branch_id);

-- INDEX: idx_hr_employees_employee_id ON hr_employees
CREATE INDEX idx_hr_employees_employee_id ON public.hr_employees USING btree (employee_id);

-- INDEX: idx_hr_employees_employee_id_branch_id ON hr_employees
CREATE INDEX idx_hr_employees_employee_id_branch_id ON public.hr_employees USING btree (employee_id, branch_id);

-- INDEX: idx_hr_employees_updated_at ON hr_employees
CREATE INDEX idx_hr_employees_updated_at ON public.hr_employees USING btree (updated_at);

-- INDEX: hr_esob_base_rules_pkey ON hr_esob_base_rules
CREATE UNIQUE INDEX hr_esob_base_rules_pkey ON public.hr_esob_base_rules USING btree (id);

-- INDEX: idx_hr_esob_base_rules_years ON hr_esob_base_rules
CREATE INDEX idx_hr_esob_base_rules_years ON public.hr_esob_base_rules USING btree (years_from, years_to);

-- INDEX: hr_esob_resignation_factors_pkey ON hr_esob_resignation_factors
CREATE UNIQUE INDEX hr_esob_resignation_factors_pkey ON public.hr_esob_resignation_factors USING btree (id);

-- INDEX: idx_hr_esob_resignation_factors_years ON hr_esob_resignation_factors
CREATE INDEX idx_hr_esob_resignation_factors_years ON public.hr_esob_resignation_factors USING btree (years_from, years_to);

-- INDEX: hr_fingerprint_transactions_pkey ON hr_fingerprint_transactions
CREATE UNIQUE INDEX hr_fingerprint_transactions_pkey ON public.hr_fingerprint_transactions USING btree (id);

-- INDEX: idx_fingerprint_transactions_processed ON hr_fingerprint_transactions
CREATE INDEX idx_fingerprint_transactions_processed ON public.hr_fingerprint_transactions USING btree (processed);

-- INDEX: idx_hr_fingerprint_branch_id ON hr_fingerprint_transactions
CREATE INDEX idx_hr_fingerprint_branch_id ON public.hr_fingerprint_transactions USING btree (branch_id);

-- INDEX: idx_hr_fingerprint_date ON hr_fingerprint_transactions
CREATE INDEX idx_hr_fingerprint_date ON public.hr_fingerprint_transactions USING btree (date);

-- INDEX: idx_hr_fingerprint_employee_id ON hr_fingerprint_transactions
CREATE INDEX idx_hr_fingerprint_employee_id ON public.hr_fingerprint_transactions USING btree (employee_id);

-- INDEX: idx_hr_fingerprint_punch_state ON hr_fingerprint_transactions
CREATE INDEX idx_hr_fingerprint_punch_state ON public.hr_fingerprint_transactions USING btree (status);

-- INDEX: unique_fingerprint_transaction ON hr_fingerprint_transactions
CREATE UNIQUE INDEX unique_fingerprint_transaction ON public.hr_fingerprint_transactions USING btree (employee_id, date, "time", status, branch_id);

-- INDEX: hr_insurance_companies_pkey ON hr_insurance_companies
CREATE UNIQUE INDEX hr_insurance_companies_pkey ON public.hr_insurance_companies USING btree (id);

-- INDEX: idx_hr_insurance_companies_name_ar ON hr_insurance_companies
CREATE INDEX idx_hr_insurance_companies_name_ar ON public.hr_insurance_companies USING btree (name_ar);

-- INDEX: idx_hr_insurance_companies_name_en ON hr_insurance_companies
CREATE INDEX idx_hr_insurance_companies_name_en ON public.hr_insurance_companies USING btree (name_en);

-- INDEX: hr_levels_pkey ON hr_levels
CREATE UNIQUE INDEX hr_levels_pkey ON public.hr_levels USING btree (id);

-- INDEX: hr_position_assignments_pkey ON hr_position_assignments
CREATE UNIQUE INDEX hr_position_assignments_pkey ON public.hr_position_assignments USING btree (id);

-- INDEX: idx_hr_assignments_branch_id ON hr_position_assignments
CREATE INDEX idx_hr_assignments_branch_id ON public.hr_position_assignments USING btree (branch_id);

-- INDEX: idx_hr_assignments_employee_id ON hr_position_assignments
CREATE INDEX idx_hr_assignments_employee_id ON public.hr_position_assignments USING btree (employee_id);

-- INDEX: hr_position_reporting_template_pkey ON hr_position_reporting_template
CREATE UNIQUE INDEX hr_position_reporting_template_pkey ON public.hr_position_reporting_template USING btree (id);

-- INDEX: hr_position_reporting_template_subordinate_position_id_key ON hr_position_reporting_template
CREATE UNIQUE INDEX hr_position_reporting_template_subordinate_position_id_key ON public.hr_position_reporting_template USING btree (subordinate_position_id);

-- INDEX: idx_hr_position_template_mgr1 ON hr_position_reporting_template
CREATE INDEX idx_hr_position_template_mgr1 ON public.hr_position_reporting_template USING btree (manager_position_1);

-- INDEX: idx_hr_position_template_mgr2 ON hr_position_reporting_template
CREATE INDEX idx_hr_position_template_mgr2 ON public.hr_position_reporting_template USING btree (manager_position_2);

-- INDEX: idx_hr_position_template_mgr3 ON hr_position_reporting_template
CREATE INDEX idx_hr_position_template_mgr3 ON public.hr_position_reporting_template USING btree (manager_position_3);

-- INDEX: idx_hr_position_template_mgr4 ON hr_position_reporting_template
CREATE INDEX idx_hr_position_template_mgr4 ON public.hr_position_reporting_template USING btree (manager_position_4);

-- INDEX: idx_hr_position_template_mgr5 ON hr_position_reporting_template
CREATE INDEX idx_hr_position_template_mgr5 ON public.hr_position_reporting_template USING btree (manager_position_5);

-- INDEX: idx_hr_position_template_subordinate ON hr_position_reporting_template
CREATE INDEX idx_hr_position_template_subordinate ON public.hr_position_reporting_template USING btree (subordinate_position_id);

-- INDEX: hr_positions_pkey ON hr_positions
CREATE UNIQUE INDEX hr_positions_pkey ON public.hr_positions USING btree (id);

-- INDEX: hr_salary_notes_pkey ON hr_salary_notes
CREATE UNIQUE INDEX hr_salary_notes_pkey ON public.hr_salary_notes USING btree (id);

-- INDEX: idx_hr_salary_notes_created_at ON hr_salary_notes
CREATE INDEX idx_hr_salary_notes_created_at ON public.hr_salary_notes USING btree (created_at DESC);

-- INDEX: idx_hr_salary_notes_employee_id ON hr_salary_notes
CREATE INDEX idx_hr_salary_notes_employee_id ON public.hr_salary_notes USING btree (employee_id);

-- INDEX: hr_salary_statements_dates_idx ON hr_salary_statements
CREATE INDEX hr_salary_statements_dates_idx ON public.hr_salary_statements USING btree (start_date, end_date);

-- INDEX: hr_salary_statements_pkey ON hr_salary_statements
CREATE UNIQUE INDEX hr_salary_statements_pkey ON public.hr_salary_statements USING btree (id);

-- INDEX: hr_salary_statements_updated_at_idx ON hr_salary_statements
CREATE INDEX hr_salary_statements_updated_at_idx ON public.hr_salary_statements USING btree (updated_at DESC);

-- INDEX: idx_incident_actions_action_type ON incident_actions
CREATE INDEX idx_incident_actions_action_type ON public.incident_actions USING btree (action_type);

-- INDEX: idx_incident_actions_employee_id ON incident_actions
CREATE INDEX idx_incident_actions_employee_id ON public.incident_actions USING btree (employee_id);

-- INDEX: idx_incident_actions_has_fine ON incident_actions
CREATE INDEX idx_incident_actions_has_fine ON public.incident_actions USING btree (has_fine);

-- INDEX: idx_incident_actions_incident_id ON incident_actions
CREATE INDEX idx_incident_actions_incident_id ON public.incident_actions USING btree (incident_id);

-- INDEX: idx_incident_actions_is_paid ON incident_actions
CREATE INDEX idx_incident_actions_is_paid ON public.incident_actions USING btree (is_paid);

-- INDEX: incident_actions_pkey ON incident_actions
CREATE UNIQUE INDEX incident_actions_pkey ON public.incident_actions USING btree (id);

-- INDEX: idx_incident_types_is_active ON incident_types
CREATE INDEX idx_incident_types_is_active ON public.incident_types USING btree (is_active) WHERE (is_active = true);

-- INDEX: incident_types_incident_type_ar_key ON incident_types
CREATE UNIQUE INDEX incident_types_incident_type_ar_key ON public.incident_types USING btree (incident_type_ar);

-- INDEX: incident_types_incident_type_en_key ON incident_types
CREATE UNIQUE INDEX incident_types_incident_type_en_key ON public.incident_types USING btree (incident_type_en);

-- INDEX: incident_types_pkey ON incident_types
CREATE UNIQUE INDEX incident_types_pkey ON public.incident_types USING btree (id);

-- INDEX: idx_incidents_attachments ON incidents
CREATE INDEX idx_incidents_attachments ON public.incidents USING gin (attachments);

-- INDEX: idx_incidents_branch_id ON incidents
CREATE INDEX idx_incidents_branch_id ON public.incidents USING btree (branch_id);

-- INDEX: idx_incidents_created_at ON incidents
CREATE INDEX idx_incidents_created_at ON public.incidents USING btree (created_at DESC);

-- INDEX: idx_incidents_employee_id ON incidents
CREATE INDEX idx_incidents_employee_id ON public.incidents USING btree (employee_id);

-- INDEX: idx_incidents_incident_type_id ON incidents
CREATE INDEX idx_incidents_incident_type_id ON public.incidents USING btree (incident_type_id);

-- INDEX: idx_incidents_related_party ON incidents
CREATE INDEX idx_incidents_related_party ON public.incidents USING gin (related_party) WHERE (related_party IS NOT NULL);

-- INDEX: idx_incidents_reports_to_user_ids ON incidents
CREATE INDEX idx_incidents_reports_to_user_ids ON public.incidents USING gin (reports_to_user_ids);

-- INDEX: idx_incidents_resolution_report ON incidents
CREATE INDEX idx_incidents_resolution_report ON public.incidents USING gin (resolution_report) WHERE (resolution_report IS NOT NULL);

-- INDEX: idx_incidents_resolution_status ON incidents
CREATE INDEX idx_incidents_resolution_status ON public.incidents USING btree (resolution_status);

-- INDEX: idx_incidents_violation_id ON incidents
CREATE INDEX idx_incidents_violation_id ON public.incidents USING btree (violation_id);

-- INDEX: incidents_pkey ON incidents
CREATE UNIQUE INDEX incidents_pkey ON public.incidents USING btree (id);

-- INDEX: idx_interface_permissions_cashier ON interface_permissions
CREATE INDEX idx_interface_permissions_cashier ON public.interface_permissions USING btree (cashier_enabled) WHERE (cashier_enabled = true);

-- INDEX: idx_interface_permissions_customer ON interface_permissions
CREATE INDEX idx_interface_permissions_customer ON public.interface_permissions USING btree (customer_enabled);

-- INDEX: idx_interface_permissions_desktop ON interface_permissions
CREATE INDEX idx_interface_permissions_desktop ON public.interface_permissions USING btree (desktop_enabled);

-- INDEX: idx_interface_permissions_mobile ON interface_permissions
CREATE INDEX idx_interface_permissions_mobile ON public.interface_permissions USING btree (mobile_enabled);

-- INDEX: idx_interface_permissions_updated_by ON interface_permissions
CREATE INDEX idx_interface_permissions_updated_by ON public.interface_permissions USING btree (updated_by);

-- INDEX: idx_interface_permissions_user_id ON interface_permissions
CREATE INDEX idx_interface_permissions_user_id ON public.interface_permissions USING btree (user_id);

-- INDEX: interface_permissions_pkey ON interface_permissions
CREATE UNIQUE INDEX interface_permissions_pkey ON public.interface_permissions USING btree (id);

-- INDEX: interface_permissions_user_unique ON interface_permissions
CREATE UNIQUE INDEX interface_permissions_user_unique ON public.interface_permissions USING btree (user_id);

-- INDEX: idx_lrlp_collection_incharge ON lease_rent_lease_parties
CREATE INDEX idx_lrlp_collection_incharge ON public.lease_rent_lease_parties USING btree (collection_incharge_id);

-- INDEX: idx_lrlp_contract_dates ON lease_rent_lease_parties
CREATE INDEX idx_lrlp_contract_dates ON public.lease_rent_lease_parties USING btree (contract_start_date, contract_end_date);

-- INDEX: idx_lrlp_payment_mode ON lease_rent_lease_parties
CREATE INDEX idx_lrlp_payment_mode ON public.lease_rent_lease_parties USING btree (payment_mode);

-- INDEX: idx_lrlp_property_id ON lease_rent_lease_parties
CREATE INDEX idx_lrlp_property_id ON public.lease_rent_lease_parties USING btree (property_id);

-- INDEX: idx_lrlp_property_space_id ON lease_rent_lease_parties
CREATE INDEX idx_lrlp_property_space_id ON public.lease_rent_lease_parties USING btree (property_space_id);

-- INDEX: lease_rent_lease_parties_pkey ON lease_rent_lease_parties
CREATE UNIQUE INDEX lease_rent_lease_parties_pkey ON public.lease_rent_lease_parties USING btree (id);

-- INDEX: idx_payment_entries_party ON lease_rent_payment_entries
CREATE INDEX idx_payment_entries_party ON public.lease_rent_payment_entries USING btree (party_type, party_id, period_num, column_name);

-- INDEX: lease_rent_payment_entries_pkey ON lease_rent_payment_entries
CREATE UNIQUE INDEX lease_rent_payment_entries_pkey ON public.lease_rent_payment_entries USING btree (id);

-- INDEX: idx_payments_party ON lease_rent_payments
CREATE INDEX idx_payments_party ON public.lease_rent_payments USING btree (party_type, party_id);

-- INDEX: idx_payments_party_period ON lease_rent_payments
CREATE UNIQUE INDEX idx_payments_party_period ON public.lease_rent_payments USING btree (party_type, party_id, period_num);

-- INDEX: lease_rent_payments_pkey ON lease_rent_payments
CREATE UNIQUE INDEX lease_rent_payments_pkey ON public.lease_rent_payments USING btree (id);

-- INDEX: lease_rent_payments_unique_period ON lease_rent_payments
CREATE UNIQUE INDEX lease_rent_payments_unique_period ON public.lease_rent_payments USING btree (party_type, party_id, period_num);

-- INDEX: idx_lease_rent_properties_created_by ON lease_rent_properties
CREATE INDEX idx_lease_rent_properties_created_by ON public.lease_rent_properties USING btree (created_by);

-- INDEX: idx_lease_rent_properties_is_leased ON lease_rent_properties
CREATE INDEX idx_lease_rent_properties_is_leased ON public.lease_rent_properties USING btree (is_leased);

-- INDEX: idx_lease_rent_properties_is_rented ON lease_rent_properties
CREATE INDEX idx_lease_rent_properties_is_rented ON public.lease_rent_properties USING btree (is_rented);

-- INDEX: lease_rent_property_spaces_pkey ON lease_rent_properties
CREATE UNIQUE INDEX lease_rent_property_spaces_pkey ON public.lease_rent_properties USING btree (id);

-- INDEX: idx_lease_rent_property_spaces_created_by ON lease_rent_property_spaces
CREATE INDEX idx_lease_rent_property_spaces_created_by ON public.lease_rent_property_spaces USING btree (created_by);

-- INDEX: idx_lease_rent_property_spaces_property_id ON lease_rent_property_spaces
CREATE INDEX idx_lease_rent_property_spaces_property_id ON public.lease_rent_property_spaces USING btree (property_id);

-- INDEX: lease_rent_property_spaces_pkey1 ON lease_rent_property_spaces
CREATE UNIQUE INDEX lease_rent_property_spaces_pkey1 ON public.lease_rent_property_spaces USING btree (id);

-- INDEX: unique_property_space_number ON lease_rent_property_spaces
CREATE UNIQUE INDEX unique_property_space_number ON public.lease_rent_property_spaces USING btree (property_id, space_number);

-- INDEX: idx_lrrp_collection_incharge ON lease_rent_rent_parties
CREATE INDEX idx_lrrp_collection_incharge ON public.lease_rent_rent_parties USING btree (collection_incharge_id);

-- INDEX: idx_lrrp_contract_dates ON lease_rent_rent_parties
CREATE INDEX idx_lrrp_contract_dates ON public.lease_rent_rent_parties USING btree (contract_start_date, contract_end_date);

-- INDEX: idx_lrrp_payment_mode ON lease_rent_rent_parties
CREATE INDEX idx_lrrp_payment_mode ON public.lease_rent_rent_parties USING btree (payment_mode);

-- INDEX: idx_lrrp_property_id ON lease_rent_rent_parties
CREATE INDEX idx_lrrp_property_id ON public.lease_rent_rent_parties USING btree (property_id);

-- INDEX: idx_lrrp_property_space_id ON lease_rent_rent_parties
CREATE INDEX idx_lrrp_property_space_id ON public.lease_rent_rent_parties USING btree (property_space_id);

-- INDEX: lease_rent_rent_parties_pkey ON lease_rent_rent_parties
CREATE UNIQUE INDEX lease_rent_rent_parties_pkey ON public.lease_rent_rent_parties USING btree (id);

-- INDEX: idx_special_changes_dates ON lease_rent_special_changes
CREATE INDEX idx_special_changes_dates ON public.lease_rent_special_changes USING btree (effective_from, effective_until);

-- INDEX: idx_special_changes_party ON lease_rent_special_changes
CREATE INDEX idx_special_changes_party ON public.lease_rent_special_changes USING btree (party_type, party_id);

-- INDEX: lease_rent_special_changes_pkey ON lease_rent_special_changes
CREATE UNIQUE INDEX lease_rent_special_changes_pkey ON public.lease_rent_special_changes USING btree (id);

-- INDEX: idx_lcb_bill_date ON loyalty_customer_bills
CREATE INDEX idx_lcb_bill_date ON public.loyalty_customer_bills USING btree (bill_date);

-- INDEX: idx_lcb_whatsapp ON loyalty_customer_bills
CREATE INDEX idx_lcb_whatsapp ON public.loyalty_customer_bills USING btree (whatsapp_number);

-- INDEX: loyalty_customer_bills_bill_number_branch_unique ON loyalty_customer_bills
CREATE UNIQUE INDEX loyalty_customer_bills_bill_number_branch_unique ON public.loyalty_customer_bills USING btree (bill_number, erp_branch_id);

-- INDEX: loyalty_customer_bills_pkey ON loyalty_customer_bills
CREATE UNIQUE INDEX loyalty_customer_bills_pkey ON public.loyalty_customer_bills USING btree (id);

-- INDEX: loyalty_redemptions_coupon_code_key ON loyalty_redemptions
CREATE UNIQUE INDEX loyalty_redemptions_coupon_code_key ON public.loyalty_redemptions USING btree (coupon_code);

-- INDEX: loyalty_redemptions_pkey ON loyalty_redemptions
CREATE UNIQUE INDEX loyalty_redemptions_pkey ON public.loyalty_redemptions USING btree (id);

-- INDEX: loyalty_tiers_pkey ON loyalty_tiers
CREATE UNIQUE INDEX loyalty_tiers_pkey ON public.loyalty_tiers USING btree (id);

-- INDEX: idx_mobile_themes_is_default ON mobile_themes
CREATE INDEX idx_mobile_themes_is_default ON public.mobile_themes USING btree (is_default);

-- INDEX: mobile_themes_name_key ON mobile_themes
CREATE UNIQUE INDEX mobile_themes_name_key ON public.mobile_themes USING btree (name);

-- INDEX: mobile_themes_pkey ON mobile_themes
CREATE UNIQUE INDEX mobile_themes_pkey ON public.mobile_themes USING btree (id);

-- INDEX: idx_multi_shift_date_wise_dates ON multi_shift_date_wise
CREATE INDEX idx_multi_shift_date_wise_dates ON public.multi_shift_date_wise USING btree (date_from, date_to);

-- INDEX: idx_multi_shift_date_wise_employee_id ON multi_shift_date_wise
CREATE INDEX idx_multi_shift_date_wise_employee_id ON public.multi_shift_date_wise USING btree (employee_id);

-- INDEX: multi_shift_date_wise_pkey ON multi_shift_date_wise
CREATE UNIQUE INDEX multi_shift_date_wise_pkey ON public.multi_shift_date_wise USING btree (id);

-- INDEX: idx_multi_shift_regular_employee_id ON multi_shift_regular
CREATE INDEX idx_multi_shift_regular_employee_id ON public.multi_shift_regular USING btree (employee_id);

-- INDEX: multi_shift_regular_pkey ON multi_shift_regular
CREATE UNIQUE INDEX multi_shift_regular_pkey ON public.multi_shift_regular USING btree (id);

-- INDEX: idx_multi_shift_weekday_employee_id ON multi_shift_weekday
CREATE INDEX idx_multi_shift_weekday_employee_id ON public.multi_shift_weekday USING btree (employee_id);

-- INDEX: idx_multi_shift_weekday_weekday ON multi_shift_weekday
CREATE INDEX idx_multi_shift_weekday_weekday ON public.multi_shift_weekday USING btree (weekday);

-- INDEX: multi_shift_weekday_pkey ON multi_shift_weekday
CREATE UNIQUE INDEX multi_shift_weekday_pkey ON public.multi_shift_weekday USING btree (id);

-- INDEX: idx_mv_expiry_barcode ON mv_expiry_products
CREATE INDEX idx_mv_expiry_barcode ON public.mv_expiry_products USING btree (barcode);

-- INDEX: idx_mv_expiry_branch ON mv_expiry_products
CREATE INDEX idx_mv_expiry_branch ON public.mv_expiry_products USING btree (branch_id);

-- INDEX: idx_mv_expiry_days ON mv_expiry_products
CREATE INDEX idx_mv_expiry_days ON public.mv_expiry_products USING btree (days_left);

-- INDEX: idx_mv_expiry_hidden ON mv_expiry_products
CREATE INDEX idx_mv_expiry_hidden ON public.mv_expiry_products USING btree (expiry_hidden);

-- INDEX: idx_mv_expiry_unique ON mv_expiry_products
CREATE UNIQUE INDEX idx_mv_expiry_unique ON public.mv_expiry_products USING btree (barcode, branch_id, expiry_date);

-- INDEX: nationalities_pkey ON nationalities
CREATE UNIQUE INDEX nationalities_pkey ON public.nationalities USING btree (id);

-- INDEX: idx_near_expiry_reports_branch ON near_expiry_reports
CREATE INDEX idx_near_expiry_reports_branch ON public.near_expiry_reports USING btree (branch_id);

-- INDEX: idx_near_expiry_reports_created ON near_expiry_reports
CREATE INDEX idx_near_expiry_reports_created ON public.near_expiry_reports USING btree (created_at DESC);

-- INDEX: idx_near_expiry_reports_reporter ON near_expiry_reports
CREATE INDEX idx_near_expiry_reports_reporter ON public.near_expiry_reports USING btree (reporter_user_id);

-- INDEX: idx_near_expiry_reports_status ON near_expiry_reports
CREATE INDEX idx_near_expiry_reports_status ON public.near_expiry_reports USING btree (status);

-- INDEX: idx_near_expiry_reports_target ON near_expiry_reports
CREATE INDEX idx_near_expiry_reports_target ON public.near_expiry_reports USING btree (target_user_id);

-- INDEX: near_expiry_reports_pkey ON near_expiry_reports
CREATE UNIQUE INDEX near_expiry_reports_pkey ON public.near_expiry_reports USING btree (id);

-- INDEX: idx_non_approved_scheduler_approval_status ON non_approved_payment_scheduler
CREATE INDEX idx_non_approved_scheduler_approval_status ON public.non_approved_payment_scheduler USING btree (approval_status);

-- INDEX: idx_non_approved_scheduler_approver_id ON non_approved_payment_scheduler
CREATE INDEX idx_non_approved_scheduler_approver_id ON public.non_approved_payment_scheduler USING btree (approver_id);

-- INDEX: idx_non_approved_scheduler_branch_id ON non_approved_payment_scheduler
CREATE INDEX idx_non_approved_scheduler_branch_id ON public.non_approved_payment_scheduler USING btree (branch_id);

-- INDEX: idx_non_approved_scheduler_category_id ON non_approved_payment_scheduler
CREATE INDEX idx_non_approved_scheduler_category_id ON public.non_approved_payment_scheduler USING btree (expense_category_id);

-- INDEX: idx_non_approved_scheduler_co_user_id ON non_approved_payment_scheduler
CREATE INDEX idx_non_approved_scheduler_co_user_id ON public.non_approved_payment_scheduler USING btree (co_user_id) WHERE (co_user_id IS NOT NULL);

-- INDEX: idx_non_approved_scheduler_created_at ON non_approved_payment_scheduler
CREATE INDEX idx_non_approved_scheduler_created_at ON public.non_approved_payment_scheduler USING btree (created_at DESC);

-- INDEX: idx_non_approved_scheduler_created_by ON non_approved_payment_scheduler
CREATE INDEX idx_non_approved_scheduler_created_by ON public.non_approved_payment_scheduler USING btree (created_by);

-- INDEX: idx_non_approved_scheduler_expense_scheduler_id ON non_approved_payment_scheduler
CREATE INDEX idx_non_approved_scheduler_expense_scheduler_id ON public.non_approved_payment_scheduler USING btree (expense_scheduler_id) WHERE (expense_scheduler_id IS NOT NULL);

-- INDEX: idx_non_approved_scheduler_schedule_type ON non_approved_payment_scheduler
CREATE INDEX idx_non_approved_scheduler_schedule_type ON public.non_approved_payment_scheduler USING btree (schedule_type);

-- INDEX: non_approved_payment_scheduler_pkey ON non_approved_payment_scheduler
CREATE UNIQUE INDEX non_approved_payment_scheduler_pkey ON public.non_approved_payment_scheduler USING btree (id);

-- INDEX: idx_notification_attachments_notification_id ON notification_attachments
CREATE INDEX idx_notification_attachments_notification_id ON public.notification_attachments USING btree (notification_id);

-- INDEX: idx_notification_attachments_uploaded_by ON notification_attachments
CREATE INDEX idx_notification_attachments_uploaded_by ON public.notification_attachments USING btree (uploaded_by);

-- INDEX: notification_attachments_pkey ON notification_attachments
CREATE UNIQUE INDEX notification_attachments_pkey ON public.notification_attachments USING btree (id);

-- INDEX: idx_notification_read_states_notification_id ON notification_read_states
CREATE INDEX idx_notification_read_states_notification_id ON public.notification_read_states USING btree (notification_id);

-- INDEX: idx_notification_read_states_notification_user ON notification_read_states
CREATE INDEX idx_notification_read_states_notification_user ON public.notification_read_states USING btree (notification_id, user_id);

-- INDEX: idx_notification_read_states_user_id ON notification_read_states
CREATE INDEX idx_notification_read_states_user_id ON public.notification_read_states USING btree (user_id);

-- INDEX: notification_read_states_notification_id_user_id_key ON notification_read_states
CREATE UNIQUE INDEX notification_read_states_notification_id_user_id_key ON public.notification_read_states USING btree (notification_id, user_id);

-- INDEX: notification_read_states_pkey ON notification_read_states
CREATE UNIQUE INDEX notification_read_states_pkey ON public.notification_read_states USING btree (id);

-- INDEX: idx_notification_recipients_delivery_status ON notification_recipients
CREATE INDEX idx_notification_recipients_delivery_status ON public.notification_recipients USING btree (delivery_status) WHERE ((delivery_status)::text = ANY (ARRAY[('pending'::character varying)::text, ('failed'::character varying)::text]));

-- INDEX: notification_recipients_pkey ON notification_recipients
CREATE UNIQUE INDEX notification_recipients_pkey ON public.notification_recipients USING btree (id);

-- INDEX: unique_notification_recipient ON notification_recipients
CREATE UNIQUE INDEX unique_notification_recipient ON public.notification_recipients USING btree (notification_id, user_id);

-- INDEX: idx_notifications_created_at ON notifications
CREATE INDEX idx_notifications_created_at ON public.notifications USING btree (created_at DESC);

-- INDEX: notifications_pkey ON notifications
CREATE UNIQUE INDEX notifications_pkey ON public.notifications USING btree (id);

-- INDEX: idx_offer_bundles_offer_id ON offer_bundles
CREATE INDEX idx_offer_bundles_offer_id ON public.offer_bundles USING btree (offer_id);

-- INDEX: offer_bundles_pkey ON offer_bundles
CREATE UNIQUE INDEX offer_bundles_pkey ON public.offer_bundles USING btree (id);

-- INDEX: idx_offer_cart_tiers_amount_range ON offer_cart_tiers
CREATE INDEX idx_offer_cart_tiers_amount_range ON public.offer_cart_tiers USING btree (min_amount, max_amount);

-- INDEX: idx_offer_cart_tiers_offer_id ON offer_cart_tiers
CREATE INDEX idx_offer_cart_tiers_offer_id ON public.offer_cart_tiers USING btree (offer_id);

-- INDEX: offer_cart_tiers_offer_id_min_amount_key ON offer_cart_tiers
CREATE UNIQUE INDEX offer_cart_tiers_offer_id_min_amount_key ON public.offer_cart_tiers USING btree (offer_id, min_amount);

-- INDEX: offer_cart_tiers_offer_id_tier_number_key ON offer_cart_tiers
CREATE UNIQUE INDEX offer_cart_tiers_offer_id_tier_number_key ON public.offer_cart_tiers USING btree (offer_id, tier_number);

-- INDEX: offer_cart_tiers_pkey ON offer_cart_tiers
CREATE UNIQUE INDEX offer_cart_tiers_pkey ON public.offer_cart_tiers USING btree (id);

-- INDEX: offer_names_pkey ON offer_names
CREATE UNIQUE INDEX offer_names_pkey ON public.offer_names USING btree (id);

-- INDEX: idx_offer_products_active_lookup ON offer_products
CREATE INDEX idx_offer_products_active_lookup ON public.offer_products USING btree (offer_id, product_id);

-- INDEX: idx_offer_products_is_variation ON offer_products
CREATE INDEX idx_offer_products_is_variation ON public.offer_products USING btree (is_part_of_variation_group) WHERE (is_part_of_variation_group = true);

-- INDEX: idx_offer_products_offer_id ON offer_products
CREATE INDEX idx_offer_products_offer_id ON public.offer_products USING btree (offer_id);

-- INDEX: idx_offer_products_product_id ON offer_products
CREATE INDEX idx_offer_products_product_id ON public.offer_products USING btree (product_id);

-- INDEX: idx_offer_products_variation_group_id ON offer_products
CREATE INDEX idx_offer_products_variation_group_id ON public.offer_products USING btree (variation_group_id) WHERE (variation_group_id IS NOT NULL);

-- INDEX: idx_offer_products_variation_parent ON offer_products
CREATE INDEX idx_offer_products_variation_parent ON public.offer_products USING btree (variation_parent_barcode) WHERE (variation_parent_barcode IS NOT NULL);

-- INDEX: offer_products_pkey ON offer_products
CREATE UNIQUE INDEX offer_products_pkey ON public.offer_products USING btree (id);

-- INDEX: unique_offer_product ON offer_products
CREATE UNIQUE INDEX unique_offer_product ON public.offer_products USING btree (offer_id, product_id);

-- INDEX: idx_offer_usage_logs_customer_id ON offer_usage_logs
CREATE INDEX idx_offer_usage_logs_customer_id ON public.offer_usage_logs USING btree (customer_id);

-- INDEX: idx_offer_usage_logs_offer_id ON offer_usage_logs
CREATE INDEX idx_offer_usage_logs_offer_id ON public.offer_usage_logs USING btree (offer_id);

-- INDEX: idx_offer_usage_logs_order_id ON offer_usage_logs
CREATE INDEX idx_offer_usage_logs_order_id ON public.offer_usage_logs USING btree (order_id);

-- INDEX: idx_offer_usage_logs_order_offer ON offer_usage_logs
CREATE INDEX idx_offer_usage_logs_order_offer ON public.offer_usage_logs USING btree (order_id, offer_id);

-- INDEX: idx_offer_usage_logs_used_at ON offer_usage_logs
CREATE INDEX idx_offer_usage_logs_used_at ON public.offer_usage_logs USING btree (used_at DESC);

-- INDEX: offer_usage_logs_pkey ON offer_usage_logs
CREATE UNIQUE INDEX offer_usage_logs_pkey ON public.offer_usage_logs USING btree (id);

-- INDEX: idx_offers_branch_id ON offers
CREATE INDEX idx_offers_branch_id ON public.offers USING btree (branch_id);

-- INDEX: idx_offers_date_range ON offers
CREATE INDEX idx_offers_date_range ON public.offers USING btree (start_date, end_date);

-- INDEX: idx_offers_is_active ON offers
CREATE INDEX idx_offers_is_active ON public.offers USING btree (is_active);

-- INDEX: idx_offers_service_type ON offers
CREATE INDEX idx_offers_service_type ON public.offers USING btree (service_type);

-- INDEX: idx_offers_type ON offers
CREATE INDEX idx_offers_type ON public.offers USING btree (type);

-- INDEX: offers_pkey ON offers
CREATE UNIQUE INDEX offers_pkey ON public.offers USING btree (id);

-- INDEX: idx_official_holidays_date ON official_holidays
CREATE INDEX idx_official_holidays_date ON public.official_holidays USING btree (holiday_date);

-- INDEX: official_holidays_pkey ON official_holidays
CREATE UNIQUE INDEX official_holidays_pkey ON public.official_holidays USING btree (id);

-- INDEX: unique_official_holiday_date ON official_holidays
CREATE UNIQUE INDEX unique_official_holiday_date ON public.official_holidays USING btree (holiday_date);

-- INDEX: idx_order_audit_logs_action_type ON order_audit_logs
CREATE INDEX idx_order_audit_logs_action_type ON public.order_audit_logs USING btree (action_type);

-- INDEX: idx_order_audit_logs_assigned_user ON order_audit_logs
CREATE INDEX idx_order_audit_logs_assigned_user ON public.order_audit_logs USING btree (assigned_user_id);

-- INDEX: idx_order_audit_logs_created_at ON order_audit_logs
CREATE INDEX idx_order_audit_logs_created_at ON public.order_audit_logs USING btree (created_at DESC);

-- INDEX: idx_order_audit_logs_order_action ON order_audit_logs
CREATE INDEX idx_order_audit_logs_order_action ON public.order_audit_logs USING btree (order_id, action_type);

-- INDEX: idx_order_audit_logs_order_created ON order_audit_logs
CREATE INDEX idx_order_audit_logs_order_created ON public.order_audit_logs USING btree (order_id, created_at DESC);

-- INDEX: idx_order_audit_logs_order_id ON order_audit_logs
CREATE INDEX idx_order_audit_logs_order_id ON public.order_audit_logs USING btree (order_id);

-- INDEX: idx_order_audit_logs_performed_by ON order_audit_logs
CREATE INDEX idx_order_audit_logs_performed_by ON public.order_audit_logs USING btree (performed_by);

-- INDEX: order_audit_logs_pkey ON order_audit_logs
CREATE UNIQUE INDEX order_audit_logs_pkey ON public.order_audit_logs USING btree (id);

-- INDEX: idx_order_items_bundle_id ON order_items
CREATE INDEX idx_order_items_bundle_id ON public.order_items USING btree (bundle_id);

-- INDEX: idx_order_items_item_type ON order_items
CREATE INDEX idx_order_items_item_type ON public.order_items USING btree (item_type);

-- INDEX: idx_order_items_offer_id ON order_items
CREATE INDEX idx_order_items_offer_id ON public.order_items USING btree (offer_id);

-- INDEX: idx_order_items_order_bundle ON order_items
CREATE INDEX idx_order_items_order_bundle ON public.order_items USING btree (order_id, bundle_id);

-- INDEX: idx_order_items_order_id ON order_items
CREATE INDEX idx_order_items_order_id ON public.order_items USING btree (order_id);

-- INDEX: idx_order_items_order_product ON order_items
CREATE INDEX idx_order_items_order_product ON public.order_items USING btree (order_id, product_id);

-- INDEX: idx_order_items_product_id ON order_items
CREATE INDEX idx_order_items_product_id ON public.order_items USING btree (product_id);

-- INDEX: idx_order_items_unit_id ON order_items
CREATE INDEX idx_order_items_unit_id ON public.order_items USING btree (unit_id);

-- INDEX: order_items_pkey ON order_items
CREATE UNIQUE INDEX order_items_pkey ON public.order_items USING btree (id);

-- INDEX: idx_orders_branch_id ON orders
CREATE INDEX idx_orders_branch_id ON public.orders USING btree (branch_id);

-- INDEX: idx_orders_branch_status ON orders
CREATE INDEX idx_orders_branch_status ON public.orders USING btree (branch_id, order_status);

-- INDEX: idx_orders_created_at ON orders
CREATE INDEX idx_orders_created_at ON public.orders USING btree (created_at DESC);

-- INDEX: idx_orders_customer_id ON orders
CREATE INDEX idx_orders_customer_id ON public.orders USING btree (customer_id);

-- INDEX: idx_orders_customer_status ON orders
CREATE INDEX idx_orders_customer_status ON public.orders USING btree (customer_id, order_status);

-- INDEX: idx_orders_delivery_person_id ON orders
CREATE INDEX idx_orders_delivery_person_id ON public.orders USING btree (delivery_person_id);

-- INDEX: idx_orders_fulfillment_method ON orders
CREATE INDEX idx_orders_fulfillment_method ON public.orders USING btree (fulfillment_method);

-- INDEX: idx_orders_order_number ON orders
CREATE INDEX idx_orders_order_number ON public.orders USING btree (order_number);

-- INDEX: idx_orders_order_status ON orders
CREATE INDEX idx_orders_order_status ON public.orders USING btree (order_status);

-- INDEX: idx_orders_payment_status ON orders
CREATE INDEX idx_orders_payment_status ON public.orders USING btree (payment_status);

-- INDEX: idx_orders_picker_id ON orders
CREATE INDEX idx_orders_picker_id ON public.orders USING btree (picker_id);

-- INDEX: idx_orders_status_created ON orders
CREATE INDEX idx_orders_status_created ON public.orders USING btree (order_status, created_at DESC);

-- INDEX: orders_order_number_key ON orders
CREATE UNIQUE INDEX orders_order_number_key ON public.orders USING btree (order_number);

-- INDEX: orders_pkey ON orders
CREATE UNIQUE INDEX orders_pkey ON public.orders USING btree (id);

-- INDEX: overtime_registrations_employee_id_overtime_date_key ON overtime_registrations
CREATE UNIQUE INDEX overtime_registrations_employee_id_overtime_date_key ON public.overtime_registrations USING btree (employee_id, overtime_date);

-- INDEX: overtime_registrations_pkey ON overtime_registrations
CREATE UNIQUE INDEX overtime_registrations_pkey ON public.overtime_registrations USING btree (id);

-- INDEX: idx_pos_deduction_transfer_edits_box ON pos_deduction_transfer_edits
CREATE INDEX idx_pos_deduction_transfer_edits_box ON public.pos_deduction_transfer_edits USING btree (box_operation_id);

-- INDEX: pos_deduction_transfer_edits_pkey ON pos_deduction_transfer_edits
CREATE UNIQUE INDEX pos_deduction_transfer_edits_pkey ON public.pos_deduction_transfer_edits USING btree (id);

-- INDEX: idx_pos_deduction_transfers_applied ON pos_deduction_transfers
CREATE INDEX idx_pos_deduction_transfers_applied ON public.pos_deduction_transfers USING btree (applied);

-- INDEX: idx_pos_deduction_transfers_branch ON pos_deduction_transfers
CREATE INDEX idx_pos_deduction_transfers_branch ON public.pos_deduction_transfers USING btree (branch_id);

-- INDEX: idx_pos_deduction_transfers_cashier ON pos_deduction_transfers
CREATE INDEX idx_pos_deduction_transfers_cashier ON public.pos_deduction_transfers USING btree (cashier_user_id);

-- INDEX: idx_pos_deduction_transfers_date_closed ON pos_deduction_transfers
CREATE INDEX idx_pos_deduction_transfers_date_closed ON public.pos_deduction_transfers USING btree (date_closed_box);

-- INDEX: pos_deduction_transfers_pkey ON pos_deduction_transfers
CREATE UNIQUE INDEX pos_deduction_transfers_pkey ON public.pos_deduction_transfers USING btree (id, box_number, date_closed_box);

-- INDEX: idx_privilege_cards_branch_branch_id ON privilege_cards_branch
CREATE INDEX idx_privilege_cards_branch_branch_id ON public.privilege_cards_branch USING btree (branch_id);

-- INDEX: idx_privilege_cards_branch_card_number ON privilege_cards_branch
CREATE INDEX idx_privilege_cards_branch_card_number ON public.privilege_cards_branch USING btree (card_number);

-- INDEX: idx_privilege_cards_branch_composite ON privilege_cards_branch
CREATE INDEX idx_privilege_cards_branch_composite ON public.privilege_cards_branch USING btree (branch_id, card_number);

-- INDEX: privilege_cards_branch_pkey ON privilege_cards_branch
CREATE UNIQUE INDEX privilege_cards_branch_pkey ON public.privilege_cards_branch USING btree (id);

-- INDEX: privilege_cards_branch_privilege_card_id_branch_id_key ON privilege_cards_branch
CREATE UNIQUE INDEX privilege_cards_branch_privilege_card_id_branch_id_key ON public.privilege_cards_branch USING btree (privilege_card_id, branch_id);

-- INDEX: idx_privilege_cards_master_card_number ON privilege_cards_master
CREATE INDEX idx_privilege_cards_master_card_number ON public.privilege_cards_master USING btree (card_number);

-- INDEX: privilege_cards_master_card_number_key ON privilege_cards_master
CREATE UNIQUE INDEX privilege_cards_master_card_number_key ON public.privilege_cards_master USING btree (card_number);

-- INDEX: privilege_cards_master_pkey ON privilege_cards_master
CREATE UNIQUE INDEX privilege_cards_master_pkey ON public.privilege_cards_master USING btree (id);

-- INDEX: idx_processed_fingerprint_branch_id ON processed_fingerprint_transactions
CREATE INDEX idx_processed_fingerprint_branch_id ON public.processed_fingerprint_transactions USING btree (branch_id);

-- INDEX: idx_processed_fingerprint_center_id ON processed_fingerprint_transactions
CREATE INDEX idx_processed_fingerprint_center_id ON public.processed_fingerprint_transactions USING btree (center_id);

-- INDEX: idx_processed_fingerprint_employee_id ON processed_fingerprint_transactions
CREATE INDEX idx_processed_fingerprint_employee_id ON public.processed_fingerprint_transactions USING btree (employee_id);

-- INDEX: idx_processed_fingerprint_punch_date ON processed_fingerprint_transactions
CREATE INDEX idx_processed_fingerprint_punch_date ON public.processed_fingerprint_transactions USING btree (punch_date);

-- INDEX: processed_fingerprint_transactions_pkey ON processed_fingerprint_transactions
CREATE UNIQUE INDEX processed_fingerprint_transactions_pkey ON public.processed_fingerprint_transactions USING btree (id);

-- INDEX: idx_product_categories_display_order ON product_categories
CREATE INDEX idx_product_categories_display_order ON public.product_categories USING btree (display_order);

-- INDEX: idx_product_categories_is_active ON product_categories
CREATE INDEX idx_product_categories_is_active ON public.product_categories USING btree (is_active);

-- INDEX: product_categories_pkey ON product_categories
CREATE UNIQUE INDEX product_categories_pkey ON public.product_categories USING btree (id);

-- INDEX: idx_product_request_bt_created ON product_request_bt
CREATE INDEX idx_product_request_bt_created ON public.product_request_bt USING btree (created_at);

-- INDEX: idx_product_request_bt_from_branch ON product_request_bt
CREATE INDEX idx_product_request_bt_from_branch ON public.product_request_bt USING btree (from_branch_id);

-- INDEX: idx_product_request_bt_requester ON product_request_bt
CREATE INDEX idx_product_request_bt_requester ON public.product_request_bt USING btree (requester_user_id);

-- INDEX: idx_product_request_bt_status ON product_request_bt
CREATE INDEX idx_product_request_bt_status ON public.product_request_bt USING btree (status);

-- INDEX: idx_product_request_bt_target ON product_request_bt
CREATE INDEX idx_product_request_bt_target ON public.product_request_bt USING btree (target_user_id);

-- INDEX: idx_product_request_bt_to_branch ON product_request_bt
CREATE INDEX idx_product_request_bt_to_branch ON public.product_request_bt USING btree (to_branch_id);

-- INDEX: product_request_bt_pkey ON product_request_bt
CREATE UNIQUE INDEX product_request_bt_pkey ON public.product_request_bt USING btree (id);

-- INDEX: idx_product_request_po_branch ON product_request_po
CREATE INDEX idx_product_request_po_branch ON public.product_request_po USING btree (from_branch_id);

-- INDEX: idx_product_request_po_created ON product_request_po
CREATE INDEX idx_product_request_po_created ON public.product_request_po USING btree (created_at);

-- INDEX: idx_product_request_po_requester ON product_request_po
CREATE INDEX idx_product_request_po_requester ON public.product_request_po USING btree (requester_user_id);

-- INDEX: idx_product_request_po_status ON product_request_po
CREATE INDEX idx_product_request_po_status ON public.product_request_po USING btree (status);

-- INDEX: idx_product_request_po_target ON product_request_po
CREATE INDEX idx_product_request_po_target ON public.product_request_po USING btree (target_user_id);

-- INDEX: product_request_po_pkey ON product_request_po
CREATE UNIQUE INDEX product_request_po_pkey ON public.product_request_po USING btree (id);

-- INDEX: idx_product_request_st_branch ON product_request_st
CREATE INDEX idx_product_request_st_branch ON public.product_request_st USING btree (branch_id);

-- INDEX: idx_product_request_st_created ON product_request_st
CREATE INDEX idx_product_request_st_created ON public.product_request_st USING btree (created_at);

-- INDEX: idx_product_request_st_requester ON product_request_st
CREATE INDEX idx_product_request_st_requester ON public.product_request_st USING btree (requester_user_id);

-- INDEX: idx_product_request_st_status ON product_request_st
CREATE INDEX idx_product_request_st_status ON public.product_request_st USING btree (status);

-- INDEX: idx_product_request_st_target ON product_request_st
CREATE INDEX idx_product_request_st_target ON public.product_request_st USING btree (target_user_id);

-- INDEX: product_request_st_pkey ON product_request_st
CREATE UNIQUE INDEX product_request_st_pkey ON public.product_request_st USING btree (id);

-- INDEX: idx_product_units_is_active ON product_units
CREATE INDEX idx_product_units_is_active ON public.product_units USING btree (is_active);

-- INDEX: product_units_pkey ON product_units
CREATE UNIQUE INDEX product_units_pkey ON public.product_units USING btree (id);

-- INDEX: flyer_products_pkey1 ON products
CREATE UNIQUE INDEX flyer_products_pkey1 ON public.products USING btree (id);

-- INDEX: idx_products_barcode ON products
CREATE INDEX idx_products_barcode ON public.products USING btree (barcode);

-- INDEX: idx_products_category_id ON products
CREATE INDEX idx_products_category_id ON public.products USING btree (category_id);

-- INDEX: idx_products_created_at ON products
CREATE INDEX idx_products_created_at ON public.products USING btree (created_at);

-- INDEX: idx_products_is_active ON products
CREATE INDEX idx_products_is_active ON public.products USING btree (is_active);

-- INDEX: idx_products_is_customer_product ON products
CREATE INDEX idx_products_is_customer_product ON public.products USING btree (is_customer_product);

-- INDEX: idx_products_is_variation ON products
CREATE INDEX idx_products_is_variation ON public.products USING btree (is_variation);

-- INDEX: idx_products_parent_product_barcode ON products
CREATE INDEX idx_products_parent_product_barcode ON public.products USING btree (parent_product_barcode);

-- INDEX: idx_products_unit_id ON products
CREATE INDEX idx_products_unit_id ON public.products USING btree (unit_id);

-- INDEX: uq_products_barcode ON products
CREATE UNIQUE INDEX uq_products_barcode ON public.products USING btree (barcode);

-- INDEX: idx_issue_types_name ON purchase_voucher_issue_types
CREATE INDEX idx_issue_types_name ON public.purchase_voucher_issue_types USING btree (type_name);

-- INDEX: purchase_voucher_issue_types_pkey ON purchase_voucher_issue_types
CREATE UNIQUE INDEX purchase_voucher_issue_types_pkey ON public.purchase_voucher_issue_types USING btree (id);

-- INDEX: purchase_voucher_issue_types_type_name_key ON purchase_voucher_issue_types
CREATE UNIQUE INDEX purchase_voucher_issue_types_type_name_key ON public.purchase_voucher_issue_types USING btree (type_name);

-- INDEX: idx_purchase_voucher_items_pv_id ON purchase_voucher_items
CREATE INDEX idx_purchase_voucher_items_pv_id ON public.purchase_voucher_items USING btree (purchase_voucher_id);

-- INDEX: idx_purchase_voucher_items_status ON purchase_voucher_items
CREATE INDEX idx_purchase_voucher_items_status ON public.purchase_voucher_items USING btree (status);

-- INDEX: idx_pvi_approver_id ON purchase_voucher_items
CREATE INDEX idx_pvi_approver_id ON public.purchase_voucher_items USING btree (approver_id);

-- INDEX: idx_pvi_close_bill_number ON purchase_voucher_items
CREATE INDEX idx_pvi_close_bill_number ON public.purchase_voucher_items USING btree (close_bill_number);

-- INDEX: idx_pvi_created_at ON purchase_voucher_items
CREATE INDEX idx_pvi_created_at ON public.purchase_voucher_items USING btree (created_at);

-- INDEX: idx_pvi_issued_by ON purchase_voucher_items
CREATE INDEX idx_pvi_issued_by ON public.purchase_voucher_items USING btree (issued_by);

-- INDEX: idx_pvi_issued_to ON purchase_voucher_items
CREATE INDEX idx_pvi_issued_to ON public.purchase_voucher_items USING btree (issued_to);

-- INDEX: idx_pvi_pending_stock_location ON purchase_voucher_items
CREATE INDEX idx_pvi_pending_stock_location ON public.purchase_voucher_items USING btree (pending_stock_location);

-- INDEX: idx_pvi_pending_stock_person ON purchase_voucher_items
CREATE INDEX idx_pvi_pending_stock_person ON public.purchase_voucher_items USING btree (pending_stock_person);

-- INDEX: idx_pvi_purchase_voucher_id ON purchase_voucher_items
CREATE INDEX idx_pvi_purchase_voucher_id ON public.purchase_voucher_items USING btree (purchase_voucher_id);

-- INDEX: idx_pvi_status ON purchase_voucher_items
CREATE INDEX idx_pvi_status ON public.purchase_voucher_items USING btree (status);

-- INDEX: idx_pvi_stock_location ON purchase_voucher_items
CREATE INDEX idx_pvi_stock_location ON public.purchase_voucher_items USING btree (stock_location);

-- INDEX: idx_pvi_stock_person ON purchase_voucher_items
CREATE INDEX idx_pvi_stock_person ON public.purchase_voucher_items USING btree (stock_person);

-- INDEX: purchase_voucher_items_pkey ON purchase_voucher_items
CREATE UNIQUE INDEX purchase_voucher_items_pkey ON public.purchase_voucher_items USING btree (id);

-- INDEX: purchase_voucher_items_purchase_voucher_id_serial_number_key ON purchase_voucher_items
CREATE UNIQUE INDEX purchase_voucher_items_purchase_voucher_id_serial_number_key ON public.purchase_voucher_items USING btree (purchase_voucher_id, serial_number);

-- INDEX: idx_purchase_vouchers_created_at ON purchase_vouchers
CREATE INDEX idx_purchase_vouchers_created_at ON public.purchase_vouchers USING btree (created_at);

-- INDEX: idx_purchase_vouchers_status ON purchase_vouchers
CREATE INDEX idx_purchase_vouchers_status ON public.purchase_vouchers USING btree (status);

-- INDEX: purchase_vouchers_pkey ON purchase_vouchers
CREATE UNIQUE INDEX purchase_vouchers_pkey ON public.purchase_vouchers USING btree (id);

-- INDEX: idx_push_subscriptions_active ON push_subscriptions
CREATE INDEX idx_push_subscriptions_active ON public.push_subscriptions USING btree (user_id, is_active) WHERE (is_active = true);

-- INDEX: idx_push_subscriptions_customer_active ON push_subscriptions
CREATE INDEX idx_push_subscriptions_customer_active ON public.push_subscriptions USING btree (customer_id, is_active) WHERE ((is_active = true) AND (customer_id IS NOT NULL));

-- INDEX: idx_push_subscriptions_customer_id ON push_subscriptions
CREATE INDEX idx_push_subscriptions_customer_id ON public.push_subscriptions USING btree (customer_id) WHERE (customer_id IS NOT NULL);

-- INDEX: idx_push_subscriptions_user_id ON push_subscriptions
CREATE INDEX idx_push_subscriptions_user_id ON public.push_subscriptions USING btree (user_id);

-- INDEX: push_subscriptions_endpoint_key ON push_subscriptions
CREATE UNIQUE INDEX push_subscriptions_endpoint_key ON public.push_subscriptions USING btree (endpoint);

-- INDEX: push_subscriptions_pkey ON push_subscriptions
CREATE UNIQUE INDEX push_subscriptions_pkey ON public.push_subscriptions USING btree (id);

-- INDEX: idx_quick_task_assignments_assignment_id_status ON quick_task_assignments
CREATE INDEX idx_quick_task_assignments_assignment_id_status ON public.quick_task_assignments USING btree (quick_task_id, status);

-- INDEX: idx_quick_task_assignments_created_at ON quick_task_assignments
CREATE INDEX idx_quick_task_assignments_created_at ON public.quick_task_assignments USING btree (created_at);

-- INDEX: idx_quick_task_assignments_require_erp_reference ON quick_task_assignments
CREATE INDEX idx_quick_task_assignments_require_erp_reference ON public.quick_task_assignments USING btree (require_erp_reference) WHERE (require_erp_reference = true);

-- INDEX: idx_quick_task_assignments_require_photo_upload ON quick_task_assignments
CREATE INDEX idx_quick_task_assignments_require_photo_upload ON public.quick_task_assignments USING btree (require_photo_upload) WHERE (require_photo_upload = true);

-- INDEX: idx_quick_task_assignments_require_task_finished ON quick_task_assignments
CREATE INDEX idx_quick_task_assignments_require_task_finished ON public.quick_task_assignments USING btree (require_task_finished);

-- INDEX: idx_quick_task_assignments_status ON quick_task_assignments
CREATE INDEX idx_quick_task_assignments_status ON public.quick_task_assignments USING btree (status);

-- INDEX: idx_quick_task_assignments_task ON quick_task_assignments
CREATE INDEX idx_quick_task_assignments_task ON public.quick_task_assignments USING btree (quick_task_id);

-- INDEX: idx_quick_task_assignments_user ON quick_task_assignments
CREATE INDEX idx_quick_task_assignments_user ON public.quick_task_assignments USING btree (assigned_to_user_id);

-- INDEX: quick_task_assignments_pkey ON quick_task_assignments
CREATE UNIQUE INDEX quick_task_assignments_pkey ON public.quick_task_assignments USING btree (id);

-- INDEX: quick_task_assignments_quick_task_id_assigned_to_user_id_key ON quick_task_assignments
CREATE UNIQUE INDEX quick_task_assignments_quick_task_id_assigned_to_user_id_key ON public.quick_task_assignments USING btree (quick_task_id, assigned_to_user_id);

-- INDEX: idx_quick_task_comments_created_by ON quick_task_comments
CREATE INDEX idx_quick_task_comments_created_by ON public.quick_task_comments USING btree (created_by);

-- INDEX: idx_quick_task_comments_task ON quick_task_comments
CREATE INDEX idx_quick_task_comments_task ON public.quick_task_comments USING btree (quick_task_id);

-- INDEX: quick_task_comments_pkey ON quick_task_comments
CREATE UNIQUE INDEX quick_task_comments_pkey ON public.quick_task_comments USING btree (id);

-- INDEX: idx_quick_task_completions_assignment ON quick_task_completions
CREATE INDEX idx_quick_task_completions_assignment ON public.quick_task_completions USING btree (assignment_id);

-- INDEX: idx_quick_task_completions_completed_by ON quick_task_completions
CREATE INDEX idx_quick_task_completions_completed_by ON public.quick_task_completions USING btree (completed_by_user_id);

-- INDEX: idx_quick_task_completions_created_at ON quick_task_completions
CREATE INDEX idx_quick_task_completions_created_at ON public.quick_task_completions USING btree (created_at DESC);

-- INDEX: idx_quick_task_completions_status ON quick_task_completions
CREATE INDEX idx_quick_task_completions_status ON public.quick_task_completions USING btree (completion_status);

-- INDEX: idx_quick_task_completions_task ON quick_task_completions
CREATE INDEX idx_quick_task_completions_task ON public.quick_task_completions USING btree (quick_task_id);

-- INDEX: idx_quick_task_completions_verified_by ON quick_task_completions
CREATE INDEX idx_quick_task_completions_verified_by ON public.quick_task_completions USING btree (verified_by_user_id) WHERE (verified_by_user_id IS NOT NULL);

-- INDEX: quick_task_completions_assignment_unique ON quick_task_completions
CREATE UNIQUE INDEX quick_task_completions_assignment_unique ON public.quick_task_completions USING btree (assignment_id);

-- INDEX: quick_task_completions_pkey ON quick_task_completions
CREATE UNIQUE INDEX quick_task_completions_pkey ON public.quick_task_completions USING btree (id);

-- INDEX: idx_quick_task_files_task ON quick_task_files
CREATE INDEX idx_quick_task_files_task ON public.quick_task_files USING btree (quick_task_id);

-- INDEX: idx_quick_task_files_uploaded_by ON quick_task_files
CREATE INDEX idx_quick_task_files_uploaded_by ON public.quick_task_files USING btree (uploaded_by);

-- INDEX: quick_task_files_pkey ON quick_task_files
CREATE UNIQUE INDEX quick_task_files_pkey ON public.quick_task_files USING btree (id);

-- INDEX: idx_quick_task_user_preferences_branch ON quick_task_user_preferences
CREATE INDEX idx_quick_task_user_preferences_branch ON public.quick_task_user_preferences USING btree (default_branch_id);

-- INDEX: idx_quick_task_user_preferences_user ON quick_task_user_preferences
CREATE INDEX idx_quick_task_user_preferences_user ON public.quick_task_user_preferences USING btree (user_id);

-- INDEX: quick_task_user_preferences_pkey ON quick_task_user_preferences
CREATE UNIQUE INDEX quick_task_user_preferences_pkey ON public.quick_task_user_preferences USING btree (id);

-- INDEX: quick_task_user_preferences_user_id_key ON quick_task_user_preferences
CREATE UNIQUE INDEX quick_task_user_preferences_user_id_key ON public.quick_task_user_preferences USING btree (user_id);

-- INDEX: idx_quick_tasks_assigned_by ON quick_tasks
CREATE INDEX idx_quick_tasks_assigned_by ON public.quick_tasks USING btree (assigned_by);

-- INDEX: idx_quick_tasks_branch ON quick_tasks
CREATE INDEX idx_quick_tasks_branch ON public.quick_tasks USING btree (assigned_to_branch_id);

-- INDEX: idx_quick_tasks_created_at ON quick_tasks
CREATE INDEX idx_quick_tasks_created_at ON public.quick_tasks USING btree (created_at);

-- INDEX: idx_quick_tasks_deadline ON quick_tasks
CREATE INDEX idx_quick_tasks_deadline ON public.quick_tasks USING btree (deadline_datetime);

-- INDEX: idx_quick_tasks_incident_id ON quick_tasks
CREATE INDEX idx_quick_tasks_incident_id ON public.quick_tasks USING btree (incident_id);

-- INDEX: idx_quick_tasks_issue_type ON quick_tasks
CREATE INDEX idx_quick_tasks_issue_type ON public.quick_tasks USING btree (issue_type);

-- INDEX: idx_quick_tasks_order_id ON quick_tasks
CREATE INDEX idx_quick_tasks_order_id ON public.quick_tasks USING btree (order_id);

-- INDEX: idx_quick_tasks_priority ON quick_tasks
CREATE INDEX idx_quick_tasks_priority ON public.quick_tasks USING btree (priority);

-- INDEX: idx_quick_tasks_product_request_id ON quick_tasks
CREATE INDEX idx_quick_tasks_product_request_id ON public.quick_tasks USING btree (product_request_id);

-- INDEX: idx_quick_tasks_product_request_type ON quick_tasks
CREATE INDEX idx_quick_tasks_product_request_type ON public.quick_tasks USING btree (product_request_type);

-- INDEX: idx_quick_tasks_require_erp_reference ON quick_tasks
CREATE INDEX idx_quick_tasks_require_erp_reference ON public.quick_tasks USING btree (require_erp_reference) WHERE (require_erp_reference = true);

-- INDEX: idx_quick_tasks_require_photo_upload ON quick_tasks
CREATE INDEX idx_quick_tasks_require_photo_upload ON public.quick_tasks USING btree (require_photo_upload) WHERE (require_photo_upload = true);

-- INDEX: idx_quick_tasks_status ON quick_tasks
CREATE INDEX idx_quick_tasks_status ON public.quick_tasks USING btree (status);

-- INDEX: quick_tasks_pkey ON quick_tasks
CREATE UNIQUE INDEX quick_tasks_pkey ON public.quick_tasks USING btree (id);

-- INDEX: idx_receiving_records_accountant_user_id ON receiving_records
CREATE INDEX idx_receiving_records_accountant_user_id ON public.receiving_records USING btree (accountant_user_id);

-- INDEX: idx_receiving_records_bank_name ON receiving_records
CREATE INDEX idx_receiving_records_bank_name ON public.receiving_records USING btree (bank_name);

-- INDEX: idx_receiving_records_bill_amount ON receiving_records
CREATE INDEX idx_receiving_records_bill_amount ON public.receiving_records USING btree (bill_amount);

-- INDEX: idx_receiving_records_bill_date ON receiving_records
CREATE INDEX idx_receiving_records_bill_date ON public.receiving_records USING btree (bill_date);

-- INDEX: idx_receiving_records_bill_number ON receiving_records
CREATE INDEX idx_receiving_records_bill_number ON public.receiving_records USING btree (bill_number);

-- INDEX: idx_receiving_records_bill_vat_number ON receiving_records
CREATE INDEX idx_receiving_records_bill_vat_number ON public.receiving_records USING btree (bill_vat_number);

-- INDEX: idx_receiving_records_branch_id ON receiving_records
CREATE INDEX idx_receiving_records_branch_id ON public.receiving_records USING btree (branch_id);

-- INDEX: idx_receiving_records_branch_manager_user_id ON receiving_records
CREATE INDEX idx_receiving_records_branch_manager_user_id ON public.receiving_records USING btree (branch_manager_user_id);

-- INDEX: idx_receiving_records_created_at ON receiving_records
CREATE INDEX idx_receiving_records_created_at ON public.receiving_records USING btree (created_at);

-- INDEX: idx_receiving_records_credit_period ON receiving_records
CREATE INDEX idx_receiving_records_credit_period ON public.receiving_records USING btree (credit_period);

-- INDEX: idx_receiving_records_damage_erp_document_number ON receiving_records
CREATE INDEX idx_receiving_records_damage_erp_document_number ON public.receiving_records USING btree (damage_erp_document_number);

-- INDEX: idx_receiving_records_damage_vendor_document_number ON receiving_records
CREATE INDEX idx_receiving_records_damage_vendor_document_number ON public.receiving_records USING btree (damage_vendor_document_number);

-- INDEX: idx_receiving_records_due_date ON receiving_records
CREATE INDEX idx_receiving_records_due_date ON public.receiving_records USING btree (due_date);

-- INDEX: idx_receiving_records_erp_purchase_invoice_reference ON receiving_records
CREATE INDEX idx_receiving_records_erp_purchase_invoice_reference ON public.receiving_records USING btree (erp_purchase_invoice_reference);

-- INDEX: idx_receiving_records_erp_purchase_invoice_uploaded ON receiving_records
CREATE INDEX idx_receiving_records_erp_purchase_invoice_uploaded ON public.receiving_records USING btree (erp_purchase_invoice_uploaded);

-- INDEX: idx_receiving_records_expired_erp_document_number ON receiving_records
CREATE INDEX idx_receiving_records_expired_erp_document_number ON public.receiving_records USING btree (expired_erp_document_number);

-- INDEX: idx_receiving_records_expired_vendor_document_number ON receiving_records
CREATE INDEX idx_receiving_records_expired_vendor_document_number ON public.receiving_records USING btree (expired_vendor_document_number);

-- INDEX: idx_receiving_records_final_bill_amount ON receiving_records
CREATE INDEX idx_receiving_records_final_bill_amount ON public.receiving_records USING btree (final_bill_amount);

-- INDEX: idx_receiving_records_iban ON receiving_records
CREATE INDEX idx_receiving_records_iban ON public.receiving_records USING btree (iban);

-- INDEX: idx_receiving_records_inventory_manager_user_id ON receiving_records
CREATE INDEX idx_receiving_records_inventory_manager_user_id ON public.receiving_records USING btree (inventory_manager_user_id);

-- INDEX: idx_receiving_records_near_expiry_erp_document_number ON receiving_records
CREATE INDEX idx_receiving_records_near_expiry_erp_document_number ON public.receiving_records USING btree (near_expiry_erp_document_number);

-- INDEX: idx_receiving_records_near_expiry_vendor_document_number ON receiving_records
CREATE INDEX idx_receiving_records_near_expiry_vendor_document_number ON public.receiving_records USING btree (near_expiry_vendor_document_number);

-- INDEX: idx_receiving_records_night_supervisor_user_ids ON receiving_records
CREATE INDEX idx_receiving_records_night_supervisor_user_ids ON public.receiving_records USING gin (night_supervisor_user_ids);

-- INDEX: idx_receiving_records_original_bill_uploaded ON receiving_records
CREATE INDEX idx_receiving_records_original_bill_uploaded ON public.receiving_records USING btree (original_bill_uploaded);

-- INDEX: idx_receiving_records_original_bill_url ON receiving_records
CREATE INDEX idx_receiving_records_original_bill_url ON public.receiving_records USING btree (original_bill_url);

-- INDEX: idx_receiving_records_over_stock_erp_document_number ON receiving_records
CREATE INDEX idx_receiving_records_over_stock_erp_document_number ON public.receiving_records USING btree (over_stock_erp_document_number);

-- INDEX: idx_receiving_records_over_stock_vendor_document_number ON receiving_records
CREATE INDEX idx_receiving_records_over_stock_vendor_document_number ON public.receiving_records USING btree (over_stock_vendor_document_number);

-- INDEX: idx_receiving_records_payment_method ON receiving_records
CREATE INDEX idx_receiving_records_payment_method ON public.receiving_records USING btree (payment_method);

-- INDEX: idx_receiving_records_pr_excel_file_uploaded ON receiving_records
CREATE INDEX idx_receiving_records_pr_excel_file_uploaded ON public.receiving_records USING btree (pr_excel_file_uploaded);

-- INDEX: idx_receiving_records_pr_excel_file_url ON receiving_records
CREATE INDEX idx_receiving_records_pr_excel_file_url ON public.receiving_records USING btree (pr_excel_file_url) WHERE (pr_excel_file_url IS NOT NULL);

-- INDEX: idx_receiving_records_purchasing_manager_user_id ON receiving_records
CREATE INDEX idx_receiving_records_purchasing_manager_user_id ON public.receiving_records USING btree (purchasing_manager_user_id);

-- INDEX: idx_receiving_records_shelf_stocker_user_ids ON receiving_records
CREATE INDEX idx_receiving_records_shelf_stocker_user_ids ON public.receiving_records USING gin (shelf_stocker_user_ids);

-- INDEX: idx_receiving_records_total_return_amount ON receiving_records
CREATE INDEX idx_receiving_records_total_return_amount ON public.receiving_records USING btree (total_return_amount);

-- INDEX: idx_receiving_records_updated_at ON receiving_records
CREATE INDEX idx_receiving_records_updated_at ON public.receiving_records USING btree (updated_at DESC);

-- INDEX: idx_receiving_records_user_id ON receiving_records
CREATE INDEX idx_receiving_records_user_id ON public.receiving_records USING btree (user_id);

-- INDEX: idx_receiving_records_vat_numbers_match ON receiving_records
CREATE INDEX idx_receiving_records_vat_numbers_match ON public.receiving_records USING btree (vat_numbers_match);

-- INDEX: idx_receiving_records_vendor_id ON receiving_records
CREATE INDEX idx_receiving_records_vendor_id ON public.receiving_records USING btree (vendor_id);

-- INDEX: idx_receiving_records_vendor_vat_number ON receiving_records
CREATE INDEX idx_receiving_records_vendor_vat_number ON public.receiving_records USING btree (vendor_vat_number);

-- INDEX: idx_receiving_records_warehouse_handler_user_ids ON receiving_records
CREATE INDEX idx_receiving_records_warehouse_handler_user_ids ON public.receiving_records USING gin (warehouse_handler_user_ids);

-- INDEX: receiving_records_pkey ON receiving_records
CREATE UNIQUE INDEX receiving_records_pkey ON public.receiving_records USING btree (id);

-- INDEX: idx_receiving_task_templates_priority ON receiving_task_templates
CREATE INDEX idx_receiving_task_templates_priority ON public.receiving_task_templates USING btree (priority);

-- INDEX: idx_receiving_task_templates_role_type ON receiving_task_templates
CREATE INDEX idx_receiving_task_templates_role_type ON public.receiving_task_templates USING btree (role_type);

-- INDEX: receiving_task_templates_pkey ON receiving_task_templates
CREATE UNIQUE INDEX receiving_task_templates_pkey ON public.receiving_task_templates USING btree (id);

-- INDEX: receiving_task_templates_role_type_unique ON receiving_task_templates
CREATE UNIQUE INDEX receiving_task_templates_role_type_unique ON public.receiving_task_templates USING btree (role_type);

-- INDEX: idx_receiving_tasks_assigned_user_id ON receiving_tasks
CREATE INDEX idx_receiving_tasks_assigned_user_id ON public.receiving_tasks USING btree (assigned_user_id);

-- INDEX: idx_receiving_tasks_completion_photo_url ON receiving_tasks
CREATE INDEX idx_receiving_tasks_completion_photo_url ON public.receiving_tasks USING btree (completion_photo_url) WHERE (completion_photo_url IS NOT NULL);

-- INDEX: idx_receiving_tasks_created_at ON receiving_tasks
CREATE INDEX idx_receiving_tasks_created_at ON public.receiving_tasks USING btree (created_at DESC);

-- INDEX: idx_receiving_tasks_receiving_record_id ON receiving_tasks
CREATE INDEX idx_receiving_tasks_receiving_record_id ON public.receiving_tasks USING btree (receiving_record_id);

-- INDEX: idx_receiving_tasks_record_role ON receiving_tasks
CREATE INDEX idx_receiving_tasks_record_role ON public.receiving_tasks USING btree (receiving_record_id, role_type);

-- INDEX: idx_receiving_tasks_role_type ON receiving_tasks
CREATE INDEX idx_receiving_tasks_role_type ON public.receiving_tasks USING btree (role_type);

-- INDEX: idx_receiving_tasks_status_role ON receiving_tasks
CREATE INDEX idx_receiving_tasks_status_role ON public.receiving_tasks USING btree (task_status, role_type);

-- INDEX: idx_receiving_tasks_task_completed ON receiving_tasks
CREATE INDEX idx_receiving_tasks_task_completed ON public.receiving_tasks USING btree (task_completed);

-- INDEX: idx_receiving_tasks_task_status ON receiving_tasks
CREATE INDEX idx_receiving_tasks_task_status ON public.receiving_tasks USING btree (task_status);

-- INDEX: idx_receiving_tasks_template_id ON receiving_tasks
CREATE INDEX idx_receiving_tasks_template_id ON public.receiving_tasks USING btree (template_id);

-- INDEX: idx_receiving_tasks_user_role ON receiving_tasks
CREATE INDEX idx_receiving_tasks_user_role ON public.receiving_tasks USING btree (assigned_user_id, role_type);

-- INDEX: idx_receiving_tasks_user_status ON receiving_tasks
CREATE INDEX idx_receiving_tasks_user_status ON public.receiving_tasks USING btree (assigned_user_id, task_status);

-- INDEX: receiving_tasks_pkey ON receiving_tasks
CREATE UNIQUE INDEX receiving_tasks_pkey ON public.receiving_tasks USING btree (id);

-- INDEX: idx_receiving_user_defaults_branch_id ON receiving_user_defaults
CREATE INDEX idx_receiving_user_defaults_branch_id ON public.receiving_user_defaults USING btree (default_branch_id);

-- INDEX: idx_receiving_user_defaults_user_id ON receiving_user_defaults
CREATE INDEX idx_receiving_user_defaults_user_id ON public.receiving_user_defaults USING btree (user_id);

-- INDEX: receiving_user_defaults_pkey ON receiving_user_defaults
CREATE UNIQUE INDEX receiving_user_defaults_pkey ON public.receiving_user_defaults USING btree (id);

-- INDEX: receiving_user_defaults_user_id_key ON receiving_user_defaults
CREATE UNIQUE INDEX receiving_user_defaults_user_id_key ON public.receiving_user_defaults USING btree (user_id);

-- INDEX: idx_recurring_schedules_active ON recurring_assignment_schedules
CREATE INDEX idx_recurring_schedules_active ON public.recurring_assignment_schedules USING btree (is_active, repeat_type);

-- INDEX: idx_recurring_schedules_assignment_id ON recurring_assignment_schedules
CREATE INDEX idx_recurring_schedules_assignment_id ON public.recurring_assignment_schedules USING btree (assignment_id);

-- INDEX: idx_recurring_schedules_next_execution ON recurring_assignment_schedules
CREATE INDEX idx_recurring_schedules_next_execution ON public.recurring_assignment_schedules USING btree (next_execution_at, is_active) WHERE (is_active = true);

-- INDEX: recurring_assignment_schedules_pkey ON recurring_assignment_schedules
CREATE UNIQUE INDEX recurring_assignment_schedules_pkey ON public.recurring_assignment_schedules USING btree (id);

-- INDEX: recurring_schedule_check_log_check_date_key ON recurring_schedule_check_log
CREATE UNIQUE INDEX recurring_schedule_check_log_check_date_key ON public.recurring_schedule_check_log USING btree (check_date);

-- INDEX: recurring_schedule_check_log_pkey ON recurring_schedule_check_log
CREATE UNIQUE INDEX recurring_schedule_check_log_pkey ON public.recurring_schedule_check_log USING btree (id);

-- INDEX: idx_regular_shift_created_at ON regular_shift
CREATE INDEX idx_regular_shift_created_at ON public.regular_shift USING btree (created_at);

-- INDEX: idx_regular_shift_updated_at ON regular_shift
CREATE INDEX idx_regular_shift_updated_at ON public.regular_shift USING btree (updated_at);

-- INDEX: regular_shift_pkey ON regular_shift
CREATE UNIQUE INDEX regular_shift_pkey ON public.regular_shift USING btree (id);

-- INDEX: idx_requesters_name ON requesters
CREATE INDEX idx_requesters_name ON public.requesters USING btree (requester_name);

-- INDEX: idx_requesters_requester_id ON requesters
CREATE INDEX idx_requesters_requester_id ON public.requesters USING btree (requester_id);

-- INDEX: requesters_pkey ON requesters
CREATE UNIQUE INDEX requesters_pkey ON public.requesters USING btree (id);

-- INDEX: requesters_requester_id_key ON requesters
CREATE UNIQUE INDEX requesters_requester_id_key ON public.requesters USING btree (requester_id);

-- INDEX: idx_ssl_action_type ON salary_statement_logs
CREATE INDEX idx_ssl_action_type ON public.salary_statement_logs USING btree (action_type);

-- INDEX: idx_ssl_created_at ON salary_statement_logs
CREATE INDEX idx_ssl_created_at ON public.salary_statement_logs USING btree (created_at DESC);

-- INDEX: idx_ssl_employee_id ON salary_statement_logs
CREATE INDEX idx_ssl_employee_id ON public.salary_statement_logs USING btree (employee_id);

-- INDEX: idx_ssl_statement_id ON salary_statement_logs
CREATE INDEX idx_ssl_statement_id ON public.salary_statement_logs USING btree (statement_id);

-- INDEX: idx_ssl_user_id ON salary_statement_logs
CREATE INDEX idx_ssl_user_id ON public.salary_statement_logs USING btree (user_id);

-- INDEX: salary_statement_logs_pkey ON salary_statement_logs
CREATE UNIQUE INDEX salary_statement_logs_pkey ON public.salary_statement_logs USING btree (id);

-- INDEX: security_code_scroll_texts_pkey ON security_code_scroll_texts
CREATE UNIQUE INDEX security_code_scroll_texts_pkey ON public.security_code_scroll_texts USING btree (id);

-- INDEX: settlement_rules_is_active_idx ON settlement_rules
CREATE INDEX settlement_rules_is_active_idx ON public.settlement_rules USING btree (is_active);

-- INDEX: settlement_rules_pkey ON settlement_rules
CREATE UNIQUE INDEX settlement_rules_pkey ON public.settlement_rules USING btree (id);

-- INDEX: settlement_rules_rule_type_idx ON settlement_rules
CREATE INDEX settlement_rules_rule_type_idx ON public.settlement_rules USING btree (rule_type);

-- INDEX: idx_shelf_paper_fonts_created_by ON shelf_paper_fonts
CREATE INDEX idx_shelf_paper_fonts_created_by ON public.shelf_paper_fonts USING btree (created_by);

-- INDEX: idx_shelf_paper_fonts_name ON shelf_paper_fonts
CREATE INDEX idx_shelf_paper_fonts_name ON public.shelf_paper_fonts USING btree (name);

-- INDEX: shelf_paper_fonts_pkey ON shelf_paper_fonts
CREATE UNIQUE INDEX shelf_paper_fonts_pkey ON public.shelf_paper_fonts USING btree (id);

-- INDEX: idx_shelf_paper_templates_created_at ON shelf_paper_templates
CREATE INDEX idx_shelf_paper_templates_created_at ON public.shelf_paper_templates USING btree (created_at DESC);

-- INDEX: idx_shelf_paper_templates_created_by ON shelf_paper_templates
CREATE INDEX idx_shelf_paper_templates_created_by ON public.shelf_paper_templates USING btree (created_by);

-- INDEX: idx_shelf_paper_templates_is_active ON shelf_paper_templates
CREATE INDEX idx_shelf_paper_templates_is_active ON public.shelf_paper_templates USING btree (is_active);

-- INDEX: shelf_paper_templates_pkey ON shelf_paper_templates
CREATE UNIQUE INDEX shelf_paper_templates_pkey ON public.shelf_paper_templates USING btree (id);

-- INDEX: sidebar_animations_active_unique ON sidebar_animations
CREATE UNIQUE INDEX sidebar_animations_active_unique ON public.sidebar_animations USING btree (is_active) WHERE (is_active = true);

-- INDEX: sidebar_animations_pkey ON sidebar_animations
CREATE UNIQUE INDEX sidebar_animations_pkey ON public.sidebar_animations USING btree (id);

-- INDEX: idx_sidebar_buttons_active ON sidebar_buttons
CREATE INDEX idx_sidebar_buttons_active ON public.sidebar_buttons USING btree (is_active);

-- INDEX: idx_sidebar_buttons_main ON sidebar_buttons
CREATE INDEX idx_sidebar_buttons_main ON public.sidebar_buttons USING btree (main_section_id);

-- INDEX: idx_sidebar_buttons_sub ON sidebar_buttons
CREATE INDEX idx_sidebar_buttons_sub ON public.sidebar_buttons USING btree (subsection_id);

-- INDEX: sidebar_buttons_main_section_id_subsection_id_button_code_key ON sidebar_buttons
CREATE UNIQUE INDEX sidebar_buttons_main_section_id_subsection_id_button_code_key ON public.sidebar_buttons USING btree (main_section_id, subsection_id, button_code);

-- INDEX: sidebar_buttons_pkey ON sidebar_buttons
CREATE UNIQUE INDEX sidebar_buttons_pkey ON public.sidebar_buttons USING btree (id);

-- INDEX: idx_social_links_branch_id ON social_links
CREATE INDEX idx_social_links_branch_id ON public.social_links USING btree (branch_id);

-- INDEX: social_links_branch_id_key ON social_links
CREATE UNIQUE INDEX social_links_branch_id_key ON public.social_links USING btree (branch_id);

-- INDEX: social_links_pkey ON social_links
CREATE UNIQUE INDEX social_links_pkey ON public.social_links USING btree (id);

-- INDEX: idx_special_shift_date_wise_date ON special_shift_date_wise
CREATE INDEX idx_special_shift_date_wise_date ON public.special_shift_date_wise USING btree (shift_date);

-- INDEX: idx_special_shift_date_wise_employee_id ON special_shift_date_wise
CREATE INDEX idx_special_shift_date_wise_employee_id ON public.special_shift_date_wise USING btree (employee_id);

-- INDEX: special_shift_date_wise_pkey ON special_shift_date_wise
CREATE UNIQUE INDEX special_shift_date_wise_pkey ON public.special_shift_date_wise USING btree (id);

-- INDEX: unique_employee_date ON special_shift_date_wise
CREATE UNIQUE INDEX unique_employee_date ON public.special_shift_date_wise USING btree (employee_id, shift_date);

-- INDEX: idx_special_shift_weekday_created_at ON special_shift_weekday
CREATE INDEX idx_special_shift_weekday_created_at ON public.special_shift_weekday USING btree (created_at);

-- INDEX: idx_special_shift_weekday_employee_id ON special_shift_weekday
CREATE INDEX idx_special_shift_weekday_employee_id ON public.special_shift_weekday USING btree (employee_id);

-- INDEX: idx_special_shift_weekday_weekday ON special_shift_weekday
CREATE INDEX idx_special_shift_weekday_weekday ON public.special_shift_weekday USING btree (weekday);

-- INDEX: special_shift_weekday_employee_id_weekday_key ON special_shift_weekday
CREATE UNIQUE INDEX special_shift_weekday_employee_id_weekday_key ON public.special_shift_weekday USING btree (employee_id, weekday);

-- INDEX: special_shift_weekday_pkey ON special_shift_weekday
CREATE UNIQUE INDEX special_shift_weekday_pkey ON public.special_shift_weekday USING btree (id);

-- INDEX: idx_surprise_box_plays_bill_number ON surprise_box_plays
CREATE INDEX idx_surprise_box_plays_bill_number ON public.surprise_box_plays USING btree (bill_number);

-- INDEX: idx_surprise_box_plays_created_at ON surprise_box_plays
CREATE INDEX idx_surprise_box_plays_created_at ON public.surprise_box_plays USING btree (created_at);

-- INDEX: idx_surprise_box_plays_voucher_code ON surprise_box_plays
CREATE INDEX idx_surprise_box_plays_voucher_code ON public.surprise_box_plays USING btree (voucher_code);

-- INDEX: surprise_box_plays_pkey ON surprise_box_plays
CREATE UNIQUE INDEX surprise_box_plays_pkey ON public.surprise_box_plays USING btree (id);

-- INDEX: surprise_box_rewards_pkey ON surprise_box_rewards
CREATE UNIQUE INDEX surprise_box_rewards_pkey ON public.surprise_box_rewards USING btree (id);

-- INDEX: surprise_box_settings_pkey ON surprise_box_settings
CREATE UNIQUE INDEX surprise_box_settings_pkey ON public.surprise_box_settings USING btree (id);

-- INDEX: surprise_box_settings_singleton ON surprise_box_settings
CREATE UNIQUE INDEX surprise_box_settings_singleton ON public.surprise_box_settings USING btree ((true));

-- INDEX: idx_surprise_box_vouchers_code ON surprise_box_vouchers
CREATE INDEX idx_surprise_box_vouchers_code ON public.surprise_box_vouchers USING btree (code);

-- INDEX: idx_surprise_box_vouchers_expires_at ON surprise_box_vouchers
CREATE INDEX idx_surprise_box_vouchers_expires_at ON public.surprise_box_vouchers USING btree (expires_at);

-- INDEX: idx_surprise_box_vouchers_status ON surprise_box_vouchers
CREATE INDEX idx_surprise_box_vouchers_status ON public.surprise_box_vouchers USING btree (status);

-- INDEX: surprise_box_vouchers_code_key ON surprise_box_vouchers
CREATE UNIQUE INDEX surprise_box_vouchers_code_key ON public.surprise_box_vouchers USING btree (code);

-- INDEX: surprise_box_vouchers_pkey ON surprise_box_vouchers
CREATE UNIQUE INDEX surprise_box_vouchers_pkey ON public.surprise_box_vouchers USING btree (id);

-- INDEX: idx_system_api_keys_service_name ON system_api_keys
CREATE INDEX idx_system_api_keys_service_name ON public.system_api_keys USING btree (service_name);

-- INDEX: system_api_keys_pkey ON system_api_keys
CREATE UNIQUE INDEX system_api_keys_pkey ON public.system_api_keys USING btree (id);

-- INDEX: system_api_keys_service_name_key ON system_api_keys
CREATE UNIQUE INDEX system_api_keys_service_name_key ON public.system_api_keys USING btree (service_name);

-- INDEX: idx_task_assignments_assigned_by ON task_assignments
CREATE INDEX idx_task_assignments_assigned_by ON public.task_assignments USING btree (assigned_by);

-- INDEX: idx_task_assignments_assigned_to_branch_id ON task_assignments
CREATE INDEX idx_task_assignments_assigned_to_branch_id ON public.task_assignments USING btree (assigned_to_branch_id);

-- INDEX: idx_task_assignments_assigned_to_user_id ON task_assignments
CREATE INDEX idx_task_assignments_assigned_to_user_id ON public.task_assignments USING btree (assigned_to_user_id);

-- INDEX: idx_task_assignments_assignment_type ON task_assignments
CREATE INDEX idx_task_assignments_assignment_type ON public.task_assignments USING btree (assignment_type);

-- INDEX: idx_task_assignments_deadline_datetime ON task_assignments
CREATE INDEX idx_task_assignments_deadline_datetime ON public.task_assignments USING btree (deadline_datetime) WHERE (deadline_datetime IS NOT NULL);

-- INDEX: idx_task_assignments_overdue ON task_assignments
CREATE INDEX idx_task_assignments_overdue ON public.task_assignments USING btree (deadline_datetime, status) WHERE ((deadline_datetime IS NOT NULL) AND (status <> ALL (ARRAY['completed'::text, 'cancelled'::text])));

-- INDEX: idx_task_assignments_reassignable ON task_assignments
CREATE INDEX idx_task_assignments_reassignable ON public.task_assignments USING btree (is_reassignable, status) WHERE (is_reassignable = true);

-- INDEX: idx_task_assignments_recurring ON task_assignments
CREATE INDEX idx_task_assignments_recurring ON public.task_assignments USING btree (is_recurring, status) WHERE (is_recurring = true);

-- INDEX: idx_task_assignments_schedule_date ON task_assignments
CREATE INDEX idx_task_assignments_schedule_date ON public.task_assignments USING btree (schedule_date) WHERE (schedule_date IS NOT NULL);

-- INDEX: idx_task_assignments_status ON task_assignments
CREATE INDEX idx_task_assignments_status ON public.task_assignments USING btree (status);

-- INDEX: idx_task_assignments_task_id ON task_assignments
CREATE INDEX idx_task_assignments_task_id ON public.task_assignments USING btree (task_id);

-- INDEX: task_assignments_pkey ON task_assignments
CREATE UNIQUE INDEX task_assignments_pkey ON public.task_assignments USING btree (id);

-- INDEX: task_assignments_task_id_assignment_type_assigned_to_user_i_key ON task_assignments
CREATE UNIQUE INDEX task_assignments_task_id_assignment_type_assigned_to_user_i_key ON public.task_assignments USING btree (task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id);

-- INDEX: idx_task_completions_assignment_id ON task_completions
CREATE INDEX idx_task_completions_assignment_id ON public.task_completions USING btree (assignment_id);

-- INDEX: idx_task_completions_completed_at ON task_completions
CREATE INDEX idx_task_completions_completed_at ON public.task_completions USING btree (completed_at DESC);

-- INDEX: idx_task_completions_completed_by ON task_completions
CREATE INDEX idx_task_completions_completed_by ON public.task_completions USING btree (completed_by);

-- INDEX: idx_task_completions_completed_by_branch_id ON task_completions
CREATE INDEX idx_task_completions_completed_by_branch_id ON public.task_completions USING btree (completed_by_branch_id);

-- INDEX: idx_task_completions_erp_reference ON task_completions
CREATE INDEX idx_task_completions_erp_reference ON public.task_completions USING btree (erp_reference_completed);

-- INDEX: idx_task_completions_photo_uploaded ON task_completions
CREATE INDEX idx_task_completions_photo_uploaded ON public.task_completions USING btree (photo_uploaded_completed);

-- INDEX: idx_task_completions_photo_url ON task_completions
CREATE INDEX idx_task_completions_photo_url ON public.task_completions USING btree (completion_photo_url) WHERE (completion_photo_url IS NOT NULL);

-- INDEX: idx_task_completions_task_finished ON task_completions
CREATE INDEX idx_task_completions_task_finished ON public.task_completions USING btree (task_finished_completed);

-- INDEX: idx_task_completions_task_id ON task_completions
CREATE INDEX idx_task_completions_task_id ON public.task_completions USING btree (task_id);

-- INDEX: task_completions_pkey ON task_completions
CREATE UNIQUE INDEX task_completions_pkey ON public.task_completions USING btree (id);

-- INDEX: idx_task_images_attachment_type ON task_images
CREATE INDEX idx_task_images_attachment_type ON public.task_images USING btree (attachment_type);

-- INDEX: idx_task_images_image_type ON task_images
CREATE INDEX idx_task_images_image_type ON public.task_images USING btree (image_type);

-- INDEX: idx_task_images_task_id ON task_images
CREATE INDEX idx_task_images_task_id ON public.task_images USING btree (task_id);

-- INDEX: idx_task_images_uploaded_by ON task_images
CREATE INDEX idx_task_images_uploaded_by ON public.task_images USING btree (uploaded_by);

-- INDEX: task_images_pkey ON task_images
CREATE UNIQUE INDEX task_images_pkey ON public.task_images USING btree (id);

-- INDEX: idx_task_reminder_logs_quick_task ON task_reminder_logs
CREATE INDEX idx_task_reminder_logs_quick_task ON public.task_reminder_logs USING btree (quick_task_assignment_id) WHERE (quick_task_assignment_id IS NOT NULL);

-- INDEX: idx_task_reminder_logs_sent_at ON task_reminder_logs
CREATE INDEX idx_task_reminder_logs_sent_at ON public.task_reminder_logs USING btree (reminder_sent_at);

-- INDEX: idx_task_reminder_logs_status ON task_reminder_logs
CREATE INDEX idx_task_reminder_logs_status ON public.task_reminder_logs USING btree (status);

-- INDEX: idx_task_reminder_logs_task_assignment ON task_reminder_logs
CREATE INDEX idx_task_reminder_logs_task_assignment ON public.task_reminder_logs USING btree (task_assignment_id) WHERE (task_assignment_id IS NOT NULL);

-- INDEX: idx_task_reminder_logs_user ON task_reminder_logs
CREATE INDEX idx_task_reminder_logs_user ON public.task_reminder_logs USING btree (assigned_to_user_id);

-- INDEX: task_reminder_logs_pkey ON task_reminder_logs
CREATE UNIQUE INDEX task_reminder_logs_pkey ON public.task_reminder_logs USING btree (id);

-- INDEX: idx_tasks_created_at ON tasks
CREATE INDEX idx_tasks_created_at ON public.tasks USING btree (created_at DESC);

-- INDEX: idx_tasks_created_by ON tasks
CREATE INDEX idx_tasks_created_by ON public.tasks USING btree (created_by);

-- INDEX: idx_tasks_deleted_at ON tasks
CREATE INDEX idx_tasks_deleted_at ON public.tasks USING btree (deleted_at);

-- INDEX: idx_tasks_due_date ON tasks
CREATE INDEX idx_tasks_due_date ON public.tasks USING btree (due_date) WHERE (due_date IS NOT NULL);

-- INDEX: idx_tasks_metadata ON tasks
CREATE INDEX idx_tasks_metadata ON public.tasks USING gin (metadata);

-- INDEX: idx_tasks_search_vector ON tasks
CREATE INDEX idx_tasks_search_vector ON public.tasks USING gin (search_vector);

-- INDEX: idx_tasks_status ON tasks
CREATE INDEX idx_tasks_status ON public.tasks USING btree (status);

-- INDEX: tasks_pkey ON tasks
CREATE UNIQUE INDEX tasks_pkey ON public.tasks USING btree (id);

-- INDEX: idx_user_audit_logs_action ON user_audit_logs
CREATE INDEX idx_user_audit_logs_action ON public.user_audit_logs USING btree (action);

-- INDEX: idx_user_audit_logs_created_at ON user_audit_logs
CREATE INDEX idx_user_audit_logs_created_at ON public.user_audit_logs USING btree (created_at);

-- INDEX: idx_user_audit_logs_user_id ON user_audit_logs
CREATE INDEX idx_user_audit_logs_user_id ON public.user_audit_logs USING btree (user_id);

-- INDEX: user_audit_logs_pkey ON user_audit_logs
CREATE UNIQUE INDEX user_audit_logs_pkey ON public.user_audit_logs USING btree (id);

-- INDEX: idx_user_device_sessions_active ON user_device_sessions
CREATE INDEX idx_user_device_sessions_active ON public.user_device_sessions USING btree (is_active);

-- INDEX: idx_user_device_sessions_device_id ON user_device_sessions
CREATE INDEX idx_user_device_sessions_device_id ON public.user_device_sessions USING btree (device_id);

-- INDEX: idx_user_device_sessions_expires_at ON user_device_sessions
CREATE INDEX idx_user_device_sessions_expires_at ON public.user_device_sessions USING btree (expires_at);

-- INDEX: idx_user_device_sessions_last_activity ON user_device_sessions
CREATE INDEX idx_user_device_sessions_last_activity ON public.user_device_sessions USING btree (last_activity);

-- INDEX: idx_user_device_sessions_user_id ON user_device_sessions
CREATE INDEX idx_user_device_sessions_user_id ON public.user_device_sessions USING btree (user_id);

-- INDEX: user_device_sessions_pkey ON user_device_sessions
CREATE UNIQUE INDEX user_device_sessions_pkey ON public.user_device_sessions USING btree (id);

-- INDEX: user_device_sessions_user_id_device_id_key ON user_device_sessions
CREATE UNIQUE INDEX user_device_sessions_user_id_device_id_key ON public.user_device_sessions USING btree (user_id, device_id);

-- INDEX: idx_user_erp_credentials_branch_id ON user_erp_credentials
CREATE INDEX idx_user_erp_credentials_branch_id ON public.user_erp_credentials USING btree (branch_id);

-- INDEX: idx_user_erp_credentials_user_id ON user_erp_credentials
CREATE INDEX idx_user_erp_credentials_user_id ON public.user_erp_credentials USING btree (user_id);

-- INDEX: uq_user_erp_credentials_user_branch ON user_erp_credentials
CREATE UNIQUE INDEX uq_user_erp_credentials_user_branch ON public.user_erp_credentials USING btree (user_id, branch_id);

-- INDEX: user_erp_credentials_pkey ON user_erp_credentials
CREATE UNIQUE INDEX user_erp_credentials_pkey ON public.user_erp_credentials USING btree (id);

-- INDEX: idx_user_favorite_buttons_employee_id ON user_favorite_buttons
CREATE INDEX idx_user_favorite_buttons_employee_id ON public.user_favorite_buttons USING btree (employee_id);

-- INDEX: idx_user_favorite_buttons_user_id ON user_favorite_buttons
CREATE INDEX idx_user_favorite_buttons_user_id ON public.user_favorite_buttons USING btree (user_id);

-- INDEX: unique_user_favorite ON user_favorite_buttons
CREATE UNIQUE INDEX unique_user_favorite ON public.user_favorite_buttons USING btree (user_id);

-- INDEX: user_favorite_buttons_pkey ON user_favorite_buttons
CREATE UNIQUE INDEX user_favorite_buttons_pkey ON public.user_favorite_buttons USING btree (id);

-- INDEX: idx_user_mobile_theme_assignments_theme_id ON user_mobile_theme_assignments
CREATE INDEX idx_user_mobile_theme_assignments_theme_id ON public.user_mobile_theme_assignments USING btree (theme_id);

-- INDEX: idx_user_mobile_theme_assignments_user_id ON user_mobile_theme_assignments
CREATE INDEX idx_user_mobile_theme_assignments_user_id ON public.user_mobile_theme_assignments USING btree (user_id);

-- INDEX: idx_user_theme_overrides ON user_mobile_theme_assignments
CREATE INDEX idx_user_theme_overrides ON public.user_mobile_theme_assignments USING btree (user_id) WHERE (color_overrides IS NOT NULL);

-- INDEX: user_mobile_theme_assignments_pkey ON user_mobile_theme_assignments
CREATE UNIQUE INDEX user_mobile_theme_assignments_pkey ON public.user_mobile_theme_assignments USING btree (id);

-- INDEX: user_mobile_theme_assignments_user_id_key ON user_mobile_theme_assignments
CREATE UNIQUE INDEX user_mobile_theme_assignments_user_id_key ON public.user_mobile_theme_assignments USING btree (user_id);

-- INDEX: idx_password_history_user_created ON user_password_history
CREATE INDEX idx_password_history_user_created ON public.user_password_history USING btree (user_id, created_at DESC);

-- INDEX: user_password_history_pkey ON user_password_history
CREATE UNIQUE INDEX user_password_history_pkey ON public.user_password_history USING btree (id);

-- INDEX: idx_user_sessions_active ON user_sessions
CREATE INDEX idx_user_sessions_active ON public.user_sessions USING btree (is_active);

-- INDEX: idx_user_sessions_token ON user_sessions
CREATE INDEX idx_user_sessions_token ON public.user_sessions USING btree (session_token);

-- INDEX: idx_user_sessions_user_id ON user_sessions
CREATE INDEX idx_user_sessions_user_id ON public.user_sessions USING btree (user_id);

-- INDEX: user_sessions_pkey ON user_sessions
CREATE UNIQUE INDEX user_sessions_pkey ON public.user_sessions USING btree (id);

-- INDEX: user_sessions_session_token_key ON user_sessions
CREATE UNIQUE INDEX user_sessions_session_token_key ON public.user_sessions USING btree (session_token);

-- INDEX: idx_user_theme_assignments_theme_id ON user_theme_assignments
CREATE INDEX idx_user_theme_assignments_theme_id ON public.user_theme_assignments USING btree (theme_id);

-- INDEX: idx_user_theme_assignments_user_id ON user_theme_assignments
CREATE INDEX idx_user_theme_assignments_user_id ON public.user_theme_assignments USING btree (user_id);

-- INDEX: user_theme_assignments_pkey ON user_theme_assignments
CREATE UNIQUE INDEX user_theme_assignments_pkey ON public.user_theme_assignments USING btree (id);

-- INDEX: user_theme_assignments_user_id_key ON user_theme_assignments
CREATE UNIQUE INDEX user_theme_assignments_user_id_key ON public.user_theme_assignments USING btree (user_id);

-- INDEX: idx_user_voice_preferences_user_id ON user_voice_preferences
CREATE INDEX idx_user_voice_preferences_user_id ON public.user_voice_preferences USING btree (user_id);

-- INDEX: user_voice_preferences_pkey ON user_voice_preferences
CREATE UNIQUE INDEX user_voice_preferences_pkey ON public.user_voice_preferences USING btree (id);

-- INDEX: user_voice_preferences_user_id_locale_key ON user_voice_preferences
CREATE UNIQUE INDEX user_voice_preferences_user_id_locale_key ON public.user_voice_preferences USING btree (user_id, locale);

-- INDEX: idx_users_ai_translation_enabled ON users
CREATE INDEX idx_users_ai_translation_enabled ON public.users USING btree (ai_translation_enabled);

-- INDEX: idx_users_branch_id ON users
CREATE INDEX idx_users_branch_id ON public.users USING btree (branch_id);

-- INDEX: idx_users_branch_lookup ON users
CREATE INDEX idx_users_branch_lookup ON public.users USING btree (branch_id) WHERE (branch_id IS NOT NULL);

-- INDEX: idx_users_created_at ON users
CREATE INDEX idx_users_created_at ON public.users USING btree (created_at);

-- INDEX: idx_users_employee_id ON users
CREATE INDEX idx_users_employee_id ON public.users USING btree (employee_id);

-- INDEX: idx_users_employee_lookup ON users
CREATE INDEX idx_users_employee_lookup ON public.users USING btree (employee_id) WHERE (employee_id IS NOT NULL);

-- INDEX: idx_users_is_admin ON users
CREATE INDEX idx_users_is_admin ON public.users USING btree (is_admin);

-- INDEX: idx_users_is_master_admin ON users
CREATE INDEX idx_users_is_master_admin ON public.users USING btree (is_master_admin);

-- INDEX: idx_users_last_login ON users
CREATE INDEX idx_users_last_login ON public.users USING btree (last_login_at);

-- INDEX: idx_users_position_lookup ON users
CREATE INDEX idx_users_position_lookup ON public.users USING btree (position_id) WHERE (position_id IS NOT NULL);

-- INDEX: idx_users_quick_access ON users
CREATE UNIQUE INDEX idx_users_quick_access ON public.users USING btree (quick_access_code);

-- INDEX: idx_users_username ON users
CREATE INDEX idx_users_username ON public.users USING btree (username);

-- INDEX: users_pkey ON users
CREATE UNIQUE INDEX users_pkey ON public.users USING btree (id);

-- INDEX: users_quick_access_code_key ON users
CREATE UNIQUE INDEX users_quick_access_code_key ON public.users USING btree (quick_access_code);

-- INDEX: users_username_key ON users
CREATE UNIQUE INDEX users_username_key ON public.users USING btree (username);

-- INDEX: idx_variation_audit_log_action_type ON variation_audit_log
CREATE INDEX idx_variation_audit_log_action_type ON public.variation_audit_log USING btree (action_type);

-- INDEX: idx_variation_audit_log_parent_barcode ON variation_audit_log
CREATE INDEX idx_variation_audit_log_parent_barcode ON public.variation_audit_log USING btree (parent_barcode) WHERE (parent_barcode IS NOT NULL);

-- INDEX: idx_variation_audit_log_timestamp ON variation_audit_log
CREATE INDEX idx_variation_audit_log_timestamp ON public.variation_audit_log USING btree ("timestamp" DESC);

-- INDEX: idx_variation_audit_log_user_id ON variation_audit_log
CREATE INDEX idx_variation_audit_log_user_id ON public.variation_audit_log USING btree (user_id);

-- INDEX: idx_variation_audit_log_variation_group_id ON variation_audit_log
CREATE INDEX idx_variation_audit_log_variation_group_id ON public.variation_audit_log USING btree (variation_group_id) WHERE (variation_group_id IS NOT NULL);

-- INDEX: variation_audit_log_pkey ON variation_audit_log
CREATE UNIQUE INDEX variation_audit_log_pkey ON public.variation_audit_log USING btree (id);

-- INDEX: idx_vendor_payment_approval_requested_by ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_approval_requested_by ON public.vendor_payment_schedule USING btree (approval_requested_by);

-- INDEX: idx_vendor_payment_approval_status ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_approval_status ON public.vendor_payment_schedule USING btree (approval_status) WHERE (approval_status = 'sent_for_approval'::text);

-- INDEX: idx_vendor_payment_approved_by ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_approved_by ON public.vendor_payment_schedule USING btree (approved_by);

-- INDEX: idx_vendor_payment_assigned_approver ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_assigned_approver ON public.vendor_payment_schedule USING btree (assigned_approver_id);

-- INDEX: idx_vendor_payment_schedule_accountant_user_id ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_accountant_user_id ON public.vendor_payment_schedule USING btree (accountant_user_id);

-- INDEX: idx_vendor_payment_schedule_adjustments ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_adjustments ON public.vendor_payment_schedule USING btree (last_adjustment_date) WHERE (last_adjustment_date IS NOT NULL);

-- INDEX: idx_vendor_payment_schedule_branch_id ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_branch_id ON public.vendor_payment_schedule USING btree (branch_id);

-- INDEX: idx_vendor_payment_schedule_due_date ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_due_date ON public.vendor_payment_schedule USING btree (due_date);

-- INDEX: idx_vendor_payment_schedule_due_date_paid ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_due_date_paid ON public.vendor_payment_schedule USING btree (due_date, is_paid);

-- INDEX: idx_vendor_payment_schedule_grr_ref ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_grr_ref ON public.vendor_payment_schedule USING btree (grr_reference_number) WHERE (grr_reference_number IS NOT NULL);

-- INDEX: idx_vendor_payment_schedule_is_paid ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_is_paid ON public.vendor_payment_schedule USING btree (is_paid);

-- INDEX: idx_vendor_payment_schedule_paid_date ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_paid_date ON public.vendor_payment_schedule USING btree (paid_date);

-- INDEX: idx_vendor_payment_schedule_pr_excel_verified ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_pr_excel_verified ON public.vendor_payment_schedule USING btree (pr_excel_verified);

-- INDEX: idx_vendor_payment_schedule_pr_excel_verified_by ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_pr_excel_verified_by ON public.vendor_payment_schedule USING btree (pr_excel_verified_by);

-- INDEX: idx_vendor_payment_schedule_pri_ref ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_pri_ref ON public.vendor_payment_schedule USING btree (pri_reference_number) WHERE (pri_reference_number IS NOT NULL);

-- INDEX: idx_vendor_payment_schedule_receiving_record_id ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_receiving_record_id ON public.vendor_payment_schedule USING btree (receiving_record_id);

-- INDEX: idx_vendor_payment_schedule_task_id ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_task_id ON public.vendor_payment_schedule USING btree (task_id);

-- INDEX: idx_vendor_payment_schedule_vendor_id ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_vendor_id ON public.vendor_payment_schedule USING btree (vendor_id);

-- INDEX: idx_vendor_payment_schedule_verification_status ON vendor_payment_schedule
CREATE INDEX idx_vendor_payment_schedule_verification_status ON public.vendor_payment_schedule USING btree (verification_status);

-- INDEX: vendor_payment_schedule_pkey ON vendor_payment_schedule
CREATE UNIQUE INDEX vendor_payment_schedule_pkey ON public.vendor_payment_schedule USING btree (id);

-- INDEX: idx_vendors_branch_id ON vendors
CREATE INDEX idx_vendors_branch_id ON public.vendors USING btree (branch_id) WHERE (branch_id IS NOT NULL);

-- INDEX: idx_vendors_branch_status ON vendors
CREATE INDEX idx_vendors_branch_status ON public.vendors USING btree (branch_id, status) WHERE (branch_id IS NOT NULL);

-- INDEX: idx_vendors_created_at ON vendors
CREATE INDEX idx_vendors_created_at ON public.vendors USING btree (created_at);

-- INDEX: idx_vendors_erp_vendor_id ON vendors
CREATE INDEX idx_vendors_erp_vendor_id ON public.vendors USING btree (erp_vendor_id);

-- INDEX: idx_vendors_payment_method ON vendors
CREATE INDEX idx_vendors_payment_method ON public.vendors USING gin (to_tsvector('english'::regconfig, payment_method));

-- INDEX: idx_vendors_payment_priority ON vendors
CREATE INDEX idx_vendors_payment_priority ON public.vendors USING btree (payment_priority);

-- INDEX: idx_vendors_status ON vendors
CREATE INDEX idx_vendors_status ON public.vendors USING btree (status);

-- INDEX: idx_vendors_vat_applicable ON vendors
CREATE INDEX idx_vendors_vat_applicable ON public.vendors USING btree (vat_applicable);

-- INDEX: idx_vendors_vendor_name ON vendors
CREATE INDEX idx_vendors_vendor_name ON public.vendors USING btree (vendor_name);

-- INDEX: vendors_erp_vendor_branch_unique ON vendors
CREATE UNIQUE INDEX vendors_erp_vendor_branch_unique ON public.vendors USING btree (erp_vendor_id, branch_id);

-- INDEX: vendors_pkey ON vendors
CREATE UNIQUE INDEX vendors_pkey ON public.vendors USING btree (erp_vendor_id, branch_id);

-- INDEX: idx_view_offer_branch_id ON view_offer
CREATE INDEX idx_view_offer_branch_id ON public.view_offer USING btree (branch_id);

-- INDEX: idx_view_offer_dates ON view_offer
CREATE INDEX idx_view_offer_dates ON public.view_offer USING btree (start_date, end_date);

-- INDEX: idx_view_offer_datetime ON view_offer
CREATE INDEX idx_view_offer_datetime ON public.view_offer USING btree (start_date, start_time, end_date, end_time);

-- INDEX: view_offer_pkey ON view_offer
CREATE UNIQUE INDEX view_offer_pkey ON public.view_offer USING btree (id);

-- INDEX: vip_campaign_settings_pkey ON vip_campaign_settings
CREATE UNIQUE INDEX vip_campaign_settings_pkey ON public.vip_campaign_settings USING btree (id);

-- INDEX: idx_vip_redemptions_customer_id ON vip_redemptions
CREATE INDEX idx_vip_redemptions_customer_id ON public.vip_redemptions USING btree (customer_id);

-- INDEX: idx_vip_redemptions_redeemed_date ON vip_redemptions
CREATE INDEX idx_vip_redemptions_redeemed_date ON public.vip_redemptions USING btree (redeemed_date);

-- INDEX: idx_vip_redemptions_whatsapp_number ON vip_redemptions
CREATE INDEX idx_vip_redemptions_whatsapp_number ON public.vip_redemptions USING btree (whatsapp_number);

-- INDEX: vip_redemptions_number_date_unique ON vip_redemptions
CREATE UNIQUE INDEX vip_redemptions_number_date_unique ON public.vip_redemptions USING btree (whatsapp_number, redeemed_date);

-- INDEX: vip_redemptions_pkey ON vip_redemptions
CREATE UNIQUE INDEX vip_redemptions_pkey ON public.vip_redemptions USING btree (id);

-- INDEX: wa_accounts_pkey ON wa_accounts
CREATE UNIQUE INDEX wa_accounts_pkey ON public.wa_accounts USING btree (id);

-- INDEX: wa_ai_bot_config_pkey ON wa_ai_bot_config
CREATE UNIQUE INDEX wa_ai_bot_config_pkey ON public.wa_ai_bot_config USING btree (id);

-- INDEX: idx_wa_auto_reply_account ON wa_auto_reply_triggers
CREATE INDEX idx_wa_auto_reply_account ON public.wa_auto_reply_triggers USING btree (wa_account_id);

-- INDEX: idx_wa_auto_reply_active ON wa_auto_reply_triggers
CREATE INDEX idx_wa_auto_reply_active ON public.wa_auto_reply_triggers USING btree (is_active);

-- INDEX: idx_wa_auto_reply_order ON wa_auto_reply_triggers
CREATE INDEX idx_wa_auto_reply_order ON public.wa_auto_reply_triggers USING btree (sort_order);

-- INDEX: wa_auto_reply_triggers_pkey ON wa_auto_reply_triggers
CREATE UNIQUE INDEX wa_auto_reply_triggers_pkey ON public.wa_auto_reply_triggers USING btree (id);

-- INDEX: idx_wa_bot_flows_account ON wa_bot_flows
CREATE INDEX idx_wa_bot_flows_account ON public.wa_bot_flows USING btree (wa_account_id);

-- INDEX: idx_wa_bot_flows_active ON wa_bot_flows
CREATE INDEX idx_wa_bot_flows_active ON public.wa_bot_flows USING btree (is_active);

-- INDEX: wa_bot_flows_pkey ON wa_bot_flows
CREATE UNIQUE INDEX wa_bot_flows_pkey ON public.wa_bot_flows USING btree (id);

-- INDEX: idx_wa_broadcast_recip_broadcast ON wa_broadcast_recipients
CREATE INDEX idx_wa_broadcast_recip_broadcast ON public.wa_broadcast_recipients USING btree (broadcast_id);

-- INDEX: idx_wa_broadcast_recip_status ON wa_broadcast_recipients
CREATE INDEX idx_wa_broadcast_recip_status ON public.wa_broadcast_recipients USING btree (status);

-- INDEX: wa_broadcast_recipients_pkey ON wa_broadcast_recipients
CREATE UNIQUE INDEX wa_broadcast_recipients_pkey ON public.wa_broadcast_recipients USING btree (id);

-- INDEX: idx_wa_broadcasts_account ON wa_broadcasts
CREATE INDEX idx_wa_broadcasts_account ON public.wa_broadcasts USING btree (wa_account_id);

-- INDEX: idx_wa_broadcasts_created ON wa_broadcasts
CREATE INDEX idx_wa_broadcasts_created ON public.wa_broadcasts USING btree (created_at DESC);

-- INDEX: idx_wa_broadcasts_status ON wa_broadcasts
CREATE INDEX idx_wa_broadcasts_status ON public.wa_broadcasts USING btree (status);

-- INDEX: wa_broadcasts_pkey ON wa_broadcasts
CREATE UNIQUE INDEX wa_broadcasts_pkey ON public.wa_broadcasts USING btree (id);

-- INDEX: idx_wa_catalog_orders_account ON wa_catalog_orders
CREATE INDEX idx_wa_catalog_orders_account ON public.wa_catalog_orders USING btree (wa_account_id);

-- INDEX: idx_wa_catalog_orders_status ON wa_catalog_orders
CREATE INDEX idx_wa_catalog_orders_status ON public.wa_catalog_orders USING btree (order_status);

-- INDEX: wa_catalog_orders_pkey ON wa_catalog_orders
CREATE UNIQUE INDEX wa_catalog_orders_pkey ON public.wa_catalog_orders USING btree (id);

-- INDEX: idx_wa_catalog_products_account ON wa_catalog_products
CREATE INDEX idx_wa_catalog_products_account ON public.wa_catalog_products USING btree (wa_account_id);

-- INDEX: idx_wa_catalog_products_catalog ON wa_catalog_products
CREATE INDEX idx_wa_catalog_products_catalog ON public.wa_catalog_products USING btree (catalog_id);

-- INDEX: idx_wa_catalog_products_sku ON wa_catalog_products
CREATE INDEX idx_wa_catalog_products_sku ON public.wa_catalog_products USING btree (sku);

-- INDEX: wa_catalog_products_pkey ON wa_catalog_products
CREATE UNIQUE INDEX wa_catalog_products_pkey ON public.wa_catalog_products USING btree (id);

-- INDEX: idx_wa_catalogs_account ON wa_catalogs
CREATE INDEX idx_wa_catalogs_account ON public.wa_catalogs USING btree (wa_account_id);

-- INDEX: wa_catalogs_pkey ON wa_catalogs
CREATE UNIQUE INDEX wa_catalogs_pkey ON public.wa_catalogs USING btree (id);

-- INDEX: idx_wa_group_members_customer ON wa_contact_group_members
CREATE INDEX idx_wa_group_members_customer ON public.wa_contact_group_members USING btree (customer_id);

-- INDEX: idx_wa_group_members_group ON wa_contact_group_members
CREATE INDEX idx_wa_group_members_group ON public.wa_contact_group_members USING btree (group_id);

-- INDEX: wa_contact_group_members_group_id_customer_id_key ON wa_contact_group_members
CREATE UNIQUE INDEX wa_contact_group_members_group_id_customer_id_key ON public.wa_contact_group_members USING btree (group_id, customer_id);

-- INDEX: wa_contact_group_members_pkey ON wa_contact_group_members
CREATE UNIQUE INDEX wa_contact_group_members_pkey ON public.wa_contact_group_members USING btree (id);

-- INDEX: wa_contact_groups_pkey ON wa_contact_groups
CREATE UNIQUE INDEX wa_contact_groups_pkey ON public.wa_contact_groups USING btree (id);

-- INDEX: idx_wa_conv_account_status_lastmsg ON wa_conversations
CREATE INDEX idx_wa_conv_account_status_lastmsg ON public.wa_conversations USING btree (wa_account_id, status, last_message_at DESC);

-- INDEX: idx_wa_conversations_account ON wa_conversations
CREATE INDEX idx_wa_conversations_account ON public.wa_conversations USING btree (wa_account_id);

-- INDEX: idx_wa_conversations_customer ON wa_conversations
CREATE INDEX idx_wa_conversations_customer ON public.wa_conversations USING btree (customer_id);

-- INDEX: idx_wa_conversations_last_msg ON wa_conversations
CREATE INDEX idx_wa_conversations_last_msg ON public.wa_conversations USING btree (last_message_at DESC);

-- INDEX: idx_wa_conversations_phone ON wa_conversations
CREATE INDEX idx_wa_conversations_phone ON public.wa_conversations USING btree (customer_phone);

-- INDEX: idx_wa_conversations_sos ON wa_conversations
CREATE INDEX idx_wa_conversations_sos ON public.wa_conversations USING btree (is_sos) WHERE (is_sos = true);

-- INDEX: wa_conversations_account_phone_unique ON wa_conversations
CREATE UNIQUE INDEX wa_conversations_account_phone_unique ON public.wa_conversations USING btree (wa_account_id, customer_phone);

-- INDEX: wa_conversations_pkey ON wa_conversations
CREATE UNIQUE INDEX wa_conversations_pkey ON public.wa_conversations USING btree (id);

-- INDEX: idx_wa_messages_account ON wa_messages
CREATE INDEX idx_wa_messages_account ON public.wa_messages USING btree (wa_account_id);

-- INDEX: idx_wa_messages_conv_created ON wa_messages
CREATE INDEX idx_wa_messages_conv_created ON public.wa_messages USING btree (conversation_id, created_at DESC);

-- INDEX: idx_wa_messages_conversation ON wa_messages
CREATE INDEX idx_wa_messages_conversation ON public.wa_messages USING btree (conversation_id);

-- INDEX: idx_wa_messages_created ON wa_messages
CREATE INDEX idx_wa_messages_created ON public.wa_messages USING btree (created_at DESC);

-- INDEX: idx_wa_messages_direction ON wa_messages
CREATE INDEX idx_wa_messages_direction ON public.wa_messages USING btree (direction);

-- INDEX: idx_wa_messages_wa_id ON wa_messages
CREATE INDEX idx_wa_messages_wa_id ON public.wa_messages USING btree (whatsapp_message_id);

-- INDEX: wa_messages_pkey ON wa_messages
CREATE UNIQUE INDEX wa_messages_pkey ON public.wa_messages USING btree (id);

-- INDEX: wa_messages_wamid_unique ON wa_messages
CREATE UNIQUE INDEX wa_messages_wamid_unique ON public.wa_messages USING btree (whatsapp_message_id) WHERE ((whatsapp_message_id IS NOT NULL) AND (whatsapp_message_id <> ''::text));

-- INDEX: wa_messages_whatsapp_message_id_unique ON wa_messages
CREATE UNIQUE INDEX wa_messages_whatsapp_message_id_unique ON public.wa_messages USING btree (whatsapp_message_id);

-- INDEX: idx_wa_settings_account ON wa_settings
CREATE INDEX idx_wa_settings_account ON public.wa_settings USING btree (wa_account_id);

-- INDEX: wa_settings_pkey ON wa_settings
CREATE UNIQUE INDEX wa_settings_pkey ON public.wa_settings USING btree (id);

-- INDEX: wa_settings_wa_account_id_unique ON wa_settings
CREATE UNIQUE INDEX wa_settings_wa_account_id_unique ON public.wa_settings USING btree (wa_account_id);

-- INDEX: idx_wa_templates_account ON wa_templates
CREATE INDEX idx_wa_templates_account ON public.wa_templates USING btree (wa_account_id);

-- INDEX: idx_wa_templates_name ON wa_templates
CREATE INDEX idx_wa_templates_name ON public.wa_templates USING btree (name);

-- INDEX: idx_wa_templates_status ON wa_templates
CREATE INDEX idx_wa_templates_status ON public.wa_templates USING btree (status);

-- INDEX: wa_templates_pkey ON wa_templates
CREATE UNIQUE INDEX wa_templates_pkey ON public.wa_templates USING btree (id);

-- INDEX: idx_warning_main_category_name_en ON warning_main_category
CREATE INDEX idx_warning_main_category_name_en ON public.warning_main_category USING btree (name_en);

-- INDEX: warning_main_category_pkey ON warning_main_category
CREATE UNIQUE INDEX warning_main_category_pkey ON public.warning_main_category USING btree (id);

-- INDEX: idx_warning_sub_category_main_id ON warning_sub_category
CREATE INDEX idx_warning_sub_category_main_id ON public.warning_sub_category USING btree (main_category_id);

-- INDEX: idx_warning_sub_category_name_en ON warning_sub_category
CREATE INDEX idx_warning_sub_category_name_en ON public.warning_sub_category USING btree (name_en);

-- INDEX: warning_sub_category_pkey ON warning_sub_category
CREATE UNIQUE INDEX warning_sub_category_pkey ON public.warning_sub_category USING btree (id);

-- INDEX: idx_warning_violation_main_id ON warning_violation
CREATE INDEX idx_warning_violation_main_id ON public.warning_violation USING btree (main_category_id);

-- INDEX: idx_warning_violation_name_en ON warning_violation
CREATE INDEX idx_warning_violation_name_en ON public.warning_violation USING btree (name_en);

-- INDEX: idx_warning_violation_sub_id ON warning_violation
CREATE INDEX idx_warning_violation_sub_id ON public.warning_violation USING btree (sub_category_id);

-- INDEX: warning_violation_pkey ON warning_violation
CREATE UNIQUE INDEX warning_violation_pkey ON public.warning_violation USING btree (id);

-- INDEX: idx_whatsapp_log_created ON whatsapp_message_log
CREATE INDEX idx_whatsapp_log_created ON public.whatsapp_message_log USING btree (created_at DESC);

-- INDEX: idx_whatsapp_log_phone ON whatsapp_message_log
CREATE INDEX idx_whatsapp_log_phone ON public.whatsapp_message_log USING btree (phone_number);

-- INDEX: whatsapp_message_log_pkey ON whatsapp_message_log
CREATE UNIQUE INDEX whatsapp_message_log_pkey ON public.whatsapp_message_log USING btree (id);

